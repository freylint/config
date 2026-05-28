#!/usr/bin/env python3
"""
Task runner — interactive TUI or direct execution.

  ./run.py              # interactive menu
  ./run.py <target>     # run named target directly

Features:
  - Targets: deploy, deploy-hosts, deploy-local, collar, lightsail, rekey,
             flake-update, lock, unlock, ss-dev, vdisp-test, vdisp-vm
  - Deploy pipeline: WoL, hwdef, flake update, fmt, colmena apply
  - AWS Lightsail container build and deploy (nix build → docker load → push → deploy)
  - SOPS secret rekeying
  - Interactive curses TUI with keyboard navigation
"""

from __future__ import annotations

import curses
import json
import os
import re
import socket
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

REPO = Path(__file__).parent
NIXOS = REPO
COLLAR = REPO / "pkg" / "collar"

# ---------------------------------------------------------------------------
# Host inventory
# ---------------------------------------------------------------------------

HOSTS: dict[str, dict] = {
    # mac: set to "aa:bb:cc:dd:ee:ff" to enable Wake-on-LAN; None disables WoL
    "glw": {"host": "glw.lan", "user": "gen", "mac": None},
    "batpc": {"host": "batpc.lan", "user": "bat", "mac": None},
    "homebase": {"host": "homebase.freyground.com", "user": "gen", "mac": None},
}

# ---------------------------------------------------------------------------
# Target definition
# ---------------------------------------------------------------------------


@dataclass
class Target:
    name: str
    description: str
    _cmd: list[str] | Callable[[], list[str]] | None = field(repr=False)

    def build_cmd(self) -> list[str] | None:
        return self._cmd() if callable(self._cmd) else self._cmd


TARGETS: list[Target] = [
    Target("deploy",       "Full deploy: hwdef → update → fmt → colmena all", None),
    Target("deploy-hosts", "Deploy to HOSTS (comma-separated env var)",                     None),
    Target("deploy-local", "Apply config to local machine via colmena apply-local",         None),
    Target("collar",       "Build collar embedded firmware via nix",                         None),
    Target("lightsail",    "Build container and deploy to AWS Lightsail (set LIGHTSAIL_SERVICE)", None),
    Target("rekey",        "Re-encrypt all sops secrets for current key set",                    None),
    Target("lock",         "Lock the display session",   lambda: ["loginctl", "lock-session",   _session()]),
    Target("unlock",       "Unlock the display session", lambda: ["loginctl", "unlock-session", _session()]),
    Target("flake-update", "Update flake.lock (nix flake update)",                           None),
    Target("ss-dev",       "Screensaver dev cycle: unlock → wait 5s → lock",                None),
    Target("vdisp-test",   "Check virtual display service and DRM state on homebase",        None),
    Target("vdisp-vm",     "Build and run virtual-display test VM (SSH :2222 root/root)",    None),
]

_TARGET_MAP: dict[str, Target] = {t.name: t for t in TARGETS}

# ---------------------------------------------------------------------------
# Low-level helpers
# ---------------------------------------------------------------------------


def _run(
    cmd: list[str],
    cwd: Path | None = None,
    extra_env: dict[str, str] | None = None,
) -> int:
    env = {**os.environ, **(extra_env or {})}
    return subprocess.run(cmd, env=env, cwd=cwd).returncode


def _capture(cmd: list[str], cwd: Path | None = None) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)


def _session() -> str | None:
    out = _capture(["loginctl", "list-sessions", "--no-legend"]).stdout
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 4 and parts[3] != "-":
            return parts[0]
    return None


def _nixos(*args: str) -> list[str]:
    """Wrap a command to run inside the nixos devShell."""
    return ["nix", "develop", str(NIXOS), "--command", *args]


def _wake(mac: str) -> None:
    mac_bytes = bytes.fromhex(mac.replace(":", "").replace("-", ""))
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        s.sendto(b"\xff" * 6 + mac_bytes * 16, ("<broadcast>", 9))


def _wait_online(host: str, timeout: int = 60) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if _capture(["ping", "-c1", "-W1", host]).returncode == 0:
            return True
        time.sleep(2)
    return False


def _wake_hosts(targets: dict[str, dict]) -> int:
    for name, info in targets.items():
        if not (mac := info.get("mac")):
            continue
        if _capture(["ping", "-c1", "-W1", info["host"]]).returncode == 0:
            continue
        print(f"  waking {name}")
        _wake(mac)
        print(f"  waiting for {name}", end="", flush=True)
        if _wait_online(info["host"]):
            print(" online")
        else:
            print(f"\n  WARNING: {name} did not come online", file=sys.stderr)
    return 0

# ---------------------------------------------------------------------------
# Deploy pipeline steps
# ---------------------------------------------------------------------------


def _update_hwdef(name: str, info: dict) -> bool:
    """Fetch hardware config from host via SSH. Returns True on success."""
    print(f"  hwdef: {name}")
    result = _capture(["ssh", f"{info['user']}@{info['host']}",
                        "sudo nixos-generate-config --show-hardware-config"])
    if result.returncode != 0:
        print(f"  WARNING: hwdef failed for {name}: {result.stderr.strip()}", file=sys.stderr)
        return False
    path = NIXOS / "hwdef" / f"{name}.nix"
    path.write_text(result.stdout)
    subprocess.run(["git", "add", str(path)], cwd=REPO)
    return True


def _flake_update() -> int:
    print("  nix flake update")
    return _run(["nix", "flake", "update"], cwd=NIXOS)


def _fmt() -> int:
    print("  nix fmt")
    return _run(["nix", "fmt", "."], cwd=NIXOS)


def _colmena(on: list[str] | None = None) -> int:
    cmd = ["colmena", "apply", "--impure"]
    cmd += ["--on", ",".join(on)] if on else ["--keep-going"]
    return _run(_nixos(*cmd), cwd=NIXOS, extra_env={"NIXPKGS_ALLOW_UNFREE": "1"})


def _pipeline(on: list[str] | None = None) -> int:
    """Full deploy pipeline for the given hosts (None = all)."""
    targets = {k: v for k, v in HOSTS.items() if on is None or k in on}

    steps: list[tuple[str, Callable[[], int | None]]] = [
        ("wake",           lambda: _wake_hosts(targets)),
        ("hwdefs",         lambda: 0 if all(_update_hwdef(n, i) for n, i in targets.items()) else 1),
        ("flake update",   _flake_update),
        ("fmt",            _fmt),
        ("colmena apply",  lambda: _colmena(on)),
    ]
    for label, step in steps:
        print(f"\n→ {label}")
        rc = step()
        if rc:
            print(f"  step failed (exit {rc})", file=sys.stderr)
            return rc
    return 0

# ---------------------------------------------------------------------------
# Lightsail pipeline
# ---------------------------------------------------------------------------


def _lightsail() -> int:
    service = os.environ.get("LIGHTSAIL_SERVICE", "jump")
    label = os.environ.get("LIGHTSAIL_LABEL", "jump")
    protocol = os.environ.get("LIGHTSAIL_PROTOCOL", "HTTP")

    if _capture(["aws", "sts", "get-caller-identity"]).returncode:
        print("error: AWS credentials not configured (set AWS_ACCESS_KEY_ID/AWS_SECRET_ACCESS_KEY or configure ~/.aws/credentials)", file=sys.stderr)
        return 1

    _port_r = _capture(["nix", "eval", "--json", f"{NIXOS}#containerPort"])
    port = os.environ.get("LIGHTSAIL_PORT") or (_port_r.stdout.strip() if _port_r.returncode == 0 else "8080")

    print("→ nix build .#container")
    if _run(["nix", "build", ".#container", "--out-link", "/tmp/lightsail-container"], cwd=NIXOS):
        return 1

    print("→ docker load")
    load = _capture(["docker", "load", "--input", "/tmp/lightsail-container"])
    if load.returncode:
        print(load.stderr, file=sys.stderr)
        return load.returncode
    m = re.search(r"Loaded image: (.+)", load.stdout)
    image = m.group(1).strip() if m else "app:latest"

    print(f"→ lightsail push-container-image ({service})")
    push = _capture(["aws", "lightsail", "push-container-image",
                     "--service-name", service, "--label", label, "--image", image])
    if push.returncode:
        print(push.stderr, file=sys.stderr)
        return push.returncode
    ref_match = re.search(rf"(:{re.escape(service)}\.{re.escape(label)}\.\d+)",
                          push.stdout + push.stderr)
    if not ref_match:
        print("error: could not parse Lightsail image reference", file=sys.stderr)
        print(push.stdout, file=sys.stderr)
        return 1
    image_ref = ref_match.group(1)

    containers = json.dumps({label: {"image": image_ref, "ports": {port: protocol}}})
    endpoint = json.dumps({
        "containerName": label,
        "containerPort": int(port),
        "healthCheck": {"path": "/"},
    })

    print(f"→ lightsail create-container-service-deployment ({image_ref})")
    return _run(["aws", "lightsail", "create-container-service-deployment",
                 "--service-name", service,
                 "--containers", containers,
                 "--public-endpoint", endpoint])

# ---------------------------------------------------------------------------
# Sops rekey
# ---------------------------------------------------------------------------


def _rekey() -> int:
    """Re-encrypt all sops secret files using current .sops.yaml key config."""
    secret_files = sorted(REPO.glob("secrets/**/*.yaml"))
    if not secret_files:
        print("No secret files found under secrets/")
        return 0
    rc = 0
    for f in secret_files:
        print(f"  rekeying {f.relative_to(REPO)}")
        result = subprocess.run(["sops", "updatekeys", "--yes", str(f)], cwd=REPO)
        if result.returncode:
            rc = result.returncode
    return rc


# ---------------------------------------------------------------------------
# Virtual display diagnostics
# ---------------------------------------------------------------------------


def _vdisp_test() -> int:
    info = HOSTS["homebase"]
    host, user = info["host"], info["user"]
    diag = (
        "echo '=== DRM connectors ==='; "
        "for f in /sys/class/drm/*/status; do "
        "  echo \"$(basename $(dirname $f)): $(cat $f)\"; "
        "done; "
        "echo; echo '=== virtual-display-manager service ==='; "
        "systemctl --user status virtual-display-manager --no-pager 2>&1 || true; "
        "echo; echo '=== kscreen outputs ==='; "
        "WAYLAND_DISPLAY=wayland-0 "
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus "
        "kscreen-doctor --outputs 2>&1 || true; "
        "echo; echo '=== virtual-display-manager journal ==='; "
        "journalctl --user -u virtual-display-manager -n 20 --no-pager 2>&1 || true"
    )
    return _run(["ssh", f"{user}@{host}", diag])


# ---------------------------------------------------------------------------
# Target dispatch
# ---------------------------------------------------------------------------


def run_target(target: Target) -> int:
    match target.name:
        case "deploy":
            return _pipeline()
        case "deploy-hosts":
            hosts = [h.strip() for h in os.environ.get("HOSTS", "").split(",") if h.strip()]
            return _pipeline(on=hosts or None)
        case "deploy-local":
            return _run(
                _nixos("colmena", "apply-local", "--impure", "--sudo"),
                cwd=NIXOS,
                extra_env={"NIXPKGS_ALLOW_UNFREE": "1"},
            )
        case "collar":
            return _run(["nix", "build", ".#default"], cwd=COLLAR)
        case "lightsail":
            return _lightsail()
        case "flake-update":
            return _flake_update()
        case "rekey":
            return _rekey()
        case "ss-dev":
            sess = _session()
            _run(["loginctl", "unlock-session", sess])
            time.sleep(5)
            return _run(["loginctl", "lock-session", sess])
        case "vdisp-test":
            return _vdisp_test()
        case "vdisp-vm":
            return _run(["nix", "run", "--impure", f"{NIXOS}#vdisp-vm"])
        case _:
            cmd = target.build_cmd()
            if cmd is None:
                print(f"error: no command defined for {target.name!r}", file=sys.stderr)
                return 1
            return _run(cmd)

# ---------------------------------------------------------------------------
# TUI
# ---------------------------------------------------------------------------


def _draw(stdscr: curses.window, selected: int) -> None:
    stdscr.clear()
    h, w = stdscr.getmaxyx()

    title = " Task Runner "
    stdscr.addstr(0, max(0, (w - len(title)) // 2), title, curses.A_BOLD | curses.A_REVERSE)

    for i, t in enumerate(TARGETS):
        y = i + 2
        if y >= h - 2:
            break
        attr = curses.A_REVERSE if i == selected else curses.A_NORMAL
        line = f"  {t.name:<18} {t.description}"
        stdscr.addstr(y, 0, line[: w - 1], attr)

    hint = " ↑↓ / jk  navigate    Enter  run    q  quit "
    stdscr.addstr(h - 1, 0, hint[: w - 1], curses.A_DIM)
    stdscr.refresh()


def _menu(stdscr: curses.window) -> Target | None:
    curses.curs_set(0)
    selected = 0

    while True:
        _draw(stdscr, selected)
        key = stdscr.getch()

        if key in (ord("q"), ord("Q"), 27):
            return None
        elif key in (curses.KEY_UP, ord("k")) and selected > 0:
            selected -= 1
        elif key in (curses.KEY_DOWN, ord("j")) and selected < len(TARGETS) - 1:
            selected += 1
        elif key in (curses.KEY_ENTER, ord("\n"), ord("\r")):
            return TARGETS[selected]


def interactive() -> int:
    target = curses.wrapper(_menu)
    if target is None:
        return 0
    print(f"\n→ {target.name}: {target.description}\n")
    return run_target(target)

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------


def main() -> None:
    if len(sys.argv) > 1:
        name = sys.argv[1]
        if name not in _TARGET_MAP:
            names = ", ".join(_TARGET_MAP)
            print(f"Unknown target {name!r}. Available: {names}", file=sys.stderr)
            sys.exit(1)
        sys.exit(run_target(_TARGET_MAP[name]))
    else:
        sys.exit(interactive())


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""
Task runner — interactive TUI or direct execution.

  ./run.py              # interactive menu
  ./run.py <target>     # run named target directly

Features:
  - Targets: deploy, deploy-hosts, deploy-local, collar, lightsail, rekey,
             update, flake-update, lock, unlock, ss-dev, vdisp-test, vdisp-vm, check
  - Deploy pipeline: WoL, hwdef, flake update, fmt, nixos-rebuild per host
  - Multi-address resolution per host: first reachable address selected at deploy time
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

REPO = Path(__file__).parent
NIXOS = REPO
COLLAR = REPO / "pkg" / "collar"

HOSTS: dict[str, dict] = {
    # mac: set to "aa:bb:cc:dd:ee:ff" to enable Wake-on-LAN; None disables WoL
    # hosts: list of addresses tried in order; first reachable one is used
    # local: True means deploy without --target-host (run nixos-rebuild directly)
    "glw":      {"hosts": ["glw.lan"],                 "user": "gen", "mac": None, "local": True},
    "batpc":    {"hosts": ["batpc.lan"],                "user": "bat", "mac": None, "local": False},
    "homebase": {"hosts": ["homebase.freyground.com"],  "user": "gen", "mac": None, "local": False},
}


@dataclass
class Target:
    name: str
    description: str
    _cmd: list[str] | Callable[[], list[str]] | None = field(repr=False)


TARGETS: list[Target] = [
    Target("deploy",       "Full deploy: hwdef → update → fmt → nixos-rebuild all", None),
    Target("deploy-hosts", "Deploy to DEPLOY_HOSTS (comma-separated env var)",       None),
    Target("deploy-local", "Apply config to local machine via nixos-rebuild switch", None),
    Target("collar",       "Build collar embedded firmware via nix",                  None),
    Target("lightsail",    "Build container and deploy to AWS Lightsail (set LIGHTSAIL_SERVICE)", None),
    Target("rekey",        "Re-encrypt all sops secrets for current key set",         None),
    Target("lock",         "Lock the display session",   lambda: ["loginctl", "lock-session",   _session()]),
    Target("unlock",       "Unlock the display session", lambda: ["loginctl", "unlock-session", _session()]),
    Target("update",       "Update flake inputs and reformat (UPDATE_INPUT=<name> for one)", None),
    Target("flake-update", "Update flake.lock (nix flake update)",                    None),
    Target("ss-dev",       "Screensaver dev cycle: unlock → wait 5s → lock",         None),
    Target("vdisp-test",   "Check virtual display service and DRM state on homebase", None),
    Target("vdisp-vm",     "Build and run virtual-display test VM (SSH :2222 root/root)", None),
    Target("check",        "Run BDD test suite: unit (eval) + integration (VM) via nix flake check", None),
]


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


def _wake(mac: str) -> None:
    mac_bytes = bytes.fromhex(mac.replace(":", "").replace("-", ""))
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
        s.sendto(b"\xff" * 6 + mac_bytes * 16, ("<broadcast>", 9))


def _wait_online(hosts: list[str], timeout: int = 60) -> bool:
    deadline = time.time() + timeout
    while time.time() < deadline:
        if any(_capture(["ping", "-c1", "-W1", h]).returncode == 0 for h in hosts):
            return True
        time.sleep(2)
    return False


def _resolve_host(name: str, hosts: list[str]) -> str:
    """Return the first reachable address, or the first entry (with a warning) if none respond."""
    for h in hosts:
        if _capture(["ping", "-c1", "-W1", h]).returncode == 0:
            return h
    print(f"  WARNING: no address responded for {name}, falling back to {hosts[0]}", file=sys.stderr)
    return hosts[0]


def _wake_hosts(targets: dict[str, dict]) -> int:
    for name, info in targets.items():
        if not (mac := info.get("mac")):
            continue
        if any(_capture(["ping", "-c1", "-W1", h]).returncode == 0 for h in info["hosts"]):
            continue
        print(f"  waking {name}")
        _wake(mac)
        print(f"  waiting for {name}", end="", flush=True)
        if _wait_online(info["hosts"]):
            print(" online")
        else:
            print(f"\n  WARNING: {name} did not come online", file=sys.stderr)
    return 0


def _update_hwdef(name: str, info: dict, host: str) -> bool:
    """Fetch hardware config from host via SSH. Returns True on success."""
    print(f"  hwdef: {name} ({host})")
    result = _capture(["ssh", f"{info['user']}@{host}",
                        "sudo nixos-generate-config --show-hardware-config"])
    if result.returncode != 0:
        print(f"  WARNING: hwdef failed for {name}: {result.stderr.strip()}", file=sys.stderr)
        return False
    path = NIXOS / "hwdef" / f"{name}.nix"
    path.write_text(result.stdout)
    subprocess.run(["git", "add", str(path)], cwd=REPO)
    return True


def _flake_update(input: str | None = None) -> int:
    cmd = ["nix", "flake", "update"] + ([input] if input else [])
    print(f"  {' '.join(cmd)}")
    return _run(cmd, cwd=NIXOS)


def _fmt() -> int:
    print("  nix fmt")
    return _run(["nix", "fmt", "."], cwd=NIXOS)


def _nixos_rebuild(host: str, target_addr: str | None = None) -> int:
    """Deploy a NixOS host via nixos-rebuild switch."""
    cmd = ["nixos-rebuild", "switch", "--flake", f"{NIXOS}#{host}", "--impure"]
    if target_addr:
        cmd += ["--target-host", f"root@{target_addr}", "--build-host", f"root@{target_addr}"]
    return _run(cmd, cwd=NIXOS, extra_env={"NIXPKGS_ALLOW_UNFREE": "1"})


def _pipeline(on: list[str] | None = None) -> int:
    """Full deploy pipeline for the given hosts (None = all)."""
    targets = {k: v for k, v in HOSTS.items() if on is None or k in on}

    print("\n→ wake")
    if rc := _wake_hosts(targets):
        print(f"  step failed (exit {rc})", file=sys.stderr)
        return rc

    print("\n→ resolve")
    resolved = {n: _resolve_host(n, info["hosts"]) for n, info in targets.items()}

    print("\n→ hwdefs")
    for n in targets:  # non-fatal: sudo/TTY may be unavailable
        _update_hwdef(n, targets[n], resolved[n])

    print("\n→ flake update")
    if rc := _flake_update():
        print(f"  step failed (exit {rc})", file=sys.stderr)
        return rc

    print("\n→ fmt")
    if rc := _fmt():
        print(f"  step failed (exit {rc})", file=sys.stderr)
        return rc

    print("\n→ nixos-rebuild")
    for name, info in targets.items():
        addr = None if info.get("local") else resolved[name]
        print(f"  {name}" + (f" → {addr}" if addr else " (local)"))
        if rc := _nixos_rebuild(name, addr):
            print(f"  step failed (exit {rc})", file=sys.stderr)
            return rc

    return 0


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
    return _run(["aws", "--no-cli-pager", "lightsail", "create-container-service-deployment",
                 "--service-name", service,
                 "--containers", containers,
                 "--public-endpoint", endpoint])


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


def _vdisp_test() -> int:
    info = HOSTS["homebase"]
    host, user = _resolve_host("homebase", info["hosts"]), info["user"]
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


def run_target(target: Target) -> int:
    match target.name:
        case "deploy":
            return _pipeline()
        case "deploy-hosts":
            hosts = [h.strip() for h in os.environ.get("DEPLOY_HOSTS", "").split(",") if h.strip()]
            return _pipeline(on=hosts or None)
        case "deploy-local":
            return _nixos_rebuild("glw")
        case "collar":
            return _run(["nix", "build", ".#default"], cwd=COLLAR)
        case "lightsail":
            return _lightsail()
        case "update":
            if rc := _flake_update(os.environ.get("UPDATE_INPUT") or None):
                return rc
            return _fmt()
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
        case "check":
            return _run(["nix", "flake", "check", "--impure"], cwd=NIXOS)
        case _:
            cmd = target._cmd() if callable(target._cmd) else target._cmd
            if cmd is None:
                print(f"error: no command defined for {target.name!r}", file=sys.stderr)
                return 1
            return _run(cmd)


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


def main() -> None:
    if len(sys.argv) > 1:
        name = sys.argv[1]
        target_map = {t.name: t for t in TARGETS}
        if name not in target_map:
            print(f"Unknown target {name!r}. Available: {', '.join(target_map)}", file=sys.stderr)
            sys.exit(1)
        sys.exit(run_target(target_map[name]))
    else:
        sys.exit(interactive())


if __name__ == "__main__":
    main()

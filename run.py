#!/usr/bin/env python3
"""
Task runner — interactive TUI or direct execution.

  ./run.py              # interactive menu
  ./run.py <target>     # run named target directly
"""

from __future__ import annotations

import curses
import json
import os
import re
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
COLLAR = REPO / "collar"

# ---------------------------------------------------------------------------
# Host inventory (formerly Ansible inventory)
# ---------------------------------------------------------------------------

HOSTS: dict[str, dict[str, str]] = {
    "glw":      {"host": "glw.lan",                "user": "gen"},
    "batpc":    {"host": "batpc.lan",               "user": "bat"},
    "homebase": {"host": "homebase.freyground.com", "user": "gen"},
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
    Target("deploy",       "Full deploy: codegen → hwconfig → update → fmt → colmena all", None),
    Target("deploy-hosts", "Deploy to HOSTS (comma-separated env var)",                     None),
    Target("deploy-local", "Apply config to local machine via colmena apply-local",         None),
    Target("collar",       "Build collar embedded firmware via nix",                         None),
    Target("lightsail",    "Build container and deploy to AWS Lightsail (set LIGHTSAIL_SERVICE)", None),
    Target("rekey",        "Re-encrypt all sops secrets for current key set",                    None),
    Target("lock",         "Lock the display session",   lambda: ["loginctl", "lock-session",   _session()]),
    Target("unlock",       "Unlock the display session", lambda: ["loginctl", "unlock-session", _session()]),
    Target("ss-dev",       "Screensaver dev cycle: unlock → wait 5s → lock",                None),
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

# ---------------------------------------------------------------------------
# Deploy pipeline steps
# ---------------------------------------------------------------------------


def _codegen() -> int:
    print("  codegen")
    return _run(
        ["python3", str(NIXOS / "scripts/codegen.py"), str(NIXOS)],
    )


def _update_hwconfig(name: str, info: dict[str, str]) -> None:
    print(f"  hwconfig: {name}")
    result = _capture(["ssh", f"{info['user']}@{info['host']}",
                        "sudo nixos-generate-config --show-hardware-config"])
    if result.returncode != 0:
        print(f"  WARNING: hwconfig failed for {name}: {result.stderr.strip()}", file=sys.stderr)
        return
    path = NIXOS / "pkg/hwconfig" / f"{name}.nix"
    path.write_text(result.stdout)
    subprocess.run(["git", "add", str(path)], cwd=REPO)


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
        ("codegen",        _codegen),
        ("hwconfigs",      lambda: [_update_hwconfig(n, i) for n, i in targets.items()] and None),
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
    service  = os.environ.get("LIGHTSAIL_SERVICE", "app")
    label    = os.environ.get("LIGHTSAIL_LABEL",   "app")
    port     = os.environ.get("LIGHTSAIL_PORT",    "8080")
    protocol = os.environ.get("LIGHTSAIL_PROTOCOL", "HTTP")

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
    endpoint   = json.dumps({
        "containerName": label,
        "containerPort": int(port),
        "healthCheck":   {"path": "/"},
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
        case "rekey":
            return _rekey()
        case "ss-dev":
            sess = _session()
            _run(["loginctl", "unlock-session", sess])
            time.sleep(5)
            return _run(["loginctl", "lock-session", sess])
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

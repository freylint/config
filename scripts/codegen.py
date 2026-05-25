#!/usr/bin/env python3
"""
NixOS config codegen.

Scans all .nix files under FLAKE_DIR for marked regions and regenerates
their content in-place:

    # CODEGEN-<TYPE> BEGIN [key=value ...]
    ... generated content (replaced on each run) ...
    # CODEGEN-<TYPE> END

The script is idempotent — it only writes a file when the generated content
actually differs from what is already there.

Adding a new codegen type
--------------------------
Decorate a function with @handler("MY-TYPE"):

    @handler("MY-TYPE")
    def my_handler(params: dict[str, str]) -> list[str]:
        # params comes from key=value tokens on the BEGIN line
        return ["line one", "line two"]

Each returned string becomes one output line; the script applies the
indentation of the BEGIN comment automatically.

Usage
-----
    python3 codegen.py [FLAKE_DIR]

FLAKE_DIR defaults to the directory containing this script's parent
(i.e. <flake_dir>/scripts/codegen.py → flake_dir).
"""

from __future__ import annotations

import re
import sys
import urllib.request
from pathlib import Path

# ---------------------------------------------------------------------------
# Core machinery
# ---------------------------------------------------------------------------

_HANDLERS: dict[str, callable] = {}

# Matches a full CODEGEN block including its delimiters.
# Groups: (indent, TYPE, params_suffix, body)
_MARKER_RE = re.compile(
    r"^( *)# CODEGEN-(\S+) BEGIN([^\n]*)\n(.*?)^\1# CODEGEN-\2 END",
    re.MULTILINE | re.DOTALL,
)


def handler(name: str):
    """Register a codegen handler for marker type *name*."""
    def decorator(fn):
        _HANDLERS[name] = fn
        return fn
    return decorator


def _parse_params(raw: str) -> dict[str, str]:
    """Parse 'key=value ...' tokens from the tail of a BEGIN line."""
    params: dict[str, str] = {}
    for token in raw.split():
        if "=" in token:
            k, v = token.split("=", 1)
            params[k] = v
    return params


def _process_file(path: Path) -> bool:
    """Regenerate all CODEGEN blocks in *path*. Returns True if the file changed."""
    content = path.read_text()
    changed = False

    def _replacer(m: re.Match) -> str:
        nonlocal changed
        indent, ctype, params_suffix = m.group(1), m.group(2), m.group(3)
        params = _parse_params(params_suffix)

        if ctype not in _HANDLERS:
            print(f"  WARNING: unknown codegen type {ctype!r} in {path}", file=sys.stderr)
            return m.group(0)

        lines = _HANDLERS[ctype](params)
        inner = "\n".join(f"{indent}{line}" for line in lines)
        replacement = (
            f"{indent}# CODEGEN-{ctype} BEGIN{params_suffix}\n"
            f"{inner}\n"
            f"{indent}# CODEGEN-{ctype} END"
        )
        if replacement != m.group(0):
            changed = True
        return replacement

    new_content = _MARKER_RE.sub(_replacer, content)
    if changed:
        path.write_text(new_content)
        print(f"Updated {path}")
    return changed


# ---------------------------------------------------------------------------
# Handlers
# ---------------------------------------------------------------------------

@handler("SSH-KEYS")
def _ssh_keys(params: dict[str, str]) -> list[str]:
    """Fetch SSH public keys from GitHub.

    Params:
        user  GitHub username whose .keys endpoint to query (default: freylint)
    """
    user = params.get("user", "freylint")
    url = f"https://github.com/{user}.keys"
    with urllib.request.urlopen(url) as resp:
        raw = resp.read().decode().strip()
    return [f'"{key}"' for key in raw.splitlines() if key.strip()]


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

def main() -> None:
    if len(sys.argv) > 1:
        flake_dir = Path(sys.argv[1])
    else:
        flake_dir = Path(__file__).parent.parent

    nix_files = sorted(flake_dir.rglob("*.nix"))
    any_changed = False
    for f in nix_files:
        if "# CODEGEN-" in f.read_text():
            if _process_file(f):
                any_changed = True

    if not any_changed:
        print("codegen: no changes")


if __name__ == "__main__":
    main()

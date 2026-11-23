#!/usr/bin/env bash
# Print the bin directory containing the pinned GDScript tools.
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
venv="$root/.venv-gdtoolkit"
pin="$(sed -n 's/^gdtoolkit==//p' "$root/requirements-dev.txt")"

pinned_tools() {
  local bin="$1"
  [[ "$("$bin/gdformat" --version 2>/dev/null)" == "gdformat $pin" &&
     "$("$bin/gdlint" --version 2>/dev/null)" == "gdlint $pin" ]]
}

# Prefer a matching checkout venv or an existing matching tool pair on PATH.
if pinned_tools "$venv/bin"; then
  printf '%s\n' "$venv/bin"
  exit 0
fi
if [[ ! -e "$venv" ]] && formatter="$(type -P gdformat)" &&
   pinned_tools "$(dirname "$formatter")"; then
  dirname "$formatter"
  exit 0
fi

if ! (python3 -m venv --clear "$venv" &&
      "$venv/bin/python" -m pip --disable-pip-version-check install -r "$root/requirements-dev.txt" &&
      pinned_tools "$venv/bin") >&2; then
  echo 'error: could not install pinned gdtoolkit. Install Python venv support and make PyPI available, or put matching tools from requirements-dev.txt on PATH.' >&2
  exit 1
fi
printf '%s\n' "$venv/bin"

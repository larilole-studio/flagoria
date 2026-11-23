#!/usr/bin/env bash
# Read-only lint of the feature map against the repo, no Godot needed:
#   - every feature page is indexed once, and relative Markdown links resolve;
#   - every drive script is named by a feature page;
#   - every feature file (except README) has exactly one Drive: line:
#       Drive: drives/<path>.gd   (file must exist under the skill)
#       Drive: not player-facing
#   - features with drives declare tracked production scripts on Source: lines;
#   - every test name a feature file cites (`test_<name>`) is a registered test;
#   - every registered test is cited by at least one feature file.
#   - with --gameplay and --changed-files <path>: a gameplay PR fails when a
#     changed or added features/*.md (not README) lacks a Drive: line.
# Registered tests are the `func _test_<name>` functions in tests/run_tests.gd
# and tests/**/test_*.gd, the set `run_tests.gd -- --list` prints.
# Exit 0 when clean, 1 with one line per problem. --self-test exits 0/1 on its own.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"
SKILL=".cursor/skills/verify-flagoria"
MAP="${SKILL}/features"
DRIVES="${SKILL}/drives"
bad=0
problem() { echo "check-map: $*"; bad=1; }

CHANGED_FILE=""
GAMEPLAY=0
SELF_TEST=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --changed-files) CHANGED_FILE="${2:-}"; shift 2 ;;
    --gameplay) GAMEPLAY=1; shift ;;
    --self-test) SELF_TEST=1; shift ;;
    -h|--help)
      echo "usage: check-map.sh [--gameplay --changed-files paths.txt] [--self-test]" >&2
      exit 2 ;;
    *) echo "check-map: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Returns the Drive: value (drives/...gd or "not player-facing") or empty.
drive_line() {
  # Prefer a line that is exactly "Drive: …" (not nested in a bullet).
  local v
  v="$(grep -E '^Drive:[[:space:]]+' "$1" | head -n 1 | sed -E 's/^Drive:[[:space:]]+//; s/[[:space:]]+$//')" || true
  printf '%s' "${v}"
}

check_drive_value() {
  # $1 = feature basename, $2 = Drive: value
  local name="$1" value="$2"
  if [[ -z "${value}" ]]; then
    problem "${name} has no Drive: line (want 'Drive: drives/<name>.gd' or 'Drive: not player-facing')"
    return
  fi
  if [[ "${value}" == "not player-facing" ]]; then
    return
  fi
  if [[ "${value}" =~ ^drives/[A-Za-z0-9_./-]+\.gd$ ]]; then
    if [[ ! -f "${SKILL}/${value}" ]]; then
      problem "${name} Drive: ${value} but ${SKILL}/${value} does not exist"
    fi
    return
  fi
  problem "${name} Drive: '${value}' is not 'drives/<path>.gd' or 'not player-facing'"
}

check_feature_sources() {
  local file="$1" name="$2" source count=0
  while IFS= read -r source; do
    count=$((count + 1))
    if [[ ! "$source" =~ ^(Scripts/[^[:space:]]+\.gd|flagoria_main\.gd)$ ]]; then
      problem "${name} has an invalid Source: '${source}' (want a production script path)"
    elif [[ ! -f "$source" ]] || ! env -u GH_TOKEN -u GITHUB_TOKEN git --literal-pathspecs ls-files -- "$source" | grep -qxF -- "$source"; then
      problem "${name} Source: ${source} is not an existing tracked file"
    fi
  done < <(sed -nE '/^Source:/ { s/^Source:[[:blank:]]+//; s/[[:space:]]+$//; p; }' "$file")
  [[ "$count" -gt 0 ]] || problem "${name} has no Source: line"
}

check_feature_drives() {
  local f name value
  for f in "${MAP}"/*.md; do
    name="$(basename "$f")"
    [[ "$name" == README.md ]] && continue
    if [[ "$(grep -c '^Drive:' "$f")" -gt 1 ]]; then
      problem "${name} has more than one Drive: line"
    fi
    value="$(drive_line "$f")"
    check_drive_value "${name}" "${value}"
    # A drive that covers a feature must take at least one snapshot (screen proof).
    if [[ "${value}" == drives/* ]]; then
      check_feature_sources "$f" "$name"
      if ! grep -qE 'snapshot\("' "${SKILL}/${value}"; then
        problem "${name} Drive: ${value} never calls snapshot(\"…\")"
      fi
    fi
  done
}

# Markdown destinations used by the map: inline links and reference definitions.
# Strip inline code, fragments, and optional titles before resolving paths.
markdown_links() {
  awk '/^[[:space:]]*(```|~~~)/ { fenced = !fenced; next } !fenced' "$1" \
    | sed -E 's/`[^`]*`//g' | {
      grep -oE '\]\([[:space:]]*(<[^>]+>|[^[:space:]()]+)|^ {0,3}\[[^]]+\]:[[:space:]]*(<[^>]+>|[^[:space:]]+)' || true
    } | sed -E 's/^(\]\(| {0,3}\[[^]]+\]:)[[:space:]]*//; s/^<|>$//g'
}

check_links() {
  local f link target
  for f in "${MAP}"/*.md "${SKILL}/SKILL.md"; do
    while IFS= read -r link; do
      target="${link%%#*}"
      case "$target" in
        ""|http://*|https://*|/*) continue ;;
      esac
      [[ -e "$(dirname "$f")/${target}" ]] || problem "${f} links ${link}, which does not exist"
    done < <(markdown_links "$f")
  done
}

check_index() {
  local f name link count
  local -A entries=()
  while IFS= read -r link; do
    link="${link#./}"
    if [[ "$link" != *.md || "$link" == */* || "$link" == README.md || ! -f "${MAP}/${link}" ]]; then
      problem "features/README.md has an invalid feature entry: ${link}"
      continue
    fi
    entries["$link"]=$(( ${entries["$link"]:-0} + 1 ))
  done < <(sed -nE '/^## Features$/,/^## /s/^- \[[^]]+\]\(([^)]*)\).*/\1/p' "${MAP}/README.md")
  for f in "${MAP}"/*.md; do
    name="$(basename "$f")"
    [[ "$name" == README.md ]] && continue
    count="${entries["$name"]:-0}"
    [[ "$count" == 1 ]] || problem "${name} has ${count} entries in features/README.md (want 1)"
  done
}

check_drive_coverage() {
  local drive mentions
  mentions="$(grep -rhoE --include='*.md' --exclude=README.md 'drives/[A-Za-z0-9_./-]+\.gd([^A-Za-z0-9_./-]|$)' "${MAP}" \
    | sed -E 's/\.gd.$/.gd/' | sort -u)" || true
  while IFS= read -r drive; do
    drive="${drive#"${SKILL}/"}"
    grep -qxF "$drive" <<<"$mentions" || problem "${drive} is not named by any feature page"
  done < <(find "${DRIVES}" -type f -name '*.gd' | sort)
}

check_tests() {
  local registered cited t n
  registered="$(find tests -name 'test_*.gd' -o -name run_tests.gd | sort \
    | xargs sed -n 's/^func _test_\([A-Za-z0-9_]*\)(.*/\1/p' | sort -u)"
  cited="$(cat "${MAP}"/*.md | grep -oE 'test_[A-Za-z0-9_]+(\.gd|\*)?' \
    | grep -vE '(\.gd|\*)$' | sed 's/^test_//; s/_$//' | sort -u)"
  while read -r t; do
    [[ -z "$t" ]] && continue
    grep -qxF "$t" <<<"${registered}" || problem "test_${t} is cited but no tests/ file defines _test_${t}"
  done <<<"${cited}"
  while read -r t; do
    grep -qxF "$t" <<<"${cited}" || problem "_test_${t} is not cited by any feature file"
  done <<<"${registered}"
  n="$(wc -l <<<"${registered}")"
  if [[ ${bad} -eq 0 ]]; then
    echo "check-map: OK (${n} tests, every one cited; feature index, links and drives checked)"
  fi
}

# Gameplay PR: every changed/added feature file must carry a Drive: line.
check_changed_gameplay() {
  local path name value
  [[ -n "${CHANGED_FILE}" && -f "${CHANGED_FILE}" ]] || {
    problem "--gameplay needs --changed-files pointing at an existing paths list"
    return
  }
  while read -r path; do
    [[ -z "${path}" ]] && continue
    case "${path}" in
      .cursor/skills/verify-flagoria/features/*.md) ;;
      *) continue ;;
    esac
    name="$(basename "${path}")"
    [[ "${name}" == README.md ]] && continue
    if [[ ! -f "${path}" ]]; then
      # Deleted feature file: nothing to require.
      continue
    fi
    value="$(drive_line "${path}")"
    if [[ -z "${value}" ]]; then
      problem "gameplay PR: changed feature ${name} lacks a Drive: line"
    else
      check_drive_value "${name}" "${value}"
    fi
  done < "${CHANGED_FILE}"
}

self_test() {
  local tmp failed=0
  tmp="$(mktemp -d)"
  cleanup() { rm -rf "${tmp}"; }
  trap cleanup EXIT

  local fixture="${tmp}/${SKILL}" check
  check="${fixture}/bin/check-map.sh"
  mkdir -p "${fixture}"/{bin,features,drives/nested} "${tmp}/tests"
  cp "${SKILL}/bin/check-map.sh" "$check"
  printf '%s\n' 'func _test_dummy() -> int:' > "${tmp}/tests/run_tests.gd"
  printf '%s\n' '## Features' '- [Good](./good.md)' '- [Npf](./npf.md)' > "${fixture}/features/README.md"
  printf '%s\n' 'Drive: drives/ok.gd' 'Source: flagoria_main.gd' 'See test_dummy.' \
    'Also driven by: `drives/nested/helper.gd`' > "${fixture}/features/good.md"
  printf '%s\n' 'Drive: not player-facing' '[Good](./good.md#heading)' \
    '[Anchor](#heading) and [web](https://example.com/page)' \
    '`[Example](./missing.md)`' '```md' '[Example](./missing.md)' '```' > "${fixture}/features/npf.md"
  printf '%s\n' '[Tests][runner]' '' '[runner]: <../../../tests/run_tests.gd> "Test runner"' \
    > "${fixture}/SKILL.md"
  printf '%s\n' 'await snapshot("start")' > "${fixture}/drives/ok.gd"
  touch "${fixture}/drives/nested/helper.gd"
  touch "${tmp}/flagoria_main.gd"
  env -u GH_TOKEN -u GITHUB_TOKEN git -C "${tmp}" init -q
  env -u GH_TOKEN -u GITHUB_TOKEN git -C "${tmp}" add -- flagoria_main.gd

  expect_fail() {
    local label="$1" diagnostic="$2"; shift 2
    if "$@" >"${tmp}/out" 2>&1 || ! grep -qF "$diagnostic" "${tmp}/out"; then
      echo "FAIL ${label}: expected error containing ${diagnostic}"; cat "${tmp}/out"; failed=1
    else
      echo "ok   ${label}"
    fi
  }
  expect_ok() {
    local label="$1"; shift
    if "$@" >"${tmp}/out" 2>&1; then
      echo "ok   ${label}"
    else
      echo "FAIL ${label}: expected zero"; cat "${tmp}/out"; failed=1
    fi
  }

  expect_ok "valid links, drives and test citations" "$check"
  sed -i '/^Source:/d' "${fixture}/features/good.md"
  expect_fail "missing Source line" "good.md has no Source: line" "$check"
  mkdir "${tmp}/Scripts"
  touch "${tmp}/Scripts/untracked.gd"
  printf '%s\n' 'Source: Scripts/untracked.gd' >> "${fixture}/features/good.md"
  expect_fail "untracked source" "Scripts/untracked.gd is not an existing tracked file" "$check"
  sed -i 's|^Source:.*|Source: flagoria_main.gd|' "${fixture}/features/good.md"
  printf '%s\n' '[Broken](./missing.md)' >> "${fixture}/features/npf.md"
  expect_fail "dead feature link" "features/npf.md links ./missing.md" "$check"
  sed -i '$d' "${fixture}/features/npf.md"
  printf '%s\n' '[Broken](./missing.md)' >> "${fixture}/SKILL.md"
  expect_fail "dead skill link" "SKILL.md links ./missing.md" "$check"
  sed -i '$d' "${fixture}/SKILL.md"
  touch "${fixture}/drives/nested/orphan.gd"
  expect_fail "unmentioned nested drive" "drives/nested/orphan.gd is not named" "$check"
  rm "${fixture}/drives/nested/orphan.gd"
  printf '%s\n' '- [Duplicate](./good.md)' >> "${fixture}/features/README.md"
  expect_fail "duplicate feature entry" "good.md has 2 entries" "$check"
  sed -i '$d' "${fixture}/features/README.md"
  printf '%s\n' '- [Extra](../SKILL.md)' >> "${fixture}/features/README.md"
  expect_fail "extra feature entry" "invalid feature entry: ../SKILL.md" "$check"
  sed -i '$d' "${fixture}/features/README.md"
  printf '%s\n' 'Drive: not player-facing' >> "${fixture}/features/good.md"
  expect_fail "duplicate Drive line" "good.md has more than one Drive: line" "$check"
  sed -i '$d' "${fixture}/features/good.md"
  printf '%s\n' "${SKILL}/features/good.md" > "${tmp}/changed.txt"
  sed -i '1d' "${fixture}/features/good.md"
  expect_fail "gameplay changed feature lacks Drive" "gameplay PR: changed feature good.md lacks a Drive: line" "$check" --gameplay --changed-files "${tmp}/changed.txt"
  sed -i '1iDrive: drives/nope.gd' "${fixture}/features/good.md"
  expect_fail "missing primary drive" "Drive: drives/nope.gd but" "$check"
  sed -i '1cDrive: drives/ok.gd' "${fixture}/features/good.md"
  : > "${fixture}/drives/ok.gd"
  expect_fail "primary drive lacks snapshot" "never calls snapshot" "$check"
  expect_ok "real feature map" "${SKILL}/bin/check-map.sh"

  trap - EXIT
  cleanup
  if [[ ${failed} -ne 0 ]]; then
    echo "check-map --self-test: FAILED"
    exit 1
  fi
  echo "check-map --self-test: OK"
  exit 0
}

if [[ ${SELF_TEST} -eq 1 ]]; then
  self_test
fi

check_feature_drives
check_index
check_links
check_drive_coverage
if [[ ${GAMEPLAY} -eq 1 ]]; then
  check_changed_gameplay
fi
check_tests
exit "${bad}"

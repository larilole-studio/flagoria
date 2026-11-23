#!/usr/bin/env python3
"""Check player-path drives for known game-state shortcuts."""

import argparse
import re
from collections import Counter
from pathlib import Path
from tempfile import TemporaryDirectory

ROOT = Path(__file__).resolve().parents[1]
DRIVES = ROOT / ".cursor/skills/verify-flagoria/drives"
ALLOWLIST = ROOT / "tools/drive_lint_allow.txt"
FIXTURE = "## fixture"

COMMENTS_AND_STRINGS = re.compile(r"""\#[^\n]*|"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'""")
INPUT_TYPE = r"InputEvent\w*"
ASSIGNMENT = re.compile(r"^\s*(?:var\s+)?(\w+)\s*(?::\s*(\w+)\s*)?:?=(?!=)\s*(.*)")
POSITION_WRITE = re.compile(r"\.\s*global_position(?:\.[xy])?\s*(?:[-+*/%])?=(?!=)")
SHORTCUTS = {
    "seek_phase": re.compile(r"\bseek_phase\s*\("),
    "set_cell": re.compile(r"\bset_cell\s*\("),
    "inventory write": re.compile(
        r"\b\w*inventory\s*(?:\([^()]*\))?\s*\.\s*(?:add|spend)\s*\(", re.I
    ),
    "pressed signal": re.compile(
        r"""\b(?:pressed\s*\.\s*emit\s*\(|emit_signal\s*\(\s*&?["']pressed["'])"""
    ),
}


def strip_comment_or_string(match):
    token = match[0]
    if token in ('"pressed"', "'pressed'"):
        return token
    return re.sub(r"[^\n]", " ", token)


def scan(source):
    if source.split("\n", 1)[0].rstrip("\r") == FIXTURE:
        return
    code = COMMENTS_AND_STRINGS.sub(strip_comment_or_string, source)
    input_events = set()
    for number, line in enumerate(code.splitlines(), 1):
        if line.startswith(("func ", "static func ")):
            input_events.clear()
        for rule, pattern in SHORTCUTS.items():
            for _ in pattern.finditer(line):
                yield number, rule
        for match in POSITION_WRITE.finditer(line):
            receiver = re.search(r"(?<![.\w])([A-Za-z_]\w*)\s*$", line[:match.start()])
            if receiver is None or receiver[1] not in input_events:
                yield number, "global_position write"
        assignment = ASSIGNMENT.match(line)
        if assignment:
            name, declared_type, value = assignment.groups()
            if (re.fullmatch(INPUT_TYPE, declared_type or "")
                    or re.match(rf"{INPUT_TYPE}\.new\s*\(", value)
                    or re.search(rf"\bas\s+{INPUT_TYPE}\s*$", value)
                    or value.strip() in input_events):
                input_events.add(name)
            else:
                input_events.discard(name)


def check(drives, allowlist):
    allowed = {}
    for line in allowlist.read_text().splitlines():
        if line.strip() and not line.startswith("#"):
            path, rule, count = line.split("\t")
            allowed[path, rule] = int(count)

    counts = Counter()
    errors = []
    for drive in sorted(drives.rglob("*.gd")):
        path = drive.relative_to(drives).as_posix()
        for number, rule in scan(drive.read_text()):
            key = path, rule
            counts[key] += 1
            if counts[key] > allowed.get(key, 0):
                errors.append(f"{path}:{number}: {rule} in a player-path drive")
    for (path, rule), limit in allowed.items():
        remaining = counts[path, rule]
        if remaining < limit:
            errors.append(f"{path}: shrink allowlist for {rule} from {limit} to {remaining}")
    return errors


def self_test():
    with TemporaryDirectory() as tmp:
        root = Path(tmp)
        drive = root / "bad.gd"
        allowlist = root / "allow.txt"
        allowlist.write_text("")
        bad = """func run():
    clock.seek_phase("night")
    hero().global_position += offset
    map.set_cell(0, cell, 1)
    hero().inventory.add(wood)
    inventory.spend(wood, 1)
    button.pressed.emit()
    button.emit_signal(&"pressed")
"""
        drive.write_text(bad)
        errors = check(root, allowlist)
        assert len(errors) == 7, errors
        drive.write_text(FIXTURE + "\n" + bad)
        assert not check(root, allowlist)
        drive.write_text("""func run():
    var e := InputEventMouseButton.new()
    e.pressed = true
    e.global_position = at
    var copy := e.duplicate() as InputEventMouseButton
    copy.global_position = at
    click("button") # button.pressed.emit()
    print("clock.seek_phase()")
""")
        assert not check(root, allowlist)
        drive.write_text("hero().global_position = at\n")
        entry = "bad.gd\tglobal_position write\t1\n"
        allowlist.write_text(entry)
        assert not check(root, allowlist)
        drive.write_text("")
        assert check(root, allowlist) == [
            "bad.gd: shrink allowlist for global_position write from 1 to 0"
        ]
        assert allowlist.read_text() == entry
        allowlist.write_text("")
        assert not check(root, allowlist)
    print("Drive lint self-test: mutation rejected, fixture and input accepted, stale allowance rejected")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--drives", type=Path, default=DRIVES)
    parser.add_argument("--allowlist", type=Path, default=ALLOWLIST)
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not args.drives.is_dir():
        parser.error(f"drive directory does not exist: {args.drives}")
    errors = check(args.drives, args.allowlist)
    if errors:
        parser.exit(1, "\n".join(errors) + "\n")
    print("Drive lint: ok")


if __name__ == "__main__":
    main()

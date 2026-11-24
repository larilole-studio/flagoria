#!/usr/bin/env python3
"""Run the pinned gdlint and compare its diagnostics with the tracked baseline."""

from collections import Counter
from hashlib import sha256
from pathlib import Path
import re
import subprocess
import sys

BASELINE = Path(__file__).with_name("gdlint_allow.txt")
DIAGNOSTIC = re.compile(r"(.+\.gd):(\d+): (?:Error|Warning): (.+) \(([\w-]+)\)")
SUMMARY = re.compile(r"Failure: (\d+) problems? found")
GENERIC_RULES = {"class-definitions-order", "max-line-length"}


def finding_key(match, source_lines):
    filename, number, message, rule = match.groups()
    path = Path(filename)
    key = f"{path.as_posix()}\t{rule}\t{message}"
    if rule in GENERIC_RULES:
        if path not in source_lines:
            source_lines[path] = path.read_text(encoding="utf-8").splitlines()
        source = source_lines[path][int(number) - 1].strip()
        key += f"\t{sha256(source.encode()).hexdigest()[:16]}"
    return key


def main():
    lint = subprocess.run(sys.argv[1:], capture_output=True, text=True)
    allowed = Counter(
        entry for entry in BASELINE.read_text(encoding="utf-8").splitlines()
        if entry and not entry.startswith("#")
    )
    seen = Counter()
    source_lines = {}
    failed = False
    reported_total = 0
    for line in lint.stderr.splitlines():
        match = DIAGNOSTIC.fullmatch(line)
        if match is None:
            summary = SUMMARY.fullmatch(line)
            if summary:
                reported_total = int(summary[1])
            elif line:
                print(line, file=sys.stderr)
                failed = True
            continue
        key = finding_key(match, source_lines)
        seen[key] += 1
        if seen[key] > allowed[key]:
            print(line, file=sys.stderr)
            failed = True

    count = sum(seen.values())
    if lint.returncode != int(bool(count)) or reported_total != count or (
        lint.stdout.strip() != ("Success: no problems found" if not count else "")
    ):
        print(lint.stdout, end="", file=sys.stderr)
        print(f"error: unexpected gdlint result (exit {lint.returncode})", file=sys.stderr)
        failed = True
    for key, unused in sorted((allowed - seen).items()):
        print(f"error: unused gdlint baseline rows ({unused}): {key}", file=sys.stderr)
        failed = True
    if not failed:
        print(f"GDScript lint: ok ({count} existing findings)")
    return int(failed)


if __name__ == "__main__":
    sys.exit(main())

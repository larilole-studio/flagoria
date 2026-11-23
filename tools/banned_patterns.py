#!/usr/bin/env python3
"""Check source files and paths for banned patterns."""

import argparse
import os
import re
import subprocess
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURES = Path("tools/testdata/banned_patterns")
IGNORED = {".git", ".godot", ".cursor", "addons", "artifacts"}
TEXT_SUFFIXES = {".gd", ".py", ".sh", ".md"}
MAP_SCRIPTS = {
    Path("Scripts/world") / f"{name}.gd"
    for name in (
        "map_gen", "terrain_shape", "spawn_finder", "sky_islands", "world_chunks",
        "start_castle", "world_map_params", "birch_trees", "plant_picker",
        "object_removals",
    )
}
SMALL_LITERALS = {"0", "1", "-1", "2", "0.0", "1.0", "-1.0"}
COMMENTS_AND_STRINGS = re.compile(
    r"\#[^\n]*|(\x22{3}|\x27{3}|\x22|\x27)(?:\\[\s\S]|(?!\1)[^\\])*\1"
)
DEBUG = re.compile(r"(?<!\w)(?:print|push_warning)[ \t]*\(")
NUMBER = re.compile(
    r"(?<![\w.])-?(?:0[xX][\da-fA-F_]+|0[bB][01_]+"
    r"|(?:\d[\d_]*(?:\.(?!\.)[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?[\d_]+)?)(?!\w)"
)
ISSUE = re.compile(r"(?<![\w#])#[1-9]\d*\b|\bhttps://github\.com/[\w.-]+/[\w.-]+/issues/[1-9]\d*\b")
MARKERS = {
    "unlinked task": re.compile(r"\b(?:TODO|FIXME|HACK)\b"),  # #8
    "unlinked hotfix": re.compile(r"\b(?:HOTFIX|TEMP[ \t]+FIX|(?i:do[ \t]+not[ \t]+remove))\b"),  # #8
}


def code_lines(source):
    return COMMENTS_AND_STRINGS.sub(lambda m: re.sub(r"[^\n]", " ", m[0]), source).split("\n")


def load_allowlist(name):
    entries = Counter()
    for line in (ROOT / "tools" / name).read_text(encoding="utf-8").splitlines():
        if line and not line.startswith("#"):
            path, entry = line.split("\t", 1)
            value, count = entry.rsplit("\t", 1)
            entries[Path(path), value] = int(count)
    return entries


def repo_paths():
    # Include new, non-ignored files so local verification works before staging.
    output = subprocess.check_output(
        ["git", "ls-files", "-z", "--cached", "--others", "--exclude-standard"], cwd=ROOT
    )
    return {Path(os.fsdecode(path)) for path in output.split(b"\0") if path}


def scan(root, paths, debug_allow, literal_allow, *, fixture=False):
    debug_counts = Counter()
    literal_counts = Counter()
    scripts_by_name = {}
    scratch_paths = set()

    for disk_path in sorted(paths):
        if disk_path.parts[0] in IGNORED or FIXTURES in disk_path.parents:
            continue
        file = root / disk_path
        if not file.is_file() or file.is_symlink():
            continue
        # Keep GDScript fixtures invisible to Godot and the all-script parse step.
        path = disk_path.with_suffix("") if fixture and disk_path.suffix == ".fixture" else disk_path
        in_scripts = path.parts[0] == "Scripts"
        candidates = (*reversed(path.parents), path) if in_scripts else (Path(path.parts[0]),)
        for part_path in candidates:
            name = part_path.name
            if (name in {".agent", ".session-scratch", "scratch.py"}
                    or name.startswith("tmp_agent_")) and part_path not in scratch_paths:
                scratch_paths.add(part_path)
                yield "scratch path", part_path, 0, "remove the scratch path"

        if in_scripts and path.suffix == ".gd":
            previous = scripts_by_name.setdefault(path.name, path)
            if previous != path:
                yield "duplicate module", path, 0, f"same basename as {previous}"

        if path.suffix not in TEXT_SUFFIXES:
            continue
        source = file.read_text(encoding="utf-8")
        lines = source.split("\n")
        for number, line in enumerate(lines, 1):
            if not ISSUE.search(line):
                for rule, pattern in MARKERS.items():
                    if match := pattern.search(line):
                        yield rule, path, number, f"{match[0]} needs an issue reference"

        if path.suffix != ".gd" or not (in_scripts or path == Path("flagoria_main.gd")):
            continue
        for number, code in enumerate(code_lines(source), 1):
            for match in DEBUG.finditer(code):
                key = path, lines[number - 1]
                debug_counts[key] += 1
                if debug_counts[key] > debug_allow[key]:
                    yield "debug call", path, number, f"unexpected {match[0]}"
            if path in MAP_SCRIPTS:
                for match in NUMBER.finditer(code):
                    value = match[0]
                    if value in SMALL_LITERALS:
                        continue
                    key = path, value
                    literal_counts[key] += 1
                    if literal_counts[key] > literal_allow[key]:
                        yield "map literal", path, number, f"unexpected numeric literal {value}"


def report(violations):
    for rule, path, number, detail in violations:
        location = f"{path}:{number}" if number else str(path)
        print(f"{location}: {rule}: {detail}")


def tree_paths(root):
    return {path.relative_to(root) for path in root.rglob("*") if path.is_file()}


def self_test():
    passed = True
    rules = ("debug call", "map literal", "scratch path", "duplicate module", *MARKERS)
    for name in (*rules, "clean"):
        root = ROOT / FIXTURES / name.replace(" ", "_")
        paths = tree_paths(root)
        violations = list(scan(root, paths, Counter(), Counter(), fixture=True))
        expected = [] if name == "clean" else [name]
        if paths and [rule for rule, *_ in violations] == expected:
            print("Clean fixture passed" if name == "clean" else f"Fixture fired: {name}")
        else:
            print(f"Unexpected result for {name} fixture")
            report(violations)
            passed = False
    return passed


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--root", type=Path, help="scan a standalone tree without repository allowances")
    args = parser.parse_args()
    if args.self_test:
        return 0 if self_test() else 1

    if args.root is None:
        violations = list(scan(ROOT, repo_paths(), load_allowlist("banned_print_allow.txt"),
                               load_allowlist("map_gen_literal_allow.txt")))
    else:
        if not args.root.is_dir():
            parser.error(f"directory does not exist: {args.root}")
        fixture = ROOT / FIXTURES in args.root.resolve().parents
        violations = list(scan(args.root, tree_paths(args.root), Counter(), Counter(), fixture=fixture))
    if violations:
        report(violations)
        return 1
    print("Banned patterns: ok")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

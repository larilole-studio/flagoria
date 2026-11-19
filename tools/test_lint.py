#!/usr/bin/env python3
"""Static lint for the headless test registry and private test access.

Mirrors discovery in tests/run_tests.gd so mistakes (duplicate `_test_*` names,
misnamed `test_*` functions, wrong signatures) fail before Godot runs the suite.

Run: python3 tools/test_lint.py [--root DIR]
Self-test: python3 tools/test_lint.py --self-test
"""
from __future__ import annotations

import argparse
import re
import sys
import tempfile
from pathlib import Path

RUNNER = "tests/run_tests.gd"
REGISTERED_RE = re.compile(r"(?m)^func (_test_[a-z0-9_]+)\(\)")
LOOSE_RE = re.compile(
    r"(?mi)^([ \t]*)(static[ \t]+)?func[ \t]+(_?test_\w*)[ \t]*\(([^)]*)\)"
)
EXACT_RE = re.compile(r"^func _test_[a-z0-9_]+\(\)$")
PRIVATE_BASELINE = "tools/test_private_access_baseline.txt"
WRITE_PRIVATE_BASELINE = "python3 tools/test_lint.py --write-private-baseline"
PRIVATE_RE = re.compile(r"\bself\._[a-z]\w*|[\w)\]]\._[a-z]\w*")
COMMENTS_AND_STRINGS_RE = re.compile(
    r"""\#[^\n]*|(?P<quote>'''|\x22{3}|'|")(?:\\.|(?!(?P=quote))[^\\])*(?P=quote)""",
    re.DOTALL,
)


def private_access_lines(source: str) -> list[int]:
    code = COMMENTS_AND_STRINGS_RE.sub(lambda m: "\n" * m[0].count("\n") + " ", source)
    return [
        number
        for number, line in enumerate(code.splitlines(), 1)
        if any(not m[0].startswith("self.") for m in PRIVATE_RE.finditer(line))
    ]


def check_private_access(root: Path, *, write: bool = False, allow_increase: bool = False) -> list[str]:
    """Per-file private access counts must equal the baseline: a rise fails, and a
    drop fails until the baseline is rewritten, so the frozen count only goes down."""
    baseline_path = root / PRIVATE_BASELINE
    baseline: dict[str, int] = {}
    if baseline_path.is_file():
        for line in baseline_path.read_text(encoding="utf-8").splitlines():
            if line.strip() and not line.lstrip().startswith("#"):
                count, rel = line.split(maxsplit=1)
                baseline[rel] = int(count)
    current: dict[str, list[int]] = {}
    for path in sorted((root / "tests").rglob("*.gd")):
        rel = path.relative_to(root).as_posix()
        if rel != RUNNER:
            lines = private_access_lines(path.read_text(encoding="utf-8", errors="replace"))
            if lines:
                current[rel] = lines
    errors: list[str] = []
    for rel in sorted(current.keys() | baseline.keys()):
        lines, limit = current.get(rel, []), baseline.get(rel, 0)
        if len(lines) > limit and not (write and allow_increase):
            excess = ", ".join(map(str, lines[limit:limit + 5]))
            errors.append(f"{rel}: {len(lines)} private access lines (baseline {limit}); excess at lines {excess}")
        elif len(lines) < limit and not write:
            errors.append(f"{rel}: private access dropped from {limit} to {len(lines)}; lock it in with {WRITE_PRIVATE_BASELINE}")
    if write and not errors:
        baseline_path.write_text(
            f"# Private access counts can only go down. Regenerate with {WRITE_PRIVATE_BASELINE}.\n"
            + "".join(f"{len(current[rel])} {rel}\n" for rel in sorted(current)),
            encoding="utf-8",
        )
    return errors


def test_paths(root: Path) -> list[Path]:
    tests = root / "tests"
    paths = sorted(tests.rglob("test_*.gd"), key=lambda p: p.relative_to(tests).as_posix())
    runner = root / RUNNER
    if runner.is_file():
        paths.append(runner)
    paths.sort(key=lambda p: p.relative_to(root).as_posix())
    return paths


def line_number(source: str, index: int) -> int:
    return source.count("\n", 0, index) + 1


def lint_source(rel: str, source: str) -> list[str]:
    """Diagnostics for loose or mis-registered test-like functions in one file."""
    found: list[str] = []
    errors: list[str] = []
    for m in REGISTERED_RE.finditer(source):
        found.append(m.group(1))
    for m in LOOSE_RE.finditer(source):
        if EXACT_RE.match(m.group(0)):
            continue
        test_name = m.group(3)
        reasons: list[str] = []
        if m.group(1):
            reasons.append("it is indented; tests must be top-level")
        if m.group(2):
            reasons.append("it is static; drop `static`")
        if not test_name.lower().startswith("_test_"):
            reasons.append("the name must start with `_test_`")
        if test_name != test_name.lower():
            reasons.append("the name has uppercase letters; use lowercase")
        if m.group(4).strip():
            reasons.append("it takes parameters; tests take none")
        if not reasons:
            reasons.append("write it exactly as `func _test_<lowercase_name>()`")
        if test_name in found:
            reasons.append(f"the top-level {test_name} is the one that runs")
        line = line_number(source, m.start())
        errors.append(f"{rel}:{line}: {test_name}: {'; '.join(reasons)}")
    return errors


def lint(root: Path) -> list[str]:
    errors = check_private_access(root)
    by_name: dict[str, list[tuple[str, int]]] = {}
    for path in test_paths(root):
        rel = path.relative_to(root).as_posix()
        source = path.read_text(encoding="utf-8", errors="replace")
        errors.extend(lint_source(rel, source))
        for m in REGISTERED_RE.finditer(source):
            by_name.setdefault(m.group(1), []).append((rel, line_number(source, m.start())))
    for name, sites in by_name.items():
        if len(sites) < 2:
            continue
        short = name.removeprefix("_test_")
        for rel, line in sites:
            others = ", ".join(f"{r}:{ln}" for r, ln in sites if (r, ln) != (rel, line))
            errors.append(f"{rel}:{line}: duplicate test name {short} (also {others})")
    return errors


def self_test() -> int:
    fail = 0
    cases = [
        (
            {
                "tests/run_tests.gd": "extends SceneTree\n",
                "tests/x/test_a.gd": "func _test_dup() -> int:\nfunc _test_dup() -> int:\n",
            },
            ["duplicate test name dup"],
        ),
        (
            {
                "tests/run_tests.gd": "",
                "tests/x/test_a.gd": "func _test_one() -> int:\n",
                "tests/y/test_b.gd": "func _test_one() -> int:\n",
            },
            ["duplicate test name one"],
        ),
        (
            {"tests/run_tests.gd": "", "tests/x/test_a.gd": "func test_loose() -> int:\n"},
            ["test_loose", "the name must start with `_test_`"],
        ),
        (
            {"tests/run_tests.gd": "", "tests/x/test_a.gd": "func _test_args(x: int) -> int:\n"},
            ["_test_args", "it takes parameters"],
        ),
    ]
    for i, (files, needles) in enumerate(cases, 1):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            for rel, body in files.items():
                p = root / rel
                p.parent.mkdir(parents=True, exist_ok=True)
                p.write_text(body)
            got = lint(root)
            for needle in needles:
                if not any(needle in line for line in got):
                    fail += 1
                    print(f"case {i}: want {needle!r} in {got}")
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        probe = root / "tests" / "probe.gd"
        probe.parent.mkdir()
        probe.write_text('self._x\n# obj._x\n"obj._x"\n\'obj._x\'\n')
        try:
            assert not lint(root), "self access, comments, and strings must be ignored"
            probe.write_text("obj._x\n")
            assert any("baseline 0" in error for error in lint(root)), "new file must fail"
            baseline = root / PRIVATE_BASELINE
            baseline.parent.mkdir()
            baseline.write_text("1 tests/probe.gd\n")
            probe.write_text("obj._x\nobj._y\n")
            assert any("baseline 1" in error and "lines 2" in error for error in lint(root)), "increase must fail"
            assert check_private_access(root, write=True), "writing an increase must fail"
            probe.write_text("self._x\n")
            assert any("dropped from 1 to 0" in e and WRITE_PRIVATE_BASELINE in e for e in lint(root)), "an unrecorded drop must fail"
            assert not check_private_access(root, write=True) and not lint(root), "a recorded drop must pass"
        except AssertionError as error:
            print(f"private access ratchet self-test failed: {error}")
            return 1
    print(f"test_lint self-test: {len(cases) - fail}/{len(cases)} cases ok" if fail else "test_lint self-test: ok")
    return 1 if fail else 0


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--root", default=str(Path(__file__).resolve().parent.parent))
    ap.add_argument("--self-test", action="store_true")
    ap.add_argument("--write-private-baseline", action="store_true")
    ap.add_argument("--allow-increase", action="store_true")
    args = ap.parse_args(argv)
    if args.self_test:
        return self_test()
    root = Path(args.root)
    if args.allow_increase and not args.write_private_baseline:
        ap.error("--allow-increase requires --write-private-baseline")
    if args.write_private_baseline:
        errors = check_private_access(root, write=True, allow_increase=args.allow_increase)
    else:
        errors = lint(root)
    for e in errors:
        print(f"error: {e}", file=sys.stderr)
    if errors:
        print(f"Test registry lint: {len(errors)} problem(s)", file=sys.stderr)
        return 1
    if args.write_private_baseline:
        print(f"Wrote {PRIVATE_BASELINE}")
        return 0
    n_files = len(test_paths(root))
    print(f"Test registry lint: ok ({n_files} files)")
    return 0


if __name__ == "__main__":
    sys.exit(main())

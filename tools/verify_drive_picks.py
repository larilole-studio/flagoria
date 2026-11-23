#!/usr/bin/env python3
"""Pick gameplay drives for verify-drive.yml (Gameplay drives job).

On pull_request, after tools/play_review_paths.py marks gameplay, read changed
paths and collect top-level Drive: entries from changed feature pages and pages
whose Source: entries exactly match changed gameplay paths. Skip README and
nested drives, including drives/two_player/*. Report gameplay source paths with
no auto-selectable drive. If nothing is collected, fall back to smoke.

Writes drives=<space-separated names> and optional reason= to $GITHUB_OUTPUT
when set. Does not set gameplay=; play_review_paths does that on PRs.

  python3 tools/verify_drive_picks.py --files paths.txt --gameplay true
  python3 tools/verify_drive_picks.py --dispatch-drives "wait smoke"

Self-test: python3 tools/verify_drive_picks.py --self-test
"""
from __future__ import annotations

import argparse
import os
import re
import sys
import tempfile
from pathlib import Path

DEFAULT_SMOKE = "smoke"
FEATURE_PREFIX = ".cursor/skills/verify-flagoria/features/"
DRIVE_LINE = re.compile(r"^Drive:[ \t]+drives/(_*[^\W_]\w*)\.gd[ \t]*$", re.MULTILINE)
SOURCE_LINE = re.compile(
    r"^Source:[ \t]+(Scripts/[^\s]+\.gd|flagoria_main\.gd)[ \t]*$", re.MULTILINE
)


def feature_pages(root: Path) -> list[Path]:
    return sorted((root / FEATURE_PREFIX).glob("*.md"))


def collect_from_paths(paths: list[str], root: Path) -> tuple[list[str], list[str]]:
    changed = dict.fromkeys(root / path for path in paths if path.startswith(FEATURE_PREFIX))
    gameplay_paths = {
        path for path in paths if path.startswith("Scripts/") or path == "flagoria_main.gd"
    }
    matched: set[str] = set()
    names: list[str] = []
    candidates = dict.fromkeys([*changed, *feature_pages(root)])
    for page in candidates:
        if page.name == "README.md" or page.suffix != ".md" or not page.is_file():
            continue
        text = page.read_text(encoding="utf-8", errors="replace")
        drive = DRIVE_LINE.search(text)
        if not drive:
            continue
        sources = gameplay_paths.intersection(SOURCE_LINE.findall(text))
        if page in changed or sources:
            names.append(drive[1])
            matched.update(sources)
    return dedupe(names), sorted(gameplay_paths - matched)


def selection_reason(gameplay: bool, names: list[str], unmatched: list[str]) -> str:
    if not gameplay:
        return "not gameplay"
    reason = "selected feature drives" if names else "default smoke fallback"
    if unmatched:
        reason += " (unmatched gameplay source paths: %s)" % ", ".join(unmatched)
    return reason


def dedupe(names: list[str]) -> list[str]:
    seen: set[str] = set()
    out: list[str] = []
    for n in names:
        if not n or n in seen:
            continue
        seen.add(n)
        out.append(n)
    return out


def finalize(gameplay: bool, names: list[str], *, dispatch: bool) -> list[str]:
    names = dedupe(names)
    if dispatch:
        return names if names else [DEFAULT_SMOKE]
    if not gameplay:
        return []
    if names:
        return names
    return [DEFAULT_SMOKE]


def write_output(drives: list[str], reason: str) -> None:
    joined = " ".join(drives)
    print("Selected drives: '%s'" % joined)
    if reason:
        print("Reason: %s" % reason)
    out = os.environ.get("GITHUB_OUTPUT")
    if out:
        with open(out, "a", encoding="utf-8") as fh:
            fh.write("drives=%s\nreason=%s\n" % (joined, reason))


def self_test() -> int:
    root = Path(__file__).resolve().parent.parent
    fail = cases = 0

    def check(label: str, got: object, want: object) -> None:
        nonlocal fail, cases
        cases += 1
        if got != want:
            fail += 1
            print("FAIL %s: got %r, want %r" % (label, got, want), file=sys.stderr)

    player = "Scripts/player/player.gd"
    chop = "Scripts/mechanics/trees/chop_action.gd"
    two = "Scripts/net/join_dial.gd"
    nested = "flagoria_main.gd"
    unowned = "Scripts/world/map_gen.gd"
    fixtures = {
        "chop": f"Drive: drives/chop_trees.gd\nSource: {chop}\n",
        "combat": f"Drive: drives/combat_hud.gd\nSource: {player}\nSee `{unowned}`.\n",
        "two-player": f"Drive: drives/two_player/two_player_host.gd\nSource: {two}\n",
        "nested": f"Drive: drives/dedicated_play/play_server.gd\nSource: {nested}\n",
        "npf": "Drive: not player-facing\n",
        "nodrive": "No drive here\n",
        "README": f"Drive: drives/wait.gd\nSource: {player}\n",
    }
    with tempfile.TemporaryDirectory() as td:
        tmproot = Path(td)
        for name, body in fixtures.items():
            page = tmproot / FEATURE_PREFIX / f"{name}.md"
            page.parent.mkdir(parents=True, exist_ok=True)
            page.write_text(body, encoding="utf-8")

        def pick(paths: list[str]) -> list[str]:
            names, _ = collect_from_paths(paths, tmproot)
            return finalize(True, names, dispatch=False)

        chop_page = FEATURE_PREFIX + "chop.md"
        check("source only", pick([player]), ["combat_hud"])
        check("feature drive", pick([chop_page]), ["chop_trees"])
        check("skip two_player", pick([FEATURE_PREFIX + "two-player.md", two]), [DEFAULT_SMOKE])
        check("skip nested", pick([FEATURE_PREFIX + "nested.md", nested]), [DEFAULT_SMOKE])
        check("not player-facing", pick([FEATURE_PREFIX + "npf.md"]), [DEFAULT_SMOKE])
        check("missing Drive line", pick([FEATURE_PREFIX + "nodrive.md"]), [DEFAULT_SMOKE])
        check("skip README", pick([FEATURE_PREFIX + "README.md", player]), ["combat_hud"])
        check("markdown and source", pick([chop_page, player]), ["chop_trees", "combat_hud"])
        check("dedupe", pick([chop_page, chop_page, chop]), ["chop_trees"])

        names, unmatched = collect_from_paths([unowned], tmproot)
        check("unowned source fallback", finalize(True, names, dispatch=False), [DEFAULT_SMOKE])
        check(
            "fallback reason", selection_reason(True, names, unmatched),
            f"default smoke fallback (unmatched gameplay source paths: {unowned})",
        )
        names, unmatched = collect_from_paths([player, nested], tmproot)
        check(
            "selection reason", selection_reason(True, names, unmatched),
            f"selected feature drives (unmatched gameplay source paths: {nested})",
        )

    check("non-gameplay", finalize(False, ["combat_hud"], dispatch=False), [])
    check("dispatch empty", finalize(True, [], dispatch=True), [DEFAULT_SMOKE])
    check("dispatch named", finalize(True, ["wait", "smoke", "wait"], dispatch=True), ["wait", "smoke"])

    expected = {"combat_hud", "ranged_bow"}
    for page in feature_pages(root):
        if page.name == "README.md":
            continue
        text = page.read_text(encoding="utf-8")
        drive = DRIVE_LINE.search(text)
        if drive and player in SOURCE_LINE.findall(text):
            expected.add(drive[1])
    names, _ = collect_from_paths([player], root)
    selected = set(finalize(True, names, dispatch=False))
    check("real player source missing drives", sorted(expected - selected), [])
    check("real player source skips smoke", DEFAULT_SMOKE in selected, False)
    smoke = (root / FEATURE_PREFIX).parent / "drives/smoke.gd"
    check("smoke drive exists", smoke.is_file(), True)

    print("verify_drive_picks self-test: %d/%d ok" % (cases - fail, cases))
    return 1 if fail else 0


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("--files", help="changed paths, one per line (default: stdin)")
    ap.add_argument("--gameplay", choices=["true", "false"], help="pull_request gameplay flag")
    ap.add_argument(
        "--dispatch-drives",
        help="workflow_dispatch drive names (space-separated; empty uses default smoke)",
    )
    ap.add_argument("--self-test", action="store_true")
    args = ap.parse_args()
    if args.self_test:
        return self_test()

    root = Path(__file__).resolve().parent.parent
    if args.dispatch_drives is not None:
        raw = [p for p in args.dispatch_drives.split() if p]
        drives = finalize(True, raw, dispatch=True)
        write_output(drives, "workflow_dispatch")
        return 0

    text = ""
    if args.files:
        text = Path(args.files).read_text(encoding="utf-8", errors="replace")
    else:
        text = sys.stdin.read()
    paths = [p.strip() for p in text.splitlines() if p.strip()]
    gameplay = args.gameplay == "true"
    collected, unmatched = collect_from_paths(paths, root) if gameplay else ([], [])
    drives = finalize(gameplay, collected, dispatch=False)
    write_output(drives, selection_reason(gameplay, collected, unmatched))
    return 0


if __name__ == "__main__":
    sys.exit(main())

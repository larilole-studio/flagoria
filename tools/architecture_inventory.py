#!/usr/bin/env python3
"""Generate and verify the tracked production script inventory."""
import argparse
from collections import defaultdict
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
DOC = ROOT / "docs/architecture.md"
START = "<!-- BEGIN GENERATED SCRIPT INVENTORY -->"
END = "<!-- END GENERATED SCRIPT INVENTORY -->"
DOMAINS = ("audio", "mechanics", "net", "player", "saves", "shell", "ui", "world")


def render_inventory():
    paths = subprocess.check_output(
        ["git", "ls-files", "-z", "--", "Scripts/", "flagoria_main.gd", "TouchScreenButton.gd"],
        cwd=ROOT,
    ).decode("utf-8").split("\0")
    groups = defaultdict(lambda: defaultdict(list))
    for path in sorted(set(paths)):
        if not path.endswith(".gd"):
            continue
        parts = path.split("/")
        domain = parts[1] if len(parts) >= 3 and parts[1] in DOMAINS else "Root and other"
        subfolder = parts[2] if domain == "mechanics" and len(parts) >= 4 else ""
        groups[domain][subfolder].append(f"- `{path}`")

    sections = []
    for domain in (*DOMAINS, "Root and other"):
        if domain not in groups:
            continue
        heading = f"`Scripts/{domain}/`" if domain in DOMAINS else domain
        sections.append(f"### {heading}")
        for subfolder, entries in sorted(groups[domain].items()):
            if subfolder:
                sections.append(f"#### `{subfolder}/`")
            sections.append("\n".join(entries))
    return "\n\n" + "\n\n".join(sections) + "\n\n"


def updated_document(document, inventory):
    if document.count(START) != 1 or document.count(END) != 1:
        raise ValueError("Expected exactly one pair of script inventory markers.")
    before, _, rest = document.partition(START)
    _, end, after = rest.partition(END)
    if not end:
        raise ValueError("Script inventory markers are out of order.")
    return before + START + inventory + END + after


def self_test(document, inventory):
    current = updated_document(document, inventory)
    entry = next(line for line in inventory.splitlines(keepends=True) if line.startswith("- "))
    missing = current.replace(START + inventory, START + inventory.replace(entry, "", 1))
    leftover = current.replace(END, "- `Scripts/leftover.gd`\n\n" + END)
    for label, stale in (("missing path", missing), ("leftover path", leftover)):
        if stale == updated_document(stale, inventory):
            raise ValueError(f"Self-test failed to detect a {label}.")
    print("Architecture inventory self-test rejected a missing and a leftover path.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group(required=True)
    modes.add_argument("--check", action="store_true")
    modes.add_argument("--write", action="store_true")
    modes.add_argument("--self-test", action="store_true")
    args = parser.parse_args()

    document = DOC.read_text(encoding="utf-8")
    inventory = render_inventory()
    try:
        updated = updated_document(document, inventory)
        if args.self_test:
            self_test(document, inventory)
    except ValueError as error:
        parser.exit(1, f"{error}\n")

    if args.write:
        if document != updated:
            DOC.write_text(updated, encoding="utf-8")
    elif document != updated:
        parser.exit(1, "Architecture inventory is stale. Run python3 tools/architecture_inventory.py --write.\n")
    print("Architecture inventory matches the tracked production scripts.")


if __name__ == "__main__":
    main()

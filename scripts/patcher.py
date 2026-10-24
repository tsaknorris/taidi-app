#!/usr/bin/env python3
"""
Lightweight Unified Diff Patcher for Sailfish OS.
Applies or reverts standard unified diffs without requiring GNU patch.
"""

import sys
import os
import re
from pathlib import Path


def parse_patch(patch_text):
    """
    Parses a unified diff into file patches and hunks.
    Returns: list of (orig_file, new_file, [hunks])
    Each hunk is: (old_start, old_count, new_start, new_count, [lines])
    """
    files = []
    current_file = None
    current_hunk = None

    for line in patch_text.splitlines():
        if line.startswith("--- "):
            orig_name = line[4:].split("\t")[0].strip()
            # Clean standard a/ or b/ prefixes
            if orig_name.startswith("a/"):
                orig_name = orig_name[2:]
            current_file = {"orig": orig_name, "new": None, "hunks": []}
            files.append(current_file)
            current_hunk = None
        elif line.startswith("+++ "):
            new_name = line[4:].split("\t")[0].strip()
            if new_name.startswith("b/"):
                new_name = new_name[2:]
            if current_file:
                current_file["new"] = new_name
        elif line.startswith("@@ "):
            m = re.match(r"^@@\s+-(\d+)(?:,(\d+))?\s+\+(\d+)(?:,(\d+))?\s+@@", line)
            if not m:
                continue
            old_start = int(m.group(1))
            old_count = int(m.group(2)) if m.group(2) is not None else 1
            new_start = int(m.group(3))
            new_count = int(m.group(4)) if m.group(4) is not None else 1
            current_hunk = {
                "old_start": old_start,
                "old_count": old_count,
                "new_start": new_start,
                "new_count": new_count,
                "lines": []
            }
            if current_file:
                current_file["hunks"].append(current_hunk)
        elif current_hunk is not None:
            if line.startswith(("+", "-", " ", "\\")):
                current_hunk["lines"].append(line)

    return files


def apply_hunks(target_lines, hunks, revert=False):
    """
    Applies hunks to target_lines (list of strings without trailing newline).
    Returns (success: bool, new_lines: list, error_msg: str).
    """
    lines = list(target_lines)

    for h_idx, hunk in enumerate(hunks):
        hunk_lines = hunk["lines"]
        expected_chunk = []
        replacement_chunk = []

        for hl in hunk_lines:
            op = hl[0]
            content = hl[1:]
            if op == "\\":
                continue
            if not revert:
                if op in (" ", "-"):
                    expected_chunk.append(content)
                if op in (" ", "+"):
                    replacement_chunk.append(content)
            else:
                if op in (" ", "+"):
                    expected_chunk.append(content)
                if op in (" ", "-"):
                    replacement_chunk.append(content)

        # Expected starting index (0-based)
        preferred_idx = (hunk["new_start"] if revert else hunk["old_start"]) - 1
        preferred_idx = max(0, min(preferred_idx, len(lines)))

        # Find match location, starting near preferred_idx with expanding search
        match_idx = -1
        max_fuzz = len(lines)
        for offset in range(max_fuzz + 1):
            for candidate in (preferred_idx + offset, preferred_idx - offset):
                if 0 <= candidate <= len(lines) - len(expected_chunk):
                    if lines[candidate : candidate + len(expected_chunk)] == expected_chunk:
                        match_idx = candidate
                        break
            if match_idx != -1:
                break

        if match_idx == -1:
            first_line = expected_chunk[0] if expected_chunk else ""
            return False, lines, f"Hunk #{h_idx + 1} failed to match near line {preferred_idx + 1}. Looking for: {first_line[:40]}..."

        lines[match_idx : match_idx + len(expected_chunk)] = replacement_chunk

    return True, lines, ""


def patch_file(target_path, patch_path, revert=False, dry_run=False):
    target = Path(target_path)
    patch = Path(patch_path)

    if not target.exists():
        return False, f"Target file does not exist: {target}"
    if not patch.exists():
        return False, f"Patch file does not exist: {patch}"

    patch_text = patch.read_text(encoding="utf-8")
    files = parse_patch(patch_text)
    if not files:
        return False, f"No valid hunks found in patch file: {patch}"

    target_text = target.read_text(encoding="utf-8")
    target_lines = target_text.splitlines()

    # Collect all hunks
    all_hunks = []
    for f in files:
        all_hunks.extend(f["hunks"])

    success, new_lines, err = apply_hunks(target_lines, all_hunks, revert=revert)
    if not success:
        return False, err

    if not dry_run:
        tmp_file = target.with_suffix(target.suffix + ".taidi_tmp")
        final_text = "\n".join(new_lines) + ("\n" if target_text.endswith("\n") else "")
        tmp_file.write_text(final_text, encoding="utf-8")
        os.replace(tmp_file, target)

    return True, "OK"


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Pure Python unified diff patcher")
    parser.add_argument("target", help="Target file to patch")
    parser.add_argument("patch", help="Unified diff (.patch) file")
    parser.add_argument("-R", "--revert", action="store_true", help="Revert the patch")
    parser.add_argument("--dry-run", action="store_true", help="Test without modifying file")

    args = parser.parse_args()
    success, msg = patch_file(args.target, args.patch, revert=args.revert, dry_run=args.dry_run)

    if success:
        action = "Revert" if args.revert else "Patch"
        mode = " [dry-run]" if args.dry_run else ""
        print(f"{action} successful{mode}: {args.target}")
        sys.exit(0)
    else:
        print(f"Error: {msg}", file=sys.stderr)
        sys.exit(1)


if __name__ == "__main__":
    main()

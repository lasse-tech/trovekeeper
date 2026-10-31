#!/usr/bin/env python3
"""Check a TOC against the source tree, in both directions.

usage: toccheck.py <toc> <dir>...

The TOC is the only place that can silently drift from the file tree: a file it
names but that is missing makes the client refuse the addon, and a file that
exists but is not named is simply never loaded, which is far harder to spot.
"""
import os
import sys


def listed(toc):
    """Every .lua/.xml path the TOC loads, normalised to forward slashes."""
    out = []
    with open(toc, encoding="utf-8") as handle:
        for line in handle:
            line = line.strip().replace("\\", "/")
            if line and not line.startswith("#") and line.lower().endswith((".lua", ".xml")):
                out.append(line)
    return out


def on_disk(dirs):
    out = []
    for directory in dirs:
        for root, _, files in os.walk(directory):
            for name in sorted(files):
                if name.lower().endswith((".lua", ".xml")):
                    out.append(os.path.join(root, name).replace("\\", "/"))
    return out


def main(argv):
    toc, dirs = argv[0], argv[1:]
    in_toc = listed(toc)
    files = on_disk(dirs)

    missing = [p for p in in_toc if not os.path.isfile(p)]
    for path in missing:
        print(f"  MISSING  {path} (listed in the TOC, not on disk)")

    known = set(in_toc)
    unlisted = [p for p in files if p not in known]
    for path in unlisted:
        print(f"  UNLISTED {path} (on disk, never loaded)")

    if missing or unlisted:
        return 1
    print(f"toc: {len(in_toc)} files, listed and present")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

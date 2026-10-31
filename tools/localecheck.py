#!/usr/bin/env python3
"""Check the locale tables against the code and against each other.

usage: localecheck.py <enUS.lua> <other.lua>... -- <source dir>...

Two failures this catches that nothing else does: a L["..."] the code looks up
but no locale defines (it silently renders as the raw English key, which reads
fine in enUS and is invisible until a German client shows it), and a key that
enUS defines but a translation forgot.
"""
import os
import re
import sys

KEY = re.compile(r'^L\[\s*"((?:[^"\\]|\\.)*)"\s*\]\s*=')
USE = re.compile(r'\bL\[\s*"((?:[^"\\]|\\.)*)"\s*\]')


def defined(path):
    with open(path, encoding="utf-8") as handle:
        return {m.group(1) for line in handle for m in [KEY.match(line)] if m}


def used(dirs):
    keys = set()
    for directory in dirs:
        for root, _, files in os.walk(directory):
            if os.path.basename(root) == "Locales":
                continue
            for name in files:
                if not name.endswith(".lua"):
                    continue
                path = os.path.join(root, name)
                with open(path, encoding="utf-8") as handle:
                    keys |= set(USE.findall(handle.read()))
    return keys


def main(argv):
    split = argv.index("--")
    locales, dirs = argv[:split], argv[split + 1:]
    base, others = locales[0], locales[1:]

    base_keys = defined(base)
    failed = 0

    for key in sorted(used(dirs) - base_keys):
        print(f'  UNDEFINED "{key}" (used in code, missing from {base})')
        failed += 1

    for other in others:
        for key in sorted(base_keys - defined(other)):
            print(f'  UNTRANSLATED "{key}" (in {os.path.basename(base)}, missing from {os.path.basename(other)})')
            failed += 1
        for key in sorted(defined(other) - base_keys):
            print(f'  ORPHAN "{key}" (in {os.path.basename(other)}, not in {os.path.basename(base)})')
            failed += 1

    if failed:
        print(f"locales: {failed} problems")
        return 1
    print(f"locales: {len(base_keys)} keys, all defined and translated")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

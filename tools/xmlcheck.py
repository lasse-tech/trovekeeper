#!/usr/bin/env python3
"""Parse every XML file passed on the command line.

A malformed template file makes the client drop the whole addon silently.
"""
import sys
import xml.etree.ElementTree as ET


def main(paths):
    failed = 0
    for path in paths:
        try:
            ET.parse(path)
        except ET.ParseError as err:
            print(f"  FAIL    {path}: {err}")
            failed += 1
    if failed:
        print(f"xml: {failed} of {len(paths)} files failed")
        return 1
    print(f"xml: {len(paths)} files parse")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

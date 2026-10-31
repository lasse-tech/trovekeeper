#!/usr/bin/env python3
"""Parse every Lua file passed on the command line with a real Lua loader.

WoW ships no compiler, so a syntax error only surfaces in the client. This runs
the same load() the client would, before the file is ever installed.
"""
import sys

import lupa

_mod = getattr(lupa, "luajit21", None) or getattr(lupa, "lua51", None) or lupa
_load = _mod.LuaRuntime().eval(
    "function(s, n) local f, e = load(s, n) if f then return true, '' end return false, tostring(e) end"
)


def main(paths):
    failed = 0
    for path in paths:
        with open(path, encoding="utf-8") as f:
            source = f.read()
        ok, err = _load(source, "@" + path)
        if not ok:
            print(f"  FAIL    {path}: {err}")
            failed += 1
    if failed:
        print(f"lua: {failed} of {len(paths)} files failed")
        return 1
    print(f"lua: {len(paths)} files parse")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))

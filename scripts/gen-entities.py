#!/usr/bin/env python3
"""lib/markdown/entities.sml: the named character references of HTML5,
which CommonMark reads, from Python's html.entities.html5 (the list of
the WHATWG's HTML standard), sorted by name for a binary search.

  python3 scripts/gen-entities.py > lib/markdown/entities.sml
"""
from html.entities import html5
import sys

def sml(s):
    out = []
    for b in s.encode("utf-8"):
        c = chr(b)
        if c in '"\\':
            out.append("\\" + c)
        elif 32 <= b < 127:
            out.append(c)
        else:
            out.append("\\%03d" % b)
    return '"' + "".join(out) + '"'

names = sorted(n[:-1] for n in html5 if n.endswith(";"))
print("(* The named character references of HTML5 and the UTF-8 of what each")
print("   stands for, by name, from Python %s's html.entities.html5;" % sys.version.split()[0])
print("   written by scripts/gen-entities.py. *)")
print("structure MarkdownEntities =")
print("struct")
print("  val table : (string * string) vector = Vector.fromList [")
print(",\n".join("    (%s, %s)" % (sml(n), sml(html5[n + ";"])) for n in names) + "]")
print("end")

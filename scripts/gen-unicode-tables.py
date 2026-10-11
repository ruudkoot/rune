#!/usr/bin/env python3
"""Write lib/unicode's tables from the Unicode Character Database
(docs/plans/repl.md, D9 and M2): the display widths of code points
(lib/unicode/width_data.sml) and the properties of grapheme clusters
(lib/unicode/grapheme_data.sml), as ranges for a binary search.

  scripts/gen-unicode-tables.py [UCD_DIR]

The files of the version below are read from UCD_DIR (default
build/ucd), downloaded from unicode.org when they are not there, and
checked against the digests below, so that the tables are made from the
files they say. The test data, GraphemeBreakTest.txt, is copied to
tests/lib/unicode. Run it when Unicode's version changes, and commit what
it writes.
"""
import hashlib
import os
import re
import sys
import urllib.request

VERSION = "18.0.0"
FILES = {
    # name: (path under Public/VERSION/, sha256)
    "EastAsianWidth.txt": ("ucd/EastAsianWidth.txt",
                           "a0cf29eacd00cfcaec4381c6b7c281685f18dbb4e7ff82b4076ccb342ca839aa"),
    "DerivedGeneralCategory.txt": ("ucd/extracted/DerivedGeneralCategory.txt",
                                   "d6b151d2d40ee9b1876d26f417980f45ffae47b6055ccf7203cb31f07a030f94"),
    "emoji-data.txt": ("ucd/emoji/emoji-data.txt",
                       "80d00f8e616a0ef27fd6b8de3b758c06383b5d917e2977709578e68baf733bf1"),
    "GraphemeBreakProperty.txt": ("ucd/auxiliary/GraphemeBreakProperty.txt",
                                  "0839dcb79e4ac639ecd538b1abf7c9d22e3f9dd265b7e182d33627aa4d75b45a"),
    "DerivedCoreProperties.txt": ("ucd/DerivedCoreProperties.txt",
                                  "09c928886a178fcafd93c29e4bd59073a058e5a100b716d425cb563ab50f68c9"),
    "GraphemeBreakTest.txt": ("ucd/auxiliary/GraphemeBreakTest.txt",
                              "b0cf047ee94485bbdc846de2b902f5f8a815f6b674f9d04223cddadd91c9df31"),
}
GCB = ["Other", "CR", "LF", "Control", "Extend", "ZWJ", "Regional_Indicator",
       "Prepend", "SpacingMark", "L", "V", "T", "LV", "LVT"]
INCB = ["None", "Linker", "Consonant", "Extend"]


def fetch(ucd):
    os.makedirs(ucd, exist_ok=True)
    for name, (path, digest) in FILES.items():
        local = os.path.join(ucd, name)
        if not os.path.exists(local):
            url = "https://www.unicode.org/Public/%s/%s" % (VERSION, path)
            sys.stderr.write("fetching %s\n" % url)
            urllib.request.urlretrieve(url, local)
        got = hashlib.sha256(open(local, "rb").read()).hexdigest()
        if got != digest:
            sys.exit("%s: sha256 %s, not %s" % (local, got, digest))


def records(path):
    """(lo, hi, fields) for every data line of a UCD file."""
    for line in open(path, encoding="utf-8"):
        line = line.split("#", 1)[0].strip()
        if not line:
            continue
        fields = [f.strip() for f in line.split(";")]
        r = fields[0]
        lo, _, hi = r.partition("..")
        yield int(lo, 16), int(hi or lo, 16), fields[1:]


def merge(ranges):
    """Sorted, adjacent ranges of the same value joined."""
    out = []
    for lo, hi, v in sorted(ranges):
        if out and out[-1][2] == v and out[-1][1] + 1 >= lo:
            out[-1] = (out[-1][0], max(out[-1][1], hi), v)
        else:
            out.append((lo, hi, v))
    return out


def subtract(ranges, holes):
    """ranges (lo, hi, v) without the code points of holes."""
    out = []
    for lo, hi, v in ranges:
        pieces = [(lo, hi)]
        for hlo, hhi in holes:
            nxt = []
            for a, b in pieces:
                if hhi < a or hlo > b:
                    nxt.append((a, b))
                else:
                    if a < hlo:
                        nxt.append((a, hlo - 1))
                    if hhi < b:
                        nxt.append((hhi + 1, b))
            pieces = nxt
        out.extend((a, b, v) for a, b in pieces)
    return out


def sml_vector(name, ints, doc):
    """An `int vector` built at its first use (`once`) from a string of
    six hexadecimal digits a number (`decode`): a string costs a compiler
    next to nothing, where thousands of integer literals cost the
    compiler's own bootstrap a seventh of its work, and a program that never
    asks for the table does not build it."""
    digits = "".join("%06X" % x for x in ints)
    lines = ["  (* %s *)" % doc, "  val %s : unit -> int vector = once (decode" % name]
    chunks = [digits[i:i + 72] for i in range(0, len(digits), 72)] or [""]
    for ci, chunk in enumerate(chunks):
        first = ci == 0
        last = ci + 1 == len(chunks)
        lines.append("    " + ('"' if first else "\\") + chunk + ("\")" if last else "\\"))
    return "\n".join(lines)


ONCE = """  (* a table built at its first use: a program that never asks for it,
     such as the compiler when it shows no excerpt, does not pay for it *)
  fun once (build : unit -> int vector) : unit -> int vector =
    let val made = ref NONE
    in fn () => case !made of SOME v => v | NONE => let val v = build () in made := SOME v; v end end

  (* the numbers of a string of six hexadecimal digits each *)
  fun decode (s : string) () : int vector =
    let
      fun digit c = if c <= #"9" then Char.ord c - Char.ord #"0" else Char.ord c - Char.ord #"A" + 10
      fun number i =
        let fun go (k, n) = if k = 6 then n else go (k + 1, n * 16 + digit (String.sub (s, 6 * i + k)))
        in go (0, 0) end
    in
      Vector.tabulate (String.size s div 6, number)
    end
"""


def header(what, files):
    sums = "\n".join("     %s %s" % (FILES[f][1][:16], f) for f in files)
    return ("(* Generated by scripts/gen-unicode-tables.py from the Unicode Character\n"
            "   Database %s; do not edit.\n\n   %s\n\n"
            "   The ranges are pairs, or triples with a value, in increasing order\n"
            "   of code point, for a binary search, each number written as six\n"
            "   hexadecimal digits of a string; a table is built at its first use.\n"
            "   Made from (sha256, first 16 digits):\n\n%s\n\n"
            "   Area: Unicode *)" % (VERSION, what, sums))


def main():
    ucd = sys.argv[1] if len(sys.argv) > 1 else "build/ucd"
    fetch(ucd)
    p = lambda n: os.path.join(ucd, n)
    # widths: zero for the nonspacing, enclosing and format marks (but the
    # soft hyphen, which terminals show) and the medial vowels and final
    # consonants of conjoining Hangul; two for East Asian Wide and Fullwidth,
    # and for what is shown as an emoji by default
    zero = [(lo, hi, 0) for lo, hi, f in records(p("DerivedGeneralCategory.txt"))
            if f[0] in ("Mn", "Me", "Cf")]
    zero = subtract(zero, [(0xAD, 0xAD)])
    zero += [(0x1160, 0x11FF, 0), (0xD7B0, 0xD7FF, 0)]
    control = [(lo, hi, 0) for lo, hi, f in records(p("DerivedGeneralCategory.txt")) if f[0] == "Cc"]
    wide = [(lo, hi, 0) for lo, hi, f in records(p("EastAsianWidth.txt")) if f[0] in ("W", "F")]
    wide += [(lo, hi, 0) for lo, hi, f in records(p("emoji-data.txt")) if f[0] == "Emoji_Presentation"]
    wide = subtract(merge(wide), [(lo, hi) for lo, hi, _ in merge(zero)])
    flat = lambda rs: [x for lo, hi, _ in merge(rs) for x in (lo, hi)]
    width = [header("The display widths of code points (lib/unicode/display_width.sml).",
                    ["DerivedGeneralCategory.txt", "EastAsianWidth.txt", "emoji-data.txt"]),
             "structure UnicodeWidthData =", "struct",
             '  val version = "%s"' % VERSION, "", ONCE,
             sml_vector("zero", flat(zero), "nonspacing, enclosing and format marks; conjoining jamo"), "",
             sml_vector("control", flat(control), "the control characters, C0 and C1"), "",
             sml_vector("wide", flat(wide), "East Asian Wide and Fullwidth, and emoji presentation"),
             "end", ""]
    open("lib/unicode/width_data.sml", "w").write("\n".join(width))
    # grapheme clusters: the Grapheme_Cluster_Break property, the
    # Extended_Pictographic property, and Indic_Conjunct_Break
    gcb = [(lo, hi, GCB.index(f[0])) for lo, hi, f in records(p("GraphemeBreakProperty.txt"))]
    pict = [(lo, hi, 0) for lo, hi, f in records(p("emoji-data.txt")) if f[0] == "Extended_Pictographic"]
    incb = [(lo, hi, INCB.index(f[1])) for lo, hi, f in records(p("DerivedCoreProperties.txt"))
            if f[0] == "InCB"]
    triples = lambda rs: [x for lo, hi, v in merge(rs) for x in (lo, hi, v)]
    graph = [header("The properties of grapheme clusters (lib/unicode/grapheme.sml).",
                    ["GraphemeBreakProperty.txt", "emoji-data.txt", "DerivedCoreProperties.txt"]),
             "structure UnicodeGraphemeData =", "struct",
             '  val version = "%s"' % VERSION, "", ONCE,
             "  (* Grapheme_Cluster_Break, a value of each range:\n     %s *)"
             % "\n     ".join(", ".join("%d %s" % (i, n) for i, n in enumerate(GCB) if i // 5 == k)
                            for k in range(3)),
             sml_vector("breakProperty", triples(gcb), "lo, hi, value"), "",
             sml_vector("pictographic", flat(pict), "Extended_Pictographic"), "",
             "  (* Indic_Conjunct_Break: %s *)" % ", ".join("%d %s" % (i, n) for i, n in enumerate(INCB)),
             sml_vector("conjunct", triples(incb), "lo, hi, value"),
             "end", ""]
    open("lib/unicode/grapheme_data.sml", "w").write("\n".join(graph))
    os.makedirs("tests/lib/unicode", exist_ok=True)
    data = open(p("GraphemeBreakTest.txt"), encoding="utf-8").read()
    open("tests/lib/unicode/GraphemeBreakTest.txt", "w", encoding="utf-8").write(data)
    print("zero %d, control %d, wide %d ranges; break %d, pictographic %d, conjunct %d"
          % (len(merge(zero)), len(merge(control)), len(merge(wide)),
             len(merge(gcb)), len(merge(pict)), len(merge(incb))))


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Write lib/unicode's tables from the Unicode Character Database
(docs/plans/repl.md, D9 and M2; docs/plans/utf8.md, M5): the display
widths of code points (lib/unicode/width_data.sml), the properties of
grapheme clusters (lib/unicode/grapheme_data.sml), normalisation
(lib/unicode/normalize_data.sml), the identifiers of UAX #31 and the
profile of them that Rune takes (lib/unicode/identifier_data.sml), and
the data of UTS #39, Unicode Security Mechanisms
(lib/unicode/security_data.sml).

  scripts/gen-unicode-tables.py [UCD_DIR]

The files of the version below are read from UCD_DIR (default
build/ucd), downloaded from unicode.org when they are not there, and
checked against the digests below, so that the tables are made from the
files they say. A reference normaliser checks the normalisation data
against all of NormalizationTest.txt before anything is written. The
test data that the tests of tests/lib/unicode read is copied there. Run
it when Unicode's version changes, and commit what it writes; the frozen
sets of the identifier profile below do not change with it.
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
    # normalisation (UAX #15): the decompositions and combining classes,
    # the exclusions from composition, the quick check, and the test data
    "UnicodeData.txt": ("ucd/UnicodeData.txt",
                        "0736451de439ae7baf1425136617da495e09ee5afbe6e394374db7009ea08950"),
    "CompositionExclusions.txt": ("ucd/CompositionExclusions.txt",
                                  "c759b100e9ae8960ae6b50fc5765950a7581fd9f30d4ef95f68f25a6d97e818e"),
    "DerivedNormalizationProps.txt": ("ucd/DerivedNormalizationProps.txt",
                                      "98ac7f67d985fe781e317f6182e885e94cabb0c314769e6dd73e48b226931ccd"),
    "NormalizationTest.txt": ("ucd/NormalizationTest.txt",
                              "25a50d816764b04abfb4a646d3eb2b2a803284c3873d9a06757b94fe4513dde3"),
    # scripts (UAX #24), and their short names
    "Scripts.txt": ("ucd/Scripts.txt",
                    "0071fd81b6aeae25f6e8bce8efec3066a6476a91b49bdb2f52dc76e817862a6a"),
    "ScriptExtensions.txt": ("ucd/ScriptExtensions.txt",
                             "5c9d34a922f687726f2a8bcf57d49f905987e51f1b21b58c95a00fbe255cec23"),
    "PropertyValueAliases.txt": ("ucd/PropertyValueAliases.txt",
                                 "06c4c8eaf7b0bf34abe73b113da1215bd784ac254d4c223600b90267caa4bbbd"),
    # UTS #39, whose data is under security/ and, unlike the UCD's, may
    # change in any version
    "confusables.txt": ("security/confusables.txt",
                        "6ed3ee967c9dfdf6677d563c9985182fbc50a2efb7d6059cd57b2e2ce18f5b92"),
    "IdentifierStatus.txt": ("security/IdentifierStatus.txt",
                             "5863c7d99ca18f213c41c7318aa5528bebfb6d32ec0f1d5944e37192c119aebd"),
    "IdentifierType.txt": ("security/IdentifierType.txt",
                           "fa24851acc669e58670e354e7b98a4ec8f52a809ec4f80524b6a60efdb868831"),
}
# the files the tests of tests/lib/unicode read, copied there
TEST_DATA = ["GraphemeBreakTest.txt", "NormalizationTest.txt", "DerivedCoreProperties.txt",
             "confusables.txt", "IdentifierStatus.txt", "IdentifierType.txt", "Scripts.txt",
             "ScriptExtensions.txt", "PropertyValueAliases.txt"]
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



# ---- the tables of docs/plans/utf8.md, M5: numbers written in base 32,
# which takes a third of the room of six hexadecimal digits, and a table
# of two stages written in hexadecimal

# the last digit of a number, 0 to 31: "0" to "9", ":" to "@", "A" to "O";
# a digit before it: "]" to "|" (no quote, backslash or parenthesis)
DIGITS = "".join(chr(48 + d) for d in range(32))
MORE = "".join(chr(93 + d) for d in range(32))


def base32(n):
    """n in base 32, most significant digit first: the last digit from
    DIGITS and those before it from MORE, so that the numbers of a string
    need no separator."""
    assert n >= 0
    out = DIGITS[n % 32]
    n //= 32
    while n:
        out = MORE[n % 32] + out
        n //= 32
    return out


def sml_literal(lines, text):
    """A string literal of text, cut into lines of 72 characters."""
    chunks = [text[i:i + 72] for i in range(0, len(text), 72)] or [""]
    for ci, chunk in enumerate(chunks):
        first = ci == 0
        last = ci + 1 == len(chunks)
        lines.append("    " + ('"' if first else "\\") + chunk + ('"' if last else "\\"))
    return lines


def sml_numbers(name, ints, doc, build="numbers"):
    """An `int vector` built at its first use (`once`) by `build` from a
    string of numbers in base 32."""
    lines = sml_literal(["  (* %s *)" % doc, "  val %s : unit -> int vector = once (%s" % (name, build)],
                        "".join(base32(x) for x in ints))
    lines[-1] += ")"
    return "\n".join(lines)


def sml_string(name, text, doc):
    """A string, for a table read as it stands."""
    return "\n".join(sml_literal(["  (* %s *)" % doc, "  val %s =" % name], text))


def ranges(rs):
    """Ranges (lo, hi, v), sorted and disjoint, as numbers: the distance of
    each from the end of the one before it, its length less one, and its
    value."""
    out, end = [], 0
    for lo, hi, v in rs:
        assert lo >= end and hi >= lo
        out += [lo - end, hi - lo, v]
        end = hi + 1
    return out


def runs(value, top=0x110000):
    """The ranges of equal value of every code point below top."""
    out = []
    for c in range(top):
        v = value(c)
        if out and out[-1][2] == v:
            out[-1][1] = c
        else:
            out.append([c, c, v])
    return [tuple(r) for r in out]


def spans(cs):
    """A set of code points as ranges (lo, hi, 1)."""
    return [(lo, hi, 1) for lo, hi, _ in merge([(c, c, 1) for c in cs])]


NUMBERS = """  (* a value built at its first use: a program that never asks for it,
     such as the compiler when it reads no name outside ASCII, does not pay
     for it *)
  fun once (build : unit -> 'a) : unit -> 'a =
    let val made = ref NONE
    in fn () => case !made of SOME v => v | NONE => let val v = build () in made := SOME v; v end end

  (* the numbers of a string, each in base 32, most significant digit
     first: a character from "]" to "|" is a digit (0 to 31) with more of
     its number after it, and one from "0" to "O" the last digit (0 to 31) *)
  fun numbers (s : string) () : int vector =
    let
      val n = String.size s
      fun go (i, v, acc) =
        if i = n then Vector.fromList (rev acc)
        else
          let val c = Char.ord (String.sub (s, i))
          in if c >= 93 then go (i + 1, 32 * v + c - 93, acc) else go (i + 1, 0, (32 * v + c - 48) :: acc) end
    in
      go (0, 0, [])
    end

  (* ranges, each written as three numbers: the distance of its first code
     point from the end of the range before it, its length less one, and
     its value; built as the triples lo, hi, value *)
  fun ranges (s : string) () : int vector =
    let
      val v = numbers s ()
      fun go (i, next, acc) =
        if i >= Vector.length v then Vector.fromList (rev acc)
        else
          let
            val lo = next + Vector.sub (v, i)
            val hi = lo + Vector.sub (v, i + 1)
          in
            go (i + 3, hi + 1, Vector.sub (v, i + 2) :: hi :: lo :: acc)
          end
    in
      go (0, 0, [])
    end
"""


def header2(what, files):
    sums = "\n".join("     %s %s" % (FILES[f][1][:16], f) for f in files)
    return ("(* Generated by scripts/gen-unicode-tables.py from the Unicode Character\n"
            "   Database %s; do not edit.\n\n   %s\n\n"
            "   A table is a string of numbers in base 32, built at its first\n"
            "   use. Made from (sha256, first 16 digits):\n\n%s\n\n"
            "   Area: Unicode *)" % (VERSION, what, sums))


# ---- normalisation (UAX #15)

# Hangul syllables, decomposed and composed by arithmetic (Unicode 3.12)
S_BASE, L_BASE, V_BASE, T_BASE = 0xAC00, 0x1100, 0x1161, 0x11A7
L_COUNT, V_COUNT, T_COUNT = 19, 21, 28
N_COUNT = V_COUNT * T_COUNT
S_COUNT = L_COUNT * N_COUNT


def unicode_data(path):
    """The combining classes and the decomposition mappings of
    UnicodeData.txt: {cp: ccc} for ccc > 0, and {cp: (compat, [cps])}."""
    ccc, dec = {}, {}
    for line in open(path, encoding="utf-8"):
        f = line.rstrip("\n").split(";")
        cp = int(f[0], 16)
        if int(f[3]):
            ccc[cp] = int(f[3])
        if f[5]:
            parts = f[5].split()
            compat = parts[0].startswith("<")
            dec[cp] = (compat, [int(x, 16) for x in (parts[1:] if compat else parts)])
    return ccc, dec


def full_decomposition(cp, dec, compat):
    """The full canonical (or, with compat, compatibility) decomposition of
    one code point, before reordering."""
    if S_BASE <= cp < S_BASE + S_COUNT:
        i = cp - S_BASE
        out = [L_BASE + i // N_COUNT, V_BASE + i % N_COUNT // T_COUNT]
        if i % T_COUNT:
            out.append(T_BASE + i % T_COUNT)
        return out
    if cp in dec and (compat or not dec[cp][0]):
        return [x for c in dec[cp][1] for x in full_decomposition(c, dec, compat)]
    return [cp]


def reorder(cps, ccc):
    """The canonical ordering algorithm: a stable sort of each run of
    non-starters by combining class."""
    out, run = [], []
    for c in cps:
        if ccc.get(c, 0):
            run.append(c)
        else:
            out.extend(sorted(run, key=lambda x: ccc[x]))
            run = []
            out.append(c)
    out.extend(sorted(run, key=lambda x: ccc[x]))
    return out


def py_normalize(cps, form, ccc, dec, comp):
    """A reference normaliser in Python, to check the tables before they are
    written: NFD, NFC, NFKD or NFKC of a list of code points."""
    compat = form in ("NFKD", "NFKC")
    d = reorder([x for c in cps for x in full_decomposition(c, dec, compat)], ccc)
    if form in ("NFD", "NFKD") or not d:
        return d
    starter = 0 if ccc.get(d[0], 0) == 0 else None
    last = 0 if starter is not None else 256
    res = [d[0]]
    for c in d[1:]:
        cc = ccc.get(c, 0)
        s = res[starter] if starter is not None else None
        composite = None
        if s is not None and (last < cc or (last == 0 and len(res) - 1 == starter)):
            if L_BASE <= s < L_BASE + L_COUNT and V_BASE <= c < V_BASE + V_COUNT:
                composite = S_BASE + ((s - L_BASE) * V_COUNT + c - V_BASE) * T_COUNT
            elif (S_BASE <= s < S_BASE + S_COUNT and (s - S_BASE) % T_COUNT == 0
                  and T_BASE < c < T_BASE + T_COUNT):
                composite = s + c - T_BASE
            else:
                composite = comp.get((s, c))
        if composite is not None:
            res[starter] = composite
        else:
            if cc == 0:
                starter = len(res)
            last = cc
            res.append(c)
    return res


def check_normalization_test(path, ccc, dec, comp):
    """Every line of NormalizationTest.txt, by the reference normaliser."""
    bad = n = 0
    for line in open(path, encoding="utf-8"):
        line = line.split("#", 1)[0].strip()
        if not line or line.startswith("@"):
            continue
        c = [[int(x, 16) for x in col.split()] for col in line.split(";")[:5]]
        n += 1
        f = lambda form, x: py_normalize(x, form, ccc, dec, comp)
        ok = (all(c[1] == f("NFC", c[i]) for i in (0, 1, 2)) and all(c[3] == f("NFC", c[i]) for i in (3, 4))
              and all(c[2] == f("NFD", c[i]) for i in (0, 1, 2)) and all(c[4] == f("NFD", c[i]) for i in (3, 4))
              and all(c[3] == f("NFKC", c[i]) for i in range(5)) and all(c[4] == f("NFKD", c[i]) for i in range(5)))
        bad += not ok
    if bad:
        sys.exit("the reference normaliser fails %d of the %d lines of NormalizationTest.txt" % (bad, n))
    return n


def normalization(p):
    """lib/unicode/normalize_data.sml: what NFD and NFC need. The
    compatibility forms are left out (docs/plans/utf8.md, E4)."""
    ccc, dec = unicode_data(p("UnicodeData.txt"))
    exclusions = {c for lo, hi, _ in records(p("CompositionExclusions.txt")) for c in range(lo, hi + 1)}
    canonical = {cp: m for cp, (compat, m) in dec.items() if not compat}
    # Full_Composition_Exclusion: the exclusions, the singletons, and the
    # decompositions that begin with or are a non-starter
    fce = exclusions | {cp for cp, m in canonical.items()
                        if len(m) == 1 or ccc.get(cp, 0) or ccc.get(m[0], 0)}
    derived = {c for lo, hi, f in records(p("DerivedNormalizationProps.txt"))
               if f[0] == "Full_Composition_Exclusion" for c in range(lo, hi + 1)}
    if fce != derived:
        sys.exit("Full_Composition_Exclusion: %d derived here, %d in DerivedNormalizationProps.txt"
                 % (len(fce), len(derived)))
    comp = {(m[0], m[1]): cp for cp, m in canonical.items() if cp not in fce}
    lines = check_normalization_test(p("NormalizationTest.txt"), ccc, dec, comp)
    qc = merge([(lo, hi, {"N": 1, "M": 2}[f[1]]) for lo, hi, f in records(p("DerivedNormalizationProps.txt"))
                if f[0] == "NFC_QC"])
    classes = merge([(c, c, v) for c, v in ccc.items()])
    order = sorted(canonical)
    index = {cp: i for i, cp in enumerate(order)}
    decomposition, prev = [], 0
    for cp in order:
        m = canonical[cp]
        decomposition += [cp - prev, m[0], m[1] if len(m) > 1 else 0]
        prev = cp
    composition = [index[comp[k]] for k in sorted(comp)]
    data = [header2("The canonical decompositions, the combining classes and the quick\n"
                    "   check of normalisation (lib/unicode/normalize.sml), UAX #15.",
                    ["UnicodeData.txt", "CompositionExclusions.txt", "DerivedNormalizationProps.txt"]),
            "structure UnicodeNormalizeData =", "struct",
            '  val version = "%s"' % VERSION, "",
            "  (* no code point below the first of these has a canonical decomposition,\n"
            "     a combining class other than 0, an NFC_Quick_Check other than Yes, or\n"
            "     is the second of a primary composite: what ASCII and Latin-1 need of\n"
            "     no table *)",
            "  val firstDecomposed = 0x%X" % min(canonical),
            "  val firstCombining = 0x%X" % min(ccc),
            "  val firstQuickCheck = 0x%X" % min(lo for lo, _, _ in qc),
            "  val firstSecond = 0x%X" % min(b for _, b in comp), "", NUMBERS,
            "  (* decompositions, each written as three numbers: the distance of its\n"
            "     code point from the one before, the first code point it maps to,\n"
            "     and the second (0 where it maps to one); built as the triples code\n"
            "     point, first, second *)\n"
            "  fun decompositions (s : string) () : int vector =\n"
            "    let\n"
            "      val v = numbers s ()\n"
            "      fun go (i, prev, acc) =\n"
            "        if i >= Vector.length v then Vector.fromList (rev acc)\n"
            "        else\n"
            "          let val c = prev + Vector.sub (v, i)\n"
            "          in go (i + 3, c, Vector.sub (v, i + 2) :: Vector.sub (v, i + 1) :: c :: acc) end\n"
            "    in\n"
            "      go (0, 0, [])\n"
            "    end\n",
            sml_numbers("combiningClass", ranges(classes),
                        "Canonical_Combining_Class other than 0: lo, hi, class", "ranges"), "",
            sml_numbers("decomposition", decomposition,
                        "the canonical decomposition mappings, but Hangul's: code point,\n"
                        "     first, second (0 for a singleton), in order of code point",
                        "decompositions"), "",
            sml_numbers("composition", composition,
                        "the primary composites, but Hangul's: the index in decomposition of\n"
                        "     each mapping to two code points that composes again, in order of\n"
                        "     first and second"), "",
            sml_numbers("quickCheck", ranges(qc), "NFC_Quick_Check: lo, hi, 1 for No, 2 for Maybe", "ranges"),
            "end", ""]
    open("lib/unicode/normalize_data.sml", "w").write("\n".join(data))
    return ("ccc %d ranges, decomposition %d, composition %d, quick check %d ranges; "
            "NormalizationTest %d lines checked"
            % (len(classes), len(canonical), len(comp), len(qc), lines))


# ---- identifiers (UAX #31), and the profile of them that Rune takes
# (docs/plans/utf8.md, D10)

# The default ignorables in XID_Continue, as Unicode 18.0.0 has them (269
# code points): the profile leaves them out, frozen here because
# Default_Ignorable_Code_Point is not a stable property (UAX #31, 2.3).
FROZEN_IGNORABLE = [
    (0x034F, 0x034F),  # COMBINING GRAPHEME JOINER
    (0x115F, 0x1160),  # HANGUL CHOSEONG FILLER, HANGUL JUNGSEONG FILLER
    (0x17B4, 0x17B5),  # KHMER VOWEL INHERENT AQ, KHMER VOWEL INHERENT AA
    (0x180B, 0x180D),  # MONGOLIAN FREE VARIATION SELECTOR ONE..THREE
    (0x180F, 0x180F),  # MONGOLIAN FREE VARIATION SELECTOR FOUR
    (0x200C, 0x200D),  # ZERO WIDTH NON-JOINER, ZERO WIDTH JOINER
    (0x3164, 0x3164),  # HANGUL FILLER
    (0xFE00, 0xFE0F),  # VARIATION SELECTOR-1..16
    (0xFFA0, 0xFFA0),  # HALFWIDTH HANGUL FILLER
    (0xE0100, 0xE01EF),  # VARIATION SELECTOR-17..256
]

# The lookalikes: identifier characters that look like a character of
# Standard ML's punctuation or a digit, each with the ASCII character it
# looks like. The profile leaves them out. The list is written here and
# not derived, so that it cannot change with Unicode's data (D10): it was
# seeded from UTS #39's confusables of SEED_VERSION, the owner's decisions
# of 2026-10-18 applied, and completed by hand.
SEED_VERSION = "18.0.0"
SEEDED_PUNCTUATION = {
    0x01C3: '!',  # LATIN LETTER RETROFLEX CLICK
    0x0241: '?',  # LATIN CAPITAL LETTER GLOTTAL STOP
    0x0294: '?',  # LATIN LETTER GLOTTAL STOP
    0x02B9: "'",  # MODIFIER LETTER PRIME
    0x02BB: "'",  # MODIFIER LETTER TURNED COMMA
    0x02BC: "'",  # MODIFIER LETTER APOSTROPHE
    0x02BD: "'",  # MODIFIER LETTER REVERSED COMMA
    0x02BE: "'",  # MODIFIER LETTER RIGHT HALF RING
    0x02C6: '^',  # MODIFIER LETTER CIRCUMFLEX ACCENT
    0x02C8: "'",  # MODIFIER LETTER VERTICAL LINE
    0x02CA: "'",  # MODIFIER LETTER ACUTE ACCENT
    0x02CB: "'",  # MODIFIER LETTER GRAVE ACCENT
    0x02D0: ':',  # MODIFIER LETTER TRIANGULAR COLON
    0x0374: "'",  # GREEK NUMERAL SIGN
    0x0586: '$',  # ARMENIAN SMALL LETTER FEH
    0x05D9: "'",  # HEBREW LETTER YOD
    0x0640: '_',  # ARABIC TATWEEL
    0x0660: '.',  # ARABIC-INDIC DIGIT ZERO
    0x06F0: '.',  # EXTENDED ARABIC-INDIC DIGIT ZERO
    0x07F4: "'",  # NKO HIGH TONE APOSTROPHE
    0x07F5: "'",  # NKO LOW TONE APOSTROPHE
    0x07FA: '_',  # NKO LAJANYALAN
    0x0903: ':',  # DEVANAGARI SIGN VISARGA
    0x097D: '?',  # DEVANAGARI LETTER GLOTTAL STOP
    0x0A83: ':',  # GUJARATI SIGN VISARGA
    0x13AE: '?',  # CHEROKEE LETTER HE
    0x1429: '+',  # CANADIAN SYLLABICS FINAL PLUS
    0x1433: '>',  # CANADIAN SYLLABICS PO
    0x1438: '<',  # CANADIAN SYLLABICS PA
    0x144A: "'",  # CANADIAN SYLLABICS WEST-CREE P
    0x1540: '+',  # CANADIAN SYLLABICS WEST-CREE Y
    0x16B2: '<',  # RUNIC LETTER KAUNA
    0x16CC: "'",  # RUNIC LETTER SHORT-TWIG-SOL S
    0x174D: '-',  # BUHID LETTER RA
    0x18D4: '^',  # CANADIAN SYLLABICS OJIBWAY P
    0x1BF3: '-',  # BATAK PANONGONAN
    0x1DBA: '^',  # MODIFIER LETTER SMALL TURNED V
    0x2CBA: '-',  # COPTIC CAPITAL LETTER DIALECT-P NI
    0x2CBB: '-',  # COPTIC SMALL LETTER DIALECT-P NI
    0x2CC6: '/',  # COPTIC CAPITAL LETTER OLD COPTIC ESH
    0x2CC7: '/',  # COPTIC SMALL LETTER OLD COPTIC ESH
    0x2D51: '!',  # TIFINAGH LETTER TUAREG YANG
    0x2D66: '<',  # TIFINAGH LETTER YE
    0x3033: '/',  # VERTICAL KANA REPEAT MARK UPPER HALF
    0x30CE: '/',  # KATAKANA LETTER NO
    0x4E36: '\\',  # CJK UNIFIED IDEOGRAPH-4E36
    0x4E3F: '/',  # CJK UNIFIED IDEOGRAPH-4E3F
    0xA4F8: '.',  # LISU LETTER TONE MYA TI
    0xA4F9: ',',  # LISU LETTER TONE NA PO
    0xA4FD: ':',  # LISU LETTER TONE MYA JEU
    0xA60C: '=',  # VAI SYLLABLE LENGTHENER
    0xA6EB: '?',  # BAMUM LETTER NTUU
    0xA778: '&',  # LATIN SMALL LETTER UM
    0xA78B: "'",  # LATIN CAPITAL LETTER SALTILLO
    0xA78C: "'",  # LATIN SMALL LETTER SALTILLO
    0xAA7D: '-',  # MYANMAR SIGN TAI LAING TONE-5
    0xABEC: '.',  # MEETEI MAYEK LUM IYEK
    0xFE4D: '_',  # DASHED LOW LINE
    0xFE4E: '_',  # CENTRELINE LOW LINE
    0xFE4F: '_',  # WAVY LOW LINE
    0xFF3F: '_',  # FULLWIDTH LOW LINE
    0xFF89: '/',  # HALFWIDTH KATAKANA LETTER NO
    0x10140: ')',  # GREEK ACROPHONIC ATTIC ONE QUARTER
    0x10141: '(',  # GREEK ACROPHONIC ATTIC ONE HALF
    0x1015B: ':',  # GREEK ACROPHONIC EPIDAUREAN TWO
    0x1029B: '+',  # LYCIAN LETTER H
    0x1031F: '*',  # OLD ITALIC LETTER ESS
    0x1032D: '<',  # OLD ITALIC LETTER YE
    0x11002: ':',  # BRAHMI SIGN VISARGA
    0x11082: ':',  # KAITHI SIGN VISARGA
    0x11182: ':',  # SHARADA SIGN VISARGA
    0x115BE: ':',  # SIDDHAM SIGN VISARGA
    0x116AC: ':',  # TAKRI SIGN VISARGA
    0x11838: ':',  # DOGRA SIGN VISARGA
    0x11DD9: ':',  # TOLONG SIKI SIGN SELA
    0x145C1: '_',  # ANATOLIAN HIEROGLYPH A397
    0x16869: '+',  # BAMUM LETTER PHASE-B SHET NJAQ
    0x16AEC: '<',  # BASSA VAH LETTER E
    0x16F3F: '>',  # MIAO LETTER ARCHAIC ZZA
    0x16F51: "'",  # MIAO SIGN ASPIRATION
    0x16F52: "'",  # MIAO SIGN REFORMED VOICING
    0x16F53: ',',  # MIAO SIGN REFORMED ASPIRATION
    0x1D16D: '.',  # MUSICAL SYMBOL COMBINING AUGMENTATION DOT
    0x1E6E9: '+',  # TAI YO LETTER IA
    0x1E94B: "'",  # ADLAM NASALIZATION MARK
}
SEEDED_DIGITS = {
    0x01A7: '2',  # LATIN CAPITAL LETTER TONE TWO
    0x01BC: '5',  # LATIN CAPITAL LETTER TONE FIVE
    0x021C: '3',  # LATIN CAPITAL LETTER YOGH
    0x0222: '8',  # LATIN CAPITAL LETTER OU
    0x0223: '8',  # LATIN SMALL LETTER OU
    0x03E8: '2',  # COPTIC CAPITAL LETTER HORI
    0x03EC: '6',  # COPTIC CAPITAL LETTER SHIMA
    0x0A67: '9',  # GURMUKHI DIGIT ONE
    0x0A6A: '8',  # GURMUKHI DIGIT FOUR
    0x0B68: '9',  # ORIYA DIGIT TWO
    0x0D6D: '9',  # MALAYALAM DIGIT SEVEN
    0x13CE: '4',  # CHEROKEE LETTER SE
    0x13EE: '6',  # CHEROKEE LETTER WV
    0x14BF: '2',  # CANADIAN SYLLABICS SAYISI M
    0x1616: '2',  # CANADIAN SYLLABICS CARRIER JO
    0x1702: '3',  # TAGALOG LETTER U
    0x172A: '7',  # HANUNOO LETTER BA
    0x1C84: '7',  # CYRILLIC SMALL LETTER TALL TE
    0x2C9C: '3',  # COPTIC CAPITAL LETTER KSI
    0x2CC4: '3',  # COPTIC CAPITAL LETTER OLD COPTIC SHEI
    0x2CCA: '9',  # COPTIC CAPITAL LETTER DIALECT-P HORI
    0x2CCB: '9',  # COPTIC SMALL LETTER DIALECT-P HORI
    0x2CCC: '3',  # COPTIC CAPITAL LETTER OLD COPTIC HORI
    0x2CD2: '6',  # COPTIC CAPITAL LETTER OLD COPTIC HEI
    0x2CD3: '6',  # COPTIC SMALL LETTER OLD COPTIC HEI
    0x2CDC: '6',  # COPTIC CAPITAL LETTER OLD NUBIAN SHIMA
    0xA543: '6',  # VAI SYLLABLE KI
    0xA589: '8',  # VAI SYLLABLE ZOO
    0xA644: '2',  # CYRILLIC CAPITAL LETTER REVERSED DZE
    0xA6EF: '2',  # BAMUM LETTER KOGHOM
    0xA75A: '2',  # LATIN CAPITAL LETTER R ROTUNDA
    0xA76A: '3',  # LATIN CAPITAL LETTER ET
    0xA76E: '9',  # LATIN CAPITAL LETTER CON
    0xA76F: '9',  # LATIN SMALL LETTER CON
    0xA7AB: '3',  # LATIN CAPITAL LETTER REVERSED OPEN E
    0xAB9E: '4',  # CHEROKEE SMALL LETTER SE
    0xABBE: '6',  # CHEROKEE SMALL LETTER WV
    0xFF12: '2',  # FULLWIDTH DIGIT TWO
    0xFF13: '3',  # FULLWIDTH DIGIT THREE
    0xFF14: '4',  # FULLWIDTH DIGIT FOUR
    0xFF15: '5',  # FULLWIDTH DIGIT FIVE
    0xFF16: '6',  # FULLWIDTH DIGIT SIX
    0xFF17: '7',  # FULLWIDTH DIGIT SEVEN
    0xFF18: '8',  # FULLWIDTH DIGIT EIGHT
    0xFF19: '9',  # FULLWIDTH DIGIT NINE
    0x1031A: '8',  # OLD ITALIC LETTER EF
    0x104D2: '7',  # OSAGE CAPITAL LETTER ZA
    0x11445: '8',  # NEWA SIGN VISARGA
    0x118AC: '9',  # WARANG CITI CAPITAL LETTER KO
    0x118AF: '4',  # WARANG CITI CAPITAL LETTER UC
    0x118BB: '5',  # WARANG CITI CAPITAL LETTER HORR
    0x118C6: '7',  # WARANG CITI SMALL LETTER II
    0x118CA: '3',  # WARANG CITI SMALL LETTER ANG
    0x118CC: '9',  # WARANG CITI SMALL LETTER KO
    0x118D5: '6',  # WARANG CITI SMALL LETTER AT
    0x118D6: '9',  # WARANG CITI SMALL LETTER AM
    0x169C1: '9',  # BAMUM LETTER PHASE-E NZUQ
    0x169FE: '8',  # BAMUM LETTER PHASE-E KI
    0x16F3B: '3',  # MIAO LETTER ZA
    0x1CCF2: '2',  # OUTLINED DIGIT TWO
    0x1CCF3: '3',  # OUTLINED DIGIT THREE
    0x1CCF4: '4',  # OUTLINED DIGIT FOUR
    0x1CCF5: '5',  # OUTLINED DIGIT FIVE
    0x1CCF6: '6',  # OUTLINED DIGIT SIX
    0x1CCF7: '7',  # OUTLINED DIGIT SEVEN
    0x1CCF8: '8',  # OUTLINED DIGIT EIGHT
    0x1CCF9: '9',  # OUTLINED DIGIT NINE
    0x1D7D0: '2',  # MATHEMATICAL BOLD DIGIT TWO
    0x1D7D1: '3',  # MATHEMATICAL BOLD DIGIT THREE
    0x1D7D2: '4',  # MATHEMATICAL BOLD DIGIT FOUR
    0x1D7D3: '5',  # MATHEMATICAL BOLD DIGIT FIVE
    0x1D7D4: '6',  # MATHEMATICAL BOLD DIGIT SIX
    0x1D7D5: '7',  # MATHEMATICAL BOLD DIGIT SEVEN
    0x1D7D6: '8',  # MATHEMATICAL BOLD DIGIT EIGHT
    0x1D7D7: '9',  # MATHEMATICAL BOLD DIGIT NINE
    0x1D7DA: '2',  # MATHEMATICAL DOUBLE-STRUCK DIGIT TWO
    0x1D7DB: '3',  # MATHEMATICAL DOUBLE-STRUCK DIGIT THREE
    0x1D7DC: '4',  # MATHEMATICAL DOUBLE-STRUCK DIGIT FOUR
    0x1D7DD: '5',  # MATHEMATICAL DOUBLE-STRUCK DIGIT FIVE
    0x1D7DE: '6',  # MATHEMATICAL DOUBLE-STRUCK DIGIT SIX
    0x1D7DF: '7',  # MATHEMATICAL DOUBLE-STRUCK DIGIT SEVEN
    0x1D7E0: '8',  # MATHEMATICAL DOUBLE-STRUCK DIGIT EIGHT
    0x1D7E1: '9',  # MATHEMATICAL DOUBLE-STRUCK DIGIT NINE
    0x1D7E4: '2',  # MATHEMATICAL SANS-SERIF DIGIT TWO
    0x1D7E5: '3',  # MATHEMATICAL SANS-SERIF DIGIT THREE
    0x1D7E6: '4',  # MATHEMATICAL SANS-SERIF DIGIT FOUR
    0x1D7E7: '5',  # MATHEMATICAL SANS-SERIF DIGIT FIVE
    0x1D7E8: '6',  # MATHEMATICAL SANS-SERIF DIGIT SIX
    0x1D7E9: '7',  # MATHEMATICAL SANS-SERIF DIGIT SEVEN
    0x1D7EA: '8',  # MATHEMATICAL SANS-SERIF DIGIT EIGHT
    0x1D7EB: '9',  # MATHEMATICAL SANS-SERIF DIGIT NINE
    0x1D7EE: '2',  # MATHEMATICAL SANS-SERIF BOLD DIGIT TWO
    0x1D7EF: '3',  # MATHEMATICAL SANS-SERIF BOLD DIGIT THREE
    0x1D7F0: '4',  # MATHEMATICAL SANS-SERIF BOLD DIGIT FOUR
    0x1D7F1: '5',  # MATHEMATICAL SANS-SERIF BOLD DIGIT FIVE
    0x1D7F2: '6',  # MATHEMATICAL SANS-SERIF BOLD DIGIT SIX
    0x1D7F3: '7',  # MATHEMATICAL SANS-SERIF BOLD DIGIT SEVEN
    0x1D7F4: '8',  # MATHEMATICAL SANS-SERIF BOLD DIGIT EIGHT
    0x1D7F5: '9',  # MATHEMATICAL SANS-SERIF BOLD DIGIT NINE
    0x1D7F8: '2',  # MATHEMATICAL MONOSPACE DIGIT TWO
    0x1D7F9: '3',  # MATHEMATICAL MONOSPACE DIGIT THREE
    0x1D7FA: '4',  # MATHEMATICAL MONOSPACE DIGIT FOUR
    0x1D7FB: '5',  # MATHEMATICAL MONOSPACE DIGIT FIVE
    0x1D7FC: '6',  # MATHEMATICAL MONOSPACE DIGIT SIX
    0x1D7FD: '7',  # MATHEMATICAL MONOSPACE DIGIT SEVEN
    0x1D7FE: '8',  # MATHEMATICAL MONOSPACE DIGIT EIGHT
    0x1D7FF: '9',  # MATHEMATICAL MONOSPACE DIGIT NINE
    0x1E2F2: '9',  # WANCHO DIGIT TWO
    0x1FBF2: '2',  # SEGMENTED DIGIT TWO
    0x1FBF3: '3',  # SEGMENTED DIGIT THREE
    0x1FBF4: '4',  # SEGMENTED DIGIT FOUR
    0x1FBF5: '5',  # SEGMENTED DIGIT FIVE
    0x1FBF6: '6',  # SEGMENTED DIGIT SIX
    0x1FBF7: '7',  # SEGMENTED DIGIT SEVEN
    0x1FBF8: '8',  # SEGMENTED DIGIT EIGHT
    0x1FBF9: '9',  # SEGMENTED DIGIT NINE
}
# By hand: the middle dot, which no skeleton maps (it is the prototype of
# others), and the lookalikes of `|`, which the skeletons map to `l`: those
# that the code charts of Unicode 18.0 draw as a bare vertical stroke, with
# no serif, foot, hook, loop or slant, and whose Identifier_Type is not
# Recommended (the owner's rule for the digits).
BY_HAND = {
    0x00B7: '.',  # MIDDLE DOT
    0x01C0: '|',  # LATIN LETTER DENTAL CLICK
    0x07CA: '|',  # NKO LETTER A
    0x16C1: '|',  # RUNIC LETTER ISAZ IS ISS I
    0x2D4F: '|',  # TIFINAGH LETTER YAN
    0xA4F2: '|',  # LISU LETTER I
    0xFE8D: '|',  # ARABIC LETTER ALEF ISOLATED FORM
    0x1028A: '|',  # LYCIAN LETTER J
    0x10309: '|',  # OLD ITALIC LETTER I
    0x10926: '|',  # LYDIAN LETTER I
    0x10C3E: '|',  # OLD TURKIC LETTER ORKHON AES
    0x10CA5: '|',  # OLD HUNGARIAN CAPITAL LETTER ESZ
    0x11DDA: '|',  # TOLONG SIKI SIGN HECAKA
    0x11DE1: '|',  # TOLONG SIKI DIGIT ONE
    0x16D63: '|',  # KIRAT RAI VOWEL SIGN AA
    0x16F28: '|',  # MIAO LETTER GHA
    0x1D5C5: '|',  # MATHEMATICAL SANS-SERIF SMALL L
    0x1D5F9: '|',  # MATHEMATICAL SANS-SERIF BOLD SMALL L
    0x1E141: '|',  # NYIAKENG PUACHUE HMONG DIGIT ONE
    0x1EE00: '|',  # ARABIC MATHEMATICAL ALEF
}
# Standard ML's punctuation and symbols: what a lookalike would forge
SML_PUNCTUATION = "!%&$#+-/:<=>?@\\~`^|*()[]{},;.'\"_"
# the code points of a block of the table of two stages
BLOCK = 128


def identifier_types(p):
    """{cp: [Identifier_Type]} of IdentifierType.txt; Not_Character where
    it lists none."""
    types = {}
    for lo, hi, f in records(p("IdentifierType.txt")):
        for c in range(lo, hi + 1):
            types[c] = f[0].split()
    return types


def skeleton_of(p):
    """The skeleton of UTS #39, section 4, of a list of code points: NFD,
    without the default ignorables, each code point mapped by
    confusables.txt, NFD again."""
    ccc, dec = unicode_data(p("UnicodeData.txt"))
    di = {c for lo, hi, f in records(p("DerivedCoreProperties.txt")) if f[0] == "Default_Ignorable_Code_Point"
          for c in range(lo, hi + 1)}
    conf = confusables(p)
    nfd = lambda cs: reorder([x for c in cs for x in full_decomposition(c, dec, False)], ccc)
    return lambda cs: nfd([y for x in nfd(cs) if x not in di for y in conf.get(x, [x])])


def confusables(p):
    """{cp: [cps]} of confusables.txt, whose sources are one code point."""
    conf = {}
    for line in open(p("confusables.txt"), encoding="utf-8"):
        line = line.split("#", 1)[0].strip()
        if line:
            src, dst = line.split(";")[:2]
            src = [int(x, 16) for x in src.split()]
            assert len(src) == 1
            conf[src[0]] = [int(x, 16) for x in dst.split()]
    return conf


def identifiers(p):
    """lib/unicode/identifier_data.sml: XID_Start, XID_Continue,
    Default_Ignorable_Code_Point, the frozen sets, and the profile they
    make as a table of two stages."""
    sets = {}
    for lo, hi, f in records(p("DerivedCoreProperties.txt")):
        if f[0] in ("XID_Start", "XID_Continue", "Default_Ignorable_Code_Point"):
            sets.setdefault(f[0], set()).update(range(lo, hi + 1))
    xs, xc, di = sets["XID_Start"], sets["XID_Continue"], sets["Default_Ignorable_Code_Point"]
    ignorable = {c for lo, hi in FROZEN_IGNORABLE for c in range(lo, hi + 1)}
    look = dict(SEEDED_PUNCTUATION)
    look.update(SEEDED_DIGITS)
    look.update(BY_HAND)
    assert len(look) == len(SEEDED_PUNCTUATION) + len(SEEDED_DIGITS) + len(BY_HAND)
    if not ignorable <= xc or not set(look) <= xc or min(look) < 0x80:
        sys.exit("a frozen code point is not XID_Continue above ASCII")
    # what the confusables give: the seed, checked while the data is that
    # it was seeded from, and shown when it is newer
    skeleton = skeleton_of(p)
    types = identifier_types(p)
    recommended = lambda c: "Recommended" in types.get(c, [])
    seed_p, seed_d, ell = {}, {}, set()
    for c in sorted(xc):
        if c < 0x80:
            continue
        s = skeleton([c])
        if len(s) == 1 and s[0] < 0x80:
            if chr(s[0]) in SML_PUNCTUATION:
                seed_p[c] = chr(s[0])
            elif chr(s[0]).isdigit() and not recommended(c):
                seed_d[c] = chr(s[0])
            elif chr(s[0]) == "l":
                ell.add(c)
    hand_ok = all((c == 0xB7 and ch == ".") or (c in ell and ch == "|" and not recommended(c))
                  for c, ch in BY_HAND.items())
    same = seed_p == SEEDED_PUNCTUATION and seed_d == SEEDED_DIGITS and hand_ok
    if VERSION == SEED_VERSION:
        if not same or ignorable != xc & di:
            sys.exit("the frozen sets are not what Unicode %s's data gives" % VERSION)
    elif not same:
        print("note: the confusables of %s would seed the lookalikes otherwise: + %s, - %s"
              % (VERSION, sorted("%04X" % c for c in set(seed_p) | set(seed_d) if c not in look),
                 sorted("%04X" % c for c in look if c not in seed_p and c not in seed_d and c not in BY_HAND)))
    excluded = ignorable | set(look)
    # the profile, a value of each code point: 0 not XID_Continue, 1
    # XID_Continue only, 2 XID_Start, 3 XID_Continue but left out
    value = lambda c: 0 if c not in xc else 3 if c in excluded else 2 if c in xs else 1
    top = max(c for c in xc if value(c) in (1, 2))
    limit = (top // BLOCK + 1) * BLOCK
    beyond = sorted(c for c in xc if c >= limit)
    assert all(value(c) == 3 for c in beyond)
    blocks, stage1 = {}, []
    for b in range(limit // BLOCK):
        t = tuple(value(b * BLOCK + i) for i in range(BLOCK))
        stage1.append(blocks.setdefault(t, len(blocks)))
    assert len(blocks) <= 256
    stage2 = "".join("%X" % (4 * t[i] + t[i + 1]) for t in sorted(blocks, key=blocks.get)
                     for i in range(0, BLOCK, 2))
    lookalikes = ranges(merge([(c, c, ord(ch)) for c, ch in look.items()]))
    data = [header2("The properties of identifiers (lib/unicode/identifier.sml): UAX #31's\n"
                    "   XID_Start and XID_Continue, the default ignorables, and the profile\n"
                    "   of docs/plans/utf8.md (D10) that leaves out the default ignorables\n"
                    "   and the lookalikes of Standard ML's punctuation and digits that\n"
                    "   scripts/gen-unicode-tables.py freezes.",
                    ["DerivedCoreProperties.txt"]),
            "structure UnicodeIdentifierData =", "struct",
            '  val version = "%s"' % VERSION, "", NUMBERS,
            "  (* The profile, as a table of two stages: the value of a code point c\n"
            "     below limit is the 2 bits at c mod block of the block numbered by\n"
            "     the two hexadecimal digits at 2 (c div block) of stage1, in stage2,\n"
            "     where each hexadecimal digit holds two values, the first in its\n"
            "     high bits. 0 is not XID_Continue, 1 XID_Continue but not\n"
            "     XID_Start, 2 XID_Start, 3 XID_Continue but left out of the profile;\n"
            "     above limit, 3 in beyond and 0 elsewhere. *)",
            "  val block = %d" % BLOCK,
            "  val limit = 0x%X" % limit, "",
            sml_string("stage1", "".join("%02X" % b for b in stage1), "the block of each %d code points" % BLOCK), "",
            sml_string("stage2", stage2, "the blocks, %d values of 2 bits each" % BLOCK), "",
            sml_numbers("beyond", ranges(spans(beyond)), "XID_Continue at or above limit: lo, hi, 1", "ranges"), "",
            sml_numbers("startLeftOut", ranges(spans(excluded & xs)),
                        "the code points left out of the profile that are XID_Start: lo, hi, 1",
                        "ranges"), "",
            sml_numbers("defaultIgnorable", ranges(spans(di)), "Default_Ignorable_Code_Point: lo, hi, 1",
                        "ranges"), "",
            sml_numbers("lookalikes", lookalikes,
                        "the lookalikes, frozen: lo, hi, the code of the ASCII character\n"
                        "     they look like", "ranges"),
            "end", ""]
    open("lib/unicode/identifier_data.sml", "w").write("\n".join(data))
    return ("XID_Start %d, XID_Continue %d, Default_Ignorable %d; frozen: ignorable %d, lookalikes %d "
            "(%d punctuation, %d digits, %d by hand); profile %d blocks of %d below 0x%X"
            % (len(xs), len(xc), len(di), len(ignorable), len(look), len(SEEDED_PUNCTUATION),
               len(SEEDED_DIGITS), len(BY_HAND), len(blocks), BLOCK, limit))


# ---- UTS #39, Unicode Security Mechanisms: identifier types, scripts,
# confusables

TYPES = ["Recommended", "Inclusion", "Limited_Use", "Technical", "Uncommon_Use", "Obsolete",
         "Exclusion", "Not_XID", "Not_NFKC", "Default_Ignorable", "Deprecated", "Not_Character"]
# UAX #31, revision 45 (Unicode 18.0.0), Table 5, Recommended Scripts
RECOMMENDED_SCRIPTS = ("Zyyy Zinh Arab Armn Beng Cyrl Deva Ethi Geor Grek Gujr Guru Hang Hani Hebr Hira "
                       "Kana Knda Khmr Laoo Latn Mlym Mymr Orya Sinh Taml Telu Thaa Thai Tibt").split()
# UTS #39, 5.1: the writing systems an augmented script set adds
AUGMENT = [("Hani", ["Hanb", "Hntl", "Jpan", "Kore"]), ("Hira", ["Jpan"]), ("Kana", ["Jpan"]),
           ("Hang", ["Kore"]), ("Bopo", ["Hanb"]), ("Latn", ["Hntl"])]


def security(p):
    """lib/unicode/security_data.sml: Identifier_Type, the augmented
    script sets, and the confusables."""
    # Identifier_Type, a set of each code point; Identifier_Status is
    # Allowed exactly where it is Recommended or Inclusion
    types = identifier_types(p)
    status = {c: f[0] for lo, hi, f in records(p("IdentifierStatus.txt")) for c in range(lo, hi + 1)}
    mask = lambda c: sum(1 << TYPES.index(t) for t in types.get(c, ["Not_Character"]))
    allowed = lambda c: mask(c) & ~3 == 0
    if any(allowed(c) != (status.get(c) == "Allowed") for c in range(0x110000)):
        sys.exit("Identifier_Status is not Allowed exactly where Identifier_Type is Recommended or Inclusion")
    masks = sorted({mask(c) for c in range(0x110000)})
    type_runs = runs(lambda c: masks.index(mask(c)))
    # the augmented script sets: Script_Extensions, or Script where it has
    # none, by short name, with the writing systems of UTS #39 added; 0
    # (all scripts) for those that hold Common or Inherited
    short = {}
    for line in open(p("PropertyValueAliases.txt"), encoding="utf-8"):
        f = [x.strip() for x in line.split("#", 1)[0].split(";")]
        if len(f) >= 3 and f[0] == "sc":
            short[f[2]] = f[1]
            for alias in f[3:]:
                short[alias] = f[1]
    script = {c: short[f[0]] for lo, hi, f in records(p("Scripts.txt")) for c in range(lo, hi + 1)}
    ext = {c: f[0].split() for lo, hi, f in records(p("ScriptExtensions.txt")) for c in range(lo, hi + 1)}
    names = sorted(set(short.values()) | {w for _, ws in AUGMENT for w in ws})
    assert all(len(n) == 4 for n in names)

    def augmented(c):
        s = set(ext.get(c, [script.get(c, "Zzzz")]))
        if "Zyyy" in s or "Zinh" in s:
            return None
        for sc, ws in AUGMENT:
            if sc in s:
                s.update(ws)
        return tuple(sorted(names.index(x) for x in s))
    script_sets = [None]
    index = {None: 0}

    def set_of(c):
        a = augmented(c)
        if a not in index:
            index[a] = len(script_sets)
            script_sets.append(a)
        return index[a]
    script_runs = runs(set_of)
    sets = [x for a in script_sets for x in ([0] if a is None else [len(a)] + list(a))]
    # the confusables: each source with the code points it maps to
    conf = confusables(p)
    table, prev = [], 0
    for c in sorted(conf):
        table += [c - prev, len(conf[c])] + conf[c]
        prev = c
    data = [header2("The data of UTS #39, Unicode Security Mechanisms\n"
                    "   (lib/unicode/security.sml): the identifier types of code points,\n"
                    "   their augmented script sets, and the confusables.",
                    ["IdentifierType.txt", "IdentifierStatus.txt", "Scripts.txt", "ScriptExtensions.txt",
                     "PropertyValueAliases.txt", "confusables.txt"]),
            "structure UnicodeSecurityData =", "struct",
            '  val version = "%s"' % VERSION, "", NUMBERS,
            "  (* Identifier_Type: a mask of the bits 1 << i of these, in order *)",
            "  val typeNames = [%s]" % ", ".join('"%s"' % t for t in TYPES), "",
            sml_numbers("typeMasks", masks, "the masks of the sets that occur"), "",
            sml_numbers("types", ranges(type_runs), "the set of each code point: lo, hi, index in typeMasks",
                        "ranges"), "",
            "  (* the short names of the scripts (ISO 15924), four characters each,\n"
            "     with Hanb, Hntl, Jpan and Kore *)",
            '  val scriptNames = "%s"' % "".join(names), "",
            "  (* the scripts of UAX #31's Table 5, Recommended Scripts, by index in\n"
            "     scriptNames *)",
            "  val recommended = [%s]" % ", ".join(str(names.index(s)) for s in RECOMMENDED_SCRIPTS), "",
            sml_numbers("scriptSets", sets,
                        "the augmented script sets that occur: the number of scripts of each\n"
                        "     and their indexes in scriptNames, in order; the first is 0, for\n"
                        "     the sets that hold Common or Inherited and stand for all scripts"), "",
            sml_numbers("scripts", ranges(script_runs),
                        "the augmented script set of each code point: lo, hi, the index of the\n"
                        "     set in scriptSets", "ranges"), "",
            sml_numbers("confusables", table,
                        "the confusables: the distance of each source from the one before, the\n"
                        "     number of code points of its prototype, and those code points"),
            "end", ""]
    open("lib/unicode/security_data.sml", "w").write("\n".join(data))
    return ("types %d sets in %d ranges; %d scripts, %d script sets in %d ranges; %d confusables"
            % (len(masks), len(type_runs), len(names), len(script_sets), len(script_runs), len(conf)))

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
    for name in TEST_DATA:
        data = open(p(name), encoding="utf-8").read()
        open("tests/lib/unicode/" + name, "w", encoding="utf-8").write(data)
    print("zero %d, control %d, wide %d ranges; break %d, pictographic %d, conjunct %d"
          % (len(merge(zero)), len(merge(control)), len(merge(wide)),
             len(merge(gcb)), len(merge(pict)), len(merge(incb))))
    print(normalization(p))
    print(identifiers(p))
    print(security(p))


if __name__ == "__main__":
    main()

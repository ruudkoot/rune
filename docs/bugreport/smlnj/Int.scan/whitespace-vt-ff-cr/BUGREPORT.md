# SML/NJ 110.99.9 and 2026.2: `StringCvt.skipWS` and the scanners do not skip a vertical tab, a form feed or a carriage return; the integer and word scanners still do not after smlnj/smlnj#447

## Status: `skipWS` reported and fixed upstream; the integer and word scanners not reported

* **`StringCvt.skipWS`:** [smlnj/smlnj#447](https://github.com/smlnj/smlnj/issues/447),
  "`StringCvt.skipWS` does not skip form feeds, returns, or vertical tabs"
  (2026-08-30), fixed by `92356f8` (`pre-basis.sml`) for 2026.3 and merged
  into smlnj/legacy by `87b5080` (2026-09-03). 110.99.9 and 2026.2 do not
  have the fix. It also fixes the scanners built on `skipWS`: `Real`,
  `Bool`, `IntInf`, `Time`.
* **The integer and word scanners:** `Int.scan`, `Int32`, `Int64`,
  `Word`, `Word8`, `Word32`, `Word64` (and `LargeWord`, `Position`) skip
  white space with a table of their own in `scan-util.sml`, which the fix
  of #447 did not touch. It is the same in smlnj/legacy at `6ed5a0a`
  (2026-09-13), as in 110.99.9, and in smlnj/smlnj at `17362d2`
  (2026-09-24). Nothing on the trackers (searched 2026-10-11).

**What is worth sending SML/NJ:** a new issue on smlnj/legacy that names
#447, with `bug.sml` and `fix.diff` (`upstream.md` is the text).

## Summary

* **The trigger:** a vertical tab (`#"\v"`), a form feed (`#"\f"`) or a
  carriage return (`#"\r"`) in front of what is scanned, e.g.
  `Int.scan StringCvt.DEC Substring.getc (Substring.full "\r1")` or
  `Word.fromString "\f1"`.
* **What goes wrong:** the scanner stops at the character and returns
  `NONE`; `StringCvt.skipWS` returns the stream unchanged. Only space, tab
  and newline are skipped. So numbers cannot be read from a file with
  CRLF line ends: `TextIO.scanStream (Int.scan StringCvt.DEC)` over
  `"1\r\n2\r\n"` gives `SOME 1` and then `NONE`, and so does `Real.scan`
  over `"1.5\r\n2.5\r\n"` (on 110.99.9 and 2026.2; after #447, `Real` is
  mended and `Int` is not).
* **Required behaviour:** the Basis specification:
  [`StringCvt.skipWS`](https://smlfamily.github.io/Basis/string-cvt.html#SIG:STRING_CVT.skipWS:VAL)
  "strips whitespace characters from a stream ... A whitespace character
  is one that satisfies the predicate `Char.isSpace`. It is equivalent to
  `dropl Char.isSpace`"; `Char.isSpace c` "returns true if c is a
  whitespace character (space, newline, tab, carriage return, vertical
  tab, formfeed)"; and
  [`INTEGER.scan`](https://smlfamily.github.io/Basis/integer.html#SIG:INTEGER.scan:VAL)
  (as `WORD.scan`) parses the number "after skipping initial whitespace".
  MLton, Poly/ML, MLKit and Rune skip all three before `Int.fromString`,
  `Word.fromString` and `Real.fromString`, and in `skipWS`.
  (`Int.fromString` of SML/NJ itself skips them: it has its own loop with
  `Char.isSpace`. `Int.scan` does not.)

## Where it happens

`bug.sml` reads `"<c>1"` (or `"<c>true"`) for each of the three characters:

| Build | wrong of 13 lines |
|---|---|
| 110.99.9, 64-bit | 13 |
| 110.99.9, 32-bit | 13 |
| 2026.2 (64-bit) | 13 |
| smlnj/legacy `6ed5a0a`, smlnj/smlnj `17362d2` (by reading the code) | the 9 lines after "through ScanUtil" |
| `fix.diff` (by reading the code, and the table checked by `fix-check.sml`) | 0 |

```
$ sml bug.sml                           # 110.99.9 (32 or 64 bits) or 2026.2
-- through StringCvt.skipWS (smlnj/smlnj#447, fixed after 110.99.9 and 2026.2)
StringCvt.skipWS: WRONG WRONG WRONG
Real.scan: WRONG WRONG WRONG
Bool.scan: WRONG WRONG WRONG
IntInf.scan: WRONG WRONG WRONG
-- through ScanUtil (not fixed)
Int.scan: WRONG WRONG WRONG
Int32.scan: WRONG WRONG WRONG
Int64.scan: WRONG WRONG WRONG
Word.scan: WRONG WRONG WRONG
Word8.scan: WRONG WRONG WRONG
Word32.scan: WRONG WRONG WRONG
Word64.scan: WRONG WRONG WRONG
Int64.fromString: WRONG WRONG WRONG
Word.fromString: WRONG WRONG WRONG
```

## The cause

There are two lists of white space in the Basis, and neither is
`Char.isSpace`'s:

* `base/system/Basis/Implementation/pre-basis.sml`, `PreBasis.skipWS`,
  which is `StringCvt.skipWS` and is used by `Bool.scan`, `Real.scan`
  (`string-to-frep.sml`), `IntInf.scan` and `Time.scan`:

  ```sml
  fun isWS (#" ") = true
    | isWS (#"\t") = true
    | isWS (#"\n") = true
    | isWS _ = false
  ```

  The fix of #447 adds `#"\v"`, `#"\f"` and `#"\r"` here.
* `base/system/Basis/Implementation/scan-util.sml`, the table `cvtTable`
  of `ScanUtil`, whose `scanPrefix` starts every scan of `NumScan64` and
  `NumScan32` (so `Int.scan`, `Int32`, `Int64`, `Word`, `Word8`, `Word32`,
  `Word64`) by skipping the characters whose code is 128, "whitespace".
  Its first row gives 128 to codes 9 and 10 only (and the third row to
  32, the space):

  ```sml
  val cvtTable = "\
	\\255\255\255\255\255\255\255\255\255\128\128\255\255\255\255\255\
  ```

  Codes 11 (`\v`), 12 (`\f`) and 13 (`\r`) are 255, "not a digit", so the
  scan stops there.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`, which has the fix of #447; it
also applies to 110.99.9, and to smlnj/smlnj with `git apply -p2`) gives
codes 11, 12 and 13 the code 128 in `cvtTable` and says so in its comment.
For 110.99.9 the fix of #447 is needed as well (`92356f8`, three lines of
`pre-basis.sml`).

The code 128 is only ever compared with `wsCode` in `scanPrefix`'s
`skipWS`. Everywhere else (`num-scan64.sml`, `num-scan32.sml`,
`int-inf.sml`, `string-to-frep.sml`) a code is compared with a digit
value or with the codes of `+`, `-`, `.`, `e`, `w` and `x`, so 128 and 255
stop a number alike.

**How it was tested:** SML/NJ was not rebuilt. `fix-check.sml` holds the
table before and after the fix, with `ScanUtil`'s `code`; on 110.99.9 (32
and 64 bits) and 2026.2 it shows that after the fix a character has the
code 128 exactly when `Char.isSpace` holds of it, and that only the
entries of `\v`, `\f` and `\r` changed.

## How Rune met it

By the laws of Rune's Basis Library documentation: each `Law:` is tested
on generated values, and `tests/basis/run-laws-hosts.py` runs them against
the Basis Library of the other compilers (`docs/plans/quickcheck-hunt.md`,
the sections on the other compilers). The law of `skipWS`
(`lib/basis/sig_string_cvt.sml`), `skipWS getc strm = dropl Char.isSpace
getc strm`, fails on SML/NJ at a vertical tab; it is the line
`native:smlnj* | STRING_CVT.skipWS/law-1@StringCvt` of
`tests/basis/law-deviations.txt`. Rune's Basis suite had found `skipWS`
before (`StringCvt.skipWS/wsx-*` in `tests/basis/deviations.txt`). The
integer and word scanners turned up while checking upstream's fix.

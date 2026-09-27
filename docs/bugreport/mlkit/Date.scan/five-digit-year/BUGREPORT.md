# MLKit 4.7.23: `Date.scan` reads a year of any number of digits, not a 24-character date

**Class 4 of 4: the specification can be read more than one way here:** it asks for "a 24-character date" in the format "precisely as produced by toString", and `toString` writes 25 characters for a year of five digits. MLton and Poly/ML read 24 characters, as this report does; SML/NJ reads the year as MLKit does.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/Date.sml` is identical to 4.7.23's.

## Summary

* **The trigger:** `Date.scan` or `Date.fromString` of a date in the
  format of `toString` followed by more digits, such as
  `"Wed Mar 08 19:06:45 19956"`.
* **What goes wrong:** the year takes every digit there is: the date is of
  the year 19956 and nothing is left, where the 24-character date is of
  1995 and `"6"` is left.
* **Required behaviour:** the
  [Basis `DATE` specification](https://smlfamily.github.io/Basis/date.html):
  "These scan a 24-character date from a character source after ignoring
  possible initial whitespace. The format of the string must be precisely
  as produced by toString"; `toString` is `fmt "%a %b %d %H:%M:%S %Y"`, 24
  characters with a year of four digits; `scan` "returns SOME(date, rest),
  where date is the scanned date and rest is the remainder of the stream".

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend.
* **System:** Linux x86-64, Ubuntu 24.04.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* "These scan a 24-character date ... The format of the string must be
   precisely as produced by toString." *)
val s = "Wed Mar 08 19:06:45 19956"
val () = print ("Date.toString of the date scanned is 24 characters: \"Wed Mar 08 19:06:45 1995\"\n")
val () =
    case Date.scan Substring.getc (Substring.full s) of
        NONE => print "Date.scan: NONE\n"
      | SOME (d, rest) =>
          print ("Date.scan \"" ^ s ^ "\" = SOME (year " ^ Int.toString (Date.year d) ^ ", rest \""
                 ^ Substring.string rest ^ "\")   (expected SOME (year 1995, rest \"6\"))\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
Date.toString of the date scanned is 24 characters: "Wed Mar 08 19:06:45 1995"
Date.scan "Wed Mar 08 19:06:45 19956" = SOME (year 19956, rest "")   (expected SOME (year 1995, rest "6"))
```

## The cause

`basis/Date.sml`, `scan`, reads the year with `digits1`, "one or more
digits" (line 312):

```sml
	val (hour, src4)  = digits 2 (expect #" " src3)
	val (min, src5)   = digits 2 (expect #":" src4)
	val (sec, src6)   = digits 2 (expect #":" src5)
	val (year, src7)  = digits1 (expect #" " src6)
```

## The fix

Read four digits, as `toString` writes them (`digits n` reads exactly `n`
and fails otherwise):

```diff
--- a/basis/Date.sml
+++ b/basis/Date.sml
@@ fun scan getc src =
-	val (year, src7)  = digits1 (expect #" " src6)
+	(* a 24-character date: the year has four digits *)
+	val (year, src7)  = digits 4 (expect #" " src6)
```

`digits1` is then unused. Tested in a copy of `basis/Date.sml` with this
patch (and those of the other `Date` reports), shadowing `Date`, in a
program built with MLKit 4.7.23: all 93 checks of Rune's
`tests/basis/date_fmt.sml` pass, among them `Date.scan/24-characters` and
the checks that read back what `toString` wrote. The patch of the library
itself was not built.

## Relation to Rune

The check `Date.scan/24-characters` of `tests/basis/date_fmt.sml` fails on
MLKit with "got SOME (19956-Mar-8 19:6:45, ""), expected SOME
(1995-Mar-8 19:6:45, "6")". SML/NJ does the same (`HOST-BUG` line of
`tests/basis/deviations.txt`). Proposed line:

```
native:mlkit@* | Date.scan/24-characters | HOST-BUG | scan reads a year of five digits (19956), not the 24-character date ("scan a 24-character date")
```

# MLKit 4.7.23: `Date.date` raises `Overflow`, not `Date`, for a date it cannot represent

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** MLton and SML/NJ (110.99.9 and 2026.2) raise `Overflow` too, for the year `valOf Int.maxInt` (2^31 - 1 on MLton) and for the day `valOf Int.maxInt`; Poly/ML raises `Overflow` for the day, and had not finished with the year after 20 seconds.

## Status

Not reported upstream from here. MLKit `master` at `5bffdc3` (2026-10-09)
has the same code: `basis/Date.sml` is identical to 4.7.23's. A search of
MLKit's issues and pull requests (`Date`, `Overflow`, 2026-10-11) found no
report of it.

## Summary

* **The trigger:** `Date.date` of a date whose number of days since the
  year 1 does not fit in an `int`: on 1 January, the year
  12,626,108,195,557,532 or later (`valOf Int.maxInt` among them; the year
  before still works), or a day, hour, minute or second large
  enough to carry the date there (`day = valOf Int.maxInt`), with any
  offset or none.
* **What goes wrong:** `Date.date` raises `Overflow`. A year below 0 does
  raise `Date`.
* **Required behaviour:** the
  [Basis `DATE` specification](https://smlfamily.github.io/Basis/date.html),
  of `date`: "creates a canonical date from the given date information. If
  the resulting date is outside the range supported by the implementation,
  the Date exception is raised." (The specification asks for "around 1900
  to 2200" and lets an implementation go further; MLKit does, up to a year
  of about 1.26 * 10^16, and should raise `Date` beyond.)

## Environment

* **MLKit:** v4.7.23 ("MLKit v4.7.23 (v4.7.23 - 2026-09-24T12:26:51+02:00)
  [X64 Backend]"), the official binary release `mlkit-bin-dist-linux.tgz`
  (`Int.precision = SOME 63`).
* **System:** Linux x86-64, Ubuntu 24.04 under WSL2 (kernel 6.18), glibc
  2.39, `TZ` unset with `/etc/localtime` Europe/London (the output is the
  same with `TZ=UTC`).
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml` (`yearOf (2000, maxInt, utc)` is the date of the day `maxInt`
of January 2000, that is 2000-01-01 and `maxInt - 1` days):

```sml
(* "If the resulting date is outside the range supported by the
   implementation, the Date exception is raised." *)
fun try (what, f) =
    print (what ^ " = " ^ (f () handle Date.Date => "Date.Date" | e => "raised " ^ General.exnName e) ^ "\n")
fun yearOf (y : int, d : int, off) =
    Int.toString (Date.year (Date.date {year = y, month = Date.Jan, day = d, hour = 0, minute = 0,
                                        second = 0, offset = off}))
val utc = SOME Time.zeroTime
val maxInt = valOf Int.maxInt
val () = print ("Int.maxInt = " ^ Int.toString maxInt ^ "\n")
val () = try ("year of 12600000000000000-01-01 UTC   ", fn () => yearOf (12600000000000000, 1, utc))
val () = try ("year of 12700000000000000-01-01 UTC   ", fn () => yearOf (12700000000000000, 1, utc))
val () = try ("year of maxInt-01-01 UTC              ", fn () => yearOf (maxInt, 1, utc))
val () = try ("year of maxInt-01-01 local            ", fn () => yearOf (maxInt, 1, NONE))
val () = try ("year of 2000-01-01 + maxInt - 1 days  ", fn () => yearOf (2000, maxInt, utc))
val () = try ("year of ~1-01-01 UTC                  ", fn () => yearOf (~1, 1, utc))
```

```
$ mlkit -o bug bug.mlb && ./bug
Int.maxInt = 4611686018427387903
year of 12600000000000000-01-01 UTC    = 12600000000000000
year of 12700000000000000-01-01 UTC    = raised Overflow
year of maxInt-01-01 UTC               = raised Overflow
year of maxInt-01-01 local             = raised Overflow
year of 2000-01-01 + maxInt - 1 days   = raised Overflow
year of ~1-01-01 UTC                   = Date.Date
```

The second to fifth lines should be `Date.Date` (or a date, for an
implementation that can represent it).

## The cause

`basis/Date.sml`, `date` (line 343), refuses only a negative year, and
then normalises the fields:

```sml
    fun date { year, month, day, hour, minute, second, offset } =
	if year < 0 then raise Date
	else
	    let val (dayoffset, offset') =
	    ...
		val day' = day + dayoffset
	    in
		normalizedate year month day' hour minute second offset'
	    end
```

`normalizedate` (line 172) counts the days from the year 1 with
`todaynumber` (line 129), in `int`:

```sml
    fun todaynumber year month day =
        let val prioryears = year - 1
	in
	    dayinyear year month day
	  + 1
	  + 365 * prioryears
	  + prioryears div 4
          - prioryears div 100
          + prioryears div 400
	end
```

For a year past about `maxInt / 365.2425` (1.26 * 10^16), or a day near
`maxInt`, the sum overflows and the `Overflow` of the arithmetic leaves
`date`; so can the carries of `normalizedate` (`mn0 + sec0 div 60`,
`hr0 + mn1 div 60`) for a huge minute or second.

## The fix

Take a date whose day number does not fit in an `int` as outside the range
(`fix.patch`):

```diff
--- a/basis/Date.sml
+++ b/basis/Date.sml
@@ -340,9 +340,12 @@
 	    fn _ => EQUAL))))))
 	end
 
+    (* "If the resulting date is outside the range supported by the
+       implementation, the Date exception is raised": a date whose day
+       number does not fit in an int is outside it. *)
     fun date { year, month, day, hour, minute, second, offset } =
-	if year < 0 then raise Date
-	else
+	(if year < 0 then raise Date
+	 else
 	    let val (dayoffset, offset') =
 	        case offset of
 		    NONE      => (0, NONE)
@@ -354,7 +357,8 @@
 		val day' = day + dayoffset
 	    in
 		normalizedate year month day' hour minute second offset'
-	    end
+	    end)
+	handle Overflow => raise Date
 
     fun year (DATE { year, ... }) = year
 
```

(The handler also catches the `Overflow` that `Time.toSeconds` of the
offset raises in 4.7.23 for an offset of 2^31 seconds or more, which the
specification takes modulo 24 hours; that is the report
`Time.toSeconds/beyond-2^31-seconds`, fixed on `master`, after which
`Time.toSeconds` of any `Time.time` fits in an `int`.)

**Tested:** `fix.patch` applied to a copy of the library of the installed
MLKit 4.7.23 (`lib/mlkit`), with `SML_LIB` pointing at the copy, so that
`mlkit` recompiled `Date.sml` and what depends on it. `bug.sml` then
prints `Date.Date` on the second to fifth lines and the same as before on
the others. A program that checks the law below for the years `2^k - 1`
and `2^k` (`k` from 0 to 61) and `maxInt`, on 1 January at 00:00:00 and on
31 December at 23:59:59, at UTC and local (500 dates), finds 432 that keep
their year and 68 that raise `Overflow` without the patch, and 432 that
keep their year and 68 that raise `Date` with it. The compiler itself was
not rebuilt, nor `master`.

## How it was found

By the laws of Rune's Basis Library documentation: each `Law:` of
`lib/basis/*.sml` is tested on generated values, and
`tests/basis/run-laws-hosts.py` runs them against MLKit's own Basis
Library (`docs/plans/quickcheck-hunt.md`, the sections on the other
compilers). The laws of `Date.year` and its five sisters in
`lib/basis/sig_date.sml` say that a date of fields in range keeps them or
raises `Date`: `(year (date r) = #year r) handle Date => true`, and the
same for `month`, `day`, `hour`, `minute` and `second`, run for `r` from
`DateArb.fieldsInRange (valOf Int.minInt, valOf Int.maxInt)`. On MLKit
they fail with `Overflow` for a large year. The line of
`tests/basis/law-deviations.txt`:

```
native:mlkit | DATE.year/law-*@Date | HOST-BUG | Date.date raises Overflow for a year it cannot represent, where the specification asks for Date
```

and MLton has the same line.

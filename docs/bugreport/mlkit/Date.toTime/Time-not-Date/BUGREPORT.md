# MLKit 4.7.23: `Date.toTime` raises `Time`, not `Date`, for a date it cannot convert

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** Poly/ML raises `Time` too; SML/NJ converts the date, and MLton raises `Overflow`.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/Date.sml` is identical to 4.7.23's.

## Summary

* **The trigger:** `Date.toTime d` for a date whose time `Time.fromReal`
  cannot make: a date of the year 100000000 (10^8 years of seconds, times
  10^6 microseconds, exceed 63 bits), and in 4.7.23 every date after
  2038-01-19 03:14:07 UTC (see the report
  `Time.toSeconds/beyond-2^31-seconds`).
* **What goes wrong:** the exception `Time.Time` of `Time.fromReal` leaves
  `toTime`.
* **Required behaviour:** the
  [Basis `DATE` specification](https://smlfamily.github.io/Basis/date.html):
  "toTime date returns the (UTC) time corresponding to the date date. It
  raises Date if the date date cannot be represented as a Time.time value."

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend.
* **System:** Linux x86-64, Ubuntu 24.04 (glibc 2.39, 64-bit `time_t`),
  `TZ='NST3:30NDT,M3.2.0,M11.1.0'` (the same in `TZ=UTC`).
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* "It raises Date if the date date cannot be represented as a Time.time value." *)
fun utc y = Date.date {year = y, month = Date.Jan, day = 1, hour = 0, minute = 0, second = 0, offset = SOME Time.zeroTime}
fun try (what, f) =
    print (what ^ ": " ^ ((f (); "no exception") handle Date.Date => "Date.Date"
                                                       | Time.Time => "Time.Time"
                                                       | e => General.exnName e) ^ "\n")
val () = try ("Date.toTime of 100000000-01-01 00:00:00 UTC (expected Date.Date or a time)", fn () => Date.toTime (utc 100000000))
val () = try ("Date.toTime of 2100-01-01 00:00:00 UTC (expected a time)", fn () => Date.toTime (utc 2100))
```

```
$ mlkit -o bug bug.mlb && TZ='NST3:30NDT,M3.2.0,M11.1.0' ./bug
Date.toTime of 100000000-01-01 00:00:00 UTC (expected Date.Date or a time): Time.Time
Date.toTime of 2100-01-01 00:00:00 UTC (expected a time): Time.Time
```

## The cause

`basis/Date.sml`, `toTime` (line 218), ends with

```sml
	in
	    if clock < 0.0 then raise Date
	    else Time.fromReal clock
	end;
```

and `Time.fromReal` (`basis/Time.sml`) raises `Time` when the real does
not fit: `fromMicro (Int.toLarge (Real.round (r * 1000000.0))) handle
Overflow => raise Time`.

## The fix

Turn `Time` (and `Overflow`) into `Date`:

```diff
--- a/basis/Date.sml
+++ b/basis/Date.sml
@@ fun toTime (date as DATE {offset, ...}) =
 	in
 	    if clock < 0.0 then raise Date
 	    else Time.fromReal clock
-	end;
+	end
+	handle Time.Time => raise Date
+	     | Overflow => raise Date;
```

The report `Date.toTime/before-1970` rewrites `toTime` with this handler
in it; that version was tested as a copy of `basis/Date.sml` shadowing
`Date` in a program built with MLKit 4.7.23: `toTime` of the year 10^8
raises `Date`, and the check below passes. The patch of the library itself
was not built.

## Relation to Rune

The check `Date.toTime/Date-or-a-year-far-away` of `tests/basis/date.sml`
(the date of the year 10^8, or `Date`) fails on MLKit with "raised an
exception, expected true". Poly/ML has the same fault (`HOST-BUG` line of
`tests/basis/deviations.txt`). Proposed line:

```
native:mlkit@* | Date.toTime/Date-or-a-year-far-away | HOST-BUG | toTime of a date of year 10^8 raises Time, not Date ("It raises Date if the date date cannot be represented as a Time.time value")
```

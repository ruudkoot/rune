# MLKit 4.7.23: `Date.toTime` raises `Date` for every date before 1970, and `fromTimeUniv` truncates negative times

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** MLton and SML/NJ also raise `Date` for a date before 1970, and MLton's `fromTimeUniv` also truncates; Poly/ML meets it. How `fromTimeUniv` rounds a fraction of a second is not written down.

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/Date.sml` and `src/Runtime/Time.c` are identical
to 4.7.23's.

## Summary

* **The trigger:** `Date.toTime d` for a date `d` before 1970-01-01 00:00:00
  UTC (1969-12-31 23:59:59 UTC, 1950, 1900, ...); `Date.fromTimeUniv t` or
  `Date.fromTimeLocal t` for a `t` before 1970 that is not a whole number of
  seconds.
* **What goes wrong:** `toTime` raises `Date`; `fromTimeUniv (Time.fromReal
  ~0.5)` is 1970-01-01 00:00:00, not 1969-12-31 23:59:59 (the time is
  truncated towards zero, not floored, to a second).
* **Required behaviour:** the
  [Basis `DATE` specification](https://smlfamily.github.io/Basis/date.html):
  "A conforming Date structure should support date values ranging from
  around 1900 to 2200"; `toTime` "returns the (UTC) time corresponding to
  the date date. It raises Date if the date date cannot be represented as a
  Time.time value" -- MLKit's `Time.time` holds negative times (seconds of
  either sign, `basis/Time.sml`); `fromTimeUniv` "returns the date in the
  UTC time zone", which for a time half a second before 1970 is in
  1969.

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend.
* **System:** Linux x86-64, Ubuntu 24.04 (glibc 2.39, 64-bit `time_t`),
  `TZ='NST3:30NDT,M3.2.0,M11.1.0'` (the results are the same in `TZ=UTC`).
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* "A conforming Date structure should support date values ranging from
   around 1900 to 2200". *)
fun utc (y, m, d, h, mi, s) =
    Date.date {year = y, month = m, day = d, hour = h, minute = mi, second = s, offset = SOME Time.zeroTime}
fun try (what, f) =
    print (what ^ " = " ^ (f () handle Date.Date => "Date.Date" | Time.Time => "Time.Time") ^ "\n")
fun secs d = IntInf.toString (Time.toSeconds (Date.toTime d))
val () = try ("Date.toTime 1970-01-01 00:00:00 UTC", fn () => secs (utc (1970, Date.Jan, 1, 0, 0, 0)))
val () = try ("Date.toTime 1969-12-31 23:59:59 UTC", fn () => secs (utc (1969, Date.Dec, 31, 23, 59, 59)) ^ "   (expected ~1)")
val () = try ("Date.toTime 1950-01-01 00:00:00 UTC", fn () => secs (utc (1950, Date.Jan, 1, 0, 0, 0)) ^ "   (expected ~631152000)")
(* the date of a time is that of the second it falls in *)
val () = try ("Date.fromTimeUniv (Time.fromReal ~0.5)", fn () =>
               Date.fmt "%Y-%m-%d %H:%M:%S" (Date.fromTimeUniv (Time.fromReal ~0.5)) ^ "   (expected 1969-12-31 23:59:59)")
```

```
$ mlkit -o bug bug.mlb && TZ='NST3:30NDT,M3.2.0,M11.1.0' ./bug
Date.toTime 1970-01-01 00:00:00 UTC = 0
Date.toTime 1969-12-31 23:59:59 UTC = Date.Date
Date.toTime 1950-01-01 00:00:00 UTC = Date.Date
Date.fromTimeUniv (Time.fromReal ~0.5) = 1970-01-01 00:00:00   (expected 1969-12-31 23:59:59)
```

## The cause

`basis/Date.sml`, `toTime` (line 218), refuses a negative clock:

```sml
    fun toTime (date as DATE {offset, ...}) =
	let val secoffset =
	    case offset of
		NONE      => 0.0
	      | SOME secs => localoffset + real secs
	    val clock = mktime_ (dateToTmoz date) - secoffset
	in
	    if clock < 0.0 then raise Date
	    else Time.fromReal clock
	end;
```

With a 64-bit `time_t`, `mktime` converts dates long before 1970 (to
negative clocks), and `okDate` already keeps the year at 1900 or later.

`fromTimeUniv` and `fromTimeLocal` (line 209) pass `Time.toReal t` to
`sml_gmtime` and `sml_localtime` of `src/Runtime/Time.c`, which convert it
with a cast, truncating towards zero:

```c
  time_t clock = (long)(get_d(r));
  gmtime_r(&clock,&tmr);
```

A date with an offset goes through `mktime`, that is through the local time
zone, and back with `localoffset`, the offset of the local zone when the
program started. Where the zone's standard offset has changed, the two do
not cancel: with `TZ=Europe/Moscow` (UTC+4 in 2012, UTC+3 now) `toTime` of
2012-06-01 00:00:00 UTC is 1338505200, an hour early (1338508800 is right).
The fix below avoids `mktime` for such dates.

## The fix

Convert a date with an offset by the calendar (`todaynumber` is already in
`Date.sml`), keep `mktime` for local dates without refusing a negative
clock, and floor the time in `fromTime*`:

```diff
--- a/basis/Date.sml
+++ b/basis/Date.sml
@@
+    (* the runtime converts the real to time_t by truncation: the date
+       of a time is that of the second it falls in, so it is floored *)
     fun fromTimeLocal t =
-	tmozToDate (getlocaltime_ (Time.toReal t)) NONE;
+	tmozToDate (getlocaltime_ (Real.realFloor (Time.toReal t))) NONE;
 
     fun fromTimeUniv t =
-	tmozToDate (getunivtime_ (Time.toReal t)) (SOME 0);
+	tmozToDate (getunivtime_ (Real.realFloor (Time.toReal t))) (SOME 0);
@@
-    fun toTime (date as DATE {offset, ...}) =
-	let val secoffset =
-	    case offset of
-		NONE      => 0.0
-	      | SOME secs => localoffset + real secs
-	    val clock = mktime_ (dateToTmoz date) - secoffset
-	in
-	    if clock < 0.0 then raise Date
-	    else Time.fromReal clock
-	end;
+    (* A date at an offset is converted by the calendar, which has no
+       limits of its own; a local date by mktime, which gives a negative
+       clock for a date before 1970.  A time that Time cannot hold is
+       Date, not Time. *)
+    fun toTime (date as DATE {year, month, day, hour, minute, second, offset, ...}) =
+	(case offset of
+	     SOME east =>
+	       let val days = todaynumber year month day - todaynumber 1970 Jan 1
+	       in Time.fromSeconds (Int.toLarge (((days * 24 + hour) * 60 + minute) * 60
+	                                         + second - east))
+	       end
+	   | NONE => Time.fromReal (mktime_ (dateToTmoz date)))
+	handle Time.Time => raise Date
+	     | Overflow => raise Date;
```

(`offset` is kept in seconds east of UTC, so the time is the local reading
minus it.) Tested as a copy of `basis/Date.sml` with this patch and those
of the reports `Date.offset/east-of-UTC`, `Date.fmt/Z-tm_zone-unset` and
`Date.scan/five-digit-year`, shadowing `Date`, in programs built with MLKit
4.7.23 and run in Rune's time zone: all 93 checks of Rune's
`tests/basis/date_fmt.sml` pass, and of the 132 of `tests/basis/date.sml`
all but four, which need times beyond 32 bits of seconds (the report
`Time.toSeconds/beyond-2^31-seconds`); with a copy of `Time` that has that
fix too, all 132 pass. The patch of the library itself was not built.

## Relation to Rune

These checks of `tests/basis/date.sml` fail on MLKit because `toTime` of a
date before 1970 raises `Date`: `Date.toTime/last-second-of-1969`,
`Date.toTime/century-from-1900`, `Date.toTime/1900-to-2200` (which also
needs times after 2038), `Date.fromTimeUniv/fraction-of-a-second-1969`
(which, once `toTime` works, also shows the truncation) and
`Date.fromTimeUniv/calendar-1900-2199` (which converts a date of 1900 to
start with). MLton has the same limit (`HOST-BUG` lines of
`tests/basis/deviations.txt`). Proposed lines:

```
native:mlkit@* | Date.toTime/*19[06][09]* | HOST-BUG | toTime of a date before 1970 raises Date ("support date values ranging from around 1900 to 2200"), and of one after 2038-01-19 03:14:07 UTC raises Time
native:mlkit@* | Date.fromTimeUniv/*19[06][09]* | HOST-BUG | toTime of a date before 1970 raises Date, and fromTimeUniv truncates a negative time towards zero instead of flooring it to its second
```

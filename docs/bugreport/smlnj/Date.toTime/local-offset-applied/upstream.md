# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `Date.toTime` of a date with an offset depends on the local time zone (smlnj/smlnj#452, not fixed in legacy), and raises `Date` for 1970-01-01 00:00:00 UTC east of UTC

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Linux |
| OS Version | Ubuntu 24.04 (WSL2) |
| Processor | Any |
| System Component | Basis Library |
| Severity | Major |
| Also present in the "development" version? | Partly: #452 is fixed there (`4419268`), but `toTime` still reads the fields as a local time, so the `Date` cases remain |

### Description

`Date.toTime` of a date with an offset (every date from `fromTimeUniv`, for
one) converts its fields with `mktime`, as a local time, and then:

* adds the local offset where it should subtract it, so the result is off
  by twice the local offset (in Chicago 10 or 12 hours late, in London 2
  hours early in summer); this is smlnj/smlnj#452;
* ignores the date's own offset (12:00 at 5 hours west is taken for 12:00
  UTC);
* raises `Date` when the fields, read as a local time, are before the
  epoch, because the runtime's `mkTime` refuses a negative `time_t`. In
  London (UTC+1 all through 1970) that makes
  `Date.toTime (Date.fromTimeUniv Time.zeroTime)` raise `Date`; in Tokyo,
  every UTC date in the first 9 hours of 1970; in every zone, a UTC date
  before 1970.

Also, `Date.date` with an offset of a day or more adds the whole days as
seconds: 12:00 at 25 hours west becomes 12:00:01 at 1 hour west.

The development version fixed the first, second and last with #452
(`4419268`); legacy `main` (`6ed5a0a`) still has the code of 110.99.9.
The fix of #452 keeps `mktime`, so the `Date` cases remain there too (and a
UTC date in the hour the local clock skips in spring comes out an hour
late).

The specification: `toTime date` "returns the (UTC) time corresponding to
the date `date`. It raises `Date` if the date `date` cannot be represented
as a `Time.time` value"; an offset `SOME t` "corresponds to time t west of
UTC".

### Transcript

```
$ TZ=Europe/London sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
toTime (fromTimeUniv zeroTime) = Date, expected 0: WRONG
toTime 1970-01-01 01:00:00 UTC = ~3600, expected 3600: WRONG
toTime 2000-01-01 12:30:45 UTC = 946729845, expected 946729845: ok
toTime 2000-07-01 12:30:45 UTC = 962447445, expected 962454645: WRONG
toTime 2000-01-01 12:00:00 5 hours west = 946728000, expected 946746000: WRONG
toTime 1969-12-31 23:00:00 UTC = Date, expected ~3600: WRONG
toTime 2000-01-01 12:00:00 25 hours west = 946728001, expected 946818000: WRONG
$ TZ=America/Chicago sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
toTime (fromTimeUniv zeroTime) = 43200, expected 0: WRONG
toTime 1970-01-01 01:00:00 UTC = 46800, expected 3600: WRONG
toTime 2000-01-01 12:30:45 UTC = 946773045, expected 946729845: WRONG
toTime 2000-07-01 12:30:45 UTC = 962490645, expected 962454645: WRONG
toTime 2000-01-01 12:00:00 5 hours west = 946771200, expected 946746000: WRONG
toTime 1969-12-31 23:00:00 UTC = 39600, expected ~3600: WRONG
toTime 2000-01-01 12:00:00 25 hours west = 946771201, expected 946818000: WRONG
```

The 32-bit build and 2026.2 print the same. With `TZ=UTC` the last three
lines are wrong.

### Expected Behavior

The expected value of each line, in every time zone. Poly/ML prints `ok`
throughout.

### Steps to Reproduce

```sml
(* Date.toTime of dates with an offset: "toTime date returns the (UTC) time
   corresponding to the date date. It raises Date if the date date cannot be
   represented as a Time.time value"; an offset SOME t "corresponds to time t
   west of UTC". The answers do not depend on the local time zone, so run it
   in a few: TZ=Europe/London sml bug.sml, TZ=America/Chicago, TZ=UTC. *)
fun show (name, d, expected) =
      let val got = (IntInf.toString (Time.toSeconds (Date.toTime (d ()))))
                      handle Date.Date => "Date" | Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
fun at offset ((year, month, day), (hour, minute, second)) () =
      Date.date {year = year, month = month, day = day, hour = hour, minute = minute,
                 second = second, offset = SOME offset}
val utc = at Time.zeroTime
val hours = Time.fromSeconds o (fn h => h * 3600)
val () = show ("toTime (fromTimeUniv zeroTime)", fn () => Date.fromTimeUniv Time.zeroTime, "0")
val () = show ("toTime 1970-01-01 01:00:00 UTC", utc ((1970, Date.Jan, 1), (1, 0, 0)), "3600")
val () = show ("toTime 2000-01-01 12:30:45 UTC", utc ((2000, Date.Jan, 1), (12, 30, 45)), "946729845")
val () = show ("toTime 2000-07-01 12:30:45 UTC", utc ((2000, Date.Jul, 1), (12, 30, 45)), "962454645")
val () = show ("toTime 2000-01-01 12:00:00 5 hours west", at (hours 5) ((2000, Date.Jan, 1), (12, 0, 0)), "946746000")
val () = show ("toTime 1969-12-31 23:00:00 UTC", utc ((1969, Date.Dec, 31), (23, 0, 0)), "~3600")
val () = show ("toTime 2000-01-01 12:00:00 25 hours west", at (hours 25) ((2000, Date.Jan, 1), (12, 0, 0)), "946818000")
val () = OS.Process.exit OS.Process.success
```

### Additional Information

The patch converts a date with an offset by the calendar, with
`toAbsoluteDay`, which `date.sml` already has: the days since 1970-01-01,
the hours, minutes and seconds, plus the offset. The local zone and
`mktime` have no part in it, so the result is right in every zone, and a
date before 1970 gives a negative time. A date without an offset still goes
through `mktime`. The change to `date` is #452's. It is against legacy
`main` (`6ed5a0a`) and also applies to 110.99.9:

```diff
diff --git a/base/system/Basis/Implementation/date.sml b/base/system/Basis/Implementation/date.sml
index fa8b640..3d31439 100644
--- a/base/system/Basis/Implementation/date.sml
+++ b/base/system/Basis/Implementation/date.sml
@@ -315,6 +315,8 @@ structure Date : DATE =
 	    hour = hour, minute = minute, second = second
 	  } end
 
+    val secsPerDay : IntInf.int = 24*60*60
+
     fun date {year, month, day, hour, minute, second, offset} = let
 	  val (secAdjust, offset) = (case offset
 		 of NONE => (0, NONE)
@@ -323,7 +325,8 @@ structure Date : DATE =
                        * it is necessary to use "quot/rem" so that we round toward
                        * zero when `t` is negative!
                        *)
-		      val (adjust, offset) = IntInf.quotRem(Time.toSeconds t, 24*60*60)
+		      val (adjust, offset) = IntInf.quotRem(Time.toSeconds t, secsPerDay)
+                      val adjust = adjust * secsPerDay
 		      in
 			(Int.fromLarge adjust, SOME(Time.fromSeconds offset))
 		      end
@@ -356,20 +359,23 @@ structure Date : DATE =
     fun fromTimeUniv t = tm2date (gmTime t, SOME Time.zeroTime)
 
   (* return the UTC time corresponding to the given date. *)
-    fun toTime (date as DATE{offset, ...}) = let
-	  val t = mkTime' (date2tm date)
-	  in
-	    case offset
-	     of NONE => nsToTime t
-	      | SOME offset =>
-		(* note that representation of a date is canonical, which means that the
-		 * offset has already been applied, so we do not need to adjust by the
-		 * date's offset.  On the other hand, mkTime' returns the _local_ time,
-		 * so we do need to adjust for the local offset.
-		 *)
-		  Time.+(nsToTime t, localOffsetForTime t)  (* converts local time to UTC *)
-	    (* end case *)
-	  end
+    fun toTime (date as DATE{year, month, day, hour, minute, second, offset, ...}) = (
+	  case offset
+	   of NONE => nsToTime (mkTime' (date2tm date))
+	    | SOME offset => let
+	      (* a date at an offset is converted by the calendar: the local time zone
+	       * has no part in it, and mkTime' would refuse a date that is before the
+	       * epoch in the local time zone.  The offset is west of UTC, so it is
+	       * added to the time of the fields read as UTC.
+	       *)
+		val days = toAbsoluteDay {year = year, month = monthToInt month + 1, day = day}
+		      - toAbsoluteDay {year = 1970, month = 1, day = 1}
+		val secs = ((Int.toLarge days * 24 + Int.toLarge hour) * 60
+		      + Int.toLarge minute) * 60 + Int.toLarge second
+		in
+		  Time.+(Time.fromSeconds secs, offset)
+		end
+	  (* end case *))
 
   (* date comparison does not take into account the offset
    * thus, it does not compare dates in different time zones
```

Not built: `date` and `toTime` as patched, copied into a standalone program
with the calendar functions of `date.sml`, give every expected value of
`bug.sml` in `Europe/London`, `America/Chicago`, `Asia/Tokyo` and `UTC`, on
110.99.9 (32 and 64 bits) and 2026.2; `toTime (fromTimeUniv t) = t` for
100,000 random `t` from 1970 to 2106; and in `UTC` they agree with the
current `toTime` of the same fields without an offset for 100,000 random
dates from 1970 to 2200.

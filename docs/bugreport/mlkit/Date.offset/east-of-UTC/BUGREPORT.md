# MLKit 4.7.23: `Date.offset` reports zones east of UTC as west, and `Date.date` gets offsets beyond 12 hours wrong

## Status

Not reported upstream from here. MLKit `master` at `c49fbea` (2026-09-25)
has the same code: `basis/Date.sml` is identical to 4.7.23's.

## Summary

* **The trigger:** `Date.date {..., offset = SOME t}` with `t` negative (a
  zone east of UTC), or with `|t|` of more than 12 hours; `Date.offset` of
  such a date.
* **What goes wrong:** two mistakes in how `Date.sml` keeps the offset (in
  seconds east of UTC):
  1. `Date.offset` reports `(86400 - east) mod 86400`, a number of seconds
     in [0, 86400): a zone 5:30 east (`~19800`) is reported as 18:30 west
     (`66600`).
  2. `Date.date` moves the date by the whole days of `t` (`quot (t,
     86400)`) but keeps as offset `~t` when `t <= 12 h` and `86400 - t`
     otherwise. For `t` of 25 hours east (`~90000`) the date moves a day
     back *and* the whole 25 hours stay in the offset, so the date is a day
     early; for `t` between 12 and 24 hours west (13 hours, `46800`) the
     offset turns into 11 hours east without the date moving, and the date
     is a day late. (`offset` then reports `82800` for the first and, by
     the modulo of 1., the right `46800` for the second.)
* **Required behaviour:** the
  [Basis `DATE` specification](https://smlfamily.github.io/Basis/date.html):
  "A value of SOME(t) corresponds to time t west of UTC. ... Negative
  offsets denote time zones to the east of UTC, as is traditional. Offsets
  are taken modulo 24 hours. That is, we express t, in hours, as
  sgn(t)(24*d + r), where d and r are non-negative, d is integral, and r <
  24. The offset then becomes sgn(t)*r and sgn(t)(24*d) is added to the
  hours (before converting hours to days)." And "The value returned by
  offset reports time zone information as the amount of time west of UTC."
  So 5:30 east stays `~19800`, 25 hours east becomes 1 hour east (`~3600`)
  a day earlier, and 13 hours west stays 13 hours west.

## Environment

* **MLKit:** v4.7.23, the official binary release `mlkit-bin-dist-linux.tgz`,
  X64 backend.
* **System:** Linux x86-64, Ubuntu 24.04, `TZ='NST3:30NDT,M3.2.0,M11.1.0'`
  (the local zone plays no part: every date here has an offset).
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* "A value of SOME(t) corresponds to time t west of UTC. ... Negative offsets
   denote time zones to the east of UTC ... Offsets are taken modulo 24 hours.
   That is, we express t, in hours, as sgn(t)(24*d + r) ... The offset then
   becomes sgn(t)*r and sgn(t)(24*d) is added to the hours" *)
fun at (h, west) = Date.date {year = 2000, month = Date.Jan, day = 1, hour = h, minute = 0, second = 0,
                              offset = SOME (Time.fromSeconds (IntInf.fromInt west))}
val utcMidnight = Date.date {year = 2000, month = Date.Jan, day = 1, hour = 0, minute = 0, second = 0,
                             offset = SOME Time.zeroTime}
fun offsetOf d = case Date.offset d of SOME t => IntInf.toString (Time.toSeconds t) | NONE => "NONE"
fun fields d = Date.fmt "%Y-%m-%d %H:%M:%S" d
fun since d = IntInf.toString (Time.toSeconds (Time.- (Date.toTime d, Date.toTime utcMidnight)))
fun show (what, h, west, expOffset, expSince) =
    let val d = at (h, west)
    in print (what ^ ": fields " ^ fields d ^ ", offset " ^ offsetOf d ^ " (expected " ^ expOffset
              ^ "), seconds after 2000-01-01 00:00 UTC " ^ since d ^ " (expected " ^ expSince ^ ")\n")
    end
val () = show ("12:00 at  5 h west (18000)  ", 12, 18000, "18000", "61200")
val () = show ("12:00 at 5:30 h east (~19800)", 12, ~19800, "~19800", "23400")
val () = show ("00:00 at 25 h west (90000)  ", 0, 90000, "3600", "90000")
val () = show ("00:00 at 25 h east (~90000) ", 0, ~90000, "~3600", "~90000")
val () = show ("12:00 at 13 h west (46800)  ", 12, 46800, "46800", "90000")
```

```
$ mlkit -o bug bug.mlb && TZ='NST3:30NDT,M3.2.0,M11.1.0' ./bug
12:00 at  5 h west (18000)  : fields 2000-01-01 12:00:00, offset 18000 (expected 18000), seconds after 2000-01-01 00:00 UTC 61200 (expected 61200)
12:00 at 5:30 h east (~19800): fields 2000-01-01 12:00:00, offset 66600 (expected ~19800), seconds after 2000-01-01 00:00 UTC 23400 (expected 23400)
00:00 at 25 h west (90000)  : fields 2000-01-02 00:00:00, offset 3600 (expected 3600), seconds after 2000-01-01 00:00 UTC 90000 (expected 90000)
00:00 at 25 h east (~90000) : fields 1999-12-31 00:00:00, offset 82800 (expected ~3600), seconds after 2000-01-01 00:00 UTC ~176400 (expected ~90000)
12:00 at 13 h west (46800)  : fields 2000-01-01 12:00:00, offset 46800 (expected 46800), seconds after 2000-01-01 00:00 UTC 3600 (expected 90000)
```

## The cause

`basis/Date.sml` keeps the offset as "signed seconds East of UTC: this
zone = UTC+t; ~43200 < t <= 43200" (the comment of the datatype). `date`
(line 343) computes it as

```sml
		  | SOME time =>
			let val secs      = LargeInt.toInt(Time.toSeconds time)
			    val secoffset =
				if secs <= 43200 then ~secs else 86400 - secs
			in (Int.quot(secs, 86400), SOME secoffset) end
		val day' = day + dayoffset
```

which reduces neither an offset of more than a day east nor keeps one of
12 to 24 hours west, while the whole days (`Int.quot (secs, 86400)`) are
added to the day in every case. `offset` (line 379) reports

```sml
    fun offset (DATE { offset, ... }) =
	Option.map (fn secs => Time.fromSeconds (LargeInt.fromInt((86400 - secs) mod 86400)))
	           offset
```

which is never negative. (`toTime` converts with the stored seconds east,
so its result is right exactly when the stored offset is.)

## The fix

Keep `sgn(t) * r` (in seconds east, `~ (rem (t, 86400))`) and report it
with its sign:

```diff
--- a/basis/Date.sml
+++ b/basis/Date.sml
@@
 	offset : int option			(* signed seconds East of UTC: this
-					       zone = UTC+t; ~43200 < t <= 43200 *)
+					       zone = UTC+t; ~86400 < t < 86400 *)
@@ fun date { year, month, day, hour, minute, second, offset } =
 		  | SOME time =>
-			let val secs      = LargeInt.toInt(Time.toSeconds time)
-			    val secoffset =
-				if secs <= 43200 then ~secs else 86400 - secs
-			in (Int.quot(secs, 86400), SOME secoffset) end
+			(* t = sgn(t)(24*d + r) hours: the offset becomes
+			   sgn(t)*r and sgn(t)*d days are added; quot and rem
+			   keep the sign of t.  It is kept in seconds east. *)
+			let val secs = LargeInt.toInt(Time.toSeconds time)
+			in (Int.quot(secs, 86400), SOME (~(Int.rem(secs, 86400)))) end
@@
     (* The offset is kept in seconds east of UTC; it is reported in
-       seconds west of UTC, within one day. *)
+       seconds west of UTC, negative to the east. *)
     fun offset (DATE { offset, ... }) =
-	Option.map (fn secs => Time.fromSeconds (LargeInt.fromInt((86400 - secs) mod 86400)))
-	           offset
+	Option.map (fn secs => Time.fromSeconds (LargeInt.fromInt (~secs))) offset
```

Tested as a copy of `basis/Date.sml` with this patch and those of the
reports `Date.toTime/before-1970`, `Date.fmt/Z-tm_zone-unset` and
`Date.scan/five-digit-year`, shadowing `Date`, in programs built with MLKit
4.7.23: every offset check of Rune's `tests/basis/date.sml` passes (all 132
checks pass with a copy of `Time` that has the fix of
`Time.toSeconds/beyond-2^31-seconds`), and all 93 of
`tests/basis/date_fmt.sml`. The patch of the library itself was not built.

## Relation to Rune

These checks of `tests/basis/date.sml` fail on MLKit:
`Date.offset/east` ("got SOME 66600s, expected SOME ~19800s"),
`Date.offset/modulo-24-hours-negative` ("got SOME 82800s, expected SOME
~3600s") and `Date.toTime/offset-modulo-24-hours-negative-is-the-same-time`
("got ~176400, expected ~90000"). The suite has no check of an offset
between 12 and 24 hours. MLton reports offsets modulo a day as well
(`HOST-BUG` line of `tests/basis/deviations.txt`). Proposed lines:

```
native:mlkit@* | Date.offset/east | HOST-BUG | offset reports the time west of UTC modulo a day, never negative: 5:30 east gives 18:30 west (66600 s)
native:mlkit@* | Date.offset/modulo-24-hours-negative | HOST-BUG | date keeps an offset of more than a day east whole while it moves the date back a day, and offset reports it modulo a day (82800 s)
native:mlkit@* | Date.toTime/offset-modulo-24-hours-negative-is-the-same-time | HOST-BUG | date keeps an offset of more than a day east whole while it moves the date back a day, so that the date is a day earlier than the time given
```

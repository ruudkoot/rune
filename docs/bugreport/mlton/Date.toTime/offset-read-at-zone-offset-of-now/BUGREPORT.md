# MLton 20241230: `Date.toTime` of a UTC date depends on the local time zone, so `toTime (fromTimeUniv Time.zeroTime)` raises `Date` in Europe/London

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (SML/NJ 110.99.9 and 2026.2, Poly/ML 5.9.2 and MLKit 4.7.23) does the same.** MLKit, whose `Date.sml` MLton's is modified from, gives exactly MLton's results. SML/NJ is wrong in another way, by a fixed amount at every date. Poly/ML converts every date correctly.

## Status

Not reported upstream from here. MLton's tracker has no matching issue or
pull request: searching the issues and the pull requests of MLton/mlton
for `Date.toTime`, `toTime`, `Date`, `fromTimeUniv`, `timezone`,
`time zone`, `mktime` and `localOffset` (on 2026-10-11) found only
[#499](https://github.com/MLton/mlton/issues/499). That issue is about the
sign of `Date.localOffset ()` east of Greenwich, was fixed by pull request
#505 (2023, in 20241230), and is not about `toTime`.

MLton's `master` at `5fe943391` (2026-10-03) has the same `toTime`. With
`master`'s `date.sml` in place of 20241230's, the program below gives the
same results. There is also a regression on `master`
that is not in 20241230. Pull request #654 ("Fix bug with `offset`
interpretation in `Date.date`", merged 2026-09-18) changed `date` to store a
date's offset as seconds *west* of UTC, but `toTime` still treats it as
seconds east. On `master`, `toTime` of every date at a non-zero offset is
therefore off by twice the offset. For example, in `TZ=UTC`, `toTime` of
2000-01-01 00:00 at `SOME (Time.fromSeconds 3600)` (one hour west) is
946681200, where 946688400 is right; 20241230 gives 946688400. Built from
`master`'s `date.sml`, Rune's `tests/basis/date.sml` fails five
`Date.toTime/offset-*` checks and `Date.date/offset-of-the-local-zone`, all
of which pass with 20241230's. The fix below has a variant for `master`
(`fix-master.patch`) that mends both.

## Summary

* **The trigger:** `Date.toTime d` for a date `d` at an offset (`offset d`
  is `SOME _`, as for every date of `Date.fromTimeUniv` and every
  `Date.date` with `offset = SOME _`), when the local time zone's offset
  from UTC on the date `d` differs from its offset now. In Europe/London,
  this machine's zone, that is every date from 1968-10-27 to 1971-10-31.
  The UK kept its clocks at UTC+1 all year then ("British Standard Time"),
  and the zone database records this as standard time (`isdst=0`,
  `gmtoff=3600`). In Europe/Moscow it is, for example, every date from
  2011-03-27 to 2014-10-26, when the zone kept UTC+4 as standard time (it is
  UTC+3 now).
* **What goes wrong:** `toTime` is off by the difference: an hour early in
  these two zones. In London, `toTime (fromTimeUniv Time.zeroTime)` would be
  `~3600`, which MLton's `toTime` refuses (it raises `Date` for every time
  before 1970). So the epoch raises `Date`, and
  `toTime (fromTimeUniv (Time.fromSeconds 86400))` is 82800. With `TZ=UTC`
  the results are right. The offset `SOME 0` of a `fromTimeUniv` date is not
  ignored: it is subtracted correctly. What is wrong is the local offset
  `toTime` subtracts with it, which is the zone's offset *now*.
* **Required behaviour:** the
  [Basis `DATE` specification](https://smlfamily.github.io/Basis/date.html#SIG:DATE.toTime:VAL):
  "toTime date returns the (UTC) time corresponding to the date date. It
  raises Date if the date date cannot be represented as a Time.time value."
  On the offset: "A value of SOME(t) corresponds to time t west of UTC. In
  particular, SOME(Time.zeroTime) is UTC". On `fromTimeUniv`: it "returns
  the date in the UTC time zone; ... The returned date will have
  offset=SOME(0)." The UTC time of 1970-01-01 00:00:00 UTC is 0, whatever
  the local zone is, and MLton's `Time.time` can represent it.

## Environment

* **MLton:** 20241230, the official binary release (`mlton` prints
  "MLton 20241230").
* **System:** Linux x86-64, Ubuntu 24.04 on WSL2 (kernel
  6.18.33.2-microsoft-standard-WSL2), glibc 2.39. `TZ` is unset and
  `/etc/localtime` is Europe/London. The program was also run with
  `TZ=UTC` and `TZ=Europe/Moscow`, on 2026-10-11.
* **Basis Library: MLton's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlton bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* toTime of a date at UTC (offset SOME 0) is the UTC time of that date,
   whatever the local time zone is. *)
fun secs t = LargeInt.toString (Time.toSeconds t)
fun show (what, f) = print (what ^ " = " ^ (f () handle Date.Date => "raised Date") ^ "\n")
fun utc (y, m, d) =
    Date.date {year = y, month = m, day = d, hour = 0, minute = 0, second = 0,
               offset = SOME Time.zeroTime}
val () = show ("toTime (fromTimeUniv Time.zeroTime)       (expected 0)",
               fn () => secs (Date.toTime (Date.fromTimeUniv Time.zeroTime)))
val () = show ("toTime (fromTimeUniv (fromSeconds 86400)) (expected 86400)",
               fn () => secs (Date.toTime (Date.fromTimeUniv (Time.fromSeconds 86400))))
val () = show ("toTime of 1971-06-01 00:00:00 UTC         (expected 44582400)",
               fn () => secs (Date.toTime (utc (1971, Date.Jun, 1))))
val () = show ("toTime of 1972-06-01 00:00:00 UTC         (expected 76204800)",
               fn () => secs (Date.toTime (utc (1972, Date.Jun, 1))))
val () = show ("toTime of 2012-06-01 00:00:00 UTC         (expected 1338508800)",
               fn () => secs (Date.toTime (utc (2012, Date.Jun, 1))))
```

```
$ mlton bug.mlb && ./bug
toTime (fromTimeUniv Time.zeroTime)       (expected 0) = raised Date
toTime (fromTimeUniv (fromSeconds 86400)) (expected 86400) = 82800
toTime of 1971-06-01 00:00:00 UTC         (expected 44582400) = 44578800
toTime of 1972-06-01 00:00:00 UTC         (expected 76204800) = 76204800
toTime of 2012-06-01 00:00:00 UTC         (expected 1338508800) = 1338508800
$ TZ=UTC ./bug
toTime (fromTimeUniv Time.zeroTime)       (expected 0) = 0
toTime (fromTimeUniv (fromSeconds 86400)) (expected 86400) = 86400
toTime of 1971-06-01 00:00:00 UTC         (expected 44582400) = 44582400
toTime of 1972-06-01 00:00:00 UTC         (expected 76204800) = 76204800
toTime of 2012-06-01 00:00:00 UTC         (expected 1338508800) = 1338508800
$ TZ=Europe/Moscow ./bug
toTime (fromTimeUniv Time.zeroTime)       (expected 0) = 0
toTime (fromTimeUniv (fromSeconds 86400)) (expected 86400) = 86400
toTime of 1971-06-01 00:00:00 UTC         (expected 44582400) = 44582400
toTime of 1972-06-01 00:00:00 UTC         (expected 76204800) = 76204800
toTime of 2012-06-01 00:00:00 UTC         (expected 1338508800) = 1338505200
```

In London the dates of 1970 and 1971 are an hour early, and 1972 is right.
In Moscow, 2012 is an hour early. In UTC everything is right. (The
expected values are those of Python's `calendar.timegm`.)

## The other implementations

The same `bug.sml`, run on each of them in Europe/London, `TZ=UTC` and
Europe/Moscow:

* **Poly/ML 5.9.2** (`use "bug.sml";`): the expected value on every line,
  in all three zones.
* **MLKit 4.7.23** (`mlkit -o bug bug.mlb`): exactly MLton's output, in all
  three zones. The report `docs/bugreport/mlkit/Date.toTime/before-1970`
  describes MLKit's `toTime`, which has the same fault.
* **SML/NJ 110.99.9 (64 bits) and SML/NJ 2026.2** (`use "bug.sml";`): right
  in `TZ=UTC`. In London `raised Date`, then 79200, 44575200, 76197600 and
  1338501600, two hours early at every date. In Moscow it is six hours early
  at every date. That is a different fault.
* **Rune** (`bin/rune bug.sml -o bug.rbc && bin/runevm bug.rbc`): the
  expected value on every line, in all three zones.

## The cause

`basis-library/system/date.sml`, `toTime` (line 291):

```sml
    (* The following implements conversion from a local date to 
     * a Time.time.  It IGNORES wday and yday.
     *)

    fun toTime (date as T {offset, ...}) = 
        let
           val secoffset = 
              case offset of
                 NONE      => 0
               | SOME secs => localoffset () + secs
            val clock = C_Time.toInt (mktime_ (dateToTmoz date)) - secoffset
        in
            if clock < 0 then raise Date
            else Time.fromSeconds clock
        end
```

and `localoffset` (line 104):

```sml
    (* The offset to add to local time to get UTC: positive West of UTC *)
    fun localoffset () : int = C_Double.round (Prim.localOffset ())
```

which is `Date_localOffset` of `runtime/basis/System/Date.c` (line 33):

```c
C_Double_t Date_localOffset(void) {
  time_t t1, t2;

  t1 = time(NULL);
  t2 = mktime(gmtime(&t1));
  return difftime(t2, t1);
}
```

A date at an offset is converted in three steps. Its fields are read as a
*local* time by `mktime`. `tm_isdst` is 0, because `fromTimeUniv` and `date`
make such dates with `isDst = SOME false`, so `mktime` reads them in the
zone's standard time *on that date*. The local zone's offset is then taken
off again, as `localoffset ()`. Last, the date's own offset (`secs`) is taken
off: 20241230's `date` stores that offset in seconds east of UTC.
`localoffset ()` comes from the current time, `time(NULL)`, read back
through `mktime` with `tm_isdst` 0, so it is the zone's standard offset
*now*. The two local offsets cancel only when the zone's standard offset on
the date is the one it has now.

In Europe/London it is 0 now, while on 1970-01-01 it was one hour east. So
`mktime` gives `~3600` for 1970-01-01 00:00:00, `localoffset ()` is 0, and
`clock` is `~3600 - 0 - 0`, which the `clock < 0` check turns into `Date`.
For 1970-01-02 the same hour gives 82800. MLton refuses a negative clock
for every date before 1970, which Rune's suite records separately
(`Date.toTime/last-second-of-1969` in `tests/basis/deviations.txt`). That
check is why the hour becomes an exception at the epoch rather than a wrong
time.

## The fix

Convert a date at an offset by the calendar, which `date.sml` already has
(`todaynumber`). Only a local date (offset `NONE`) goes through `mktime`.
This is `fix.patch`:

```diff
--- a/basis-library/system/date.sml
+++ b/basis-library/system/date.sml
@@ -284,17 +284,32 @@
     fun fromTimeUniv t = 
         tmozToDate (getgmtime_ (C_Time.fromInt (Time.toSeconds t))) (SOME 0)
 
-    (* The following implements conversion from a local date to 
-     * a Time.time.  It IGNORES wday and yday.
+    (* The following implements conversion from a date to a Time.time.
+     * It IGNORES wday and yday.  A local date (offset NONE) is converted
+     * by mktime.  A date at an offset is converted by the calendar: mktime
+     * would read it in the local time zone, at the zone's offset on that
+     * date, which need not be its offset now, localoffset ().
      *)
 
-    fun toTime (date as T {offset, ...}) = 
+    fun toTime (date as T {year, month, day, hour, minute, second,
+                           offset, ...}) =
         let
-           val secoffset = 
-              case offset of
-                 NONE      => 0
-               | SOME secs => localoffset () + secs
-            val clock = C_Time.toInt (mktime_ (dateToTmoz date)) - secoffset
+            val clock =
+               case offset of
+                  NONE => C_Time.toInt (mktime_ (dateToTmoz date))
+                | SOME secs =>
+                     if not (okDate date)
+                        then raise Date
+                     else
+                        let
+                           val days =
+                              todaynumber year month day
+                              - todaynumber 1970 Jan 1
+                        in
+                           (* secs is seconds East of UTC *)
+                           ((days * 24 + hour) * 60 + minute) * 60 + second
+                           - secs
+                        end
         in
             if clock < 0 then raise Date
             else Time.fromSeconds clock
```

`localoffset` is then used only by `Date.localOffset`. The patch keeps
MLton's present limits: `Date` for a time before 1970 (the `clock < 0`
check, unchanged), and `Overflow` for a time after 2038-01-19 03:14:07 UTC,
which is where the `int` arithmetic now overflows instead of
`C_Time.toInt` (the report `Date.date/Overflow-not-Date` mentions it).

**For `master`:** after #654, `date` stores the offset in seconds west of
UTC, so the time is the reading *plus* it. `fix-master.patch` (a diff
against `master`'s `date.sml` at `5fe943391`) is the same change with
`+ secs` and the comment "secs is seconds West of UTC". It also mends the
regression of #654 described under Status.

**How it was tested.** MLton compiles its Basis Library from source into
every program, so the fix was built without rebuilding MLton. The installed
library (`lib/mlton/sml/basis`, identical to `basis-library` of the 20241230
sources) was copied with the patch applied and used with
`mlton -mlb-path-var 'SML_LIB <copy>'`:

* `bug.sml` gives the expected value on every line in Europe/London, `UTC`,
  Europe/Moscow, America/New_York and Asia/Kolkata.
* 5,000 random dates were drawn from 1969 to 2038, at random offsets
  between a day east and a day west, and one in four at UTC. The patched
  `toTime` of each in Europe/London and in Europe/Moscow is the same as the
  unpatched `toTime` under `TZ=UTC` (where `localoffset ()` and `mktime`
  agree), down to the dates that raise `Date`.
* `toTime (fromTimeUniv t) = t` was checked at every 3599 seconds from 0 to
  2^31 - 3600, in Europe/London, with no mismatch. The unpatched library
  fails at 16,039 of these times, every one from the epoch up to
  1971-10-31.
* Rune's `tests/basis/date.sml` (133 checks) and `tests/basis/date_fmt.sml`
  (93 checks), built with the patches of all four MLton reports of this
  directory, have no failure that the unpatched library does not have. This
  was checked in `TZ=NST3:30NDT,M3.2.0,M11.1.0` (the zone of Rune's test
  matrix) and in Europe/London.

`fix-master.patch` was tested the same way, on a copy of the library with
`master`'s `date.sml` (#654) in it. `bug.sml` is right in London and
Moscow, and the stepped `toTime (fromTimeUniv t)` check passes. `toTime` of
2000-01-01 00:00 at offsets of ±1 hour, ±5:30 and ±25 hours is right in
`UTC` and in London. Rune's `tests/basis/date.sml` goes from 17 failures
(`master`'s `date.sml`) to 10. The seven that pass are the checks named
under Status, and `Date.toTime/offset-modulo-24-hours-negative-is-the-same-time`,
which 20241230 also fails (for a date more than a day east of UTC, a fault
of 20241230's `date` that #654 mended). The rest of `master` was not built.

## How it was found

By the laws of Rune's Basis Library documentation: each `Law:` in
`lib/basis` is tested on generated values. The laws were run against MLton's
own Basis Library with `tests/basis/run-laws-hosts.py` (see the sections on
the other compilers in `docs/plans/quickcheck-hunt.md`). The law of
`fromTimeUniv` in `lib/basis/sig_date.sml`:

```
Law: `toTime (fromTimeUniv t) = Time.fromSeconds (Time.toSeconds t)` for
`Time.>= (t, Time.zeroTime)`
```

`DATE.fromTimeUniv/law-1` at `Date` failed on MLton (as on SML/NJ and
MLKit) at `t = Time.zeroTime`, with `Date`. The line of
`tests/basis/law-deviations.txt`:

```
native:mlton | DATE.fromTimeUniv/law-1@Date | HOST-BUG | Date.toTime (Date.fromTimeUniv Time.zeroTime) raises Date, where Poly/ML and Rune give the epoch
```

The law runner runs the programs in the machine's zone, Europe/London.
Rune's Basis Library suite (`tests/basis/run-matrix.sh`) sets
`TZ='NST3:30NDT,M3.2.0,M11.1.0'`, a zone without history, where the
standard offset never changes, so the suite had not met this. The
explanation above, and the time zone dependence, come from probing for this
report.

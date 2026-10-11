# SML/NJ 110.99.9 and 2026.2: `Date.toTime` of a date with an offset goes through the local time zone: off by twice the local offset, the date's own offset ignored, and `Date` for the epoch east of UTC

## Status: partly fixed in the new series (smlnj/smlnj#452), not in 110.x; the rest not reported

* **What is fixed:** [smlnj/smlnj#452](https://github.com/smlnj/smlnj/issues/452),
  "`Date.fromTimeUniv o Date.toTime` adds 12 hours to the date"
  (2026-08-30), fixed by commit `4419268` of smlnj/smlnj (2026-09-01),
  first in `v2026.3-beta`: `toTime` now subtracts the local offset and adds
  the date's own, and `Date.date` adds the whole days of an offset of a day
  or more as days (it added them as seconds). 2026.2 does not have it.
* **110.x:** smlnj/legacy at `6ed5a0a` (2026-09-13) has the same
  `date.sml` as 110.99.9; `87b5080`, which merged other fixes from the
  development repository, did not take this one.
* **What is left in both:** `toTime` still converts the date's fields as a
  *local* time with `mktime`, and the runtime refuses a negative result.
  So in a zone east of UTC the first hours of 1970 (UTC) raise `Date`,
  `toTime (fromTimeUniv Time.zeroTime)` among them, and in every zone a
  UTC date before 1970 does. A UTC date in the hour that the local clock
  skips in spring comes out an hour late. These were found by computing
  2026.3's formula with 110.99.9's own `mktime` (below); no 2026.3 build
  was run. Nothing on the trackers (searched 2026-10-11); the open
  [smlnj/smlnj#435](https://github.com/smlnj/smlnj/issues/435) is about
  the same unsigned runtime interface, from the side of `fromTimeUniv`.

**What is worth sending SML/NJ:** a new issue on smlnj/legacy that names
#452, with `bug.sml` and `fix.diff`, which ports #452's change to `date`
and converts a date with an offset by the calendar (`upstream.md` is the
text). The development version would want the `toTime` half too.

## Is it a bug, or the time zone?

The law that found it, `toTime (fromTimeUniv t) = t`, failed at
`t = Time.zeroTime` on a machine whose zone is `Europe/London`. In 1970 the
United Kingdom was on British Standard Time, UTC+1 all year (October 1968
to October 1971). So the zone matters, but only because `toTime` uses it
for a date that says it is in UTC: with `TZ=UTC` the law holds at 0; in
`Europe/London` it raises `Date` there and is 2 hours off at every `t` in
summer time; in `America/Chicago` it is 10 or 12 hours off at every `t`
(#452). The specification leaves the local zone no part: `toTime date`
"returns the (UTC) time corresponding to the date
`date`. It raises `Date` if the date `date` cannot be represented as a
`Time.time` value", and a `SOME t` offset "corresponds to time t west of
UTC" ([`DATE`](https://smlfamily.github.io/Basis/date.html#SIG:DATE.toTime:VAL)).
1970-01-01 00:00:00 UTC is `Time.zeroTime`. So it is a bug, and the time
zone only decides where it shows.

## Summary

* **The trigger:** `Date.toTime d` where `d` has an offset (`SOME`), for
  example any date from `Date.fromTimeUniv`, where the local zone is not at
  UTC on that date; and in UTC too for a date at another offset or before
  1970.
* **What goes wrong** (110.99.9 and 2026.2):
  - the result is off by twice the local zone's offset, the wrong way: in
    `Europe/London` a UTC date in summer is 2 hours early, in
    `America/Chicago` 10 or 12 hours late (#452);
  - the date's own offset is ignored: 12:00 at 5 hours west is taken for
    12:00 UTC;
  - `Date` is raised when the date's fields, read as a local time, are
    before the epoch: 1970-01-01 00:00:00 UTC in `Europe/London`, the
    first 9 hours of 1970 in `Asia/Tokyo`, and 1969-12-31 23:00:00 UTC
    everywhere, `TZ=UTC` included;
  - `Date.date` with an offset of a day or more moves the date by seconds,
    not days: 12:00 at 25 hours west becomes 12:00:01 at 1 hour west.
* **Required behaviour:** as quoted above. Poly/ML and Rune print `ok` on
  every line of `bug.sml`, in `Europe/London` and in `America/Chicago`.
  MLton raises `Date` before 1970, and in `Europe/London` at the epoch too;
  MLKit raises `Date` before 1970 (its report
  `docs/bugreport/mlkit/Date.toTime/before-1970`).

## Where it happens

`bug.sml` gives `toTime` seven dates with an offset. The results are the
same on all three builds:

| Time zone | 110.99.9, 64-bit | 110.99.9, 32-bit | 2026.2 | 2026.3's formula (computed, first six lines) | `fix.diff`, as a standalone copy |
|---|---|---|---|---|---|
| `Europe/London` (the machine's) | 6 of 7 | 6 | 6 | 2 (`Date` at 0 and before 1970) | 0 |
| `America/Chicago` | 7 | 7 | 7 | 0 | 0 |
| `Asia/Tokyo` | 7 | 7 | 7 | 3 (`Date` in the first hours of 1970 and before) | 0 |
| `UTC` | 3 | 3 | 3 | 1 (`Date` before 1970) | 0 |

```
$ TZ=Europe/London sml bug.sml          # 110.99.9 (32 or 64 bits) or 2026.2
toTime (fromTimeUniv zeroTime) = Date, expected 0: WRONG
toTime 1970-01-01 01:00:00 UTC = ~3600, expected 3600: WRONG
toTime 2000-01-01 12:30:45 UTC = 946729845, expected 946729845: ok
toTime 2000-07-01 12:30:45 UTC = 962447445, expected 962454645: WRONG
toTime 2000-01-01 12:00:00 5 hours west = 946728000, expected 946746000: WRONG
toTime 1969-12-31 23:00:00 UTC = Date, expected ~3600: WRONG
toTime 2000-01-01 12:00:00 25 hours west = 946728001, expected 946818000: WRONG

$ TZ=America/Chicago sml bug.sml
toTime (fromTimeUniv zeroTime) = 43200, expected 0: WRONG
toTime 1970-01-01 01:00:00 UTC = 46800, expected 3600: WRONG
toTime 2000-01-01 12:30:45 UTC = 946773045, expected 946729845: WRONG
toTime 2000-07-01 12:30:45 UTC = 962490645, expected 962454645: WRONG
toTime 2000-01-01 12:00:00 5 hours west = 946771200, expected 946746000: WRONG
toTime 1969-12-31 23:00:00 UTC = 39600, expected ~3600: WRONG
toTime 2000-01-01 12:00:00 25 hours west = 946771201, expected 946818000: WRONG

$ TZ=UTC sml bug.sml
toTime (fromTimeUniv zeroTime) = 0, expected 0: ok
toTime 1970-01-01 01:00:00 UTC = 3600, expected 3600: ok
toTime 2000-01-01 12:30:45 UTC = 946729845, expected 946729845: ok
toTime 2000-07-01 12:30:45 UTC = 962454645, expected 962454645: ok
toTime 2000-01-01 12:00:00 5 hours west = 946728000, expected 946746000: WRONG
toTime 1969-12-31 23:00:00 UTC = Date, expected ~3600: WRONG
toTime 2000-01-01 12:00:00 25 hours west = 946728001, expected 946818000: WRONG
```

## The cause

`base/system/Basis/Implementation/date.sml`:

```sml
    fun toTime (date as DATE{offset, ...}) = let
	  val t = mkTime' (date2tm date)
	  in
	    case offset
	     of NONE => nsToTime t
	      | SOME offset =>
		(* note that representation of a date is canonical, which means that the
		 * offset has already been applied, so we do not need to adjust by the
		 * date's offset.  On the other hand, mkTime' returns the _local_ time,
		 * so we do need to adjust for the local offset.
		 *)
		  Time.+(nsToTime t, localOffsetForTime t)  (* converts local time to UTC *)
	    (* end case *)
	  end
```

* **Twice the local offset.** `mkTime'` is `mktime`: it reads the fields
  `F` as a local time and returns `F + off` seconds, where `off` is the
  local offset, west of UTC (`localOffset ()` is `~3600` in London summer
  time). The time of the fields as UTC is `F = t - off`; the code computes
  `t + off = F + 2 * off`.
* **The date's offset.** The representation is not canonical in that
  sense: `Date.date` keeps the fields as given and stores the offset, so
  `toTime` must add it, and does not.
* **`Date`.** The runtime's `mktime` (`runtime/c-libs/smlnj-date/mktime.c`)
  raises an error for a negative `time_t`, as its result goes back to SML
  as an unsigned `Word64` (#435), and `wrap` turns the error into `Date`.
  For a UTC date the negative time is the date's fields read in the local
  zone: in London 1970-01-01 00:00:00 is 1969-12-31 23:00:00 UTC.
* **`Date.date`:** `IntInf.quotRem (Time.toSeconds t, 24*60*60)` gives
  whole days, which are then added to the seconds.

2026.3 (`4419268`) computes `t - off + offset` and multiplies the days by
86,400, which mends the first, second and fourth. It still calls `mkTime'`
on the fields, so the third remains; and where the fields fall in the hour
that the local clock skips, `mktime` moves them, `off` is that of summer
time, and the result is an hour late. Computed with 110.99.9's own
`mktime` and offsets in `Europe/London` (the program is not included):
`Date` for `fromTimeUniv zeroTime` and for 1969-12-31 23:00:00 UTC, and
1774751400 for 2026-03-29 01:30:00 UTC, where 1774747800 is right.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9):

* **`toTime` of a date with an offset is computed by the calendar**, with
  `toAbsoluteDay`, which `date.sml` already has: the days since
  1970-01-01, the hours, minutes and seconds, plus the offset. The local
  zone and `mktime` have no part in it, so the result is right in every
  zone and for dates before 1970 (a negative `Time.time`, which SML/NJ's
  `Time` holds). A date without an offset still goes through `mktime`.
* **`Date.date`**: #452's change, verbatim: the whole days of the offset
  are added as `days * 86400` seconds.

**How it was tested:** SML/NJ was not rebuilt. `fix-check.sml` holds
`date.sml`'s calendar functions, `date` and `toTime` as `fix.diff` leaves
them, copied into a standalone program (a date without an offset, which
needs the runtime, left out). On 110.99.9 (32 and 64 bits) and 2026.2, in
`Europe/London`, `America/Chicago`, `Asia/Tokyo` and `UTC`:
* every line of `bug.sml` is right;
* `toTime (fromTimeUniv t) = t` for 100,000 random `t` from 1970 to 2106
  (to 2038 on the 32-bit build, whose `time_t` has 32 bits);
* a date at an offset from -47 to 47 hours is the time of its fields as
  UTC plus the offset, for 100,000 random dates from 1900 to 2200;
* in `UTC`, it agrees with SML/NJ's own `toTime` of the same fields
  without an offset for 100,000 random dates from 1970 to 2200 (2037).

## How Rune met it

By the laws of Rune's Basis Library documentation: each `Law:` is tested
on generated values, and `tests/basis/run-laws-hosts.py` runs them against
the Basis Library of the other compilers (`docs/plans/quickcheck-hunt.md`,
the sections on the other compilers). The law of `fromTimeUniv`
(`lib/basis/sig_date.sml`), `toTime (fromTimeUniv t) = Time.fromSeconds
(Time.toSeconds t)` for `t >= Time.zeroTime`, fails on SML/NJ at
`Time.zeroTime` in the machine's zone, `Europe/London`; it is the line
`native:smlnj* | DATE.fromTimeUniv/law-1@Date` of
`tests/basis/law-deviations.txt` (MLton and MLKit have the same line). Rune's Basis suite, run in a zone of its
own, had seen the parts before: `Date.toTime/*inverts-fromTimeUniv*`,
`Date.toTime/offset-*`, `Date.fromTimeUniv/*` and the lines on dates before
1970 in `tests/basis/deviations.txt`.

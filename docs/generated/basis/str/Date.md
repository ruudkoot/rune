# structure Date

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; [Structures](../structures.md) &rsaquo; **Date**

|  |  |
| --- | --- |
| Signature | [`DATE`](../sig/DATE.md) |
| Status | required |
| Members | 24 |
| Tests | 209 checks |
| Source | [lib/basis/date.sml](../../../../lib/basis/date.sml) |

## Synopsis

```sml
structure Date : DATE
```

Date: a moment as a person writes it down.

## Members

What each means is on [`DATE`](../sig/DATE.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`date`](../sig/DATE.md#val-date) | *a type of its own* |
| datatype | [`month`](../sig/DATE.md#val-month) | `Jan` &#124; `Feb` &#124; `Mar` &#124; `Apr` &#124; `May` &#124; `Jun` &#124; `Jul` &#124; `Aug` &#124; `Sep` &#124; `Oct` &#124; `Nov` &#124; `Dec` |
| datatype | [`weekday`](../sig/DATE.md#type-weekday) | `Mon` &#124; `Tue` &#124; `Wed` &#124; `Thu` &#124; `Fri` &#124; `Sat` &#124; `Sun` |
| exception | [`Date`](../sig/DATE.md#exn-date) |  |
| val | [`compare`](../sig/DATE.md#val-compare) | `date * date -> order` |
| val | [`date`](../sig/DATE.md#val-date) | `{day : int, hour : int, minute : int, month : month, offset : Time.time option, second : int, year : int} -> date` |
| val | [`day`](../sig/DATE.md#val-day) | `date -> int` |
| val | [`fmt`](../sig/DATE.md#val-fmt) | `string -> date -> string` |
| val | [`fromString`](../sig/DATE.md#val-fromstring) | `string -> date option` |
| val | [`fromTimeLocal`](../sig/DATE.md#val-fromtimelocal) | `Time.time -> date` |
| val | [`fromTimeUniv`](../sig/DATE.md#val-fromtimeuniv) | `Time.time -> date` |
| val | [`hour`](../sig/DATE.md#val-hour) | `date -> int` |
| val | [`isDst`](../sig/DATE.md#val-isdst) | `date -> bool option` |
| val | [`localOffset`](../sig/DATE.md#val-localoffset) | `unit -> Time.time` |
| val | [`minute`](../sig/DATE.md#val-minute) | `date -> int` |
| val | [`month`](../sig/DATE.md#val-month) | `date -> month` |
| val | [`offset`](../sig/DATE.md#val-offset) | `date -> Time.time option` |
| val | [`scan`](../sig/DATE.md#val-scan) | `('a -> (char * 'a) option) -> 'a -> (date * 'a) option` |
| val | [`second`](../sig/DATE.md#val-second) | `date -> int` |
| val | [`toString`](../sig/DATE.md#val-tostring) | `date -> string` |
| val | [`toTime`](../sig/DATE.md#val-totime) | `date -> Time.time` |
| val | [`weekDay`](../sig/DATE.md#val-weekday) | `date -> weekday` |
| val | [`year`](../sig/DATE.md#val-year) | `date -> int` |
| val | [`yearDay`](../sig/DATE.md#val-yearday) | `date -> int` |

## Notes

### compare

> **Reading** `Date.compare/ignores-the-offset`. The fields are compared as
> they are written: two dates that name the same moment in different zones
> do not compare equal, and one written later in its own zone is the
> greater.

### date

> **Reading** `Date.date/fields-carry-upward`. Seconds, minutes, hours, days
> and months outside their range are carried into the field above, up to
> the year; an offset is reduced modulo twenty-four hours with the whole
> days moved into the hours. A local date is normalised by the C library
> instead.

> **Implementation** `Date.date/any-year`. The calendar of a date at an offset
> is computed and not looked up, so any year that is an `int` has its dates,
> the year \~5 and the year 100000 too. The specification asks for the years
> from about 1900 to 2200 only, and the suite takes a date or [`Date`](../sig/DATE.md#exn-date) beyond
> the range of a 32-bit `time_t`. [`toTime`](../sig/DATE.md#val-totime) raises [`Date`](../sig/DATE.md#exn-date) from about the year
> 292000 on, where the microseconds no longer fit, and [`fmt`](../sig/DATE.md#val-fmt) for a year that
> C's `int` of 32 bits cannot hold.

### fmt

> **Implementation** `Date.fmt/strftime-in-the-C-locale`. The work is done by
> `strftime` in the "C" locale as it stood when the program started; only
> the directives the specification lists are passed on, and any other
> `%c` gives `c`. The specification names no text for `%Z` on a UTC date,
> and the suite accepts `"UTC"`, `"GMT"`, `"Z"` or nothing.

> **Implementation** `Date.fmt/zone-names`. `%Z` is the C library's name of the
> zone for a local date, `UTC` for a date at the offset zero and nothing for
> one at any other offset. A `%` that ends the format is written as it is.

### fromTimeLocal

> **Implementation** `Date.fromTimeLocal/the-machines-zone`. Which zone that
> is depends on the machine, so the suite's checks of local dates are
> written to hold in any of them: the offset is `NONE`, whole minutes, and
> less than a day from UTC.

### fromTimeUniv

> **Reading** `Date.fromTimeUniv/second-it-falls-in`. The date is that of the
> second the time falls in: a fraction of a second is dropped, also for
> times before the epoch, where dropping is towards the earlier second.

### isDst

> **Reading** `Date.isDst/UTC-has-none`. A date at a fixed offset is not in
> daylight saving time: `SOME true` is wrong for it, and `NONE` and `SOME false` are both right.

### localOffset

> **Reading** `Date.localOffset/now-and-modulo-a-day`. The specification does
> not say whether daylight saving time counts, and takes offsets modulo
> twenty-four hours; the suite accepts the offset in force now, or an hour
> more, reduced modulo a day, west of UTC.

### scan

> **Reading** `Date.scan/does-not-validate`. It reads exactly that layout and
> checks nothing beyond it: the weekday is taken as written rather than
> worked out, and the date it gives is a local one ([`offset`](../sig/DATE.md#val-offset) and [`isDst`](../sig/DATE.md#val-isdst)
> both `NONE`). So [`scan`](../sig/DATE.md#val-scan) can give a date that [`fmt`](../sig/DATE.md#val-fmt) and [`toString`](../sig/DATE.md#val-tostring) then
> refuse.

### toTime

> **Reading** `Date.toTime/read-in-its-own-zone`. A date is "interpreted in
> its own time zone": one at offset `t` west of UTC is the UTC reading of
> its fields plus `t`. A local date is converted by the C library.

<details><summary>Other implementations (23)</summary>

- **MLton, SML/NJ (32-bit)** &mdash; date of year 10^8 raises Overflow, not Date
- **SML/NJ 110.99.9** &mdash; toTime ignores the offset of a date
- **SML/NJ** &mdash; fmt "%%Y" gives "1995": after %% the Y is taken as a directive, not the character Y
- **SML/NJ (32-bit)** &mdash; fmt "%Z" raises Date for a UTC date
- **Poly/ML** &mdash; fmt "" raises Date instead of giving ""
- **MLton, SML/NJ 110.99.9 (64-bit)** &mdash; fmt "%Z" of a UTC date gives the name of the local time zone ("NST"), not that of UTC
- **Poly/ML** &mdash; fmt "%Z" raises Date for a UTC date (an empty result of strftime)
- **SML/NJ** &mdash; scan and fromString do not skip initial whitespace ("after ignoring possible initial whitespace")
- **MLton, SML/NJ (32-bit), SML/NJ** &mdash; toTime of a date before 1970 raises Date
- **SML/NJ 110.99.9** &mdash; fromTimeUniv is off by twice the local offset, the wrong way: 23:59:59 UTC comes back as 4:59:59 the next day in summer time (2:30 west) and 6:59:59 in winter (3:30 west)
- **SML/NJ** &mdash; localOffset is east of UTC (110.79), or toTime reads UTC dates as local time (110.99.9), so it disagrees with the offset of fromTimeLocal
- **MLton** &mdash; offset reports the time east of UTC modulo a day (an offset of 5 hours west gives 19 hours, 5:30 east gives 5:30), not "the amount of time west of UTC"
- **SML/NJ** &mdash; date does not add the whole days of an offset of 24 hours or more to the hours ("sgn(t)(24\*d) is added to the hours")
- **SML/NJ** &mdash; scan reads a year of five digits (19956), not the 24-character date ("scan a 24-character date")
- **MLton** &mdash; date with an offset of more than a day east moves the date a day the wrong way
- **MLton** &mdash; toTime of a date after 2038 raises Overflow ("A conforming Date structure should support date values ranging from around 1900 to 2200")
- **MLton** &mdash; toTime of a date before 1970 raises Date ("support date values ranging from around 1900 to 2200")
- **SML/NJ (32-bit)** &mdash; date does not add the whole days of an offset of 24 hours or more to the hours, so that the date is another time
- **SML/NJ** &mdash; toTime of a UTC date from fromTimeUniv is not the time converted: it is off by the local offset
- **SML/NJ 110.99.9 (64-bit)** &mdash; toTime of a date of year 10^8 gives a time of the year 2092 instead of raising Date
- **SML/NJ (32-bit)** &mdash; toTime of a date after 2038 raises Date (32-bit time; "support date values ranging from around 1900 to 2200")
- **SML/NJ 110.99.9** &mdash; toTime ignores the offset of a date (12:00 at 5 hours west is 12:00 UTC)
- **Poly/ML** &mdash; toTime of a date of year 10^8 raises Time, not Date ("It raises Date if the date date cannot be represented as a Time.time value")

</details>

---

<sub>Generated by runedoc from lib/basis/date.sml; do not edit.</sub>

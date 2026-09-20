# signature DATE

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **DATE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 24 of 24 entries documented |
| Tests | 232 checks of 23 entries |
| Source | [lib/basis/sig\_date.sml](../../../../lib/basis/sig_date.sml) |

## Synopsis

```sml
signature DATE
structure Date : DATE
```

| Implementation |  | Source |
| --- | --- | --- |
| `Date` | Date: a moment as a person writes it down. | [lib/basis/date.sml](../../../../lib/basis/date.sml) |

A moment as a person writes it down: a year, a month, a day and a time of
day, in some time zone.

A [`date`](#val-date) is what [`TIME`](../sig/TIME.md) is not: a calendar reading. [`fromTimeUniv`](#val-fromtimeuniv) and
[`fromTimeLocal`](#val-fromtimelocal) turn a time into one, [`toTime`](#val-totime) turns one back, and the
pair are inverse only as far as the calendar is -- a date carries fields
that a time does not, and a time carries a fraction of a second that a
date does not.

The [`offset`](#val-offset) of a date is the time zone it is read in, as a duration west
of UTC: `NONE` means the local zone of the machine, `SOME zeroTime` means UTC. A date with an offset is arithmetic; a local date is
whatever the system's calendar says, daylight saving time and all.

The fields given to [`date`](#val-date) need not be in range: what is over is carried
into the field above it, so the thirty-second of January is the first of
February.

> **Implementation** `DATE/the-C-calendar`. Local dates are converted by the C
> library, so the local zone is the machine's and the calendar is the one it
> keeps; dates at a fixed offset, and UTC, are computed with the proleptic
> Gregorian calendar, which is how "leap years follow the Gregorian
> calendar" is read for years before it was adopted.

## Interface

<pre>
signature DATE =
sig
  datatype <a href="#type-weekday">weekday</a> = <a href="#con-mon">Mon</a> | <a href="#con-tue">Tue</a> | <a href="#con-wed">Wed</a> | <a href="#con-thu">Thu</a> | <a href="#con-fri">Fri</a> | <a href="#con-sat">Sat</a> | <a href="#con-sun">Sun</a>

  datatype <a href="#type-month">month</a>
    = <a href="#con-jan">Jan</a>
    | <a href="#con-feb">Feb</a>
    | <a href="#con-mar">Mar</a>
    | <a href="#con-apr">Apr</a>
    | <a href="#con-may">May</a>
    | <a href="#con-jun">Jun</a>
    | <a href="#con-jul">Jul</a>
    | <a href="#con-aug">Aug</a>
    | <a href="#con-sep">Sep</a>
    | <a href="#con-oct">Oct</a>
    | <a href="#con-nov">Nov</a>
    | <a href="#con-dec">Dec</a>

  type <a href="#type-date">date</a>

  exception <a href="#exn-date">Date</a>

  val <a href="#val-date">date</a> : {<a href="#fld-date.year">year</a> : int,
              <a href="#fld-date.month">month</a> : month,
              <a href="#fld-date.day">day</a> : int,
              <a href="#fld-date.hour">hour</a> : int,
              <a href="#fld-date.minute">minute</a> : int,
              <a href="#fld-date.second">second</a> : int,
              <a href="#fld-date.offset">offset</a> : Time.time option} -&gt; date

  val <a href="#val-year">year</a> : date -&gt; int

  val <a href="#val-month">month</a> : date -&gt; month

  val <a href="#val-day">day</a> : date -&gt; int

  val <a href="#val-hour">hour</a> : date -&gt; int

  val <a href="#val-minute">minute</a> : date -&gt; int

  val <a href="#val-second">second</a> : date -&gt; int

  val <a href="#val-weekday">weekDay</a> : date -&gt; weekday

  val <a href="#val-yearday">yearDay</a> : date -&gt; int

  val <a href="#val-offset">offset</a> : date -&gt; Time.time option

  val <a href="#val-isdst">isDst</a> : date -&gt; bool option

  val <a href="#val-localoffset">localOffset</a> : unit -&gt; Time.time

  val <a href="#val-fromtimelocal">fromTimeLocal</a> : Time.time -&gt; date

  val <a href="#val-fromtimeuniv">fromTimeUniv</a> : Time.time -&gt; date

  val <a href="#val-totime">toTime</a> : date -&gt; Time.time

  val <a href="#val-compare">compare</a> : date * date -&gt; order

  val <a href="#val-fmt">fmt</a> : string -&gt; date -&gt; string

  val <a href="#val-tostring">toString</a> : date -&gt; string

  val <a href="#val-scan">scan</a> : (char, 'a) StringCvt.reader -&gt; (date, 'a) StringCvt.reader

  val <a href="#val-fromstring">fromString</a> : string -&gt; date option
end
</pre>

### <a name="type-weekday"></a>`weekday`

```sml
datatype weekday = Mon | Tue | Wed | Thu | Fri | Sat | Sun
```

The days of the week.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-mon"></a>`Mon` |  |  |
| <a name="con-tue"></a>`Tue` |  |  |
| <a name="con-wed"></a>`Wed` |  |  |
| <a name="con-thu"></a>`Thu` |  |  |
| <a name="con-fri"></a>`Fri` |  |  |
| <a name="con-sat"></a>`Sat` |  |  |
| <a name="con-sun"></a>`Sun` |  |  |

### <a name="type-month"></a>`month`

```sml
datatype month
  = Jan
  | Feb
  | Mar
  | Apr
  | May
  | Jun
  | Jul
  | Aug
  | Sep
  | Oct
  | Nov
  | Dec
```

The months of the year.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-jan"></a>`Jan` |  |  |
| <a name="con-feb"></a>`Feb` |  |  |
| <a name="con-mar"></a>`Mar` |  |  |
| <a name="con-apr"></a>`Apr` |  |  |
| <a name="con-may"></a>`May` |  |  |
| <a name="con-jun"></a>`Jun` |  |  |
| <a name="con-jul"></a>`Jul` |  |  |
| <a name="con-aug"></a>`Aug` |  |  |
| <a name="con-sep"></a>`Sep` |  |  |
| <a name="con-oct"></a>`Oct` |  |  |
| <a name="con-nov"></a>`Nov` |  |  |
| <a name="con-dec"></a>`Dec` |  |  |

<details><summary>Tests (1)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example`

</details>

### <a name="type-date"></a>`date`

```sml
type date
```

The type of a calendar reading.

> **Deviation** `DATE.date/not-abstract`. The specification leaves the type
> abstract. In Rune it is a record of the fields [`year`](#val-year), [`month`](#val-month), [`day`](#val-day),
> [`hour`](#val-hour), [`minute`](#val-minute), [`second`](#val-second), [`offset`](#val-offset), `wday`, `yday` and [`isDst`](#val-isdst), and
> the structure is not sealed, so the record shows.

<details><summary>Tests (26)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `canonical-is-kept` &middot; `spec-example-negative-seconds` &middot; `second-60` &middot; `minutes-to-hours` &middot; `hour-24` &middot; `negative-hour` &middot; `days-to-months` &middot; `day-0` &middot; `negative-day` &middot; `months-to-years` &middot; `seconds-carry-to-the-year` &middot; `seconds-borrow-from-the-year` &middot; `a-year-of-seconds` &middot; `366-days-of-2000` &middot; `leap-2000` &middot; `leap-2004` &middot; `not-leap-2001` &middot; `not-leap-1900` &middot; `not-leap-2100` &middot; `weekDay-of-normalised` &middot; `yearDay-of-normalised` &middot; `is-canonical` &middot; `Date-or-a-year-far-away` &middot; `calendar-1900-2199` &middot; `offset-of-the-local-zone` &middot; `local-normalises`

</details>

### <a name="exn-date"></a>`Date`

```sml
exception Date
```

Raised when a date cannot be made, converted or printed: a field is out of range, or the time does not fit.

<details><summary>Tests (2)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `raise-and-handle` &middot; `is-its-own-exception`

</details>

### <a name="val-date"></a>`date`

```sml
val date : {year : int,
            month : month,
            day : int,
            hour : int,
            minute : int,
            second : int,
            offset : Time.time option} -> date
```

`date {year, month, day, hour, minute, second, offset}` is that date, with the fields carried into range.

`offset` is the zone: `NONE` for the local one, `SOME t` for the zone
`t` west of UTC. The weekday and the day of the year are worked out.

**Raises** [`Date`](#exn-date) if the date cannot be represented.

> **Reading** `Date.date/fields-carry-upward`. Seconds, minutes, hours, days
> and months outside their range are carried into the field above, up to
> the year; an offset is reduced modulo twenty-four hours with the whole
> days moved into the hours. A local date is normalised by the C library
> instead.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-date.year"></a>`year` | `int` |  |
| <a name="fld-date.month"></a>`month` | `month` |  |
| <a name="fld-date.day"></a>`day` | `int` |  |
| <a name="fld-date.hour"></a>`hour` | `int` |  |
| <a name="fld-date.minute"></a>`minute` | `int` |  |
| <a name="fld-date.second"></a>`second` | `int` |  |
| <a name="fld-date.offset"></a>`offset` | `Time.time option` |  |

<details><summary>Tests (26)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `canonical-is-kept` &middot; `spec-example-negative-seconds` &middot; `second-60` &middot; `minutes-to-hours` &middot; `hour-24` &middot; `negative-hour` &middot; `days-to-months` &middot; `day-0` &middot; `negative-day` &middot; `months-to-years` &middot; `seconds-carry-to-the-year` &middot; `seconds-borrow-from-the-year` &middot; `a-year-of-seconds` &middot; `366-days-of-2000` &middot; `leap-2000` &middot; `leap-2004` &middot; `not-leap-2001` &middot; `not-leap-1900` &middot; `not-leap-2100` &middot; `weekDay-of-normalised` &middot; `yearDay-of-normalised` &middot; `is-canonical` &middot; `Date-or-a-year-far-away` &middot; `calendar-1900-2199` &middot; `offset-of-the-local-zone` &middot; `local-normalises`

</details>

### <a name="val-year"></a>`year`

```sml
val year : date -> int
```

`year d` is the year of `d`, as a number and not counted from 1900.

<details><summary>Tests (2)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example` &middot; `base-0`

</details>

### <a name="val-month"></a>`month`

```sml
val month : date -> month
```

`month d` is the month of `d`.

<details><summary>Tests (1)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example`

</details>

### <a name="val-day"></a>`day`

```sml
val day : date -> int
```

`day d` is the day of the month of `d`, from 1.

<details><summary>Tests (1)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example`

</details>

### <a name="val-hour"></a>`hour`

```sml
val hour : date -> int
```

`hour d` is the hour of `d`, from 0 to 23.

<details><summary>Tests (1)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example`

</details>

### <a name="val-minute"></a>`minute`

```sml
val minute : date -> int
```

`minute d` is the minute of `d`, from 0 to 59.

<details><summary>Tests (1)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example`

</details>

### <a name="val-second"></a>`second`

```sml
val second : date -> int
```

`second d` is the second of `d`, from 0 to 59, or up to 61 for a leap second.

<details><summary>Tests (1)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example`

</details>

### <a name="val-weekday"></a>`weekDay`

```sml
val weekDay : date -> weekday
```

`weekDay d` is the day of the week of `d`.

<details><summary>Tests (5)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example` &middot; `2000-01-01` &middot; `2000-02-29` &middot; `1900-01-01` &middot; `2200-01-01`

</details>

### <a name="val-yearday"></a>`yearDay`

```sml
val yearDay : date -> int
```

`yearDay d` is the day of the year of `d`, from 0 for the first of January.

<details><summary>Tests (6)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example` &middot; `1-January-is-0` &middot; `31-December` &middot; `31-December-leap` &middot; `1-March-leap` &middot; `1-March`

</details>

### <a name="val-offset"></a>`offset`

```sml
val offset : date -> Time.time option
```

`offset d` is the zone of `d`: `NONE` for the local one, `SOME t` for `t` west of UTC.

<details><summary>Tests (13)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `UTC` &middot; `west` &middot; `east` &middot; `west-keeps-the-fields` &middot; `east-keeps-the-fields` &middot; `modulo-24-hours` &middot; `modulo-24-hours-moves-the-date` &middot; `modulo-24-hours-negative` &middot; `modulo-24-hours-negative-moves-the-date` &middot; `24-hours` &middot; `24-hours-moves-the-date` &middot; `49-hours-and-a-half` &middot; `local-is-NONE`

</details>

### <a name="val-isdst"></a>`isDst`

```sml
val isDst : date -> bool option
```

`isDst d` is `SOME true` when `d` is in daylight saving time, `SOME false` when it is not, `NONE` when that is unknown.

> **Reading** `Date.isDst/UTC-has-none`. A date at a fixed offset is not in
> daylight saving time: `SOME true` is wrong for it, and `NONE` and `SOME false` are both right.

<details><summary>Tests (2)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `UTC-is-not-daylight-saving` &middot; `not-both-January-and-July`

</details>

### <a name="val-localoffset"></a>`localOffset`

```sml
val localOffset : unit -> Time.time
```

`localOffset ()` is how far the local zone is west of UTC, now.

> **Reading** `Date.localOffset/now-and-modulo-a-day`. The specification does
> not say whether daylight saving time counts, and takes offsets modulo
> twenty-four hours; the suite accepts the offset in force now, or an hour
> more, reduced modulo a day, west of UTC.

<details><summary>Tests (3)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `west-of-UTC-now` &middot; `less-than-a-day` &middot; `whole-minutes`

</details>

### <a name="val-fromtimelocal"></a>`fromTimeLocal`

```sml
val fromTimeLocal : Time.time -> date
```

`fromTimeLocal t` is the moment `t` read in the local zone, with [`offset`](#val-offset) `NONE`.

> **Implementation** `Date.fromTimeLocal/the-machines-zone`. Which zone that
> is depends on the machine, so the suite's checks of local dates are
> written to hold in any of them: the offset is `NONE`, whole minutes, and
> less than a day from UTC.

<details><summary>Tests (5)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `offset-is-NONE` &middot; `toTime-inverts` &middot; `differs-from-UTC-by-less-than-a-day` &middot; `differs-from-UTC-by-whole-minutes` &middot; `same-weekDay-and-yearDay-as-the-fields`

</details>

### <a name="val-fromtimeuniv"></a>`fromTimeUniv`

```sml
val fromTimeUniv : Time.time -> date
```

`fromTimeUniv t` is the moment `t` read in UTC.

> **Reading** `Date.fromTimeUniv/second-it-falls-in`. The date is that of the
> second the time falls in: a fraction of a second is dropped, also for
> times before the epoch, where dropping is towards the earlier second.

<details><summary>Tests (10)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `offset-is-SOME-0` &middot; `not-daylight-saving` &middot; `inverts-toTime` &middot; `weekDay` &middot; `yearDay` &middot; `fraction-of-a-second` &middot; `fraction-of-a-second-1969` &middot; `now-is-after-2020` &middot; `calendar-1972-2037` &middot; `calendar-1900-2199`

</details>

### <a name="val-totime"></a>`toTime`

```sml
val toTime : date -> Time.time
```

`toTime d` is the moment that `d` names.

> **Reading** `Date.toTime/read-in-its-own-zone`. A date is "interpreted in
> its own time zone": one at offset `t` west of UTC is the UTC reading of
> its fields plus `t`. A local date is converted by the C library.

**Raises** [`Date`](#exn-date) if the moment does not fit in a [`Time.time`](../sig/TIME.md#type-time).

<details><summary>Tests (22)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `offset-west` &middot; `offset-east` &middot; `offset-west-in-UTC` &middot; `offset-east-in-UTC` &middot; `offset-modulo-24-hours-is-the-same-time` &middot; `offset-modulo-24-hours-negative-is-the-same-time` &middot; `a-day` &middot; `a-second` &middot; `leap-day` &middot; `no-leap-day` &middot; `leap-year` &middot; `year` &middot; `1972-to-2037` &middot; `last-second-of-1969` &middot; `century-from-1900` &middot; `century-to-2100-beyond-2038` &middot; `1900-to-2200` &middot; `Date-or-a-year-far-away` &middot; `inverts-fromTimeUniv` &middot; `fromTimeUniv-inverts-1972-2037` &middot; `local-date` &middot; `local-date-in-January`

</details>

### <a name="val-compare"></a>`compare`

```sml
val compare : date * date -> order
```

`compare (d, e)` orders two dates by year, month, day, hour, minute and second, in that order.

> **Reading** `Date.compare/ignores-the-offset`. The fields are compared as
> they are written: two dates that name the same moment in different zones
> do not compare equal, and one written later in its own zone is the
> greater.

<details><summary>Tests (11)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `equal` &middot; `year` &middot; `month` &middot; `day` &middot; `hour` &middot; `minute` &middot; `second` &middot; `ignores-the-offset` &middot; `ignores-the-offset-not-the-time` &middot; `local-and-UTC` &middot; `agrees-with-toTime-for-UTC`

</details>

### <a name="val-fmt"></a>`fmt`

```sml
val fmt : string -> date -> string
```

`fmt s d` is `d` written out by the directives of `s`, as C's `strftime` writes them.

**Raises** [`Date`](#exn-date) if `d` is not a valid date, which [`scan`](#val-scan) can produce.

> **Implementation** `Date.fmt/strftime-in-the-C-locale`. The work is done by
> `strftime` in the "C" locale as it stood when the program started; only
> the directives the specification lists are passed on, and any other
> `%c` gives `c`. The specification names no text for `%Z` on a UTC date,
> and the suite accepts `"UTC"`, `"GMT"`, `"Z"` or nothing.

<details><summary>Tests (58)</summary>

For `Date`, in [tests/basis/date\_fmt.sml](../../../../tests/basis/date_fmt.sml): `%d` &middot; `%H` &middot; `%I` &middot; `%I-morning` &middot; `%I-midnight` &middot; `%I-noon` &middot; `%I-one` &middot; `%j` &middot; `%j-first-day` &middot; `%j-last-day-of-a-leap-year` &middot; `%m` &middot; `%m-December` &middot; `%M` &middot; `%S` &middot; `%S-zero` &middot; `%U` &middot; `%U-Sunday` &middot; `%W` &middot; `%W-Sunday` &middot; `%U-before-the-first-Sunday` &middot; `%W-before-the-first-Monday` &middot; `%W-first-Monday` &middot; `%w` &middot; `%w-Sunday` &middot; `%w-Saturday` &middot; `%y` &middot; `%y-2005` &middot; `%Y` &middot; `%%` &middot; `%%Y` &middot; `text-around-directives` &middot; `no-directive` &middot; `empty` &middot; `several` &middot; `other-character` &middot; `other-character-e` &middot; `other-character-digit` &middot; `other-characters-in-text` &middot; `%Z-UTC` &middot; `numeric-directives` &middot; `prints-no-second-99` &middot; `prints-no-hour-24` &middot; `prints-no-30-February` &middot; `prints-a-valid-date` &middot; `%a` &middot; `%a-Sunday` &middot; `%A` &middot; `%A-Sunday` &middot; `%b` &middot; `%B` &middot; `%B-September` &middot; `%p` &middot; `%p-morning` &middot; `%c` &middot; `%x` &middot; `%X` &middot; `names-of-every-month` &middot; `names-of-every-weekday`

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : date -> string
```

`toString d` is `d` in the layout `"Wed Mar 8 19:06:45 1995"`, as C's `%a %b %e %H:%M:%S %Y`.

**Raises** [`Date`](#exn-date) if `d` is not a valid date.

<details><summary>Tests (9)</summary>

For `Date`, in [tests/basis/date\_fmt.sml](../../../../tests/basis/date_fmt.sml): `prints-no-31-April` &middot; `prints-no-minute-60` &middot; `spec-example` &middot; `morning` &middot; `midnight` &middot; `end-of-year` &middot; `every-month` &middot; `every-weekday` &middot; `24-characters-as-fmt`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (date, 'a) StringCvt.reader
```

`scan getc src` reads a date in the layout of [`toString`](#val-tostring), after leading whitespace.

> **Reading** `Date.scan/does-not-validate`. It reads exactly that layout and
> checks nothing beyond it: the weekday is taken as written rather than
> worked out, and the date it gives is a local one ([`offset`](#val-offset) and [`isDst`](#val-isdst)
> both `NONE`). So [`scan`](#val-scan) can give a date that [`fmt`](#val-fmt) and [`toString`](#val-tostring) then
> refuse.

<details><summary>Tests (6)</summary>

For `Date`, in [tests/basis/date\_fmt.sml](../../../../tests/basis/date_fmt.sml): `rest` &middot; `time-zone-not-parsed` &middot; `24-characters` &middot; `initial-whitespace` &middot; `NONE` &middot; `list-reader`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> date option
```

`fromString s` is `SOME` of the date that `s` begins with, after whitespace, or `NONE`.

**Law** `fromString s = StringCvt.scanString scan s`

<details><summary>Tests (20)</summary>

For `Date`, in [tests/basis/date\_fmt.sml](../../../../tests/basis/date_fmt.sml): `spec-example` &middot; `weekDay` &middot; `yearDay` &middot; `initial-whitespace` &middot; `rest-ignored` &middot; `morning` &middot; `no-consistency-check-of-the-weekday` &middot; `empty` &middot; `blank` &middot; `letters` &middot; `weekday-only` &middot; `no-year` &middot; `no-seconds` &middot; `unknown-weekday` &middot; `unknown-month` &middot; `dashes` &middot; `numeric-date` &middot; `every-month` &middot; `every-weekday` &middot; `inverts-toString`

</details>

## See also

[`TIME`](../sig/TIME.md), [`TIMER`](../sig/TIMER.md), [`OS_PROCESS`](../sig/OS_PROCESS.md)

---

<sub>Generated by runedoc from lib/basis/sig\_date.sml; do not edit.</sub>

# signature DATE

[The Standard ML Basis Library](../README.md) &rsaquo; **DATE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 24 entries documented |
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

signature DATE, transcribed from <https://smlfamily.github.io/Basis/date.html>

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

<details><summary>Tests (26)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `canonical-is-kept` &middot; `spec-example-negative-seconds` &middot; `second-60` &middot; `minutes-to-hours` &middot; `hour-24` &middot; `negative-hour` &middot; `days-to-months` &middot; `day-0` &middot; `negative-day` &middot; `months-to-years` &middot; `seconds-carry-to-the-year` &middot; `seconds-borrow-from-the-year` &middot; `a-year-of-seconds` &middot; `366-days-of-2000` &middot; `leap-2000` &middot; `leap-2004` &middot; `not-leap-2001` &middot; `not-leap-1900` &middot; `not-leap-2100` &middot; `weekDay-of-normalised` &middot; `yearDay-of-normalised` &middot; `is-canonical` &middot; `Date-or-a-year-far-away` &middot; `calendar-1900-2199` &middot; `offset-of-the-local-zone` &middot; `local-normalises`

</details>

### <a name="exn-date"></a>`Date`

```sml
exception Date
```

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

<details><summary>Tests (2)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example` &middot; `base-0`

</details>

### <a name="val-month"></a>`month`

```sml
val month : date -> month
```

<details><summary>Tests (1)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example`

</details>

### <a name="val-day"></a>`day`

```sml
val day : date -> int
```

<details><summary>Tests (1)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example`

</details>

### <a name="val-hour"></a>`hour`

```sml
val hour : date -> int
```

<details><summary>Tests (1)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example`

</details>

### <a name="val-minute"></a>`minute`

```sml
val minute : date -> int
```

<details><summary>Tests (1)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example`

</details>

### <a name="val-second"></a>`second`

```sml
val second : date -> int
```

<details><summary>Tests (1)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example`

</details>

### <a name="val-weekday"></a>`weekDay`

```sml
val weekDay : date -> weekday
```

<details><summary>Tests (5)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example` &middot; `2000-01-01` &middot; `2000-02-29` &middot; `1900-01-01` &middot; `2200-01-01`

</details>

### <a name="val-yearday"></a>`yearDay`

```sml
val yearDay : date -> int
```

<details><summary>Tests (6)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `example` &middot; `1-January-is-0` &middot; `31-December` &middot; `31-December-leap` &middot; `1-March-leap` &middot; `1-March`

</details>

### <a name="val-offset"></a>`offset`

```sml
val offset : date -> Time.time option
```

<details><summary>Tests (13)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `UTC` &middot; `west` &middot; `east` &middot; `west-keeps-the-fields` &middot; `east-keeps-the-fields` &middot; `modulo-24-hours` &middot; `modulo-24-hours-moves-the-date` &middot; `modulo-24-hours-negative` &middot; `modulo-24-hours-negative-moves-the-date` &middot; `24-hours` &middot; `24-hours-moves-the-date` &middot; `49-hours-and-a-half` &middot; `local-is-NONE`

</details>

### <a name="val-isdst"></a>`isDst`

```sml
val isDst : date -> bool option
```

<details><summary>Tests (2)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `UTC-is-not-daylight-saving` &middot; `not-both-January-and-July`

</details>

### <a name="val-localoffset"></a>`localOffset`

```sml
val localOffset : unit -> Time.time
```

<details><summary>Tests (3)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `west-of-UTC-now` &middot; `less-than-a-day` &middot; `whole-minutes`

</details>

### <a name="val-fromtimelocal"></a>`fromTimeLocal`

```sml
val fromTimeLocal : Time.time -> date
```

<details><summary>Tests (5)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `offset-is-NONE` &middot; `toTime-inverts` &middot; `differs-from-UTC-by-less-than-a-day` &middot; `differs-from-UTC-by-whole-minutes` &middot; `same-weekDay-and-yearDay-as-the-fields`

</details>

### <a name="val-fromtimeuniv"></a>`fromTimeUniv`

```sml
val fromTimeUniv : Time.time -> date
```

<details><summary>Tests (10)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `offset-is-SOME-0` &middot; `not-daylight-saving` &middot; `inverts-toTime` &middot; `weekDay` &middot; `yearDay` &middot; `fraction-of-a-second` &middot; `fraction-of-a-second-1969` &middot; `now-is-after-2020` &middot; `calendar-1972-2037` &middot; `calendar-1900-2199`

</details>

### <a name="val-totime"></a>`toTime`

```sml
val toTime : date -> Time.time
```

<details><summary>Tests (22)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `offset-west` &middot; `offset-east` &middot; `offset-west-in-UTC` &middot; `offset-east-in-UTC` &middot; `offset-modulo-24-hours-is-the-same-time` &middot; `offset-modulo-24-hours-negative-is-the-same-time` &middot; `a-day` &middot; `a-second` &middot; `leap-day` &middot; `no-leap-day` &middot; `leap-year` &middot; `year` &middot; `1972-to-2037` &middot; `last-second-of-1969` &middot; `century-from-1900` &middot; `century-to-2100-beyond-2038` &middot; `1900-to-2200` &middot; `Date-or-a-year-far-away` &middot; `inverts-fromTimeUniv` &middot; `fromTimeUniv-inverts-1972-2037` &middot; `local-date` &middot; `local-date-in-January`

</details>

### <a name="val-compare"></a>`compare`

```sml
val compare : date * date -> order
```

<details><summary>Tests (11)</summary>

For `Date`, in [tests/basis/date.sml](../../../../tests/basis/date.sml): `equal` &middot; `year` &middot; `month` &middot; `day` &middot; `hour` &middot; `minute` &middot; `second` &middot; `ignores-the-offset` &middot; `ignores-the-offset-not-the-time` &middot; `local-and-UTC` &middot; `agrees-with-toTime-for-UTC`

</details>

### <a name="val-fmt"></a>`fmt`

```sml
val fmt : string -> date -> string
```

<details><summary>Tests (58)</summary>

For `Date`, in [tests/basis/date\_fmt.sml](../../../../tests/basis/date_fmt.sml): `%d` &middot; `%H` &middot; `%I` &middot; `%I-morning` &middot; `%I-midnight` &middot; `%I-noon` &middot; `%I-one` &middot; `%j` &middot; `%j-first-day` &middot; `%j-last-day-of-a-leap-year` &middot; `%m` &middot; `%m-December` &middot; `%M` &middot; `%S` &middot; `%S-zero` &middot; `%U` &middot; `%U-Sunday` &middot; `%W` &middot; `%W-Sunday` &middot; `%U-before-the-first-Sunday` &middot; `%W-before-the-first-Monday` &middot; `%W-first-Monday` &middot; `%w` &middot; `%w-Sunday` &middot; `%w-Saturday` &middot; `%y` &middot; `%y-2005` &middot; `%Y` &middot; `%%` &middot; `%%Y` &middot; `text-around-directives` &middot; `no-directive` &middot; `empty` &middot; `several` &middot; `other-character` &middot; `other-character-e` &middot; `other-character-digit` &middot; `other-characters-in-text` &middot; `%Z-UTC` &middot; `numeric-directives` &middot; `prints-no-second-99` &middot; `prints-no-hour-24` &middot; `prints-no-30-February` &middot; `prints-a-valid-date` &middot; `%a` &middot; `%a-Sunday` &middot; `%A` &middot; `%A-Sunday` &middot; `%b` &middot; `%B` &middot; `%B-September` &middot; `%p` &middot; `%p-morning` &middot; `%c` &middot; `%x` &middot; `%X` &middot; `names-of-every-month` &middot; `names-of-every-weekday`

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : date -> string
```

<details><summary>Tests (9)</summary>

For `Date`, in [tests/basis/date\_fmt.sml](../../../../tests/basis/date_fmt.sml): `prints-no-31-April` &middot; `prints-no-minute-60` &middot; `spec-example` &middot; `morning` &middot; `midnight` &middot; `end-of-year` &middot; `every-month` &middot; `every-weekday` &middot; `24-characters-as-fmt`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (date, 'a) StringCvt.reader
```

<details><summary>Tests (6)</summary>

For `Date`, in [tests/basis/date\_fmt.sml](../../../../tests/basis/date_fmt.sml): `rest` &middot; `time-zone-not-parsed` &middot; `24-characters` &middot; `initial-whitespace` &middot; `NONE` &middot; `list-reader`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> date option
```

<details><summary>Tests (20)</summary>

For `Date`, in [tests/basis/date\_fmt.sml](../../../../tests/basis/date_fmt.sml): `spec-example` &middot; `weekDay` &middot; `yearDay` &middot; `initial-whitespace` &middot; `rest-ignored` &middot; `morning` &middot; `no-consistency-check-of-the-weekday` &middot; `empty` &middot; `blank` &middot; `letters` &middot; `weekday-only` &middot; `no-year` &middot; `no-seconds` &middot; `unknown-weekday` &middot; `unknown-month` &middot; `dashes` &middot; `numeric-date` &middot; `every-month` &middot; `every-weekday` &middot; `inverts-toString`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_date.sml; do not edit.</sub>

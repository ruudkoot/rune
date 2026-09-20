# signature DATE

[The Standard ML Basis Library](../README.md) &rsaquo; **DATE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 0 of 24 entries documented |
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

### <a name="type-date"></a>`date`

```sml
type date
```

### <a name="exn-date"></a>`Date`

```sml
exception Date
```

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

### <a name="val-year"></a>`year`

```sml
val year : date -> int
```

### <a name="val-month"></a>`month`

```sml
val month : date -> month
```

### <a name="val-day"></a>`day`

```sml
val day : date -> int
```

### <a name="val-hour"></a>`hour`

```sml
val hour : date -> int
```

### <a name="val-minute"></a>`minute`

```sml
val minute : date -> int
```

### <a name="val-second"></a>`second`

```sml
val second : date -> int
```

### <a name="val-weekday"></a>`weekDay`

```sml
val weekDay : date -> weekday
```

### <a name="val-yearday"></a>`yearDay`

```sml
val yearDay : date -> int
```

### <a name="val-offset"></a>`offset`

```sml
val offset : date -> Time.time option
```

### <a name="val-isdst"></a>`isDst`

```sml
val isDst : date -> bool option
```

### <a name="val-localoffset"></a>`localOffset`

```sml
val localOffset : unit -> Time.time
```

### <a name="val-fromtimelocal"></a>`fromTimeLocal`

```sml
val fromTimeLocal : Time.time -> date
```

### <a name="val-fromtimeuniv"></a>`fromTimeUniv`

```sml
val fromTimeUniv : Time.time -> date
```

### <a name="val-totime"></a>`toTime`

```sml
val toTime : date -> Time.time
```

### <a name="val-compare"></a>`compare`

```sml
val compare : date * date -> order
```

### <a name="val-fmt"></a>`fmt`

```sml
val fmt : string -> date -> string
```

### <a name="val-tostring"></a>`toString`

```sml
val toString : date -> string
```

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (date, 'a) StringCvt.reader
```

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> date option
```

---

<sub>Generated by runedoc from lib/basis/sig\_date.sml; do not edit.</sub>

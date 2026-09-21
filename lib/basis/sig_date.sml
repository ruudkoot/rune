(* A moment as a person writes it down: a year, a month, a day and a time of
   day, in some time zone.

   A `date` is what `TIME` is not: a calendar reading. `fromTimeUniv` and
   `fromTimeLocal` turn a time into one, `toTime` turns one back, and the
   pair are inverse only as far as the calendar is -- a date carries fields
   that a time does not, and a time carries a fraction of a second that a
   date does not.

   The `offset` of a date is the time zone it is read in, as a duration west
   of UTC: `NONE` means the local zone of the machine, `SOME
   zeroTime` means UTC. A date with an offset is arithmetic; a local date is
   whatever the system's calendar says, daylight saving time and all.

   The fields given to `date` need not be in range: what is over is carried
   into the field above it, so the thirty-second of January is the first of
   February.

   Area: The operating system

   See also: `TIME`, `TIMER`, `OS_PROCESS`

   Implementation: `DATE/the-C-calendar`. Local dates are converted by the C
   library, so the local zone is the machine's and the calendar is the one it
   keeps; dates at a fixed offset, and UTC, are computed with the proleptic
   Gregorian calendar, which is how "leap years follow the Gregorian
   calendar" is read for years before it was adopted. *)
signature DATE =
sig
  (* The days of the week. *)
  datatype weekday = Mon | Tue | Wed | Thu | Fri | Sat | Sun

  (* The months of the year. *)
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

  (* The type of a calendar reading.

     Deviation: `DATE.date/not-abstract`. The specification leaves the type
     abstract. In Rune it is a record of the fields `year`, `month`, `day`,
     `hour`, `minute`, `second`, `offset`, `wday`, `yday` and `isDst`, and the type is not made abstract, so the record shows. *)
  type date

  (* Raised when a date cannot be made, converted or printed: a field is out of range, or the time does not fit. *)
  exception Date

  (* `date {year, month, day, hour, minute, second, offset}` is that date, with the fields carried into range.

     `offset` is the zone: `NONE` for the local one, `SOME t` for the zone
     `t` west of UTC. The weekday and the day of the year are worked out.

     Raises: `Date` if the date cannot be represented.

     Reading: `Date.date/fields-carry-upward`. Seconds, minutes, hours, days
     and months outside their range are carried into the field above, up to
     the year; an offset is reduced modulo twenty-four hours with the whole
     days moved into the hours. A local date is normalised by the C library
     instead.

     Pinned by: `Date.date/offset-of-the-local-zone`

     Example: `(fn d => (month d, day d, hour d)) (date {year = 2001, month =
     Jan, day = 32, hour = 25, minute = 0, second = 0, offset = SOME
     Time.zeroTime}) = (Feb, 2, 1)`

     Implementation: `Date.date/any-year`. The calendar of a date at an offset
     is computed and not looked up, so any year that is an `int` has its dates,
     the year ~5 and the year 100000 too. The specification asks for the years
     from about 1900 to 2200 only, and the suite takes a date or `Date` beyond
     the range of a 32-bit `time_t`. `toTime` raises `Date` from about the year
     292000 on, where the microseconds no longer fit, and `fmt` for a year that
     C's `int` of 32 bits cannot hold. *)
  val date : {year : int,
              month : month,
              day : int,
              hour : int,
              minute : int,
              second : int,
              offset : Time.time option} -> date

  (* `year d` is the year of `d`, as a number and not counted from 1900. *)
  val year : date -> int

  (* `month d` is the month of `d`. *)
  val month : date -> month

  (* `day d` is the day of the month of `d`, from 1. *)
  val day : date -> int

  (* `hour d` is the hour of `d`, from 0 to 23. *)
  val hour : date -> int

  (* `minute d` is the minute of `d`, from 0 to 59. *)
  val minute : date -> int

  (* `second d` is the second of `d`, from 0 to 59, or up to 61 for a leap second. *)
  val second : date -> int

  (* `weekDay d` is the day of the week of `d`.

     Example: `weekDay (date {year = 1995, month = Mar, day = 8, hour = 19,
     minute = 6, second = 45, offset = SOME Time.zeroTime}) = Wed` *)
  val weekDay : date -> weekday

  (* `yearDay d` is the day of the year of `d`, from 0 for the first of January.

     Example: `yearDay (date {year = 1995, month = Mar, day = 8, hour = 0,
     minute = 0, second = 0, offset = SOME Time.zeroTime}) = 66` *)
  val yearDay : date -> int

  (* `offset d` is the zone of `d`: `NONE` for the local one, `SOME t` for `t` west of UTC. *)
  val offset : date -> Time.time option

  (* `isDst d` is `SOME true` when `d` is in daylight saving time, `SOME false` when it is not, `NONE` when that is unknown.

     Reading: `Date.isDst/UTC-has-none`. A date at a fixed offset is not in
     daylight saving time: `SOME true` is wrong for it, and `NONE` and `SOME
     false` are both right.

     Pinned by: `Date.isDst/UTC-is-not-daylight-saving`

     The suite assumes that no zone has daylight saving time both in January
     and in July. *)
  val isDst : date -> bool option

  (* `localOffset ()` is how far the local zone is west of UTC, now.

     Reading: `Date.localOffset/now-and-modulo-a-day`. The specification does
     not say whether daylight saving time counts, and takes offsets modulo
     twenty-four hours; the suite accepts the offset in force now, or an hour
     more, reduced modulo a day, west of UTC.

     Pinned by: `Date.localOffset/*` *)
  val localOffset : unit -> Time.time

  (* `fromTimeLocal t` is the moment `t` read in the local zone, with `offset` `NONE`.

     Implementation: `Date.fromTimeLocal/the-machines-zone`. Which zone that
     is depends on the machine, so the suite's checks of local dates are
     written to hold in any of them: the offset is `NONE`, whole minutes, and
     less than a day from UTC.

     Pinned by: `Date.fromTimeLocal/*`

     The suite's moments are noon UTC on 15 January and 15 July 2001, away from
     the changes of every zone, and the time at which it runs. *)
  val fromTimeLocal : Time.time -> date

  (* `fromTimeUniv t` is the moment `t` read in UTC.

     Reading: `Date.fromTimeUniv/second-it-falls-in`. The date is that of the
     second the time falls in: a fraction of a second is dropped, also for
     times before the epoch, where dropping is towards the earlier second.

     Pinned by: `Date.fromTimeUniv/fraction-of-a-second*`

     The suite assumes that the clock of the machine shows a year from 2020 to
     2199. *)
  val fromTimeUniv : Time.time -> date

  (* `toTime d` is the moment that `d` names.

     Reading: `Date.toTime/read-in-its-own-zone`. A date is "interpreted in
     its own time zone": one at offset `t` west of UTC is the UTC reading of
     its fields plus `t`. A local date is converted by the C library.

     Raises: `Date` if the moment does not fit in a `Time.time`.

     Example: `Time.toSeconds (toTime (date {year = 1970, month = Jan, day = 2,
     hour = 0, minute = 0, second = 0, offset = SOME Time.zeroTime})) = 86400` *)
  val toTime : date -> Time.time

  (* `compare (d, e)` orders two dates by year, month, day, hour, minute and second, in that order.

     Reading: `Date.compare/ignores-the-offset`. The fields are compared as
     they are written: two dates that name the same moment in different zones
     do not compare equal, and one written later in its own zone is the
     greater.

     Pinned by: `Date.compare/ignores-the-offset*` *)
  val compare : date * date -> order

  (* `fmt s d` is `d` written out by the directives of `s`, as C's `strftime` writes them.

     Raises: `Date` if `d` is not a valid date, which `scan` can produce.

     Implementation: `Date.fmt/strftime-in-the-C-locale`. The work is done by
     `strftime` in the "C" locale as it stood when the program started; only
     the directives the specification lists are passed on, and any other
     `%c` gives `c`. The specification names no text for `%Z` on a UTC date,
     and the suite accepts `"UTC"`, `"GMT"`, `"Z"` or nothing.

     Pinned by: `Date.fmt/%Z-UTC`, `Date.fmt/prints-*`

     Example: `fmt "%Y-%m-%d %H:%M" (date {year = 1995, month = Mar, day = 8,
     hour = 19, minute = 6, second = 45, offset = SOME Time.zeroTime}) =
     "1995-03-08 19:06"`

     Implementation: `Date.fmt/zone-names`. `%Z` is the C library's name of the
     zone for a local date, `UTC` for a date at the offset zero and nothing for
     one at any other offset. A `%` that ends the format is written as it is. *)
  val fmt : string -> date -> string

  (* `toString d` is `d` in the 24 characters of `"Wed Mar 08 19:06:45 1995"`, which is `fmt "%a %b %d %H:%M:%S %Y" d`.

     Raises: `Date` if `d` is not a valid date.

     Example: `toString (date {year = 1995, month = Mar, day = 8, hour = 19,
     minute = 6, second = 45, offset = SOME Time.zeroTime}) =
     "Wed Mar 08 19:06:45 1995"` *)
  val toString : date -> string

  (* `scan getc src` reads a date in the layout of `toString`, after leading whitespace.

     Reading: `Date.scan/does-not-validate`. It reads exactly that layout and
     checks nothing beyond it: the weekday is taken as written rather than
     worked out, and the date it gives is a local one (`offset` and `isDst`
     both `NONE`). So `scan` can give a date that `fmt` and `toString` then
     refuse. *)
  val scan : (char, 'a) StringCvt.reader -> (date, 'a) StringCvt.reader

  (* `fromString s` is `SOME` of the date that `s` begins with, after whitespace, or `NONE`.

     Law: `fromString s = StringCvt.scanString scan s`

     Example: `Option.map toString (fromString
     "  Wed Mar 08 19:06:45 1995 and more") = SOME "Wed Mar 08 19:06:45 1995"` *)
  val fromString : string -> date option
end

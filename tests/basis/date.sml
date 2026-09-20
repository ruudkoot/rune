(* requires: Date Time LargeInt *)
(* The Date structure (signature DATE): dates, their fields, normalisation,
   time zones, the conversions to and from Time.time and compare. fmt,
   toString, scan and fromString are in date_fmt.sml. Expected values follow
   the text of https://smlfamily.github.io/Basis/date.html.

   The reference point of Time.time is not specified ("time values are not
   portable across implementations"), so that no check depends on the time
   that a date is: the times of UTC dates are only compared with each other,
   and the calendar is checked against a Gregorian calendar written out
   below, counting seconds from a date that toTime converted. Dates in UTC
   (offset SOME Time.zeroTime) have exact expectations. The local time zone
   is whatever the machine has; the checks of local dates hold in every
   zone. "A conforming Date structure should support date values ranging from
   around 1900 to 2200": checks that go outside the 32-bit time of the C
   library (1901-12-13 to 2038-01-19) say so in their labels. *)
structure TestDate =
struct
  val eqB = T.eq T.bool
  val eqI = T.eq T.int
  val eqL = T.eq LargeInt.toString
  (* Numbers of seconds are LargeInt.int values made from ints: a host that
     compiles lib/basis (xc1) has no constants and no overloaded operators at
     the LargeInt of lib/basis. *)
  val large = LargeInt.fromInt
  fun days (n : int) : LargeInt.int = LargeInt.* (large n, large 86400)

  fun monthName m =
    case m of
      Date.Jan => "Jan" | Date.Feb => "Feb" | Date.Mar => "Mar" | Date.Apr => "Apr"
    | Date.May => "May" | Date.Jun => "Jun" | Date.Jul => "Jul" | Date.Aug => "Aug"
    | Date.Sep => "Sep" | Date.Oct => "Oct" | Date.Nov => "Nov" | Date.Dec => "Dec"
  fun weekdayName d =
    case d of
      Date.Mon => "Mon" | Date.Tue => "Tue" | Date.Wed => "Wed" | Date.Thu => "Thu"
    | Date.Fri => "Fri" | Date.Sat => "Sat" | Date.Sun => "Sun"
  val months = [Date.Jan, Date.Feb, Date.Mar, Date.Apr, Date.May, Date.Jun,
                Date.Jul, Date.Aug, Date.Sep, Date.Oct, Date.Nov, Date.Dec]
  val weekdays = [Date.Mon, Date.Tue, Date.Wed, Date.Thu, Date.Fri, Date.Sat, Date.Sun]

  (* the year, month, day, hour, minute and second of a date *)
  fun fieldsOf d = (Date.year d, Date.month d, Date.day d, Date.hour d, Date.minute d, Date.second d)
  fun showFields (y, m, d, h, mi, s) =
    Int.toString y ^ "-" ^ monthName m ^ "-" ^ Int.toString d ^ " "
    ^ Int.toString h ^ ":" ^ Int.toString mi ^ ":" ^ Int.toString s
  fun eqFields (label, expected, f : unit -> Date.date) = T.eq showFields (label, expected, fn () => fieldsOf (f ()))
  val eqW = T.eq weekdayName
  val eqM = T.eq monthName
  fun showOffset t = LargeInt.toString t ^ "s"
  (* the offset of a date in seconds *)
  fun offsetOf d = Option.map Time.toSeconds (Date.offset d)
  fun eqOffset (label, expected : int option, f : unit -> Date.date) =
    T.eq (T.option showOffset) (label, Option.map large expected, fn () => offsetOf (f ()))

  fun at (y, m, d, h, mi, s, offset) =
    Date.date {year = y, month = m, day = d, hour = h, minute = mi, second = s, offset = offset}
  (* a date in UTC *)
  fun utc (y, m, d, h, mi, s) = at (y, m, d, h, mi, s, SOME Time.zeroTime)
  fun sec (n : int) = Time.fromSeconds (large n)
  (* the seconds from date a to date b *)
  fun secondsBetween (a, b) = Time.toSeconds (Time.- (Date.toTime b, Date.toTime a))
  val day = 86400

  (* ---- a Gregorian calendar ("Leap years follow the Gregorian calendar") ---- *)
  fun leap y = (y mod 4 = 0 andalso y mod 100 <> 0) orelse y mod 400 = 0
  fun yearLength y = if leap y then 366 else 365
  fun monthLength (y, k) =       (* k = 0 for January *)
    case k of 1 => if leap y then 29 else 28 | 3 => 30 | 5 => 30 | 8 => 30 | 10 => 30 | _ => 31
  (* civil (y, n): the year, month, day of the month and day of the year of
     the day n >= 0 days after 1 January of year y *)
  fun civil (y, n) =
    if n >= yearLength y then civil (y + 1, n - yearLength y)
    else
      let fun go (k, r) = if r >= monthLength (y, k) then go (k + 1, r - monthLength (y, k))
                          else (y, List.nth (months, k), r + 1, n)
      in go (0, n) end
  (* the weekday n days after a weekday w *)
  fun weekdayAfter (w, n) =
    let fun index (x :: rest, k) = if x = w then k else index (rest, k + 1)
          | index ([], k) = k
    in List.nth (weekdays, (index (weekdays, 0) + n) mod 7) end

  (* law (label, n, sample, holds, show): holds x for n pseudo-random samples
     x = sample (); the first counterexample is reported. *)
  fun law (label, n, sample : unit -> 'a, holds : 'a -> bool, show : 'a -> string) : unit =
    let
      fun go i =
        if i >= n then NONE
        else let val x = sample () in if (holds x handle _ => false) then go (i + 1) else SOME x end
    in
      case (SOME (go 0) handle _ => NONE) of
        SOME NONE => T.pass label
      | SOME (SOME x) => T.fail (label, "fails for " ^ show x)
      | NONE => T.fail (label, "raised an exception")
    end
  fun showDaySecond (n, s) = "day " ^ Int.toString n ^ " second " ^ Int.toString s

  val () = T.seed 1995

  (* ---- the constructors: 1 to 7 January 2001 are Monday to Sunday; day
     1, 32, 60, ... of January 2001 is the first of each month ---- *)
  fun weekdayOfJanuary n = Date.weekDay (utc (2001, Date.Jan, n, 12, 0, 0))
  val () = eqW ("Date.Mon/2001-01-01", Date.Mon, fn () => weekdayOfJanuary 1)
  val () = eqW ("Date.Tue/2001-01-02", Date.Tue, fn () => weekdayOfJanuary 2)
  val () = eqW ("Date.Wed/2001-01-03", Date.Wed, fn () => weekdayOfJanuary 3)
  val () = eqW ("Date.Thu/2001-01-04", Date.Thu, fn () => weekdayOfJanuary 4)
  val () = eqW ("Date.Fri/2001-01-05", Date.Fri, fn () => weekdayOfJanuary 5)
  val () = eqW ("Date.Sat/2001-01-06", Date.Sat, fn () => weekdayOfJanuary 6)
  val () = eqW ("Date.Sun/2001-01-07", Date.Sun, fn () => weekdayOfJanuary 7)
  fun monthOfJanuary n = Date.month (utc (2001, Date.Jan, n, 12, 0, 0))
  val () = eqM ("Date.Jan/day-1", Date.Jan, fn () => monthOfJanuary 1)
  val () = eqM ("Date.Feb/day-32", Date.Feb, fn () => monthOfJanuary 32)
  val () = eqM ("Date.Mar/day-60", Date.Mar, fn () => monthOfJanuary 60)
  val () = eqM ("Date.Apr/day-91", Date.Apr, fn () => monthOfJanuary 91)
  val () = eqM ("Date.May/day-121", Date.May, fn () => monthOfJanuary 121)
  val () = eqM ("Date.Jun/day-152", Date.Jun, fn () => monthOfJanuary 152)
  val () = eqM ("Date.Jul/day-182", Date.Jul, fn () => monthOfJanuary 182)
  val () = eqM ("Date.Aug/day-213", Date.Aug, fn () => monthOfJanuary 213)
  val () = eqM ("Date.Sep/day-244", Date.Sep, fn () => monthOfJanuary 244)
  val () = eqM ("Date.Oct/day-274", Date.Oct, fn () => monthOfJanuary 274)
  val () = eqM ("Date.Nov/day-305", Date.Nov, fn () => monthOfJanuary 305)
  val () = eqM ("Date.Dec/day-335", Date.Dec, fn () => monthOfJanuary 335)
  val () = eqB ("Date.Dec/is-the-first-day-335", true,
                fn () => Date.day (utc (2001, Date.Jan, 335, 12, 0, 0)) = 1 andalso Date.day (utc (2001, Date.Jan, 334, 0, 0, 0)) = 30)

  (* ---- Date: "If the resulting date is outside the range supported by the
     implementation, the Date exception is raised" ---- *)
  val () = eqB ("Date.Date/raise-and-handle", true, fn () => (raise Date.Date) handle Date.Date => true)
  val () = eqB ("Date.Date/is-its-own-exception", true,
                fn () => (raise Date.Date) handle Time.Time => false | Fail _ => false | Date.Date => true)

  (* ---- date and the fields. The spec's example of toString is Wednesday
     8 March 1995, 19:06:45; its yearDay is 31 + 28 + 7 = 66 ("1 January is
     day 0"). ---- *)
  fun example () = utc (1995, Date.Mar, 8, 19, 6, 45)
  val () = eqI ("Date.year/example", 1995, fn () => Date.year (example ()))
  val () = eqM ("Date.month/example", Date.Mar, fn () => Date.month (example ()))
  val () = eqI ("Date.day/example", 8, fn () => Date.day (example ()))
  val () = eqI ("Date.hour/example", 19, fn () => Date.hour (example ()))
  val () = eqI ("Date.minute/example", 6, fn () => Date.minute (example ()))
  val () = eqI ("Date.second/example", 45, fn () => Date.second (example ()))
  val () = eqW ("Date.weekDay/example", Date.Wed, fn () => Date.weekDay (example ()))
  val () = eqI ("Date.yearDay/example", 66, fn () => Date.yearDay (example ()))
  val () = eqOffset ("Date.offset/UTC", SOME 0, example)
  (* UTC has no daylight saving time *)
  val () = eqB ("Date.isDst/UTC-is-not-daylight-saving", true, fn () => Date.isDst (example ()) <> SOME true)
  val () = eqFields ("Date.date/canonical-is-kept", (1995, Date.Mar, 8, 19, 6, 45), example)
  (* "the date Robin Milner received the Turing award would have year 1991" *)
  val () = eqI ("Date.year/base-0", 1991,
                fn () => Date.year (Date.fromTimeUniv (Date.toTime (utc (1991, Date.Jun, 1, 12, 0, 0)))))
  val () = eqI ("Date.yearDay/1-January-is-0", 0, fn () => Date.yearDay (utc (1999, Date.Jan, 1, 0, 0, 0)))
  val () = eqI ("Date.yearDay/31-December", 364, fn () => Date.yearDay (utc (1999, Date.Dec, 31, 23, 59, 59)))
  val () = eqI ("Date.yearDay/31-December-leap", 365, fn () => Date.yearDay (utc (2000, Date.Dec, 31, 0, 0, 0)))
  val () = eqI ("Date.yearDay/1-March-leap", 60, fn () => Date.yearDay (utc (2000, Date.Mar, 1, 0, 0, 0)))
  val () = eqI ("Date.yearDay/1-March", 59, fn () => Date.yearDay (utc (2001, Date.Mar, 1, 0, 0, 0)))
  val () = eqW ("Date.weekDay/2000-01-01", Date.Sat, fn () => Date.weekDay (utc (2000, Date.Jan, 1, 0, 0, 0)))
  val () = eqW ("Date.weekDay/2000-02-29", Date.Tue, fn () => Date.weekDay (utc (2000, Date.Feb, 29, 23, 59, 59)))
  val () = eqW ("Date.weekDay/1900-01-01", Date.Mon, fn () => Date.weekDay (utc (1900, Date.Jan, 1, 0, 0, 0)))
  val () = eqW ("Date.weekDay/2200-01-01", Date.Wed, fn () => Date.weekDay (utc (2200, Date.Jan, 1, 0, 0, 0)))

  (* ---- normalisation: "Seconds outside the range [0,59] are converted to
     the equivalent minutes and added to the minutes argument. Similar
     conversions are performed for minutes to hours, hours to days, days to
     months, and months to years. Negative values are similarly translated
     into a canonical range, with the extra borrowed from the next larger
     unit. Thus, minute = 10, second = ~140 becomes minute = 7, second = 40." ---- *)
  val () = eqFields ("Date.date/spec-example-negative-seconds", (2000, Date.Jan, 1, 12, 7, 40),
                     fn () => utc (2000, Date.Jan, 1, 12, 10, ~140))
  val () = eqFields ("Date.date/second-60", (2000, Date.Jan, 1, 12, 11, 0), fn () => utc (2000, Date.Jan, 1, 12, 10, 60))
  val () = eqFields ("Date.date/minutes-to-hours", (2000, Date.Jan, 1, 14, 30, 0), fn () => utc (2000, Date.Jan, 1, 12, 150, 0))
  val () = eqFields ("Date.date/hour-24", (2000, Date.Jan, 2, 0, 0, 0), fn () => utc (2000, Date.Jan, 1, 24, 0, 0))
  val () = eqFields ("Date.date/negative-hour", (1999, Date.Dec, 31, 23, 0, 0), fn () => utc (2000, Date.Jan, 1, ~1, 0, 0))
  val () = eqFields ("Date.date/days-to-months", (2000, Date.Feb, 1, 0, 0, 0), fn () => utc (2000, Date.Jan, 32, 0, 0, 0))
  val () = eqFields ("Date.date/day-0", (2000, Date.Feb, 29, 6, 0, 0), fn () => utc (2000, Date.Mar, 0, 6, 0, 0))
  val () = eqFields ("Date.date/negative-day", (2000, Date.Feb, 28, 6, 0, 0), fn () => utc (2000, Date.Mar, ~1, 6, 0, 0))
  val () = eqFields ("Date.date/months-to-years", (2000, Date.Jan, 1, 0, 0, 0), fn () => utc (1999, Date.Dec, 32, 0, 0, 0))
  val () = eqFields ("Date.date/seconds-carry-to-the-year", (2000, Date.Jan, 1, 0, 0, 0),
                     fn () => utc (1999, Date.Dec, 31, 23, 59, 60))
  val () = eqFields ("Date.date/seconds-borrow-from-the-year", (1999, Date.Dec, 31, 23, 59, 59),
                     fn () => utc (2000, Date.Jan, 1, 0, 0, ~1))
  val () = eqFields ("Date.date/a-year-of-seconds", (2002, Date.Jan, 1, 0, 0, 0),
                     fn () => utc (2001, Date.Jan, 1, 0, 0, 365 * day))
  val () = eqFields ("Date.date/366-days-of-2000", (2001, Date.Jan, 1, 0, 0, 0), fn () => utc (2000, Date.Jan, 367, 0, 0, 0))
  val () = eqFields ("Date.date/leap-2000", (2000, Date.Feb, 29, 0, 0, 0), fn () => utc (2000, Date.Feb, 29, 0, 0, 0))
  val () = eqFields ("Date.date/leap-2004", (2004, Date.Feb, 29, 0, 0, 0), fn () => utc (2004, Date.Feb, 29, 0, 0, 0))
  val () = eqFields ("Date.date/not-leap-2001", (2001, Date.Mar, 1, 0, 0, 0), fn () => utc (2001, Date.Feb, 29, 0, 0, 0))
  val () = eqFields ("Date.date/not-leap-1900", (1900, Date.Mar, 1, 0, 0, 0), fn () => utc (1900, Date.Feb, 29, 0, 0, 0))
  val () = eqFields ("Date.date/not-leap-2100", (2100, Date.Mar, 1, 0, 0, 0), fn () => utc (2100, Date.Feb, 29, 0, 0, 0))
  val () = eqW ("Date.date/weekDay-of-normalised", Date.Tue, fn () => Date.weekDay (utc (2000, Date.Mar, 0, 6, 0, 0)))
  val () = eqI ("Date.date/yearDay-of-normalised", 59, fn () => Date.yearDay (utc (2000, Date.Mar, 0, 6, 0, 0)))
  val () = eqB ("Date.date/is-canonical", true,
                fn () => let
                           val d = utc (2000, Date.Jan, 60, 25, 61, 61)
                           val d' = utc (Date.year d, Date.month d, Date.day d, Date.hour d, Date.minute d, Date.second d)
                         in fieldsOf d = fieldsOf d' andalso fieldsOf d = (2000, Date.Mar, 1, 2, 2, 1)
                            andalso Date.weekDay d = Date.weekDay d' andalso Date.yearDay d = Date.yearDay d'
                         end)
  (* a year that no implementation's time may hold: the date, or Date *)
  val () = eqB ("Date.date/Date-or-a-year-far-away", true,
                fn () => (Date.year (utc (100000000, Date.Jan, 1, 0, 0, 0)) = 100000000) handle Date.Date => true)

  (* ---- the offset: "A value of NONE represents the local time zone. A value
     of SOME(t) corresponds to time t west of UTC. ... Negative offsets denote
     time zones to the east of UTC ... Offsets are taken modulo 24 hours.
     That is, we express t, in hours, as sgn(t)(24*d + r), where d and r are
     non-negative, d is integral, and r < 24. The offset then becomes
     sgn(t)*r and sgn(t)(24*d) is added to the hours (before converting hours
     to days)." ---- *)
  fun zoned (h, offset) = at (2000, Date.Jan, 1, h, 0, 0, SOME (sec offset))
  val () = eqOffset ("Date.offset/west", SOME 18000, fn () => zoned (12, 18000))
  val () = eqOffset ("Date.offset/east", SOME ~19800, fn () => zoned (12, ~19800))
  val () = eqFields ("Date.offset/west-keeps-the-fields", (2000, Date.Jan, 1, 12, 0, 0), fn () => zoned (12, 18000))
  val () = eqFields ("Date.offset/east-keeps-the-fields", (2000, Date.Jan, 1, 12, 0, 0), fn () => zoned (12, ~19800))
  val () = eqOffset ("Date.offset/modulo-24-hours", SOME 3600, fn () => zoned (0, 25 * 3600))
  val () = eqFields ("Date.offset/modulo-24-hours-moves-the-date", (2000, Date.Jan, 2, 0, 0, 0), fn () => zoned (0, 25 * 3600))
  val () = eqOffset ("Date.offset/modulo-24-hours-negative", SOME ~3600, fn () => zoned (0, ~25 * 3600))
  val () = eqFields ("Date.offset/modulo-24-hours-negative-moves-the-date", (1999, Date.Dec, 31, 0, 0, 0),
                     fn () => zoned (0, ~25 * 3600))
  val () = eqOffset ("Date.offset/24-hours", SOME 0, fn () => zoned (0, 24 * 3600))
  val () = eqFields ("Date.offset/24-hours-moves-the-date", (2000, Date.Jan, 2, 0, 0, 0), fn () => zoned (0, 24 * 3600))
  val () = eqOffset ("Date.offset/49-hours-and-a-half", SOME 5400, fn () => zoned (0, 49 * 3600 + 1800))
  val () = eqOffset ("Date.offset/local-is-NONE", NONE, fn () => at (2000, Date.Jan, 1, 12, 0, 0, NONE))
  (* 12:00 at 5 hours west of UTC is 17:00 UTC; at 5:30 east it is 6:30 UTC *)
  val () = eqL ("Date.toTime/offset-west", large 18000,
                fn () => secondsBetween (utc (2000, Date.Jan, 1, 12, 0, 0), zoned (12, 18000)))
  val () = eqL ("Date.toTime/offset-east", large ~19800,
                fn () => secondsBetween (utc (2000, Date.Jan, 1, 12, 0, 0), zoned (12, ~19800)))
  val () = eqFields ("Date.toTime/offset-west-in-UTC", (2000, Date.Jan, 1, 17, 0, 0),
                     fn () => Date.fromTimeUniv (Date.toTime (zoned (12, 18000))))
  val () = eqFields ("Date.toTime/offset-east-in-UTC", (2000, Date.Jan, 1, 6, 30, 0),
                     fn () => Date.fromTimeUniv (Date.toTime (zoned (12, ~19800))))
  val () = eqL ("Date.toTime/offset-modulo-24-hours-is-the-same-time", large (25 * 3600),
                fn () => secondsBetween (utc (2000, Date.Jan, 1, 0, 0, 0), zoned (0, 25 * 3600)))
  val () = eqL ("Date.toTime/offset-modulo-24-hours-negative-is-the-same-time", large (~25 * 3600),
                fn () => secondsBetween (utc (2000, Date.Jan, 1, 0, 0, 0), zoned (0, ~25 * 3600)))

  (* ---- toTime: "the (UTC) time corresponding to the date"; fromTimeUniv:
     "the date in the UTC time zone ... The returned date will have
     offset=SOME(0)". ---- *)
  val () = eqL ("Date.toTime/a-day", days 1,
                fn () => secondsBetween (utc (2000, Date.Jan, 1, 0, 0, 0), utc (2000, Date.Jan, 2, 0, 0, 0)))
  val () = eqL ("Date.toTime/a-second", large 1,
                fn () => secondsBetween (utc (2000, Date.Jan, 1, 0, 0, 0), utc (2000, Date.Jan, 1, 0, 0, 1)))
  val () = eqL ("Date.toTime/leap-day", days 2,
                fn () => secondsBetween (utc (2000, Date.Feb, 28, 0, 0, 0), utc (2000, Date.Mar, 1, 0, 0, 0)))
  val () = eqL ("Date.toTime/no-leap-day", days 1,
                fn () => secondsBetween (utc (1999, Date.Feb, 28, 0, 0, 0), utc (1999, Date.Mar, 1, 0, 0, 0)))
  val () = eqL ("Date.toTime/leap-year", days 366,
                fn () => secondsBetween (utc (2000, Date.Jan, 1, 0, 0, 0), utc (2001, Date.Jan, 1, 0, 0, 0)))
  val () = eqL ("Date.toTime/year", days 365,
                fn () => secondsBetween (utc (2001, Date.Jan, 1, 0, 0, 0), utc (2002, Date.Jan, 1, 0, 0, 0)))
  val () = eqL ("Date.toTime/1972-to-2037", LargeInt.- (days (66 * 365 + 17), large 1),
                fn () => secondsBetween (utc (1972, Date.Jan, 1, 0, 0, 0), utc (2037, Date.Dec, 31, 23, 59, 59)))
  val () = eqL ("Date.toTime/last-second-of-1969", large 1,
                fn () => secondsBetween (utc (1969, Date.Dec, 31, 23, 59, 59), utc (1970, Date.Jan, 1, 0, 0, 0)))
  val () = eqL ("Date.toTime/century-from-1900", days 36524,
                fn () => secondsBetween (utc (1900, Date.Jan, 1, 0, 0, 0), utc (2000, Date.Jan, 1, 0, 0, 0)))
  val () = eqL ("Date.toTime/century-to-2100-beyond-2038", days 36525,
                fn () => secondsBetween (utc (2000, Date.Jan, 1, 0, 0, 0), utc (2100, Date.Jan, 1, 0, 0, 0)))
  val () = eqL ("Date.toTime/1900-to-2200", days (300 * 365 + 73),
                fn () => secondsBetween (utc (1900, Date.Jan, 1, 0, 0, 0), utc (2200, Date.Jan, 1, 0, 0, 0)))
  (* "It raises Date if the date date cannot be represented as a Time.time value" *)
  val () = eqB ("Date.toTime/Date-or-a-year-far-away", true,
                fn () => (Date.year (Date.fromTimeUniv (Date.toTime (utc (100000000, Date.Jan, 1, 0, 0, 0)))) = 100000000)
                         handle Date.Date => true)
  val () = eqOffset ("Date.fromTimeUniv/offset-is-SOME-0", SOME 0, fn () => Date.fromTimeUniv (Time.now ()))
  val () = eqB ("Date.fromTimeUniv/not-daylight-saving", true, fn () => Date.isDst (Date.fromTimeUniv (Time.now ())) <> SOME true)
  val () = eqFields ("Date.fromTimeUniv/inverts-toTime", (1995, Date.Mar, 8, 19, 6, 45),
                     fn () => Date.fromTimeUniv (Date.toTime (example ())))
  val () = eqW ("Date.fromTimeUniv/weekDay", Date.Wed, fn () => Date.weekDay (Date.fromTimeUniv (Date.toTime (example ()))))
  val () = eqI ("Date.fromTimeUniv/yearDay", 66, fn () => Date.yearDay (Date.fromTimeUniv (Date.toTime (example ()))))
  (* the date of a time is that of the second it falls in *)
  val () = eqFields ("Date.fromTimeUniv/fraction-of-a-second", (2001, Date.Jun, 30, 23, 59, 59),
                     fn () => Date.fromTimeUniv (Time.+ (Date.toTime (utc (2001, Date.Jun, 30, 23, 59, 59)), Time.fromMilliseconds (large 999))))
  val () = eqFields ("Date.fromTimeUniv/fraction-of-a-second-1969", (1969, Date.Dec, 31, 23, 59, 59),
                     fn () => Date.fromTimeUniv (Time.+ (Date.toTime (utc (1969, Date.Dec, 31, 23, 59, 59)), Time.fromMilliseconds (large 500))))
  val () = eqB ("Date.toTime/inverts-fromTimeUniv", true,
                fn () => let val t = Time.fromSeconds (Time.toSeconds (Time.now ()))
                         in Date.toTime (Date.fromTimeUniv t) = t end)
  (* The clock of the machine shows a date after 2020 (and before 2200). *)
  val () = eqB ("Date.fromTimeUniv/now-is-after-2020", true,
                fn () => let val y = Date.year (Date.fromTimeUniv (Time.now ())) in y >= 2020 andalso y < 2200 end)

  (* The calendar of pseudo-random times: n days and s seconds after
     1 January 1972 (a Saturday) up to 2037, and after 1 January 1900 (a
     Monday) up to 2199. *)
  fun calendar (baseYear, baseWeekday, days) () =
    let
      val base = Date.toTime (utc (baseYear, Date.Jan, 1, 0, 0, 0))
      val (n, s) = (T.range (0, days - 1), T.range (0, day - 1))
    in (base, baseWeekday, baseYear, n, s) end
  fun calendarHolds (base, baseWeekday, baseYear, n, s) =
    let
      val d = Date.fromTimeUniv (Time.+ (base, Time.fromSeconds (LargeInt.+ (days n, large s))))
      val (y, m, dd, yday) = civil (baseYear, n)
    in
      fieldsOf d = (y, m, dd, s div 3600, s mod 3600 div 60, s mod 60)
      andalso Date.yearDay d = yday andalso Date.weekDay d = weekdayAfter (baseWeekday, n)
      andalso offsetOf d = SOME (large 0)
    end
  fun showCalendar (_, _, baseYear, n, s) = Int.toString baseYear ^ " + " ^ showDaySecond (n, s)
  val () = law ("Date.fromTimeUniv/calendar-1972-2037", 300, calendar (1972, Date.Sat, 66 * 365 + 17),
                calendarHolds, showCalendar)
  val () = law ("Date.fromTimeUniv/calendar-1900-2199", 300, calendar (1900, Date.Mon, 300 * 365 + 73),
                calendarHolds, showCalendar)
  (* the same days built by date, from 1 January and n days and s seconds *)
  val () = law ("Date.date/calendar-1900-2199", 300, fn () => (T.range (0, 300 * 365 + 72), T.range (0, day - 1)),
                fn (n, s) => let
                               val d = utc (1900, Date.Jan, 1 + n, 0, 0, s)
                               val (y, m, dd, yday) = civil (1900, n)
                             in
                               fieldsOf d = (y, m, dd, s div 3600, s mod 3600 div 60, s mod 60)
                               andalso Date.yearDay d = yday andalso Date.weekDay d = weekdayAfter (Date.Mon, n)
                             end,
                showDaySecond)
  val () = law ("Date.toTime/fromTimeUniv-inverts-1972-2037", 200, calendar (1972, Date.Sat, 66 * 365 + 17),
                fn (base, _, _, n, s) => let val t = Time.+ (base, Time.fromSeconds (LargeInt.+ (days n, large s)))
                                         in Date.toTime (Date.fromTimeUniv t) = t end,
                showCalendar)

  (* ---- compare: "It lexicographically compares the dates, using the year,
     month, day, hour, minute, and second information, but ignoring the
     offset and daylight savings time information." ---- *)
  val eqO = T.eq T.order
  fun cmp (a, b) = Date.compare (utc a, utc b)
  val () = eqO ("Date.compare/equal", EQUAL, fn () => cmp ((2000, Date.Jan, 1, 0, 0, 0), (2000, Date.Jan, 1, 0, 0, 0)))
  val () = eqO ("Date.compare/year", LESS, fn () => cmp ((1999, Date.Dec, 31, 23, 59, 59), (2000, Date.Jan, 1, 0, 0, 0)))
  val () = eqO ("Date.compare/month", GREATER, fn () => cmp ((2000, Date.Feb, 1, 0, 0, 0), (2000, Date.Jan, 31, 23, 59, 59)))
  val () = eqO ("Date.compare/day", LESS, fn () => cmp ((2000, Date.Mar, 9, 23, 0, 0), (2000, Date.Mar, 10, 0, 0, 0)))
  val () = eqO ("Date.compare/hour", GREATER, fn () => cmp ((2000, Date.Mar, 9, 13, 0, 0), (2000, Date.Mar, 9, 12, 59, 59)))
  val () = eqO ("Date.compare/minute", LESS, fn () => cmp ((2000, Date.Mar, 9, 13, 5, 59), (2000, Date.Mar, 9, 13, 6, 0)))
  val () = eqO ("Date.compare/second", GREATER, fn () => cmp ((2000, Date.Mar, 9, 13, 5, 2), (2000, Date.Mar, 9, 13, 5, 1)))
  val () = eqO ("Date.compare/ignores-the-offset", EQUAL,
                fn () => Date.compare (zoned (12, 18000), utc (2000, Date.Jan, 1, 12, 0, 0)))
  val () = eqO ("Date.compare/ignores-the-offset-not-the-time", LESS,
                fn () => Date.compare (zoned (11, ~18000), utc (2000, Date.Jan, 1, 12, 0, 0)))
  val () = eqO ("Date.compare/local-and-UTC", EQUAL,
                fn () => Date.compare (at (2001, Date.Jul, 15, 12, 0, 0, NONE), utc (2001, Date.Jul, 15, 12, 0, 0)))
  val () = law ("Date.compare/agrees-with-toTime-for-UTC", 200,
                fn () => ((T.range (0, 17000), T.range (0, day - 1)), (T.range (0, 17000), T.range (0, day - 1))),
                fn ((n1, s1), (n2, s2)) => let val a = utc (1990, Date.Jan, 1 + n1, 0, 0, s1)
                                               val b = utc (1990, Date.Jan, 1 + n2, 0, 0, s2)
                                           in Date.compare (a, b) = Time.compare (Date.toTime a, Date.toTime b)
                                              andalso Date.compare (a, a) = EQUAL end,
                fn (a, b) => showDaySecond a ^ ", " ^ showDaySecond b)

  (* ---- local time. fromTimeLocal: "The returned date will have
     offset=NONE. ... If these functions are applied to the same time value,
     the resulting dates will differ by the offset of the local time zone
     from UTC." The checks hold in every time zone. ---- *)
  (* times away from the changes of daylight saving time of every zone:
     15 January and 15 July 2001, noon UTC, and now to the second *)
  fun times () = [Date.toTime (utc (2001, Date.Jan, 15, 12, 0, 0)), Date.toTime (utc (2001, Date.Jul, 15, 12, 0, 0)),
                  Time.fromSeconds (Time.toSeconds (Time.now ()))]
  (* west t: the offset in effect at time t, in seconds west of UTC: t minus
     the local date of t read as a UTC date *)
  fun asUTC d = utc (Date.year d, Date.month d, Date.day d, Date.hour d, Date.minute d, Date.second d)
  fun west t = Time.toSeconds (Time.- (t, Date.toTime (asUTC (Date.fromTimeLocal t))))
  val () = eqB ("Date.fromTimeLocal/offset-is-NONE", true,
                fn () => List.all (fn t => Date.offset (Date.fromTimeLocal t) = NONE) (times ()))
  val () = eqB ("Date.fromTimeLocal/toTime-inverts", true,
                fn () => List.all (fn t => Date.toTime (Date.fromTimeLocal t) = t) (times ()))
  val () = eqB ("Date.fromTimeLocal/differs-from-UTC-by-less-than-a-day", true,
                fn () => List.all (fn t => let val w = west t in LargeInt.> (w, days ~1) andalso LargeInt.< (w, days 1) end) (times ()))
  val () = eqB ("Date.fromTimeLocal/differs-from-UTC-by-whole-minutes", true,
                fn () => List.all (fn t => LargeInt.mod (west t, large 60) = large 0) (times ()))
  (* the fields of the local date with the offset of the zone as the offset:
     the same time *)
  val () = eqB ("Date.date/offset-of-the-local-zone", true,
                fn () => List.all (fn t =>
                                     let val l = Date.fromTimeLocal t
                                         val d = at (Date.year l, Date.month l, Date.day l, Date.hour l, Date.minute l,
                                                     Date.second l, SOME (Time.fromSeconds (west t)))
                                     in Date.toTime d = t end) (times ()))
  val () = eqB ("Date.fromTimeLocal/same-weekDay-and-yearDay-as-the-fields", true,
                fn () => List.all (fn t => let val l = Date.fromTimeLocal t val u = asUTC l
                                           in Date.weekDay l = Date.weekDay u andalso Date.yearDay l = Date.yearDay u end)
                                  (times ()))
  val () = eqFields ("Date.date/local-normalises", (2001, Date.Feb, 1, 12, 0, 0),
                     fn () => at (2001, Date.Jan, 32, 12, 0, 0, NONE))
  val () = eqFields ("Date.toTime/local-date", (2001, Date.Jul, 15, 12, 0, 0),
                     fn () => Date.fromTimeLocal (Date.toTime (at (2001, Date.Jul, 15, 12, 0, 0, NONE))))
  val () = eqFields ("Date.toTime/local-date-in-January", (2001, Date.Jan, 15, 0, 30, 0),
                     fn () => Date.fromTimeLocal (Date.toTime (at (2001, Date.Jan, 15, 0, 30, 0, NONE))))
  (* no zone has daylight saving time both in January and in July *)
  val () = eqB ("Date.isDst/not-both-January-and-July", true,
                fn () => case List.map (Date.isDst o Date.fromTimeLocal) (times ()) of
                           a :: b :: _ => not (a = SOME true andalso b = SOME true)
                         | _ => false)
  (* "The offset from UTC for the local time zone", west of UTC like the
     offsets of dates. The page does not say whether it includes daylight
     saving time, and takes offsets modulo 24 hours: it is the offset in
     effect now, or an hour more, modulo a day. *)
  val () = eqB ("Date.localOffset/west-of-UTC-now", true,
                fn () => let
                           val w = west (Time.fromSeconds (Time.toSeconds (Time.now ())))
                           val l = Time.toSeconds (Date.localOffset ())
                           val r = LargeInt.mod (LargeInt.- (l, w), days 1)
                         in r = large 0 orelse r = large 3600 end)
  val () = eqB ("Date.localOffset/less-than-a-day", true,
                fn () => let val l = Time.toSeconds (Date.localOffset ()) in LargeInt.> (l, days ~1) andalso LargeInt.< (l, days 1) end)
  val () = eqB ("Date.localOffset/whole-minutes", true, fn () => LargeInt.mod (Time.toSeconds (Date.localOffset ()), large 60) = large 0)
end

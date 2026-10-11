(* Date.date and Date.toTime as fix.diff leaves them, copied from date.sml
   into a standalone program, with the parts that need the runtime (a date
   without an offset, converted by mktime) left out. Run it in a few time
   zones: TZ=Europe/London sml fix-check.sml, TZ=America/Chicago, TZ=Asia/Tokyo,
   TZ=UTC. It checks
   - the lines of bug.sml;
   - the law that found the bug, toTime (fromTimeUniv t) = t, for t = 0 and
     100,000 random whole seconds from 1970 to 2106 (fromTimeUniv, from the
     runtime's gmtime, is right for these; up to 2038 where time_t has 32
     bits, as on the 32-bit build);
   - that a date at an offset w west of UTC is the time of its fields read as
     UTC plus w, for 100,000 random dates from 1900 to 2200 and offsets of
     -47 to 47 hours (Date.date normalizes an offset of a day or more);
   - where the time zone is UTC, that it agrees with SML/NJ's own toTime of
     the same date without an offset, for 100,000 random dates from 1970 to
     2200 (to 2037 where time_t has 32 bits). *)
structure D = struct
    exception Date = Date.Date
    fun mkTime' _ = raise Fail "local dates are not copied"
    fun date2tm _ = ()
    fun nsToTime _ = Time.zeroTime

    datatype weekday = datatype Date.weekday

    datatype month = datatype Date.month

    datatype date = DATE of {
	year : int,			(* 1.. *)
	month : month,
	day : int,			(* 1..31 *)
	hour : int,			(* 0..23 *)
	minute : int,			(* 0..59 *)
	second : int,			(* 0..61 (allowing for leap seconds) *)
	offset : Time.time option,	(* signed delta east of UTC; add to UTC to get local time *)
	wday : weekday,
	yday : int,			(* 0..365 *)
	isDst : bool option
      }

  (* tables for mapping integers to days/months *)
    val dayTbl = #[Sun, Mon, Tue, Wed, Thu, Fri, Sat]
    val monthTbl = #[Jan, Feb, Mar, Apr, May, Jun, Jul,
		     Aug, Sep, Oct, Nov, Dec]

    fun dayToInt Sun = 0
      | dayToInt Mon = 1
      | dayToInt Tue = 2
      | dayToInt Wed = 3
      | dayToInt Thu = 4
      | dayToInt Fri = 5
      | dayToInt Sat = 6

  (* careful about this: the month numbers are 0-11 *)
    fun monthToInt Jan = 0
      | monthToInt Feb = 1
      | monthToInt Mar = 2
      | monthToInt Apr = 3
      | monthToInt May = 4
      | monthToInt Jun = 5
      | monthToInt Jul = 6
      | monthToInt Aug = 7
      | monthToInt Sep = 8
      | monthToInt Oct = 9
      | monthToInt Nov = 10
      | monthToInt Dec = 11

    fun year (DATE{year, ...}) = year
    fun month (DATE{month, ...}) = month
    fun day (DATE{day, ...}) = day
    fun hour (DATE{hour, ...}) = hour
    fun minute (DATE{minute, ...}) = minute
    fun second (DATE{second, ...}) = second
    fun weekDay (DATE{wday, ...}) = wday
    fun yearDay (DATE{yday, ...}) = yday
    fun isDst (DATE{isDst, ...}) = isDst
    fun offset (DATE{offset,...}) = offset


    type gregorian_date = {
	year : int,	(* 1.. (* year 1 == 1 AD *) *)
	month : int,	(* 1..12 *)
	day : int	(* 1..31 *)
      }

    local
      val monthLengths = #[31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
    (* the number of days in the year before the 1st of the month; it is
     * the prefix sum of monthLengths
     *)
      val daysBeforeMonth = #[0,31,59,90,120,151,181,212,243,273,304,334];
    (* for greforian dates, months are numbered from 1 *)
      val febId = 2
    in
  (* return true for leap years *)
    fun isLeapYear y = (y mod 4 = 0) andalso ((y mod 100 <> 0) orelse (y mod 400 = 0))
  (* return the number of days in a month given the year and month *)
    fun lastDayOfGregorianMonth {month, year} = if month = febId andalso isLeapYear year
	  then 29
	  else Vector.sub(monthLengths, month-1)
  (* return the # of days of the year before the given Gregorian date; 0 is January 1st *)
    fun daysInYear {year, month, day} = let
	  val n = Vector.sub(daysBeforeMonth, month-1) + day
	  in
	    if (febId < month) andalso isLeapYear year
	      then n
	      else n-1
	  end
  (* convert a Gregorian date to an absolute day (i.e., the day index starting with day 1
   * being January 1, year 1 AD.
   *)
    fun toAbsoluteDay {year, month, day} = let
	  val priorYears = year - 1
	  val n = daysInYear {year=year, month=month, day=day}
	  val n = n + 365 * priorYears		(* days in previous years ignoring leap days *)
	  val n = n + priorYears div 4		(* Julian leap days before this year... *)
	  val n = n - priorYears div 100	(* ...minus prior century years... *)
	  val n = n + priorYears div 400	(* ...plus prior years divisible by 400 *)
	  in
	    n + 1
	  end
  (* convert an abosolute day to a Gregorian date *)
    fun fromAbsoluteDay d = let
	(* search forward from a lower bound on the year *)
	  val year = let
		fun lp y = if toAbsoluteDay{year=y+1, month=1, day=1} <= d
		      then lp (y+1)
		      else y
		in
		  lp (d div 366)
		end
	(* search forward from January *)
	  val month = let
		fun lp m = let
		      val d' = lastDayOfGregorianMonth{month = m, year = year}
		      in
			if toAbsoluteDay{year=year, month=m, day=d'} < d
			  then lp(m+1)
			  else m
		      end
		in
		  lp 1
		end
	  in {
	    year = year, month = month,
	    day = d - toAbsoluteDay{year=year, month=month, day=1} + 1
	  } end
  (* return the number of days in a given year *)
    fun yearLength year = if isLeapYear year then 366 else 365
    end
(* DEBUG **
  (* some internal test cases *)
    local
    fun test name true = print(concat["!!! test ", name, " OK\n"])
      | test name false = print(concat["!!! test ", name, " FAILED\n"])
    in
    val _ = test "t01" (toAbsoluteDay {year=1, month=1, day=1} = 1)
    val _ = test "t02" (toAbsoluteDay {year=1, month=12, day=31} = 365)
    val _ = test "t03" (toAbsoluteDay {year=2, month=1, day=1} = 366)
    val _ = test "t04" (daysInYear {year=1, month=12, day=31} = 364)
    val _ = test "t05" (daysInYear {year=2000, month=12, day=31} = 365)
    val _ = test "t06" (isLeapYear 2000 andalso isLeapYear 2004 andalso isLeapYear 2400)
    val _ = test "t07" (not (List.exists isLeapYear [1800, 1900, 2100, 2200, 2300, 2500]))
    val _ = test "t08" (toAbsoluteDay(fromAbsoluteDay 1) = 1)
    val _ = test "t09" (toAbsoluteDay(fromAbsoluteDay 364) = 364)
    val _ = test "t10" (toAbsoluteDay(fromAbsoluteDay 365) = 365)
    val _ = test "t11" (toAbsoluteDay(fromAbsoluteDay 366) = 366)
    val _ = test "t12" (toAbsoluteDay(fromAbsoluteDay 1460) = 1460)
    val _ = test "t13" (toAbsoluteDay(fromAbsoluteDay 1461) = 1461)
    val _ = test "t14" (toAbsoluteDay(fromAbsoluteDay 5000) = 5000)
    end
** DEBUG *)

  (* canonicalization of a date record.  Note that the month values are
   * 0 based (unlike the 1-based values of a gregorian_date).
   *)
    fun normalizeDate {year, month, day, hour, minute, second} = let
	  fun divMod (a, b) = let
		val q = a div b
		in
		  (q, a - q * b)
		end
	  val (minute, second) = let
		val (m, s) = divMod (second, 60)
		in
		  (minute + m, s)
		end
	  val (hour, minute) = let
		val (h, m) = divMod (minute, 60)
		in
		  (hour + h, m)
		end
	  val (absDay, hour) = let
		val (d, h) = divMod (hour, 24)
		val day = day + d
		in
		(* note that toAbsoluteDay will handle the case where day <= 0 *)
		  (toAbsoluteDay{year = year, month=month+1, day=day}, h)
		end
	(* we only allow CE (aka AD) dates *)
	  val _ = if (absDay <= 0) then raise Date else ()
	  val (year, month, day) = let
		val {year, month, day} = fromAbsoluteDay absDay
		in
		  (year, month-1, day)
		end
	  in {
	    year = year, month = month, day = day, absDay = absDay,
	    hour = hour, minute = minute, second = second
	  } end

    val secsPerDay : IntInf.int = 24*60*60

    fun date {year, month, day, hour, minute, second, offset} = let
	  val (secAdjust, offset) = (case offset
		 of NONE => (0, NONE)
		  | SOME t => let
		      (* normalize offset to +/- one day in seconds.  Note that it
                       * it is necessary to use "quot/rem" so that we round toward
                       * zero when `t` is negative!
                       *)
		      val (adjust, offset) = IntInf.quotRem(Time.toSeconds t, secsPerDay)
                      val adjust = adjust * secsPerDay
		      in
			(Int.fromLarge adjust, SOME(Time.fromSeconds offset))
		      end
		(* end case *))
	  val normDate = normalizeDate {
		  year = year, month = monthToInt month, day = day,
		  hour = hour, minute = minute, second = second + secAdjust
		}
	(* check that we are in AD at least *)
	  val _ = if #year normDate < 0 then raise Date else ()
	  in
	    DATE{
		year = #year normDate,
		month = Vector.sub (monthTbl, #month normDate),
		day = #day normDate,
		hour = #hour normDate,
		minute = #minute normDate,
		second = #second normDate,
		offset = offset,
		isDst = NONE,
		yday = daysInYear {
		    year = #year normDate, month = #month normDate + 1, day = #day normDate
		  },
		wday = Vector.sub(dayTbl, #absDay normDate mod 7)
	      }
	  end


  (* return the UTC time corresponding to the given date. *)
    fun toTime (date as DATE{year, month, day, hour, minute, second, offset, ...}) = (
	  case offset
	   of NONE => nsToTime (mkTime' (date2tm date))
	    | SOME offset => let
	      (* a date at an offset is converted by the calendar: the local time zone
	       * has no part in it, and mkTime' would refuse a date that is before the
	       * epoch in the local time zone.  The offset is west of UTC, so it is
	       * added to the time of the fields read as UTC.
	       *)
		val days = toAbsoluteDay {year = year, month = monthToInt month + 1, day = day}
		      - toAbsoluteDay {year = 1970, month = 1, day = 1}
		val secs = ((Int.toLarge days * 24 + Int.toLarge hour) * 60
		      + Int.toLarge minute) * 60 + Int.toLarge second
		in
		  Time.+(Time.fromSeconds secs, offset)
		end
	  (* end case *))

end

fun secs t = IntInf.toString (Time.toSeconds t)
fun copyOf d = D.date {year = Date.year d, month = Date.month d, day = Date.day d, hour = Date.hour d,
                       minute = Date.minute d, second = Date.second d, offset = Date.offset d}
fun show (name, d, expected) =
      let val got = (secs (D.toTime (d ()))) handle Date.Date => "Date"
      in print (concat [name, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
fun at offset ((year, month, day), (hour, minute, second)) () =
      D.date {year = year, month = month, day = day, hour = hour, minute = minute,
              second = second, offset = SOME offset}
val utc = at Time.zeroTime
val hours = Time.fromSeconds o (fn h => h * 3600)
val () = show ("toTime (fromTimeUniv zeroTime)", fn () => copyOf (Date.fromTimeUniv Time.zeroTime), "0")
val () = show ("toTime 1970-01-01 01:00:00 UTC", utc ((1970, Date.Jan, 1), (1, 0, 0)), "3600")
val () = show ("toTime 2000-01-01 12:30:45 UTC", utc ((2000, Date.Jan, 1), (12, 30, 45)), "946729845")
val () = show ("toTime 2000-07-01 12:30:45 UTC", utc ((2000, Date.Jul, 1), (12, 30, 45)), "962454645")
val () = show ("toTime 2000-01-01 12:00:00 5 hours west", at (hours 5) ((2000, Date.Jan, 1), (12, 0, 0)), "946746000")
val () = show ("toTime 1969-12-31 23:00:00 UTC", utc ((1969, Date.Dec, 31), (23, 0, 0)), "~3600")
val () = show ("toTime 2000-01-01 12:00:00 25 hours west", at (hours 25) ((2000, Date.Jan, 1), (12, 0, 0)), "946818000")

val rng = Random.rand (7, 11)
fun big lo hi = IntInf.fromInt lo + IntInf.fromInt (Random.randRange (0, hi - lo) rng)
val months = Vector.fromList [Date.Jan, Date.Feb, Date.Mar, Date.Apr, Date.May, Date.Jun,
                              Date.Jul, Date.Aug, Date.Sep, Date.Oct, Date.Nov, Date.Dec]
fun count (n, p) = let fun lp (0, k) = k | lp (i, k) = lp (i - 1, if p () then k else k + 1) in lp (n, 0) end
(* does the runtime's time_t go past 2038? *)
val wide = (Date.year (Date.fromTimeUniv (Time.fromSeconds 4294967295)) = 2106) handle _ => false
(* the law, for t from 1970 to 2106 (2038) *)
val bad1 = count (100000, fn () =>
             let val t = Time.fromSeconds (big 0 1073741823 * (if wide then 4 else 2) + big 0 1)
             in Time.toSeconds (D.toTime (copyOf (Date.fromTimeUniv t))) = Time.toSeconds t end)
fun calendar (y, m, d, h, mi, s) =
      IntInf.fromInt (((D.toAbsoluteDay {year = y, month = m, day = d} - D.toAbsoluteDay {year = 1970, month = 1, day = 1}) * 24 + h) * 60 + mi) * 60
      + IntInf.fromInt s
fun randomDate (lo, hi) =
      let val y = Random.randRange (lo, hi) rng
          val m = Random.randRange (1, 12) rng
          val d = Random.randRange (1, D.lastDayOfGregorianMonth {month = m, year = y}) rng
      in (y, m, d, Random.randRange (0, 23) rng, Random.randRange (0, 59) rng, Random.randRange (0, 59) rng) end
(* a date at an offset is the time of its fields as UTC plus the offset *)
val bad2 = count (100000, fn () =>
             let val (f as (y, m, d, h, mi, s)) = randomDate (1900, 2200)
                 val w = big (~47 * 3600) (47 * 3600)
                 val dt = D.date {year = y, month = Vector.sub (months, m - 1), day = d, hour = h, minute = mi,
                                  second = s, offset = SOME (Time.fromSeconds w)}
             in Time.toSeconds (D.toTime dt) = calendar f + w end)
(* in UTC, the same as SML/NJ's toTime of the date without an offset *)
val isUTC = Time.toSeconds (Date.localOffset ()) = 0
                andalso (Time.toSeconds (Date.toTime (Date.date {year = 2000, month = Date.Jul, day = 1, hour = 0, minute = 0, second = 0, offset = NONE})) = 962409600)
val bad3 = if not isUTC then ~1 else count (100000, fn () =>
             let val (y, m, d, h, mi, s) = randomDate (1970, if wide then 2200 else 2037)
                 val f = {year = y, month = Vector.sub (months, m - 1), day = d, hour = h, minute = mi, second = s}
                 fun withOffset off = {year = #year f, month = #month f, day = #day f, hour = #hour f,
                                       minute = #minute f, second = #second f, offset = off}
             in Time.toSeconds (D.toTime (D.date (withOffset (SOME Time.zeroTime))))
                = Time.toSeconds (Date.toTime (Date.date (withOffset NONE))) end)
val () = print (concat ["toTime (fromTimeUniv t) <> t for ", Int.toString bad1, " of 100000\n",
                        "date at an offset not its fields as UTC plus the offset for ", Int.toString bad2, " of 100000\n",
                        if bad3 < 0 then "(the time zone is not UTC: the comparison with SML/NJ's own toTime is skipped)\n"
                        else "differs from SML/NJ's toTime in UTC for " ^ Int.toString bad3 ^ " of 100000\n"])
val () = OS.Process.exit OS.Process.success

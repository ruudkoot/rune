(* Date: a moment as a person writes it down. *)
structure Date =
struct
  datatype weekday = Mon | Tue | Wed | Thu | Fri | Sat | Sun
  datatype month = Jan | Feb | Mar | Apr | May | Jun | Jul | Aug | Sep | Oct | Nov | Dec
  exception Date

  (* The offset is the time zone the date is in: NONE local, SOME t the time
     t west of UTC, less than a day either way. *)
  type date = {year : int, month : month, day : int, hour : int, minute : int, second : int,
               offset : Time.time option, wday : weekday, yday : int, isDst : bool option}

  local
    val parts' = _prim "date_parts" : int * int -> int list
    val seconds' = _prim "date_seconds" : int list * int -> int list
    val offset' = _prim "date_offset" : int -> int
    val format' = _prim "date_format" : string * int list * int -> string
  in
    val months = [Jan, Feb, Mar, Apr, May, Jun, Jul, Aug, Sep, Oct, Nov, Dec]
    val weekdays = [Sun, Mon, Tue, Wed, Thu, Fri, Sat]   (* as the C library numbers them *)

    fun monthNumber m =
      let fun go (k, x :: rest) = if x = m then k else go (k + 1, rest)
            | go (k, []) = 0
      in go (0, months) end
    fun monthOf k = List.nth (months, k)
    fun weekdayNumber d =
      let fun go (k, x :: rest) = if x = d then k else go (k + 1, rest)
            | go (k, []) = 0
      in go (0, weekdays) end
    fun weekdayOf k = List.nth (weekdays, k)

    fun year (d : date) = #year d
    fun month (d : date) = #month d
    fun day (d : date) = #day d
    fun hour (d : date) = #hour d
    fun minute (d : date) = #minute d
    fun second (d : date) = #second d
    fun weekDay (d : date) = #wday d
    fun yearDay (d : date) = #yday d
    fun isDst (d : date) = #isDst d
    fun offset (d : date) = #offset d

    fun partsOf (seconds, local') =
      case parts' (seconds, if local' then 1 else 0) of
        [sec, min, hr, mday, mon, yr, wday, yday, dst] =>
          {second = sec, minute = min, hour = hr, day = mday, month = monthOf mon,
           year = yr + 1900, wday = weekdayOf wday, yday = yday,
           isDst = if dst < 0 then NONE else SOME (dst > 0)}
      | _ => raise Date

    (* The nine fields the primitives take. The weekday and the day of the
       year are there for strftime; the conversions to seconds work them out
       for themselves. *)
    fun listOf (d : date) =
      [#second d, #minute d, #hour d, #day d, monthNumber (#month d), #year d - 1900,
       weekdayNumber (#wday d), #yday d,
       case #isDst d of NONE => ~1 | SOME true => 1 | SOME false => 0]

    (* The proleptic Gregorian calendar ("Leap years follow the Gregorian
       calendar"), for the dates of a zone at a fixed offset from UTC, which
       need no time zone: the days from 1970-01-01 to y-m-d, for m in 1..12
       and any d, and back (Howard Hinnant's days_from_civil and
       civil_from_days; div rounds down, as they need). *)
    fun daysFromCivil (y, m, d) =
      let
        val y = if m <= 2 then y - 1 else y
        val era = y div 400
        val yoe = y - era * 400
        val doy = (153 * (if m > 2 then m - 3 else m + 9) + 2) div 5 + d - 1
      in era * 146097 + yoe * 365 + yoe div 4 - yoe div 100 + doy - 719468 end
    fun civilFromDays days =
      let
        val z = days + 719468
        val era = z div 146097
        val doe = z - era * 146097
        val yoe = (doe - doe div 1460 + doe div 36524 - doe div 146096) div 365
        val doy = doe - (365 * yoe + yoe div 4 - yoe div 100)
        val mp = (5 * doy + 2) div 153
        val m = if mp < 10 then mp + 3 else mp - 9
      in (yoe + era * 400 + (if m <= 2 then 1 else 0), m, doy - (153 * mp + 2) div 5 + 1) end
    fun monthLength (y, k) =    (* k = 0 for January *)
      daysFromCivil (if k = 11 then y + 1 else y, (k + 1) mod 12 + 1, 1) - daysFromCivil (y, k + 1, 1)

    (* The date of the fields in the zone at offset from UTC, normalised:
       "Seconds outside the range [0,59] are converted to the equivalent
       minutes and added to the minutes argument", and so on up to years. *)
    fun fixed (y, m, d, h, mi, s, offset) =
      let
        val mi = mi + s div 60
        val h = h + mi div 60
        val days = daysFromCivil (y, monthNumber m + 1, 1) + (d - 1) + h div 24
        val (y', m', d') = civilFromDays days
      in
        {year = y', month = monthOf (m' - 1), day = d', hour = h mod 24, minute = mi mod 60,
         second = s mod 60, offset = SOME offset,
         wday = weekdayOf ((days + 4) mod 7),                 (* 1970-01-01 was a Thursday *)
         yday = days - daysFromCivil (y', 1, 1), isDst = SOME false} : date
      end

    (* The date in the zone of offset, with the day of the week and of the
       year worked out and the fields normalised. "Offsets are taken modulo
       24 hours. That is, we express t, in hours, as sgn(t)(24*d + r) ... The
       offset then becomes sgn(t)*r and sgn(t)(24*d) is added to the hours";
       a local date is normalised by the C library, which knows the zone. *)
    fun date {year = y, month = m, day = d, hour = h, minute = mi, second = s, offset = off} =
      (case off of
         SOME t =>
           let
             val microsPerDay = 86400 * 1000000
             val sign = if Time.micros t < 0 then ~1 else 1
             val magnitude = Int.abs (Time.micros t)
           in
             fixed (y, m, d, h + sign * 24 * (magnitude div microsPerDay), mi, s,
                    Time.ofMicros (sign * (magnitude mod microsPerDay)))
           end
       | NONE =>
           case seconds' ([s, mi, h, d, monthNumber m, y - 1900, 0, 0, ~1], 1) of
             _ :: sec :: min :: hr :: mday :: mon :: yr :: wday :: yday :: dst :: _ =>
               {second = sec, minute = min, hour = hr, day = mday, month = monthOf mon,
                year = yr + 1900, wday = weekdayOf wday, yday = yday,
                isDst = if dst < 0 then NONE else SOME (dst > 0), offset = NONE}
           | _ => raise Date)
      handle Overflow => raise Date

    fun localOffset () = Time.ofMicros (Int.~ (offset' (Time.micros (Time.now ()) div 1000000)) * 1000000)

    fun fromTimeLocal t =
      let val d = partsOf (Time.micros t div 1000000, true)
      in ({second = #second d, minute = #minute d, hour = #hour d, day = #day d,
           month = #month d, year = #year d, wday = #wday d, yday = #yday d,
           isDst = #isDst d, offset = NONE} : date) end

    (* the second that t falls in, as a date in UTC *)
    fun fromTimeUniv t =
      let val s = Time.micros t div 1000000
      in fixed (1970, Jan, 1 + s div 86400, 0, 0, s mod 86400, Time.zeroTime) end

    (* "the date is interpreted in its own time zone": a date at an offset t
       west of UTC is t earlier than the same date in UTC *)
    fun toTime (d : date) =
      (case #offset d of
         SOME off =>
           let
             val days = daysFromCivil (#year d, monthNumber (#month d) + 1, #day d)
             val seconds = ((days * 24 + #hour d) * 60 + #minute d) * 60 + #second d
           in Time.+ (Time.ofMicros (seconds * 1000000), off) end
       | NONE =>
           case seconds' (listOf d, 1) of
             [] => raise Date
           | t :: _ => Time.ofMicros (t * 1000000))
      handle Overflow => raise Date | Time.Time => raise Date

    (* "They raise Date if the given date is invalid", as a date from scan
       may be. *)
    fun valid (d : date) =
      #day d >= 1 andalso #day d <= monthLength (#year d, monthNumber (#month d))
      andalso #hour d >= 0 andalso #hour d <= 23 andalso #minute d >= 0 andalso #minute d <= 59
      andalso #second d >= 0 andalso #second d <= 61

    (* Only the directives of the specification reach strftime: a % followed
       by another character c is "the character c". The C library knows the
       name of the local zone only; %Z of a date at an offset is zone. *)
    fun directives (format, zone) =
      let
        fun go (#"%" :: #"Z" :: rest, acc) =
              (case zone of
                 SOME name => go (rest, List.revAppend (String.explode name, acc))
               | NONE => go (rest, #"Z" :: #"%" :: acc))
          | go (#"%" :: c :: rest, acc) =
              if Char.contains "aAbBcdHIjmMpSUwWxXyYZ%" c then go (rest, c :: #"%" :: acc)
              else go (rest, c :: acc)
          | go ([#"%"], acc) = go ([], #"%" :: #"%" :: acc)
          | go (c :: rest, acc) = go (rest, c :: acc)
          | go ([], acc) = String.implode (List.rev acc)
      in go (String.explode format, []) end

    (* "time zone name or abbreviation, or the empty string if no time zone
       information exists": UTC, or nothing for another offset *)
    fun zoneName (d : date) =
      Option.map (fn t => if Time.micros t = 0 then "UTC" else "") (#offset d)

    fun fmt format (d : date) =
      if valid d then format' (directives (format, zoneName d), listOf d, if Option.isSome (#offset d) then 0 else 1)
      else raise Date

    (* strftime's %c, as the specification prescribes for toString:
       "Thu Sep 18 23:39:29 2026" *)
    fun toString d = fmt "%a %b %d %H:%M:%S %Y" d

    (* The reverse of toString: "Thu Sep 18 23:39:29 2026". *)
    fun scan getc src =
      let
        fun word (names, src) =
          let
            fun try ((text, value) :: rest) =
                (case exactly (text, src) of
                   SOME after => SOME (value, after)
                 | NONE => try rest)
              | try [] = NONE
            and exactly (text, src) =
              let
                fun go (i, src) =
                  if i >= size text then SOME src
                  else
                    case getc src of
                      SOME (c, rest) => if Char.toLower c = Char.toLower (String.sub (text, i)) then go (i + 1, rest) else NONE
                    | NONE => NONE
              in go (0, src) end
          in try names end
        fun number (src, atMost) =
          let
            fun go (src, acc, n) =
              if n >= atMost then (SOME acc, src)
              else
                case getc src of
                  SOME (c, rest) => if Char.isDigit c then go (rest, acc * 10 + (ord c - 48), n + 1)
                                    else (if n = 0 then NONE else SOME acc, src)
                | NONE => (if n = 0 then NONE else SOME acc, src)
          in go (src, 0, 0) end
        fun literal (c, src) =
          case getc src of SOME (c', rest) => if c = c' then SOME rest else NONE | NONE => NONE
        fun spaces src =
          case getc src of SOME (c, rest) => if Char.isSpace c then spaces rest else src | NONE => src
        val dayNames = List.map (fn d => (String.substring (dayName d, 0, 3), d)) weekdays
        val monthNames = List.map (fn m => (String.substring (monthName m, 0, 3), m)) months
        val src = StringCvt.skipWS getc src
      in
        case word (dayNames, src) of
          NONE => NONE
        | SOME (wday, src) =>
            let val src = spaces src
            in
              case word (monthNames, src) of
                NONE => NONE
              | SOME (mon, src) =>
                  let val src = spaces src
                  in
                    case number (src, 2) of
                      (NONE, _) => NONE
                    | (SOME day, src) =>
                        let val src = spaces src
                        in
                          case number (src, 2) of
                            (NONE, _) => NONE
                          | (SOME hour, src) =>
                              (case literal (#":", src) of
                                 NONE => NONE
                               | SOME src =>
                                   (case number (src, 2) of
                                      (NONE, _) => NONE
                                    | (SOME minute, src) =>
                                        (case literal (#":", src) of
                                           NONE => NONE
                                         | SOME src =>
                                             (case number (src, 2) of
                                                (NONE, _) => NONE
                                              | (SOME second, src) =>
                                                  let val src = spaces src
                                                  in
                                                    case number (src, 4) of
                                                      (NONE, _) => NONE
                                                    | (SOME year, src) =>
                                                        SOME ({year = year, month = mon, day = day,
                                                               hour = hour, minute = minute, second = second,
                                                               wday = wday, isDst = NONE, offset = NONE,
                                                               yday = daysFromCivil (year, monthNumber mon + 1, day)
                                                                      - daysFromCivil (year, 1, 1)} : date, src)
                                                  end))))
                        end
                  end
            end
      end

    and dayName Mon = "Monday" | dayName Tue = "Tuesday" | dayName Wed = "Wednesday"
      | dayName Thu = "Thursday" | dayName Fri = "Friday" | dayName Sat = "Saturday"
      | dayName Sun = "Sunday"
    and monthName Jan = "January" | monthName Feb = "February" | monthName Mar = "March"
      | monthName Apr = "April" | monthName May = "May" | monthName Jun = "June"
      | monthName Jul = "July" | monthName Aug = "August" | monthName Sep = "September"
      | monthName Oct = "October" | monthName Nov = "November" | monthName Dec = "December"

    fun fromString s = StringCvt.scanString scan s

    (* "returns LESS, EQUAL or GREATER according as the first date precedes,
       equals or follows the second"; the fields are compared in order. *)
    fun compare (a : date, b : date) =
      let
        fun cmp [] = EQUAL
          | cmp ((x, y) :: rest) = case Int.compare (x, y) of EQUAL => cmp rest | other => other
      in
        cmp [(#year a, #year b), (monthNumber (#month a), monthNumber (#month b)),
             (#day a, #day b), (#hour a, #hour b), (#minute a, #minute b), (#second a, #second b)]
      end
  end
end

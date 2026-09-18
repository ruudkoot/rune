(* Date: a moment as a person writes it down. *)
structure Date =
struct
  datatype weekday = Mon | Tue | Wed | Thu | Fri | Sat | Sun
  datatype month = Jan | Feb | Mar | Apr | May | Jun | Jul | Aug | Sep | Oct | Nov | Dec
  exception Date

  (* The offset is the time zone the date is in: NONE local, SOME t east of
     Greenwich (the specification's convention for the argument of date). *)
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

    (* The date in the zone of offset, with the day of the week and of the
       year worked out and the fields normalised. *)
    fun date {year = y, month = m, day = d, hour = h, minute = mi, second = s, offset = off} =
      let
        val local' = case off of NONE => true | SOME _ => false
        val fields = [s, mi, h, d, monthNumber m, y - 1900, 0, 0, if local' then ~1 else 0]
      in
        case seconds' (fields, if local' then 1 else 0) of
          _ :: sec :: min :: hr :: mday :: mon :: yr :: wday :: yday :: dst :: _ =>
            ({second = sec, minute = min, hour = hr, day = mday, month = monthOf mon,
             year = yr + 1900, wday = weekdayOf wday, yday = yday,
             isDst = if dst < 0 then NONE else SOME (dst > 0),
             offset = Option.map (fn t => Time.ofMicros (Int.mod (Time.micros t div 1000000, 86400) * 1000000)) off} : date)
        | _ => raise Date
      end

    fun localOffset () = Time.ofMicros (Int.~ (offset' (Time.micros (Time.now ()) div 1000000)) * 1000000)

    fun fromTimeLocal t =
      let val d = partsOf (Time.micros t div 1000000, true)
      in ({second = #second d, minute = #minute d, hour = #hour d, day = #day d,
           month = #month d, year = #year d, wday = #wday d, yday = #yday d,
           isDst = #isDst d, offset = NONE} : date) end

    fun fromTimeUniv t =
      let val d = partsOf (Time.micros t div 1000000, false)
      in ({second = #second d, minute = #minute d, hour = #hour d, day = #day d,
           month = #month d, year = #year d, wday = #wday d, yday = #yday d,
           isDst = #isDst d, offset = SOME Time.zeroTime} : date) end

    (* "the date is interpreted in its own time zone" *)
    fun toTime (d : date) =
      let
        val local' = case #offset d of NONE => true | SOME _ => false
      in
        case seconds' (listOf d, if local' then 1 else 0) of
          [] => raise Date
        | t :: _ =>
            (case #offset d of
               NONE => Time.ofMicros (t * 1000000)
             | SOME off => Time.- (Time.ofMicros (t * 1000000), off))
      end

    fun fmt format (d : date) =
      format' (format, listOf d, case #offset d of NONE => 1 | SOME _ => 0)

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
                                                               wday = wday, yday = 0, isDst = NONE,
                                                               offset = NONE} : date, src)
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

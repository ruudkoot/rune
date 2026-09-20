(* requires: Date Time StringCvt Substring *)
(* Date.fmt, Date.toString, Date.scan and Date.fromString. Expected values
   follow the text of https://smlfamily.github.io/Basis/date.html; the dates
   are in UTC.

   fmt follows "the semantics of the ISO C function strftime. In particular,
   fmt is locale-dependent." A program starts in the "C" locale (ISO C
   7.11.1.1: "At program startup, the equivalent of setlocale(LC_ALL, "C")
   is executed"), so that the names, %c, %p, %x and %X are those of the C
   locale; they are in the section c-locale. toString, scan and fromString
   are defined by the page itself: "Wed Mar 08 19:06:45 1995". *)
structure TestDateFmt =
struct
  val eqB = T.eq T.bool
  val eqS = T.eq T.string

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

  fun fieldsOf d = (Date.year d, Date.month d, Date.day d, Date.hour d, Date.minute d, Date.second d)
  fun showFields (y, m, d, h, mi, s) =
    Int.toString y ^ "-" ^ monthName m ^ "-" ^ Int.toString d ^ " "
    ^ Int.toString h ^ ":" ^ Int.toString mi ^ ":" ^ Int.toString s
  val eqFO = T.eq (T.option showFields)
  val eqScan = T.eq (T.option (T.pair (showFields, T.string)))

  fun utc (y, m, d, h, mi, s) =
    Date.date {year = y, month = m, day = d, hour = h, minute = mi, second = s, offset = SOME Time.zeroTime}
  (* the example of the page, a Wednesday, and a Sunday of the same week (the
     first day of the year 1995 was a Sunday: 5 March is day 63) *)
  fun wed () = utc (1995, Date.Mar, 8, 19, 6, 45)
  fun sun () = utc (1995, Date.Mar, 5, 9, 7, 3)
  fun fmt s d = Date.fmt s (d ())

  (* law (label, n, sample, holds, show) as in date.sml *)
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
  fun index (x, l) =
    let fun go (y :: rest, k) = if y = x then k else go (rest, k + 1)
          | go ([], k) = k
    in go (l, 0) end
  fun monthNumber m = 1 + index (m, months)
  fun sundayFirst d = index (d, [Date.Sun, Date.Mon, Date.Tue, Date.Wed, Date.Thu, Date.Fri, Date.Sat])
  fun pad2 n = if n < 10 then "0" ^ Int.toString n else Int.toString n
  (* a pseudo-random UTC date between 1970 and 2037 *)
  fun randomDate () = utc (1970, Date.Jan, T.range (1, 24837), T.range (0, 23), T.range (0, 59), T.range (0, 59))
  fun showDate d = showFields (fieldsOf d)

  val () = T.seed 1996

  (* ---- fmt: the numeric directives ---- *)
  val () = eqS ("Date.fmt/%d", "08", fn () => fmt "%d" wed)
  val () = eqS ("Date.fmt/%H", "19", fn () => fmt "%H" wed)
  val () = eqS ("Date.fmt/%I", "07", fn () => fmt "%I" wed)
  val () = eqS ("Date.fmt/%I-morning", "09", fn () => fmt "%I" sun)
  val () = eqS ("Date.fmt/%I-midnight", "12", fn () => Date.fmt "%I" (utc (1995, Date.Mar, 8, 0, 30, 0)))
  val () = eqS ("Date.fmt/%I-noon", "12", fn () => Date.fmt "%I" (utc (1995, Date.Mar, 8, 12, 30, 0)))
  val () = eqS ("Date.fmt/%I-one", "01", fn () => Date.fmt "%I" (utc (1995, Date.Mar, 8, 13, 30, 0)))
  val () = eqS ("Date.fmt/%j", "067", fn () => fmt "%j" wed)
  val () = eqS ("Date.fmt/%j-first-day", "001", fn () => Date.fmt "%j" (utc (1995, Date.Jan, 1, 0, 0, 0)))
  val () = eqS ("Date.fmt/%j-last-day-of-a-leap-year", "366", fn () => Date.fmt "%j" (utc (2000, Date.Dec, 31, 0, 0, 0)))
  val () = eqS ("Date.fmt/%m", "03", fn () => fmt "%m" wed)
  val () = eqS ("Date.fmt/%m-December", "12", fn () => Date.fmt "%m" (utc (1995, Date.Dec, 1, 0, 0, 0)))
  val () = eqS ("Date.fmt/%M", "06", fn () => fmt "%M" wed)
  val () = eqS ("Date.fmt/%S", "45", fn () => fmt "%S" wed)
  val () = eqS ("Date.fmt/%S-zero", "00", fn () => Date.fmt "%S" (utc (1995, Date.Mar, 8, 0, 0, 0)))
  (* %U: "week number of year [00-53], with the first Sunday as the first day
     of week 01"; %W the same with Monday; %w: "day of week [0-6], with 0
     representing Sunday" *)
  val () = eqS ("Date.fmt/%U", "10", fn () => fmt "%U" wed)
  val () = eqS ("Date.fmt/%U-Sunday", "10", fn () => fmt "%U" sun)
  val () = eqS ("Date.fmt/%W", "10", fn () => fmt "%W" wed)
  val () = eqS ("Date.fmt/%W-Sunday", "09", fn () => fmt "%W" sun)
  val () = eqS ("Date.fmt/%U-before-the-first-Sunday", "00", fn () => Date.fmt "%U" (utc (2000, Date.Jan, 1, 0, 0, 0)))
  val () = eqS ("Date.fmt/%W-before-the-first-Monday", "00", fn () => Date.fmt "%W" (utc (2000, Date.Jan, 2, 0, 0, 0)))
  val () = eqS ("Date.fmt/%W-first-Monday", "01", fn () => Date.fmt "%W" (utc (2000, Date.Jan, 3, 0, 0, 0)))
  val () = eqS ("Date.fmt/%w", "3", fn () => fmt "%w" wed)
  val () = eqS ("Date.fmt/%w-Sunday", "0", fn () => fmt "%w" sun)
  val () = eqS ("Date.fmt/%w-Saturday", "6", fn () => Date.fmt "%w" (utc (2000, Date.Jan, 1, 0, 0, 0)))
  val () = eqS ("Date.fmt/%y", "95", fn () => fmt "%y" wed)
  val () = eqS ("Date.fmt/%y-2005", "05", fn () => Date.fmt "%y" (utc (2005, Date.Jun, 1, 0, 0, 0)))
  val () = eqS ("Date.fmt/%Y", "1995", fn () => fmt "%Y" wed)
  val () = eqS ("Date.fmt/%%", "%", fn () => fmt "%%" wed)
  val () = eqS ("Date.fmt/%%Y", "%Y", fn () => fmt "%%Y" wed)
  val () = eqS ("Date.fmt/text-around-directives", "Year 1995, day 067.", fn () => fmt "Year %Y, day %j." wed)
  val () = eqS ("Date.fmt/no-directive", "no directive", fn () => fmt "no directive" wed)
  val () = eqS ("Date.fmt/empty", "", fn () => fmt "" wed)
  val () = eqS ("Date.fmt/several", "1995-03-08 19:06:45", fn () => fmt "%Y-%m-%d %H:%M:%S" wed)
  (* "%c: the character c, if c is not one of the format characters listed
     above ... unlike strftime, the behavior of fmt is defined for the
     directive %c for any character c" *)
  val () = eqS ("Date.fmt/other-character", "Q", fn () => fmt "%Q" wed)
  val () = eqS ("Date.fmt/other-character-e", "e", fn () => fmt "%e" wed)
  val () = eqS ("Date.fmt/other-character-digit", "1", fn () => fmt "%1" wed)
  val () = eqS ("Date.fmt/other-characters-in-text", "[k][s][Y=1995]", fn () => fmt "[%k][%s][Y=%Y]" wed)
  (* %Z: "time zone name or abbreviation, or the empty string if no time zone
     information exists"; the name of UTC is not given *)
  val () = eqB ("Date.fmt/%Z-UTC", true, fn () => List.exists (fn z => z = fmt "%Z" wed) ["UTC", "GMT", "Z", ""])
  val () = law ("Date.fmt/numeric-directives", 200, randomDate,
                fn d => Date.fmt "%Y-%m-%d %H:%M:%S %j %w" d
                        = String.concat [Int.toString (Date.year d), "-", pad2 (monthNumber (Date.month d)), "-",
                                         pad2 (Date.day d), " ", pad2 (Date.hour d), ":", pad2 (Date.minute d), ":",
                                         pad2 (Date.second d), " ", StringCvt.padLeft #"0" 3 (Int.toString (Date.yearDay d + 1)),
                                         " ", Int.toString (sundayFirst (Date.weekDay d))],
                showDate)
  (* "They raise Date if the given date is invalid". Such a date comes from
     scan, which performs no check ("No check of the consistency of the date
     (weekday, date in the month, ...) is performed"): it may give NONE, a
     canonical date, or the date as written, which fmt and toString then
     refuse. What they print is never an invalid date. *)
  fun leap y = (y mod 4 = 0 andalso y mod 100 <> 0) orelse y mod 400 = 0
  fun monthLength (y, m) =        (* m = 1 for January *)
    case m of 2 => if leap y then 29 else 28 | 4 => 30 | 6 => 30 | 9 => 30 | 11 => 30 | _ => 31
  fun validFields (y, m, d, h, mi, s) =
    m >= 1 andalso m <= 12 andalso d >= 1 andalso d <= monthLength (y, m) andalso h >= 0 andalso h <= 23
    andalso mi >= 0 andalso mi <= 59 andalso s >= 0 andalso s <= 61
  (* the fields that fmt "%Y %m %d %H %M %S" or toString printed *)
  fun numbers s = List.mapPartial Int.fromString (String.tokens (fn c => c = #" " orelse c = #":") s)
  fun printedByFmt s = case numbers s of [y, m, d, h, mi, sec] => validFields (y, m, d, h, mi, sec) | _ => false
  fun printedByToString s =
    case (String.tokens (fn c => c = #" " orelse c = #":") s, numbers s) of
      (_ :: name :: _, [d, h, mi, sec, y]) =>
        List.exists (fn m => monthName m = name andalso validFields (y, monthNumber m, d, h, mi, sec)) months
    | _ => false
  fun printsValid (printed, valid) s =
    case Date.fromString s of NONE => true | SOME d => valid (printed d) handle Date.Date => true
  val fmtValid = printsValid (Date.fmt "%Y %m %d %H %M %S", printedByFmt)
  val () = eqB ("Date.fmt/prints-no-second-99", true, fn () => fmtValid "Wed Mar 08 19:06:99 1995")
  val () = eqB ("Date.fmt/prints-no-hour-24", true, fn () => fmtValid "Wed Mar 08 24:06:45 1995")
  val () = eqB ("Date.fmt/prints-no-30-February", true, fn () => fmtValid "Wed Feb 30 19:06:45 1995")
  val () = eqB ("Date.fmt/prints-a-valid-date", true, fn () => fmtValid "Wed Mar 08 19:06:45 1995" andalso
                                                                  printedByFmt (Date.fmt "%Y %m %d %H %M %S" (wed ())))
  val () = eqB ("Date.toString/prints-no-31-April", true,
                fn () => printsValid (Date.toString, printedByToString) "Wed Apr 31 19:06:45 1995")
  val () = eqB ("Date.toString/prints-no-minute-60", true,
                fn () => printsValid (Date.toString, printedByToString) "Wed Apr 30 19:60:45 1995")

  (*<< c-locale *)
  val () = eqS ("Date.fmt/%a", "Wed", fn () => fmt "%a" wed)
  val () = eqS ("Date.fmt/%a-Sunday", "Sun", fn () => fmt "%a" sun)
  val () = eqS ("Date.fmt/%A", "Wednesday", fn () => fmt "%A" wed)
  val () = eqS ("Date.fmt/%A-Sunday", "Sunday", fn () => fmt "%A" sun)
  val () = eqS ("Date.fmt/%b", "Mar", fn () => fmt "%b" wed)
  val () = eqS ("Date.fmt/%B", "March", fn () => fmt "%B" wed)
  val () = eqS ("Date.fmt/%B-September", "September", fn () => Date.fmt "%B" (utc (2001, Date.Sep, 1, 0, 0, 0)))
  val () = eqS ("Date.fmt/%p", "PM", fn () => fmt "%p" wed)
  val () = eqS ("Date.fmt/%p-morning", "AM", fn () => fmt "%p" sun)
  val () = eqS ("Date.fmt/%c", "Wed Mar  8 19:06:45 1995", fn () => fmt "%c" wed)
  val () = eqS ("Date.fmt/%x", "03/08/95", fn () => fmt "%x" wed)
  val () = eqS ("Date.fmt/%X", "19:06:45", fn () => fmt "%X" wed)
  val () = eqS ("Date.fmt/names-of-every-month", "JanFebMarAprMayJunJulAugSepOctNovDec",
                fn () => String.concat (List.map (fn m => Date.fmt "%b" (utc (2001, m, 1, 0, 0, 0))) months))
  val () = eqS ("Date.fmt/names-of-every-weekday", "Mon Tue Wed Thu Fri Sat Sun ",
                fn () => String.concat (List.tabulate (7, fn k => Date.fmt "%a " (utc (2001, Date.Jan, k + 1, 0, 0, 0)))))
  (*>> c-locale *)

  (* ---- toString: "a 24-character string ... "Wed Mar 08 19:06:45 1995".
     The function is equivalent to Date.fmt "%a %b %d %H:%M:%S %Y"." ---- *)
  val () = eqS ("Date.toString/spec-example", "Wed Mar 08 19:06:45 1995", fn () => Date.toString (wed ()))
  val () = eqS ("Date.toString/morning", "Sun Mar 05 09:07:03 1995", fn () => Date.toString (sun ()))
  val () = eqS ("Date.toString/midnight", "Sat Jan 01 00:00:00 2000", fn () => Date.toString (utc (2000, Date.Jan, 1, 0, 0, 0)))
  val () = eqS ("Date.toString/end-of-year", "Fri Dec 31 23:59:59 1999",
                fn () => Date.toString (utc (1999, Date.Dec, 31, 23, 59, 59)))
  val () = eqS ("Date.toString/every-month", "JanFebMarAprMayJunJulAugSepOctNovDec",
                fn () => String.concat (List.map (fn m => String.substring (Date.toString (utc (2001, m, 10, 0, 0, 0)), 4, 3)) months))
  val () = eqS ("Date.toString/every-weekday", "MonTueWedThuFriSatSun",
                fn () => String.concat (List.tabulate (7, fn k => String.substring (Date.toString (utc (2001, Date.Jan, k + 1, 0, 0, 0)), 0, 3))))
  val () = law ("Date.toString/24-characters-as-fmt", 200, randomDate,
                fn d => let val s = Date.toString d
                        in size s = 24 andalso s = Date.fmt "%a %b %d %H:%M:%S %Y" d
                           andalso String.substring (s, 0, 3) = weekdayName (Date.weekDay d)
                           andalso String.substring (s, 4, 3) = monthName (Date.month d)
                           andalso String.substring (s, 7, 13) = String.concat [" ", pad2 (Date.day d), " ", pad2 (Date.hour d),
                                                                                ":", pad2 (Date.minute d), ":", pad2 (Date.second d), " "]
                           andalso String.substring (s, 20, 4) = Int.toString (Date.year d)
                        end,
                showDate)

  (* ---- scan, fromString: "scan a 24-character date from a character source
     after ignoring possible initial whitespace. The format of the string
     must be precisely as produced by toString. In particular, the functions
     do not parse time zone abbreviations. No check of the consistency of the
     date (weekday, date in the month, ...) is performed. If the scanning
     fails, NONE is returned." ---- *)
  fun fromString s = Option.map fieldsOf (Date.fromString s)
  fun scanSub s =
    case Date.scan Substring.getc (Substring.full s) of
      SOME (d, rest) => SOME (fieldsOf d, Substring.string rest)
    | NONE => NONE
  val example = (1995, Date.Mar, 8, 19, 6, 45)
  val () = eqFO ("Date.fromString/spec-example", SOME example, fn () => fromString "Wed Mar 08 19:06:45 1995")
  val () = T.eq (T.option weekdayName) ("Date.fromString/weekDay", SOME Date.Wed,
                                         fn () => Option.map Date.weekDay (Date.fromString "Wed Mar 08 19:06:45 1995"))
  (* the day of the year of the date read: 31 + 28 + 7 *)
  val () = T.eq (T.option Int.toString) ("Date.fromString/yearDay", SOME 66,
                                          fn () => Option.map Date.yearDay (Date.fromString "Wed Mar 08 19:06:45 1995"))
  val () = eqFO ("Date.fromString/initial-whitespace", SOME example, fn () => fromString " \t\n Wed Mar 08 19:06:45 1995")
  val () = eqFO ("Date.fromString/rest-ignored", SOME example, fn () => fromString "Wed Mar 08 19:06:45 1995 and more")
  val () = eqFO ("Date.fromString/morning", SOME (1995, Date.Mar, 5, 9, 7, 3), fn () => fromString "Sun Mar 05 09:07:03 1995")
  val () = eqFO ("Date.fromString/no-consistency-check-of-the-weekday", SOME example,
                 fn () => fromString "Mon Mar 08 19:06:45 1995")
  val () = eqFO ("Date.fromString/empty", NONE, fn () => fromString "")
  val () = eqFO ("Date.fromString/blank", NONE, fn () => fromString "    ")
  val () = eqFO ("Date.fromString/letters", NONE, fn () => fromString "hello")
  val () = eqFO ("Date.fromString/weekday-only", NONE, fn () => fromString "Wed")
  val () = eqFO ("Date.fromString/no-year", NONE, fn () => fromString "Wed Mar 08 19:06:45")
  val () = eqFO ("Date.fromString/no-seconds", NONE, fn () => fromString "Wed Mar 08 19:06 1995")
  val () = eqFO ("Date.fromString/unknown-weekday", NONE, fn () => fromString "Wex Mar 08 19:06:45 1995")
  val () = eqFO ("Date.fromString/unknown-month", NONE, fn () => fromString "Wed Mzr 08 19:06:45 1995")
  val () = eqFO ("Date.fromString/dashes", NONE, fn () => fromString "Wed Mar 08 19-06-45 1995")
  val () = eqFO ("Date.fromString/numeric-date", NONE, fn () => fromString "1995-03-08 19:06:45")
  val () = eqScan ("Date.scan/rest", SOME (example, " rest"), fn () => scanSub "Wed Mar 08 19:06:45 1995 rest")
  val () = eqScan ("Date.scan/time-zone-not-parsed", SOME (example, " UTC"), fn () => scanSub "Wed Mar 08 19:06:45 1995 UTC")
  val () = eqScan ("Date.scan/24-characters", SOME (example, "6"), fn () => scanSub "Wed Mar 08 19:06:45 19956")
  val () = eqScan ("Date.scan/initial-whitespace", SOME (example, ""), fn () => scanSub "\n Wed Mar 08 19:06:45 1995")
  val () = eqScan ("Date.scan/NONE", NONE, fn () => scanSub "Wed Mar 08")
  fun listRd [] = NONE
    | listRd (c :: cs) = SOME (c, cs)
  val () = T.eq (T.option (T.pair (showFields, T.list T.char)))
                ("Date.scan/list-reader", SOME (example, [#"!"]),
                 fn () => Option.map (fn (d, rest) => (fieldsOf d, rest)) (Date.scan listRd (String.explode "Wed Mar 08 19:06:45 1995!")))
  val () = eqB ("Date.fromString/every-month", true,
                fn () => List.all (fn m => case Date.fromString (Date.toString (utc (2001, m, 10, 0, 0, 0))) of
                                             SOME d => fieldsOf d = (2001, m, 10, 0, 0, 0)
                                           | NONE => false) months)
  val () = eqB ("Date.fromString/every-weekday", true,
                fn () => List.all (fn k => case Date.fromString (Date.toString (utc (2001, Date.Jan, k, 0, 0, 0))) of
                                             SOME d => Date.day d = k
                                           | NONE => false) [1, 2, 3, 4, 5, 6, 7])
  val () = law ("Date.fromString/inverts-toString", 200, randomDate,
                fn d => fromString (Date.toString d) = SOME (fieldsOf d)
                        andalso Option.map Date.toString (Date.fromString (Date.toString d)) = SOME (Date.toString d),
                showDate)
end

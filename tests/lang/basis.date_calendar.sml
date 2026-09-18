(* Date: the calendar, checked against dates worked out by hand.
   1970-01-01 was a Thursday; 2000-02-29 existed; 1900 was not a leap year. *)
fun show d = Date.toString d ^ " yday=" ^ Int.toString (Date.yearDay d)
val epoch = Date.fromTimeUniv Time.zeroTime
val () = print (show epoch ^ "\n")
fun utc (y, m, d, h, mi, s) =
  Date.date {year = y, month = m, day = d, hour = h, minute = mi, second = s, offset = SOME Time.zeroTime}
val leap = utc (2000, Date.Feb, 29, 12, 0, 0)
val () = print (show leap ^ "\n")
(* 1900-03-01 follows 1900-02-28: 1900 is not a leap year *)
val notLeap = utc (1900, Date.Feb, 29, 0, 0, 0)
val () = print (show notLeap ^ "\n")
(* the fields are carried: month 13 is January of the next year *)
val carried = utc (2026, Date.Dec, 32, 25, 61, 61)
val () = print (show carried ^ "\n")
val () = print (Time.toString (Date.toTime (utc (2026, Date.Sep, 18, 12, 0, 0))) ^ "\n")
val () = print (Date.fmt "%Y-%m-%d %H:%M:%S" (utc (2026, Date.Sep, 18, 12, 0, 0)) ^ "\n")
val there = valOf (Date.fromString "Fri Sep 18 12:00:00 2026")
val () = print (show there ^ " " ^ (case Date.compare (there, utc (2026, Date.Sep, 18, 12, 0, 0)) of EQUAL => "equal" | _ => "differs") ^ "\n")

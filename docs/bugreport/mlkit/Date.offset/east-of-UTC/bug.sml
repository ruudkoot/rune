(* "A value of SOME(t) corresponds to time t west of UTC. ... Negative offsets
   denote time zones to the east of UTC ... Offsets are taken modulo 24 hours.
   That is, we express t, in hours, as sgn(t)(24*d + r) ... The offset then
   becomes sgn(t)*r and sgn(t)(24*d) is added to the hours" *)
fun at (h, west) = Date.date {year = 2000, month = Date.Jan, day = 1, hour = h, minute = 0, second = 0,
                              offset = SOME (Time.fromSeconds (IntInf.fromInt west))}
val utcMidnight = Date.date {year = 2000, month = Date.Jan, day = 1, hour = 0, minute = 0, second = 0,
                             offset = SOME Time.zeroTime}
fun offsetOf d = case Date.offset d of SOME t => IntInf.toString (Time.toSeconds t) | NONE => "NONE"
fun fields d = Date.fmt "%Y-%m-%d %H:%M:%S" d
fun since d = IntInf.toString (Time.toSeconds (Time.- (Date.toTime d, Date.toTime utcMidnight)))
fun show (what, h, west, expOffset, expSince) =
    let val d = at (h, west)
    in print (what ^ ": fields " ^ fields d ^ ", offset " ^ offsetOf d ^ " (expected " ^ expOffset
              ^ "), seconds after 2000-01-01 00:00 UTC " ^ since d ^ " (expected " ^ expSince ^ ")\n")
    end
val () = show ("12:00 at  5 h west (18000)  ", 12, 18000, "18000", "61200")
val () = show ("12:00 at 5:30 h east (~19800)", 12, ~19800, "~19800", "23400")
val () = show ("00:00 at 25 h west (90000)  ", 0, 90000, "3600", "90000")
val () = show ("00:00 at 25 h east (~90000) ", 0, ~90000, "~3600", "~90000")
val () = show ("12:00 at 13 h west (46800)  ", 12, 46800, "46800", "90000")

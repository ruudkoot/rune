(* Date.toTime of dates with an offset: "toTime date returns the (UTC) time
   corresponding to the date date. It raises Date if the date date cannot be
   represented as a Time.time value"; an offset SOME t "corresponds to time t
   west of UTC". The answers do not depend on the local time zone, so run it
   in a few: TZ=Europe/London sml bug.sml, TZ=America/Chicago, TZ=UTC. *)
fun show (name, d, expected) =
      let val got = (IntInf.toString (Time.toSeconds (Date.toTime (d ()))))
                      handle Date.Date => "Date" | Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
fun at offset ((year, month, day), (hour, minute, second)) () =
      Date.date {year = year, month = month, day = day, hour = hour, minute = minute,
                 second = second, offset = SOME offset}
val utc = at Time.zeroTime
val hours = Time.fromSeconds o (fn h => h * 3600)
val () = show ("toTime (fromTimeUniv zeroTime)", fn () => Date.fromTimeUniv Time.zeroTime, "0")
val () = show ("toTime 1970-01-01 01:00:00 UTC", utc ((1970, Date.Jan, 1), (1, 0, 0)), "3600")
val () = show ("toTime 2000-01-01 12:30:45 UTC", utc ((2000, Date.Jan, 1), (12, 30, 45)), "946729845")
val () = show ("toTime 2000-07-01 12:30:45 UTC", utc ((2000, Date.Jul, 1), (12, 30, 45)), "962454645")
val () = show ("toTime 2000-01-01 12:00:00 5 hours west", at (hours 5) ((2000, Date.Jan, 1), (12, 0, 0)), "946746000")
val () = show ("toTime 1969-12-31 23:00:00 UTC", utc ((1969, Date.Dec, 31), (23, 0, 0)), "~3600")
val () = show ("toTime 2000-01-01 12:00:00 25 hours west", at (hours 25) ((2000, Date.Jan, 1), (12, 0, 0)), "946818000")
val () = OS.Process.exit OS.Process.success

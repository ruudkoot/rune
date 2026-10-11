(* toTime of a date at UTC (offset SOME 0) is the UTC time of that date,
   whatever the local time zone is. *)
fun secs t = LargeInt.toString (Time.toSeconds t)
fun show (what, f) = print (what ^ " = " ^ (f () handle Date.Date => "raised Date") ^ "\n")
fun utc (y, m, d) =
    Date.date {year = y, month = m, day = d, hour = 0, minute = 0, second = 0,
               offset = SOME Time.zeroTime}
val () = show ("toTime (fromTimeUniv Time.zeroTime)       (expected 0)",
               fn () => secs (Date.toTime (Date.fromTimeUniv Time.zeroTime)))
val () = show ("toTime (fromTimeUniv (fromSeconds 86400)) (expected 86400)",
               fn () => secs (Date.toTime (Date.fromTimeUniv (Time.fromSeconds 86400))))
val () = show ("toTime of 1971-06-01 00:00:00 UTC         (expected 44582400)",
               fn () => secs (Date.toTime (utc (1971, Date.Jun, 1))))
val () = show ("toTime of 1972-06-01 00:00:00 UTC         (expected 76204800)",
               fn () => secs (Date.toTime (utc (1972, Date.Jun, 1))))
val () = show ("toTime of 2012-06-01 00:00:00 UTC         (expected 1338508800)",
               fn () => secs (Date.toTime (utc (2012, Date.Jun, 1))))

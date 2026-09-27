(* "It raises Date if the date date cannot be represented as a Time.time value." *)
fun utc y = Date.date {year = y, month = Date.Jan, day = 1, hour = 0, minute = 0, second = 0, offset = SOME Time.zeroTime}
fun try (what, f) =
    print (what ^ ": " ^ ((f (); "no exception") handle Date.Date => "Date.Date"
                                                       | Time.Time => "Time.Time"
                                                       | e => General.exnName e) ^ "\n")
val () = try ("Date.toTime of 100000000-01-01 00:00:00 UTC (expected Date.Date or a time)", fn () => Date.toTime (utc 100000000))
val () = try ("Date.toTime of 2100-01-01 00:00:00 UTC (expected a time)", fn () => Date.toTime (utc 2100))

(* toTime (fromTimeUniv t) is t, to the second, in every time zone.  Run with
   TZ=Europe/London: the UK kept UTC+1 all year from 1968-10-27 to
   1971-10-31 ("British Standard Time"), and its offset is 0 now. *)
fun try (what, f) =
    print (what ^ " = " ^ (f () handle Date.Date => "Date.Date" | Time.Time => "Time.Time") ^ "\n")
fun secs t = IntInf.toString (Time.toSeconds t)
fun roundTrip s = secs (Date.toTime (Date.fromTimeUniv (Time.fromSeconds s)))
val () = try ("Date.toTime (Date.fromTimeUniv Time.zeroTime)         ", fn () => roundTrip 0)
val () = try ("Date.toTime (Date.fromTimeUniv 3600 s)                ", fn () => roundTrip 3600)
val () = try ("Date.toTime (Date.fromTimeUniv 31536000 s, 1971-01-01)", fn () => roundTrip 31536000)
val () = try ("Date.toTime (Date.fromTimeUniv 63072000 s, 1972-01-01)", fn () => roundTrip 63072000)

(* "A conforming Date structure should support date values ranging from
   around 1900 to 2200". *)
fun utc (y, m, d, h, mi, s) =
    Date.date {year = y, month = m, day = d, hour = h, minute = mi, second = s, offset = SOME Time.zeroTime}
fun try (what, f) =
    print (what ^ " = " ^ (f () handle Date.Date => "Date.Date" | Time.Time => "Time.Time") ^ "\n")
fun secs d = IntInf.toString (Time.toSeconds (Date.toTime d))
val () = try ("Date.toTime 1970-01-01 00:00:00 UTC", fn () => secs (utc (1970, Date.Jan, 1, 0, 0, 0)))
val () = try ("Date.toTime 1969-12-31 23:59:59 UTC", fn () => secs (utc (1969, Date.Dec, 31, 23, 59, 59)) ^ "   (expected ~1)")
val () = try ("Date.toTime 1950-01-01 00:00:00 UTC", fn () => secs (utc (1950, Date.Jan, 1, 0, 0, 0)) ^ "   (expected ~631152000)")
(* the date of a time is that of the second it falls in *)
val () = try ("Date.fromTimeUniv (Time.fromReal ~0.5)", fn () =>
               Date.fmt "%Y-%m-%d %H:%M:%S" (Date.fromTimeUniv (Time.fromReal ~0.5)) ^ "   (expected 1969-12-31 23:59:59)")

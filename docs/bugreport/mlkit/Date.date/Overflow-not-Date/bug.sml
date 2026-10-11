(* "If the resulting date is outside the range supported by the
   implementation, the Date exception is raised." *)
fun try (what, f) =
    print (what ^ " = " ^ (f () handle Date.Date => "Date.Date" | e => "raised " ^ General.exnName e) ^ "\n")
fun yearOf (y : int, d : int, off) =
    Int.toString (Date.year (Date.date {year = y, month = Date.Jan, day = d, hour = 0, minute = 0,
                                        second = 0, offset = off}))
val utc = SOME Time.zeroTime
val maxInt = valOf Int.maxInt
val () = print ("Int.maxInt = " ^ Int.toString maxInt ^ "\n")
val () = try ("year of 12600000000000000-01-01 UTC   ", fn () => yearOf (12600000000000000, 1, utc))
val () = try ("year of 12700000000000000-01-01 UTC   ", fn () => yearOf (12700000000000000, 1, utc))
val () = try ("year of maxInt-01-01 UTC              ", fn () => yearOf (maxInt, 1, utc))
val () = try ("year of maxInt-01-01 local            ", fn () => yearOf (maxInt, 1, NONE))
val () = try ("year of 2000-01-01 + maxInt - 1 days  ", fn () => yearOf (2000, maxInt, utc))
val () = try ("year of ~1-01-01 UTC                  ", fn () => yearOf (~1, 1, utc))

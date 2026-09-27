(* IntInf.int (LargeInt.int) is unbounded and int has 63 bits, so neither
   conversion below should raise Overflow; Time.time is 63-bit seconds and
   microseconds, so 2^31 seconds (2038-01-19 03:14:08 UTC) is a time. *)
fun try (what, f) =
    print (what ^ " = " ^ (f () handle Overflow => "Overflow" | Time.Time => "Time.Time") ^ "\n")
val two31 : int = 2147483648
val () = try ("Int.toLarge 2147483648           ", fn () => IntInf.toString (Int.toLarge two31))
val () = try ("IntInf.fromInt 2147483647        ", fn () => IntInf.toString (IntInf.fromInt (two31 - 1)))
val () = try ("IntInf.fromInt 2147483648        ", fn () => IntInf.toString (IntInf.fromInt two31))
val () = try ("LargeInt.fromInt 2147483648      ", fn () => IntInf.toString (LargeInt.fromInt two31))
val () = try ("IntInf.toInt (IntInf.pow (2, 31))", fn () => Int.toString (IntInf.toInt (IntInf.pow (2, 31))))
val () = try ("Time.fromSeconds 2147483647      ", fn () => IntInf.toString (Time.toSeconds (Time.fromSeconds (IntInf.fromInt (two31 - 1)))))
val () = try ("Time.fromSeconds 2^31            ", fn () => IntInf.toString (Time.toSeconds (Time.fromSeconds (IntInf.pow (2, 31)))))
val () = try ("Time.fromReal 2147483648.0       ", fn () => IntInf.toString (Time.toSeconds (Time.fromReal 2147483648.0)))
val t = Time.+ (Time.fromSeconds (IntInf.fromInt (two31 - 1)), Time.fromSeconds (IntInf.fromInt 1))
val () = try ("Time.toSeconds ((2^31 - 1 s) + 1 s)", fn () => IntInf.toString (Time.toSeconds t))
val () = try ("Time.toString ((2^31 - 1 s) + 1 s) ", fn () => Time.toString t)
val () = try ("Date.toTime 2038-01-19 03:14:08 UTC", fn () =>
               Time.toString (Date.toTime (Date.date {year = 2038, month = Date.Jan, day = 19, hour = 3,
                                                      minute = 14, second = 8, offset = SOME Time.zeroTime})))

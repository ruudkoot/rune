(* "If the resulting date is outside the range supported by the
   implementation, the Date exception is raised." *)
fun try y =
    let
      val what = "Date.date of 1 January " ^ Int.toString y
      val d = Date.date {year = y, month = Date.Jan, day = 1, hour = 0, minute = 0,
                         second = 0, offset = SOME Time.zeroTime}
    in
      print (what ^ ": a date of the year " ^ Int.toString (Date.year d) ^ "\n")
    end
    handle Date.Date => print ("Date.date of 1 January " ^ Int.toString y ^ ": raised Date\n")
         | e => print ("Date.date of 1 January " ^ Int.toString y ^ ": raised " ^ exnName e
                       ^ " (expected Date or a date)\n")
val () = List.app try [2200, 5879490, 5879491, 1000000000, 2147483647]

(* Date.fmt gives the year to C's strftime as an int of 32 bits: a year that
   does not fit raises Date instead of being printed as another year. The
   date itself is there whatever the year. *)
fun d y = Date.date {year = y, month = Date.Jan, day = 1, hour = 0, minute = 0, second = 0, offset = SOME Time.zeroTime}
fun show y =
  print (Int.toString y ^ ": " ^ (Date.fmt "%Y" (d y) handle Date.Date => "Date")
         ^ (if Date.year (d y) = y then "" else " (the year is lost)") ^ "\n")
val () = List.app show [1995, ~5, 100000, 2147483647, 2147483648, ~2147481748, ~2147481749, 1000000000000]
val () = print ((Date.toString (d 2147483648) handle Date.Date => "Date") ^ "\n")

(* Local time before 1970, which msvcrt refuses: a moment of 1969 and a date
   of 1960 through the local zone and back. The runners set TZ to 3:30 west
   of UTC with summer time from March to November (tests/run-tests.sh); both
   are in winter, since glibc keeps no summer time before 1970 and the layer
   of Windows follows the rule of TZ in every year. *)
val t = Time.fromSeconds ~30000000
val d = Date.fromTimeLocal t
val () = print (Date.fmt "%Y-%m-%d %H:%M:%S %a %Z" d ^ "\n")
val () = print ("back: " ^ Bool.toString (Date.toTime d = t) ^ "\n")
val winter = Date.date {year = 1960, month = Date.Jan, day = 4, hour = 12, minute = 0, second = 0, offset = NONE}
val () = print ("1960-01-04 12:00 local is " ^ Date.fmt "%Y-%m-%d %H:%M UTC" (Date.fromTimeUniv (Date.toTime winter)) ^ "\n")
val () = print ("weekday: " ^ Date.fmt "%A" winter ^ "\n")

(* %Z: "time zone name or abbreviation, or the empty string if no time zone
   information exists". Run with TZ='NST3:30NDT,M3.2.0,M11.1.0'. *)
fun show s = "\"" ^ String.toString s ^ "\" (" ^ String.concatWith " " (map (Int.toString o ord) (explode s)) ^ ")"
val u = Date.date {year = 1995, month = Date.Mar, day = 8, hour = 19, minute = 6, second = 45,
                   offset = SOME Time.zeroTime}
val () = print ("UTC date:   Date.fmt \"%Z\" = " ^ show (Date.fmt "%Z" u) ^ "\n")
fun again () = Date.fmt "[%Z]" u
val () = print ("UTC date:   Date.fmt \"[%Z]\" = " ^ show (again ()) ^ "\n")
val l = Date.fromTimeLocal (Time.fromSeconds (IntInf.fromInt 794689605))
val () = print ("local date: Date.fmt \"%Y\" = " ^ show (Date.fmt "%Y" l) ^ "\n")
val () = print ("local date: Date.fmt \"%Z\" = " ^ show (Date.fmt "%Z" l) ^ "\n")

val i = ref 0
val sum = ref 0
val () = while !i < 5 do (sum := !sum + !i; i := !i + 1)
val () = print (Int.toString (!sum) ^ " " ^ Int.toString (!i) ^ "\n")
val () = while false do print "never"
val n = ref 1000000
val () = while !n > 0 do n := !n - 1
val () = print (Int.toString (!n) ^ "\n")

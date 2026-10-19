(* The same raw TAB after 0 to 8 characters of a literal: MLKit puts
   spaces up to the next column that is a multiple of 8, counted from 0.
   The first argument of show is the column of the TAB. *)
fun show (column, s) =
  let val n = length (List.filter (fn c => c = #" ") (explode s))
  in print ("TAB at column " ^ Int.toString column ^ ": " ^ Int.toString n
            ^ (if n = 1 then " space" else " spaces") ^ "\n")
  end
val () = show (20, "	")
val () = show (21, "a	")
val () = show (22, "ab	")
val () = show (23, "abc	")
val () = show (24, "abcd	")
val () = show (25, "abcde	")
val () = show (26, "abcdef	")
val () = show (27, "abcdefg	")
val () = show (28, "abcdefgh	")

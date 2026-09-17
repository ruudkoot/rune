fun double x = x + x
val () = print (Int.toString (double 21) ^ "\n")
fun half x = x / 2.0
val () = print (Real.toString (half 3.0) ^ "\n")
fun cmp (a, b) = a < b
val () = print (Bool.toString (cmp (1, 2)) ^ "\n")
val neg = ~
val () = print (Int.toString (neg 5) ^ "\n")
val () = print (Real.toString (~ 2.5) ^ Real.toString (abs ~1.5) ^ Int.toString (abs ~3) ^ "\n")
val () = print (Bool.toString (#"a" < #"b") ^ Bool.toString ("b" >= "a") ^ Bool.toString (1.0 <= 0.5) ^ Bool.toString (0w1 > 0w0) ^ "\n")
val () = print (Real.toString (1.5 * 2.0 - 0.5) ^ Word.toString (0w7 * 0w2 + 0w1 - 0w3) ^ Word.toString (0w17 div 0w5) ^ Word.toString (0w17 mod 0w5) ^ "\n")

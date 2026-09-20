(* ~ at type word: two's complement negation, 0 - w modulo 2^64 *)
val () = print (Word.toString (~ 0w5) ^ "\n")
val () = print (Word.toString (~ 0w0) ^ "\n")
val () = print (Word.toString (Word.~ 0w1) ^ "\n")
val neg : word -> word = ~
val () = print (Word.toString (neg (neg 0w42)) ^ "\n")
fun twice (w : word) = ~ (~ w + 0w1)
val () = print (Word.toString (twice 0w16) ^ "\n")

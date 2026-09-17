val x' = 1
val x'' = 2
val under_score = 3
val +++ = fn (a, b) => a * b
infix 6 +++
val () = print (Int.toString (x' + x'' + under_score + (2 +++ 3)) ^ "\n")

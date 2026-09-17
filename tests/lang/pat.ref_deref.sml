val r = ref 5
val ref v = r
val () = print (Int.toString v ^ "\n")
fun bump (ref n) = n + 1
val () = print (Int.toString (bump r) ^ "\n")
fun both (ref a, ref b) = a + b
val () = print (Int.toString (both (ref 1, ref 2)) ^ "\n")
val () = r := 10
val ref v2 = r
val () = print (Int.toString v2 ^ "\n")

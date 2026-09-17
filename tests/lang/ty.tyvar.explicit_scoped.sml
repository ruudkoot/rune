fun 'a id (x : 'a) : 'a = x
fun pair (x : 'a, y : 'b) : 'a * 'b = (x, y)
fun swap ((a, b) : 'a * 'b) = (b, a)
val p = swap (pair (1, "s"))
val () = print (#1 p ^ Int.toString (#2 p) ^ Int.toString (id 3) ^ "\n")
fun ''a eq (x : ''a, y : ''a) = x = y
val () = print (Bool.toString (eq (1, 1)) ^ Bool.toString (eq ("a", "b")) ^ "\n")

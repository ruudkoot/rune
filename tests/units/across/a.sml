(* the first unit: what the units after it use *)
infix 5 +++
fun (x, y) +++ z = x + y + z
fun add (x, y) = x + y                  (* a worker, since its argument is a pair it takes apart *)
fun curried a b c = a * 100 + b * 10 + c
datatype shape = Circle of real | Rect of real * real | Point
exception Bad of string
structure Store = struct val items = ref [1, 2, 3] fun push x = items := x :: !items end
functor Counter (X : sig val start : int end) = struct val n = ref X.start fun next () = (n := !n + 1; !n) end
val () = print "a done\n"

(* dump: --passes=shake,uncurry --dump-after=uncurry *)
(* Uncurrying (eval/apply proper, the haskell98 roadmap's D15 C): add3,
   curried three deep, gets a twin of three parameters, and its use as a
   value (given to apply3) becomes the twin's: a closure of three
   parameters, which a call of three arguments enters at once. In apply3
   and apply2, calls through a closure in a row, each of the last one's
   result, become one call of them all. scale computes before the
   function it returns, which a partial application does once and a twin
   would do at every call: it gets none, and apply2's call of two
   arguments, given scale, takes the general path. *)
fun add3 (x : int) (y : int) (z : int) = x + y + z
fun apply3 (f : int -> int -> int -> int) = f 1 2 3
val r = apply3 add3
fun scale (k : int) = let val m = k * k in fn (x : int) => m * x end
fun apply2 (f : int -> int -> int) = f 2 3
val s = apply2 scale

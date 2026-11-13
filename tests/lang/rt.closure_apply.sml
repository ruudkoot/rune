(* Calls of n arguments through closures (eval/apply, the haskell98
   roadmap's D15 C): saturated, partial, over-applied, through partial
   applications, in tail position, and with exceptions raised through them *)
fun add3 x y z = x + y + z
fun pair x y = (x, y)
fun twice f x = f (f x)
fun ap2 (f : int -> int -> int) a b = f a b                (* an unknown call of 2 *)
fun ap3 (f : int -> int -> int -> int) a b c = f a b c    (* of 3 *)
fun tailap (f : int -> int -> int) a b = if a > 1000 then 0 else f a b
fun compose f g x = f (g x)
val sums = List.map (fn f => f 1) [add3 1 2, add3 10 20]   (* partial applications applied *)
val () = print (String.concatWith "," (List.map Int.toString sums) ^ "\n")
val () = print (Int.toString (ap2 (fn a => fn b => a * b) 6 7) ^ "\n")
val () = print (Int.toString (ap3 add3 1 2 3) ^ "\n")
val p1 = add3 100                    (* a partial application of a known function *)
val () = print (Int.toString (ap2 p1 1 2) ^ "\n")
val () = print (Int.toString (ap2 (add3 5) 6 7) ^ "\n")
(* over-application: a closure of one parameter that returns one of two *)
fun mk x = let val y = x * 2 in fn a => fn b => a + b + y end
val () = print (Int.toString (ap3 mk 1 2 3) ^ "\n")
(* a local curried function, used as a value and called *)
fun local' n =
  let
    fun f a b = a * 10 + b + n
    val g = f 3
  in
    ap2 f 1 2 + g 4 + List.foldl (fn (x, acc) => acc + f x 1) 0 [1, 2, 3]
  end
val () = print (Int.toString (local' 5) ^ "\n")
val () = print (Int.toString (tailap (fn a => fn b => a - b) 9 4) ^ "\n")
val () = print (Int.toString (twice (add3 1 1) 0) ^ "\n")
val () = print (Int.toString (compose (add3 1 2) (fn x => x * x) 5) ^ "\n")
(* a loop through an unknown curried function in tail position *)
fun loop (step : int -> int -> int) n acc = if n = 0 then acc else loop step (n - 1) (step acc n)
val () = print (Int.toString (loop (fn a => fn b => a + b) 100000 0) ^ "\n")
(* a partial application of a partial application *)
val q = ap3 (fn a => fn b => fn c => a * 100 + b * 10 + c)
val () = print (Int.toString (q 1 2 3) ^ "\n")
fun curry4 a b c d = a + b * 2 + c * 3 + d * 4
val c1 = curry4 1
val () = print (Int.toString (ap3 c1 2 3 4) ^ "\n")
val () = print (Int.toString (List.foldl (fn (f, acc) => acc + f 1 1) 0 [curry4 1 1, curry4 2 2]) ^ "\n")
val () = print (let val (a, b) = pair 1 2 in Int.toString (a + b) end ^ "\n")
(* exceptions through the general path *)
fun boom a b = if a = b then raise Fail "equal" else a - b
val () = print ((Int.toString (ap2 boom 3 3)) handle Fail m => m ^ "\n")
val () = print ((Int.toString (ap2 boom 5 3) ^ "\n") handle Fail m => m ^ "\n")

(* A closure made where a case of v has tested v's tag and taken nothing
   apart: Simplify knows the tag in the closure too, but the closure is a
   function of its own, whose test of v must stay before its Decon (Lower's
   shapes lint, a function at a time). *)
datatype t = A of int | B of string | C

fun check (v : t) : t = case v of A _ => v | _ => raise Fail "not an A"

fun f (v : t) : int list -> int list =
  let val v = check v
  in List.map (fn k => case v of A m => m + k | B s => size s | C => 0) end

val () = List.app (fn n => print (Int.toString n ^ "\n")) (f (A 3) [1, 2])
val () = (ignore (f C [1]); print "no\n") handle Fail m => print (m ^ "\n")

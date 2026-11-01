(* The program the check of the register code is tried on, with each of its
   corruptions (RUNE_REGVERIFY_INJECT; tests/runner/oracles.sml, regverify):
   it has a place of every kind they corrupt -- an int register written by
   INT and read by int_add, a known call and its RESULT, a handler, a
   SWITCH, a closure that reads its environment, a function of two
   parameters, an image primitive -- and is refused with each. *)
datatype shape = Circle of int | Rect of int * int | Tri of int * int * int | Dot
fun area s = case s of Circle r => 3 * r * r | Rect (w, h) => w * h | Tri (a, b, c) => a + b + c | Dot => 0
exception Bad of int
fun check n = if n > 100 then raise Bad n else n
fun safe n = check n handle Bad m => m - 100
fun adder k = fn x => x + k
fun sum (f, xs) = List.foldl (fn (x, acc) => f x + acc) 0 xs
val shapes = [Circle 2, Rect (3, 4), Tri (1, 2, 3), Dot, Circle 5]
val total = List.foldl (fn (s, acc) => area s + acc) 0 shapes
val () = print (Int.toString total ^ " " ^ Int.toString (safe 150) ^ " " ^ Int.toString (sum (adder 10, [1, 2, 3])) ^ "\n")
val fs = List.map adder [1, 2, 3]
val () = print (String.concatWith "," (List.map (fn f => Int.toString (f 5)) fs) ^ "\n")
val () = if total = 0 then ignore (Posix.Process.fork ()) else ()

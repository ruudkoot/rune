(* The program the check of the stack code is tried on (StackCheck, at
   level 2 after the stack stage; tests/runner/oracles.sml, rbccheck), with
   each of its corruptions (RUNE_RBCCHECK_INJECT): it has a place of every
   kind they corrupt -- functions with locals, jumps that join, a handler,
   a RET -- and is refused with each. *)
datatype shape = Circle of int | Rect of int * int | Tri of int * int * int | Dot
fun area s = case s of Circle r => 3 * r * r | Rect (w, h) => w * h | Tri (a, b, c) => a + b + c | Dot => 0
exception Bad of int
fun check n = if n > 100 then raise Bad n else n
fun safe n = check n handle Bad m => m - 100
fun pick (a, b) = if a > b then a - b else b - a
fun sum (f, xs) = List.foldl (fn (x, acc) => f x + acc) 0 xs
val shapes = [Circle 2, Rect (3, 4), Tri (1, 2, 3), Dot, Circle 5]
val total = List.foldl (fn (s, acc) => area s + acc) 0 shapes
val () = print (Int.toString total ^ " " ^ Int.toString (safe 150) ^ " " ^ Int.toString (pick (3, 9))
                ^ " " ^ Int.toString (sum (fn x => x * 2, [1, 2, 3])) ^ "\n")

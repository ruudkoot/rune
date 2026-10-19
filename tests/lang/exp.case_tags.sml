(* Matches on a constructor's tag in every representation the compiler
   gives a datatype (src/backend/lower.sml): nullary constructors alone
   (an immediate), constructors that all carry a value (a pointer), the two
   mixed, and many constructors (a SWITCH) -- each value in a register and
   live across calls (in its slot), so that compiled code tests each the way
   its representation lets it (native-frames.md, M2) *)
datatype colour = Red | Green | Blue | Yellow
datatype shape = Circle of int | Square of int | Rect of int * int
datatype tree = Leaf | Node of tree * int * tree
datatype instr = Halt | Push of int | Pop | Add | Jump of int | Nop | Dup | Neg of int

fun colourName Red = "red" | colourName Green = "green" | colourName Blue = "blue" | colourName Yellow = "yellow"
fun warm Red = 1 | warm Yellow = 1 | warm _ = 0
fun area (Circle r) = 3 * r * r | area (Square s) = s * s | area (Rect (w, h)) = w * h
fun isRect (Rect _) = true | isRect _ = false
fun insert (x, Leaf) = Node (Leaf, x, Leaf)
  | insert (x, t as Node (l, y, r)) =
      if x < y then Node (insert (x, l), y, r) else if x > y then Node (l, y, insert (x, r)) else t
fun sum Leaf = 0 | sum (Node (l, x, r)) = sum l + x + sum r
fun depth Leaf = 0 | depth (Node (l, _, r)) = 1 + Int.max (depth l, depth r)
fun step (Halt, acc) = acc | step (Push n, acc) = acc + n | step (Pop, acc) = acc - 1
  | step (Add, acc) = acc * 2 | step (Jump n, acc) = acc + n * 10 | step (Nop, acc) = acc
  | step (Dup, acc) = acc + acc | step (Neg n, acc) = acc - n
(* the value live across a call: its slot, then its tag *)
fun twice (c, f) = let val n = f () in if warm c = 1 then n + 1 else n end
fun loop (0, acc) = acc
  | loop (k, acc) =
      let
        val c = case k mod 4 of 0 => Red | 1 => Green | 2 => Blue | _ => Yellow
        val s = case k mod 3 of 0 => Circle k | 1 => Square k | _ => Rect (k, 2)
        val i = case k mod 8 of 0 => Halt | 1 => Push k | 2 => Pop | 3 => Add | 4 => Jump 1 | 5 => Nop | 6 => Dup | _ => Neg 3
      in
        loop (k - 1, step (i, acc mod 1000003) + area s + twice (c, fn () => warm c) + (if isRect s then 1 else 0))
      end
val () = List.app (fn c => print (colourName c ^ " ")) [Red, Green, Blue, Yellow]
val () = print "\n"
val t = List.foldl insert Leaf [5, 3, 8, 1, 4, 7, 9, 2, 6]
val () = print (Int.toString (sum t) ^ " " ^ Int.toString (depth t) ^ "\n")
val () = print (Int.toString (loop (30000, 0)) ^ "\n")

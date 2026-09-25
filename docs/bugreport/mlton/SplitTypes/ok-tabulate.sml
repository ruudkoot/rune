(* bug.sml with the vector made by Vector.tabulate instead of Array.vector:
   correct. It prints 2. *)
val a = Array.array (256, [] : (string * int) list)
fun add (w as (s, _)) =
  let val i = Char.ord (String.sub (s, 0)) in Array.update (a, i, Array.sub (a, i) @ [w]) end
val () = List.app add [("a", 1), ("ab", 2), ("c", 3)]
val table = Vector.tabulate (Array.length a, fn i => Array.sub (a, i))
val () = print (Int.toString (length (Vector.sub (table, Char.ord #"a"))) ^ "\n")

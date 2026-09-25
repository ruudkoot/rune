(* The smallest program found: an array of lists of pairs, filled from
   another list, made into a vector. It should print 2. Standalone: MLton's
   own Basis Library, no .mlb file. *)
val a = Array.array (256, [] : (string * int) list)
fun add (w as (s, _)) =
  let val i = Char.ord (String.sub (s, 0)) in Array.update (a, i, Array.sub (a, i) @ [w]) end
val () = List.app add [("a", 1), ("ab", 2), ("c", 3)]
val table = Array.vector a
val () = print (Int.toString (length (Vector.sub (table, Char.ord #"a"))) ^ "\n")

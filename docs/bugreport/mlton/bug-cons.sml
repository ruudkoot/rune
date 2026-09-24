(* bug.sml with each element built by :: instead of @: still fails. It
   should print 2. *)
val a = Array.array (256, [] : (string * int) list)
fun add (w as (s, _)) =
  let val i = Char.ord (String.sub (s, 0)) in Array.update (a, i, w :: Array.sub (a, i)) end
val () = List.app add [("a", 1), ("ab", 2), ("c", 3)]
val table = Array.vector a
val () = print (Int.toString (length (Vector.sub (table, Char.ord #"a"))) ^ "\n")

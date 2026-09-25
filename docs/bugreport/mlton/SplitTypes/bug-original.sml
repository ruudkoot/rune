(* The shape the bug was found in, a lexer's table of reserved words by
   their first character: inside a function, with a datatype. It should
   print "found". *)
datatype token = A | B | C

val words : (string * token) list = [("a", A), ("ab", B), ("c", C)]

fun buckets (ws : (string * token) list) : (string * token) list vector =
  let
    val a = Array.array (256, [] : (string * token) list)
    fun add (w as (s, _)) =
      let val i = Char.ord (String.sub (s, 0)) in Array.update (a, i, Array.sub (a, i) @ [w]) end
  in
    List.app add ws; Array.vector a
  end

val table = buckets words

fun lookup s =
  let
    fun go [] = NONE
      | go ((k, t) :: rest) = if k = s then SOME t else go rest
  in
    go (Vector.sub (table, Char.ord (String.sub (s, 0))))
  end

val () = print (case lookup "ab" of SOME B => "found\n" | _ => "not found\n")

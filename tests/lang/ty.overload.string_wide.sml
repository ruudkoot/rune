(* ^, size, concat and substring are overloaded over the class String, as
   the comparisons are: one type of the class throughout, resolved by the
   operands, and string by default (docs/language.md, Deviations,
   Overloading). At WideString.string they are WideString's. *)
val lambda : WideString.string = "\u03BB"
val w = "a" ^ lambda ^ "b"
val () = print (WideString.toString w ^ " " ^ Int.toString (size w) ^ "\n")
val c = concat [w, "-", lambda]
val () = print (WideString.toString c ^ " " ^ Int.toString (size c) ^ "\n")
val () = print (WideString.toString (substring (c, 1, 3)) ^ "\n")
(* without a constraint they are the 8-bit ones, as before *)
fun twice x = x ^ x
val () = print (twice "ab" ^ " " ^ Int.toString (size (twice "ab")) ^ "\n")
val () = print (concat ["x", "y"] ^ substring ("hello", 1, 3) ^ "\n")
(* as values *)
val wsize : WideString.string -> int = size
val wcat : WideString.string * WideString.string -> WideString.string = op ^
val () = print (Int.toString (wsize (wcat (lambda, lambda))) ^ "\n")
val ssize = size
val () = print (Int.toString (ssize "abc") ^ "\n")
(* the operations of the structures are still there *)
val () = print (WideString.toString (WideString.^ (lambda, lambda)) ^ " " ^ String.^ ("a", "b") ^ "\n")

(* The words of a text.

   Area: Tests *)
signature WORDS =
sig
  (* `count s` is the number of words of `s`.

     Example: `count "a b  c" = 3` *)
  val count : string -> int
end

(* Implements: WORDS *)
structure Words =
struct
  fun count s = List.length (String.tokens Char.isSpace s)
end

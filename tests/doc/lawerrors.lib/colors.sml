(* Colours, with laws that cannot be run.

   Area: Tests *)
signature COLORS =
sig
  (* The colours. *)
  datatype color = Red | Green | Blue

  (* `next c` is the colour after `c`, and `Red` after `Blue`.

     Law: `next (next (next c)) = c`, where `c` is a colour that
     lib/test/property has no arbitrary of *)
  val next : color -> color

  (* `index c` is the place of `c` among the colours, from 0.

     Law: `index c < 3 +` *)
  val index : color -> int

  (* `fromIndex i` is the colour at the place `i`.

     Raises: `Subscript` if `i` is not a place of a colour.

     Law: `fromIndex (i mod 3) = fromIndex ((i + 3) mod 3)` for `i` *)
  val fromIndex : int -> color
end

(* Implements: COLORS *)
structure Colors =
struct
  datatype color = Red | Green | Blue
  fun next Red = Green | next Green = Blue | next Blue = Red
  fun index Red = 0 | index Green = 1 | index Blue = 2
  fun fromIndex 0 = Red | fromIndex 1 = Green | fromIndex 2 = Blue | fromIndex _ = raise Subscript
end

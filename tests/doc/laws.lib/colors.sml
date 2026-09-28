(* Colours and their places.

   Area: Tests *)
signature COLORS =
sig
  (* The colours. *)
  datatype color = Red | Green | Blue

  (* `index c` is the place of `c` among the colours, from 0.

     Law: `index (fromIndex i) = i` for `0 <= i andalso i < 3` *)
  val index : color -> int

  (* `fromIndex i` is the colour at the place `i`.

     Raises: `Subscript` if `i` is not a place of a colour.

     Law: `index (fromIndex (i mod 3)) = index (fromIndex ((i + 3) mod 3))` *)
  val fromIndex : int -> color

  (* `keep (f, l)` is the places of `l` that `f` keeps.

     Law: `List.length (keep (f, l)) <= List.length l` when `f` has no effects

     Law (Constant): `keep (fn _ => true, l) = l`, and `keep (fn _ => false, l) = []`

     Law (Idempotent): `keep (f, keep (f, l)) = keep (f, l)` when `f` has no effects

     Law: `keep (f, keep (g, l)) = keep (g, keep (f, l))` when `f` and `g` have
     no effects *)
  val keep : (int -> bool) * int list -> int list
end

(* Implements: COLORS *)
structure Colors =
struct
  datatype color = Red | Green | Blue
  fun index Red = 0 | index Green = 1 | index Blue = 2
  fun fromIndex 0 = Red | fromIndex 1 = Green | fromIndex 2 = Blue | fromIndex _ = raise Subscript
  fun keep (f, l) = List.filter f l
end

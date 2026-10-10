(* A dynamic module's implementation used as an ordinary structure: _export
   ascribes it to its signature opaquely, and its datatype, whose
   constructors it declares in another order than the signature's, takes the
   signature's order for its tags; the program names and matches them as it
   would any structure's (docs/units.md, Dynamic modules) *)
signature COLOUR =
sig
  datatype colour = Red | Green | Blue of int
  type t
  val make : int -> t
  val colourOf : t -> colour
  val name : colour -> string
end

_export structure Colour : COLOUR =
struct
  datatype colour = Blue of int | Green | Red
  type t = colour
  fun make n = if n = 0 then Red else if n = 1 then Green else Blue n
  fun colourOf c = c
  fun name Red = "red" | name Green = "green" | name (Blue n) = "blue " ^ Int.toString n
end

fun show c = case Colour.colourOf c of Colour.Red => "Red" | Colour.Green => "Green" | Colour.Blue n => "Blue " ^ Int.toString n
val () = List.app (fn n => print (show (Colour.make n) ^ " " ^ Colour.name (Colour.colourOf (Colour.make n)) ^ "\n")) [0, 1, 5]

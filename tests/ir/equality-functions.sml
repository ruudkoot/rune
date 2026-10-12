(* dump: --passes=shake,workers,simplify,inline,equality --dump-after=simplify *)
(* The optional pass equality (performance M5, D7 C; from -O2): `=` of a
   datatype at a type with no type variable is a call of the function made
   for that type -- identity first in a wrapper, put where it is called,
   then the worker: the tags, then each field by its own type, the
   function of the datatype itself for the list's tail. *)
datatype t = A | B of int | C of string * t list
fun same (x : t, y) = x = y
val r = (same (B 1, B 1), same (C ("a", [A]), C ("a", [B 2])))

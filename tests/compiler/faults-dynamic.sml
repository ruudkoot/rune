(* The program the casts of a dynamic module's slots are corrupted in
   (dynamic_cast; tests/runner/tools.sml, compiler/faults), built in units,
   as a program that loads one is: compiled only, never run. *)
signature SHAPE =
sig
  val name : string
  val scale : int -> int
  exception Gone of int
  structure Sub : sig val n : int end
end
structure S = _dynamic "faults-impl.rbu" : SHAPE
val () = print (S.name ^ Int.toString (S.scale S.Sub.n) ^ "\n") handle S.Gone k => print (Int.toString k)

(* Stamps: the names of the variables, join points and exceptions of the
   program, one counter for every representation (docs/ir.md, Unique
   stamps). A front end takes its binders' stamps here and a pass the ones it
   makes, so that neither names a front end's module. *)
structure Stamp =
struct
  val counter = ref 0
  val () = CompilerState.cellRoot ("Stamp.counter", counter)
  fun fresh () = let val s = !counter in counter := s + 1; s end
end

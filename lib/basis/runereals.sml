(* The VM's array of reals, which RealArray and RealVector are: the doubles
   themselves side by side, as C has an array of them (docs/runtime.md), so
   that an element is read and written without the word a real has anywhere
   else. An array's equality is its identity; a vector is one that the
   library does not write again once it is made. *)
structure RuneReals =
struct
  type reals = _prim "realarray"
  val new = _prim "reals_new" : int * real -> reals
  val length = _prim "reals_length" : reals -> int
  val sub = _prim "reals_sub" : reals * int -> real
  val update = _prim "reals_update" : reals * int * real -> unit
  val blit = _prim "reals_blit" : reals * int * reals * int * int -> unit
end

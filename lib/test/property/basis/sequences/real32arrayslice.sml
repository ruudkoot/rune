(* Real32ArraySliceArb: the arbitrary of a monomorphic vector, array, slice
   or two-dimensional array that the Basis Library leaves optional, in a
   file of its own, so that a compiler without the structure builds the rest
   (it was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Real32ArraySlice.slice *)
structure Real32ArraySliceArb =
  MonoArraySliceArbFn (structure S = Real32ArraySlice val array = Real32ArrayArb.arb val name = "Real32ArraySlice")

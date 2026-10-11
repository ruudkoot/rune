(* Real32VectorSliceArb: the arbitrary of a monomorphic vector, array, slice
   or two-dimensional array that the Basis Library leaves optional, in a
   file of its own, so that a compiler without the structure builds the rest
   (it was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Real32VectorSlice.slice *)
structure Real32VectorSliceArb =
  MonoVectorSliceArbFn (structure S = Real32VectorSlice val vector = Real32VectorArb.arb val name = "Real32VectorSlice")

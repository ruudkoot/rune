(* Int8VectorSliceArb: the arbitrary of a monomorphic vector, array, slice
   or two-dimensional array that the Basis Library leaves optional, in a
   file of its own, so that a compiler without the structure builds the rest
   (it was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Int8VectorSlice.slice *)
structure Int8VectorSliceArb =
  MonoVectorSliceArbFn (structure S = Int8VectorSlice val vector = Int8VectorArb.arb val name = "Int8VectorSlice")

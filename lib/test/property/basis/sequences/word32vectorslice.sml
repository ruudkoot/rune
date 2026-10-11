(* Word32VectorSliceArb: the arbitrary of a monomorphic vector, array, slice
   or two-dimensional array that the Basis Library leaves optional, in a
   file of its own, so that a compiler without the structure builds the rest
   (it was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Word32VectorSlice.slice *)
structure Word32VectorSliceArb =
  MonoVectorSliceArbFn (structure S = Word32VectorSlice val vector = Word32VectorArb.arb val name = "Word32VectorSlice")

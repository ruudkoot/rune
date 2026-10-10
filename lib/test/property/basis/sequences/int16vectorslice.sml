(* Int16VectorSliceArb: the arbitrary of a monomorphic vector, array, slice
   or two-dimensional array that the Basis Library leaves optional, in a
   file of its own, so that a compiler without the structure builds the rest
   (it was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Int16VectorSlice.slice *)
structure Int16VectorSliceArb =
  MonoVectorSliceArbFn (structure S = Int16VectorSlice val vector = Int16VectorArb.arb val name = "Int16VectorSlice")

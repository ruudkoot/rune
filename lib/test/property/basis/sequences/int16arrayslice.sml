(* Int16ArraySliceArb: the arbitrary of a monomorphic vector, array, slice
   or two-dimensional array that the Basis Library leaves optional, in a
   file of its own, so that a compiler without the structure builds the rest
   (it was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Int16ArraySlice.slice *)
structure Int16ArraySliceArb =
  MonoArraySliceArbFn (structure S = Int16ArraySlice val array = Int16ArrayArb.arb val name = "Int16ArraySlice")

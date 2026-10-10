(* Int64ArraySliceArb: the arbitrary of a monomorphic vector, array, slice
   or two-dimensional array that the Basis Library leaves optional, in a
   file of its own, so that a compiler without the structure builds the rest
   (it was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Int64ArraySlice.slice *)
structure Int64ArraySliceArb =
  MonoArraySliceArbFn (structure S = Int64ArraySlice val array = Int64ArrayArb.arb val name = "Int64ArraySlice")

(* LargeRealArray2Arb: the arbitrary of a monomorphic vector, array, slice
   or two-dimensional array that the Basis Library leaves optional, in a
   file of its own, so that a compiler without the structure builds the rest
   (it was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = LargeRealArray2.array *)
structure LargeRealArray2Arb = MonoArray2ArbFn (structure A = LargeRealArray2 val elem = LargeRealArb.arb val name = "LargeRealArray2")

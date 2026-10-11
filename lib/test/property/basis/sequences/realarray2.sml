(* RealArray2Arb: the arbitrary of a monomorphic vector, array, slice or
   two-dimensional array that the Basis Library leaves optional, in a file
   of its own, so that a compiler without the structure builds the rest (it
   was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = RealArray2.array *)
structure RealArray2Arb = MonoArray2ArbFn (structure A = RealArray2 val elem = RealArb.arb val name = "RealArray2")

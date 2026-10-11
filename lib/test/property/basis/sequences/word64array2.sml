(* Word64Array2Arb: the arbitrary of a monomorphic vector, array, slice or
   two-dimensional array that the Basis Library leaves optional, in a file
   of its own, so that a compiler without the structure builds the rest (it
   was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Word64Array2.array *)
structure Word64Array2Arb = MonoArray2ArbFn (structure A = Word64Array2 val elem = Word64Arb.arb val name = "Word64Array2")

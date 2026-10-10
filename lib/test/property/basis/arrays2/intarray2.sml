(* IntArray2Arb: the arbitrary of a monomorphic two-dimensional array that
   the Basis Library leaves optional, in a file of its own, so that a
   compiler without the structure builds the rest (it was in arrays2.sml;
   docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = IntArray2.array *)
structure IntArray2Arb = MonoArray2ArbFn (structure A = IntArray2 val elem = IntArb.arb val name = "IntArray2")

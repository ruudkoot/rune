(* CharArray2Arb: the arbitrary of a monomorphic two-dimensional array that
   the Basis Library leaves optional, in a file of its own, so that a
   compiler without the structure builds the rest (it was in arrays2.sml;
   docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = CharArray2.array *)
structure CharArray2Arb = MonoArray2ArbFn (structure A = CharArray2 val elem = CharArb.arb val name = "CharArray2")

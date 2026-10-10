(* Word8Array2Arb: the arbitrary of a monomorphic two-dimensional array that
   the Basis Library leaves optional, in a file of its own, so that a
   compiler without the structure builds the rest (it was in arrays2.sml;
   docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Word8Array2.array *)
structure Word8Array2Arb = MonoArray2ArbFn (structure A = Word8Array2 val elem = Word8Arb.arb val name = "Word8Array2")

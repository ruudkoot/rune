(* Word32Array2Arb: the arbitrary of a monomorphic vector, array, slice or
   two-dimensional array that the Basis Library leaves optional, in a file
   of its own, so that a compiler without the structure builds the rest (it
   was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Word32Array2.array *)
structure Word32Array2Arb = MonoArray2ArbFn (structure A = Word32Array2 val elem = Word32Arb.arb val name = "Word32Array2")

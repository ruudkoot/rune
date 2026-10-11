(* Word16VectorArb: the arbitrary of a monomorphic vector, array, slice or
   two-dimensional array that the Basis Library leaves optional, in a file
   of its own, so that a compiler without the structure builds the rest (it
   was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Word16Vector.vector *)
structure Word16VectorArb = MonoVectorArbFn (structure V = Word16Vector val elem = Word16Arb.arb val name = "Word16Vector")

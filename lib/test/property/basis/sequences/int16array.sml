(* Int16ArrayArb: the arbitrary of a monomorphic vector, array, slice or
   two-dimensional array that the Basis Library leaves optional, in a file
   of its own, so that a compiler without the structure builds the rest (it
   was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Int16Array.array *)
structure Int16ArrayArb = MonoArrayArbFn (structure A = Int16Array val elem = Int16Arb.arb val name = "Int16Array")

(* Int64ArrayArb: the arbitrary of a monomorphic vector, array, slice or
   two-dimensional array that the Basis Library leaves optional, in a file
   of its own, so that a compiler without the structure builds the rest (it
   was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Int64Array.array *)
structure Int64ArrayArb = MonoArrayArbFn (structure A = Int64Array val elem = Int64Arb.arb val name = "Int64Array")

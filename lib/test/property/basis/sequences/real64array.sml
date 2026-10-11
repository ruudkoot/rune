(* Real64ArrayArb: the arbitrary of a monomorphic vector, array, slice or
   two-dimensional array that the Basis Library leaves optional, in a file
   of its own, so that a compiler without the structure builds the rest (it
   was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Real64Array.array *)
structure Real64ArrayArb = MonoArrayArbFn (structure A = Real64Array val elem = Real64Arb.arb val name = "Real64Array")

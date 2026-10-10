(* IntArrayArb: the arbitrary of a monomorphic vector, array, slice or
   two-dimensional array that the Basis Library leaves optional, in a file
   of its own, so that a compiler without the structure builds the rest (it
   was in sequences.sml; docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = IntArray.array *)
structure IntArrayArb = MonoArrayArbFn (structure A = IntArray val elem = IntArb.arb val name = "IntArray")

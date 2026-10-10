(* Int32Arb: the arbitrary of an integer, word or real of a fixed width that
   the Basis Library leaves optional, in a file of its own, so that a
   compiler without the structure builds the rest (it was in sized.sml;
   docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = Int32.int *)
structure Int32Arb = IntegerArbFn (Int32)

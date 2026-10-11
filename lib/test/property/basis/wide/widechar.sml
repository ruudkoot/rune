(* WideCharArb: an arbitrary of the wide characters and their text that the
   Basis Library leaves optional, in a file of its own, so that a compiler
   without the structure builds the rest (it was in wide.sml;
   docs/plans/quickcheck.md, D10). *)

(* Implements: ARB_OF where type t = WideChar.char *)
structure WideCharArb = CharArbFn (WideChar)

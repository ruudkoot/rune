(* The arbitraries of the Basis Library's optional wide characters, strings
   and substrings (docs/plans/quickcheck.md, M6): `XArb.arb` is the arbitrary
   of the type of `X`. *)

(* Implements: ARB_OF where type t = WideChar.char *)
structure WideCharArb = CharArbFn (WideChar)
(* Implements: ARB_OF where type t = WideString.string *)
structure WideStringArb = StringArbFn (structure S = WideString val char = WideCharArb.arb)
(* Implements: ARB_OF where type t = WideSubstring.substring *)
structure WideSubstringArb =
  SubstringArbFn (structure S = WideSubstring val string = WideStringArb.arb val name = "WideSubstring")

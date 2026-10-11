(* The arbitraries of the characters, strings, substrings and their vectors,
   arrays and slices that the Basis Library requires (docs/plans/quickcheck.md,
   M6): `XArb.arb` is the arbitrary of the type of `X`. The optional wide
   characters are in wide.sml. *)

(* Implements: ARB_OF where type t = Char.char *)
structure CharArb = CharArbFn (Char)
(* Implements: ARB_OF where type t = String.string *)
structure StringArb = StringArbFn (structure S = String val char = CharArb.arb)
(* Implements: ARB_OF where type t = Substring.substring *)
structure SubstringArb = SubstringArbFn (structure S = Substring val string = StringArb.arb val name = "Substring")

(* Implements: ARB_OF where type t = CharVector.vector *)
structure CharVectorArb = MonoVectorArbFn (structure V = CharVector val elem = CharArb.arb val name = "CharVector")
(* Implements: ARB_OF where type t = CharArray.array *)
structure CharArrayArb = MonoArrayArbFn (structure A = CharArray val elem = CharArb.arb val name = "CharArray")
(* Implements: ARB_OF where type t = CharVectorSlice.slice *)
structure CharVectorSliceArb =
  MonoVectorSliceArbFn (structure S = CharVectorSlice val vector = CharVectorArb.arb val name = "CharVectorSlice")
(* Implements: ARB_OF where type t = CharArraySlice.slice *)
structure CharArraySliceArb =
  MonoArraySliceArbFn (structure S = CharArraySlice val array = CharArrayArb.arb val name = "CharArraySlice")

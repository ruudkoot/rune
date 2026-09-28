(* The arbitraries of the Basis Library's optional integers, words and reals
   of fixed widths (docs/plans/quickcheck.md, M6): `XArb.arb` is the
   arbitrary of `X.int`, `X.word` or `X.real`. Not every compiler has every
   one of these structures. *)

(* Implements: ARB_OF where type t = Int8.int *)
structure Int8Arb = IntegerArbFn (Int8)
(* Implements: ARB_OF where type t = Int16.int *)
structure Int16Arb = IntegerArbFn (Int16)
(* Implements: ARB_OF where type t = Int32.int *)
structure Int32Arb = IntegerArbFn (Int32)
(* Implements: ARB_OF where type t = Int64.int *)
structure Int64Arb = IntegerArbFn (Int64)
(* Implements: ARB_OF where type t = FixedInt.int *)
structure FixedIntArb = IntegerArbFn (FixedInt)

(* Implements: ARB_OF where type t = Word16.word *)
structure Word16Arb = WordArbFn (Word16)
(* Implements: ARB_OF where type t = Word32.word *)
structure Word32Arb = WordArbFn (Word32)
(* Implements: ARB_OF where type t = Word64.word *)
structure Word64Arb = WordArbFn (Word64)

(* Implements: ARB_OF where type t = Real32.real *)
structure Real32Arb = RealArbFn (Real32)
(* Implements: ARB_OF where type t = Real64.real *)
structure Real64Arb = RealArbFn (Real64)

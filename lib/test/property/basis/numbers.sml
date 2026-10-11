(* The arbitraries of the integers, words and reals of the structures the
   Basis Library requires, and of IntInf and SysWord (docs/plans/quickcheck.md,
   M6): `XArb.arb` is the arbitrary of `X.int`, `X.word` or `X.real`. The
   optional structures of fixed widths are in sized.sml. *)

(* Implements: ARB_OF where type t = Int.int *)
structure IntArb = IntegerArbFn (Int)
(* Implements: ARB_OF where type t = IntInf.int *)
structure IntInfArb = IntegerArbFn (IntInf)
(* Implements: ARB_OF where type t = LargeInt.int *)
structure LargeIntArb = IntegerArbFn (LargeInt)
(* Implements: ARB_OF where type t = Position.int *)
structure PositionArb = IntegerArbFn (Position)

(* Implements: ARB_OF where type t = Word.word *)
structure WordArb = WordArbFn (Word)
(* Implements: ARB_OF where type t = Word8.word *)
structure Word8Arb = WordArbFn (Word8)
(* Implements: ARB_OF where type t = LargeWord.word *)
structure LargeWordArb = WordArbFn (LargeWord)
(* Implements: ARB_OF where type t = SysWord.word *)
structure SysWordArb = WordArbFn (SysWord)

(* Implements: ARB_OF where type t = Real.real *)
structure RealArb = RealArbFn (Real)
(* Implements: ARB_OF where type t = LargeReal.real *)
structure LargeRealArb = RealArbFn (LargeReal)

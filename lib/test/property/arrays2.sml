(* The arbitraries of the Basis Library's optional monomorphic
   two-dimensional arrays that its laws are written over
   (docs/plans/quickcheck.md, M6): `XArb.arb` is the arbitrary of the type of
   `X`. *)

(* Implements: ARB_OF where type t = IntArray2.array *)
structure IntArray2Arb = MonoArray2ArbFn (structure A = IntArray2 val elem = IntArb.arb val name = "IntArray2")
(* Implements: ARB_OF where type t = CharArray2.array *)
structure CharArray2Arb = MonoArray2ArbFn (structure A = CharArray2 val elem = CharArb.arb val name = "CharArray2")
(* Implements: ARB_OF where type t = Word8Array2.array *)
structure Word8Array2Arb = MonoArray2ArbFn (structure A = Word8Array2 val elem = Word8Arb.arb val name = "Word8Array2")

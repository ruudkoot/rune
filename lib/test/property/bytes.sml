(* The arbitraries of the vectors, arrays and slices of bytes that the Basis
   Library requires (docs/plans/quickcheck.md, M6): `XArb.arb` is the
   arbitrary of the type of `X`. *)

(* Implements: ARB_OF where type t = Word8Vector.vector *)
structure Word8VectorArb = MonoVectorArbFn (structure V = Word8Vector val elem = Word8Arb.arb val name = "Word8Vector")
(* Implements: ARB_OF where type t = Word8Array.array *)
structure Word8ArrayArb = MonoArrayArbFn (structure A = Word8Array val elem = Word8Arb.arb val name = "Word8Array")
(* Implements: ARB_OF where type t = Word8VectorSlice.slice *)
structure Word8VectorSliceArb =
  MonoVectorSliceArbFn (structure S = Word8VectorSlice val vector = Word8VectorArb.arb val name = "Word8VectorSlice")
(* Implements: ARB_OF where type t = Word8ArraySlice.slice *)
structure Word8ArraySliceArb =
  MonoArraySliceArbFn (structure S = Word8ArraySlice val array = Word8ArrayArb.arb val name = "Word8ArraySlice")

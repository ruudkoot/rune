(* requires: Word8ArraySlice Word8Array Word8VectorSlice Word8Vector Word8 *)
(* uses: spec-sigs/MONO_ARRAY_SLICE.sml *)
(* Word8ArraySlice matches MONO_ARRAY_SLICE, `where type vector =
   Word8Vector.vector where type vector_slice = Word8VectorSlice.slice where
   type array = Word8Array.array where type elem = Word8.word`. *)
structure TestWord8ArraySliceSig =
struct
  structure C : SPEC_MONO_ARRAY_SLICE = Word8ArraySlice
  structure E : SPEC_MONO_ARRAY_SLICE where type vector = Word8Vector.vector where type vector_slice = Word8VectorSlice.slice where type array = Word8Array.array where type elem = Word8.word = Word8ArraySlice
  val () = T.check ("Word8ArraySlice:MONO_ARRAY_SLICE/matches", fn () => true)
  val () = T.check ("Word8ArraySlice:MONO_ARRAY_SLICE/array-is-Word8Array.array",
                    fn () => E.length (E.full (Word8Array.array (3, Word8.fromInt 0))) = 3
                             andalso Word8Array.length (#1 (E.base (E.full (Word8Array.array (3, Word8.fromInt 0))))) = 3)
  val () = T.check ("Word8ArraySlice:MONO_ARRAY_SLICE/vector-is-Word8Vector.vector",
                    fn () => Word8Vector.length (E.vector (E.full (Word8Array.array (3, Word8.fromInt 0)))) = 3)
  val () = T.check ("Word8ArraySlice:MONO_ARRAY_SLICE/vector_slice-is-Word8VectorSlice.slice",
                    fn () => let val a = Word8Array.array (3, Word8.fromInt 0)
                             in E.copyVec {src = Word8VectorSlice.full (Word8Vector.tabulate (2, fn _ => Word8.fromInt 9)), dst = a, di = 1};
                                Word8.toInt (Word8Array.sub (a, 2)) = 9 end)
  val () = T.check ("Word8ArraySlice:MONO_ARRAY_SLICE/elem-is-Word8.word",
                    fn () => Word8.toInt (E.sub (E.full (Word8Array.array (1, Word8.fromInt 7)), 0) : Word8.word) = 7)
  val () = T.check ("Word8ArraySlice:MONO_ARRAY_SLICE/slice-is-Word8ArraySlice.slice",
                    fn () => Word8ArraySlice.length (E.full (Word8Array.fromList []) : Word8ArraySlice.slice) = 0)
  (* the signature can be implemented opaquely, given the other types *)
  structure O :> SPEC_MONO_ARRAY_SLICE where type vector = Word8Vector.vector where type vector_slice = Word8VectorSlice.slice where type array = Word8Array.array where type elem = Word8.word = Word8ArraySlice
  val () = T.check ("Word8ArraySlice:MONO_ARRAY_SLICE/opaque-slice",
                    fn () => Word8.toInt (O.sub (O.slice (Word8Array.tabulate (5, Word8.fromInt), 2, NONE), 1)) = 3)
end

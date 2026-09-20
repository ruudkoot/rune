(* requires: Word8VectorSlice Word8Vector Word8 *)
(* uses: spec-sigs/MONO_VECTOR_SLICE.sml *)
(* Word8VectorSlice matches MONO_VECTOR_SLICE, `where type vector =
   Word8Vector.vector where type elem = Word8.word`. *)
structure TestWord8VectorSliceSig =
struct
  structure C : SPEC_MONO_VECTOR_SLICE = Word8VectorSlice
  structure E : SPEC_MONO_VECTOR_SLICE where type vector = Word8Vector.vector where type elem = Word8.word = Word8VectorSlice
  val () = T.check ("Word8VectorSlice:MONO_VECTOR_SLICE/matches", fn () => true)
  val () = T.check ("Word8VectorSlice:MONO_VECTOR_SLICE/vector-is-Word8Vector.vector",
                    fn () => Word8Vector.length (E.vector (E.full (Word8Vector.tabulate (3, Word8.fromInt)))) = 3)
  val () = T.check ("Word8VectorSlice:MONO_VECTOR_SLICE/elem-is-Word8.word",
                    fn () => Word8.toInt (E.sub (E.full (Word8Vector.tabulate (3, Word8.fromInt)), 2) : Word8.word) = 2)
  val () = T.check ("Word8VectorSlice:MONO_VECTOR_SLICE/slice-is-Word8VectorSlice.slice",
                    fn () => Word8VectorSlice.length (E.full (Word8Vector.fromList []) : Word8VectorSlice.slice) = 0
                             andalso E.length (Word8VectorSlice.full (Word8Vector.fromList []) : E.slice) = 0)
  (* the signature can be implemented opaquely, given elem and vector *)
  structure O :> SPEC_MONO_VECTOR_SLICE where type vector = Word8Vector.vector where type elem = Word8.word = Word8VectorSlice
  val () = T.check ("Word8VectorSlice:MONO_VECTOR_SLICE/opaque-slice",
                    fn () => Word8.toInt (O.sub (O.slice (Word8Vector.tabulate (5, Word8.fromInt), 2, NONE), 1)) = 3)
end

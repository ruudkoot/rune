(* requires: Word8Vector Word8 *)
(* uses: spec-sigs/MONO_VECTOR.sml *)
(* Word8Vector matches MONO_VECTOR, `where type elem = Word8.word`. *)
structure TestWord8VectorSig =
struct
  structure C : SPEC_MONO_VECTOR = Word8Vector
  structure E : SPEC_MONO_VECTOR where type elem = Word8.word = Word8Vector
  val () = T.check ("Word8Vector:MONO_VECTOR/matches", fn () => true)
  val () = T.check ("Word8Vector:MONO_VECTOR/elem-is-Word8.word",
                    fn () => Word8.toInt (E.sub (E.fromList [Word8.fromInt 7 : Word8.word], 0) : Word8.word) = 7)
  val () = T.check ("Word8Vector:MONO_VECTOR/vector-is-Word8Vector.vector",
                    fn () => Word8Vector.length (C.fromList [] : Word8Vector.vector) = 0
                             andalso C.length (Word8Vector.fromList [] : C.vector) = 0)
  (* the signature can be implemented opaquely, given elem *)
  structure O :> SPEC_MONO_VECTOR where type elem = Word8.word = Word8Vector
  val () = T.check ("Word8Vector:MONO_VECTOR/opaque-vector",
                    fn () => Word8.toInt (O.sub (O.tabulate (3, Word8.fromInt), 2)) = 2)
end

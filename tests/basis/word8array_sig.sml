(* requires: Word8Array Word8Vector Word8 *)
(* uses: spec-sigs/MONO_ARRAY.sml *)
(* Word8Array matches MONO_ARRAY, `where type vector = Word8Vector.vector where
   type elem = Word8.word`, and its array type admits equality. *)
structure TestWord8ArraySig =
struct
  structure C : SPEC_MONO_ARRAY = Word8Array
  structure E : SPEC_MONO_ARRAY where type vector = Word8Vector.vector where type elem = Word8.word = Word8Array
  val () = T.check ("Word8Array:MONO_ARRAY/matches", fn () => true)
  val () = T.check ("Word8Array:MONO_ARRAY/elem-is-Word8.word",
                    fn () => Word8.toInt (E.sub (E.array (1, Word8.fromInt 7 : Word8.word), 0) : Word8.word) = 7)
  val () = T.check ("Word8Array:MONO_ARRAY/vector-is-Word8Vector.vector",
                    fn () => Word8Vector.length (E.vector (E.array (3, Word8.fromInt 0))) = 3)
  val () = T.check ("Word8Array:MONO_ARRAY/array-is-Word8Array.array",
                    fn () => Word8Array.length (C.fromList [] : Word8Array.array) = 0
                             andalso C.length (Word8Array.fromList [] : C.array) = 0)
  val () = T.check ("Word8Array:MONO_ARRAY/eqtype", fn () => let val a = C.fromList [] in a = a end)
  (* the signature can be implemented opaquely, given elem and vector *)
  structure O :> SPEC_MONO_ARRAY where type vector = Word8Vector.vector where type elem = Word8.word = Word8Array
  val () = T.check ("Word8Array:MONO_ARRAY/opaque-array",
                    fn () => let val a = O.tabulate (3, Word8.fromInt) in Word8.toInt (O.sub (a, 2)) = 2 andalso a = a end)
end

(* requires: Word8Array2 Word8Vector Word8 *)
(* uses: spec-sigs/MONO_ARRAY2.sml *)
(* Word8Array2 matches MONO_ARRAY2, `where type vector = Word8Vector.vector
   where type elem = Word8.word`; its array type admits equality, its
   traversal is that of Array2, and it can be implemented opaquely. *)
structure TestWord8Array2Sig =
struct
  structure C : SPEC_MONO_ARRAY2 = Word8Array2
  structure E : SPEC_MONO_ARRAY2 where type vector = Word8Vector.vector where type elem = Word8.word = Word8Array2
  val () = T.check ("Word8Array2:MONO_ARRAY2/matches", fn () => true)
  val () = T.check ("Word8Array2:MONO_ARRAY2/elem-is-Word8.word",
                    fn () => Word8.toInt (E.sub (E.array (1, 1, Word8.fromInt 7), 0, 0) : Word8.word) = 7)
  val () = T.check ("Word8Array2:MONO_ARRAY2/vector-is-Word8Vector.vector",
                    fn () => Word8Vector.length (E.row (E.array (2, 3, Word8.fromInt 0), 1)) = 3)
  val () = T.check ("Word8Array2:MONO_ARRAY2/array-is-Word8Array2.array",
                    fn () => Word8Array2.nRows (C.array (2, 3, Word8.fromInt 0) : Word8Array2.array) = 2
                             andalso C.nCols (Word8Array2.array (2, 3, Word8.fromInt 0) : C.array) = 3)
  val () = T.check ("Word8Array2:MONO_ARRAY2/region-is-Word8Array2.region",
                    fn () => let val a = Word8Array2.array (2, 3, Word8.fromInt 0)
                             in C.foldi C.RowMajor (fn (_, _, _, n) => n + 1) 0
                                  ({base = a, row = 1, col = 0, nrows = NONE, ncols = NONE} : Word8Array2.region) = 3 end)
  val () = T.check ("Word8Array2:MONO_ARRAY2/traversal-is-Array2.traversal",
                    fn () => (C.RowMajor : Array2.traversal) = Array2.RowMajor andalso Word8Array2.ColMajor = (Array2.ColMajor : C.traversal))
  val () = T.check ("Word8Array2:MONO_ARRAY2/eqtype", fn () => let val a = C.array (1, 1, Word8.fromInt 0) in a = a end)
  structure O :> SPEC_MONO_ARRAY2 where type vector = Word8Vector.vector where type elem = Word8.word = Word8Array2
  val () = T.check ("Word8Array2:MONO_ARRAY2/opaque-array",
                    fn () => let val a = O.tabulate O.ColMajor (2, 2, fn (i, j) => Word8.fromInt (2 * i + j))
                             in Word8.toInt (Word8Vector.sub (O.row (a, 1), 0)) = 2 andalso a = a end)
end

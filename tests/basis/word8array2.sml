(* requires: Word8Array2 Word8Vector Word8 List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY2.sml fn/mono_array2_fn.sml *)
(* Word8Array2 (optional in the specification: MONO_ARRAY2 "where type vector
   = Word8Vector.vector where type elem = Word8.word"): the checks that hold
   for every MONO_ARRAY2 structure, from fn/mono_array2_fn.sml, on 16 sample
   bytes that include 0 and 255, and those of the element and vector types.
   Bytes are built with Word8.fromInt: there are no word constants at
   Word8.word here. *)
structure TestWord8Array2 =
struct
  val bytes = Vector.fromList (List.map Word8.fromInt [0, 1, 2, 127, 128, 200, 254, 255, 3, 4, 5, 64, 100, 129, 253, 16])
  structure Generic = TestMonoArray2Fn (structure A = Word8Array2 structure V = Word8Vector val name = "Word8Array2" val elems = bytes val show = Word8.toString val same = op =)
  structure Laws = TestMonoArray2LawsFn (structure A = Word8Array2 structure V = Word8Vector val name = "Word8Array2" val elems = bytes val show = Word8.toString val same = op = val empty = false)

  val eqL = T.eq (T.list T.int)
  fun vectorToInts v = List.tabulate (Word8Vector.length v, fn i => Word8.toInt (Word8Vector.sub (v, i)))

  (* ---- elem is Word8.word, rows and columns are Word8Vector.vector ---- *)
  val () = eqL ("Word8Array2.tabulate/every-byte", List.tabulate (256, fn i => i),
                fn () => let val a = Word8Array2.tabulate Word8Array2.RowMajor (16, 16, fn (i, j) => Word8.fromInt (16 * i + j))
                         in List.concat (List.tabulate (16, fn i => vectorToInts (Word8Array2.row (a, i)))) end)
  val () = eqL ("Word8Array2.column/Word8Vector", [15, 31, 47], fn () =>
                vectorToInts (Word8Array2.column (Word8Array2.tabulate Word8Array2.ColMajor (3, 16, fn (i, j) => Word8.fromInt (16 * i + j)), 15)))
  val () = eqL ("Word8Array2.modify/Word8-arithmetic", [1, 0, 129],   (* + 1 modulo 256 *)
                fn () => let val a = Word8Array2.fromList [List.map Word8.fromInt [0, 255, 128]]
                         in Word8Array2.modify Word8Array2.RowMajor (fn w => Word8.+ (w, Word8.fromInt 1)) a; vectorToInts (Word8Array2.row (a, 0)) end)
  val () = T.eq T.int ("Word8Array2.fold/sum-of-bytes", 32640,   (* 255 * 256 div 2 *)
                       fn () => Word8Array2.fold Word8Array2.ColMajor (fn (w, s) => Word8.toInt w + s) 0
                                  (Word8Array2.tabulate Word8Array2.RowMajor (16, 16, fn (i, j) => Word8.fromInt (16 * i + j))))

  (*<< no-elements *)
  structure Empty = TestMonoArray2EmptyFn (structure A = Word8Array2 val name = "Word8Array2" val elems = bytes val show = Word8.toString val same = op =)
  structure LawsEmpty = TestMonoArray2LawsFn (structure A = Word8Array2 structure V = Word8Vector val name = "Word8Array2" val elems = bytes val show = Word8.toString val same = op = val empty = true)
  (*>> no-elements *)

  (*<< overflow *)
  structure Overflow = TestMonoArray2OverflowFn (structure A = Word8Array2 val name = "Word8Array2" val elem = Word8.fromInt 0)
  (*>> overflow *)

  (*<< too-large *)
  structure Size = TestMonoArray2SizeFn (structure A = Word8Array2 val name = "Word8Array2" val elem = Word8.fromInt 0)
  (*>> too-large *)
end

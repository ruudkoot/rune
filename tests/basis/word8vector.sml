(* requires: Word8Vector Word8 List *)
(* uses: spec-sigs/MONO_VECTOR.sml fn/mono_vector_fn.sml *)
(* Word8Vector (signature MONO_VECTOR, "where type elem = Word8.word"): the
   checks that hold for every MONO_VECTOR structure, from
   fn/mono_vector_fn.sml, on sample bytes that include 0 and 255, and those of
   the element type. Bytes are built with Word8.fromInt: there are no word
   constants at Word8.word here. *)
structure TestWord8Vector =
struct
  val bytes = Vector.fromList (List.map Word8.fromInt [0, 1, 2, 127, 128, 200, 254, 255])
  structure Generic = TestMonoVectorFn (structure V = Word8Vector val name = "Word8Vector" val elems = bytes val show = Word8.toString val same = op =)

  val eqI = T.eq T.int
  val eqL = T.eq (T.list T.int)
  fun toInts v = List.tabulate (Word8Vector.length v, fn i => Word8.toInt (Word8Vector.sub (v, i)))

  (* ---- elem is Word8.word: every byte is an element, and stays itself ---- *)
  val () = eqL ("Word8Vector.tabulate/every-byte", List.tabulate (256, fn i => i),
                fn () => toInts (Word8Vector.tabulate (256, Word8.fromInt)))
  val () = eqL ("Word8Vector.fromList/every-byte", List.tabulate (256, fn i => 255 - i),
                fn () => toInts (Word8Vector.fromList (List.tabulate (256, fn i => Word8.fromInt (255 - i)))))
  val () = eqI ("Word8Vector.sub/elem-is-Word8.word", 44,   (* 300 mod 256 *)
                fn () => Word8.toInt (Word8Vector.sub (Word8Vector.fromList [Word8.fromInt 300], 0)))
  val () = eqL ("Word8Vector.map/Word8-arithmetic", [1, 0, 129],   (* + 1 modulo 256 *)
                fn () => toInts (Word8Vector.map (fn w => Word8.+ (w, Word8.fromInt 1))
                                                 (Word8Vector.fromList (List.map Word8.fromInt [0, 255, 128]))))
  val () = eqI ("Word8Vector.foldl/sum-of-bytes", 32640,   (* 255 * 256 div 2 *)
                fn () => Word8Vector.foldl (fn (w, s) => Word8.toInt w + s) 0 (Word8Vector.tabulate (256, Word8.fromInt)))
  val () = T.eq T.order ("Word8Vector.collate/unsigned-bytes", LESS,   (* 127 < 128 as words *)
                         fn () => Word8Vector.collate Word8.compare
                                    (Word8Vector.fromList [Word8.fromInt 127], Word8Vector.fromList [Word8.fromInt 128]))

  (*<< size *)
  structure Size = TestMonoVectorSizeFn (structure V = Word8Vector val name = "Word8Vector" val elem = Word8.fromInt 0)
  (*>> size *)
end

(* requires: Word8Array Word8Vector Word8 List *)
(* uses: spec-sigs/MONO_VECTOR.sml spec-sigs/MONO_ARRAY.sml fn/mono_array_fn.sml *)
(* Word8Array (signature MONO_ARRAY, "where type vector = Word8Vector.vector
   where type elem = Word8.word"): the checks that hold for every MONO_ARRAY
   structure, from fn/mono_array_fn.sml, on sample bytes that include 0 and
   255, and those of the element and vector types. Bytes are built with
   Word8.fromInt: there are no word constants at Word8.word here. *)
structure TestWord8Array =
struct
  val bytes = Vector.fromList (List.map Word8.fromInt [0, 1, 2, 127, 128, 200, 254, 255])
  structure Generic = TestMonoArrayFn (structure A = Word8Array structure V = Word8Vector val name = "Word8Array" val elems = bytes val show = Word8.toString val same = op =)

  val eqI = T.eq T.int
  val eqL = T.eq (T.list T.int)
  fun toInts a = List.tabulate (Word8Array.length a, fn i => Word8.toInt (Word8Array.sub (a, i)))
  fun vectorToInts v = List.tabulate (Word8Vector.length v, fn i => Word8.toInt (Word8Vector.sub (v, i)))
  fun fromInts l = Word8Array.fromList (List.map Word8.fromInt l)

  (* ---- elem is Word8.word: every byte is an element, and stays itself ---- *)
  val () = eqL ("Word8Array.tabulate/every-byte", List.tabulate (256, fn i => i),
                fn () => toInts (Word8Array.tabulate (256, Word8.fromInt)))
  val () = eqL ("Word8Array.update/every-byte", List.tabulate (256, fn i => 255 - i),
                fn () => let val a = Word8Array.array (256, Word8.fromInt 0)
                         in T.repeat (256, fn i => Word8Array.update (a, i, Word8.fromInt (255 - i))); toInts a end)
  val () = eqI ("Word8Array.sub/elem-is-Word8.word", 44,   (* 300 mod 256 *)
                fn () => Word8.toInt (Word8Array.sub (Word8Array.array (1, Word8.fromInt 300), 0)))
  val () = eqL ("Word8Array.modify/Word8-arithmetic", [1, 0, 129],   (* + 1 modulo 256 *)
                fn () => let val a = fromInts [0, 255, 128]
                         in Word8Array.modify (fn w => Word8.+ (w, Word8.fromInt 1)) a; toInts a end)
  val () = eqI ("Word8Array.foldl/sum-of-bytes", 32640,   (* 255 * 256 div 2 *)
                fn () => Word8Array.foldl (fn (w, s) => Word8.toInt w + s) 0 (Word8Array.tabulate (256, Word8.fromInt)))
  val () = T.eq T.order ("Word8Array.collate/unsigned-bytes", LESS,   (* 127 < 128 as words *)
                         fn () => Word8Array.collate Word8.compare (fromInts [127], fromInts [128]))

  (* ---- vector is Word8Vector.vector ---- *)
  val () = eqL ("Word8Array.vector/is-Word8Vector.vector", [1, 2, 255],
                fn () => vectorToInts (Word8Array.vector (fromInts [1, 2, 255]) : Word8Vector.vector))
  val () = eqL ("Word8Array.copyVec/from-Word8Vector", [0, 9, 8, 0],
                fn () => let val a = fromInts [0, 0, 0, 0]
                         in Word8Array.copyVec {src = Word8Vector.fromList [Word8.fromInt 9, Word8.fromInt 8], dst = a, di = 1};
                            toInts a end)

  (*<< size *)
  structure Size = TestMonoArraySizeFn (structure A = Word8Array val name = "Word8Array" val elem = Word8.fromInt 0)
  (*>> size *)
end

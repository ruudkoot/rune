(* Checks of a structure with signature PACK_WORD, after
   https://smlfamily.github.io/Basis/pack-word.html.

     structure R = TestPackWordFn (structure P = PackWord32Big val name = "PackWord32Big"
                                   val bytes = 4 val big = true)

   The expected values are worked out from the definition: element i is the
   bytes bytesPerElem*i .. bytesPerElem*(i+1)-1, most significant first when
   big. Bytes are built with Word8.fromInt; LargeWord is assumed to have at
   least 8 * bytes bits. *)
signature TEST_PACK_WORD =
sig
  val bytesPerElem : int
  val isBigEndian : bool
  val subVec : Word8Vector.vector * int -> LargeWord.word
  val subVecX : Word8Vector.vector * int -> LargeWord.word
  val subArr : Word8Array.array * int -> LargeWord.word
  val subArrX : Word8Array.array * int -> LargeWord.word
  val update : Word8Array.array * int * LargeWord.word -> unit
end

functor TestPackWordFn (structure P : TEST_PACK_WORD val name : string val bytes : int val big : bool) =
struct
  fun lab s = name ^ "." ^ s
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqW = T.eq (fn w => "0wx" ^ LargeWord.toString w)
  val eqL = T.eq (T.list T.int)
  val isSubscript = fn Subscript => true | _ => false

  (* the model: the word of element i of a sequence given by its bytes *)
  fun model (byte : int -> int, i) =
    let
      fun go (k, w) =
        if k = bytes then w
        else
          let val b = byte (bytes * i + (if big then k else bytes - 1 - k))
          in go (k + 1, LargeWord.orb (LargeWord.<< (w, 0w8), LargeWord.fromInt b)) end
    in go (0, 0w0) end
  val bits = Word.fromInt (8 * bytes)
  fun extended w =
    if Word.>= (bits, Word.fromInt LargeWord.wordSize) then w
    else if LargeWord.andb (w, LargeWord.<< (0w1, Word.- (bits, 0w1))) <> 0w0
    then LargeWord.orb (w, LargeWord.notb (LargeWord.- (LargeWord.<< (0w1, bits), 0w1)))
    else w

  (* three elements of bytes 1, 2, 3, ..., and three whose top bytes are set *)
  fun small j = j + 1
  fun high j = 255 - j
  fun vec f = Word8Vector.tabulate (3 * bytes, fn j => Word8.fromInt (f j))
  fun arr f = Word8Array.tabulate (3 * bytes, fn j => Word8.fromInt (f j))

  val () = eqI (lab "bytesPerElem/value", bytes, fn () => P.bytesPerElem)
  val () = eqB (lab "isBigEndian/value", big, fn () => P.isBigEndian)

  val () = List.app (fn i =>
    (eqW (lab "subVec/element-" ^ Int.toString i, model (small, i), fn () => P.subVec (vec small, i));
     eqW (lab "subVec/high-element-" ^ Int.toString i, model (high, i), fn () => P.subVec (vec high, i));
     eqW (lab "subVecX/sign-extended-" ^ Int.toString i, extended (model (high, i)), fn () => P.subVecX (vec high, i));
     eqW (lab "subVecX/non-negative-" ^ Int.toString i, model (small, i), fn () => P.subVecX (vec small, i));
     eqW (lab "subArr/element-" ^ Int.toString i, model (small, i), fn () => P.subArr (arr small, i));
     eqW (lab "subArr/high-element-" ^ Int.toString i, model (high, i), fn () => P.subArr (arr high, i));
     eqW (lab "subArrX/sign-extended-" ^ Int.toString i, extended (model (high, i)), fn () => P.subArrX (arr high, i));
     eqW (lab "subArrX/non-negative-" ^ Int.toString i, model (small, i), fn () => P.subArrX (arr small, i))))
    [0, 1, 2]

  (* "Subscript if i < 0 or if length < bytesPerElem * (i + 1)" *)
  val () = T.raises (lab "subVec/Subscript-negative", isSubscript, fn () => P.subVec (vec small, ~1))
  val () = T.raises (lab "subVec/Subscript-past-the-end", isSubscript, fn () => P.subVec (vec small, 3))
  val () = T.raises (lab "subVec/Subscript-partial-element", isSubscript,
                     fn () => P.subVec (Word8Vector.tabulate (bytes - 1, fn _ => Word8.fromInt 1), 0))
  val () = T.raises (lab "subVecX/Subscript-past-the-end", isSubscript, fn () => P.subVecX (vec small, 3))
  val () = T.raises (lab "subArr/Subscript-negative", isSubscript, fn () => P.subArr (arr small, ~1))
  val () = T.raises (lab "subArr/Subscript-past-the-end", isSubscript, fn () => P.subArr (arr small, 3))
  val () = T.raises (lab "subArrX/Subscript-past-the-end", isSubscript, fn () => P.subArrX (arr small, 3))

  (* "stores the bytesPerElem low-order bytes of the word w into the bytes
     bytesPerElem*i through bytesPerElem*(i+1)-1" *)
  fun bytesOf a = List.tabulate (Word8Array.length a, fn j => Word8.toInt (Word8Array.sub (a, j)))
  (* 0wx0102030405060708, as far as LargeWord goes, built from its bytes *)
  val w = List.foldl (fn (b, acc) => LargeWord.orb (LargeWord.<< (acc, 0w8), LargeWord.fromInt b)) 0w0
                     [1, 2, 3, 4, 5, 6, 7, 8]
  val low = if Word.>= (bits, Word.fromInt LargeWord.wordSize) then w
            else LargeWord.andb (w, LargeWord.- (LargeWord.<< (0w1, bits), 0w1))
  val () = eqL (lab "update/element-1", 
                List.tabulate (3 * bytes, fn j =>
                  if j < bytes orelse j >= 2 * bytes then 0
                  else let val k = if big then 2 * bytes - 1 - j else j - bytes   (* k-th least significant byte *)
                       in Word8.toInt (Word8.fromLarge (LargeWord.>> (w, Word.fromInt (8 * k)))) end),
                fn () => let val a = Word8Array.array (3 * bytes, Word8.fromInt 0)
                         in P.update (a, 1, w); bytesOf a end)
  val () = eqW (lab "update/read-back", low,
                fn () => let val a = Word8Array.array (bytes, Word8.fromInt 0)
                         in P.update (a, 0, w); P.subArr (a, 0) end)
  val () = T.raises (lab "update/Subscript-negative", isSubscript,
                     fn () => P.update (Word8Array.array (bytes, Word8.fromInt 0), ~1, w))
  val () = T.raises (lab "update/Subscript-past-the-end", isSubscript,
                     fn () => P.update (Word8Array.array (2 * bytes - 1, Word8.fromInt 0), 1, w))
  (* the largest int, where bytesPerElem * (i + 1) overflows (Poly/ML's int
     has no largest); in a ref, since Poly/ML 5.7.1 folds a constant index and
     raises Overflow while it compiles the test *)
  val largestRef = ref (getOpt (Int.maxInt, 1073741823))
  fun largest () = !largestRef
  val () = T.raises (lab "subVec/Subscript-maxInt", isSubscript, fn () => P.subVec (vec small, largest ()))
  val () = T.raises (lab "subVecX/Subscript-maxInt", isSubscript, fn () => P.subVecX (vec small, largest ()))
  val () = T.raises (lab "subArr/Subscript-maxInt", isSubscript, fn () => P.subArr (arr small, largest ()))
  val () = T.raises (lab "subArrX/Subscript-maxInt", isSubscript, fn () => P.subArrX (arr small, largest ()))
  val () = T.raises (lab "update/Subscript-maxInt", isSubscript,
                     fn () => P.update (Word8Array.array (2 * bytes, Word8.fromInt 0), largest (), w))
end

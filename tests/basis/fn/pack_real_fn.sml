(* Checks of a structure with signature PACK_REAL for 64-bit reals (IEEE 754
   binary64), after https://smlfamily.github.io/Basis/pack-float.html.

     structure R = TestPackRealFn (structure P = PackRealBig val name = "PackRealBig" val big = true)

   The expected bytes are the encodings of binary64, most significant first
   when big. *)
signature TEST_PACK_REAL =
sig
  val bytesPerElem : int
  val isBigEndian : bool
  val toBytes : real -> Word8Vector.vector
  val fromBytes : Word8Vector.vector -> real
  val subVec : Word8Vector.vector * int -> real
  val subArr : Word8Array.array * int -> real
  val update : Word8Array.array * int * real -> unit
end

functor TestPackRealFn (structure P : TEST_PACK_REAL val name : string val big : bool) =
struct
  fun lab s = name ^ "." ^ s
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqL = T.eq (T.list T.int)
  val isSubscript = fn Subscript => true | _ => false
  (* the same real, with the sign of a zero *)
  fun same (a, b) = (Real.isNan a andalso Real.isNan b)
                    orelse (Real.== (a, b) andalso Real.signBit a = Real.signBit b)
  fun check (label, expected, f) = T.check (label, fn () => same (expected, f ()))

  (* binary64 encodings, most significant byte first *)
  val encodings =
    [("one", 1.0, [0x3F, 0xF0, 0, 0, 0, 0, 0, 0]),
     ("half", 0.5, [0x3F, 0xE0, 0, 0, 0, 0, 0, 0]),
     ("minus-two", ~2.0, [0xC0, 0, 0, 0, 0, 0, 0, 0]),
     ("zero", 0.0, [0, 0, 0, 0, 0, 0, 0, 0]),
     ("negative-zero", ~0.0, [0x80, 0, 0, 0, 0, 0, 0, 0]),
     ("posInf", Real.posInf, [0x7F, 0xF0, 0, 0, 0, 0, 0, 0]),
     ("negInf", Real.negInf, [0xFF, 0xF0, 0, 0, 0, 0, 0, 0]),
     ("maxFinite", Real.maxFinite, [0x7F, 0xEF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]),
     ("minPos", Real.minPos, [0, 0, 0, 0, 0, 0, 0, 1]),
     ("minNormalPos", Real.minNormalPos, [0, 0x10, 0, 0, 0, 0, 0, 0])]
  fun ordered bytes = if big then bytes else List.rev bytes
  fun toInts v = List.tabulate (Word8Vector.length v, fn i => Word8.toInt (Word8Vector.sub (v, i)))
  fun vecOf l = Word8Vector.fromList (List.map Word8.fromInt l)
  fun arrOf l = Word8Array.fromList (List.map Word8.fromInt l)

  val () = eqI (lab "bytesPerElem/eight", 8, fn () => P.bytesPerElem)
  val () = eqB (lab "isBigEndian/value", big, fn () => P.isBigEndian)

  val () = List.app (fn (what, r, bytes) =>
    (eqL (lab "toBytes/" ^ what, ordered bytes, fn () => toInts (P.toBytes r));
     check (lab "fromBytes/" ^ what, r, fn () => P.fromBytes (vecOf (ordered bytes)))))
    encodings
  val () = T.check (lab "toBytes/nan-exponent", fn () =>
    let val b = toInts (P.toBytes (0.0 / 0.0))
        val (b0, b1) = if big then (List.nth (b, 0), List.nth (b, 1)) else (List.nth (b, 7), List.nth (b, 6))
    in b0 mod 128 = 0x7F andalso b1 >= 0xF0 andalso List.exists (fn x => x <> 0) (List.map (fn x => x) b) end)
  val () = T.check (lab "fromBytes/nan", fn () => Real.isNan (P.fromBytes (P.toBytes (0.0 / 0.0))))
  (* "otherwise the first bytesPerElem bytes are used" *)
  val () = check (lab "fromBytes/longer-uses-the-first", 1.0,
                  fn () => P.fromBytes (vecOf (ordered [0x3F, 0xF0, 0, 0, 0, 0, 0, 0] @ [0x40, 0])))
  val () = T.raises (lab "fromBytes/Subscript-short", isSubscript, fn () => P.fromBytes (vecOf [0x3F, 0xF0, 0, 0, 0, 0, 0]))
  val () = T.check (lab "fromBytes/inverts-toBytes", fn () =>
    List.all (fn r => same (r, P.fromBytes (P.toBytes r)))
             [0.1, ~3.25, 1.0E300, ~1.0E~300, 123456789.0, Real.minPos * 3.0])

  (* element 1 of a sequence of three *)
  val three = ordered [0x40, 0, 0, 0, 0, 0, 0, 0] @ ordered [0x3F, 0xF0, 0, 0, 0, 0, 0, 0] @ ordered [0xC0, 0x08, 0, 0, 0, 0, 0, 0]
  val () = check (lab "subVec/element-1", 1.0, fn () => P.subVec (vecOf three, 1))
  val () = check (lab "subVec/element-2", ~3.0, fn () => P.subVec (vecOf three, 2))
  val () = T.raises (lab "subVec/Subscript-negative", isSubscript, fn () => P.subVec (vecOf three, ~1))
  val () = T.raises (lab "subVec/Subscript-past-the-end", isSubscript, fn () => P.subVec (vecOf three, 3))
  val () = check (lab "subArr/element-0", 2.0, fn () => P.subArr (arrOf three, 0))
  val () = T.raises (lab "subArr/Subscript-negative", isSubscript, fn () => P.subArr (arrOf three, ~1))
  val () = T.raises (lab "subArr/Subscript-past-the-end", isSubscript, fn () => P.subArr (arrOf three, 3))
  (* "stores r into the bytes bytesPerElem*i through bytesPerElem*(i+1)-1" *)
  val () = eqL (lab "update/element-1", List.tabulate (8, fn _ => 0) @ ordered [0x3F, 0xE0, 0, 0, 0, 0, 0, 0] @ List.tabulate (8, fn _ => 0),
                fn () => let val a = Word8Array.array (24, Word8.fromInt 0)
                         in P.update (a, 1, 0.5); List.tabulate (24, fn i => Word8.toInt (Word8Array.sub (a, i))) end)
  val () = T.raises (lab "update/Subscript-negative", isSubscript, fn () => P.update (Word8Array.array (8, Word8.fromInt 0), ~1, 1.0))
  val () = T.raises (lab "update/Subscript-past-the-end", isSubscript, fn () => P.update (Word8Array.array (15, Word8.fromInt 0), 1, 1.0))
  (* the largest int, where bytesPerElem * (i + 1) overflows (Poly/ML's int
     has no largest); in a ref, since Poly/ML 5.7.1 folds a constant index and
     raises Overflow while it compiles the test *)
  val largestRef = ref (getOpt (Int.maxInt, 1073741823))
  fun largest () = !largestRef
  val () = T.raises (lab "subVec/Subscript-maxInt", isSubscript, fn () => P.subVec (vecOf three, largest ()))
  val () = T.raises (lab "subArr/Subscript-maxInt", isSubscript, fn () => P.subArr (arrOf three, largest ()))
  val () = T.raises (lab "update/Subscript-maxInt", isSubscript, fn () => P.update (Word8Array.array (16, Word8.fromInt 0), largest (), 1.0))
end

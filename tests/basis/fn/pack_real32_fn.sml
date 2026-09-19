(* Checks of a structure with signature PACK_REAL for Real32 (IEEE 754
   binary32), after https://smlfamily.github.io/Basis/pack-float.html.

     structure R = TestPackReal32Fn (structure P = PackReal32Big val name = "PackReal32Big" val big = true)

   The expected bytes are the encodings of binary32, most significant first
   when big. *)
signature TEST_PACK_REAL32 =
sig
  val bytesPerElem : int
  val isBigEndian : bool
  val toBytes : Real32.real -> Word8Vector.vector
  val fromBytes : Word8Vector.vector -> Real32.real
  val subVec : Word8Vector.vector * int -> Real32.real
  val subArr : Word8Array.array * int -> Real32.real
  val update : Word8Array.array * int * Real32.real -> unit
end

functor TestPackReal32Fn (structure P : TEST_PACK_REAL32 val name : string val big : bool) =
struct
  fun lab s = name ^ "." ^ s
  val eqI = T.eq T.int
  val eqB = T.eq T.bool
  val eqL = T.eq (T.list T.int)
  val isSubscript = fn Subscript => true | _ => false
  fun r x = Real32.fromLarge IEEEReal.TO_NEAREST x
  (* the same value, with the sign of a zero *)
  fun same (a, b) = (Real32.isNan a andalso Real32.isNan b)
                    orelse (Real32.== (a, b) andalso Real32.signBit a = Real32.signBit b)
  fun check (label, expected, f) = T.check (label, fn () => same (expected, f ()))
  val nan = Real32.- (Real32.posInf, Real32.posInf)

  (* binary32 encodings, most significant byte first *)
  val encodings =
    [("one", r 1.0, [0x3F, 0x80, 0, 0]),
     ("half", r 0.5, [0x3F, 0, 0, 0]),
     ("minus-two", r ~2.0, [0xC0, 0, 0, 0]),
     ("tenth", r 0.1, [0x3D, 0xCC, 0xCC, 0xCD]),
     ("zero", r 0.0, [0, 0, 0, 0]),
     ("negative-zero", r ~0.0, [0x80, 0, 0, 0]),
     ("posInf", Real32.posInf, [0x7F, 0x80, 0, 0]),
     ("negInf", Real32.negInf, [0xFF, 0x80, 0, 0]),
     ("maxFinite", Real32.maxFinite, [0x7F, 0x7F, 0xFF, 0xFF]),
     ("minPos", Real32.minPos, [0, 0, 0, 1]),
     ("subnormal", Real32.* (Real32.minPos, r 1000.0), [0, 0, 0x03, 0xE8]),
     ("minNormalPos", Real32.minNormalPos, [0, 0x80, 0, 0])]
  fun ordered bytes = if big then bytes else List.rev bytes
  fun toInts v = List.tabulate (Word8Vector.length v, fn i => Word8.toInt (Word8Vector.sub (v, i)))
  fun vecOf l = Word8Vector.fromList (List.map Word8.fromInt l)
  fun arrOf l = Word8Array.fromList (List.map Word8.fromInt l)

  val () = eqI (lab "bytesPerElem/four", 4, fn () => P.bytesPerElem)
  val () = eqB (lab "isBigEndian/value", big, fn () => P.isBigEndian)

  val () = List.app (fn (what, x, bytes) =>
    (eqL (lab "toBytes/" ^ what, ordered bytes, fn () => toInts (P.toBytes x));
     check (lab "fromBytes/" ^ what, x, fn () => P.fromBytes (vecOf (ordered bytes)))))
    encodings
  val () = T.check (lab "toBytes/nan-exponent", fn () =>
    let val b = toInts (P.toBytes nan)
        val (b0, b1) = if big then (List.nth (b, 0), List.nth (b, 1)) else (List.nth (b, 3), List.nth (b, 2))
    in b0 mod 128 = 0x7F andalso b1 >= 0x80 andalso (b1 > 0x80 orelse List.exists (fn x => x <> 0) (List.take (ordered b, 2))) end)
  val () = T.check (lab "fromBytes/nan", fn () => Real32.isNan (P.fromBytes (P.toBytes nan)))
  (* "otherwise the first bytesPerElem bytes are used" *)
  val () = check (lab "fromBytes/longer-uses-the-first", r 1.0,
                  fn () => P.fromBytes (vecOf (ordered [0x3F, 0x80, 0, 0] @ [0x40, 0])))
  val () = T.raises (lab "fromBytes/Subscript-short", isSubscript, fn () => P.fromBytes (vecOf [0x3F, 0x80, 0]))
  val () = T.check (lab "fromBytes/inverts-toBytes", fn () =>
    List.all (fn x => same (x, P.fromBytes (P.toBytes x)))
             [r 0.1, r ~3.25, r 1.0E30, r ~1.0E~30, r 123456789.0, r 1.0E~40, Real32.nextAfter (Real32.minNormalPos, r 0.0)])

  (* element 1 of a sequence of three *)
  val three = ordered [0x40, 0, 0, 0] @ ordered [0x3F, 0x80, 0, 0] @ ordered [0xC0, 0x40, 0, 0]
  val () = check (lab "subVec/element-1", r 1.0, fn () => P.subVec (vecOf three, 1))
  val () = check (lab "subVec/element-2", r ~3.0, fn () => P.subVec (vecOf three, 2))
  val () = T.raises (lab "subVec/Subscript-negative", isSubscript, fn () => P.subVec (vecOf three, ~1))
  val () = T.raises (lab "subVec/Subscript-past-the-end", isSubscript, fn () => P.subVec (vecOf three, 3))
  val () = check (lab "subArr/element-0", r 2.0, fn () => P.subArr (arrOf three, 0))
  val () = T.raises (lab "subArr/Subscript-negative", isSubscript, fn () => P.subArr (arrOf three, ~1))
  val () = T.raises (lab "subArr/Subscript-past-the-end", isSubscript, fn () => P.subArr (arrOf three, 3))
  (* "stores r into the bytes bytesPerElem*i through bytesPerElem*(i+1)-1" *)
  val () = eqL (lab "update/element-1", [0, 0, 0, 0] @ ordered [0x3F, 0, 0, 0] @ [0, 0, 0, 0],
                fn () => let val a = Word8Array.array (12, Word8.fromInt 0)
                         in P.update (a, 1, r 0.5); List.tabulate (12, fn i => Word8.toInt (Word8Array.sub (a, i))) end)
  val () = T.raises (lab "update/Subscript-negative", isSubscript, fn () => P.update (Word8Array.array (4, Word8.fromInt 0), ~1, r 1.0))
  val () = T.raises (lab "update/Subscript-past-the-end", isSubscript, fn () => P.update (Word8Array.array (7, Word8.fromInt 0), 1, r 1.0))
  (* the largest int, where bytesPerElem * (i + 1) overflows (Poly/ML's int
     has no largest); in a ref, since Poly/ML 5.7.1 folds a constant index and
     raises Overflow while it compiles the test *)
  val largestRef = ref (getOpt (Int.maxInt, 1073741823))
  fun largest () = !largestRef
  val () = T.raises (lab "subVec/Subscript-maxInt", isSubscript, fn () => P.subVec (vecOf three, largest ()))
  val () = T.raises (lab "subArr/Subscript-maxInt", isSubscript, fn () => P.subArr (arrOf three, largest ()))
  val () = T.raises (lab "update/Subscript-maxInt", isSubscript, fn () => P.update (Word8Array.array (8, Word8.fromInt 0), largest (), r 1.0))
end

(* The primitives of MLton's Basis Library (its _prim, _import and _symbol
   extensions, which tests/basis/xc2/mlton/rewrite.awk turns into XC2Prim.N,
   XC2FFI.N and XC2Symbol.N), made of Rune's library. Compiled after
   prologue.sml; the generated stubs.sml then gives every primitive this
   file and the generated prims.sml do not implement a value that raises
   XC2.Unimplemented.

   A primitive of MLton has one name for every type it is used at
   (Word8_add adds an Int8.int and a Word8.word alike): the generator gives
   such a name its type (Word8_add__int_x_int_to_int), and prims.sml makes it
   of the structures below, one for each of MLton's integer types. *)

(* An index or a size of MLton's (SeqIndex.int, C_Ptrdiff.t, ...), an
   Int64.int, as Rune's int: one that Rune's int cannot hold is out of
   range, as an array of Rune's says. *)
structure XC2Index =
struct
  fun index (i : Int64.int) = Int64.toInt i handle Overflow => raise Subscript
  fun size (n : Int64.int) = Int64.toInt n handle Overflow => raise Size
end

(* ---- MLton's string types, Rune's string and WideString.string, which
   MLton's library takes for vectors of their characters ---- *)
functor XC2StringOps (type char
                      eqtype string
                      val size : string -> int
                      val sub : string * int -> char
                      val tabulate : int * (int -> char) -> string) =
struct
  (* an index, MLton's SeqIndex.int, is an Int64.int *)
  fun length s = Int64.fromInt (size s)
  fun subUnsafe (s, i) = sub (s, XC2Index.index i)
  fun fromVector (v : char vector) : string =
    tabulate (Vector.length v, fn i => Vector.sub (v, i))
  fun toVector (s : string) : char vector =
    Vector.tabulate (size s, fn i => sub (s, i))
  fun fromArray (a : char XC2.array) : string =
    tabulate (XC2.Array.length a, fn i => XC2.Array.sub (a, i))
  (* copyUnsafe (dst, di, src, si, len): src[si, si + len) to dst[di, ...) *)
  fun copyUnsafe (dst : char XC2.array, di, src : string, si, len) =
    let val (di, si, len) = (XC2Index.index di, XC2Index.index si, XC2Index.index len)
        fun loop k = if k >= len then () else (XC2.Array.update (dst, di + k, sub (src, si + k)); loop (k + 1))
    in loop 0 end
end
structure XC2String8 = XC2StringOps (type char = char type string = string
                                     val size = String.size val sub = String.sub
                                     val tabulate = CharVector.tabulate)
structure XC2String32 = XC2StringOps (type char = WideChar.char type string = WideString.string
                                      val size = WideString.size val sub = WideString.sub
                                      val tabulate = WideCharVector.tabulate)

(* ---- MLton's integer types: their bits ----
   The library is built for a 64-bit int and word (gen.sh), and the
   programs are compiled with --default-type=int64 and word64: MLton's
   int64 and word64 are Rune's Int64.int and Word64.word, and the bits of
   any of its integer types are kept in a Word64.word. *)

(* One of MLton's integer or character types of WIDTH bits, kept in a type
   of Rune's: the operations on it are those on its bits. *)
signature XC2_FIXED =
sig
  type t
  val width : int
  (* the WIDTH bits of x, zero-extended *)
  val bits : t -> Word64.word
  (* the WIDTH bits of x, sign-extended *)
  val sbits : t -> Word64.word
  (* the value of the low WIDTH bits of w *)
  val fromBits : Word64.word -> t
end

structure XC2Bits =
struct
  val toInt64 = _prim "word64_to_int64" : Word64.word -> Int64.int
  val fromInt64 = _prim "word64_from_int64" : Int64.int -> Word64.word
  fun mask width : Word64.word =
    if width >= 64 then Word64.notb 0w0 else Word64.<< (0w1, Word.fromInt width) - 0w1
  fun low (width, w) = Word64.andb (w, mask width)
  (* w, its low WIDTH bits, sign-extended *)
  fun sext (width, w) =
    if width >= 64 then w
    else
      let val w = low (width, w)
      in if Word64.andb (w, Word64.<< (0w1, Word.fromInt (width - 1))) = 0w0 then w
         else Word64.orb (w, Word64.notb (mask width))
      end
end

(* an IntK of Rune's, holding the values of WIDTH <= K bits *)
functor XC2FixedInt (type int
                     val width : Int.int
                     val toInt64 : int -> Int64.int
                     val fromInt64 : Int64.int -> int) : XC2_FIXED =
struct
  type t = int
  val width = width
  fun sbits x = XC2Bits.fromInt64 (toInt64 x)
  fun bits x = XC2Bits.low (width, sbits x)
  fun fromBits w = fromInt64 (XC2Bits.toInt64 (XC2Bits.sext (width, w)))
end

(* a WordK of Rune's, holding the values of WIDTH <= K bits *)
functor XC2FixedWord (type word
                      val width : Int.int
                      val toLarge : word -> Word64.word
                      val fromLarge : Word64.word -> word) : XC2_FIXED =
struct
  type t = word
  val width = width
  fun bits x = toLarge x
  fun sbits x = XC2Bits.sext (width, bits x)
  fun fromBits w = fromLarge (XC2Bits.low (width, w))
end

(* WideChar.char, holding the values of WIDTH bits (MLton's char16 and char32) *)
functor XC2FixedWide (val width : int) : XC2_FIXED =
struct
  type t = WideChar.char
  val width = width
  fun bits c = Word64.fromInt (WideChar.ord c)
  fun sbits c = XC2Bits.sext (width, bits c)
  fun fromBits w = WideChar.chr (Word64.toInt (XC2Bits.low (width, w)))
end

structure XC2Fixed =
struct
  structure I8 = XC2FixedInt (type int = Int8.int val width = 8
                              val toInt64 = Int64.fromInt o Int8.toInt val fromInt64 = Int8.fromInt o Int64.toInt)
  structure I16 = XC2FixedInt (type int = Int16.int val width = 16
                               val toInt64 = Int64.fromInt o Int16.toInt val fromInt64 = Int16.fromInt o Int64.toInt)
  structure I32 = XC2FixedInt (type int = Int32.int val width = 32
                               val toInt64 = Int64.fromInt o Int32.toInt val fromInt64 = Int32.fromInt o Int64.toInt)
  structure I64 = XC2FixedInt (type int = Int64.int val width = 64 val toInt64 = fn x => x val fromInt64 = fn x => x)
  structure W8 = XC2FixedWord (type word = Word8.word val width = 8 val toLarge = Word8.toLarge val fromLarge = Word8.fromLarge)
  structure W16 = XC2FixedWord (type word = Word16.word val width = 16 val toLarge = Word16.toLarge val fromLarge = Word16.fromLarge)
  structure W32 = XC2FixedWord (type word = Word32.word val width = 32 val toLarge = Word32.toLarge val fromLarge = Word32.fromLarge)
  structure W64 = XC2FixedWord (type word = Word64.word val width = 64 val toLarge = fn x => x val fromLarge = fn x => x)
  structure C8 : XC2_FIXED =
  struct
    type t = char
    val width = 8
    fun bits c = Word64.fromInt (Char.ord c)
    fun sbits c = XC2Bits.sext (8, bits c)
    fun fromBits w = Char.chr (Word64.toInt (XC2Bits.low (8, w)))
  end
  structure C16 = XC2FixedWide (val width = 16)
  structure C32 = XC2FixedWide (val width = 32)
end

(* ---- MLton's integer primitives, on the bits ---- *)

functor XC2FixedOps (X : XC2_FIXED) =
struct
  open X
  (* the signed value of x *)
  fun sval x = XC2Bits.toInt64 (sbits x)
  (* whether the integer r fits in WIDTH bits, signed *)
  fun fits r = XC2Bits.sext (width, XC2Bits.fromInt64 r) = XC2Bits.fromInt64 r
  fun shift (n : Word32.word) = Word.fromLarge (Word32.toLarge n)

  fun add (a, b) = fromBits (bits a + bits b)
  fun sub (a, b) = fromBits (bits a - bits b)
  fun neg a = fromBits (0w0 - bits a)
  fun mul (a, b) = fromBits (bits a * bits b)
  fun andb (a, b) = fromBits (Word64.andb (bits a, bits b))
  fun orb (a, b) = fromBits (Word64.orb (bits a, bits b))
  fun xorb (a, b) = fromBits (Word64.xorb (bits a, bits b))
  fun notb a = fromBits (Word64.notb (bits a))
  fun lshift (a, n) = fromBits (Word64.<< (bits a, shift n))
  fun rshiftU (a, n) = fromBits (Word64.>> (bits a, shift n))
  fun rshiftS (a, n) = fromBits (Word64.~>> (sbits a, shift n))
  fun rotl (a, k) =
    if k = 0 then a
    else fromBits (Word64.orb (Word64.<< (bits a, Word.fromInt k),
                               Word64.>> (bits a, Word.fromInt (width - k))))
  fun rol (a, n) = rotl (a, Word.toInt (shift n) mod width)
  fun ror (a, n) = rotl (a, (width - Word.toInt (shift n) mod width) mod width)
  fun ltS (a, b) = Int64.< (sval a, sval b)
  fun ltU (a, b) = Word64.< (bits a, bits b)
  fun quotS (a, b) = fromBits (XC2Bits.fromInt64 (Int64.quot (sval a, sval b)))
  fun remS (a, b) = fromBits (XC2Bits.fromInt64 (Int64.rem (sval a, sval b)))
  fun quotU (a, b) = fromBits (Word64.div (bits a, bits b))
  fun remU (a, b) = fromBits (Word64.mod (bits a, bits b))
  (* whether the signed operation overflows: in 64 bits it raises Overflow *)
  fun addCheckP (a, b) = not (fits (Int64.+ (sval a, sval b))) handle Overflow => true
  fun subCheckP (a, b) = not (fits (Int64.- (sval a, sval b))) handle Overflow => true
  fun mulCheckP (a, b) = not (fits (Int64.* (sval a, sval b))) handle Overflow => true
  fun negCheckP a = not (fits (Int64.~ (sval a))) handle Overflow => true
  (* conversions to and from the reals: a real to an integer truncates, as
     C's conversion does (MLton rounds it before, in the mode it wants) *)
  fun toReal64S x = Real.fromLargeInt (Int64.toLarge (sval x))
  fun toReal64U x = Real.fromLargeInt (Word64.toLargeInt (bits x))
  fun toReal32S x = Real32.fromLargeInt (Int64.toLarge (sval x))
  fun toReal32U x = Real32.fromLargeInt (Word64.toLargeInt (bits x))
  fun fromReal64 r = fromBits (Word64.fromLargeInt (Real.toLargeInt IEEEReal.TO_ZERO r))
  fun fromReal32 r = fromBits (Word64.fromLargeInt (Real32.toLargeInt IEEEReal.TO_ZERO r))
end

(* ---- MLton's real primitives ---- *)

functor XC2RealOps (type real
                    val + : real * real -> real
                    val - : real * real -> real
                    val * : real * real -> real
                    val / : real * real -> real
                    val ~ : real -> real
                    val abs : real -> real
                    val == : real * real -> bool
                    val ?= : real * real -> bool
                    val <= : real * real -> bool
                    val < : real * real -> bool
                    val *+ : real * real * real -> real
                    val *- : real * real * real -> real
                    val fromManExp : {man : real, exp : int} -> real
                    val realRound : real -> real
                    val realFloor : real -> real
                    val realCeil : real -> real
                    val realTrunc : real -> real
                    val acos : real -> real
                    val asin : real -> real
                    val atan : real -> real
                    val atan2 : real * real -> real
                    val cos : real -> real
                    val exp : real -> real
                    val ln : real -> real
                    val log10 : real -> real
                    val sin : real -> real
                    val sqrt : real -> real
                    val tan : real -> real) =
struct
  val add = op + val sub = op - val mul = op * val op div = op / val neg = ~
  val abs = abs val equal = op == val qequal = op ?= val le = op <= val lt = op <
  val muladd = op *+ val mulsub = op *-
  fun ldexp (r, e : Int32.int) = fromManExp {man = r, exp = Int32.toInt e}
  (* C's rint: to an integer in the current rounding mode *)
  fun round r =
    case IEEEReal.getRoundingMode () of
      IEEEReal.TO_NEAREST => realRound r
    | IEEEReal.TO_NEGINF => realFloor r
    | IEEEReal.TO_POSINF => realCeil r
    | IEEEReal.TO_ZERO => realTrunc r
  val Math_acos = acos val Math_asin = asin val Math_atan = atan
  val Math_atan2 = atan2 val Math_cos = cos val Math_exp = exp
  val Math_ln = ln val Math_log10 = log10 val Math_sin = sin
  val Math_sqrt = sqrt val Math_tan = tan
end

structure XC2Real64 =
struct
  structure O = XC2RealOps (open Real open Math)
  open O
  val realToBits = _prim "real_to_bits" : real -> Word64.word
  val realFromBits = _prim "real_from_bits" : Word64.word -> real
  val castToWord64 = realToBits
  val castFromWord64 = realFromBits
  fun rndToReal32 r = Real32.fromLarge (IEEEReal.getRoundingMode ()) r
  fun rndToReal64 (r : real) = r
end

structure XC2Real32 =
struct
  structure O = XC2RealOps (open Real32 open Real32.Math)
  open O
  fun castToWord32 r =
    let val v = PackReal32Little.toBytes r
        fun b i = Word32.fromLarge (Word8.toLarge (Word8Vector.sub (v, i)))
    in Word32.orb (Word32.orb (b 0, Word32.<< (b 1, 0w8)),
                   Word32.orb (Word32.<< (b 2, 0w16), Word32.<< (b 3, 0w24)))
    end
  fun castFromWord32 w =
    let fun b k = Word8.fromLarge (Word32.toLarge (Word32.>> (w, k)))
    in PackReal32Little.fromBytes (Word8Vector.fromList [b 0w0, b 0w8, b 0w16, b 0w24])
    end
  fun rndToReal32 (r : Real32.real) = r
  val rndToReal64 = Real32.toLarge
end

(* ---- C's memory ----
   What MLton's library reads through a C pointer: the strings and the
   arrays of strings that C functions return (CommandLine, the entries of
   the system databases, ...). A pointer, a Word64.word, is a block of bytes
   (its number, from 1, in the high 32 bits) and an offset in it (the low
   32); NULL is 0w0. The shim's C functions make the blocks. *)
structure XC2Mem =
struct
  val blocks : Word8Array.array list ref = ref []
  val count = ref 0
  (* the blocks, the newest first; block k is at position count - k *)
  fun block k = List.nth (!blocks, !count - k)
  fun alloc n : Word64.word =
    let val a = Word8Array.array (n, 0w0)
    in blocks := a :: !blocks; count := !count + 1;
       Word64.<< (Word64.fromInt (!count), 0w32)
    end
  fun locate (p : Word64.word, byteOffset : int) =
    (block (Word64.toInt (Word64.>> (p, 0w32))),
     Word64.toInt (Word64.andb (p, 0wxFFFFFFFF)) + byteOffset)
  fun getByte (p, i) = let val (a, j) = locate (p, i) in Word8Array.sub (a, j) end
  fun setByte (p, i, b) = let val (a, j) = locate (p, i) in Word8Array.update (a, j, b) end
  (* the n bytes at p + i, little-endian, as a Word64.word *)
  fun get (p, i, n) : Word64.word =
    let fun loop (k, w) = if k < 0 then w
                          else loop (k - 1, Word64.orb (Word64.<< (w, 0w8), Word8.toLarge (getByte (p, i + k))))
    in loop (n - 1, 0w0) end
  fun set (p, i, n, w : Word64.word) =
    let fun loop k = if k >= n then ()
                     else (setByte (p, i + k, Word8.fromLarge (Word64.>> (w, Word.fromInt (8 * k)))); loop (k + 1))
    in loop 0 end
  (* a C string: the bytes of s and a NUL *)
  fun string s =
    let val p = alloc (size s + 1)
    in CharVector.appi (fn (i, c) => setByte (p, i, Word8.fromInt (Char.ord c))) s; p end
  (* a NULL-terminated array of C strings *)
  fun strings l =
    let val p = alloc (8 * (length l + 1))
    in List.foldl (fn (s, i) => (set (p, 8 * i, 8, string s); i + 1)) 0 l; p end
  (* the C string at p *)
  fun toString p =
    let fun len i = if getByte (p, i) = 0w0 then i else len (i + 1)
    in CharVector.tabulate (len 0, fn i => Char.chr (Word8.toInt (getByte (p, i)))) end
end

(* ---- MLton's IntInf.int, Rune's ----
   MLton's library takes an IntInf.int apart: a small one (of 63 bits) is
   the tagged word 2i + 1 (IntInf_toWord); a big one a vector of limbs of 64
   bits, the sign (0 or 1) first and then the magnitude, least significant
   limb first (IntInf_toVector). *)
structure XC2IntInf =
struct
  val smallMin = IntInf.~ (IntInf.pow (2, 62))
  val smallMax = IntInf.- (IntInf.pow (2, 62), 1)
  fun isSmall i = IntInf.>= (i, smallMin) andalso IntInf.<= (i, smallMax)
  fun toWord i : Word64.word =
    if isSmall i then Word64.orb (Word64.<< (Word64.fromLargeInt i, 0w1), 0w1) else 0w0
  fun fromWord (w : Word64.word) = Word64.toLargeIntX (Word64.~>> (w, 0w1))
  val base = IntInf.pow (2, 64)
  val mask = IntInf.- (base, 1)
  (* the number of limbs of the magnitude, and the sign, without the vector *)
  fun numLimbs i : Int64.int = Int64.fromInt (if i = 0 then 1 else IntInf.log2 (IntInf.abs i) div 64 + 1)
  fun isNeg i = IntInf.< (i, 0)
  fun toVector i =
    let fun limbs m = if m = 0 then [] else Word64.fromLargeInt (IntInf.andb (m, mask)) :: limbs (IntInf.~>> (m, 0w64))
    in Vector.fromList ((if IntInf.< (i, 0) then 0w1 else 0w0) :: limbs (IntInf.abs i)) end
  fun fromVector (v : Word64.word vector) =
    let val m = Vector.foldri (fn (k, l, m) => if k = 0 then m else IntInf.orb (IntInf.<< (m, 0w64), Word64.toLargeInt l)) 0 v
    in if Vector.sub (v, 0) = 0w0 then m else IntInf.~ m end
  fun toString (i, base : Int32.int) =
    IntInf.fmt (case Int32.toInt base of 2 => StringCvt.BIN | 8 => StringCvt.OCT
                                       | 16 => StringCvt.HEX | _ => StringCvt.DEC) i
end

(* ---- the primitives of one type ---- *)
structure XC2PrimImpl =
struct
  structure A = XC2.Array
  (* an index, MLton's SeqIndex.int, Int64.int *)
  val ix = XC2Index.index
  val xi = Int64.fromInt
  fun Array_alloc n = A.alloc (XC2Index.size n)
  val Array_allocRaw = Array_alloc
  fun Array_toArray a = a
  fun Array_length a = xi (A.length a)
  fun Array_sub (a, i) = A.sub (a, ix i)
  fun Array_update (a, i, x) = A.update (a, ix i, x)
  val Array_toVector = A.toVector
  fun Array_uninit _ = ()
  fun Array_uninitIsNop _ = true
  (* as memmove *)
  fun Array_copyArray (dst, di, src, si, len) =
    let val (di, si, len) = (ix di, ix si, ix len)
    in
      if dst = src andalso di > si
        then let fun loop k = if k < 0 then () else (A.update (dst, di + k, A.sub (src, si + k)); loop (k - 1))
             in loop (len - 1) end
      else let fun loop k = if k >= len then () else (A.update (dst, di + k, A.sub (src, si + k)); loop (k + 1))
           in loop 0 end
    end
  fun Array_copyVector (dst, di, src, si, len) =
    let val (di, si, len) = (ix di, ix si, ix len)
        fun loop k = if k >= len then () else (A.update (dst, di + k, Vector.sub (src, si + k)); loop (k + 1))
    in loop 0 end
  fun Vector_length v = xi (Vector.length v)
  fun Vector_sub (v, i) = Vector.sub (v, ix i)
  fun Vector_vector () = Vector.fromList []
  val Ref_assign = op :=
  val Ref_deref = op !
  fun String_toWord8Vector s = Vector.tabulate (size s, fn i => Word8.fromInt (Char.ord (String.sub (s, i))))
  fun Word8Vector_toString v = CharVector.tabulate (Vector.length v, fn i => Char.chr (Word8.toInt (Vector.sub (v, i))))
  val Exn_name = exnName
  fun Exn_setExtendExtra _ = ()
  fun GC_collect () = ()
  fun GC_state () = 0w0 : Word64.word
  (* the last argument of IntInf's, the size of the result, a C_Size.t *)
  fun IntInf_add (a, b, _ : Word64.word) = IntInf.+ (a, b)
  fun IntInf_sub (a, b, _ : Word64.word) = IntInf.- (a, b)
  fun IntInf_mul (a, b, _ : Word64.word) = IntInf.* (a, b)
  fun IntInf_quot (a, b, _ : Word64.word) = IntInf.quot (a, b)
  fun IntInf_rem (a, b, _ : Word64.word) = IntInf.rem (a, b)
  fun IntInf_neg (a, _ : Word64.word) = IntInf.~ a
  fun IntInf_andb (a, b, _ : Word64.word) = IntInf.andb (a, b)
  fun IntInf_orb (a, b, _ : Word64.word) = IntInf.orb (a, b)
  fun IntInf_xorb (a, b, _ : Word64.word) = IntInf.xorb (a, b)
  fun IntInf_notb (a, _ : Word64.word) = IntInf.notb a
  fun IntInf_gcd (a, b, _ : Word64.word) =
    let fun gcd (a, b) = if b = 0 then a else gcd (b, IntInf.rem (a, b))
    in gcd (IntInf.abs a, IntInf.abs b) end
  fun IntInf_lshift (a, n : Word32.word, _ : Word64.word) = IntInf.<< (a, Word.fromLarge (Word32.toLarge n))
  fun IntInf_arshift (a, n : Word32.word, _ : Word64.word) = IntInf.~>> (a, Word.fromLarge (Word32.toLarge n))
  fun IntInf_compare (a, b) : Int32.int =
    case IntInf.compare (a, b) of LESS => ~1 | EQUAL => 0 | GREATER => 1
  fun IntInf_toString (i, base, _ : Word64.word) = XC2IntInf.toString (i, base)
  val IntInf_toVector = XC2IntInf.toVector
  val IntInf_toWord = XC2IntInf.toWord
  val WordVector_toIntInf = XC2IntInf.fromVector
  val Word_toIntInf = XC2IntInf.fromWord
  fun MLton_bug msg = raise Fail ("MLton bug: " ^ msg)
  val MLton_eq = _prim "ptr_eq" : 'a * 'a -> bool
  val MLton_equal__qqa_x_qqa_to_bool = op =
  val MLton_equal__qa_x_qa_to_bool = _prim "poly_eq" : 'a * 'a -> bool
  val halt = _prim "posix_exit" : int -> 'a
  fun MLton_halt (status : Int32.int) : unit = halt (Int32.toInt status)
  fun MLton_hash _ = 0w0 : Word32.word
  fun MLton_installSignalHandler () = ()
  fun MLton_share _ = ()
  fun MLton_touch _ = ()
  fun MLton_size _ = 0w0 : Word64.word
  (* MLton's atomic sections nest: a count, which atomicEnd checks *)
  val atomic = ref 0w0 : Word32.word ref
  fun Thread_atomicBegin () = atomic := !atomic + 0w1
  fun Thread_atomicEnd () = atomic := !atomic - 0w1
  fun Thread_atomicState () = !atomic
  (* MLton.Thread copies the running thread when it is loaded; switching
     threads is not made *)
  fun Thread_copyCurrent () = ()
  local
    val handler : (exn -> unit) ref = ref (fn e => raise e)
    val suffix : (unit -> unit) ref = ref (fn () => ())
  in
    fun TopLevel_getHandler () = !handler
    fun TopLevel_setHandler h = handler := h
    fun TopLevel_getSuffix () = !suffix
    fun TopLevel_setSuffix s = suffix := s
  end
  fun Weak_new x = ref (SOME x)
  fun Weak_get (ref (SOME x)) = x
    | Weak_get (ref NONE) = raise Fail "xc2: Weak.get"
  fun Weak_canGet (ref x) = Option.isSome x
  (* a pointer, MLton's cpointer and C_Pointer.t, is a Word64.word *)
  fun CPointer_add (p : Word64.word, d : Int64.int) = Word64.+ (p, XC2Bits.fromInt64 d)
  fun CPointer_sub (p : Word64.word, d : Int64.int) = Word64.- (p, XC2Bits.fromInt64 d)
  fun CPointer_diff (p : Word64.word, q : Word64.word) = XC2Bits.toInt64 (Word64.- (p, q))
  fun CPointer_fromWord (w : Word64.word) = w
  fun CPointer_toWord (p : Word64.word) = p
  fun CPointer_lt (p : Word64.word, q : Word64.word) = Word64.< (p, q)
  fun CPointer_getCPointer (p, i : Int64.int) = XC2Mem.get (p, 8 * XC2Index.index i, 8)
  fun CPointer_setCPointer (p, i : Int64.int, q) = XC2Mem.set (p, 8 * XC2Index.index i, 8, q)
end

(* ---- MLton's C functions (_import) and variables (_symbol) ----
   Made of the primitives of Rune's machine (XC2Sys, tests/basis/xc2/xc2.sml),
   which are C's functions with Rune's types: a call that fails returns ~1
   and leaves its error in sys_errno, which the shim keeps as C's errno. *)
(* C's errno, and the conventions of C's functions *)
structure XC2C =
struct
  val errno = ref 0
  (* r, a result of a call; its error when it is ~1 *)
  fun check (r : int) = (if r = ~1 then errno := XC2Sys.sysErrno () else (); r)
  fun ci r : Int32.int = Int32.fromInt (check r)
  (* the call failed with the error of the machine, or with e *)
  fun fail () = (errno := XC2Sys.sysErrno (); ~1)
  fun failWith e = (errno := e; ~1)
  (* a NullString8.t: the string without its NUL *)
  fun cstr s = if size s > 0 andalso String.sub (s, size s - 1) = #"\000" then String.substring (s, 0, size s - 1) else s
  (* an array of C strings, whose last element is the NULL at its end *)
  fun cstrs (a : string XC2.array) = List.tabulate (XC2.Array.length a - 1, fn i => cstr (XC2.Array.sub (a, i)))
  fun i32 (x : Int32.int) = Int32.toInt x
  fun w32 (x : Word32.word) = Word32.toInt x
  (* the chars of a[i, i + n) of an array of MLton's *)
  fun arrString (a : char XC2.array, i, n) = CharVector.tabulate (n, fn k => XC2.Array.sub (a, i + k))
  fun arrBytes (a : Word8.word XC2.array, i, n) = CharVector.tabulate (n, fn k => Char.chr (Word8.toInt (XC2.Array.sub (a, i + k))))
  fun vecString (v : char vector, i, n) = CharVector.tabulate (n, fn k => Vector.sub (v, i + k))
  fun vecBytes (v : Word8.word vector, i, n) = CharVector.tabulate (n, fn k => Char.chr (Word8.toInt (Vector.sub (v, i + k))))
  fun toArr (a : char XC2.array, i, s) = CharVector.appi (fn (k, c) => XC2.Array.update (a, i + k, c)) s
  fun toBytes (a : Word8.word XC2.array, i, s) = CharVector.appi (fn (k, c) => XC2.Array.update (a, i + k, Word8.fromInt (Char.ord c))) s
  (* a read of the machine: "" is the end of the file when errno is 0 *)
  fun read (fd, n, put) : int =
    let val s = XC2Sys.read (fd, n)
    in if s = "" andalso XC2Sys.sysErrno () <> 0 then fail ()
       else (put s; size s)
    end handle Size => failWith (XC2Sys.posixConst "EINVAL")
  fun write (fd, s) : int = check (XC2Sys.write (fd, s))
  (* a C_SSize.t, an Int64.int *)
  val ssize = Int64.fromInt
  (* the value of a constant of MLton's constants file *)
  fun const name =
    case List.find (fn (n, _) => n = name) XC2Consts.table of
      SOME (_, v) => v
    | NONE => raise Fail ("xc2: no constant " ^ name)
  (* the name, after PREFIX, of the constant PREFIX... whose value is v *)
  fun constName (prefix, v) =
    case List.find (fn (n, v') => v' = v andalso String.isPrefix prefix n) XC2Consts.table of
      SOME (n, _) => SOME (String.extract (n, size prefix, NONE))
    | NONE => NONE
end

structure XC2FFIImpl =
struct
  open XC2C

  (* ---- the process ---- *)
  fun Time_getTimeOfDay (sec : Int64.int ref, usec : Int64.int ref) : Int32.int =
    let val t = XC2Sys.timeNow ()
    in sec := Int64.fromInt (t div 1000000); usec := Int64.fromInt (t mod 1000000); 0 end
  fun Stdio_print s = ignore (XC2Sys.write (2, s))
  fun Stdio_printStderr s = ignore (XC2Sys.write (2, s))
  fun Stdio_printStdout s = ignore (XC2Sys.write (1, s))
  fun Posix_Error_getErrno () : Int32.int = Int32.fromInt (!errno)
  fun Posix_Error_clearErrno () = errno := 0
  fun Posix_Error_strError (e : Int32.int) = XC2Mem.string (XC2Sys.errorMsg (i32 e))
  fun Posix_Process_exit (status : Int32.int) : unit = XC2Sys.exit (i32 status)
  fun MLton_bug msg = raise Fail ("MLton bug: " ^ msg)
  fun GC_getSavedThread__GCState_t_to_preThread (_ : Word64.word) = ref ()
  fun GC_getSavedThread__GCState_t_to_thread (_ : Word64.word) = ref ()
  (* MLton's collector: its controls do nothing, its statistics are 0 *)
  fun GC_setAmOriginal (_ : Word64.word, _ : bool) = ()
  fun GC_getAmOriginal (_ : Word64.word) = true
  fun GC_setControlsMessages (_ : Word64.word, _ : bool) = ()
  fun GC_setControlsRusageMeasureGC (_ : Word64.word, _ : bool) = ()
  fun GC_setControlsSummary (_ : Word64.word, _ : bool) = ()
  fun GC_setHashConsDuringGC (_ : Word64.word, _ : bool) = ()
  fun GC_getCumulativeStatisticsBytesAllocated (_ : Word64.word) = 0w0 : Word64.word
  fun GC_getCumulativeStatisticsMaxBytesLive (_ : Word64.word) = 0w0 : Word64.word
  fun GC_getCumulativeStatisticsNumCopyingGCs (_ : Word64.word) = 0w0 : Word64.word
  fun GC_getCumulativeStatisticsNumMarkCompactGCs (_ : Word64.word) = 0w0 : Word64.word
  fun GC_getCumulativeStatisticsNumMinorGCs (_ : Word64.word) = 0w0 : Word64.word
  fun GC_getLastMajorStatisticsBytesLive (_ : Word64.word) = 0w0 : Word64.word
  fun GC_sizeAll (_ : Word64.word) = 0w0 : Word64.word
  fun GC_pack (_ : Word64.word) = ()
  fun GC_unpack (_ : Word64.word) = ()
  fun GC_getCurrentThread (_ : Word64.word) = ref ()
  fun GC_setSavedThread (_ : Word64.word, _ : unit ref) = ()
  fun GC_setSignalHandlerThread (_ : Word64.word, _ : unit ref) = ()
  fun GC_setCallFromCHandlerThread (_ : Word64.word, _ : unit ref) = ()
  fun GC_finishSignalHandler (_ : Word64.word) = ()
  fun GC_startSignalHandler (_ : Word64.word) = ()
  fun GC_numStackFrames (_ : Word64.word) = 0w0 : Word32.word
  fun GC_callStack (_ : Word64.word, _ : Word32.word XC2.array) = ()

  (* ---- the rounding mode: MLton's numbers are C's FE_ constants ---- *)
  fun IEEEReal_getRoundingMode () : Int32.int =
    Int32.fromInt (const (case IEEEReal.getRoundingMode () of
                            IEEEReal.TO_NEAREST => "IEEEReal_RoundingMode_FE_TONEAREST"
                          | IEEEReal.TO_NEGINF => "IEEEReal_RoundingMode_FE_DOWNWARD"
                          | IEEEReal.TO_POSINF => "IEEEReal_RoundingMode_FE_UPWARD"
                          | IEEEReal.TO_ZERO => "IEEEReal_RoundingMode_FE_TOWARDZERO"))
  fun IEEEReal_setRoundingMode (m : Int32.int) : Int32.int =
    let val m = i32 m
        fun is n = m = const ("IEEEReal_RoundingMode_FE_" ^ n)
    in if is "TONEAREST" then (IEEEReal.setRoundingMode IEEEReal.TO_NEAREST; 0)
       else if is "DOWNWARD" then (IEEEReal.setRoundingMode IEEEReal.TO_NEGINF; 0)
       else if is "UPWARD" then (IEEEReal.setRoundingMode IEEEReal.TO_POSINF; 0)
       else if is "TOWARDZERO" then (IEEEReal.setRoundingMode IEEEReal.TO_ZERO; 0)
       else ~1
    end

  (* ---- Posix.IO ---- *)
  fun Posix_IO_close fd = ci (XC2Sys.close (i32 fd))
  fun Posix_IO_dup fd = ci (XC2Sys.dup (i32 fd))
  fun Posix_IO_dup2 (fd, fd') = ci (XC2Sys.dup2 (i32 fd, i32 fd'))
  fun Posix_IO_fcntl2 (fd, cmd) = ci (XC2Sys.fcntl (i32 fd, i32 cmd, 0))
  fun Posix_IO_fcntl3 (fd, cmd, arg) = ci (XC2Sys.fcntl (i32 fd, i32 cmd, i32 arg))
  fun Posix_IO_fsync fd = ci (XC2Sys.fsync (i32 fd))
  fun Posix_IO_lseek (fd, off : Int64.int, whence) : Int64.int =
    Int64.fromInt (check (XC2Sys.lseek (i32 fd, Int64.toInt off, i32 whence)))
  fun Posix_IO_pipe (a : Int32.int XC2.array) : Int32.int =
    case XC2Sys.pipe () of
      [r, w] => (XC2.Array.update (a, 0, Int32.fromInt r); XC2.Array.update (a, 1, Int32.fromInt w); 0)
    | _ => Int32.fromInt (fail ())
  fun Posix_IO_readChar8 (fd, a, i, n : Word64.word) : Int64.int =
    ssize (read (i32 fd, Word64.toInt n, fn s => toArr (a, i32 i, s)))
  fun Posix_IO_readWord8 (fd, a, i, n : Word64.word) : Int64.int =
    ssize (read (i32 fd, Word64.toInt n, fn s => toBytes (a, i32 i, s)))
  fun Posix_IO_writeChar8Arr (fd, a, i, n : Word64.word) = ssize (write (i32 fd, arrString (a, i32 i, Word64.toInt n)))
  fun Posix_IO_writeChar8Vec (fd, v, i, n : Word64.word) = ssize (write (i32 fd, vecString (v, i32 i, Word64.toInt n)))
  fun Posix_IO_writeWord8Arr (fd, a, i, n : Word64.word) = ssize (write (i32 fd, arrBytes (a, i32 i, Word64.toInt n)))
  fun Posix_IO_writeWord8Vec (fd, v, i, n : Word64.word) = ssize (write (i32 fd, vecBytes (v, i32 i, Word64.toInt n)))
  fun Posix_IO_setbin (_ : Int32.int) = ()
  fun Posix_IO_settext (_ : Int32.int) = ()
  local
    (* the lock of the last Posix_IO_FLock_fcntl: type, whence, start, length, pid *)
    val flock = ref [0, 0, 0, 0, 0]
    fun get k = List.nth (!flock, k)
    fun set (k, v) = flock := List.tabulate (5, fn j => if j = k then v else get j)
  in
    fun Posix_IO_FLock_fcntl (fd, cmd) : Int32.int =
      case XC2Sys.lock (i32 fd, i32 cmd, get 0, get 1, get 2, get 3) of
        [] => Int32.fromInt (fail ())
      | l => (flock := l; 0)
    fun Posix_IO_FLock_getType () = Int16.fromInt (get 0)
    fun Posix_IO_FLock_getWhence () = Int16.fromInt (get 1)
    fun Posix_IO_FLock_getStart () = Int64.fromInt (get 2)
    fun Posix_IO_FLock_getLen () = Int64.fromInt (get 3)
    fun Posix_IO_FLock_getPId () = Int32.fromInt (get 4)
    fun Posix_IO_FLock_setType (t : Int16.int) = set (0, Int16.toInt t)
    fun Posix_IO_FLock_setWhence (w : Int16.int) = set (1, Int16.toInt w)
    fun Posix_IO_FLock_setStart (s : Int64.int) = set (2, Int64.toInt s)
    fun Posix_IO_FLock_setLen (l : Int64.int) = set (3, Int64.toInt l)
    fun Posix_IO_FLock_setPId (p : Int32.int) = set (4, Int32.toInt p)
  end

  (* ---- Posix.ProcEnv ---- *)
  fun Posix_ProcEnv_getpid () = Int32.fromInt (XC2Sys.getpid ())
  fun Posix_ProcEnv_getppid () = Int32.fromInt (XC2Sys.getppid ())
  fun Posix_ProcEnv_getuid () = Word32.fromInt (XC2Sys.getuid ())
  fun Posix_ProcEnv_geteuid () = Word32.fromInt (XC2Sys.geteuid ())
  fun Posix_ProcEnv_getgid () = Word32.fromInt (XC2Sys.getgid ())
  fun Posix_ProcEnv_getegid () = Word32.fromInt (XC2Sys.getegid ())
  fun Posix_ProcEnv_setuid u = ci (XC2Sys.setuid (w32 u))
  fun Posix_ProcEnv_setgid g = ci (XC2Sys.setgid (w32 g))
  fun Posix_ProcEnv_getgroupsN () = Int32.fromInt (length (XC2Sys.getgroups ()))
  fun Posix_ProcEnv_getgroups (n : Int32.int, a : Word32.word XC2.array) : Int32.int =
    let val gs = XC2Sys.getgroups ()
    in List.foldl (fn (g, k) => (XC2.Array.update (a, k, Word32.fromInt g); k + 1)) 0 gs;
       Int32.fromInt (length gs)
    end
  fun Posix_ProcEnv_setgroups _ = Int32.fromInt (failWith (XC2Sys.posixConst "EPERM"))
  fun Posix_ProcEnv_getlogin () =
    case XC2Sys.getlogin () of "" => (ignore (fail ()); 0w0) | s => XC2Mem.string s
  fun Posix_ProcEnv_getpgrp () = Int32.fromInt (XC2Sys.getpgrp ())
  fun Posix_ProcEnv_setsid () = ci (XC2Sys.setsid ())
  fun Posix_ProcEnv_setpgid (p, g) = ci (XC2Sys.setpgid (i32 p, i32 g))
  local
    val un = ref ["", "", "", "", ""]
    fun field k () = XC2Mem.string (List.nth (!un, k))
  in
    fun Posix_ProcEnv_uname () : Int32.int =
      case XC2Sys.uname () of l as [_, _, _, _, _] => (un := l; 0) | _ => Int32.fromInt (fail ())
    val Posix_ProcEnv_Uname_getSysName = field 0
    val Posix_ProcEnv_Uname_getNodeName = field 1
    val Posix_ProcEnv_Uname_getRelease = field 2
    val Posix_ProcEnv_Uname_getVersion = field 3
    val Posix_ProcEnv_Uname_getMachine = field 4
  end
  local
    (* the clock of times is CLK_TCK a second; the machine gives microseconds *)
    val tms = ref [0, 0, 0, 0, 0]
    fun ticks us = us * XC2Sys.sysconf "CLK_TCK" div 1000000
    fun field k () = Int64.fromInt (ticks (List.nth (!tms, k)))
  in
    fun Posix_ProcEnv_times () : Int64.int = (tms := XC2Sys.times (); Int64.fromInt (ticks (hd (!tms))))
    val Posix_ProcEnv_Times_getUTime = field 1
    val Posix_ProcEnv_Times_getSTime = field 2
    val Posix_ProcEnv_Times_getCUTime = field 3
    val Posix_ProcEnv_Times_getCSTime = field 4
  end
  fun Posix_ProcEnv_getenv name =
    case XC2Sys.getenv (cstr name) of SOME v => XC2Mem.string v | NONE => 0w0
  fun Posix_ProcEnv_setenv _ = Int32.fromInt (failWith (XC2Sys.posixConst "ENOSYS"))
  fun Posix_ProcEnv_ctermid () = XC2Mem.string (XC2Sys.ctermid ())
  fun Posix_ProcEnv_ttyname fd =
    case XC2Sys.ttyname (i32 fd) of "" => (ignore (fail ()); 0w0) | s => XC2Mem.string s
  fun Posix_ProcEnv_isatty fd = Int32.fromInt (XC2Sys.isatty (i32 fd))
  fun Posix_ProcEnv_sysconf (n : Int32.int) : Int64.int =
    Int64.fromInt (case constName ("Posix_ProcEnv_SC_", i32 n) of
                     SOME name => (case XC2Sys.sysconf name of ~1 => failWith (XC2Sys.posixConst "EINVAL") | v => v)
                   | NONE => failWith (XC2Sys.posixConst "EINVAL"))

  (* ---- Posix.FileSys ---- *)
  (* C's R_OK, W_OK and X_OK (4, 2, 1) are the machine's 1, 2 and 4 *)
  fun Posix_FileSys_access (p, m) : Int32.int =
    let val m = i32 m
        val flags = (if m div 4 mod 2 = 1 then 1 else 0) + (if m div 2 mod 2 = 1 then 2 else 0) + (if m mod 2 = 1 then 4 else 0)
    in
      case XC2Sys.osAccess (cstr p, flags, 0) of
        1 => 0
      | 0 => Int32.fromInt (failWith (XC2Sys.posixConst "EACCES"))
      | _ => Int32.fromInt (fail ())
    end
  fun Posix_FileSys_chdir p = ci (XC2Sys.osChdir (cstr p))
  fun Posix_FileSys_fchdir _ = Int32.fromInt (failWith (XC2Sys.posixConst "ENOSYS"))
  fun Posix_FileSys_chmod (p, m) = ci (XC2Sys.chmod (cstr p, ~1, w32 m))
  fun Posix_FileSys_fchmod (fd, m) = ci (XC2Sys.chmod ("", i32 fd, w32 m))
  fun Posix_FileSys_chown (p, u, g) = ci (XC2Sys.chown (cstr p, ~1, w32 u, w32 g))
  fun Posix_FileSys_fchown (fd, u, g) = ci (XC2Sys.chown ("", i32 fd, w32 u, w32 g))
  fun Posix_FileSys_ftruncate (fd, n : Int64.int) = ci (XC2Sys.ftruncate (i32 fd, Int64.toInt n))
  fun Posix_FileSys_truncate (p, n : Int64.int) =
    let val fd = XC2Sys.openf (cstr p, XC2Sys.posixConst "O_WRONLY", 0)
    in if fd = ~1 then Int32.fromInt (fail ())
       else let val r = check (XC2Sys.ftruncate (fd, Int64.toInt n)) in ignore (XC2Sys.close fd); Int32.fromInt r end
    end
  fun Posix_FileSys_getcwd (a : char XC2.array, n : Word64.word) =
    case XC2Sys.osGetcwd () of
      "" => (ignore (fail ()); 0w0)
    | s => if size s + 1 > Word64.toInt n then (errno := XC2Sys.posixConst "ERANGE"; 0w0)
           else (toArr (a, 0, s ^ "\000"); 0w1)
  fun Posix_FileSys_link (a, b) = ci (XC2Sys.link (cstr a, cstr b))
  fun Posix_FileSys_symlink (a, b) = ci (XC2Sys.symlink (cstr a, cstr b))
  (* the mode less the mask of new files, as mkdir makes it *)
  fun Posix_FileSys_mkdir (p, m : Word32.word) =
    let val r = XC2Sys.osMkdir (cstr p)
        val mask = XC2Sys.umask 0
        val _ = XC2Sys.umask mask
    in if r = ~1 then Int32.fromInt (fail ())
       else ci (XC2Sys.chmod (cstr p, ~1, Word32.toInt (Word32.andb (m, Word32.notb (Word32.fromInt mask)))))
    end
  fun Posix_FileSys_mkfifo (p, m) = ci (XC2Sys.mkfifo (cstr p, w32 m))
  fun Posix_FileSys_open2 (p, f) = ci (XC2Sys.openf (cstr p, i32 f, 0))
  fun Posix_FileSys_open3 (p, f, m) = ci (XC2Sys.openf (cstr p, i32 f, w32 m))
  fun pathconf (p, fd, n) : Int64.int =
    Int64.fromInt (case constName ("Posix_FileSys_PC_", i32 n) of
                     SOME name => (case XC2Sys.pathconf (p, fd, name) of [v] => (if v = ~1 then errno := 0 else (); v) | _ => fail ())
                   | NONE => failWith (XC2Sys.posixConst "EINVAL"))
  fun Posix_FileSys_pathconf (p, n) = pathconf (cstr p, ~1, n)
  fun Posix_FileSys_fpathconf (fd, n) = pathconf ("", i32 fd, n)
  fun Posix_FileSys_readlink (p, a : char XC2.array, n : Word64.word) : Int64.int =
    case XC2Sys.osReadLink (cstr p) of
      "" => ssize (fail ())
    | s => let val s = if size s > Word64.toInt n then String.substring (s, 0, Word64.toInt n) else s
           in toArr (a, 0, s); ssize (size s) end
  fun Posix_FileSys_rename (a, b) = ci (XC2Sys.osRename (cstr a, cstr b))
  fun Posix_FileSys_rmdir p = ci (XC2Sys.osRmdir (cstr p))
  fun Posix_FileSys_unlink p = ci (XC2Sys.osRemove (cstr p))
  fun Posix_FileSys_umask (m : Word32.word) = Word32.fromInt (XC2Sys.umask (w32 m))
  (* the file types of a mode (Linux's and the BSDs' numbers) *)
  val S_IFMT = 0wxF000 : Word32.word
  fun ifmt kind : Word32.word =
    case kind of 0 => 0wx8000 | 1 => 0wx4000 | 2 => 0wxA000 | 4 => 0wx1000
               | 5 => 0wxC000 | 6 => 0wx2000 | 7 => 0wx6000 | _ => 0w0
  fun isType kind (m : Word32.word) : Int32.int = if Word32.andb (m, S_IFMT) = ifmt kind then 1 else 0
  val Posix_FileSys_ST_isReg = isType 0
  val Posix_FileSys_ST_isDir = isType 1
  val Posix_FileSys_ST_isLink = isType 2
  val Posix_FileSys_ST_isFIFO = isType 4
  val Posix_FileSys_ST_isSock = isType 5
  val Posix_FileSys_ST_isChr = isType 6
  val Posix_FileSys_ST_isBlk = isType 7
  local
    (* the last stat: kind, mode, inode, device, links, user, group, size, times *)
    val st = ref [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    fun field k = List.nth (!st, k)
    fun stat r : Int32.int = case r of [] => Int32.fromInt (fail ()) | l => (st := l; 0)
  in
    fun Posix_FileSys_Stat_stat p = stat (XC2Sys.stat (cstr p, 0, ~1))
    fun Posix_FileSys_Stat_lstat p = stat (XC2Sys.stat (cstr p, 1, ~1))
    fun Posix_FileSys_Stat_fstat fd = stat (XC2Sys.stat ("", 0, i32 fd))
    fun Posix_FileSys_Stat_getMode () =
      Word32.orb (Word32.andb (Word32.fromInt (field 1), 0wxFFF), ifmt (field 0))
    fun Posix_FileSys_Stat_getINo () = Word64.fromInt (field 2)
    fun Posix_FileSys_Stat_getDev () = Word64.fromInt (field 3)
    fun Posix_FileSys_Stat_getRDev () = 0w0 : Word64.word
    fun Posix_FileSys_Stat_getNLink () = Word64.fromInt (field 4)
    fun Posix_FileSys_Stat_getUId () = Word32.fromInt (field 5)
    fun Posix_FileSys_Stat_getGId () = Word32.fromInt (field 6)
    fun Posix_FileSys_Stat_getSize () = Int64.fromInt (field 7)
    fun Posix_FileSys_Stat_getATime () = Int64.fromInt (field 8)
    fun Posix_FileSys_Stat_getMTime () = Int64.fromInt (field 9)
    fun Posix_FileSys_Stat_getCTime () = Int64.fromInt (field 10)
  end
  local
    val times = ref (0, 0)
  in
    fun Posix_FileSys_Utimbuf_setAcTime (t : Int64.int) = times := (Int64.toInt t, #2 (!times))
    fun Posix_FileSys_Utimbuf_setModTime (t : Int64.int) = times := (#1 (!times), Int64.toInt t)
    fun Posix_FileSys_Utimbuf_utime p = ci (XC2Sys.utime (cstr p, #1 (!times), #2 (!times)))
  end
  (* a directory stream: the number of the machine's, plus one (0 is NULL) *)
  fun Posix_FileSys_Dirstream_openDir p =
    case XC2Sys.osOpenDir (cstr p) of ~1 => (ignore (fail ()); 0w0) | d => Word64.fromInt (d + 1)
  fun Posix_FileSys_Dirstream_readDir (d : Word64.word) =
    case XC2Sys.osReadDir (Word64.toInt d - 1) of SOME n => XC2Mem.string n | NONE => 0w0
  fun Posix_FileSys_Dirstream_rewindDir (d : Word64.word) = ignore (XC2Sys.osRewindDir (Word64.toInt d - 1))
  fun Posix_FileSys_Dirstream_closeDir (d : Word64.word) = ci (XC2Sys.osCloseDir (Word64.toInt d - 1))

  (* ---- Posix.Process ---- *)
  fun Posix_Process_fork () = ci (XC2Sys.fork ())
  fun Posix_Process_execp (p, args) = ci (XC2Sys.exec (cstr p, cstrs args, 1))
  fun Posix_Process_exece (p, args, env) = ci (XC2Sys.exece (cstr p, cstrs args, cstrs env))
  fun Posix_Process_kill (p, s) = ci (XC2Sys.kill (i32 p, i32 s))
  fun Posix_Process_alarm (s : Word32.word) = Word32.fromInt (XC2Sys.alarm (w32 s))
  fun Posix_Process_pause () = ci (XC2Sys.pause ())
  fun Posix_Process_sleep (s : Word32.word) : Word32.word =
    ((_prim "time_sleep" : int -> unit) (w32 s * 1000000); 0w0)
  fun Posix_Process_nanosleep (sec : Int64.int ref, nsec : Int64.int ref) : Int32.int =
    ((_prim "time_sleep" : int -> unit) (Int64.toInt (!sec) * 1000000 + Int64.toInt (!nsec) div 1000); sec := 0; nsec := 0; 0)
  (* what the machine reports (the exit status, or 256 plus the signal) as
     C's status of wait *)
  fun Posix_Process_system cmd : Int32.int =
    case XC2Sys.system (cstr cmd) of
      ~1 => Int32.fromInt (fail ())
    | r => Int32.fromInt (if r >= 256 then r - 256 else r * 256)
  (* a status of waitpid, in the machine's form (process, how, status or
     signal) coded as C's: exited with s is s << 8, killed by g is g, stopped
     by g is g << 8 | 0x7f *)
  fun Posix_Process_waitpid (p, status : Int32.int ref, flags) : Int32.int =
    case XC2Sys.waitpid (i32 p, i32 flags) of
      [pid, how, v] =>
        (status := Int32.fromInt (case how of 0 => v * 256 | 1 => v | _ => v * 256 + 127);
         Int32.fromInt pid)
    | _ => Int32.fromInt (fail ())
  (* C's macros of a status *)
  fun bit b : Int32.int = if b then 1 else 0
  fun Posix_Process_ifExited (s : Int32.int) = bit (i32 s mod 128 = 0)
  fun Posix_Process_exitStatus (s : Int32.int) = Int32.fromInt (i32 s div 256 mod 256)
  fun Posix_Process_ifSignaled (s : Int32.int) = bit (i32 s mod 128 <> 0 andalso i32 s mod 128 <> 127)
  fun Posix_Process_termSig (s : Int32.int) = Int32.fromInt (i32 s mod 128)
  fun Posix_Process_ifStopped (s : Int32.int) = bit (i32 s mod 256 = 127)
  fun Posix_Process_stopSig (s : Int32.int) = Int32.fromInt (i32 s div 256 mod 256)

  (* ---- Date: C's tm, one to set (mkTime, strfTime) and one to read ---- *)
  local
    (* sec, min, hour, mday, mon, year - 1900, wday, yday, isdst *)
    val tmIn = ref [0, 0, 0, 1, 0, 70, 0, 0, 0]
    val tmOut = ref [0, 0, 0, 1, 0, 70, 0, 0, 0]
    fun get k () = Int32.fromInt (List.nth (!tmOut, k))
    fun set k (x : Int32.int) = tmIn := List.tabulate (9, fn j => if j = k then i32 x else List.nth (!tmIn, j))
    fun conv (t, local') : Int32.int =
      case XC2Sys.dateParts (t, local') of [] => Int32.fromInt (fail ()) | l => (tmOut := l; 0)
  in
    val Date_Tm_getSec = get 0 val Date_Tm_getMin = get 1 val Date_Tm_getHour = get 2
    val Date_Tm_getMDay = get 3 val Date_Tm_getMon = get 4 val Date_Tm_getYear = get 5
    val Date_Tm_getWDay = get 6 val Date_Tm_getYDay = get 7 val Date_Tm_getIsDst = get 8
    val Date_Tm_setSec = set 0 val Date_Tm_setMin = set 1 val Date_Tm_setHour = set 2
    val Date_Tm_setMDay = set 3 val Date_Tm_setMon = set 4 val Date_Tm_setYear = set 5
    val Date_Tm_setWDay = set 6 val Date_Tm_setYDay = set 7 val Date_Tm_setIsDst = set 8
    fun Date_gmTime (t : Int64.int ref) = conv (Int64.toInt (!t), 0)
    fun Date_localTime (t : Int64.int ref) = conv (Int64.toInt (!t), 1)
    fun Date_mkTime () : Int64.int =
      Int64.fromInt (case XC2Sys.dateSeconds (!tmIn, 1) of s :: parts => (tmIn := parts; s) | [] => fail ())
    (* mktime (gmtime (now)) - now: the broken-down time of UTC, taken for
       local time with no daylight saving *)
    fun Date_localOffset () : real =
      let val now = XC2Sys.timeNow () div 1000000
      in case XC2Sys.dateSeconds (XC2Sys.dateParts (now, 0), 1) of
           t :: _ => Real.fromInt (t - now)
         | [] => 0.0
      end
    fun Date_strfTime (a : char XC2.array, n : Word64.word, fmt) : Word64.word =
      let val s = XC2Sys.dateFormat (cstr fmt, !tmIn, 1)
      in if size s + 1 > Word64.toInt n then 0w0 else (toArr (a, 0, s ^ "\000"); Word64.fromInt (size s)) end
  end

  (* ---- the system databases ---- *)
  local
    val pw = ref ["", "", "", "0", "0"]
    val gr = ref ["", "0"]
    (* 1 when there is an entry, 0 when there is none, as MLton's C *)
    fun entry (r, l) : Int32.int = case l of [] => 0 | l => (r := l; 1)
    fun num s = getOpt (Int.fromString s, 0)
  in
    (* the machine looks a user up by number when the name is empty *)
    fun Posix_SysDB_getpwnam n = if cstr n = "" then 0 else entry (pw, XC2Sys.getpw (cstr n, 0))
    fun Posix_SysDB_getpwuid (u : Word32.word) = entry (pw, XC2Sys.getpw ("", w32 u))
    fun Posix_SysDB_getgrnam n = if cstr n = "" then 0 else entry (gr, XC2Sys.getgr (cstr n, 0))
    fun Posix_SysDB_getgrgid (g : Word32.word) = entry (gr, XC2Sys.getgr ("", w32 g))
    fun Posix_SysDB_Passwd_getName () = XC2Mem.string (List.nth (!pw, 0))
    fun Posix_SysDB_Passwd_getDir () = XC2Mem.string (List.nth (!pw, 1))
    fun Posix_SysDB_Passwd_getShell () = XC2Mem.string (List.nth (!pw, 2))
    fun Posix_SysDB_Passwd_getUId () = Word32.fromInt (num (List.nth (!pw, 3)))
    fun Posix_SysDB_Passwd_getGId () = Word32.fromInt (num (List.nth (!pw, 4)))
    fun Posix_SysDB_Group_getName () = XC2Mem.string (hd (!gr))
    fun Posix_SysDB_Group_getGId () = Word32.fromInt (num (List.nth (!gr, 1)))
    fun Posix_SysDB_Group_getMem () = XC2Mem.strings (List.drop (!gr, 2))
  end

  (* ---- Posix.TTY: one termios; iflag, oflag, cflag, lflag, ispeed, ospeed, cc ---- *)
  local
    val tio = ref [0, 0, 0, 0, 0, 0]
    fun get k () = Word32.fromInt (List.nth (!tio, k))
    fun set k (x : Word32.word) = tio := List.tabulate (length (!tio), fn j => if j = k then w32 x else List.nth (!tio, j))
    fun nosys () = Int32.fromInt (failWith (XC2Sys.posixConst "ENOSYS"))
  in
    fun Posix_TTY_TC_getattr fd : Int32.int =
      case XC2Sys.tcgetattr (i32 fd) of [] => Int32.fromInt (fail ()) | l => (tio := l; 0)
    fun Posix_TTY_TC_setattr (fd, act) = ci (XC2Sys.tcsetattr (i32 fd, i32 act, !tio))
    val Posix_TTY_Termios_getIFlag = get 0 val Posix_TTY_Termios_getOFlag = get 1
    val Posix_TTY_Termios_getCFlag = get 2 val Posix_TTY_Termios_getLFlag = get 3
    val Posix_TTY_Termios_cfGetISpeed = get 4 val Posix_TTY_Termios_cfGetOSpeed = get 5
    val Posix_TTY_Termios_setIFlag = set 0 val Posix_TTY_Termios_setOFlag = set 1
    val Posix_TTY_Termios_setCFlag = set 2 val Posix_TTY_Termios_setLFlag = set 3
    fun Posix_TTY_Termios_cfSetISpeed s : Int32.int = (set 4 s; 0)
    fun Posix_TTY_Termios_cfSetOSpeed s : Int32.int = (set 5 s; 0)
    fun Posix_TTY_Termios_getCC (a : Word8.word XC2.array) = ignore (
      List.foldl (fn (c, k) => (if k < XC2.Array.length a then XC2.Array.update (a, k, Word8.fromInt c) else (); k + 1)) 0 (List.drop (!tio, 6)))
    fun Posix_TTY_Termios_setCC (a : Word8.word XC2.array) =
      tio := List.take (!tio, 6) @ List.tabulate (XC2.Array.length a, fn k => Word8.toInt (XC2.Array.sub (a, k)))
    fun Posix_TTY_TC_drain _ = nosys ()
    fun Posix_TTY_TC_flow _ = nosys ()
    fun Posix_TTY_TC_flush _ = nosys ()
    fun Posix_TTY_TC_sendbreak _ = nosys ()
    fun Posix_TTY_TC_getpgrp _ = nosys ()
    fun Posix_TTY_TC_setpgrp _ = nosys ()
  end

  (* the machine's poll, SOME events or NONE on failure: with no descriptors
     it waits the time (microseconds, ~1 for ever) and gives SOME [] *)
  fun poll (fds, evs, t) =
    if null fds then ((if t > 0 then (_prim "time_sleep" : int -> unit) t else ()); SOME [])
    else case XC2Sys.osPoll (fds, evs, t) of [] => NONE | l => SOME l

  (* ---- OS.IO.poll: C's POLL bits are the machine's 1 read, 2 write, 4 urgent ---- *)
  fun OS_IO_poll (fds : Int32.int vector, evs : Int16.int vector, n : Word64.word, timeout : Int32.int,
                  revs : Int16.int XC2.array) : Int32.int =
    let
      val cin = const "OS_IO_POLLIN" val cout = const "OS_IO_POLLOUT" val cpri = const "OS_IO_POLLPRI"
      fun has (x, b) = Int.rem (x div b, 2) = 1
      fun toRune e = (if has (e, cin) then 1 else 0) + (if has (e, cout) then 2 else 0) + (if has (e, cpri) then 4 else 0)
      fun fromRune e = (if has (e, 1) then cin else 0) + (if has (e, 2) then cout else 0) + (if has (e, 4) then cpri else 0)
      val k = Word64.toInt n
      val t = i32 timeout
    in
      case poll (List.tabulate (k, fn i => i32 (Vector.sub (fds, i))),
                          List.tabulate (k, fn i => toRune (Int16.toInt (Vector.sub (evs, i)))),
                          if t < 0 then ~1 else t * 1000) of
        NONE => Int32.fromInt (fail ())
      | SOME l => (List.foldl (fn (e, i) => (XC2.Array.update (revs, i, Int16.fromInt (fromRune e)); i + 1)) 0 l;
              Int32.fromInt (length (List.filter (fn e => e <> 0) l)))
    end

  (* ---- Posix.Signal: a sigset is a bitmap of its bytes; a signal is
     neither masked nor caught (Rune's machine does neither) ---- *)
  fun sigbit (s : Int32.int) = let val k = i32 s - 1 in (k div 8, Word8.<< (0w1, Word.fromInt (k mod 8))) end
  fun Posix_Signal_sigemptyset (a : Word8.word XC2.array) : Int32.int =
    (List.app (fn i => XC2.Array.update (a, i, 0w0)) (List.tabulate (XC2.Array.length a, fn i => i)); 0)
  fun Posix_Signal_sigfillset (a : Word8.word XC2.array) : Int32.int =
    (List.app (fn i => XC2.Array.update (a, i, 0wxFF)) (List.tabulate (XC2.Array.length a, fn i => i)); 0)
  fun Posix_Signal_sigaddset (a : Word8.word XC2.array, s) : Int32.int =
    let val (i, b) = sigbit s in XC2.Array.update (a, i, Word8.orb (XC2.Array.sub (a, i), b)); 0 end
  fun Posix_Signal_sigdelset (a : Word8.word XC2.array, s) : Int32.int =
    let val (i, b) = sigbit s in XC2.Array.update (a, i, Word8.andb (XC2.Array.sub (a, i), Word8.notb b)); 0 end
  fun Posix_Signal_sigismember (v : Word8.word vector, s) : Int32.int =
    let val (i, b) = sigbit s in if Word8.andb (Vector.sub (v, i), b) = 0w0 then 0 else 1 end
  fun Posix_Signal_sigprocmask (_ : Int32.int, _ : Word8.word vector, old : Word8.word XC2.array) =
    Posix_Signal_sigemptyset old
  fun Posix_Signal_sigsuspend (_ : Word8.word vector) = ()
  fun Posix_Signal_isDefault (_ : Int32.int, r : Int32.int ref) : Int32.int = (r := 1; 0)
  fun Posix_Signal_isIgnore (_ : Int32.int, r : Int32.int ref) : Int32.int = (r := 0; 0)
  fun Posix_Signal_default (_ : Word64.word, _ : Int32.int) : Int32.int = 0
  fun Posix_Signal_ignore (_ : Word64.word, _ : Int32.int) : Int32.int = 0
  fun Posix_Signal_handlee (_ : Word64.word, _ : Int32.int) : Int32.int = Int32.fromInt (failWith (XC2Sys.posixConst "ENOSYS"))
  fun Posix_Signal_handleGC (_ : Word64.word) = ()
  fun Posix_Signal_isPending (_ : Word64.word, _ : Int32.int) : Int32.int = 0
  fun Posix_Signal_isPendingGC (_ : Word64.word) : Int32.int = 0
  fun Posix_Signal_resetPending (_ : Word64.word) = ()

  (* ---- sockets: an address of the machine's is the bytes of C's sockaddr,
     as MLton's library makes and reads them ---- *)
  structure Sock =
  struct
    val create = _prim "socket_create" : int * int * int -> int
    val pair = _prim "socket_pair" : int * int * int -> int list
    val bind = _prim "socket_bind" : int * string -> int
    val connect = _prim "socket_connect" : int * string -> int
    val listen = _prim "socket_listen" : int * int -> int
    val accept = _prim "socket_accept" : int -> int
    val send = _prim "socket_send" : int * string * int -> int
    val sendto = _prim "socket_sendto" : int * string * int * string -> int
    val recv = _prim "socket_recv" : int * int * int -> string
    val recvfrom = _prim "socket_recvfrom" : int * int * int -> string list
    val shutdown = _prim "socket_shutdown" : int * int -> int
    val name = _prim "socket_name" : int -> string
    val peer = _prim "socket_peer" : int -> string
    val getopt = _prim "socket_getopt" : int * int * int -> int
    val setopt = _prim "socket_setopt" : int * int * int * int -> int
    val linger = _prim "socket_linger" : int * int * int -> int list
    val query = _prim "socket_query" : int * int -> int
    val family = _prim "socket_addr_family" : string -> int
    val hostByName = _prim "netdb_host_byname" : string -> string list
    val hostByAddr = _prim "netdb_host_byaddr" : string -> string list
    val hostname = _prim "netdb_hostname" : unit -> string
    val protoByName = _prim "netdb_proto_byname" : string -> string list
    val protoByNumber = _prim "netdb_proto_bynumber" : int -> string list
    val servByName = _prim "netdb_serv_byname" : string * string -> string list
    val servByPort = _prim "netdb_serv_byport" : int * string -> string list
  end
  fun w8 (w : Word8.word) = Word8.toInt w
  fun bytesVec (v : Word8.word vector) = vecBytes (v, 0, Vector.length v)
  fun bytesVecN (v : Word8.word vector, n) = vecBytes (v, 0, n)
  (* an address into a byte array, and its length into the ref *)
  fun putAddr (a : Word8.word XC2.array, len : Word32.word ref, s) : Int32.int =
    (toBytes (a, 0, s); len := Word32.fromInt (size s); 0)
  fun Socket_GenericSock_socket (d, t, p) = ci (Sock.create (i32 d, i32 t, i32 p))
  fun Socket_GenericSock_socketPair (d, t, p, a : Int32.int XC2.array) : Int32.int =
    case Sock.pair (i32 d, i32 t, i32 p) of
      [x, y] => (XC2.Array.update (a, 0, Int32.fromInt x); XC2.Array.update (a, 1, Int32.fromInt y); 0)
    | _ => Int32.fromInt (fail ())
  fun Socket_bind (s, a, n : Word32.word) = ci (Sock.bind (i32 s, bytesVecN (a, w32 n)))
  fun Socket_connect (s, a, n : Word32.word) = ci (Sock.connect (i32 s, bytesVecN (a, w32 n)))
  fun Socket_listen (s, n) = ci (Sock.listen (i32 s, i32 n))
  fun Socket_close s = ci (XC2Sys.close (i32 s))
  fun Socket_shutdown (s, how) = ci (Sock.shutdown (i32 s, i32 how))
  fun Socket_accept (s, a, len) : Int32.int =
    case Sock.accept (i32 s) of
      ~1 => Int32.fromInt (fail ())
    | fd => (ignore (putAddr (a, len, Sock.peer fd)); Int32.fromInt fd)
  fun Socket_familyOfAddr v = Int32.fromInt (Sock.family (bytesVec v))
  fun sent r : Int64.int = ssize (check r)
  fun Socket_sendArr (s, a, i, n : Word64.word, f) = sent (Sock.send (i32 s, arrBytes (a, i32 i, Word64.toInt n), i32 f))
  fun Socket_sendVec (s, v, i, n : Word64.word, f) = sent (Sock.send (i32 s, vecBytes (v, i32 i, Word64.toInt n), i32 f))
  fun Socket_sendArrTo (s, a, i, n : Word64.word, f, to, tn : Word32.word) =
    sent (Sock.sendto (i32 s, arrBytes (a, i32 i, Word64.toInt n), i32 f, bytesVecN (to, w32 tn)))
  fun Socket_sendVecTo (s, v, i, n : Word64.word, f, to, tn : Word32.word) =
    sent (Sock.sendto (i32 s, vecBytes (v, i32 i, Word64.toInt n), i32 f, bytesVecN (to, w32 tn)))
  fun Socket_recv (s, a, i, n : Word64.word, f) : Int64.int =
    let val r = Sock.recv (i32 s, Word64.toInt n, i32 f)
    in ssize (if r = "" andalso XC2Sys.sysErrno () <> 0 then fail () else (toBytes (a, i32 i, r); size r)) end
  fun Socket_recvFrom (s, a, i, n : Word64.word, f, from, len) : Int64.int =
    ssize (case Sock.recvfrom (i32 s, Word64.toInt n, i32 f) of
             [r, addr] => (toBytes (a, i32 i, r); ignore (putAddr (from, len, addr)); size r)
           | _ => fail ())
  fun Socket_Ctl_getSockName (s, a, len) =
    case Sock.name (i32 s) of "" => Int32.fromInt (fail ()) | addr => putAddr (a, len, addr)
  fun Socket_Ctl_getPeerName (s, a, len) =
    case Sock.peer (i32 s) of "" => Int32.fromInt (fail ()) | addr => putAddr (a, len, addr)
  fun Socket_Ctl_getSockOptC_Int (s, l, opt, r : Int32.int ref) : Int32.int =
    case Sock.getopt (i32 s, i32 l, i32 opt) of ~1 => Int32.fromInt (fail ()) | v => (r := Int32.fromInt v; 0)
  fun Socket_Ctl_setSockOptC_Int (s, l, opt, v) = ci (Sock.setopt (i32 s, i32 l, i32 opt, i32 v))
  fun Socket_Ctl_getSockOptC_Linger (s, _ : Int32.int, _ : Int32.int, on : Int32.int ref, secs : Int32.int ref) : Int32.int =
    case Sock.linger (i32 s, 0, 0) of
      [t] => (if t < 0 then (on := 0; secs := 0) else (on := 1; secs := Int32.fromInt t); 0)
    | _ => Int32.fromInt (fail ())
  fun Socket_Ctl_setSockOptC_Linger (s, _ : Int32.int, _ : Int32.int, on : Int32.int, secs : Int32.int) : Int32.int =
    case Sock.linger (i32 s, 1, if on = 0 then ~1 else i32 secs) of [_] => 0 | _ => Int32.fromInt (fail ())
  fun Socket_Ctl_getNREAD (s, r : Int32.int ref) : Int32.int =
    case Sock.query (i32 s, 0) of ~1 => Int32.fromInt (fail ()) | n => (r := Int32.fromInt n; 0)
  fun Socket_Ctl_getATMARK (s, r : Int32.int ref) : Int32.int =
    case Sock.query (i32 s, 1) of ~1 => Int32.fromInt (fail ()) | n => (r := Int32.fromInt n; 0)
  (* sockaddr_in: family (2 bytes), port (2, as given), address (4), zeros (8) *)
  fun Socket_INetSock_toAddr (inAddr : Word8.word vector, port : Word16.word, a, len) =
    let val p = Word16.toInt port
        val fam = const "Socket_AF_INET"
        val s = CharVector.tabulate (16, fn k =>
                  Char.chr (case k of 0 => fam mod 256 | 1 => fam div 256 | 2 => p mod 256 | 3 => p div 256
                                    | 4 => w8 (Vector.sub (inAddr, 0)) | 5 => w8 (Vector.sub (inAddr, 1))
                                    | 6 => w8 (Vector.sub (inAddr, 2)) | 7 => w8 (Vector.sub (inAddr, 3)) | _ => 0))
    in ignore (putAddr (a, len, s)) end
  local
    val from = ref (Vector.tabulate (16, fn _ => 0w0 : Word8.word))
  in
    fun Socket_INetSock_fromAddr (v : Word8.word vector) = from := v
    fun Socket_INetSock_getPort () = Word16.fromInt (w8 (Vector.sub (!from, 2)) + 256 * w8 (Vector.sub (!from, 3)))
    fun Socket_INetSock_getInAddr (a : Word8.word XC2.array) =
      List.app (fn k => XC2.Array.update (a, k, Vector.sub (!from, 4 + k))) [0, 1, 2, 3]
  end
  (* sockaddr_un: family (2 bytes) and the path, 108 bytes *)
  val unixPathMax = 108
  fun Socket_UnixSock_toAddr (path, n : Word64.word, a, len) =
    let val p = String.substring (cstr path ^ "\000", 0, Int.min (Word64.toInt n, unixPathMax))
        val fam = const "Socket_AF_UNIX"
        val s = CharVector.tabulate (2 + unixPathMax, fn k =>
                  if k = 0 then Char.chr (fam mod 256) else if k = 1 then Char.chr (fam div 256)
                  else if k - 2 < size p then String.sub (p, k - 2) else #"\000")
    in ignore (putAddr (a, len, s)) end
  fun Socket_UnixSock_pathLen (v : Word8.word vector) : Word64.word =
    let val n = Vector.length v
        fun loop i = if i >= unixPathMax orelse 2 + i >= n orelse Vector.sub (v, 2 + i) = 0w0 then i else loop (i + 1)
    in Word64.fromInt (if n > 2 andalso Vector.sub (v, 2) = 0w0 then unixPathMax else loop 0) end
  fun Socket_UnixSock_fromAddr (v : Word8.word vector, a : char XC2.array, n : Word64.word) =
    List.app (fn k => XC2.Array.update (a, k, if 2 + k < Vector.length v then Char.chr (w8 (Vector.sub (v, 2 + k))) else #"\000"))
      (List.tabulate (Word64.toInt n, fn k => k))
  local
    val timeout : (int * int) option ref = ref NONE
  in
    (* C_Time.t and C_SUSeconds.t, Int64.int *)
    fun Socket_setTimeout (s : Int64.int, us : Int64.int) = timeout := SOME (Int64.toInt s, Int64.toInt us)
    fun Socket_setTimeoutNull () = timeout := NONE
    fun Socket_getTimeout_sec () = Int64.fromInt (case !timeout of SOME (s, _) => s | NONE => 0)
    fun Socket_getTimeout_usec () = Int64.fromInt (case !timeout of SOME (_, us) => us | NONE => 0)
    (* select, as a poll of every descriptor for what it is asked for *)
    fun Socket_select (rv : Int32.int vector, wv : Int32.int vector, ev : Int32.int vector,
                       ra : Int32.int XC2.array, wa : Int32.int XC2.array, ea : Int32.int XC2.array) : Int32.int =
      let
        val sets = [(rv, ra, 1), (wv, wa, 2), (ev, ea, 4)]
        val asked = List.concat (List.map (fn (v, _, b) => List.tabulate (Vector.length v, fn i => (i32 (Vector.sub (v, i)), b))) sets)
        val t = case !timeout of SOME (s, us) => s * 1000000 + us | NONE => ~1
      in
        (* select fails for a descriptor that is not open, poll does not *)
        if List.exists (fn (fd, _) => XC2Sys.fcntl (fd, const "Posix_IO_F_GETFD", 0) = ~1) asked
          then Int32.fromInt (failWith (XC2Sys.posixConst "EBADF"))
        else
        case poll (List.map #1 asked, List.map #2 asked, t) of
          NONE => Int32.fromInt (fail ())
        | SOME got =>
            let
              val n = ref 0
              fun mark ([], _) = ()
                | mark (((v, a, b) :: rest), got) =
                    let val k = Vector.length v
                        val mine = List.take (got, k)
                    in List.foldl (fn (e, i) => (if Int.rem (e div b, 2) = 1 then (XC2.Array.update (a, i, 1); n := !n + 1) else (); i + 1)) 0 mine;
                       mark (rest, List.drop (got, k))
                    end
            in mark (sets, got); Int32.fromInt (!n) end
      end
  end
  (* byte order: the host's is little-endian *)
  fun Net_htonl (w : Word32.word) =
    Word32.orb (Word32.orb (Word32.<< (Word32.andb (w, 0wxFF), 0w24), Word32.<< (Word32.andb (Word32.>> (w, 0w8), 0wxFF), 0w16)),
                Word32.orb (Word32.<< (Word32.andb (Word32.>> (w, 0w16), 0wxFF), 0w8), Word32.>> (w, 0w24)))
  val Net_ntohl = Net_htonl
  fun Net_htons (w : Word16.word) = Word16.orb (Word16.<< (Word16.andb (w, 0wxFF), 0w8), Word16.>> (w, 0w8))
  val Net_ntohs = Net_htons
  (* the system's databases of hosts, protocols and services: one entry each *)
  local
    val host = ref ["", ""]
    val proto = ref ["", "0"]
    val serv = ref ["", "0", ""]
    fun found (r, l) : Int32.int = case l of [] => 0 | l => (r := l; 1)
    fun num s = getOpt (Int.fromString s, 0)
    fun addrs () = String.tokens (fn c => c = #" ") (List.nth (!host, 1))
    fun dotted (v : Word8.word vector) = String.concatWith "." (List.tabulate (Vector.length v, fn i => Int.toString (w8 (Vector.sub (v, i)))))
  in
    fun NetHostDB_getByName n = found (host, Sock.hostByName (cstr n))
    fun NetHostDB_getByAddress (v : Word8.word vector, _ : Word32.word) = found (host, Sock.hostByAddr (dotted v))
    fun NetHostDB_getEntryName () = XC2Mem.string (hd (!host))
    fun NetHostDB_getEntryAliasesNum () = Int32.fromInt (length (!host) - 2)
    fun NetHostDB_getEntryAliasesN (i : Int32.int) = XC2Mem.string (List.nth (!host, 2 + i32 i))
    fun NetHostDB_getEntryAddrType () = Int32.fromInt (const "Socket_AF_INET")
    fun NetHostDB_getEntryLength () : Int32.int = 4
    fun NetHostDB_getEntryAddrsNum () = Int32.fromInt (length (addrs ()))
    fun NetHostDB_getEntryAddrsN (i : Int32.int, a : Word8.word XC2.array) = ignore (
      List.foldl (fn (f, k) => (XC2.Array.update (a, k, Word8.fromInt (num f)); k + 1)) 0
        (String.fields (fn c => c = #".") (List.nth (addrs (), i32 i))))
    fun NetHostDB_getHostName (a : char XC2.array, n : Word64.word) : Int32.int =
      let val h = Sock.hostname () in toArr (a, 0, String.substring (h ^ "\000", 0, Int.min (size h + 1, Word64.toInt n))); 0 end
    fun NetProtDB_getByName n = found (proto, Sock.protoByName (cstr n))
    fun NetProtDB_getByNumber p = found (proto, Sock.protoByNumber (i32 p))
    fun NetProtDB_getEntryName () = XC2Mem.string (hd (!proto))
    fun NetProtDB_getEntryProto () = Int32.fromInt (num (List.nth (!proto, 1)))
    fun NetProtDB_getEntryAliasesNum () = Int32.fromInt (length (!proto) - 2)
    fun NetProtDB_getEntryAliasesN (i : Int32.int) = XC2Mem.string (List.nth (!proto, 2 + i32 i))
    fun NetServDB_getByName (n, p) = found (serv, Sock.servByName (cstr n, cstr p))
    fun NetServDB_getByNameNull n = found (serv, Sock.servByName (cstr n, ""))
    fun NetServDB_getByPort (port, p) = found (serv, Sock.servByPort (i32 port, cstr p))
    fun NetServDB_getByPortNull port = found (serv, Sock.servByPort (i32 port, ""))
    fun NetServDB_getEntryName () = XC2Mem.string (hd (!serv))
    fun NetServDB_getEntryPort () = Int32.fromInt (num (List.nth (!serv, 1)))
    fun NetServDB_getEntryProto () = XC2Mem.string (List.nth (!serv, 2))
    fun NetServDB_getEntryAliasesNum () = Int32.fromInt (length (!serv) - 3)
    fun NetServDB_getEntryAliasesN (i : Int32.int) = XC2Mem.string (List.nth (!serv, 3 + i32 i))
  end

  (* ---- MLton's extensions ---- *)
  fun MLton_Process_spawne (p, args, env) : Int32.int =
    ci ((_prim "posix_spawn" : string * string list * string list * int * int list -> int)
          (cstr p, cstrs args, cstrs env, 2, [~1, ~1, ~1]))
  fun MLton_Process_spawnp (p, args) : Int32.int =
    ci ((_prim "posix_spawn" : string * string list * string list * int * int list -> int)
          (cstr p, cstrs args, [], 1, [~1, ~1, ~1]))
  local
    val ru = ref [0, 0, 0, 0, 0, 0]
    (* C_Time.t and C_SUSeconds.t, Int64.int *)
    fun sec k () = Int64.fromInt (List.nth (!ru, k) div 1000000)
    fun usec k () = Int64.fromInt (List.nth (!ru, k) mod 1000000)
  in
    fun MLton_Rusage_getrusage (_ : Word64.word) =
      let val t = XC2Sys.times ()
      in ru := [(_prim "time_user" : unit -> int) (), (_prim "time_sys" : unit -> int) (),
                List.nth (t, 3), List.nth (t, 4),
                (_prim "time_gc_user" : unit -> int) (), (_prim "time_gc_sys" : unit -> int) ()]
      end
    val MLton_Rusage_self_utime_sec = sec 0 val MLton_Rusage_self_utime_usec = usec 0
    val MLton_Rusage_self_stime_sec = sec 1 val MLton_Rusage_self_stime_usec = usec 1
    val MLton_Rusage_children_utime_sec = sec 2 val MLton_Rusage_children_utime_usec = usec 2
    val MLton_Rusage_children_stime_sec = sec 3 val MLton_Rusage_children_stime_usec = usec 3
    val MLton_Rusage_gc_utime_sec = sec 4 val MLton_Rusage_gc_utime_usec = usec 4
    val MLton_Rusage_gc_stime_sec = sec 5 val MLton_Rusage_gc_stime_usec = usec 5
  end
  fun MLton_Syslog_openlog _ = ()
  fun MLton_Syslog_closelog () = ()
  fun MLton_Syslog_syslog _ = ()
end

(* ---- the C functions of the reals: MLton's formatting and reading ---- *)
functor XC2RealC (type real
                  val toManExp : real -> {man : real, exp : int}
                  val split : real -> {whole : real, frac : real}
                  val isFinite : real -> bool
                  val isNan : real -> bool
                  val == : real * real -> bool
                  val abs : real -> real
                  val fromLargeInt : IntInf.int -> real
                  val fromManExp : {man : real, exp : int} -> real
                  val fmt : StringCvt.realfmt -> real -> string
                  val toDecimal : real -> IEEEReal.decimal_approx
                  val copySign : real * real -> real
                  val zero : real
                  val toReal : string * IEEEReal.rounding_mode -> real) =
struct
  fun frexp (x, e : Int32.int ref) =
    if not (isFinite x) orelse == (x, zero) then (e := 0; x)
    else let val {man, exp} = toManExp x in e := Int32.fromInt exp; man end
  fun modf (x, ip : real ref) =
    if isNan x then (ip := x; x)
    else if not (isFinite x) then (ip := x; copySign (zero, x))
    else let val {whole, frac} = split x in ip := whole; frac end
  fun mode (r : Int32.int) =
    case Int32.toInt r of 0 => IEEEReal.TO_ZERO | 2 => IEEEReal.TO_POSINF | 3 => IEEEReal.TO_NEGINF | _ => IEEEReal.TO_NEAREST
  (* f () in the rounding mode m *)
  fun inMode m f =
    let val old = IEEEReal.getRoundingMode ()
        val () = IEEEReal.setRoundingMode m
        val r = f () handle e => (IEEEReal.setRoundingMode old; raise e)
    in IEEEReal.setRoundingMode old; r end
  (* the digits and the position of the point, value = 0.digits * 10^decpt, of
     the text of fmt: without leading and trailing zeros *)
  fun digitsOf (s, decpt) =
    let
      val ds = String.explode s
      fun dropLead ([], d) = ([], d)
        | dropLead (#"0" :: r, d) = dropLead (r, d - 1)
        | dropLead (l, d) = (l, d)
      val (ds, decpt) = dropLead (ds, decpt)
      val ds = List.rev (#1 (dropLead (List.rev ds, 0)))
    in (String.implode ds, decpt) end
  fun gdtoa (x, m : Int32.int, ndig : Int32.int, r : Int32.int, decpt : Int32.int ref) =
    let
      val x = abs x
      val n = Int32.toInt ndig
      val (s, d) =
        case Int32.toInt m of
          0 => if == (x, zero) then ("0", 1)
               else let val {digits, exp, ...} = toDecimal x
                    in (String.concat (List.map Int.toString digits), exp) end
        | 2 => if == (x, zero) then ("0", 1)
               else
                 let val t = inMode (mode r) (fn () => fmt (StringCvt.SCI (SOME (Int.max (n - 1, 0)))) x)
                     val (man, e) = case String.fields (fn c => c = #"E") t of [a, b] => (a, b) | _ => (t, "0")
                     val e = valOf (Int.fromString e)
                     val man = String.translate (fn #"." => "" | c => str c) man
                     val (s, d) = digitsOf (man, e + 1)
                 in if s = "" then ("0", 1) else (s, d) end
        | _ => let val t = inMode (mode r) (fn () => fmt (StringCvt.FIX (SOME n)) x)
                   val (whole, frac) = case String.fields (fn c => c = #".") t of [a, b] => (a, b) | _ => (t, "")
                   val (s, d) = digitsOf (whole ^ frac, size whole)
               in if s = "" then ("", ~n) else (s, d) end
    in decpt := Int32.fromInt d; XC2Mem.string s end
  (* C's strtod of MLton's texts ([-]digits[.digits][E[-]digits]) in the
     rounding mode r (toReal: XC2Strtod below) *)
  fun strtor (text, r : Int32.int) = toReal (XC2C.cstr text, mode r)
end

(* C's strtod and strtof in a rounding mode: the machine's, which reads a
   numeral in the current one *)
structure XC2Strtod =
struct
  val fromString64 = _prim "real_from_string" : string -> real option
  val fromString32 = _prim "real_single_from_string" : string -> real option
  fun inMode (m, read) text =
    let val old = IEEEReal.getRoundingMode ()
        val () = IEEEReal.setRoundingMode m
        val x = read text handle e => (IEEEReal.setRoundingMode old; raise e)
    in IEEEReal.setRoundingMode old; getOpt (x, 0.0) end
  fun strtod (text, m) = inMode (m, fromString64) text
  fun strtof (text, m) = Real32.fromLarge IEEEReal.TO_NEAREST (inMode (m, fromString32) text)
end
structure XC2RealC64 = XC2RealC (open Real val zero = 0.0 val toReal = XC2Strtod.strtod)
structure XC2RealC32 = XC2RealC (open Real32 val zero = Real32.fromInt 0 val toReal = XC2Strtod.strtof)

structure XC2FFIReal =
struct
  local
    structure M = Math
    structure M32 = Real32.Math
  in
    val Real64_frexp = XC2RealC64.frexp val Real32_frexp = XC2RealC32.frexp
    val Real64_modf = XC2RealC64.modf val Real32_modf = XC2RealC32.modf
    val Real64_gdtoa = XC2RealC64.gdtoa val Real32_gdtoa = XC2RealC32.gdtoa
    val Real64_strtor = XC2RealC64.strtor val Real32_strtor = XC2RealC32.strtor
    fun Real64_fetch (r : real ref) = !r fun Real32_fetch (r : Real32.real ref) = !r
    fun Real64_store (r : real ref, x) = r := x fun Real32_store (r : Real32.real ref, x) = r := x
    fun Real64_move (d : real ref, s) = d := !s fun Real32_move (d : Real32.real ref, s) = d := !s
    val Real64_realCeil = Real.realCeil val Real32_realCeil = Real32.realCeil
    val Real64_realFloor = Real.realFloor val Real32_realFloor = Real32.realFloor
    val Real64_realTrunc = Real.realTrunc val Real32_realTrunc = Real32.realTrunc
    val Real64_Math_acos = M.acos val Real64_Math_asin = M.asin val Real64_Math_atan = M.atan
    val Real64_Math_atan2 = M.atan2 val Real64_Math_cos = M.cos val Real64_Math_cosh = M.cosh
    val Real64_Math_exp = M.exp val Real64_Math_ln = M.ln val Real64_Math_log10 = M.log10
    val Real64_Math_pow = M.pow val Real64_Math_sin = M.sin val Real64_Math_sinh = M.sinh
    val Real64_Math_sqrt = M.sqrt val Real64_Math_tan = M.tan val Real64_Math_tanh = M.tanh
    val Real32_Math_acos = M32.acos val Real32_Math_asin = M32.asin val Real32_Math_atan = M32.atan
    val Real32_Math_atan2 = M32.atan2 val Real32_Math_cos = M32.cos val Real32_Math_cosh = M32.cosh
    val Real32_Math_exp = M32.exp val Real32_Math_ln = M32.ln val Real32_Math_log10 = M32.log10
    val Real32_Math_pow = M32.pow val Real32_Math_sin = M32.sin val Real32_Math_sinh = M32.sinh
    val Real32_Math_sqrt = M32.sqrt val Real32_Math_tan = M32.tan val Real32_Math_tanh = M32.tanh
  end
end
structure XC2SymbolImpl =
struct
  local
    val argv = ref NONE
    (* MLton's runtime gives the arguments without the name of the program *)
    fun args () = CommandLine.arguments ()
    fun getArgv () = case !argv of SOME p => p | NONE => let val p = XC2Mem.strings (args ()) in argv := SOME p; p end
  in
    val CommandLine_argc = (fn () => Int32.fromInt (length (args ())), fn (_ : Int32.int) => ())
    val CommandLine_argv = (getArgv, fn (_ : Word64.word) => ())
    val CommandLine_commandName = (fn () => XC2Mem.string (CommandLine.name ()), fn (_ : Word64.word) => ())
    val Posix_ProcEnv_environ = (fn () => XC2Mem.strings (XC2Sys.environ ()), fn (_ : Word64.word) => ())
    val MLton_Platform_CygwinUseMmap = (fn () => false, fn (_ : bool) => ())
  end
end

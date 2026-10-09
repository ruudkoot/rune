(* The primitives of MLKit's Basis Library (prim ("NAME", ARG), which
   tests/basis/xc2/mlkit/rewrite.awk turns into XC2KPrim.ID), made of Rune's
   library. Compiled after prologue.sml; the generated stubs.sml then gives
   every primitive this file does not implement a value that raises
   XC2.Unimplemented. *)
(* The tables of MLKit's PolyTable and TableSlice functors, which basis.patch
   gives their operations: an array is XC2's array, a vector Rune's, which a
   functor makes by filling an array and then fromArray *)
structure XC2KArrayTable =
struct
  val sub0 = XC2.Array.sub
  val update0 = XC2.Array.update
  val length = XC2.Array.length
  val length0 = length
  fun fromArray (a : 'a XC2.array) = a
  (* an array of n elements x: the first update makes every cell x *)
  fun array (n, x) =
    let val a = XC2.Array.alloc n in if n > 0 then XC2.Array.update (a, 0, x) else (); a end
end
structure XC2KVectorTable =
struct
  val sub0 = Vector.sub
  fun update0 (_ : 'a vector, _ : int, _ : 'a) : unit = raise Fail "xc2: a vector is not updated"
  val length = Vector.length
  val length0 = length
  val fromArray = XC2.Array.toVector
end

(* The four instances of MLKit's ByteTable functor, which basis.patch gives
   their operations: a vector is Rune's string, a chararray an array of
   XC2's of chars, and a word8 is the char of its code *)
structure XC2KBytes =
struct
  fun c2w c = Word8.fromInt (Char.ord c)
  fun w2c w = Char.chr (Word8.toInt w)
  fun string (a : char XC2.array) = CharVector.tabulate (XC2.Array.length a, fn i => XC2.Array.sub (a, i))
  fun wstring (a : Word8.word XC2.array) = CharVector.tabulate (XC2.Array.length a, fn i => w2c (XC2.Array.sub (a, i)))
  fun noUpdate _ = raise Fail "xc2: a string is not updated"
end
structure XC2KCharString =
struct
  val sub_unsafe = String.sub val update_unsafe : string * int * char -> unit = XC2KBytes.noUpdate
  val length = String.size val fromArray = XC2KBytes.string
  val length0 = length
  val sub_vector_unsafe = String.sub val length_vector = String.size val vectorFromArray = XC2KBytes.string
end
structure XC2KWord8String =
struct
  fun sub_unsafe (s, i) = XC2KBytes.c2w (String.sub (s, i))
  val update_unsafe : string * int * Word8.word -> unit = XC2KBytes.noUpdate
  val length = String.size val fromArray = XC2KBytes.wstring
  val length0 = length
  val sub_vector_unsafe = sub_unsafe val length_vector = String.size val vectorFromArray = XC2KBytes.wstring
end
structure XC2KCharArray =
struct
  val sub_unsafe : char XC2.array * int -> char = XC2.Array.sub
  val update_unsafe : char XC2.array * int * char -> unit = XC2.Array.update
  val length : char XC2.array -> int = XC2.Array.length
  val length0 = length
  fun fromArray (a : char XC2.array) = a
  val sub_vector_unsafe = String.sub val length_vector = String.size val vectorFromArray = XC2KBytes.string
end
structure XC2KWord8Array =
struct
  fun sub_unsafe (a : char XC2.array, i) = XC2KBytes.c2w (XC2.Array.sub (a, i))
  fun update_unsafe (a : char XC2.array, i, w) = XC2.Array.update (a, i, XC2KBytes.w2c w)
  val length : char XC2.array -> int = XC2.Array.length
  val length0 = length
  (* a new chararray, of the chars of the word8s *)
  fun fromArray (a : Word8.word XC2.array) : char XC2.array =
    let val n = XC2.Array.length a
        val c = XC2.Array.alloc n
        fun loop i = if i < n then (XC2.Array.update (c, i, XC2KBytes.w2c (XC2.Array.sub (a, i))); loop (i + 1)) else ()
    in loop 0; c end
  fun sub_vector_unsafe (s, i) = XC2KBytes.c2w (String.sub (s, i))
  val length_vector = String.size val vectorFromArray = XC2KBytes.wstring
end

(* C's printf of a real, %.Pe, %.Pf and %.Pg (the first two the machine's,
   %g made of them by C's rule), made SML's as MLKit's runtime makes it
   (mkSMLMinus: ~ for -, no +, E, and no leading zeros in the exponent) *)
structure XC2KFloat =
struct
  val fmtE = _prim "real_fmt_e" : real * int -> string
  val fmtF = _prim "real_fmt_f" : real * int -> string
  (* C's printf of a real with %.Pe, %.Pf or %.Pg *)
  fun cprintf (conv, p, x) =
    if Real.isNan x then (if Real.signBit x then "-nan" else "nan")
    else if not (Real.isFinite x) then (if x < 0.0 then "-inf" else "inf")
    else
      case conv of
        #"e" => fmtE (x, p)
      | #"f" => fmtF (x, p)
      | _ =>
          let
            val p = if p = 0 then 1 else p
            fun parts t = case String.fields (fn c => c = #"e") t of [m, ex] => (m, ex) | _ => (t, "0")
            fun expOf ex = valOf (Int.fromString (String.translate (fn #"+" => "" | #"-" => "~" | c => str c) ex))
            val e = expOf (#2 (parts (fmtE (x, p - 1))))
            (* the trailing zeros of the fraction, and then its point *)
            fun trim t =
              if not (CharVector.exists (fn c => c = #".") t) then t
              else Substring.string (Substring.dropr (fn c => c = #".") (Substring.dropr (fn c => c = #"0") (Substring.full t)))
          in
            if e < p andalso e >= ~4 then trim (fmtF (x, p - 1 - e))
            else let val (m, ex) = parts (fmtE (x, p - 1)) in trim m ^ "e" ^ ex end
          end
  (* MLKit's mkSMLMinus: no '+', '~' for '-', 'E' for 'e', and the exponent
     without its leading zeros *)
  fun smlMinus t =
    let
      val t = String.translate (fn #"+" => "" | #"-" => "~" | #"e" => "E" | c => str c) t
    in
      case String.fields (fn c => c = #"E") t of
        [m, ex] =>
          let val (sg, ds) = if String.isPrefix "~" ex then ("~", String.extract (ex, 1, NONE)) else ("", ex)
              val ds = Substring.string (Substring.dropl (fn c => c = #"0") (Substring.full ds))
          in m ^ "E" ^ sg ^ (if ds = "" then "0" else ds) end
      | _ => t
    end
  (* generalStringOfFloat: printf of the format %.Pe, %.Pf or %.Pg (P 6
     when it is not given), made SML's *)
  fun printf (format, x) =
    let
      val n = size format
      val conv = String.sub (format, n - 1)
      val p = if n > 3 then getOpt (Int.fromString (String.substring (format, 2, n - 3)), 6) else 6
      val t = smlMinus (cprintf (conv, p, x))
    in if t = "~nan" then "nan" else t end
  (* stringOfFloat: %.12g, and .0 when it has no point, E or n *)
  fun toString x =
    let val t = smlMinus (cprintf (#"g", 12, x))
        val t = if CharVector.exists (fn c => c = #"." orelse c = #"E" orelse c = #"n") t then t else t ^ ".0"
    in if t = "~nan" then "nan" else t end
end

(* the rounding modes of MLKit's runtime: 0 nearest, 1 down, 2 up, 3 zero *)
structure XC2KRound =
struct
  fun get () = case IEEEReal.getRoundingMode () of
                 IEEEReal.TO_NEAREST => 0 | IEEEReal.TO_NEGINF => 1 | IEEEReal.TO_POSINF => 2 | IEEEReal.TO_ZERO => 3
  fun set m = IEEEReal.setRoundingMode (case m of 1 => IEEEReal.TO_NEGINF | 2 => IEEEReal.TO_POSINF | 3 => IEEEReal.TO_ZERO | _ => IEEEReal.TO_NEAREST)
end

(* the words of 32 and 64 bits and Rune's word, by way of LargeWord (Rune's
   word and int are MLKit's of 63 bits; those of 31 bits have types of their
   own: prologue.sml) *)
structure XC2KBits =
struct
  fun w32 (w : word) = Word32.fromLarge (Word.toLarge w)
  fun wLarge (w : Word32.word) = Word.fromLarge (Word32.toLarge w)
  fun w64 (w : word) = Word.toLarge w
  fun w64X (w : word) = Word.toLargeX w
end

structure XC2KPrimImpl =
struct
  open XC2KBits
  (* _export: the functions MLKit's library gives its runtime; the one it
     has, sml_exitCallback, runs the tasks of OS.Process.atExit, and
     terminateML calls it *)
  val exitCallback : (int -> int) ref = ref (fn i => i)
  fun export ("sml_exitCallback", f : int -> int) = exitCallback := f
    | export (name, _) = raise Fail ("xc2: _export " ^ name)

  (* ---- the core ---- *)
  val EQ = op =
  val DEREF = op !
  val ASSIGN = op :=
  val ord = Char.ord
  val exnNameML = exnName
  fun concatStringML (a, b) = a ^ b
  val implodeCharsML = String.implode
  val implodeStringML = String.concat
  (* a string of MLKit's is a table of bytes; allocStringML and
     __bytetable_update, which write one in place, are left to the stubs: the
     patch builds strings whole *)
  val P__bytetable_size = String.size
  val P__bytetable_sub = String.sub
  fun P__get_ctx () = 0w0 : word

  (* ---- ints and words ---- *)
  val word64ToInt64 = _prim "word64_to_int64" : Word64.word -> Int64.int
  fun P__precision () = 63
  fun P__maxInt () = valOf Int.maxInt
  fun P__minInt () = valOf Int.minInt
  fun P__maxInt63 () = 4611686018427387903
  fun P__minInt63 () = ~4611686018427387904
  fun P__maxInt64 () = valOf Int64.maxInt
  fun P__minInt64 () = valOf Int64.minInt
  fun P__quot_int (a : int, b) = Int.quot (a, b)
  fun P__rem_int (a : int, b) = Int.rem (a, b)
  fun P__quot_int31 (a : int31, b) = XC2Int31.quot (a, b)
  fun P__rem_int31 (a : int31, b) = XC2Int31.rem (a, b)
  fun P__quot_int32 (a : Int32.int, b) = Int32.quot (a, b)
  fun P__rem_int32 (a : Int32.int, b) = Int32.rem (a, b)
  fun P__quot_int63 (a : int, b) = Int.quot (a, b)
  fun P__rem_int63 (a : int, b) = Int.rem (a, b)
  fun P__quot_int64 (a : Int64.int, b) = Int64.quot (a, b)
  fun P__rem_int64 (a : Int64.int, b) = Int64.rem (a, b)
  fun P__andb_word (a : word, b) = Word.andb (a, b)
  fun P__andb_word31 (a : word31, b) = XC2Word31.andb (a, b)
  fun P__andb_word32 (a : Word32.word, b) = Word32.andb (a, b)
  fun P__andb_word63 (a : word, b) = Word.andb (a, b)
  fun P__andb_word64 (a : Word64.word, b) = Word64.andb (a, b)
  fun P__orb_word (a : word, b) = Word.orb (a, b)
  fun P__orb_word31 (a : word31, b) = XC2Word31.orb (a, b)
  fun P__orb_word32 (a : Word32.word, b) = Word32.orb (a, b)
  fun P__orb_word63 (a : word, b) = Word.orb (a, b)
  fun P__orb_word64 (a : Word64.word, b) = Word64.orb (a, b)
  fun P__xorb_word (a : word, b) = Word.xorb (a, b)
  fun P__xorb_word31 (a : word31, b) = XC2Word31.xorb (a, b)
  fun P__xorb_word32 (a : Word32.word, b) = Word32.xorb (a, b)
  fun P__xorb_word63 (a : word, b) = Word.xorb (a, b)
  fun P__xorb_word64 (a : Word64.word, b) = Word64.xorb (a, b)
  (* the shifts: MLKit's library gives amounts below the width *)
  fun P__shift_left_word (w : word, k : word) = Word.<< (w, k)
  fun P__shift_left_word31 (w : word31, k : word) = XC2Word31.<< (w, k)
  fun P__shift_left_word32 (w : Word32.word, k : word) = Word32.<< (w, k)
  fun P__shift_left_word63 (w : word, k : word) = Word.<< (w, k)
  fun P__shift_left_word64 (w : Word64.word, k : word) = Word64.<< (w, k)
  fun P__shift_right_signed_word (w : word, k : word) = Word.~>> (w, k)
  fun P__shift_right_signed_word31 (w : word31, k : word) = XC2Word31.~>> (w, k)
  fun P__shift_right_signed_word32 (w : Word32.word, k : word) = Word32.~>> (w, k)
  fun P__shift_right_signed_word63 (w : word, k : word) = Word.~>> (w, k)
  fun P__shift_right_signed_word64 (w : Word64.word, k : word) = Word64.~>> (w, k)
  fun P__shift_right_unsigned_word (w : word, k : word) = Word.>> (w, k)
  fun P__shift_right_unsigned_word31 (w : word31, k : word) = XC2Word31.>> (w, k)
  fun P__shift_right_unsigned_word32 (w : Word32.word, k : word) = Word32.>> (w, k)
  fun P__shift_right_unsigned_word63 (w : word, k : word) = Word.>> (w, k)
  fun P__shift_right_unsigned_word64 (w : Word64.word, k : word) = Word64.>> (w, k)
  (* conversions: X extends the sign; the others raise Overflow for a value
     the result cannot hold *)
  fun P__int31_to_int (i : int31) = XC2Int31.toInt i
  fun P__int31_to_int32 (i : int31) = Int32.fromInt (XC2Int31.toInt i)
  fun P__int32_to_int (i : Int32.int) = Int32.toInt i
  fun P__int32_to_int31 (i : Int32.int) = XC2Int31.fromInt (Int32.toInt i)
  fun P__int32_to_int64 (i : Int32.int) = Int64.fromInt (Int32.toInt i)
  fun P__int32_to_word32 (i : Int32.int) = Word32.fromInt (Int32.toInt i)
  fun P__int63_to_int (i : int) = i
  fun P__int63_to_int64 (i : int) = Int64.fromInt i
  fun P__int64_to_int (i : Int64.int) = Int64.toInt i
  fun P__int64_to_int63 (i : Int64.int) = Int64.toInt i
  val P__int64_to_word64 = _prim "word64_from_int64" : Int64.int -> Word64.word
  fun P__int_to_int31 (i : int) = XC2Int31.fromInt i
  fun P__int_to_int32 (i : int) = Int32.fromInt i
  fun P__int_to_int63 (i : int) = i
  fun P__int_to_int64__int__int64 (i : int) = Int64.fromInt i
  fun P__int_to_int64__int__word64 (i : int) = Word64.fromInt i
  fun P__word31_to_word (w : word31) = Word.fromLarge (XC2Word31.toLarge w)
  fun P__word31_to_word32 (w : word31) = Word32.fromLarge (XC2Word31.toLarge w)
  fun P__word31_to_word32_X (w : word31) = Word32.fromLarge (XC2Word31.toLargeX w)
  fun P__word31_to_word64 (w : word31) = XC2Word31.toLarge w
  fun P__word31_to_word64_X (w : word31) = XC2Word31.toLargeX w
  fun P__word31_to_word_X (w : word31) = Word.fromLarge (XC2Word31.toLargeX w)
  fun P__word32_to_int (w : Word32.word) = Word32.toInt w
  fun P__word32_to_int32 (w : Word32.word) = Int32.fromInt (Word32.toInt w)
  fun P__word32_to_int32_X (w : Word32.word) = Int32.fromInt (Word32.toIntX w)
  fun P__word32_to_int_X (w : Word32.word) = Word32.toIntX w
  fun P__word32_to_word (w : Word32.word) = wLarge w
  fun P__word32_to_word31 (w : Word32.word) = XC2Word31.fromLarge (Word32.toLarge w)
  fun P__word32_to_word64 (w : Word32.word) = Word32.toLarge w
  fun P__word32_to_word64_X (w : Word32.word) = Word32.toLargeX w
  fun P__word63_to_word (w : word) = w
  val P__word63_to_word64 = w64
  val P__word63_to_word64_X = w64X
  fun P__word63_to_word_X (w : word) = w
  fun P__word64_to_int (w : Word64.word) = Word64.toInt w
  fun P__word64_to_int64 (w : Word64.word) = if Word64.>= (w, 0wx8000000000000000) then raise Overflow else word64ToInt64 w
  val P__word64_to_int64_X = word64ToInt64
  fun P__word64_to_int_X (w : Word64.word) = Word64.toIntX w
  fun P__word64_to_word (w : Word64.word) = Word.fromLarge w
  fun P__word64_to_word31 (w : Word64.word) = XC2Word31.fromLarge w
  fun P__word64_to_word32 (w : Word64.word) = Word32.fromLarge w
  fun P__word64_to_word63 (w : Word64.word) = Word.fromLarge w
  fun P__word_to_word31 (w : word) = XC2Word31.fromLarge (Word.toLarge w)
  fun P__word_to_word32 (w : word) = w32 w
  fun P__word_to_word32_X (w : word) = w32 w
  fun P__word_to_word63 (w : word) = w
  val P__word_to_word64 = w64
  val P__word_to_word64_X = w64X
  (* the casts of prim ("id", x), by their types (rewrite.awk) *)
  fun id__Char_char__Word8_word c = Word8.fromInt (Char.ord c)
  fun id__Word8_word__Char_char w = Char.chr (Word8.toInt w)
  fun id__int31__word31 (i : int31) = XC2Word31.fromInt (XC2Int31.toInt i)
  fun id__int63__word63 (i : int) = Word.fromInt i
  fun id__word31__int31 (w : word31) = XC2Int31.fromInt (XC2Word31.toIntX w)
  fun id__int__char i = Char.chr i
  (* an error number of the system: MLKit's syserror is its int *)
  fun id__int__syserror (i : int) = i
  fun id__int__OS_syserror (i : int) = i
  fun id__unit__char (_ : int) = #"\000"
  fun id__int__word i = Word.fromInt i
  fun id__word__int w = Word.toIntX w
  fun id__word8__int w = Word8.toInt w
  fun id__word8__word w = Word.fromLarge (Word8.toLarge w)
  fun id__word__word8 w = Word8.fromLarge (Word.toLarge w)

  (* ---- reals ---- *)
  fun posInfFloat () = Real.posInf
  fun negInfFloat () = Real.negInf
  fun maxFiniteFloat () = Real.maxFinite
  fun P__maxIntReal () = Real.fromInt (valOf Int.maxInt)
  fun P__minIntReal () = Real.fromInt (valOf Int.minInt)
  val P__max_real = Real.max
  val P__min_real = Real.min
  fun P__real_to_int (x : real) = Real.trunc x
  val divFloat = op / : real * real -> real
  val sqrtFloat = Math.sqrt val lnFloat = Math.ln val expFloat = Math.exp
  val sinFloat = Math.sin val cosFloat = Math.cos val tanFloat = Math.tan
  val asinFloat = Math.asin val acosFloat = Math.acos val atanFloat = Math.atan
  val atan2Float = Math.atan2 val powFloat = Math.pow
  val sinhFloat = Math.sinh val coshFloat = Math.cosh val tanhFloat = Math.tanh
  val copysignFloat = Real.copySign
  val isnanFloat = Real.isNan
  val isnormalFloat = Real.isNormal
  val signbitFloat = Real.signBit
  val nextafterFloat = Real.nextAfter
  val remFloat = Real.rem
  val realCeil = Real.realCeil val realFloor = Real.realFloor
  val realRound = Real.realRound val realTrunc = Real.realTrunc
  val realInt = Real.fromInt
  fun ceilFloat (_ : word, x) = Real.ceil x
  fun floorFloat (_ : word, x) = Real.floor x
  fun truncFloat (_ : word, x) = Real.trunc x
  fun frexpFloat x =
    if Real.isFinite x andalso Real.!= (x, 0.0) then let val {man, exp} = Real.toManExp x in (man, exp) end
    else (x, 0)
  fun ldexpFloat (x, e) = Real.fromManExp {man = x, exp = e}
  fun splitFloat x = let val {whole, frac} = Real.split x in (whole, frac) end
  val stringOfFloat = XC2KFloat.toString
  val generalStringOfFloat = XC2KFloat.printf
  (* C's strtod, in the rounding mode *)
  fun strtodFloat s = getOpt ((_prim "real_from_string" : string -> real option) s, 0.0)
  val floatGetRoundingMode = XC2KRound.get
  val floatSetRoundingMode = XC2KRound.set
  (* the 8 bytes of a real, the least significant first (not by PackRealLittle,
     whose file brings PackWord16Big and the rest, which MLKit lacks) *)
  val toBits = _prim "real_to_bits" : real -> Word64.word
  val fromBits = _prim "real_from_bits" : Word64.word -> real
  fun sml_real_to_bytes x =
    let val w = toBits x
    in CharVector.tabulate (8, fn i => Char.chr (Word64.toInt (Word64.andb (Word64.>> (w, Word.fromInt (8 * i)), 0w255)))) end
  fun sml_bytes_to_real s =
    fromBits (CharVector.foldr (fn (c, w) => Word64.orb (Word64.<< (w, 0w8), Word64.fromInt (Char.ord c))) 0w0 s)

  (* ---- the process: C's errno is kept here, set by the calls that fail ---- *)
  val errno = ref 0
  fun check (r : int) = (if r = ~1 then errno := XC2Sys.sysErrno () else (); r)
  fun fail () = (errno := XC2Sys.sysErrno (); ~1)
  fun sml_errno () = !errno
  fun sml_errormsg (e : int) = XC2Sys.errorMsg e
  fun sml_errorName (e : int) = (_prim "sys_error_name" : int -> string) e
  (* a named constant, ~1 when the system has none (MLKit's tables do the same) *)
  fun AT_sml_syserror (s : string) = XC2Sys.posixConst s
  fun AT_sml_findsignal (s : string) = XC2Sys.posixConst s
  (* the constants of termios, by the index of MLKit's table sml_ttyVals *)
  local
    val names = Vector.fromList ["VEOF", "VEOL", "VERASE", "VINTR", "VKILL", "VMIN", "VQUIT", "VSUSP", "VTIME", "VSTART", "VSTOP",
      "BRKINT", "ICRNL", "IGNBRK", "IGNCR", "IGNPAR", "INLCR", "INPCK", "ISTRIP", "IXOFF", "IXON", "PARMRK", "OPOST",
      "CLOCAL", "CREAD", "CS5", "CS6", "CS7", "CS8", "CSIZE", "CSTOPB", "HUPCL", "PARENB", "PARODD", "ECHO", "ECHOE",
      "ECHOK", "ECHONL", "ICANON", "IEXTEN", "ISIG", "NOFLSH", "TOSTOP", "", "I*", "C*", "L*", "", "B0", "B50", "B75",
      "B110", "B134", "B150", "B200", "B300", "B600", "B1200", "B1800", "B2400", "B4800", "B9600", "B19200", "B38400",
      "B57600", "B115200", "B230400", "", "", "", "NCCS"]
    fun c n = case XC2Sys.posixConst n of ~1 => 0 | v => v
    fun ors l = List.foldl (fn (n, a) => Word.toInt (Word.orb (Word.fromInt a, Word.fromInt (c n)))) 0 l
    fun tty i =
      case Vector.sub (names, i) of
        "" => 0
      | "I*" => ors ["BRKINT", "ICRNL", "IGNBRK", "IGNCR", "IGNPAR", "INLCR", "INPCK", "ISTRIP", "IXOFF", "IXON", "PARMRK"]
      | "C*" => ors ["CLOCAL", "CREAD", "CS5", "CS6", "CS7", "CS8", "CSIZE", "CSTOPB", "HUPCL", "PARENB", "PARODD"]
      | "L*" => ors ["ECHO", "ECHOE", "ECHOK", "ECHONL", "ICANON", "IEXTEN", "ISIG", "NOFLSH", "TOSTOP"]
      | n => c n
  in
    fun AT_sml_getTty (i : int) = tty i
  end
  fun sml_setFailNumber (_ : exn, _ : int) = ()
  fun get_time_base (_ : int) = 0
  fun sml_getrealtime () = let val t = XC2Sys.timeNow () in {sec = t div 1000000, usec = t mod 1000000} end
  fun sml_getrutime () =
    let val u = (_prim "time_user" : unit -> int) () val s = (_prim "time_sys" : unit -> int) ()
        val gu = (_prim "time_gc_user" : unit -> int) ()
    in {gcSec = gu div 1000000, gcUsec = gu mod 1000000, sysSec = s div 1000000, sysUsec = s mod 1000000,
        usrSec = u div 1000000, usrUsec = u mod 1000000}
    end
  (* mktime (gmtime (now)) - now, as MLKit's tm2cal of the broken-down UTC *)
  fun sml_localoffset () : real =
    let val now = XC2Sys.timeNow () div 1000000
    in case XC2Sys.dateSeconds (XC2Sys.dateParts (now, 0), 1) of t :: _ => Real.fromInt (t - now) | [] => 0.0 end
  fun sml_commandline_name () = CommandLine.name ()
  fun sml_commandline_args () = CommandLine.arguments ()
  fun sml_getStdNumbers () = (0, 1, 2)
  (* MLKit's streams of C (FILE * of fopen): the file system's
     OS.FileSys.tmpName makes its file with them. Only opening for writing
     and closing are left: the library's TextIO is not built on them. *)
  fun openOutStream (_ : word, path : string, e : exn) =
    case XC2Sys.openf (path, XC2Sys.posixConst "O_WRONLY" + XC2Sys.posixConst "O_CREAT" + XC2Sys.posixConst "O_TRUNC", 438) of
      ~1 => (ignore (fail ()); raise e)
    | fd => fd
  fun closeStream (fd : int) = ignore (XC2Sys.close fd)
  fun stdInStream (_ : int) = 0
  fun stdOutStream (_ : int) = 1
  fun stdErrStream (_ : int) = 2
  fun printStringML s = ignore (XC2Sys.write (1, s))
  (* terminateML: the tasks of atExit (the callback), then the end *)
  fun terminateML (status : int) = (ignore ((!exitCallback) 0) handle _ => (); XC2Sys.exit status)
  fun AT_exit (status : int) : unit = XC2Sys.exit status
  (* ---- descriptors ---- *)
  fun AT_sml_writeVec (fd, s : string, i, n) = check (XC2Sys.write (fd, String.substring (s, i, n)))
  (* (the bytes, how many), ~1 on failure *)
  fun sml_readVec (fd, n) =
    let val s = XC2Sys.read (fd, n)
    in if s = "" andalso XC2Sys.sysErrno () <> 0 then ("", fail ()) else (s, size s) end
  fun AT_sml_readArr (fd, a : char XC2.array, i, n) =
    let val (s, r) = sml_readVec (fd, n)
    in CharVector.appi (fn (k, c) => XC2.Array.update (a, i + k, c)) s; r end
  fun AT_close (fd : int) = check (XC2Sys.close fd)
  fun AT_sml_dup2 (a : int, b : int) = check (XC2Sys.dup2 (a, b))
  fun AT_sml_dupfd (fd : int, base : int) = check (XC2Sys.fcntl (fd, XC2Sys.posixConst "F_DUPFD", base))
  fun AT_sml_getfd (fd : int) = check (XC2Sys.fcntl (fd, XC2Sys.posixConst "F_GETFD", 0))
  fun AT_sml_setfd (fd : int, f : int) = check (XC2Sys.fcntl (fd, XC2Sys.posixConst "F_SETFD", f))
  (* the flags of a descriptor in MLKit's bits: 0x1 O_APPEND, 0x8 O_NONBLOCK,
     0x10 O_SYNC; getfl adds 0x100 for O_RDONLY (which is 0, so never, as in
     MLKit's C), 0x200 O_WRONLY and 0x400 O_RDWR *)
  local
    val c = XC2Sys.posixConst
    fun has (x, b) = Word.andb (Word.fromInt x, Word.fromInt b) <> 0w0
    fun bit (x, b, m) = if has (x, b) then m else 0
  in
    fun AT_sml_getfl (fd : int) =
      case check (XC2Sys.fcntl (fd, c "F_GETFL", 0)) of
        ~1 => ~1
      | r => bit (r, c "O_APPEND", 0x1) + bit (r, c "O_NONBLOCK", 0x8) + bit (r, c "O_SYNC", 0x10)
             + bit (r, c "O_RDONLY", 0x100) + bit (r, c "O_WRONLY", 0x200) + bit (r, c "O_RDWR", 0x400)
    fun AT_sml_setfl (fd : int, f : int) =
      check (XC2Sys.fcntl (fd, c "F_SETFL", bit (f, 0x1, c "O_APPEND") + bit (f, 0x8, c "O_NONBLOCK") + bit (f, 0x10, c "O_SYNC")))
  end
  (* whence: 0 SEEK_SET, 1 SEEK_END, anything else SEEK_CUR *)
  fun sml_lseek (fd, p, w) = check (XC2Sys.lseek (fd, p, case w of 0 => XC2Sys.posixConst "SEEK_SET" | 1 => XC2Sys.posixConst "SEEK_END" | _ => XC2Sys.posixConst "SEEK_CUR"))
  fun sml_pipe () = case XC2Sys.pipe () of [r, w] => (0, r, w) | _ => (fail (), ~1, ~1)
  fun AT_isatty (fd : int) = XC2Sys.isatty fd = 1
  (* ---- the file system: a call that fails sets errno and raises the
     exception MLKit gives it, as MLKit's runtime does ---- *)
  fun orRaise (r, e : exn) = if r = ~1 then (ignore (fail ()); raise e) else ()
  (* stat: 8 ints, MLKit's (sml_statA): the kind bits (reg dir chr blk fifo
     lnk sock, 6 to 0), the mode bits (isgid isuid xoth woth roth rwxo xgrp
     wgrp rgrp rwxg xusr wusr rusr rwxu, 13 to 0), ino, dev, nlink, size, uid,
     gid; the first ~1 on failure *)
  fun statOf [] = (fail (), 0, 0, 0, 0, 0, 0, 0)
    | statOf (kind :: mode :: ino :: dev :: nlink :: uid :: gid :: size :: _) =
        let
          fun bit (b, n) = if b then n else 0
          val kbits = bit (kind = 0, 64) + bit (kind = 1, 32) + bit (kind = 6, 16) + bit (kind = 7, 8)
                      + bit (kind = 4, 4) + bit (kind = 2, 2) + bit (kind = 5, 1)
          fun has m = Word.andb (Word.fromInt mode, Word.fromInt m) <> 0w0
          val mbits =
            bit (has 1024, 8192) + bit (has 2048, 4096) + bit (has 1, 2048) + bit (has 2, 1024) + bit (has 4, 512)
            + bit (has 7, 256) + bit (has 8, 128) + bit (has 16, 64) + bit (has 32, 32) + bit (has 56, 16)
            + bit (has 64, 8) + bit (has 128, 4) + bit (has 256, 2) + bit (has 448, 1)
        in (kbits, mbits, ino, dev, nlink, size, uid, gid) end
    | statOf _ = (fail (), 0, 0, 0, 0, 0, 0, 0)
  fun sml_stat (p : string) = statOf (XC2Sys.stat (p, 0, ~1))
  fun sml_lstat (p : string) = statOf (XC2Sys.stat (p, 1, ~1))
  fun sml_fstat (fd : int) = statOf (XC2Sys.stat ("", 0, fd))
  fun kindOf (l, e) = case l of k :: _ => k | [] => (ignore (fail ()); raise e)
  fun sml_isdir (_ : word, p, e) = kindOf (XC2Sys.stat (p, 0, ~1), e) = 1
  fun sml_islink (_ : word, p, e) = kindOf (XC2Sys.stat (p, 1, ~1), e) = 2
  fun sml_isreg__string__bool (_ : word, p, e) = kindOf (XC2Sys.stat (p, 0, ~1), e) = 0
  fun sml_isreg__file_desc__bool (_ : word, fd, e) = kindOf (XC2Sys.stat ("", 0, fd), e) = 0
  fun field k (l, e) = case l of [] => (ignore (fail ()); raise e) | l => List.nth (l, k)
  fun sml_filesize (_ : word, p, e) = field 7 (XC2Sys.stat (p, 0, ~1), e)
  fun sml_filesizefd (_ : word, fd, e) = field 7 (XC2Sys.stat ("", 0, fd), e)
  fun sml_modtime (_ : word, p, e) = Real.fromInt (field 9 (XC2Sys.stat (p, 0, ~1), e))
  fun sml_settime (_ : word, p, r : real, e) = let val t = Real.trunc r in orRaise (XC2Sys.utime (p, t, t), e) end
  fun sml_devinode (_ : word, p, e) =
    case XC2Sys.stat (p, 0, ~1) of _ :: _ :: ino :: dev :: _ => {dev = dev, ino = ino} | _ => (ignore (fail ()); raise e)
  (* MLKit's bits: 1 read, 2 write, 4 execute, as the machine's *)
  fun sml_access (p : string, perm : int) = XC2Sys.osAccess (p, perm, 0) = 1
  fun sml_chdir (_ : word, p, e) = orRaise (XC2Sys.osChdir p, e)
  fun sml_remove (_ : word, p, e) = orRaise (XC2Sys.osRemove p, e)
  fun sml_rename (_ : word, a, b, e) = orRaise (XC2Sys.osRename (a, b), e)
  fun sml_rmdir (_ : word, p, e) = orRaise (XC2Sys.osRmdir p, e)
  fun sml_mkdir (_ : word, p, e) = orRaise (XC2Sys.osMkdir p, e)
  fun sml_getdir (_ : word, e) = case XC2Sys.osGetcwd () of "" => (ignore (fail ()); raise e) | d => d
  fun sml_readlink (_ : word, p, e) = case XC2Sys.osReadLink p of "" => (ignore (fail ()); raise e) | l => l
  fun sml_realpath (_ : word, p, e) = case (_prim "os_real_path" : string -> string) p of "" => (ignore (fail ()); raise e) | l => l
  fun sml_opendir (_ : word, p, e) = case XC2Sys.osOpenDir p of ~1 => (ignore (fail ()); raise e) | d => d
  fun sml_readdir (_ : word, d : int, e) = case XC2Sys.osReadDir d of SOME n => n | NONE => raise e
  fun sml_rewinddir (d : int) = ignore (XC2Sys.osRewindDir d)
  fun sml_closedir (_ : word, d : int, e) = orRaise (XC2Sys.osCloseDir d, e)

  (* ---- processes ---- *)
  fun AT_fork () = check (XC2Sys.fork ())
  fun AT_getpid () = XC2Sys.getpid () fun AT_getppid () = XC2Sys.getppid ()
  fun AT_getuid () = XC2Sys.getuid () fun AT_geteuid () = XC2Sys.geteuid ()
  fun AT_getgid () = XC2Sys.getgid () fun AT_getegid () = XC2Sys.getegid ()
  fun AT_getpgrp () = XC2Sys.getpgrp ()
  fun AT_setsid () = check (XC2Sys.setsid ())
  fun AT_setpgid (p : int, g : int) = check (XC2Sys.setpgid (p, g))
  fun AT_setgid (g : int) = check (XC2Sys.setgid g)
  fun AT_setuid (u : int) = check (XC2Sys.setuid u)
  fun AT_kill (p : int, s : int) = check (XC2Sys.kill (p, s))
  fun AT_alarm (s : int) = XC2Sys.alarm s
  fun AT_pause () = ignore (XC2Sys.pause ())
  (* a status of the machine's (how, value) as C's of wait *)
  fun cstatus (how, v) = case how of 0 => v * 256 | 1 => v | _ => v * 256 + 127
  (* MLKit's flags: 1 WUNTRACED, 2 WNOHANG *)
  fun sml_waitpid (p : int, flags : int) =
    let val f = (if flags mod 2 = 1 then XC2Sys.posixConst "WUNTRACED" else 0)
              + (if flags div 2 mod 2 = 1 then XC2Sys.posixConst "WNOHANG" else 0)
    in case XC2Sys.waitpid (p, f) of [pid, how, v] => (pid, cstatus (how, v)) | _ => (fail (), 0) end
  fun sml_WIFEXITED (s : int) = s mod 128 = 0
  fun sml_WEXITSTATUS (s : int) = s div 256 mod 256
  fun sml_WIFSIGNALED (s : int) = s mod 128 <> 0 andalso s mod 128 <> 127
  fun sml_WTERMSIG (s : int) = s mod 128
  fun sml_WIFSTOPPED (s : int) = s mod 256 = 127
  fun sml_WSTOPSIG (s : int) = s div 256 mod 256
  (* exec: the environment when it is given (else the process's), PATH
     searched when kind is 0 (execvp), not when it is 1 (execv) *)
  fun sml_exec (path : string, args : string list, env : string list, kind : int) =
    check (if null env then XC2Sys.exec (path, args, if kind = 0 then 1 else 0) else XC2Sys.exece (path, args, env))
  (* 0 when the command succeeded, ~1 otherwise *)
  fun sml_system (cmd : string) = case XC2Sys.system cmd of 0 => 0 | _ => ~1
  fun sml_times (_ : word) =
    case XC2Sys.times () of
      [_, u, s, cu, cs] => (u div 1000000, u mod 1000000, s div 1000000, s mod 1000000,
                            cu div 1000000, cu mod 1000000, cs div 1000000, cs mod 1000000)
    | _ => raise Overflow
  fun sml_microsleep (s : int, u : int) = ((_prim "time_sleep" : int -> unit) (s * 1000000 + u); (0, 0, 0))
  fun sml_gettime () = let val t = XC2Sys.timeNow () div 1000000 in (t mod 1000000000, t div 1000000000, 0) end
  (* ---- the environment ---- *)
  fun sml_environ () = XC2Sys.environ ()
  fun sml_getenv (_ : word, s, e) = case XC2Sys.getenv s of SOME v => v | NONE => raise e
  fun sml_getlogin () = XC2Sys.getlogin ()
  fun sml_ctermid () = XC2Sys.ctermid ()
  (* a NULL string of C's: P__is_null tells it *)
  val cNull = "\^@xc2 NULL\^@"
  fun P__is_null (s : string) = s = cNull
  (* (0, the name), or (errno, NULL) *)
  fun sml_ttyname (fd : int) = case XC2Sys.ttyname fd of "" => (ignore (fail ()); (!errno, cNull)) | s => (0, s)
  fun sml_uname () =
    case XC2Sys.uname () of
      [a, b, c, d, e] => [("sysname", a), ("nodename", b), ("release", c), ("version", d), ("machine", e)]
    | _ => (ignore (fail ()); [])
  fun sml_getgroups (_ : word, _ : exn) = (0, XC2Sys.getgroups ())
  (* sysconf: the names of MLKit's numbers *)
  fun sml_sysconf (_ : word, t : int) =
    let val n = case t of 1 => "ARG_MAX" | 2 => "CHILD_MAX" | 3 => "CLK_TCK" | 4 => "NGROUPS_MAX"
                        | 5 => "OPEN_MAX" | 6 => "STREAM_MAX" | 7 => "TZNAME_MAX" | 8 => "JOB_CONTROL"
                        | 9 => "SAVED_IDS" | 10 => "VERSION" | 11 => "GETGR_R_SIZE_MAX" | 12 => "GETPW_R_SIZE_MAX"
                        | _ => raise Overflow
    in
      (* Rune's machine does not know the last two; glibc's sysconf gives 1024 *)
      if t >= 11 then 1024 else XC2Sys.sysconf n
    end
  (* pathconf: ~2 for no limit *)
  fun pcName k = case k of 0 => "CHOWN_RESTRICTED" | 1 => "LINK_MAX" | 2 => "MAX_CANON" | 3 => "MAX_INPUT"
                         | 4 => "NAME_MAX" | 5 => "NO_TRUNC" | 6 => "PATH_MAX" | 7 => "PIPE_BUF"
                         | 8 => "VDISABLE" | 9 => "ASYNC_IO" | 10 => "SYNC_IO" | _ => "PRIO_IO"
  fun pathconf (p, fd, k) = case XC2Sys.pathconf (p, fd, pcName k) of [~1] => ~2 | [v] => v | _ => fail ()
  fun AT_sml_pathconf (p : string, k : int) = pathconf (p, ~1, k)
  fun AT_sml_fpathconf (fd : int, k : int) = pathconf ("", fd, k)
  (* ---- the system databases: a record of the entry and 0, or the exception ---- *)
  fun num s = getOpt (Int.fromString s, 0)
  fun pw (l, e) = case l of [n, dir, sh, u, g] => (n, num u, num g, dir, sh) | _ => raise e
  (* the name "" is no user (Rune's machine takes it for a lookup by number) *)
  fun sml_getpwnam (_ : word, n, _ : int, e) = let val (_, u, g, h, s) = pw (if n = "" then [] else XC2Sys.getpw (n, 0), e) in (u, g, h, s, 0) end
  fun sml_getpwuid (_ : word, u, _ : int, e) = let val (n, _, g, h, s) = pw (XC2Sys.getpw ("", u), e) in (n, g, h, s, 0) end
  fun gr (l, e) = case l of n :: g :: m => (n, num g, m) | _ => raise e
  fun sml_getgrnam (_ : word, n, _ : int, e) = let val (_, g, m) = gr (if n = "" then [] else XC2Sys.getgr (n, 0), e) in (g, m, 0) end
  fun sml_getgrgid (_ : word, g, _ : int, e) = let val (n, _, m) = gr (XC2Sys.getgr ("", g), e) in (n, m, 0) end
  (* ---- open, umask, mkdir, mkfifo, chmod: MLKit's sml_lower, whose chmod
     and fchmod are given the flags of open for the mode, as MLKit's are ---- *)
  fun AT_sml_lower (name : string, rwx : int, flags : int, perm : int, i : int, kind : int) =
    let
      val c = XC2Sys.posixConst
      fun has (x, b) = x div b mod 2 = 1
      val f = (case rwx of 1 => c "O_WRONLY" | 2 => c "O_RDWR" | _ => c "O_RDONLY")
              + (if has (flags, 1) then c "O_APPEND" else 0) + (if has (flags, 2) then c "O_EXCL" else 0)
              + (if has (flags, 4) then c "O_NOCTTY" else 0) + (if has (flags, 8) then c "O_NONBLOCK" else 0)
              + (if has (flags, 16) then c "O_SYNC" else 0) + (if has (flags, 32) then c "O_TRUNC" else 0)
      val bits = [(1, 448), (2, 256), (4, 128), (8, 64), (16, 56), (32, 32), (64, 16), (128, 8),
                  (256, 7), (512, 4), (1024, 2), (2048, 1), (4096, 2048), (8192, 1024)]
      val mode = List.foldl (fn ((b, m), a) => if has (perm, b) then Word.toInt (Word.orb (Word.fromInt a, Word.fromInt m)) else a) 0 bits
    in
      case kind of
        1 => check (XC2Sys.openf (name, f + c "O_CREAT", mode))
      | 2 => check (XC2Sys.openf (name, f, 0))
      | 3 => XC2Sys.umask mode
      | 4 => (* mkdir (name, mode): the mode less the umask *)
             let val mask = XC2Sys.umask 0
                 val _ = XC2Sys.umask mask
                 val m = Word.toInt (Word.andb (Word.fromInt mode, Word.notb (Word.fromInt mask)))
             in case XC2Sys.osMkdir name of ~1 => fail () | _ => check (XC2Sys.chmod (name, ~1, m)) end
      | 5 => check (XC2Sys.mkfifo (name, mode))
      | 6 => check (XC2Sys.chmod (name, ~1, f))
      | 7 => check (XC2Sys.chmod ("", i, f))
      | _ => 0
    end
  fun AT_chown (p : string, u : int, g : int) = check (XC2Sys.chown (p, ~1, u, g))
  fun AT_fchown (fd : int, u : int, g : int) = check (XC2Sys.chown ("", fd, u, g))
  fun AT_ftruncate (fd : int, n : int) = check (XC2Sys.ftruncate (fd, n))
  fun AT_link (a : string, b : string) = check (XC2Sys.link (a, b))
  fun AT_symlink (a : string, b : string) = check (XC2Sys.symlink (a, b))
  fun AT_rename (a : string, b : string) = check (XC2Sys.osRename (a, b))
  fun AT_rmdir (p : string) = check (XC2Sys.osRmdir p)
  fun AT_unlink (p : string) = check (XC2Sys.osRemove p)
  (* ---- poll: {iod, pri, rd, wr} of the descriptors ready, the last first ---- *)
  fun sml_poll (_ : word, pds : {iod : int, pri : bool, rd : bool, wr : bool} list, tm : int, e : exn) =
    let
      fun ev {iod, pri, rd, wr} = (if rd then 1 else 0) + (if wr then 2 else 0) + (if pri then 4 else 0)
      val fds = List.map #iod pds
      val got = if null fds then ((if tm > 0 then (_prim "time_sleep" : int -> unit) (tm * 1000) else ()); [])
                else case XC2Sys.osPoll (fds, List.map ev pds, if tm < 0 then ~1 else tm * 1000) of
                       [] => (ignore (fail ()); raise e) | l => l
      fun has (x, b) = x div b mod 2 = 1
    in
      List.foldl (fn ((fd, r), acc) => if r = 0 then acc else {iod = fd, pri = has (r, 4), rd = has (r, 1), wr = has (r, 2)} :: acc)
        [] (ListPair.zip (fds, got))
    end
  (* ---- sockets of the internet (Socket.c of MLKit's runtime): an address
     is a number and a port, a sockaddr_in of the machine's in between ---- *)
  local
    val create = _prim "socket_create" : int * int * int -> int
    val bind = _prim "socket_bind" : int * string -> int
    val connect = _prim "socket_connect" : int * string -> int
    val listen = _prim "socket_listen" : int * int -> int
    val accept = _prim "socket_accept" : int -> int
    val send = _prim "socket_send" : int * string * int -> int
    val recv = _prim "socket_recv" : int * int * int -> string
    val shutdown = _prim "socket_shutdown" : int * int -> int
    val name = _prim "socket_name" : int -> string
    val peer = _prim "socket_peer" : int -> string
    val getopt = _prim "socket_getopt" : int * int * int -> int
    val setopt = _prim "socket_setopt" : int * int * int * int -> int
    val hostByName = _prim "netdb_host_byname" : string -> string list
    val hostByAddr = _prim "netdb_host_byaddr" : string -> string list
    val hostname = _prim "netdb_hostname" : unit -> string
    fun byte (x, k) = Char.chr (x div k mod 256)
    fun at (s, k) = Char.ord (String.sub (s, k))
    (* family (the machine's order), port and address (the network's) *)
    fun sockaddr (a : int, p : int) =
      let val f = XC2Sys.posixConst "AF_INET"
      in String.implode ([byte (f, 1), byte (f, 256), byte (p, 256), byte (p, 1),
                          byte (a, 16777216), byte (a, 65536), byte (a, 256), byte (a, 1)]
                         @ List.tabulate (8, fn _ => #"\000"))
      end
    fun parts s = (((at (s, 4) * 256 + at (s, 5)) * 256 + at (s, 6)) * 256 + at (s, 7), at (s, 2) * 256 + at (s, 3))
    fun dotted (a : int) = String.concatWith "." (List.map (fn k => Int.toString (a div k mod 256)) [16777216, 65536, 256, 1])
    fun undotted t = List.foldl (fn (d, a) => a * 256 + getOpt (Int.fromString d, 0)) 0 (String.fields (fn c => c = #".") t)
    (* the record of sml_gethostby*: the lists are the reverse of C's order,
       as MLKit's C builds them; xerr ~1 when there is no such host *)
    fun entry l =
      case l of
        n :: addrs :: aliases =>
          {addrType = XC2Sys.posixConst "AF_INET", addrs = List.rev (List.map undotted (String.tokens Char.isSpace addrs)),
           aliases = List.rev aliases, name = n, xerr = 0}
      | _ => {addrType = XC2Sys.posixConst "AF_INET", addrs = [], aliases = [], name = "", xerr = ~1}
  in
    fun sml_sock_socket (d : int, t : int) = check (create (d, t, 0))
    fun sml_sock_bind_inet (fd : int, a : int, p : int) = check (bind (fd, sockaddr (a, p)))
    fun sml_sock_connect_inet (fd : int, a : int, p : int) = check (connect (fd, sockaddr (a, p)))
    fun sml_sock_listen (fd : int, n : int) = check (listen (fd, n))
    (* (the new socket, its address and port); Overflow on failure *)
    fun sml_sock_accept_inet (_ : word, fd : int) =
      case accept fd of
        ~1 => (ignore (fail ()); raise Overflow)
      | fd' => let val (a, p) = parts (peer fd') in (fd', a, p) end
    (* (the address, the port), the port ~1 on failure *)
    fun sml_getsockname_inet (fd : int) = case name fd of "" => (ignore (fail ()); (0, ~1)) | s => parts s
    fun sml_getpeername_inet (fd : int) = case peer fd of "" => (ignore (fail ()); (0, ~1)) | s => parts s
    fun sml_sock_sendvec (fd : int, v : string, i : int, n : int) = check (send (fd, String.substring (v, i, n), 0))
    fun sml_sock_recvvec (_ : word, fd : int, n : int) =
      case recv (fd, n, 0) of
        "" => if XC2Sys.sysErrno () <> 0 then (ignore (fail ()); raise Overflow) else ""
      | s => s
    fun AT_shutdown (fd : int, how : int) = check (shutdown (fd, how))
    (* setsockopt sets 1 when the value is true (the patch passes a bool as
       1 or 0) or the int 1, and 0 otherwise; getsockopt gives ~1 always:
       MLKit's C asks for 8 bytes and takes the 4 of Linux for a failure *)
    fun sml_sock_setsockopt (fd : int, opt : int, v : int) =
      check (setopt (fd, XC2Sys.posixConst "SOL_SOCKET", opt, if v = 1 then 1 else 0))
    fun sml_sock_getsockopt (fd : int, opt : int) = (ignore (getopt (fd, XC2Sys.posixConst "SOL_SOCKET", opt)); ~1)
    (* select: the descriptors ready, of those below the greatest one (C's
       select is given it as nfds), the last first; no timeout when t < 0 *)
    fun sml_sock_select (_ : word, rds : int list, wrs : int list, exs : int list, t : real) =
      let
        val nfds = List.foldl Int.max 0 (rds @ wrs @ exs)
        val all = List.filter (fn fd => fd < nfds) (rds @ wrs @ exs)
        fun ev fd = (if List.exists (fn x => x = fd) rds then 1 else 0) + (if List.exists (fn x => x = fd) wrs then 2 else 0)
                    + (if List.exists (fn x => x = fd) exs then 4 else 0)
        val fds = List.foldr (fn (fd, l) => if List.exists (fn x => x = fd) l then l else fd :: l) [] all
        val tm = if t < 0.0 then ~1 else Real.trunc (t * 1000000.0)
        val got = if null fds then ((if tm > 0 then (_prim "time_sleep" : int -> unit) tm else ()); [])
                  else case XC2Sys.osPoll (fds, List.map ev fds, tm) of [] => (ignore (fail ()); raise Overflow) | l => l
        val ready = ListPair.zip (fds, got)
        fun pick (l, b) = List.foldl (fn (fd, acc) =>
                            case List.find (fn (x, _) => x = fd) ready of
                              SOME (_, r) => if r div b mod 2 = 1 then fd :: acc else acc
                            | NONE => acc) [] l
      in (pick (rds, 1), pick (wrs, 2), pick (exs, 4)) end
    fun sml_gethostbyname (n : string) = entry (hostByName n)
    fun sml_gethostbyaddr (a : int) = entry (hostByAddr (dotted a))
    fun sml_gethostname () = case hostname () of "" => cNull | s => s
    fun sml_inaddr_tostring (a : int) = dotted a
  end

  (* ---- terminals: as MLKit's C (Posix.c), the actions, queues and flows by
     MLKit's numbers, a control character as its index * 256 + its value ---- *)
  val tcop = _prim "posix_tcop" : int * int * int -> int
  fun sml_tty_getattr (fd : int) =
    case XC2Sys.tcgetattr fd of
      i :: ofl :: c :: l :: is :: os :: cc =>
        (0, i, ofl, c, l, is, os, #2 (List.foldl (fn (v, (k, a)) => (k + 1, a @ [k * 256 + v])) (0, []) cc))
    | _ => (fail (), 0, 0, 0, 0, 0, 0, [])
  fun sml_tty_setattr (fd : int, action : int, i : int, ofl : int, c : int, l : int, is : int, os : int, ccl : int list, nccs : int) =
    case XC2Sys.tcgetattr fd of
      _ :: _ :: _ :: _ :: _ :: _ :: cc =>
        let
          val cc = Array.fromList cc
          fun put (k, e) = if k >= nccs then () else
                             let val idx = e div 256 in if idx >= 0 andalso idx < Array.length cc then Array.update (cc, idx, e mod 256) else () end
          val _ = List.foldl (fn (e, k) => (put (k, e); k + 1)) 0 ccl
          val act = XC2Sys.posixConst (case action of 1 => "TCSADRAIN" | 2 => "TCSAFLUSH" | _ => "TCSANOW")
        in check (XC2Sys.tcsetattr (fd, act, [i, ofl, c, l, is, os] @ Array.foldr op :: [] cc)) end
    | _ => fail ()
  fun sml_tty_sendbreak (fd : int, d : int) = check (tcop (3, fd, d))
  fun sml_tty_drain (fd : int) = check (tcop (0, fd, 0))
  fun sml_tty_flush (fd : int, q : int) =
    check (tcop (1, fd, XC2Sys.posixConst (case q of 0 => "TCIFLUSH" | 1 => "TCOFLUSH" | _ => "TCIOFLUSH")))
  fun sml_tty_flow (fd : int, a : int) =
    check (tcop (2, fd, XC2Sys.posixConst (case a of 0 => "TCOOFF" | 1 => "TCOON" | 2 => "TCIOFF" | _ => "TCION")))
  fun sml_tty_getpgrp (fd : int) = check (tcop (4, fd, 0))
  fun sml_tty_setpgrp (fd : int, p : int) = check (tcop (5, fd, p))

  (* ---- time: C's tm as MLKit's record ---- *)
  type tmoz = {tm_hour : int, tm_isdst : int, tm_mday : int, tm_min : int, tm_mon : int,
               tm_sec : int, tm_wday : int, tm_yday : int, tm_year : int}
  fun tmOf [sec, min, hour, mday, mon, year, wday, yday, isdst] : tmoz =
        {tm_hour = hour, tm_isdst = isdst, tm_mday = mday, tm_min = min, tm_mon = mon,
         tm_sec = sec, tm_wday = wday, tm_yday = yday, tm_year = year}
    | tmOf _ = raise Fail "xc2: a broken-down time"
  fun partsOf ({tm_hour, tm_isdst, tm_mday, tm_min, tm_mon, tm_sec, tm_wday, tm_yday, tm_year} : tmoz) =
    [tm_sec, tm_min, tm_hour, tm_mday, tm_mon, tm_year, tm_wday, tm_yday, tm_isdst]
  fun sml_localtime (r : real) = tmOf (XC2Sys.dateParts (Real.trunc r, 1))
  fun sml_gmtime (r : real) = tmOf (XC2Sys.dateParts (Real.trunc r, 0))
  fun sml_mktime (t : tmoz) = case XC2Sys.dateSeconds (partsOf t, 1) of s :: _ => Real.fromInt s | [] => ~1.0
  fun sml_strftime (_ : word, fmt : string, t : tmoz, _ : exn) = XC2Sys.dateFormat (fmt, partsOf t, 1)
  fun sml_asctime (_ : word, t : tmoz, _ : exn) = XC2Sys.dateFormat ("%a %b %e %H:%M:%S %Y\n", partsOf t, 1)

  (* ---- sockets ---- *)
  fun sml_sock_getDefines () =
    let val c = XC2Sys.posixConst
    in {AF_INET = c "AF_INET", AF_UNIX = c "AF_UNIX", INADDR_ANY = 0, SHUT_RD = c "SHUT_RD",
        SHUT_RDWR = c "SHUT_RDWR", SHUT_WR = c "SHUT_WR", SOCK_DGRAM = c "SOCK_DGRAM", SOCK_RAW = c "SOCK_RAW",
        SOCK_STREAM = c "SOCK_STREAM", SO_BROADCAST = c "SO_BROADCAST", SO_DEBUG = c "SO_DEBUG",
        SO_DONTROUTE = c "SO_DONTROUTE", SO_ERROR = c "SO_ERROR", SO_KEEPALIVE = c "SO_KEEPALIVE",
        SO_LINGER = c "SO_LINGER", SO_OOBINLINE = c "SO_OOBINLINE", SO_RCVBUF = c "SO_RCVBUF",
        SO_REUSEADDR = c "SO_REUSEADDR", SO_SNDBUF = c "SO_SNDBUF", SO_TYPE = c "SO_TYPE"}
    end
end

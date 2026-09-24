(* RunePrim: the primitives of vm/prims.def written on the Basis Library of a
   host system, for the xc1 configurations of tests/basis/run-matrix.sh, which
   compile lib/basis with MLton, SML/NJ and Poly/ML.

   tests/basis/host/gen-host-basis.sh turns `_prim "name"` in lib/basis into
   `RunePrim.name` and generates signature RUNE_PRIM from the TYPE column of
   vm/prims.def, so the host checks three things Rune takes on trust: that
   each `_prim` annotation in lib/basis agrees with vm/prims.def, that this
   structure does, and that lib/basis is portable Standard ML.

   Every primitive follows its description in vm/prims.def and is written
   independently of vm/prims.c. `int` and `word` are the default types of the
   host, whatever their precision. *)
structure RunePrim : RUNE_PRIM =
struct
  (* ---- int ---- *)
  val int_add = Int.+
  val int_sub = Int.-
  val int_mul = Int.*
  val int_div = Int.div
  val int_mod = Int.mod
  val int_quot = Int.quot
  val int_rem = Int.rem
  val int_neg = Int.~
  val int_abs = Int.abs
  val int_lt = Int.<
  val int_le = Int.<=
  val int_gt = Int.>
  val int_ge = Int.>=
  val int_order = Int.compare
  val int_to_string = Int.toString
  val int_from_string = Int.fromString
  val int_to_char = Char.chr
  val int_to_real = Real.fromInt

  (* ---- word ---- *)
  val word_add = Word.+
  val word_sub = Word.-
  val word_mul = Word.*
  val word_div = Word.div
  val word_mod = Word.mod
  val word_lt = Word.<
  val word_le = Word.<=
  val word_gt = Word.>
  val word_ge = Word.>=
  val word_order = Word.compare
  val word_andb = Word.andb
  val word_orb = Word.orb
  val word_xorb = Word.xorb
  val word_notb = Word.notb
  val word_lsl = Word.<<
  val word_lsr = Word.>>
  val word_to_int = Word.toInt
  val word_to_int_x = Word.toIntX
  val word_from_int = Word.fromInt
  val word_to_string = Word.toString
  val word_neg = Word.~

  (* ---- real ---- *)
  val real_add = Real.+
  val real_sub = Real.-
  val real_mul = Real.*
  val real_div = Real./
  val real_neg = Real.~
  val real_abs = Real.abs
  val real_lt = Real.<
  val real_le = Real.<=
  val real_gt = Real.>
  val real_ge = Real.>=
  val real_eq = Real.==
  val real_floor = Real.floor
  val real_ceil = Real.ceil
  (* Not the host's Real.round: Poly/ML 5.7.1 rounds 0.49999999999999994 up.
     r - floor r is exact, so the three cases are decided exactly. On a
     31-bit int, floor overflows for r in [minInt - 0.5, minInt), which rounds
     to minInt (not trunc: SML/NJ 110.99.9 truncates minInt to maxInt). *)
  fun real_round r =
    let
      val below = Real.floor r
      val d = Real.- (r, Real.fromInt below)
    in
      if Real.< (d, 0.5) then below
      else if Real.> (d, 0.5) orelse Int.rem (below, 2) <> 0 then Int.+ (below, 1)
      else below
    end
    handle Overflow =>
      case Int.minInt of
        SOME m => if Real.< (r, 0.0) andalso Real.>= (r, Real.- (Real.fromInt m, 0.5)) then m else raise Overflow
      | NONE => raise Overflow
  val real_trunc = Real.trunc
  val real_to_string = Real.toString
  (* Poly/ML raises Overflow for an exponent that does not fit an int; the
     value is then an infinity, or a zero for a negative exponent or a zero
     mantissa. *)
  fun real_from_string s =
    Real.fromString s
    handle Overflow =>
      let
        val cs = String.explode s
        fun mantissaIsZero [] = true
          | mantissaIsZero (c :: rest) =
            if c = #"e" orelse c = #"E" then true
            else if #"1" <= c andalso c <= #"9" then false
            else mantissaIsZero rest
        val negativeExponent = String.isSubstring "e-" s orelse String.isSubstring "e~" s
                               orelse String.isSubstring "E-" s orelse String.isSubstring "E~" s
        val magnitude = if mantissaIsZero cs orelse negativeExponent then 0.0 else Real.posInf
      in SOME (if String.isPrefix "-" s orelse String.isPrefix "~" s then ~ magnitude else magnitude) end
  val real_sqrt = Math.sqrt
  val real_exp = Math.exp
  val real_ln = Math.ln
  val real_sin = Math.sin
  val real_cos = Math.cos
  val real_tan = Math.tan
  fun real_atan x = if Real.== (x, 0.0) then x else Math.atan x   (* SML/NJ: atan 0.0 is ~0.0 *)
  val real_atan2 = Math.atan2
  val real_pow = Math.pow
  val real_is_nan = Real.isNan

  (* ---- the primitives that are C library functions on the VM ----
     Written to avoid what the suite shows to be wrong on a host: reals from
     2^52 are integral already (SML/NJ's realFloor is inexact there), a zero
     result takes the sign of the argument, and rounding is decided on the
     exact fraction x - floor x (Poly/ML rounds 0.49999999999999994 up). *)
  val two52 = 4503599627370496.0
  fun integral (f : real -> real) x =
    if Real.isNan x orelse not (Real.isFinite x) orelse Real.abs x >= two52 then x
    else let val r = f x in if Real.== (r, 0.0) then Real.copySign (0.0, x) else r end
  val real_floor_r = integral Real.realFloor
  val real_ceil_r = integral Real.realCeil
  val real_trunc_r = integral Real.realTrunc
  val real_round_r =
    integral (fn x =>
      let val below = Real.realFloor x
          val d = x - below
      in
        if d < 0.5 then below
        else if d > 0.5 then below + 1.0
        else if Real.== (Real.rem (below, 2.0), 0.0) then below
        else below + 1.0
      end)
  val real_sign_bit = Real.signBit
  (* The bits of IEEE 754 binary64, worked out with the host's IntInf, which
     every host has (SML/NJ has no PackReal). A host whose word has fewer
     than 64 bits keeps the low ones. *)
  local
    val two52 = IntInf.pow (2, 52)
    val two63 = IntInf.pow (2, 63)
  in
    fun real_to_bits r =
      let
        val sign = if Real.signBit r then two63 else 0
        val body =
          if Real.isNan r then IntInf.* (0xFFF, IntInf.pow (2, 51))
          else if not (Real.isFinite r) then IntInf.* (0x7FF, two52)
          else if Real.== (r, 0.0) then 0
          else
            let
              val a = Real.abs r
              val {man, exp} = Real.toManExp a
              val e = exp + 1022
            in
              if e >= 1 then
                IntInf.+ (IntInf.* (IntInf.fromInt e, two52),
                          Real.toLargeInt IEEEReal.TO_NEAREST (Real.fromManExp {man = 2.0 * man - 1.0, exp = 52}))
              else Real.toLargeInt IEEEReal.TO_NEAREST (Real.fromManExp {man = a, exp = 1074})
            end
      in Word.fromLargeInt (IntInf.+ (sign, body)) end
    fun real_from_bits w =
      let
        val i = Word.toLargeInt w
        val negative = IntInf.>= (i, two63)
        val m = if negative then IntInf.- (i, two63) else i
        val e = IntInf.toInt (IntInf.div (m, two52))
        val f = IntInf.mod (m, two52)
        val magnitude =
          if e = 0x7FF then (if f = 0 then Real.posInf else 0.0 / 0.0)
          else if e = 0 then Real.fromManExp {man = Real.fromLargeInt f, exp = ~1074}
          else Real.fromManExp {man = 1.0 + Real.fromLargeInt f / Real.fromLargeInt two52, exp = e - 1023}
      in if negative then Real.~ magnitude else magnitude end
  end
  val real_copy_sign = Real.copySign
  fun unscaled x = Real.isNan x orelse not (Real.isFinite x) orelse Real.== (x, 0.0)
  fun real_frexp_man x = if unscaled x then x else #man (Real.toManExp x)
  fun real_frexp_exp x = if unscaled x then 0 else #exp (Real.toManExp x)
  fun real_ldexp (x, n) = if unscaled x then x else Real.fromManExp {man = x, exp = n}
  val real_next_after = Real.nextAfter
  (* C's fmod, exactly: the hosts compute x - n*y in floating point. While
     r >= y, subtract y scaled to the binade of r, halved if that is above r;
     then t <= r < 2t and r - t is exact (Sterbenz). *)
  fun real_rem (x, y) =
    if Real.isNan x orelse Real.isNan y then x + y
    else if not (Real.isFinite x) orelse Real.== (y, 0.0) then Real.posInf - Real.posInf
    else if not (Real.isFinite y) then x
    else
      let
        val ay = Real.abs y
        fun go r =
          if r < ay then r
          else
            let
              val t = Real.fromManExp {man = ay, exp = #exp (Real.toManExp r) - #exp (Real.toManExp ay)}
              val t = if t > r then t / 2.0 else t
            in go (r - t) end
      in Real.copySign (go (Real.abs x), x) end

  (* C's printf syntax from the host's fmt, for a finite real that is not negative *)
  fun cSyntax s = String.map (fn #"E" => #"e" | #"~" => #"-" | c => c) s
  fun precision n = if n < 0 orelse n > 100000 then raise Size else SOME n
  fun real_fmt_e (x, n) = cSyntax (Real.fmt (StringCvt.SCI (precision n)) x)
  fun real_fmt_f (x, n) = Real.fmt (StringCvt.FIX (precision n)) x
  fun real_shortest x =
    let
      fun go k =
        let val s = Real.fmt (StringCvt.SCI (SOME k)) x
        in
          if k >= 16 then s
          else case Real.fromString s of
                 SOME y => if Real.== (x, y) then s else go (k + 1)
               | NONE => go (k + 1)
        end
    in cSyntax (go 0) end

  fun real_set_round 0 = IEEEReal.setRoundingMode IEEEReal.TO_NEAREST
    | real_set_round 1 = IEEEReal.setRoundingMode IEEEReal.TO_NEGINF
    | real_set_round 2 = IEEEReal.setRoundingMode IEEEReal.TO_POSINF
    | real_set_round _ = IEEEReal.setRoundingMode IEEEReal.TO_ZERO
  fun real_get_round () =
    case IEEEReal.getRoundingMode () of
      IEEEReal.TO_NEAREST => 0 | IEEEReal.TO_NEGINF => 1 | IEEEReal.TO_POSINF => 2 | IEEEReal.TO_ZERO => 3

  (* Real32, rounding to binary32 in the current mode: to a multiple of the
     spacing 2^q of binary32 at the magnitude, as an integral real of at most
     25 bits (real_to_single) or, for the exact value of a numeral, with
     IntInf (real_single_from_string, as strtof). *)
  local
    val maxSingle = Real.fromManExp {man = 1.0 - Real.fromManExp {man = 1.0, exp = ~24}, exp = 128}
    val minSingle = Real.fromManExp {man = 1.0, exp = ~149}
    (* q for a magnitude in [2^(e-1), 2^e) *)
    fun quantum e = if e < ~125 then ~149 else e - 24
    (* whether the mode rounds a magnitude up at this sign *)
    fun away (negative, mode) = (mode = 1 andalso negative) orelse (mode = 2 andalso not negative)
    fun beyond (negative, mode) =
      let val m = if mode = 0 orelse away (negative, mode) then Real.posInf else maxSingle
      in if negative then Real.~ m else m end
    fun signed (negative, r) = if negative then Real.~ r else r
  in
    fun real_to_single x =
      if Real.isNan x orelse not (Real.isFinite x) orelse Real.== (x, 0.0) then x
      else
        let
          val mode = real_get_round ()
          val q = quantum (#exp (Real.toManExp x))
          val scaled = Real.fromManExp {man = x, exp = Int.~ q}
          val n = case mode of 0 => real_round_r scaled | 1 => real_floor_r scaled
                             | 2 => real_ceil_r scaled | _ => real_trunc_r scaled
          val r = Real.fromManExp {man = n, exp = q}
        in if Real.> (Real.abs r, maxSingle) then beyond (Real.< (x, 0.0), mode) else r end

    fun real_single_from_string s =
      let
        val (negative, cs) =
          case String.explode s of
            #"-" :: r => (true, r) | #"~" :: r => (true, r) | #"+" :: r => (false, r) | cs => (false, cs)
        fun isDigit c = #"0" <= c andalso c <= #"9"
        fun value c = IntInf.fromInt (Char.ord c - 48)
        (* the digits as an integer, how many there are, and the rest *)
        fun number (c :: r, acc, n) =
              if isDigit c then number (r, IntInf.+ (IntInf.* (acc, 10), value c), n + 1) else (acc, n, c :: r)
          | number ([], acc, n) = (acc, n, [])
        val (whole, nw, rest) = number (cs, 0, 0)
        val (d, nf, rest) = case rest of #"." :: r => number (r, whole, 0) | _ => (whole, 0, rest)
        val exponent =
          case rest of
            e :: r =>
              if e = #"e" orelse e = #"E" then
                let
                  val (neg, r) = case r of #"-" :: t => (true, t) | #"~" :: t => (true, t)
                                         | #"+" :: t => (false, t) | _ => (false, r)
                  val (x, n, _) = number (r, 0, 0)
                in if n = 0 then 0 else if neg then IntInf.~ x else x end
              else 0
          | [] => 0
        val mode = real_get_round ()
      in
        if nw + nf = 0 then NONE
        else if d = 0 then SOME (signed (negative, 0.0))
        else
          let
            (* d * 10^e; its decimal digits end at 10^(e + digits) *)
            val e = IntInf.- (exponent, IntInf.fromInt nf)
            val top = IntInf.+ (e, IntInf.fromInt (String.size (IntInf.toString d)))
          in
            if IntInf.> (top, 40) then SOME (beyond (negative, mode))
            else if IntInf.< (top, ~50) then SOME (signed (negative, if away (negative, mode) then minSingle else 0.0))
            else
              let
                val e = IntInf.toInt e
                val (num, den) = if e >= 0 then (IntInf.* (d, IntInf.pow (10, e)), 1) else (d, IntInf.pow (10, Int.~ e))
                fun shift (i, k) = IntInf.<< (i, Word.fromInt k)
                (* the magnitude is in [2^(t-1), 2^t) *)
                val k = IntInf.log2 num - IntInf.log2 den
                val below = if k >= 0 then IntInf.< (num, shift (den, k)) else IntInf.< (shift (num, Int.~ k), den)
                val t = (if below then k - 1 else k) + 1
                val q = quantum t
                val (num, den) = if q <= 0 then (shift (num, Int.~ q), den) else (num, shift (den, q))
                val n = IntInf.div (num, den)
                val rem = IntInf.mod (num, den)
                val up =
                  if mode = 0 then
                    (case IntInf.compare (IntInf.* (rem, 2), den) of
                       GREATER => true | LESS => false | EQUAL => IntInf.mod (n, 2) = 1)
                  else away (negative, mode) andalso rem <> 0
                val n = if up then IntInf.+ (n, 1) else n
                val r = Real.fromManExp {man = Real.fromLargeInt n, exp = q}
              in SOME (if Real.> (r, maxSingle) then beyond (negative, mode) else signed (negative, r)) end
          end
      end
  end
  val real_sinh = Math.sinh
  fun real_cosh x = Math.cosh (Real.abs x)   (* even; MLton gives ~inf for ~inf *)
  val real_tanh = Math.tanh

  (* ---- char and string ---- *)
  val char_ord = Char.ord
  val char_lt = Char.<
  val char_le = Char.<=
  val char_gt = Char.>
  val char_ge = Char.>=
  val char_order = Char.compare
  val string_size = String.size
  val string_sub = String.sub
  (* the VM's limit (String.maxSize of lib/basis), not the host's *)
  val maxString = 1073741823
  fun string_concat (a, b) = if String.size a + String.size b > maxString then raise Size else a ^ b
  fun string_extract (s, i, n) = String.substring (s, i, n)
  val string_lt = String.<
  val string_le = String.<=
  val string_gt = String.>
  val string_ge = String.>=
  fun string_compare (a, b) =
    case String.compare (a, b) of LESS => ~1 | EQUAL => 0 | GREATER => 1
  val string_order = String.compare
  val string_from_char = String.str
  val string_implode = String.implode
  val string_explode = String.explode
  val string_concat_list = String.concat

  val exn_name = exnName

  (* ---- ref, array, vector ---- *)
  fun ref_new x = ref x
  fun ref_get r = !r
  fun ref_set (r, x) = r := x
  (* The VM's limit, not the host's. *)
  val maxLen = 100000000
  fun longer (l, n) =
    case l of [] => false | _ :: rest => n = 0 orelse longer (rest, n - 1)
  fun array_new (n, x) = if n > maxLen then raise Size else Array.array (n, x)
  val array_length = Array.length
  val array_sub = Array.sub
  val array_update = Array.update
  fun array_from_list l = if longer (l, maxLen) then raise Size else Array.fromList l
  fun vector_from_list l = if longer (l, maxLen) then raise Size else Vector.fromList l
  val vector_length = Vector.length
  val vector_sub = Vector.sub

  (* ---- standard streams and the process ---- *)
  val print = TextIO.print
  fun print_err s = (TextIO.output (TextIO.stdErr, s); TextIO.flushOut TextIO.stdErr)
  fun flush_out () = TextIO.flushOut TextIO.stdOut
  fun input_line () = TextIO.inputLine TextIO.stdIn
  fun input_all () = TextIO.inputAll TextIO.stdIn
  (* OS.Process.exit flushes the host's streams but knows two statuses only. *)
  fun exit 0 = OS.Process.exit OS.Process.success
    | exit 1 = OS.Process.exit OS.Process.failure
    | exit n =
      (TextIO.flushOut TextIO.stdOut; Posix.Process.exit (Word8.fromInt n))
  fun posix_exit n = Posix.Process.exit (Word8.fromInt n)
  val command_args = CommandLine.arguments
  val command_name = CommandLine.name

  (* ---- files: handles 0-2 are the standard streams; the others are file
     descriptors of the host, used through Posix.IO so that the stream layer
     of the host, which the suite tests as well, plays no part ---- *)
  structure FS = Posix.FileSys
  datatype file =
      Reader of {fd : Posix.IO.file_desc, buf : string ref, pos : int ref, eof : bool ref, taken : int ref}
    | Writer of Posix.IO.file_desc
  val files : (int * file) list ref = ref []
  val next = ref 3
  val lastError = ref ""
  val lastErrno = ref 0
  val rw = FS.S.flags [FS.S.irusr, FS.S.iwusr, FS.S.irgrp, FS.S.iwgrp, FS.S.iroth, FS.S.iwoth]

  fun noteError (SOME e) = lastErrno := SysWord.toInt (Posix.Error.toWord e)
    | noteError NONE = ()

  fun lookup h =
    let fun go [] = NONE
          | go ((h', f) :: rest) = if h = h' then SOME f else go rest
    in go (!files) end

  fun file_open (name, mode) =
    let
      val f = case mode of
                0 => Reader {fd = FS.openf (name, FS.O_RDONLY, FS.O.flags []),
                             buf = ref "", pos = ref 0, eof = ref false, taken = ref 0}
              | 1 => Writer (FS.createf (name, FS.O_WRONLY, FS.O.trunc, rw))
              | _ => Writer (FS.createf (name, FS.O_WRONLY, FS.O.append, rw))
      val h = !next
    in next := h + 1; files := (h, f) :: !files; SOME h end
    handle OS.SysErr (msg, e) => (lastError := msg; noteError e; NONE)

  fun file_close h =
    (case lookup h of
       SOME (Reader {fd, ...}) => Posix.IO.close fd
     | SOME (Writer fd) => Posix.IO.close fd
     | NONE => ();
     files := List.filter (fn (h', _) => h' <> h) (!files))

  fun writeAll (fd, s) =
    let
      val bytes = Byte.stringToBytes s
      fun go i =
        if i >= Word8Vector.length bytes then ()
        else go (i + Posix.IO.writeVec (fd, Word8VectorSlice.slice (bytes, i, NONE)))
    in go 0 end

  fun file_write (1, s) = (TextIO.output (TextIO.stdOut, s); true)
    | file_write (2, s) = (TextIO.output (TextIO.stdErr, s); true)
    | file_write (h, s) =
      (case lookup h of
         SOME (Writer fd) => (writeAll (fd, s); true)
       | _ => (lastError := OS.errorMsg Posix.Error.badf; false))
      handle OS.SysErr (msg, e) => (lastError := msg; noteError e; false)

  fun file_flush 1 = TextIO.flushOut TextIO.stdOut
    | file_flush 2 = TextIO.flushOut TextIO.stdErr
    | file_flush _ = ()

  (* fill: append what the file has to the buffer; false when it has nothing
     more for now. A file may grow after it has been read to its end, so this
     tries again every time. *)
  fun fill {fd, buf, pos, eof, taken} =
    let val more = Byte.bytesToString (Posix.IO.readVec (fd, 65536))
    in
      if more = "" then (eof := true; false)
      else (buf := String.extract (!buf, !pos, NONE) ^ more; pos := 0; eof := false;
            taken := !taken + String.size more; true)
    end

  fun readLine (r as {buf, pos, ...}
                : {fd : Posix.IO.file_desc, buf : string ref, pos : int ref, eof : bool ref, taken : int ref}) =
    let
      val s = !buf
      val start = !pos
      fun find i =
        if i >= size s then NONE else if String.sub (s, i) = #"\n" then SOME i else find (i + 1)
    in
      case find start of
        SOME i => (pos := i + 1; SOME (String.substring (s, start, i + 1 - start)))
      | NONE =>
          if fill r then readLine r
          else if start >= size s then NONE
          else (pos := size s; SOME (String.extract (s, start, NONE) ^ "\n"))
    end

  fun file_read_line 0 = TextIO.inputLine TextIO.stdIn
    | file_read_line h =
      (case lookup h of SOME (Reader r) => readLine r | _ => NONE)

  (* at most n bytes, "" at end of file *)
  fun file_read_vec (0, n) =
      (case TextIO.inputN (TextIO.stdIn, n) of s => s)
    | file_read_vec (h, n) =
      if n < 0 then raise Size
      else
        (case lookup h of
           SOME (Reader (r as {buf, pos, ...})) =>
             let
               val buffered = String.size (!buf) - !pos
               val () = if buffered <= 0 then ignore (fill r) else ()
               val have = String.size (!buf) - !pos
               val k = if n < have then n else have
               val s = String.substring (!buf, !pos, k)
             in pos := !pos + k; s end
         | _ => "")

  (* What a seekable file has left; ~1 for anything else. The position is
     counted here and the size comes from fstat, because Poly/ML 5.7.1
     answers every lseek with 0. *)
  fun file_avail 0 = ~1
    | file_avail h =
      (case lookup h of
         SOME (Reader {fd, buf, pos, taken, ...}) =>
           let
             val buffered = String.size (!buf) - !pos
             val theEnd = Position.toInt (Posix.FileSys.ST.size (Posix.FileSys.fstat fd))
           in buffered + theEnd - !taken end
           handle OS.SysErr _ => ~1
       | _ => 0)

  (* The position of a file: for a reader what it has taken from the file
     less what it holds, for a writer the descriptor's; ~1 for the standard
     handles, which the shim reaches through the host's streams. *)
  fun file_tell h =
    (case lookup h of
       SOME (Reader {buf, pos, taken, ...}) => !taken - (String.size (!buf) - !pos)
     | SOME (Writer fd) => Position.toInt (Posix.IO.lseek (fd, Position.fromInt 0, Posix.IO.SEEK_CUR))
     | NONE => ~1)
    handle OS.SysErr (_, e) => (noteError e; ~1)
  fun file_seek (h, p) =
    (case lookup h of
       SOME (Reader {fd, buf, pos, eof, taken}) =>
         (ignore (Posix.IO.lseek (fd, Position.fromInt p, Posix.IO.SEEK_SET));
          buf := ""; pos := 0; eof := false; taken := p; 0)
     | SOME (Writer fd) => (ignore (Posix.IO.lseek (fd, Position.fromInt p, Posix.IO.SEEK_SET)); 0)
     | NONE => ~1)
    handle OS.SysErr (_, e) => (noteError e; ~1)

  fun file_read_all 0 = TextIO.inputAll TextIO.stdIn
    | file_read_all h =
      (case lookup h of
         SOME (Reader {fd, buf, pos, eof, taken}) =>
           let
             val buffered = String.extract (!buf, !pos, NONE)
             fun go acc =
               let val more = Byte.bytesToString (Posix.IO.readVec (fd, 65536))
               in
                 if more = "" then (eof := true; String.concat (List.rev acc))
                 else (taken := !taken + String.size more; go (more :: acc))
               end
           in buf := ""; pos := 0; go [buffered] end
       | _ => "")

  fun file_error () = !lastError
  fun file_errno () = !lastErrno

  (* ---- the system layer, on the host's Posix, Date and Timer ----
     The VM numbers the errors of the system the way the C library does,
     which is what Posix.Error holds too; its names are the lower-case tails
     of the C ones. *)
  fun sys_errno () = !lastErrno
  fun errorOf e = Posix.Error.fromWord (SysWord.fromInt e)
  fun sys_error_msg e = Posix.Error.errorMsg (errorOf e)
  (* The C name of the host's name of an error, and the reverse: E2BIG is
     toobig, the others are the C name in lower case without the E. *)
  fun cNameOf "toobig" = "E2BIG"
    | cNameOf name = "E" ^ String.map Char.toUpper name
  fun hostNameOf "E2BIG" = SOME "toobig"
    | hostNameOf name =
      if String.size name < 2 orelse String.sub (name, 0) <> #"E" then NONE
      else SOME (String.map Char.toLower (String.extract (name, 1, NONE)))
  fun sys_error_name e =
    case Posix.Error.errorName (errorOf e) of
      "" => ""
    | name => cNameOf name
  fun sys_error_of_name name =
    case Option.mapPartial Posix.Error.syserror (hostNameOf name) of
      SOME e => SysWord.toInt (Posix.Error.toWord e)
    | NONE => ~1

  fun time_now () = Int.fromLarge (Time.toMicroseconds (Time.now ()))
  val cpu = Timer.totalCPUTimer ()
  fun time_user () = Int.fromLarge (Time.toMicroseconds (#usr (Timer.checkCPUTimer cpu)))
  fun time_sys () = Int.fromLarge (Time.toMicroseconds (#sys (Timer.checkCPUTimer cpu)))
  (* the host's own collector, where it accounts for one *)
  fun time_gc_user () = Int.fromLarge (Time.toMicroseconds (#usr (#gc (Timer.checkCPUTimes cpu))))
  fun time_gc_sys () = Int.fromLarge (Time.toMicroseconds (#sys (#gc (Timer.checkCPUTimes cpu))))
  (* At least n microseconds, as the VM waits: Poly/ML 5.9.2 can return a
     little early, so sleep again for what is left. *)
  fun time_sleep n =
    if n <= 0 then ()
    else
      let
        val until = Time.+ (Time.now (), Time.fromMicroseconds (Int.toLarge n))
        fun go () =
          let val now = Time.now ()
          in if Time.< (now, until) then (OS.Process.sleep (Time.- (until, now)); go ()) else () end
      in go () end

  val months = [Date.Jan, Date.Feb, Date.Mar, Date.Apr, Date.May, Date.Jun,
                Date.Jul, Date.Aug, Date.Sep, Date.Oct, Date.Nov, Date.Dec]
  val weekdays = [Date.Sun, Date.Mon, Date.Tue, Date.Wed, Date.Thu, Date.Fri, Date.Sat]
  fun indexOf (x, l) =
    let fun go (k, y :: rest) = if y = x then k else go (k + 1, rest) | go (_, []) = 0
    in go (0, l) end

  fun partsOf d =
    [Date.second d, Date.minute d, Date.hour d, Date.day d, indexOf (Date.month d, months),
     Date.year d - 1900, indexOf (Date.weekDay d, weekdays), Date.yearDay d,
     case Date.isDst d of NONE => ~1 | SOME true => 1 | SOME false => 0]

  fun dateOf (parts, local') =
    case parts of
      sec :: min :: hr :: mday :: mon :: yr :: _ =>
        Date.date {year = yr + 1900, month = List.nth (months, if mon < 0 then 0 else if mon > 11 then 11 else mon),
                   day = mday, hour = hr, minute = min, second = sec,
                   offset = if local' = 1 then NONE else SOME Time.zeroTime}
    | _ => raise Fail "dateOf"

  fun date_parts (seconds, local') =
    partsOf ((if local' = 1 then Date.fromTimeLocal else Date.fromTimeUniv) (Time.fromSeconds (Int.toLarge seconds)))
    handle _ => []

  fun date_seconds (parts, local') =
    let
      val t = Int.fromLarge (Time.toSeconds (Date.toTime (dateOf (parts, local'))))
      val back = (if local' = 1 then Date.fromTimeLocal else Date.fromTimeUniv) (Time.fromSeconds (Int.toLarge t))
    in t :: partsOf back end
    handle _ => []

  (* how far local time is ahead of UTC *)
  fun date_offset (seconds : int) =
    let
      val t = Time.fromSeconds (Int.toLarge seconds)
      val asLocal = Date.fromTimeLocal t
      val asUtc = Date.fromTimeUniv t
      fun minutesOf d = ((Date.yearDay d * 24 + Date.hour d) * 60 + Date.minute d)
      val difference = minutesOf asLocal - minutesOf asUtc
      (* a day may separate them at the turn of a year *)
      val difference = if difference > 720 then difference - 1440
                       else if difference < ~720 then difference + 1440 else difference
    in difference * 60 end
    handle _ => raise Domain

  fun date_format (format, parts, local') = Date.fmt format (dateOf (parts, local'))

  (* The status of the host's OS.Process.system is abstract; Posix.Process
     opens it, which is cheaper and safer than running the command here. *)
  fun os_system command =
    case Posix.Process.fromStatus (OS.Process.system command) of
      Posix.Process.W_EXITED => 0
    | Posix.Process.W_EXITSTATUS w => Word8.toInt w
    | Posix.Process.W_SIGNALED sg => 256 + SysWord.toInt (Posix.Signal.toWord sg)
    | Posix.Process.W_STOPPED sg => 512 + SysWord.toInt (Posix.Signal.toWord sg)
  fun os_getenv name = OS.Process.getEnv name

  (* ---- the file system, on the host's Posix ---- *)
  fun noted f = (f (); 0) handle OS.SysErr (_, e) => (noteError e; ~1)
  fun notedValue (f, onFailure) = f () handle OS.SysErr (_, e) => (noteError e; onFailure)

  val rwx = Posix.FileSys.S.flags [Posix.FileSys.S.irwxu, Posix.FileSys.S.irwxg, Posix.FileSys.S.irwxo]
  fun os_mkdir path = noted (fn () => Posix.FileSys.mkdir (path, rwx))
  fun os_rmdir path = noted (fn () => Posix.FileSys.rmdir path)
  fun os_chdir path = noted (fn () => Posix.FileSys.chdir path)
  fun os_getcwd () = notedValue (Posix.FileSys.getcwd, "")
  fun os_remove path = noted (fn () => Posix.FileSys.unlink path)
  fun os_rename (from, to) = noted (fn () => Posix.FileSys.rename {old = from, new = to})

  fun os_access (path, flags, _) =
    let
      fun bit (k, m) = if Int.rem (Int.quot (flags, k), 2) = 1 then [m] else []
      val modes = bit (1, Posix.FileSys.A_READ) @ bit (2, Posix.FileSys.A_WRITE) @ bit (4, Posix.FileSys.A_EXEC)
    in if Posix.FileSys.access (path, modes) then 1 else 0 end
    handle OS.SysErr (_, e) => (noteError e; ~1)

  fun kindOf st =
    if Posix.FileSys.ST.isReg st then 0
    else if Posix.FileSys.ST.isDir st then 1
    else if Posix.FileSys.ST.isLink st then 2
    else 3
  fun os_file_kind path = notedValue (fn () => kindOf (Posix.FileSys.stat path), ~1)
  fun os_link_kind path = notedValue (fn () => kindOf (Posix.FileSys.lstat path), ~1)
  fun os_file_size path =
    notedValue (fn () => Position.toInt (Posix.FileSys.ST.size (Posix.FileSys.stat path)), ~1)
  fun os_mod_time path =
    notedValue (fn () => Int.fromLarge (Time.toSeconds (Posix.FileSys.ST.mtime (Posix.FileSys.stat path))), ~1)
  fun os_set_time (path, seconds, now) =
    noted (fn () =>
      Posix.FileSys.utime (path, if now = 1 then NONE
                                 else SOME {actime = Time.fromSeconds (Int.toLarge seconds),
                                            modtime = Time.fromSeconds (Int.toLarge seconds)}))
  fun os_read_link path = notedValue (fn () => Posix.FileSys.readlink path, "")
  fun os_real_path path = notedValue (fn () => OS.FileSys.fullPath path, "")
  fun os_tmp_name () = OS.FileSys.tmpName ()
  fun os_file_id path =
    notedValue (fn () =>
      let val st = Posix.FileSys.stat path
      in [SysWord.toInt (Posix.FileSys.devToWord (Posix.FileSys.ST.dev st)),
          SysWord.toInt (Posix.FileSys.inoToWord (Posix.FileSys.ST.ino st))] end, [])

  (* The directory streams the library holds by number. *)
  val dirs : (int * Posix.FileSys.dirstream option ref) list ref = ref []
  val nextDir = ref 0
  fun dirOf n =
    let fun go [] = NONE | go ((k, d) :: rest) = if k = n then SOME d else go rest
    in go (!dirs) end

  fun os_open_dir path =
    (let
       val d = Posix.FileSys.opendir path
       val n = !nextDir
     in nextDir := n + 1; dirs := (n, ref (SOME d)) :: !dirs; n end)
    handle OS.SysErr (_, e) => (noteError e; ~1)

  fun os_read_dir n =
    case dirOf n of
      SOME (ref (SOME d)) => Posix.FileSys.readdir d
    | _ => NONE

  fun os_rewind_dir n =
    case dirOf n of
      SOME (ref (SOME d)) => (Posix.FileSys.rewinddir d; 0)
    | _ => ~1

  fun os_close_dir n =
    case dirOf n of
      SOME (r as ref (SOME d)) => (Posix.FileSys.closedir d; r := NONE; 0)
    | _ => ~1

  (* ---- descriptors ---- *)
  fun fdOf (n : int) = Posix.FileSys.wordToFD (SysWord.fromInt n)
  fun fdNum fd = SysWord.toInt (Posix.FileSys.fdToWord fd)

  fun descriptorOf h =
    case lookup h of
      SOME (Reader {fd, ...}) => SOME fd
    | SOME (Writer fd) => SOME fd
    | NONE => NONE

  (* An iodesc is the host's descriptor, as it is the system's on the VM. *)
  fun file_descriptor h =
    case descriptorOf h of
      SOME fd => fdNum fd
    | NONE => if h >= 0 andalso h <= 2 then h else ~1

  fun os_desc_kind n =
        notedValue (fn () =>
          let val st = Posix.FileSys.fstat (fdOf n)
          in
            if Posix.ProcEnv.isatty (fdOf n) then 3
            else if Posix.FileSys.ST.isReg st then 0
            else if Posix.FileSys.ST.isDir st then 1
            else if Posix.FileSys.ST.isLink st then 2
            else if Posix.FileSys.ST.isFIFO st then 4
            else if Posix.FileSys.ST.isSock st then 5
            else 6
          end, ~1)

  (* The host has no poll of its own, so a file is taken to be ready, which
     is what poll says of a regular file. *)
  fun os_poll (handles, events, _) =
    List.map (fn e => e) events

  (* ---- POSIX, on the host's own Posix ----
     The named constants come from the host's structures, so that the same
     library sees the same numbers it would on the VM. *)
  local
    structure PF = Posix.FileSys
    structure PE = Posix.Error
    structure PS = Posix.Signal
    fun ofWord w = SysWord.toInt w
  in
    val constants =
      [("O_APPEND", ofWord (PF.O.toWord PF.O.append)), ("O_EXCL", ofWord (PF.O.toWord PF.O.excl)),
       ("O_NOCTTY", ofWord (PF.O.toWord PF.O.noctty)), ("O_NONBLOCK", ofWord (PF.O.toWord PF.O.nonblock)),
       ("O_SYNC", ofWord (PF.O.toWord PF.O.sync)), ("O_TRUNC", ofWord (PF.O.toWord PF.O.trunc)),
       ("O_RDONLY", 0), ("O_WRONLY", 1), ("O_RDWR", 2), ("O_CREAT", 64),
       ("S_IRUSR", ofWord (PF.S.toWord PF.S.irusr)), ("S_IWUSR", ofWord (PF.S.toWord PF.S.iwusr)),
       ("S_IXUSR", ofWord (PF.S.toWord PF.S.ixusr)), ("S_IRWXU", ofWord (PF.S.toWord PF.S.irwxu)),
       ("S_IRGRP", ofWord (PF.S.toWord PF.S.irgrp)), ("S_IWGRP", ofWord (PF.S.toWord PF.S.iwgrp)),
       ("S_IXGRP", ofWord (PF.S.toWord PF.S.ixgrp)), ("S_IRWXG", ofWord (PF.S.toWord PF.S.irwxg)),
       ("S_IROTH", ofWord (PF.S.toWord PF.S.iroth)), ("S_IWOTH", ofWord (PF.S.toWord PF.S.iwoth)),
       ("S_IXOTH", ofWord (PF.S.toWord PF.S.ixoth)), ("S_IRWXO", ofWord (PF.S.toWord PF.S.irwxo)),
       ("S_ISUID", ofWord (PF.S.toWord PF.S.isuid)), ("S_ISGID", ofWord (PF.S.toWord PF.S.isgid)),
       ("SIGABRT", ofWord (PS.toWord PS.abrt)), ("SIGALRM", ofWord (PS.toWord PS.alrm)),
       ("SIGBUS", ofWord (PS.toWord PS.bus)), ("SIGCHLD", ofWord (PS.toWord PS.chld)),
       ("SIGCONT", ofWord (PS.toWord PS.cont)), ("SIGFPE", ofWord (PS.toWord PS.fpe)),
       ("SIGHUP", ofWord (PS.toWord PS.hup)), ("SIGILL", ofWord (PS.toWord PS.ill)),
       ("SIGINT", ofWord (PS.toWord PS.int)), ("SIGKILL", ofWord (PS.toWord PS.kill)),
       ("SIGPIPE", ofWord (PS.toWord PS.pipe)), ("SIGQUIT", ofWord (PS.toWord PS.quit)),
       ("SIGSEGV", ofWord (PS.toWord PS.segv)), ("SIGSTOP", ofWord (PS.toWord PS.stop)),
       ("SIGTERM", ofWord (PS.toWord PS.term)), ("SIGTSTP", ofWord (PS.toWord PS.tstp)),
       ("SIGTTIN", ofWord (PS.toWord PS.ttin)), ("SIGTTOU", ofWord (PS.toWord PS.ttou)),
       ("SIGUSR1", ofWord (PS.toWord PS.usr1)), ("SIGUSR2", ofWord (PS.toWord PS.usr2)),
       ("SEEK_SET", 0), ("SEEK_CUR", 1), ("SEEK_END", 2),
       ("F_DUPFD", 0), ("F_GETFD", 1), ("F_SETFD", 2), ("F_GETFL", 3), ("F_SETFL", 4),
       ("FD_CLOEXEC", ofWord (Posix.IO.FD.toWord Posix.IO.FD.cloexec)),
       ("F_GETLK", 5), ("F_SETLK", 6), ("F_SETLKW", 7), ("F_RDLCK", 0), ("F_WRLCK", 1), ("F_UNLCK", 2),
       ("WNOHANG", 1), ("WUNTRACED", 2),
       (* the sockets fail with ENOSYS, but their families and types are
          values of the library all the same *)
       ("AF_UNIX", 1), ("AF_INET", 2), ("AF_INET6", 10), ("SOCK_STREAM", 1), ("SOCK_DGRAM", 2), ("SOL_SOCKET", 1),
       ("SO_DEBUG", 1), ("SO_REUSEADDR", 2), ("SO_TYPE", 3), ("SO_ERROR", 4), ("SO_DONTROUTE", 5),
       ("SO_BROADCAST", 6), ("SO_SNDBUF", 7), ("SO_RCVBUF", 8), ("SO_KEEPALIVE", 9), ("SO_OOBINLINE", 10),
       ("SO_LINGER", 13), ("MSG_OOB", 1), ("MSG_PEEK", 2), ("MSG_DONTROUTE", 4),
       ("SHUT_RD", 0), ("SHUT_WR", 1), ("SHUT_RDWR", 2), ("IPPROTO_TCP", 6), ("TCP_NODELAY", 1),
       (* the terminal: the flags, indices and speeds are the host's; the
          actions of TC are abstract on the hosts, so they are Linux's *)
       ("BRKINT", ofWord (Posix.TTY.I.toWord Posix.TTY.I.brkint)),
       ("ICRNL", ofWord (Posix.TTY.I.toWord Posix.TTY.I.icrnl)),
       ("IGNBRK", ofWord (Posix.TTY.I.toWord Posix.TTY.I.ignbrk)),
       ("IGNCR", ofWord (Posix.TTY.I.toWord Posix.TTY.I.igncr)),
       ("IGNPAR", ofWord (Posix.TTY.I.toWord Posix.TTY.I.ignpar)),
       ("INLCR", ofWord (Posix.TTY.I.toWord Posix.TTY.I.inlcr)),
       ("INPCK", ofWord (Posix.TTY.I.toWord Posix.TTY.I.inpck)),
       ("ISTRIP", ofWord (Posix.TTY.I.toWord Posix.TTY.I.istrip)),
       ("IXOFF", ofWord (Posix.TTY.I.toWord Posix.TTY.I.ixoff)),
       ("IXON", ofWord (Posix.TTY.I.toWord Posix.TTY.I.ixon)),
       ("PARMRK", ofWord (Posix.TTY.I.toWord Posix.TTY.I.parmrk)),
       ("OPOST", ofWord (Posix.TTY.O.toWord Posix.TTY.O.opost)),
       ("CLOCAL", ofWord (Posix.TTY.C.toWord Posix.TTY.C.clocal)),
       ("CREAD", ofWord (Posix.TTY.C.toWord Posix.TTY.C.cread)),
       ("CS5", ofWord (Posix.TTY.C.toWord Posix.TTY.C.cs5)),
       ("CS6", ofWord (Posix.TTY.C.toWord Posix.TTY.C.cs6)),
       ("CS7", ofWord (Posix.TTY.C.toWord Posix.TTY.C.cs7)),
       ("CS8", ofWord (Posix.TTY.C.toWord Posix.TTY.C.cs8)),
       ("CSIZE", ofWord (Posix.TTY.C.toWord Posix.TTY.C.csize)),
       ("CSTOPB", ofWord (Posix.TTY.C.toWord Posix.TTY.C.cstopb)),
       ("HUPCL", ofWord (Posix.TTY.C.toWord Posix.TTY.C.hupcl)),
       ("PARENB", ofWord (Posix.TTY.C.toWord Posix.TTY.C.parenb)),
       ("PARODD", ofWord (Posix.TTY.C.toWord Posix.TTY.C.parodd)),
       ("ECHO", ofWord (Posix.TTY.L.toWord Posix.TTY.L.echo)),
       ("ECHOE", ofWord (Posix.TTY.L.toWord Posix.TTY.L.echoe)),
       ("ECHOK", ofWord (Posix.TTY.L.toWord Posix.TTY.L.echok)),
       ("ECHONL", ofWord (Posix.TTY.L.toWord Posix.TTY.L.echonl)),
       ("ICANON", ofWord (Posix.TTY.L.toWord Posix.TTY.L.icanon)),
       ("IEXTEN", ofWord (Posix.TTY.L.toWord Posix.TTY.L.iexten)),
       ("ISIG", ofWord (Posix.TTY.L.toWord Posix.TTY.L.isig)),
       ("NOFLSH", ofWord (Posix.TTY.L.toWord Posix.TTY.L.noflsh)),
       ("TOSTOP", ofWord (Posix.TTY.L.toWord Posix.TTY.L.tostop)),
       ("VEOF", Posix.TTY.V.eof),
       ("VEOL", Posix.TTY.V.eol),
       ("VERASE", Posix.TTY.V.erase),
       ("VINTR", Posix.TTY.V.intr),
       ("VKILL", Posix.TTY.V.kill),
       ("VMIN", Posix.TTY.V.min),
       ("VQUIT", Posix.TTY.V.quit),
       ("VSUSP", Posix.TTY.V.susp),
       ("VTIME", Posix.TTY.V.time),
       ("VSTART", Posix.TTY.V.start),
       ("VSTOP", Posix.TTY.V.stop),
       ("NCCS", Posix.TTY.V.nccs),
       ("B0", ofWord (Posix.TTY.speedToWord Posix.TTY.b0)),
       ("B50", ofWord (Posix.TTY.speedToWord Posix.TTY.b50)),
       ("B75", ofWord (Posix.TTY.speedToWord Posix.TTY.b75)),
       ("B110", ofWord (Posix.TTY.speedToWord Posix.TTY.b110)),
       ("B134", ofWord (Posix.TTY.speedToWord Posix.TTY.b134)),
       ("B150", ofWord (Posix.TTY.speedToWord Posix.TTY.b150)),
       ("B200", ofWord (Posix.TTY.speedToWord Posix.TTY.b200)),
       ("B300", ofWord (Posix.TTY.speedToWord Posix.TTY.b300)),
       ("B600", ofWord (Posix.TTY.speedToWord Posix.TTY.b600)),
       ("B1200", ofWord (Posix.TTY.speedToWord Posix.TTY.b1200)),
       ("B1800", ofWord (Posix.TTY.speedToWord Posix.TTY.b1800)),
       ("B2400", ofWord (Posix.TTY.speedToWord Posix.TTY.b2400)),
       ("B4800", ofWord (Posix.TTY.speedToWord Posix.TTY.b4800)),
       ("B9600", ofWord (Posix.TTY.speedToWord Posix.TTY.b9600)),
       ("B19200", ofWord (Posix.TTY.speedToWord Posix.TTY.b19200)),
       ("B38400", ofWord (Posix.TTY.speedToWord Posix.TTY.b38400)),
       ("TCSANOW", 0),
       ("TCSADRAIN", 1),
       ("TCSAFLUSH", 2),
       ("TCOOFF", 0),
       ("TCOON", 1),
       ("TCIOFF", 2),
       ("TCION", 3),
       ("TCIFLUSH", 0),
       ("TCOFLUSH", 1),
       ("TCIOFLUSH", 2)]

    fun posix_const name =
      let
        fun go [] =
            (case Option.mapPartial PE.syserror (hostNameOf name) of
               SOME e => ofWord (PE.toWord e)
             | NONE => ~1)
          | go ((n, v) :: rest) = if n = name then v else go rest
      in go constants end
  end

  (* The descriptors of the host are abstract; these hold the numbers. *)

  fun posix_fork () =
    case Posix.Process.fork () of
      NONE => 0
    | SOME pid => SysWord.toInt (Posix.Process.pidToWord pid)

  fun posix_exec (path, args, search) =
    ((if search = 1 then Posix.Process.execp (path, args)
      else Posix.Process.exec (path, args)); ~1)
    handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_exece (path, args, env) =
    (Posix.Process.exece (path, args, env); ~1)
    handle OS.SysErr (_, e) => (noteError e; ~1)

  (* fork, the descriptors onto 0, 1 and 2, exec, and 126 if that fails *)
  fun posix_spawn (path, args, env, flags, fds) =
    case Posix.Process.fork () of
      NONE =>
        ((List.app (fn (to, from) => if from >= 0 andalso from <> to
                                     then Posix.IO.dup2 {old = fdOf from, new = fdOf to} else ())
                   (ListPair.zip ([0, 1, 2], fds));
          if Int.rem (Int.quot (flags, 2), 2) = 1 then Posix.Process.exece (path, args, env)
          else if Int.rem (flags, 2) = 1 then Posix.Process.execp (path, args)
          else Posix.Process.exec (path, args))
         handle _ => ();
         Posix.Process.exit 0w126)
    | SOME pid => SysWord.toInt (Posix.Process.pidToWord pid)

  fun posix_waitpid (pid, flags) =
    let
      val arg = if pid = ~1 then Posix.Process.W_ANY_CHILD
                else if pid = 0 then Posix.Process.W_SAME_GROUP
                else if pid < 0 then Posix.Process.W_GROUP (Posix.Process.wordToPid (SysWord.fromInt (~pid)))
                else Posix.Process.W_CHILD (Posix.Process.wordToPid (SysWord.fromInt pid))
      (* WNOHANG (1) is waitpid_nh, WUNTRACED (2) is W.untraced *)
      val options = if Int.rem (Int.quot (flags, 2), 2) = 1 then [Posix.Process.W.untraced] else []
      val (got, status) =
        if Int.rem (flags, 2) = 1 then
          (case Posix.Process.waitpid_nh (arg, options) of
             SOME r => r
           | NONE => (Posix.Process.wordToPid 0w0, Posix.Process.W_EXITED))
        else Posix.Process.waitpid (arg, options)
      val number = SysWord.toInt (Posix.Process.pidToWord got)
    in
      case status of
        Posix.Process.W_EXITED => [number, 0, 0]
      | Posix.Process.W_EXITSTATUS w => [number, 0, Word8.toInt w]
      | Posix.Process.W_SIGNALED s => [number, 1, ofWordSignal s]
      | Posix.Process.W_STOPPED s => [number, 2, ofWordSignal s]
    end
    handle OS.SysErr (_, e) => (noteError e; [])
  and ofWordSignal s = SysWord.toInt (Posix.Signal.toWord s)

  fun posix_kill (pid, signal) =
    (Posix.Process.kill (if pid = 0 then Posix.Process.K_SAME_GROUP
                         else if pid < 0 then Posix.Process.K_GROUP (Posix.Process.wordToPid (SysWord.fromInt (~pid)))
                         else Posix.Process.K_PROC (Posix.Process.wordToPid (SysWord.fromInt pid)),
                        Posix.Signal.fromWord (SysWord.fromInt signal));
     0)
    handle OS.SysErr (_, e) => (noteError e; ~1)

  fun posix_alarm n = Int.fromLarge (Time.toSeconds (Posix.Process.alarm (Time.fromSeconds (Int.toLarge n))))
  fun posix_pause () = (Posix.Process.pause (); 0)
  fun posix_getpid () = SysWord.toInt (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
  fun posix_getppid () = SysWord.toInt (Posix.Process.pidToWord (Posix.ProcEnv.getppid ()))
  fun posix_getuid () = SysWord.toInt (Posix.ProcEnv.uidToWord (Posix.ProcEnv.getuid ()))
  fun posix_geteuid () = SysWord.toInt (Posix.ProcEnv.uidToWord (Posix.ProcEnv.geteuid ()))
  fun posix_getgid () = SysWord.toInt (Posix.ProcEnv.gidToWord (Posix.ProcEnv.getgid ()))
  fun posix_getegid () = SysWord.toInt (Posix.ProcEnv.gidToWord (Posix.ProcEnv.getegid ()))
  fun posix_setuid u = (Posix.ProcEnv.setuid (Posix.ProcEnv.wordToUid (SysWord.fromInt u)); 0)
                       handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_setgid g = (Posix.ProcEnv.setgid (Posix.ProcEnv.wordToGid (SysWord.fromInt g)); 0)
                       handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_getgroups () =
    List.map (fn g => SysWord.toInt (Posix.ProcEnv.gidToWord g)) (Posix.ProcEnv.getgroups ())
    handle OS.SysErr (_, e) => (noteError e; [])
  fun posix_getlogin () = Posix.ProcEnv.getlogin () handle OS.SysErr (_, e) => (noteError e; "")
  fun posix_getpgrp () = SysWord.toInt (Posix.Process.pidToWord (Posix.ProcEnv.getpgrp ()))
  fun posix_setsid () = SysWord.toInt (Posix.Process.pidToWord (Posix.ProcEnv.setsid ()))
                        handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_setpgid (pid, pgid) =
    (Posix.ProcEnv.setpgid {pid = if pid = 0 then NONE else SOME (Posix.Process.wordToPid (SysWord.fromInt pid)),
                            pgid = if pgid = 0 then NONE else SOME (Posix.Process.wordToPid (SysWord.fromInt pgid))};
     0)
    handle OS.SysErr (_, e) => (noteError e; ~1)
  (* in the order of the primitive; the hosts list the fields in orders of their own *)
  fun posix_uname () =
    let val fields = Posix.ProcEnv.uname ()
    in
      List.map (fn name => case List.find (fn (n, _) => n = name) fields of SOME (_, v) => v | NONE => "")
               ["sysname", "nodename", "release", "version", "machine"]
    end
  fun posix_times () =
    let val {elapsed, utime, stime, cutime, cstime} = Posix.ProcEnv.times ()
    in List.map (fn t => Int.fromLarge (Time.toMicroseconds t)) [elapsed, utime, stime, cutime, cstime] end
  fun posix_environ () = Posix.ProcEnv.environ ()
  fun posix_ctermid () = Posix.ProcEnv.ctermid ()
  fun posix_ttyname n = Posix.ProcEnv.ttyname (fdOf n) handle OS.SysErr (_, e) => (noteError e; "")
  fun posix_isatty n = (if Posix.ProcEnv.isatty (fdOf n) then 1 else 0) handle OS.SysErr _ => 0
  fun posix_sysconf name = SysWord.toInt (Posix.ProcEnv.sysconf name)
                           handle OS.SysErr (_, e) => (noteError e; ~1)

  fun posix_openf (path, flags, mode) =
    let
      val accessBits = Int.rem (flags, 4)
      val openMode = if accessBits = 1 then Posix.FileSys.O_WRONLY
                     else if accessBits = 2 then Posix.FileSys.O_RDWR
                     else Posix.FileSys.O_RDONLY
      val others = Posix.FileSys.O.fromWord (SysWord.fromInt (flags - accessBits - (if mode = 0 then 0 else 64)))
      val fd = if mode = 0 then Posix.FileSys.openf (path, openMode, others)
               else Posix.FileSys.createf (path, openMode, others,
                                           Posix.FileSys.S.fromWord (SysWord.fromInt mode))
    in fdNum fd end
    handle OS.SysErr (_, e) => (noteError e; ~1)

  fun posix_close n = (Posix.IO.close (fdOf n); 0) handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_dup n = fdNum (Posix.IO.dup (fdOf n)) handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_dup2 (old, new) = (Posix.IO.dup2 {old = fdOf old, new = fdOf new}; 0)
                              handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_pipe () =
    let val {infd, outfd} = Posix.IO.pipe () in [fdNum infd, fdNum outfd] end
    handle OS.SysErr (_, e) => (noteError e; [])
  (* errno is 0 after a read that succeeds, as posix_read promises *)
  fun posix_read (n, k) =
    if k < 0 then raise Size
    else (Byte.bytesToString (Posix.IO.readVec (fdOf n, k)) before lastErrno := 0)
         handle OS.SysErr (_, e) => (noteError e; "")
  fun posix_utime (path, access, modification) =
    (Posix.FileSys.utime (path, SOME {actime = Time.fromSeconds (Int.toLarge access),
                                      modtime = Time.fromSeconds (Int.toLarge modification)}); 0)
    handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_pathconf (path, n, name) =
    (case (if path = "" then Posix.FileSys.fpathconf (fdOf n, name) else Posix.FileSys.pathconf (path, name)) of
       NONE => [~1]
     | SOME w => [SysWord.toInt w])
    handle OS.SysErr (_, e) => (noteError e; [])
  (* the terminal, on the host's Posix.TTY; the numbers of the actions are
     Linux's (see posix_const). Poly/ML has no TC.getpgrp or setpgrp, so
     those two fail with ENOSYS on every host. *)
  fun posix_tcgetattr n =
    let
      val {iflag, oflag, cflag, lflag, cc, ispeed, ospeed} = Posix.TTY.fieldsOf (Posix.TTY.TC.getattr (fdOf n))
      fun w x = SysWord.toInt x
    in
      [w (Posix.TTY.I.toWord iflag), w (Posix.TTY.O.toWord oflag), w (Posix.TTY.C.toWord cflag),
       w (Posix.TTY.L.toWord lflag), w (Posix.TTY.speedToWord ispeed), w (Posix.TTY.speedToWord ospeed)]
      @ List.tabulate (Posix.TTY.V.nccs, fn i => ord (Posix.TTY.V.sub (cc, i)))
    end
    handle OS.SysErr (_, e) => (noteError e; [])
  fun posix_tcsetattr (n, action, fields) =
    (case fields of
       iflag :: oflag :: cflag :: lflag :: ispeed :: ospeed :: cc =>
         let
           fun w x = SysWord.fromInt x
           val t = Posix.TTY.termios
                     {iflag = Posix.TTY.I.fromWord (w iflag), oflag = Posix.TTY.O.fromWord (w oflag),
                      cflag = Posix.TTY.C.fromWord (w cflag), lflag = Posix.TTY.L.fromWord (w lflag),
                      cc = Posix.TTY.V.cc (List.tabulate (List.length cc, fn i => (i, chr (List.nth (cc, i))))),
                      ispeed = Posix.TTY.wordToSpeed (w ispeed), ospeed = Posix.TTY.wordToSpeed (w ospeed)}
           val a = if action = 1 then Posix.TTY.TC.sadrain else if action = 2 then Posix.TTY.TC.saflush
                   else Posix.TTY.TC.sanow
         in Posix.TTY.TC.setattr (fdOf n, a, t); 0 end
     | _ => (lastErrno := posix_const "EINVAL"; ~1))
    handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_tcop (op', n, argument) =
    (case op' of
       0 => (Posix.TTY.TC.drain (fdOf n); 0)
     | 1 => (Posix.TTY.TC.flush (fdOf n, if argument = 1 then Posix.TTY.TC.oflush
                                         else if argument = 2 then Posix.TTY.TC.ioflush
                                         else Posix.TTY.TC.iflush); 0)
     | 2 => (Posix.TTY.TC.flow (fdOf n, if argument = 1 then Posix.TTY.TC.oon
                                        else if argument = 2 then Posix.TTY.TC.ioff
                                        else if argument = 3 then Posix.TTY.TC.ion
                                        else Posix.TTY.TC.ooff); 0)
     | 3 => (Posix.TTY.TC.sendbreak (fdOf n, argument); 0)
     | _ => (lastErrno := posix_const "ENOSYS"; ~1))
    handle OS.SysErr (_, e) => (noteError e; ~1)

  (* the host's locks, in the numbers of the system *)
  fun posix_lock (n, command, ltype, whence, start, len) =
    let
      fun lt t = if t = posix_const "F_RDLCK" then Posix.IO.F_RDLCK
                 else if t = posix_const "F_WRLCK" then Posix.IO.F_WRLCK else Posix.IO.F_UNLCK
      fun ltNum Posix.IO.F_RDLCK = posix_const "F_RDLCK"
        | ltNum Posix.IO.F_WRLCK = posix_const "F_WRLCK"
        | ltNum Posix.IO.F_UNLCK = posix_const "F_UNLCK"
      fun wh w = if w = posix_const "SEEK_CUR" then Posix.IO.SEEK_CUR
                 else if w = posix_const "SEEK_END" then Posix.IO.SEEK_END else Posix.IO.SEEK_SET
      fun whNum Posix.IO.SEEK_SET = posix_const "SEEK_SET"
        | whNum Posix.IO.SEEK_CUR = posix_const "SEEK_CUR"
        | whNum Posix.IO.SEEK_END = posix_const "SEEK_END"
      val fl = Posix.IO.FLock.flock {ltype = lt ltype, whence = wh whence, start = Position.fromInt start,
                                     len = Position.fromInt len, pid = NONE}
      val got = if command = posix_const "F_GETLK" then Posix.IO.getlk (fdOf n, fl)
                else if command = posix_const "F_SETLKW" then Posix.IO.setlkw (fdOf n, fl)
                else Posix.IO.setlk (fdOf n, fl)
    in
      [ltNum (Posix.IO.FLock.ltype got), whNum (Posix.IO.FLock.whence got),
       Position.toInt (Posix.IO.FLock.start got), Position.toInt (Posix.IO.FLock.len got),
       (* the system leaves the pid of a segment without a lock as it was
          given, which is 0 on the VM; SML/NJ gives one it did not set *)
       case (Posix.IO.FLock.ltype got, Posix.IO.FLock.pid got) of
         (Posix.IO.F_UNLCK, _) => 0
       | (_, SOME p) => SysWord.toInt (Posix.Process.pidToWord p)
       | (_, NONE) => 0]
    end
    handle OS.SysErr (_, e) => (noteError e; [])
  fun posix_write (n, s) =
    Posix.IO.writeVec (fdOf n, Word8VectorSlice.full (Byte.stringToBytes s))
    handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_lseek (n, offset, whence) =
    Position.toInt (Posix.IO.lseek (fdOf n, Position.fromInt offset,
                                    if whence = 0 then Posix.IO.SEEK_SET
                                    else if whence = 1 then Posix.IO.SEEK_CUR
                                    else Posix.IO.SEEK_END))
    handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_fsync n = (Posix.IO.fsync (fdOf n); 0) handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_fcntl (n, command, argument) =
    (case command of
       0 => fdNum (Posix.IO.dupfd {old = fdOf n, base = fdOf argument})
     | 1 => SysWord.toInt (Posix.IO.FD.toWord (Posix.IO.getfd (fdOf n)))
     | 2 => (Posix.IO.setfd (fdOf n, Posix.IO.FD.fromWord (SysWord.fromInt argument)); 0)
     | 3 => let val (flags, mode) = Posix.IO.getfl (fdOf n)
            in SysWord.toInt (Posix.IO.O.toWord flags)
               + (case mode of Posix.FileSys.O_RDONLY => 0 | Posix.FileSys.O_WRONLY => 1 | Posix.FileSys.O_RDWR => 2)
            end
     | _ => (Posix.IO.setfl (fdOf n, Posix.IO.O.fromWord (SysWord.fromInt argument)); 0))
    handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_ftruncate (n, length) =
    (Posix.FileSys.ftruncate (fdOf n, Position.fromInt length); 0)
    handle OS.SysErr (_, e) => (noteError e; ~1)

  fun posix_stat (path, follow, n) =
    let
      val st = if path = "" then Posix.FileSys.fstat (fdOf n)
               else if follow = 1 then Posix.FileSys.lstat path
               else Posix.FileSys.stat path
      val kind = if Posix.FileSys.ST.isReg st then 0
                 else if Posix.FileSys.ST.isDir st then 1
                 else if Posix.FileSys.ST.isLink st then 2
                 else if Posix.FileSys.ST.isFIFO st then 4
                 else if Posix.FileSys.ST.isSock st then 5
                 else if Posix.FileSys.ST.isChr st then 6
                 else if Posix.FileSys.ST.isBlk st then 7
                 else 3
    in
      [kind, SysWord.toInt (Posix.FileSys.S.toWord (Posix.FileSys.ST.mode st)),
       SysWord.toInt (Posix.FileSys.inoToWord (Posix.FileSys.ST.ino st)),
       SysWord.toInt (Posix.FileSys.devToWord (Posix.FileSys.ST.dev st)),
       Posix.FileSys.ST.nlink st,
       SysWord.toInt (Posix.ProcEnv.uidToWord (Posix.FileSys.ST.uid st)),
       SysWord.toInt (Posix.ProcEnv.gidToWord (Posix.FileSys.ST.gid st)),
       Position.toInt (Posix.FileSys.ST.size st),
       Int.fromLarge (Time.toSeconds (Posix.FileSys.ST.atime st)),
       Int.fromLarge (Time.toSeconds (Posix.FileSys.ST.mtime st)),
       Int.fromLarge (Time.toSeconds (Posix.FileSys.ST.ctime st))]
    end
    handle OS.SysErr (_, e) => (noteError e; [])

  fun posix_chmod (path, n, mode) =
    ((if path = "" then Posix.FileSys.fchmod (fdOf n, Posix.FileSys.S.fromWord (SysWord.fromInt mode))
      else Posix.FileSys.chmod (path, Posix.FileSys.S.fromWord (SysWord.fromInt mode)));
     0)
    handle OS.SysErr (_, e) => (noteError e; ~1)

  fun posix_chown (path, n, uid, gid) =
    ((if path = "" then Posix.FileSys.fchown (fdOf n, Posix.ProcEnv.wordToUid (SysWord.fromInt uid),
                                              Posix.ProcEnv.wordToGid (SysWord.fromInt gid))
      else Posix.FileSys.chown (path, Posix.ProcEnv.wordToUid (SysWord.fromInt uid),
                                Posix.ProcEnv.wordToGid (SysWord.fromInt gid)));
     0)
    handle OS.SysErr (_, e) => (noteError e; ~1)

  fun posix_link (from, to) = (Posix.FileSys.link {old = from, new = to}; 0)
                              handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_symlink (from, to) = (Posix.FileSys.symlink {old = from, new = to}; 0)
                                 handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_mkfifo (path, mode) =
    (Posix.FileSys.mkfifo (path, Posix.FileSys.S.fromWord (SysWord.fromInt mode)); 0)
    handle OS.SysErr (_, e) => (noteError e; ~1)
  fun posix_umask mask =
    SysWord.toInt (Posix.FileSys.S.toWord (Posix.FileSys.umask (Posix.FileSys.S.fromWord (SysWord.fromInt mask))))

  fun posix_getpw (name, uid) =
    let
      val pw = if name = "" then Posix.SysDB.getpwuid (Posix.ProcEnv.wordToUid (SysWord.fromInt uid))
               else Posix.SysDB.getpwnam name
    in
      [Posix.SysDB.Passwd.name pw, Posix.SysDB.Passwd.home pw, Posix.SysDB.Passwd.shell pw,
       Int.toString (SysWord.toInt (Posix.ProcEnv.uidToWord (Posix.SysDB.Passwd.uid pw))),
       Int.toString (SysWord.toInt (Posix.ProcEnv.gidToWord (Posix.SysDB.Passwd.gid pw)))]
    end
    handle OS.SysErr (_, e) => (noteError e; [])

  (* ---- sockets and the network databases ----
     The hosts keep a socket and its address behind types that carry the
     family and the mode, where the library passes numbers and bytes; the
     cross-check leaves them out (XC1-N/A), and every call fails with ENOSYS. *)
  fun unsupported onFailure = (lastErrno := posix_const "ENOSYS"; onFailure)
  fun socket_create (_ : int, _ : int, _ : int) = unsupported ~1
  fun socket_pair (_ : int, _ : int, _ : int) : int list = unsupported []
  fun socket_bind (_ : int, _ : string) = unsupported ~1
  fun socket_connect (_ : int, _ : string) = unsupported ~1
  fun socket_listen (_ : int, _ : int) = unsupported ~1
  fun socket_accept (_ : int) = unsupported ~1
  fun socket_send (_ : int, _ : string, _ : int) = unsupported ~1
  fun socket_sendto (_ : int, _ : string, _ : int, _ : string) = unsupported ~1
  fun socket_recv (_ : int, _ : int, _ : int) = unsupported ""
  fun socket_recvfrom (_ : int, _ : int, _ : int) : string list = unsupported []
  fun socket_shutdown (_ : int, _ : int) = unsupported ~1
  fun socket_name (_ : int) = unsupported ""
  fun socket_peer (_ : int) = unsupported ""
  fun socket_getopt (_ : int, _ : int, _ : int) = unsupported ~1
  fun socket_setopt (_ : int, _ : int, _ : int, _ : int) = unsupported ~1
  fun socket_inet_addr (_ : string, _ : int) = unsupported ""
  fun socket_inet6_addr (_ : string, _ : int) = unsupported ""
  fun socket_unix_addr (_ : string) = unsupported ""
  fun socket_addr_family (_ : string) = unsupported ~1
  fun socket_inet_parts (_ : string) : string list = unsupported []
  fun socket_inet6_parts (_ : string) : string list = unsupported []
  fun socket_unix_path (_ : string) = unsupported ""
  fun socket_linger (_ : int, _ : int, _ : int) : int list = unsupported []
  fun socket_query (_ : int, _ : int) = unsupported ~1
  fun netdb_host_byname (_ : string) : string list = unsupported []
  fun netdb_host_byaddr (_ : string) : string list = unsupported []
  fun netdb_hostname () = unsupported ""
  fun netdb_proto_byname (_ : string) : string list = unsupported []
  fun netdb_proto_bynumber (_ : int) : string list = unsupported []
  fun netdb_serv_byname (_ : string, _ : string) : string list = unsupported []
  fun netdb_serv_byport (_ : int, _ : string) : string list = unsupported []

  (* ---- the structure Windows: Windows' own, which fails with ENOSYS on
     every host, as on a VM of another system ---- *)
  fun win_reg_open (_ : int, _ : string, _ : int, _ : int) : int list = unsupported []
  fun win_reg_close (_ : int) = unsupported ~1
  fun win_reg_delete (_ : int, _ : string, _ : int) = unsupported ~1
  fun win_reg_enum (_ : int, _ : int, _ : int) : string list = unsupported []
  fun win_reg_query (_ : int, _ : string) : string list = unsupported []
  fun win_reg_set (_ : int, _ : string, _ : int, _ : string) = unsupported ~1
  fun win_config (_ : int) = unsupported ""
  fun win_version () : string list = unsupported []
  fun win_volume (_ : string) : string list = unsupported []
  fun win_find_executable (_ : string) : string list = unsupported []
  fun win_shell_execute (_ : string, _ : string, _ : int) = unsupported ~1
  fun win_spawn (_ : string, _ : string, _ : int list) = unsupported ~1
  fun win_wait (_ : int) : int list = unsupported []
  fun win_dde_start (_ : string, _ : string) = unsupported ~1
  fun win_dde_execute (_ : int, _ : string, _ : int, _ : int) = unsupported ~1
  fun win_dde_stop (_ : int) = unsupported ~1

  (* Runtime: the counters of Rune's VM. A host counts none of them -- it has
     neither Rune's instructions nor Rune's heap -- and lib/basis/runtime.sml
     is `host = no` in the MANIFEST, so nothing here calls these. *)
  fun rt_instructions () = unsupported ~1
  fun rt_bytes () = unsupported ~1
  fun rt_objects () = unsupported ~1
  fun rt_collections () = unsupported ~1
  fun rt_live () = unsupported ~1
  fun rt_heap_size () = unsupported ~1
  fun rt_collect () = unsupported ()
  fun rt_version () = unsupported ""
  fun rt_trace (_ : int) : (string * string * int * int) list = unsupported []
  fun rt_save (_ : string) = unsupported ~1
  fun rt_restore (_ : string) = unsupported ~1

  fun posix_getgr (name, gid) =
    let
      val gr = if name = "" then Posix.SysDB.getgrgid (Posix.ProcEnv.wordToGid (SysWord.fromInt gid))
               else Posix.SysDB.getgrnam name
    in
      Posix.SysDB.Group.name gr
      :: Int.toString (SysWord.toInt (Posix.ProcEnv.gidToWord (Posix.SysDB.Group.gid gr)))
      :: Posix.SysDB.Group.members gr
    end
    handle OS.SysErr (_, e) => (noteError e; [])
end

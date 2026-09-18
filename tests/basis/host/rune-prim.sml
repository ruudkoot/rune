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
     r - floor r is exact, so the three cases are decided exactly. *)
  fun real_round r =
    let
      val below = Real.floor r
      val d = Real.- (r, Real.fromInt below)
    in
      if Real.< (d, 0.5) then below
      else if Real.> (d, 0.5) orelse Int.rem (below, 2) <> 0 then Int.+ (below, 1)
      else below
    end
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
  val real_atan = Math.atan
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
  val real_sinh = Math.sinh
  fun real_cosh x = Math.cosh (Real.abs x)   (* even; MLton gives ~inf for ~inf *)
  val real_tanh = Math.tanh

  (* ---- char and string ---- *)
  val char_ord = Char.ord
  val char_lt = Char.<
  val char_le = Char.<=
  val char_gt = Char.>
  val char_ge = Char.>=
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
  fun sys_error_name e =
    case Posix.Error.errorName (errorOf e) of
      "" => ""
    | name => "E" ^ String.map Char.toUpper name
  fun sys_error_of_name name =
    if String.size name < 2 orelse String.sub (name, 0) <> #"E" then ~1
    else
      case Posix.Error.syserror (String.map Char.toLower (String.extract (name, 1, NONE))) of
        SOME e => SysWord.toInt (Posix.Error.toWord e)
      | NONE => ~1

  fun time_now () = Int.fromLarge (Time.toMicroseconds (Time.now ()))
  val cpu = Timer.totalCPUTimer ()
  fun time_user () = Int.fromLarge (Time.toMicroseconds (#usr (Timer.checkCPUTimer cpu)))
  fun time_sys () = Int.fromLarge (Time.toMicroseconds (#sys (Timer.checkCPUTimer cpu)))
  fun time_sleep n = if n <= 0 then () else OS.Process.sleep (Time.fromMicroseconds (Int.toLarge n))

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

  (* The status of the host's OS.Process.system is abstract, so the command
     is run here: what it exited with, or 128 plus the signal that ended it. *)
  fun os_system command =
    case Posix.Process.fork () of
      NONE =>
        ((Posix.Process.exece ("/bin/sh", ["sh", "-c", command], Posix.ProcEnv.environ ())) ;
         Posix.Process.exit 0w127)
    | SOME pid =>
        (case #2 (Posix.Process.waitpid (Posix.Process.W_CHILD pid, [])) of
           Posix.Process.W_EXITED => 0
         | Posix.Process.W_EXITSTATUS w => Word8.toInt w
         | Posix.Process.W_SIGNALED sg => 128 + SysWord.toInt (Posix.Signal.toWord sg)
         | Posix.Process.W_STOPPED sg => 128 + SysWord.toInt (Posix.Signal.toWord sg))
  fun os_getenv name = OS.Process.getEnv name
end

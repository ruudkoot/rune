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
  val real_from_string = Real.fromString
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
      Reader of {fd : Posix.IO.file_desc, buf : string ref, pos : int ref, eof : bool ref}
    | Writer of Posix.IO.file_desc
  val files : (int * file) list ref = ref []
  val next = ref 3
  val lastError = ref ""
  val rw = FS.S.flags [FS.S.irusr, FS.S.iwusr, FS.S.irgrp, FS.S.iwgrp, FS.S.iroth, FS.S.iwoth]

  fun lookup h =
    let fun go [] = NONE
          | go ((h', f) :: rest) = if h = h' then SOME f else go rest
    in go (!files) end

  fun file_open (name, mode) =
    let
      val f = case mode of
                0 => Reader {fd = FS.openf (name, FS.O_RDONLY, FS.O.flags []),
                             buf = ref "", pos = ref 0, eof = ref false}
              | 1 => Writer (FS.createf (name, FS.O_WRONLY, FS.O.trunc, rw))
              | _ => Writer (FS.createf (name, FS.O_WRONLY, FS.O.append, rw))
      val h = !next
    in next := h + 1; files := (h, f) :: !files; SOME h end
    handle OS.SysErr (msg, _) => (lastError := msg; NONE)

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
      handle OS.SysErr (msg, _) => (lastError := msg; false)

  fun file_flush 1 = TextIO.flushOut TextIO.stdOut
    | file_flush 2 = TextIO.flushOut TextIO.stdErr
    | file_flush _ = ()

  (* fill: append what the file has to the buffer; false at end of file, and
     from then on. *)
  fun fill {fd, buf, pos, eof} =
    if !eof then false
    else
      let val more = Byte.bytesToString (Posix.IO.readVec (fd, 65536))
      in
        if more = "" then (eof := true; false)
        else (buf := String.extract (!buf, !pos, NONE) ^ more; pos := 0; true)
      end

  fun readLine (r as {buf, pos, ...} : {fd : Posix.IO.file_desc, buf : string ref, pos : int ref, eof : bool ref}) =
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

  fun file_read_all 0 = TextIO.inputAll TextIO.stdIn
    | file_read_all h =
      (case lookup h of
         SOME (Reader {fd, buf, pos, eof}) =>
           let
             val buffered = String.extract (!buf, !pos, NONE)
             fun go acc =
               let val more = Byte.bytesToString (Posix.IO.readVec (fd, 65536))
               in if more = "" then (eof := true; String.concat (List.rev acc)) else go (more :: acc) end
           in buf := ""; pos := 0; go [buffered] end
       | _ => "")

  fun file_error () = !lastError
end

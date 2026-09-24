(* The .rbc format read back, as the loader of runevm reads it (vm/loader.c):
   a file that the loader refuses is refused here, at the same point and with
   the same message. docs/bytecode.md is the format; docs/native.md is
   how runeopt translates, which this is the first part of.

   A number of the file is a u32 or an i32, and an int has 31 bits on one of
   the hosts, so no number is read into an int that could not hold it. A
   length or a count of 2^30 or more reads as 2^30 - 1, which no bound of the
   loader admits and no file this reader can hold is long enough for, so it
   is refused where the loader refuses it. An operand says whether it lies
   above or below the range an int holds. *)
structure Rbc =
struct
  exception Bad of string

  datatype const =
      CInt of IntInf.int
    | CWord of IntInf.int            (* 0 .. 2^64 - 1 *)
    | CReal of string                (* the text, in C strtod syntax *)
    | CString of string
    | CChar of int

  (* A function's code runs from offset to stop, where the next one begins. *)
  type func = {offset : int, nlocals : int, name : string, stop : int}
  type line = {pc : int, file : int, line : int, col : int}

  type program =
    {consts : const vector,
     nglobals : int,
     funcs : func vector,
     code : string,
     files : string vector,
     lines : line vector}

  (* An operand: an i32, which is an int when it lies in -2^30 .. 2^30 - 1. *)
  datatype operand = In of int | Above | Below

  (* 2^30 - 1, the largest int on the 32-bit SML/NJ. Read from a string
     rather than written as a literal: SML/NJ 110.99.9 in 32 bits compiles
     `big - x`, for a literal big that is its Int.maxInt, into code that
     overflows whatever x is. *)
  val big = valOf (Int.fromString "1073741823")
  val builtinExns = 8               (* NUM_BUILTIN_EXNS of vm/vm.h *)

  fun byte (s, i) = Char.ord (String.sub (s, i))

  (* Four bytes, little-endian, as a natural number: big for 2^30 or more. *)
  fun u32At (s, i) =
    let val b3 = byte (s, i + 3)
    in
      if b3 >= 64 then big
      else ((b3 * 256 + byte (s, i + 2)) * 256 + byte (s, i + 1)) * 256 + byte (s, i)
    end

  fun i32At (s, i) : operand =
    let
      val b3 = byte (s, i + 3)
      val low = (byte (s, i + 2) * 256 + byte (s, i + 1)) * 256 + byte (s, i)
    in
      if b3 < 64 then In (b3 * 16777216 + low)
      else if b3 >= 192 then In ((b3 - 256) * 16777216 + low)
      else if b3 < 128 then Above
      else Below
    end

  (* SML's sign as C's: "~5" as "-5". *)
  fun minus (t : string) : string =
    if String.isPrefix "~" t then "-" ^ String.extract (t, 1, NONE) else t

  (* The operand as a decimal number with a minus sign, whatever its size,
     which is how the disassembler of the VM prints it. *)
  fun i32Text (s, i) : string =
    case i32At (s, i) of
      In n => minus (Int.toString n)
    | _ =>
        let
          fun b k = IntInf.fromInt (byte (s, i + k))
          val b256 = IntInf.fromInt 256
          val u = IntInf.+ (IntInf.* (IntInf.+ (IntInf.* (IntInf.+ (IntInf.* (b 3, b256), b 2), b256), b 1), b256), b 0)
          val v = if IntInf.>= (u, IntInf.pow (IntInf.fromInt 2, 31))
                  then IntInf.- (u, IntInf.pow (IntInf.fromInt 2, 32)) else u
        in
          minus (IntInf.toString v)
        end

  (* The reader: the bytes, where it is, and whether a read has run past the
     end, which the loader looks at after a run of reads, not after each. *)
  type reader = {data : string, pos : int ref, error : bool ref}

  fun need ({data, pos, error} : reader, n : int) : bool =
    if n > String.size data - !pos then (error := true; false) else true

  fun rdU8 (r as {data, pos, ...} : reader) : int =
    if need (r, 1) then (pos := !pos + 1; byte (data, !pos - 1)) else 0

  fun rdU32 (r as {data, pos, ...} : reader) : int =
    if need (r, 4) then (pos := !pos + 4; u32At (data, !pos - 4)) else 0

  val two64 = IntInf.pow (IntInf.fromInt 2, 64)
  val two63 = IntInf.pow (IntInf.fromInt 2, 63)

  (* Eight bytes as a natural number below 2^64. *)
  fun rdU64 (r as {data, pos, ...} : reader) : IntInf.int =
    if not (need (r, 8)) then IntInf.fromInt 0
    else
      let
        val p = !pos
        fun go (k, acc) =
          if k < 0 then acc
          else go (k - 1, IntInf.+ (IntInf.* (acc, IntInf.fromInt 256), IntInf.fromInt (byte (data, p + k))))
      in
        pos := p + 8;
        go (7, IntInf.fromInt 0)
      end

  fun signed64 (u : IntInf.int) : IntInf.int =
    if IntInf.>= (u, two63) then IntInf.- (u, two64) else u

  fun take ({data, pos, ...} : reader, n : int) : string =
    let val s = String.substring (data, !pos, n) in pos := !pos + n; s end

  fun fail msg = raise Bad msg

  (* A number of the line table, seven bits at a time, least significant
     first. Broken where it does not end before the table does or does not
     fit 64 bits, which the loader refuses as a bad table; Wide where it fits
     64 bits but not an int. *)
  datatype varnum = Num of int | Wide | Broken

  fun uvar (data : string, q : int ref, stop : int) : varnum =
    let
      (* the groups of seven bits, the last read (the most significant) first *)
      fun groups (shift, acc) =
        if !q >= stop then NONE
        else
          let
            val b = byte (data, !q)
            val () = q := !q + 1
            val low = b mod 128
          in
            if shift > 63 orelse (shift = 63 andalso low > 1) then NONE
            else if b < 128 then SOME (low :: acc)
            else groups (shift + 7, low :: acc)
          end
      (* v * 128 + g is computed only where it cannot pass big *)
      fun value ([], v) = Num v
        | value (g :: gs, v) = if v > (big - g) div 128 then Wide else value (gs, v * 128 + g)
    in
      case groups (0, []) of
        NONE => Broken
      | SOME gs => value (gs, 0)
    end

  fun svar (data, q, stop) : varnum =
    case uvar (data, q, stop) of
      Num v => Num (if v mod 2 = 1 then ~ (v div 2) - 1 else v div 2)
    | other => other

  (* The line table, as load_program decodes and checks it. A line or a
     column of 2^30 or more, which the loader takes up to 2^31 - 1, is out
     of range here: no host may be asked to hold it in an int. *)
  fun lineTable (data : string, start : int, len : int, n : int, codeLen : int, nfiles : int) : line vector =
    let
      val q = ref start
      val stop = start + len
      fun outOfRange () = fail "line table out of range"
      (* acc + d, or out of range if it would leave 0 .. big *)
      fun add (acc, d) =
        if d > 0 andalso acc > big - d then outOfRange () else acc + d
      fun entries (i, pc, file, line, col, acc) =
        if i = n then acc
        else
          let
            val dpc = uvar (data, q, stop)
            val dfile = case dpc of Broken => Broken | _ => svar (data, q, stop)
            val dline = case dfile of Broken => Broken | _ => svar (data, q, stop)
            val dcol = case dline of Broken => Broken | _ => svar (data, q, stop)
            fun num (Num v) = v | num _ = outOfRange ()
          in
            case (dpc, dfile, dline, dcol) of
              (Broken, _, _, _) => fail "bad line table"
            | (_, Broken, _, _) => fail "bad line table"
            | (_, _, Broken, _) => fail "bad line table"
            | (_, _, _, Broken) => fail "bad line table"
            | _ =>
                let
                  val dp = num dpc
                  val () = if dp > codeLen then outOfRange () else ()
                  val pc' = add (pc, dp)
                  val file' = add (file, num dfile)
                  val line' = add (line, num dline)
                  val col' = add (col, num dcol)
                in
                  if pc' >= codeLen orelse file' < 0 orelse file' >= nfiles orelse line' < 1 orelse col' < 1
                  then outOfRange ()
                  else entries (i + 1, pc', file', line', col',
                                {pc = pc', file = file', line = line', col = col'} :: acc)
                end
          end
      val es = entries (0, 0, 0, 0, 0, [])
    in
      if !q <> stop then fail "bad line table" else Vector.fromList (List.rev es)
    end

  (* The byte length of an instruction, or 0 for an opcode there is not. *)
  fun instrLength (opc : int) : int =
    if opc < 0 orelse opc >= Opcodes.count then 0 else 1 + 4 * Vector.sub (Opcodes.nargs, opc)

  (* validate_program: the functions, then every instruction and its
     operands, then every jump target and function entry, which must be where
     an instruction begins. The instruction starts, for whoever reads on. *)
  fun validate (p : program) : bool array =
    let
      val code = #code p
      val codeLen = String.size code
      val funcs = #funcs p
      val nfuncs = Vector.length funcs
      val nconsts = Vector.length (#consts p)
      val () =
        Vector.appi
          (fn (i, {offset, nlocals, stop, ...} : func) =>
             (if offset >= codeLen then fail "function offset out of range" else ();
              if i > 0 andalso offset < #offset (Vector.sub (funcs, i - 1)) then fail "functions out of order" else ();
              if nlocals < 1 orelse nlocals > 1000000 then fail "bad frame size" else ();
              if stop <> (if i + 1 < nfuncs then #offset (Vector.sub (funcs, i + 1)) else codeLen)
              then fail "function does not end where the next begins" else ()))
          funcs
      val starts = Array.array (codeLen + 1, false)
      fun badOperand (opc, pc) =
        fail ("bad operand for " ^ Vector.sub (Opcodes.names, opc) ^ " at " ^ Int.toString pc)
      fun within (x, lo, hi) = case x of In v => v >= lo andalso v <= hi | _ => false
      fun nonneg x = case x of In v => v >= 0 | Above => true | Below => false
      fun scan (pc, fi) =
        if pc >= codeLen then ()
        else
          let
            fun advance fi = if fi + 1 < nfuncs andalso pc >= #offset (Vector.sub (funcs, fi + 1)) then advance (fi + 1) else fi
            val fi = advance fi
            val opc = byte (code, pc)
            val len = instrLength opc
            val () = if len = 0 then fail ("invalid opcode " ^ Int.toString opc ^ " at " ^ Int.toString pc) else ()
            val () = if pc + len > codeLen then fail "truncated instruction" else ()
            val () = Array.update (starts, pc, true)
            (* each operand by its kind (src/isa/isa.sml), as the loader
               checks it; a label is checked below, once every instruction's
               start is known *)
            fun operandOk ((_, kind), (k, ok)) =
              let
                val x = i32At (code, pc + 1 + 4 * k)
                val good =
                  case kind of
                    Isa.Constant => within (x, 0, nconsts - 1)
                  | Isa.StringConstant =>
                      (case x of
                         In c => c >= 0 andalso c < nconsts
                                 andalso (case Vector.sub (#consts p, c) of CString _ => true | _ => false)
                       | _ => false)
                  | Isa.Immediate => true
                  | Isa.Tag => within (x, 0, 65535)
                  | Isa.Local => within (x, 0, #nlocals (Vector.sub (funcs, fi)) - 1)
                  | Isa.EnvSlot => nonneg x
                  | Isa.Global => within (x, 0, #nglobals p - 1)
                  | Isa.Function => within (x, 0, nfuncs - 1)
                  | Isa.Label => true
                  | Isa.HandlerLabel => true
                  | Isa.Primitive => within (x, 0, List.length Prims.table - 1)
                  | Isa.Count => within (x, 0, 1000000)
                  | Isa.Field => nonneg x
                  | Isa.BuiltinExn => within (x, 0, builtinExns - 1)
              in
                (k + 1, ok andalso good)
              end
            val ok = #2 (List.foldl operandOk (0, true) (#operands (Vector.sub (StackIsa.info, opc))))
          in
            if ok then scan (pc + len, fi) else badOperand (opc, pc)
          end
      val () = scan (0, 0)
      fun targets pc =
        if pc >= codeLen then ()
        else
          let
            val opc = byte (code, pc)
            val len = instrLength opc
          in
            List.foldl
              (fn ((_, kind), k) =>
                 (if kind = Isa.Label orelse kind = Isa.HandlerLabel then
                    (case i32At (code, pc + 1 + 4 * k) of
                       In t => if t < 0 orelse t >= codeLen orelse not (Array.sub (starts, t))
                               then fail ("bad jump target at " ^ Int.toString pc) else ()
                     | _ => fail ("bad jump target at " ^ Int.toString pc))
                  else ();
                  k + 1))
              0 (#operands (Vector.sub (StackIsa.info, opc)));
            targets (pc + len)
          end
      val () = targets 0
      val () =
        Vector.app (fn {offset, ...} : func =>
                      if Array.sub (starts, offset) then () else fail "function entry is not an instruction")
          funcs
    in
      starts
    end

  (* The program of a .rbc, given the whole file; Bad with the message the
     loader gives where it refuses the file. *)
  fun read (data : string) : program =
    let
      val r = {data = data, pos = ref 0, error = ref false} : reader
      val () = if not (need (r, 8)) orelse String.substring (data, 0, 4) <> "RUNE"
               then fail "not a Rune bytecode file" else ()
      val () = #pos r := 4
      val () = if rdU32 r <> Opcodes.rbcVersion then fail "unsupported bytecode version" else ()
      val () = if rdU32 r <> Opcodes.fingerprint then fail "bytecode of another instruction set" else ()

      val nconsts = rdU32 r
      val () = if !(#error r) orelse nconsts > 10000000 then fail "bad constant table" else ()
      fun const () =
        case rdU8 r of
          0 => CInt (signed64 (rdU64 r))
        | 1 => CWord (rdU64 r)
        | 2 => let val n = rdU32 r
               in if not (need (r, n)) orelse n > 64 then fail "bad real constant" else CReal (take (r, n)) end
        | 3 => let val n = rdU32 r
               in if not (need (r, n)) then fail "bad string constant" else CString (take (r, n)) end
        | 4 => CChar (rdU8 r)
        | _ => fail "bad constant kind"
      fun consts (i, acc) =
        if i = nconsts then Vector.fromList (List.rev acc)
        else
          let val c = const ()
          in if !(#error r) then fail "truncated constant table" else consts (i + 1, c :: acc) end
      val consts = consts (0, [])

      val nglobals = rdU32 r
      val () = if !(#error r) orelse nglobals > 10000000 then fail "bad global count" else ()

      val nfuncs = rdU32 r
      val () = if !(#error r) orelse nfuncs = 0 orelse nfuncs > 10000000 then fail "bad function table" else ()
      fun funcs (i, prev, acc) =
        if i = nfuncs then List.rev acc
        else
          let
            val offset = rdU32 r
            val nlocals = rdU32 r
            val n = rdU32 r
            val () = if not (need (r, n)) then fail "bad function name" else ()
            val name = take (r, n)
            val () = if nlocals < 1 orelse nlocals > 1000000 then fail "bad frame size" else ()
            val () = if i > 0 andalso offset < prev then fail "functions out of order" else ()
          in
            funcs (i + 1, offset, (offset, nlocals, name) :: acc)
          end
      val fs = funcs (0, 0, [])

      val codeLen = rdU32 r
      val () = if !(#error r) orelse not (need (r, codeLen)) then fail "truncated code" else ()
      val code = take (r, codeLen)

      val nfiles = rdU32 r
      val () = if !(#error r) orelse nfiles > 1000000 then fail "bad file table" else ()
      fun files (i, acc) =
        if i = nfiles then Vector.fromList (List.rev acc)
        else
          let
            val n = rdU32 r
            val () = if not (need (r, n)) then fail "bad file name" else ()
          in
            files (i + 1, take (r, n) :: acc)
          end
      val files = files (0, [])
      val nlines = rdU32 r
      val tableLen = rdU32 r
      val () = if !(#error r) orelse nlines > 100000000 orelse not (need (r, tableLen)) then fail "bad line table" else ()
      val lines = lineTable (data, !(#pos r), tableLen, nlines, codeLen, nfiles)

      val fv = Vector.fromList fs
      val funcs =
        Vector.mapi
          (fn (i, (offset, nlocals, name)) =>
             {offset = offset, nlocals = nlocals, name = name,
              stop = if i + 1 < nfuncs then #1 (Vector.sub (fv, i + 1)) else codeLen})
          fv
      val p = {consts = consts, nglobals = nglobals, funcs = funcs, code = code, files = files, lines = lines}
      val _ = validate p
    in
      p
    end

  (* The bytes of a file, as load_program reads them. *)
  fun readBytes (path : string) : string =
    let
      val ins = BinIO.openIn path handle IO.Io _ => fail "cannot open file"
      val data = Byte.bytesToString (BinIO.inputAll ins) handle IO.Io _ => (BinIO.closeIn ins; fail "cannot read file")
    in
      BinIO.closeIn ins;
      data
    end

  fun readFile (path : string) : program = read (readBytes path)

  (* ---- writing ---- *)

  (* n as `bytes` bytes, little-endian, two's complement below zero *)
  fun leInf (n : IntInf.int, bytes : int) : string =
    let
      val b256 = IntInf.fromInt 256
      fun go (0, _) = []
        | go (k, v) = Char.chr (IntInf.toInt (IntInf.mod (v, b256))) :: go (k - 1, IntInf.div (v, b256))
    in
      String.implode (go (bytes, IntInf.mod (n, IntInf.pow (IntInf.fromInt 2, 8 * bytes))))
    end

  fun le32 (n : int) = leInf (IntInf.fromInt n, 4)

  (* the numbers of the line table, as load_program reads them *)
  fun uvarText (v : IntInf.int) : string =
    let val b128 = IntInf.fromInt 128
    in
      if IntInf.< (v, b128) then String.str (Char.chr (IntInf.toInt v))
      else String.str (Char.chr (128 + IntInf.toInt (IntInf.mod (v, b128)))) ^ uvarText (IntInf.div (v, b128))
    end

  fun svarText (n : int) : string =
    let val v = IntInf.fromInt n
    in uvarText (if n >= 0 then IntInf.* (v, IntInf.fromInt 2)
                 else IntInf.- (IntInf.* (IntInf.~ v, IntInf.fromInt 2), IntInf.fromInt 1))
    end

  (* An .rbc of a program given as its parts: what load_program reads back
     as that program (runeopt --from-image). *)
  fun write {consts : const list, nglobals : int, funcs : (int * int * string) list, code : string,
             files : string list, lines : (int * int * int * int) list} : string =
    let
      fun const c =
        case c of
          CInt i => "\000" ^ leInf (i, 8)
        | CWord w => "\001" ^ leInf (w, 8)
        | CReal t => "\002" ^ le32 (String.size t) ^ t
        | CString t => "\003" ^ le32 (String.size t) ^ t
        | CChar c => "\004" ^ String.str (Char.chr c)
      fun func (offset, nlocals, name) = le32 offset ^ le32 nlocals ^ le32 (String.size name) ^ name
      fun table ([], _) = []
        | table ((pc, file, line, col) :: rest, (pc0, file0, line0, col0)) =
            uvarText (IntInf.fromInt (pc - pc0)) :: svarText (file - file0) :: svarText (line - line0)
            :: svarText (col - col0) :: table (rest, (pc, file, line, col))
      val tableText = String.concat (table (lines, (0, 0, 0, 0)))
    in
      String.concat
        (["RUNE", le32 Opcodes.rbcVersion, le32 Opcodes.fingerprint, le32 (List.length consts)] @ List.map const consts
         @ [le32 nglobals, le32 (List.length funcs)] @ List.map func funcs
         @ [le32 (String.size code), code, le32 (List.length files)]
         @ List.map (fn f => le32 (String.size f) ^ f) files
         @ [le32 (List.length lines), le32 (String.size tableText), tableText])
    end

  (* line_at: the entry that covers pc, the last that begins at or before it. *)
  fun lineAt (lines : line vector, pc : int) : line option =
    let
      val n = Vector.length lines
      fun search (lo, hi) =
        if hi - lo <= 1 then lo
        else
          let val mid = lo + (hi - lo) div 2
          in if #pc (Vector.sub (lines, mid)) <= pc then search (mid, hi) else search (lo, mid) end
    in
      if n = 0 orelse #pc (Vector.sub (lines, 0)) > pc then NONE
      else SOME (Vector.sub (lines, search (0, n)))
    end
end

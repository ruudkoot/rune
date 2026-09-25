(* Serialization of a compiled program to the .rbc bytecode format.
   See docs/bytecode.md for the layout. All multi-byte values are little-endian.
   The output is assembled from 8-bit strings rather than a list of bytes so
   that the emitter is cheap when the compiler itself runs on runevm. *)
structure Emit =
struct
  open Lambda Codegen

  val magic = "RUNE"

  val two64 : IntInf.int = IntInf.pow (IntInf.fromInt 2, 64)
  val b256 : IntInf.int = IntInf.fromInt 256

  fun byteChar (v : int) : char = Char.chr (v mod 256)
  fun u8 (v : int) : string = String.str (byteChar v)

  (* floor division makes this correct for negative values too (two's complement) *)
  fun u32 (v : int) : string =
    String.implode [byteChar v, byteChar (v div 256), byteChar (v div 65536), byteChar (v div 16777216)]

  val i32 = u32

  (* The strings of the opcodes, and of the operands below 256, which are
     most of them (slots, tags, counts), made once: the code of a function
     is the concatenation of such pieces, so that most instructions allocate
     nothing but the cells of the list of pieces. *)
  val byteString : string vector = Vector.tabulate (256, fn i => String.str (Char.chr i))
  val smallU32 : string vector = Vector.tabulate (256, u32)
  fun operand (v : int) : string = if v >= 0 andalso v < 256 then Vector.sub (smallU32, v) else u32 v

  fun i64 (v : IntInf.int) : string =
    let
      val u = IntInf.mod (v, two64)     (* two's complement *)
      fun go (0, _) = []
        | go (n, x) = byteChar (IntInf.toInt (IntInf.rem (x, b256))) :: go (n - 1, IntInf.quot (x, b256))
    in String.implode (go (8, u)) end

  fun str (s : string) : string = u32 (String.size s) ^ s

  (* The line table is the largest thing in the file after the code, so its
     numbers are written as differences, base 128, seven bits at a time with
     the top bit saying that another byte follows (LEB128). A difference that
     can be negative is folded to a natural number first, so that a small one
     stays one byte whichever way it goes. *)
  fun uvar (v : int) : string =
    if v < 128 then String.str (byteChar v)
    else String.str (byteChar (128 + v mod 128)) ^ uvar (v div 128)

  fun svar (v : int) : string = uvar (if v >= 0 then 2 * v else ~2 * v - 1)

  (* SML real literal text to C strtod syntax. *)
  fun realText (r : string) = String.map (fn #"~" => #"-" | c => c) r

  fun instrSize (Op (_, args)) = 1 + 4 * List.length args
    | instrSize (Ops (_, args)) = 1 + 4 * List.length args
    | instrSize (OpLab _) = 5
    | instrSize (OpLabImm _) = 9
    | instrSize (Lab _) = 0
    | instrSize (Pos _) = 0

  (* The file as chunks in order: the header, then one chunk per function. *)
  fun serialize (fingerprint : int, p : program) : string list =
    let
      (* layout: function start offsets and label offsets, the latter in an
         array since labels are numbered densely from 0 *)
      val labels : int array = Array.array (#nlabels p, ~1)
      (* where each position begins, in the order the code is laid out *)
      val lineEntries : (int * int * int * int) list ref = ref []
      val (starts, codeLen) =
        List.foldl (fn (f : func, (starts, off)) =>
                       let
                         val off' =
                           List.foldl (fn (it, o') =>
                                          (case it of
                                             Lab l => Array.update (labels, l, o')
                                           | Pos (fi, ln, cl) => lineEntries := (o', fi, ln, cl) :: !lineEntries
                                           | _ => ();
                                           o' + instrSize it)) off (#code f)
                       in ((#id f, off) :: starts, off') end) ([], 0) (#funcs p)
      val starts = List.rev starts
      (* The table, as differences from the entry before it. *)
      val lineTable =
        let
          fun go ([], _) = []
            | go ((pc, fi, ln, cl) :: rest, (pc0, fi0, ln0, cl0)) =
                (uvar (pc - pc0) ^ svar (fi - fi0) ^ svar (ln - ln0) ^ svar (cl - cl0))
                :: go (rest, (pc, fi, ln, cl))
        in String.concat (go (List.rev (!lineEntries), (0, 0, 0, 0))) end
      val nlines = List.length (!lineEntries)
      fun labelOffset l =
        let val o' = Array.sub (labels, l) in if o' < 0 then Error.bug "unresolved label" else o' end
      fun constBytes c =
        case c of
          CInt i => u8 0 ^ i64 i
        | CWord w => u8 1 ^ i64 w
        | CReal r => u8 2 ^ str (realText r)
        | CString s => u8 3 ^ str s
        | CChar c => u8 4 ^ u8 c
      fun funcEntry (f : func, (_, off)) = u32 off ^ u32 (#nlocals f) ^ str (#name f)
      (* A function's code is one concatenation of the pieces of its
         instructions, consed from its last instruction back. *)
      fun pieces (it, acc) =
        case it of
          Op (opc, []) => Vector.sub (byteString, opc) :: acc
        | Op (opc, [a]) => Vector.sub (byteString, opc) :: operand a :: acc
        | Op (opc, args) => Vector.sub (byteString, opc) :: List.foldr (fn (a, acc) => operand a :: acc) acc args
        | Ops (opc, args) =>
            Vector.sub (byteString, opc)
            :: List.foldr (fn (I a, acc) => operand a :: acc | (L l, acc) => operand (labelOffset l) :: acc) acc args
        | OpLab (opc, l) => Vector.sub (byteString, opc) :: operand (labelOffset l) :: acc
        | OpLabImm (opc, l, i) => Vector.sub (byteString, opc) :: operand (labelOffset l) :: operand i :: acc
        | Lab _ => acc
        | Pos _ => acc
      fun codeString (f : func) =
        let
          fun go ([], acc) = acc
            | go (it :: rest, acc) = go (rest, pieces (it, acc))
        in
          String.concat (go (List.rev (#code f), []))
        end
      val header =
        String.concat
          [magic, u32 Opcodes.rbcVersion, u32 fingerprint,
           u32 (List.length (#consts p)), String.concat (List.map constBytes (#consts p)),
           u32 (#nglobals p),
           u32 (List.length (#funcs p)), String.concat (ListPair.map funcEntry (#funcs p, starts)),
           u32 codeLen]
      (* The debug section, after the code: the files positions name, then the
         table that says which of them each instruction came from. *)
      val debug =
        String.concat
          [u32 (List.length (#files p)), String.concat (List.map str (#files p)),
           u32 nlines, u32 (String.size lineTable), lineTable]
    in
      header :: List.map codeString (#funcs p)
      @ [debug]
    end

  (* The file of a program of the stack bytecode, or with the fingerprint of
     another instruction set (the register bytecode's, Regs). *)
  fun writeFileAs (fingerprint : int, path : string, p : program) : unit =
    let
      val chunks = serialize (fingerprint, p)
      val out = TextIO.openOut path
    in
      List.app (fn s => TextIO.output (out, s)) chunks;
      TextIO.closeOut out
    end

  fun writeFile (path : string, p : program) : unit = writeFileAs (Opcodes.fingerprint, path, p)
end

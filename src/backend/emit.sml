(* Serialization of a compiled program to the .rbc bytecode format.
   See docs/bytecode.md for the layout. All multi-byte values are little-endian.
   The output is assembled from 8-bit strings rather than a list of bytes so
   that the emitter is cheap when the compiler itself runs on runevm. *)
structure Emit =
struct
  open Lambda Codegen

  val magic = "RUNE"
  val version = 1

  val two64 : IntInf.int = IntInf.pow (IntInf.fromInt 2, 64)
  val b256 : IntInf.int = IntInf.fromInt 256

  fun byteChar (v : int) : char = Char.chr (v mod 256)
  fun u8 (v : int) : string = String.str (byteChar v)

  (* floor division makes this correct for negative values too (two's complement) *)
  fun u32 (v : int) : string =
    String.implode [byteChar v, byteChar (v div 256), byteChar (v div 65536), byteChar (v div 16777216)]

  val i32 = u32

  fun i64 (v : IntInf.int) : string =
    let
      val u = IntInf.mod (v, two64)     (* two's complement *)
      fun go (0, _) = []
        | go (n, x) = byteChar (IntInf.toInt (IntInf.rem (x, b256))) :: go (n - 1, IntInf.quot (x, b256))
    in String.implode (go (8, u)) end

  fun str (s : string) : string = u32 (String.size s) ^ s

  (* SML real literal text to C strtod syntax. *)
  fun realText (r : string) = String.map (fn #"~" => #"-" | c => c) r

  fun instrSize (Op (_, args)) = 1 + 4 * List.length args
    | instrSize (OpLab _) = 5
    | instrSize (Lab _) = 0

  (* The file as chunks in order: the header, then one chunk per function. *)
  fun serialize (p : program) : string list =
    let
      (* layout: function start offsets and label offsets *)
      val labels : int IntMap.map ref = ref IntMap.empty
      val (starts, codeLen) =
        List.foldl (fn (f : func, (starts, off)) =>
                       let
                         val off' =
                           List.foldl (fn (it, o') =>
                                          (case it of Lab l => labels := IntMap.insert (!labels, l, o') | _ => ();
                                           o' + instrSize it)) off (#code f)
                       in ((#id f, off) :: starts, off') end) ([], 0) (#funcs p)
      val starts = List.rev starts
      fun labelOffset l = case IntMap.find (!labels, l) of SOME o' => o' | NONE => Error.bug "unresolved label"
      fun constBytes c =
        case c of
          CInt i => u8 0 ^ i64 i
        | CWord w => u8 1 ^ i64 w
        | CReal r => u8 2 ^ str (realText r)
        | CString s => u8 3 ^ str s
        | CChar c => u8 4 ^ u8 c
      fun funcEntry (f : func, (_, off)) = u32 off ^ u32 (#nlocals f) ^ str (#name f)
      fun itemBytes it =
        case it of
          Op (opc, args) => String.concat (u8 opc :: List.map i32 args)
        | OpLab (opc, l) => u8 opc ^ i32 (labelOffset l)
        | Lab _ => ""
      val header =
        String.concat
          [magic, u32 version,
           u32 (List.length (#consts p)), String.concat (List.map constBytes (#consts p)),
           u32 (#nglobals p),
           u32 (List.length (#funcs p)), String.concat (ListPair.map funcEntry (#funcs p, starts)),
           u32 codeLen]
    in
      header :: List.map (fn (f : func) => String.concat (List.map itemBytes (#code f))) (#funcs p)
    end

  fun writeFile (path : string, p : program) : unit =
    let
      val chunks = serialize p
      val out = TextIO.openOut path
    in
      List.app (fn s => TextIO.output (out, s)) chunks;
      TextIO.closeOut out
    end
end

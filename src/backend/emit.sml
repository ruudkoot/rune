(* Serialization of a compiled program to the .rbc bytecode format.
   See docs/bytecode.md for the layout. All multi-byte values are little-endian. *)
structure Emit =
struct
  open Lambda Codegen

  val magic = "RUNE"
  val version = 1

  val two64 : IntInf.int = IntInf.pow (2, 64)

  (* Byte buffer built in reverse. *)
  type buf = Word8.word list ref

  fun byte (b : buf, v : int) = b := Word8.fromInt (v mod 256) :: !b

  (* floor division makes this correct for negative values too (two's complement) *)
  fun u32 (b : buf, v : int) =
    (byte (b, v mod 256); byte (b, (v div 256) mod 256); byte (b, (v div 65536) mod 256); byte (b, (v div 16777216) mod 256))

  fun i32 (b : buf, v : int) = u32 (b, v)

  fun i64 (b : buf, v : IntInf.int) =
    let
      val u = IntInf.mod (v, two64)     (* two's complement *)
      fun go (0, _) = ()
        | go (n, x) = (byte (b, IntInf.toInt (IntInf.rem (x, 256))); go (n - 1, IntInf.quot (x, 256)))
    in go (8, u) end

  fun bytes (b : buf, s : string) = CharVector.app (fn c => byte (b, Char.ord c)) s

  fun str (b : buf, s : string) = (u32 (b, String.size s); bytes (b, s))

  (* SML real literal text to C strtod syntax. *)
  fun realText (r : string) = String.map (fn #"~" => #"-" | c => c) r

  fun instrSize (Op (_, args)) = 1 + 4 * List.length args
    | instrSize (OpLab _) = 5
    | instrSize (Lab _) = 0

  fun serialize (p : program) : Word8.word list =
    let
      val b : buf = ref []
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
    in
      bytes (b, magic);
      u32 (b, version);
      (* constants *)
      u32 (b, List.length (#consts p));
      List.app (fn c =>
                  case c of
                    CInt i => (byte (b, 0); i64 (b, i))
                  | CWord w => (byte (b, 1); i64 (b, w))
                  | CReal r => (byte (b, 2); str (b, realText r))
                  | CString s => (byte (b, 3); str (b, s))
                  | CChar c => (byte (b, 4); byte (b, c))) (#consts p);
      (* globals *)
      u32 (b, #nglobals p);
      (* functions *)
      u32 (b, List.length (#funcs p));
      ListPair.app (fn (f : func, (_, off)) => (u32 (b, off); u32 (b, #nlocals f); str (b, #name f))) (#funcs p, starts);
      (* code *)
      u32 (b, codeLen);
      List.app (fn f =>
                  List.app (fn it =>
                              case it of
                                Op (opc, args) => (byte (b, opc); List.app (fn a => i32 (b, a)) args)
                              | OpLab (opc, l) => (byte (b, opc); i32 (b, labelOffset l))
                              | Lab _ => ()) (#code f)) (#funcs p);
      List.rev (!b)
    end

  fun writeFile (path : string, p : program) : unit =
    let
      val data = serialize p
      val out = BinIO.openOut path
    in
      BinIO.output (out, Word8Vector.fromList data);
      BinIO.closeOut out
    end
end

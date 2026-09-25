(* The code of a program as the targets make it (docs/ir.md): each
   function's instructions in order, as opcodes and operands, with labels
   where jumps go and positions where the source changes, and the tables the
   program's file has -- constants, globals, files and the frames of inlined
   functions -- which Emit writes. Stack and Regs make it from Low. *)
structure Code =
struct
  open Lambda

  (* An operand of Ops: a number, or a label whose offset it is. *)
  datatype operand = I of int | L of int

  datatype item =
      Op of int * int list                (* opcode, immediate operands *)
    | Ops of int * operand list           (* opcode, operands of which any may be a label *)
    | OpLab of int * int                  (* opcode with one label operand *)
    | OpLabImm of int * int * int         (* opcode with a label operand, then an immediate *)
    | Lab of int
    | Pos of int * int * int * int        (* file, line, column of what follows, and the inlined
                                             frames it is in (inlineIdx) *)

  type func = {id : int, nlocals : int, code : item list, name : string}

  (* nlabels: the labels of the program are numbered from 0 up to it. *)
  type program = {consts : const list, nglobals : int, funcs : func list, files : string list,
                  inlines : (string * int * int * int * int) list, nlabels : int}

  (* ---------------------------------------------------------------- *)
  (* The tables of the program being made.                              *)

  val consts : const list ref = ref []
  val nconsts = ref 0
  val constIndex : int StringMap.map ref = ref StringMap.empty
  val globals : int IntMap.map ref = ref IntMap.empty
  val nglobals = ref 0
  val nextLabel = ref 0
  (* The source files positions refer to, in the order they were first seen;
     an index into this is what the line table holds. *)
  val files : string list ref = ref []
  val nfiles = ref 0
  val fileIndex : int StringMap.map ref = ref StringMap.empty
  (* The file numbered last, since positions come file by file. *)
  val lastFile : (string * int) option ref = ref NONE

  (* The inlined frames the positions name (Low.pos), each once, numbered
     from 1: a function's name, the file, line and column it was called
     from -- 0, 0, 0 where it was called in tail position -- and the frame
     that call is in (0: none). Latest first. *)
  val inlines : (string * int * int * int * int) list ref = ref []
  val ninlines = ref 0
  val inlineIndex : int StringMap.map ref = ref StringMap.empty
  val lastInline : ({name : string, site : Source.span option} list * int) ref = ref ([], 0)

  fun reset () =
    (consts := []; nconsts := 0; constIndex := StringMap.empty;
     globals := IntMap.empty; nglobals := 0; nextLabel := 0;
     files := []; nfiles := 0; fileIndex := StringMap.empty; lastFile := NONE;
     inlines := []; ninlines := 0; inlineIndex := StringMap.empty; lastInline := ([], 0))

  fun fileIdx (name : string) : int =
    case !lastFile of
      SOME (n, i) => if n = name then i else fileIdx' name
    | NONE => fileIdx' name
  and fileIdx' name =
    let
      val i =
        case StringMap.find (!fileIndex, name) of
          SOME i => i
        | NONE =>
          let val i = !nfiles
          in files := name :: !files; nfiles := i + 1;
             fileIndex := StringMap.insert (!fileIndex, name, i); i
          end
    in
      lastFile := SOME (name, i); i
    end

  (* The number of a chain of inlined frames, innermost first; 0 for none. A
     call site the source was not loaded for is left out. The last chain
     asked for is kept, since the positions of inlined code come in runs. *)
  fun inlineIdx (frames : {name : string, site : Source.span option} list) : int =
    case frames of
      [] => 0
    | _ =>
        if frames = #1 (!lastInline) then #2 (!lastInline)
        else let val i = inlineIdx' frames in lastInline := (frames, i); i end
  and inlineIdx' frames =
    case frames of
      [] => 0
    | {name, site} :: rest =>
        let
          val parent = inlineIdx' rest
          fun row (f, line, col) =
            let val key = String.concatWith ":" [name, Int.toString f, Int.toString line, Int.toString col, Int.toString parent]
            in
              case StringMap.find (!inlineIndex, key) of
                SOME i => i
              | NONE =>
                  let val i = !ninlines + 1
                  in
                    ninlines := i; inlines := (name, f, line, col, parent) :: !inlines;
                    inlineIndex := StringMap.insert (!inlineIndex, key, i); i
                  end
            end
        in
          case site of
            NONE => row (0, 0, 0)
          | SOME sp =>
              case Source.lineColOf sp of
                NONE => parent
              | SOME (file, line, col) => row (fileIdx file, line, col)
        end

  fun newLabel () = let val l = !nextLabel in nextLabel := l + 1; l end

  fun constKey c =
    case c of
      CInt i => "i:" ^ IntInf.toString i
    | CWord w => "w:" ^ IntInf.toString w
    | CReal r => "r:" ^ r
    | CString s => "s:" ^ s
    | CChar c => "c:" ^ Int.toString c

  fun constIdx c =
    let val key = constKey c
    in
      case StringMap.find (!constIndex, key) of
        SOME i => i
      | NONE =>
        let val i = !nconsts
        in consts := c :: !consts; nconsts := i + 1; constIndex := StringMap.insert (!constIndex, key, i); i end
    end

  fun globalIdx g =
    case IntMap.find (!globals, g) of
      SOME i => i
    | NONE => let val i = !nglobals in globals := IntMap.insert (!globals, g, i); nglobals := i + 1; i end

  fun primIdx name =
    case Prims.find name of
      SOME (i, _) => i
    | NONE => Error.bug ("unknown primitive " ^ name)

  (* The names of the opcodes a dump shows: the stack bytecode's, or the
     register bytecode's where the program is of that (Regs). *)
  val opcodeNames = ref Opcodes.names

  fun itemToString it =
    case it of
      Op (opc, args) => "    " ^ Vector.sub (!opcodeNames, opc) ^ " " ^ String.concatWith " " (List.map Int.toString args)
    | Ops (opc, args) =>
        "    " ^ Vector.sub (!opcodeNames, opc) ^ " "
        ^ String.concatWith " " (List.map (fn I n => Int.toString n | L l => "L" ^ Int.toString l) args)
    | OpLab (opc, l) => "    " ^ Vector.sub (!opcodeNames, opc) ^ " L" ^ Int.toString l
    | OpLabImm (opc, l, i) => "    " ^ Vector.sub (!opcodeNames, opc) ^ " L" ^ Int.toString l ^ " " ^ Int.toString i
    | Lab l => "  L" ^ Int.toString l ^ ":"
    | Pos (f, l, c, i) =>
        "  ; " ^ Int.toString f ^ ":" ^ Int.toString l ^ ":" ^ Int.toString c ^ (if i = 0 then "" else " inlined " ^ Int.toString i)

  (* The instructions of a program, for --pass-stats. *)
  fun size ({funcs, ...} : program) : int =
    List.foldl (fn ({code, ...} : func, n) =>
                  List.foldl (fn (Lab _, n) => n | (Pos _, n) => n | (_, n) => n + 1) n code) 0 funcs

  fun dump (p : program) : string =
    let
      fun const (c, (acc, i)) = ("const " ^ Int.toString i ^ " = " ^ constToString c ^ "\n" :: acc, i + 1)
      val cs = String.concat (List.rev (#1 (List.foldl const ([], 0) (#consts p))))
      val fs = String.concat (List.map (fn f => "function " ^ Int.toString (#id f) ^ " " ^ #name f ^ " (locals " ^ Int.toString (#nlocals f) ^ ")\n" ^
                                           String.concat (List.map (fn it => itemToString it ^ "\n") (#code f))) (#funcs p))
    in cs ^ "globals " ^ Int.toString (#nglobals p) ^ "\n" ^ fs end
end

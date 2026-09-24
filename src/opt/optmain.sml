(* runeopt, the native code generator: the command line. It reads an .rbc
   as the loader of runevm does, checks what a translation relies on, and
   translates it into an executable for Linux on x86-64.
   docs/plans/codegen.md is the plan. *)
structure OptMain =
struct
  fun println s = print (s ^ "\n")
  fun eprintln s = TextIO.output (TextIO.stdErr, s ^ "\n")

  exception Usage of string

  val usage =
    "usage: runeopt [-o FILE] [-S] [--options TEXT] FILE.rbc\n\
    \       runeopt --check FILE.rbc ...\n\
    \       runeopt --disasm FILE.rbc\n\
    \       runeopt --facts FILE.rbc ...\n\
    \  -o FILE     the executable to write (default: FILE.rbc without .rbc)\n\
    \  -S          write the assembly to FILE (default FILE.rbc with .s) and stop\n\
    \  --options TEXT  options of runevm the program is to run with, as\n\
    \              RUNEVM_OPTIONS gives them when it runs, which come after\n\
    \              these: --count, --stats, --heap-size N, --gc-stress N\n\
    \  --cc CC     the C compiler that assembles and links (default cc)\n\
    \  --runtime DIR  where librune.a and rune-offsets.s are (the wrappers\n\
    \              pass it)\n\
    \  --check     check that each file is one runeopt can translate: one the\n\
    \              loader of runevm accepts, whose code keeps what the\n\
    \              translation relies on (docs/plans/codegen.md, D0)\n\
    \  --disasm    print the bytecode as runevm --disasm does\n\
    \  --inlined   list the primitives whose common case the code does itself\n\
    \  --facts     what the check found in each file: functions,\n\
    \              instructions, the highest stack, the places to resume at\n\
    \  --version   print the version\n\
    \  --help      print this text\n"

  datatype mode = Check | Disasm | Facts | Inlined | Translate

  val mode = ref Translate
  val modeGiven = ref false
  val inputs : string list ref = ref []
  val output : string option ref = ref NONE
  val assembly = ref false
  val options = ref ""
  val cc = ref "cc"
  val runtime : string option ref = ref NONE
  val showHelp = ref false
  val showVersion = ref false

  fun setMode m =
    if !modeGiven then raise Usage "give one of --check, --disasm, --facts and --inlined"
    else (mode := m; modeGiven := true)

  fun parse (args : string list) : unit =
    case args of
      [] => ()
    | "--check" :: rest => (setMode Check; parse rest)
    | "--disasm" :: rest => (setMode Disasm; parse rest)
    | "--facts" :: rest => (setMode Facts; parse rest)
    | "--inlined" :: rest => (setMode Inlined; parse rest)
    | "-o" :: file :: rest => (output := SOME file; parse rest)
    | "-S" :: rest => (assembly := true; parse rest)
    | "--options" :: text :: rest => (options := text; parse rest)
    | "--cc" :: c :: rest => (cc := c; parse rest)
    | "--runtime" :: dir :: rest => (runtime := SOME dir; parse rest)
    | "--version" :: rest => (showVersion := true; parse rest)
    | "--help" :: rest => (showHelp := true; parse rest)
    | "-h" :: rest => (showHelp := true; parse rest)
    | arg :: rest =>
        if String.isPrefix "-" arg then raise Usage ("unknown option " ^ arg)
        else (inputs := !inputs @ [arg]; parse rest)

  (* A file that is refused, and why. *)
  exception Refused of string * string

  fun load (path : string) : Rbc.program =
    Rbc.readFile path handle Rbc.Bad msg => raise Refused (path, msg)

  fun check (path : string) : Rbc.program * RbcCheck.facts =
    let val p = load path
    in (p, RbcCheck.check p) handle RbcCheck.Refused msg => raise Refused (path, msg) end

  fun count (pred : 'a -> bool) (v : 'a vector) : int =
    Vector.foldl (fn (x, n) => if pred x then n + 1 else n) 0 v

  fun facts (path : string) : string =
    let
      val (p, f) = check path
      val instrs = #instrs f
      fun sites opc = count (fn {opc = c, ...} : RbcCheck.instr => c = opc) instrs
    in
      path ^ ": " ^ Int.toString (Vector.length (#funcs p)) ^ " functions, "
      ^ Int.toString (Vector.length instrs) ^ " instructions, "
      ^ Int.toString (count (fn h => h < 0) (#height f)) ^ " unreachable, highest stack "
      ^ Int.toString (Vector.foldl Int.max 0 (#maxHeight f)) ^ ", resume points "
      ^ Int.toString (sites Opcodes.CALL) ^ " after a CALL, "
      ^ Int.toString (sites Opcodes.PRIM) ^ " after a PRIM, "
      ^ Int.toString (sites Opcodes.PUSHHANDLER) ^ " handlers"
    end

  (* A word for sh, between single quotes. *)
  fun shellQuote (s : string) : string =
    "'" ^ String.translate (fn #"'" => "'\\''" | c => String.str c) s ^ "'"

  fun withoutRbc (path : string) : string =
    if String.isSuffix ".rbc" path then String.substring (path, 0, String.size path - 4) else path

  (* The program of an .rbc: its assembly, then, but with -S, the executable
     that cc makes of it with the runtime. The assembly goes when the
     executable is made. *)
  fun translate (path : string) : OS.Process.status =
    let
      val data = Rbc.readBytes path handle Rbc.Bad msg => raise Refused (path, msg)
      val p = Rbc.read data handle Rbc.Bad msg => raise Refused (path, msg)
      val f = RbcCheck.check p handle RbcCheck.Refused msg => raise Refused (path, msg)
      val exe = case !output of SOME o' => o' | NONE => withoutRbc path
      val asm = if !assembly then (case !output of SOME o' => o' | NONE => withoutRbc path ^ ".s") else exe ^ ".s"
      val out = TextIO.openOut asm
      val () = X64.write (fn s => TextIO.output (out, s), p, f,
                          {rbc = path, rbcSize = String.size data, options = !options})
      val () = TextIO.closeOut out
    in
      if !assembly then OS.Process.success
      else
        let
          val dir = case !runtime of SOME d => d | NONE => raise Usage "no runtime directory (use --runtime DIR)"
          val command =
            String.concatWith " "
              [!cc, "-o", shellQuote exe, shellQuote asm, "-Wa,-I," ^ shellQuote dir,
               shellQuote (dir ^ "/librune.a"), "-lm"]
        in
          if OS.Process.isSuccess (OS.Process.system command)
          then (OS.FileSys.remove asm; OS.Process.success)
          else raise Refused (path, "the assembly " ^ asm ^ " could not be assembled and linked: " ^ command)
        end
    end

  fun run () : OS.Process.status =
    case (!mode, !inputs) of
      (Inlined, _) => (List.app println X64.inlined; OS.Process.success)
    | (_, []) => raise Usage "no input file"
    | (Translate, [path]) => translate path
    | (Translate, _) => raise Usage "translate one file at a time"
    | (Disasm, [path]) => (RbcDisasm.print (TextIO.stdOut, load path); OS.Process.success)
    | (Disasm, _) => raise Usage "--disasm takes one file"
    | (Check, paths) => (List.app (fn path => ignore (check path)) paths; OS.Process.success)
    | (Facts, paths) => (List.app (println o facts) paths; OS.Process.success)

  fun main (_ : string, args : string list) : OS.Process.status =
    (parse args;
     if !showHelp then (print usage; OS.Process.success)
     else if !showVersion then (println ("runeopt " ^ Config.version); OS.Process.success)
     else run ())
    handle Usage msg => (eprintln ("runeopt: " ^ msg); eprintln "try 'runeopt --help'"; OS.Process.failure)
         | Refused (path, msg) => (eprintln ("runeopt: " ^ path ^ ": " ^ msg); OS.Process.failure)
         | IO.Io {name, ...} => (eprintln ("runeopt: I/O error on " ^ name); OS.Process.failure)
         | e => (eprintln ("runeopt: internal error: " ^ General.exnMessage e); OS.Process.failure)
end

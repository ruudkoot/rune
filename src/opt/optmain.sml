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
    "usage: runeopt --check FILE.rbc ...\n\
    \       runeopt --disasm FILE.rbc\n\
    \       runeopt --facts FILE.rbc ...\n\
    \  --check     check that each file is one runeopt can translate: one the\n\
    \              loader of runevm accepts, whose code keeps what the\n\
    \              translation relies on (docs/plans/codegen.md, D0)\n\
    \  --disasm    print the bytecode as runevm --disasm does\n\
    \  --facts     what the check found in each file: functions,\n\
    \              instructions, the highest stack, the places to resume at\n\
    \  --version   print the version\n\
    \  --help      print this text\n"

  datatype mode = Check | Disasm | Facts | Translate

  val mode = ref Translate
  val modeGiven = ref false
  val inputs : string list ref = ref []
  val showHelp = ref false
  val showVersion = ref false

  fun setMode m =
    if !modeGiven then raise Usage "give one of --check, --disasm and --facts"
    else (mode := m; modeGiven := true)

  fun parse (args : string list) : unit =
    case args of
      [] => ()
    | "--check" :: rest => (setMode Check; parse rest)
    | "--disasm" :: rest => (setMode Disasm; parse rest)
    | "--facts" :: rest => (setMode Facts; parse rest)
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

  fun run () : OS.Process.status =
    case (!mode, !inputs) of
      (_, []) => raise Usage "no input file"
    | (Translate, _) => raise Usage "nothing to do"
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

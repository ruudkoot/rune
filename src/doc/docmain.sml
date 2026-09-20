(* runedoc, the documentation generator: the command line.
   docs/plans/docgen.md is the plan; so far it names the signatures that the
   files on the command line declare. *)
structure DocMain =
struct
  fun println s = print (s ^ "\n")
  fun eprintln s = TextIO.output (TextIO.stdErr, s ^ "\n")

  exception Usage of string

  val usage =
    "usage: runedoc [options] FILE...\n\
    \  --lib DIR   the directory of the libraries (the wrappers pass it)\n\
    \  --version   print the version\n\
    \  --help      print this text\n\
    \Prints the signatures that the files declare.\n"

  val libDir : string option ref = ref NONE
  val inputs : string list ref = ref []
  val showHelp = ref false
  val showVersion = ref false

  fun parse (args : string list) : unit =
    case args of
      [] => ()
    | "--lib" :: dir :: rest => (libDir := SOME dir; parse rest)
    | "--lib" :: [] => raise Usage "--lib needs a directory"
    | "--version" :: rest => (showVersion := true; parse rest)
    | "--help" :: rest => (showHelp := true; parse rest)
    | "-h" :: rest => (showHelp := true; parse rest)
    | arg :: rest =>
        if String.isPrefix "-" arg then raise Usage ("unknown option " ^ arg)
        else (inputs := !inputs @ [arg]; parse rest)

  (* The signatures a file declares, in order. *)
  fun signaturesOf (path : string) : string list =
    let
      val file = Source.load path
                 handle IO.Io _ => raise Usage ("cannot read " ^ path)
      val (prog, _) = Parser.parseTokensWith (Lexer.tokenize file, Fixity.initial)
    in
      List.concat (List.map (fn Ast.DSignature (binds, _) => List.map #name binds
                              | _ => []) prog)
    end

  fun run () : OS.Process.status =
    (if List.null (!inputs) then raise Usage "no input files" else ();
     List.app (fn path => List.app (fn s => println ("signature " ^ s)) (signaturesOf path)) (!inputs);
     OS.Process.success)

  fun main (_ : string, args : string list) : OS.Process.status =
    (parse args;
     if !showHelp then (print usage; OS.Process.success)
     else if !showVersion then (println ("runedoc " ^ Config.version); OS.Process.success)
     else run ())
    handle Usage msg => (eprintln ("runedoc: " ^ msg); eprintln "try 'runedoc --help'"; OS.Process.failure)
         | Error.CompileError (sp, msg) => (eprintln (Error.format (sp, msg)); OS.Process.failure)
         | Error.Bug msg => (eprintln ("runedoc: " ^ msg); OS.Process.failure)
         | IO.Io {name, ...} => (eprintln ("runedoc: I/O error on " ^ name); OS.Process.failure)
end

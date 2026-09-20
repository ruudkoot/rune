(* runedoc, the documentation generator: the command line.
   docs/plans/docgen.md is the plan. *)
structure DocMain =
struct
  fun println s = print (s ^ "\n")
  fun eprintln s = TextIO.output (TextIO.stdErr, s ^ "\n")

  exception Usage of string

  val usage =
    "usage: runedoc [options] FILE...\n\
    \  --dump-ir   print what is extracted from the files (the intermediate\n\
    \              representation, in the text form the tests compare)\n\
    \  --lint      check the comments of the files: every comment is in the\n\
    \              language of doc comments, and those that document\n\
    \              something say it in the way the generator can use\n\
    \  --lib DIR   the directory of the libraries (the wrappers pass it)\n\
    \  --version   print the version\n\
    \  --help      print this text\n"

  val libDir : string option ref = ref NONE
  val inputs : string list ref = ref []
  val dumpIR = ref false
  val lint = ref false
  val showHelp = ref false
  val showVersion = ref false

  fun parse (args : string list) : unit =
    case args of
      [] => ()
    | "--lib" :: dir :: rest => (libDir := SOME dir; parse rest)
    | "--lib" :: [] => raise Usage "--lib needs a directory"
    | "--dump-ir" :: rest => (dumpIR := true; parse rest)
    | "--lint" :: rest => (lint := true; parse rest)
    | "--version" :: rest => (showVersion := true; parse rest)
    | "--help" :: rest => (showHelp := true; parse rest)
    | "-h" :: rest => (showHelp := true; parse rest)
    | arg :: rest =>
        if String.isPrefix "-" arg then raise Usage ("unknown option " ^ arg)
        else (inputs := !inputs @ [arg]; parse rest)

  fun load (path : string) : DocIR.module list =
    DocExtract.file path
    handle IO.Io _ => raise Usage ("cannot read " ^ path)

  (* --lint: what extraction has to say about a file, and the grammar of
     every comment in it, also of those that document nothing. *)
  fun lintFile (path : string) : unit =
    let
      val _ = load path
      val src = DocSource.load path
      fun gap i =
        List.app (fn {start, stop} =>
                    ignore (DocText.parse (fn why => DocDiag.error ({file = DocSource.name src, start = start, stop = stop}, why))
                                          (DocComments.textOf (src, start, stop))))
                 (DocSource.commentsBefore (src, i))
      fun loop i = if i >= DocSource.numTokens src then () else (gap i; loop (i + 1))
    in
      loop 0
    end

  (* Diagnostics go to the standard error, in source order; an error among
     them fails the run after everything has been reported. *)
  fun report () : OS.Process.status =
    (List.app eprintln (DocDiag.lines ());
     if DocDiag.numErrors () > 0 then OS.Process.failure else OS.Process.success)

  fun run () : OS.Process.status =
    (if List.null (!inputs) then raise Usage "no input files" else ();
     if !dumpIR then List.app (fn path => print (DocIR.dump (path, load path))) (!inputs)
     else if !lint then List.app lintFile (!inputs)
     else raise Usage "nothing to do (use --dump-ir or --lint)";
     report ())

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

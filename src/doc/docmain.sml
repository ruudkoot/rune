(* runedoc, the documentation generator: the command line.
   docs/plans/docgen.md is the plan. *)
structure DocMain =
struct
  fun println s = print (s ^ "\n")
  fun eprintln s = TextIO.output (TextIO.stdErr, s ^ "\n")

  exception Usage of string

  val usage =
    "usage: runedoc --library NAME --out DIR [--check] [--title TEXT]\n\
    \       runedoc (--page | --dump-ir | --lint) FILE...\n\
    \  --library NAME  document the library LIBDIR/NAME, which has a MANIFEST\n\
    \  --out DIR       write the documentation there, and remove the pages\n\
    \                  that are no longer generated\n\
    \  --check         write nothing: fail if DIR is not what would be written\n\
    \  --title TEXT    the title of the overview page\n\
    \  --page      print the pages of the signatures that the files declare\n\
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
  val page = ref false
  val library : string option ref = ref NONE
  val out : string option ref = ref NONE
  val title : string option ref = ref NONE
  val check = ref false
  val lint = ref false
  val showHelp = ref false
  val showVersion = ref false

  fun parse (args : string list) : unit =
    case args of
      [] => ()
    | "--lib" :: dir :: rest => (libDir := SOME dir; parse rest)
    | "--lib" :: [] => raise Usage "--lib needs a directory"
    | "--dump-ir" :: rest => (dumpIR := true; parse rest)
    | "--page" :: rest => (page := true; parse rest)
    | "--check" :: rest => (check := true; parse rest)
    | "--library" :: name :: rest => (library := SOME name; parse rest)
    | "--out" :: dir :: rest => (out := SOME dir; parse rest)
    | "--title" :: text :: rest => (title := SOME text; parse rest)
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

  (* --page: the pages of the signatures of some files, which can refer to
     each other and to nothing else. *)
  fun pages (paths : string list) : unit =
    let
      val modules = List.concat (List.map load paths)
      val env = {index = DocResolve.indexOf modules, root = "../", up = "", links = ref [], anchors = ref []}
    in
      List.app (fn DocIR.Signature s => print (DocPage.signaturePage (env, "Library") s ^ "\n") | _ => ()) modules;
      DocSite.verify (env, NONE)
    end

  fun generate (name : string) : OS.Process.status =
    let
      val lib = case !libDir of SOME d => d | NONE => raise Usage "no library directory (use --lib DIR)"
      val dir = case !out of SOME d => d | NONE => raise Usage "no output directory (use --out DIR)"
      val files = DocSite.build {dir = lib ^ "/" ^ name, out = dir,
                                 title = (case !title of SOME t => t | NONE => name)}
                  handle BasisManifest.Usage why => raise Usage why
      val status = report ()
    in
      if not (OS.Process.isSuccess status) then status
      else if !check then
        (case DocSite.check (dir, files) of
           [] => (println ("runedoc: " ^ dir ^ " is up to date (" ^ Int.toString (List.length files) ^ " files)"); status)
         | differences => (List.app eprintln differences;
                           eprintln ("runedoc: " ^ dir ^ " is not what the sources give (run `make docs`)");
                           OS.Process.failure))
      else (DocSite.write (dir, files);
            println ("runedoc: wrote " ^ Int.toString (List.length files) ^ " files to " ^ dir); status)
    end

  fun run () : OS.Process.status =
    case !library of
      SOME name => generate name
    | NONE =>
        (if List.null (!inputs) then raise Usage "no input files" else ();
         if !dumpIR then List.app (fn path => print (DocIR.dump (path, load path))) (!inputs)
         else if !page then pages (!inputs)
         else if !lint then List.app lintFile (!inputs)
         else raise Usage "nothing to do (use --library, --page, --dump-ir or --lint)";
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

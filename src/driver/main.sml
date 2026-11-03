(* Compiler driver. *)
structure Main =
struct
  fun println s = print (s ^ "\n")
  fun eprintln s = TextIO.output (TextIO.stdErr, s ^ "\n")

  fun libRoot () : string =
    case !Options.libDir of
      NONE => raise Options.Usage "no basis library (use --lib DIR or --no-prelude)"
    | SOME lib => lib

  fun libDir () : string = libRoot () ^ "/basis"

  datatype when = datatype BasisManifest.when
  type entry = BasisManifest.entry
  type names = BasisManifest.names
  val providers = BasisManifest.providers
  fun readManifest () = BasisManifest.readManifest (libDir ())
  (* what each scope of this compile sees (BasisManifest), which choosing its
     files works out *)
  val librariesScoped = ref (BasisManifest.noScopes "")
  (* the virtual modules of its libraries, KIND, NAME and library, which a
     library implements and the program's build does not (D22) *)
  val libraryVirtuals : (string * string * string) list ref = ref []

  (* The libraries of --library and those they are written on, in the order
     they are compiled, with the entries of each. *)
  fun libraryManifests () : (string * entry list) list =
    List.map (fn d => (d, BasisManifest.readManifest d))
             (BasisManifest.libraries (libRoot (), !Options.libraries)
              handle BasisManifest.Usage why => raise Options.Usage why)

  (* a file of the Basis Library, which may use _prim, and is compiled before
     the libraries: but for a seal of a view, which comes after them (D12) *)
  fun inBasis (e : entry) : bool = #dir e = libDir () andalso not (isSome (#view e))

  (* Manifest entries are already ordered by library dependency. Contiguous
     library groups stay so, that their private bases can be hidden. *)
  val entryGroups = CompilerPrelude.groups

  fun defaultOutput (first : string) : string =
    let
      val base = if String.isSuffix ".sml" first then String.substring (first, 0, String.size first - 4) else first
    in base ^ ".rbc" end

  val fixity : Fixity.env ref = ref Fixity.initial

  (* A compile that reported its errors as it found them (Error.report),
     and so fails once the front end is done *)
  exception Reported
  fun failIfReported () = if !Error.errors > 0 then raise Reported else ()

  (* --dump-witnesses: what the elaborator recorded of the input files'
     nodes, once Elaborate.finish has run; nothing where an error was found *)
  fun dumpWitnesses () =
    if not (!Options.dumpWitnesses) orelse !Error.errors > 0 then ()
    else Witness.dump (fn f => List.exists (fn i => i = f) (!Options.inputs), print)

  (* AstLint (elab/astlint.sml), at --lint=2 and above: what was elaborated
     checked, once Elaborate.finish has run and before Translate; nothing
     where an error was found. The elaborator keeps what it reads from the
     start of the elaboration (lintWanted) *)
  fun lintWanted () = Elaborate.lintRecords := Pass.linting' 2
  fun astlint () =
    if !Error.errors > 0 then Elaborate.forgetLintRecords ()
    else Pass.checkAt ("astlint", 2) AstLint.check ()

  (* the syntax of the program's units, elaborated, when wanted (Serve) *)
  val keepSyntax = ref false
  val keptSyntax : (string * Ast.dec list) list ref = ref []

  (* a file's tokens, read in a mode (Source.mode) *)
  fun loadTokens (mode : Source.mode, path : string) : Lexer.item vector =
    let
      val file = Source.load (mode, path)
                 handle IO.Io _ => raise Options.Usage (Options.cannotRead path)
    in
      Lexer.tokenize file
    end

  (* The mode of the units of a build file, by their paths: the last mode
     that a unit's annotations name ("ascii", "unicode", "unicode=latin1"),
     else the command line's (modeOf; compile) *)
  val buildModes : Source.mode StringMap.map ref = ref StringMap.empty
  fun modeOf (anns : string list) : Source.mode =
    CompilerProject.modeOf (!Options.sourceMode,anns)
  (* the mode of an input file: its build file's, else the command line's *)
  fun inputMode (path : string) : Source.mode =
    case StringMap.find (!buildModes, path) of
      SOME m => m
    | NONE => !Options.sourceMode

  (* --dump-tokens: the tokens of the named files and nothing else; no basis
     is loaded, nothing is compiled and nothing is written. *)
  fun dumpTokens () : OS.Process.status =
    let
      val inputs = !Options.inputs
      val () = if List.null inputs then raise Options.Usage "no input files" else ()
    in
      List.app (fn path =>
        Vector.app (fn (t, sp) => println (Source.describe sp ^ " " ^ Token.toString t))
                   (loadTokens (inputMode path, path))) inputs;
      OS.Process.success
    end

  (* --lex-count N: the inputs lexed N times, each in its mode, and how
     many tokens and bytes they have; what bin/rune-measure lex-corpus measures
     the lexer by *)
  fun lexCount () : OS.Process.status =
    let
      val inputs = !Options.inputs
      val () = if List.null inputs then raise Options.Usage "no input files" else ()
      val files = List.map (fn p => Source.load (inputMode p, p) handle IO.Io _ => raise Options.Usage (Options.cannotRead p))
                           inputs
      fun once () = List.foldl (fn (f, (t, b)) => (t + Vector.length (Lexer.tokenize f), b + String.size (#text f))) (0, 0) files
      fun again (k, last) = if k = 0 then last else again (k - 1, once ())
      val (t, b) = again (!Options.lexCount, (0, 0))
    in
      println (Int.toString t ^ " tokens, " ^ Int.toString b ^ " bytes");
      OS.Process.success
    end

  fun parseTokens (toks : Lexer.item vector) : Ast.program =
    let val (prog, fx) = Parser.parseTokensWith (toks, !fixity)
    in fixity := fx; prog end

  (* --basis-check: the provides and requires columns say what the sources
     do, and every required file comes first. A demand file declares modules
     and type abbreviations only, all of them in its provides column: what it
     puts in scope is then in scope for exactly the programs that mention it.
     (A top-level value or fixity directive belongs in an always file.) *)
  fun checkManifest () : OS.Process.status =
    let
      val basisEntries = readManifest ()
      val libs = libraryManifests ()
      val ok = ref true
      val declaredKinds = ref StringMap.empty : unit StringMap.map ref
      fun declarationKey (dir,kind,name) = dir ^ "\000" ^ kind ^ " " ^ name
      fun complain (e : entry, msg) = (eprintln ("rune: " ^ #dir e ^ "/MANIFEST: " ^ #file e ^ ": " ^ msg); ok := false)
      fun sorted l = StringMap.listKeys (List.foldl (fn (n, m) => StringMap.insert (m, n, ())) StringMap.empty l)
      fun show l = String.concatWith " " l
      (* A file of the basis library is checked against the basis library;
         one of another library against it and all that comes before it, or
         where the library has a header, against what it sees. *)
      fun check provider (e : entry, earlier : names) : names =
        let
          val toks = loadTokens (Source.Ascii, BasisManifest.path e)
          val (prog, fx) = Parser.parseTokensWith (toks, !fixity)
          val () = fixity := fx
          val declared =
            List.concat (List.map (fn Ast.DStructure (binds, _, _) => List.map #name binds
                                    | Ast.DSignature (binds, _, _) => List.map #name binds
                                    | Ast.DFunctor (binds, _, _) => List.map #name binds
                                    | Ast.DType (binds, _, _) => List.map #name binds
                                    | _ => []) prog)
          val () = if sorted declared = sorted (#provides e) then ()
                   else complain (e, "provides " ^ show (sorted (#provides e)) ^ " but declares " ^ show (sorted declared))
          val deps = Deps.analyse (BasisManifest.path e,prog)
          val () = if #when e = Final then () else List.app (fn (kind,name) =>
            declaredKinds := StringMap.insert (!declaredKinds,declarationKey (#dir e,Deps.kindName kind,name),()))
            (#declares deps)
          (* the names another file provides and this one does not *)
          val used =
            List.filter (fn n => not (List.exists (fn p => p = n) (#provides e))
                                 andalso (case StringMap.find (provider, n) of
                                            SOME files => List.exists (fn f => f <> BasisManifest.path e) files
                                          | NONE => false))
                        (StringMap.listKeys
                           (List.foldl (fn ((_, n), m) => StringMap.insert (m, n, ())) StringMap.empty
                                       (#uses deps)))
          (* -Name in the column: named, but not required *)
          fun plain n = if String.isPrefix "-" n then String.extract (n, 1, NONE) else n
          val () = if used = sorted (List.map plain (#requires e ())) then ()
                   else complain (e, "requires " ^ show (#requires e ()) ^ " but names " ^ show used)
          val () = List.app (fn n => if String.isPrefix "-" n orelse StringMap.member (earlier, n) then ()
                                     else complain (e, "requires " ^ n ^ ", which is not provided by an earlier file"))
                            (#requires e ())
          val () =
            if #when e <> Demand andalso #when e <> Seal then ()
            else if isSome (#view e) then
              (* a view seals structures again, and what is wired in stays
                 outside it (D12) *)
              List.app (fn Ast.DStructure _ => () | Ast.DSignature _ => ()
                         | d => complain (e, "a view's seal may declare structures and signatures only, but has: " ^
                                             String.substring (Ast.decToString d ^ "                    ", 0, 20)))
                       prog
            else List.app (fn Ast.DStructure _ => () | Ast.DSignature _ => () | Ast.DFunctor _ => ()
                            | Ast.DType _ => () | Ast.DOverload _ => ()
                            | d => complain (e, "a demand file may declare modules and types only, but has: " ^
                                                String.substring (Ast.decToString d ^ "                    ", 0, 20)))
                          prog
        in List.foldl (fn (n, m) => StringMap.insert (m, n, ())) earlier (#provides e) end
      val scopes = BasisManifest.scopes {root = libRoot (), building = !Options.build, names = !Options.libraries, headed = false,
                                         libraries = libs, view = NONE}
                   handle BasisManifest.Usage why => raise Options.Usage why
      val walk = LibraryScope.walk (ref Env.initial, fixity, ref StringMap.empty, scopes)
      val checkBasis = fn () => List.foldl (check (providers basisEntries)) StringMap.empty basisEntries
      val earlier = if List.null basisEntries then checkBasis () else LibraryScope.group (walk, basisEntries, checkBasis)
      val all = basisEntries @ List.concat (List.map #2 libs)
      (* what a file of a library may name of the others *)
      fun providersOf dir =
        case BasisManifest.importsOf (scopes, dir) of
          NONE => providers all
        | SOME imports =>
            let
              fun visible (e as {dir = d, file, when, provides, requires, scope, header, view} : entry) =
                if d = dir then e
                else {dir = d, file = file, when = when, provides = BasisManifest.seenNames (imports, e),
                      requires = requires, scope = scope, header = header, view = view}
            in providers (basisEntries @ List.map visible (List.concat (List.map #2 libs))) end
      fun library ((dir,[]),earlier) = earlier
        | library ((dir,es),earlier) =
        let val raw = LibraryScope.group (walk, es, fn () => List.foldl (check (providersOf dir)) earlier es)
        in case BasisManifest.scopeOf es of
             NONE => raw
           | SOME exports =>
               (List.app (fn (kind,name) =>
                  if kind = "fixity" orelse StringMap.member (!declaredKinds,declarationKey (dir,kind,name)) then ()
                  else (eprintln ("rune: " ^ dir ^ "/MANIFEST: exports " ^ kind ^ " " ^ name ^
                                  ", which no source before the program declares");ok := false)) exports;
                List.foldl (fn ((_,name),m) => StringMap.insert (m,name,())) earlier exports)
        end
      val _ = List.foldl library earlier libs
      val count = List.length all
    in
      if !ok then (println ("basis-check: OK (" ^ Int.toString count ^ " files)"); OS.Process.success)
      else OS.Process.failure
    end

  (* --read-mid: a Mid program from its text, made and checked as the pass
     mid makes and checks one; there is no bytecode from Mid yet. *)
  fun readMid (file : string) : OS.Process.status =
    let
      val text = #text (Source.readFile (Source.Ascii, file)) handle IO.Io _ => raise Options.Usage ("cannot read " ^ file)
      fun parse t = MidText.parse t handle MidText.Syntax msg => raise Options.Usage (file ^ ": " ^ msg)
    in
      ignore (Pipeline.midStage NONE parse text);
      OS.Process.success
    end

  (* whether the program being linked keeps its units' exports in its file
     (compileUnits) *)
  val keepExports = ref false
  (* whether the files of the program say that it loads units, by name
     (BasisManifest.namesLoading), which selecting its libraries finds out *)
  val namesLoading = ref false
  (* a program found to load units only once a unit was taken across a unit
     that changed, and the unit that showed it: compileUnits leaves it to be
     compiled again, knowing (compiledAgain) *)
  exception LoadsUnits of string
  val knownToLoad = ref false

  (* ---- the graph (Deps; the incremental roadmap's M8) ---- *)

  (* a file's syntax, for the names it declares and uses, in a fixity *)
  fun syntaxIn (mode : Source.mode, path : string, fx : Fixity.env) : Ast.program * Fixity.env =
    Parser.parseTokensWith (loadTokens (mode, path), fx)
  (* in the initial basis's, for a file of no known place *)
  fun syntaxOf (mode : Source.mode, path : string) : Ast.program = #1 (syntaxIn (mode, path, Fixity.initial))

  (* the files given, each read in the fixity those before it leave, as a
     compile reads them *)
  fun analysedInOrder (analyse : string * Ast.program -> Deps.file) (paths : string list) : Deps.file list =
    List.rev (#1 (List.foldl (fn (p, (acc, fx)) =>
                                let val (prog, fx') = syntaxIn (inputMode p, p, fx)
                                in (analyse (p, prog) :: acc, fx') end)
                             ([], Fixity.initial) paths))

  (* where a build breaks the rules, for those who asked *)
  fun warnIllFormed (findings : (Source.span * string) list) : unit =
    if !Options.noWarnings then ()
    else (List.app (fn (sp, what) => Error.warn (sp, Deps.notWellFormed what)) findings; Error.flushWarnings ())

  (* -I DIR: the one input an entry point, and before it the files of its
     directory and of each DIR that it needs, in the graph's order. A file
     that is not well-formed has no place there, with no written order to
     keep it, and is none of them *)
  fun entryFiles (main : string) : string list =
    let
      fun smlFiles d =
        (let
           val s = OS.FileSys.openDir (if d = "" then "." else d)
           fun go acc = case OS.FileSys.readDir s of
                          NONE => acc
                        | SOME f => go (if String.isSuffix ".sml" f then OS.Path.joinDirFile {dir = d, file = f} :: acc else acc)
         in go [] before OS.FileSys.closeDir s end)
        handle OS.SysErr _ => raise Options.Usage ("-I: cannot read the directory " ^ d)
      fun sorted l = StringMap.listKeys (List.foldl (fn (n, m) => StringMap.insert (m, n, ())) StringMap.empty l)
      val same = fn (a, b) => OS.Path.mkCanonical a = OS.Path.mkCanonical b
      val candidates = List.filter (fn p => not (same (p, main)))
                                   (sorted (List.concat (List.map smlFiles (OS.Path.dir main :: !Options.includeDirs))))
      val analysed = List.map (fn p => Deps.analyse (p, syntaxOf (!Options.sourceMode, p))) candidates
      val (group, broken) = List.partition (fn (f : Deps.file) => List.null (#breaks f)) analysed
      val program = Deps.analyse (main, syntaxOf (!Options.sourceMode, main))
      (* a file left out that declares what the program names: said *)
      val () =
        List.app (fn (f : Deps.file) =>
                    if List.exists (fn d => List.exists (fn u => u = d) (#uses program)) (#declares f)
                    then eprintln ("rune: " ^ #path f ^ " declares a module " ^ main ^ " names, and is not well-formed: "
                                   ^ Error.format (hd (#breaks f)))
                    else ())
                 broken
    in
      List.map #path (Deps.closure (group, #uses program)) @ [main]
      handle Deps.Graph msg => raise Options.Usage msg
    end

  (* ---- build files (docs/build.md; the incremental roadmap's M10) ---- *)

  (* What a compile is: a unit -- a file, with the annotations in force -- or
     a scope of units whose basis a build file says, which the units driver
     follows (compileUnits, elabSteps). The command line says it too, for
     files given by themselves, so that there is one plan (D6; commandPlan). *)
  datatype step = datatype CompilerProject.step

  val buildPlan : step list ref = ref []
  (* what of the Basis Library the plan takes, demand, all or none, and its
     view of it (CompilerProject.plan) *)
  val planBasis : {basis : string, view : string option} ref = ref {basis = "demand", view = NONE}

  fun readText (f : string) : string =
    let val i = TextIO.openIn f in TextIO.inputAll i before TextIO.closeIn i end

  val onWindows = Workspace.onWindows
  (* The workspace of this compile, from the build file or the first file
     given, and the file that was: the libraries it names are found by
     `libraries` and --library, and a build's units are named from it *)
  val workspace : Workspace.t option ref = ref NONE
  val entryFile : string option ref = ref NONE
  fun findWorkspace (file : string) : unit =
    (workspace := (Workspace.find {file=file,windows=onWindows ()}
                   handle Workspace.Invalid message => raise Options.Usage message);
     BasisManifest.roots := (case !workspace of
                               SOME w => List.map (fn root => Workspace.fromHere (onWindows (), root)) (#libraryRoots w)
                             | NONE => []))
  (* where this compile's units are named from (Workspace), lib being where
     its libraries are *)
  fun scopeWith (lib : string option) : Workspace.scope =
    let val windows=onWindows ()
    in case (!Options.build,!entryFile) of
         (SOME file,_) => Workspace.ofBuild {file=file,workspace= !workspace,lib=lib,windows=windows}
       | (NONE,file) => Workspace.ofFiles {file=getOpt (file,"."),workspace= !workspace,lib=lib,windows=windows}
    end
  fun unitScope () : Workspace.scope = scopeWith (!Options.libDir)
  fun readBuild (path : string) =
    let val text=readText path handle IO.Io _ => raise CompilerProject.Invalid ("cannot read the build file " ^ path)
    in {text=text,revision=Pickle.hash text} end
  fun projectOf (file : string) : CompilerProject.plan =
    CompilerProject.plan {file=file,windows=onWindows (),readBuild=readBuild}
    handle CompilerProject.Invalid message => raise Options.Usage message

  (* --deps --build: what the build compiles, in its order, and where it
     breaks the rules *)
  fun depsOfBuild (file : string) : Deps.file list =
    let
      val () = findWorkspace file
      val project = projectOf file
      (* a file is read as a compile reads it, through its preprocessor; a
         step is not run (docs/build.md, Generated sources) *)
      val () = Steps.preprocess {windows = onWindows (), cache = UnitCache.directory (), explain = fn _ => ()}
                                (#preprocessors project) (CompilerProject.units (#steps project))
      val imported = List.concat (List.map BasisManifest.fixities (BasisManifest.libraries (libRoot (), #libraries project)))
                     handle BasisManifest.Usage why => raise Options.Usage why
      val layout = CompilerProject.layout {steps = #steps project, defaultMode = !Options.sourceMode,
                                           library = OS.Path.file file = "library.build", syntax = syntaxIn,
                                           fixity = Fixity.extend (Fixity.initial, imported)}
      val () = warnIllFormed (Deps.illFormed layout)
      fun filesIn (Deps.Unit (f, _)) = [Deps.declared f]
        | filesIn (Deps.Scope ls) = List.concat (List.map filesIn ls)
    in List.concat (List.map filesIn layout) end

  (* --deps, --deps-dot: the inputs in an order the modules they declare and
     use give, or as the graph; with --build, the build's order, which a
     build file writes *)
  fun depsCommand () : OS.Process.status =
    if !Options.depsUses then
      (* the names, whatever they are of: what a MANIFEST's requires
         column is made of (scripts/gen-basis-sigs.sh) *)
      let
        val names = List.foldl (fn (f : Deps.file, m) => List.foldl (fn ((_, n), m) => StringMap.insert (m, n, ())) m (#uses f))
                               StringMap.empty (analysedInOrder Deps.analyse (!Options.inputs))
      in List.app println (StringMap.listKeys names); OS.Process.success end
    else
    let
      val files =
        case !Options.build of
          SOME file => depsOfBuild file
        | NONE =>
            let val files = analysedInOrder Deps.analyseUnit (!Options.inputs)
            in warnIllFormed (Deps.illFormed (List.map (fn f => Deps.Unit (f, NONE)) files)); files end
    in
      (let val (ordered, edges) = Deps.order files
       in
         if !Options.depsDot then print (Deps.dot edges) else List.app (fn (f : Deps.file) => println (#path f)) ordered;
         OS.Process.success
       end)
      handle Deps.Graph msg => (eprintln ("rune: " ^ msg); OS.Process.failure)
    end

  (* What the command line asks for, as a plan: the build file's, or the files
     it gives, with -I those of an entry point (entryFiles). *)
  fun commandPlan () : CompilerProject.plan =
    let
      val project =
        case !Options.build of
          SOME f =>
            (if List.null (!Options.includeDirs) then () else raise Options.Usage "-I wants an entry point, and a build file says its own files";
             findWorkspace f;
             projectOf f)
        | NONE =>
            CompilerProject.ofFiles {libraries=[],files=
              case (!Options.includeDirs, !Options.inputs) of
                ([], files) => files
              | (_, [main]) => entryFiles main
              | (_, files) => if !knownToLoad then files else raise Options.Usage "-I wants one input, the entry point"}
      (* what of the Basis Library a compile takes is the plan's too, the
         command line's part of it *)
      val project = CompilerProject.withBasis (project, {basis = if !Options.noPrelude then "none" else if !Options.basisAll then "all" else "demand",
                                                         view = !Options.basisView})
                    handle CompilerProject.Invalid message => raise Options.Usage message
    in
      if #basis project = "none" andalso isSome (#view project)
      then raise Options.Usage "a view of the Basis Library needs the Basis Library (not --no-prelude)"
      else project
    end

  (* a compile's libraries: those of --library, then what its plan names *)
  fun librariesOf (project : CompilerProject.plan) : string list =
    List.foldl (fn (library, all) => if List.exists (fn present => present = library) all then all else all @ [library])
               (!Options.libraries) (#libraries project)

  (* The plan of this compile, all of it, each library read from its build
     file: what --plan prints and --build-list flattens. Its paths are from
     here, --lib's too, so that a plan made at the top of a checkout holds no
     directory of the machine. *)
  fun wholePlan () : CompilerPlan.t =
    let
      val windows = onWindows ()
      val () = entryFile := (case !Options.inputs of first :: _ => SOME first | [] => NONE)
      val project = commandPlan ()
      val libraries = librariesOf project
      val () = if List.null libraries then () else ignore (libRoot ())
      val lib = Option.map (fn dir => case Workspace.fromHere (windows, Workspace.keyOf (windows, Workspace.here ()) dir) of
                                        "" => "." | relative => relative) (!Options.libDir)
    in
      CompilerPlan.make {project = project, libraries = libraries, lib = lib, mode = !Options.sourceMode, scope = scopeWith lib,
                         windows = windows, read = readBuild, hash = Hex.fromBytes o Sha256.digest,
                         (* where a virtual library's tail begins: a file that says _virtual (D22) *)
                         virtual = fn path => Vector.exists (fn (Token.VIRTUAL, _) => true | _ => false) (loadTokens (Source.Ascii, path))}
      handle CompilerProject.Invalid message => raise Options.Usage message
    end

  (* --plan: the plan's text (docs/build.md, The plan), of the build file given
     or of what the command line says; of a stored plan, that text again. The
     text is read back as it is printed, so that what is printed can be. *)
  fun planCommand () : OS.Process.status =
    let
      fun readBack text =
        let val again = CompilerPlan.print (CompilerPlan.read text)
        in if again = text then text else raise Error.Bug "--plan: a plan's text does not read back as it is" end
        handle CompilerPlan.Bad why => raise Options.Usage ("not a plan: " ^ why)
      fun stored file =
        readBack (CompilerPlan.print (CompilerPlan.read (readText file)))
        handle IO.Io _ => raise Options.Usage (Options.cannotRead file)
             | CompilerPlan.Bad why => raise Options.Usage (file ^ ": not a plan: " ^ why)
    in
      case !Options.inputs of
        [file] =>
          if String.isSuffix ".plan" file then print (stored file)
          else
            (if String.isSuffix ".build" file then (Options.build := SOME file; Options.inputs := []) else ();
             print (readBack (CompilerPlan.print (wholePlan ()))))
      | _ => print (readBack (CompilerPlan.print (wholePlan ())));
      OS.Process.success
    end

  (* --basis-index DIR: DIR/MANIFEST, from DIR/library.build (LibraryIndex) *)
  fun indexCommand (dir : string) : OS.Process.status =
    (findWorkspace (OS.Path.joinDirFile {dir = dir, file = "library.build"});
     LibraryIndex.write {dir = dir, root = libRoot (), warnings = not (!Options.noWarnings), windows = onWindows ()};
     OS.Process.success)

  (* the files of a plan, in the order they are compiled, with their
     annotations *)
  val unitsOf = CompilerProject.units
  val filesOf = CompilerProject.files

  (* --build-list FILE: the closure of a build: the plan flattened, the files
     of the libraries it names and of those they are written on, each library
     before what is written on it, then its own, then the libraries' final
     files. Whole libraries, of what a program may name: which of their files
     one compile takes is --basis-deps. The Basis Library is every program's,
     and not in the list. *)
  fun buildList () : OS.Process.status =
    (List.app println (CompilerPlan.flatten (wholePlan ()));
     OS.Process.success)

  fun compile () : OS.Process.status =
    let
      (* what a compile begins with that is not one of the compiler's roots,
         for one made again (diagnosed, compiledAgain) *)
      val () = (fixity := Fixity.initial; keptSyntax := []; namesLoading := false; workspace := NONE; BasisManifest.roots := [])
      (* files given by themselves: the first names their units, and the
         workspace above it has only libraries to give them *)
      val () = if !knownToLoad then () else entryFile := (case !Options.inputs of first :: _ => SOME first | [] => NONE)
      (* the plan: the inputs are its files, and it is what the units driver
         follows *)
      val project = commandPlan ()
      (* reaching into a library, which a later roadmap's milestone refuses
         (docs/build.md, Reaching in) *)
      val () =
        if !Options.noWarnings orelse !knownToLoad then ()
        else
          (List.app (fn (build,library,paths) =>
             Error.warn ({file=build,start=0,stop=0},
               "this build reaches into the library " ^ library ^ " (" ^ Int.toString paths
               ^ (if paths=1 then " path" else " paths") ^ "), which is reached through its interface"))
             (CompilerProject.reaches {references= #references project,windows=onWindows (),
                isLibrary=fn dir => OS.FileSys.access (OS.Path.joinDirFile {dir=dir,file="library.build"},[])
                                    handle OS.SysErr _ => false});
           Error.flushWarnings ())
      val () = Options.libraries := librariesOf project
      (* the functors its build files mark to be inlined (M6b) *)
      val () = Elaborate.inlineFunctors := List.foldl (fn (n,m) => StringMap.insert (m,n,()))
                                                      (!Elaborate.inlineFunctors) (#inline project)
      (* and the functions (functors-units M10) *)
      val () = Elaborate.inlineValues := List.foldl (fn (n,m) => StringMap.insert (m,n,()))
                                                    (!Elaborate.inlineValues) (#inlineValues project)
      val () = buildPlan := #steps project
      val () = planBasis := {basis = #basis project, view = #view project}
      val () = Options.inputs := filesOf (!buildPlan)
      val () = buildModes := List.foldl (fn ((p, anns), m) => if StringMap.member (m, p) then m
                                                              else StringMap.insert (m, p, modeOf anns))
                                        StringMap.empty (unitsOf (!buildPlan))
      (* what the build runs before a unit is read: its steps, and its
         preprocessors, whose output each unit of theirs compiles (Steps;
         docs/build.md, Generated sources) *)
      val () = Steps.prepare {project = project, cache = UnitCache.directory (), windows = onWindows (),
                              explain = fn message => if !Options.explainRebuild then eprintln message else ()}
      val () =
        case (!Options.build,!entryFile,!Options.libraries) of
          (NONE,SOME first,_ :: _) => findWorkspace first
        | _ => ()
      (* the functors and the functions the Basis Library's and the chosen
         libraries' build files mark to be inlined (docs/build.md, Inline
         functors and functions) *)
      val () =
        if #basis (!planBasis) <> "none" andalso not (!Options.noInlineFunctors) then
          let
            val dirs = libDir () :: (BasisManifest.libraries (libRoot (), !Options.libraries)
                                     handle BasisManifest.Usage _ => [])
            fun add (table, names) = table := List.foldl (fn (n, m) => StringMap.insert (m, n, ())) (!table) names
          in
            add (Elaborate.inlineFunctors, List.concat (List.map BasisManifest.inlineFunctors dirs));
            add (Elaborate.inlineValues, List.concat (List.map BasisManifest.inlineValues dirs))
          end
        else ()
      (* a whole program's dynamic modules: none (UnitBasis.wholeFingerprints) *)
      val () = UnitBasis.wholeFingerprints := (not (!Options.units) orelse !Options.wholeFromUnits)
      val inputs = !Options.inputs
      val () = if List.null inputs then raise Options.Usage "no input files" else ()
    in
      if List.all (fn f => String.isSuffix ".rbu" f) inputs then linkUnitFiles inputs
      else compileSources inputs
    end

  and compileSources (inputs : string list) : OS.Process.status =
    let
      (* the input files read and lexed, and the files of the libraries
         they need chosen: stages of --pass-stats, whose sizes are the
         tokens and the files chosen *)
      val userToks =
        Pass.stage {name = "lex", showIn = NONE, show = fn _ => "", check = fn _ => (),
                    size = List.foldl (fn (toks, n) => n + Vector.length toks) 0}
                   (List.map (fn p => loadTokens (inputMode p, p))) inputs
      (* what of the Basis Library the plan takes, and its view of it *)
      val {basis = taken, view} = !planBasis
      val () = if taken = "none" andalso not (List.null (!Options.libraries))
               then raise Options.Usage "--library needs the basis library (not --no-prelude)" else ()
      val () = librariesScoped := BasisManifest.noScopes ""
      val () = libraryVirtuals := []
      val basis =
        Pass.stage {name = "select", showIn = NONE, show = fn _ => "", check = fn _ => (), size = List.length}
                   (fn () =>
        if taken = "none" then []
        else
          let
            val found = CompilerPrelude.candidates {root = libRoot (), libraries = !Options.libraries, building = !Options.build,
                                                    view = view}
                        handle BasisManifest.Usage why => raise Options.Usage why
            val {entries, scopes, ...} = found
            val () = librariesScoped := scopes
            val () = libraryVirtuals := (BasisManifest.virtualModules (#libraries found)
                                         handle BasisManifest.Usage why => raise Options.Usage why)
            (* two imports of one name in the program's scope, each an error
               that a rename at import answers (D9) *)
            val () =
              if not (#scoped scopes) then ()
              else
                case BasisManifest.clashes (#program scopes, entries, libDir ()) of
                  [] => ()
                | found =>
                    (List.app (fn clash => Error.report ({file = getOpt (!Options.build, hd inputs), start = 0, stop = 0},
                                                         LibraryIndex.clashText (libRoot ()) clash)) found;
                     raise Reported)
            (* the fixity a program's files are read in: the initial basis's,
               and what the libraries it sees export (docs/build.md) *)
            val imported = List.concat (List.map (fn (dir, _) => BasisManifest.fixities dir) (#libraries found))
            val mentioned = CompilerPrelude.usedByAll (scopes, entries, inputs, userToks, Fixity.extend (Fixity.initial, imported))
            val () = namesLoading := List.exists BasisManifest.namesLoading userToks
            fun tokens (e : entry) =
              let val toks = loadTokens (Source.Ascii, BasisManifest.path e)
              in if BasisManifest.namesLoading toks then namesLoading := true else (); toks end
            val selected = CompilerPrelude.choose (found, mentioned, tokens)
          in
            if taken = "all" then BasisManifest.inView (scopes, entries) handle BasisManifest.Usage why => raise Options.Usage why
            else selected
          end) ()
    in
      if !Options.basisDeps
      then (List.app (fn e : entry => println (if inBasis e then #file e else BasisManifest.path e)) basis;
            OS.Process.success)
      else compileWith (List.filter (fn e : entry => #when e <> Final) basis,
                        List.filter (fn e : entry => #when e = Final) basis, userToks, inputs)
    end

  (* The front end and the back end are two functions, so that nothing of
     the first -- tokens, syntax, environment -- is still reachable, and
     copied by every collection, while the second runs: compileWith
     calls frontEnd and then hands its result on in a tail call. *)
  and compileWith (args : entry list * entry list * Lexer.item vector list * string list) : OS.Process.status =
    if !Options.units then compileUnits args
    else backEnd (#4 args, frontEnd args)

  (* --units: every file a unit of its own -- the basis library's, those of
     the libraries beside it, the program's -- compiled after the ones before
     it, and the units linked (docs/units.md; Link). The environment, the
     fixity and the compiler's tables go on from unit to unit, as each unit's
     basis gives them (Pipeline.unitThrough); the passes see one unit at a
     time (Pass.whole). *)
  and compileUnits (basis : entry list, final : entry list, userToks, inputs : string list) : OS.Process.status =
    let
      val () = Pass.whole := false
      val () = Elaborate.recover := true
      (* --whole: each unit's Mid, as the session names it, for one program
         of them all (the incremental roadmap's M7) *)
      val () = Pipeline.keepMid := (!Options.wholeFromUnits orelse isSome (UnitCache.directory ()))
      val mids : MidCanon.unitMid list ref = ref []
      val registers = !Options.target = "registers"
      val () = if registers then Code.opcodeNames := RegCodes.names else ()
      val env = ref (Env.initialNow ())
      val () = UnitBasis.startSession ()
      (* each unit's source, its tokens when wanted, whether it may use
         _prim -- the basis library may, the libraries beside it may not --
         and its logical name, with a rank where it is another's, in the
         order of the units (Workspace): no spelling of a path reaches a
         key, an identity or an anchor, and a cache follows a library where
         it is moved (UnitCache) *)
      val logical = Workspace.names (unitScope ())
      val ranks = Workspace.ranks ()
      val entryNames : string StringMap.map ref = ref StringMap.empty
      fun nameEntry (e : entry) =
        entryNames := StringMap.insert (!entryNames, BasisManifest.path e,
                                        Workspace.fresh (ranks, Workspace.ofEntry (logical, {dir = #dir e, file = #file e})))
      fun file (e : entry, allow) =
        (BasisManifest.path e, fn () => loadTokens (Source.Ascii, BasisManifest.path e), allow,
         valOf (StringMap.find (!entryNames, BasisManifest.path e)), Source.Ascii)
      val () = List.app nameEntry basis
      val basisPart = List.map (fn e => file (e, inBasis e)) basis
      val userPart = ListPair.map (fn (toks, name) => (name, fn () => toks, !Options.allowPrim,
                                                       Workspace.fresh (ranks, Workspace.name (logical, name)), inputMode name))
                                  (userToks, inputs)
      val () = List.app nameEntry final
      val finalPart = List.map (fn e => file (e, !Options.allowPrim)) final
      val sources = basisPart @ userPart @ finalPart
      val buildContext=CompilerBuildContext.new (env,fixity)
      fun logDeclared result=CompilerBuildContext.note (buildContext,result)
      (* A program that loads units while it runs -- a unit of it names a
         member of Runtime that loads one or reads what is kept for that
         (BasisManifest.loading), or it has a dynamic module -- keeps in its
         file what its units export, under the identities a build from source
         gives them, which a unit loaded into it names: so it takes no unit
         from the cache across a unit that changed (UnitBasis.remapAllowed;
         docs/units.md, Dynamic modules). A program that names Runtime for
         its counters, or has a Runtime of its own, is none of these.

         Where the files say so, by name or by holding dynamic.sml, that is
         known here. Any other program with Runtime's file is judged a unit
         at a time, by the keys its code names, however it came to them (an
         alias, an open, a functor's argument). The program is known to load
         units only once it reaches such a unit: if none was taken across a
         unit that changed by then, the rest are kept from it, and it is what
         a build knowing it from the start makes; if one was, it is compiled
         again (compiledAgain), from the state sealed here.

         --emit-units gives the units' identities to whoever reads them, as
         a loader might: a program with Runtime's file takes no unit across
         a change then either, and is the same program. *)
      fun holds file = List.exists (fn (_, _, _, ident, _) => ident = file) sources
      val runtimeFile = BasisManifest.runtimeFile
      val known = !knownToLoad orelse !namesLoading orelse holds BasisManifest.dynamicFile
      val judged = holds runtimeFile andalso not known andalso not (!Options.typecheckOnly)
      val () = keepExports := known
      val () = UnitBasis.remapAllowed := not (known orelse (holds runtimeFile andalso isSome (!Options.emitUnits)))
      val () = UnitCache.across := false
      val () = if judged andalso !UnitBasis.remapAllowed andalso isSome (UnitCache.directory ())
               then CompilerState.seal () else ()
      val loadingKeys : Link.key list ref = ref []
      fun judge (name, ident, acc) =
        if not judged orelse !keepExports then ()
        else
          case acc of
            (u, _) :: _ =>
              if ident = runtimeFile then loadingKeys := Link.functionKeys (u, BasisManifest.loadingFunctions)
              else if not (Link.namesKey (u, !loadingKeys)) then ()
              else if !UnitCache.across andalso not (isSome (!Parallel.child)) then raise LoadsUnits name
              else (UnitBasis.remapAllowed := false; keepExports := true)
          | [] => ()
      (* the front end's stages, for --pass-stats; their size is the number of
         top-level declarations *)
      fun frontStage name f =
        Pass.stage {name = name, showIn = NONE, show = fn _ => "", check = fn _ => (), size = List.length} f
      fun text (name, mode) () =
        case Source.findFile name of
          SOME f => #text f
        | NONE => #text (Source.load (mode, name)) handle IO.Io _ => raise Options.Usage (Options.cannotRead name)
      (* the cache (UnitCache): its directory and configuration; after a
         unit that failed, the units are elaborated for their errors alone,
         and not looked for *)
      val cache = Option.map (fn d => (d, UnitCache.configuration ())) (UnitCache.directory ())
      val frozen = UnitCache.frozen ()
      val failedBefore = ref false
      (* --verify-cache: the units whose entry is not what compiling them gives *)
      val unverified = ref 0
      fun explain msg = if !Options.explainRebuild then TextIO.output (TextIO.stdErr, msg ^ "\n") else ()
      fun cachePaths (dir, config) = UnitCache.pathsIn (dir :: (case frozen of SOME f => [f] | NONE => []), config)
      (* entries of this compile's configuration but for the hash, in the
         cache or the frozen Basis: a compiler's whose hash gives other values
         (UnitCache.settings), which none is taken from *)
      val otherHash =
        if not (!Options.explainRebuild) then NONE
        else
          case cache of
            SOME (dir, config) =>
              (case UnitCache.otherHash (dir, config) of
                 SOME p => (explain ("rune: the cache " ^ dir ^ " holds entries made by a compiler whose hash differs (its "
                                     ^ p ^ ", this compiler's " ^ Pickle.probe () ^ "): none is taken");
                            SOME p)
               | NONE => NONE)
          | NONE => NONE
      val () =
        case (cache, frozen) of
          (SOME (_, config), SOME f) =>
            if not (!Options.explainRebuild) then ()
            else (case UnitCache.otherHash (f, config) of
                    SOME p => explain ("rune: the frozen Basis " ^ f ^ " was made by a compiler whose hash differs (its " ^ p
                                       ^ ", this compiler's " ^ Pickle.probe () ^ "): its units are compiled")
                  | NONE => ())
        | _ => ()
      (* the cache's work, for --pass-stats *)
      val timed = Pass.timed
      (* the input files' settings, which the libraries are compiled
         without: in their units' keys, so that a unit compiled under them is
         not taken for one compiled without (--default-type, --or-patterns,
         and --no-unicode-lints, since an entry keeps the warnings it
         leaves out) *)
      val userSettings =
        String.concatWith " " (List.filter (fn s => s <> "")
                                 [if !Options.defaultInt64 then "int64" else "",
                                  if !Options.defaultWord64 then "word64" else "",
                                  if !Options.orPatterns then "or-patterns" else "",
                                  if !Lexer.lints then "" else "no-unicode-lints"])
      val userNames = List.foldl (fn ((_, _, _, ident, _), m) => StringMap.insert (m, ident, ())) StringMap.empty userPart
      (* and the unit's mode, where it is not the default: a unit read in
         one mode is not taken for one read in another (docs/plans/utf8.md,
         D1) *)
      fun settingsOf (ident, mode) =
        String.concatWith " " (List.filter (fn s => s <> "")
                                 [if isSome (StringMap.find (userNames, ident)) then userSettings else "",
                                  if mode = Source.Ascii then "" else Source.modeName mode])
      (* --default-type holds for the input files, not for the libraries *)
      fun withDefaults f x =
        let
          fun reset () = (Elaborate.intDefault := Types.intTy; Elaborate.wordDefault := Types.wordTy)
        in
          Elaborate.intDefault := (if !Options.defaultInt64 then Types.int64Ty else Types.intTy);
          Elaborate.wordDefault := (if !Options.defaultWord64 then Types.word64Ty else Types.wordTy);
          (f x before reset ()) handle e => (reset (); raise e)
        end
      (* a unit's basis, kept to the end for --emit-units alone, which
         writes it: a unit of MLton's has megabytes of it *)
      fun keptPickle (p : string) : string = if isSome (!Options.emitUnits) then p else ""
      (* a unit: from the cache, or compiled; with -j, by a child where it
         is likely to be compiled, or skipped in a child that does not need
         it (Parallel) *)
      fun unit (src as (name, _, _, ident, _), acc) =
        let
          val acc =
            case Parallel.at ident of
              Parallel.Skip => acc
            | Parallel.Run {quiet} => timedUnit (src, acc, quiet)
            | Parallel.Compile => timedUnit (src, acc, false)
        in judge (name, ident, acc); acc end
      (* --pass-stats: what each unit took, start to end *)
      and timedUnit (src as (name, _, _, ident, _), acc, quiet) =
        let
          val t0 = if !Pass.stats then Time.now () else Time.zeroTime
          val (acc, compiledIt) = unitHere (src, acc, quiet)
          val () = if !Pass.stats
                   then TextIO.output (TextIO.stdErr, "unit " ^ name ^ " took "
                                                      ^ Real.fmt (StringCvt.FIX (SOME 3)) (Time.toReal (Time.- (Time.now (), t0)))
                                                      ^ " s" ^ (if compiledIt then "" else ", from the cache")
                                                      ^ (if isSome (OS.Process.getEnv "RUNE_MEM")
                                                         then ", live " ^ Int.toString (!Pass.liveBytes ()) else "")
                                                      ^ "\n")
                   else ()
        in Parallel.after (ident, compiledIt); acc end
      and unitHere ((name, load, allow, ident, mode), acc, quiet) =
        let
          val () = if !Pass.stats then TextIO.output (TextIO.stdErr, "unit " ^ name ^ "\n") else ()
          val k = case cache of
                    SOME _ =>
                      if !failedBefore then NONE
                      else SOME (timed "cache-key" (fn () => UnitCache.key {name = ident, text = text (name, mode) (), allow = allow,
                                                                            settings = settingsOf (ident, mode)}))
                  | NONE => NONE
          (* the unit's place, which its entries' usages are checked at *)
          val () = UnitBasis.position (!env, !fixity)
          (* from the cache: its basis loaded, its code read; or why not *)
          datatype looked = Hit of UnitBasis.result * Link.unitCode * string * UnitCache.entry | Miss of string
          fun lookup quiet : looked * (UnitCache.entry * CacheCheck.unitForm option) option =
            let
              val found =
                case (cache, k) of
                  (SOME (dir, config), SOME k) =>
                    timed "cache-find"
                      (fn () => case (UnitCache.find (dir, config, k), frozen) of
                                  (UnitCache.Missed why, SOME f) =>
                                    (case UnitCache.find (f, config, k) of
                                       UnitCache.Missed "no entry" => UnitCache.Missed why
                                     | UnitCache.Missed fwhy => UnitCache.Missed (why ^ "; the frozen Basis's: " ^ fwhy)
                                     | found => found)
                                | (found, _) => found)
                | _ => UnitCache.Missed (if isSome cache then "a unit before it failed" else "the cache is off")
              (* --verify-cache: an entry found is compiled all the same, and
                 what that gives is compared with it *)
              val (found, against) =
                case found of
                  UnitCache.Found (e as {usages, pickle, ...}) =>
                    if not (UnitCache.verifying ()) then (found, NONE)
                    else if UnitBasis.exactEntry (usages, pickle) then (UnitCache.Missed "to verify its entry", SOME (e, NONE))
                    (* one taken across a unit that changed names the old
                       unit: what it comes to loaded here is what is
                       compared (issue 15, CacheCheck) *)
                    else
                      (case CacheCheck.ofEntry (e, {start = fn () => UnitBasis.begin (!env, !fixity), name = name, ident = ident,
                                                    text = text (name, mode), mode = mode},
                                                cachePaths (valOf cache)) of
                         CacheCheck.Done form => (UnitCache.Missed "to verify, across a unit that changed", SOME (e, SOME form))
                       | CacheCheck.Refused why =>
                           (UnitCache.Missed ("to verify: its entry holds across a unit that changed and does not load here: " ^ why),
                            NONE))
                | _ => (found, NONE)
            in
              case found of
                UnitCache.Missed why => (Miss why, against)
              | UnitCache.Found (e as {pickle, identity, code, file, others, mid, ...}) =>
                  let val at = UnitBasis.counters ()
                  in
                    (let
                       val (fp, u) = timed "cache-code" (fn () => UnitFile.read code)
                       val () = if fp <> Pipeline.fingerprint () then raise UnitFile.Bad "another instruction set" else ()
                       (* the units it was compiled against that are others
                          now, which its usages held of all the same, by the
                          paths to their names (M6's third part) *)
                       val remap = case cache of
                                     SOME c => UnitBasis.remapping (pickle, u, cachePaths c)
                                   | NONE => []
                       val () = if List.null remap then () else UnitCache.across := true
                       val u = UnitBasis.remapKeys (u, remap)
                       val () = Option.app (fn i => raise UnitBasis.Missing i) (UnitBasis.absent u)
                       (* the schemes of what it names of other units, as its
                          compile had them, against those units now, where it
                          holds by their identities *)
                       val () = if List.null remap then UnitBasis.checkSchemes (#schemes e) else ()
                       val l = timed "cache-basis" (fn () => UnitBasis.loadKnown ({pickle = pickle, sidecar = "", file = name, at = at},
                                                                                   SOME identity, remap))
                       (* its source, and those of the functors' bodies it
                          applied, where they are now, in its code's files *)
                       val u = UnitBasis.relocate (u, file, name, others)
                       (* --whole: its Mid, as the session names it *)
                       val () =
                         if not (!Options.wholeFromUnits) then ()
                         else if mid = "" then raise UnitFile.Bad "no Mid in its entry"
                         else mids := UnitMid.read (mid, #unit l, remap, UnitBasis.movedTo (file, name, others)) :: !mids
                       val () =
                         if quiet then ()
                         else explain ("rune: from the cache " ^ name
                                       ^ String.concat (List.map (fn (i, _, _) => ", across " ^ UnitBasis.nameOf i ^ " changed") remap))
                     in
                       (Hit (l, u, pickle, e), NONE)
                     end)
                    handle UnitMid.Bad why => (UnitBasis.abandon at; (Miss ("a damaged entry: " ^ why), NONE))
                         | Pickle.Bad why => (UnitBasis.abandon at; (Miss ("a damaged entry: " ^ why), NONE))
                         | UnitFile.Bad why => (UnitBasis.abandon at; (Miss ("a damaged entry: " ^ why), NONE))
                         | UnitBasis.Missing u => (UnitBasis.abandon at; (Miss ("its entry names " ^ u), NONE))
                         | UnitBasis.SchemeChanged k =>
                             (UnitBasis.abandon at; (Miss ("its entry had another scheme of " ^ k ^ " than its unit has"), NONE))
                  end
            end
          fun bindHit (l, u, pickle, {warnings, file = was, ...} : UnitCache.entry) =
            ((* the warnings its compile gave, again *)
             if !Options.noWarnings then () else UnitCache.giveWarnings (warnings, was, name);
             env := Env.plus (!env, #delta l);
             fixity := Fixity.extend (!fixity, #directives l);
             UnitBasis.bind l;
             logDeclared l;
             ((u, keptPickle pickle) :: acc, false))
          fun here (why, against) =
            (explain ("rune: compiled " ^ name ^ ": " ^ why
                      ^ (if why = "no entry" andalso isSome otherHash
                         then " (the cache's entries were made by a compiler whose hash differs)" else ""));
             (compileUnit ((name, load, allow, ident, mode), k, against, acc), true))
        in
          case lookup quiet of
            (Hit h, _) => bindHit h
          | (Miss why, against) =>
              if isSome against then here (why, against)
              else
                (case Parallel.missed ident of
                   Parallel.Skip => (acc, false)
                 | Parallel.Run {quiet} => (case lookup quiet of (Hit h, _) => bindHit h | (Miss why, against) => here (why, against))
                 | Parallel.Compile => here (why, against))
        end
      and compileUnit ((name, load, allow, ident, mode), k, against : (UnitCache.entry * CacheCheck.unitForm option) option, acc) =
        let
          val () = CacheCheck.blankEach name
          val start = timed "unit-begin" (fn () => UnitBasis.begin (!env, !fixity))
          (* parsed and elaborated, the names it looks up recorded: its
             usages (UnitCache) *)
          val (decs, names) =
            Usage.record
              (fn () =>
                 let
                   val decs = frontStage "parse" (fn () => parseTokens (load ())) ()
                   (* the warnings of UTS #39 its lexing found (D13) *)
                   val () = Lexer.report name
                 in
                   (* a unit's flexible records are settled at its end, and its
                      matches reported (docs/units.md) *)
                   frontStage "elaborate"
                              (fn () => (Elaborate.allowPrim := allow; lintWanted (); Elaborate.elabTop (env, decs);
                                         Elaborate.finish (); dumpWitnesses (); astlint (); decs))
                              ()
                 end)
          val () = if !keepSyntax then keptSyntax := (name, decs) :: !keptSyntax else ()
          (* after an error, the units are only elaborated, for their errors *)
          val failed = !Error.errors > 0
          val warnings = List.rev (!Error.warnings)
          val () = if failed then () else if !Options.noWarnings then Error.warnings := [] else Error.flushWarnings ()
        in
          if failed then (CacheCheck.blankResult (name, fn () => "error"); failedBefore := true; acc)
          else if !Options.typecheckOnly then
            (* no unit is made, whose basis would say what it declares: the
               signatures and functors of a boundary's exports, from its syntax *)
            let val declared = #declares (Deps.analyse (name, decs))
                fun named kind = List.mapPartial (fn (k, n) => if k = kind then SOME n else NONE) declared
            in CompilerBuildContext.noteNames (buildContext, named Deps.Fun, named Deps.Sig); acc end
          else
            let
              val usages = timed "unit-usages" (fn () => UnitBasis.usagesOf names)
              val {code, exported, loaded} =
                Pipeline.unitThrough {start = start, name = ident, file = name, text = text (name, mode), mode = mode, decs = decs,
                                      delta = !Elaborate.lastDelta, fixity = !fixity, used = names, fresh = false}
              val bytes = timed "unit-chunks" (fn () => String.concat (UnitFile.chunks (Pipeline.fingerprint (), code)))
              (* its code read back, at level 2 *)
              val () = Pass.checkAt ("code-rt", 2) (Pipeline.codeRoundTrip (Pipeline.fingerprint (), bytes)) code
              (* --pass-stats with RUNE_MEM set: the bytes of its basis and
                 its code (issue 14) *)
              val () = if !Pass.stats andalso isSome (OS.Process.getEnv "RUNE_MEM")
                       then TextIO.output (TextIO.stdErr, "unit " ^ name ^ " basis " ^ Int.toString (String.size (#pickle exported))
                                                          ^ " bytes, code " ^ Int.toString (String.size bytes) ^ " bytes\n")
                       else ()
              (* its Mid in bytes, kept in its entry *)
              val midBytes = timed "unit-mid" (fn () => Pipeline.keeping name (fn () =>
                                                 case !Pipeline.lastMid of SOME um => UnitMid.write (exported, um) | NONE => ""))
              val () = Pipeline.lastMid := NONE
              val () = CacheCheck.blankResult (name, fn () => Pickle.hash (String.concat
                         (UnitBasis.basisOf (#pickle exported) :: bytes :: midBytes :: List.map UnitCache.warningBytes warnings)))
              (* the entry verified: its basis the same bytes, and its code,
                 named by the source where it is now; one taken across a
                 unit that changed by what each comes to loaded *)
              val verified =
                case against of
                  NONE => true
                | SOME (e, NONE) => UnitCache.verifies (e, name, #pickle exported, bytes, midBytes)
                | SOME (_, SOME form) =>
                    (case CacheCheck.ofCompile (Pipeline.fingerprint (), bytes, loaded,
                                                {start = fn () => start, name = name, ident = ident, text = text (name, mode), mode = mode}) of
                       CacheCheck.Done form' =>
                         (case CacheCheck.difference (form, form') of
                            NONE => (explain ("rune: " ^ name ^ ": its entry, loaded across a unit that changed, is what compiling it gives");
                                     true)
                          | SOME where' => (explain ("rune: " ^ name ^ ": across a unit that changed its entry differs in " ^ where'); false))
                     | CacheCheck.Refused why => (explain ("rune: " ^ name ^ ": written again it raised " ^ why); false))
            in
              env := Env.plus (#env start, #delta loaded);
              fixity := Fixity.extend (#fixity start, #directives loaded);
              UnitBasis.bind loaded;
              logDeclared loaded;
              (* for --whole, its Mid read back as the session names it, as a
                 unit from the cache is *)
              if !Options.wholeFromUnits then mids := UnitMid.read (midBytes, #unit loaded, [], fn f => f) :: !mids
              else ();
              (case cache of
                 SOME (dir, config) =>
                   UnitCache.storePaths (dir, config, #identity (#unit loaded), UnitBasis.pathsOf (#unit loaded))
               | NONE => ());
              if verified then ()
              else (TextIO.output (TextIO.stdErr, "rune: " ^ name ^ ": the cache's entry is not what compiling it gives\n");
                    unverified := !unverified + 1);
              (* an entry that did not verify is left as it was, to be looked at *)
              (case (cache, k, verified) of
                 (SOME (dir, config), SOME k, true) =>
                   Pipeline.keeping name (fn () =>
                     UnitCache.store (dir, config, k,
                                      {usages = usages, warnings = warnings, file = name,
                                       others = UnitBasis.sourcesOf (code, name), pickle = #pickle exported,
                                       identity = #identity exported, code = bytes, mid = midBytes,
                                       level = UnitCache.level (), schemes = UnitBasis.importedSchemes code}))
               | _ => ());
              (code, keptPickle (#pickle exported)) :: acc
            end
        end
      (* --build: the user's units as the build file says (docs/build.md):
         each compiled in the basis the steps before it leave. A basis is the
         environment, the fixity, the signatures and functors, and the units
         that bound each name (UnitBasis.binders), which the usages of the
         units after it are of *)
      type snapshot=CompilerBuildContext.snapshot
      type delta=CompilerBuildContext.delta
      fun snap ()=CompilerBuildContext.snap buildContext
      fun deltaOf (before',after)=CompilerBuildContext.delta (buildContext,before',after)
      fun apply (before',change,exports)=CompilerBuildContext.apply (buildContext,before',change,exports)
      (* a boundary's exports held to what is inside it; not after an error,
         or in a child of -j, which skips units, where they may be missing *)
      fun checkExports (change, exports) =
        if !failedBefore orelse isSome (!Parallel.child) then ()
        else Option.app (fn message => raise Options.Usage message)
                        (CompilerBuildContext.exportProblem (change, exports))
      val libraryWalk = LibraryScope.walk (env, fixity, UnitBasis.binders, !librariesScoped)
      fun libraries (es,acc) =
        LibraryScope.libraries (libraryWalk, entryGroups es,
                                fn (group,acc) => List.foldl (fn (e,acc) => unit (file (e,inBasis e),acc)) acc group, acc)
      fun finals (es,acc) =
        LibraryScope.finals (libraryWalk, entryGroups es,
                             fn (group,acc) => List.foldl (fn (e,acc) => unit (file (e,!Options.allowPrim),acc)) acc group, acc)
      val implemented : string list ref = ref []
      (* the plan's units, which its steps go through in order *)
      val remaining = ref userPart
      fun nextUnit () =
        case !remaining of
          u :: rest => (remaining := rest; u)
        | [] => raise Fail "a unit that is not among the inputs"
      fun elabSteps (steps : step list, acc) = List.foldl elabStep acc steps
      and elabStep (SUnit (p, anns), acc) =
            let
              val (_, load, given, ident, read) = nextUnit ()
              val allow = given orelse List.exists (fn a => a = "allowPrim") anns
              val quiet = !Options.noWarnings
              val () = if List.exists (fn a => a = "noWarnings") anns then Options.noWarnings := true else ()
              val mode = modeOf anns
              (* its tokens as they were read, but for a file given twice in
                 two modes *)
              val load = if mode = read then load else fn () => loadTokens (mode, p)
              val acc = unit ((p, load, allow, ident, mode), acc)
                        handle e => (Options.noWarnings := quiet; raise e)
            in Options.noWarnings := quiet; acc end
        | elabStep (SLibrary (exports, ds), acc) =
            let
              val b0 = snap ()
              val boundary = CompilerBuildContext.enter buildContext
              val acc = elabSteps (ds, acc)
              val change = deltaOf (b0, snap ())
            in
              checkExports (change, exports);
              CompilerBuildContext.leave (buildContext, boundary, exports);
              apply (b0, change, SOME exports); acc
            end
        | elabStep (SUse (p, ds), acc) =
            if CompilerBuildContext.replay (buildContext, p) then acc
            else
              let
                val b1 = snap ()
                val acc = elabSteps (ds, acc)
              in CompilerBuildContext.record (buildContext, p, deltaOf (b1, snap ()), ds); acc end
        | elabStep (SImplements (x, ds), acc) =
            if List.exists (fn y => y = x) (!implemented)
            then raise Options.Usage ("the build gives the virtual module or functor " ^ x ^ " two implementations")
            else if List.exists (fn (_, n, _) => n = x) (!libraryVirtuals)
            then
              (* a library's files run before the program's: its virtual
                 module is implemented by a library (D22) *)
              let val (kind, _, dir) = valOf (List.find (fn (_, n, _) => n = x) (!libraryVirtuals))
              in raise Options.Usage ("the build implements " ^ x ^ ", the virtual " ^ (if kind = "functor" then "functor" else "module")
                                      ^ " of the library " ^ LibraryIndex.libraryShown (libRoot (), dir)
                                      ^ ", which a library implements, with implements (" ^ kind ^ " " ^ x
                                      ^ ") in its header (docs/build.md, Virtual libraries)") end
            else
              (* what the implementation declares is the program's, and no
                 file after it names it: it is reached through the virtual
                 module, whose units do not change with it *)
              let
                val () = implemented := x :: !implemented
                val b0 = snap ()
                val boundary = CompilerBuildContext.enter buildContext
                val acc = elabSteps (ds, acc)
              in
                CompilerBuildContext.leave (buildContext, boundary, []);
                apply (b0, deltaOf (b0, snap ()), SOME []); acc
              end
      (* -j N: the units before the final ones, each with what it declares
         and uses -- a Basis file's by its MANIFEST, a program's by Deps --
         for Parallel to start children in an order that works *)
      val () =
        if !Options.jobs > 1 andalso isSome cache andalso not (UnitCache.verifying ())
           andalso not (!Options.typecheckOnly)
        then
          let
            val basisUnits =
              ListPair.map (fn (e : entry, (_, _, _, ident, _)) =>
                              (ident, #provides e, List.filter (fn n => not (String.isPrefix "-" n)) (#requires e ()),
                               #when e = Always))
                           (basis, basisPart)
            fun userUnit (name, _, _, ident, mode) =
              let val f = Deps.analyse (name, syntaxOf (mode, name))
              in (ident, List.map #2 (#declares f), List.map #2 (#uses f), not (List.null (#breaks f))) end
              handle _ => (ident, [], [], true)
            val described = Vector.fromList (basisPart @ userPart)
            fun hasEntry i =
              case cache of
                NONE => false
              | SOME (dir, config) =>
                  let
                    val (name, _, allow, ident, mode) = Vector.sub (described, i)
                    val k = UnitCache.key {name = ident, text = text (name, mode) (), allow = allow,
                                           settings = settingsOf (ident, mode)}
                  in
                    UnitCache.hasEntry (dir, config, k)
                    orelse (case frozen of SOME f => UnitCache.hasEntry (f, config, k) | NONE => false)
                  end
            (* a unit worth a child: its text at least RUNE_PARALLEL_MIN
               bytes, 16384 if not set *)
            val least = case Option.mapPartial Int.fromString (OS.Process.getEnv "RUNE_PARALLEL_MIN") of
                          SOME n => n | NONE => 16384
            fun worth i = let val (name, _, _, _, mode) = Vector.sub (described, i) in String.size (text (name, mode) ()) >= least end
          in
            Parallel.start {units = basisUnits @ List.map userUnit userPart, jobs = !Options.jobs, hasEntry = hasEntry,
                            worth = worth, explain = !Options.explainRebuild}
          end
        else ()
      fun programPart compileIt acc = (LibraryScope.program libraryWalk; compileIt acc)
      val compiled =
        List.rev (finals (final,withDefaults (programPart (fn acc => elabSteps (!buildPlan,acc))) (libraries (basis,[]))))
        handle e => (Parallel.finish (); raise e)
      val () = Parallel.finish ()
      val units = List.map #1 compiled
      val () = failIfReported ()
      val () = if !unverified > 0 then raise Reported else ()
      val fingerprint = Pipeline.fingerprint ()
      val () =
        case !Options.emitUnits of
          NONE => ()
        | SOME dir => if !Options.typecheckOnly then () else emitUnitFiles (dir, fingerprint, List.map #1 sources, compiled)
    in
      if !Options.typecheckOnly then OS.Process.success
      else if !Options.wholeFromUnits then
        (* one program of the units' Mid, with the passes of a whole one *)
        let
          val () = refuseDynamic ()
          val prog = Pass.stage {name = "midcanon", showIn = NONE, show = MidText.show, check = fn p => (Pass.checkAt ("midconcat", 1) MidLint.check p; Pipeline.roundTrip "midconcat" p),
                                 size = Mid.size}
                                MidCanon.concat (List.rev (!mids))
          val () = Pass.whole := true
          val low = Pipeline.lowOfMid prog
        in
          if registers then emitProgramAs (RegCodes.fingerprint, inputs, Pipeline.targetStage low)
          else emitProgram (inputs, Pipeline.targetStage low)
        end
      else timed "link" (fn () => linkUnits (fingerprint, inputs, units))
    end

  (* The units linked into the program, by the target of the fingerprint *)
  and linkUnits (fingerprint : int, inputs : string list, units : Link.unitCode list) : OS.Process.status =
    let
      val prog = if fingerprint = RegCodes.fingerprint then (Code.opcodeNames := RegCodes.names;
                                                             Link.program (Regs.program, RegCodes.linked, units))
                 else
                   (* the stack code linked, checked at level 2 as a whole
                      program's is after its stack stage (StackCheck) *)
                   let val p = Link.program (Stack.program, Opcodes.linked, units)
                   in Pipeline.checkStack p; p end
      (* the units' exports, for a unit loaded into the program later,
         where it may load one *)
      val () = Emit.trailer := (if !keepExports then Emit.unitsSection (!Link.lastExports) else "")
      val status = emitProgramAs (fingerprint, inputs, prog) handle e => (Emit.trailer := ""; raise e)
    in Emit.trailer := ""; status end

  (* --emit-units DIR: each unit's file, its number and its source's name,
     and beside it the unit's basis (.rbi, UnitBasis), which a compile after
     it loads (the REPL); DIR/units, their names in order, and DIR/sources,
     their sources. *)
  and emitUnitFiles (dir : string, fingerprint : int, names : string list, units : (Link.unitCode * string) list) : unit =
    let
      val () = (OS.FileSys.mkDir dir handle OS.SysErr _ => ())
      fun base n = OS.Path.base (OS.Path.file n)
      val files =
        ListPair.map (fn ((n, (u, pickle)), i) =>
                        let
                          val stem = OS.Path.joinDirFile {dir = dir, file = StringCvt.padLeft #"0" 4 (Int.toString i) ^ "-" ^ base n}
                          val f = stem ^ ".rbu"
                          val out = BinIO.openOut (stem ^ ".rbi")
                        in
                          UnitFile.write (f, fingerprint, u);
                          BinIO.output (out, Byte.stringToBytes pickle); BinIO.closeOut out;
                          f
                        end)
                     (ListPair.zip (names, units), List.tabulate (List.length units, fn i => i))
      fun write (file, lines) =
        let val out = BinIO.openOut (OS.Path.joinDirFile {dir = dir, file = file})
        in List.app (fn l => BinIO.output (out, Byte.stringToBytes (l ^ "\n"))) lines; BinIO.closeOut out end
    in
      (* the units' files in order, and the source of each, as named here *)
      write ("units", files);
      write ("sources", names)
    end

  (* rune -o P.rbc A.rbu B.rbu ...: unit files linked, each after those it
     names *)
  and linkUnitFiles (inputs : string list) : OS.Process.status =
    let
      val read = List.map (fn f => UnitFile.readFile f handle UnitFile.Bad why => raise Options.Usage why
                                                        | IO.Io _ => raise Options.Usage ("cannot read " ^ f)) inputs
      val (fingerprint, _) = List.hd read
      val () =
        if List.all (fn (fp, _) => fp = fingerprint) read then ()
        else raise Options.Usage "the units are of different instruction sets"
      (* each unit names only units before it *)
      val () =
        ignore (List.foldl (fn ((_, u : Link.unitCode), seen) =>
                              let
                                fun known ({unit, ...} : Link.key) = unit = "" orelse unit = #identity u
                                                                     orelse StringMap.member (seen, unit)
                              in
                                if List.all (known o #1) (#globals u) andalso List.all (known o #2) (#imports u)
                                then StringMap.insert (seen, #identity u, ())
                                else raise Options.Usage ("the unit " ^ #identity u ^ " names a unit not linked before it")
                              end) StringMap.empty read)
      (* a program that loads units keeps their exports, as compileUnits
         says, the same bytes that a compile in units gives *)
      fun unitOf file = List.find (fn (_, u : Link.unitCode) => String.isPrefix (file ^ "@") (#identity u)) read
      val () =
        keepExports :=
          (isSome (unitOf BasisManifest.dynamicFile)
           orelse (case unitOf BasisManifest.runtimeFile of
                     NONE => false
                   | SOME (_, runtime) =>
                       let val keys = Link.functionKeys (runtime, BasisManifest.loadingFunctions)
                       in List.exists (fn (_, u : Link.unitCode) => #identity u <> #identity runtime andalso Link.namesKey (u, keys)) read end))
    in
      linkUnits (fingerprint, inputs, List.map #2 read)
    end

  and frontEnd (basis : entry list, final : entry list, userToks, _ : string list) : Lambda.lexp option =
    let
      fun parseEntries es = List.concat (List.map (fn e : entry => parseTokens (loadTokens (Source.Ascii, BasisManifest.path e))) es)
      val syntaxGroups : (entry list * Ast.program) list ref = ref []
      val finalSyntax : (entry list * Ast.program) list ref = ref []
      (* the syntax of each library, in its scope's fixity; no environment
         changes while they are read *)
      val parsing = LibraryScope.walk (ref Env.initial, fixity, ref StringMap.empty, !librariesScoped)
      fun parsed (es,acc) = (es,parseEntries es) :: acc
      (* The front end's two stages, for --pass-stats; their size is the
         number of top-level declarations. *)
      fun frontStage name f =
        Pass.stage {name = name, showIn = NONE, show = fn _ => "", check = fn _ => (),
                    size = fn (b, l, u, fin) => List.length b + List.length l + List.length u + List.length fin}
                   f
      (* the basis library may use _prim; the libraries beside it may not *)
      val (basisProg, libraryProg, userProg, finalProg) =
        frontStage "parse"
                   (fn () => let
                               val groups = List.rev (LibraryScope.libraries (parsing,entryGroups basis,parsed,[]))
                               val () = syntaxGroups := groups
                               fun part keep = List.concat (List.map #2 (List.filter (fn (es,_) => keep (inBasis (hd es))) groups))
                               val b = part (fn inside => inside)
                               val l = part not
                               val () = LibraryScope.program parsing
                               val u = List.concat (List.map parseTokens userToks)
                               val finals = List.rev (LibraryScope.finals (parsing,entryGroups final,parsed,[]))
                               val () = finalSyntax := finals
                             in (b,l,u,List.concat (List.map #2 finals)) end)
                   ()
      val preludeProg = basisProg @ libraryProg
      (* the warnings of UTS #39 the inputs' lexing found (D13) *)
      val () = List.app Lexer.report (!Options.inputs)
      val () = if !Options.dumpAst then List.app (fn d => println (Ast.decToString d)) (userProg @ finalProg) else ()
      val env = ref (Env.initialNow ())
      val elaborating = LibraryScope.walk (env, fixity, ref StringMap.empty, !librariesScoped)
      fun elabLibrary (es : entry list,ds) =
        (Elaborate.allowPrim := inBasis (hd es);
         LibraryScope.group (elaborating,es,fn () => Elaborate.elabTop (env,ds)))
      fun elabFinal (es : entry list,ds) =
        LibraryScope.final (elaborating,es,fn () => Elaborate.elabTop (env,ds))
      fun elaborate (progs as (b, l, u, fin)) =
        (lintWanted ();
         List.app elabLibrary (!syntaxGroups);
         Elaborate.allowPrim := !Options.allowPrim;
         (* --default-type holds for the input files, not for the libraries *)
         Elaborate.intDefault := (if !Options.defaultInt64 then Types.int64Ty else Types.intTy);
         Elaborate.wordDefault := (if !Options.defaultWord64 then Types.word64Ty else Types.wordTy);
         LibraryScope.program elaborating;
         Elaborate.elabTop (env, u);
         Elaborate.intDefault := Types.intTy;
         Elaborate.wordDefault := Types.wordTy;
         List.app elabFinal (!finalSyntax);
         Elaborate.finish ();
         dumpWitnesses ();
         astlint ();
         progs)
      val () = Elaborate.recover := true
      val _ = frontStage "elaborate" elaborate (basisProg, libraryProg, userProg, finalProg)
      val () = failIfReported ()
      val () = if !Options.noWarnings then Error.warnings := [] else Error.flushWarnings ()
    in
      if !Options.typecheckOnly then NONE
      else
        SOME (Pass.stage {name = "translate", showIn = NONE, show = Lambda.show, check = Pass.checkAt ("translate", 1) LambdaLint.check,
                          size = Lambda.size}
                         (fn decs => Fault.lambda ("translate", Translate.transProgram decs)) (preludeProg @ userProg @ finalProg))
    end

  (* -O0 is the same stages with no optional pass *)
  and backEnd (_, NONE) = OS.Process.success
    | backEnd (inputs, SOME lam) =
        let val () = refuseDynamic ()
            val low = Pipeline.lowOf lam
        in
          if !Options.target = "registers" then
            (Code.opcodeNames := RegCodes.names;
             emitProgramAs (RegCodes.fingerprint, inputs, Pipeline.targetStage low))
          else emitProgram (inputs, Pipeline.targetStage low)
        end

  (* A whole program has no units for a dynamic module to link against:
     its units are one (docs/units.md, Dynamic modules) *)
  and refuseDynamic () =
    case !Elaborate.dynamicAt of
      SOME sp => raise Error.CompileError (sp, "a program that loads a dynamic module (_dynamic) is built in units "
                                                ^ "(rune --units), which the module links against, and not whole")
    | NONE => ()

  and emitProgram (inputs : string list, prog : Code.program) : OS.Process.status =
    emitProgramAs (Opcodes.fingerprint, inputs, prog)

  and emitProgramAs (fingerprint : int, inputs : string list, prog : Code.program) : OS.Process.status =
    let
      val out = case !Options.output of SOME f => f | NONE => defaultOutput (List.hd inputs)
      fun absolute p = OS.Path.mkCanonical (OS.Path.mkAbsolute {path = p, relativeTo = OS.FileSys.getDir ()})
      fun idOf p = SOME (OS.FileSys.fileId p) handle OS.SysErr _ => NONE
      (* a file id names a file only where it tells the output from its
         directory: MLton under MinGW gives every file of a drive one *)
      val outId = idOf out
      val ids = isSome outId andalso outId <> idOf (OS.Path.dir (absolute out))
      fun same p = absolute p = absolute out orelse (ids andalso idOf p = outId)
      val () = if List.exists same inputs then raise Options.Usage "output must differ from every input file" else ()
    in
      Pass.stage {name = "emit", showIn = NONE, show = fn _ => "", check = fn _ => (), size = fn () => Code.size prog}
                 Emit.writeFileAs (fingerprint, out, prog);
      OS.Process.success
    end

  (* A breach that a check at a boundary found, at level 1, names where it
     was found; the compile is then made again at level 2, from the state
     the options left (CompilerState's baseline, sealed before the first),
     to name the pass that made it: a compile is deterministic, and no check
     changes it (docs/ir.md, Levels). Units the first compile stored in the
     cache are taken from there, linted as they were; a breach in a child
     of -j is not made again. At level 0 the seal would cost a small
     compile a seventh (300,000 instructions, budgets compile-hello and
     compile-expo), so a breach of a check that is always on says to
     compile at --lint=2 instead (Pass.checkAt). *)
  fun diagnosed (compile : unit -> OS.Process.status) : OS.Process.status =
    let val level = Pass.lintLevel ()
    in
      if level <> 1 then compile ()
      else
        (CompilerState.seal ();
         compile ()
         handle Error.Bug msg =>
           case !Pass.breach of
             NONE => raise Error.Bug msg
           | SOME (key, _) =>
               let
                 val () = eprintln ("rune: " ^ msg)
                 val () = eprintln ("rune: found at --lint=" ^ Int.toString level ^ ", after " ^ key
                                    ^ "; compiling again at --lint=2 to find the pass that made it")
                 val again = CompilerState.session ()
               in
                 (CompilerState.withSession (again, fn () => (Pass.lintGiven := SOME 2; Pass.breach := NONE; compile ()));
                  eprintln "rune: the compile at --lint=2 found no breach";
                  OS.Process.failure)
                 handle Error.Bug msg => (eprintln ("rune: " ^ msg); OS.Process.failure)
               end)
    end

  (* A program found to load units only once a unit was taken across a unit
     that changed (LoadsUnits): that unit's identity in the program would not
     be a build from source's, which a unit loaded into it names. It is
     compiled again, as what it is, from the state sealed before the first
     unit. A warning the first compile gave is given again: an alias of
     Runtime that loads is rare, and an entry taken across a change rarer. *)
  fun compiledAgain () : OS.Process.status =
    compile ()
    handle LoadsUnits name =>
      let
        val () = if !Options.explainRebuild
                 then eprintln ("rune: " ^ name ^ " loads units, which a unit taken from the cache across a unit that "
                                ^ "changed does not allow: compiling again")
                 else ()
        val () = knownToLoad := true
        val again = CompilerState.session ()
        val diagnostics = ref []
        val status = CompilerState.withSession (again, fn () =>
                       (compile () before diagnostics := !Diagnostic.collected)
                       handle e => (diagnostics := !Diagnostic.collected; raise e))
      in Diagnostic.collected := !diagnostics; status end

  fun main (name : string, args : string list) : OS.Process.status =
    let val status = main' (name, args)
    in UnitBasis.hashStats (); Pass.finish (); Diagnostic.finish (OS.Process.isSuccess status); status end

  and main' (_ : string, args : string list) : OS.Process.status =
    (CacheCheck.seal ();
     Options.parse args;
     Options.settle ();
     Pass.startup ();
     Parser.orPatterns := !Options.orPatterns;
     Diagnostic.install {color = !Options.color, full = !Options.diagnostics, json = !Options.diagnosticsJson};
     if !Options.showHelp then (print Options.usage; OS.Process.success)
     else if !Options.showVersion then (println ("rune " ^ Config.version); OS.Process.success)
     else if !Options.basisCheck then checkManifest ()
     else if !Options.deps orelse !Options.depsDot orelse !Options.depsUses then depsCommand ()
     else if isSome (!Options.indexLibrary) then indexCommand (valOf (!Options.indexLibrary))
     else if !Options.plan then planCommand ()
     else if !Options.buildList then buildList ()
     else if !Options.lexCount > 0 then lexCount ()
     else if !Options.dumpTokens then dumpTokens ()
     else if isSome (!Options.readMid) then diagnosed (fn () => readMid (valOf (!Options.readMid)))
     else diagnosed compiledAgain)
    handle BasisManifest.Usage msg => (eprintln ("rune: " ^ msg); eprintln "try 'rune --help'"; OS.Process.failure)
         | Options.Usage msg => (eprintln ("rune: " ^ msg); eprintln "try 'rune --help'"; OS.Process.failure)
         (* units whose interfaces do not fit at the link, which unit files
            from other compiles can be (Link.Mismatch) *)
         | Link.Mismatch msg => (eprintln ("rune: the units do not fit together: " ^ msg); OS.Process.failure)
         | Error.CompileError (sp, msg) => (eprintln (!Error.show ("error", sp, msg)); Error.note ("error", sp, msg); OS.Process.failure)
         | Reported => OS.Process.failure
         | Steps.Refused msg => (eprintln ("rune: " ^ msg); OS.Process.failure)
         | Error.Bug msg => (eprintln ("rune: " ^ msg); OS.Process.failure)
         | IO.Io {name, ...} => (eprintln ("rune: I/O error on " ^ name); OS.Process.failure)
end

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
  val namesOf = BasisManifest.namesOf
  val providers = BasisManifest.providers
  val select = BasisManifest.select
  fun readManifest () = BasisManifest.readManifest (libDir ())

  (* The libraries of --library and those they are written on, in the order
     they are compiled, with the entries of each. *)
  fun libraryManifests () : (string * entry list) list =
    List.map (fn d => (d, BasisManifest.readManifest d))
             (BasisManifest.libraries (libRoot (), !Options.libraries)
              handle BasisManifest.Usage why => raise Options.Usage why)

  fun inBasis (e : entry) : bool = #dir e = libDir ()

  (* Manifest entries are already ordered by library dependency. Preserve
     contiguous library groups so their private bases can be hidden. *)
  fun entryGroups (entries : entry list) : entry list list =
    let
      fun take (_,[],acc) = (List.rev acc,[])
        | take (dir,e :: rest,acc) =
            if #dir (e : entry) = dir then take (dir,rest,e :: acc) else (List.rev acc,e :: rest)
      fun groups [] = []
        | groups (e :: rest) =
            let val (group,rest) = take (#dir e,rest,[e]) in group :: groups rest end
    in groups entries end

  fun exportsOf entries =
    Option.map (List.map (fn (kind,n) =>
      ((case kind of "structure" => BuildFile.Str | "signature" => BuildFile.Sig
                   | "functor" => BuildFile.Fun | "type" => BuildFile.Ty
                   | _ => raise Options.Usage ("unknown library export kind: " ^ kind)),n)))
      (BasisManifest.scopeOf entries)

  fun defaultOutput (first : string) : string =
    let
      val base = if String.isSuffix ".sml" first then String.substring (first, 0, String.size first - 4) else first
    in base ^ ".rbc" end

  val fixity : Fixity.env ref = ref Fixity.initial

  (* A compile that reported its errors as it found them (Error.report),
     and so fails once the front end is done *)
  exception Reported
  fun failIfReported () = if !Error.errors > 0 then raise Reported else ()

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
         one of another library against it and all that comes before it. *)
      fun check provider (e : entry, earlier : names) : names =
        let
          val toks = loadTokens (Source.Ascii, BasisManifest.path e)
          val (prog, fx) = Parser.parseTokensWith (toks, !fixity)
          val () = fixity := fx
          val declared =
            List.concat (List.map (fn Ast.DStructure (binds, _) => List.map #name binds
                                    | Ast.DSignature (binds, _) => List.map #name binds
                                    | Ast.DFunctor (binds, _) => List.map #name binds
                                    | Ast.DType (binds, _) => List.map #name binds
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
            else List.app (fn Ast.DStructure _ => () | Ast.DSignature _ => () | Ast.DFunctor _ => ()
                            | Ast.DType _ => () | Ast.DOverload _ => ()
                            | d => complain (e, "a demand file may declare modules and types only, but has: " ^
                                                String.substring (Ast.decToString d ^ "                    ", 0, 20)))
                          prog
        in List.foldl (fn (n, m) => StringMap.insert (m, n, ())) earlier (#provides e) end
      val earlier = List.foldl (check (providers basisEntries)) StringMap.empty basisEntries
      val all = basisEntries @ List.concat (List.map #2 libs)
      fun library ((dir,es),earlier) =
        let val incoming = !fixity
            val raw = List.foldl (check (providers all)) earlier es
        in case BasisManifest.scopeOf es of
             NONE => raw
           | SOME exports =>
               (List.app (fn (kind,name) =>
                  if StringMap.member (!declaredKinds,declarationKey (dir,kind,name)) then ()
                  else (eprintln ("rune: " ^ dir ^ "/MANIFEST: exports " ^ kind ^ " " ^ name ^
                                  ", which no source before the program declares");ok := false)) exports;
                fixity := incoming;
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

  (* ---- the graph (Deps; the incremental roadmap's M8) ---- *)

  (* a file's syntax, for the names it declares and uses: the fixity of the
     initial basis, as a file of a group's has no other (D15) *)
  fun syntaxOf (mode : Source.mode, path : string) : Ast.program =
    #1 (Parser.parseTokensWith (loadTokens (mode, path), Fixity.initial))

  (* where a file breaks the discipline, as errors *)
  fun breaksOf (f : Deps.file) : string list =
    List.map (fn (sp, what) => Error.format (sp, "a file of a group declares modules and type abbreviations only, and this is " ^ what))
             (#breaks f)

  (* --deps, --deps-dot: the inputs in an order the modules they declare and
     use give, or as the graph *)
  fun depsCommand () : OS.Process.status =
    if !Options.depsUses then
      (* the names, whatever they are of: what a MANIFEST's requires
         column is made of (scripts/gen-basis-sigs.sh) *)
      let
        val names = List.foldl (fn (p, m) => List.foldl (fn ((_, n), m) => StringMap.insert (m, n, ())) m
                                                        (#uses (Deps.analyse (p, syntaxOf (inputMode p, p)))))
                               StringMap.empty (!Options.inputs)
      in List.app println (StringMap.listKeys names); OS.Process.success end
    else
    let
      val files = List.map (fn p => Deps.analyse (p, syntaxOf (inputMode p, p))) (!Options.inputs)
      val broken = List.concat (List.map breaksOf files)
    in
      if not (List.null broken) then (List.app eprintln broken; OS.Process.failure)
      else
        (let val (ordered, edges) = Deps.order files
         in
           if !Options.depsDot then print (Deps.dot edges) else List.app (fn (f : Deps.file) => println (#path f)) ordered;
           OS.Process.success
         end)
        handle Deps.Graph msg => (eprintln ("rune: " ^ msg); OS.Process.failure)
    end

  (* -I DIR: the one input an entry point, and before it the files of its
     directory and of each DIR that it needs, in the graph's order. A file
     that breaks the discipline cannot be ordered, and is none of them *)
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
                    then eprintln ("rune: " ^ #path f ^ " declares a module " ^ main ^ " names, and breaks the discipline: "
                                   ^ hd (breaksOf f))
                    else ())
                 broken
    in
      List.map #path (Deps.closure (group, #uses program)) @ [main]
      handle Deps.Graph msg => raise Options.Usage msg
    end

  (* ---- build files (docs/build.md; the incremental roadmap's M10) ---- *)

  (* What a build file says, as the units driver follows it: a unit -- a
     file, with the annotations in force -- or a scope of units whose basis
     the build file says (compileUnits, elabSteps) *)
  datatype step = datatype CompilerProject.step

  val buildPlan : step list option ref = ref NONE

  fun readText (f : string) : string =
    let val i = TextIO.openIn f in TextIO.inputAll i before TextIO.closeIn i end

  (* A build file read: its paths made the files' (relative to its
     directory, the variables given), each build file it uses read in its
     place, each group put in the order its files' modules give (Deps), the
     annotations given to each unit; and the cache directories it names *)
  fun projectOf (file : string) : CompilerProject.plan =
    let
      val windows=List.exists (fn (key,value) => key="sysname" andalso value="Windows")
                    (Posix.ProcEnv.uname ()) handle OS.SysErr _ => false
      fun read path =
        let val text=readText path handle IO.Io _ => raise CompilerProject.Invalid ("cannot read the build file " ^ path)
        in {text=text,revision=Pickle.hash text} end
      val plan=CompilerProject.plan {file=file,defaultMode= !Options.sourceMode,windows=windows,readBuild=read,syntax=syntaxOf}
        handle CompilerProject.Invalid message => raise Options.Usage message
    in plan end
  fun planOf file = let val plan=projectOf file in (#steps plan,#caches plan) end

  (* --basis-index DIR: DIR/MANIFEST, what each file of the library provides
     and requires (BasisManifest), from its build file DIR/library.build --
     each file's class and host by its annotations ("always", "demand",
     "seal", "final"; "host=swap", "host=no"), the libraries it is written
     on by `libraries` -- and from the files: what each declares (Deps), and
     what it uses that the files before it, the Basis Library or the
     libraries it is written on provide. A file that uses a name only a file
     after it provides is refused. *)
  fun basisIndex (dir : string) : OS.Process.status =
    let
      val file = OS.Path.joinDirFile {dir = dir, file = "library.build"}
      val text = readText file handle IO.Io _ => raise Options.Usage ("cannot read the build file " ^ file)
      val decs = BuildFile.parse (file, text) handle BuildFile.Error m => raise Options.Usage m
      val libs : string list ref = ref []
      val used = ref [] : string list ref
      val boundary = ref NONE : (BuildFile.kind * string) list option ref
      fun relative (base, p) = OS.Path.mkCanonical (OS.Path.concat (base, p))
      fun entries (base, stack, anns, inside, ds) = List.concat (List.map (fn d => entry (base, stack, anns, inside, d)) ds)
      and entry (base, stack, anns, inside, d) =
        case d of
          BuildFile.File p => [(relative (base, p), anns, inside)]
        | BuildFile.Files ps => List.map (fn p => (relative (base, p), anns, inside)) ps
        | BuildFile.Annotate (a, ds) => entries (base, stack, anns @ a, inside, ds)
        | BuildFile.Use p =>
            let val path = relative (base, p)
                val () = if List.exists (fn q => q = path) stack then raise Options.Usage (file ^ ": cyclic use of " ^ path) else ()
            in if List.exists (fn q => q = path) (!used) then []
               else let val () = used := path :: !used
                        val source = readText (OS.Path.concat (dir, path))
                          handle IO.Io _ => raise Options.Usage (file ^ ": cannot read " ^ path)
                        val included = BuildFile.parse (path, source) handle BuildFile.Error m => raise Options.Usage m
                    in entries (OS.Path.dir path, path :: stack, anns, inside, included) end end
        | BuildFile.Library (es, ds) =>
            if inside orelse isSome (!boundary) then raise Options.Usage (file ^ ": a library has one outer export boundary")
            else (boundary := SOME es; entries (base, stack, anns, true, ds))
        | BuildFile.Libraries ns => (libs := !libs @ ns; [])
        | _ => raise Options.Usage (file ^ ": a library's build file lists its files, annotated; no more")
      val raw = entries (".", ["library.build"], [], false, decs)
      val () = if isSome (!boundary) andalso List.exists (fn (_,_,inside) => not inside) raw
               then raise Options.Usage (file ^ ": all source files belong inside the library export boundary") else ()
      val listed = List.map (fn (p,anns,_) => (p,anns)) raw
      fun kindName k = case k of BuildFile.Str => "structure" | BuildFile.Sig => "signature"
                              | BuildFile.Fun => "functor" | BuildFile.Ty => "type"
      val exports = Option.map (List.map (fn (k,n) => (kindName k,n))) (!boundary)
      fun classOf anns =
        case List.filter (fn a => List.exists (fn c => c = a) ["always", "demand", "seal", "final"]) anns of
          [] => "demand" | cs => List.last cs
      fun hostOf anns =
        case List.filter (fn a => String.isPrefix "host=" a) anns of
          [] => "yes" | hs => String.extract (List.last hs, 5, NONE)
      (* a file may be in a directory below the library's: sized/int32.sml *)
      val analysed = List.map (fn (p, anns) => (p, anns, Deps.analyse (p, syntaxOf (Source.Ascii, OS.Path.concat (dir, p)))))
                              listed
      (* what the Basis Library and the libraries this one is written on
         provide, from their MANIFESTs, made before this one's *)
      val outside =
        if OS.Path.mkCanonical dir = OS.Path.mkCanonical (libRoot () ^ "/basis") then []
        else readManifest () @ List.concat (List.map BasisManifest.readManifest
                                                    (BasisManifest.libraries (libRoot (), !libs)))
      val provided = List.foldl (fn (e : entry, m) => List.foldl (fn (n, m) => StringMap.insert (m, n, ())) m (BasisManifest.public e))
                                StringMap.empty outside
      fun sorted l = StringMap.listKeys (List.foldl (fn (n, m) => StringMap.insert (m, n, ())) StringMap.empty l)
      val providers = List.foldl (fn ((_, _, f : Deps.file), m) => List.foldl (fn ((_, n), m) => StringMap.insert (m, n, ())) m
                                                                               (#declares f))
                                 provided analysed
      val declared = List.concat (List.map (fn (_,_,f : Deps.file) =>
        List.map (fn (k,n) => (Deps.kindName k,n)) (#declares f))
        (List.filter (fn (_,anns,_) => classOf anns <> "final") analysed))
      val () = Option.app (List.app (fn exported as (k,n) =>
        if List.exists (fn declared => exported=declared) declared then ()
        else raise Options.Usage (file ^ ": exports " ^ k ^ " " ^ n ^ ", which no source declares"))) exports
      val scopeColumn = case exports of NONE => "" | SOME [] => " | -"
        | SOME es => " | " ^ String.concatWith " " (List.map (fn (k,n) => k ^ ":" ^ n) es)
      val (lines, _) =
        List.foldl
          (fn ((p, anns, f : Deps.file), (acc, earlier)) =>
             let
               val provides = List.map #2 (#declares f)
               val requires = sorted (List.filter (fn n => StringMap.member (providers, n) andalso
                                                           not (List.exists (fn m => m = n) provides))
                                                  (List.map #2 (#uses f)))
               val () = List.app (fn n => if StringMap.member (earlier, n) then ()
                                          else raise Options.Usage (file ^ ": " ^ p ^ " uses " ^ n ^
                                                                    ", which only a file after it provides"))
                                 requires
               val line = p ^ " | " ^ classOf anns ^ " | " ^ hostOf anns ^ " | " ^ String.concatWith " " provides ^ " | "
                          ^ String.concatWith " " requires ^ scopeColumn
             in (line :: acc, List.foldl (fn (n, m) => StringMap.insert (m, n, ())) earlier provides) end)
          ([], provided) analysed
      val out = OS.Path.joinDirFile {dir = dir, file = "MANIFEST"}
      (* in bytes, so that every host writes the same file (Emit.writeFileAs) *)
      val o' = BinIO.openOut out
      fun put s = BinIO.output (o', Byte.stringToBytes s)
    in
      put "# Generated from library.build by rune --basis-index -- do not edit.\n";
      List.app (fn l => put ("# library: " ^ l ^ "\n")) (!libs);
      List.app (fn l => put (l ^ "\n")) (List.rev lines);
      BinIO.closeOut o';
      OS.Process.success
    end

  (* the files of a plan, in the order they are compiled, with their
     annotations *)
  val unitsOf = CompilerProject.units
  val filesOf = CompilerProject.files

  fun compile () : OS.Process.status =
    let
      (* --build: the inputs are the build file's files, its plan what the
         units driver follows *)
      val () =
        case !Options.build of
          NONE => ()
        | SOME f =>
            let val project=projectOf f
                val plan= #steps project
                val caches= #caches project
                val ()=Options.libraries:=List.foldl (fn (library,all) =>
                  if List.exists (fn present => present=library) all then all else all @ [library])
                  (!Options.libraries) (#libraries project)
            in
              buildPlan := SOME plan;
              Options.inputs := filesOf plan;
              buildModes := List.foldl (fn ((p, anns), m) => if StringMap.member (m, p) then m
                                                             else StringMap.insert (m, p, modeOf anns))
                                       StringMap.empty (unitsOf plan);
              case (caches, !Options.cacheDir) of
                (c :: _, NONE) => Options.cacheDir := SOME c
              | _ => ()
            end
      (* a whole program's dynamic modules: none (UnitBasis.wholeFingerprints) *)
      val () = UnitBasis.wholeFingerprints := (not (!Options.units) orelse !Options.wholeFromUnits)
      (* -I: the entry point's files before it *)
      val () =
        case (!Options.includeDirs, !Options.inputs) of
          ([], _) => ()
        | (_, [main]) => Options.inputs := entryFiles main
        | _ => raise Options.Usage "-I wants one input, the entry point"
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
      val () = if !Options.noPrelude andalso not (List.null (!Options.libraries))
               then raise Options.Usage "--library needs the basis library (not --no-prelude)" else ()
      val basis =
        Pass.stage {name = "select", showIn = NONE, show = fn _ => "", check = fn _ => (), size = List.length}
                   (fn () =>
        if !Options.noPrelude then []
        else
          let
            val entries = readManifest () @ List.concat (List.map #2 (libraryManifests ()))
            val mentioned = List.foldl namesOf StringMap.empty userToks
            (* A library beside the basis library sees the basis library as a
               program does, through its seals: what the chosen files of the
               libraries name counts as mentioned, and the choice is made
               again with it. *)
            val chosenLibrary = List.filter (not o inBasis) (select (entries, mentioned))
            val mentioned =
              List.foldl (fn (e, m) => namesOf (loadTokens (Source.Ascii, BasisManifest.path e), m)) mentioned chosenLibrary
          in
            if !Options.basisAll then entries
            else select (entries, mentioned)
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
      val () = MidLint.importedScheme := (fn g => SOME (ToMid.globalScheme g) handle Error.Bug _ => NONE)
      val registers = !Options.target = "registers"
      val () = if registers then Code.opcodeNames := RegCodes.names else ()
      val env = ref Env.initial
      val () = UnitBasis.startSession ()
      (* each unit's source, its tokens when wanted, whether it may use
         _prim -- the basis library may, the libraries beside it may not --
         and its name: a library's file by where it is in the library, so
         that a cache follows the library where it is moved (UnitCache) *)
      fun libName (e : entry) : string =
        let val root = libRoot () ^ "/"
        in
          if String.isPrefix root (#dir e) then "lib/" ^ String.extract (#dir e, String.size root, NONE) ^ "/" ^ #file e
          else BasisManifest.path e
        end
      fun file (e : entry, allow) =
        (BasisManifest.path e, fn () => loadTokens (Source.Ascii, BasisManifest.path e), allow, libName e, Source.Ascii)
      val basisPart = List.map (fn e => file (e, inBasis e)) basis
      val userPart = ListPair.map (fn (toks, name) => (name, fn () => toks, !Options.allowPrim, name, inputMode name))
                                  (userToks, inputs)
      val finalPart = List.map (fn e => file (e, !Options.allowPrim)) final
      val sources = basisPart @ userPart @ finalPart
      (* the signatures and functors the units declared, newest first: what a
         scope of a build file added (elabSteps) *)
      val declLog : (string * string) list ref = ref []
      fun logDeclared (l : UnitBasis.result) =
        declLog := List.map (fn n => ("fun", n)) (#funs l) @ List.map (fn n => ("sig", n)) (#sigs l) @ !declLog
      (* a program that may load units while it runs -- it has Runtime's
         loading or a dynamic module's: their files are among its units --
         keeps in its file what its units export, under the identities a
         build from source gives them, which a unit loaded into it names: so
         it takes no unit from the cache across a unit that changed
         (UnitBasis.remapAllowed; docs/units.md, Dynamic modules) *)
      val loadsUnits = List.exists (fn (_, _, _, ident, _) => ident = "lib/basis/runtime.sml" orelse ident = "lib/basis/dynamic.sml")
                                   sources
      val () = UnitBasis.remapAllowed := not loadsUnits
      val () = keepExports := loadsUnits
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
      val userNames = List.foldl (fn (n, m) => StringMap.insert (m, n, ())) StringMap.empty inputs
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
      fun unit (src as (name, _, _, _, _), acc) =
        case Parallel.at name of
          Parallel.Skip => acc
        | Parallel.Run {quiet} => timedUnit (src, acc, quiet)
        | Parallel.Compile => timedUnit (src, acc, false)
      (* --pass-stats: what each unit took, start to end *)
      and timedUnit (src as (name, _, _, _, _), acc, quiet) =
        let
          val t0 = Time.now ()
          val (acc, compiledIt) = unitHere (src, acc, quiet)
          val () = if !Pass.stats
                   then TextIO.output (TextIO.stdErr, "unit " ^ name ^ " took "
                                                      ^ Real.fmt (StringCvt.FIX (SOME 3)) (Time.toReal (Time.- (Time.now (), t0)))
                                                      ^ " s" ^ (if compiledIt then "" else ", from the cache")
                                                      ^ (if isSome (OS.Process.getEnv "RUNE_MEM")
                                                         then ", live " ^ Int.toString (!Pass.liveBytes ()) else "")
                                                      ^ "\n")
                   else ()
        in Parallel.after (name, compiledIt); acc end
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
          fun lookup quiet : looked * UnitCache.entry option =
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
                  UnitCache.Found (e as {usages, ...}) =>
                    if not (UnitCache.verifying ()) then (found, NONE)
                    else if UnitBasis.exact usages then (UnitCache.Missed "to verify its entry", SOME e)
                    (* one taken across a unit that changed names the old
                       unit, and is compiled again rather than compared
                       (issue 15) *)
                    else (UnitCache.Missed "to verify: its entry holds across a unit that changed, and is compiled again", NONE)
                | _ => (found, NONE)
            in
              case found of
                UnitCache.Missed why => (Miss why, against)
              | UnitCache.Found (e as {pickle, code, file, others, mid, ...}) =>
                  let val at = UnitBasis.counters ()
                  in
                    (let
                       val (fp, u) = timed "cache-code" (fn () => UnitFile.read code)
                       val () = if fp <> Pipeline.fingerprint () then raise UnitFile.Bad "another instruction set" else ()
                       (* the units it was compiled against that are others
                          now, which its usages held of all the same, by the
                          paths to their names (M6's third part) *)
                       val remap = case cache of
                                     SOME (dir, config) =>
                                       UnitBasis.remapping (pickle, u, UnitCache.pathsIn (dir :: (case frozen of SOME f => [f] | NONE => []),
                                                                                       config))
                                   | NONE => []
                       val u = UnitBasis.remapKeys (u, remap)
                       val () = Option.app (fn i => raise UnitBasis.Missing i) (UnitBasis.absent u)
                       val l = timed "cache-basis" (fn () => UnitBasis.loadAgainst ({pickle = pickle, file = name, at = at,
                                                                                      env = !env, fixity = !fixity,
                                                                                      text = text (name, mode)}, remap))
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
                  end
            end
          fun bindHit (l, u, pickle, {warnings, ...} : UnitCache.entry) =
            ((* the warnings its compile gave, again *)
             if !Options.noWarnings then ()
             else List.app (fn w => TextIO.output (TextIO.stdErr, Diagnostic.showCached w ^ "\n")) warnings;
             env := Env.plus (!env, #delta l);
             fixity := Fixity.extend (!fixity, #directives l);
             UnitBasis.bind l;
             logDeclared l;
             ((u, keptPickle pickle) :: acc, false))
          fun here (why, against) =
            (explain ("rune: compiled " ^ name ^ ": " ^ why);
             (compileUnit ((name, load, allow, ident, mode), k, against, acc), true))
        in
          case lookup quiet of
            (Hit h, _) => bindHit h
          | (Miss why, against) =>
              if isSome against then here (why, against)
              else
                (case Parallel.missed name of
                   Parallel.Skip => (acc, false)
                 | Parallel.Run {quiet} => (case lookup quiet of (Hit h, _) => bindHit h | (Miss why, against) => here (why, against))
                 | Parallel.Compile => here (why, against))
        end
      and compileUnit ((name, load, allow, ident, mode), k, against : UnitCache.entry option, acc) =
        let
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
                              (fn () => (Elaborate.allowPrim := allow; Elaborate.elabTop (env, decs); Elaborate.finish (); decs))
                              ()
                 end)
          val () = if !keepSyntax then keptSyntax := (name, decs) :: !keptSyntax else ()
          (* after an error, the units are only elaborated, for their errors *)
          val failed = !Error.errors > 0
          val warnings = map Error.formatWarning (List.rev (!Error.warnings))
          val () = if failed then () else if !Options.noWarnings then Error.warnings := [] else Error.flushWarnings ()
        in
          if !Options.typecheckOnly orelse failed then (if failed then failedBefore := true else (); acc)
          else
            let
              val usages = timed "unit-usages" (fn () => UnitBasis.usagesOf names)
              val {code, exported, loaded} =
                Pipeline.unitThrough {start = start, name = ident, file = name, text = text (name, mode), mode = mode, decs = decs,
                                      delta = !Elaborate.lastDelta, fixity = !fixity, used = names}
              val bytes = timed "unit-chunks" (fn () => String.concat (UnitFile.chunks (Pipeline.fingerprint (), code)))
              (* --pass-stats with RUNE_MEM set: the bytes of its basis and
                 its code (issue 14) *)
              val () = if !Pass.stats andalso isSome (OS.Process.getEnv "RUNE_MEM")
                       then TextIO.output (TextIO.stdErr, "unit " ^ name ^ " basis " ^ Int.toString (String.size (#pickle exported))
                                                          ^ " bytes, code " ^ Int.toString (String.size bytes) ^ " bytes\n")
                       else ()
              (* its Mid in bytes, kept in its entry *)
              val midBytes = timed "unit-mid" (fn () => case !Pipeline.lastMid of SOME um => UnitMid.write (exported, um) | NONE => "")
              val () = Pipeline.lastMid := NONE
              (* the entry verified: its basis the same bytes, and its code,
                 named by the source where it is now *)
              val verified =
                case against of
                  NONE => true
                | SOME e => UnitCache.verifies (e, name, #pickle exported, bytes, midBytes)
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
                   UnitCache.store (dir, config, k,
                                    {usages = usages, warnings = warnings, file = name,
                                     others = UnitBasis.sourcesOf (code, name), pickle = #pickle exported,
                                     code = bytes, mid = midBytes})
               | _ => ());
              (code, keptPickle (#pickle exported)) :: acc
            end
        end
      (* --build: the user's units as the build file says (docs/build.md):
         each compiled in the basis the steps before it leave. A basis is the
         environment, the fixity, the signatures and functors, and the units
         that bound each name (UnitBasis.binders), which the usages of the
         units after it are of *)
      type snapshot = {env : Env.env, fixity : Fixity.env, sigs : SigMatch.sigma StringMap.map,
                       funs : Elaborate.funinfo StringMap.map, binders : string StringMap.map,
                       declared : int, bound : int}
      fun snap () : snapshot =
        {env = !env, fixity = !fixity, sigs = !Elaborate.sigs, funs = !Elaborate.funs, binders = !UnitBasis.binders,
         declared = List.length (!declLog), bound = List.length (!UnitBasis.bindLog)}
      (* what the steps between two snapshots added *)
      type delta = {env : Env.env, directives : (string * Fixity.fixity) list, declared : (string * string) list,
                    bound : string list, sigs : SigMatch.sigma StringMap.map, funs : Elaborate.funinfo StringMap.map,
                    binders : string StringMap.map}
      fun deltaOf (b1 : snapshot, b2 : snapshot) : delta =
        {env = UnitBasis.envDelta (#env b1, #env b2),
         directives = List.take (#list (#fixity b2), List.length (#list (#fixity b2)) - List.length (#list (#fixity b1))),
         declared = List.rev (List.take (!declLog, List.length (!declLog) - #declared b1)),
         bound = List.rev (List.take (!UnitBasis.bindLog, List.length (!UnitBasis.bindLog) - #bound b1)),
         sigs = #sigs b2, funs = #funs b2, binders = #binders b2}
      (* b0's basis, and what a delta adds to it: all of it, or a library's
         exports *)
      fun apply (b0 : snapshot, d : delta, exports : (BuildFile.kind * string) list option) =
        let
          fun exported (k, n) = case exports of NONE => true | SOME es => List.exists (fn e => e = (k, n)) es
          val Env.Env {vals, tys, strs} = #env d
          val e = Env.Env {vals = if isSome exports then StringMap.empty else vals,
                           tys = StringMap.filteri (fn (n, _) => exported (BuildFile.Ty, n)) tys,
                           strs = StringMap.filteri (fn (n, _) => exported (BuildFile.Str, n)) strs}
          fun keyVisible key =
            case String.fields (fn c => c = #" ") key of
              [kind, n] =>
                (case kind of
                   "s" => exported (BuildFile.Str, n) | "t" => exported (BuildFile.Ty, n)
                 | "sig" => exported (BuildFile.Sig, n) | "fun" => exported (BuildFile.Fun, n)
                 | _ => not (isSome exports))
            | _ => not (isSome exports)
        in
          env := Env.plus (#env b0, e);
          fixity := Fixity.extend (#fixity b0, if isSome exports then [] else #directives d);
          Elaborate.sigs := List.foldl (fn (("sig", n), m) =>
                                          if exported (BuildFile.Sig, n)
                                          then (case StringMap.find (#sigs d, n) of SOME x => StringMap.insert (m, n, x) | NONE => m)
                                          else m
                                        | (_, m) => m) (#sigs b0) (#declared d);
          Elaborate.funs := List.foldl (fn (("fun", n), m) =>
                                          if exported (BuildFile.Fun, n)
                                          then (case StringMap.find (#funs d, n) of SOME x => StringMap.insert (m, n, x) | NONE => m)
                                          else m
                                        | (_, m) => m) (#funs b0) (#declared d);
          UnitBasis.binders := List.foldl (fn (key, m) =>
                                             if keyVisible key
                                             then (case StringMap.find (#binders d, key) of
                                                     SOME i => StringMap.insert (m, key, i)
                                                   | NONE => m)
                                             else m) (#binders b0) (#bound d)
        end
      val libraryContexts : (string * snapshot) list ref = ref []
      fun restoreContext (b : snapshot) =
        (env := #env b; fixity := #fixity b; Elaborate.sigs := #sigs b;
         Elaborate.funs := #funs b; UnitBasis.binders := #binders b)
      fun libraries (es,acc) =
        List.foldl (fn (group,acc) =>
          let val prior = snap ()
              val acc = List.foldl (fn (e,acc) => unit (file (e,inBasis e),acc)) acc group
          in case exportsOf group of
               NONE => acc
             | SOME exports =>
                 (libraryContexts := (#dir (hd group),snap ()) :: !libraryContexts;
                  apply (prior,deltaOf (prior,snap ()),SOME exports); acc)
          end) acc (entryGroups es)
      fun finals (es,acc) =
        List.foldl (fn (group,acc) =>
          case List.find (fn (dir,_) => dir = #dir (hd group)) (!libraryContexts) of
            NONE => List.foldl (fn (e,acc) => unit (file (e,!Options.allowPrim),acc)) acc group
          | SOME (_,context) =>
              let val prior = snap ()
                  val () = restoreContext context
                  val acc = List.foldl (fn (e,acc) => unit (file (e,!Options.allowPrim),acc)) acc group
              in restoreContext prior; acc end) acc (entryGroups es)
      val implemented : string list ref = ref []
      val used : (string * delta) list ref = ref []
      fun elabSteps (steps : step list, acc) = List.foldl elabStep acc steps
      and elabStep (SUnit (p, anns), acc) =
            let
              val allow = !Options.allowPrim orelse List.exists (fn a => a = "allowPrim") anns
              val quiet = !Options.noWarnings
              val () = if List.exists (fn a => a = "noWarnings") anns then Options.noWarnings := true else ()
              val mode = modeOf anns
              val acc = unit ((p, fn () => loadTokens (mode, p), allow, p, mode), acc)
                        handle e => (Options.noWarnings := quiet; raise e)
            in Options.noWarnings := quiet; acc end
        | elabStep (SLocal (a, b), acc) =
            let
              val b0 = snap ()
              val acc = elabSteps (a, acc)
              val b1 = snap ()
              val acc = elabSteps (b, acc)
            in apply (b0, deltaOf (b1, snap ()), NONE); acc end
        | elabStep (SLibrary (exports, ds), acc) =
            let
              val b0 = snap ()
              val acc = elabSteps (ds, acc)
            in apply (b0, deltaOf (b0, snap ()), SOME exports); acc end
        | elabStep (SUse (p, ds), acc) =
            (case List.find (fn (q, _) => q = p) (!used) of
               SOME (_, d) => (apply (snap (), d, NONE); acc)
             | NONE =>
                 let
                   val b1 = snap ()
                   val acc = elabSteps (ds, acc)
                 in used := (p, deltaOf (b1, snap ())) :: !used; acc end)
        | elabStep (SImplements (x, ds), acc) =
            if List.exists (fn y => y = x) (!implemented)
            then raise Options.Usage ("the build gives the virtual module " ^ x ^ " two implementations")
            else
              (* what the implementation declares is the program's, and no
                 file after it names it: it is reached through the virtual
                 module, whose units do not change with it *)
              let
                val () = implemented := x :: !implemented
                val b0 = snap ()
                val acc = elabSteps (ds, acc)
              in apply (b0, deltaOf (b0, snap ()), SOME []); acc end
      (* -j N: the units before the final ones, each with what it declares
         and uses -- a Basis file's by its MANIFEST, a program's by Deps --
         for Parallel to start children in an order that works *)
      val () =
        if !Options.jobs > 1 andalso isSome cache andalso not (UnitCache.verifying ())
           andalso not (!Options.typecheckOnly)
        then
          let
            val basisUnits =
              ListPair.map (fn (e : entry, (name, _, _, _, _)) =>
                              (name, #provides e, List.filter (fn n => not (String.isPrefix "-" n)) (#requires e ()),
                               #when e = Always))
                           (basis, basisPart)
            fun userUnit (name, _, _, _, mode) =
              let val f = Deps.analyse (name, syntaxOf (mode, name))
              in (name, List.map #2 (#declares f), List.map #2 (#uses f), not (List.null (#breaks f))) end
              handle _ => (name, [], [], true)
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
      val compiled =
        (case !buildPlan of
           NONE => List.rev (finals (final,withDefaults (fn acc => List.foldl unit acc userPart) (libraries (basis,[]))))
         | SOME plan =>
             List.rev (finals (final,withDefaults (fn acc => elabSteps (plan,acc)) (libraries (basis,[])))))
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
          val prog = Pass.stage {name = "midcanon", showIn = NONE, show = MidText.show, check = MidLint.check,
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
                 else Link.program (Stack.program, Opcodes.linked, units)
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
      (* a program that may load units keeps their exports, as compileUnits
         says *)
      val () = keepExports := List.exists (fn (_, u : Link.unitCode) =>
                                             List.exists (fn n => String.isPrefix (n ^ "@") (#identity u))
                                                         ["lib/basis/runtime.sml", "lib/basis/dynamic.sml"]) read
    in
      linkUnits (fingerprint, inputs, List.map #2 read)
    end

  and frontEnd (basis : entry list, final : entry list, userToks, _ : string list) : Lambda.lexp option =
    let
      fun parseEntries es = List.concat (List.map (fn e : entry => parseTokens (loadTokens (Source.Ascii, BasisManifest.path e))) es)
      val syntaxGroups : (entry list * Ast.program * Fixity.env) list ref = ref []
      val finalSyntax : (entry list * Ast.program) list ref = ref []
      fun parseLibrary es =
        let val incoming = !fixity
            val ds = parseEntries es
            val outgoing = !fixity
            val () = if isSome (exportsOf es) then fixity := incoming else ()
        in (es,ds,outgoing) end
      fun parseFinal es =
        let val incoming = !fixity
            val scoped = isSome (exportsOf es)
            val () = if not scoped then () else
              (case List.find (fn (group,_,_) => #dir (hd group) = #dir (hd es)) (!syntaxGroups) of
                 SOME (_,_,fx) => fixity := fx | NONE => ())
            val ds = parseEntries es
            val () = if scoped then fixity := incoming else ()
        in (es,ds) end
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
                               val b = parseEntries (List.filter inBasis basis)
                               val libraries = List.map parseLibrary (entryGroups (List.filter (not o inBasis) basis))
                               val () = syntaxGroups := libraries
                               val l = List.concat (List.map #2 libraries)
                               val u = List.concat (List.map parseTokens userToks)
                               val finals = List.map parseFinal (entryGroups final)
                               val () = finalSyntax := finals
                             in (b,l,u,List.concat (List.map #2 finals)) end)
                   ()
      val preludeProg = basisProg @ libraryProg
      (* the warnings of UTS #39 the inputs' lexing found (D13) *)
      val () = List.app Lexer.report (!Options.inputs)
      val () = if !Options.dumpAst then List.app (fn d => println (Ast.decToString d)) (userProg @ finalProg) else ()
      val env = ref Env.initial
      type libraryContext = LibraryScope.basis
      val libraryContexts : (string * libraryContext) list ref = ref []
      fun context () : libraryContext = {env= !env,sigs= !Elaborate.sigs,funs= !Elaborate.funs}
      fun restore (b : libraryContext) =
        (env := #env b; Elaborate.sigs := #sigs b; Elaborate.funs := #funs b)
      fun elabLibrary (es,ds,_) =
        let val prior = context ()
            val () = Elaborate.elabTop (env,ds)
        in case exportsOf es of
             NONE => ()
           | SOME _ =>
               let val raw = context ()
                   val exports = valOf (BasisManifest.scopeOf es)
               in libraryContexts := (#dir (hd es),raw) :: !libraryContexts;
                  restore (LibraryScope.restrict (prior,raw,exports)) end
        end
      fun elabFinal (es : entry list,ds) =
        case List.find (fn (dir,_) => dir = #dir (hd es)) (!libraryContexts) of
          NONE => Elaborate.elabTop (env,ds)
        | SOME (_,raw) =>
            let val prior = context ()
                val () = restore raw
                val () = Elaborate.elabTop (env,ds)
            in restore prior end
      fun elaborate (progs as (b, l, u, fin)) =
        (Elaborate.allowPrim := true;
         Elaborate.elabTop (env, b);
         Elaborate.allowPrim := false;
         List.app elabLibrary (!syntaxGroups);
         Elaborate.allowPrim := !Options.allowPrim;
         (* --default-type holds for the input files, not for the libraries *)
         Elaborate.intDefault := (if !Options.defaultInt64 then Types.int64Ty else Types.intTy);
         Elaborate.wordDefault := (if !Options.defaultWord64 then Types.word64Ty else Types.wordTy);
         Elaborate.elabTop (env, u);
         Elaborate.intDefault := Types.intTy;
         Elaborate.wordDefault := Types.wordTy;
         List.app elabFinal (!finalSyntax);
         Elaborate.finish ();
         progs)
      val () = Elaborate.recover := true
      val _ = frontStage "elaborate" elaborate (basisProg, libraryProg, userProg, finalProg)
      val () = failIfReported ()
      val () = if !Options.noWarnings then Error.warnings := [] else Error.flushWarnings ()
    in
      if !Options.typecheckOnly then NONE
      else
        SOME (Pass.stage {name = "translate", showIn = NONE, show = Lambda.show, check = LambdaLint.check,
                          size = Lambda.size}
                         Translate.transProgram (preludeProg @ userProg @ finalProg))
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

  fun main (name : string, args : string list) : OS.Process.status =
    let val status = main' (name, args)
    in Pass.finish (); Diagnostic.finish (OS.Process.isSuccess status); status end

  and main' (_ : string, args : string list) : OS.Process.status =
    (Options.parse args;
     Pass.startup ();
     Parser.orPatterns := !Options.orPatterns;
     Diagnostic.install {color = !Options.color, full = !Options.diagnostics, json = !Options.diagnosticsJson};
     if !Options.showHelp then (print Options.usage; OS.Process.success)
     else if !Options.showVersion then (println ("rune " ^ Config.version); OS.Process.success)
     else if !Options.basisCheck then checkManifest ()
     else if !Options.deps orelse !Options.depsDot orelse !Options.depsUses then depsCommand ()
     else if isSome (!Options.basisIndex) then basisIndex (valOf (!Options.basisIndex))
     else if !Options.buildList then
       (List.app println (filesOf (#1 (planOf (valOf (!Options.build))))); OS.Process.success)
     else if !Options.lexCount > 0 then lexCount ()
     else if !Options.dumpTokens then dumpTokens ()
     else if isSome (!Options.readMid) then readMid (valOf (!Options.readMid))
     else compile ())
    handle BasisManifest.Usage msg => (eprintln ("rune: " ^ msg); eprintln "try 'rune --help'"; OS.Process.failure)
         | Options.Usage msg => (eprintln ("rune: " ^ msg); eprintln "try 'rune --help'"; OS.Process.failure)
         | Error.CompileError (sp, msg) => (eprintln (!Error.show ("error", sp, msg)); Error.note ("error", sp, msg); OS.Process.failure)
         | Reported => OS.Process.failure
         | Error.Bug msg => (eprintln ("rune: " ^ msg); OS.Process.failure)
         | IO.Io {name, ...} => (eprintln ("rune: I/O error on " ^ name); OS.Process.failure)
end

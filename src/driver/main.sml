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

  fun defaultOutput (first : string) : string =
    let
      val base = if String.isSuffix ".sml" first then String.substring (first, 0, String.size first - 4) else first
    in base ^ ".rbc" end

  val fixity : Fixity.env ref = ref Fixity.initial

  (* A compile that reported its errors as it found them (Error.report),
     and so fails once the front end is done *)
  exception Reported
  fun failIfReported () = if !Error.errors > 0 then raise Reported else ()

  fun loadTokens (path : string) : Lexer.item vector =
    let
      val file = Source.load path
                 handle IO.Io _ => raise Options.Usage ("cannot read " ^ path)
    in
      Lexer.tokenize file
    end

  (* --dump-tokens: the tokens of the named files and nothing else; no basis
     is loaded, nothing is compiled and nothing is written. *)
  fun dumpTokens () : OS.Process.status =
    let
      val inputs = !Options.inputs
      val () = if List.null inputs then raise Options.Usage "no input files" else ()
    in
      List.app (fn path =>
        Vector.app (fn (t, sp) => println (Source.describe sp ^ " " ^ Token.toString t))
                   (loadTokens path)) inputs;
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
      fun complain (e : entry, msg) = (eprintln ("rune: " ^ #dir e ^ "/MANIFEST: " ^ #file e ^ ": " ^ msg); ok := false)
      fun sorted l = StringMap.listKeys (List.foldl (fn (n, m) => StringMap.insert (m, n, ())) StringMap.empty l)
      fun show l = String.concatWith " " l
      (* A file of the basis library is checked against the basis library;
         one of another library against it and all that comes before it. *)
      fun check provider (e : entry, earlier : names) : names =
        let
          val toks = loadTokens (BasisManifest.path e)
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
          (* the names another file provides and this one does not *)
          val used =
            List.filter (fn n => not (List.exists (fn p => p = n) (#provides e))
                                 andalso (case StringMap.find (provider, n) of
                                            SOME files => List.exists (fn f => f <> BasisManifest.path e) files
                                          | NONE => false))
                        (StringMap.listKeys (namesOf (toks, StringMap.empty)))
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
      val _ = List.foldl (fn ((_, es), earlier) => List.foldl (check (providers all)) earlier es) earlier libs
      val count = List.length all
    in
      if !ok then (println ("basis-check: OK (" ^ Int.toString count ^ " files)"); OS.Process.success)
      else OS.Process.failure
    end

  (* --read-mid: a Mid program from its text, made and checked as the pass
     mid makes and checks one; there is no bytecode from Mid yet. *)
  fun readMid (file : string) : OS.Process.status =
    let
      val text = #text (Source.readFile file) handle IO.Io _ => raise Options.Usage ("cannot read " ^ file)
      fun parse t = MidText.parse t handle MidText.Syntax msg => raise Options.Usage (file ^ ": " ^ msg)
    in
      ignore (Pipeline.midStage NONE parse text);
      OS.Process.success
    end

  fun compile () : OS.Process.status =
    let
      val inputs = !Options.inputs
      val () = if List.null inputs then raise Options.Usage "no input files" else ()
    in
      if List.all (fn f => String.isSuffix ".rbu" f) inputs then linkUnitFiles inputs
      else compileSources inputs
    end

  and compileSources (inputs : string list) : OS.Process.status =
    let
      val userToks = List.map loadTokens inputs
      val () = if !Options.noPrelude andalso not (List.null (!Options.libraries))
               then raise Options.Usage "--library needs the basis library (not --no-prelude)" else ()
      val basis =
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
              List.foldl (fn (e, m) => namesOf (loadTokens (BasisManifest.path e), m)) mentioned chosenLibrary
          in
            if !Options.basisAll then entries
            else select (entries, mentioned)
          end
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
      fun file (e : entry, allow) = (BasisManifest.path e, fn () => loadTokens (BasisManifest.path e), allow, libName e)
      val sources =
        List.map (fn e => file (e, inBasis e)) basis
        @ ListPair.map (fn (toks, name) => (name, fn () => toks, !Options.allowPrim, name)) (userToks, inputs)
        @ List.map (fn e => file (e, !Options.allowPrim)) final
      (* the front end's stages, for --pass-stats; their size is the number of
         top-level declarations *)
      fun frontStage name f =
        Pass.stage {name = name, showIn = NONE, show = fn _ => "", check = fn _ => (), size = List.length} f
      fun text name () =
        case Source.findFile name of
          SOME f => #text f
        | NONE => #text (Source.load name) handle IO.Io _ => raise Options.Usage ("cannot read " ^ name)
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
      fun timed name f = Pass.stage {name = name, showIn = NONE, show = fn _ => "", check = fn _ => (), size = fn _ => 0} f ()
      fun unit ((name, load, allow, ident), acc) =
        let
          val () = if !Pass.stats then TextIO.output (TextIO.stdErr, "unit " ^ name ^ "\n") else ()
          val k = case cache of
                    SOME _ =>
                      if !failedBefore then NONE
                      else SOME (timed "cache-key" (fn () => UnitCache.key {name = ident, text = text name (), allow = allow}))
                  | NONE => NONE
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
              UnitCache.Found e => if UnitCache.verifying () then (UnitCache.Missed "to verify its entry", SOME e)
                                   else (found, NONE)
            | _ => (found, NONE)
          (* from the cache: its basis loaded, its code read *)
          val hit =
            case found of
              UnitCache.Missed why => (explain ("rune: compiled " ^ name ^ ": " ^ why); NONE)
            | UnitCache.Found {pickle, code, warnings, file, others, ...} =>
                let val at = UnitBasis.counters ()
                in
                  (let
                     val (fp, u) = timed "cache-code" (fn () => UnitFile.read code)
                     val () = if fp <> Pipeline.fingerprint () then raise UnitFile.Bad "another instruction set" else ()
                     val () = Option.app (fn i => raise UnitBasis.Missing i) (UnitBasis.absent u)
                     val l = timed "cache-basis" (fn () => UnitBasis.load {pickle = pickle, file = name, at = at, env = !env,
                                                                           fixity = !fixity, text = text name})
                     (* its source, and those of the functors' bodies it
                        applied, where they are now, in its code's files *)
                     val u = UnitBasis.relocate (u, file, name, others)
                   in
                     explain ("rune: from the cache " ^ name);
                     (* the warnings its compile gave, again *)
                     if !Options.noWarnings then ()
                     else List.app (fn w => TextIO.output (TextIO.stdErr, w ^ "\n")) warnings;
                     SOME (l, u, pickle)
                   end)
                  handle Pickle.Bad why => (UnitBasis.setCounters at; explain ("rune: compiled " ^ name ^ ": a damaged entry: " ^ why); NONE)
                       | UnitFile.Bad why => (UnitBasis.setCounters at; explain ("rune: compiled " ^ name ^ ": a damaged entry: " ^ why); NONE)
                       | UnitBasis.Missing u => (UnitBasis.setCounters at; explain ("rune: compiled " ^ name ^ ": its entry names " ^ u); NONE)
                end
        in
          case hit of
            SOME (l, u, pickle) =>
              (env := Env.plus (!env, #delta l);
               fixity := Fixity.extend (!fixity, #directives l);
               UnitBasis.bind l;
               (u, pickle) :: acc)
          | NONE => compileUnit ((name, load, allow, ident), k, against, acc)
        end
      and compileUnit ((name, load, allow, ident), k, against : UnitCache.entry option, acc) =
        let
          val start = UnitBasis.begin (!env, !fixity)
          (* parsed and elaborated, the names it looks up recorded: its
             usages (UnitCache) *)
          val (decs, names) =
            Usage.record
              (fn () =>
                 let
                   val decs = frontStage "parse" (fn () => parseTokens (load ())) ()
                 in
                   (* a unit's flexible records are settled at its end, and its
                      matches reported (docs/units.md) *)
                   frontStage "elaborate"
                              (fn () => (Elaborate.allowPrim := allow; Elaborate.elabTop (env, decs); Elaborate.finish (); decs))
                              ()
                 end)
          (* after an error, the units are only elaborated, for their errors *)
          val failed = !Error.errors > 0
          val warnings = List.rev (!Error.warnings)
          val () = if failed then () else if !Options.noWarnings then Error.warnings := [] else Error.flushWarnings ()
        in
          if !Options.typecheckOnly orelse failed then (if failed then failedBefore := true else (); acc)
          else
            let
              val usages = UnitBasis.usagesOf names
              val {code, exported, loaded} =
                Pipeline.unitThrough {start = start, name = ident, file = name, text = text name, decs = decs,
                                      delta = !Elaborate.lastDelta, fixity = !fixity, used = names}
              val bytes = String.concat (UnitFile.chunks (Pipeline.fingerprint (), code))
              (* the entry verified: its basis the same bytes, and its code,
                 named by the source where it is now *)
              val verified =
                case against of
                  NONE => true
                | SOME e => UnitCache.verifies (e, name, #pickle exported, bytes)
            in
              env := Env.plus (#env start, #delta loaded);
              fixity := Fixity.extend (#fixity start, #directives loaded);
              UnitBasis.bind loaded;
              if verified then ()
              else (TextIO.output (TextIO.stdErr, "rune: " ^ name ^ ": the cache's entry is not what compiling it gives\n");
                    unverified := !unverified + 1);
              (* an entry that did not verify is left as it was, to be looked at *)
              (case (cache, k, verified) of
                 (SOME (dir, config), SOME k, true) =>
                   UnitCache.store (dir, config, k,
                                    {usages = usages, warnings = warnings, file = name,
                                     others = UnitBasis.sourcesOf (code, name), pickle = #pickle exported,
                                     code = bytes})
               | _ => ());
              (code, #pickle exported) :: acc
            end
        end
      val compiled = List.rev (List.foldl unit [] sources)
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
      else timed "link" (fn () => linkUnits (fingerprint, inputs, units))
    end

  (* The units linked into the program, by the target of the fingerprint *)
  and linkUnits (fingerprint : int, inputs : string list, units : Link.unitCode list) : OS.Process.status =
    if fingerprint = RegCodes.fingerprint then
      (Code.opcodeNames := RegCodes.names;
       emitProgramAs (fingerprint, inputs, Link.program (Regs.program, RegCodes.linked, units)))
    else emitProgram (inputs, Link.program (Stack.program, Opcodes.linked, units))

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
        let val out = TextIO.openOut (OS.Path.joinDirFile {dir = dir, file = file})
        in List.app (fn l => TextIO.output (out, l ^ "\n")) lines; TextIO.closeOut out end
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
    in
      linkUnits (fingerprint, inputs, List.map #2 read)
    end

  and frontEnd (basis : entry list, final : entry list, userToks, _ : string list) : Lambda.lexp option =
    let
      fun parseEntries es = List.concat (List.map (fn e : entry => parseTokens (loadTokens (BasisManifest.path e))) es)
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
                               val l = parseEntries (List.filter (not o inBasis) basis)
                             in (b, l, List.concat (List.map parseTokens userToks), parseEntries final) end)
                   ()
      val preludeProg = basisProg @ libraryProg
      val () = if !Options.dumpAst then List.app (fn d => println (Ast.decToString d)) (userProg @ finalProg) else ()
      val env = ref Env.initial
      fun elaborate (progs as (b, l, u, fin)) =
        (Elaborate.allowPrim := true;
         Elaborate.elabTop (env, b);
         Elaborate.allowPrim := false;
         Elaborate.elabTop (env, l);
         Elaborate.allowPrim := !Options.allowPrim;
         (* --default-type holds for the input files, not for the libraries *)
         Elaborate.intDefault := (if !Options.defaultInt64 then Types.int64Ty else Types.intTy);
         Elaborate.wordDefault := (if !Options.defaultWord64 then Types.word64Ty else Types.wordTy);
         Elaborate.elabTop (env, u);
         Elaborate.intDefault := Types.intTy;
         Elaborate.wordDefault := Types.wordTy;
         Elaborate.elabTop (env, fin);
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
        let val low = Pipeline.lowOf lam
        in
          if !Options.target = "registers" then
            (Code.opcodeNames := RegCodes.names;
             emitProgramAs (RegCodes.fingerprint, inputs, Pipeline.targetStage low))
          else emitProgram (inputs, Pipeline.targetStage low)
        end

  and emitProgram (inputs : string list, prog : Code.program) : OS.Process.status =
    emitProgramAs (Opcodes.fingerprint, inputs, prog)

  and emitProgramAs (fingerprint : int, inputs : string list, prog : Code.program) : OS.Process.status =
    let
      val out = case !Options.output of SOME f => f | NONE => defaultOutput (List.hd inputs)
      fun absolute p = OS.Path.mkCanonical (OS.Path.mkAbsolute {path = p, relativeTo = OS.FileSys.getDir ()})
      fun same p = absolute p = absolute out orelse
                   ((OS.FileSys.fileId p = OS.FileSys.fileId out) handle OS.SysErr _ => false)
      val () = if List.exists same inputs then raise Options.Usage "output must differ from every input file" else ()
    in
      Emit.writeFileAs (fingerprint, out, prog);
      OS.Process.success
    end

  fun main (_ : string, args : string list) : OS.Process.status =
    (Options.parse args;
     Parser.orPatterns := !Options.orPatterns;
     if !Options.showHelp then (print Options.usage; OS.Process.success)
     else if !Options.showVersion then (println ("rune " ^ Config.version); OS.Process.success)
     else if !Options.basisCheck then checkManifest ()
     else if !Options.dumpTokens then dumpTokens ()
     else if isSome (!Options.readMid) then readMid (valOf (!Options.readMid))
     else compile ())
    handle BasisManifest.Usage msg => (eprintln ("rune: " ^ msg); eprintln "try 'rune --help'"; OS.Process.failure)
         | Options.Usage msg => (eprintln ("rune: " ^ msg); eprintln "try 'rune --help'"; OS.Process.failure)
         | Error.CompileError (sp, msg) => (eprintln (Error.format (sp, msg)); OS.Process.failure)
         | Reported => OS.Process.failure
         | Error.Bug msg => (eprintln ("rune: " ^ msg); OS.Process.failure)
         | IO.Io {name, ...} => (eprintln ("rune: I/O error on " ^ name); OS.Process.failure)
end

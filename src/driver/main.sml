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

  (* The stage that makes Mid, from Lambda or from its text. *)
  fun midStage (showIn : ('a -> string) option) (f : 'a -> Mid.program) : 'a -> Mid.program =
    Pass.stage {name = "mid", showIn = showIn, show = MidText.show,
                check = fn p => (MidLint.check p; if !Options.midRoundTrip then MidText.roundTrip p else ()),
                size = Mid.size}
               f

  (* --read-mid: a Mid program from its text, made and checked as the pass
     mid makes and checks one; there is no bytecode from Mid yet. *)
  fun readMid (file : string) : OS.Process.status =
    let
      val text = #text (Source.readFile file) handle IO.Io _ => raise Options.Usage ("cannot read " ^ file)
      fun parse t = MidText.parse t handle MidText.Syntax msg => raise Options.Usage (file ^ ": " ^ msg)
    in
      ignore (midStage NONE parse text);
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
     fixity and the compiler's tables go on from unit to unit; the passes see
     one unit at a time (Pass.whole). *)
  and compileUnits (basis : entry list, final : entry list, userToks, inputs : string list) : OS.Process.status =
    let
      val () = Pass.whole := false
      val () = Elaborate.recover := true
      val () = MidLint.importedScheme := (fn g => SOME (ToMid.globalScheme g) handle Error.Bug _ => NONE)
      val registers = !Options.target = "registers"
      val () = if registers then Code.opcodeNames := RegCodes.names else ()
      val env = ref Env.initial
      (* each unit's name, its tokens when wanted, and whether it may use
         _prim: the basis library may, the libraries beside it may not *)
      fun file (e : entry, allow) = (BasisManifest.path e, fn () => loadTokens (BasisManifest.path e), allow)
      val sources =
        List.map (fn e => file (e, inBasis e)) basis
        @ ListPair.map (fn (toks, name) => (name, fn () => toks, !Options.allowPrim)) (userToks, inputs)
        @ List.map (fn e => file (e, !Options.allowPrim)) final
      (* the front end's stages, for --pass-stats; their size is the number of
         top-level declarations *)
      fun frontStage name f =
        Pass.stage {name = name, showIn = NONE, show = fn _ => "", check = fn _ => (), size = List.length} f
      fun unit ((name, load, allow), acc) =
        let
          val () = if !Pass.stats then TextIO.output (TextIO.stdErr, "unit " ^ name ^ "\n") else ()
          val decs = frontStage "parse" (fn () => parseTokens (load ())) ()
          (* a unit's flexible records are settled at its end, and its
             matches reported (docs/units.md) *)
          val _ = frontStage "elaborate"
                             (fn () => (Elaborate.allowPrim := allow; Elaborate.elabTop (env, decs); Elaborate.finish (); decs))
                             ()
          (* after an error, the units are only elaborated, for their errors *)
          val failed = !Error.errors > 0
          val () = if failed then () else if !Options.noWarnings then Error.warnings := [] else Error.flushWarnings ()
        in
          if !Options.typecheckOnly orelse failed then acc
          else
            let
              val lam = Pass.stage {name = "translate", showIn = NONE, show = Lambda.show, check = LambdaLint.check,
                                    size = Lambda.size}
                                   Translate.transProgram decs
              val low = lowOf lam
              val code = targetStage low
              val u : Link.unitCode =
                {code = code, globals = IntMap.listItemsi (!Code.globals), defines = Link.defines low,
                 imports = List.map (fn (s, i) => (i, s)) (IntMap.listItemsi (!Lower.imported)),
                 exports = IntMap.listItemsi (!Lower.globalFids)}
            in
              Lower.knownBefore := IntMap.foldli (fn (s, _, m) => IntMap.insert (m, s, ())) (!Lower.knownBefore)
                                                 (!Lower.globalFids);
              u :: acc
            end
        end
      val units = List.rev (List.foldl unit [] sources)
      val () = failIfReported ()
      val fingerprint = if registers then RegCodes.fingerprint else Opcodes.fingerprint
      val () =
        case !Options.emitUnits of
          NONE => ()
        | SOME dir => if !Options.typecheckOnly then () else emitUnitFiles (dir, fingerprint, List.map #1 sources, units)
    in
      if !Options.typecheckOnly then OS.Process.success
      else linkUnits (fingerprint, inputs, units)
    end

  (* The units linked into the program, by the target of the fingerprint *)
  and linkUnits (fingerprint : int, inputs : string list, units : Link.unitCode list) : OS.Process.status =
    if fingerprint = RegCodes.fingerprint then
      (Code.opcodeNames := RegCodes.names;
       emitProgramAs (fingerprint, inputs, Link.program (Regs.program, RegCodes.linked, units)))
    else emitProgram (inputs, Link.program (Stack.program, Opcodes.linked, units))

  (* --emit-units DIR: each unit's file, its number and its source's name,
     and DIR/units, their names in order. The units of one compile share a
     session, a hash of the names and texts of all of them, since the
     stamps they name each other by mean something only beside each other
     (UnitFile). *)
  and emitUnitFiles (dir : string, fingerprint : int, names : string list, units : Link.unitCode list) : unit =
    let
      fun hash (m, k) s (h : int) = CharVector.foldl (fn (c, h) => (h * k + Char.ord c) mod m) h s
      fun text name = case Source.findFile name of SOME f => #text f | NONE => ""
      val (h1, h2) =
        List.foldl (fn (n, (a, b)) =>
                      let val s = n ^ "\000" ^ text n ^ "\000"
                      in (hash (16777213, 31) s a, hash (16777199, 37) s b) end) (7, 11) names
      fun hex6 n = StringCvt.padLeft #"0" 6 (Int.fmt StringCvt.HEX n)
      val session = hex6 h1 ^ hex6 h2
      val () = (OS.FileSys.mkDir dir handle OS.SysErr _ => ())
      fun base n = OS.Path.base (OS.Path.file n)
      val files =
        ListPair.map (fn ((n, u), i) =>
                        let val f = OS.Path.joinDirFile {dir = dir, file = StringCvt.padLeft #"0" 4 (Int.toString i) ^ "-" ^ base n ^ ".rbu"}
                        in UnitFile.write (f, fingerprint, session, u); f end)
                     (ListPair.zip (names, units), List.tabulate (List.length units, fn i => i))
      val out = TextIO.openOut (OS.Path.joinDirFile {dir = dir, file = "units"})
    in
      List.app (fn f => TextIO.output (out, f ^ "\n")) files;
      TextIO.closeOut out
    end

  (* rune -o P.rbc A.rbu B.rbu ...: unit files of one compile, linked *)
  and linkUnitFiles (inputs : string list) : OS.Process.status =
    let
      val read = List.map (fn f => UnitFile.readFile f handle UnitFile.Bad why => raise Options.Usage why
                                                        | IO.Io _ => raise Options.Usage ("cannot read " ^ f)) inputs
      val (fingerprint, session, _) = List.hd read
      val () =
        if List.all (fn (fp, s, _) => fp = fingerprint andalso s = session) read then ()
        else raise Options.Usage "the units were not compiled together: their instruction sets or sessions differ"
    in
      linkUnits (fingerprint, inputs, List.map #3 read)
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
        let val low = lowOf lam
        in
          if !Options.target = "registers" then
            (Code.opcodeNames := RegCodes.names;
             emitProgramAs (RegCodes.fingerprint, inputs, targetStage low))
          else emitProgram (inputs, targetStage low)
        end

  (* Lambda to Low: Mid, the optional passes on it, and Lower. Shake runs
     on a whole program only (Pass.whole). *)
  and lowOf (lam : Lambda.lexp) : Low.program =
        let
          val mid = midStage (SOME Lambda.show) ToMid.program lam
          (* the optional passes on Mid (docs/ir.md) *)
          fun optional (name, f) m =
            if Pass.enabled (name, 1) andalso (name <> "shake" orelse !Pass.whole) then
              Pass.stage {name = name, showIn = SOME MidText.show, show = MidText.show, check = MidLint.check,
                          size = Mid.size}
                         f m
            else m
          val mid = optional ("shake", Shake.program) mid
          val mid = optional ("lift", Lift.program) mid
          val mid = optional ("workers", Workers.program) mid
          val mid = optional ("simplify", Simplify.program) mid
          (* what the inliner left of the functions it put in place goes *)
          val mid =
            if Pass.enabled ("simplify", 1) andalso Pass.enabled ("inline", 1) then optional ("shake", Shake.program) mid
            else mid
        in
          Pass.stage {name = "lower", showIn = SOME MidText.show, show = Low.show, check = LowLint.check,
                      size = Low.size}
                     (fn m => Lower.program (m, !Translate.funNames)) mid
        end

  (* Low to the code of the target --target names *)
  and targetStage (low : Low.program) : Code.program =
    if !Options.target = "registers" then
      Pass.stage {name = "registers", showIn = SOME Low.show, show = Code.dump, check = fn _ => (), size = Code.size}
                 Regs.program low
    else
      Pass.stage {name = "stack", showIn = SOME Low.show, show = Code.dump, check = fn _ => (), size = Code.size}
                 Stack.program low

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

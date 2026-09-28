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
    backEnd (#4 args, frontEnd args)

  and frontEnd (basis : entry list, final : entry list, userToks, _ : string list) : Lambda.lexp option =
    let
      fun parseEntries es = List.concat (List.map (fn e : entry => parseTokens (loadTokens (BasisManifest.path e))) es)
      (* the basis library may use _prim; the libraries beside it may not *)
      val basisProg = parseEntries (List.filter inBasis basis)
      val libraryProg = parseEntries (List.filter (not o inBasis) basis)
      val preludeProg = basisProg @ libraryProg
      val userProg = List.concat (List.map parseTokens userToks) @ parseEntries final
      val () = if !Options.dumpAst then List.app (fn d => println (Ast.decToString d)) userProg else ()
      val env = ref Env.initial
      val () = Elaborate.allowPrim := true
      val () = Elaborate.elabTop (env, basisProg)
      val () = Elaborate.allowPrim := false
      val () = Elaborate.elabTop (env, libraryProg)
      val () = Elaborate.allowPrim := !Options.allowPrim
      val () = Elaborate.elabTop (env, userProg)
      val () = Elaborate.finish ()
      val () = if !Options.noWarnings then Error.warnings := [] else Error.flushWarnings ()
    in
      if !Options.typecheckOnly then NONE
      else
        SOME (Pass.stage {name = "translate", showIn = NONE, show = Lambda.show, check = LambdaLint.check,
                          size = Lambda.size}
                         Translate.transProgram (preludeProg @ userProg))
    end

  (* -O0 is the same stages with no optional pass *)
  and backEnd (_, NONE) = OS.Process.success
    | backEnd (inputs, SOME lam) =
        let
          val mid = midStage (SOME Lambda.show) ToMid.program lam
          (* the optional passes on Mid (docs/ir.md) *)
          fun optional (name, f) m =
            if Pass.enabled (name, 1) then
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
          val low = Pass.stage {name = "lower", showIn = SOME MidText.show, show = Low.show, check = LowLint.check,
                                size = Low.size}
                               (fn m => Lower.program (m, !Translate.funNames)) mid
        in
          if !Options.target = "registers" then
            (Code.opcodeNames := RegCodes.names;
             emitProgramAs (RegCodes.fingerprint, inputs,
                            Pass.stage {name = "registers", showIn = SOME Low.show, show = Code.dump,
                                        check = fn _ => (), size = Code.size}
                                       Regs.program low))
          else
            emitProgram (inputs,
                         Pass.stage {name = "stack", showIn = SOME Low.show, show = Code.dump,
                                     check = fn _ => (), size = Code.size}
                                    Stack.program low)
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
         | Error.Bug msg => (eprintln ("rune: " ^ msg); OS.Process.failure)
         | IO.Io {name, ...} => (eprintln ("rune: I/O error on " ^ name); OS.Process.failure)
end

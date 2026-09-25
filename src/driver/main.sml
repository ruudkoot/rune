(* Compiler driver. *)
structure Main =
struct
  fun println s = print (s ^ "\n")
  fun eprintln s = TextIO.output (TextIO.stdErr, s ^ "\n")

  fun libDir () : string =
    case !Options.libDir of
      NONE => raise Options.Usage "no basis library (use --lib DIR or --no-prelude)"
    | SOME lib => lib ^ "/basis"

  datatype when = datatype BasisManifest.when
  type entry = BasisManifest.entry
  type names = BasisManifest.names
  val namesOf = BasisManifest.namesOf
  val providers = BasisManifest.providers
  val select = BasisManifest.select
  fun readManifest () = BasisManifest.readManifest (libDir ())

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
      val entries = readManifest ()
      val dir = libDir ()
      val provider = providers entries
      val ok = ref true
      fun complain (e : entry, msg) = (eprintln ("rune: " ^ dir ^ "/MANIFEST: " ^ #file e ^ ": " ^ msg); ok := false)
      fun sorted l = StringMap.listKeys (List.foldl (fn (n, m) => StringMap.insert (m, n, ())) StringMap.empty l)
      fun show l = String.concatWith " " l
      fun check (e : entry, earlier : names) : names =
        let
          val toks = loadTokens (dir ^ "/" ^ #file e)
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
                                            SOME files => List.exists (fn f => f <> #file e) files
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
      val _ = List.foldl check StringMap.empty entries
    in
      if !ok then (println ("basis-check: OK (" ^ Int.toString (List.length entries) ^ " files)"); OS.Process.success)
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
      val basis =
        if !Options.noPrelude then []
        else
          let val entries = readManifest ()
          in
            if !Options.basisAll then entries
            else select (entries, List.foldl namesOf StringMap.empty userToks)
          end
    in
      if !Options.basisDeps then (List.app (fn e : entry => println (#file e)) basis; OS.Process.success)
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
      fun parseEntries es = List.concat (List.map (fn e : entry => parseTokens (loadTokens (libDir () ^ "/" ^ #file e))) es)
      val preludeProg = parseEntries basis
      val userProg = List.concat (List.map parseTokens userToks) @ parseEntries final
      val () = if !Options.dumpAst then List.app (fn d => println (Ast.decToString d)) userProg else ()
      val env = ref Env.initial
      val () = Elaborate.allowPrim := true
      val () = Elaborate.elabTop (env, preludeProg)
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

  and backEnd (_, NONE) = OS.Process.success
    | backEnd (inputs, SOME lam) =
        if !Pass.level = 0 then
          (* -O0: the code generator of Lambda (decision D10 of the plan) *)
          emitProgram (inputs,
                       Pass.stage {name = "codegen", showIn = SOME Lambda.show, show = Codegen.dump,
                                   check = fn _ => (), size = Codegen.size}
                                  (fn lam => Codegen.compile (lam, !Translate.funNames)) lam)
        else
          let
            val mid = midStage (SOME Lambda.show) ToMid.program lam
            val low = Pass.stage {name = "lower", showIn = SOME MidText.show, show = Low.show, check = LowLint.check,
                                  size = Low.size}
                                 (fn m => Lower.program (m, !Translate.funNames)) mid
          in
            if !Options.target = "registers" then
              (Codegen.opcodeNames := RegCodes.names;
               emitProgramAs (RegCodes.fingerprint, inputs,
                              Pass.stage {name = "registers", showIn = SOME Low.show, show = Codegen.dump,
                                          check = fn _ => (), size = Codegen.size}
                                         Regs.program low))
            else
              emitProgram (inputs,
                           Pass.stage {name = "stack", showIn = SOME Low.show, show = Codegen.dump,
                                       check = fn _ => (), size = Codegen.size}
                                      Stack.program low)
          end

  and emitProgram (inputs : string list, prog : Codegen.program) : OS.Process.status =
    emitProgramAs (Opcodes.fingerprint, inputs, prog)

  and emitProgramAs (fingerprint : int, inputs : string list, prog : Codegen.program) : OS.Process.status =
    let
      val out = case !Options.output of SOME f => f | NONE => defaultOutput (List.hd inputs)
    in
      Emit.writeFileAs (fingerprint, out, prog);
      OS.Process.success
    end

  fun main (_ : string, args : string list) : OS.Process.status =
    (Options.parse args;
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

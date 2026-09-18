(* Compiler driver. *)
structure Main =
struct
  fun println s = print (s ^ "\n")
  fun eprintln s = TextIO.output (TextIO.stdErr, s ^ "\n")

  fun readLines (path : string) : string list =
    let
      val ins = TextIO.openIn path
      fun go acc =
        case TextIO.inputLine ins of
          NONE => List.rev acc
        | SOME l =>
          let val t = String.substring (l, 0, String.size l - (if String.isSuffix "\n" l then 1 else 0))
          in if t = "" orelse String.isPrefix "#" t then go acc else go (t :: acc) end
    in go [] before TextIO.closeIn ins end

  fun preludeFiles () : string list =
    let
      val dir = !Options.libDir ^ "/basis"
      val manifest = dir ^ "/MANIFEST"
    in
      List.map (fn f => dir ^ "/" ^ f) (readLines manifest)
      handle IO.Io _ => raise Options.Usage ("cannot read basis manifest " ^ manifest ^ " (use --lib or --no-prelude)")
    end

  fun defaultOutput (first : string) : string =
    let
      val base = if String.isSuffix ".sml" first then String.substring (first, 0, String.size first - 4) else first
    in base ^ ".rbc" end

  val fixity : Fixity.env ref = ref Fixity.initial

  fun parseFile (path : string) : Ast.program =
    let
      val file = Source.load path
                 handle IO.Io _ => raise Options.Usage ("cannot read " ^ path)
    in
      if !Options.dumpTokens then
        Vector.app (fn (t, sp) => println (Source.describe sp ^ " " ^ Token.toString t)) (Lexer.tokenize file)
      else ();
      let val (prog, fx) = Parser.parseFileWith (file, !fixity)
      in fixity := fx; prog end
    end

  fun compile () : OS.Process.status =
    let
      val inputs = !Options.inputs
      val () = if List.null inputs then raise Options.Usage "no input files" else ()
      val preludeProg =
        if !Options.noPrelude then []
        else List.concat (List.map parseFile (preludeFiles ()))
      val userProg = List.concat (List.map parseFile inputs)
      val () = if !Options.dumpAst then List.app (fn d => println (Ast.decToString d)) userProg else ()
      val env = ref Env.initial
      val () = Elaborate.allowPrim := true
      val () = Elaborate.elabTop (env, preludeProg)
      val () = Elaborate.allowPrim := !Options.allowPrim
      val () = Elaborate.elabTop (env, userProg)
      val () = Elaborate.finish ()
      val () = if !Options.noWarnings then Error.warnings := [] else Error.flushWarnings ()
    in
      if !Options.typecheckOnly then OS.Process.success
      else
        let
          val lam = Translate.transProgram (preludeProg @ userProg)
          val () = if !Options.dumpLambda then println (Lambda.toString lam) else ()
          val prog = Codegen.compile lam
          val () = if !Options.dumpCode then print (Codegen.dump prog) else ()
          val out = case !Options.output of SOME f => f | NONE => defaultOutput (List.hd inputs)
        in
          Emit.writeFile (out, prog);
          OS.Process.success
        end
    end

  fun main (_ : string, args : string list) : OS.Process.status =
    (Options.parse args;
     if !Options.showHelp then (print Options.usage; OS.Process.success)
     else if !Options.showVersion then (println ("rune " ^ Config.version); OS.Process.success)
     else compile ())
    handle Options.Usage msg => (eprintln ("rune: " ^ msg); eprintln "try 'rune --help'"; OS.Process.failure)
         | Error.CompileError (sp, msg) => (eprintln (Error.format (sp, msg)); OS.Process.failure)
         | Error.Bug msg => (eprintln ("rune: " ^ msg); OS.Process.failure)
         | IO.Io {name, ...} => (eprintln ("rune: I/O error on " ^ name); OS.Process.failure)
end

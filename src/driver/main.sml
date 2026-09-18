(* Compiler driver. *)
structure Main =
struct
  fun println s = print (s ^ "\n")
  fun eprintln s = TextIO.output (TextIO.stdErr, s ^ "\n")

  (* ---- the basis library: lib/basis/MANIFEST ----
     One file per line, in load order:
       file | always or demand | host | provides | requires
     provides: the structures, signatures and functors the file declares;
     requires: those of other files that it names. (host is for the
     cross-check of tests/basis.) A program is compiled after the always
     files, the files that provide a name it mentions, and what those require:
     the scan below looks at identifiers only, so it may load a file the
     program does not need, never miss one it does. *)
  type entry = {file : string, always : bool, provides : string list, requires : string list}

  fun trim (s : string) : string =
    let
      val n = String.size s
      fun left i = if i < n andalso Char.isSpace (String.sub (s, i)) then left (i + 1) else i
      fun right j = if j > 0 andalso Char.isSpace (String.sub (s, j - 1)) then right (j - 1) else j
      val i = left 0
      val j = right n
    in if i >= j then "" else String.substring (s, i, j - i) end

  fun libDir () : string =
    case !Options.libDir of
      NONE => raise Options.Usage "no basis library (use --lib DIR or --no-prelude)"
    | SOME lib => lib ^ "/basis"

  fun readManifest () : entry list =
    let
      val manifest = libDir () ^ "/MANIFEST"
      fun bad line = raise Options.Usage ("malformed line in " ^ manifest ^ ": " ^ line)
      fun names field = String.tokens Char.isSpace field
      fun entry line =
        case List.map trim (String.fields (fn c => c = #"|") line) of
          [file, mode, _, provides, requires] =>
            {file = file,
             always = (case mode of "always" => true | "demand" => false | _ => bad line),
             provides = names provides, requires = names requires}
        | _ => bad line
      val ins = TextIO.openIn manifest
                handle IO.Io _ => raise Options.Usage ("cannot read basis manifest " ^ manifest ^ " (use --lib or --no-prelude)")
      fun go acc =
        case TextIO.inputLine ins of
          NONE => List.rev acc
        | SOME l =>
            let val t = trim l
            in if t = "" orelse String.isPrefix "#" t then go acc else go (entry t :: acc) end
    in go [] before TextIO.closeIn ins end

  type names = unit StringMap.map

  (* The identifiers of a token stream, and the heads of its long identifiers. *)
  fun namesOf (toks : Lexer.item vector, acc : names) : names =
    Vector.foldl (fn ((Token.ID s, _), acc) => StringMap.insert (acc, s, ())
                   | ((Token.LONGID (s :: _, _), _), acc) => StringMap.insert (acc, s, ())
                   | (_, acc) => acc) acc toks

  (* The entries to load for a program that mentions the given names, in
     MANIFEST order. *)
  fun select (entries : entry list, mentioned : names) : entry list =
    let
      val provider =
        List.foldl (fn (e : entry, m) => List.foldl (fn (n, m) => StringMap.insert (m, n, #file e)) m (#provides e))
                   StringMap.empty entries
      fun entryOf file = List.find (fn e : entry => #file e = file) entries
      fun add (e : entry, chosen : names) : names =
        if StringMap.member (chosen, #file e) then chosen
        else
          List.foldl (fn (n, chosen) =>
                         case StringMap.find (provider, n) of
                           SOME file => (case entryOf file of SOME e' => add (e', chosen) | NONE => chosen)
                         | NONE => raise Options.Usage ("basis manifest: " ^ #file e ^ " requires " ^ n ^
                                                        ", which no file provides"))
                     (StringMap.insert (chosen, #file e, ()))
                     (List.filter (fn n => not (String.isPrefix "-" n)) (#requires e))
      val wanted = fn e : entry => #always e orelse List.exists (fn n => StringMap.member (mentioned, n)) (#provides e)
      val chosen = List.foldl (fn (e, chosen) => if wanted e then add (e, chosen) else chosen) StringMap.empty entries
    in List.filter (fn e : entry => StringMap.member (chosen, #file e)) entries end

  fun defaultOutput (first : string) : string =
    let
      val base = if String.isSuffix ".sml" first then String.substring (first, 0, String.size first - 4) else first
    in base ^ ".rbc" end

  val fixity : Fixity.env ref = ref Fixity.initial

  fun loadTokens (path : string) : Lexer.item vector =
    let
      val file = Source.load path
                 handle IO.Io _ => raise Options.Usage ("cannot read " ^ path)
      val toks = Lexer.tokenize file
    in
      if !Options.dumpTokens then
        Vector.app (fn (t, sp) => println (Source.describe sp ^ " " ^ Token.toString t)) toks
      else ();
      toks
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
      val provider =
        List.foldl (fn (e : entry, m) => List.foldl (fn (n, m) => StringMap.insert (m, n, #file e)) m (#provides e))
                   StringMap.empty entries
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
          val used =
            List.filter (fn n => case StringMap.find (provider, n) of
                                   SOME file => file <> #file e
                                 | NONE => false)
                        (StringMap.listKeys (namesOf (toks, StringMap.empty)))
          (* -Name in the column: named, but not required *)
          fun plain n = if String.isPrefix "-" n then String.extract (n, 1, NONE) else n
          val () = if used = sorted (List.map plain (#requires e)) then ()
                   else complain (e, "requires " ^ show (#requires e) ^ " but names " ^ show used)
          val () = List.app (fn n => if String.isPrefix "-" n orelse StringMap.member (earlier, n) then ()
                                     else complain (e, "requires " ^ n ^ ", which is not provided by an earlier file"))
                            (#requires e)
          val () =
            if #always e then ()
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
      else compileWith (basis, userToks, inputs)
    end

  and compileWith (basis : entry list, userToks, inputs) : OS.Process.status =
    let
      val preludeProg =
        List.concat (List.map (fn e : entry => parseTokens (loadTokens (libDir () ^ "/" ^ #file e))) basis)
      val userProg = List.concat (List.map parseTokens userToks)
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
     else if !Options.basisCheck then checkManifest ()
     else compile ())
    handle Options.Usage msg => (eprintln ("rune: " ^ msg); eprintln "try 'rune --help'"; OS.Process.failure)
         | Error.CompileError (sp, msg) => (eprintln (Error.format (sp, msg)); OS.Process.failure)
         | Error.Bug msg => (eprintln ("rune: " ^ msg); OS.Process.failure)
         | IO.Io {name, ...} => (eprintln ("rune: I/O error on " ^ name); OS.Process.failure)
end

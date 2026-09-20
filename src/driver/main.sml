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
     program does not need, never miss one it does. A name can have several
     files, as IO and OS do (the structure and the signature of the
     specification); naming it loads them all. *)
  datatype when = Always | Demand | Final
  (* requires is read from the text when it is asked for: most programs need
     it of few files *)
  type entry = {file : string, when : when, provides : string list, requires : unit -> string list}

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

  (* The MANIFEST is read for every program, so it is scanned in one pass
     over its text, a line at a time, with the bars and the words of a line
     found by index rather than by splitting it into strings first. *)
  fun readManifest () : entry list =
    let
      val manifest = libDir () ^ "/MANIFEST"
      val ins = TextIO.openIn manifest
                handle IO.Io _ => raise Options.Usage ("cannot read basis manifest " ^ manifest ^ " (use --lib or --no-prelude)")
      val text = TextIO.inputAll ins before TextIO.closeIn ins
      val n = String.size text
      fun at k = String.sub (text, k)
      fun blank c = c = #" " orelse c = #"\t" orelse c = #"\r"
      (* the words of text[i, j) *)
      fun words (i, j) =
        let
          fun skip k = if k < j andalso blank (at k) then skip (k + 1) else k
          fun stop k = if k < j andalso not (blank (at k)) then stop (k + 1) else k
          fun go (k, acc) =
            let val a = skip k
            in if a >= j then List.rev acc else let val e = stop a in go (e, String.substring (text, a, e - a) :: acc) end end
        in go (i, []) end
      fun bad (i, e) = raise Options.Usage ("malformed line in " ^ manifest ^ ": " ^ String.substring (text, i, e - i))
      (* the one word of text[i, j), or NONE *)
      fun one (i, j) = case words (i, j) of [w] => SOME w | _ => NONE
      (* a line text[i, e) of five fields *)
      fun entry (i, e) =
        let
          fun bars (k, acc) = if k >= e then List.rev acc else bars (k + 1, if at k = #"|" then k :: acc else acc)
        in
          case bars (i, []) of
            [b1, b2, b3, b4] =>
              (case (one (i, b1), one (b1 + 1, b2)) of
                 (SOME file, SOME mode) =>
                   {file = file,
                    when = (case mode of "always" => Always | "demand" => Demand | "final" => Final | _ => bad (i, e)),
                    provides = words (b3 + 1, b4), requires = fn () => words (b4 + 1, e)}
               | _ => bad (i, e))
          | _ => bad (i, e)
        end
      fun go (i, acc) =
        if i >= n then List.rev acc
        else
          let
            fun eol k = if k < n andalso at k <> #"\n" then eol (k + 1) else k
            val e = eol i
            fun first k = if k < e andalso blank (at k) then first (k + 1) else k
            val f = first i
          in
            if f >= e orelse at f = #"#" then go (e + 1, acc) else go (e + 1, entry (i, e) :: acc)
          end
    in go (0, []) end

  type names = unit StringMap.map

  (* The identifiers of a token stream, and the heads of its long identifiers. *)
  fun namesOf (toks : Lexer.item vector, acc : names) : names =
    Vector.foldl (fn ((Token.ID s, _), acc) => StringMap.insert (acc, s, ())
                   | ((Token.LONGID (s :: _, _), _), acc) => StringMap.insert (acc, s, ())
                   | (_, acc) => acc) acc toks

  (* name -> the files that provide it, in MANIFEST order *)
  fun providers (entries : entry list) : string list StringMap.map =
    List.foldl (fn (e : entry, m) =>
                   List.foldl (fn (n, m) =>
                                  StringMap.insert (m, n, (case StringMap.find (m, n) of
                                                             SOME fs => fs @ [#file e]
                                                           | NONE => [#file e])))
                              m (#provides e))
               StringMap.empty entries

  (* The entries to load for a program that mentions the given names, in
     MANIFEST order. *)
  fun select (entries : entry list, mentioned : names) : entry list =
    let
      (* The files that provide a name: a scan of the entries, compared with
         the primitive =, for the few names the chosen files require (a map of
         every name would cost more to build than a program needs). *)
      fun providersOf n = List.filter (fn e : entry => List.exists (fn p => p = n) (#provides e)) entries
      fun required (e : entry) = List.filter (fn n => not (String.isPrefix "-" n)) (#requires e ())
      fun add (e : entry, chosen : names) : names =
        if StringMap.member (chosen, #file e) then chosen
        else
          List.foldl (fn (n, chosen) =>
                         case providersOf n of
                           [] => raise Options.Usage ("basis manifest: " ^ #file e ^ " requires " ^ n ^
                                                      ", which no file provides")
                         | es => List.foldl add chosen es)
                     (StringMap.insert (chosen, #file e, ()))
                     (required e)
      val wanted = fn e : entry => #when e = Always orelse List.exists (fn n => StringMap.member (mentioned, n)) (#provides e)
      val chosen = List.foldl (fn (e, chosen) => if wanted e then add (e, chosen) else chosen) StringMap.empty entries
      (* A file compiled after the program joins it only when what it needs is
         there anyway: a program that never mentions OS has nothing to do when
         it ends. *)
      val chosen =
        List.foldl (fn (e : entry, chosen) =>
                       if #when e = Final
                          andalso List.all (fn n => List.exists (fn e' : entry => StringMap.member (chosen, #file e'))
                                                                (providersOf n))
                                           (required e)
                       then add (e, chosen) else chosen)
                   chosen entries
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
            if #when e <> Demand then ()
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
      else compileWith (List.filter (fn e : entry => #when e <> Final) basis,
                        List.filter (fn e : entry => #when e = Final) basis, userToks, inputs)
    end

  and compileWith (basis : entry list, final : entry list, userToks, inputs) : OS.Process.status =
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

(* What the round trips of rhc (tests/runner/hsroundtrip.sml) and its
   clause programs (tests/runner/hslang.sml, hsconformance.sml) do not hold
   the syntax of Haskell 98 to (tests/hs/syntax/README.md; the haskell98
   roadmap's M11): the diagnostics of tests/hs/syntax/errors, the parser's
   own; the parser's mutants, each caught by the test that alone can see
   it; the layout of the files of tests/hs/roundtrip that have an expansion
   written by hand beside them; and the cost of a token. Each is a job of bin/rune-test or
   of bin/rune-hs-syntax that prints a line FAIL for what it finds. *)
structure HsSyntax =
struct
  open Sh

  val accepting = env ("RUNE_TEST_ACCEPT", "") = "1"
  fun fail s = say ("FAIL " ^ s ^ "\n")

  val dir = "tests/hs/syntax"

  (* ---- the parser's mutants ---- *)

  (* A mutant: an edit of a file of lib/language/haskell, which must occur
     `count` times, and the test that must catch it on some file of
     tests/hs/roundtrip: the token test (E10's five parser mutants,
     which the tree test cannot see, since both sides of it lose the field)
     or the exact print (a comment lost, which no token shows). *)
  type mutant = {name : string, file : string, old : string, new : string, count : int, catches : string}

  val mutants : mutant list =
    [{name = "parser drops where on a right-hand side", file = "parser.sml",
      old = "A.Rhs (ann s, A.Plain (e, w))", new = "A.Rhs (ann s, A.Plain (e, NONE))", count = 1, catches = "tok"},
     {name = "parser drops a fixity's precedence", file = "parser.sml",
      old = "else SOME (literal \"\")", new = "else (ignore (literal \"\"); NONE)", count = 1, catches = "tok"},
     {name = "parser drops a signature's context", file = "parser.sml",
      old = "A.DSig (vs, c, t)", new = "A.DSig (vs, NONE, t)", count = 1, catches = "tok"},
     {name = "parser drops ~ from patterns", file = "parser.sml",
      old = "| A.PLazy p => A.P (sp, A.PLazy (toPat false p))", new = "| A.PLazy p => toPat false p",
      count = 1, catches = "tok"},
     {name = "parser drops deriving", file = "parser.sml",
      old = "val d = deriving ()", new = "val d = (ignore (deriving ()); NONE)", count = 2, catches = "tok"},
     {name = "lexer drops a block comment", file = "lexer.sml",
      old = "loop 1; trivium (kind, a)", new = "loop 1; if kind = T.BlockComment then () else trivium (kind, a)",
      count = 1, catches = "exact"}]

  fun occurrences (text, s) =
    let
      fun go (i, k) =
        if i + size s > size text then k
        else if String.substring (text, i, size s) = s then go (i + size s, k + 1)
        else go (i + 1, k)
    in
      go (0, 0)
    end

  fun replaceAll (text, old, new) =
    let
      fun go (i, acc) =
        if i + size old > size text then String.concat (List.rev (String.extract (text, i, NONE) :: acc))
        else if String.substring (text, i, size old) = old then go (i + size old, new :: acc)
        else
          let val j = i + 1
          in go (j, String.substring (text, i, 1) :: acc) end
    in
      go (0, [])
    end

  fun slug s = String.translate (fn c => if Char.isAlphaNum c then str (Char.toLower c) else "-") s

  (* the files the mutants and the budget run on: those of tests/hs/roundtrip,
     which the syntax accepts *)
  fun corpus () =
    let
      fun under d =
        List.concat (List.map (fn n => let val p = d ^ "/" ^ n
                                       in if isDir p then under p
                                          else if String.isSuffix ".hs" n orelse String.isSuffix ".lhs" n then [p] else [] end)
                              (sort (entries d)))
    in
      under (fromRoot "tests/hs/roundtrip")
    end

  fun mutantOne ({name, file, old, new, count, catches} : mutant) =
    let
      val out = run ^ "/hs-syntax-mutants/" ^ slug name
      val lib = out ^ "/lib"
      val () = (rmTree out; mkdirs lib)
      val src = fromRoot "lib/language/haskell"
      val () =
        List.app (fn f => if String.isSuffix ".sml" f orelse f = "syntax.build" then write (lib ^ "/" ^ f, read (src ^ "/" ^ f)) else ())
          (entries src)
      val text = read (lib ^ "/" ^ file)
      val found = occurrences (text, old)
    in
      if found <> count then
        fail ("hs/syntax/mutants: " ^ name ^ ": its edit occurs " ^ Int.toString found ^ " times in " ^ file ^
              ", not " ^ Int.toString count ^ ": the mutant no longer applies")
      else
        let
          val () = write (lib ^ "/" ^ file, replaceAll (text, old, new))
          val () = write (out ^ "/driver.build",
                          "libraries unicode end\nuse lib/syntax.build\nfiles " ^ fromRoot (dir ^ "/generate.sml") ^ " " ^
                          fromRoot (dir ^ "/driver.sml") ^ " end\n")
          val built = exec {cmd = [fromRoot "bin/rune", "-O2", "--build", out ^ "/driver.build", "-o", out ^ "/driver.rbc"],
                            dir = NONE, stdin = "", stdout = out ^ "/build.out", stderr = out ^ "/build.err", timeout = 600}
        in
          if built <> 0 then fail ("hs/syntax/mutants: " ^ name ^ ": does not build: " ^ firstLine (out ^ "/build.err"))
          else
            let
              val files = corpus ()
              val _ = exec {cmd = [fromRoot "bin/runevm", "--equality-work", "2000000000", out ^ "/driver.rbc", "roundtrip"] @ files,
                            dir = NONE, stdin = "", stdout = out ^ "/roundtrip.tsv", stderr = out ^ "/roundtrip.err", timeout = 600}
              val rows = lines (read (out ^ "/roundtrip.tsv"))
              fun failing test = List.length (List.filter (fn r => String.isSubstring (test ^ "-DIFF") r) rows)
              val tree = failing "tree" val tok = failing "tok" val exact = List.length (List.filter (String.isSubstring "exact-DIFF") rows)
              val caught = if catches = "exact" then exact else tok
            in
              say ("mutant " ^ name ^ ": of " ^ Int.toString (length files) ^ " files, the tree test fails " ^ Int.toString tree ^
                   ", the token test " ^ Int.toString tok ^ ", the exact print " ^ Int.toString exact ^ "\n");
              if caught > 0 then ()
              else fail ("hs/syntax/mutants: " ^ name ^ ": uncaught: no file fails its " ^ catches ^ " test")
            end
        end
    end

  fun mutantsAll () = List.app mutantOne mutants

  (* ---- the cost of a token ---- *)

  (* The instructions, bytes and objects that lexing and parsing the files
     of tests/hs/roundtrip three times costs, less those of no time,
     by runevm --count, with spans and with every annotation; within the
     budget tests/hs/syntax/budget, which RUNE_TEST_ACCEPT=1 writes again
     at 10% over the counts. *)
  fun budget () =
    let
      val out = run ^ "/hs-syntax-budget"
      val () = mkdirs out
      val files = corpus ()
      fun counts (mode, rounds) =
        let
          val tag = mode ^ Int.toString rounds
          val _ = exec {cmd = [fromRoot "bin/runevm", "--count", fromRoot "bin/rune-hs-syntax.rbc"]
                              @ (if mode = "full" then ["--full"] else []) @ ["speed", Int.toString rounds] @ files,
                        dir = NONE, stdin = "", stdout = out ^ "/" ^ tag ^ ".out", stderr = out ^ "/" ^ tag ^ ".err", timeout = 600}
          val tokens =
            case List.find (String.isPrefix "tokens\t") (lines (read (out ^ "/" ^ tag ^ ".out"))) of
              SOME l => valOf (Int.fromString (String.extract (l, 7, NONE)))
            | NONE => 0
          val numbers = List.mapPartial Int.fromString (String.tokens (fn c => not (Char.isDigit c)) (countOf (out ^ "/" ^ tag ^ ".err")))
        in
          case numbers of
            [i, b, ob] => SOME (tokens, i, b, ob)
          | _ => NONE
        end
      fun measure mode =
        case (counts (mode, 0), counts (mode, 3)) of
          (SOME (_, i0, b0, ob0), SOME (t, i3, b3, ob3)) => SOME (t, i3 - i0, b3 - b0, ob3 - ob0)
        | _ => NONE
      val file = fromRoot (dir ^ "/budget")
      val kept = List.filter (fn l => String.isPrefix "#" l) (lines (read file))
      fun limit key =
        case List.find (fn l => String.isPrefix (key ^ " ") l) (lines (read file)) of
          SOME l => Int.fromString (String.extract (l, size key + 1, NONE))
        | NONE => NONE
      fun perToken (n, t) = Real.fmt (StringCvt.FIX (SOME 1)) (real n / real (Int.max (t, 1)))
      fun one mode =
        case measure mode of
          NONE => (fail ("hs/syntax/budget: " ^ mode ^ ": no counts from runevm --count"); [])
        | SOME (t, i, b, ob) =>
            (say (mode ^ ": " ^ Int.toString t ^ " tokens, per token " ^ perToken (i, t) ^ " instructions, " ^
                  perToken (b, t) ^ " bytes, " ^ perToken (ob, t) ^ " objects\n");
             if not accepting then
               List.app
                 (fn (key, n) =>
                    case limit (mode ^ " " ^ key) of
                      NONE => fail ("hs/syntax/budget: " ^ dir ^ "/budget has no " ^ mode ^ " " ^ key)
                    | SOME m =>
                        if key = "tokens" then
                          (if n = m then () else fail ("hs/syntax/budget: " ^ mode ^ ": " ^ Int.toString n ^
                                                       " tokens where the budget counted " ^ Int.toString m))
                        else if n > m then
                          fail ("hs/syntax/budget: " ^ mode ^ ": " ^ Int.toString n ^ " " ^ key ^ " over the budget's " ^ Int.toString m)
                        else ())
                 [("tokens", t), ("instructions", i), ("bytes", b), ("objects", ob)]
             else ();
             [mode ^ " tokens " ^ Int.toString t, mode ^ " instructions " ^ Int.toString (i + i div 10),
              mode ^ " bytes " ^ Int.toString (b + b div 10), mode ^ " objects " ^ Int.toString (ob + ob div 10)])
      val rows = one "spans" @ one "full"
    in
      if accepting then (write (file, String.concat (List.map (fn l => l ^ "\n") (kept @ rows))); say ("ACCEPTED " ^ file ^ "\n"))
      else ()
    end

  (* ---- GHC's parser as an independent check of the tree's shape ---- *)

  (* E10's check (the roadmap's section Round trips): GHC's dump of the parsed
     tree (-ddump-parsed, as Haskell 98) of a file, its LANGUAGE and OPTIONS
     pragmas blanked, is its dump of the explicit print of the file. A
     file whose source GHC refuses, with NondecreasingIndentation and
     without, is not compared. The files are those of tests/hs/roundtrip,
     and those a file named by RUNE_HS_SYNTAX_GHC_LIST names, a path a line,
     as E10's corpus; the differences known, each with its reason, are the
     lines of tests/hs/syntax/ghc-dump.tsv, each a path from the repository's
     root or from the corpus's, RUNE_HS_SYNTAX_GHC_ROOT. *)
  val ghcFlags = ["-c", "-fno-code", "-XHaskell98", "-ddump-parsed", "-dsuppress-all", "-dsuppress-uniques",
                  "-fforce-recomp", "-w"]

  (* the source with its LANGUAGE and OPTIONS pragmas made spaces, lines kept *)
  fun blankPragmas text =
    let
      val n = size text
      val out = CharArray.tabulate (n, fn i => String.sub (text, i))
      fun pragmaAt i = i + 2 < n andalso String.substring (text, i, 3) = "{-#"
      fun word i =
        let
          fun skip j = if j < n andalso Char.isSpace (String.sub (text, j)) then skip (j + 1) else j
          val a = skip (i + 3)
          fun take j = if j < n andalso (Char.isAlpha (String.sub (text, j)) orelse String.sub (text, j) = #"_") then take (j + 1) else j
        in
          String.map Char.toUpper (String.substring (text, a, take a - a))
        end
      fun close j = if j + 2 >= n then n else if String.substring (text, j, 3) = "#-}" then j + 3 else close (j + 1)
      fun go i =
        if i >= n then ()
        else if pragmaAt i andalso (String.isPrefix "LANGUAGE" (word i) orelse String.isPrefix "OPTIONS" (word i)) then
          let val e = close i
          in
            List.app (fn k => if String.sub (text, k) = #"\n" then () else CharArray.update (out, k, #" "))
              (List.tabulate (e - i, fn k => i + k));
            go e
          end
        else go (i + 1)
    in
      go 0; CharArray.vector out
    end

  (* GHC's dump of the file DIR/NAME, if it parses it *)
  fun ghcDump (work, name, extra) =
    let
      val out = work ^ "/" ^ name ^ ".ghc"
      val _ = exec {cmd = ["ghc"] @ ghcFlags @ extra @ [name], dir = SOME work, stdin = "", stdout = out,
                    stderr = out ^ ".err", timeout = 120}
      val text = read out
      val marker = "==================== Parser"
      fun find i = if i + size marker > size text then NONE
                   else if String.substring (text, i, size marker) = marker then SOME i else find (i + 1)
    in
      case find 0 of
        NONE => NONE
      | SOME i =>
          let val rest = String.extract (text, i, NONE)
          in SOME (case String.fields (fn c => c = #"\n") rest of _ :: body => String.concatWith "\n" body | [] => "") end
    end

  fun ghcCheck () =
    let
      val work = run ^ "/hs-syntax-ghc"
      val () = (rmTree work; mkdirs work)
      val known =
        List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of
                                   p :: why :: _ => if String.isPrefix "#" p then NONE else SOME (p, why)
                                 | _ => NONE)
          (lines (read (fromRoot (dir ^ "/ghc-dump.tsv"))))
      (* a line's path is from the repository's root, or from the corpus's,
         RUNE_HS_SYNTAX_GHC_ROOT *)
      val corpusRoot = env ("RUNE_HS_SYNTAX_GHC_ROOT", "")
      fun knownOf file =
        List.find (fn (p, _) => file = fromRoot p orelse (corpusRoot <> "" andalso file = corpusRoot ^ "/" ^ p)) known
      val listed =
        case env ("RUNE_HS_SYNTAX_GHC_LIST", "") of
          "" => []
        | f => lines (read f)
      (* E10's corpus has dotted module names, which bin/rune-hs-syntax
         reads with --hier; Haskell 98's files are read as rhc reads them *)
      val files = List.map (fn f => (f, false)) (corpus ()) @ List.map (fn f => (f, true)) listed
      val compared = ref 0
      val same = ref 0
      val refused = ref 0
      fun one (k, (file, hier)) =
        let
          val ext = if String.isSuffix ".lhs" file then ".lhs" else ".hs"
          val w = work ^ "/" ^ Int.toString k
          val () = mkdirs w
          val () = write (w ^ "/Source" ^ ext, blankPragmas (read file))
          val source =
            case ghcDump (w, "Source" ^ ext, ["-XNoNondecreasingIndentation"]) of
              SOME d => SOME d
            | NONE => ghcDump (w, "Source" ^ ext, ["-XNondecreasingIndentation"])
        in
          case source of
            NONE => refused := !refused + 1
          | SOME a =>
              let
                val status = exec {cmd = [fromRoot "bin/rune-hs-syntax"] @ (if hier then ["--hier"] else []) @ ["explicit", file],
                                   dir = NONE, stdin = "",
                                   stdout = w ^ "/Printed.hs", stderr = w ^ "/Printed.err", timeout = 120}
                val printed = if status = 0 then ghcDump (w, "Printed.hs", ["-XNoNondecreasingIndentation"]) else NONE
                val () = compared := !compared + 1
              in
                case (printed, knownOf file) of
                  (SOME b, NONE) =>
                    if a = b then same := !same + 1
                    else fail ("hs/syntax/ghc: GHC parses the explicit print of " ^ file ^ " to another tree than the file " ^
                               "(the dumps are in " ^ w ^ ")")
                | (SOME b, SOME (_, why)) =>
                    if a = b then fail ("hs/syntax/ghc: " ^ file ^ " is listed in " ^ dir ^ "/ghc-dump.tsv (" ^ why ^
                                        "), and GHC now parses its print to the same tree: remove the line")
                    else ()
                | (NONE, NONE) => fail ("hs/syntax/ghc: GHC refuses the explicit print of " ^ file ^ " (" ^ w ^ ")")
                | (NONE, SOME _) => ()
              end
        end
    in
      List.app one (ListPair.zip (List.tabulate (length files, fn k => k), files));
      say ("ghc: " ^ Int.toString (length files) ^ " files, " ^ Int.toString (!refused) ^ " GHC refuses, " ^
           Int.toString (!compared) ^ " compared, " ^ Int.toString (!same) ^ " the same\n")
    end

  (* GHC, the judge of E10's check *)
  val capabilities =
    [{name = "ghc", probe = "command -v ghc", hint = "install GHC (apt: ghc), whose parser checks the shape of rhc's trees (hs/syntax/ghc)"}]

  (* ---- the tree ---- *)

  fun job (name, cmd, timeout) =
    Test.it name
      {program = "/bin/sh", args = ["sh", "-c", "exec " ^ cmd],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds timeout, cap = 0, cpus = 1, memory = 500,
       pools = [], exclusive = false, after = [], judge = failLines} : Run.command Test.tree

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags

  val covers = ["covers:lib/language/haskell/*", "covers:tests/hs/syntax/*", "covers:tests/hs/roundtrip/*",
                "covers:tests/runner/hssyntax.sml", "covers:lib/unicode/*", "covers:src/rhc/*"]

  fun tree () =
    Test.describe "hs/syntax"
      [tagged (["check", "hs", "test-hs-syntax"] @ covers)
         (Test.describe ""
            [tagged ["quick"] (job ("errors", "bin/rune-hs-syntax errors " ^ dir ^ "/errors", 300)),
             tagged ["quick"] (job ("expansions", "bin/rune-hs-syntax expansions tests/hs/roundtrip", 300)),
             tagged ["quick"] (job ("generated", "bin/rune-hs-syntax generate 1 2000 3 && bin/rune-hs-syntax generate 5000 500 4", 600)),
             job ("mutants", "\"$RUNE_TEST_ROOT\"/bin/rune-test hs-syntax-mutants", 1800),
             job ("budget", "\"$RUNE_TEST_ROOT\"/bin/rune-test hs-syntax-budget", 600)]),
       Test.requires ["ghc"]
         (tagged (["nightly", "hs"] @ covers) (job ("ghc", "\"$RUNE_TEST_ROOT\"/bin/rune-test hs-syntax-ghc", 7200)))]

  fun command args =
    case args of
      ["hs-syntax-mutants"] => SOME mutantsAll
    | ["hs-syntax-budget"] => SOME budget
    | ["hs-syntax-ghc"] => SOME ghcCheck
    | _ => NONE
end

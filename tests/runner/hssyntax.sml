(* What the round trips of rhc (tests/runner/hsroundtrip.sml) and its
   refusals (tests/runner/hslang.sml) do not hold the syntax of Haskell 98
   to (tests/hs/syntax/README.md; the haskell98 roadmap's M11): the parser's
   mutants, each caught by the test that alone can see it; the layout of
   the files of tests/hs/roundtrip that have an expansion written by hand
   beside them; and the cost of a token. Each is a job of bin/rune-test or
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

  (* ---- the tree ---- *)

  fun job (name, cmd, timeout) =
    Test.it name
      {program = "/bin/sh", args = ["sh", "-c", "exec " ^ cmd],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds timeout, cap = 0, cpus = 1, memory = 500,
       pools = [], exclusive = false, after = [], judge = failLines} : Run.command Test.tree

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags

  val tree =
    tagged ["check", "hs", "test-hs-syntax", "covers:lib/language/haskell/*", "covers:tests/hs/syntax/*",
            "covers:tests/hs/roundtrip/*", "covers:tests/runner/hssyntax.sml", "covers:lib/unicode/*"]
      (Test.describe "hs/syntax"
        [tagged ["quick"] (job ("expansions", "bin/rune-hs-syntax expansions tests/hs/roundtrip", 300)),
         tagged ["quick"] (job ("generated", "bin/rune-hs-syntax generate 1 2000 3 && bin/rune-hs-syntax generate 5000 500 4", 600)),
         job ("mutants", "\"$RUNE_TEST_ROOT\"/bin/rune-test hs-syntax-mutants", 1800),
         job ("budget", "\"$RUNE_TEST_ROOT\"/bin/rune-test hs-syntax-budget", 600)])

  fun command args =
    case args of
      ["hs-syntax-mutants"] => SOME mutantsAll
    | ["hs-syntax-budget"] => SOME budget
    | _ => NONE
end

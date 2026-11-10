(* The round trips of rhc's parser and printers (docs/plans/language/haskell98.md,
   D28, M2; docs/testing.md, rhc's tests): on every file the parser
   accepts, two tests, and two more where the printers exist.

   - The tree test: the file printed with explicit braces parses to the
     tree the file does, its locations erased.
   - The token test: the tokens of that print are the tokens the layout
     algorithm makes of the file (the Report's L), but for empty items (a
     `;` after `{` or `;`, or before `}`) and a trailing comma before `)`.
     A parser that drops something from the tree prints without it, and the
     reparse agrees with itself: only this test sees it (E10's mutants).
   - The same two of the print with layout, the implicit print, since a
     printer that prints only braces never exercises L (D28).
   - The exact print of the file is the file, byte for byte (D28's C).

   A tool is the commands that do it, each given a file and writing to
   standard output: `print` (explicit braces), `implicit`, `exact`, `tokens`
   (L of the file: one token a line, a layout token as `{`, `;` or `}`),
   `tree` (the tree as text, locations erased), and `generate SEED COUNT
   DIR`, which writes `DIR/gen-K.hs`, the explicit print of a generated
   tree, and `DIR/gen-K.tree`, that tree (D55). What a tool lacks it leaves
   out. A command that refuses the file, or prints nothing for a file that
   is not empty, fails the test.

   rhc's tool is `bin/rhc`, an option for each command, over the files of
   tests/hs/lang, tests/hs/accept and tests/hs/roundtrip
   (`hs/roundtrip/rhc/PATH`, which need the capability `rhc`). The harness
   is held to its own tests without a parser: a stub tool, commands of
   bin/rune-test over a toy syntax of words written here, passes on
   tests/hs/runner/roundtrip (`hs/roundtrip/stub/...`); and the stub with a
   fault planted (`hs/roundtrip/@faults`) fails the test it must: a parser
   that drops `where` the token test alone, a printer that drops
   parentheses the tree test, an exact printer that drops a comment the
   exact test, a tree command that prints nothing, an implicit printer that
   swaps two items. `hs/roundtrip/@normalise` holds the token test's
   normalisation to examples. *)
structure HsRoundTrip =
struct
  open Sh

  type tool = {name : string, print : string, implicit : string option, exact : string option, tokens : string,
               tree : string, generate : string option}

  (* rhc's options are its driver's (src/rhc); a tool turns on a command
     here when rhc has it *)
  val rhc : tool =
    {name = "rhc", print = "bin/rhc --print", implicit = SOME "bin/rhc --print-layout", exact = SOME "bin/rhc --print-exact",
     tokens = "bin/rhc --dump-tokens", tree = "bin/rhc --dump-ast --no-spans", generate = NONE}
  fun stubWith fault : tool =
    let val c = "bin/rune-test hs-stub-syntax" ^ (if fault = "" then "" else " --fault " ^ fault) ^ " "
    in {name = "stub", print = c ^ "print", implicit = SOME (c ^ "implicit"), exact = SOME (c ^ "exact"),
        tokens = c ^ "tokens", tree = c ^ "tree", generate = SOME (c ^ "generate")} end
  val stub = stubWith ""
  val tools = [rhc, stub]
  val suffixes = [".hs", ".lhs"]

  (* ---- the token test's normalisation *)
  fun normalise (ts : string list) =
    let
      fun semis ([], acc) = List.rev acc
        | semis (";" :: r, acc) =
            (case (acc, r) of
               ([], _) => semis (r, acc)
             | ("{" :: _, _) => semis (r, acc)
             | (";" :: _, _) => semis (r, acc)
             | (_, "}" :: _) => semis (r, acc)
             | _ => semis (r, ";" :: acc))
        | semis ("}" :: r, ";" :: acc) = semis ("}" :: r, acc)
        | semis (t :: r, acc) = semis (r, t :: acc)
      (* a comma before `)` goes, but in a tuple's constructor, `(,)` *)
      fun commas ([], acc) = List.rev acc
        | commas ("," :: ")" :: r, acc as p :: _) =
            if p = "(" orelse p = "," then commas (")" :: r, "," :: acc) else commas (")" :: r, acc)
        | commas (t :: r, acc) = commas (r, t :: acc)
    in commas (semis (ts, []), []) end

  (* ---- one file *)
  datatype kind = Command | Empty | Tree | Token | Exact | Generated
  fun kindName k = case k of Command => "command" | Empty => "nothing printed" | Tree => "tree test" | Token => "token test"
                           | Exact => "exact test" | Generated => "generated tree"
  type failure = kind * string
  (* what a command printed, or why it did not *)
  datatype got = Got of string | Lost of failure list

  fun lineList text =
    case List.rev (String.fields (fn c => c = #"\n") text) of
      "" :: rest => List.rev rest
    | all => List.rev all
  fun firstDiff (a, b) =
    let
      fun go (n, x :: xs, y :: ys) = if x = y then go (n + 1, xs, ys) else SOME (n, x, y)
        | go (n, x :: _, []) = SOME (n, x, "(nothing)")
        | go (n, [], y :: _) = SOME (n, "(nothing)", y)
        | go (_, [], []) = NONE
    in go (1, a, b) end
  fun at (what, a, b) =
    case firstDiff (a, b) of
      SOME (n, x, y) => SOME (what ^ " " ^ Int.toString n ^ ": " ^ x ^ " / " ^ y)
    | NONE => NONE

  (* ---- the stub: a toy syntax of words *)
  (* A file of the stub is its words; its tree is the words, but for empty
     items and a trailing comma, which its parser drops; its explicit print
     writes an empty item after every `{`, so that its round trip passes
     only through the token test's normalisation *)
  fun stubWords file =
    let
      val text = read file
      val text = if String.isSuffix ".lhs" file then
                   String.concatWith "\n" (List.mapPartial (fn l => if String.isPrefix "> " l then SOME (String.extract (l, 2, NONE))
                                                                    else NONE) (String.fields (fn c => c = #"\n") text))
                 else text
    in String.tokens Char.isSpace text end
  fun stubParse (fault, ws) =
    let
      fun go ([], acc) = List.rev acc
        | go (";" :: r, acc) =
            if null acc orelse hd acc = "{" orelse hd acc = ";" orelse (case r of "}" :: _ => true | _ => false)
            then go (r, acc) else go (r, ";" :: acc)
        | go ("}" :: r, ";" :: acc) = go ("}" :: r, acc)
        | go ("," :: ")" :: r, acc) =
            if not (null acc) andalso (hd acc = "(" orelse hd acc = ",") then go (")" :: r, "," :: acc) else go (")" :: r, acc)
        | go ("where" :: r, acc) = if fault = "drops-where" then go (r, acc) else go (r, "where" :: acc)
        | go (w :: r, acc) = go (r, w :: acc)
    in go (ws, []) end
  (* what a command of the stub prints, given its words: [--fault F] MODE
     FILE, or generate SEED COUNT DIR, which writes the files and prints
     nothing *)
  fun stubOutput args =
    let
      val (fault, rest) = case args of "--fault" :: f :: rest => (f, rest) | _ => ("", args)
      fun items file = stubParse (fault, stubWords file)
      fun line ws = String.concatWith " " ws ^ "\n"
      fun printed ws =
        line (List.concat (List.map (fn "{" => ["{", ";"] | w => if fault = "drops-parens" andalso (w = "(" orelse w = ")") then []
                                                                  else [w]) ws))
      fun each ws = String.concat (List.map (fn w => w ^ "\n") ws)
    in
      case rest of
        ["tokens", file] => each (stubWords file)
      | ["tree", file] => if fault = "silent-tree" then "" else line (items file)
      | ["print", file] => printed (items file)
      | ["implicit", file] =>
          let val ws = items file
          in each (case (fault, ws) of ("implicit-swaps", a :: b :: r) => b :: a :: r | _ => ws) end
      | ["exact", file] =>
          if fault = "drops-comment" then
            String.concatWith "\n" (List.filter (fn l => not (String.isPrefix "--" l)) (String.fields (fn c => c = #"\n") (read file)))
          else read file
      | ["generate", seed, count, dir] =>
          let
            (* a fixed sequence of trees from the seed, of the words that
               need no normalising *)
            val vocabulary = Vector.fromList ["{", "}", "(", ")", "x", "f", "=", "where", "module", "M", "1", "+"]
            val state = ref (getOpt (Int.fromString seed, 1))
            fun next n = (state := (!state * 1103 + 12345) mod 65536; !state mod n)
            fun one k =
              let val ws = List.tabulate (4 + next 12, fn _ => Vector.sub (vocabulary, next (Vector.length vocabulary)))
                  val name = dir ^ "/gen-" ^ Int.toString k
              in write (name ^ ".hs", printed ws); write (name ^ ".tree", line ws) end
          in List.app one (List.tabulate (getOpt (Int.fromString count, 0), fn k => k + 1)); "" end
      | _ => raise Fail "hs-stub-syntax [--fault F] (tokens|tree|print|implicit|exact) FILE | generate SEED COUNT DIR"
    end

  (* How a tool's commands run: through the shell, from the root; or, for
     the stub's own checks, the stub's in this process, since a command of
     bin/rune-test starts slowly. The stub's jobs of a file run its
     commands through the shell, as rhc's are run. *)
  datatype how = Shell | Here
  val stubCommand = "bin/rune-test hs-stub-syntax"

  (* a tool's command on its arguments, its output in OUT and what it says
     in OUT.err; NONE where it failed *)
  fun runOn (how, command, args, out) =
    let val err = out ^ ".err"
    in
      case (how, String.tokens Char.isSpace command) of
        (Here, "bin/rune-test" :: "hs-stub-syntax" :: words) =>
          ((write (out, stubOutput (words @ args)); write (err, ""); SOME (read out))
           handle e => (write (err, exnMessage e ^ "\n"); NONE))
      | _ =>
          let
            val status = exec {cmd = ["/bin/sh", "-c", "exec " ^ command ^ String.concat (List.tabulate (length args, fn i => " \"$" ^ Int.toString (i + 1) ^ "\"")),
                                      "sh"] @ args,
                               dir = SOME root, stdin = "", stdout = out, stderr = err, timeout = 600}
          in if status = 0 then SOME (read out) else (append (err, "exit " ^ Int.toString status ^ "\n"); NONE) end
    end

  (* the failures of a tool on a file, its files in DIR *)
  fun one (how, tool : tool, dir, file) : failure list =
    let
      val () = (rmTree dir; mkdirs dir)
      fun f x = dir ^ "/" ^ x
      val nonEmpty = String.size (read (fromRoot file)) > 0
      fun get (what, command, input, out) =
        case runOn (how, command, [input], f out) of
          SOME text =>
            if text = "" andalso nonEmpty then Lost [(Empty, what ^ " prints nothing for " ^ input)]
            else Got text
        | NONE => Lost [(Command, what ^ " refuses " ^ input ^ ": " ^ firstNonEmpty (f out ^ ".err"))]
      val source = fromRoot file
    in
      case (get ("the tree command", #tree tool, source, "tree"), get ("the tokens command", #tokens tool, source, "tokens")) of
        (Lost a, Lost b) => a @ b
      | (Lost a, _) => a
      | (_, Lost b) => b
      | (Got tree0, Got tokens0) =>
          let
            (* a print, parsed again: the tree test and the token test *)
            fun trip (what, command, name) =
              let val printed = f name
              in
                case get (what, command, source, name) of
                  Lost fs => fs
                | Got _ =>
                    (case get ("the tree command", #tree tool, printed, name ^ ".tree") of
                       Lost fs => List.map (fn (_, m) => (Tree, what ^ ": " ^ m)) fs
                     | Got tree1 =>
                         (case at ("line", lineList tree0, lineList tree1) of
                            SOME d => [(Tree, what ^ " parses to another tree, at " ^ d)]
                          | NONE => []))
                    @ (case get ("the tokens command", #tokens tool, printed, name ^ ".tokens") of
                         Lost fs => List.map (fn (_, m) => (Token, what ^ ": " ^ m)) fs
                       | Got tokens1 =>
                           (case at ("token", normalise (lineList tokens0), normalise (lineList tokens1)) of
                              SOME d => [(Token, "the tokens of " ^ what ^ " are not layout's of the file, at " ^ d)]
                            | NONE => []))
              end
            val exact =
              case #exact tool of
                NONE => []
              | SOME command =>
                  case get ("the exact print", command, source, "exact") of
                    Lost fs => fs
                  | Got text =>
                      if text = read source then []
                      else [(Exact, "the exact print is not the file, at "
                                    ^ getOpt (at ("line", lineList (read source), lineList text), "its end"))]
          in
            trip ("the explicit print", #print tool, "print.hs")
            @ (case #implicit tool of SOME c => trip ("the implicit print", c, "implicit.hs") | NONE => [])
            @ exact
          end
    end

  fun toolNamed name =
    case List.find (fn (t : tool) => #name t = name) tools of
      SOME t => t
    | NONE => raise Fail ("hs-roundtrip: no tool " ^ name)
  fun scratchOf (tool : tool, id) = run ^ "/hs-roundtrip/" ^ #name tool ^ "/" ^ String.translate (fn #"/" => "_" | c => str c) id
  fun report fs = List.app (fn (k, m) => say ("FAIL " ^ kindName k ^ ": " ^ m ^ "\n")) fs

  (* the generated trees: each printed file parses to its tree, and goes
     round as a file does *)
  fun generated (how, tool : tool, seed, count) : failure list =
    case #generate tool of
      NONE => []
    | SOME command =>
        let
          val dir = scratchOf (tool, "@generated")
          val out = dir ^ "/files"
          val () = (rmTree dir; mkdirs out)
          val made = runOn (how, command, [seed, count, out], dir ^ "/generate")
          val files = List.filter (String.isSuffix ".hs") (sort (entries out))
        in
          if not (isSome made) then [(Command, "the generator refuses seed " ^ seed ^ ": " ^ firstNonEmpty (dir ^ "/generate.err"))]
          else if null files then [(Empty, "the generator wrote nothing for seed " ^ seed)]
          else
            List.concat (List.map (fn file =>
              let
                val path = out ^ "/" ^ file
                val expected = read (out ^ "/" ^ OS.Path.base file ^ ".tree")
                val tree = runOn (how, #tree tool, [path], dir ^ "/" ^ file ^ ".parsed")
                val here = case tree of
                             NONE => [(Command, "the tree command refuses generated " ^ file)]
                           | SOME t => (case at ("line", lineList expected, lineList t) of
                                          SOME d => [(Generated, file ^ " parses to another tree than it was printed from, at " ^ d)]
                                        | NONE => [])
              in here @ List.map (fn (k, m) => (k, file ^ ": " ^ m)) (one (how, tool, dir ^ "/" ^ file ^ ".trip", path)) end)
              files)
        end

  (* ---- the harness's own tests *)
  val stubInputs = ["tests/hs/runner/roundtrip/words.hs", "tests/hs/runner/roundtrip/literate.lhs"]
  (* each fault, the kind of failure it must give, and whether it may give
     a tree test's too *)
  val faults =
    [("drops-where", Token, false), ("drops-parens", Tree, true), ("drops-comment", Exact, false),
     ("silent-tree", Empty, false), ("implicit-swaps", Tree, true)]
  fun faultChecks () =
    List.app (fn (fault, kind, alsoTree) =>
                List.app (fn file =>
                            let
                              val fs = one (Here, stubWith fault, scratchOf (stub, "@faults/" ^ fault ^ "/" ^ file), file)
                              val kinds = List.map #1 fs
                            in
                              if not (List.exists (fn k => k = kind) kinds) then
                                say ("FAIL the stub that " ^ fault ^ " is not failed by the " ^ kindName kind ^ " on " ^ file ^ "\n")
                              else if not alsoTree andalso kind <> Tree andalso List.exists (fn k => k = Tree) kinds then
                                say ("FAIL the stub that " ^ fault ^ " fails the tree test on " ^ file ^ ", which cannot see it\n")
                              else ()
                            end)
                         stubInputs)
             faults
  fun normaliseChecks () =
    List.app (fn (input, expected) =>
                if normalise input = expected then ()
                else say ("FAIL normalise [" ^ String.concatWith " " input ^ "] = [" ^ String.concatWith " " (normalise input)
                          ^ "], not [" ^ String.concatWith " " expected ^ "]\n"))
             [(["{", ";", "a", ";", ";", "b", ";", "}"], ["{", "a", ";", "b", "}"]),
              ([";", "a", ";", "b"], ["a", ";", "b"]),
              (["{", "}"], ["{", "}"]),
              (["x", ";", ";", "}"], ["x", "}"]),
              (["(", "a", ",", "b", ",", ")"], ["(", "a", ",", "b", ")"]),
              (["(", ",", ")"], ["(", ",", ")"]),
              (["(", ",", ",", ")"], ["(", ",", ",", ")"]),
              (["[", "a", ",", "]"], ["[", "a", ",", "]"]),
              (["f", "(", "a", ",", ")", ";", "}"], ["f", "(", "a", ")", "}"])]

  fun command args =
    case args of
      ["hs-roundtrip-one", tool, file] =>
        SOME (fn () => let val t = toolNamed tool in report (one (Shell, t, scratchOf (t, file), file)) end)
    | ["hs-roundtrip-generated", tool, seed, count] =>
        SOME (fn () => report (generated (if tool = "stub" then Here else Shell, toolNamed tool, seed, count)))
    | ["hs-roundtrip-faults"] => SOME faultChecks
    | ["hs-roundtrip-normalise"] => SOME normaliseChecks
    | "hs-stub-syntax" :: rest => SOME (fn () => say (stubOutput rest))
    | _ => NONE

  (* ---- the tree *)
  (* the files of the suffixes under a directory, to any depth *)
  fun filesUnder dir =
    List.concat (List.map (fn n => let val p = dir ^ "/" ^ n
                                   in if isDir p then filesUnder p
                                      else if List.exists (fn s => String.isSuffix s n) suffixes then [p] else [] end)
                          (sort (entries dir)))
  val rhcInputs = List.concat (List.map filesUnder ["tests/hs/lang", "tests/hs/accept", "tests/hs/roundtrip"])
  fun job (path, args, timeout) =
    Test.it path
      {program = "/bin/sh",
       args = ["sh", "-c", "exec \"$RUNE_TEST_ROOT\"/bin/rune-test " ^ String.concatWith " " (List.map quote args)],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds timeout, cap = 0, cpus = 1, memory = 500,
       pools = [], exclusive = false, after = [], judge = failLines} : Run.command Test.tree
  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags
  (* a file's job, under its path from tests/hs *)
  fun fileJob (tool : tool) file =
    job (if String.isPrefix "tests/hs/" file then String.extract (file, size "tests/hs/", NONE) else file,
         ["hs-roundtrip-one", #name tool, file], 600)
  val rhcCovers = ["covers:tests/hs/lang/*", "covers:tests/hs/accept/*", "covers:tests/hs/roundtrip/*",
                   "covers:lib/language/haskell/*", "covers:src/rhc/*", "covers:tests/runner/hsroundtrip.sml"]
  val stubCovers = ["covers:tests/hs/runner/*", "covers:tests/runner/hsroundtrip.sml"]
  val tree =
    Test.describe "hs/roundtrip"
      [Test.requires ["rhc"]
         (tagged (["check", "hs"] @ rhcCovers)
            (Test.describe "rhc"
               (List.tabulate (length rhcInputs, fn i =>
                                 let val t = fileJob rhc (List.nth (rhcInputs, i))
                                 in if i mod 10 = 0 then Test.tag "quick" t else t end)
                @ (case #generate rhc of
                     SOME _ => [Test.tag "quick" (job ("@generated", ["hs-roundtrip-generated", "rhc", "1", "64"], 1800))]
                   | NONE => [])))),
       tagged (["check", "hs", "quick"] @ stubCovers)
         (Test.describe ""
            [Test.describe "stub"
               (List.map (fileJob stub) stubInputs @ [job ("@generated", ["hs-roundtrip-generated", "stub", "1", "16"], 600)]),
             job ("@faults", ["hs-roundtrip-faults"], 600),
             job ("@normalise", ["hs-roundtrip-normalise"], 60)])]
end

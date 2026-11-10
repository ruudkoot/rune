(* The names of rhc's programs (tests/hs/names/README.md; the haskell98
   roadmap's M12): for each fixture of tests/hs/names, a directory whose
   All.hs imports the rest, what `bin/rhc --dump-names` prints of it under
   each mode its expected files name, `least.names`, `greatest.names` or
   `dotted.names` (`--names=least` with `--dotted-names`); the mutants of
   names and fixity, each caught by some fixture; and for each fixture of
   tests/hs/types (M13), what `bin/rhc --dump-types` says of it under each
   setting of `--cycle-default`. Each is a job of bin/rune-test that prints
   a line FAIL for what it finds. *)
structure HsNames =
struct
  open Sh

  val accepting = env ("RUNE_TEST_ACCEPT", "") = "1"
  fun fail s = say ("FAIL " ^ s ^ "\n")

  val dir = "tests/hs/names"

  val modes = ["least", "greatest", "dotted"]

  fun flags mode =
    case mode of
      "greatest" => ["--names=greatest"]
    | "dotted" => ["--names=least", "--dotted-names"]
    | _ => ["--names=least"]

  (* the fixtures, and the modes each has an expected file of *)
  fun fixtures () =
    List.filter (fn (_, ms) => not (null ms))
      (List.map (fn d => (d, List.filter (fn m => exists (fromRoot (dir ^ "/" ^ d ^ "/" ^ m ^ ".names"))) modes))
         (List.filter (fn d => exists (fromRoot (dir ^ "/" ^ d ^ "/All.hs"))) (sort (entries (fromRoot dir)))))

  (* the modules of a fixture's program, by its files: A/B.hs is A.B *)
  fun programModules d =
    let
      fun under (path, prefix) =
        List.concat
          (List.map
             (fn n =>
                let val p = path ^ "/" ^ n
                in
                  if isDir p then under (p, prefix ^ n ^ ".")
                  else if String.isSuffix ".hs" n then [prefix ^ String.substring (n, 0, size n - 3)]
                  else if String.isSuffix ".lhs" n then [prefix ^ String.substring (n, 0, size n - 4)]
                  else []
                end)
             (entries path))
    in
      under (d, "")
    end

  (* whether a line of the dump names a module of the program: its module,
     an entity's, or an error's place *)
  fun mentions (mods, line) =
    let
      fun ofField f =
        List.exists (fn m => f = m orelse String.isPrefix ("v" ^ m ^ " ") f orelse String.isPrefix ("t" ^ m ^ " ") f
                             orelse String.isPrefix (m ^ ":") f) mods
    in
      case String.fields (fn c => c = #"\t") line of
        _ :: fields => List.exists ofField fields
      | [] => false
    end

  (* What a fixture's expected file holds: `pairs N`, the count of
     EXPORT lines, and the lines that name a module of the program, or
     every line where the file's first line is `# whole`. *)
  fun view (whole, mods, dump) =
    let val pairs = List.length (List.filter (String.isPrefix "EXPORT\t") dump)
    in ("pairs " ^ Int.toString pairs) :: (if whole then dump else List.filter (fn l => mentions (mods, l)) dump) end

  (* `check (driver, fixture, mode, out)`: NONE where the driver's dump of
     the fixture is what its expected file says, or the failure; with
     RUNE_TEST_ACCEPT=1 the file is written again *)
  fun check (driver : string list, fixture, mode, out) =
    let
      val d = fromRoot (dir ^ "/" ^ fixture)
      val file = d ^ "/" ^ mode ^ ".names"
      val expected = lines (read file)
      val comments = List.filter (String.isPrefix "#") expected
      val whole = List.exists (fn l => l = "# whole") comments
      val () = mkdirs out
      val stdout = out ^ "/" ^ fixture ^ "-" ^ mode ^ ".dump"
      val status = exec {cmd = driver @ flags mode @ [d ^ "/All.hs"], dir = NONE, stdin = "", stdout = stdout,
                         stderr = stdout ^ ".err", timeout = 300}
      val got = view (whole, programModules d, lines (read stdout))
      val want = List.filter (fn l => not (String.isPrefix "#" l)) expected
    in
      if status <> 0 then SOME ("the dump of " ^ fixture ^ " (" ^ mode ^ ") fails: " ^ firstLine (stdout ^ ".err"))
      else if accepting andalso driver = [fromRoot "bin/rhc", "--dump-names"] then
        (write (file, String.concat (List.map (fn l => l ^ "\n") (comments @ got))); say ("ACCEPTED " ^ file ^ "\n"); NONE)
      else if got = want then NONE
      else
        let
          fun missing (xs, ys) = List.filter (fn x => not (List.exists (fn y => y = x) ys)) xs
          fun some xs = String.concatWith "; " (List.take (xs, Int.min (3, length xs)))
          val (lost, gained) = (missing (want, got), missing (got, want))
        in
          SOME (fixture ^ " (" ^ mode ^ "): " ^ Int.toString (length lost) ^ " expected lines not printed" ^
                (if null lost then "" else " (" ^ some lost ^ ")") ^ ", " ^ Int.toString (length gained) ^ " printed not expected" ^
                (if null gained then "" else " (" ^ some gained ^ ")") ^ "; the dump is " ^ stdout)
        end
    end

  fun one (fixture, mode) =
    case check ([fromRoot "bin/rhc", "--dump-names"], fixture, mode, run ^ "/hs-names") of
      NONE => ()
    | SOME msg => fail ("hs/names/" ^ msg)

  (* ---- the mutants of names and fixity ---- *)

  (* A mutant: an edit of a file of lib/language/haskell (`lib/`) or of
     src/rhc (`src/`), which must occur `count` times, and must make some
     fixture's dump differ. *)
  type mutant = {name : string, file : string, old : string, new : string, count : int}

  val mutants : mutant list =
    [{name = "greatest for least fixpoint", file = "lib/modules.sml",
      old = "        case fixpoint of\n          Least =>", new = "        case (ignore fixpoint; Greatest) of\n          Least =>",
      count = 1},
     {name = "a hidden module importable", file = "src/library.sml",
      old = "fun isHidden m = List.exists (fn h => h = m) hidden", new = "fun isHidden (_ : string) = false", count = 1},
     {name = "fixity read before names", file = "src/names.sml",
      old = "HsFixity.resolve {fixityOf = fixityOf} (#module r)",
      new = "HsFixity.resolve {fixityOf = fn {name, ...} : A.qname => Option.map #2 (List.find (fn (k, _) => " ^
            "String.isSuffix (\"\\t\" ^ name) k) (M.listItems fixTable))} (#ast n)",
      count = 1}]

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
        else go (i + 1, String.substring (text, i, 1) :: acc)
    in
      go (0, [])
    end

  fun slug s = String.translate (fn c => if Char.isAlphaNum c then str (Char.toLower c) else "-") s

  val rhcFiles = ["library.sml", "graph.sml", "names.sml"]

  fun mutantOne ({name, file, old, new, count} : mutant) =
    let
      val out = run ^ "/hs-names-mutants/" ^ slug name
      val () = (rmTree out; mkdirs (out ^ "/lib"); mkdirs (out ^ "/src"))
      val lib = fromRoot "lib/language/haskell"
      val () =
        List.app (fn f => if String.isSuffix ".sml" f orelse String.isSuffix ".build" f andalso f <> "library.build"
                          then write (out ^ "/lib/" ^ f, read (lib ^ "/" ^ f)) else ())
          (entries lib)
      val () = List.app (fn f => write (out ^ "/src/" ^ f, read (fromRoot ("src/rhc/" ^ f)))) rhcFiles
      val target = out ^ "/" ^ file
      val text = read target
      val found = occurrences (text, old)
    in
      if found <> count then
        fail ("hs/names/mutants: " ^ name ^ ": its edit occurs " ^ Int.toString found ^ " times in " ^ file ^ ", not " ^
              Int.toString count ^ ": the mutant no longer applies")
      else
        let
          val () = write (target, replaceAll (text, old, new))
          val () = write (out ^ "/driver.build",
                          "libraries unicode end\nuse lib/syntax.build\nuse lib/names.build\nuse lib/types.build\nfiles " ^
                          String.concatWith " " (List.map (fn f => "src/" ^ f) rhcFiles) ^ " " ^
                          fromRoot (dir ^ "/driver.sml") ^ " end\n")
          val built = exec {cmd = [fromRoot "bin/rune", "--build", out ^ "/driver.build", "-o", out ^ "/driver.rbc"],
                            dir = NONE, stdin = "", stdout = out ^ "/build.out", stderr = out ^ "/build.err", timeout = 900}
        in
          if built <> 0 then fail ("hs/names/mutants: " ^ name ^ ": does not build: " ^ firstLine (out ^ "/build.err"))
          else
            let
              val driver = [fromRoot "bin/runevm", out ^ "/driver.rbc", "--share", fromRoot "share/rhc"]
              val caught =
                List.mapPartial (fn x => x)
                  (List.concat (List.map (fn (f, ms) => List.map (fn m => Option.map (fn _ => f ^ " (" ^ m ^ ")")
                                                                                  (check (driver, f, m, out))) ms)
                                  (fixtures ())))
            in
              say ("mutant " ^ name ^ ": caught by " ^ (if null caught then "nothing" else String.concatWith ", " caught) ^ "\n");
              if null caught then fail ("hs/names/mutants: " ^ name ^ ": uncaught: every fixture's dump is as expected") else ()
            end
        end
    end

  fun mutantsAll () = List.app mutantOne mutants

  (* ---- the types of programs (M13) ---- *)

  (* The fixtures of tests/hs/types, each a directory whose All.hs imports
     the rest, with what `bin/rhc --dump-types --cycle-default=MODE` says of
     it, standard error's lines first, in `module.types` and `scc.types`. *)
  val typesDir = "tests/hs/types"
  val typeModes = ["module", "scc"]

  fun typeFixtures () =
    List.filter (fn (_, ms) => not (null ms))
      (List.map (fn d => (d, List.filter (fn m => exists (fromRoot (typesDir ^ "/" ^ d ^ "/" ^ m ^ ".types"))) typeModes))
         (List.filter (fn d => exists (fromRoot (typesDir ^ "/" ^ d ^ "/All.hs"))) (sort (entries (fromRoot typesDir)))))

  fun checkTypes (fixture, mode) =
    let
      val d = fromRoot (typesDir ^ "/" ^ fixture)
      val file = d ^ "/" ^ mode ^ ".types"
      val expected = lines (read file)
      val comments = List.filter (String.isPrefix "#") expected
      val out = run ^ "/hs-types"
      val () = mkdirs out
      val stdout = out ^ "/" ^ fixture ^ "-" ^ mode ^ ".out"
      val stderr = out ^ "/" ^ fixture ^ "-" ^ mode ^ ".err"
      val _ = exec {cmd = [fromRoot "bin/rhc", "--dump-types", "--cycle-default=" ^ mode, d ^ "/All.hs"], dir = NONE, stdin = "",
                    stdout = stdout, stderr = stderr, timeout = 300}
      fun relative l = if String.isPrefix (root ^ "/") l then String.extract (l, size root + 1, NONE) else l
      val got = List.map relative (lines (read stderr)) @ lines (read stdout)
      val want = List.filter (fn l => not (String.isPrefix "#" l)) expected
    in
      if accepting then (write (file, String.concat (List.map (fn l => l ^ "\n") (comments @ got))); say ("ACCEPTED " ^ file ^ "\n"))
      else if got = want then ()
      else
        let
          fun missing (xs, ys) = List.filter (fn x => not (List.exists (fn y => y = x) ys)) xs
          fun some xs = String.concatWith "; " (List.take (xs, Int.min (3, length xs)))
          val (lost, gained) = (missing (want, got), missing (got, want))
        in
          fail ("hs/types/" ^ fixture ^ " (" ^ mode ^ "): " ^ Int.toString (length lost) ^ " expected lines not printed" ^
                (if null lost then "" else " (" ^ some lost ^ ")") ^ ", " ^ Int.toString (length gained) ^ " printed not expected" ^
                (if null gained then "" else " (" ^ some gained ^ ")") ^ "; the output is " ^ stdout)
        end
    end

  (* ---- the tree ---- *)

  fun job (name, cmd, timeout) =
    Test.it name
      {program = "/bin/sh", args = ["sh", "-c", "exec " ^ cmd],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds timeout, cap = 0, cpus = 1, memory = 500,
       pools = [], exclusive = false, after = [], judge = failLines} : Run.command Test.tree

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags

  val covers = ["covers:lib/language/haskell/*", "covers:src/rhc/*", "covers:share/rhc/*", "covers:tests/hs/names/*",
                "covers:tests/hs/types/*",
                "covers:tests/runner/hsnames.sml", "covers:rhc.build", "covers:rhc.plan"]

  fun tree () =
    Test.describe ""
      [Test.describe "hs/names"
         [tagged (["hs"] @ covers)
            (Test.describe ""
               (List.concat
                  (List.map (fn (f, ms) =>
                               List.map (fn m => tagged ["check", "quick"]
                                                   (job (f ^ "/" ^ m, "\"$RUNE_TEST_ROOT\"/bin/rune-test hs-names " ^ f ^ " " ^ m, 600)))
                                 ms)
                     (fixtures ()))
                (* the mutants nightly (the roadmap's D56, the lead's ruling 45) *)
                @ [Test.tag "nightly" (job ("mutants", "\"$RUNE_TEST_ROOT\"/bin/rune-test hs-names-mutants", 3600))]))],
       Test.describe "hs/types"
         [tagged (["check", "hs"] @ covers)
            (Test.describe ""
               (List.concat
                  (List.map (fn (f, ms) =>
                               List.map (fn m => tagged ["quick"]
                                                   (job (f ^ "/" ^ m, "\"$RUNE_TEST_ROOT\"/bin/rune-test hs-types " ^ f ^ " " ^ m, 600)))
                                 ms)
                     (typeFixtures ()))))]]

  fun command args =
    case args of
      ["hs-names", fixture, mode] => SOME (fn () => one (fixture, mode))
    | ["hs-names-mutants"] => SOME mutantsAll
    | ["hs-types", fixture, mode] => SOME (fn () => checkTypes (fixture, mode))
    | _ => NONE
end

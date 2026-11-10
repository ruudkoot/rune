(* rhc's mutants (D55; the haskell98 roadmap's *rhc's mutants*;
   docs/testing.md, rhc's mutants): which job sees which bug seeded in rhc.
   CompilerMutants' machinery with rhc in Rune's place: a mutant
   (tests/runner/hsmutantlist.sml) is exact edits of rhc's sources, built by
   the good Rune from rhc.plan's files (CompilerMutants.buildFrom; rhc never
   compiles itself, so there is no stage two), into an rhc of its own.

   Its corpus is rhc's suites, an even sample of the files of tests/hs/accept,
   errors and lang: what rhc says of each by the commands that show a stage
   (its tokens, its tree, its check), against what the good rhc says. An
   output that differs exercises the mutant. What must see it are the jobs
   it names, run as they are in a tree of the root's files in which bin/rhc is
   the mutant's (links but for bin/rhc.rbc and tests/out): one of them failing
   is CAUGHT; none, UNCAUGHT, or UNEXERCISED where no output differs; a
   mutant that does not build is STILLBORN. Each but CAUGHT fails its job,
   and a job named that does not run (no such job, or one held while its
   rows are Planned) fails it too: an UNCAUGHT mutant is a missing test or a
   redundant line of code, settled as one or the other.

   Jobs: prepare (each mutant's old text once in a file of rhc.plan) and
   built-ID (it builds), the first in make check, a canary that holds the
   mutants to the sources, and the rest with good, ID and final in the tier
   test-rhc-mutants (make test-rhc-mutants, nightly). HS_MUTANTS=HL01,HP02 runs those alone.
   `bin/rune-test hs-mutant-tree ID` builds a mutant and its tree and says
   where, for any job to be run against it by hand. *)
structure HsMutants =
struct
  open Sh
  exception Failed of string
  fun need (ok, why) = if ok then () else raise Failed why
  type mutant = HsMutantList.mutant

  fun dirOf name = run ^ "/hs-mutants/" ^ name
  val vm = fromRoot "bin/runevm"
  val good = fromRoot "bin/rhc.rbc"
  fun selected () =
    case String.tokens (fn c => c = #",") (env ("HS_MUTANTS", "")) of
      [] => HsMutantList.mutants
    | ids => List.filter (fn (m : mutant) => List.exists (fn i => i = #id m) ids) HsMutantList.mutants
  fun named id = case List.find (fn (m : mutant) => #id m = id) HsMutantList.mutants of
                   SOME m => m
                 | NONE => raise Failed ("no mutant " ^ id)
  fun slug s = String.translate (fn #"/" => "_" | c => str c) s

  (* rhc's sources, in the order rhc.plan gives them *)
  fun sources tag =
    let
      val out = dirOf (tag ^ ".sources")
      val () = mkdirs (dirOf "")
      val code = Children.exec Subprocess.unlimited (fn e => e)
                   {cmd = ["sh", "scripts/plan-files.sh", "rhc.plan"], dir = SOME root, stdin = "", stdout = out,
                    stderr = out ^ ".err", timeout = 60}
    in
      need (code = 0, "scripts/plan-files.sh rhc.plan failed: " ^ firstNonEmpty (out ^ ".err"));
      String.tokens Char.isSpace (read out)
    end
  fun build (m : mutant) =
    CompilerMutants.buildFrom {id = #id m, edits = #edits m, srcs = sources (#id m), dir = dirOf (#id m), out = "rhc.rbc"}

  (* ---- the corpus *)
  val sample = 160
  fun corpus () =
    let
      val files = List.concat (List.map (fn d => glob ("tests/hs/" ^ d, ".hs") @ glob ("tests/hs/" ^ d, ".lhs"))
                                        ["accept", "errors", "lang"])
    in CompilerMutants.evenSample (files, sample) end
  val commands = [("tokens", ["--dump-tokens"]), ("tree", ["--dump-ast", "--no-spans"]), ("check", ["--typecheck-only"])]
  (* what an rhc says of each file of the corpus: lines FILE TAB COMMAND TAB
     its exit, its output's hash and its first line of error *)
  fun outputs (rbc, scratch) =
    let
      val () = (rmTree scratch; mkdirs scratch)
      val out = scratch ^ "/out"
      val err = scratch ^ "/err"
      fun one file (k, args) =
        let val code = CompilerMutants.execute (60, [vm, rbc] @ args @ [file], root, "", out, err)
        in String.concatWith "\t" [file, k, Int.toString code, CompilerMutants.hash out, CompilerMutants.errLine (read err)] end
    in List.concat (List.map (fn f => List.map (one f) commands) (corpus ())) before rmTree scratch end

  (* ---- a tree in which bin/rhc is the mutant's *)
  fun mutantTree (d, rbc) =
    let
      val t = d ^ "/tree"
      val () = (rmTree t; mkdirs (t ^ "/bin"); mkdirs (t ^ "/tests/out"))
      fun link (dir, except) =
        List.app (fn e => if List.exists (fn x => x = e) except then ()
                          else Posix.FileSys.symlink {old = root ^ "/" ^ dir ^ e, new = t ^ "/" ^ dir ^ e})
                 (entries (root ^ "/" ^ dir))
      val () = (link ("", ["bin", "tests"]); link ("bin/", ["rhc.rbc"]); link ("tests/", ["out"]))
      val code = exec {cmd = ["cp", rbc, t ^ "/bin/rhc.rbc"], dir = NONE, stdin = "", stdout = "", stderr = "", timeout = 60}
    in need (code = 0, "cannot copy " ^ rbc); t end

  (* a job run in the tree as make check runs it: its verdict there, or
     "none" where the run has no such job *)
  fun runJob (t, job) =
    let
      val out = t ^ "/../job-" ^ slug job
      val _ = Children.exec (CompilerMutants.limits 1800)
                (fn e => setEnv ("RUNE_TEST_ROOT", t) (unsetEnv ["RUNE_TEST_RUN", "RUNE_TEST_ACCEPT", "HS_MUTANTS"] e))
                {cmd = [t ^ "/bin/rune-test", "run", job], dir = SOME t, stdin = "", stdout = out, stderr = out, timeout = 1800}
      val said = read out
      val events =
        case CompilerMutants.places (said, "events in ") of
          i :: _ => SOME (hd (String.tokens (fn c => c = #";" orelse c = #"," orelse Char.isSpace c) (String.extract (said, i + 10, NONE))))
        | [] => NONE
      val key = "\"path\":\"" ^ job ^ "\""
    in
      case events of
        NONE => "none"
      | SOME e =>
          case List.find (String.isSubstring key) (lines (read (if OS.Path.isAbsolute e then e else t ^ "/" ^ e))) of
            NONE => "none"
          | SOME l => List.foldl (fn (v, acc) => if String.isSubstring ("\"verdict\":\"" ^ v ^ "\"") l then v else acc)
                                 "?" ["PASS", "FAIL", "SKIP", "ERROR"]
    end

  (* ---- the jobs *)
  fun prepare () =
    let
      val srcs = sources "prepare"
      val ms = HsMutantList.mutants
    in
      List.app (fn (m : mutant) =>
                  (need (length (List.filter (fn (n : mutant) => #id n = #id m) ms) = 1, #id m ^ " is twice");
                   need (not (null (#caughtBy m)), #id m ^ " names no job to catch it");
                   List.app (fn {file, old, ...} =>
                               (need (List.exists (fn s => s = file) srcs, #id m ^ ": " ^ file ^ " is no file of rhc.plan");
                                need (length (CompilerMutants.places (read (fromRoot file), old)) = 1,
                                      #id m ^ ": its old text is not in " ^ file ^ " once")))
                            (#edits m)))
               ms;
      say ("PASS hs-mutants: prepared " ^ Int.toString (length ms) ^ " mutants\n")
    end

  fun builtJob id () =
    let val (rbc, status) = build (named id)
    in
      rmTree (dirOf id);
      need (isSome rbc, id ^ " no longer compiles: " ^ status);
      say ("PASS hs-mutants: " ^ id ^ " builds\n")
    end

  fun goodJob () =
    (need (exists good, "no bin/rhc.rbc");
     write (dirOf "good.tsv", String.concat (List.map (fn l => l ^ "\n") (outputs (good, dirOf "good-scratch"))));
     say ("PASS hs-mutants: the good rhc on " ^ Int.toString (length (corpus ())) ^ " files\n"))

  fun mutantJob id () =
    let
      val m = named id
      val d = dirOf id
      val (rbc, status) = build m
      fun verdict text = (mkdirs (dirOf "verdicts"); write (dirOf "verdicts/" ^ id, text ^ "\n"); say (text ^ "\n"))
      val what = id ^ " (" ^ #stage m ^ ": " ^ #note m ^ ")"
    in
      case rbc of
        NONE => (verdict ("STILLBORN " ^ what ^ ": " ^ status); raise Failed (id ^ " no longer compiles: " ^ status))
      | SOME rbc =>
          let
            val goodLines = lines (read (dirOf "good.tsv"))
            val mine = outputs (rbc, d ^ "/scratch")
            val () = need (length goodLines = length mine, "the good rhc's outputs are not this corpus's: rerun hs-mutants/good")
            val differ = length (List.filter (fn (a, b) => a <> b) (ListPair.zip (goodLines, mine)))
            val t = mutantTree (d, rbc)
            val ran = List.map (fn j => (j, runJob (t, j))) (#caughtBy m)
            val unrun = List.filter (fn (_, v) => v <> "PASS" andalso v <> "FAIL") ran
            val caught = List.filter (fn (_, v) => v = "FAIL") ran
            val exercised = Int.toString differ ^ " of " ^ Int.toString (length mine) ^ " outputs differ"
          in
            List.app (fn (j, v) => say ("FAIL hs-mutants: " ^ id ^ " names " ^ j ^ ", which "
                                        ^ (if v = "none" then "is no job" else "does not run (" ^ v ^ ")") ^ "\n")) unrun;
            case caught of
              (j, _) :: _ => verdict ("CAUGHT " ^ what ^ " by " ^ j ^ "; " ^ exercised)
            | [] =>
                if differ = 0 then (verdict ("UNEXERCISED " ^ what ^ ": no output of the corpus differs");
                                    say ("FAIL hs-mutants: " ^ id ^ " is unexercised\n"))
                else (verdict ("UNCAUGHT " ^ what ^ "; " ^ exercised ^ ", and the jobs it names pass");
                      say ("FAIL hs-mutants: " ^ id ^ " is uncaught\n"));
            rmTree t
          end
    end

  fun final () =
    let
      val vs = List.map (fn (m : mutant) => firstNonEmpty (dirOf ("verdicts/" ^ #id m))) (selected ())
      val text = String.concat (List.map (fn v => (if v = "" then "no verdict" else v) ^ "\n") vs)
    in
      write (fromRoot "tests/out/hs-mutants.txt", text);
      say ("PASS hs-mutants: " ^ Int.toString (length (List.filter (String.isPrefix "CAUGHT") vs)) ^ " of "
           ^ Int.toString (length vs) ^ " caught (tests/out/hs-mutants.txt)\n")
    end

  fun treeCommand id () =
    let val m = named id
        val (rbc, status) = build m
    in
      need (isSome rbc, id ^ " does not build: " ^ status);
      say ("hs-mutants: " ^ id ^ "'s tree is " ^ mutantTree (dirOf id, valOf rbc)
           ^ "\n  run a job against it: RUNE_TEST_ROOT=THAT THAT/bin/rune-test run JOB, with RUNE_TEST_RUN unset\n")
    end

  fun protect f () = f () handle Failed why => say ("FAIL hs-mutants: " ^ why ^ "\n")
  fun command args =
    case args of
      ["hs-mutants-prepare"] => SOME (protect prepare)
    | ["hs-mutant-built", id] => SOME (protect (builtJob id))
    | ["hs-mutants-good"] => SOME (protect goodJob)
    | ["hs-mutant", id] => SOME (protect (mutantJob id))
    | ["hs-mutants-final"] => SOME (protect final)
    | ["hs-mutant-tree", id] => SOME (protect (treeCommand id))
    | _ => NONE

  val covers = ["covers:lib/language/haskell/*", "covers:src/rhc/*", "covers:rhc.build", "covers:rhc.plan",
                "covers:tests/runner/hsmutant*", "covers:tests/runner/compilermutants.sml"]
  fun tree () =
    let
      val ms = List.map #id (selected ())
      val job = CompilerMutants.job
      val nightly = Test.tag "test-rhc-mutants" o Test.requires ["rhc"]
    in
      List.foldl (fn (c, t) => Test.tag c t)
        (Test.describe "hs-mutants"
           (Test.tag "test-rhc-mutants" (Test.tag "check" (job ("prepare", ["hs-mutants-prepare"], [], 300)))
            (* the first mutant's build in make check, a canary of the
               sources; the others' with their runs (the roadmap's D56, the
               lead's ruling 45) *)
            :: List.map (fn i => Test.tag (if SOME i = List.find (fn _ => true) ms then "check" else "test-rhc-mutants")
                                   (job ("built-" ^ i, ["hs-mutant-built", i], ["hs-mutants/prepare"], 1500))) ms
            @ List.map nightly
                (job ("good", ["hs-mutants-good"], ["hs-mutants/prepare"], 1500)
                 :: List.map (fn i => job (i, ["hs-mutant", i], ["hs-mutants/good"], 2500)) ms
                 @ [job ("final", ["hs-mutants-final"], List.map (fn i => "hs-mutants/" ^ i) ms, 300)])))
        covers
    end
end

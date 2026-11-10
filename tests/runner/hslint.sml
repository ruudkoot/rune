(* HsLint on rhc's programs (the haskell98 roadmap's M16, D54;
   docs/testing.md, rhc's tests): its second inference held to what it
   must find, by `bin/rhc --dump-hslint`, which prints what it infers or
   REFUSED and why. Each is a job of bin/rune-test that prints a line FAIL
   for what it finds.

   - `hs/hslint/dump/NAME[/MODE]`: each program of tests/hs/hslint, a file
     `NAME.hs` or a directory `NAME` with its `Main.hs`, against
     `NAME.expected`, and under `--cycle-default=scc` against
     `NAME.scc.expected`, with the library's unsigned bindings
     (`--dump-hslint=library`) against `NAME.library.expected`, where
     those are; reviewed line by line, and written again with --accept.
     Then the checker on it at level 2 (`--typecheck-only --lint=2`),
     where HsLint replays its records and holds them to the second
     inference: it accepts what the dump infers and refuses, with its own
     error, what the dump refuses, so that a bug seeded in the checker
     that its records show (rhc's mutants HK01 to HK05) fails the job.
   - `hs/hslint/accept/K-of-N`, `hs/hslint/lang/K-of-N`: every program of
     tests/hs/accept and tests/hs/lang infers, whatever its rows' status,
     since the second inference does not wait on the checker; a program
     whose names rhc refuses is noted, not judged.
   - `hs/hslint/errors/K-of-N`: every program of tests/hs/errors whose row
     is of the classes static, prelude or library, the type errors, is
     refused, by HsLint or before it.

   The programs of a directory are judged in `shards` jobs, the K-th
   taking every N-th program from the K-th, since a job of bin/rune-test
   costs several times what rhc does on one program; each prints a line
   FAIL for each program it fails, and `bin/rune-test hs-hslint-expect
   KIND NAME` judges one. The first shard of each is make check's, the
   others nightly (the roadmap's D56, the lead's ruling 45).

   - `hs/hslint/faults`: each rule of HsLint's comparison and of its replay
     refuses its fault (as `astlintFaults` holds AstLint's):
     tests/hs/hslint/faults.hs, its checker's records replayed and held to
     the second inference, and held by `--hslint-claims` to its own expected
     dump, is accepted, and with RHC_HSLINT_FAULT=RULE, which reads the
     first claim or record RULE checks corrupted, refused with `lint after
     hslint` and `[RULE]`; and the faults are the rules `bin/rhc
     --hslint-rules` names, both ways.

   The same jobs run the checker alone (`--typecheck-only --lint=off`)
   beside HsLint's second inference alone, and want one verdict of the two
   judges; tests/hs/hslint/judges.tsv lists where they part, each with why.

   A program on which HsLint and its expectation disagree is a finding: a
   reading, a bug of HsLint's, or a program that does not mean what it
   says. tests/hs/hslint/disagreements.tsv lists those not settled yet,
   each with why, and its job holds the disagreement to still being there,
   so that a fix on either side is seen. *)
structure HsLintJobs =
struct
  open Sh

  val accepting = env ("RUNE_TEST_ACCEPT", "") = "1"
  fun fail s = say ("FAIL " ^ s ^ "\n")

  val dir = "tests/hs/hslint"
  val suffixes = [".hs", ".lhs"]
  val mains = ["Main.hs", "Main.lhs"]

  (* the modes of a fixture: its expected file's middle name, its flags *)
  val modes = [("", ["--dump-hslint"]), ("scc", ["--dump-hslint", "--cycle-default=scc"]),
               ("library", ["--dump-hslint=library"])]

  fun expectedOf (base, mode) = base ^ (if mode = "" then "" else "." ^ mode) ^ ".expected"

  fun programs d = Lang.programsOf (d, suffixes, mains)

  (* the fixtures of tests/hs/hslint, each with the modes it has an
     expected file of *)
  fun fixtures () =
    List.filter (fn (_, ms) => not (null ms))
      (List.map (fn (p : Lang.program) =>
                   (p, List.filter (fn (m, _) => exists (fromRoot (expectedOf (#base p, m)))) modes))
         (programs dir))

  (* a run of `bin/rhc FLAGS FILE` from the root: its status and output *)
  fun rhc (flags, src, out) =
    let
      val () = mkdirs (OS.Path.dir out)
      val status = exec {cmd = [fromRoot "bin/rhc"] @ flags @ [src], dir = SOME root, stdin = "", stdout = out,
                         stderr = out ^ ".err", timeout = 600}
    in
      (status, read out)
    end

  fun slug s = String.translate (fn #"/" => "-" | c => str c) s

  fun dumpOne (name, mode) =
    case List.find (fn ((p : Lang.program), _) => #name p = name) (fixtures ()) of
      NONE => fail ("hs/hslint/dump/" ^ name ^ ": no such fixture")
    | SOME (p, ms) =>
        case List.find (fn (m, _) => m = mode) ms of
          NONE => fail ("hs/hslint/dump/" ^ name ^ ": no expected file for " ^ mode)
        | SOME (_, flags) =>
            let
              val file = fromRoot (expectedOf (#base p, mode))
              val job = "hs/hslint/dump/" ^ name ^ (if mode = "" then "" else "/" ^ mode)
              val out = run ^ "/hs-hslint/dump/" ^ slug name ^ (if mode = "" then "" else "." ^ mode) ^ ".out"
              val (_, got) = rhc (flags, #src p, out)
            in
              if accepting then (write (file, got); say ("ACCEPTED " ^ file ^ "\n"))
              else if got = read file then checked (job, p, mode, String.isPrefix "REFUSED" got, out)
              else fail (job ^ ": the dump differs from " ^ expectedOf (#base p, mode) ^ ": " ^ out)
            end

  (* the checker on a fixture at level 2, where HsLint replays its records
     and holds them to the second inference (HsLint.check): it accepts what
     the dump infers, or refuses with its own error what the dump refuses *)
  and checked (job, p : Lang.program, mode, refused, out) =
    if mode = "library" then ()
    else
      let
        val checkOut = out ^ ".check"
        val (status, text) = rhc (["--typecheck-only", "--lint=2"] @ (if mode = "scc" then ["--cycle-default=scc"] else []),
                                  #src p, checkOut)
        val text = text ^ read (checkOut ^ ".err")
        val first = case lines text of l :: _ => l | [] => ""
      in
        if String.isSubstring "lint after hslint" text then
          fail (job ^ ": the checker accepts, and HsLint refuses at level 2: " ^ first ^ " (" ^ checkOut ^ ")")
        else if refused andalso status = 0 then
          fail (job ^ ": the checker accepts what HsLint refuses (" ^ checkOut ^ ")")
        else if not refused andalso status <> 0 then
          fail (job ^ ": the checker refuses: " ^ first ^ " (" ^ checkOut ^ ")")
        else ()
      end

  (* ---- the expectations of tests/hs ---- *)

  (* the disagreements listed: the program, from tests/hs, and why *)
  fun disagreements () =
    List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of
                               p :: why :: _ => if String.isPrefix "#" p orelse p = "program" then NONE else SOME (p, why)
                             | _ => NONE)
      (lines (read (fromRoot (dir ^ "/disagreements.tsv"))))

  (* the class of the row a program's name gives, from the table *)
  fun classes () =
    List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of
                               id :: _ :: _ :: cls :: _ => SOME (id, cls)
                             | _ => NONE)
      (lines (read (fromRoot "tests/hs/conformance.tsv")))

  fun rowOf (p : Lang.program) = hd (String.fields (fn c => c = #"_") (#name p))

  val typeClasses = ["static", "prelude", "library"]

  fun errorPrograms () =
    let val cls = classes ()
    in
      List.filter (fn p => case List.find (fn (id, _) => id = rowOf p) cls of
                             SOME (_, c) => List.exists (fn t => t = c) typeClasses
                           | NONE => false)
        (programs "tests/hs/errors")
    end

  (* the judges' disagreements listed: the program, from tests/hs, and why *)
  fun judgeDisagreements () =
    List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of
                               p :: why :: _ => if String.isPrefix "#" p orelse p = "program" then NONE else SOME (p, why)
                             | _ => NONE)
      (lines (read (fromRoot (dir ^ "/judges.tsv"))))

  (* `expectOne (kind, name)`: a program of tests/hs/KIND, accept or lang
     inferred, errors refused; and the two judges, the checker alone
     (`--typecheck-only --lint=off`) and HsLint's second inference alone
     (`--dump-hslint`), of one verdict *)
  fun expectOne (kind, name) =
    case List.find (fn (p : Lang.program) => #name p = name) (programs ("tests/hs/" ^ kind)) of
      NONE => fail ("hs/hslint/" ^ kind ^ "/" ^ name ^ ": no such program")
    | SOME p =>
        let
          val key = kind ^ "/" ^ name
          val listed = List.find (fn (q, _) => q = key) (disagreements ())
          val out = run ^ "/hs-hslint/" ^ kind ^ "/" ^ slug name ^ ".out"
          val (status, got) = rhc (["--dump-hslint"], #src p, out)
          val refused = String.isPrefix "REFUSED" got
          val first = case lines got of l :: _ => l | [] => firstLine (out ^ ".err")
          val disagrees = if kind = "errors" then status = 0 else refused
        in
          (case (disagrees, listed) of
            (false, NONE) =>
              if kind <> "errors" andalso status <> 0 then say ("NOTE " ^ key ^ ": refused before HsLint: " ^ first ^ "\n")
              else ()
          | (true, SOME (_, why)) => say ("NOTE " ^ key ^ ": a listed disagreement: " ^ why ^ "\n")
          | (true, NONE) =>
              fail ("hs/hslint/" ^ key ^ ": " ^
                    (if kind = "errors" then "HsLint accepts a program of a type error's row"
                     else "HsLint refuses: " ^ first) ^ " (" ^ out ^ ")")
          | (false, SOME _) =>
              fail ("hs/hslint/" ^ key ^ ": listed in " ^ dir ^ "/disagreements.tsv, and HsLint and its expectation agree " ^
                    "now: remove the line"));
          judges (key, p, status <> 0, out)
        end

  (* the checker's verdict against HsLint's, refused or not *)
  and judges (key, p : Lang.program, hslintRefuses, out) =
    let
      val checkerOut = out ^ ".checker"
      val (checked, _) = rhc (["--typecheck-only", "--lint=off"], #src p, checkerOut)
      val checkerRefuses = checked <> 0
      val listed = List.find (fn (q, _) => q = key) (judgeDisagreements ())
    in
      case (checkerRefuses = hslintRefuses, listed) of
        (true, NONE) => ()
      | (false, SOME (_, why)) => say ("NOTE " ^ key ^ ": a listed disagreement of the judges: " ^ why ^ "\n")
      | (false, NONE) =>
          fail ("hs/hslint/" ^ key ^ ": the judges part: " ^
                (if checkerRefuses then "the checker refuses (" ^ firstLine (checkerOut ^ ".err") ^ ") and HsLint accepts"
                 else "HsLint refuses and the checker accepts") ^ " (" ^ out ^ ")")
      | (true, SOME _) =>
          fail ("hs/hslint/" ^ key ^ ": listed in " ^ dir ^ "/judges.tsv, and the judges agree now: remove the line")
    end

  (* the K-th shard of N of a directory's programs *)
  val shards = 4

  fun shardOf (kind, k, n) =
    let
      val ps = if kind = "errors" then errorPrograms () else programs ("tests/hs/" ^ kind)
      val names = sort (List.map #name ps)
      val sorted = List.mapPartial (fn n => List.find (fn (p : Lang.program) => #name p = n) ps) names
    in
      List.mapPartial (fn (i, p) => if i mod n = k - 1 then SOME p else NONE)
        (ListPair.zip (List.tabulate (length sorted, fn i => i), sorted))
    end

  fun expectShard (kind, k, n) = List.app (fn (p : Lang.program) => expectOne (kind, #name p)) (shardOf (kind, k, n))

  (* ---- the faults of the comparison's rules ---- *)

  val faultProgram = dir ^ "/faults.hs"
  val faultClaims = dir ^ "/faults.expected"

  (* each rule's fault: the rule it must reach *)
  val faults = ["kind", "derive", "binding", "rule1", "type", "numeric", "standard", "rule2", "default",
                "bindg", "dict tuple", "dict var", "dict inst", "dict super", "super", "method", "slot", "scc"]

  fun faultsAll () =
    let
      val out = run ^ "/hs-hslint/faults"
      val () = mkdirs out
      fun rhcWith (fault, file) =
        execEnv (fn e => if fault = "" then unsetEnv ["RHC_HSLINT_FAULT"] e else setEnv ("RHC_HSLINT_FAULT", fault) e)
          {cmd = [fromRoot "bin/rhc", "--lint=2", "--typecheck-only", "--hslint-claims=" ^ faultClaims, faultProgram],
           dir = SOME root, stdin = "", stdout = file, stderr = file, timeout = 600}
      val listed = out ^ "/rules"
      val _ = exec {cmd = [fromRoot "bin/rhc", "--hslint-rules"], dir = SOME root, stdin = "", stdout = listed,
                    stderr = listed ^ ".err", timeout = 300}
      val rules = List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of r :: _ => SOME r | [] => NONE)
                    (lines (read listed))
      val clean = out ^ "/none.out"
    in
      if null rules then fail ("hs/hslint/faults: bin/rhc --hslint-rules names no rule: " ^ firstLine (listed ^ ".err")) else ();
      List.app (fn r => if List.exists (fn f => f = r) faults then ()
                        else fail ("hs/hslint/faults: the rule " ^ r ^ " has no fault")) rules;
      List.app (fn f => if List.exists (fn r => r = f) rules then ()
                        else fail ("hs/hslint/faults: the fault " ^ f ^ " is no rule of bin/rhc --hslint-rules")) faults;
      if rhcWith ("", clean) = 0 then ()
      else fail ("hs/hslint/faults: the program is refused with its own claims: " ^ firstLine clean);
      List.app
        (fn f =>
           let
             val file = out ^ "/" ^ f ^ ".out"
             val status = rhcWith (f, file)
             val text = read file
           in
             if status = 0 then fail ("hs/hslint/faults: " ^ f ^ ": accepted")
             else if String.isSubstring "lint after hslint" text andalso String.isSubstring ("[" ^ f ^ "]") text then ()
             else fail ("hs/hslint/faults: " ^ f ^ ": not refused by [" ^ f ^ "]: " ^ firstLine file)
           end)
        faults
    end

  (* ---- the tree ---- *)

  fun job (name, cmd, timeout) =
    Test.it name
      {program = "/bin/sh", args = ["sh", "-c", "exec " ^ cmd],
       env = NONE, dir = SOME ".", stdin = NONE, timeout = Time.fromSeconds timeout, cap = 0, cpus = 1, memory = 500,
       pools = [], exclusive = false, after = [], judge = failLines} : Run.command Test.tree

  fun tagged tags t = List.foldl (fn (tag, t) => Test.tag tag t) t tags

  val covers = ["covers:lib/language/haskell/*", "covers:src/rhc/*", "covers:share/rhc/*", "covers:tests/hs/hslint/*",
                "covers:tests/hs/accept/*", "covers:tests/hs/lang/*", "covers:tests/hs/errors/*",
                "covers:tests/runner/hslint.sml", "covers:rhc.build", "covers:rhc.plan"]

  fun tree () =
    let
      val cmd = "\"$RUNE_TEST_ROOT\"/bin/rune-test "
      val dumps =
        List.concat
          (List.map (fn ((p : Lang.program), ms) =>
                       List.map (fn (m, _) =>
                                   job ("dump/" ^ #name p ^ (if m = "" then "" else "/" ^ m),
                                        cmd ^ "hs-hslint-dump " ^ quote (#name p) ^ " " ^ quote m, 600))
                         ms)
             (fixtures ()))
      (* the first shard of a directory in make check, the others nightly
         (the roadmap's D56, the lead's ruling 45: about 10% of make check
         for rhc's families) *)
      fun expect kind =
        List.tabulate (shards, fn i =>
                                 let val k = Int.toString (i + 1) ^ "-of-" ^ Int.toString shards
                                 in Test.tag (if i = 0 then "check" else "nightly")
                                      (job (kind ^ "/" ^ k, cmd ^ "hs-hslint-expect-shard " ^ kind ^ " " ^ k, 3600)) end)
    in
      Test.describe "hs/hslint"
        [tagged (["hs"] @ covers)
           (Test.requires ["rhc"]
              (Test.describe ""
                 (List.map (Test.tag "check") (dumps @ [job ("faults", cmd ^ "hs-hslint-faults", 1200)])
                  @ expect "accept" @ expect "lang" @ expect "errors")))]
    end

  fun command args =
    case args of
      ["hs-hslint-dump", name, mode] => SOME (fn () => dumpOne (name, mode))
    | ["hs-hslint-faults"] => SOME faultsAll
    | ["hs-hslint-expect", kind, name] => SOME (fn () => expectOne (kind, name))
    | ["hs-hslint-expect-shard", kind, kn] =>
        (case String.fields (fn c => c = #"-") kn of
           [k, "of", n] =>
             (case (Int.fromString k, Int.fromString n) of
                (SOME k, SOME n) => SOME (fn () => expectShard (kind, k, n))
              | _ => NONE)
         | _ => NONE)
    | _ => NONE
end

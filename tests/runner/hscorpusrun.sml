(* rhc on D56's run set (the haskell98 roadmap's D56, B; M19's corpus): the
   188 programs of E8's run set right under `ghc -O0` in at most a second,
   each compiled by rhc and run in D56's three ways (`test` on the stack VM,
   `register` and `register-opt` on the register VM), its output held to
   E8's expected output as E8 compared it (the same, the same words, or the
   same but for numbers equal to about five digits) and its exit status 0.
   A program both judges ran right that rhc does not is a finding, judged
   by tests/hs/rhc-corpus.txt as the corpus's checks are (`ID::run`).

   The programs are vendored under tests/hs/corpus/vendored (the owner's
   rules: code lands with its LICENSE beside it, or, without a licence,
   with a PROVENANCE), so their jobs are make check's: all 188, 45 under
   their trees' licences (GHC's tests, BSD-3; jhc's, MIT) and 143 under
   PROVENANCE files. A program not vendored would be read through
   RUNE_HS_CORPUS, nightly, with the capability hs-corpus; none is now.
   Every job waits while rhc runs no program: until the row prog.main.value
   of tests/hs/conformance.tsv is no longer Planned.

   tests/hs/corpus/vendored is also where `hs-rhc-corpus/vendored-SET`, in
   make check, a job a set, puts the 45 under a LICENSE through `bin/rhc
   --typecheck-only` as the nightly corpus jobs put the whole corpus
   (tests/runner/hsrhccorpus.sml), and `hs-rhc-corpus/provenance-SET`,
   nightly, the 143 under a PROVENANCE (ruling 46). *)
structure HsCorpusRun =
struct
  open Sh

  fun out () = fromRoot (env ("RUNE_HS_OUT", run ^ "/hs-corpus-run"))
  fun vendoredRoot () = HsCorpus.data () ^ "/vendored"
  val gib = 1024 * 1024 * 1024
  val limits = {addressSpace = SOME (6 * gib), cpuTime = NONE, fileSize = SOME gib, core = SOME 0}

  (* the 188, and those vendored *)
  fun d56 () = List.filter (fn r => HsCorpus.field r "d56" = "yes") (HsCorpus.rows "licences.tsv")

  (* the programs of tests/hs/corpus-nightly.txt, whose run in a way of
     make check is over D56's second (the lead's ruling 47: a program over
     the second in any of its check ways runs all its families nightly), as
     tests/hs/lang-nightly.txt lists rhc's own *)
  fun listedNightly () =
    List.mapPartial (fn l => case String.tokens Char.isSpace l of
                               n :: _ => if String.isPrefix "#" n then NONE else SOME n
                             | [] => NONE)
                    (lines (read (fromRoot "tests/hs/corpus-nightly.txt")))
    handle _ => []
  fun vendored () = List.map (fn r => HsCorpus.field r "id") (List.filter (fn r => HsCorpus.field r "vendor" = "vendored") (d56 ()))
  fun isVendored id = List.exists (fn v => v = id) (vendored ())

  (* read the trees from tests/hs/corpus/vendored while f runs *)
  fun fromVendored f =
    let val saved = !HsCorpus.rootOverride
        val () = HsCorpus.rootOverride := SOME (vendoredRoot ())
    in (f () before HsCorpus.rootOverride := saved) handle e => (HsCorpus.rootOverride := saved; raise e) end

  (* D56's three ways, as rhc's own programs run (tests/runner/hslang.sml) *)
  val ways = [("test", "stack", [fromRoot "bin/runevm-stack"]),
              ("register", "register", [fromRoot "bin/runevm"]),
              ("register-opt", "register", [fromRoot "bin/runevm", "--jit=all", "--jit-tier=2"])]
  (* each way's target, compiled once and its bytecode run by every way of
     it (the lead's ruling 52): register and register-opt take the same *)
  val targets = [("stack", ["--target=stack"]), ("register", [])]

  (* both judges ran it right (D52: GHC and Hugs, E8's run.tsv), so that
     a program rhc does not run right is a finding of rhc's *)
  fun judgesAgree row =
    let fun right v = List.exists (fn w => w = v) ["same", "close", "same-ws"]
    in right (HsCorpus.field row "ghc_out") andalso HsCorpus.field row "hugs_build" = "ok"
       andalso right (HsCorpus.field row "hugs_out") end

  (* a program compiled and run in each way; its outcome judged as the
     corpus's checks are (HsRhcCorpus.decide), by its label `run`: wanted,
     E8's output and status 0 in every way; else its first failure, `compile`
     (rhc refuses it), `exit` (a status not 0, or killed) or `diff` (another
     output), with each way's word. A failure where both judges ran it right
     fails the job unless a line of tests/hs/rhc-corpus.txt gives its cause
     (`rhc | ID::run | CATEGORY | OUTCOME: why`); where they do not, it is
     recorded in the results and judged by nothing *)
  fun runOne id =
    let
      val row = case List.find (fn r => HsCorpus.field r "id" = id) (HsCorpus.rows "run.tsv") of
                  SOME r => r | NONE => raise HsOracles.Failed ("no run of " ^ id)
      val c = case List.find (fn (c : HsCorpus.candidate) => #id c = id) (HsCorpus.candidates ()) of
                SOME c => c | NONE => raise HsOracles.Failed ("no candidate " ^ id)
      val work = out () ^ "/run/" ^ id
      val log = out () ^ "/logs/" ^ id
      val variant = case HsCorpus.field row "variant" of "" => "h98" | v => v
      val {files, rewritable, ...} = HsCorpus.closureOf c
      val expected = HsSource.universal (read (HsCorpus.tree (HsCorpus.field row "expected")))
      val args = String.tokens Char.isSpace (HsCorpus.field row "args")
      (* the program as rhc takes it, as the corpus's check tries it: in
         E8's variant; refused, rewritten (E8's import rewrite) where it can
         be; refused again, under `--dotted-names`, the flag D35 gives the
         corpus for hierarchical names. Each try prepared once, in its own
         directory, with the run's input beside it *)
      val variants = [variant] @ (if variant <> "rewrite" andalso not (null rewritable) then ["rewrite"] else [])
      val tries = List.map (fn v => (v, [])) variants @ [(List.last variants, ["--dotted-names"])]
      val prepared = ref [] : (string * (string * string)) list ref
      fun prepare v =
        case List.find (fn (w, _) => w = v) (!prepared) of
          SOME (_, pm) => pm
        | NONE =>
            let val (p, m) = HsCorpus.prepare (c, v, files, work ^ "/" ^ v)
                val stdin = HsCorpus.field row "stdin"
                val () = if stdin = "" then ()
                         else let val q = p ^ "/" ^ OS.Path.file stdin
                              in if exists q then () else HsCorpus.copyFile (HsCorpus.tree stdin, q) end
            in prepared := (v, (p, m)) :: !prepared; (p, m) end
      (* each step's CPU (user and system, the child's) and wall time, in
         LOG.times, for D56's second by way (the lead's ruling 47) *)
      fun childCpu () = let val {cutime, cstime, ...} = Posix.ProcEnv.times () in Time.+ (cutime, cstime) end
      fun secs t = Real.fmt (StringCvt.FIX (SOME 3)) (Time.toReal t)
      fun call (dir, tag, cmd, input) =
        let val () = mkdirs (OS.Path.dir log)
            val (t0, c0) = (Time.now (), childCpu ())
            val s = execProcess false limits (fn e => e)
                      {cmd = cmd, dir = SOME dir, stdin = input, stdout = log ^ "." ^ tag ^ ".out", stderr = log ^ "." ^ tag ^ ".err",
                       timeout = 600}
            val () = append (log ^ ".times", tag ^ "\t" ^ secs (Time.- (childCpu (), c0)) ^ "\t" ^ secs (Time.- (Time.now (), t0)) ^ "\n")
        in (s, read (log ^ "." ^ tag ^ ".out"), firstNonEmpty (log ^ "." ^ tag ^ ".err")) end
      (* a target compiled: (true, the directory and its bytecode), or
         (false, the first refusal) *)
      fun compileTarget (target, flags) =
        let
          val rbc = "main." ^ target ^ ".rbc"
          fun compile [] first = (false, first, "")
            | compile ((v, extra) :: rest) first =
                let val (p, m) = prepare v
                    val tag = target ^ ".rhc." ^ v ^ (if null extra then "" else ".dotted")
                    val (cs, _, cerr) = call (p, tag, [HsRhcCorpus.rhc (), m] @ extra @ flags @ ["-o", rbc], "")
                in if cs = 0 then (true, p, rbc) else compile rest (if first = "" then cerr else first) end
        in (target, compile tries "") end
      val compiled = List.map compileTarget targets
      fun way (name, target, vm) =
        case List.find (fn (t, _) => t = target) compiled of
          NONE => SOME ("compile", name ^ ": no target " ^ target)
        | SOME (_, (false, cerr, _)) => SOME ("compile", name ^ ": " ^ cerr)
        | SOME (_, (true, p, rbc)) =>
            let val stdin = case HsCorpus.field row "stdin" of "" => "" | f => p ^ "/" ^ OS.Path.file f
                val (rs, output, rerr) = call (p, name, vm @ [rbc] @ args, stdin)
            in
              if rs <> 0 then SOME ("exit", name ^ ": " ^ Int.toString rs ^ (if rerr = "" then "" else " " ^ rerr))
              else if HsOracles.same (expected, HsSource.universal output) = "diff" then
                SOME ("diff", name ^ ": " ^ Int.toString (size output) ^ " bytes, not " ^ HsCorpus.field row "expected")
              else NONE
            end
      val fails = List.mapPartial way ways
      val () = rmTree work
      val outcome = {id = id, label = "run", got = case fails of [] => "run" | (g, _) :: _ => g,
                     said = String.concatWith "; " (List.map #2 fails), passed = null fails, judged = judgesAgree row,
                     want = "E8's output and status 0 in D56's three ways"} : HsRhcCorpus.outcome
    in HsRhcCorpus.report ("run-" ^ String.translate (fn #"/" => "_" | ch => str ch) id, [outcome]) end
    handle HsOracles.Failed msg => say ("FAIL hs-corpus-run " ^ id ^ ": " ^ msg ^ "\n")
         | HsCorpus.Bad msg => say ("FAIL hs-corpus-run " ^ id ^ ": " ^ msg ^ "\n")

  (* the vendored programs by their notice: under their tree's LICENSE (45),
     whose names jobs are make check's, or under a PROVENANCE (143), whose
     names jobs are nightly (ruling 46: D56 puts the 188's runs in check, not
     a names job, and the nightly m13 and rest jobs check the 143 as well);
     each set's of a kind a job *)
  fun vendoredRows () = List.filter (fn r => HsCorpus.field r "vendor" = "vendored") (d56 ())
  fun underLicence r = OS.Path.file (HsCorpus.field r "notice") = "LICENSE"
  fun setsOf rows =
    List.foldr (fn (s, acc) => if List.exists (fn t => t = s) acc then acc else s :: acc) []
               (List.map (fn r => HsCorpus.field r "set") rows)

  (* the vendored programs whose rows of licences.tsv `keep` holds of,
     through rhc --typecheck-only, reported as the job `job` *)
  fun namesVendored (job, keep) () =
    fromVendored (fn () =>
      let
        val ids = List.map (fn r => HsCorpus.field r "id") (List.filter keep (vendoredRows ()))
        val cs = HsCorpus.candidates ()
        val rows = List.filter (fn r => List.exists (fn v => v = HsCorpus.field r "id") ids) (HsCorpus.rows "accept.tsv")
        fun cand r = case List.find (fn (c : HsCorpus.candidate) => #id c = HsCorpus.field r "id") cs of
                       SOME c => c | NONE => raise HsOracles.Failed ("no candidate " ^ HsCorpus.field r "id")
      in HsRhcCorpus.report (job, List.map (fn r => HsRhcCorpus.one false (r, cand r)) rows) end)
    handle HsOracles.Failed m => say ("FAIL rhc " ^ job ^ ": " ^ m ^ "\n")
         | HsCorpus.Bad m => say ("FAIL rhc " ^ job ^ ": " ^ m ^ "\n")
  fun ofSet set r = HsCorpus.field r "set" = set

  fun command ["hs-corpus-run", id] =
        SOME (fn () => if isVendored id then fromVendored (fn () => runOne id) else runOne id)
    | command ["hs-rhc-corpus-vendored"] = SOME (namesVendored ("vendored", fn _ => true))
    | command ["hs-rhc-corpus-vendored", "licence", set] =
        SOME (namesVendored ("vendored-" ^ set, fn r => ofSet set r andalso underLicence r))
    | command ["hs-rhc-corpus-vendored", "provenance", set] =
        SOME (namesVendored ("provenance-" ^ set, fn r => ofSet set r andalso not (underLicence r)))
    | command _ = NONE

  fun tree () =
    let
      val rows = d56 () handle HsCorpus.Bad _ => []
      val held = HsConformance.pendingUntil ["prog.main.value"]
      fun job id = HsOracles.job (id, ["hs-corpus-run", id], [], 3600, 2000)
      fun hold t = case held of SOME why => Test.pending why t | NONE => t
      val late = listedNightly ()
      fun isLate r = List.exists (fn n => n = HsCorpus.field r "id") late
      val (inTree, outside) = List.partition (fn r => HsCorpus.field r "vendor" = "vendored" andalso not (isLate r)) rows
      val vrows = vendoredRows () handle HsCorpus.Bad _ => []
      fun names (kind, prefix, keep) =
        List.map (fn s => HsOracles.job (prefix ^ s, ["hs-rhc-corpus-vendored", kind, s], [], 1800, 2000))
                 (setsOf (List.filter keep vrows))
      val covers = ["covers:tests/hs/corpus/*", "covers:tests/runner/hscorpusrun.sml", "covers:lib/language/haskell/*",
                    "covers:src/rhc/*"]
    in
      List.foldl (fn (c, t) => Test.tag c t)
        (Test.requires ["rhc"]
          (Test.describe ""
             [Test.describe "hs-corpus-run"
                [Test.tag "check" (Test.describe "" (List.map (fn r => hold (job (HsCorpus.field r "id"))) inTree
                                                     @ [hold (HsOracles.job ("@stale", ["hs-rhc-corpus", "stale"],
                                                                             List.map (fn r => "hs-corpus-run/" ^ HsCorpus.field r "id") inTree,
                                                                             300, 100))])),
                 Test.tag "nightly"
                   (Test.describe "" (List.map (fn r => hold (if HsCorpus.field r "vendor" = "vendored" then job (HsCorpus.field r "id")
                                                              else Test.requires ["hs-corpus"] (job (HsCorpus.field r "id"))))
                                               outside
                                      @ [hold (HsOracles.job ("@stale-nightly", ["hs-rhc-corpus", "stale"],
                                                              List.map (fn r => "hs-corpus-run/" ^ HsCorpus.field r "id") outside,
                                                              300, 100))]))],
              Test.describe "hs-rhc-corpus"
                [Test.tag "check" (Test.describe "" (names ("licence", "vendored-", underLicence))),
                 Test.tag "nightly" (Test.describe "" (names ("provenance", "provenance-", not o underLicence)))]]))
        ("hs" :: covers)
    end
end

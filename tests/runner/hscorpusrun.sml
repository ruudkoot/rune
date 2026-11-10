(* rhc on D56's run set (the haskell98 roadmap's D56, B; M19's corpus): the
   188 programs of E8's run set right under `ghc -O0` in at most a second,
   each compiled by rhc and run in D56's three ways (`test` on the stack VM,
   `register` and `register-opt` on the register VM), its output held to
   E8's expected output as E8 compared it (the same, the same words, or the
   same but for numbers equal to about five digits) and its exit status 0.

   The programs whose licence lets them be copied are vendored under
   tests/hs/corpus/vendored (the owner's decision: a program lands with its
   tree's LICENSE beside it), and their jobs are make check's: 45 of the
   188, GHC's tests (BSD-3) and jhc's (MIT). The rest are read through
   RUNE_HS_CORPUS, nightly, with the capability hs-corpus. Every job waits
   while rhc runs no program: until the row prog.main.value of
   tests/hs/conformance.tsv is no longer Planned.

   tests/hs/corpus/vendored is also where `hs-rhc-corpus/vendored`, in
   make check, puts the vendored programs through `bin/rhc
   --typecheck-only` as the nightly corpus jobs put the whole corpus
   (tests/runner/hsrhccorpus.sml). *)
structure HsCorpusRun =
struct
  open Sh

  fun out () = fromRoot (env ("RUNE_HS_OUT", run ^ "/hs-corpus-run"))
  fun vendoredRoot () = HsCorpus.data () ^ "/vendored"
  val gib = 1024 * 1024 * 1024
  val limits = {addressSpace = SOME (6 * gib), cpuTime = NONE, fileSize = SOME gib, core = SOME 0}

  (* the 188, and those vendored *)
  fun d56 () = List.filter (fn r => HsCorpus.field r "d56" = "yes") (HsCorpus.rows "licences.tsv")
  fun vendored () = List.map (fn r => HsCorpus.field r "id") (List.filter (fn r => HsCorpus.field r "vendor" = "vendored") (d56 ()))
  fun isVendored id = List.exists (fn v => v = id) (vendored ())

  (* read the trees from tests/hs/corpus/vendored while f runs *)
  fun fromVendored f =
    let val saved = !HsCorpus.rootOverride
        val () = HsCorpus.rootOverride := SOME (vendoredRoot ())
    in (f () before HsCorpus.rootOverride := saved) handle e => (HsCorpus.rootOverride := saved; raise e) end

  (* D56's three ways, as rhc's own programs run (tests/runner/hslang.sml) *)
  val ways = [("test", ["--target=stack"], [fromRoot "bin/runevm-stack"]),
              ("register", [], [fromRoot "bin/runevm"]),
              ("register-opt", [], [fromRoot "bin/runevm", "--jit=all", "--jit-tier=2"])]

  fun runOne id =
    let
      val row = case List.find (fn r => HsCorpus.field r "id" = id) (HsCorpus.rows "run.tsv") of
                  SOME r => r | NONE => raise HsOracles.Failed ("no run of " ^ id)
      val c = case List.find (fn (c : HsCorpus.candidate) => #id c = id) (HsCorpus.candidates ()) of
                SOME c => c | NONE => raise HsOracles.Failed ("no candidate " ^ id)
      val work = out () ^ "/run/" ^ id
      val log = out () ^ "/logs/" ^ id
      val variant = case HsCorpus.field row "variant" of "" => "h98" | v => v
      val {files, ...} = HsCorpus.closureOf c
      val (p, m) = HsCorpus.prepare (c, variant, files, work)
      fun beside f = if f = "" then "" else
                       let val q = p ^ "/" ^ OS.Path.file f
                       in (if exists q then () else HsCorpus.copyFile (HsCorpus.tree f, q)); q end
      val stdin = beside (HsCorpus.field row "stdin")
      val expected = HsSource.universal (read (HsCorpus.tree (HsCorpus.field row "expected")))
      val args = String.tokens Char.isSpace (HsCorpus.field row "args")
      fun call (tag, cmd, input) =
        let val () = mkdirs (OS.Path.dir log)
            val s = execProcess false limits (fn e => e)
                      {cmd = cmd, dir = SOME p, stdin = input, stdout = log ^ "." ^ tag ^ ".out", stderr = log ^ "." ^ tag ^ ".err",
                       timeout = 600}
        in (s, read (log ^ "." ^ tag ^ ".out"), firstNonEmpty (log ^ "." ^ tag ^ ".err")) end
      fun way (name, flags, vm) =
        let
          val rbc = "main." ^ name ^ ".rbc"
          val (cs, _, cerr) = call (name ^ ".rhc", [HsRhcCorpus.rhc (), m] @ flags @ ["-o", rbc], "")
        in
          if cs <> 0 then say ("FAIL hs-corpus-run " ^ id ^ " (" ^ name ^ "): rhc does not compile it: " ^ cerr ^ "\n")
          else
            let val (rs, output, rerr) = call (name, vm @ [rbc] @ args, stdin)
                val verdict = HsOracles.same (expected, HsSource.universal output)
            in
              if rs <> 0 then say ("FAIL hs-corpus-run " ^ id ^ " (" ^ name ^ "): exit " ^ Int.toString rs ^ ": " ^ rerr ^ "\n")
              else if verdict = "diff" then
                say ("FAIL hs-corpus-run " ^ id ^ " (" ^ name ^ "): its output is not E8's expected "
                     ^ HsCorpus.field row "expected" ^ " (" ^ Int.toString (size output) ^ " bytes)\n")
              else ()
            end
        end
    in List.app way ways; rmTree work end
    handle HsOracles.Failed msg => say ("FAIL hs-corpus-run " ^ id ^ ": " ^ msg ^ "\n")
         | HsCorpus.Bad msg => say ("FAIL hs-corpus-run " ^ id ^ ": " ^ msg ^ "\n")

  (* the vendored programs through rhc --typecheck-only, in make check *)
  fun namesVendored () =
    fromVendored (fn () =>
      let
        val ids = vendored ()
        val cs = HsCorpus.candidates ()
        val rows = List.filter (fn r => List.exists (fn v => v = HsCorpus.field r "id") ids) (HsCorpus.rows "accept.tsv")
        fun cand r = case List.find (fn (c : HsCorpus.candidate) => #id c = HsCorpus.field r "id") cs of
                       SOME c => c | NONE => raise HsOracles.Failed ("no candidate " ^ HsCorpus.field r "id")
      in HsRhcCorpus.report ("vendored", List.map (fn r => HsRhcCorpus.one false (r, cand r)) rows) end)
    handle HsOracles.Failed m => say ("FAIL rhc vendored: " ^ m ^ "\n")
         | HsCorpus.Bad m => say ("FAIL rhc vendored: " ^ m ^ "\n")

  fun command ["hs-corpus-run", id] =
        SOME (fn () => if isVendored id then fromVendored (fn () => runOne id) else runOne id)
    | command ["hs-rhc-corpus-vendored"] = SOME namesVendored
    | command _ = NONE

  fun tree () =
    let
      val rows = d56 () handle HsCorpus.Bad _ => []
      val held = HsConformance.pendingUntil ["prog.main.value"]
      fun job id = HsOracles.job (id, ["hs-corpus-run", id], [], 3600, 2000)
      fun hold t = case held of SOME why => Test.pending why t | NONE => t
      val (inTree, outside) = List.partition (fn r => HsCorpus.field r "vendor" = "vendored") rows
      val covers = ["covers:tests/hs/corpus/*", "covers:tests/runner/hscorpusrun.sml", "covers:lib/language/haskell/*",
                    "covers:src/rhc/*"]
    in
      List.foldl (fn (c, t) => Test.tag c t)
        (Test.requires ["rhc"]
          (Test.describe ""
             [Test.describe "hs-corpus-run"
                [Test.tag "check" (Test.describe "" (List.map (fn r => hold (job (HsCorpus.field r "id"))) inTree)),
                 Test.tag "nightly" (Test.requires ["hs-corpus"]
                   (Test.describe "" (List.map (fn r => hold (job (HsCorpus.field r "id"))) outside)))],
              Test.tag "check" (Test.describe "hs-rhc-corpus"
                [HsOracles.job ("vendored", ["hs-rhc-corpus-vendored"], [], 1800, 2000)])]))
        ("hs" :: covers)
    end
end

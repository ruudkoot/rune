(* What make check holds of rhc's corpus and oracles without either: the data
   is whole and agrees with itself, nothing lands under tests/hs/corpus that
   the survey has not cleared, tests/hs/oracles.txt explains exactly what
   the recorded verdicts need explained, each hard case has a reading, the
   source rewrites do what E8's did on planted text, and the harness fails
   where it must, on fake oracles. *)
structure HsChecks =
struct
  open Sh

  val errors = ref [] : string list ref
  fun need (ok, why) = if ok then () else errors := why :: !errors
  fun finish what =
    (List.app (fn m => say ("FAIL " ^ what ^ ": " ^ m ^ "\n")) (rev (!errors));
     if null (!errors) then say ("PASS " ^ what ^ "\n") else ();
     errors := [])

  fun count p xs = List.length (List.filter p xs)
  fun ids rows = List.map (fn r => HsCorpus.field r "id") rows
  fun member x xs = List.exists (fn y => y = x) xs
  fun distinct xs = length (HsSource.dedup xs) = length xs

  val conformanceLabels = ["conformance"]
  val recordedLabels = ["judge", "open", "ext", "run"]
  val verdicts = ["ok", "ok?", "accept", "diff", "rtfail", "reject", "timeout"]

  (* the R numbers a reason cites *)
  fun readings reason =
    let
      val n = size reason
      fun go (i, acc) =
        if i + 1 >= n then rev acc
        else if String.sub (reason, i) = #"R" andalso Char.isDigit (String.sub (reason, i + 1))
                andalso (i = 0 orelse not (HsSource.isWord (String.sub (reason, i - 1)))) then
          let val e = HsSource.skip Char.isDigit reason (i + 1)
          in go (e, valOf (Int.fromString (String.substring (reason, i + 1, e - i - 1))) :: acc) end
        else go (i + 1, acc)
    in go (0, []) end

  (* ---- The data ---- *)

  (* ---- The vendored programs (M19-O7, O8; README.md, The licences) ---- *)

  (* a vendored candidate's files, by their paths under the trees' root, as
     the harness reads them from the root in force: of a set whose program is
     its directory, the directory whole but a sub-directory that is a program
     of its own, and the parent's sources (as HsCorpus.prepare copies them);
     of another, its closure and boot files; nofib's NofibUtils where it is
     imported; and its run's input and expected output *)
  fun programFiles (c : HsCorpus.candidate) =
    let
      val root = HsCorpus.root ()
      fun rel f = HsCorpus.relative (root, f)
      val {files, ...} = HsCorpus.closureOf c
      val dir = HsCorpus.dirname (HsCorpus.tree (#path c))
      (* a symbolic link is not copied: nofib's program directories link
         NofibUtils.hs to common/NofibUtils.hs, which is vendored once *)
      fun under d = List.concat (List.map (fn n => let val p = d ^ "/" ^ n in
                                                     if OS.FileSys.isLink p then []
                                                     else if isDir p then (if exists (p ^ "/Main.hs") then [] else under p) else [p] end)
                                          (sort (entries d)))
      val boots = List.filter (fn f => List.exists (fn (_, sc : HsSource.scan) =>
                                                      List.exists (fn b => b = hd (String.fields (fn ch => ch = #".") (OS.Path.file f))) (#boot sc)) files)
                              (glob (dir, ".hs-boot") @ glob (dir, ".lhs-boot"))
      (* nofib's fixtures of its fast and slow modes, which E8's runs do not
         read, are left in the trees *)
      fun fixture f = List.exists (fn e => String.isSuffix e f) [".faststdout", ".slowstdout", ".faststdin", ".slowstdin"]
      val own = if HsCorpus.whole (#set c) then List.filter (not o fixture) (under dir) else List.map #1 files @ boots
      val parent = if #parent c <> "-" then glob (HsCorpus.tree (#parent c), ".hs") else []
      val utils = HsCorpus.tree (HsCorpus.common ^ "/NofibUtils.hs")
      val nofibUtils = if exists utils andalso List.exists (fn (_, sc : HsSource.scan) => List.exists (fn m => m = "NofibUtils") (#imports sc)) files
                       then [utils] else []
      val run = case List.find (fn r => HsCorpus.field r "id" = #id c) (HsCorpus.rows "run.tsv") of
                  SOME r => List.filter (fn x => x <> "") [HsCorpus.field r "expected", HsCorpus.field r "stdin"]
                | NONE => []
    in HsSource.dedup (List.map rel (own @ parent @ nofibUtils) @ run) end

  (* the vendored rows of licences.tsv: each candidate and its notice, the
     LICENSE of its tree or the PROVENANCE of its origin, a path under
     tests/hs/corpus/vendored *)
  fun vendoredRows () =
    List.map (fn r => (HsCorpus.field r "id", HsCorpus.field r "notice"))
             (List.filter (fn r => HsCorpus.field r "vendor" = "vendored") (HsCorpus.rows "licences.tsv"))
  fun candidatesOf ids = List.filter (fn (c : HsCorpus.candidate) => member (#id c) ids) (HsCorpus.candidates ())

  (* every vendored program's file; and the notices, LICENSE files copied
     from their trees and PROVENANCE files written here *)
  fun vendoredFiles () =
    let val rows = vendoredRows ()
    in HsSource.dedup (List.concat (List.map programFiles (candidatesOf (List.map #1 rows)))) end
  fun notices () = HsSource.dedup (List.map #2 (vendoredRows ()))
  fun isLicence f = OS.Path.file f = "LICENSE"

  (* hs-corpus-vendor: the vendored candidates' files and their trees'
     LICENSE files copied from the trees under RUNE_HS_CORPUS into
     tests/hs/corpus/vendored, as they are; a PROVENANCE is this project's,
     and stays as written *)
  fun vendor () =
    let
      val dst = HsCorpusRun.vendoredRoot ()
      val files = vendoredFiles () @ List.filter isLicence (notices ())
    in
      List.app (fn f => HsCorpus.copyFile (HsCorpus.tree f, dst ^ "/" ^ f)) files;
      say ("vendored " ^ Int.toString (length files) ^ " files of " ^ Int.toString (length (vendoredRows ()))
           ^ " programs under " ^ dst ^ "\n")
    end

  (* hs-corpus/vendored (nightly, with the trees): the vendored files and
     LICENSE files are the trees' at their pinned commits, byte for byte,
     and no more nor fewer *)
  fun vendoredUpstream () =
    let
      val fromTrees = vendoredFiles () @ List.filter isLicence (notices ())
      val inTree = HsCorpusRun.fromVendored vendoredFiles @ List.filter isLicence (notices ())
      val dst = HsCorpusRun.vendoredRoot ()
      val sets = HsSource.dedup (List.map #set (candidatesOf (List.map #1 (vendoredRows ()))))
      val () = List.app (fn s => HsOracles.pinned s handle HsOracles.Failed m => need (false, m)) sets
      val () = List.app (fn f => need (member f inTree, f ^ ": the trees have it for a vendored program, tests/hs/corpus/vendored does not"))
                        fromTrees
      val () = List.app (fn f => need (member f fromTrees, f ^ ": vendored, and of no vendored program in the trees")) inTree
      val () = List.app (fn f => need (not (exists (dst ^ "/" ^ f)) orelse read (dst ^ "/" ^ f) = read (HsCorpus.tree f),
                                       f ^ ": the vendored copy is not the tree's")) fromTrees
    in finish "tests/hs/corpus/vendored against the trees" end
    handle HsCorpus.Bad m => (need (false, m); finish "tests/hs/corpus/vendored against the trees")

  (* the notice that covers a vendored file: the nearest LICENSE or
     PROVENANCE in its directory or above it, under vendored *)
  fun noticeOf (root, f) =
    let
      fun up d =
        if d = "" orelse d = "." then NONE
        else case List.find (fn n => exists (root ^ "/" ^ d ^ "/" ^ n)) ["PROVENANCE", "LICENSE"] of
               SOME n => SOME (d ^ "/" ^ n)
             | NONE => up (OS.Path.dir d)
    in up (OS.Path.dir f) end

  fun data () =
    let
      val cands = HsCorpus.rows "candidates.tsv"
      val accept = HsCorpus.rows "accept.tsv"
      val reject = HsCorpus.rows "reject.tsv"
      val runs = HsCorpus.rows "run.tsv"
      val conf = HsCorpus.rows "conformance.tsv"
      val lic = HsCorpus.rows "licences.tsv"
      val trees = HsCorpus.rows "trees.tsv"
      val cids = ids cands
      val () = need (length cands = 3089, "candidates.tsv has " ^ Int.toString (length cands) ^ " rows, not E8's 3,089")
      val () = need (distinct cids, "candidates.tsv names a candidate twice")
      val () = need (length accept = 1441 andalso length reject = 1648,
                     "accept.tsv and reject.tsv have " ^ Int.toString (length accept) ^ " and " ^ Int.toString (length reject)
                     ^ " rows, not E8's 1,441 and 1,648")
      val judged = ids accept @ ids reject
      val () = need (distinct judged andalso length judged = length cids andalso List.all (fn i => member i cids) judged,
                     "accept.tsv and reject.tsv together are not each candidate once")
      val () = need (length runs = 283, "run.tsv has " ^ Int.toString (length runs) ^ " rows, not E8's 283")
      val () = need (List.all (fn i => member i (ids accept)) (ids runs), "a program of run.tsv is not in accept.tsv")
      val () = need (length conf = 82 andalso distinct (ids conf) andalso List.all (fn i => member i cids) (ids conf),
                     "conformance.tsv is not E7's 82 tests, each a candidate")
      val sets = List.map (fn r => HsCorpus.field r "set") trees
      val () = List.app (fn r => need (member (HsCorpus.field r "set") sets, "no tree for the set of " ^ HsCorpus.field r "id")) cands
      val () = List.app (fn r =>
                 let val t = HsCorpus.field (valOf (List.find (fn t => HsCorpus.field t "set" = HsCorpus.field r "set") trees)) "tree"
                 in need (String.isPrefix (t ^ "/") (HsCorpus.field r "path"), HsCorpus.field r "id" ^ " is not in its tree " ^ t) end
                 handle Option => ()) cands
      (* the survey: a row a candidate, and D56's 188 the run set's programs
         right under ghc -O0 in at most a second *)
      val () = need (length lic = length cids andalso distinct (ids lic) andalso List.all (fn i => member i cids) (ids lic),
                     "licences.tsv is not a row for each candidate")
      val () = List.app (fn r => need (member (HsCorpus.field r "vendor") ["vendored", "vendor", "outside", "owner"],
                                       "licences.tsv: no verdict for " ^ HsCorpus.field r "id")) lic
      val d56 = List.map (fn r => HsCorpus.field r "id") (List.filter (fn r => HsCorpus.field r "d56" = "yes") lic)
      fun fast r =
        member (HsCorpus.field r "ghc_out") ["same", "same-ws", "close"] andalso HsCorpus.field r "ghc_rc" = "0"
        andalso (case Real.fromString (HsCorpus.field r "ghc_cpu_ms") of SOME ms => ms <= 1000.0 | NONE => false)
      val fastIds = ids (List.filter fast runs)
      val () = need (length d56 = 188 andalso List.all (fn i => member i fastIds) d56 andalso length fastIds = 188,
                     "licences.tsv's d56 rows are not the run set's 188 programs right in at most 1 s under ghc -O0")
      (* nothing lands under tests/hs/corpus but this project's own *)
      val root = HsCorpus.data ()
      fun walk d = List.concat (List.map (fn n => let val p = d ^ "/" ^ n in if isDir p then walk p else [p] end) (sort (entries d)))
      val own = ["README.md", "trees.tsv", "licences.tsv", "candidates.tsv", "accept.tsv", "reject.tsv", "run.tsv",
                 "conformance.tsv", "compat/NofibCompat.hs", "compat/NofibUtils.hs"]
      (* and the vendored programs, each a candidate licences.tsv marks
         vendored, of D56's 188, under the notice it names: its tree's
         LICENSE or its origin's PROVENANCE, the nearest above each of its
         files; no vendored file without one *)
      val vrows = vendoredRows ()
      val () = List.app (fn (i, _) => need (member i d56, i ^ ": vendored, and not of D56's 188")) vrows
      val () = List.app (fn (i, n) => need (member (OS.Path.file n) ["LICENSE", "PROVENANCE"],
                                            i ^ ": vendored with no notice, a LICENSE or a PROVENANCE, in licences.tsv")) vrows
      val vroot = HsCorpusRun.vendoredRoot ()
      val byProgram = HsCorpusRun.fromVendored (fn () =>
                        List.map (fn (c : HsCorpus.candidate) => (#id c, programFiles c)) (candidatesOf (List.map #1 vrows)))
      val () = List.app (fn (i, fs) =>
                 let val n = case List.find (fn (j, _) => j = i) vrows of SOME (_, n) => n | NONE => ""
                 in List.app (fn f => need (noticeOf (vroot, f) = SOME n,
                                            "vendored/" ^ f ^ " (" ^ i ^ "): " ^ (case noticeOf (vroot, f) of
                                                                                     SOME m => "under " ^ m ^ ", not " ^ n
                                                                                   | NONE => "no LICENSE or PROVENANCE beside it or above it")))
                              fs end) byProgram
      (* a PROVENANCE names its upstream and commit and quotes the owner's rule *)
      val () = List.app (fn n =>
                 if OS.Path.file n <> "PROVENANCE" then ()
                 else
                   let val t = if exists (vroot ^ "/" ^ n) then read (vroot ^ "/" ^ n) else ""
                       val tree = hd (String.fields (fn ch => ch = #"/") n)
                       val pins = List.filter (fn r => HsCorpus.field r "tree" = tree) trees
                   in need (List.exists (fn r => String.isSubstring (HsCorpus.field r "upstream") t
                                                 andalso String.isSubstring (HsCorpus.field r "commit") t) pins
                            andalso String.isSubstring "If you want to vendor code without a license add a PROVENANCE alongside it instead." t,
                            "vendored/" ^ n ^ ": a PROVENANCE names its upstream and its commit (trees.tsv) and quotes the owner's rule")
                   end) (notices ())
      val vfiles = List.map (fn f => "vendored/" ^ f) (List.concat (List.map #2 byProgram) @ notices ())
      val () = List.app (fn f => need (exists (root ^ "/" ^ f), f ^ ": a vendored program's file or its notice is missing")) vfiles
      val () = List.app (fn p =>
                 let val r = HsCorpus.relative (root, p)
                 in need (member r own orelse member r vfiles orelse (String.isPrefix "compat/" r andalso String.isSuffix ".sed" r),
                          r ^ " is under tests/hs/corpus, and is neither its data, its compat layer nor a vendored "
                          ^ "program's file or notice: a program lands only under a LICENSE or a PROVENANCE (README.md)") end)
                (walk root)
    in finish "rhc's corpus data" end
    handle HsCorpus.Bad m => (need (false, m); finish "rhc's corpus data")

  (* ---- oracles.txt against the record ---- *)

  fun oraclesText () =
    let
      val ls = Expectations.read (HsOracles.oraclesFile ())
      val conf = HsCorpus.rows "conformance.tsv"
      val cands = ids (HsCorpus.rows "candidates.tsv")
      val accept = HsCorpus.rows "accept.tsv"
      val reject = HsCorpus.rows "reject.tsv"
      val runs = HsCorpus.rows "run.tsv"
      val readingsText = read (fromRoot "tests/hs/readings.md")
      (* the oracles' ways, and rhc's on E7's conformance tests (G2) *)
      fun has (r : Expectations.line) = #category r <> "" andalso member (#way r) ("*" :: "rhc" :: HsOracles.oracles)
      val () = List.app (fn l => need (has l, Expectations.describe l ^ ": no oracle " ^ #way l)) ls
      val () = List.app (fn l => need (isSome (#label l) andalso member (valOf (#label l)) (conformanceLabels @ recordedLabels),
                                        Expectations.describe l ^ ": a line names its label, conformance, judge, open, ext or run")) ls
      val () = List.app (fn l => List.app (fn n => need (n <= 54 orelse String.isSubstring ("### R" ^ Int.toString n ^ ".") readingsText,
                                                         Expectations.describe l ^ ": R" ^ Int.toString n ^ " is not in tests/hs/readings.md"))
                                          (readings (#reason l))) ls
      (* each conformance test and oracle: a failure of what the suite
         expects has its line, naming its verdict; a pass has none *)
      fun conformance r =
        List.app (fn oracle =>
          let
            val got = HsCorpus.field r oracle
            val want = if String.isPrefix "accept" (HsCorpus.field r "expected") then "accept" else "reject"
            val passed = if want = "accept" then member got ["ok", "ok?", "accept"] else got = "reject"
            val x = {oracle = oracle, id = HsCorpus.field r "id", label = "conformance", got = got, want = want, passed = passed}
          in
            case HsOracles.decide ls x of
              HsOracles.Failure m => need (false, "E7's record does not agree with oracles.txt: " ^ m)
            | _ => ()
          end) HsOracles.oracles
      val () = List.app conformance conf
      (* the hard cases: each line cites a reading, but nhc98's two refusals
         of legal code *)
      val none = ["conformance98/ctxsimpl", "conformance98/identifiers/twiddle"]
      val () = List.app (fn r =>
                 if HsCorpus.field r "class" <> "hard" orelse member (HsCorpus.field r "id") none then ()
                 else need (List.exists (fn oracle =>
                              case Expectations.find (ls, {way = oracle, path = HsCorpus.field r "id", label = SOME "conformance"}) of
                                SOME l => not (null (readings (#reason l)))
                              | NONE => false) HsOracles.oracles,
                            HsCorpus.field r "id" ^ ": a hard case of E7 with no line that cites a reading")) conf
      (* a line of a recorded label names a candidate that has that record,
         and an outcome other than the one recorded *)
      fun recordedOutcomes label =
        case label of
          "run" => List.concat (List.map (fn r => List.map (fn oracle =>
                     (oracle, HsCorpus.field r "id",
                      case HsCorpus.field r (oracle ^ "_build") of
                        "fail" => "fail"
                      | b => b ^ "/" ^ HsCorpus.field r (oracle ^ "_rc") ^ "/" ^ HsCorpus.field r (oracle ^ "_out")))
                     ["ghc", "hugs", "nhc98"]) runs)
        | _ =>
            List.concat (List.map (fn r => List.mapPartial (fn oracle =>
              let val k = case label of "judge" => "v_" ^ oracle | "open" => "v_ghc_open" | _ => "v_" ^ oracle ^ "_ext"
              in case HsOracles.recorded (r, k) of "" => NONE | v => SOME (oracle, HsCorpus.field r "id", v) end)
              (if label = "open" then ["ghc"] else ["ghc", "hugs", "nhc98"])) (accept @ reject))
      (* a line of rhc's own programs (tests/hs, M19) is judged by their
         runner, not against the corpus's record *)
      fun own (l : Expectations.line) = String.isPrefix "hs/" (#path l)
      val () = List.app (fn l =>
                 case #label l of
                   SOME label =>
                     if own l then ()
                     else if member label recordedLabels then
                       let val hits = List.filter (fn (oracle, id, _) => Expectations.glob (#way l, oracle) andalso Expectations.glob (#path l, id))
                                                  (recordedOutcomes label)
                       in need (not (null hits), Expectations.describe l ^ ": names no candidate with a " ^ label ^ " record");
                          (* a lenient line may name either outcome; a strict one
                             names the one that is not E8's *)
                          need (Expectations.meaning (#category l) <> SOME Expectations.Strict
                                orelse List.all (fn (_, _, v) => v <> HsOracles.firstWord (#reason l)) hits,
                                Expectations.describe l ^ ": explains the outcome E8 recorded, which needs no line")
                       end
                     else if label = "conformance" then
                       need (List.exists (fn r => Expectations.glob (#path l, HsCorpus.field r "id")) conf,
                             Expectations.describe l ^ ": names no conformance test")
                     else ()
                 | NONE => ()) ls
    in finish "tests/hs/oracles.txt against the record" end
    handle HsCorpus.Bad m => (need (false, m); finish "tests/hs/oracles.txt against the record")
         | Expectations.Parse m => (need (false, m); finish "tests/hs/oracles.txt against the record")

  (* ---- rhc's findings and the -lazy ports' manifest ---- *)

  (* a line of tests/hs/rhc-corpus.txt names rhc, a candidate of accept.tsv
     whose judges both accept it (::check) or a ready -lazy port (::run),
     a cause after its outcome, and only readings that exist; each port of
     examples/benchmarks is in lazy-ports.tsv once, and a ready one names
     its upstream main and its fixture *)
  fun rhcText () =
    let
      val ports = HsLazyPorts.ports ()
      val ready = List.filter (fn r => #status r = "ready") ports
      val accept = HsCorpus.rows "accept.tsv"
      val both = List.map (fn r => HsCorpus.field r "id") (List.filter HsRhcCorpus.judgesAccept accept)
      val readingsText = read (fromRoot "tests/hs/readings.md")
      val ls = Expectations.read (HsRhcCorpus.expectations ())
      fun one (l : Expectations.line) =
        let
          val what = Expectations.describe l
          val word = HsOracles.firstWord (#reason l)
          val cause = HsOracles.trim (String.extract (#reason l, Int.min (size (#reason l), size word + 1), NONE))
        in
          need (#way l = "rhc", what ^ ": the way is rhc");
          need (isSome (Expectations.meaning (#category l)), what ^ ": no category " ^ #category l);
          need (size cause >= 10, what ^ ": a refusal is listed with its cause, never alone");
          List.app (fn n => need (n <= 54 orelse String.isSubstring ("### R" ^ Int.toString n ^ ".") readingsText,
                                  what ^ ": R" ^ Int.toString n ^ " is not in tests/hs/readings.md")) (readings (#reason l));
          case #label l of
            SOME "check" =>
              (need (List.exists (fn id => Expectations.glob (#path l, id)) both,
                     what ^ ": names no program of accept.tsv that both judges accept");
               need (member word ["reject", "crash", "timeout", "harness-error"], what ^ ": the outcome is reject, crash or timeout"))
          | SOME "levels" =>
              (* G2's runs of the nofib run set at -O0 and -O2 (tests/runner/hscorpusrun.sml) *)
              (need (List.exists (fn id => Expectations.glob (#path l, id)) (HsCorpusRun.levelsIds ()),
                     what ^ ": names no program of the nofib run set GHC ran right (run.tsv)");
               need (member word ["compile", "exit", "diff"], what ^ ": the outcome of a corpus run is compile, exit or diff"))
          | SOME "sestoft" =>
              (* ruling 59's way of D56's 188 (tests/runner/hscorpusrun.sml) *)
              (need (List.exists (fn id => Expectations.glob (#path l, id)) (List.map (fn r => HsCorpus.field r "id") (HsCorpusRun.d56 ())),
                     what ^ ": names no run of D56's 188 (licences.tsv)");
               need (member word ["compile", "exit", "diff"], what ^ ": the outcome of a corpus run is compile, exit or diff"))
          | SOME "run" =>
              if String.isPrefix "lazy/" (#path l) then
                (need (List.exists (fn r => Expectations.glob (#path l, "lazy/" ^ #port r)) ready,
                       what ^ ": names no ready -lazy port");
                 need (member word ["reject", "timeout", "diff", "rtfail", "harness-error"],
                       what ^ ": the outcome is reject, timeout, diff or rtfail"))
              else
                (* a run of D56's 188 (tests/runner/hscorpusrun.sml) *)
                (need (List.exists (fn id => Expectations.glob (#path l, id)) (List.map (fn r => HsCorpus.field r "id") (HsCorpusRun.d56 ())),
                       what ^ ": names no run of D56's 188 (licences.tsv) nor a ready -lazy port");
                 need (member word ["compile", "exit", "diff"], what ^ ": the outcome of a corpus run is compile, exit or diff"))
          | _ => need (false, what ^ ": the label is check, run, sestoft or levels")
        end
      val () = List.app one ls
      val bench = fromRoot "examples/benchmarks"
      val lazy = List.filter (fn n => String.isSuffix "-lazy" n andalso isDir (bench ^ "/" ^ n)) (sort (entries bench))
      val names = List.map #port ports
      val () = List.app (fn n => need (List.length (List.filter (fn m => m = n) names) = 1,
                                       "tests/hs/lazy-ports.tsv: " ^ n ^ " is not there once")) lazy
      val () = List.app (fn n => need (member n lazy, "tests/hs/lazy-ports.tsv: no port " ^ n ^ " in examples/benchmarks")) names
      val () = List.app (fn r => need (member (#status r) ["ready", "held"] andalso #reason r <> "",
                                       "tests/hs/lazy-ports.tsv: " ^ #port r ^ " is ready or held, with why")) ports
      val () = List.app (fn r => need (member (#variant r) ["", "h98", "rewrite", "harness"],
                                       "tests/hs/lazy-ports.tsv: " ^ #port r ^ "'s variant is none, h98, rewrite or harness")) ports
      val () = List.app (fn r =>
                 let val up = bench ^ "/" ^ #port r ^ "/upstream/"
                 in need (exists (up ^ #main r) andalso exists (up ^ #expected r)
                          andalso (#stdin r = "" orelse exists (up ^ #stdin r)),
                          "tests/hs/lazy-ports.tsv: " ^ #port r ^ " names a main, a fixture or an input not in its upstream")
                 end) ready
    in finish "tests/hs/rhc-corpus.txt and tests/hs/lazy-ports.tsv" end
    handle HsCorpus.Bad m => (need (false, m); finish "tests/hs/rhc-corpus.txt and tests/hs/lazy-ports.tsv")
         | Expectations.Parse m => (need (false, m); finish "tests/hs/rhc-corpus.txt and tests/hs/lazy-ports.tsv")

  (* ---- The source rewrites, on planted text ---- *)

  fun source () =
    let
      fun eq (what, got, want) = need (got = want, what ^ ": " ^ String.toString got ^ ", not " ^ String.toString want)
      fun eqs (what, got, want) = eq (what, String.concatWith "," got, String.concatWith "," want)
      fun eqb (what, got, want) = eq (what, Bool.toString got, Bool.toString want)
      val () = eq ("unlit, bird tracks", HsSource.unlit "text\n> main = x\nmore", "\n  main = x\n")
      val () = eq ("unlit, code blocks", HsSource.unlit "\\begin{code}\nf = 1\n\\end{code}\n> g", "\nf = 1\n\n  g")
      val () = eq ("a nested comment", HsSource.stripComments "a {- b {- c -} d -} e", "a                   e")
      val () = eq ("--> is an operator", HsSource.stripComments "x --> y -- c\nz", "x --> y     \nz")
      val () = eq ("a string is blanked", HsSource.stripComments "s = \"import X\"", "s =           ")
      val () = eqs ("imports", HsSource.importsOf "module M where\nimport qualified Data.List as L\nimport safe \"base\" Char\n  import\n   IO",
                   ["Data.List", "Char", "IO"])
      val () = eq ("the module", HsSource.moduleOf "\n\n  module A.B (x) where", "A.B")
      val () = eq ("no module", HsSource.moduleOf "main = print 1", "Main")
      val () = eq ("pragmas blanked", HsSource.blankPragmas "{-# LANGUAGE CPP #-}\n{-# OPTIONS_JHC -fx #-}\n{-# options_ghc\n -w #-}",
                   "                    \n{-# OPTIONS_JHC -fx #-}\n               \n       ")
      val () = eqb ("CPP in a pragma", HsSource.wantsCpp "{-# LANGUAGE BangPatterns, CPP #-}", true)
      val () = eqb ("a directive", HsSource.wantsCpp "x\n#  ifdef FOO\n", true)
      val () = eqb ("no preprocessor", HsSource.wantsCpp "{-# LANGUAGE CPPX #-}\n#line 3", false)
      val () = eq ("the import rewrite", HsSource.rewriteImports "import qualified Data.Map as M\nimport qualified Data.List\nimport Data.Char (ord)",
                   "import qualified Data.Map as M\nimport qualified List as Data.List\nimport Char (ord)")
      val () = eq ("the compat layer",
                   HsSource.harnessText ("module Main (main) where\nimport Control.Monad (forM_, when)\nimport Control.Exception\nmain = forM_ [1] print\n",
                                         "Main.hs"),
                   "module Main (main) where\nimport NofibCompat (forM_)\nimport Monad (when)\n\nmain = forM_ [1] print\n")
      val () = eq ("the compat layer, no import", HsSource.harnessText ("module Main where {\nmain = pure ()}", "Main.hs"),
                   "module Main where {\nimport NofibCompat (pure);\n\nmain = pure ()}")
      val () = eq ("newlines", HsSource.universal "a\r\nb\rc", "a\nb\nc")
    in finish "the source rewrites" end

  (* ---- The harness on fake oracles ---- *)

  (* a fake GHC: a check accepts a source that says ACCEPT, and a build makes
     a Main.ghc that prints what HELLO says *)
  val fakeGhc =
    "#!/bin/sh\nfor a; do last=$a; done\n"
    ^ "case \" $* \" in *\" -o Main.ghc \"*) printf '#!/bin/sh\\nprintf \"%s\"\\n' \"${HELLO-hello\\n}\" > Main.ghc; chmod +x Main.ghc; exit 0;; esac\n"
    ^ "grep -q ACCEPT \"$last\"\n"

  fun faults () =
    let
      val d = run ^ "/hs-faults"
      val () = (rmTree d; mkdirs d)
      val corpus = d ^ "/corpus"
      val dataDir = d ^ "/data"
      val () = mkdirs (corpus ^ "/ghc/testsuite/tests/x")
      val () = write (corpus ^ "/ghc/testsuite/tests/x/A.hs", "-- ACCEPT\nmain = print 1\n")
      val () = write (corpus ^ "/ghc/testsuite/tests/x/B.hs", "main = print 2\n")
      val () = mkdirs dataDir
      val () = write (dataDir ^ "/trees.tsv", "set\ttree\tdir\tupstream\tcommit\tlicence\nghc-legacy\tghc\ttestsuite/tests\t-\t-\t-\n"
                                              ^ "jhc\tjhc\tregress/tests\t-\t-\t-\n")
      val () = mkdirs (corpus ^ "/jhc")
      val () = write (dataDir ^ "/candidates.tsv",
                      "id\tset\tpath\tparent\texpect\texpect_src\nghc/x/A\tghc-legacy\tghc/testsuite/tests/x/A.hs\t-\tcompile\t\n"
                      ^ "ghc/x/B\tghc-legacy\tghc/testsuite/tests/x/B.hs\t-\tcompile\t\n")
      fun records (a, b) = write (dataDir ^ "/accept.tsv", "id\tv_hugs\tv_ghc\tv_nhc98\tv_ghc_open\nghc/x/A\taccept\t" ^ a
                                                          ^ "\taccept\t\nghc/x/B\taccept\t" ^ b ^ "\taccept\t\n")
      val () = write (dataDir ^ "/reject.tsv", "id\tv_hugs\tv_ghc\tv_nhc98\n")
      val ghc = d ^ "/ghc"
      val () = write (ghc, fakeGhc)
      val () = Posix.FileSys.chmod (ghc, Posix.FileSys.S.irwxu)
      val counter = ref 0
      (* the jobs run here, in this process, on the fake data and the fake
         GHC: what they say is taken, not printed, so that their planted
         failures are not the check's *)
      fun job (runs, lines, hello) =
        let
          val () = counter := !counter + 1
          val n = Int.toString (!counter)
          val txt = d ^ "/oracles-" ^ n ^ ".txt"
          val () = write (txt, String.concatWith "\n" lines ^ "\n")
          val said = ref []
          fun set (data, root, g, outDir, oracles, extra, sink) =
            (HsCorpus.dataOverride := data; HsCorpus.rootOverride := root; HsOracles.ghcOverride := g;
             HsOracles.outOverride := outDir; HsOracles.oraclesOverride := oracles; HsOracles.extraEnv := extra;
             HsOracles.sink := sink)
          fun reset () = set (NONE, NONE, NONE, NONE, NONE, [], say)
          val () = set (SOME dataDir, SOME corpus, SOME ghc, SOME (d ^ "/out-" ^ n), SOME txt, [("HELLO", hello)],
                        fn s => said := s :: !said)
          val () = (List.app (fn f => f ()) runs; reset ()) handle e => (reset (); raise e)
        in String.concat (rev (!said)) end
      val judge = fn () => HsOracles.judge ("ghc", "ghc-legacy")
      val stale = fn () => HsOracles.stale "ghc"
      fun saw (what, text, s) = need (String.isSubstring s text, what ^ ": no " ^ String.toString s ^ " in " ^ String.toString text)
      fun not' (what, text, s) = need (not (String.isSubstring s text), what ^ ": " ^ String.toString s ^ " in " ^ String.toString text)
      val bLine = "ghc | ghc/x/B::judge | HOST-BUG | reject: planted"
      (* E8 recorded B accepted: the fake refuses it *)
      val () = records ("accept", "accept")
      val t = job ([judge], [], "hello\\n")
      val () = saw ("a verdict that differs from the record", t, "FAIL ghc ghc/x/B::judge: reject, where E8 recorded accept")
      val () = not' ("a verdict that agrees", t, "ghc/x/A")
      val t = job ([judge, stale], [bLine], "hello\\n")
      val () = not' ("a line that explains the difference", t, "FAIL")
      val () = saw ("a line that explains the difference", t, "1 explained")
      val t = job ([judge], ["ghc | ghc/x/B::judge | HOST-BUG | accept: planted"], "hello\\n")
      val () = saw ("a line of another outcome", t, "says accept")
      val t = job ([judge], [bLine, "ghc | ghc/x/A | HOST-BUG | reject: planted"], "hello\\n")
      val () = saw ("a line for what passes", t, "FAIL ghc ghc/x/A::judge: accept as expected")
      val t = job ([judge, stale], [bLine, "ghc | ghc/x/* | HOST-BUG | reject: planted again"], "hello\\n")
      val () = saw ("a line that no failure uses", t, "FAIL stale ghc")
      val t = job ([judge], [bLine], "")
      val () = saw ("an oracle that prints nothing", t, "FAIL ghc does not run hello")
      val () = not' ("an oracle that prints nothing", t, "explained")
      val () = records ("accept", "reject")
      val t = job ([judge, stale], [], "hello\\n")
      val () = not' ("the record agreeing", t, "FAIL")
      val t = job ([fn () => HsOracles.judge ("ghc", "jhc")], [], "hello\\n")
      val () = saw ("a set with no candidate", t, "nothing was judged")
    in finish "the oracle harness on fake oracles" end

  (* ---- rhc's corpus jobs on a fake rhc (tests/runner/hsrhccorpus.sml) ---- *)

  (* a fake rhc: a source that says REFUSE has a diagnostic, one that says
     CRASH an uncaught exception *)
  val fakeRhc =
    "#!/bin/sh\nfor a; do last=$a; done\n"
    ^ "if grep -q CRASH \"$last\"; then echo 'rhc: uncaught exception Fail' >&2; exit 1; fi\n"
    ^ "if grep -q REFUSE \"$last\"; then echo \"$last:1:1: error: planted\" >&2; exit 1; fi\nexit 0\n"

  fun rhcFaults () =
    let
      val d = run ^ "/hs-rhc-faults"
      val () = (rmTree d; mkdirs d)
      val corpus = d ^ "/corpus"
      val dataDir = d ^ "/data"
      val x = corpus ^ "/ghc/testsuite/tests/x"
      val () = mkdirs x
      val () = List.app (fn (n, t) => write (x ^ "/" ^ n ^ ".hs", t))
                 [("A", "main = print 1\n"), ("B", "-- REFUSE\nmain = print 2\n"), ("C", "-- CRASH\nmain = print 3\n"),
                  ("D", "-- REFUSE\nmain = print 4\n")]
      val () = mkdirs dataDir
      val () = write (dataDir ^ "/trees.tsv", "set\ttree\tdir\tupstream\tcommit\tlicence\nghc-legacy\tghc\ttestsuite/tests\t-\t-\t-\n"
                                              ^ "jhc\tjhc\tregress/tests\t-\t-\t-\n")
      val () = mkdirs (corpus ^ "/jhc")
      val () = write (dataDir ^ "/candidates.tsv",
                      "id\tset\tpath\tparent\texpect\texpect_src\n"
                      ^ String.concat (List.map (fn n => "ghc/x/" ^ n ^ "\tghc-legacy\tghc/testsuite/tests/x/" ^ n ^ ".hs\t-\tcompile\t\n")
                                                ["A", "B", "C", "D"]))
      (* D is one the judges do not both accept: rhc's refusal is recorded *)
      val () = write (dataDir ^ "/accept.tsv",
                      "id\tset\tneeds\tv_hugs\tv_ghc\n"
                      ^ String.concat (List.map (fn (n, h) => "ghc/x/" ^ n ^ "\tghc-legacy\tnothing\t" ^ h ^ "\taccept\n")
                                                [("A", "accept"), ("B", "accept"), ("C", "accept"), ("D", "reject")]))
      val rhc = d ^ "/rhc"
      val () = write (rhc, fakeRhc)
      val () = Posix.FileSys.chmod (rhc, Posix.FileSys.S.irwxu)
      val counter = ref 0
      (* the jobs run here, in this process, on the fake data: what they say
         is taken, not printed, so that their planted failures are not the
         check's *)
      fun job (runs, lines) =
        let
          val () = counter := !counter + 1
          val n = Int.toString (!counter)
          val txt = d ^ "/rhc-corpus-" ^ n ^ ".txt"
          val () = write (txt, String.concatWith "\n" lines ^ "\n")
          val said = ref []
          fun set (data, root, r, outDir, expect, sink) =
            (HsCorpus.dataOverride := data; HsCorpus.rootOverride := root; HsRhcCorpus.rhcOverride := r;
             HsRhcCorpus.outOverride := outDir; HsRhcCorpus.expectOverride := expect; HsRhcCorpus.sink := sink)
          fun reset () = set (NONE, NONE, NONE, NONE, NONE, say)
          val () = set (SOME dataDir, SOME corpus, SOME rhc, SOME (d ^ "/out-" ^ n), SOME txt, fn s => said := s :: !said)
          val () = (List.app (fn f => f ()) runs; reset ()) handle e => (reset (); raise e)
        in String.concat (rev (!said)) end
      val m13 = fn () => HsRhcCorpus.check ("m13", "ghc-legacy")
      val stale = HsRhcCorpus.stale
      fun saw (what, text, s) = need (String.isSubstring s text, what ^ ": no " ^ String.toString s ^ " in " ^ String.toString text)
      fun not' (what, text, s) = need (not (String.isSubstring s text), what ^ ": " ^ String.toString s ^ " in " ^ String.toString text)
      val bLine = "rhc | ghc/x/B::check | RUNE-DEV | reject: planted"
      val cLine = "rhc | ghc/x/C::check | RUNE-DEV | crash: planted"
      val t = job ([m13], [])
      val () = saw ("a refusal of what the judges accept", t, "FAIL rhc ghc/x/B::check: reject")
      val () = saw ("a crash", t, "FAIL rhc ghc/x/C::check: crash")
      val () = not' ("what rhc accepts", t, "ghc/x/A")
      val t = job ([fn () => HsRhcCorpus.check ("rest", "ghc-legacy")], [])
      val () = not' ("a refusal of what the judges do not both accept", t, "FAIL")
      val () = saw ("a refusal of what the judges do not both accept", t, "1 recorded")
      val t = job ([m13, stale], [bLine, cLine])
      val () = not' ("lines that explain each refusal", t, "FAIL")
      val () = saw ("lines that explain each refusal", t, "2 refusals explained")
      val t = job ([m13], [bLine, "rhc | ghc/x/C::check | RUNE-DEV | reject: planted"])
      val () = saw ("a line of another outcome", t, "says reject")
      val t = job ([m13], [bLine, cLine, "rhc | ghc/x/A::check | RUNE-DEV | reject: planted"])
      val () = saw ("a line for what rhc accepts", t, "FAIL rhc ghc/x/A::check: accept, where")
      val t = job ([m13, stale], [bLine, cLine, "rhc | ghc/x/* | RUNE-DEV | reject: planted again"])
      val () = saw ("a line that no refusal uses", t, "FAIL stale rhc")
      val t = job ([fn () => HsRhcCorpus.check ("m13", "jhc")], [])
      val () = saw ("a part with no row", t, "nothing was checked")
    in finish "rhc's corpus jobs on a fake rhc" end

  fun command ["hs-corpus-data"] = SOME (fn () => (data (); oraclesText (); rhcText ()))
    | command ["hs-corpus-vendor"] = SOME vendor
    | command ["hs-corpus-vendored"] = SOME vendoredUpstream
    | command ["hs-source"] = SOME source
    | command ["hs-faults"] = SOME (fn () => (faults (); rhcFaults ()))
    | command _ = NONE
end

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
      val () = List.app (fn r => need (member (HsCorpus.field r "vendor") ["vendor", "outside", "owner"],
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
      val () = List.app (fn p =>
                 let val r = HsCorpus.relative (root, p)
                 in need (member r own orelse (String.isPrefix "compat/" r andalso String.isSuffix ".sed" r),
                          r ^ " is under tests/hs/corpus, and is neither its data nor its compat layer: a program lands only "
                          ^ "with a surveyed licence and the owner's choice (README.md)") end) (walk root)
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
      fun has (r : Expectations.line) = #category r <> "" andalso member (#way r) ("*" :: HsOracles.oracles)
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
      fun job (args, lines, hello) =
        let
          val () = counter := !counter + 1
          val n = Int.toString (!counter)
          val txt = d ^ "/oracles-" ^ n ^ ".txt"
          val () = write (txt, String.concatWith "\n" lines ^ "\n")
          val changes = [("RUNE_HS_DATA", dataDir), ("RUNE_HS_CORPUS", corpus), ("RUNE_HS_GHC", ghc),
                         ("RUNE_HS_OUT", d ^ "/out-" ^ n), ("RUNE_HS_ORACLES_TXT", txt), ("HELLO", hello)]
          fun one a = (execEnv (fn e => List.foldl (fn ((k, v), e) => setEnv (k, v) e) e changes)
                         {cmd = [fromRoot "bin/rune-test"] @ a, dir = NONE, stdin = "", stdout = d ^ "/stdout-" ^ n,
                          stderr = d ^ "/stderr-" ^ n, timeout = 300};
                       read (d ^ "/stdout-" ^ n))
        in String.concat (List.map one args) end
      val judge = ["hs-oracle", "judge", "ghc", "ghc-legacy"]
      val stale = ["hs-oracle", "stale", "ghc"]
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
      val t = job ([["hs-oracle", "judge", "ghc", "jhc"]], [], "hello\\n")
      val () = saw ("a set with no candidate", t, "nothing was judged")
    in finish "the oracle harness on fake oracles" end

  fun command ["hs-corpus-data"] = SOME (fn () => (data (); oraclesText ()))
    | command ["hs-source"] = SOME source
    | command ["hs-faults"] = SOME faults
    | command _ = NONE
end

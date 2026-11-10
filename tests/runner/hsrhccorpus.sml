(* rhc on E8's corpus (the haskell98 roadmap's M19, *The corpus*; M13's
   done-when): each program of tests/hs/corpus/accept.tsv put through
   bin/rhc in the variants the oracles judge it in (HsCorpus.prepare), as
   far as rhc goes: `--typecheck-only`, which stops after names and fixity
   until M13 lands and then checks the types. The trees are read through
   RUNE_HS_CORPUS, as the oracles' jobs read them, since none is vendored.

   A program both judges accept (D52: GHC and Hugs) and rhc refuses is a
   finding: it fails its job unless a line of tests/hs/rhc-corpus.txt says
   why, in the format of Expectations (`rhc | SET/ID::check | RUNE-DEV |
   reject: ...`), its reason beginning with the outcome it explains; a line
   that explains no failure of a job that ran is stale. A refusal is never
   taken as expected without its cause. A program the judges do not both
   accept goes through rhc too, and what rhc says is kept in the job's
   results, not judged: the names and fixity rhc has checked so far say
   nothing of what the judges refuse.

   M13's own list is its own jobs, `m13-SET`: the 815 rows both judges
   accept that need nothing (`nothing` or `nothing+cpp`), in the variant
   `h98`; `rest-SET` takes the other rows of the set. Once rhc compiles, M13
   holds `--typecheck-only` to agree with the compile on each of the 815:
   that comparison joins these jobs then. Nightly, by capability: rhc and
   the corpus. *)
structure HsRhcCorpus =
struct
  open Sh

  fun out () = fromRoot (env ("RUNE_HS_OUT", run ^ "/hs-rhc-corpus"))
  fun expectations () = env ("RUNE_HS_RHC_TXT", fromRoot "tests/hs/rhc-corpus.txt")
  fun rhc () = env ("RUNE_HS_RHC", fromRoot "bin/rhc")
  val gib = 1024 * 1024 * 1024
  val limits = {addressSpace = SOME (6 * gib), cpuTime = NONE, fileSize = SOME gib, core = SOME 0}

  (* ---- Which rows, and what is wanted of them ---- *)

  fun judgesAccept r = HsCorpus.field r "v_ghc" = "accept" andalso HsCorpus.field r "v_hugs" = "accept"
  fun needsNothing r = let val n = HsCorpus.field r "needs" in n = "nothing" orelse n = "nothing+cpp" end
  (* M13's done-when: the rows both judges accept that need nothing *)
  fun m13 r = judgesAccept r andalso needsNothing r

  (* ---- rhc on a program ---- *)

  (* rhc's check of a prepared program: accept; reject, a diagnostic of the
     program's (`FILE:LINE:COL: error: ...`, status 1); timeout; or crash,
     any other end, an uncaught exception among them *)
  fun checkOne log (p, m) =
    let
      val () = mkdirs (OS.Path.dir log)
      val status = execProcess false limits (fn e => e)
                     {cmd = [rhc (), "--typecheck-only", m], dir = SOME p, stdin = "", stdout = log ^ ".out",
                      stderr = log ^ ".err", timeout = 300}
      val err = read (log ^ ".err")
      fun diagnostic () = List.exists (fn l => String.isSubstring ": error: " l) (lines err)
                          andalso not (String.isSubstring "uncaught exception" err)
    in
      if status = 0 then ("accept", "")
      else if status = 124 then ("timeout", "")
      else if status = 1 andalso diagnostic () then ("reject", firstNonEmpty (log ^ ".err"))
      else ("crash", "status " ^ Int.toString status ^ ": " ^ firstNonEmpty (log ^ ".err"))
    end

  (* what rhc did with a program, whether it is what is wanted, and whether
     it is judged at all (or only recorded), with what is wanted in words *)
  type outcome = {id : string, label : string, got : string, said : string, passed : bool, judged : bool, want : string}
  fun note (file, text) = (mkdirs (OS.Path.dir file); write (file, text))

  fun noHarness id = String.isPrefix "nofib/parallel/" id orelse String.isPrefix "nofib/smp/" id

  (* a program in the variants the oracles judge it in, the first rhc
     accepts; M13's rows in h98 alone *)
  fun one only13 (row, c : HsCorpus.candidate) =
    let
      val id = #id c
      val work = out () ^ "/work/" ^ id
      val log = out () ^ "/logs/" ^ id
      val {files, rewritable, ...} = HsCorpus.closureOf c
      val variants =
        if only13 then ["h98"]
        else ["h98"] @ (if null rewritable then [] else ["rewrite"])
             @ (if #set c = "nofib-2019" andalso not (noHarness id) then ["harness"] else [])
      fun go [] first = first
        | go (v :: vs) first =
            let val r = checkOne (log ^ "." ^ v) (HsCorpus.prepare (c, v, files, work ^ "/" ^ v))
            in if #1 r = "accept" then SOME r else go vs (case first of NONE => SOME r | s => s) end
      val (got, said) = case go variants NONE of SOME r => r | NONE => ("accept", "")
    in rmTree work; {id = id, label = "check", got = got, said = said, passed = got = "accept", judged = judgesAccept row,
                     want = "GHC and Hugs accept it"} : outcome end
    handle e => (note (out () ^ "/logs/" ^ #id c ^ ".exn", exnMessage e ^ "\n");
                 {id = #id c, label = "check", got = "harness-error", said = exnMessage e, passed = false, judged = true,
                  want = "GHC and Hugs accept it"})

  (* ---- What is expected ---- *)

  datatype verdict = Pass | Explained of string | Recorded | Failure of string
  fun key (l : Expectations.line) =
    String.concatWith " | " [#way l, #path l ^ (case #label l of SOME x => "::" ^ x | NONE => ""), #category l, #reason l]
  fun firstWord r = HsOracles.trim (hd (String.fields (fn c => c = #":") r))
  fun place (l : Expectations.line) = OS.Path.file (#file l) ^ ":" ^ Int.toString (#number l)

  fun decide ls (x as {id, label, got, said, passed, judged, want} : outcome) =
    let val what = "rhc " ^ id ^ "::" ^ label ^ ": " ^ got ^ (if said = "" then "" else " (" ^ said ^ ")")
    in
      case Expectations.find (ls, {way = "rhc", path = id, label = SOME label}) of
        NONE => if passed then Pass else if judged then Failure (what ^ ", where " ^ want) else Recorded
      | SOME l =>
          case Expectations.meaning (#category l) of
            SOME Expectations.Strict =>
              if passed then Failure ("rhc " ^ id ^ "::" ^ label ^ ": " ^ got ^ ", where " ^ place l ^ " says "
                                      ^ firstWord (#reason l))
              else if firstWord (#reason l) = got then Explained (key l)
              else Failure (what ^ ", where " ^ place l ^ " says " ^ firstWord (#reason l))
          | SOME Expectations.Lenient => Explained (key l)
          | _ => if passed orelse not judged then Pass else Failure (what ^ ", where " ^ want)
    end

  fun results () = out () ^ "/results"
  fun report (job, os : outcome list) =
    let
      val ls = Expectations.read (expectations ())
      val vs = List.map (fn x => (x, decide ls x)) os
      val () = mkdirs (results ())
      val () = write (results () ^ "/" ^ job ^ ".tsv", String.concat (List.map (fn (x : outcome, v) =>
                 String.concatWith "\t" [case v of Pass => "PASS" | Explained _ => "EXPLAINED" | Recorded => "RECORDED"
                                                 | Failure _ => "FAIL",
                                         #id x, #label x, #got x, case v of Explained k => k | _ => "-",
                                         String.translate (fn #"\t" => " " | c => str c) (#said x)] ^ "\n") vs))
      fun count p = List.length (List.filter p vs)
      val failures = List.mapPartial (fn (_, Failure m) => SOME m | _ => NONE) vs
    in
      List.app (fn m => say ("FAIL " ^ m ^ "\n")) failures;
      if null os then say ("FAIL rhc " ^ job ^ ": nothing was checked\n")
      else say ((if null failures then "PASS " else "SUMMARY ") ^ "rhc " ^ job ^ ": " ^ Int.toString (length os)
                ^ " programs, " ^ Int.toString (count (fn (x, _) => #passed x)) ^ " as wanted, "
                ^ Int.toString (count (fn (_, v) => case v of Explained _ => true | _ => false)) ^ " refusals explained by "
                ^ expectations () ^ ", " ^ Int.toString (count (fn (_, v) => v = Recorded))
                ^ " recorded where the judges do not both accept, " ^ Int.toString (length failures) ^ " failures\n")
    end

  (* the strict lines that explain no failure of a job that ran *)
  fun stale () =
    let
      val ls = Expectations.read (expectations ())
      val rs = List.concat (List.map (fn f => List.mapPartial (fn l => case String.fields (fn c => c = #"\t") l of
                                                                          v :: id :: label :: _ :: k :: _ => SOME (v, id, label, k)
                                                                        | _ => NONE)
                                                              (lines (read f))) (glob (results (), ".tsv")))
      fun ran (l : Expectations.line) =
        List.exists (fn (_, id, label, _) => isSome (Expectations.find ([l], {way = "rhc", path = id, label = SOME label}))) rs
      fun used (l : Expectations.line) = List.exists (fn (v, _, _, k) => v = "EXPLAINED" andalso k = key l) rs
      val bad = List.filter (fn l => Expectations.meaning (#category l) = SOME Expectations.Strict andalso ran l
                                     andalso not (used l)) ls
    in
      if null rs then say "FAIL rhc: no job left results\n" else ();
      List.app (fn l => say ("FAIL stale rhc: " ^ Expectations.describe l ^ "\n")) bad;
      if null bad andalso not (null rs) then say ("PASS rhc: no line of " ^ expectations () ^ " is stale\n") else ()
    end

  (* ---- The jobs ---- *)

  (* the rows of a set, M13's or the rest, each with its candidate *)
  fun rowsOf (part, set) =
    let
      val cs = HsCorpus.candidates ()
      fun cand id = case List.find (fn (c : HsCorpus.candidate) => #id c = id) cs of
                      SOME c => c | NONE => raise HsOracles.Failed ("no candidate " ^ id)
      val rows = List.filter (fn r => HsCorpus.field r "set" = set andalso HsOracles.only (HsCorpus.field r "id")
                                      andalso (if part = "m13" then m13 r else not (m13 r)))
                             (HsCorpus.rows "accept.tsv")
    in List.map (fn r => (r, cand (HsCorpus.field r "id"))) rows end

  fun check (part, set) =
    (HsOracles.pinned set;
     if not (exists (rhc ())) then say ("FAIL rhc " ^ part ^ "-" ^ set ^ ": no " ^ rhc () ^ " (make bin/rhc)\n")
     else report (part ^ "-" ^ set, List.map (one (part = "m13")) (rowsOf (part, set))))
    handle HsOracles.Failed m => say ("FAIL rhc " ^ part ^ "-" ^ set ^ ": " ^ m ^ "\n")
         | HsCorpus.Bad m => say ("FAIL rhc " ^ part ^ "-" ^ set ^ ": " ^ m ^ "\n")

  val sets = HsOracles.judgeSets
  (* every set has rows of both parts (accept.tsv); the tree reads no data,
     so that a run with other data builds it *)
  val parts = List.concat (List.map (fn s => [("m13", s), ("rest", s)]) sets)

  fun tree () =
    let
      val names = List.map (fn (p, s) => p ^ "-" ^ s) parts
      val jobs = List.map (fn (p, s) => HsOracles.job (p ^ "-" ^ s, ["hs-rhc-corpus", p, s], [], 14400, 2000)) parts
    in
      Test.tag "covers:tests/hs/corpus/*" (Test.tag "covers:tests/hs/rhc-corpus.txt"
        (Test.tag "covers:tests/runner/hsrhccorpus.sml" (Test.tag "nightly"
          (Test.requires ["rhc", "hs-corpus"]
            (Test.describe "hs-rhc-corpus"
              (jobs @ [HsOracles.job ("@stale", ["hs-rhc-corpus", "stale"], List.map (fn n => "hs-rhc-corpus/" ^ n) names,
                                      300, 100)]))))))
    end

  fun command ["hs-rhc-corpus", "stale"] = SOME stale
    | command ["hs-rhc-corpus", part, set] =
        if (part = "m13" orelse part = "rest") andalso List.exists (fn s => s = set) sets
        then SOME (fn () => check (part, set)) else NONE
    | command _ = NONE
end

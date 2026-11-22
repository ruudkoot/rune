(* The Core simplifier's figures (the haskell98 roadmap's M23, *Decisions on
   the numbers*: D48's D against C, D34's B against A after the
   simplifier): a program of the run set compiled by rhc in several ways and
   run on bin/runevm, each way's output held to the program's own and to
   -O0's, with the instructions, bytes and objects `runevm --count` gives,
   the suspensions made (`runevm-census --census-summary`: thunk_make's
   calls) and, where perf is there, the instructions:u of a run at tier 2,
   and of the suspensions those copied (the census's THUNK objects, a
   suspension of a code that captures nothing, which thunk_make allocates
   apart where it makes the rest of their closures in place). Measured, not
   adopted: the owner decides on the figures.

   `bin/rune-test hs-simplify-figures SET ID OUT [WAY...]` appends a line a
   way to OUT, tab-separated: the set (lang, corpus or lazy), the id, the
   way, whether rhc compiled it, the run's status, whether it printed the
   program's expected output and what -O0 printed, then instructions,
   bytes, objects, suspensions, instructions:u and suspensions copied (-
   where not measured). `bin/rune-test hs-simplify-compile SET ID OUT
   [WAY...]` prepares the program alike and only compiles it, a line a way:
   the set, the id, the way, whether rhc compiled it, the compile's
   instructions:u and the bytecode's bytes (D34's compile time and size).
   The ways are O0 and O2, each the level's defaults (the pedantic rule;
   the Report's order at -O0, Sestoft's trees at -O2 since the owner's
   decision on D34 of 2026-11-15), O2-report (D34's A at -O2), O2-ghc
   (D48's D), O2-sestoft and O0-sestoft (D34's B), O2-nostrict (M24's
   strictness off, E3's L2 step against O2), all of them where none
   is named or where `all` is; and, where named, iO0 and iO2, the program
   run on Core's interpreter, whose sameness is to iO0's, and `stats`, a
   compile at -O2 under each eta rule that runs nothing and counts its eta
   rewrites (eta, eta-refused, eta-ghc, all, for C then D). A program of
   tests/hs/lang is prepared as tests/runner/hslang.sml runs it, one of the
   corpus as hs-corpus-run, a lazy port as hs-lazy-ports (the first variant
   rhc compiles). *)
structure HsSimplifyFigures =
struct
  open Sh

  val gib = 1024 * 1024 * 1024
  val limits = {addressSpace = SOME (6 * gib), cpuTime = NONE, fileSize = SOME gib, core = SOME 0}

  val ways = [("O0", ["-O0"]), ("O2", ["-O2"]), ("O2-report", ["-O2", "--match=report"]), ("O2-ghc", ["-O2", "--eta=ghc"]),
              ("O2-sestoft", ["-O2", "--match=sestoft"]), ("O0-sestoft", ["-O0", "--match=sestoft"]),
              ("O2-nostrict", ["-O2", "--strictness=off"])]
  (* the ways on Core's interpreter, named and never all: iO0 and iO2, the
     program run by rhc itself, its output held to iO0's *)
  val interpreted = [("iO0", ["-O0"]), ("iO2", ["-O2"])]

  (* a program ready to compile: where, its main file, where it runs, its
     arguments and standard input, and what it must print *)
  type prog = {dir : string, main : string, runDir : string, fresh : bool, args : string list, stdin : string,
               expected : string}

  (* the rhc measured, RUNE_HS_RHC for another build's (an earlier one,
     for a figure before and after), bin/rhc where none is named *)
  fun rhc () = env ("RUNE_HS_RHC", fromRoot "bin/rhc")

  fun call (cmd, dir, stdin, out, err, timeout) =
    execProcess false limits (fn e => e) {cmd = cmd, dir = SOME dir, stdin = stdin, stdout = out, stderr = err, timeout = timeout}

  fun lineAfter (file, prefix) =
    case List.find (String.isPrefix prefix) (lines (read file)) of
      SOME l => SOME (String.extract (l, size prefix, NONE))
    | NONE => NONE

  (* the first number in s *)
  fun firstNumber s =
    let val digits = String.tokens (fn c => not (Char.isDigit c)) s
    in case digits of d :: _ => d | [] => "-" end

  (* hs-simplify-compile: each way compiled and nothing run, the compile's
     instructions:u (perf) and the bytecode's bytes its line: set, id, way,
     compiled, instructions, bytes *)
  val compileOnly = ref false

  fun compileWays (set, id, p : prog, out, chosen) =
    let
      fun one (name, flags) =
        let
          val rbcDir = #dir p ^ "/way"
          val () = (rmTree rbcDir; mkdirs rbcDir)
          val rbc = rbcDir ^ "/" ^ OS.Path.base (OS.Path.file (#main p)) ^ ".rbc"
          fun f x = #dir p ^ "/" ^ name ^ "." ^ x
          val cs = call (["perf", "stat", "-x", ",", "-e", "instructions:u", "-o", f "cperf", rhc (), #main p] @ flags @ ["-o", rbc],
                         #dir p, "", f "c.out", f "c.err", 1800)
          val instr =
            case List.find (fn l => String.isSubstring "instructions" l) (lines (read (f "cperf"))) of
              SOME l => (case String.fields (fn c => c = #",") l of n :: _ => n | [] => "-")
            | NONE => "-"
          val bytes = if cs = 0 andalso exists rbc then Int.toString (Position.toInt (OS.FileSys.fileSize rbc)) else "-"
        in append (out, String.concatWith "\t" [set, id, name, if cs = 0 then "yes" else "no", instr, bytes] ^ "\n") end
      val selected = if null chosen orelse List.exists (fn m => m = "all") chosen then ways
                     else List.filter (fn (n, _) => List.exists (fn m => m = n) chosen) ways
    in List.app one selected end

  fun measure (set, id, p : prog, out, chosen) =
    if !compileOnly then compileWays (set, id, p, out, chosen) else
    let
      val runevm = fromRoot "bin/runevm"
      val census = fromRoot "bin/runevm-census"
      val haveCensus = exists census
      val havePerf = exec {cmd = ["sh", "-c", "command -v perf"], dir = NONE, stdin = "", stdout = "/dev/null", stderr = "/dev/null",
                           timeout = 10} = 0
      val o0out = ref NONE
      val i0out = ref NONE
      (* where a run runs: with `fresh`, a directory of its own, empty, so
         that what one way's run writes no other's sees *)
      fun runIn tag =
        if #fresh p then let val d = #runDir p ^ "/run." ^ tag in rmTree d; mkdirs d; d end
        else #runDir p
      (* on Core's interpreter: its output against the program's and iO0's *)
      fun interp (name, flags) =
        let
          fun f x = #dir p ^ "/" ^ name ^ "." ^ x
          (* the interpreter is slow by design: a run past 300 s is not
             compared, its status 124 *)
          val rs = call ([rhc (), #main p] @ flags @ (case #args p of [] => [] | a => "--" :: a), runIn name, #stdin p,
                         f "out", f "err", 300)
          val output = read (f "out")
          val () = if name = "iO0" then i0out := SOME output else ()
          val row = [name, "yes", Int.toString rs, if output = #expected p then "yes" else "no",
                     case !i0out of SOME first => if output = first then "yes" else "no" | NONE => "-",
                     "-", "-", "-", "-", "-", "-"]
        in append (out, String.concatWith "\t" ([set, id] @ row) ^ "\n") end
      fun one (name, flags) =
        let
          (* every way's bytecode at one path, the main file's base in one
             directory, made again for each way: getProgName reads the
             bytecode's path, a character at a time, so that a program that
             prints it costs more for a longer one, and a way's name in the
             path was measured as the way's (nhcnofib/real/grep) *)
          val rbcDir = #dir p ^ "/way"
          val () = (rmTree rbcDir; mkdirs rbcDir)
          val rbc = rbcDir ^ "/" ^ OS.Path.base (OS.Path.file (#main p)) ^ ".rbc"
          fun f x = #dir p ^ "/" ^ name ^ "." ^ x
          val cs = call ([rhc (), #main p] @ flags @ ["-o", rbc], #dir p, "", f "c.out", f "c.err", 1800)
          val row =
            if cs <> 0 then [name, "no", "-", "-", "-", "-", "-", "-", "-", "-", "-"]
            else
              let
                val rs = call ([runevm, "--count", rbc] @ #args p, runIn (name ^ ".count"), #stdin p, f "out", f "err", 1800)
                val output = read (f "out")
                val () = if name = "O0" then o0out := SOME output else ()
                val count = getOpt (lineAfter (f "err", "runevm: count: "), "")
                val fields = String.tokens (fn c => c = #",") count
                fun nth i = if length fields > i then firstNumber (List.nth (fields, i)) else "-"
                (* the suspensions made, thunk_make's calls (its line of the
                   census's primitive results), and of them those copied, a
                   THUNK allocated apart for a code that captures nothing,
                   where the rest are their closures made suspensions in place
                   (runtime/prims.c, p_thunk_make) *)
                val (thunks, copies) =
                  if not haveCensus then ("-", "-")
                  else
                    let
                      val d = f "census"
                      val () = rmTree d
                      (* no forced collection: the census collects where the
                         stock VM does (docs/census.md) *)
                      val _ = call ([census, "--census-dir", d, "--census-every", "0", "--census-summary", rbc] @ #args p,
                                    runIn (name ^ ".census"), #stdin p,
                                    "/dev/null", f "census.err", 1800)
                      val text = d ^ "/census.txt"
                      val made = if exists text then getOpt (lineAfter (text, "thunk_make\tPTR\t"), "0") else "-"
                      val copied = if exists text then getOpt (lineAfter (text, "THUNK\t"), "0") else "-"
                    in rmTree d; (firstNumber made, firstNumber copied) end
                val tier2 =
                  if not havePerf then "-"
                  else
                    let val _ = call (["perf", "stat", "-x", ",", "-e", "instructions:u", runevm, rbc] @ #args p, runIn (name ^ ".perf"),
                                      #stdin p,
                                      "/dev/null", f "perf", 1800)
                    in case List.find (fn l => String.isSubstring "instructions" l) (lines (read (f "perf"))) of
                         SOME l => (case String.fields (fn c => c = #",") l of n :: _ => n | [] => "-")
                       | NONE => "-"
                    end
              in
                [name, "yes", Int.toString rs, if output = #expected p then "yes" else "no",
                 case !o0out of SOME first => if output = first then "yes" else "no" | NONE => "-",
                 nth 0, nth 1, nth 2, thunks, tier2, copies]
              end
        in append (out, String.concatWith "\t" ([set, id] @ row) ^ "\n") end
      (* the eta-expansions under each rule (D48): compiled at -O2 with
         --simplify-stats, and nothing run; a line `stats` with the counts
         of eta (both), eta-refused (C's, what D would expand) and eta-ghc
         (D's), and the rewrites in all *)
      fun stats () =
        let
          fun counts flags tag =
            let
              val e = #dir p ^ "/stats." ^ tag ^ ".err"
              val _ = call ([rhc (), #main p, "-O2", "--simplify-stats", "--desugar-only"] @ flags, #dir p, "",
                            "/dev/null", e, 1800)
              fun get what = case lineAfter (e, "simplify " ^ what ^ ": ") of SOME n => n | NONE => "0"
              val all = List.foldl (fn (l, n) => if String.isPrefix "simplify " l
                                                 then n + getOpt (Int.fromString (firstNumber l), 0) else n)
                                   0 (lines (read e))
            in [get "eta", get "eta-refused", get "eta-ghc", Int.toString all] end
        in
          append (out, String.concatWith "\t" ([set, id, "stats"] @ counts [] "C" @ counts ["--eta=ghc"] "D") ^ "\n")
        end
      fun pick ws = List.filter (fn (n, _) => List.exists (fn m => m = n) chosen) ws
      val selected = if null chosen orelse List.exists (fn m => m = "all") chosen then ways
                     else if chosen = ["stats"] then [] else pick ways
    in List.app one selected; List.app interp (pick interpreted); if List.exists (fn m => m = "stats") chosen then stats () else () end

  (* ---- The sets ---- *)

  fun lang (name, out, chosen) =
    case List.find (fn (p : Lang.program) => #name p = name)
                   (Lang.programsOf ("tests/hs/lang", [".hs", ".lhs"], ["Main.hs", "Main.lhs"])) of
      NONE => say ("FAIL hs-simplify-figures: no program " ^ name ^ " in tests/hs/lang\n")
    | SOME (p : Lang.program) =>
        let
          val work = run ^ "/hs-simplify-figures/lang/" ^ name
          val () = (rmTree work; mkdirs work)
          val stdin = if exists (#base p ^ ".stdin") then fromRoot (#base p ^ ".stdin") else ""
          val expected = if exists (#base p ^ ".expected") then read (fromRoot (#base p ^ ".expected")) else ""
        in
          measure ("lang", name, {dir = work, main = fromRoot (#src p), runDir = work, fresh = true, args = [], stdin = stdin,
                                  expected = expected}, out, chosen);
          rmTree work
        end

  fun corpus (id, out, chosen) =
    HsCorpusRun.fromVendored (fn () =>
      let
        val row = case List.find (fn r => HsCorpus.field r "id" = id) (HsCorpus.rows "run.tsv") of
                    SOME r => r | NONE => raise HsOracles.Failed ("no run of " ^ id)
        val c = case List.find (fn (c : HsCorpus.candidate) => #id c = id) (HsCorpus.candidates ()) of
                  SOME c => c | NONE => raise HsOracles.Failed ("no candidate " ^ id)
        val work = run ^ "/hs-simplify-figures/corpus/" ^ id
        val () = rmTree work
        val variant = case HsCorpus.field row "variant" of "" => "h98" | v => v
        val {files, ...} = HsCorpus.closureOf c
        val (p, m) = HsCorpus.prepare (c, variant, files, work)
        fun beside f = if f = "" then "" else
                         let val q = p ^ "/" ^ OS.Path.file f
                         in (if exists q then () else HsCorpus.copyFile (HsCorpus.tree f, q)); q end
        val stdin = beside (HsCorpus.field row "stdin")
        val expected = HsSource.universal (read (HsCorpus.tree (HsCorpus.field row "expected")))
        val args = String.tokens Char.isSpace (HsCorpus.field row "args")
      in
        measure ("corpus", id, {dir = p, main = m, runDir = p, fresh = false, args = args, stdin = stdin, expected = expected},
                 out, chosen);
        rmTree work
      end)
    handle HsOracles.Failed msg => say ("FAIL hs-simplify-figures " ^ id ^ ": " ^ msg ^ "\n")
         | HsCorpus.Bad msg => say ("FAIL hs-simplify-figures " ^ id ^ ": " ^ msg ^ "\n")

  fun lazy (port, out, chosen) =
    case List.find (fn r => #port r = port) (HsLazyPorts.ready ()) of
      NONE => say ("FAIL hs-simplify-figures: no ready port " ^ port ^ "\n")
    | SOME r =>
        let
          val bench = "examples/benchmarks"
          val () = HsCorpus.rootOverride := SOME (fromRoot bench)
          val up = fromRoot bench ^ "/" ^ port ^ "/upstream"
          val c = {id = "lazy/" ^ port, set = "lazy-ports", path = port ^ "/upstream/" ^ #main r, parent = "-", expect = "run"}
                  : HsCorpus.candidate
          val work = run ^ "/hs-simplify-figures/lazy/" ^ port
          val () = rmTree work
          val {files, rewritable, ...} = HsCorpus.closureOf c
          val variants = ["h98"] @ (if null rewritable then [] else ["rewrite"]) @ ["harness"]
          (* the first variant rhc compiles at -O0, as hs-lazy-ports takes it *)
          fun pick [] = NONE
            | pick (v :: vs) =
                let val (p, m) = HsCorpus.prepare (c, v, files, work ^ "/" ^ v)
                in
                  if call ([rhc (), m, "-O0", "-o", "probe.rbc"], p, "", p ^ "/probe.out", p ^ "/probe.err", 1800) = 0
                  then SOME (p, m) else pick vs
                end
        in
          case pick variants of
            NONE => append (out, String.concatWith "\t" ["lazy", port, "-", "no"] ^ "\n")
          | SOME (p, m) =>
              let
                val rd = work ^ "/run"
                val () = HsCorpus.copyTree (up, rd)
                val stdin = if #stdin r = "" then "" else rd ^ "/" ^ #stdin r
              in
                measure ("lazy", port, {dir = p, main = m, runDir = rd, fresh = false, args = String.tokens Char.isSpace (#args r),
                                        stdin = stdin,
                                        expected = read (up ^ "/" ^ #expected r)}, out, chosen);
                rmTree work
              end
        end

  (* ---- The comparison, -O0 against -O2 ---- *)

  (* a program of a set at -O0 and -O2, its lines of figures judged: what
     -O2 prints is what -O0 printed, both end in a value or both in a
     bottom, and -O2 compiles where -O0 does *)
  fun compare (set, id) () =
    let
      val out = run ^ "/hs-simplify-figures/" ^ set ^ "-" ^ String.translate (fn #"/" => "-" | c => str c) id ^ ".tsv"
      val () = (mkdirs (OS.Path.dir out); if exists out then OS.FileSys.remove out else ())
      val () = case set of
                 "corpus" => corpus (id, out, ["O0", "O2"])
               | "lazy" => lazy (id, out, ["O0", "O2"])
               | _ => lang (id, out, ["O0", "O2"])
      val rows = List.map (String.fields (fn c => c = #"\t")) (lines (read out))
      fun way w = List.find (fn r => length r > 2 andalso List.nth (r, 2) = w) rows
      val what = "hs/simplify/" ^ set ^ "/" ^ id
      fun bottom s = s <> "0"
    in
      case (way "O0", way "O2") of
        (SOME (_ :: _ :: _ :: "yes" :: s0 :: _), SOME (_ :: _ :: _ :: "yes" :: s2 :: _ :: same :: _)) =>
          if same <> "yes" then say ("FAIL " ^ what ^ ": -O2 prints otherwise than -O0 (" ^ out ^ ")\n")
          else if bottom s0 <> bottom s2 then say ("FAIL " ^ what ^ ": -O0 ends with status " ^ s0 ^ ", -O2 with " ^ s2 ^ "\n")
          else ()
      | (SOME (_ :: _ :: _ :: "yes" :: _), _) => say ("FAIL " ^ what ^ ": rhc compiles it at -O0 and not at -O2 (" ^ out ^ ")\n")
      | _ => ()
    end

  fun tree () =
    let
      val corpusIds = HsCorpusRun.vendored () handle _ => []
      val ports = List.map #port (HsLazyPorts.ready ()) handle _ => []
      fun job (set, id) = HsOracles.job (id, ["hs-simplify-compare", set, id], [], 3600, 2000)
    in
      List.foldl (fn (c, t) => Test.tag c t)
        (Test.tag "nightly" (Test.tag "hs" (Test.describe "hs/simplify"
           [Test.describe "corpus" (List.map (fn id => job ("corpus", id)) corpusIds),
            Test.describe "lazy" (List.map (fn p => job ("lazy", p)) ports)])))
        ["covers:tests/runner/hssimplifyfigures.sml", "covers:lib/language/haskell/*", "covers:src/rhc/*"]
    end

  fun command args =
    case args of
      ["hs-simplify-compare", set, id] => SOME (compare (set, id))
    | "hs-simplify-figures" :: "lang" :: name :: out :: chosen => SOME (fn () => lang (name, out, chosen))
    | "hs-simplify-figures" :: "corpus" :: id :: out :: chosen => SOME (fn () => corpus (id, out, chosen))
    | "hs-simplify-figures" :: "lazy" :: port :: out :: chosen => SOME (fn () => lazy (port, out, chosen))
    | "hs-simplify-compile" :: set :: id :: out :: chosen =>
        SOME (fn () => (compileOnly := true;
                        case set of
                          "lang" => lang (id, out, chosen)
                        | "corpus" => corpus (id, out, chosen)
                        | "lazy" => lazy (id, out, chosen)
                        | _ => say ("FAIL hs-simplify-compile: no set " ^ set ^ "\n")))
    | _ => NONE
end

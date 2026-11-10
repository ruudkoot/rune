(* rhc's sharing budgets (D55; the haskell98 roadmap's M19 and its sharing
   budgets, rhc's policy): programs of tests/hs/perf that cost far more when
   what the Report leaves unsaid is not shared (a section's operand, a file
   read on demand, an array's components), each with NAME.budget, rhc's
   policy and not the Report's: lines `a: STDIN`, `b: STDIN` and `ratio: R`.
   The program, compiled by rhc, runs twice under bin/runevm --count, on the
   line a and on the line b as its standard input; the instructions of the
   first are at most R times those of the second. A ratio, not a count: it
   holds across machines and stays put as rhc's code improves, and it is what
   separates linear from quadratic. A program is held while the row its
   name gives is Planned (HsConformance). *)
structure HsPerf =
struct
  open Sh

  val dir = "tests/hs/perf"
  fun field (text, key) =
    case List.find (String.isPrefix (key ^ ":")) (lines text) of
      SOME l => SOME (String.extract (l, size key + 1, NONE))
    | NONE => NONE
  fun trim s = String.implode (List.filter (fn c => c <> #"\r") (String.explode s))
  fun instructions file =
    case List.find (String.isPrefix "runevm: count: ") (lines (read file)) of
      SOME l => (case String.tokens Char.isSpace (String.extract (l, size "runevm: count: ", NONE)) of
                   n :: _ => LargeInt.fromString n
                 | [] => NONE)
    | NONE => NONE

  fun one name () =
    let
      val src = fromRoot (dir ^ "/" ^ name ^ ".hs")
      val budget = read (fromRoot (dir ^ "/" ^ name ^ ".budget"))
      val work = run ^ "/hs-perf/" ^ name
      val () = (rmTree work; mkdirs work)
      fun f x = work ^ "/" ^ x
    in
      case (field (budget, "a"), field (budget, "b"), Option.mapPartial Real.fromString (field (budget, "ratio"))) of
        (SOME a, SOME b, SOME ratio) =>
          if exec {cmd = [fromRoot "bin/rhc", src, "-o", f "prog.rbc"], dir = SOME work, stdin = "", stdout = f "c.err",
                   stderr = f "c.err", timeout = 600} <> 0
          then say ("FAIL hs-perf " ^ name ^ ": rhc does not compile it: " ^ firstNonEmpty (f "c.err") ^ "\n")
          else
            let
              fun count (tag, input) =
                let
                  val () = write (f (tag ^ ".in"), String.concatWith " " (String.tokens Char.isSpace (trim input)) ^ "\n")
                  val c = exec {cmd = [fromRoot "bin/runevm", "--count", f "prog.rbc"], dir = SOME work, stdin = f (tag ^ ".in"),
                                stdout = f (tag ^ ".out"), stderr = f (tag ^ ".err"), timeout = 1200}
                in if c = 0 then instructions (f (tag ^ ".err")) else NONE end
            in
              case (count ("a", a), count ("b", b)) of
                (SOME na, SOME nb) =>
                  if Real.fromLargeInt na <= ratio * Real.fromLargeInt nb
                  then (say ("PASS hs-perf " ^ name ^ ": " ^ LargeInt.toString na ^ " against " ^ LargeInt.toString nb ^ "\n"); rmTree work)
                  else say ("FAIL hs-perf " ^ name ^ ": " ^ LargeInt.toString na ^ " instructions against " ^ LargeInt.toString nb
                            ^ ", above rhc's ratio " ^ Real.toString ratio ^ " (" ^ work ^ ")\n")
              | _ => say ("FAIL hs-perf " ^ name ^ ": a run failed or gave no count (" ^ work ^ ")\n")
            end
      | _ => say ("FAIL hs-perf " ^ name ^ ": its budget wants lines a:, b: and ratio:\n")
    end

  fun names () = List.map (fn p => OS.Path.base (OS.Path.file p)) (glob (dir, ".budget"))
  fun command args =
    case args of
      ["hs-perf", name] => SOME (one name)
    | _ => NONE

  fun tree () =
    Test.tag "covers:tests/runner/hsperf.sml"
      (Test.tag "covers:tests/hs/perf/*"
        (Test.tag "check" (Test.tag "hs" (Test.describe "hs/perf"
           (List.map (fn n =>
                        let val t = Test.requires ["rhc"] (Oracles.jobIn ("", n, ["hs-perf", n], [], 1, 800, 3600))
                        in case HsConformance.pendingUntil [n] of SOME why => Test.pending why t | NONE => t end)
                     (names ()))))))
end

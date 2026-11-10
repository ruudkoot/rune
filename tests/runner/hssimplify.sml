(* rhc's Core simplifier (tests/hs/simplify; the haskell98 roadmap's M23,
   D48, D49; docs/testing.md, rhc's Core simplifier): each program of
   tests/hs/simplify run on Core's interpreter at -O0 and at -O2, where
   the simplifier's passes run, at --lint=3 (every pass's Core checked by
   CoreLint and HsLint's target check, and read back), and compiled through
   Mid at --lint=2 and run on the VM at both levels, each printing
   NAME.expected and ending as NAME.exitcode says, 0 where there is none,
   a bottom anything else (hs/simplify/run/NAME); with NAME.stdin as its
   standard input.

   A program with a line `-- fuel:` is compiled at -O2 again with the
   rewrites stopped after each of several counts (--fuel=N), every lint
   holding and the program printing the same (hs/simplify/fuel/NAME); one
   with `-- budget: SIZE1 SIZE2` is a sharing budget: compiled at -O0 and
   -O2 and run on the VM with each size as its standard input, the
   instructions at the second at most 2.2 times those at the first, so
   that a thunk copied where it runs once for each element, or eta that
   moves its work under a lambda, shows as a square (hs/simplify/budget/NAME).

   Over the run programs of tests/hs/lang (nightly, held while their rows
   are Planned): what the VM prints at -O2 it printed at -O0, and both end
   in a value or both in a bottom (hs/simplify/lang/NAME). *)
structure HsSimplifyJobs =
struct
  open Sh

  (* the rhc the jobs run, RUNE_HS_RHC for a mutant's (bin/rune-test's
     hs-mutants, or by hand) *)
  fun rhcPath () = env ("RUNE_HS_RHC", fromRoot "bin/rhc")
  val dir = "tests/hs/simplify"

  fun fail s = say ("FAIL " ^ s ^ "\n")

  fun stdinOf (p : Lang.program) = if exists (#base p ^ ".stdin") then fromRoot (#base p ^ ".stdin") else ""
  fun statusOf (p : Lang.program) =
    if exists (#base p ^ ".exitcode") then getOpt (Int.fromString (firstNonEmpty (fromRoot (#base p ^ ".exitcode"))), 0) else 0

  fun workFor (kind, name) =
    let val w = run ^ "/hs-simplify/" ^ kind ^ "/" ^ name
    in rmTree w; mkdirs w; w end

  (* the lines of the source that start with `-- KEY:`, what follows *)
  fun marked (src, key) =
    List.mapPartial (fn l => if String.isPrefix ("-- " ^ key ^ ":") l then SOME (String.extract (l, size key + 4, NONE)) else NONE)
                    (String.fields (fn c => c = #"\n") (read src))

  (* p run on Core's interpreter with flags: stdout and status *)
  fun interpret (p : Lang.program, flags, w, tag, stdin) =
    let
      fun f x = w ^ "/" ^ x
      val c = exec {cmd = [rhcPath (), "--lint=3"] @ flags @ [fromRoot (#src p)], dir = SOME w, stdin = stdin,
                    stdout = f (tag ^ ".out"), stderr = f (tag ^ ".err"), timeout = 600}
    in (read (f (tag ^ ".out")), c) end

  (* p compiled with flags and run on the VM, with vmFlags: stdout and
     status, or NONE where rhc does not compile it *)
  fun onVm (p : Lang.program, flags, vmFlags, w, tag, stdin) =
    let
      fun f x = w ^ "/" ^ x
      val cc = exec {cmd = [rhcPath (), "--lint=2"] @ flags @ [fromRoot (#src p), "-o", f (tag ^ ".rbc")], dir = SOME w,
                     stdin = "", stdout = f (tag ^ ".c.err"), stderr = f (tag ^ ".c.err"), timeout = 600}
    in
      if cc <> 0 then NONE
      else
        let val c = exec {cmd = [fromRoot "bin/runevm"] @ vmFlags @ [f (tag ^ ".rbc")], dir = SOME w, stdin = stdin,
                          stdout = f (tag ^ ".out"), stderr = f (tag ^ ".err"), timeout = 600}
        in SOME (read (f (tag ^ ".out")), c) end
    end

  (* what a run printed and how it ended, held to the program's own; true
     where it holds *)
  fun judge (what, p : Lang.program, w, (out, c)) =
    let
      val want = statusOf p
      val expected = read (fromRoot (#base p ^ ".expected"))
    in
      if out <> expected then (fail (what ^ ": it printed otherwise than " ^ #base p ^ ".expected (" ^ w ^ ")"); false)
      else if (c = 0) <> (want = 0) then
        (fail (what ^ ": the status is " ^ Int.toString c ^ ", where " ^ Int.toString want ^ " is wanted (" ^ w ^ ")"); false)
      else true
    end

  fun runOne (p : Lang.program) () =
    let
      val w = workFor ("run", #name p)
      val what = "hs/simplify/run/" ^ #name p
      val stdin = stdinOf p
      fun vm level =
        case onVm (p, ["-" ^ level], [], w, "vm." ^ level, stdin) of
          SOME r => judge (what ^ " (VM, -" ^ level ^ ")", p, w, r)
        | NONE => (fail (what ^ ": rhc does not compile it at -" ^ level ^ ": " ^ firstNonEmpty (w ^ "/vm." ^ level ^ ".c.err")); false)
      val oks = [judge (what ^ " (interpreter, -O0)", p, w, interpret (p, ["-O0"], w, "interp.O0", stdin)),
                 judge (what ^ " (interpreter, -O2)", p, w, interpret (p, ["-O2"], w, "interp.O2", stdin)),
                 vm "O0", vm "O2"]
    in if List.all (fn b => b) oks then rmTree w else () end

  (* the counts of rewrites a program is stopped after *)
  val fuels = [0, 1, 3, 10, 40, 150, 600, 2500]

  fun fuelOne (p : Lang.program) () =
    let
      val w = workFor ("fuel", #name p)
      val what = "hs/simplify/fuel/" ^ #name p
      fun one n =
        case onVm (p, ["-O2", "--fuel=" ^ Int.toString n], [], w, "fuel" ^ Int.toString n, stdinOf p) of
          SOME r => judge (what ^ " (--fuel=" ^ Int.toString n ^ ")", p, w, r)
        | NONE => (fail (what ^ ": rhc does not compile it at --fuel=" ^ Int.toString n ^ ": "
                         ^ firstNonEmpty (w ^ "/fuel" ^ Int.toString n ^ ".c.err")); false)
    in if List.all one fuels then rmTree w else () end

  (* the instructions a run gives with stdin, from runevm --count *)
  fun countOf (rbc, w, tag, stdin) =
    let
      val _ = exec {cmd = [fromRoot "bin/runevm", "--count", rbc], dir = SOME w, stdin = stdin, stdout = w ^ "/" ^ tag ^ ".out",
                    stderr = w ^ "/" ^ tag ^ ".err", timeout = 600}
      val lines = String.fields (fn c => c = #"\n") (read (w ^ "/" ^ tag ^ ".err"))
    in
      case List.find (String.isPrefix "runevm: count: ") lines of
        SOME l => Int.fromString (String.extract (l, size "runevm: count: ", NONE))
      | NONE => NONE
    end

  (* a file holding the size, a program's standard input *)
  fun sizeFile (w, tag, n) = let val f = w ^ "/size." ^ tag in write (f, n ^ "\n"); f end

  fun budgetOne (p : Lang.program) () =
    let
      val w = workFor ("budget", #name p)
      val what = "hs/simplify/budget/" ^ #name p
    in
      case marked (fromRoot (#src p), "budget") of
        [line] =>
          (case String.tokens Char.isSpace line of
             [a, b] =>
               let
                 fun level l =
                   let
                     val rbc = w ^ "/" ^ l ^ ".rbc"
                     val cc = exec {cmd = [rhcPath (), "--lint=2", "-" ^ l, fromRoot (#src p), "-o", rbc], dir = SOME w, stdin = "",
                                    stdout = w ^ "/" ^ l ^ ".c.err", stderr = w ^ "/" ^ l ^ ".c.err", timeout = 600}
                   in
                     if cc <> 0 then (fail (what ^ ": rhc does not compile it at -" ^ l ^ ": " ^ firstNonEmpty (w ^ "/" ^ l ^ ".c.err")); false)
                     else
                       case (countOf (rbc, w, l ^ ".a", sizeFile (w, "a", a)), countOf (rbc, w, l ^ ".b", sizeFile (w, "b", b))) of
                         (SOME x, SOME y) =>
                           if 10 * y <= 22 * x then true
                           else (fail (what ^ ": at -" ^ l ^ " " ^ Int.toString y ^ " instructions at the second size, more than 2.2 times the "
                                       ^ Int.toString x ^ " at the first: a lost share"); false)
                       | _ => (fail (what ^ ": at -" ^ l ^ " no count (" ^ w ^ ")"); false)
                   end
               in if List.all level ["O0", "O2"] then rmTree w else () end
           | _ => fail (what ^ ": its line -- budget: wants two sizes"))
      | _ => fail (what ^ ": no line -- budget: SIZE1 SIZE2")
    end

  (* a run program of tests/hs/lang at -O0 and -O2 on the VM: the same
     output, and both a value or both a bottom *)
  fun langOne (p : Lang.program) () =
    let
      val w = workFor ("lang", #name p)
      val what = "hs/simplify/lang/" ^ #name p
      fun ends c = if c = 0 then "a value" else "a bottom"
    in
      case (onVm (p, ["-O0"], [], w, "O0", stdinOf p), onVm (p, ["-O2"], [], w, "O2", stdinOf p)) of
        (SOME (a, ca), SOME (b, cb)) =>
          if a <> b then fail (what ^ ": -O2 prints otherwise than -O0 (" ^ w ^ "/O0.out, O2.out)")
          else if (ca = 0) <> (cb = 0) then fail (what ^ ": -O0 ends in " ^ ends ca ^ ", -O2 in " ^ ends cb)
          else rmTree w
      | (NONE, _) => fail (what ^ ": rhc does not compile it at -O0: " ^ firstNonEmpty (w ^ "/O0.c.err"))
      | (_, NONE) => fail (what ^ ": rhc does not compile it at -O2: " ^ firstNonEmpty (w ^ "/O2.c.err"))
    end

  fun programs () = Lang.programsOf (dir, [".hs"], ["Main.hs"])
  fun langPrograms () = Lang.programsOf ("tests/hs/lang", [".hs", ".lhs"], ["Main.hs", "Main.lhs"])

  fun find (ps, name) = List.find (fn (p : Lang.program) => #name p = name) ps

  fun command args =
    case args of
      ["hs-simplify", kind, name] =>
        SOME (fn () =>
          case (kind, find (if kind = "lang" then langPrograms () else programs (), name)) of
            ("run", SOME p) => runOne p ()
          | ("fuel", SOME p) => fuelOne p ()
          | ("budget", SOME p) => budgetOne p ()
          | ("lang", SOME p) => langOne p ()
          | _ => fail ("hs-simplify: no program " ^ name ^ " for " ^ kind))
    | _ => NONE

  val covers = ["covers:tests/runner/hssimplify.sml", "covers:tests/hs/simplify/*", "covers:lib/language/haskell/*",
                "covers:src/rhc/*"]

  fun job (kind, name) = Test.requires ["rhc"] (Oracles.job (name, ["hs-simplify", kind, name], [], 1, 600, 1800))

  fun tree () =
    let
      val own = programs ()
      fun marking key = List.filter (fn (p : Lang.program) => not (null (marked (fromRoot (#src p), key)))) own
      fun family (kind, ps) = Test.tag "check" (Test.describe kind (List.map (fn (p : Lang.program) => job (kind, #name p)) ps))
      val lang =
        Test.tag "nightly"
          (Test.describe "lang"
             (List.map (fn (p : Lang.program) =>
                          let val t = job ("lang", #name p)
                          in case HsConformance.pending p of SOME why => Test.pending why t | NONE => t end)
                       (langPrograms ())))
    in
      List.foldl (fn (c, t) => Test.tag c t)
        (Test.tag "hs" (Test.describe "hs/simplify"
           [family ("run", own), family ("fuel", marking "fuel"), family ("budget", marking "budget"), lang]))
        covers
    end
end

(* rhc's desugaring to Core (tests/hs/desugar; the haskell98 roadmap's M15,
   D34; docs/testing.md, rhc's desugaring): each program of tests/hs/desugar
   through rhc, checked, desugared and read back at --lint=3, and run on
   Core's interpreter with its matches in the Report's order
   (hs/desugar/report/NAME) and as decision trees in Sestoft's order
   (hs/desugar/sestoft/NAME, `--match=sestoft`), each printing NAME.expected
   and ending with NAME.exitcode, 0 where there is none; compiled through
   Mid and run on the VM, the same (hs/desugar/vm/NAME); and printed with
   explicit braces (`rhc --print`), which desugars to the same Core text
   (hs/desugar/braces/NAME). A pair tests/hs/desugar/relations/NAME.hs and
   NAME.parens.hs, the same program with every operator's application in
   parentheses, desugars to the same Core text (hs/desugar/parens/NAME).

   Over the run programs of tests/hs/lang, the two orders agree: what one
   prints the other prints, and both end in a value or both in a bottom
   (hs/desugar/orders/NAME), held while every row a program tests is
   Planned (HsConformance). *)
structure HsDesugarJobs =
struct
  open Sh

  val rhc = "bin/rhc"
  val dir = "tests/hs/desugar"

  fun fail s = say ("FAIL " ^ s ^ "\n")

  fun stdinOf (p : Lang.program) = if exists (#base p ^ ".stdin") then fromRoot (#base p ^ ".stdin") else ""
  fun statusOf (p : Lang.program) =
    if exists (#base p ^ ".exitcode") then getOpt (Int.fromString (firstNonEmpty (fromRoot (#base p ^ ".exitcode"))), 0) else 0

  fun workFor (kind, name) =
    let val w = run ^ "/hs-desugar/" ^ kind ^ "/" ^ name
    in rmTree w; mkdirs w; w end

  (* p run on Core's interpreter with `flags`: stdout and status *)
  fun interpret (p : Lang.program, flags, w, tag) =
    let
      fun f x = w ^ "/" ^ x
      val c = exec {cmd = [fromRoot rhc, "--lint=3"] @ flags @ [fromRoot (#src p)], dir = SOME w, stdin = stdinOf p,
                    stdout = f (tag ^ ".out"), stderr = f (tag ^ ".err"), timeout = 600}
    in
      (read (f (tag ^ ".out")), c)
    end

  (* what a run printed and how it ended, held to the program's own *)
  fun judge (kind, p : Lang.program, w, (out, c)) =
    let
      val want = statusOf p
      val expected = read (fromRoot (#base p ^ ".expected"))
    in
      if out <> expected then fail ("hs/desugar/" ^ kind ^ "/" ^ #name p ^ ": it printed otherwise than " ^ #base p
                                    ^ ".expected (" ^ w ^ ")")
      else if (c = 0) <> (want = 0) then
        fail ("hs/desugar/" ^ kind ^ "/" ^ #name p ^ ": the status is " ^ Int.toString c ^ ", where " ^ Int.toString want
              ^ " is wanted (" ^ w ^ ")")
      else rmTree w
    end

  fun ordered (order, p : Lang.program) () =
    let val w = workFor (order, #name p)
    in judge (order, p, w, interpret (p, ["--match=" ^ order], w, "run")) end

  fun vm (p : Lang.program) () =
    let
      val w = workFor ("vm", #name p)
      fun f x = w ^ "/" ^ x
      val cc = exec {cmd = [fromRoot rhc, "--lint=2", fromRoot (#src p), "-o", f "prog.rbc"], dir = SOME w, stdin = "",
                     stdout = f "c.err", stderr = f "c.err", timeout = 600}
    in
      if cc <> 0 then fail ("hs/desugar/vm/" ^ #name p ^ ": rhc does not compile it: " ^ firstNonEmpty (f "c.err"))
      else
        let
          val c = exec {cmd = [fromRoot "bin/runevm", f "prog.rbc"], dir = SOME w, stdin = stdinOf p, stdout = f "vm.out",
                        stderr = f "vm.err", timeout = 600}
        in
          judge ("vm", p, w, (read (f "vm.out"), c))
        end
    end

  (* the Core text a file of Haskell desugars to *)
  fun core (src, w, tag) =
    let
      fun f x = w ^ "/" ^ x
      val c = exec {cmd = [fromRoot rhc, "--desugar-only", "--dump-after=desugar", src], dir = SOME w, stdin = "",
                    stdout = f (tag ^ ".core"), stderr = f (tag ^ ".err"), timeout = 600}
    in
      if c <> 0 then NONE else SOME (read (f (tag ^ ".core")))
    end

  fun sameCore (kind, name, a, b, w) =
    case (core (a, w, "a"), core (b, w, "b")) of
      (SOME x, SOME y) =>
        if x = "" then fail ("hs/desugar/" ^ kind ^ "/" ^ name ^ ": no Core was printed (" ^ w ^ ")")
        else if x <> y then fail ("hs/desugar/" ^ kind ^ "/" ^ name ^ ": the two desugar to other Core text (" ^ w
                                  ^ "/a.core, b.core)")
        else rmTree w
    | _ => fail ("hs/desugar/" ^ kind ^ "/" ^ name ^ ": rhc does not desugar both (" ^ w ^ "/a.err, b.err)")

  fun braces (p : Lang.program) () =
    let
      val w = workFor ("braces", #name p)
      val printed = w ^ "/braces.hs"
      val c = exec {cmd = [fromRoot rhc, "--print", fromRoot (#src p)], dir = SOME w, stdin = "", stdout = printed,
                    stderr = w ^ "/print.err", timeout = 600}
    in
      if c <> 0 then fail ("hs/desugar/braces/" ^ #name p ^ ": rhc --print fails (" ^ w ^ "/print.err)")
      else sameCore ("braces", #name p, fromRoot (#src p), printed, w)
    end

  fun parens name () =
    let val w = workFor ("parens", name)
    in sameCore ("parens", name, fromRoot (dir ^ "/relations/" ^ name ^ ".hs"), fromRoot (dir ^ "/relations/" ^ name ^ ".parens.hs"), w) end

  (* both orders on a program of tests/hs/lang: the same output, and both a
     value or both a bottom *)
  fun orders (p : Lang.program) () =
    let
      val w = workFor ("orders", #name p)
      val (a, ca) = interpret (p, ["--match=report"], w, "report")
      val (b, cb) = interpret (p, ["--match=sestoft"], w, "sestoft")
      fun ends c = if c = 0 then "a value" else "a bottom"
    in
      if a <> b then fail ("hs/desugar/orders/" ^ #name p ^ ": the two orders print otherwise (" ^ w ^ "/report.out, sestoft.out)")
      else if (ca = 0) <> (cb = 0) then
        fail ("hs/desugar/orders/" ^ #name p ^ ": the Report's order ends in " ^ ends ca ^ ", Sestoft's in " ^ ends cb)
      else rmTree w
    end

  fun programs () = Lang.programsOf (dir, [".hs"], ["Main.hs"])
  fun langPrograms () = Lang.programsOf ("tests/hs/lang", [".hs", ".lhs"], ["Main.hs", "Main.lhs"])

  (* the relations' pairs, by name, in order *)
  fun pairs () =
    List.map (fn f => let val b = OS.Path.file f in String.substring (b, 0, size b - size ".parens.hs") end)
      (glob (fromRoot (dir ^ "/relations"), ".parens.hs"))

  fun find (ps, name) = List.find (fn (p : Lang.program) => #name p = name) ps

  fun command args =
    case args of
      ["hs-desugar", kind, name] =>
        SOME (fn () =>
          case (kind, find (programs (), name)) of
            ("report", SOME p) => ordered ("report", p) ()
          | ("sestoft", SOME p) => ordered ("sestoft", p) ()
          | ("vm", SOME p) => vm p ()
          | ("braces", SOME p) => braces p ()
          | ("parens", _) => parens name ()
          | ("orders", _) =>
              (case find (langPrograms (), name) of
                 SOME p => orders p ()
               | NONE => fail ("hs-desugar: no program " ^ name ^ " in tests/hs/lang"))
          | _ => fail ("hs-desugar: no program " ^ name ^ " in " ^ dir ^ " for " ^ kind))
    | _ => NONE

  val covers = ["covers:tests/runner/hsdesugar.sml", "covers:tests/hs/desugar/*", "covers:lib/language/haskell/*",
                "covers:src/rhc/*"]

  fun job (kind, name) = Test.requires ["rhc"] (Oracles.job (name, ["hs-desugar", kind, name], [], 1, 600, 1800))

  fun tree () =
    let
      fun family (kind, ps) = Test.describe kind (List.map (fn (p : Lang.program) => job (kind, #name p)) ps)
      val own = programs ()
      (* the orders of a program of tests/hs/lang-nightly.txt are nightly,
         as its own jobs are (HsLang.tiers; the roadmap's D56): two runs on
         Core's interpreter are a way of make check too *)
      fun tier (p : Lang.program) = if List.exists (fn n => n = #name p) HsLang.listedNightly then "nightly" else "check"
    in
      List.foldl (fn (c, t) => Test.tag c t)
        (Test.tag "hs" (Test.describe "hs/desugar"
           [Test.tag "check" (Test.describe ""
              [family ("report", own), family ("sestoft", own), family ("vm", own), family ("braces", own),
               Test.describe "parens" (List.map (fn n => job ("parens", n)) (pairs ()))]),
            Test.describe "orders"
              (List.map (fn (p : Lang.program) =>
                           let val t = Test.tag (tier p) (job ("orders", #name p))
                           in case HsConformance.pending p of SOME why => Test.pending why t | NONE => t end)
                 (langPrograms ()))]))
        covers
    end
end

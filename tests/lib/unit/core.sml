(* libraries: test/unit *)
(* The unit-testing library's own tests (docs/plans/unit-testing.md, M1 and
   Testing the tester): run under a harness of their own, a dozen lines that
   do not use the library, as HSpec's hspec-meta tests HSpec. The tree and
   its metadata, the filters, the checks, golden files, and the program's
   options, list, events and summary. *)
structure UnitCore =
struct
  (* the harness: a check, the failures counted, the verdict printed *)
  val failures = ref 0
  fun check (name, ok) = if ok then () else (failures := !failures + 1; print ("FAIL " ^ name ^ "\n"))
  fun finish () = print ((if !failures = 0 then "PASS" else "FAIL") ^ " unit: " ^ Int.toString (!failures) ^ " failed\n")

  (* what a run printed, and what it counted *)
  fun capture args tests =
    let
      val out = ref []
      val summary = Suite.run {args = args, print = fn s => out := s :: !out} tests
    in (String.concat (rev (!out)), summary) end
  fun lines s = String.tokens (fn c => c = #"\n") s

  open Test

  val tree =
    describe "lib"
      [tag "slow" (describe "basis" [it "word64" 1, it "int" 2]),
       timeout (Time.fromSeconds 5) (it "json" 3),
       requires ["tmux"] (resources {cpus = 2, memory = 300} (describe "terminal" [requires ["python3"] (it "screen" 4)])),
       pending "not yet" (it "later" 5)]

  fun trees () =
    let
      val ls = leaves tree
      val paths = List.map #path ls
      fun metaOf p = #meta (valOf (List.find (fn l => #path l = p) ls))
    in
      check ("paths in order", paths = ["lib/basis/word64", "lib/basis/int", "lib/json", "lib/terminal/screen", "lib/later"]);
      check ("leaves in order", List.map #leaf ls = [1, 2, 3, 4, 5]);
      check ("tags inherited", #tags (metaOf "lib/basis/int") = ["slow"] andalso #tags (metaOf "lib/json") = []);
      check ("timeout", #timeout (metaOf "lib/json") = SOME (Time.fromSeconds 5)
                        andalso #timeout (metaOf "lib/basis/int") = NONE);
      check ("requirements add up", #requires (metaOf "lib/terminal/screen") = ["tmux", "python3"]);
      check ("resources", #cpus (metaOf "lib/terminal/screen") = SOME 2 andalso #memory (metaOf "lib/terminal/screen") = SOME 300);
      check ("pending", #pending (metaOf "lib/later") = SOME "not yet" andalso #pending (metaOf "lib/json") = NONE);
      check ("map", List.map #leaf (leaves (map (fn x => x * 10) tree)) = [10, 20, 30, 40, 50]);
      check ("an empty name joins nothing", List.map #path (leaves (describe "" [it "a" (), describe "" [it "b" ()]])) = ["a", "b"]);
      let
        val w = leaves (describe "lang" [ways [("stack", "s"), ("register", "r")] (describe "" [it "x" (fn v => "x" ^ v), it "y" (fn v => "y" ^ v)])])
      in
        check ("ways: names", List.map #path w = ["lang/x[stack]", "lang/x[register]", "lang/y[stack]", "lang/y[register]"]);
        check ("ways: leaves", List.map #leaf w = ["xs", "xr", "ys", "yr"]);
        check ("ways: tags", List.map (fn l => #tags (#meta l)) w = [["way:stack"], ["way:register"], ["way:stack"], ["way:register"]])
      end;
      check ("ways of a single test", List.map #path (leaves (ways [("a", 1), ("b", 2)] (it "t" (fn n => n)))) = ["t[a]", "t[b]"])
    end

  fun filters () =
    let
      fun m (f, path, tags) = TestFilter.matches (TestFilter.parse f) {path = path, tags = tags}
      fun bad f = (ignore (TestFilter.parse f); false) handle TestFilter.Parse _ => true
    in
      check ("empty: all", m ("", "anything", []) andalso m ("   ", "x", []));
      check ("a word is a substring", m ("word", "lib/basis/word64", []) andalso not (m ("words", "lib/basis/word64", [])));
      check ("a glob is the whole path", m ("lib/*", "lib/json", []) andalso not (m ("lib/*", "x/lib/json", []))
                                         andalso m ("lib/?son", "lib/json", []));
      check ("tags and ways", m ("tag:slow", "a", ["slow"]) andalso not (m ("tag:slow", "a", []))
                              andalso m ("way:stack", "a[stack]", ["way:stack"]));
      check ("not, and, or", m ("!json", "lib/basis", []) andalso not (m ("!json", "lib/json", []))
                             andalso m ("json & !tag:slow", "lib/json", []) andalso not (m ("json & tag:slow", "lib/json", []))
                             andalso m ("json | basis", "lib/basis", []));
      check ("precedence", m ("a | b & c", "a", []) andalso not (m ("(a | b) & c", "a", [])));
      check ("errors", bad "a &" andalso bad "(a" andalso bad "a )" andalso bad "| a" andalso bad "!")
    end

  fun expects () =
    let
      fun outcome f = #outcome (Expect.run f)
    in
      check ("pass", Expect.run (fn () => Expect.that ("t", true)) = {outcome = Expect.Pass, checks = 1});
      check ("soft checks go on", outcome (fn () => (Expect.that ("a", false); Expect.that ("b", true); Expect.that ("c", false)))
                                  = Expect.Fail ["a", "c"]);
      (* the names of the exceptions; their messages are each compiler's own *)
      check ("check: a raise fails the check alone",
             case Expect.run (fn () => (Expect.check ("h", fn () => hd [] = 1); Expect.that ("after", true))) of
               {outcome = Expect.Fail [m], checks = 2} => String.isPrefix "h: raised Empty" m
             | _ => false);
      check ("eq", outcome (fn () => Expect.eq Int.toString ("sum", 4, fn () => 2 + 3)) = Expect.Fail ["sum: expected 4, got 5"]);
      check ("eq raising", case outcome (fn () => Expect.eq Int.toString ("d", 1, fn () => 1 div 0)) of
                             Expect.Fail [m] => String.isPrefix "d: expected 1, raised Div" m
                           | _ => false);
      check ("equal", outcome (fn () => Expect.equal (Real.==, Real.toString) ("r", 0.5, fn () => 1.0 / 2.0)) = Expect.Pass);
      check ("raises", outcome (fn () => Expect.raises ("e", fn Empty => true | _ => false, fn () => hd [])) = Expect.Pass
                       andalso outcome (fn () => Expect.raises ("e", fn Empty => true | _ => false, fn () => 1)) <> Expect.Pass);
      check ("fail ends the test", Expect.run (fn () => (Expect.that ("a", false); Expect.fail "stop"; Expect.that ("never", true)))
                                   = {outcome = Expect.Fail ["a", "stop"], checks = 1});
      check ("a raise of its own", case outcome (fn () => raise Subscript) of
                                     Expect.Error m => String.isPrefix "Subscript" m
                                   | _ => false);
      check ("Fail's message", outcome (fn () => raise Fail "boom") = Expect.Error "Fail: boom");
      check ("runs are apart", (ignore (Expect.run (fn () => Expect.that ("x", false)));
                                Expect.run (fn () => ()) = {outcome = Expect.Pass, checks = 0}))
    end

  fun goldens () =
    let
      val file = OS.FileSys.tmpName ()
      fun write s = let val f = TextIO.openOut file in TextIO.output (f, s); TextIO.closeOut f end
      fun read () = let val f = TextIO.openIn file in TextIO.inputAll f before TextIO.closeIn f end
      fun outcome actual = #outcome (Expect.run (fn () => Golden.check ("g", {expected = file, actual = actual})))
    in
      check ("difference", Golden.difference ("a\nb\n", "a\nb\n") = NONE
                           andalso Golden.difference ("a\nb\n", "a\nc\n") = SOME (2, "b", "c")
                           andalso Golden.difference ("a\n", "a\nb\n") = SOME (2, "", "b"));
      write "one\ntwo\n";
      check ("golden: same", outcome "one\ntwo\n" = Expect.Pass);
      check ("golden: differs", case outcome "one\nthree\n" of Expect.Fail [m] => String.isSubstring "line 2" m | _ => false);
      Golden.accept := true;
      check ("golden: accepted", outcome "one\nthree\n" = Expect.Pass andalso read () = "one\nthree\n");
      Golden.accept := false;
      OS.FileSys.remove file;
      check ("golden: missing", case outcome "x" of Expect.Fail [m] => String.isSubstring "no file" m | _ => false)
    end

  val suite =
    describe "s"
      [it "pass" (fn () => Expect.that ("ok", true)),
       it "fail" (fn () => (Expect.that ("first", false); Expect.that ("second", false))),
       it "raise" (fn () => raise Fail "boom"),
       pending "later" (it "skip" (fn () => raise Fail "never run")),
       tag "slow" (it "slow" (fn () => ()))]

  fun suites () =
    let
      val (out, s) = capture [] suite
      val ls = lines out
    in
      check ("summary counts", s = {tests = 5, passed = 2, failed = 2, skipped = 1});
      check ("verdict lines", List.filter (fn l => String.isPrefix "PASS" l orelse String.isPrefix "FAIL" l orelse String.isPrefix "SKIP" l) ls
                              = ["PASS s/pass", "FAIL s/fail", "FAIL s/raise", "SKIP s/skip: later", "PASS s/slow"]);
      check ("failed checks listed", List.exists (fn l => l = "  - first") ls andalso List.exists (fn l => l = "  - second") ls);
      check ("a raise named", List.exists (fn l => String.isSubstring "raised Fail" l andalso String.isSubstring "boom" l) ls);
      check ("summary line", List.last ls = "SUMMARY 5 tests, 2 passed, 2 failed, 1 skipped");
      check ("--list runs nothing", capture ["--list"] (describe "x" [it "a" (fn () => raise Fail "ran")])
                                    = ("x/a\n", {tests = 0, passed = 0, failed = 0, skipped = 0}));
      check ("--filter", #2 (capture ["--filter", "!tag:slow & !raise"] suite) = {tests = 3, passed = 1, failed = 1, skipped = 1});
      check ("--run", #2 (capture ["--run", "s/pass", "--run", "s/slow"] suite) = {tests = 2, passed = 2, failed = 0, skipped = 0});
      check ("--after", #2 (capture ["--after", "s/raise"] suite) = {tests = 2, passed = 1, failed = 0, skipped = 1});
      check ("--quiet", not (String.isSubstring "PASS" (#1 (capture ["--quiet"] suite)))
                        andalso String.isSubstring "FAIL s/fail" (#1 (capture ["--quiet"] suite)));
      check ("--list-meta", case lines (#1 (capture ["--list-meta", "--run", "s/skip"] suite)) of
                              [l] => String.isPrefix "{\"path\":\"s/skip\"" l andalso String.isSubstring "\"pending\":\"later\"" l
                            | _ => false);
      check ("words ignored", #2 (capture ["lib/random/random.sml", "--run", "s/pass"] suite)
                              = {tests = 1, passed = 1, failed = 0, skipped = 0});
      check ("unknown option", case capture ["--nonsense"] suite of
                                 (o', {failed = 1, tests = 0, ...}) => String.isPrefix "FAIL usage" o' | _ => false);
      check ("bad filter", #failed (#2 (capture ["--filter", "a &"] suite)) = 1);
      check ("duplicate paths", case capture [] (describe "d" [it "a" (fn () => ()), it "a" (fn () => ())]) of
                                  (o', {failed = 1, passed = 2, ...}) => String.isSubstring "two tests have this path" o'
                                | _ => false);
      let
        val file = OS.FileSys.tmpName ()
        val _ = capture ["--events", file, "--run", "s/pass", "--run", "s/fail"] suite
        val f = TextIO.openIn file
        val ev = lines (TextIO.inputAll f) before TextIO.closeIn f
        val () = OS.FileSys.remove file
      in
        check ("events: start, checks, end", List.length ev = 6
                                              andalso String.isPrefix "{\"event\":\"start\",\"path\":\"s/pass\"" (hd ev)
                                              andalso String.isSubstring "\"verdict\":\"PASS\"" (List.nth (ev, 1))
                                              andalso String.isSubstring "\"message\":\"first\"" (List.nth (ev, 3))
                                              andalso String.isSubstring "\"verdict\":\"FAIL\"" (List.nth (ev, 5)))
      end
    end

  fun properties () =
    let
      val good = property "rev twice" (fn () => Prop.forAll (Arb.list Arb.int) (fn l => Prop.holds (rev (rev l) = l)))
      val bad = property "rev is identity" (fn () => Prop.forAll (Arb.list Arb.int) (fn l => Prop.holds (rev l = l)))
      val (_, s) = capture ["--quiet"] (describe "p" [good, bad])
      val (out, _) = capture ["--run", "p/rev is identity"] (describe "p" [good, bad])
    in
      check ("property: verdicts", s = {tests = 2, passed = 1, failed = 1, skipped = 0});
      check ("property: the report and its replay token", String.isSubstring "replay" out)
    end

  fun main () = (trees (); filters (); expects (); goldens (); suites (); properties (); finish ())
end

val () = UnitCore.main ()

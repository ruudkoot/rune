(* libraries: test/runner *)
(* What lib/test/runner's scheduler promises (docs/plans/unit-testing.md,
   D12 and Testing the tester), on random runs of up to a dozen jobs with
   edges, pools, exclusive jobs and jobs too big for the machine: that a
   job starts after the jobs it waits for, that what runs fits the machine,
   that two jobs of one pool never overlap, that an exclusive job runs
   alone, that the makespan lies between the lower bounds and list
   scheduling's upper bound, and that a job that failed last time starts
   first. Then the history, read back as it was written. *)
structure RunnerProps =
struct
  type job = Scheduler.job

  val pools = Vector.fromList [[], [], [], ["a"], ["b"], ["a", "b"]]

  (* a job that may wait for jobs before it, so that the jobs have no cycle *)
  fun jobGen i =
    Gen.bind (Gen.intRange (1, 20)) (fn cost =>
    Gen.bind (Gen.intRange (1, 6)) (fn cpus =>
    Gen.bind (Gen.intRange (0, 60)) (fn memory =>
    Gen.bind (Gen.elements pools) (fn pools =>
    Gen.bind (Gen.frequency [(9, Gen.return false), (1, Gen.return true)]) (fn exclusive =>
    Gen.bind (Gen.frequency [(5, Gen.return false), (1, Gen.return true)]) (fn failedLast =>
    Gen.map (fn deps => {cost = real cost, cpus = cpus, memory = memory, pools = pools, exclusive = exclusive,
                         failedLast = failedLast, deps = deps})
            (if i = 0 then Gen.return []
             else Gen.map (List.filter (fn d => d < i)) (Gen.listOf (Gen.intRange (0, 2)) (Gen.intRange (0, i - 1))))))))))

  val jobsGen =
    Gen.bind (Gen.intRange (1, 12)) (fn n =>
      let fun go i = if i = n then Gen.return [] else Gen.map2 (op ::) (jobGen i, go (i + 1))
      in Gen.map Vector.fromList (go 0) end)

  val machineGen = Gen.pair (Gen.intRange (1, 8), Gen.intRange (40, 200))

  fun showJob ({cost, cpus, memory, pools, exclusive, failedLast, deps} : job) =
    "{cost " ^ Real.toString cost ^ ", cpus " ^ Int.toString cpus ^ ", memory " ^ Int.toString memory
    ^ ", pools [" ^ String.concatWith "," pools ^ "]" ^ (if exclusive then ", exclusive" else "")
    ^ (if failedLast then ", failed" else "") ^ ", deps [" ^ String.concatWith "," (List.map Int.toString deps) ^ "]}"
  fun showRun (jobs, (cpus, memory)) =
    "machine " ^ Int.toString cpus ^ " cpus " ^ Int.toString memory ^ " MB: "
    ^ String.concatWith " " (Vector.foldr (fn (j, acc) => showJob j :: acc) [] jobs)

  val runGen = (Gen.pair (jobsGen, machineGen), showRun)

  fun simulated (jobs, (cpus, memory)) = Scheduler.simulate (Scheduler.plan jobs, {cpus = cpus, memory = memory})

  (* the jobs that run at time t: started at or before it and not yet ended *)
  fun runningAt (jobs : job vector, starts, t) =
    List.filter (fn i => Vector.sub (starts, i) <= t andalso t < Vector.sub (starts, i) + #cost (Vector.sub (jobs, i)))
                (List.tabulate (Vector.length jobs, fn i => i))

  (* every time something starts: what runs then is what runs at its widest *)
  fun everyStart (jobs, starts, p) =
    Vector.foldl (fn (t, ok) => ok andalso p (runningAt (jobs, starts, t))) true starts

  fun sum f l = List.foldl (fn (x, s) => s + f x) 0 l
  fun ids jobs = List.tabulate (Vector.length jobs, fn i => i)

  fun afterItsDeps (jobs, m) =
    let val (starts, _) = simulated (jobs, m)
    in Vector.foldli (fn (i, j : job, ok) =>
                        ok andalso List.all (fn d => Vector.sub (starts, i) >= Vector.sub (starts, d) + #cost (Vector.sub (jobs, d)))
                                            (#deps j))
                     true jobs
    end

  fun fitsTheMachine (jobs : job vector, m as (cpus, memory)) =
    let val (starts, _) = simulated (jobs, m)
    in everyStart (jobs, starts, fn rs =>
                     length rs <= 1
                     orelse (sum (fn i => #cpus (Vector.sub (jobs, i))) rs <= cpus
                             andalso sum (fn i => #memory (Vector.sub (jobs, i))) rs <= memory))
    end

  fun poolsExclude (jobs : job vector, m) =
    let
      val (starts, _) = simulated (jobs, m)
      fun clash rs =
        List.exists (fn q => length (List.filter (fn i => List.exists (fn x => x = q) (#pools (Vector.sub (jobs, i)))) rs) > 1)
                    ["a", "b"]
    in everyStart (jobs, starts, not o clash) end

  fun exclusiveAlone (jobs : job vector, m) =
    let val (starts, _) = simulated (jobs, m)
    in everyStart (jobs, starts, fn rs => length rs <= 1 orelse not (List.exists (fn i => #exclusive (Vector.sub (jobs, i))) rs))
    end

  (* the longest chain of costs, and the work spread over every CPU *)
  fun lowerBound (jobs : job vector, (cpus, _)) =
    let
      val memo = Array.array (Vector.length jobs, 0.0)
      val () = Vector.appi (fn (i, j : job) =>
                              Array.update (memo, i, #cost j + List.foldl (fn (d, b) => Real.max (b, Array.sub (memo, d))) 0.0 (#deps j)))
                           jobs
      val chain = Array.foldl Real.max 0.0 memo
      val work = Vector.foldl (fn (j : job, s) => s + #cost j * real (Int.min (#cpus j, cpus))) 0.0 jobs
    in Real.max (chain, work / real cpus) end

  fun withinBounds (jobs : job vector, m) =
    let val (_, makespan) = simulated (jobs, m)
    in makespan >= lowerBound (jobs, m) - 1.0e~9 andalso makespan <= Vector.foldl (fn (j : job, s) => s + #cost j) 0.0 jobs + 1.0e~9
    end

  (* jobs of one CPU each with no edges, pools or exclusion: Graham's bound
     for list scheduling, the work over the CPUs and the longest job *)
  fun graham (costs, cpus) =
    let
      val jobs = Vector.fromList (List.map (fn c => {cost = real c, cpus = 1, memory = 0, pools = [], exclusive = false,
                                                       failedLast = false, deps = []}) costs)
      val (_, makespan) = Scheduler.simulate (Scheduler.plan jobs, {cpus = cpus, memory = 100})
      val total = real (List.foldl op+ 0 costs)
      val longest = real (List.foldl Int.max 0 costs)
    in makespan <= total / real cpus + longest + 1.0e~9 end

  (* a job that failed last time, waits for nothing and fits, starts at 0 *)
  fun failedFirst (jobs : job vector, m as (cpus, memory)) =
    let
      val (starts, _) = simulated (jobs, m)
      val candidates = List.filter (fn i => let val j = Vector.sub (jobs, i)
                                            in #failedLast j andalso null (#deps j) andalso not (#exclusive j)
                                               andalso #cpus j <= cpus andalso #memory j <= memory andalso null (#pools j) end)
                                   (ids jobs)
    in
      (* the first such job by number, since two of them may not both fit *)
      case candidates of [] => true | i :: _ => Real.== (Vector.sub (starts, i), 0.0) orelse
        (* or every CPU or megabyte went to jobs that failed too *)
        List.exists (fn k => k <> i andalso #failedLast (Vector.sub (jobs, k))) (runningAt (jobs, starts, 0.0))
    end

  (* a job's priority is its cost and the most of its dependents', with the
     bonus of a job that failed last time taken off *)
  fun criticalPath (jobs : job vector, _) =
    let
      val p = Scheduler.plan jobs
      fun level i = Scheduler.priority (p, i) - (if #failedLast (Vector.sub (jobs, i)) then 1.0e12 else 0.0)
      fun dependents i = List.filter (fn k => List.exists (fn d => d = i) (#deps (Vector.sub (jobs, k)))) (ids jobs)
    in
      List.all (fn i => Real.abs (level i - (#cost (Vector.sub (jobs, i))
                                             + List.foldl (fn (k, b) => Real.max (b, level k)) 0.0 (dependents i))) < 1.0e~3)
               (ids jobs)
    end

  fun prop f = fn () => Prop.forAllGen runGen (fn r => Prop.holds (f r))

  fun historyRoundTrip entries =
    let
      val file = OS.FileSys.tmpName ()
      val h = List.foldl (fn ((p, w, ok), h) => History.record (h, {path = p, wall = real w / 8.0, passed = ok})) History.empty entries
      val () = History.write (file, h)
      val back = History.read file
      val () = OS.FileSys.remove file
      fun same (a : History.entry, b : History.entry) =
        #path a = #path b andalso #passed a = #passed b andalso #flips a = #flips b
        andalso ListPair.allEq (fn (x, y) => Real.abs (x - y) < 0.001) (#walls a, #walls b)
    in ListPair.allEq same (History.entries h, History.entries back) end

  val pathGen = Gen.map (fn k => "suite/" ^ Int.toString k) (Gen.intRange (0, 5))
  val showEntries = Show.list (Show.triple (Show.string, Show.int, Show.bool))

  (* the expectations: one file of each meaning *)
  val sample =
    Expectations.parse ("e.txt",
      "# a comment, and an empty line\n\n"
      ^ "native* | rt.interrupt_self | UNSUPPORTED | native code does not poll\n"
      ^ "smlnj* | Word64.toInt::overflow | HOST-BUG | the host's bug\n"
      ^ "* | flaky.test | HOST-FLAKY | it races\n"
      ^ "* | new.test | QUARANTINE | until 2026-11-01: being fixed\n"
      ^ "mlkit | gone.test | HOST-BUG | a test that passes now\n")
  fun at n = List.nth (sample, n)
  fun judged (way, path, label, passed, today) =
    Expectations.judge (sample, {way = way, path = path, label = label, passed = passed, today = today})
  fun expectationTests () =
    [Test.it "Expectations.parse/the-lines" (fn () =>
       (Expect.that ("five lines", length sample = 5);
        Expect.that ("the label", #label (at 1) = SOME "overflow" andalso #path (at 1) = "Word64.toInt");
        Expect.that ("the reason", #reason (at 3) = "until 2026-11-01: being fixed");
        Expect.that ("a line of every way",
                     case Expectations.parse ("e", "MATH.atan2/law-1@* | FAILS | the reals\n") of
                       [l] => #way l = "*" andalso #path l = "MATH.atan2/law-1@*" andalso #category l = "FAILS"
                     | _ => false))),
     Test.it "Expectations.parse/refuses" (fn () =>
       (Expect.raises ("no category", fn Expectations.Parse _ => true | _ => false,
                       fn () => Expectations.parse ("e", "* | a | NOPE | why\n"));
        Expect.raises ("too few fields", fn Expectations.Parse _ => true | _ => false,
                       fn () => Expectations.parse ("e", "* | a\n"));
        Expect.raises ("a quarantine without its date", fn Expectations.Parse _ => true | _ => false,
                       fn () => Expectations.parse ("e", "* | a | QUARANTINE | soon\n")))),
     Test.it "Expectations.glob/whole" (fn () =>
       (Expect.that ("a star", Expectations.glob ("native*", "native-cycles"));
        Expect.that ("the whole", not (Expectations.glob ("native", "native-cycles")));
        Expect.that ("a question mark", Expectations.glob ("rt.?", "rt.a") andalso not (Expectations.glob ("rt.?", "rt.ab")));
        Expect.that ("a class", Expectations.glob ("*[Ss]tring.x", "WideString.x") andalso not (Expectations.glob ("[Ss]x", "tx")));
        Expect.that ("a range and a negation", Expectations.glob ("v[0-9]", "v7") andalso Expectations.glob ("[!o]x", "ax")
                                                andalso not (Expectations.glob ("[!o]x", "ox")));
        Expect.that ("a hyphen at the end", Expectations.glob ("[+-]1", "-1") andalso Expectations.glob ("[+-]1", "+1"));
        Expect.that ("stars between", Expectations.glob ("a*b*c", "axxbyyc") andalso not (Expectations.glob ("a*b*c", "axxbyy"))))),
     Test.it "Expectations.skipped/skip" (fn () =>
       (Expect.that ("skipped where it says", isSome (Expectations.skipped (sample, {way = "native", path = "rt.interrupt_self"})));
        Expect.that ("run elsewhere", not (isSome (Expectations.skipped (sample, {way = "test", path = "rt.interrupt_self"})))))),
     Test.it "Expectations.judge/strict" (fn () =>
       (Expect.that ("its failure expected",
                     case judged ("smlnj32", "Word64.toInt", SOME "overflow", false, "2026-10-12") of
                       Expectations.Expected _ => true | _ => false);
        Expect.that ("its pass unexpected, and failing",
                     case judged ("smlnj32", "Word64.toInt", SOME "overflow", true, "2026-10-12") of
                       oc as Expectations.Unexpected _ => Expectations.failing oc | _ => false);
        Expect.that ("another label is not its",
                     judged ("smlnj32", "Word64.toInt", SOME "other", false, "2026-10-12") = Expectations.Fail))),
     Test.it "Expectations.judge/lenient" (fn () =>
       Expect.that ("either way, and failing nothing",
                    List.all (fn passed => case judged ("polyml", "flaky.test", NONE, passed, "2026-10-12") of
                                             oc as Expectations.Flaky _ => not (Expectations.failing oc) | _ => false)
                             [true, false])),
     Test.it "Expectations.judge/quarantine" (fn () =>
       (Expect.that ("its failure fails nothing before the date",
                     case judged ("rune", "new.test", NONE, false, "2026-11-01") of
                       oc as Expectations.Quarantined _ => not (Expectations.failing oc) | _ => false);
        Expect.that ("and fails after it",
                     case judged ("rune", "new.test", NONE, false, "2026-11-02") of
                       oc as Expectations.Expired _ => Expectations.failing oc | _ => false))),
     Test.it "Scheduler.retry/again" (fn () =>
       let
         val p = Scheduler.plan (Vector.fromList [{cost = 1.0, cpus = 1, memory = 0, pools = [], exclusive = false,
                                                   failedLast = false, deps = []}])
         val s = Scheduler.start p
         val first = Scheduler.admit (s, {cpus = 1, memory = 10})
         val () = Scheduler.retry (s, 0)
         val again = Scheduler.admit (s, {cpus = 1, memory = 10})
       in
         Expect.that ("started, put back, and started again", first = [0] andalso again = [0]);
         Expect.that ("not finished until it ends", not (Scheduler.finished s) andalso null (Scheduler.ended (s, 0, true))
                                                    andalso Scheduler.finished s)
       end),
     Test.it "Requirements.missing/probes" (fn () =>
       let val cs = [{name = "yes", probe = "true", hint = "h1"}, {name = "no", probe = "false", hint = "h2"}]
       in
         Expect.that ("a probe that fails, and a capability without one",
                      Requirements.missing (cs, ["yes", "no", "unknown"]) = [("no", "h2"), ("unknown", "no probe says what it is")]);
         Expect.that ("probed once, and remembered", Requirements.present (cs, "yes") andalso not (Requirements.present (cs, "no")))
       end),
     Test.it "Expectations.stale/each" (fn () =>
       let
         val st = Expectations.stale (sample, {ways = ["mlkit", "native"], paths = ["rt.interrupt_self", "flaky.test"],
                                               used = [], today = "2026-12-01"})
       in
         Expect.that ("the strict line that matched no failure in a way that ran", List.exists (fn l => #path l = "gone.test") st);
         Expect.that ("not a strict line of a way that did not run", not (List.exists (fn l => #path l = "Word64.toInt") st));
         Expect.that ("not a skip that names a test", not (List.exists (fn l => #path l = "rt.interrupt_self") st));
         Expect.that ("the quarantine past its date", List.exists (fn l => #path l = "new.test") st);
         Expect.that ("never a lenient line", not (List.exists (fn l => #path l = "flaky.test") st));
         Expect.that ("a used strict line is not stale",
                      not (List.exists (fn l => #path l = "gone.test")
                             (Expectations.stale (sample, {ways = ["mlkit"], paths = [], used = [at 4], today = "2026-10-12"}))))
       end)]

  fun retention () =
    let
      val base = OS.FileSys.tmpName ()
      val () = (OS.FileSys.remove base; OS.FileSys.mkDir base)
      fun join p = OS.Path.concat (base,p)
      fun touch p = TextIO.closeOut (TextIO.openOut p)
      fun entries dir =
        let val stream = OS.FileSys.openDir dir
            fun read kept = case OS.FileSys.readDir stream of NONE => kept | SOME n => read (n::kept)
        in read [] before OS.FileSys.closeDir stream end
      fun clean path = if OS.FileSys.isDir path then
        (List.app (fn n => clean (OS.Path.concat (path,n))) (entries path); OS.FileSys.rmDir path)
        else OS.FileSys.remove path
      fun work () =
        let
          val out = join "runs"
          val () = OS.FileSys.mkDir out
          fun directory name = let val path=OS.Path.concat (out,name)
                               in OS.FileSys.mkDir path; path end
          (* The oldest run is still active while more than five newer runs
             finish. Reports may already exist while a run is closing them. *)
          val active = directory "19990101-000000-1"
          val () = List.app (fn n => touch (OS.Path.concat (active,n)))
            ["running","sentinel","summary.md","junit.xml"]
          val unfinished = directory "19990101-000000-2"
          val () = touch (OS.Path.concat (unfinished,"running"))
          fun completed i =
            let val dir=directory ("20000101-000000-" ^ Int.toString i)
            in List.app (fn n => touch (OS.Path.concat (dir,n))) ["summary.md","junit.xml"] end
          val () = List.app completed [1,2,3,4,5,6]
          val tests = List.map (fn {path,meta,leaf} => (path,meta,leaf))
            (Test.leaves (Test.it "retention/probe" (Run.shell ("exit 0",1))))
          val ok = Run.run {tests=tests,root=OS.FileSys.getDir (),out=out,
            history=join "history",cpus=1,memory=100,keep=false,
            reader=Report.Log,capabilities=[],strict=true,quarantine=[]}
        in
          Expect.that ("run completed",ok);
          Expect.that ("active output survives",OS.FileSys.access (OS.Path.concat (active,"sentinel"),[]));
          Expect.that ("interrupted output survives",OS.FileSys.access (unfinished,[]));
          Expect.that ("old completed output is removed",not (OS.FileSys.access (OS.Path.concat (out,"20000101-000000-1"),[])));
          Expect.that ("five completed runs and two unfinished runs remain",length (entries out)=7)
        end
    in (work () before clean base) handle error => (clean base; raise error) end

  val tests =
    Test.describe "runner/props"
      (expectationTests () @
      [Test.it "Run.run/preserves-concurrent-output" retention,
       Test.property "Scheduler.simulate/after-its-dependencies" (prop afterItsDeps),
       Test.property "Scheduler.simulate/fits-the-machine" (prop fitsTheMachine),
       Test.property "Scheduler.simulate/pools-exclude" (prop poolsExclude),
       Test.property "Scheduler.simulate/exclusive-alone" (prop exclusiveAlone),
       Test.property "Scheduler.simulate/within-bounds" (prop withinBounds),
       Test.property "Scheduler.simulate/failed-first" (prop failedFirst),
       Test.property "Scheduler.priority/the-critical-path" (prop criticalPath),
       Test.property "Scheduler.simulate/graham" (fn () =>
         Prop.forAllGen (Gen.pair (Gen.list (Gen.intRange (1, 30)), Gen.intRange (1, 8)),
                         Show.pair (Show.list Show.int, Show.int))
                        (Prop.holds o graham)),
       Test.it "Scheduler.plan/a-cycle" (fn () =>
         Expect.raises ("a cycle", fn Fail _ => true | _ => false, fn () =>
           Scheduler.plan (Vector.fromList [{cost = 1.0, cpus = 1, memory = 0, pools = [], exclusive = false, failedLast = false, deps = [1]},
                                            {cost = 1.0, cpus = 1, memory = 0, pools = [], exclusive = false, failedLast = false, deps = [0]}]))),
       Test.it "Scheduler.priority/critical-path" (fn () =>
         let
           fun job (c, ds) = {cost = c, cpus = 1, memory = 0, pools = [], exclusive = false, failedLast = false, deps = ds}
           val p = Scheduler.plan (Vector.fromList [job (1.0, []), job (5.0, [0]), job (2.0, [])])
         in
           Expect.that ("the chain of 1 and 5", Real.== (Scheduler.priority (p, 0), 6.0));
           Expect.that ("alone", Real.== (Scheduler.priority (p, 2), 2.0))
         end),
       Test.it "History.record/many-in-order" (fn () =>
         (* 5000 paths in order, which a tree that is not balanced makes a list *)
         let
           val paths = List.tabulate (5000, fn i => "t/" ^ StringCvt.padLeft #"0" 5 (Int.toString i))
           val h = List.foldl (fn (p, h) => History.record (h, {path = p, wall = 1.0, passed = p <> "t/02500"})) History.empty paths
         in
           Expect.that ("every one found", List.all (fn p => isSome (History.cost (h, p))) paths);
           Expect.that ("the failed one", History.failedLast (h, "t/02500") andalso not (History.failedLast (h, "t/02501")));
           Expect.that ("in order", List.map #path (History.entries h) = paths)
         end),
       Test.property "History.write/read-back" (fn () =>
         Prop.forAllGen (Gen.list (Gen.triple (pathGen, Gen.intRange (0, 4000), Gen.bool)), showEntries)
                        (Prop.holds o historyRoundTrip))])
end

structure RunnerPropsMain = Main (struct val name = "runner/props" val tests = RunnerProps.tests end)
val () = RunnerPropsMain.main ()

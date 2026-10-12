(* The laws of the Basis Library's documentation on the runner
   (docs/plans/unit-testing.md, M8; docs/plans/quickcheck.md, M8, D9, D12
   and D13): what tests/basis/run-laws.sh did.

   `runedoc --laws` writes a program for each signature with a law into
   build/laws (make check-tools), holding every law at every structure that
   implements the signature. Each is compiled with `--library
   test/property/basis` (`laws-compile/NAME`), and its laws run a structure
   at a time (`laws/NAME@STRUCTURE`, or `laws/NAME@-` for all of them) by
   `bin/rune-test laws-one`: the program runs with at most LAWS_MEMORY
   megabytes (4096), printing a line before each law and each case, and a
   case that runs LAWS_TIMEOUT seconds (60) without the next line is
   stopped. A case the machine cannot hold, for its memory or its time, is
   skipped: the program starts again with that case skipped
   (RUNE_PROPERTY_SKIP), from the law it was in (RUNE_PROPERTY_AFTER). A law
   with ten such cases stopped for their time, or fifty in all, is STOPPED,
   and the program goes on after it.

   tests/basis/law-skips.txt lists the laws that do not hold or are not
   tested (D12), in the format of the expectations of every way: the
   failure or stop of a law it lists is known, and a law it lists that
   passes is a line to remove. Any other failure or stop fails the test.
   The environment chooses how the laws run (Check.laws): RUNE_PROPERTY_DEEP
   and the rest pass to the programs. *)
structure Laws =
struct
  fun env (name, default) = case OS.Process.getEnv name of SOME v => if v = "" then default else v | NONE => default
  fun read f = (let val s = TextIO.openIn f in TextIO.inputAll s before TextIO.closeIn s end) handle IO.Io _ => ""
  fun lines s = List.filter (fn l => l <> "") (String.fields (fn c => c = #"\n") s)
  fun say s = (TextIO.output (TextIO.stdOut, s); TextIO.flushOut TextIO.stdOut)
  fun words l = String.tokens (fn c => c = #" ") l
  fun field (n, l) = case List.drop (words l, n) of x :: _ => x | [] => "" handle Subscript => ""

  (* ---- one program at one structure (bin/rune-test laws-one RBC STRUCTURE) *)
  fun one (rbc, st) =
    let
      (* the register VM with its JIT, from the root of the tree *)
      val vm = env ("RUNE_TEST_ROOT", ".") ^ "/bin/runevm"
      val timeout = getOpt (Int.fromString (env ("LAWS_TIMEOUT", "60")), 60)
      val memory = getOpt (Int.fromString (env ("LAWS_MEMORY", "4096")), 4096)
      val at = if st = "-" then "" else st
      val base = List.filter (fn kv => not (List.exists (fn p => String.isPrefix p kv)
                                                        ["RUNE_PROPERTY_CASES=", "RUNE_PROPERTY_AT=", "RUNE_PROPERTY_AFTER=",
                                                         "RUNE_PROPERTY_SKIP="]))
                             (Posix.ProcEnv.environ ())
      fun lineCount f = length (String.fields (fn c => c = #"\n") (read f)) - 1
      (* a run of the program; whether the watchdog stopped it, and its status *)
      fun attempt (last, skips) =
        let
          val out = Posix.FileSys.creat ("run.out", Posix.FileSys.S.flags [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr])
          val null = Posix.FileSys.openf ("/dev/null", Posix.FileSys.O_RDONLY, Posix.FileSys.O.flags [])
          fun n fd = SysWord.toInt (Posix.FileSys.fdToWord fd)
          val pid =
            Subprocess.spawn {program = vm, args = [vm, rbc],
                              env = SOME (["RUNE_PROPERTY_CASES=1", "RUNE_PROPERTY_AT=" ^ at, "RUNE_PROPERTY_AFTER=" ^ last,
                                           "RUNE_PROPERTY_SKIP=" ^ String.concatWith " " skips] @ base),
                              search = false, dir = NONE, stdin = SOME (n null), stdout = SOME (n out), stderr = SOME (n out),
                              group = true,
                              limits = {addressSpace = SOME (memory * 1024 * 1024), cpuTime = NONE, fileSize = NONE, core = NONE}}
          val () = (Posix.IO.close out; Posix.IO.close null)
          (* the watchdog: a case that prints nothing for the timeout is stopped *)
          fun watch (seen, idleSince) =
            case Subprocess.poll (SOME pid) of
              SOME {status, ...} => (false, status)
            | NONE =>
                let
                  val () = OS.Process.sleep (Time.fromSeconds 1)
                  val now = Runtime.clock ()
                  val count = lineCount "run.out"
                in
                  if count <> seen then watch (count, now)
                  else if Time.toSeconds (Time.- (now, idleSince)) >= LargeInt.fromInt timeout then
                    ((Subprocess.kill (pid, Posix.Signal.kill) handle OS.SysErr _ => ());
                     (true, #status (Subprocess.wait (SOME pid))))
                  else watch (seen, idleSince)
                end
        in watch (0, Runtime.clock ()) end
      fun loop (last, skips, slow) =
        let
          val (stopped, status) = attempt (last, skips)
          val run = lines (read "run.out")
          val () = List.app (fn l => if String.isPrefix "PASS " l orelse String.isPrefix "FAIL " l then say (l ^ "\n") else ()) run
          (* the program's output but the cases, for a reader *)
          val () = let val s = TextIO.openAppend "laws.out"
                   in List.app (fn l => if String.isPrefix "CASE " l then () else TextIO.output (s, l ^ "\n")) run; TextIO.closeOut s end
          val lawLines = List.filter (fn l => String.isPrefix "LAW " l) run
        in
          if List.exists (fn l => String.isPrefix "laws: " l) run then ()
          else
            case rev lawLines of
              [] => say ("STOPPED " ^ st ^ " before its first law (" ^ Supervisor.outcomeName
                           (case status of Posix.Process.W_EXITED => Supervisor.Exited 0
                                         | Posix.Process.W_EXITSTATUS w => Supervisor.Exited (Word8.toInt w)
                                         | Posix.Process.W_SIGNALED s => Supervisor.Signalled (SysWord.toInt (Posix.Signal.toWord s))
                                         | Posix.Process.W_STOPPED s => Supervisor.Signalled (SysWord.toInt (Posix.Signal.toWord s)))
                         ^ ")\n")
            | stuckLine :: earlier =>
                let
                  val stuck = field (1, stuckLine)
                  val why =
                    if stopped then "after " ^ Int.toString timeout ^ "s"
                    else case rev (List.filter (fn l => not (List.exists (fn p => String.isPrefix p l)
                                                                          ["LAW", "CASE", "PASS", "FAIL", "  "])) run) of
                           l :: _ => l
                         | [] => ""
                  (* the case the machine could not hold: the last one of the law it was in *)
                  fun after ([], _) = []
                    | after (l :: rest, inLaw) =
                        if l = "LAW " ^ stuck then after (rest, true)
                        else if inLaw then l :: after (rest, true) else after (rest, false)
                  val case' = case rev (List.filter (fn l => String.isPrefix "CASE " l) (after (run, false))) of
                                l :: _ => field (1, l)
                              | [] => ""
                  val count = length (List.filter (fn s => String.isPrefix (stuck ^ ":") s) skips)
                  val slows = length (List.filter (fn s => String.isPrefix (stuck ^ ":") s) slow)
                in
                  if case' <> "" andalso count < 50 andalso (not stopped orelse slows < 10) then
                    let
                      val () = say ("SKIPPED " ^ stuck ^ " case " ^ case' ^ ": " ^ why ^ "\n")
                      val prev = case earlier of l :: _ => field (1, l) | [] => stuck
                    in
                      loop (if prev <> stuck then prev else last, skips @ [stuck ^ ":" ^ case'],
                            if stopped then slow @ [stuck ^ ":" ^ case'] else slow)
                    end
                  else
                    (say ("STOPPED " ^ stuck ^ " " ^ why
                          ^ (if case' = "" then "" else " (the " ^ Int.toString (count + 1) ^ "th case it could not finish)") ^ "\n");
                     loop (stuck, skips, slow))
                end
        end
    in
      loop ("", [], [])
    end

  (* ---- the tree *)
  fun sort xs =
    let
      fun merge ([], ys) = ys
        | merge (xs, []) = xs
        | merge (x :: xs, y :: ys) = if y < x then y :: merge (x :: xs, ys) else x :: merge (xs, y :: ys)
      fun split (x :: y :: rest) = let val (a, b) = split rest in (x :: a, y :: b) end
        | split xs = (xs, [])
      fun go [] = []
        | go [x] = [x]
        | go xs = let val (a, b) = split xs in merge (go a, go b) end
    in go xs end

  val programs =
    let
      val d = OS.FileSys.openDir "build/laws"
      fun go acc = case OS.FileSys.readDir d of
                     NONE => acc
                   | SOME f => go (if String.isSuffix ".sml" f then String.substring (f, 0, size f - 4) :: acc else acc)
    in sort (go [] before OS.FileSys.closeDir d) end
    handle OS.SysErr _ => []

  (* a program's structures, as run-laws.sh found them: the @S of its labels,
     or "-" for all of them when a label names none *)
  fun structures name =
    let
      val ls = List.filter (fn l => String.isPrefix "  (\"" l) (lines (read ("build/laws/" ^ name ^ ".sml")))
      val labels = List.map (fn l => case String.fields (fn c => c = #"\"") l of _ :: lab :: _ => lab | _ => "") ls
      val ats = List.mapPartial (fn lab => case String.fields (fn c => c = #"@") lab of
                                             [_, s] => SOME s
                                           | _ => NONE) labels
      fun uniq [] = []
        | uniq (x :: xs) = x :: uniq (List.filter (fn y => y <> x) xs)
    in
      if null ats orelse List.exists (fn lab => not (String.isSubstring "@" lab)) labels then ["-"] else sort (uniq ats)
    end

  val skips = Expectations.read "tests/basis/law-skips.txt"

  fun shell (script, dir, timeout, memory, after, judge) =
    {program = "/bin/sh", args = ["sh", "-c", script], env = NONE, dir = dir, stdin = NONE,
     timeout = Time.fromSeconds timeout, cap = 0, cpus = 1, memory = memory, pools = [], exclusive = false,
     after = after, judge = judge} : Run.command

  fun compile name =
    Test.it name
      (shell ("mkdir -p \"$RUNE_TEST_RUN\"/laws && exec bin/rune --library test/property/basis build/laws/"
              ^ name ^ ".sml -o \"$RUNE_TEST_RUN\"/laws/" ^ name ^ ".rbc",
              SOME ".", 600, 500, [], Run.exitZero))

  fun judge (r : Supervisor.result, files as {stdout, ...}) =
    case #outcome r of
      Supervisor.Exited 0 =>
        let
          val results = List.filter (fn l => List.exists (fn p => String.isPrefix p l) ["PASS ", "FAIL ", "STOPPED "])
                                    (lines (read stdout))
          fun label l = let val x = field (1, l) in if String.isSuffix ":" x then String.substring (x, 0, size x - 1) else x end
          fun listed l = isSome (Expectations.find (skips, {way = "rune", path = label l, label = NONE}))
          val bad = List.filter (fn l => not (String.isPrefix "PASS " l) andalso not (listed l)) results
          val stale = List.filter (fn l => String.isPrefix "PASS " l andalso listed l) results
        in
          case (bad, stale) of
            ([], []) => NONE
          | _ => SOME ("FAIL", String.concatWith "\n"
                                 (bad @ List.map (fn l => l ^ " -- listed in tests/basis/law-skips.txt: remove the line") stale))
        end
    | _ => Run.exitZero (r, files)

  fun run name st =
    Test.it (name ^ "@" ^ st)
      (shell ("exec \"$RUNE_TEST_ROOT\"/bin/rune-test laws-one \"$RUNE_TEST_RUN\"/laws/" ^ name ^ ".rbc " ^ st,
              NONE, 3600, 4200, ["laws-compile/" ^ name], judge))

  val tree =
    Test.tag "check" (Test.tag "test-laws" (Test.tag "covers:tests/basis/law-skips.txt"
      (Test.describe ""
         [Test.describe "laws-compile" (List.map compile programs),
          Test.describe "laws" (List.concat (List.map (fn p => List.map (run p) (structures p)) programs))])))
end

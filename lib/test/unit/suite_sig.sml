(* A suite: a structure that names its tests (docs/plans/unit-testing.md,
   D2 and D10). A structure that ascribes `SUITE` is a suite, and `Main`
   makes it a program.

   Area: Unit testing *)
signature SUITE =
sig
  (* The suite's name, which its summary line gives. *)
  val name : string

  (* The suite's tests. *)
  val tests : Test.test
end

(* Running a suite, as a program does (D10). Without options every test
   runs, and each prints a line: `PASS path`, `FAIL path` with the failed
   checks below it, or `SKIP path` with the reason; a `SUMMARY` line ends
   the run. The options are:

   - `--list`: the paths of the tests that would run, one to a line, and
     nothing run;
   - `--list-meta`: the same as JSON lines, with each test's metadata;
   - `--filter F`: only the tests that `F` selects (`TestFilter`);
   - `--run P`: only the test of the path `P`, and with several, those;
   - `--after P`: only the tests after the test of the path `P`, in the
     order they were written, where a run that was stopped goes on;
   - `--events FILE`: a JSON line in `FILE` as each test starts and ends,
     and for each check that fails, so that a runner whose worker died
     knows the test it died in;
   - `--accept`: golden files written, not compared (`Golden`);
   - `--quiet`: no line for a test that passes.

   Words that do not start with `--` are ignored, so that a compiler that
   passes its own arguments on to the program does not change the run.

   Area: Unit testing *)
signature SUITE_RUN =
sig
  (* What a run counted. A failed test is one whose checks failed, that
     called `Expect.fail` or that raised; a skipped test is a pending one. *)
  type summary = {tests : int, passed : int, failed : int, skipped : int}

  (* `run {args, print} tests` runs the tests that the options `args`
     select, reporting through `print`.

     An unknown option, and two tests with the same path, are each reported
     as a failure.

     Example: `#failed (run {args = [], print = fn _ => ()} (Test.it "two" (fn () => Expect.that ("2", 1 + 1 = 2)))) = 0`

     Example: `#failed (run {args = ["--quiet"], print = fn _ => ()} (Test.describe "s" [Test.it "t" (fn () => Expect.fail "no")])) = 1` *)
  val run : {args : string list, print : string -> unit} -> Test.test -> summary

  (* `main tests` runs `tests` with the program's arguments, printing to
     standard output, and ends the program with failure if a test failed. *)
  val main : Test.test -> unit
end

(* The program of a suite: `main ()` runs the suite's tests as `Suite.main`
   does.

   Area: Unit testing *)
signature SUITE_MAIN =
sig
  (* `main ()` runs the suite's tests with the program's arguments. *)
  val main : unit -> unit
end

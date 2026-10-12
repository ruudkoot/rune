(* The runner's canaries (docs/plans/unit-testing.md, Testing the tester):
   tests whose commands fail on purpose -- they exit with 1, run past their
   time, crash, overflow their output, and leave a process behind -- and
   whose judges pass only when the runner saw that fault for what it is. A
   runner that a broken compiler or VM built, and that wrongly passes what
   it runs, fails here. They run in every run of the tier `check`. *)
structure Canary =
struct
  fun judge expect (r : Supervisor.result, _) =
    if expect r then NONE else SOME ("FAIL", "the runner did not see the fault: " ^ Supervisor.outcomeName (#outcome r)
                                             ^ (if #leaked r then ", left processes behind" else ""))

  fun canary (name, script, timeout, cap, expect) =
    Test.tag "check"
      (Test.it name {program = "/bin/sh", args = ["sh", "-c", script], env = NONE, dir = NONE, stdin = NONE,
                     timeout = timeout, cap = cap, cpus = 1, memory = 10, pools = [], exclusive = false, after = [],
                     judge = judge expect} : Run.command Test.tree)

  val tests =
    Test.describe "runner/canary"
      [canary ("fails", "exit 1", Time.fromSeconds 60, 0,
               fn r => #outcome r = Supervisor.Exited 1),
       canary ("runs-past-its-time", "sleep 60", Time.fromSeconds 1, 0,
               fn r => #outcome r = Supervisor.TimedOut),
       canary ("crashes", "kill -SEGV $$", Time.fromSeconds 60, 0,
               fn r => #outcome r = Supervisor.Signalled 11),
       canary ("floods-its-output", "yes flooding the output", Time.fromSeconds 60, 1000000,
               fn r => case #outcome r of Supervisor.Capped => true | Supervisor.Signalled _ => true | _ => false),
       canary ("leaves-a-process", "sleep 60 & exit 0", Time.fromSeconds 60, 0,
               fn r => #outcome r = Supervisor.Exited 0 andalso #leaked r)]
end

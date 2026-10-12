(* A run of tests that are commands (docs/plans/unit-testing.md, M3): each
   in a directory of its own of a fixed width under the run's directory, or
   in a directory it names; judged when it ends; its directory removed when
   it passed and kept when it did not; its wall time recorded in the
   history; and every outcome reported.

   Area: Running tests *)
signature RUN =
sig
  (* A test that is a command: what runs, where, what it may take, what it
     waits for, and how its verdict is found.

     `after` names the tests it waits for by path. `judge` finds the
     verdict from how the command ended and the files of its output and
     errors: `NONE` passes, and `SOME (verdict, reason)` does not. `dir` is
     `NONE` for a directory of its own. `env` is `NONE` for the runner's
     environment without what would make a `make` inside it a part of the
     runner's own (`MAKELEVEL`, `MFLAGS`, and the jobs and jobserver of
     `MAKEFLAGS`, whose variables stay) or force colour (`FORCE_COLOR`,
     `CLICOLOR_FORCE`). A command takes no more CPUs than the run has, and
     finds how many it has in `RUNE_TEST_CPUS`, the run's directory in
     `RUNE_TEST_RUN` and the tree's in `RUNE_TEST_ROOT`, both absolute;
     `RUNE_TEST_ACCEPT` is 1 in a run that accepts (`accept`). *)
  type command = {program : string, args : string list, env : string list option, dir : string option,
                  stdin : string option, timeout : Time.time, cap : int, cpus : int, memory : int,
                  pools : string list, exclusive : bool, after : string list,
                  judge : Supervisor.result * {stdout : string, stderr : string} -> (string * string) option}

  (* `exitZero (r, files)` is the verdict of a command that passes when it
     exits with 0.

     Otherwise its verdict is `FAIL`, `TIMEOUT`, `CRASH` (a signal) or
     `LEAK` (it left processes behind), with the end of its output. *)
  val exitZero : Supervisor.result * {stdout : string, stderr : string} -> (string * string) option

  (* `shell (script, cpus)` is a command that runs `script` with `/bin/sh -c`
     in the directory of the tree, judged by `exitZero`.

     Its timeout is an hour, and its output has no cap. *)
  val shell : string * int -> command

  (* `index names` finds a name among `names`: its place, or `NONE`.

     Example: `index (Vector.fromList ["b", "a"]) "a" = SOME 1` *)
  val index : string vector -> string -> int option

  (* `tail (n, file)` is the last `n` lines of `file`, or "" when there is
     none. *)
  val tail : int * string -> string

  (* Whether the run accepts what its tests printed as what they should
     print (`--accept`).

     A judge that reads a golden file writes it instead, and says
     `ACCEPTED`. It is `false` unless the command line sets it. *)
  val accept : bool ref

  (* `run {tests, root, out, history, cpus, memory, keep, reader}` runs
     `tests` in a new directory under `out`, and is whether every test
     passed.

     The tree's directory is `root`; the run has `cpus` processors and
     `memory` megabytes; it reads and rewrites the history file `history`;
     and `keep` keeps every test's directory. *)
  val run : {tests : (string * Test.meta * command) list, root : string, out : string, history : string,
             cpus : int, memory : int, keep : bool, reader : Report.reader} -> bool
end

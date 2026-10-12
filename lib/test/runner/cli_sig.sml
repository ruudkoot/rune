(* The runner's command line (docs/plans/unit-testing.md, D19):

   - `list [FILTER]`: the tests, with their tags, and nothing run;
   - `run [FILTER] [--tier T] [-j N] [--mem MB] [--keep] [--failed]`: the
     tests the filter selects (and the tier, a tag), on `N` processors
     (by default those of the machine less its load from outside, and at
     least half of them) and `MB`
     megabytes; `--failed` runs the tests that failed last time,
     `--keep` keeps every test's directory, and `--accept` writes what the
     tests printed into their golden files (`Run.accept`);
   - `explain PATH`: a test's command, directory and needs;
   - `stats`: the slowest and the flakiest tests in the history;
   - `doctor [FILTER]`: the capabilities the tests require, each probed,
     with how to get those that are missing (it fails when one is).

   A run of the tier check, or with `--strict`, fails a test whose
   capability is missing; any other run skips it. For flaky tests
   (docs/plans/unit-testing.md, D17): `--repeat N` runs the selection N
   times, `--until-fail` until a run fails (at most N times, 100 by
   default), and `--under-load` keeps every processor busy beside it.

   A filter is the language of `TestFilter`; two or more of them select
   the tests any of them selects. The tests a selected test waits for are
   selected with it, and a run runs the tests tagged `always` as well.
   `--profile P` is `--tier P`.

   The tier quick, and `--informed`, add every test that failed last time
   or whose verdict has changed between runs, by the history.

   `--affected` keeps, of what is selected, the tests that cover a path
   changed since `HEAD` (in the work tree, or not yet known to git);
   `--since REV` since `REV`, and `--changed FILE` the paths that `FILE`
   lists, one to a line. A test covers the paths its tags `covers:GLOB`
   match; a changed path that no test covers keeps every test. `--root DIR` is the directory of the tree (default `.`), `--out DIR` where
   runs go (default `tests/out/r`), `--history FILE` the history (default
   `build/test-history.tsv`). A run ends the program with success when every
   test passed, with failure otherwise, and with 2 for a mistake in the
   command line.

   Area: Running tests *)
signature CLI =
sig
  (* `main tests` runs the command line's command over `tests`. *)
  val main : Run.command Test.tree -> unit

  (* `mainWith {tests, capabilities, quarantine}` is `main tests`, with
     what the tests may require and what is in quarantine.

     `capabilities` are what tests may require (`Requirements`), and
     `quarantine` the file of the quarantine's expectations ("" for none). *)
  val mainWith : {tests : Run.command Test.tree, capabilities : Requirements.capability list, quarantine : string} -> unit
end

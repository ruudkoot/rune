(* The runner's command line (docs/plans/unit-testing.md, D19):

   - `list [FILTER]`: the tests, with their tags, and nothing run;
   - `run [FILTER] [--tier T] [-j N] [--mem MB] [--keep] [--failed]`: the
     tests the filter selects (and the tier, a tag), on `N` processors
     (by default those of the machine less its load from outside) and `MB`
     megabytes; `--failed` runs the tests that failed last time,
     `--keep` keeps every test's directory, and `--accept` writes what the
     tests printed into their golden files (`Run.accept`);
   - `explain PATH`: a test's command, directory and needs;
   - `stats`: the slowest and the flakiest tests in the history.

   A filter is the language of `TestFilter`; two or more of them select
   the tests any of them selects. The tests a selected test waits for are
   selected with it. `--root DIR` is the directory of the tree (default `.`), `--out DIR` where
   runs go (default `tests/out/r`), `--history FILE` the history (default
   `build/test-history.tsv`). A run ends the program with success when every
   test passed, with failure otherwise, and with 2 for a mistake in the
   command line.

   Area: Running tests *)
signature CLI =
sig
  (* `main tests` runs the command line's command over `tests`. *)
  val main : Run.command Test.tree -> unit
end

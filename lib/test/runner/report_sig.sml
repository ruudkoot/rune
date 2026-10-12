(* What a run says, to the reader it has (docs/plans/unit-testing.md, D14).

   On a terminal: one status line, redrawn at most ten times a second, with
   each failure printed above it as it happens and a summary at the end. To
   a log, and to an agent: nothing for a test that passes, a line every 30
   seconds that says how far the run is, a block for each failure that
   stands alone, and the summary. An agent, recognised by its environment
   (`AI_AGENT`, `CLAUDECODE`, `CODEX_SANDBOX`, `CURSOR_AGENT`,
   `GEMINI_CLI`), gets the path of the run's events at the start as well,
   since it may see only the head and the tail of a long output. Every
   failure line begins with its verdict, and the last line with `RESULT:`.
   The run's events go to a file of JSON lines in every case, and the
   summary, in Markdown, to the file summary.md beside it, and to the file
   `GITHUB_STEP_SUMMARY` names when it names one.

   Area: Running tests *)
signature REPORT =
sig
  (* Who reads: a person at a terminal, a log, or an agent. *)
  datatype reader = Terminal | Log | Agent

  (* `reader ()` is the reader of standard output: an agent when the
     environment names one, a terminal when standard output is one, and a
     log otherwise. *)
  val reader : unit -> reader

  (* A report being written. *)
  type report

  (* `start {reader, events, total}` begins the report of a run of `total`
     tests, its events written to the file `events`. *)
  val start : {reader : reader, events : string, total : int} -> report

  (* `tick (r, running)` redraws the status line, or writes the line that
     says the run goes on, when it is time to. *)
  val tick : report * int -> unit

  (* What a test ended with: its path, its verdict and why, what it cost,
     where its outputs are kept, and the command that reruns it.

     The verdict is one of `PASS`, `FAIL`, `TIMEOUT`, `CRASH`, `LEAK`,
     `ERROR`, `SKIP` and `ACCEPTED` (a golden file written, `Run.accept`);
     the first, the last and `SKIP` are not failures. *)
  type ended = {path : string, verdict : string, reason : string, wall : Time.time, user : Time.time,
                system : Time.time, peakResident : int, outputBytes : int, kept : string list,
                command : string, rerun : string}

  (* `test (r, e)` reports `e`: a failure as a block, a pass as a count, and
     both as an event. *)
  val test : report * ended -> unit

  (* `finish (r, {cpus, freed, keptBytes})` writes the summary and the
     `RESULT:` line, and is whether every test ran and passed.

     `cpus` is the processors the run had, and `freed` and `keptBytes` the
     bytes of output removed and kept. *)
  val finish : report * {cpus : int, freed : int, keptBytes : int} -> bool
end

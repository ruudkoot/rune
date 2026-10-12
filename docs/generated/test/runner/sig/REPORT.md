# signature REPORT

[Running tests](../README.md) &rsaquo; Running tests &rsaquo; **REPORT**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 8 of 8 entries documented |
| Tests | not listed |
| Source | [lib/test/runner/report\_sig.sml](../../../../../lib/test/runner/report_sig.sml) |

## Synopsis

```sml
signature REPORT
structure Report :> REPORT
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Report`](../str/Report.md) | The report: the status line, the failure blocks, the events and the summary. | [lib/test/runner/report.sml](../../../../../lib/test/runner/report.sml) |

What a run says, to the reader it has (docs/plans/unit-testing.md, D14).

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

## Interface

<pre>
signature REPORT =
sig
  datatype <a href="#type-reader">reader</a> = <a href="#con-terminal">Terminal</a> | <a href="#con-log">Log</a> | <a href="#con-agent">Agent</a>
  val <a href="#val-reader">reader</a> : unit -&gt; reader
  type <a href="#type-report">report</a>
  val <a href="#val-start">start</a> : {<a href="#fld-start.reader">reader</a> : reader, <a href="#fld-start.events">events</a> : string, <a href="#fld-start.total">total</a> : int} -&gt; report
  val <a href="#val-tick">tick</a> : report * int -&gt; unit
  type <a href="#type-ended">ended</a> = {<a href="#fld-ended.path">path</a> : string, <a href="#fld-ended.verdict">verdict</a> : string, <a href="#fld-ended.reason">reason</a> : string, <a href="#fld-ended.wall">wall</a> : Time.time, <a href="#fld-ended.user">user</a> : Time.time,
                <a href="#fld-ended.system">system</a> : Time.time, <a href="#fld-ended.peakresident">peakResident</a> : int, <a href="#fld-ended.outputbytes">outputBytes</a> : int, <a href="#fld-ended.kept">kept</a> : string list,
                <a href="#fld-ended.command">command</a> : string, <a href="#fld-ended.rerun">rerun</a> : string}
  val <a href="#val-test">test</a> : report * ended -&gt; unit
  val <a href="#val-finish">finish</a> : report * {<a href="#fld-finish.cpus">cpus</a> : int, <a href="#fld-finish.freed">freed</a> : int, <a href="#fld-finish.keptbytes">keptBytes</a> : int} -&gt; bool
end
</pre>

### <a name="type-reader"></a>`reader`

```sml
datatype reader = Terminal | Log | Agent
```

Who reads: a person at a terminal, a log, or an agent.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-terminal"></a>`Terminal` |  |  |
| <a name="con-log"></a>`Log` |  |  |
| <a name="con-agent"></a>`Agent` |  |  |

### <a name="val-reader"></a>`reader`

```sml
val reader : unit -> reader
```

`reader ()` is the reader of standard output: an agent when the
environment names one, a terminal when standard output is one, and a
log otherwise.

### <a name="type-report"></a>`report`

```sml
type report
```

A report being written.

### <a name="val-start"></a>`start`

```sml
val start : {reader : reader, events : string, total : int} -> report
```

`start {reader, events, total}` begins the report of a run of `total`
tests, its events written to the file `events`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-start.reader"></a>`reader` | `reader` |  |
| <a name="fld-start.events"></a>`events` | `string` |  |
| <a name="fld-start.total"></a>`total` | `int` |  |

### <a name="val-tick"></a>`tick`

```sml
val tick : report * int -> unit
```

`tick (r, running)` redraws the status line, or writes the line that
says the run goes on, when it is time to.

### <a name="type-ended"></a>`ended`

```sml
type ended = {path : string, verdict : string, reason : string, wall : Time.time, user : Time.time,
              system : Time.time, peakResident : int, outputBytes : int, kept : string list,
              command : string, rerun : string}
```

What a test ended with: its path, its verdict and why, what it cost,
where its outputs are kept, and the command that reruns it.

The verdict is one of `PASS`, `FAIL`, `TIMEOUT`, `CRASH`, `LEAK`,
`ERROR`, `SKIP` and `ACCEPTED` (a golden file written, [`Run.accept`](../sig/RUN.md#val-accept));
the first, the last and `SKIP` are not failures.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-ended.path"></a>`path` | `string` |  |
| <a name="fld-ended.verdict"></a>`verdict` | `string` |  |
| <a name="fld-ended.reason"></a>`reason` | `string` |  |
| <a name="fld-ended.wall"></a>`wall` | `Time.time` |  |
| <a name="fld-ended.user"></a>`user` | `Time.time` |  |
| <a name="fld-ended.system"></a>`system` | `Time.time` |  |
| <a name="fld-ended.peakresident"></a>`peakResident` | `int` |  |
| <a name="fld-ended.outputbytes"></a>`outputBytes` | `int` |  |
| <a name="fld-ended.kept"></a>`kept` | `string list` |  |
| <a name="fld-ended.command"></a>`command` | `string` |  |
| <a name="fld-ended.rerun"></a>`rerun` | `string` |  |

### <a name="val-test"></a>`test`

```sml
val test : report * ended -> unit
```

`test (r, e)` reports `e`: a failure as a block, a pass as a count, and
both as an event.

### <a name="val-finish"></a>`finish`

```sml
val finish : report * {cpus : int, freed : int, keptBytes : int} -> bool
```

`finish (r, {cpus, freed, keptBytes})` writes the summary and the
`RESULT:` line, and is whether every test ran and passed.

`cpus` is the processors the run had, and `freed` and `keptBytes` the
bytes of output removed and kept.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-finish.cpus"></a>`cpus` | `int` |  |
| <a name="fld-finish.freed"></a>`freed` | `int` |  |
| <a name="fld-finish.keptbytes"></a>`keptBytes` | `int` |  |

---

<sub>Generated by runedoc from lib/test/runner/report\_sig.sml; do not edit.</sub>

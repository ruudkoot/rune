# Roadmap: the REPL, its terminal and its colours

Rune has had a REPL since incremental M4: units are compiled one declaration
at a time, loaded into the running program, echoed with printers made
from their types, and interrupted with Ctrl-C. What the user sees of it
is still the minimum: a prompt `- ` on a terminal in the kernel's
cooked mode, so that an arrow key puts `^[[A` into the declaration; no
history, completion or colour; one error line with no excerpt of what
was typed; values printed on one line however long; no command but
`use`. This roadmap plans what makes it best in class: a terminal
library any Rune program can use, with colours and a full line editor
on Linux and Windows; one palette for the REPL, the compiler and
runedoc; a REPL built on them, with commands, documentation and
printing to match the best of the other languages; reload of changed
files; a protocol through which editors, rune-ide and a Jupyter kernel
drive it; and a debugger at its prompt. It was written on 2026-10-09
against `f8e9fdc5`, the commit of incremental M5 (Rune's side), and is
committed on branch `repl` from that commit.

What it rests on:
* a reading of the REPL as built (`src/repl`, `lib/basis/compiler.sml`,
  `docs/repl.md`, `tests/repl`), of the terminal and console code of the
  runtime (`runtime/sys`, `runtime/prims.c`, `lib/basis/posix_tty.sml`),
  of the compiler's diagnostics and runedoc's output, and of the plans
  this one continues or serves (`incremental-compilation.md`, `hol4.md`,
  `ide.md` here and in rune-ide, `errror-messages.md`, `weak-points.md`);
* six calibration experiments run on a build of `f8e9fdc5`, on Linux
  and on Windows 11 through WSL interop (*The experiments*): today's
  REPL timed, a terminal probe and a mini editor written in Standard ML
  on Rune, Windows console input as Rune reads it and as it could,
  SHA-256, HMAC and ZMTP in Standard ML for a kernel, and the capture
  of a program's output;
* the sources of twenty-two REPLs and seventeen line editors under
  `/home/ruud/reference` and on the web, and the literature (*What the
  implementations do*, *What the literature says*, *References*).

Paths without a prefix are in this tree at `f8e9fdc5`; `rune-ide:` paths
are in `/home/ruud/rune-ide` at `d4b3552`; `~/reference/` paths are under
`/home/ruud/reference`. Numbers marked as measured were taken on
2026-10-09 on a machine another session loaded with a test chain (load
average about 30 on 16 CPUs): they bound costs and compare designs, and
M1 measures them again on a quiet machine.

## Status

| Milestone | What | State |
|---|---|---|
| M0 | This roadmap | done |
| M1 | The terminal harness and the baselines | done |
| M2 | The palette and coloured diagnostics | done |
| M3 | The console in the runtime and the Basis | done |
| M4 | `lib/terminal`: styles, keys, raw mode | planned |
| M5 | `lib/terminal`: the line editor | planned |
| M6 | The REPL on the editor | planned |
| M7 | Printing | planned |
| M8 | Commands and documentation | planned |
| M9 | Reload | planned |
| M10 | The engine and its protocol | planned |
| M11 | The Jupyter kernel | planned |
| M12 | The debugger | planned |
| M13 | Windows, accessibility and the performance sweep | planned |

The owner decided D1 to D25 on 2026-10-10, as recommended, and added a
rule for generic code (*The request*); what starts first is the owner's. M1 to
M6 are one part: at its end the REPL has colours and a line editor on
Linux and Windows, and `lib/terminal` serves any program; the owner may
stop there. M7 to M9 finish the REPL as a tool; M10 to M12 open it to
other programs. M2 to M5 do not need incremental merged and can be
built from master; M1's harness can too, though its scripts of today's
REPL need incremental's (*Prerequisites and flags*).

## The request

The owner's brief, as written:

> - this is a draft roadmap to make Rune's REPL best-in-class
> - the basic repl has been implemented on the incremantal worktree
>   - that worktree and the incremental-compilation.md are still being implemented
>   - but the user-facing functionally of the repl should be mostly done now
> - please research existing REPLs to find the features we need to support
>   - some implementation can be found in /home/ruud/reference
>   - you can probably find the source of other programming languages you want to study on the internet
>   - there might even be some academic literature on the topic?
> - i want the REPL to have colors and good editing
>   - start lib/terminal that has color output and a full readline implementation that can be used any rune program
>     - readline needs to work on both linux and windows terminals
>   - add a color.sml file under src that has a shared color pallete than can be used to ensure consistency across rune repl and rune compiler output and runedoc etc.
>   - in the repl we should distinguish:
>     - repl 'ui'
>     - user input
>     - evaluation output (non-errors)
>     - evaluation output (errors)
>     - etc.

The owner's answers to three questions asked before this was written
(2026-10-09):
* **Where:** a worktree `.worktrees/repl` on branch `repl` from
  incremental's latest commit, this roadmap committed as its M0 and not
  pushed; the brief in the main tree left as it is.
* **Evidence:** a survey of the REPLs from their sources and of the
  literature, and small calibration prototypes run on a snapshot of the
  tree, never on the incremental worktree another session works in.
* **Scope:** beyond the terminal REPL, an evaluation protocol for
  editors and IDEs, a Jupyter kernel, debugging at the REPL, and reload
  of changed files.

**The owner's decisions after reading this roadmap (2026-10-10):** every
recommendation, D1 to D25 (*Decisions*), and a rule, as written:

> if you need any highly generic and reusable functionality (e.g. sha256, zmtp) factor it into a separate well tested library under lib so it can be reused in future projects

What the rule changes is in *The architecture* (*The libraries*) and in
the milestones that build them.

| The brief asks | Answered in |
|---|---|
| a roadmap that makes Rune's REPL best in class | the whole; what "best" means, measurably: D24 |
| the REPL as built on incremental is the base | *Where we are*; *Relation to other plans* |
| research existing REPLs for the features to support | *What the implementations do*, the feature matrix |
| the implementations in `/home/ruud/reference` | the same; *References* |
| the sources of other languages from the internet | the same |
| academic literature | *What the literature says* |
| colours and good editing | D2, D3, D7 to D13; M2, M4 to M6 |
| `lib/terminal`: colour output and a full readline for any Rune program | *The architecture*; D4, D7, D25; M4, M5 |
| the readline works on Linux and Windows terminals | *The experiments* (P1, P3); D4, D5; M3, M13 |
| `color.sml` under `src`: one palette for the REPL, the compiler, runedoc | D1, D2; M2 |
| distinguish the REPL's UI, user input, output, errors, and the rest | D2 (the roles), D18; M2, M6 |
| (owner's answer) an evaluation protocol for editors and IDEs | D20; M10 |
| (owner's answer) a Jupyter kernel | D21; M11 |
| (owner's answer) debugging at the REPL | D22; M12 |
| (owner's answer) reload of changed files | D19; M9 |
| (owner's rule) generic code as tested libraries under `lib` | *The libraries*; M2, M4, M5, M7, M8, M10 to M12 |

## Where we are

### The REPL as built

`rune -i` and `bin/rune-repl` start the REPL: an image of the compiler
and the Basis, units linked one by one and saved with `Runtime.save`,
restored by `runevm --restore` (`Makefile:855-871`; `src/repl/load.sml:9-24`;
`src/repl/repl.sml:299-304`). On this build it shows its first prompt in
72 to 87 ms and answers `1;` in 8 to 16 ms (*The experiments*, P0).

* **Reading.** `Repl.loop` prints the prompt, flushes, and calls
  `TextIO.inputLine TextIO.stdIn` (`src/repl/repl.sml:238-259`). The
  terminal stays in the kernel's cooked mode: nothing in the tree calls
  `tcsetattr` for it, so editing is the line discipline's own (erase,
  `^U`, `^W`), and an arrow key is three bytes in the declaration. The
  prompt is printed whatever stdin is: nothing in `src/repl` looks at
  `isatty`, `TERM` or any environment variable but `RUNE_CACHE`
  (`src/repl/session.sml:115`), and the transcripts of `tests/repl`
  contain the prompts (`tests/repl/values.expected:1`).
* **Completeness.** After every line the whole buffer is lexed and parsed
  again as a new source `stdIn` from line 1 (`src/repl/repl.sml:247-256`),
  and `Repl.parseAt` decides: complete when the last token is `;` and the
  parse succeeds; more when the parse fails at the end, when there is
  nothing but blanks and comments, or when the lexer's message contains
  "unterminated" (`src/repl/repl.sml:49-69`). Pasting 1,000 lines takes 6.7
  to 7.0 s, 100 lines 0.34 s: the cost grows faster than the length, with a
  term in its square (P0). An unterminated string never completes, since the
  lexer stops it at the newline (`src/frontend/lexer.sml:148`), and at end
  of input the buffer is dropped without a word
  (`src/repl/repl.sml:246,255`). The depth scanner HOL4 needed for
  `Compiler.compile` (`src/repl/repl.sml:160-205`) is not used by the
  interactive loop.
* **Compiling.** Each declaration is a unit (`src/repl/repl.sml:80-111`;
  `ReplSession.compile`, `src/repl/session.sml:136-222`): elaborated with
  `_prim` forbidden and recovery off (`src/repl/session.sml:40,185`), its
  warnings flushed to stderr, a printer made from its type appended
  (`ReplShow`, incremental D10 A), linked into the running program.
* **Echo.** The unit prints its own values while it runs:
  `RuneShow.echo` calls the top-level `print` (`lib/basis/compiler.sml:58`;
  `src/repl/show.sml:141-150`). Every printer returns one string: there is
  a depth (`Compiler.printDepth`, 20) but no length, no width and no line
  breaking (`lib/basis/compiler.sml:24-59`). A type is printed without its
  structure (`Types.toString`; `Types.toStringNamed`, which runedoc uses
  for paths, is not in the REPL, `src/elab/types.sml:302-346`), an
  exception without its argument, a real without its point
  (`val r = 5 : real`, `tests/repl/values.expected:3`). Signatures,
  functors and fixity echo nothing; a structure echoes `structure S`
  (`src/repl/session.sml:79-101`).
* **Errors.** `file:line:col: error: msg` on stderr, the first error of a
  declaration only (recovery is off, `src/repl/session.sml:40`), no excerpt
  of the input and no caret (`src/util/error.sml:8`;
  `src/repl/repl.sml:24`), with lines counted from the start of each entry.
  An uncaught exception is `uncaught exception` and `exnMessage`, which
  shows an argument for `Fail` alone (`src/repl/repl.sml:27-30`;
  `lib/basis/pervasive.sml:92-93`), and no trace: the REPL's handler catches
  it after its frames are gone, and `Exception.location` was planned and not
  built (`docs/plans/incremental-compilation.md:2359-2361`).
* **Interrupts.** Ctrl-C is caught and masked around the REPL's own work,
  unmasked around the user's code and the wait for a line
  (`src/repl/repl.sml:34-42,284-285`); a terminal read waits in `poll` so
  that the signal ends it (`runtime/sys/sys_posix.c:781-796`); the
  interpreter and the JIT poll the flag at calls and backward jumps
  (`runtime/register/interp.c:95-100`;
  `runtime/register/jit/compile.c:780-792`). `OS.IO.poll` and
  `Socket.select` are not interrupted (`runtime/sys/sys_posix.c:450`;
  `runtime/sys/sys_win.c:951-1012`).
* **Everything else.** No command but `use` and the `Compiler`
  structure (`lib/basis/compiler_sig.sml:22-71`); no flag but the files
  to `use`, so `rune-repl --help` reports that it cannot read `--help`
  (`src/repl/repl.sml:299-305`); no banner, init file, history or
  completion; no wrapper for Windows (`Makefile:869-871`).
  `docs/repl.md:168-172` says as much: "there is no history or editing
  of lines".

The incremental worktree goes on beyond this commit: a printer API in
Poly/ML's shape (`Compiler.pretty`, `prettyPrint`, `addPrettyPrinter`,
`lineLength`), which HOL4's branch already calls
(`HOL:tools-rune/rune-polyml.ML:13-26,49-52`, HOL `3d15b18a8`), is being
built there and is not in `f8e9fdc5`. This roadmap builds on it when it
lands (D16, *Prerequisites and flags*).

### Output, and what the REPL shares with the program

The REPL and the user's code are one program with one Basis
(`docs/repl.md:110-113`; `src/repl/session.sml:6-14`). `TextIO.stdOut`
can be replaced from Standard ML with a writer of one's own
(`lib/basis/imperativeio_fn.sml:18-23`; `lib/basis/streamio_fn.sml:284-286`),
and a wrapped writer costs nothing measurable (P5). But the top-level
`print` is a primitive that writes to C's `stdout` and not through
`TextIO.stdOut` (`lib/basis/pervasive.sml:32`; `runtime/prims.c:1771-1775`),
so a replaced stream sees neither the user's `print` nor the REPL's own
echo. The order of the two is kept, since both end in the same C
`FILE`; what is lost is the line: `TextIO.output (TextIO.stdOut, "abc");`
echoes `abcval it = () : unit`, the echo glued to the user's unfinished
line (P5).

### The console in the runtime and the Basis

* **POSIX.** `Posix.TTY` is complete over `posix_tcgetattr`,
  `posix_tcsetattr` and `posix_tcop` (`lib/basis/posix_tty.sml:22-75`),
  `isatty` is in `Posix.ProcEnv`, `OS.IO.poll` takes a timeout. A Standard
  ML program on Rune can therefore enter raw mode and read keys: P1 does,
  and decodes every key a terminal sends. What is missing is the size of
  the terminal (no `TIOCGWINSZ`), the signal of a resize (no `SIGWINCH`;
  the only handler is `SIGINT`'s, `runtime/sys/sys_posix.c:1287-1312`), and
  a restore when the program dies: an uncaught exception leaves the
  terminal raw (P1).
* **Windows.** termios is emulated over console modes: `ECHO`,
  `ICANON` and `ISIG` become `ENABLE_ECHO_INPUT`, `ENABLE_LINE_INPUT` and
  `ENABLE_PROCESSED_INPUT` (`runtime/sys/sys_win.c:1611-1647`); the
  standard handles are in binary mode (`runtime/sys/sys_win.c:43-52`);
  input is read with the C runtime's `_read`; the key wait looks at key
  events whose `AsciiChar` is not 0 (`runtime/sys/sys_win.c:912-923`).
  Nothing sets `ENABLE_VIRTUAL_TERMINAL_INPUT` or the UTF-8 code pages.
  P3 ran P1's probe on `runevm.exe` in a console: the arrows, Home, End,
  the function keys, Delete and Escape are lost, Alt arrives without its
  escape, é arrives as the byte of code page 437 and € as `?`, the
  markers of a paste are lost, Ctrl-Z ends the input. No line editor can
  be written over this layer; with the console in virtual terminal mode
  and read as UTF-16, the same keys arrive as the same bytes as on Linux
  (P3).
* **Libraries.** A library under `lib/` may not use `_prim`
  (`src/driver/main.sml:200-202,411-427`; `AGENTS.md:327-331`), and those of its
  files marked `host yes` build on MLton, SML/NJ, Poly/ML and MLKit
  against their own Basis (`tests/lib/run-hosts.sh:35-42`). What
  `lib/terminal` needs of the system beyond `Posix.TTY` has to come
  through a structure of `lib/basis`.

### Diagnostics, runedoc and the IDE

* The compiler's diagnostics are strings: `Error.format` is
  `Source.describe sp ^ ": error: " ^ msg` (`src/util/error.sml:8`), a
  warning the same with `warning` (`:17-22`), a column a byte offset
  (`src/util/source.sml:4,49-62`). There is no colour anywhere in the
  tree, no `--color` flag, no test of `NO_COLOR` or `TERM` (a search of
  `src`, `lib`, `runtime`, `scripts` and `tests` finds none).
* The tests hold that text: `tests/errors` wants the first line of
  stderr to contain the expected message, `tests/lang` compares `.cwarn`
  and `.stderr` exactly, `tests/repl` and `tests/units` compare stderr
  exactly (`tests/run-tests.sh:12-17,84-169`; `tests/repl/run.sh:47-50`;
  `tests/units/run.sh:48,60-63`). Output to anything that is not a
  terminal must stay byte for byte what it is.
* Messages name types badly: `IntInf.int` against `int` reads
  `type mismatch between int and int/1 (type constructor mismatch: int
  vs int)` (`src/elab/elaborate.sml:46-55`; met while writing P1,
  `logs/p1-error-example.log` in the drafts).
* runedoc writes Markdown (`docs/generated/basis/`): pages that list every
  member for people (`index/a.md` to `index/z.md`), and tables for programs
  that name modules only (`claims.tsv`, `notes.tsv`), but no
  machine-readable index of members; search is out of its scope
  (`docs/plans/docgen.md:973-978`), and `make install` does not install the
  pages (`scripts/install.sh:244-254`).
* rune-ide speaks JSON-RPC 2.0, one message per line, to a service
  written in Standard ML (`rune-ide:docs/ide-protocol.md:1-26`), with its
  own JSON codec (`rune-ide:src/sml/json.sml`); its M6 will "Integrate
  REPL/evaluation when the incremental/REPL work provides it"
  (`rune-ide:docs/plans/ide.md:536`).

### What the compiler gives a REPL

* The session's environment is an `Env.env` of `StringMap`s
  (`src/elab/env.sml:6-24`; `ReplSession.env`, `src/repl/session.sml:19`):
  enough for completion and `:type`. Signatures and functors are outside
  it, in `Elaborate.sigs` and `Elaborate.funs`
  (`src/elab/elaborate.sml:12-20`). No binding records where it was
  defined (`src/elab/env.sml:7`).
* The lexer needs `Token`, `Scon`, `Source`, `StringMap` and `Error`
  and nothing else (`src/frontend/lexer.sml`); it drops comments and
  raises at its first error with no tokens at all
  (`src/frontend/lexer.sml:70,81,148`). P2 highlights with it.
* At run time a program carries a line table with inlined frames and a
  name for every function, but no name for a local
  (`docs/bytecode.md:24-29,86-138`); `Runtime.trace` gives frames
  (`lib/basis/runtime_sig.sml:131-152`); the JIT can leave compiled code
  at any instruction boundary with the frame made exact (jit M11,
  `docs/plans/jit.md:2403-2445`); `runevm --trace` runs a second copy of
  the interpreter loop and switches the JIT off
  (`runtime/register/interp.c:19-20,130-148,189`). There is no breakpoint,
  step or debugger primitive.
* The Basis has sockets, `INetSock` and `UnixSock` on Linux and Windows
  (`lib/basis/inetsock.sml:1,56`), with `Socket.select` over `OS.IO.poll`
  (`lib/basis/socket.sml:282-298`), and no threads; no SHA, HMAC, JSON or
  ZeroMQ code is in `lib` or `src`.

## What is different for SML

Most of what a good REPL does is the same in every language: a line
editor, history, completion, colour, a pager for documentation. What
follows is what Standard ML changes, and where it changes the design.

* **The end of an entry.** A top-level declaration ends at a `;` that
  is not inside an expression: `(a; b)`, `let ... in a; b end` and a
  `case` arm hold `;` without ending anything. The terminator is a
  token, not a line, so Enter on `val x = 1` cannot submit by itself the
  way it can in Python or Julia, and a pasted file of declarations with
  no `;` at all is complete only at its end. Whether an entry is
  finished is decided by the depth of `let`/`local`/`struct`/`sig`/
  `abstype` ... `end` and of brackets outside strings and comments, then
  by the parser (D12). OCaml has the same rule with `;;`; MLKit,
  Moscow ML, SML/NJ and Poly/ML all wait for `;`.
* **Fixity is part of the session.** An `infix` declaration changes how
  later input parses, so completeness, highlighting and completion read
  the session's fixity, not the initial one (`ReplSession.fixity`,
  `src/repl/session.sml:20`).
* **A free prefix for commands.** A `:` followed by a letter begins no
  SML: a symbolic identifier can begin with `:` (`:=`, or a `:::` of
  one's own), but never with `:` and a letter. So `:type`, `:doc` and the
  rest, named by letters only, cannot be mistaken for SML (D15). `#`
  begins a record selector (`#1 x`).
* **Identifiers.** Symbolic identifiers (`++`, `<$>`, `::`) and long
  ones (`TextIO.StreamIO.mkOutstream`) make a word for editing (Alt-B,
  Ctrl-W) and a prefix for completion different things: completion
  works on long identifiers and on symbolic names, word motion on runs
  of alphanumerics or of symbols. A name may be in scope through `open`.
* **Values print from their types.** There is no type at run time: the
  printer of a value is made from its type when the declaration is
  compiled (incremental D10 A, `src/repl/show.sml`). Everything a REPL
  prints of a value, a debugger shows of a local, or a notebook renders
  as HTML goes through printers made by the compiler, and a value whose
  type is abstract shows as `?` unless a printer is installed for it
  (D16, D22).
* **Generativity.** Declaring a datatype again makes a new type; values
  of the old one keep it, print it, and do not match the new
  constructors. A REPL must show the difference (SML/NJ prints the old
  type as `?.t`), and a reload cannot patch a value in place the way
  Revise.jl patches a method: it shadows, and says which bindings still
  hold the old types (D19).
* **The top level of the Definition.** Chapter 8 makes a declaration
  that raises bind nothing while its effects stay; the value
  restriction makes `val r = ref []` an error at the top level in Rune
  (a warning in SML/NJ); type variables left free are reported, not
  generalised. The REPL keeps all three as they are and explains them
  better (D17).
* **An interrupt is an exception.** `SML90.Interrupt` reaches the
  user's handlers, and a program may catch it. Ctrl-C at the prompt,
  in the editor (where the terminal is raw and no signal is sent) and
  during evaluation must keep meaning the same thing (D11 of incremental,
  D18 here).
* **Strings are bytes.** `char` is eight bits and a `string` holds
  UTF-8 as bytes, so a line editor measures what it draws in code points
  and display columns of its own (D9), and a column in a diagnostic is a
  byte offset until it is converted (`src/util/source.sml:4,49-62`).
* **Separate compilation is new here.** The REPL compiles a unit per
  declaration and loads it (incremental M2 to M4); reload, the engine
  and the debugger are built on units, the cache and `UnitBasis.undo`,
  not on an interpreter of the source.

## What the literature says

There is little research on REPLs and line editors as such: no
empirical study of how people use a REPL was found, and only one user
study of an extended one (Peleg et al. 2020). What there is comes from
the systems themselves, from the long line of work on error messages,
pretty printing, search by type and debugging, and from studies of
notebooks. Each item: what it is and what transfers. The *References*
give the sources; every DOI was checked against Crossref on 2026-10-09.

### The top level

* **Sandewall 1978**, the survey of the Lisp experience, states the
  loop ("read an expression from the user, execute it, and print out the
  result while preserving global side effects") and three lessons that
  still hold: keep the history both as structure and as text; a user
  must always be able to cancel a feature that acts for them (Ctrl-C
  must stop a completion, a search, the printing of a huge value as
  surely as a computation); undoing a redefinition needs one versioning
  of definitions, not ad hoc fixes.
* **DrScheme** (Findler et al. 2002, §3.2) names the "ghosts of old
  programs": after a redefinition, closures and helpers keep the old
  definitions, and a forgotten rename silently calls the old function.
  Its answer is that Run resets the REPL and evaluates the definitions
  afresh, and that the REPL warns when the source changed since. SML's
  shadowing has exactly the same ghosts; `:reload!` is that reset (D19).
  Its §3.3 asks that values print in the syntax that writes them, which
  SML's `val x = [1, 2] : int list` already does.
* **"The top level is hopeless"** (Flatt, mailing-list messages
  collected by Tobin-Hochstadt) is about Racket's macro-expanding top
  level, where a definition can see a binding that a later one replaces.
  SML's top level is better specified (the Definition's Chapter 8), but
  the conclusion carries: the REPL is a place to try things against a
  program kept in files, and reload is the main way changes get in.
* **Elsman 2026**, the MLKit REPL, is the closest prior art: each
  top-level declaration is a unit of MLKit's incremental compilation, its
  bases kept on disk and loaded lazily; a compiler process and an
  evaluator process talk over named pipes (`LOADRUN`, `PRINT`; `DONE`,
  `EXN`), the evaluator loading each declaration with `dlopen`; values
  print by a generic printer that walks a value along a description of
  its type and representation; the session's rules come from the
  Definition's §8 with a mechanisation in Rocq (an uncaught exception
  keeps its effects and binds nothing). Rune made the same choice of a
  unit per declaration (incremental D9 A, in one process); the formal
  rules are a ready test suite, and the two processes are D20's C.
* **Isabelle/PIDE** (Wenzel 2014) replaces the synchronous loop the LCF
  tradition inherited with edits to versions of a document and
  asynchronous, cancellable print functions. It is the model for what an
  editor wants from an ML system beyond "send this text", and the reason
  D20's protocol has ids, cancellation and pushed results.
* **PEP 762** (Python 3.13) replaced a REPL on GNU readline with
  pyrepl, a line editor in Python, because "multi-line editing and
  Windows support" were "prohibitively complex" with readline; it keeps a
  basic mode (`PYTHON_BASIC_REPL`), and 3.14 adds highlighting with the
  16 ANSI colours only. It is the precedent for a language owning its
  line editor (D7) and for D24.
* **CakeML** (Kumar et al. 2014; Sewell et al. 2023) has a REPL proved
  to print only what the semantics allows, and an `Eval` that shares
  values with the running program: the yardstick for "the REPL prints
  nothing the Definition does not".
* **History.** Greenberg and Witten (1988, 1993) studied command lines:
  people "frequently and persistently repeat" them; history mechanisms
  rest on the premise that "the last few inputs form a reasonable
  selection", and conditioning on context predicts better. So a history
  is stepped through, searched, and suggested from (D11).

### Live programming and notebooks

* **Liveness** (Tanimoto 2013, extending his 1990 hierarchy; McDirmid
  2007; Rein et al. 2019's study of 212 publications) places a REPL low:
  feedback after each entry. Types, completions and errors shown while
  typing move it up; Hazel (Omar et al. 2019) evaluates around the holes
  of an unfinished program. Rune's editor can show the type of what is
  typed and errors as they appear (D13, *Ready for, not built*).
* **RESL** (Peleg et al. 2020) adds synthesis to the loop; 19
  programmers edited less, read less documentation and solved more: one
  of the few studies of a REPL's users.
* **Notebooks** (Pérez and Granger 2007; Kluyver et al. 2016) are what a
  kernel serves. Rule et al. (2018: over a million notebooks, a quarter with
  no text), Pimentel et al. (2019: 1.4 million, and practices for
  reproducibility), Head et al. (2019: recovering the slice of code that
  made an output) and Chattopadhyay et al. (2020: nine pain points) agree
  that hidden state and out-of-order runs are the problem: the ghosts again.
  A kernel that says when a cell uses a binding since redefined, and can
  write the slice that reproduces a value, answers them (D19, D21).

### Error messages

* **People read them.** Barik et al. (2017, eye tracking, 56
  developers): messages are read, are as hard to read as code, and take
  13 to 25 per cent of a task's time.
* **Guidelines with their evidence.** Traver (2010) gives principles;
  Becker et al. (2019) survey the field and grade each guideline by the
  kind of evidence for it; Marceau et al. (2011) judge a message by the
  edit that follows it; Wrenn and Krishnamurthi (2017) treat a message
  as a classifier of program locations, judged by precision and recall:
  mark all and only the relevant spans.
* **Practice.** Elm (Czaplicki 2015): show the code as written, with line
  numbers; context above, a hint below; red for the problem, a second colour
  to separate messages; JSON for editors; and the better messages needed
  only "an extra bit of info to each type constraint". The Rust guide: a
  level, an optional code, a message that stands alone, primary and
  secondary spans with labels, `note` for facts and `help` for fixes,
  suggestions graded by how safely they apply, small spans, messages that
  start in lowercase (Rune's rule already, `AGENTS.md`, *Conventions*). GCC
  counts columns in display columns since 11.1 and writes SARIF; GHC writes
  JSON Lines.
* **Type errors in ML.** A type error is a set of places, not the one
  where unification failed: Haack and Wells (2003, 2004) define the
  slice; Skalpel (Rahli et al. 2015, 2017) is the only slicer for full
  SML; Lerner et al. (2007) search for nearby programs that type-check;
  Pavlinovic et al. (2014) find minimum error sources; Chen and Erwig
  (2014) type counter-factually; Helium (Heeren et al. 2003) was built
  around its messages; bidirectional type slicing (Carroll et al. 2026)
  answers "why has this term this type". The REPL wants the cheap part
  now (a snippet with all the spans the elaborator knows) and leaves
  slicing to `errror-messages.md` (D17).

### Pretty printing

Oppen (1980) prints in linear time and in space bounded by the width,
streaming; Hughes (1995) gave the algebra of combinators; Wadler (2003)
the `group`/`nest`/`line` core, which Leijen's `wl-pprint` extends
(`align`, `hang`, `fill`) and `prettyprinter` annotates (styles carried
to any back end); Swierstra and Chitil (2009), Chitil (2005) and
Kiselyov et al. (2012) make the streaming printer functional and
bounded; Bernardy (2017), Podkopaev and Boulytchev (2015) and
Porncharoenwase et al. (2023) find optimal layouts at a higher cost, the
last with a survey of all of them. For the REPL: Wadler's core with
annotations for the roles of the palette, a budget of nodes and depth so
that a huge value stops, and Poly/ML's `pretty` datatype as the type
user printers build (D16).

### Search by type and completion

Rittri (1989, 1991) searches a library by type modulo the isomorphisms
of a cartesian closed category, so that argument order and currying do
not matter; Runciman and Toyn (1989, 1991) by unification and instance,
ranked by distance; Di Cosmo (1993, 1995) axiomatises the isomorphisms
of ML's let-polymorphism and built a search tool on them, and with
Aponte (1996) extends them to module signatures. Hoogle is the measure of
the experience: one box for a name or a type, ranked, linked to the
documentation. Gvero et al. (2013) complete with whole expressions of
the wanted type; Bruch et al. (2009) rank completions by use rather
than alphabet. `:search` (D15) is Rittri's matching over the session's
environment, ranked by Runciman and Toyn's distance; completion ranks
what the session uses.

### Highlighting

The evidence is thin and mixed: Hannebauer et al. (2018, 390 students)
found no effect of syntax highlighting on comprehension; Sarkar (2015,
10 subjects) a faster completion that fades with experience; Beelders
and du Plessis (2015) no significant difference, but a preference for
colour. Highlighting is worth having when it is cheap; colour earns its
place where it carries meaning, on errors, the matching bracket and
what a name is (D2, D13).

### Debuggers

Tolmach and Appel (1990, 1995) debugged SML/NJ by instrumenting the
source, which ML's safety allows and which keeps the debugger out of the
back end, with checkpoints from continuations for reverse execution and
types resolved for polymorphic variables. Marlow et al. (2007) put the
debugger in GHCi, reusing its printer: stop, look, continue. Hölzle et
al. (1992) debug optimised code by deoptimising the frame on demand,
what jit M11 already does for Rune. Pothier et al. (2007) record traces
for omniscient debugging; the OCaml debugger travels back by forking
checkpoints, which Windows lacks. The DrScheme stepper (Clements et al.
2001) shows evaluation as reduction. For the REPL: instrumented units
and the VM's poll points first, deoptimisation for the frames, replay
later (D22).

### Colour

WCAG 2.2 defines contrast (4.5:1 for text, 3:1 for other things) and
asks that colour never be the only cue; Machado et al. (2009) simulate
the deficiencies of colour vision (with a typo in two equations of the
paper; the supplementary matrices are right). Python checks
`PYTHON_COLORS`, `NO_COLOR`, `FORCE_COLOR` and `TERM=dumb` in that order;
NO_COLOR (no-color.org) turns colour off but not bold; GCC_COLORS and
GHC_COLORS let a user restyle the roles (D2, D3).

### Standards

The terminal is ECMA-48 and xterm's control sequences (bracketed paste,
mode 2004; `modifyOtherKeys`; focus events; OSC 11 to ask the
background; OSC 8 for links; OSC 133 for the marks of prompts, input
and output, written with REPLs in mind; synchronised output, mode
2026), the kitty keyboard protocol for keys the legacy encoding cannot
say, and Microsoft's console virtual terminal sequences and ConPTY
(Windows 10 1809). Widths come from Unicode 18 (UAX #11, UAX #29, UTS
#51). A kernel speaks Jupyter's messaging protocol (5.5; DAP inside it
for debugging, JEP 47) over ZMTP 3.1, signs with HMAC (RFC 2104) over
SHA-256 (FIPS 180-4), tested with RFC 4231's vectors; editors speak LSP
(3.18), DAP, nREPL's operations, or JSON-RPC 2.0 as rune-ide does
(Merlin, Bour et al. 2018, for an ML's editor server).

### What transfers to Rune

* Own the line editor (PEP 762) and keep a basic mode.
* Keep the top level's semantics and say more about them: the ghosts of
  redefinitions (DrScheme), generativity, Chapter 8 (Elsman's rules as
  tests).
* Messages: spans as a classifier, the code as written, a hint below,
  display columns, JSON for tools.
* A Wadler printer with annotations and budgets for values and types.
* Search by type over the session (Rittri, Di Cosmo), ranked.
* Colour where it means something, never the only cue, off on request.
* A protocol with ids, cancellation and pushed output (PIDE, nREPL,
  Jupyter), and a debugger that reuses the REPL's printer (GHCi).

## What the implementations do

Twenty-two REPLs and seventeen line editors were read: from their
sources under `~/reference` where they are there (SML/NJ, Poly/ML,
MLKit, OCaml, GHC and haskeline, Julia, CPython, Erlang, Chez Scheme,
Guile, jshell and JLine, F#, Roslyn, Koka, Go), from Moscow ML's
release in `~/.local/rune-hosts/src`, and from their published sources
and documentation for the rest (utop, IPython, Scala 3, Node, Clojure,
Racket, IEx, Idris 2, linenoise, replxx, isocline, rustyline, reedline,
prompt_toolkit, GNU readline, libedit, fish, zsh). The research notes
with every citation are kept with the drafts (`research/R2*`, `R3*`).

### The REPLs

| REPL | Commands | Type, info, doc, search | Printing limits; own printers | Error excerpt | Completeness | Reload | Debugger; protocol; kernel |
|---|---|---|---|---|---|---|---|
| SML/NJ 2026.2 | none (`Control.Print`, `CM`) | none (echo only) | depth 10, length 16, string 70, width 79; `install_pp`, untyped | no: `stdIn:L.C Error:` | `;` | `CM.make` adds on top; old values print `?.t` | no; CM's slave protocol; none |
| Poly/ML 5.9 | none (`PolyML.*`) | name lists, `NameSpace` | one depth 10 that lists use up, width 77; `addPrettyPrinter` (depth, argument printers, value to `pretty`) | no: re-printed "Found near" | `;` | `PolyML.make` | `PolyML.Debug` at a `debug >` prompt; `--ideprotocol`; none |
| MLKit 4.7 | `:` (ended by `;`) | `:search` over flags only | depth 5, list 10, string 80; none | `^^^` under the entry | `;` | `:reset` restarts the evaluator | no; evaluator over named pipes; none |
| Moscow ML 2.10 | none (`help`, `Meta`) | `help "id"` pager over signatures | depth 20, length 200; `installPP` for constant constructors | the line and `^^^` | `;` | `load` of compiled units | no; no; none |
| OCaml 5 | `#` (ended by `;;`) | `#show_val`, `#show_module` | depth 100, 300 nodes in all; `#install_printer` | `N \| line` and `^^^`, or the input highlighted in place | `;;` | `#use`, `#mod_use` | separate `ocamldebug`; no; ocaml-jupyter |
| utop | `#` | `#typeof` | as OCaml | as OCaml, coloured | `;;` | as OCaml | no; Emacs mode; none |
| GHCi | `:` | `:type`, `:info`, `:browse`, `:doc` | `show`; `-interactive-print` | GHC's, with a caret | `:set +m`, `:{ :}` | `:reload` loses the prompt's bindings | `:break`, `:step`, `:trace`, `:history`; external interpreter; IHaskell |
| Julia 1.13 | modes `?`, `;`, `]` | help mode renders Markdown, "Perhaps you meant" | sized to the screen; `show` methods per MIME type | `REPL[n]:line` in traces | parser (`:incomplete`) | Revise.jl patches methods | Debugger.jl; no; IJulia |
| CPython 3.14 | bare `exit`, `help`, F1 to F3 | `help()` | `repr`; `sys.displayhook` | coloured traceback | `codeop` | `importlib.reload` | `pdb`; no; ipykernel |
| IPython | `%`, `?`, `!` | `?`, `??` (source), `%whos` | `max_seq_length` 1000; `_repr_*_` | traceback modes | parser and indent | `%autoreload` patches in place | `%debug`; ZeroMQ; ipykernel |
| jshell | `/` | `/vars`, `/methods`, documentation on Tab | truncated at 80 or 1000; none | the line and `^---^` | `CompletenessAnalyzer` | redefinition recompiles dependents | none; JDI; IJava |
| F# fsi | `#` (ended by `;;`) | `#help "id"` (XML docs) | depth 100, length 100, width 78; `AddPrinter` | the line and `---^` | `;;` | shadowing (`FSI_000N`) | `#dbgbreak`; hosting API; .NET Interactive (archived 2026) |
| Roslyn csi | `#help` only | none | 1024 characters; `DebuggerDisplay` | none, at most 5 errors | `IsCompleteSubmission` | shadowing (`Submission#N`) | Visual Studio; no; .NET Interactive |
| Scala 3 | `:` | `:type`, `:doc`, `:imports` | 1000 elements, 50,000 characters; none | the compiler's | parser | `:reset` | no; no; almond |
| Node | `.` | none | `util.inspect`: depth 2, 100 elements, width 80; `inspect.custom` | stack | parser (recoverable errors) | `.load` again | `--inspect`; `repl` module; tslab |
| Clojure, rebel-readline | none (functions) | `doc`, `source`, `apropos` | `*print-length*`, `*print-level*`; `print-method` | `pst` | reader | `tools.namespace` | CIDER; nREPL, prepl; clojupyter |
| Racket, xrepl | `,` | `,describe`, `,doc` | `pretty-print` width; `prop:custom-write` | errortrace | reader | `,reload`; "hopeless" | `,trace`; none; iracket |
| Guile | `,` | `,describe`, `,apropos` | options; `print` | backtrace, nested REPL | reader | `,reload` | `,bt`, `,break`, `,step`; `--listen`; none |
| Erlang shell | none (functions) | `h/1` from EEP-48 Markdown | `~P` depth; none | `** exception error:` | forms ended by `.` | two code versions, purge | `int`, `debugger`; remote shell; ierl |
| IEx | none (helpers) | `h`, `t`, `i`, `b` | `inspect` limit 50 to 200 by version, width 80; `Inspect` | coloured stack | parser | `recompile`, `r/1` | `IEx.pry`, `break!`; `--remsh`; Livebook |
| Idris 2 | `:` | `:t`, `:doc`, `:browse`, `:search` | none; `Show` | Idris's | one line | `:reload` | no; `--ide-mode`; none |
| Koka 3.2 | `:` | `:t`, `:k` | through `show`; none | coloured, no excerpt | one line | `:l`, `:r` | no; no; none |
| **Rune today** | none (`Compiler.*`) | none | depth 20 only; none yet | none | `;`, re-parsed per line | `use` again, through the cache | none; none; none |

What the table says:
* **The SML family is behind on everything but the language.** None of
  SML/NJ, Poly/ML, MLKit or Moscow ML has a line editor, colour, a type
  query, documentation at the prompt or search by type; only Poly/ML has
  a debugger and an IDE protocol. A REPL with those is new for SML.
* **`:` commands.** GHCi, Idris, Scala, Koka and MLKit use `:`; Racket and
  Guile chose `,` because `:` is taken in Scheme, and the others have
  reasons of their own (IPython's `%`, Node's `.`, jshell's `/`). MLKit's
  commands must end in `;`, which its users trip over; jshell and GHCi
  accept any unique prefix of a command.
* **Two limits at least.** Every printer worth copying has a depth and
  a length, most a string length and a width; Poly/ML's single depth
  that list elements use up surprises its users, OCaml's budget of nodes
  in all is the robust one. Poly/ML's `addPrettyPrinter`, which gets the
  depth and printers for the type's arguments and returns a document,
  is the strongest interface for printers of one's own.
* **Types by their shortest path.** SML/NJ prints a type by the shortest
  path that still names it in the current environment, or `?.t` when none
  does (`~/reference/smlnj/compiler/ElabData/types/pptype.sml:160-185`);
  GHCi names shadowed types `Ghci1.T`. This is what generativity needs.
* **Excerpts of the entry.** Moscow ML, MLKit, OCaml, jshell and F#
  quote the entry under the error with a caret; OCaml on a terminal
  highlights the user's own input in place. Entries get names in errors
  and traces: `REPL[3]:1` (Julia), `#3:1` (jshell), `<interactive>:3:5`
  (GHCi).
* **Completeness by the parser** is the modern rule (jshell, IPython,
  Julia, Python, Scala, Erlang): incomplete means "the parser wanted
  more", and anything else is evaluated so that the user sees the error.
  For SML the `;` remains the explicit end (D12).
* **Reload is answered four ways:** drop the prompt's bindings (GHCi),
  recompile dependents (jshell), patch in place (Revise, IPython,
  Erlang's two versions), reset and replay (DrScheme, Racket). SML's
  generativity rules out patching (*What is different for SML*).
* **Feedback modes.** jshell has normal, concise, verbose and silent
  (and a language to define more); fsi `--quiet`; Moscow ML `quietdec`.
* **Timing** reports wall time, CPU, allocation and collections (GHCi
  `:set +s`, fsi `#time`, Julia `@time`), Poly/ML compile and run apart.
* **Documentation.** Julia's help mode is the best: Markdown rendered
  in the terminal, a fuzzy "search:" line, "Perhaps you meant", and a
  summary of what has no documentation. Erlang renders EEP-48 chunks.
* **Sessions** are saved as an image (Poly/ML `SaveState`, SML/NJ
  `exportML`, Rune `Runtime.save`) or as the inputs that succeeded
  (jshell `/save -history`, IPython `%save`, Node `.save`); the second
  survives a new compiler.
* **Debuggers at the prompt** are Poly/ML's, GHCi's and Guile's: break,
  step, frames, a nested prompt in a frame's environment.
* **Editors' protocols**: Poly/ML's ESC-framed packets, GHCi's hidden
  `:type-at`, Idris's S-expressions, nREPL, Swank. Jupyter kernels exist
  for most, for SML none maintained.

### The line editors

| Editor | Language, lines | Windows | Drawing | Widths | Multi-line | Keymaps; undo; kill ring | Paste | History | Highlight hook | Basic mode |
|---|---|---|---|---|---|---|---|---|---|---|
| CPython `_pyrepl` 3.14 | Python, 6,944 | records; VT output, none before build 10586 | diff of rows | Unicode data, per code point | yes | Emacs; none; unbounded | yes | appended, rewritten at exit; Ctrl-R | built-in tokenizer | not a tty, `TERM=dumb`, `PYTHON_BASIC_REPL` |
| Julia LineEdit 1.13 | Julia, 7,780 | libuv: records to VT bytes | repaint of the region | utf8proc (Unicode 17) | yes | Emacs, modes; linear; 100 | yes | one appended write per entry; fuzzy search | parse per refresh | `TERM=dumb`, not a tty |
| haskeline 0.8 | Haskell, 6,360 | records, console API | diff | Kuhn 2007 (Unicode 5.0) | no | Emacs, Vi; linear; yes | no | rewritten at end, last writer wins | none | not a tty, dumb |
| Erlang edlin, prim_tty (OTP 29) | Erlang and C, 9,600 | records, VT input required | requests on a screen mirror | `wcwidth`, EAW 17 | yes | Emacs, user keymap; none; one | no | off by default; `disk_log` | none | not a tty |
| Chez expeditor | Scheme and C, 4,489 | records to VT, console API out | per-line redisplay | one cell per character | yes | Emacs; none; one | heuristic | locked, merged | none | not a tty, no caps |
| JLine 3.29 (jshell) | Java, 31,091 | records to xterm, console API out | screen-model diff | Kuhn 2007 | yes | Emacs, Vi, inputrc; linear; 60 | yes | escaped, appended; Ctrl-R | per redisplay (jshell's async) | `TERM=dumb`, comint |
| F# `console.fs` | F#, 646 | .NET console | rewrite from an anchor | BMP wide table | no | fixed; none; none | no | in memory | none | console probe fails |
| Go `x/term` | Go, 1,411 | VT input via the runtime | tail rewrite | runes | no | Emacs subset; none; none | yes | in memory, 100 | none | caller decides |
| linenoise (2026) | C, 2,380 | none | full repaint | heuristic ranges | soft wrap | minimal; none; none | yes | one per line | hints | dumb, `emacs` |
| replxx | C++, 9,159 | records, own SGR emulator | full repaint | Kuhn | soft wrap | Emacs; none; 10 | yes | timestamped, locked, merged | per code point | dumb, `emacs` |
| isocline | C, 11,377 | records, own emulator | full repaint | Kuhn 2007 | yes | Emacs; undo, redo; none | no | escaped | bbcode callback | dumb, `emacs` |
| rustyline 18 | Rust, 15,833 | records, console API | full repaint, synchronised | unicode-width and segmentation | yes | Emacs, Vi; grouped; 60 | yes | locked, merged, or SQLite | `highlight(line, pos)` | dumb, `emacs` |
| reedline 0.52, crossterm | Rust, 45,234 | records, `ToUnicodeEx` | repaint from a CPR anchor | unicode-width and segmentation | yes | Emacs, Vi; linear; one | yes, kitty | locked, or SQLite with sessions | `highlight → StyledText` | `TERM=dumb` |
| prompt_toolkit 3.0 | Python, 41,610 | records, VT input if settable | cell-screen diff | `wcwidth` | yes | Emacs, Vi; linear; 60 | yes | appended; Ctrl-R | lexer (Pygments) | dumb |
| GNU readline 8.3 | C, 38,457 | none native | diff (`update_line`) | `wcwidth` | newlines in buffer | Emacs, Vi, inputrc; linear; 10 | yes | rename or append, no lock | none | echo off, no `up` |
| libedit | C, 20,700 | none | diff | `wcwidth` | no | Emacs, Vi; vi only; one | no | truncating write | none | not a tty |
| fish 4 | Rust, 22,000 | none native | desired-against-actual diff | own (Unicode 17), switches | yes, indented | Emacs, Vi; linear; yes | yes, kitty | appended under `flock` | async, on a thread | dumb |

What the editors teach:
* **Raw mode** is the same everywhere it is done well (the settings of
  `cfmakeraw`, `OPOST` kept), held only while a line is edited. Most
  clear `ISIG`, so Ctrl-C and Ctrl-Z arrive as keys and the editor
  decides; those that keep it carry the suspend bugs. A restore that does
  not depend on the program ending cleanly (libuv's signal-safe reset,
  called from its exit and fatal paths) is what keeps a crash from
  leaving a raw terminal, which P1 showed Rune does today.
* **Decoding.** A real CSI grammar (consume to the final byte, then look
  the sequence up) never puts an unknown sequence into the buffer;
  fixed tries do (Julia, Chez, haskeline, pyrepl, Go). The wait after an
  Escape ranges from none (Escape is only a prefix) to half a second
  (readline); fish waits 30 ms. The kitty protocol is in fish, crossterm
  and reedline, and in Windows Terminal 1.25 and VS Code's terminal.
* **Windows.** Every editor that edits in a console reads
  `ReadConsoleInputW` records; Erlang, pyrepl and prompt_toolkit read
  them with virtual terminal input on, so the keys come as the same bytes
  as on a Unix terminal and the resize as a record. No one reads with
  `ReadFile`. Below Windows 10 1511 there is no VT output and the good
  ones refuse and fall back to a basic mode (CPython) or require it
  (Erlang). P3 measured this path on Rune's machine.
* **Drawing.** Repainting the edit region with relative moves is the
  common case and enough for a line; a diff against a model of the
  screen (JLine, pyrepl, prompt_toolkit, fish, zsh, readline) is what
  keeps a long entry cheap. Every one has to handle the pending wrap at
  the right margin; only zsh, fish and JLine handle a prompt that does
  not start in column 0 (zsh's `PROMPT_SP`).
* **Widths** are the weakest part: four of the seventeen still use
  Kuhn's tables of Unicode 5.0 and Chez counts every character as one
  cell; three move the cursor by grapheme cluster; almost none asks the
  terminal how it measures. Terminals disagree
  about a farmer emoji (2, 4, 5 or 6 cells), and VS Code's terminal is
  reported to measure by code point where Windows Terminal measures by
  cluster.
* **History** survives when entries are escaped and appended one write
  at a time, under a lock or merged (fish, rustyline, replxx, Chez, zsh,
  Julia); it is lost when the file is rewritten at exit (haskeline,
  jshell, pyrepl's race).
* **Testing** is done four ways: the pure core asserted on frames
  (pyrepl, Julia), golden bytes (haskeline, Julia, jshell), tmux end to
  end (Erlang, fish), and a small terminal emulator driven by the real
  program (linenoise). The last runs anywhere, Windows included.
* **Size.** linenoise is 2,400 lines of C, haskeline 6,400, the Chez
  expeditor 4,500, rustyline 15,800; a `lib/terminal` with the scope of
  this roadmap is about 5,000 to 6,500 lines of SML and about 450 of C.

## The experiments

Six small experiments settle what reading cannot: whether Standard ML
on Rune can drive a terminal, what Windows gives a program, what a
keystroke costs, whether a kernel can be written in Standard ML, and
what output a REPL can capture. They ran on a build of `f8e9fdc5` made
from a `git archive` of the commit (never in a worktree another session
uses), on Linux under WSL2 and on Windows 11 build 22000 through WSL
interop. Their sources, scripts, screens and logs are kept with the
drafts of this roadmap (`~/.cache/claude-rune-drafts/repl`: `proto/`,
`harness/`, `logs/`); M1 brings the harness into the tree. The machine
was loaded by another session's test chain (load average about 30 on
16 CPUs): timings are upper bounds.

### The harness

Two drivers stand in for a person at a terminal.
* `term.py` runs a program in a private tmux server at a given size,
  types keys, pastes, resizes, and waits until the screen matches a
  pattern; it captures the screen with or without its escapes. Text is
  sent as hex: tmux takes a lone `;` for its own separator.
* `ptyraw.py` runs a program on a pty of its own, writes bytes, reads
  until a pattern, and times each step to the microsecond.

A Windows program started from WSL inside a tmux pane gets a real
console: interop gives it a ConPTY bridged to the pane, of the pane's
size, in which `SetConsoleMode` takes the virtual terminal modes. From
pipes it gets pipes. So the same tmux scripts drive Windows programs end
to end. They test ConPTY, the console of Windows Terminal and VS Code,
and not a window of the legacy console host, which stays a manual check
(M13).

### P0: today's REPL

| Measured (ptyraw, `bin/rune-repl` of `f8e9fdc5`) | Time |
|---|---|
| start to the first prompt | 72 to 87 ms (5 runs) |
| `1;` to its echo and the next prompt | 8 to 16 ms |
| `val y = [1,2,3];` | 5 to 13 ms |
| a paste of 10 one-line declarations and a `;` | 52 ms |
| 100 lines | 335 to 350 ms |
| 1,000 lines | 6.7 to 7.0 s |

The paste grows faster than its length (ten times the lines, twenty
times the time), from the parse of the whole buffer after every line
(*Where we are*). A paste of 2,000 lines
first hung in the harness, which wrote without reading the echo of the
cooked terminal; the driver now reads while it writes, and M1 measures
2,000 lines again.

### P1: a terminal probe in Standard ML

`probe.sml` (249 lines, the Basis only) puts the terminal in raw mode
with `Posix.TTY`, reads bytes with `Posix.IO.readVec`, waits with
`OS.IO.poll`, and decodes keys.
* **Keys.** Under tmux every key arrives and decodes: the arrows, Home, End,
  Ctrl- and Shift-arrows (`ESC [1;5D`), Alt-letter (`ESC b`), the function
  keys in both forms (`ESC O P`, `ESC [15~`), Delete, PageUp, Backspace as
  `7F`, Tab, Enter as `0D`, Ctrl-A, Ctrl-W, Ctrl-C and Ctrl-Z as bytes (with
  `ISIG` off, Ctrl-C is `03` and no signal), UTF-8 of two, three and four
  bytes, a family emoji as five code points joined by ZWJ, and a bracketed
  paste between `ESC [200~` and `ESC [201~`.
* **Latency.** A key reaches the program's output 0.2 to 0.4 ms after
  it is written to the pty (6 ms once, under load). An Escape alone is
  reported after the timeout of the wait for a following byte: 29 to 33
  ms with 25, 50 to 52 ms with 50, 102 to 110 ms with 100. `ESC ESC x`
  typed at once decodes as Alt-Escape and `x`, the ambiguity every
  decoder has.
* **Size.** The cursor position report (`ESC 7`, `ESC [999C ESC [999B`,
  `ESC [6n`, `ESC 8`) gives the size of the window with no new
  primitive: 7.4 ms the first time, 0.7 ms after. `COLUMNS` and `LINES`
  are shell variables, not in the environment of a program.
* **Restore.** An uncaught exception in raw mode leaves the terminal
  raw (`-isig -icanon -echo` after the program ends): the VM must restore
  what a program changed when it exits, whatever way it exits (D4).
* **Typeahead.** Keys typed while the program computes in cooked mode
  are echoed by the kernel onto the screen (`abc`, `def^[[A`) and are all
  delivered afterwards, nothing lost (10 bytes). The echo is the
  problem, not the loss (D18).

### P2: a mini editor

`edit.sml` (340 lines) keeps a buffer of several lines, highlights it
with the compiler's own lexer (`src/frontend/lexer.sml` and the five
files it needs, compiled into the program), renders it to a virtual
screen wrapped by display width, and writes only the rows that changed.
Per keystroke, inserting one character in the middle line:

| Lines | Bytes | ms/key | lex | render | diff | bytes written/key |
|---|---|---|---|---|---|---|
| 10 | 379 | 0.38 | 0.17 | 0.20 | 0.01 | 89 |
| 100 | 3,979 | 3.05 | 1.14 | 1.86 | 0.04 | 203 |
| 1,000 | 41,779 | 29.6 | 12.5 | 16.8 | 0.25 | 1,324 |

Lexing and rendering the whole buffer at every key fits a frame of 16
ms up to a few hundred lines; beyond, the editor lexes from the line
that changed and renders the lines that changed (D8, D13). The first
version rewrote every row below the change and wrote 8 KB a key at 100
lines and 83 KB at 1,000.
On screen (tmux, 40 and 60 columns): CJK and emoji wrap at their
display width; an entry of several lines is accepted at a final `;` and
comes back whole from history; Tab completes a unique prefix; an
unterminated string, on which the lexer raises with no tokens, is
highlighted by lexing the text before it again and colouring the rest
as a string; a resize redraws at the new width. It found one bug worth
a rule: the colour of the last token of a row leaked into the next
output line, so every row the editor writes ends by resetting its
style.

### P3: Windows

P1's probe on `runevm.exe` of `f8e9fdc5`, in a console: the arrows,
Home, End, Ctrl-arrows, function keys, Delete, PageUp and Escape are not
read at all; Alt-x arrives as `x`; é arrives as `82` (code page 437), €
and the emoji as `?`; Backspace is `08`; the markers of a paste and the
newline inside it are lost; Ctrl-Z ends the input.

`wincon-keys.c` (132 lines of C, mingw) reads the console three ways,
all with `ENABLE_VIRTUAL_TERMINAL_INPUT` on the input, virtual terminal
processing on the output, the UTF-8 code pages, and `WaitForSingleObject`
as the wait.
* **`ReadFile`.** Every key of the list above arrives as the same bytes
  as on Linux under tmux, bracketed paste included; but é € and the emoji
  arrive as four zero bytes, the console's known fault with UTF-8 input
  (microsoft/terminal#4551, fixed in 2023 builds), and the records that
  are not characters must be consumed apart or a read blocks.
* **`ReadConsoleW`**, converted with `WideCharToMultiByte`: the same
  keys, and the UTF-8 right; a resize is seen only by asking the size.
* **`ReadConsoleInputW` records**, the UTF-16 of each key-down (times its
  repeat count) converted: the same keys, é right, but € and the emoji
  lost. They come as a key-down of Alt with no character and a key-up of
  Alt with it, the emoji as two such records (a surrogate pair): the
  path of Alt and the numeric keypad, which is how ConPTY delivers a
  character outside the keyboard's layout. Taking the character of an
  Alt key-up as well, as Erlang, JLine and libuv do, gets
  `C3 A9 E2 82 AC F0 9F 98 80`; and a resize arrives as a record of its
  own (`WINDOW_BUFFER_SIZE_EVENT`), after which the window's size is read.

Output in UTF-8 displays. The third way is D5's.

### P4: a kernel in Standard ML

* `sha.sml` (153 lines): SHA-256 and HMAC-SHA-256 pass the FIPS 180-4
  and RFC 4231 vectors (cases 1, 2 and 6) and agree with Python's on a
  MiB. They are slow: 1.4 MiB/s, 765 µs for an HMAC of 1 KiB against
  26 µs in Python's C. A Jupyter message of a few KiB costs about a
  millisecond to sign or check, which an interactive kernel can afford
  and a chatty one would notice; `Word32` arithmetic is the cost.
* `zmtp.sml` (86 lines): a ZMTP 3.0 REP socket over `INetSock`, as a
  kernel's heartbeat is, against a peer of 61 lines of Python written
  from the specification with the standard library: the greeting with
  the NULL mechanism, the READY command with its metadata, short and long
  frames. A thousand round trips: median 66 µs at 16 bytes, 100 µs at
  4,000, 539 µs at 100,000. Untested: libzmq itself (pyzmq is not
  installed, and nothing was installed for this), CURVE, PUB and ROUTER.

### P5: the program's output

`wrap.sml` (68 lines) replaces `TextIO.stdOut` with a wrapping writer
that counts calls and remembers whether the last line is complete. A
million writes of one character cost no more wrapped than not (192 ms
against 233 ms to `/dev/null`; 133 ms against 185 ms on a pty for
200,000). The top-level `print` does not go through it: it is a
primitive (*Where we are*). In the REPL, `TextIO.output (TextIO.stdOut,
"abc");` is followed by its echo on the same line, `abcval it = () :
unit`.

## Constraints

* **The compiler's sources are portable.** `src/` is built by four other
  Standard ML systems in six builds and by Rune, and all seven builds make
  the same bytecode (`AGENTS.md:246-247`). The palette in `src` uses the
  Basis only, decides colour from `isatty` and the environment, and writes
  the same text as today wherever colour is off.
* **A library may not use `_prim`** (`AGENTS.md:327-331`), and its files
  marked `host yes` build on the other systems against their own Basis.
  `lib/terminal` reaches the system through `Posix` and through a
  structure of Rune's Basis; the files that need the latter are marked
  `host no`, and those that do not (styles, keys, widths, the editor's
  core) are plain Standard ML.
* **New primitives go the documented way** (`AGENTS.md:63-75`): a
  description in `src/isa/prims.sml`, `make isa`, C in `runtime/prims.c`
  behind a call of `runtime/sys/sys.h` answered by `sys_posix.c`,
  `sys_win.c` and `sys_none.c`, a host shim in
  `tests/basis/host/rune-prim.sml`, a line in `docs/bytecode.md`. They
  change the fingerprint of the instruction set and the images.
* **What is not a terminal is untouched.** The suites compare stderr and
  stdout byte for byte (*Where we are*), HOL4 reads the REPL through a
  pipe and through Emacs, and scripts parse `rune`'s errors. With
  output to anything but a terminal, or with `TERM=dumb`, every program
  prints exactly what it prints today, prompts included; with `NO_COLOR`
  set, a terminal gets no colour (D3).
* **One program, one Basis.** The REPL and the code it runs share
  `TextIO`, the interrupt and the terminal. The REPL owns the terminal
  while it reads; the program owns it while it runs, in the mode it
  expects (cooked, echoing) if it reads from stdin.
* **No threads** in Standard ML. Every front that must answer while code
  runs (a heartbeat, an interrupt, a protocol's cancel) is a second
  process or a poll loop (`docs/plans/async-io.md` is one line); the
  runtime may run a thread of C that only sets the VM's interrupt flag,
  as its console handler does (M11).
* **Both operating systems, one library.** Linux and Windows get the
  same editor, keys, colours and tests; the system's differences stay
  in the runtime's `sys_posix.c` and `sys_win.c` and in one structure
  of the Basis. macOS and the BSDs have POSIX terminals;
  they are tested when Rune is built there.
* **The incremental worktree is live.** Another session builds
  incremental M5 to M7 in it; the REPL's files there change under this
  plan (*Prerequisites and flags*). Milestones that touch `src/repl`
  start from incremental's head at the time and say which commit.
* **C17, C99 with a switch,** no platform code outside `runtime/sys`
  (`AGENTS.md`, *Conventions*).

## The architecture

```
  rune, runedoc, rune-repl            any Rune program
         |                                   |
  src/util/color.sml  (roles -> styles; SGR, CSS, plain; when to colour)
  src/util/diagnostic.sml  (a message with spans, rendered)
         |
  src/repl: the engine  <---- fronts: terminal (lib/terminal)
         |                            protocol (--engine, JSON-RPC)
         |                            kernel (rune-kernel: Jupyter)
         |                            debug adapter (--dap: DAP)
  lib/terminal:  Style  Key  Width  Terminal  LineEdit  History
         |
  lib/basis: Posix.TTY, OS.IO, RuneTerminal (new)
         |
  runtime: sys_term_* in sys_posix.c, sys_win.c, sys_none.c
```

Five layers, each usable without the ones above it.

* **The console in the runtime** (M3). A few calls of `runtime/sys/sys.h`
  answered on POSIX and Windows: the size of a terminal; a counter of
  resizes (`SIGWINCH` on POSIX, the window's size looked at in every wait
  on Windows); entering and leaving a raw mode that the VM undoes when it
  exits, however it exits; reading what was typed with a timeout, as
  UTF-8, which on Windows is the console in virtual terminal mode read as
  UTF-16 (D5, P3). At start the VM turns on virtual terminal processing
  and UTF-8 output for a console's output handles, so that any program's
  escapes and UTF-8 display, the compiler's included. The Basis shows
  them as `RuneTerminal` (D4), next to `Posix.TTY`, which stays as it is.
* **`lib/terminal`** (M4, M5), a library like `lib/random`: styles and
  capabilities (`Style`), keys decoded from bytes (`Key`), the widths of
  code points and clusters (`Width`), the terminal itself (`Terminal`: raw
  mode, size, resize, reading keys with a timeout, writing), a line
  editor (`LineEdit`) and its history (`History`). The editor is a pure
  core (a buffer, actions on it, a rendering to a virtual screen) under
  a thin loop that reads keys and writes the difference between two
  screens (D7, D8). It knows nothing of SML: the program gives it
  callbacks to decide whether an entry is complete, to colour it, to
  complete a word and to hint. A program that wants a line gets one with
  `LineEdit.readLine`. Its files that need `RuneTerminal` are `host no`;
  the rest, the core included, build and are tested on the other
  systems, with `Posix.TTY` for the terminal.
* **The palette** (M2), `src/util/color.sml`: the roles (a prompt, a
  keyword, a type, an error, a location, ...), the style each gets in
  the default theme, a user's overrides from `RUNE_COLORS`, the rule for
  when a stream is coloured (D3), and three renderings of a style: SGR
  escapes for a terminal, CSS custom properties for HTML (runedoc's
  future pages, rune-ide's views), and nothing. It is portable Standard
  ML: the compiler, runedoc and the REPL use it; `lib/terminal` knows
  styles, not roles. Beside it `src/util/diagnostic.sml` renders a
  message with its spans: the first line exactly as today, then, when
  the stream is a terminal or the user asks, the lines of source with a
  gutter and carets in display columns (D17).
* **The REPL's engine** (M6 to M9, M10), in `src/repl`: the session as
  it is now (units, the environment, the cache, `use`), plus what the
  fronts ask of it: is this entry complete, complete this word, colour
  this text, the type and the documentation of a name, run an entry,
  print a value, reload, interrupt. Its output is not text but events
  (a value with its type, a declaration, a diagnostic, a line of the
  program's output, an interrupt), which each front renders its own way.
* **The fronts.** The terminal front (M6) runs in the REPL's process and
  draws with `lib/terminal`. `rune-repl --engine` (M10) puts the engine
  behind JSON-RPC 2.0 instead; editors, rune-ide, the kernel and the
  debug adapter are processes of their own that start it as a child and
  drain its stdout and stderr. The kernel (`rune-kernel`, M11) owns
  Jupyter's sockets and answers the heartbeat and control while the
  engine runs. The debugger (M12) is commands of the terminal front and
  requests of the protocol, with a DAP adapter over them.

Two rules hold across the layers:
* **Nothing changes for a pipe.** Every layer decides colour, editing
  and excerpts from whether its stream is a terminal (and `TERM`,
  `NO_COLOR`, the flags); when it is not, the bytes are today's.
* **One meaning per role.** The REPL's prompt, the compiler's error and
  runedoc's heading take their style from one table; a user who changes
  `error` in `RUNE_COLORS` changes it everywhere.

### The libraries

The owner's rule (2026-10-10): what is generic and reusable goes into a
library of its own under `lib`, tested well enough to be reused by other
projects. The libraries this roadmap makes:

| Library | What | Tested against | Built in | Used by |
|---|---|---|---|---|
| `lib/unicode` | UTF-8 encoding and strict decoding (overlong forms, surrogates and code points past 0x10FFFF rejected), display widths, grapheme clusters (UAX #29), from tables generated from Unicode 18 | Unicode's `GraphemeBreakTest.txt` and `emoji-test.txt`; properties of decoding and encoding | M2 | the compiler's excerpts, `lib/terminal`, the kernel's offsets |
| `lib/terminal` | styles, keys, the terminal, the line editor, history, and a terminal emulator for tests (D23) | the emulator's property; scripts through tmux on Linux and Windows | M4, M5 | the REPL; any program that reads lines |
| `lib/pretty` | Wadler and Leijen's documents with annotations, laid out at a width, within budgets of depth, length and nodes | properties (a layout fits its width; flattening keeps the text); golden layouts | M7 | the REPL's printing; `Compiler.prettyPrint` through a hook; runedoc later |
| `lib/markdown` | the Markdown runedoc writes, parsed and rendered in a terminal's styles or as plain text | CommonMark's examples for the constructs it accepts | M8 | `:doc`; any program that shows documentation |
| `lib/json`, `lib/jsonrpc` | JSON (RFC 8259); JSON-RPC 2.0 framed by lines or `Content-Length`, with requests, notifications and cancellation | JSONTestSuite's cases; properties; transcripts | M10 | the engine's protocol, the kernel, the debug adapter, rune-ide (with its codec) |
| `lib/digest` | SHA-256, HMAC (RFC 2104), comparison in constant time | FIPS 180-4's and RFC 4231's vectors | M11 | the kernel; the protocol's tokens |
| `lib/zmtp` | ZMTP 3.1 with the NULL mechanism over the Basis's sockets: greeting, commands, frames, and the socket types a kernel needs (REQ/REP, DEALER/ROUTER, PUB/XPUB) | a peer written from the specification, in the tree; libzmq where installed | M11 | the kernel; any program that speaks to ZeroMQ |
| `lib/jupyter` | Jupyter's wire protocol: the envelope, signing, the five channels, a kernel's loop with handlers | `jupyter_client` where installed; transcripts | M11 | `rune-kernel`; a kernel for any language written in Rune |
| `lib/dap` | the Debug Adapter Protocol's messages and framing | transcripts against VS Code's adapter tests | M12 | `rune-repl --dap`; other debuggers |

Each has its `MANIFEST`, `DOCUMENTED` signatures and runedoc pages, its
tests in `tests/lib/NAME` under `make test-lib`, properties written with
`lib/test/property`, the published vectors of the standard it implements,
and `make test-lib-hosts` for its files marked `host yes`. Three limits
of the rule:
* **The Basis Library cannot use a library**, since libraries are built
  on it. `Compiler.prettyPrint` reaches `lib/pretty` through a hook the
  REPL installs, as `use` does.
* **The compiler's sources are built by the hosts without Rune's
  libraries.** Where the compiler needs a library's code (the display
  width of an excerpt), `sources.txt` lists the library's portable files
  themselves, so the code is one; M2 settles how a program that has both,
  the REPL, has it once.
* **What is specific stays where it is used:** search by type (the
  compiler's types), the engine, the REPL's commands, `ReplShow`.

## Decisions

Each gives the options, what favours each, and the recommendation it
was written with. The owner decided all of them on 2026-10-10, as
recommended:

| Decision | Recommended | Chosen |
|---|---|---|
| D1. Where the palette lives | A: `src/util/color.sml`, in the compiler's sources and their lint | A |
| D2. The roles and their colours | C: a table of roles; the terminal's 16 colours and attributes, no blue, yellow or bright colour in the default theme; themes `dark`, `light`, `mono`, `none`; `RUNE_COLORS` to restyle | C |
| D3. When colour is on | A: per stream: the flag, `NO_COLOR` (attributes only), `FORCE_COLOR`, `CLICOLOR=0`, `TERM`, a terminal, a console with VT | A |
| D4. The console in the runtime and the Basis | A: a few calls of `sys.h` and a structure `RuneTerminal`; the VM restores the terminal at exit and turns on VT output for a console | A |
| D5. Reading the Windows console | A: `ReadConsoleInputW` records with VT input on, to UTF-8, with resize events; a basic mode where VT is refused | A |
| D6. Keys | A: a decoder of our own (a CSI grammar, an Escape timeout of 50 ms); bracketed paste always; the kitty protocol when the terminal says it has it | A |
| D7. The editor's architecture | A: a pure core (decode, step, lay out, diff) under a thin loop | A |
| D8. Drawing | A: frames diffed, relative moves, one write a frame, synchronised output where answered, the editor wraps itself, `PROMPT_SP` | A |
| D9. Widths | A: tables generated from Unicode 18, grapheme clusters, a policy for terminals that measure by code point | A |
| D10. Keymaps and configuration | A: Emacs bindings; Vi later; configuration in an SML init file through `LineEdit` and `Repl` | A |
| D11. History | A: whole entries, escaped, appended one write each, shared between sessions; prefix and incremental search | A |
| D12. When an entry is complete | A: a `;` outside any nesting, found by a scanner as keys are typed and confirmed by the parser | A |
| D13. Highlighting | A: the compiler's lexer with a mode that never raises and restarts at a line; names coloured from the session | A |
| D14. Completion | A: commands, files, labels and long identifiers of the session; common prefix, then a menu; ranked by use | A |
| D15. Commands | A: `:` commands without `;`, any unique prefix; a `Repl` structure for scripts | A |
| D16. Printing | A: printers that make documents, laid out at the terminal's width; depth, length, strings and a budget; types by shortest path | A |
| D17. Errors | A: one renderer: today's first line, then the code with carets in display columns; entries named; recovery on | A |
| D18. The terminal and the output, shared with the program | A: a quiet terminal while code runs, cooked when it reads; the echo through a stream; `print` through `TextIO.stdOut`; partial lines marked | A |
| D19. Reload | A: `:reload` of changed files and those after them, through the cache, naming the ghosts; `:reload!` resets and replays | A |
| D20. The engine and its fronts | B: an `ENGINE` signature, `rune-repl --engine` speaking JSON-RPC 2.0; the terminal front in-process, every other front a process with the engine as its child | B |
| D21. The Jupyter kernel | A: `rune-kernel`, a bridge in Standard ML that owns the sockets and drives an engine child; `Display` for rich output | A |
| D22. The debugger | A, staged, free when unused: traces of the raise, break on raise, pause and breakpoints in a debug interpreter loop, locals with `-g`, DAP | A |
| D23. Testing an interactive program | A: the pure core by unit and property tests over an emulator; tmux end to end on Linux and, through interop, on Windows; a manual list for the rest | A |
| D24. What "best in class" means, measurably | the criteria of D24, the gate of M13 | as recommended |
| D25. Names | as listed in D25 | as recommended |

### D1. Where the palette lives

**Decided: A** (2026-10-10), as recommended.

The brief asks for "a color.sml file under src". `src/` holds the
compiler's sources one directory deep (`src/util`, `src/elab`, ...);
`make check-docs` lints `src/*/*.sml` (`Makefile:888-892`), and the build
files of the six hosts are generated from `sources.txt`
(`scripts/gen-build-files.sh`).

* **A. `src/util/color.sml`**, a structure `Color`, listed in
  `sources.txt` and `sources-doc.txt` (runedoc) and wherever else a tool
  needs it; linted with the rest. "Under src", where the tree's own
  conventions put a utility.
* **B. `src/color.sml`**, at the top of `src`, as written. The lint's
  glob and the generator of build files learn a second place for one
  file.
* **C. In `lib/terminal`.** The compiler cannot use it: the hosts build
  `src/` against their own Basis and without Rune's libraries.

**Recommended: A.** It is the brief's file in the place the tree would
give it; the path is the owner's to change.

### D2. The roles and their colours

**Decided: C** (2026-10-10), as recommended.

What gets a style is a *role*, never a token or a message: the REPL, the
compiler and runedoc ask for `repl.prompt`, `syn.keyword`, `error`, not
for red. The roles, and their style in the default theme (`auto`), in
SGR codes (1 bold, 2 dim, 4 underline, 7 reverse, 9 struck through, 3x a
colour, "none" the terminal's own foreground):

| Group | Roles and their default style |
|---|---|
| Base | `text` none; `strong` 1; `faint` 2; `code` 1; `link` 4; `error` 1;31; `warning` 1;35; `note` 1;36; `help` 1;32; `success` 32; `selection` 7 |
| Diagnostics | `diag.location` 1; `diag.message` 1; `diag.code` the level's colour; `diag.gutter` 2; `diag.quote` none; `diag.primary` the level's colour, bold; `diag.secondary` 1;36; `diag.fixit.insert` 32, `diag.fixit.delete` 31; `diag.type.a` 1;32 and `diag.type.b` 1;35 (the two sides of a mismatch) |
| The REPL | `repl.prompt` 1;32; `repl.prompt2` 32; `repl.input` none; `repl.name` 1; `repl.value` the syntax roles; `repl.type` as `syn.type`; `repl.exception` as `error`; `repl.interrupt` as `warning`; `repl.ui` and `repl.timing` 2; `repl.hint` 2; `repl.menu` none, `repl.menu.selected` 7, `repl.menu.detail` 2; `repl.search` 1, `repl.search.match` 4; `repl.bracket` 1;4; `repl.bracket.bad` 4;31; `repl.partial-line` 2 |
| Syntax (input, excerpts, documentation, the IDE) | `syn.keyword` 1; `syn.ident`, `syn.operator`, `syn.punct`, `syn.constructor`, `syn.number` none; `syn.type`, `syn.tyvar`, `syn.module` 36; `syn.string` 32; `syn.comment` 2; `syn.error` 4;31 |
| runedoc | `doc.heading` 1 (the first 1;4); `doc.signature` the syntax roles, the documented name bold; `doc.code` as `code`; `doc.link` 4; `doc.label` (`Raises:`, `Law:`, `Example:`) 1; `doc.deprecated` 2;9; `doc.status` 2 |

A program's own output has no role: the REPL never styles the user's
bytes.

* **A. The 16 colours of the user's terminal and attributes.** They
  follow the user's theme, light or dark, and are what every compiler
  in the survey uses and what Python 3.14 chose "for maximum
  compatibility". Some of the 16 fail somewhere: on the default
  palettes of seven terminals (xterm, the legacy console, Windows
  Terminal's Campbell, Terminal.app, GNOME, iTerm2, VS Code), blue on a
  dark background reaches only 1.3 to 4.3:1 against WCAG's 4.5, yellow
  on white 1.4 to 4.2, the bright greens, yellows and cyans on white 1.1
  to 2.3, and Solarized Dark's bright black is its background (R6's
  computation). Text that is not a role keeps the terminal's own
  foreground (SGR 39), never white or black.
* **B. A fixed palette in 256 or 24-bit colours.** The same everywhere
  and chosen for contrast, but blind to the background: what reads on
  black fails on white unless the background is asked for (OSC 11),
  which not every terminal answers.
* **C. A, restricted and with themes.** The default theme `auto` uses
  no blue, no yellow and no bright colour, and so avoids the worst
  failures on either background; the colours it keeps still fall low on
  some palettes (red on the legacy console's black, 1.9:1; green and cyan
  on white, 2.0 to 2.2), which is why every role also has a weight or a
  mark, and why M2 measures the theme and moves a role that fails to an
  attribute; red, magenta, green and cyan with bold and dim carry
  it. Warnings are magenta, as in GCC, Clang, GHC and OCaml: red against
  magenta stays apart under all three simulated deficiencies of colour
  vision (Machado et al.), where red against green does not. Themes
  `dark` and `light` use the bright or the blue colours where they are
  safe; `mono` has attributes and no hues (what `NO_COLOR` gives, D3);
  `none` has nothing. `COLORFGBG` may choose `dark` or `light`; only the
  REPL may ask the terminal for its background. `RUNE_COLORS`, in
  `GCC_COLORS`'s form with Rune's role names (`light:error=1;91:diag.gutter=2`),
  picks a theme and restyles roles; its values are digits and `;`, so it
  can write no other escape. Dim and italic degrade to plain where a
  console lacks them (the legacy console).

**Recommended: C.** Colour is never the only carrier: an error says
`error:`, a primary span is `^` and a secondary one `-`, a suggestion
says `help:`. The roles reach rune-ide too: the palette writes a CSS
file of `--rune-<role>` variables and `.rune-<role>` classes for runedoc's
future HTML and the IDE, and the rules of Monaco's theme for the tokens
rune-ide's highlighter already names (`keyword`, `string`, `number`,
`comment`, `type.identifier`, `operator`), whose rules are empty today
(`rune-ide:src/renderer/app.tsx:20`).

### D3. When colour is on

**Decided: A** (2026-10-10), as recommended.

Each stream decides for itself: stderr may be a terminal while stdout
is a pipe.

* **A. In order, the first that applies:**
  1. a `--color=always|never|auto` flag of the program;
  2. `NO_COLOR` set and not empty: the `mono` theme (attributes, no
     hues) on a terminal, nothing elsewhere; no-color.org asks to turn
     colour off, not bold;
  3. `FORCE_COLOR` or `CLICOLOR_FORCE` set and not `0` or `false`: on;
  4. `CLICOLOR=0`: off;
  5. `TERM` is `dumb`, or unset on POSIX: off (a Windows console has no
     `TERM`);
  6. the stream is not a terminal: off;
  7. a Windows console that refused VT processing (D4): off.

  `RUNE_COLORS` changes the styles, not whether there are any. CI
  systems are not detected (rustc's library does not either): they set
  `FORCE_COLOR` if they want colour. Emacs's comint sets `TERM=dumb`, so
  it gets none; `TERM=dumb-emacs-ansi` gets colour and no editing.
* **B. A flag only.** Every user of `NO_COLOR` and every CI system that
  sets `FORCE_COLOR` would be ignored.

**Recommended: A.** It is Python's order with Rune's names. The test
runners (`tests/run-tests.sh`, `tests/repl/run.sh` and `drive.py`, the
units' and the documentation's) unset `FORCE_COLOR` and `CLICOLOR_FORCE`
or pass `--color=never` (M2), so that a CI that forces colour cannot
change what they compare.

### D4. The console in the runtime and the Basis

**Decided: A** (2026-10-10), as recommended.

`lib/terminal` cannot use `_prim`; what it needs beyond `Posix.TTY` must
come from the Basis. P1 and P3 say what that is: the size, the resize,
a restore that survives a crash, and on Windows a console that delivers
keys at all.

* **A. A few calls of `runtime/sys/sys.h`, answered by `sys_posix.c`,
  `sys_win.c` and `sys_none.c`, and a structure `RuneTerminal` of the
  Basis over them** (Rune-only, `host no`):
  * `term_size`: `TIOCGWINSZ`; the window (`srWindow`, not the buffer) of
    `GetConsoleScreenBufferInfo`.
  * `term_resizes`: a counter, incremented by a `SIGWINCH` handler
    installed when a program first asks (the handler also ends a wait in
    `poll`), and on Windows by a size event read from the console.
  * `term_enter` and `term_leave`: the raw mode of D7's loop (POSIX: the
    settings of `cfmakeraw` with `OPOST` kept; Windows: the console modes
    of D5 and the UTF-8 code pages), the state before it saved once, and
    a restore registered with the VM's exit, its fatal errors and the
    signals that end it (`SIGTERM`, `SIGHUP`, `SIGQUIT`), all written to
    be safe in a signal handler.
  * `term_read`: what was typed, as UTF-8 bytes, waiting at most a given
    time, ended early by a resize or the user's interrupt (POSIX: `poll`
    and `read`; Windows: D5).
  * At start the VM turns on `ENABLE_VIRTUAL_TERMINAL_PROCESSING` and
    the UTF-8 output code page for each output handle that is a console,
    and restores them at exit, so that the compiler's colours and any
    program's UTF-8 display on Windows without the program asking. Where
    the console refuses (before Windows 10 1511, or the legacy console),
    nothing changes and colour is off (D3).
  * The host shim (`tests/basis/host/rune-prim.sml`) answers with
    `Posix.TTY` and no size, so that the rest of the tree builds on the
    hosts.
* **B. No new primitives.** `Posix.TTY` for raw mode, the cursor
  position report for the size (P1: 0.7 to 7.4 ms), the size asked
  before every frame instead of a resize signal (Julia does only that),
  `OS.Process.atExit` for the restore. It works on Linux; it cannot work
  on Windows (P3), and a crash still leaves the terminal raw (P1).
* **C. An FFI**, which Rune does not have.

**Recommended: A.** About 150 lines of C for POSIX and 300 for Windows
(R2's estimate from the editors that do the same), a fingerprint change
and a new image format number. `lib/terminal` keeps a second, portable
`Terminal` over B for the hosts, so that its core is tested on them.

### D5. Reading the Windows console

**Decided: A** (2026-10-10), as recommended.

P3 read the same keys four ways on Windows 11 through ConPTY.

* **A. `ReadConsoleInputW` records with VT input on.** The console
  turns each key into the VT bytes a Unix terminal sends, as UTF-16 in
  the records: the runtime converts to UTF-8, pairs surrogates, repeats
  a record by its count, takes the character of a key-down and of an
  Alt key-up (the path of Alt and the numeric keypad, and of a character
  outside the layout: P3 lost € and the emoji until it did), skips the
  other records, and reports a size record as a resize. Erlang, CPython
  and prompt_toolkit read this way.
* **B. `ReadConsoleW`.** The keys and UTF-8 right (P3), but no resize
  but by asking the size, and no key-ups.
* **C. `ReadFile`.** UTF-8 input comes back as zero bytes on this
  build (P3; microsoft/terminal#4551, fixed only in 2023).
* **D. Records without VT input,** virtual-key codes turned into xterm
  sequences in C (libuv, Chez, JLine). For consoles that refuse VT
  input; more code, more layouts to get wrong (AltGr, dead keys).

**Recommended: A**, and where the console refuses VT (Windows before 10
1511, the legacy console), no editing: the basic mode of D24, as
CPython does. D would only be for those systems; nothing in Rune's
targets needs them.

### D6. Keys

**Decided: A** (2026-10-10), as recommended.

* **A. A decoder of our own.** A state machine over bytes: UTF-8; a
  CSI grammar that consumes to the final byte and then looks the
  sequence up, so that an unknown key is dropped, never typed (the
  editors with fixed tries leak them); SS3; the modifiers of xterm's
  parameter; bracketed paste (mode 2004, turned on while editing and off
  before code runs); an Escape alone after 50 ms of silence (30 in
  fish, 100 in isocline, 500 in readline; P1 measured the cost as the
  timeout itself), settable. The kitty keyboard protocol is asked for
  only when the terminal answers its query (`CSI ? u` and a DA1 after
  it), and popped before code runs.
* **B. terminfo.** No terminfo on Windows; every terminal Rune meets
  speaks xterm's dialect; Julia and pyrepl keep terminfo only for
  colours.

**Recommended: A.**

### D7. The editor's architecture

**Decided: A** (2026-10-10), as recommended.

* **A. A pure core under a thin loop.** `Key.decode` turns bytes into
  events; `LineEdit.step` takes a state and an event to a state and
  effects (accept, cancel, ask for completions); `layout` turns a state
  into a frame (rows of cells with their styles, the cursor), wrapping
  by display width itself; `diff` turns two frames into bytes. The loop
  reads, steps, draws. Everything but the loop is a function: tested
  without a terminal, on every host, by properties (D23).
* **B. A port of linenoise's imperative editor.** Small, and the
  rendering mixed with the editing: the kind of code where the wrap and
  width bugs of every editor in the survey live.
* **C. GNU readline or libedit through C.** No FFI, readline is GPL,
  neither works on Windows, and PEP 762 left readline for the reasons
  this roadmap has.

**Recommended: A.**

### D8. Drawing

**Decided: A** (2026-10-10), as recommended.

* **A. Frames diffed.** The previous frame is kept; a new one is
  compared row by row and only changed rows are rewritten, with
  relative cursor moves (no absolute position, which a scrolling
  terminal invalidates), in one write, inside synchronised output
  (mode 2026) where the terminal answers that it has it. The editor
  wraps its own rows, so the terminal's pending wrap at the margin never
  decides where the cursor is. Every row ends with its style reset (P2's
  bug). Before a prompt, if the program left its last line unfinished,
  the editor marks it and starts a new line (zsh's `PROMPT_SP`, D18).
  Long entries are laid out from the first changed line.
* **B. Repaint the edit region at every key.** What most editors do;
  P2 measured 8 to 83 KB written a key at 100 and 1,000 lines before its
  diff, and its layout of the whole buffer would pass 16 ms near 500 lines
  (between its measures at 100 and 1,000).

**Recommended: A.**

### D9. Widths

**Decided: A** (2026-10-10), as recommended.

* **A. Tables generated from Unicode 18** (East Asian Width, emoji
  presentation, the zero-width and combining classes, the grapheme break
  properties) by a script in the tree into SML, checked in with their
  version, in `lib/unicode` (*The libraries*); the cursor moves by
  grapheme cluster (UAX #29's extended
  clusters); a cluster is as wide as its widest code point, an emoji
  presentation sequence two; a policy switch for terminals known to
  measure by code point (VS Code's terminal on Windows, by
  `TERM_PROGRAM`), as rustyline and fish have.
* **B. Kuhn's `wcwidth` of 2007.** What four of the editors still use:
  Unicode 5.0, no emoji.
* **C. Ask the terminal** (write a cluster, read the cursor back).
  Exact, but a round trip per new cluster.

**Recommended: A**, with C used once at start for the one cluster that
decides the policy, when the terminal answers within 50 ms.

### D10. Keymaps and configuration

**Decided: A** (2026-10-10), as recommended.

* **A. Emacs bindings by default** (readline's: Ctrl-A, Ctrl-E, Alt-B,
  Alt-F, Ctrl-K, Ctrl-Y, Alt-Y, Ctrl-W, Ctrl-U, Ctrl-T, Ctrl-L, Ctrl-R,
  Ctrl-_ for undo, and the arrows, Home, End, Delete, Page Up and Down);
  Vi's modes later (M13). The user configures the REPL in an SML file
  (`~/.config/rune/init.sml`, or `%APPDATA%\rune\init.sml`, D25) run at
  start, through `LineEdit` (bindings, the Escape timeout, the width
  policy) and `Repl` (D15); a program that uses `lib/terminal` configures
  it through the same `LineEdit` calls.
* **B. An `inputrc` subset**, readline's file. Familiar, and a second
  language to parse for what an SML file says better.

**Recommended: A.** An init file that is SML is what OCaml (`.ocamlinit`),
GHCi (`.ghci`) and Julia (`startup.jl`) have; it is trusted like any
code the user runs, and `--no-init` skips it.

### D11. History

**Decided: A** (2026-10-10), as recommended.

* **A. Whole entries, appended.** One history entry is one accepted
  entry, however many lines; newlines and backslashes escaped; each
  entry appended with one write (`O_APPEND` on POSIX, `FILE_APPEND_DATA`
  on Windows), so that two sessions interleave entries but never lines;
  consecutive duplicates dropped; the file kept under a size by a
  rewrite to a temporary file and a rename; another session's entries
  read at each prompt from where the file was last read (Julia's way).
  Up with text typed searches by prefix; Ctrl-R searches incrementally
  for a substring; a menu with fuzzy search later. The file is
  `$XDG_STATE_HOME/rune/history` (default `~/.local/state/rune/history`)
  or `%LOCALAPPDATA%\rune\history`. `:save FILE` writes the session's
  entries that succeeded as a script (D15).
* **B. Read at start, written at exit.** Loses the history of every
  session but the last to exit, and all of it after a crash
  (haskeline, jshell).

**Recommended: A.** Greenberg and Witten's studies are why search and
suggestion stand beside stepping back through recent entries.

### D12. When an entry is complete

**Decided: A** (2026-10-10), as recommended.

* **A. A `;` outside any nesting.** As now, an entry ends at a `;` that
  is outside brackets, `let`/`local`/`struct`/`sig`/`abstype` ... `end`,
  strings and comments; a scanner (the one `Compiler.compile` has,
  `src/repl/repl.sml:160-205`, made incremental) follows the nesting as
  keys are typed, and the parser confirms when Enter is pressed. Enter
  in an unfinished entry inserts a newline and indents to the nesting;
  Alt-Enter always inserts a newline; Enter after the final `;` submits.
  An unterminated string at Enter is reported at once instead of
  waiting for ever (today's bug). A paste is taken whole and submitted
  if it ends complete. Without a terminal, the same scanner decides,
  so the cost is linear in the input (P0: superlinear today).
* **B. Complete when the parser says so, `;` or not**, as Julia, Python
  and jshell do. For SML it is ambiguous where it matters: `fun f 0 = 1`
  parses, and its next clause `| f n = n` is a second line the user had
  not typed yet.
* **C. A with B as an option** (`:set enter parse`).

**Recommended: A.** It is what every SML system and HOL4's Emacs mode
expect; C is listed under *Ready for, not built*.

### D13. Highlighting

**Decided: A** (2026-10-10), as recommended.

* **A. The compiler's lexer, with a mode that never raises.** A new
  entry of `src/frontend/lexer.sml` returns the tokens with the comments
  between them, turns an error into a token of its own (an unterminated
  string or comment runs to the end; an unexpected character is one
  bad token), and gives the state at the end of each line (inside a
  comment of some depth, inside a string), so that a change re-lexes
  from its line. Names are coloured by what they are in the session
  (a constructor, a structure, a value; unbound in its own role),
  looked up once a frame. The REPL's highlighter is one function from
  text to styled spans, and the same lexer colours the excerpts of
  diagnostics and, later, runedoc's code.
* **B. A lexer for colours only**, regular expressions in the manner of
  Pygments' SML lexer (`~/reference/mlton/ide`). Two lexers to keep in
  step; a string escape or a nested comment read differently by each.

**Recommended: A.** P2 lexed 1,000 lines in 12.5 ms with the lexer as
it is, re-lexing the text before an error by hand; the incremental mode
makes it a line's cost.

### D14. Completion

**Decided: A** (2026-10-10), as recommended.

* **A. What the cursor is in decides the source.** After a `:`, the
  commands and then each command's arguments; inside a string after
  `use` or `:use`, file names; after `#`, the labels of the record types
  in scope; elsewhere the long identifiers of the session's environment
  (values, constructors, structures, then their members after a dot;
  types where a type is expected; signatures after `:` and `:>`),
  enumerated from `ReplSession.env`, `Elaborate.sigs` and
  `Elaborate.funs` without recording uses. Tab completes the longest
  common prefix; a second Tab shows a menu of columns under the entry,
  each candidate with its type in the `hint` role; the menu is ranked by
  exact prefix, then by use in this session (Bruch et al.), then
  alphabetically. A hint (fish's suggestion from history, dimmed after
  the cursor) is an option, off by default.
* **B. Names of the Basis only**, a fixed list. What P2 did; useless for
  the user's own declarations.

**Recommended: A.** Completion by type (Gvero et al.) is under *Ready
for, not built*.

### D15. Commands

**Decided: A** (2026-10-10), as recommended.

* **A. `:` commands.** A `:` and a letter begin no SML (*What is different
  for SML*); a command is `:` and a name of letters, needs no `;` and takes
  the rest of the line; any unique prefix names it (`:t` for `:type`), as in
  GHCi and jshell.

  | Command | Does |
  |---|---|
  | `:help [command]` | the commands, or one |
  | `:quit` | ends the session (as Ctrl-D on an empty entry) |
  | `:type exp` | the type of an expression, not evaluated |
  | `:info name` | what a name is: a value and its type, a constructor and its datatype, a type and its definition, a structure and its signature, a signature, a functor, a fixity, and the file and line it comes from |
  | `:browse struct` | a structure's signature, printed |
  | `:doc name` | runedoc's documentation of a name, rendered |
  | `:search text` | names that contain the text, or values whose type matches it (Rittri) |
  | `:use file`, `:reload[!]` | `use`; D19 |
  | `:edit [name or file]` | `$EDITOR` at the definition, then `:reload` |
  | `:cd dir`, `:pwd`, `:sh command` | the directory; a shell command |
  | `:set option value`, `:show` | depth, length, width, feedback mode, colour, editing options |
  | `:time [on or off]` | wall time, CPU, allocation and collections after each entry, compiling apart from running |
  | `:history`, `:save file`, `:save-image file` | the entries; the entries that succeeded as a script; the session as an image (`Runtime.save`) |
  | `:break`, `:step`, `:bt`, ... | the debugger (D22) |

  A structure `Repl` in the session gives the same as functions
  (`Repl.typeOf`, `Repl.info`, `Repl.set`, ...) for init files, scripts
  and HOL4; `Compiler` stays as it is.
* **B. `#` directives,** as OCaml and F#. `#1 x` is SML; a line starting
  with `#` is not free.
* **C. Functions only,** as SML/NJ and Poly/ML. No syntax to learn, and
  no `:type` of an expression that is not evaluated.

**Recommended: A.**

### D16. Printing

**Decided: A** (2026-10-10), as recommended.

* **A. Documents, laid out.** The printers made for each declaration
  (incremental D10 A) build a document of the `Compiler.pretty` datatype
  in Poly/ML's shape, which the incremental worktree is building for
  HOL4, instead of a string; a Wadler printer lays it out at the
  terminal's width (80 when it is not a terminal), with the roles as
  annotations, so that a value is styled by what its parts are. Limits:
  a depth (20, as now), a length of every list, array and vector (100),
  a length of strings (1,000 characters), a budget of nodes in all, each
  cut shown as `...`. A type is printed by the shortest path that names
  it in the session, `?.t` when none does (SML/NJ's rule; generativity
  needs it). An exception is printed with its argument (incremental
  D10's condition 4). A real prints so that it reads back as a real
  (`5.0`). Printers of one's own are `addPrettyPrinter`'s (depth,
  printers of the type's arguments, value, to a document), as HOL4
  uses. Feedback modes, `:set feedback normal|concise|verbose|silent`:
  concise prints values and not declarations of types, verbose adds the
  signature of a structure, silent nothing.
* **B. Strings, as now,** with a length added. Cheaper, and a value
  wider than the screen stays one line.

**Recommended: A.** It reuses the API HOL4 already calls, and it is the
same document the kernel renders as HTML (D21) and the debugger prints
locals with (D22).

### D17. Errors

**Decided: A** (2026-10-10), as recommended.

* **A. One renderer, `src/util/diagnostic.sml`.** A diagnostic is a
  level, a message, a primary span, secondary spans with labels, notes
  and helps. Its first line is exactly today's `file:line:col: error:
  msg`, so every test and every script that reads it keeps working.
  After it, on a terminal or with `--diagnostics=full`, the excerpt in
  GCC's and Erlang's manner: a gutter of line numbers (at least four
  wide) and ` | `, the line as written, `^` under the primary span and
  `-` under the others with their labels after them, placed by display
  width (a wide character counts two; a tab is copied into the marker
  line, so they align whatever the tab width); control and bidirectional
  characters shown as escapes (rustc's defence against Trojan Source); a
  span of many lines shown by its first two and last, with `...`; a long
  line shown in a window around the span. A note without a place is
  `= note: ...` under the excerpt, one with a place its own
  `file:line:col: note:` line. The columns of the first line stay bytes,
  which the tests read. When the text of the source is gone (the REPL
  keeps only the lines of a file `use`d, `src/util/source.sml:73-81`),
  there is no excerpt: never a guessed line. `--diagnostics=short` keeps
  the first line only, the default when the stream is not a terminal;
  `--diagnostics-json FILE` writes them in rune-ide's schema
  (`rune-ide:src/compiler/diagnostics.sml`), extended with the code, the related
  spans, the notes and the rendered text.
  The compiler, runedoc and the REPL print through it. In the REPL an
  entry is a source named after its unit (`stdIn#3`), the excerpt is the
  user's own input as typed, and elaboration recovers per declaration
  (`Elaborate.recover`, off in the REPL today) so that an entry reports
  every independent error. An uncaught exception prints its argument
  and the trace from where it was raised (the frames recorded as it
  unwinds: D22's first stage, which incremental M4 planned as
  `Exception.location` and M8 builds here).
* **B. Colour the line we have,** nothing more. The excerpt is what
  readers of every modern compiler expect (Elm, Rust, GCC, OCaml, jshell,
  F#; *What the implementations do*).

**Recommended: A.** It needs a diagnostic to be a record (level, code,
message, primary span, labelled spans, notes) rather than a span and a
string: M2 maps `Error.CompileError`'s pair, left as it is, to the
simplest such record, and
`errror-messages.md` keeps the rest (an error datatype through the
compiler, several errors per pass in the lexer and parser, and better
messages). Slicing type
errors (Skalpel) and `:why` (bidirectional type slicing) are under
*Ready for, not built*.

### D18. The terminal and the output, shared with the program

**Decided: A** (2026-10-10), as recommended.

The REPL and the program it runs share a terminal and a Basis.

* **A.**
  * **While code runs**, the terminal is quiet: no echo, no line
    editing, `ISIG` on so that Ctrl-C is the user's interrupt as now.
    Keys typed ahead stay unechoed in the kernel's queue and are the
    editor's when the prompt returns (P1 showed they are all kept, and
    echoed onto the screen when the mode is cooked). When the program
    reads `TextIO.stdIn`, the REPL's wrapper of its reader turns echo
    and line editing on for the read and off after it, so a program
    that asks a question works as at a shell.
  * **The REPL's own output** (echoes, declarations, errors, command
    output) goes through a stream of its own with roles, by a hook
    `RuneCompiler.echoHook` whose default is today's plain `print`, not
    through the `print` primitive; the program's output is never styled.
  * **Marks for the terminal.** On a terminal known to accept them
    (Windows Terminal, VS Code, kitty, by `WT_SESSION`, `TERM_PROGRAM` or
    `TERM`; never under `TERM=dumb`, `INSIDE_EMACS` or a pipe), the
    prompt, the input and the output are marked with OSC 133, so that
    the terminal can jump between entries, select one entry's output and
    mark failed ones (compile errors, uncaught exceptions, interrupts).
  * **`print` goes through `TextIO.stdOut`**, as the Basis defines it
    (`print s` is `TextIO.output (stdOut, s)` and a flush): the primitive
    behind `pervasive.sml` is pointed at `TextIO.print` once `TextIO`
    exists, so that one replacement of `stdOut` captures everything the
    program writes (P5); and the primitive writes through the VM's slot
    for descriptor 1 rather than C's `stdout` directly, so that a VM mode
    can frame the program's output for a client with one pipe (D20).
  * **A partial line** left by the program is marked before the next
    prompt (a dim `⏎` and a newline, zsh's `PROMPT_SP`), known from the
    wrapped writer (P5: no measurable cost) rather than by asking the
    cursor's position.
  * **Ctrl-C** in the editor discards the entry (a second on an empty
    entry does nothing; Ctrl-D quits); while code runs it is
    `SML90.Interrupt`, as now.
* **B. As now.** Typed-ahead keys garble the screen, the echo is glued to
  an unfinished line (P5), and nothing can be captured.

**Recommended: A.** The change to `print` is a fix of the Basis and
goes through `docs/language.md` and `tests/basis` like any.

### D19. Reload

**Decided: A** (2026-10-10), as recommended.

Generativity rules out patching a value in place (*What is different for
SML*); DrScheme's ghosts are SML's too.

* **A. `:reload` and `:reload!`.** The session remembers the files it
  `use`d, in order, with their texts' digests. `:reload` re-uses each
  file that changed and every file used after the first that changed
  (their declarations may depend on it), through the cache, so that
  unchanged declarations relink instead of compiling (incremental M6).
  Before it runs it says which of the session's bindings it will shadow,
  and after it which bindings made at the prompt still hold values of the
  old types: the ghosts, by name. `:reload!` resets the session to its
  start (or to a `:mark`) with `UnitBasis.undo` and replays the files:
  DrScheme's Run. `:set watch on` checks the files' times at each
  prompt and reloads by itself.
* **B. Patch in place.** Impossible for a datatype; for a function it is
  incremental M12's hot reload, with its own decision there.
* **C. Restart and replay.** Clean, and as slow as starting over.

**Recommended: A.** Once incremental M8's dependency graph exists, "the
files after the first that changed" becomes "the files that depend on
it".

### D20. The engine and its fronts

**Decided: B** (2026-10-10), as recommended.

rune-ide's M6 waits for "REPL/evaluation"; incremental M12 plans "the
compiler as a service" on stdio (diagnostics with spans, the type at a
position, the definition of a name); a kernel and a debug adapter need
the same session from outside.

* **A. In-process only.** Every front is code in the REPL's program
  calling the session; editors drive the terminal REPL through a pty,
  as Emacs comint does. No protocol to design, and nothing structured
  for an editor: it scrapes text.
* **B. One engine, a protocol over it, fronts in their own processes.**
  * *The engine* is a signature, `ENGINE`, before it is a protocol:
    requests `initialize`, `eval` (an id, and optionally the file and line
    the text comes from), `use`, `isComplete` (D12's answer: complete,
    incomplete with an indent, invalid), `complete`, `inspect` (type,
    information, documentation of a name), `check` (diagnostics of a text
    not run), `reload`, `interrupt`, `cancel`, `value/children` and
    `value/release`, `debug/*`, `shutdown`; notifications from the engine
    `output` (the program's stdout and stderr), `display` (D21), `status`,
    `debug/stopped`; and one request from the engine, `input`, when the
    program reads `TextIO.stdIn`. The echo is data: `eval` answers with
    the declared bindings (name, type, the printed document, a handle to
    the value when asked), the diagnostics with their spans, and an
    exception with its trace.
  * *Handles* to values are numbers into a table the collector treats as
    roots, paged when large, freed by `value/release`, and those made
    while stopped in the debugger die on `continue` (DAP's rule): rune-ide
    M6's question of handles across a collection and a resume.
  * *The terminal front* calls the signature in the REPL's process.
    `rune-repl --engine` runs the same program with a protocol loop in
    place of the terminal (Poly/ML's `--ideprotocol`): JSON-RPC 2.0,
    framed one message per line, as rune-ide's service already speaks
    (`rune-ide:docs/ide-protocol.md:1-26`), or by `Content-Length`
    headers, as Emacs's `jsonrpc.el`, VS Code and Neovim speak, told
    apart by the first byte.
  * *Every other front* (rune-ide, Emacs, the kernel, the debug adapter)
    is a process of its own that starts the engine as a child, owns its
    sockets, and polls; a crash of the user's code takes the engine, not
    the front, which starts another from `rune-repl.img`.
  * *Channels.* The protocol has a channel of its own (a socket the
    engine connects out to, as Poly/ML's second protocol, PIDE and
    Julia's VS Code server do; or inherited descriptors), and the
    program's stdout and stderr stay on pipes the front drains: the
    engine flushes them before every protocol message and the front
    drains them before it reads one, so output and results keep their
    order. A VM mode that frames writes to the standard descriptors as
    `output` notifications serves a client with one pipe (Emacs's
    `make-process`) later.
  * *Transport and trust.* By default a child process, the protocol on
    descriptors it inherits other than stdin and stdout; else a
    Unix socket in a per-user directory of mode 0700 (on Windows 10 1803
    and later, in a directory only the user can read); TCP on
    `127.0.0.1` only with a token of 128 bits or more as the first bytes,
    compared in constant time, minted by the front (Rune has no secure
    random source on Windows), and with nothing but `Content-Length` and
    `Content-Type` headers accepted, since `Content-Length` framing on TCP
    is HTTP-shaped (*Risks*).
* **C. Two processes always**, a compiler and an evaluator, as MLKit and
  GHC's external interpreter. Isolation from a crash of the user's code,
  at the price of a process boundary in every interaction; Rune's
  compiler and the program share one VM by design (incremental D9 A).

**Recommended: B.** A protocol document in the tree
(`docs/repl-protocol.md`) is written with rune-ide's owner and with
incremental M12, whose analysis requests are this engine's, so editors
get one service for analysis and evaluation.

### D21. The Jupyter kernel

**Decided: A** (2026-10-10), as recommended.

Notebook and JupyterLab decide that a kernel died by whether its process
lives, not by its heartbeat; R's kernel, which has no threads, answers
the heartbeat between cells in its one loop. What a busy kernel cannot
serve is the control channel: interrupts sent as messages, and
JupyterLab's debugger, whose DAP requests come on it while a cell runs
(JEP 47). An interrupt is otherwise a `SIGINT` to the kernel's process
group on POSIX, and on Windows a Win32 event passed in
`JPY_INTERRUPT_EVENT`.

* **A. `rune-kernel`, a bridge in Standard ML.** A process that owns the
  five sockets (ZMTP 3.1 over the Basis's sockets; P4 wrote 3.0's NULL
  handshake and frames, a REP in 86 lines, 66 µs a round trip), signs and
  checks messages with HMAC-SHA256 in SML (P4: right, about 1 ms a message)
  and keeps the set that rejects a replay, answers the heartbeat and control
  at once, and drives an engine child through D20's protocol.
  `execute_request` is `eval`; `is_complete`, `complete` and `inspect` are
  the engine's; `stdin` requests answer `input`; `stream` messages carry the
  child's drained stdout and stderr; an interrupt, by signal or by message,
  becomes the child's interrupt; `debug_request` is the debug adapter's
  (D22). Rich output: a structure `Display` in the session registers, for a
  type, functions from a value to a MIME type's text, keyed when the program
  is compiled by the type's stamp as `addPrettyPrinter` is (incremental
  D10); `text/plain` always comes from D16's printer, `text/html` from the
  same document with the palette's CSS; `display`, `update` by display id
  and `clear` for explicit outputs. `rune-kernel --install` writes the
  kernelspec (language `sml`).
* **B. One process, the engine speaking ZeroMQ itself,** as R's kernel
  does. Simpler; no interrupt by message, no debugger while a cell runs,
  and a crash of the user's code takes the kernel.
* **C. A bridge in Python** over the same protocol (ipykernel's base
  class, a few hundred lines). The quickest to a working notebook; a
  dependency on Python and pyzmq Rune does not otherwise have. The SML
  kernels found are of a cruder kind still: pexpect around SML/NJ, a
  missing `;` hanging the evaluation.

**Recommended: A**, with C as a way to try notebooks early if the owner
wants one before M11. P4 tested ZMTP against a peer written from the
specification, not against libzmq: M11 begins by running a real
`jupyter_client` against the bridge (*Prerequisites and flags*).

### D22. The debugger

**Decided: A** (2026-10-10), as recommended.

What exists: a line table with inlined frames, a name for every
function, no names for locals (`docs/bytecode.md:24-29,86-138`); the
VM's interrupt poll at every call and backward jump in the interpreter
and in compiled code (Self's interrupt points); deoptimisation that
leaves compiled code at any instruction boundary with the frame exact
(jit M11); a second copy of the interpreter's loop chosen per run, which
`--trace` uses (`runtime/register/interp.c:130-148,186-208`); an exact
count of instructions; `Runtime.trace`. What is missing: names and types
of locals, a hook and a table of breakpoints, the trace of a raise once
the REPL's handler has caught it.

* **A. Staged, each stage costing nothing when no one debugs.**
  1. *Post-mortem.* The frames are recorded as an exception unwinds
     (OCaml's way), returned with it to the REPL and with `eval`'s
     answer; `:bt` shows them again.
  2. *Break on raise.* `:break raise [Exn]`: at `RAISE`, before
     unwinding, the VM calls an SML hook that runs the engine's loop
     nested on the stopped frames (Poly/ML's `enterDebugger`): a prompt
     in the frame, D16's printer, `:continue`. "Uncaught" is judged
     against the REPL's boundary; a first pass over each `handle`'s
     patterns, as .NET's, refines it later.
  3. *Pause, breakpoints, stepping.* Pause is a second value of the
     interrupt flag, so it reaches compiled code at its polls, which then
     leaves through deoptimisation. While breakpoints are set the driver
     runs a debug copy of the interpreter's loop, as it runs `--trace`'s,
     that checks a table of lines at each new line; later, `BREAK`
     written over an instruction and the JIT's code for that function
     invalidated (HotSpot, ocamldebug). `:break file:line`, `:step`,
     `:next`, `:finish` (Poly/ML's rule of depths; a tail call leaves no
     frame), `:continue`, `:frame`.
  4. *Locals and evaluation in a frame.* A unit compiled with `-g` carries,
     per function, the name, register, range of code and type of each
     variable; their printers are made from the types by the compiler the
     REPL holds (incremental D10 A). What incremental D10 left to a run-time
     model of representations, the table gives at compile time: beside the
     type, the representation the register holds there (the register
     bytecode's representations, `docs/bytecode.md:54-75`), and the printer
     is made for it. `:locals`, and an expression evaluated in a frame by
     compiling `fn (locals) => e`.
  5. *DAP.* `rune-repl --dap`, an adapter in SML with one poll loop over
     the engine; the debug console is the REPL (`evaluate` without a
     frame is `eval`); Jupyter's debugger through the kernel.
* **B. Instrumentation** (Tolmach and Appel: calls to the debugger
  compiled into the code at each event, with time travel by
  checkpoints). Independent of the VM; about three times slower and five
  times larger code in every debugged unit, breakpoints or not.
* **C. Patched opcodes from the start** (ocamldebug, HotSpot): the
  fastest debugged code, the most VM work first.

**Recommended: A**, stage 1 in M8, stages 2 to 5 in M12. Travel back in
time, by checkpoints from images and the count of instructions as the
clock, is under *Ready for, not built*.

### D23. Testing an interactive program

**Decided: A** (2026-10-10), as recommended.

* **A. Four layers.**
  * The pure core (`Key.decode`, `LineEdit.step`, `layout`, `diff`):
    unit tests on events and frames, in `tests/lib/terminal`, run on
    every host.
  * A terminal emulator in SML (about 400 lines: cursor moves, erase,
    wrap, wide cells, styles recorded) and a property, with
    `lib/test/property`: for any edits and any width, what `diff` writes,
    replayed by the emulator onto the previous screen, is the new frame.
    linenoise tests itself this way; it catches the wrap and width bugs,
    and runs on Windows without a console.
  * End to end through tmux: P1's harness (`term.py`) moved into
    `tests/terminal`, scripts of keys and expected screens, in `make
    check` when `tmux` is installed (`make doctor` says so); the same
    scripts against `runevm.exe` through WSL interop in `make
    test-windows` (*The experiments*: interop gives the program a ConPTY
    console of the pane's size).
  * By hand, from a list in `tests/terminal/MANUAL.md`: the legacy console
    window, Windows Terminal, VS Code's terminal on Windows and Linux,
    a screen reader with the basic mode.
* **B. Transcripts only,** as `tests/repl` is now. They stay, for the
  basic mode, but see nothing a terminal shows.

**Recommended: A.**

### D24. What "best in class" means, measurably

**Decided** (2026-10-10), as recommended.

The brief's aim needs a test. Recommended, as the gate of M13:
* **Features.** Every feature of the matrix (a column of *What the
  implementations do*) that at least two of the leading REPLs share (GHCi,
  Julia, IPython, CPython, jshell, utop, Scala, F#, Erlang, IEx) is in
  Rune's REPL, or is listed with its reason in *Ready for, not built*.
  Search by type, documentation at the prompt and reload that names its
  ghosts are beyond them.
* **Speed** (measured by M1's harness, on a quiet machine):
  keystroke to screen within 16 ms for an entry of 1,000 lines (P2:
  29.6 ms for the naive editor); start to the first prompt within 100
  ms (P0: 72 to 87); the completion menu over the Basis within 50 ms;
  a paste of 2,000 lines in time linear in its length (P0: superlinear).
* **Robustness.** The terminal restored after every way a program can
  end (normal exit, uncaught exception, `vm_fatal`, `SIGTERM`, `SIGHUP`;
  P1); not one byte changed in the output of any program to a pipe; the
  same end-to-end tests pass on Linux and Windows.
* **Access.** The default theme is measured on the default palettes of
  seven terminals (M2): text keeps the terminal's own foreground; a
  coloured role below 3:1 on any of them (WCAG's figure for what is not
  body text) takes an attribute or another colour there; colour is never
  the only cue; **a basic
  mode** (a prompt and `TextIO.inputLine`, no cursor movement, no
  redraw) is used when stdin or stdout is not a terminal, when `TERM` is
  `dumb`, `unknown`, `cons25` or `emacs`, when `INSIDE_EMACS` names
  comint, when the console refuses VT, and when `RUNE_BASIC_REPL` is
  set; it serves screen readers and Emacs, and its transcript is today's
  byte for byte.

### D25. Names

**Decided** (2026-10-10), as recommended.

| What | Name |
|---|---|
| the palette | `src/util/color.sml`, structure `Color` |
| the diagnostics' renderer | `src/util/diagnostic.sml`, structure `Diagnostic` |
| the console in the Basis | structure `RuneTerminal` (`lib/basis/runeterminal.sml`), signature `RUNE_TERMINAL` |
| the libraries | `lib/terminal`: `Style`, `Key`, `Terminal`, `LineEdit`, `History`, `Emulator`; `lib/unicode`, `lib/pretty`, `lib/markdown`, `lib/json`, `lib/jsonrpc`, `lib/digest`, `lib/zmtp`, `lib/jupyter`, `lib/dap` (*The libraries*) |
| the REPL's structures for scripts and output | `Repl`, `Display` |
| the engine's signature | `ENGINE` (`src/repl/engine.sml`) |
| generated from the palette | `palette.css`, `palette.json` (rune-ide's Monaco theme) |
| environment | `RUNE_COLORS`, `RUNE_BASIC_REPL`, `NO_COLOR`, `FORCE_COLOR`, `CLICOLOR_FORCE` |
| files | `~/.config/rune/init.sml` (`%APPDATA%\rune\init.sml`); `~/.local/state/rune/history` (`%LOCALAPPDATA%\rune\history`), both after the XDG variables |
| flags | `rune --color=WHEN --diagnostics=short\|full --diagnostics-json FILE`; `rune-repl -q -e EXP --no-init --color=WHEN --engine --dap --basic`; `rune-kernel --install` |
| programs | `rune-repl` (as now, and `rune -i`), `rune-kernel` |

**Recommended:** as listed; `Terminal` rather than `Term`, since the
Basis has `Posix.TTY` and no structure `Terminal`.

## The milestones

Every milestone is one commit or a few, each with `make check` green, as
the repository's rules require; one that touches the runtime also passes
the sanitiser build, `make test-windows` and `make test-portability`, and
one that changes `lib/terminal` passes `make test-lib-hosts`. Every
milestone that changes a number measures itself against M1's baselines
(*Measuring*). Sizes are lines of code, estimated: M1 to M6, the part the
owner may stop after, about 8,000 lines (1,500 of them generated tables)
and 450 of C; M7 to M13 about 10,000 and 500 of C.

### M0. This roadmap

* **What:** this file, written from the reading, the experiments and
  the research of *What it rests on*. The drafts are kept under
  `~/.cache/claude-rune-drafts/repl`: the prototypes, the harness, the
  logs of every number quoted, and the research notes with their
  citations. It is committed on branch `repl` from `f8e9fdc5`, and not
  pushed.
* **Done when:** the owner has read it and decided D1 to D25.

### M1. The terminal harness and the baselines (S, about 600 Python, shell and SML)

* **What:**
  * `tests/terminal/`: the drafts' `term.py` (tmux, screens) and
    `ptyraw.py` (a pty, bytes, times), with a runner and a first set of
    scripts that drive today's REPL; `make test-terminal`, which skips
    with a message when `tmux` is missing, and `make doctor --scope
    terminal`, which says so. The same scripts against `runevm.exe`
    through WSL interop in `make test-windows`.
  * `scripts/perf-repl.sh`: start to the first prompt, `1;`, pastes of
    10 to 2,000 lines, and (from M5) the cost of a keystroke at 10, 100
    and 1,000 lines, run on a quiet machine (load under 2) and tabled in
    this file.
  * Today's REPL recorded as screens, the net the basic mode (D24) must
    keep.
* **Why now:** every later milestone is tested and measured by it; P0's
  numbers were taken under a load of 30.
* **Done when:** the scripts pass on Linux and on Windows through
  interop, and the baselines are in *Measuring*.
* **As built** (2026-10-10): `tests/terminal/` (`term.py`, `ptyraw.py`,
  `run.sh`, three scripts of today's REPL and one expected screen),
  `make test-terminal` in `make check`, the scripts again through interop
  in `make test-windows`, `make doctor --scope terminal`, and
  `scripts/perf-repl.sh`. Two findings:
  * **The REPL could not read a line on a Windows console.**
    `file_read_vec` read a handle with a position through `fread`, which
    waits for all its bytes, and the C runtime of Windows gives a console
    a position (`_ftelli64` answers 0); a terminal is now read with one
    `read` whatever `ftell` says (`runtime/prims.c`).
  * **WSL interop under tmux delivers no console Ctrl-C.** A stock
    `ping -t` ignores the key, and SIGINT to interop's process ends the
    program rather than signalling it; the interrupt script runs on Linux
    only, and Windows' interrupt stays with `rt.interrupt_self` and the
    manual list (M13).

  The baselines were taken at a load average of 14 to 20 (another
  session's chain): the doubling from 1,000 to 2,000 lines costs 5.7
  times as much, the parse of the whole buffer after every line.

  Checked: every target of `make check` but one, and `make test-windows`
  (the terminal scripts through interop among it). `check-units` failed
  for the stack bytecode (37 programs otherwise through the cache at
  `-O1`) in M1's snapshot, which was copied from the working tree with
  its outputs; it passes in M2's, made from the commit, so it was the
  copy's. The sanitiser build did not run: `libasan8` is not installed
  (`make doctor`).

### M2. The palette and coloured diagnostics (L, about 1,200 SML and 1,500 generated)

* **What:**
  * `src/util/color.sml` (D1 to D3): the roles, the default theme, the
    parser of `RUNE_COLORS`, the decision per stream, the renderings to
    SGR, CSS custom properties and plain text. Portable Standard ML;
    `isatty` from `Posix.ProcEnv`.
  * `lib/unicode` (*The libraries*): UTF-8, widths and clusters from
    tables generated from Unicode 18's data files, pinned in the tree with
    their version, by `scripts/gen-unicode-tables.sh`.
  * `src/util/diagnostic.sml` (D17): a diagnostic's first line as today,
    then the excerpt with a gutter, `^` and `-` in display columns,
    labels, `note:` and `help:`; `--diagnostics=short|full`.
  * `rune` and `runedoc` print their errors and warnings through it;
    `--color=WHEN` and `--diagnostics-json FILE` on both.
    `Error.CompileError (span, msg)` stays as it is and maps to the
    simplest record the renderer takes, so the code that matches it
    (incremental's REPL among it) does not change.
  * The palette writes `palette.css` and `palette.json`, for runedoc's
    future HTML and rune-ide's Monaco theme.
  * The test runners unset `FORCE_COLOR` and `CLICOLOR_FORCE`, so that a
    CI that forces colour changes nothing they compare.
  * A test of the theme (`tests/color/`): the contrast of each text role
    against the default palettes of xterm, VTE, Windows Terminal and the
    legacy console, and under the simulations of deficient colour vision.
  * `docs/diagnostics.md`: the format, the flags, the variables.
* **Tests:** every existing suite byte for byte (their stderr is not a
  terminal); `tests/diagnostics/` with `FORCE_COLOR=1` and
  `--diagnostics=full`, each expected rendering reviewed line by line.
* **Done when:** `rune` on a terminal shows coloured excerpts, and
  nothing else changed. It needs nothing of incremental and can be
  built on master (*Prerequisites and flags*).
* **As built** (2026-10-10): `src/util/color.sml`, `src/util/diagnostic.sml`
  and `Error.show`, through which `rune` and `runedoc` print; `--color`,
  `--diagnostics` and `--diagnostics-json` on both; `runedoc --palette`,
  which `make docs` runs into `docs/generated/palette`; `lib/unicode` and
  `lib/json`; `tests/diagnostics` (eleven cases, reviewed), `tests/color`,
  `make test-diagnostics`, and a terminal script of `rune`'s excerpt;
  `docs/diagnostics.md`, the manual pages and the completions. Where it
  differs from the plan:
  * **`lib/json` came here from M10**, for `--diagnostics-json`, and the
    compiler's sources list it with `lib/unicode`'s portable files.
  * **The theme was measured, and `auto` lost colours** (decision C's
    rule). `tests/color/contrast.py` draws each role on the default
    palettes of xterm, VTE (GNOME), Windows Terminal (Campbell) and the
    legacy console, bold drawn bright where the terminal does so, also
    under protanopia, deuteranopia and tritanopia, and wants 3:1 (2.5:1
    under a deficiency, which no colour of the 16 reaches on both
    backgrounds). Only bright red and magenta passed on both: `auto` keeps
    them, `note`, `help`, prompts and types are bold or plain there, and
    `dark` and `light` have the rest. Four palettes, not D24's seven:
    Terminal.app, iTerm2 and VS Code are for M13's sweep.
  * **Excerpts are measured by grapheme cluster**, so the compiler's
    sources also take `lib/unicode`'s cluster tables: an emoji of several
    code points is two columns, as a terminal draws it.
  * **No `note:`, `help:` or secondary spans yet**: the compiler makes no
    such diagnostics; their roles are in the palette.
  * **`NO_COLOR` on a dumb terminal is no styles at all**, not
    attributes, since a dumb terminal shows the escapes.
  * Two faults of MLKit 4.7.23, recorded and not worked around
    (`tests/lib/deviations.txt`): an internal assertion on `lib/unicode`'s
    test in the runner's order, and a segmentation fault in the code it
    makes of `lib/json`'s random round trips (`docs/bugreport/mlkit`).
  * SML/NJ and MLKit wanted the type of a record projection in
    `Diagnostic` written out, where MLton and Rune inferred it.
  * **`lib/unicode`'s tables are strings of hexadecimal digits, built
    into vectors at their first use**: as lists of integer literals they
    cost the compiler's bootstrap a seventh more work and every compile
    410 KB of allocation, which moved `check-heapsim`'s `compile-sigs` at
    4 MiB across a collection. Its validation (`tools/heapsim/validate.sh`)
    now allows the live data the slack of a few dead registers, 64 KiB, as
    it allowed the copied bytes: the stock VM kept 2,464 bytes more than
    the model's lower band. ASCII asks no table. The bootstrap's budget
    (`tests/perf/bootstrap.budget`) is measured again: the compiler
    compiles 1,800 more lines, 8.6 % more instructions.

### M3. The console in the runtime and the Basis (M, about 450 C and 250 SML)

* **What:** D4 and D5.
  * `sys.h`'s `term_size`, `term_resizes`, `term_enter`, `term_leave`,
    `term_read` in `sys_posix.c` (the `SIGWINCH` counter, `cfmakeraw`'s
    settings, `poll` and `read`), `sys_win.c` (records with VT input, the
    UTF-8 conversion with surrogates, repeats and Alt key-ups, size
    events, the window's size) and `sys_none.c` (`ENOSYS`).
  * The restore: registered with the VM's exit, its fatal paths and the
    signals that end it.
  * At the VM's start on Windows: VT processing and the UTF-8 output
    code page on console output handles, restored at exit.
  * The Windows console wait fixed to wake on any record in VT mode.
  * `RuneTerminal` and `RUNE_TERMINAL` in `lib/basis`, with their
    MANIFEST lines, transcription, doc comments, `basis.runeterminal`
    row and tests; the host shim; `docs/bytecode.md` and
    `docs/runtime.md`.
* **Tests:** P1's probe rewritten on `RuneTerminal` as a terminal test:
  the same key script gives the same bytes on Linux and on Windows; the
  size and a resize seen on both; the terminal cooked again after an
  uncaught exception, `SIGTERM`, `SIGHUP` and a fatal error.
* **Done when:** those pass; the fingerprint and the image format
  number change, documented.
* **As built** (2026-10-10): `sys_term_size`, `sys_term_resizes`,
  `sys_term_enter`, `sys_term_leave` and `sys_term_read` in `sys.h`, the
  three system layers, the primitives `term_*` and `RuneTerminal` with
  `RUNE_TERMINAL` (`host no`; the host shim answers that there is no
  terminal); VT processing and the UTF-8 code page at the VM's start on
  Windows; `docs/runtime.md` (*The terminal*), `docs/bytecode.md`,
  `docs/language.md`. Tests: `tests/lang/basis.runeterminal_noterminal` where
  nothing is a terminal; the probe `tests/terminal/keys.sml` in
  `term-keys` (ten keys, the same bytes on Linux and on Windows through
  ConPTY, Ctrl-C as the byte 3 and an emoji as one code point among
  them), `term-resize` (on both) and `term-restore` (Linux: the terminal
  cooked again after a return, an uncaught exception, a stack overflow,
  `SIGTERM` and `SIGHUP`). Where it differs from the plan:
  * **`RuneTerminal` works on the standard streams**: keys from the
    standard input, drawing on the standard output, the size of
    whichever is a terminal. The primitives take descriptors.
  * **`enter` takes the bytes that undo the program's own modes**
    (bracketed paste, a hidden cursor), which the runtime writes when it
    puts the terminal back, at exit and from a signal handler alike.
  * **A stop puts the terminal back and a continue makes it raw again**
    (`SIGTSTP`, `SIGCONT`), counted as a resize; the handlers of
    `SIGTERM`, `SIGHUP`, `SIGQUIT` and `SIGTSTP` are installed only where
    the signal's action was the default.
  * **A console that refuses VT output makes the VM set `TERM=dumb`**
    for itself where `TERM` was unset, which turns colour off by D3's
    rule 4.
  * **No new image format number**: an image's magic carries the
    instruction set's fingerprint, which the five primitives changed.
  * **`RuneTerminal` has no generated page**: the Basis's MANIFEST takes a
    name that begins `Rune` or `RUNE_` for the library's own, which runedoc
    leaves out, and D25 chose that name for a structure programs use. It
    is documented in `docs/language.md`, `docs/runtime.md` and its
    signature's comments; a name without the prefix would have its page
    (the owner's choice).
  * Checked beyond `make check`: `make test-windows` and `make
    test-portability` (32-bit x86, and big-endian ppc64 and aarch64 under
    qemu). Not run: the sanitiser build (`libasan8` missing).

### M4. `lib/terminal`: styles, keys, raw mode (M, about 1,000 SML)

* **What:** the library's first half, with its `MANIFEST` and
  `DOCUMENTED`:
  * `Style`: SGR, the depth of colour the terminal has (`COLORTERM`,
    `TERM`), D3's rule for programs that are not the compiler.
  * `Key`: D6's decoder.
  * The width policy (D9), over `lib/unicode`.
  * `Terminal`: over `RuneTerminal`, and a portable one over `Posix.TTY`
    for the hosts.
  * Wired into the Makefile's lists for docs and lint.
* **Tests:**
  * the decoder on every split of every sequence (a property);
  * `make test-lib-hosts` on the files marked `host yes`.
* **Done when:** green on Rune and on the hosts; P1's decoder retired
  for `Key`.
### M5. `lib/terminal`: the line editor (L, about 2,500 SML)

* **What:** D7 to D11.
  * `LineEdit`: the buffer, `step`, the Emacs bindings, the kill ring,
    grouped undo, `layout` and `diff`, synchronised output, the mark of a
    partial line, bracketed paste, resize, Ctrl-Z on POSIX, the basic
    mode.
  * The callbacks for completeness, highlighting, completion and hints.
  * `History` (D11).
  * `LineEdit.readLine` for any program, and an example under
    `examples/`.
  * The SML terminal emulator of D23.
* **Tests:**
  * the core on events and frames;
  * the emulator's property;
  * editing scripts in `tests/terminal`, on Linux and Windows.
* **Done when:** those pass and a keystroke at 1,000 lines costs under
  16 ms (M1's harness).
### M6. The REPL on the editor (L, about 1,500 SML)

* **What:** starting from incremental's head at the time (the REPL's
  files change there):
  * the REPL built with `--library terminal`;
  * the terminal front: the prompt's roles, D12's scanner, D13's lexer
    mode and highlighter, D14's completion of names, long identifiers and
    files, history;
  * D18: the quiet terminal while code runs, the wrapper of `stdIn`, the
    echo through a stream, `print` through `TextIO.stdOut`, the mark of
    a partial line;
  * D17 in the REPL: entries named, the input as the excerpt, recovery
    per declaration;
  * D25's flags of the terminal REPL (`-q`, `-e`, `--no-init`,
    `--color`, `--basic`), a banner of one line, the init file;
  * OSC 133 marks on the terminals that accept them (D18);
  * the basic mode (D24);
  * a `rune-repl.cmd` for Windows.
* **Tests:**
  * `tests/repl`'s transcripts unchanged (basic mode);
  * terminal scripts for the prompt, highlighting, completion, history,
    errors, partial lines and Ctrl-C;
  * HOL4's Emacs mode against the REPL, unchanged.
* **Done when:** those pass, and a paste of 2,000 lines costs time linear
  in its length.

The first part ends here: the REPL has colours and editing on Linux and
Windows, and any Rune program can read a line with them.

### M7. Printing (M, about 900 SML)

* **What:** D16.
  * The generated printers build `Compiler.pretty` documents, laid out
    by a Wadler printer at the width.
  * The limits.
  * Shortest paths and `?.t`.
  * Exception arguments and reals.
  * Feedback modes.
  * Printers of one's own through `addPrettyPrinter`, the API HOL4
    calls.
  * `lib/pretty`, the layout engine, a library of its own (*The
    libraries*).
* **Tests:** `tests/repl` grows a transcript per rule; HOL4's printers
  through it.
* **Done when:** those pass.

### M8. Commands and documentation (M, about 1,200 SML)

* **What:** D15's commands and the `Repl` structure.
  * `:info` with where a name was defined (the elaborator records a
    binding's span with the unit).
  * `:doc` over a machine-readable index of members that runedoc writes
    and the REPL installs, with Markdown rendered in the terminal's styles
    by `lib/markdown`.
  * `:search` by name and by type: Rittri's matching over the session's
    environment, ranked by Runciman and Toyn's distance.
  * `:time`, `:edit`, `:save`, `:save-image`.
  * The frames recorded as an exception unwinds and returned with it
    (D22's first stage), and `:bt`.
* **Tests:** a transcript per command; runedoc's index in `tests/doc`.
* **Done when:** those pass.

### M9. Reload (M, about 700 SML)

* **What:** D19: the files of the session and their digests, `:reload`
  through the cache, the shadowed bindings and the ghosts named,
  `:reload!` with `UnitBasis.undo`, `:mark`, `:set watch`.
* **Tests:** reload after a change to a function, to a datatype (the
  ghosts named), to nothing (all relinked from the cache); `:reload!`
  against a fresh session.
* **Done when:** those pass.

### M10. The engine and its protocol (L, about 1,800 SML)

* **What:** D20.
  * The session split into the `ENGINE` signature and the terminal
    front; the requests, notifications and the `input` request; value
    handles as roots of the collector.
  * `rune-repl --engine`: JSON-RPC 2.0, lines or `Content-Length`; the
    protocol's own channel, the program's output on drained pipes; the
    transports and the token of D20.
  * `print` through the VM's slot for descriptor 1, and `OS.IO.poll`
    ended by the interrupt like a terminal read.
  * `docs/repl-protocol.md`, written with rune-ide and incremental M12.
  * `lib/json` (from rune-ide's codec, with its owner's agreement) and
    `lib/jsonrpc`.
* **Tests:** protocol transcripts in `tests/repl-protocol`: evaluation,
  output pushed, cancellation, interrupt, completion, the type at a
  position.
* **Done when:** those pass and rune-ide can drive it (its M6, built
  there).

### M11. The Jupyter kernel (L, about 1,800 SML and 100 C)

* **What:** D21.
  * `lib/digest`, `lib/zmtp` and `lib/jupyter` (*The libraries*).
  * `rune-kernel`, the bridge over them: the messages of protocol 5.5 a
    kernel must answer, a replay set, the engine as its child.
  * `Display` in the session: registered renderers per type and MIME
    type, `display`, `update`, `clear`; `text/html` from D16's documents
    and the palette's CSS.
  * Interrupts reaching the engine: `SIGINT` on POSIX; on Windows a
    thread of the runtime that waits on the event it is given (Jupyter's
    `JPY_INTERRUPT_EVENT`, or the bridge's for its child) and only sets
    the VM's flag; the engine ending when its parent does.
  * `--install` for the kernelspec.
* **Tests:**
  * a ZMTP peer in the tree for `make check`;
  * a real `jupyter_client` session (execute, stream, error, interrupt,
    complete) where its Python packages are installed (*Prerequisites and
    flags*).
* **Done when:** a notebook in JupyterLab runs Rune cells, on Linux and
  Windows.

### M12. The debugger (XL, about 2,500 SML and 400 C)

* **What:** D22's stages 2 to 5.
  * Break on raise: the hook at `RAISE` and the nested loop on the
    stopped frames.
  * Pause as a second value of the interrupt flag; the debug copy of
    the interpreter's loop with its table of lines; deoptimisation to
    leave compiled code.
  * `-g`: the names, registers, ranges and types of variables, and
    their printers made on demand; evaluation in a frame.
  * `:break`, `:step`, `:next`, `:finish`, `:continue`, `:frame`,
    `:locals`.
  * `lib/dap`, and `rune-repl --dap` over it; Jupyter's debugger through
    `debug_request`.
* **Tests:**
  * a transcript per command;
  * the same program stopped at every tier of the JIT with the same
    frames;
  * a DAP session against the adapter.
* **Done when:** those pass, and a program not being debugged runs at
  the speed it ran before (*Measuring*). Writing `BREAK` over
  instructions, in place of the debug loop, is a measured follow-up.

### M13. Windows, accessibility and the performance sweep (M, about 800 SML)

* **What:**
  * Vi's modes.
  * The kitty keyboard protocol where it is answered.
  * History's fuzzy search menu (D11) and the width probe at start (D9).
  * The manual list of D23 run and recorded.
  * D24's criteria measured and tabled: the gate.
  * What fails them fixed or written into *Ready for, not built* with
    its reason.
  * `docs/repl.md` rewritten as the REPL's manual; this file retired
    into `docs/` as the earlier roadmaps were.
* **Done when:** the gate passes.

### Why this order

* **The harness first**, because every interactive milestone is tested
  by it, and the baselines are taken before anything changes them.
* **The palette second.** It is independent of everything else, can
  land on master, and is visible at once in every compiler error.
* **The runtime before the library.** Without M3 there are no keys on
  Windows (P3).
* **The library before the REPL**, so that it is general and not the
  REPL's private code.
* **Printing before commands**, because `:type`, `:info`, `:doc` and the
  debugger all print with it.
* **Reload after commands**, because it is one.
* **The engine after the REPL's features.** Its requests are those
  features, and designing the protocol before them would guess.
* **The kernel after the engine; the debugger last**, the largest, and
  in need of printing, the engine and the kernel's control channel.

## Prerequisites and flags

* **Incremental first, for the REPL's part.** M6 to M12 change
  `src/repl`, which exists on branch `incremental` only, and whose files
  the session working there is still changing. They start from
  incremental's head when they start, after it is merged or with the
  owner's word on where to branch. M2 to M5 need nothing of it: M2 is
  the compiler's, M3 the runtime's, M4 and M5 a library's; they can be
  built on master and merged first. M1's harness can too; its scripts
  of today's REPL need incremental's `bin/rune-repl`.
* **New primitives meet incremental's.** M3 adds primitives and changes
  the fingerprint of the instruction set and the image format;
  incremental adds primitives too (`rt_link`, `rt_share`, the interrupt's)
  and changes the image format with them. Whichever lands second
  renumbers.
* **The printer API.** M7 uses `Compiler.pretty`, `prettyPrint`,
  `addPrettyPrinter` and `lineLength`, which the incremental worktree is
  building (uncommitted at `f8e9fdc5`; HOL4's branch already calls them).
  Exception arguments need incremental D10's condition 4 (a printer per
  exception constructor).
* **runedoc's index.** M8's `:doc` needs runedoc to write an index of
  members that a program can read (its pages list them for people), a change
  to `src/doc` with its tests in `tests/doc` (`docs/plans/docgen.md` keeps
  search out of its own scope).
* **Python for the kernel's test.** M11's interoperation test needs
  Python's `jupyter_client` and `pyzmq`, which this machine does not have
  (no `pip` either). The owner installs them, or M11 is tested against
  the tree's ZMTP peer only.
* **tmux** is installed here; `make doctor` reports it where it is not.
  The Windows tests need WSL interop (`make test-windows` already does).
* **`print` and the Basis.** D18 changes what `print` writes through: a
  change to the Basis that `docs/language.md` and `tests/basis` record.
* **Found while writing this** (outside this roadmap; for the owner):
  * `make -j4 all` on a clean checkout of `f8e9fdc5` fails: `lib/cache/made`
    runs `bin/rune` but depends on `bin/rune.rbc` and `bin/runevm` only
    (`Makefile:154-157`); a second run succeeds.
  * `use` raises `Fail` for a file it cannot read, where `COMPILER`'s
    documentation says `IO.Io` (`src/repl/repl.sml:117`;
    `lib/basis/compiler_sig.sml:34-36`).
  * `docs/bytecode.md:17` says the version is 3 and `:46` says 6.
  * `runtime/sys/sys_win.c:13` points to a `docs/plans/windows.md` that
    does not exist.
  * `docs/plans/jit.md`'s M11 names files under `vm/new/`.
  * Rune and rune-ide have no licence file. This roadmap studied the
    sources of GPL code (GNU readline, fish) and copied none.

## Relation to other plans

* **[incremental-compilation.md](incremental-compilation.md).**
  * This roadmap is that plan's "REPL with editing", listed under its
    *Ready for, not built*.
  * It builds on its M4 (the REPL), M6 (the cache, for reload) and D10
    (printers from types).
  * It uses incremental M8's dependency graph for reload once it exists.
  * Its engine (D20) is the service of incremental M12. Both are one
    protocol: analysis and evaluation for editors.
  * The debugger takes up "printing without the compiler" in its own way:
    with the compiler, which the REPL has.
* **[hol4.md](hol4.md).** HOL4's users meet the REPL through a pipe,
  Emacs and `holrepl`. The basic mode and the unchanged transcripts are
  for them, and M7's printers are the ones HOL4 installs.
* **ide.md, here and in rune-ide.** rune-ide's M6 ("Integrate
  REPL/evaluation") is a client of M10. Its M5's analysis requests may
  use the same engine. Its JSON-RPC framing is the protocol's. The
  palette's CSS is offered to its themes. Its M6 also plans "an SML
  debug-adapter layer" over runtime hooks: D22's adapter is meant to be
  that layer.
* **[errror-messages.md](errror-messages.md) and
  [weak-points.md](weak-points.md) §3.** D17's renderer is what an
  error datatype will print with. The datatype, several errors per pass
  in the lexer and parser, and better messages stay there. §4 ("there
  is no REPL") is out of date since incremental M4.
* **[async-io.md](async-io.md).** With no threads, every front that
  must answer during a computation is a poll loop or a second process.
  Green threads would make D21's B cheap; nothing here waits for them.
* **[docgen.md](docgen.md).** runedoc gains the palette (its
  diagnostics in M2, its future HTML pages through the CSS) and an index
  of members (M8).
* **[jit.md](jit.md).** The debugger stops compiled code by the poll
  points of jit M6 and deoptimisation of jit M11. Nothing here changes
  the JIT.
* **quickcheck.md.** The editor's properties (D23) are written with
  `lib/test/property`.
* **The REPL's semantics.** Chapter 8, and Elsman's rules for it, are
  the specification the REPL's tests hold to, whichever form runespec
  gives the Definition.

## Risks

* **The incremental worktree moves under M6 to M12.** Start each of
  them from its head, in small commits, and ask its session before
  touching the same files.
* **Windows consoles differ.**
  * The legacy console window, Windows 10's inbox console, Windows
    Terminal's versions and VS Code's xterm.js do not agree on bracketed
    paste, widths and the kitty protocol.
  * The tests drive ConPTY only.
  * Mitigation: the basic mode where VT is refused, the width policy,
    the manual list of D23.
* **Emoji widths.** Terminals disagree (2 to 6 cells for one cluster).
  The policy switch and a probe at start mitigate; some terminal will
  still be wrong.
* **The Escape timeout over a slow link.** 50 ms splits an
  Alt-key over ssh; the timeout is settable, and the kitty protocol
  removes the ambiguity where it is answered.
* **A terminal left raw.** P1 showed it happens today. M3's restore
  covers exit, fatal errors and terminating signals, but not `SIGKILL`;
  `reset` remains the user's answer to that, as for every editor.
* **`lib/terminal` on the hosts.** Their `Posix.TTY`s differ in details.
  The portable `Terminal` is tested by `make test-lib-hosts`, and a
  difference is a `HOST-BUG` line, never a workaround (`AGENTS.md`).
* **Flaky end-to-end tests.** tmux and timing. The harness waits on
  screens, never on time, and retries a wait. The latency numbers come
  from `ptyraw.py` on a quiet machine, not from tmux.
* **Generativity confuses.** After a reload, a value whose type has the
  same name but is not the same type will print `?.t` and fail to match.
  Naming the ghosts (D19) is the mitigation; the confusion is SML's.
* **A socket someone else can reach.**
  * Where it listens: a Unix socket in a directory of mode 0700, since
    POSIX does not say what a socket file's own mode does (nREPL's
    advice), and on Windows 10 1803 and later in a directory only the
    user can read; TCP on `127.0.0.1` only with the token below.
  * The first message must carry a token read from a file only the
    user can read.
  * A line that looks like HTTP closes the connection. Guile's REPL
    server was attacked by a web page posting to it on localhost
    (CVE-2016-8606), and Node's inspector by DNS rebinding
    (CVE-2018-7160).
  * Content-Length framing on TCP is HTTP-shaped: only `Content-Length`
    and `Content-Type` headers are accepted.
  * The kernel checks every message's HMAC and rejects replays.
* **HMAC at 1 ms a message.** Chatty output in a notebook will feel it.
  The fix is `Word32` arithmetic in the JIT, or a primitive, measured
  first.
* **The debugger is XL.** Stage it (D22), and let each stage be useful
  alone.
* **Scope.** Thirteen milestones. M6 is a stopping point with a REPL
  that is already better than any other SML's.

## Testing

* **The libraries.** Each of *The libraries* is tested on its own in
  `make test-lib`, against its standard's vectors and by properties, and
  on the hosts where its files are portable.
* **The core of `lib/terminal`.** Unit tests on events, states and
  frames, and the emulator's property (D23), in `make test-lib`, on Rune
  and the hosts.
* **The runtime's console.** Terminal tests of M3 (keys, size, resize,
  the restore after every way to end) on Linux in `make test-terminal`,
  and through interop on Windows in `make test-windows`.
* **The REPL.**
  * `tests/repl`'s transcripts, which are the basic mode and do not
    change.
  * Screens in `tests/terminal` for what a terminal shows.
  * Protocol transcripts in `tests/repl-protocol` (M10).
  * The kernel against the tree's ZMTP peer, and against
    `jupyter_client` where installed (M11).
  * The debugger at every tier of the JIT (M12).
* **The diagnostics.** Every suite's stderr is unchanged, since it is not
  a terminal. `tests/diagnostics` renders with colour forced, and the
  theme's contrast is checked in `tests/color`.
* **By hand.** The list of D23, run at M13 and when the console code
  changes.

## Measuring

`scripts/perf-repl.sh` (M1), on a quiet machine (load average under 2),
compared at every milestone with the table below, which M1 fills. The
first column is what the experiments measured under a load of 30; the
next, what each milestone measured, with the load it was measured at
(another session's builds kept the machine busy throughout).

| What | P0 to P4 (loaded) | M1 | Target (D24) |
|---|---|---|---|
| start to the first prompt | 72 to 87 ms | 46.5 ms | 100 ms |
| `1;` to the next prompt | 8 to 16 ms | 7.8 ms | as M1 |
| paste of 1,000 lines | 6.7 to 7.0 s | 5.8 s | linear in the length |
| paste of 2,000 lines | hung in the harness | 33.1 s | linear in the length |
| keystroke, 10 lines | 0.38 ms (P2) | from M5 | 16 ms |
| keystroke, 1,000 lines | 29.6 ms (P2) | from M5 | 16 ms |
| bytes written a keystroke, 1,000 lines | 1,324 (P2) | from M5 | as M5 |
| completion menu over the Basis | none | from M6 | 50 ms |
| kernel round trip, 16 bytes | 66 µs median (P4) | from M11 | as M11 |
| a program not debugged, under M12 | as before | from M12 | no slower |

## Ready for, not built

* **Enter by the parser** (D12's C). Submit a complete entry without
  `;`, for those who want Julia's behaviour.
* **Completion by type.** Expressions of the wanted type at the cursor
  (Gvero et al.).
* **Live feedback.** The type of what is being typed, shown as a hint
  as it is typed; errors marked before Enter (Tanimoto's higher
  liveness).
* **Explaining type errors.** Type error slicing (Haack and Wells,
  Skalpel) for `:explain`, and `:why exp` by bidirectional type slicing.
  They belong with `errror-messages.md`.
* **Hot reload** of a function in place (incremental M12), and a kernel
  that warns when a cell uses a binding since redefined, writing the
  slice that reproduces a value (Head et al.).
* **Travel back in time** in the debugger: checkpoints from images, the
  count of instructions as the clock (ocamldebug's `fork`, which Windows
  lacks; Tolmach and Appel's continuations).
* **A notebook's widgets and comms**, and a bridge in Python (D21's C)
  for whoever wants notebooks before M11.
* **A VM mode that frames the program's output** as the protocol's
  `output` notifications, for a client with one pipe (Emacs's
  `make-process`; D20).
* **`BREAK` written over instructions** in place of the debug loop of
  D22's third stage, if M12's measures ask for it.
* **Links in diagnostics.** OSC 8 from an error code to its explanation
  and from a location to the file (GHC and rustc link codes), off by
  default: a terminal's support cannot be detected.
* **A light or dark theme chosen automatically** by asking the
  background (OSC 11).
* **Autoloading a library.** `:require NAME` or an unbound structure
  that loads `lib/NAME` into the session (CM's autoloader, incremental
  D12).
* **A language server** on the engine (incremental M12 and rune-ide's
  M5), and the mouse in the editor.

## References

The sources were read on 2026-10-09; every DOI was checked against
Crossref's record that day, and pages without one give their URL. The
implementations are cited by path where they are under
`/home/ruud/reference`; the research notes behind *What the
implementations do* keep every citation.

**The top level** (*What the literature says*, D12, D19, D20):
* Sandewall. "Programming in an interactive environment: the 'LISP'
  experience." ACM Computing Surveys 10(1), 1978.
  doi:10.1145/356715.356719.
* Findler, Clements, Flanagan, Flatt, Krishnamurthi, Steckler,
  Felleisen. "DrScheme: a programming environment for Scheme." JFP
  12(2), 2002. doi:10.1017/S0956796801004208.
* Flatt et al. "The top level is hopeless", mailing-list messages
  collected by Tobin-Hochstadt. https://gist.github.com/samth/3083053
* Elsman. "Crafting a REPL for HOT compiled execution." DIKU technical
  report, 2026. https://elsman.com/pdf/repl.pdf
* Wenzel. "Asynchronous user interaction and tool integration in
  Isabelle/PIDE." ITP 2014. doi:10.1007/978-3-319-08970-6_33.
* Galindo Salgado, Langa, Nikolaou, Morehouse-Valcarcel. "PEP 762:
  REPL-acing the default REPL." 2024. https://peps.python.org/pep-0762/
* Kumar, Myreen, Norrish, Owens. "CakeML: a verified implementation of
  ML." POPL 2014. doi:10.1145/2535838.2535841.
* Sewell et al. "Cakes that bake cakes: dynamic computation in CakeML."
  PLDI 2023. doi:10.1145/3591266.
* Greenberg, Witten. "How users repeat their actions on computers:
  principles for design of history mechanisms." CHI 1988.
  doi:10.1145/57167.57196.
* Greenberg, Witten. "Supporting command reuse." IJMMS 39(3), 1993,
  parts 1 and 2. doi:10.1006/imms.1993.1065, doi:10.1006/imms.1993.1066.
* Poly/ML. "The PolyML structure"; "IDE communications protocol";
  "The PolyML.Debug structure."
  https://polyml.org/documentation/Reference/PolyMLStructure.html
  https://www.polyml.org/documentation/IDEProtocol.html
  https://www.polyml.org/documentation/Reference/PolyMLDebug.html

**Live programming and notebooks:**
* Tanimoto. "A perspective on the evolution of live programming." LIVE
  2013. doi:10.1109/LIVE.2013.6617346.
* McDirmid. "Living it up with a live programming language." OOPSLA
  2007. doi:10.1145/1297027.1297073.
* Rein, Ramson, Lincke, Hirschfeld, Pape. "Exploratory and live,
  programming and coding." Programming 3(1), 2019.
  doi:10.22152/programming-journal.org/2019/3/1.
* Omar, Voysey, Chugh, Hammer. "Live functional programming with typed
  holes." POPL 2019. doi:10.1145/3290327.
* Peleg, Gabay, Itzhaky, Yahav. "Programming with a read-eval-synth
  loop." OOPSLA 2020. doi:10.1145/3428227.
* Pérez, Granger. "IPython: a system for interactive scientific
  computing." CiSE 9(3), 2007. doi:10.1109/MCSE.2007.53.
* Kluyver et al. "Jupyter Notebooks: a publishing format for
  reproducible computational workflows." ELPUB 2016.
  doi:10.3233/978-1-61499-649-1-87.
* Rule, Tabard, Hollan. "Exploration and explanation in computational
  notebooks." CHI 2018. doi:10.1145/3173574.3173606.
* Pimentel, Murta, Braganholo, Freire. "A large-scale study about
  quality and reproducibility of Jupyter notebooks." MSR 2019.
  doi:10.1109/MSR.2019.00077.
* Head, Hohman, Barik, Drucker, DeLine. "Managing messes in
  computational notebooks." CHI 2019. doi:10.1145/3290605.3300500.
* Chattopadhyay, Prasad, Henley, Sarma, Barik. "What's wrong with
  computational notebooks?" CHI 2020. doi:10.1145/3313831.3376729.

**Error messages** (D17):
* Barik et al. "Do developers read compiler error messages?" ICSE 2017.
  doi:10.1109/icse.2017.59.
* Traver. "On compiler error messages: what they say and what they
  mean." Advances in HCI 2010. doi:10.1155/2010/602570.
* Becker et al. "Compiler error messages considered unhelpful."
  ITiCSE-WGR 2019. doi:10.1145/3344429.3372508.
* Marceau, Fisler, Krishnamurthi. "Measuring the effectiveness of error
  messages designed for novice programmers." SIGCSE 2011.
  doi:10.1145/1953163.1953308.
* Wrenn, Krishnamurthi. "Error messages are classifiers." Onward! 2017.
  doi:10.1145/3133850.3133862.
* Czaplicki. "Compiler errors for humans." Elm blog, 2015.
  https://elm-lang.org/news/compiler-errors-for-humans
* Rust compiler development guide, "Errors and lints."
  https://rustc-dev-guide.rust-lang.org/diagnostics.html
* GCC, "Diagnostic message formatting options."
  https://gcc.gnu.org/onlinedocs/gcc/Diagnostic-Message-Formatting-Options.html
* GHC user's guide, "Using GHC."
  https://downloads.haskell.org/ghc/latest/docs/users_guide/using.html
* Haack, Wells. "Type error slicing in implicitly typed higher-order
  languages." ESOP 2003, doi:10.1007/3-540-36575-3_20; SCP 50, 2004,
  doi:10.1016/j.scico.2004.01.004.
* Rahli, Wells, Pirie, Kamareddine. "Skalpel: a type error slicer for
  Standard ML." ENTCS 312, 2015, doi:10.1016/j.entcs.2015.04.012; JSC
  80, 2017, doi:10.1016/j.jsc.2016.07.013.
* Lerner, Flower, Grossman, Chambers. "Searching for type-error
  messages." PLDI 2007. doi:10.1145/1250734.1250783.
* Pavlinovic, King, Wies. "Finding minimum type error sources." OOPSLA
  2014. doi:10.1145/2660193.2660230.
* Chen, Erwig. "Counter-factual typing for debugging type errors." POPL
  2014. doi:10.1145/2535838.2535863.
* Heeren, Leijen, van IJzendoorn. "Helium, for learning Haskell."
  Haskell Workshop 2003. doi:10.1145/871895.871902.
* Carroll, Madhavapeddy, Omar. "Bidirectional type slicing." 2026.
  https://arxiv.org/abs/2607.12197

**Pretty printing** (D16):
* Oppen. "Prettyprinting." TOPLAS 2(4), 1980.
  doi:10.1145/357114.357115.
* Hughes. "The design of a pretty-printing library." AFP 1995.
  doi:10.1007/3-540-59451-5_3.
* Wadler. "A prettier printer." The Fun of Programming, 2003.
  doi:10.1007/978-1-349-91518-7_11.
* Leijen. wl-pprint. https://hackage.haskell.org/package/wl-pprint ;
  its successor https://hackage.haskell.org/package/prettyprinter
* Swierstra, Chitil. "Linear, bounded, functional pretty-printing."
  JFP 19(1), 2009. doi:10.1017/S0956796808006990.
* Chitil. "Pretty printing with lazy dequeues." TOPLAS 27(1), 2005.
  doi:10.1145/1053468.1053473.
* Kiselyov, Peyton Jones, Sabry. "Lazy v. yield: incremental, linear
  pretty-printing." APLAS 2012. doi:10.1007/978-3-642-35182-2_14.
* Bernardy. "A pretty but not greedy printer." ICFP 2017.
  doi:10.1145/3110250.
* Podkopaev, Boulytchev. "Polynomial-time optimal pretty-printing
  combinators with choice." PSI 2014. doi:10.1007/978-3-662-46823-4_21.
* Porncharoenwase, Pombrio, Torlak. "A pretty expressive printer."
  OOPSLA 2023. doi:10.1145/3622837.

**Search and completion** (D14, D15):
* Rittri. "Using types as search keys in function libraries." FPCA 1989,
  doi:10.1145/99370.99384; JFP 1(1), 1991, doi:10.1017/S095679680000006X.
* Runciman, Toyn. "Retrieving re-usable software components by
  polymorphic type." FPCA 1989, doi:10.1145/99370.99383; JFP 1(2), 1991,
  doi:10.1017/s0956796800020049.
* Di Cosmo. "Deciding type isomorphisms in a type-assignment
  framework." JFP 3(4), 1993. doi:10.1017/s0956796800000861.
* Di Cosmo. Isomorphisms of Types. Birkhäuser, 1995.
  doi:10.1007/978-1-4612-2572-0.
* Aponte, Di Cosmo. "Type isomorphisms for module signatures." PLILP
  1996. doi:10.1007/3-540-61756-6_95.
* Mitchell. Hoogle. https://hoogle.haskell.org
* Gvero, Kuncak, Kuraj, Piskac. "Complete completion using types and
  weights." PLDI 2013. doi:10.1145/2491956.2462192.
* Bruch, Monperrus, Mezini. "Learning from examples to improve code
  completion systems." ESEC/FSE 2009. doi:10.1145/1595696.1595728.

**Highlighting** (D13):
* Hannebauer, Hesenius, Gruhn. "Does syntax highlighting help
  programming novices?" EMSE 23(5), 2018.
  doi:10.1007/s10664-017-9579-0.
* Sarkar. "The impact of syntax colouring on program comprehension."
  PPIG 2015. https://ppig.org/papers/2015-ppig-26th-sarkar1/
* Beelders, du Plessis. "Syntax highlighting as an influencing factor
  when reading and comprehending source code." JEMR 9(1), 2015.
  doi:10.16910/jemr.9.1.1.

**Debuggers** (D22):
* Tolmach, Appel. "Debugging Standard ML without reverse engineering."
  LFP 1990, doi:10.1145/91556.91564; "A debugger for Standard ML." JFP
  5(2), 1995, doi:10.1017/S0956796800001313.
* Marlow, Iborra, Pope, Gill. "A lightweight interactive debugger for
  Haskell." Haskell Workshop 2007. doi:10.1145/1291201.1291204.
* Hölzle, Chambers, Ungar. "Debugging optimized code with dynamic
  deoptimization." PLDI 1992. doi:10.1145/143095.143114.
* Pothier, Tanter, Piquer. "Scalable omniscient debugging." OOPSLA
  2007. doi:10.1145/1297027.1297067.
* Clements, Flatt, Felleisen. "Modeling an algebraic stepper." ESOP
  2001. doi:10.1007/3-540-45309-1_21.
* Debug Adapter Protocol.
  https://microsoft.github.io/debug-adapter-protocol/specification

**Colour** (D2, D3):
* Machado, Oliveira, Fernandes. "A physiologically-based model for
  simulation of color vision deficiency." TVCG 15(6), 2009.
  doi:10.1109/TVCG.2009.113.
* W3C. Web Content Accessibility Guidelines 2.2.
  https://www.w3.org/TR/WCAG22/
* NO_COLOR. https://no-color.org/ ; FORCE_COLOR.
  https://force-color.org/ ; CLICOLOR. https://bixense.com/clicolors/
* Python, "Controlling color."
  https://docs.python.org/3/using/cmdline.html

**Terminals** (D4 to D9):
* ECMA-48, Control functions for coded character sets.
  https://ecma-international.org/publications-and-standards/standards/ecma-48/
* Dickey. XTerm control sequences.
  https://invisible-island.net/xterm/ctlseqs/ctlseqs.html
* Goyal. Comprehensive keyboard handling in terminals (the kitty
  protocol). https://sw.kovidgoyal.net/kitty/keyboard-protocol/
* Microsoft. Console virtual terminal sequences; classic console APIs
  versus virtual terminal sequences; SetConsoleMode; creating a
  pseudoconsole session.
  https://learn.microsoft.com/en-us/windows/console/console-virtual-terminal-sequences
  https://learn.microsoft.com/en-us/windows/console/classic-vs-vt
  https://learn.microsoft.com/en-us/windows/console/setconsolemode
  https://learn.microsoft.com/en-us/windows/console/creating-a-pseudoconsole-session
* microsoft/terminal issue 4551 (UTF-8 input through `ReadFile`).
  https://github.com/microsoft/terminal/issues/4551
* Bothner. Semantic prompts (OSC 133).
  https://gitlab.freedesktop.org/Per_Bothner/specifications/-/raw/master/proposals/semantic-prompts.md
* Koblinger. Hyperlinks in terminal emulators (OSC 8).
  https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda
* Unicode 18.0.0; UAX #11 East Asian Width; UAX #29 Text Segmentation;
  UTS #51 Emoji. https://www.unicode.org/versions/Unicode18.0.0/
  https://www.unicode.org/reports/tr11/tr11-46.html
  https://www.unicode.org/reports/tr29/tr29-49.html
  https://www.unicode.org/reports/tr51/tr51-31.html

**Protocols** (D20, D21):
* Jupyter messaging; kernels; the debugger protocol (JEP 47).
  https://jupyter-client.readthedocs.io/en/latest/messaging.html
  https://jupyter-client.readthedocs.io/en/latest/kernels.html
  https://jupyter.org/enhancement-proposals/jupyter-debugger-protocol
* ZMTP 3.1. https://rfc.zeromq.org/spec/37/
* Krawczyk, Bellare, Canetti. "HMAC." RFC 2104, 1997.
  doi:10.17487/RFC2104.
* NIST. "Secure hash standard." FIPS 180-4, 2015.
  doi:10.6028/NIST.FIPS.180-4.
* Nystrom. "Identifiers and test vectors for HMAC-SHA-224, -256, -384
  and -512." RFC 4231, 2005. doi:10.17487/RFC4231.
* JSON-RPC 2.0. https://www.jsonrpc.org/specification
* Bray (ed.). "The JavaScript Object Notation (JSON) data interchange
  format." RFC 8259, 2017. doi:10.17487/RFC8259.
* Language Server Protocol 3.18.
  https://microsoft.github.io/language-server-protocol/specifications/lsp/3.18/specification/
* nREPL operations. https://nrepl.org/nrepl/ops.html
* Bour, Refis, Scherer. "Merlin: a language server for OCaml
  (experience report)." ICFP 2018. doi:10.1145/3236798.
* CVE-2016-8606 (Guile's REPL server) and CVE-2018-7160 (Node's
  inspector). https://cveawg.mitre.org/api/cve/CVE-2016-8606
  https://cveawg.mitre.org/api/cve/CVE-2018-7160


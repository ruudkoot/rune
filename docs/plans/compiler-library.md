# Roadmap: the compiler as a library

The owner's request (2026-10-10):

> what i had intended was that most of the compiler moves to lib/compiler
> so it can be used from other sml programs to load sml/mid/bytecode and
> than run it in-process or write to disk etc.
>
> (the compiler driver stays under src)
>
> given that another agent is working on the repl i think we need to merge
> that work first

The incremental roadmap's M12 built "the compiler as a service" as a
protocol: `rune --serve`, which answers an editor's requests over JSON-RPC
(*M12, as built*). That is not this. This is the compiler as a library: a
program names `RuneCompiler`, and with it compiles Standard ML, Mid or
bytecode into units, runs them in its own process, or writes them to
disk. `rune --serve`, the REPL and its engine become programs written on
it.

## Status

| Milestone | What | State |
|---|---|---|
| M0 | The REPL's branch and `incremental` merged; this plan's numbers measured again | done 2026-10-13: both on `master` since 2026-10-11 (#38, #39), the numbers measured again at `2e2351ba` |
| M1 | The compiler moved to `lib/compiler`, the driver left in `src` | planned |
| M2 | A library's names: export lists for `rune --library` | planned |
| M3 | The compiler's state: a session that starts from nothing | planned |
| M4 | `RuneCompiler`: the API, its tests, its frozen cache | planned |
| M5 | The clients: the REPL's engine, `rune --serve`, the Basis's `Compiler` | planned |

Size: L, about 2,000 lines of SML beside the move of about 19,000.

## Before it starts: the REPL's work merged

The `repl` branch (roadmap `docs/plans/repl.md`) changed the files this
plan moves. It was merged with `incremental`, and both have been on
`master` since 2026-10-11 (#38 and #39). What it added that this plan
builds on:

* **The engine**: `src/repl/engine.sml`, the signature `ENGINE`
  (`ReplEngine`: `eval`, `use`, `reload`, `check`, `typeAt`, `complete`,
  `inspect`), which takes as data what the REPL's loop prints
  (`Error.silent`, `Error.kept`), and `src/repl/protocol.sml`, its
  JSON-RPC protocol (`rune-repl --engine`, `docs/repl-protocol.md`). It is
  the closest thing there is to the API of M4: a session of the compiler,
  driven by calls.
* **Diagnostics as data**: `src/util/diagnostic.sml` (`Diagnostic.item`)
  and `src/util/color.sml`, beside incremental M12's `Error.note`.
* **Libraries**: `lib/json`, `lib/jsonrpc`, `lib/pretty`, `lib/terminal`
  and others, and the owner's rule that generic code becomes a tested
  library under `lib` (repl M0). `rune --serve` keeps a JSON codec of its
  own (`src/driver/serve.sml`) that `lib/json` replaces in M5.

The merge itself did work this plan depends on. M10 of `incremental` had
replaced `sources.txt` by `rune.build`, and the hand-written MANIFESTs by
`library.build` and `rune --basis-index`. The REPL's branch had added
files to `sources.txt`, and libraries with hand-written MANIFESTs. M0 is
done: both branches are on `master`, and `make check` passes there. The
numbers below are `master`'s at `2e2351ba`; they were `incremental`'s at
`6e9d11b9`.

## Where it starts

* **The compiler** is 75 files and 22,543 lines (`rune --build-list
  rune.build`): `src/util` 10 files and 1,246 lines, `src/frontend` 5 and
  2,300, `src/elab` 8 and 2,963, `src/core` 15 and 5,703, `src/backend` 14
  and 4,132, `src/driver` 12 and 4,719, `src/main` 1. The rest are two
  libraries that it is written on, `lib/unicode` (8 files, 1,162 lines)
  and `lib/json` (2 files, 315 lines). `runedoc` shares 34 of the files,
  24 of `src` and the two libraries; `runeopt` shares 3 and `runeisa` 1.
* **Compiling in-process and running the result** is what the REPL's
  session does already (`src/repl/session.sml`, `compile`): a declaration
  is elaborated, made into a unit's code (`Pipeline.unitThrough`), kept in
  the cache, and linked into the running program (`Runtime.link`).
* **Units in and out**: `UnitFile.read`, `write` and `chunks` (`.rbu`);
  `Link` makes a program of units and `Emit` writes it (`.rbc`); `UnitMid`
  writes and reads a unit's Mid with its names by key; a cache entry keeps
  a unit's basis (a pickle), its code and its Mid together (`UnitCache`).
* **The Basis's `Compiler`** (`lib/basis/compiler.sml`) has hooks that
  the REPL fills (`use`, `compile`); in a program that `rune` compiled
  nothing fills them, and they raise `Fail`.
* **The compiler's state is global**: about 205 top-level `ref`s and
  tables in 32 of its files (*M0*, below) -- the environment, the
  elaborator's signatures and functors, the tables by stamp, the
  counters, the options, the errors.
  That is why `docs/plans/ide.md` says not to call `Main.main` twice and
  expect two compiles to be independent, and why `rune --serve` forks a
  child for each request.
* **A library's names**: `rune --library NAME` puts every declaration of
  each file it loads in scope, so a program that uses the compiler would
  see its `Ast`, `Env`, `Error`, `Source` and `Types`, and could not
  declare its own. Build files have export lists (`library (structure X) =
  ... end`, incremental M10); `--library` does not read them.

## What moves and what stays

* **To `lib/compiler`**: `src/util`, `src/frontend`, `src/elab`,
  `src/core`, `src/backend`, and of `src/driver` the compiler proper --
  `basismanifest.sml`, `buildfile.sml`, `unitbasis.sml`, `pipeline.sml`,
  `unitmid.sml`, `unitcache.sml`, `deps.sml` (2,865 lines): 58 files, about
  19,200 lines.
* **In `src`**: the driver -- `options.sml` (the command line),
  `main.sml`, `parallel.sml` and `serve.sml` -- with
  `src/main`, `src/repl` (the terminal front and the protocol; the engine's
  core moves in M5 if M4 makes it the library's session), `src/doc`,
  `src/opt` and `src/isa`.
* **What the moved files take from the driver**: `pipeline.sml` and
  `unitcache.sml` read seven of the command line's options (`Options.*`),
  in nine places.
  They become the library's own settings, which `options.sml` sets.
* **`build/config.sml`** (the compiler's version and its identity, the
  hash of its sources that names a cache's configuration) stays
  generated; the library's build file names it.

## Decisions

**D1. A library's names.** (a) `rune --library` honours a library's export
list: `library.build` says `library (structure RuneCompiler, signature
RUNE_COMPILER) = ... end`, `rune --basis-index` writes the exports into
the MANIFEST, a file loads when a name it exports or one it needs is
used, and a program sees the exports only. (b) The library is used only
through build files, whose export lists work today. (c) Every structure
renamed with a prefix (`RuneAst`, ...). Recommended: (a); it is what a
library needs anyway (`lib/json` will have the same problem), and (c)
renames 58 files for nothing a program can use.

**D2. The compiler's state.** (a) One session at a time, which
`RuneCompiler.session` starts from nothing: every top-level `ref` and table
of the library registered with how to put it back, and a check in `make
check` that finds one not registered. (b) A compile in a forked child,
whose unit's bytes the parent links and runs, as `rune --serve` does: the
compiler's state never reaches the parent, and nothing is registered, but
there is no fork on Windows (the VM emulates one by a second process,
which costs an image). (c) The state made explicit: a value of the
compiler's state passed through every module, so that a program can hold
two compilers. Recommended: (a) now, (b) offered beside it for a caller
that wants isolation, and (c) left until a program needs two compilers at
once; it touches every module of the front end.

**D3. Running in-process.** The VM loads units into a running program
(`Runtime.link`, `Runtime.load`); it does not load a whole program
(`.rbc`), whose globals are numbered from zero as the only program there
is. (a) In-process means units: Standard ML, Mid and `.rbu` are compiled
or read into units and linked; a `.rbc` is written, or run in a child VM.
(b) The VM learns to load a `.rbc` as one unit. Recommended: (a); (b) is
VM work for a case that a build in units already covers.

**D4. Mid as an input.** A unit's Mid names other units' names by key, and
means something only beside its basis, as a cache entry keeps them. (a) The
library reads a unit's Mid with its basis (an entry, or what `--emit-units`
writes), and runs the back end over it. (b) It also reads a whole
program's Mid, as `MidText` prints it, which needs no basis. Recommended:
(a) first; (b) when a program wants to make Mid of its own.

**D5. The rules for libraries.** `AGENTS.md` forbids a library `_prim`
(the compiler uses none) and a work-around of another compiler's bug
(`lib/NAME`, the owner's rule of 2026-09-27); the compiler must still build
with every host. It carried two for MLKit 4.7.23 (`UnifyExn`, and
`ServeExn` in `src`), which MLKit 4.7.24 made unneeded and which are gone
(2026-10-13), so the rule bites again only with a host's next bug. (a)
`lib/compiler` is excepted from the second rule, said so in `AGENTS.md`.
(b) The work-arounds stay in `src`, with a stub in the library that the
hosts' builds replace. Recommended: (a); (b) splits one structure across
two trees for one host.

**D6. The API's name and the Basis's `Compiler`.** The Basis has
`Compiler : COMPILER`, the REPL's controls. (a) The library is
`RuneCompiler : RUNE_COMPILER`, and when a program links it, it fills the
Basis's `Compiler.use` and `Compiler.compile`, so `use` works in any
program that has the library. (b) The library is a second `Compiler`.
Recommended: (a).

## The API (to be settled in M4)

```sml
signature RUNE_COMPILER =
sig
  type session
  type compiled                         (* a unit: its basis and its code *)
  type diagnostic = {severity : string, file : string, start : int, stop : int,
                     line : int, column : int, message : string}
  exception Failed of diagnostic list

  val session : {lib : string option, flags : string list} -> session
  val compileText : session * {file : string, text : string} -> compiled
  val compileFile : session * string -> compiled
  val readUnit : session * string -> compiled            (* a .rbu *)
  val readMid : session * {basis : string, mid : string} -> compiled
  val run : compiled -> unit            (* linked, run; its names join the session *)
  val writeUnit : compiled * string -> unit
  val writeMid : compiled * string -> unit
  val writeProgram : compiled list * string -> unit      (* linked, a .rbc *)
  val typeAt : session * {file : string, offset : int} -> string option
end
```

Its diagnostics are `Diagnostic.item` and `Error.note`'s, joined; its
session is the REPL engine's, made a library's.

## Milestones

### M0. Merge first

* **What:** the `repl` branch and `incremental` on `master` (the owner's
  pull requests); `make check` there; this plan's numbers and file lists
  measured again.
* **Done when:** both are merged and this file is updated.
* **Done** (2026-10-13):
  * Both branches were merged on 2026-10-11 (#38, #39). CI's `check`
    passes on `master` at `2e2351ba`, where the numbers of *Where it
    starts* and *What moves and what stays* were measured.
  * The compiler's state was counted as the `val`s at the top of a
    structure, in the files of `src`, bound to a `ref`, an
    `IntTable.table` or an `Array.array`. This plan first said 210 and
    did not say how it counted. The same count gives 184 at `6e9d11b9`,
    so the state has grown by about a tenth.
  * Two things changed besides the sizes. The compiler is now written on
    two libraries, `lib/unicode` and `lib/json`. The moved files read
    seven options, in nine places, where this plan said nine options.

### M1. The move (M, the files and their build)

* **What:** the 58 files moved with `git mv` to `lib/compiler/...`,
  keeping their directories (`lib/compiler/elab/unify.sml`);
  `lib/compiler/library.build` lists them in their order; `rune.build`,
  `runedoc.build`, `runeopt.build` and `runeisa.build` `use` it;
  `scripts/build-files.sh` and `scripts/gen-build-files.sh` follow the
  `use`, so the hosts' `.mlb`, `.cm` and Poly/ML scripts are still made
  from the build files; the options that `pipeline.sml` and
  `unitcache.sml` read become the library's settings; the Makefile, the
  check scripts and the docs follow the paths; D5's exception in
  `AGENTS.md`.
* **Done when:** `make check`; the seven builds of the compiler agree
  (`check-cross`); `rune --build rune.build --whole` is `bin/rune.rbc`
  (`check-reproducible`). The compiler's own bytecode changes, since its
  sources' paths are in it.
* **Touches:** every path in `docs/architecture.md`; `AGENTS.md`;
  rune-ide's generated MLB, which reads Rune's sources.

### M2. A library's names (M, about 300 SML)

* **What:** D1's (a): the export list of a library's build file in its
  MANIFEST (a column), `BasisManifest` choosing a library's files by its
  exports and what they need, and a program that loads the library seeing
  its exports only; `rune --basis-check --library` checks that an export
  is declared. Tests in `tests/lib`: a program that declares its own `Ast`
  beside the library.
* **Done when:** those pass, and the libraries of the REPL's branch that
  want one have an export list.

### M3. The compiler's state (M, about 400 SML)

* **What:** D2's (a): `CompilerState` in the library, where each of the
  about 205 `ref`s and tables registers with its initial value or a
  function that makes it again; `RuneCompiler.session` puts them back; a script in
  `make check` that lists the top-level `ref`s and tables of
  `lib/compiler` and fails on one not registered. D2's (b) as
  `RuneCompiler.isolated`, where there is a fork.
* **Done when:** a program that compiles the same text in two sessions
  one after the other gets the same bytes both times (a test), and the
  script passes.

### M4. `RuneCompiler` (L, about 1,000 SML)

* **What:** the API above on the REPL engine's session: Standard ML text
  and files, unit files and a unit's Mid with its basis, compiled or read
  into units; `run` through `Runtime.link`; `writeUnit`, `writeMid` and
  `writeProgram` through `UnitFile`, `UnitMid`, `Link` and `Emit`;
  diagnostics as data; the type at an offset. `lib/cache`, the frozen
  cache, takes `lib/compiler`'s units too (`make basis-cache`), so a
  program that uses the library does not compile 19,000 lines first.
  `tests/lib/compiler`: a program that compiles a string and runs it
  in-process, writes a `.rbu` and reads it back, writes a `.rbc` and runs
  it with `runevm`, compiles a unit's Mid from a cache entry, and gets its
  errors as data; on the hosts, the parts that need no `Runtime`
  (`test-lib-hosts`).
* **Done when:** those pass under the interpreter and `--jit=all`.

### M5. The clients (M, about 500 SML)

* **What:** the REPL's engine and session written on `RuneCompiler`;
  `rune --serve` on it and on `lib/json` and `lib/jsonrpc` (its own codec
  removed); the Basis's `Compiler.use` and `compile` filled by the library
  where a program links it (D6); `runedoc`'s elaboration of a library
  through it where that is simpler than what it does now.
* **Done when:** `make check`, the REPL's transcripts and
  `tests/repl-protocol` unchanged, `tests/serve` unchanged.

## What could go wrong

* **The merge of M0 is the larger part of the risk**: two branches that
  each changed `src/util`, `src/driver/main.sml`, `options.sml`, the
  Makefile and the Basis's MANIFEST, one of them after replacing the
  MANIFESTs and `sources.txt` by build files.
* **The cost of a client's compile**: without the frozen cache, a program
  that uses the library compiles the compiler with it, 4.5 to 6 s in units
  cold (incremental *M6, the third part as built*, and *M11, as built*).
* **A `ref` M3 misses** makes a session see what an earlier one left. The
  script of M3 is what guards it; the tests of M4 compile in two sessions
  for the same reason.

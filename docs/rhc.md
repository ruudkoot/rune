# rhc

rhc is a compiler of Haskell 98: the Revised Report of December 2002 with its
eighteen published errata applied. It is written in Standard ML and built by
Rune alone (`make bin/rhc`; `rhc.build`), and it shares Rune's compiler from
Mid on: a Haskell program is read, named, checked and desugared by rhc's own
front end into Core, a typed lazy language of rhc's, which Core to Mid lowers
to Mid, and from there Rune's passes, `Lower` and a target make the same
bytecode an SML program becomes, run by the same `bin/runevm`. How the parts
fit is in [architecture.md](architecture.md), *rhc*; the plan it was built to
is [plans/language/haskell98.md](plans/language/haskell98.md).

rhc lives in the build tree: `make install` and `make dist` carry neither it
nor its library.

## Running a program

```
bin/rhc Main.hs                    # check it and run it on Core's interpreter
bin/rhc Main.hs -- one two         # with the arguments getArgs gives
bin/rhc Main.hs -o prog.rbc        # compile it to register bytecode
bin/runevm prog.rbc one two        # and run that
bin/rhc --target=stack Main.hs -o prog.rbc && bin/runevm-stack prog.rbc
bin/rhc --typecheck-only Main.hs   # check it, and run nothing
```

A program is a file and the modules it imports. A module `M` is the file
`M.hs`, or `M.lhs`, a literate file, beside the first file given; failing
that, the library's module `M`. The first file's module is the program's,
which must be `Main` and export `main`, of a type `IO t` (5). A cycle of
modules is allowed and compiled as one unit (5.7 leaves it to the
implementation; D30).

`bin/rhc` is a script that runs `bin/rhc.rbc` on `bin/runevm` and gives it
`--share` (where the library is) and `--snapshot` (the library compiled
once, below). Run `bin/runevm bin/rhc.rbc` directly and both are yours to
give.

A run on the interpreter and a compiled program end alike: with status 0, or
the status `exitWith` gives, or, where the program meets a bottom (`error`,
a failed pattern, `undefined`, an uncaught `IOError`, a suspension forced
while it is evaluated), a line `rhc: bottom: KIND: MESSAGE` on standard
error after what it printed, and status 1. `getProgName` is the program
file's base name without its extension: the `.hs` file's on the
interpreter, the bytecode's when compiled.

`Int` is 63 bits wide on a 64-bit host, and its arithmetic is checked: an
overflow is an error, as 6.4 allows (D22). `Integer` is unbounded. A string
literal's list is made a cell at a time as it is read (D24).

## The snapshot, `--whole` and units

A program's compile would spend most of its front end on the library: the
Prelude's closure alone is fourteen modules. So `make bin/rhc` compiles the
library once, from a `Main` that imports every module of it, into a store:
the snapshot, `bin/rhc.layer`. Every check, run and
compile of `bin/rhc` takes the library's units from it, read only, and
reads, names, checks and desugars the program's own modules alone, a group
of its module graph at a time, each from the interfaces of those before it;
its Core is what `main` reaches of the units, which compiles to the bytes a
whole compile makes. At level 2 HsLint checks each unit after what it found
of the units before, the library's kept in the snapshot. Nothing is
written: there is no store of the program's own.

- `--whole` reads, checks and desugars the library as well, with the
  program, as the reference the snapshot is held to (`hs/snapshot/*` in
  [testing.md](testing.md)). The options that change how the library is
  read go whole too: `--names=greatest`, `--cycle-default=scc`.
- `--match=sestoft` and `--strings=whole` change the library's Core, so the
  snapshot holds none of their units and they are made at each compile.
- `--units FILE.hs -o OUT` compiles each group of the module graph as a
  unit kept in a store, `--store DIR`, and takes it from there at the next
  compile where everything it read of the units before it is as it was;
  `--layer DIR` adds a store read and never written, after `--store` and
  before the snapshot; `--show-units` says of each unit, and of the link,
  whether it was compiled or taken. With nothing edited every unit and the
  link are taken.
- A store keeps one configuration for each rhc and set of the options its
  entries depend on. `rhc --prune-store DIR` drops every configuration of
  another rhc, file by file as the store's own trim drops what it drops;
  make does it to `bin/rhc.layer` after each build of rhc, so the snapshot
  holds this rhc's entries alone.

How a unit is kept, what its usages hold and what its compile costs are in
[units.md](units.md), *rhc's units*.

## Options

`bin/rhc --help` prints them all. By what they do:

**What to do with a file.**

| Option | What it does |
|---|---|
| `FILE.hs` | check the program and run it on Core's interpreter |
| `-o FILE` | compile it to bytecode, through Mid, in place of running it |
| `-- ARG...` | the arguments of the program run on the interpreter, as `bin/runevm` takes them after its file |
| `--typecheck-only` | read and check it: names, fixity, kinds, types and classes; run nothing |
| `--desugar-only` | check it, desugar it to Core, CoreLint that, and run nothing |
| `--parse-only` | read the file and stop |
| `--print`, `--print-layout`, `--print-exact` | print it with every block in braces, by layout, or byte for byte from its tree |
| `--dump-tokens` | print its tokens after layout, one a line |
| `--dump-ast` | print its tree; `--no-spans` leaves out where each node is |

**The dumps,** each of a program read whole, the library with it:

| Option | What it prints |
|---|---|
| `--dump-names` | the exports, fixities and instances of the program of `FILE.hs...` and of the library, and its errors of names, sorted |
| `--dump-types` | the type of each top-level value of the program's modules |
| `--dump-evidence` | the checker's evidence records: each overloaded use's dictionaries, each binder's type |
| `--dump-derived` | the methods of the program's derived instances |
| `--dump-binders` | each local name of the program's own modules: a line for each binding site and use |
| `--dump-hslint` | the type HsLint's second inference gives each binding of the top level, and the defaults it chose; `--dump-hslint=library` the library's unsigned ones too |
| `--dump-iface` | each module's interface: its items' text and fingerprints |
| `--dump-usages` | what each unit reads of its imports |
| `--dump-after=STAGE` | what a stage makes: `read`, `desugar` (the program's Core), `coretomid` (Mid's text), `mid`, a pass on Mid, `lower`, `registers` or `stack`, or `all` |
| `--pass-stats` | the time and size of every stage, on standard error |

**Names and modules.**

| Option | What it does |
|---|---|
| `--names=least\|greatest` | the solution of a cycle's exports: the least fixpoint (the default) or the greatest; chapter 5 is met by either (D29) |
| `--cycle-default=module\|scc` | in a cycle of modules, each module's `default` declaration and Rule 2 at its end (the default), or the cycle's, an extension (D30) |
| `--dotted-names` | read a module name with dots, `Data.List`, as one, which Haskell 98's `modid` is not; module `A.B` is the file `A/B.hs` (D35) |
| `--by-interface` | with `--typecheck-only`, check each group of the program from the interfaces of the groups before it, the library's computed too |

**Checks.** `--lint[=N]`, or `RUNE_LINT=N`, sets the level: `off`, or 0
to 3, a bare `--lint` being 2, and 0 where neither is given. From 0
CoreLint checks the Core the front end made, and Mid's checks run from
their levels as in a compile of Rune's ([ir.md](ir.md), *Levels*); at 2,
the level every test runs at, HsLint checks the program a second time and
holds the checker's evidence and the Core to it; at 3 Core's text is
printed, read back and printed again after every stage. A refusal at any
of them is a bug of rhc's.

| Option | What it does |
|---|---|
| `--hslint-claims=FILE` | at level 2, hold HsLint's inference to a record's claims, lines of the dump's form; `RHC_HSLINT_FAULT=RULE` corrupts one, for the tests of each rule |
| `--hslint-rules` | print the name of each rule of HsLint's comparison |
| `--lint-rules` | print the name of each rule of CoreLint |

**Code and the interpreter.**

| Option | What it does |
|---|---|
| `-O0`, `-O1`, `-O2` | the level of Mid's optional passes (default 1) |
| `--target=T` | the bytecode: `registers` (the default) or `stack` |
| `--thunks=c` | suspensions in Mid by form C's primitives, the one form there is |
| `--match=M` | the order of a match: `report`, the Report's, a clause after another (the default), or `sestoft`, decision trees, for D34's measurement |
| `--strings=S` | a string literal's list: `lazy`, a cell as it is read (the default), or `whole`, for D24's measurement |
| `--fault=F` | a fault of Core to Mid made on purpose, for the tests of what catches it |
| `--steps=N` | stop the interpreter after N steps, a bottom |
| `--depth=N` | the deepest the interpreter's stack may go (default 10,000,000) |

**Units and stores.**

| Option | What it does |
|---|---|
| `--units` | with `-o`, compile a program of Haskell a unit at a time, kept in the store (above); of Core, each `--read-core` file a unit |
| `--store DIR` | with `--units`, the store a unit is kept in and taken from |
| `--layer DIR` | a store a unit is taken from and never kept in |
| `--show-units` | say of each unit whether it was compiled or taken |
| `--link=whole\|units` | with `--units` over Core, join the units' Core and compile what `main` reaches whole, or link each unit's code (the default) |
| `--desugar-units` | desugar a program a unit at a time and join the units, as a compile in units does, for its tests |
| `--prune-store DIR` | drop from the store `DIR` every configuration another rhc made |

**rhc itself.**

| Option | What it does |
|---|---|
| `--share DIR` | where the library is, `DIR/haskell98` (`bin/rhc` gives it) |
| `--snapshot DIR` | the store the library's units are taken from, read only (`bin/rhc` gives it) |
| `--whole` | read, check and desugar the library too, not take it from the snapshot |
| `--read-core FILE` | read `FILE` as Core text; given again, the files make one program |
| `--generate-core=SEED` | print a well-typed Core program made from `SEED` (D55) |
| `--identity` | print rhc's identity, a digest of its sources, which keys its stores |
| `--version` | print the version and the identity |
| `--help` | print the options |

`RHC_INSTRUCTIONS`, set, has rhc print the bytecode instructions a command
took on standard error.

## The library

The Report's libraries are in `share/rhc/haskell98`, its twenty modules in
the Report's own layout (D36): the Prelude as chapter 8 prints it, split
into `Prelude`, `PreludeList`, `PreludeText` and `PreludeIO`, and the
modules of chapters 12 to 27. Two modules are rhc's: `PreludeRuntime`, the
primitives the Report leaves to the implementation, and `PreludeEnum`, the
numeric enumerations the Prelude defines and Ratio uses, which chapter 5
does not let Ratio see where the Report puts them.
`pristine/` holds the code as the Report prints it; every place where rhc's
differs is an entry of `overlay.tsv`, with its ground: an erratum
(`errata.tsv`, all eighteen, each applied or said to be about prose), a
reading, a section of the Report or a decision of the roadmap (D37).
`LICENSE` says what was changed from the Report. A program cannot import
the modules chapter 8 keeps to the Prelude, `PreludeList`, `PreludeText`
and `PreludeIO`, nor rhc's own.

## Where rhc departs from the Report

rhc follows the text, the Report with its errata, unless the text is wrong,
contradictory, ambiguous, or conceded by the Report: a passage the Report
itself says implementations will not meet, advising programmers to avoid
the construct (D38, with the owner's decision of 2026-11-13, which struck
"cannot be implemented" as a ground). That every implementation does
otherwise is no ground. Each departure is a line of
`tests/hs/deviations.tsv`, its ground named and a test pinning what rhc
does:

| Ground | The departures |
|---|---|
| wrong | a line comment that ends the file with no newline (`lex.comment.line.eof`); a vertical tab in a line comment (`lex.any.linecomment`) |
| contradictory | 2.7's implicit close brace against 9.3's Note 3 (`lay.note3.implicit`); a decimal literal of non-ASCII digits, refused (`lex.int.unidigit`) |
| ambiguous | the column a vertical tab moves to (`lay.col.vt`); a file with no lexeme (`lay.first.empty`) |
| conceded by the Report | fixity met while parsing: `do a == b == c` (9.3's parse-error rule, `lay.parseerror.fixity`) and `let x = True in x == x == True` (chapter 3's meta-rule, `exp.parse.letnonassoc`), each refused at fixity resolution |

Where the oracles (GHC, Hugs, nhc98 and others) disagree on a test, or agree
against the text, `tests/hs/readings.md` says what the text says, what each
does and what rhc follows. Every statement of the Report is a row of
`tests/hs/conformance.tsv` with its status and the tests that hold rhc to
it (D53; [testing.md](testing.md), *rhc's tests*); what the Report leaves to
the implementation is decided there, row by row.

## Diagnostics

- An error of the program's is a line `FILE:LINE:COL: error: MESSAGE` on
  standard error, every one the program has, in the order of its modules'
  groups and, in a file, of the source, and status 1. A file that does not
  lex or parse gives one such line. Errors in the library are not shown.
- A command line rhc does not take is `rhc: MESSAGE` and `rhc --help says
  what rhc takes`, status 1.
- A bug of rhc's, a check that refuses what the compile made, is `rhc: lint
  after STAGE: ...` (HsLint's with `[RULE]`), or `rhc: error: ...` from a
  compile in units, status 1. A program the checker accepts and HsLint
  refuses is one.
- A bottom while running is `rhc: bottom: KIND: MESSAGE` (above).

## What rhc does not do

- Any language but Haskell 98: no extension of GHC's or Hugs', no Haskell
  2010, no hierarchical module names but by `--dotted-names`, which reads a
  file, and no module of a library but the Report's: no `Foreign`, no
  `IORef`, no concurrency.
- Optimise Core: `-O` sets the level of Mid's passes alone; the roadmap's
  Core simplifier and strictness (M23, M24) are not in rhc yet.
- Meet the rows of `tests/hs/conformance.tsv` whose status is `Planned`,
  each waiting on a named piece of work. rhc does not yet refuse a
  record's construction that omits a strict field, an update whose labels
  no one constructor has or that names a label twice (3.15), a class
  method's type that does not mention the class's variable, a fixity
  declaration in a class for what is not its method or given twice, an
  instance binding a method not in scope, or a type synonym exported as
  `S(..)`; nor give chapter 21's I/O errors of a full device, a failed
  `hClose` and block buffering.
- Keep a program's own units between compiles without `--units --store`,
  or read a dump against the snapshot: the dumps read whole.

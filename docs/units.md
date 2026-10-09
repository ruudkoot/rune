# Units

A program is compiled whole by default: every file of the Basis Library it
needs and every file it names are parsed, elaborated and translated into one
program, and the passes of [ir.md](ir.md) see all of it. That is what
production builds want, and it stays the default. This page is about the
other way, which the REPL, incremental builds and dynamic modules are built
on ([plans/incremental-compilation.md](plans/incremental-compilation.md)):
compiling a program a *unit* at a time.

## What a unit is

A unit is a file of top-level declarations, in the order the build gives
it: every file of the Basis Library that a program loads, every file of a
library beside it, and every file on the command line, each of them a unit
of its own. (A declaration typed at the REPL will be one too.) A unit is
compiled against what the units before it declared, which it sees as a
program sees the declarations above it, and nothing after it: incremental
compilation in the sense of SMLSC (Swasey, Murphy, Crary and Harper 2006),
and the order of the build is the order of the program.

`rune --units FILE...` compiles every unit in turn and links them into one
`.rbc`, which runs as the program compiled whole does: it prints the same,
exits the same, and an uncaught exception's trace shows the same frames
(`make check-units`, below). It is a different program all the same: no
function of one unit is inlined into another, nothing is shaken out, and so
its `--count` differs.

## Compiling a unit

The front end runs on one unit as on a program: its tokens are parsed with
the fixity the units before left, and its declarations are elaborated one
by one into the environment they left. Overloading and the literals are
settled at the end of each top-level declaration, as in a whole program;
the flexible records and the reports of the matches at the end of the
unit, where a whole program settles them at its end. So nothing of a unit
waits on the units after it, and a flexible record must be determined in
its own file: a program that leaves it to a declaration of a later file
compiles whole and not with `--units` ([language.md](language.md),
*Flexible records*).

The unit's declarations alone are then translated, and the passes run on
them with `Pass.whole` false: every top-level binding of a unit may be named
by a unit after it, so `Shake` does not run, `Workers` keeps every wrapper
and `Simplify` does not put in place a function that is called once, since
it is called once here only. Inlining within the unit, specialisation and
the rest are as in a whole program.

`Lower` knows the functions of the top level of the units before, and a
call of one is a known call (`CALLK`) as in a whole program: such a function
gets an id after the unit's own functions, and so does the next unit's top
level, which this unit's top level calls last, in tail position. Globals,
constants, labels, files and the frames of inlined functions are numbered
from 0 in each unit, in the order the unit first names them.

## Linking

`Link.program` puts the units' code together, in order. Each unit's
functions follow those of the unit before, so that function 0 is the first
unit's top level; its constants, labels, files and inlined frames follow
those before in the same way; and every global a unit sets gets the next
global's number. Every operand that names a function, a global or a
constant is then renumbered by the kind its instruction gives it
(`RegCodes.linked` and `Opcodes.linked`, which `make isa` writes from the
descriptions of the instruction sets): an own function or constant by the
unit's base, a function or global of another unit by its stamp, through the
unit that defined it. A unit's call of the next unit's top level becomes a
call of the next unit's first function, and the last unit's a call of a
function that returns.

So the units' top levels run in order, each tail-calling the next, and only
one of them is ever on the stack: the trace of an uncaught exception shows
one `<toplevel>` frame, at the declaration that raised it, as the program
compiled whole does.

## Unit files

`rune --units --emit-units DIR FILE...` writes each unit's file into
`DIR` -- `0000-initial.rbu`, ... in the order of the units, the Basis
Library's first -- and `DIR/units`, their names in order, beside the
program. A unit's file is its code as the target made it, numbered from 0,
and the linker's record of it ([bytecode.md](bytecode.md), *Units*).
`rune -o P.rbc $(cat DIR/units)` reads them back (`UnitFile.read`: every
instruction decoded by the layout `make isa` writes into `RegCodes` and
`Opcodes`, its labels and positions made again) and links them as above:
the program is the same bytes as the one `rune --units` wrote.

The units of one compile name each other by the compiler's stamps, which
are not the same from one compile to the next, so a unit's file says which
compile it came from, and the linker refuses to link units of two. Until
the cache (incremental roadmap, M6) gives them names that do not depend
on the compile, unit files are linked with the other units of their
compile only.

## Loading

A running program may take units in: `Runtime.load file` reads a unit's
file and `Runtime.link bytes` takes its bytes; each appends the unit to the
program and gives the function that runs its top level
([runtime.md](runtime.md), *Loading a program*, says what the VM does).
`tests/units/load.sml` is the whole of a loader:

```sml
val () = List.app (fn file => Runtime.load file ()) (CommandLine.arguments ())
```

`runevm load.rbc $(cat DIR/units)` loads the units of a program one by one
and runs each as it comes, and prints and exits as the program linked by
the compiler does (`make check-units`); its traces have the loader's frames
below the program's. What a loaded unit names of the units before it is
found among what those exported, by the compile they came from and their
stamps, so they must be loaded first and come from the same compile. A
unit's top level, which in a program linked by the compiler goes on to the
next unit's, here returns to the caller.

A unit loaded twice is two units: the second has globals of its own, and
the units loaded after it name the second's. So loading `a.rbu`, then
`b.rbu` twice, runs `b` twice against one `a`; loading `a`, `b`, `a`, `b`
runs each `b` against the `a` before it (`tests/units/twice`). An image of
the program carries the units loaded and what they export, so that a world
saved after loading some units goes on loading the rest when it is
restored (`tests/units/loadsave.sml`).

Each load makes the JIT forget the code it compiled, since its tables name
functions by number and a load renumbers nothing but grows them; the
functions that are hot are compiled again. That is cheap for a few loads
and will not be for a REPL that loads a unit per declaration, which the
incremental roadmap's M4 answers.

## Errors

A top-level declaration that fails to elaborate is reported at once and
undone: the environment it would have extended is left as it was, and
what else it put in the elaborator's state -- signatures, functors,
datatypes, overloadings, the flexible records and match reports waiting
for the end -- is put back as it was before it (`Elaborate.snapshot` and
`restore`). The declarations after it are then elaborated, so that a
compile reports every independent error, whole or in units, and fails at
the end of the front end without translating anything. A later
declaration that names what the failed one would have bound is reported
too, as unbound. The tables keyed by stamps only grow and are not put
back: no stamp is made twice, so what a failed declaration left in them
is never named again. A syntax error still ends the compile, since a file
is parsed whole before it is elaborated. This is the rollback the REPL
needs, a declaration at a time (Chapter 8 of the Definition).

## Checking it

`make check-units` (`scripts/check-units.sh`) compiles every program of
`tests/lang` and `tests/perf` whole and with `--units` at `-O0`, `-O1` and
`-O2`, the lint of every pass on, runs them as `tests/run-tests.sh` does,
and wants the same output on both streams, traces included, and the same
exit status. It is to separate compilation what `make check-levels` is to
the optimisations. Those programs are of one file; `tests/units`
(`tests/units/run.sh`) has programs of several, each built whole and in
units for both bytecodes and held to what it expects: functions, workers,
datatypes, exceptions, a functor and fixity used across files, a
structure shadowed by a later file, the trace of an exception raised in
the last file, the errors of two files, and a flexible record left to a
later file, which only the whole build accepts. Last, the compiler is
compiled in units and made to compile its own sources whole, which must
give `bin/rune.rbc` byte for byte.

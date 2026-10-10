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
settled at the end of each top-level declaration, as in a whole program,
and so are the flexible records, in the default mode of `--flex-records`
([language.md](language.md), *Flexible records*), a file's end ending one;
the reports of the matches at the end of the unit. So nothing of a unit
waits on the units after it. Under `--flex-records=program`, which settles
flexible records at the end of the program, a unit settles them at its
end: a program that leaves one to a declaration of a later file then
compiles whole and not with `--units`.

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
from 0 in each unit, in the order the unit first names them. No function of
a unit before is inlined into this one, nor specialised for it: what the
units after a unit see of it is its basis (below), which holds no code.

## The export basis

Once a unit is compiled, what the units after it need of it -- its
*export basis* (the incremental roadmap's D4) -- is written as bytes
(`UnitBasis.export`, `src/driver/unitbasis.sml`; [bytecode.md](bytecode.md),
*A unit's basis*): the environment it declared, its fixity directives,
signatures, functors and overloading, and the compiler's tables of what it
declared: each value's scheme, each exception's argument, each datatype's
constructors, what each opaque type stands for, the primitives some of its
values are, its functions that may be called by name, and the constructors
the REPL prints a datatype's values by. A functor's body is not written:
where it is in the unit's source is, and loading the basis parses the
source again for it, with the fixity of the unit's start, and checks that
the source is the one the basis was made from by its hash. A functor's
basis -- the environment it was declared in -- is written as what the unit
added to its start.

Then the unit's basis is *loaded* again in place of what its compile left
(`UnitBasis.load`; `Pipeline.unitThrough`): the compiler's tables go back
to the unit's start, the bytes are read, their names given names of the
session after everything before, and the unit's environment, fixity,
signatures, functors and tables are what the bytes say. So the units after
a unit see only its basis, whether it was compiled now or taken from the
cache, and a compile is the same bytes either way.

## Names

Everything a unit declared is named, in its basis and in its code, in a
way that does not depend on what was compiled before it (D3):

* a name that exists before any unit -- the built-in types, the initial
  environment -- is itself;
* one of the unit's own is a number, given in the order the writing of its
  basis meets them, so that the same declarations always get the same
  numbers;
* one of an earlier unit's is that unit's *identity* and its number there.

A unit's identity is its name and the hash of its basis, without what its
compile used of the session's counters. A unit whose body changed and whose
basis did not keeps its identity, so that what was compiled against it
stays valid. Loading a basis gives the unit's numbers a range of each kind
of name -- stamps, type names, type variables -- after the session's, and
registers the range, which is how a name of the session is written back as
a unit's identity and number.

A unit's code names globals and functions by *keys*, the same pairs
(`Link.key`): its own by the numbers its basis gave them, and those its
basis did not -- what no unit after it can name -- by numbers after those.

## Linking

`Link.program` puts the units' code together, in order. Each unit's
functions follow those of the unit before, so that function 0 is the first
unit's top level; its constants, labels, files and inlined frames follow
those before in the same way; and every global a unit sets gets the next
global's number. Every operand that names a function, a global or a
constant is then renumbered by the kind its instruction gives it
(`RegCodes.linked` and `Opcodes.linked`, which `make isa` writes from the
descriptions of the instruction sets): an own function or constant by the
unit's base, a function or global of another unit by its key, through the
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
Library's first -- and beside each its basis (`0000-initial.rbi`), and
`DIR/units`, their names in order, and `DIR/sources`, their sources. A
unit's file is its code as the target made it, numbered from 0, and the
linker's record of it ([bytecode.md](bytecode.md), *Units*).
`rune -o P.rbc $(cat DIR/units)` reads them back (`UnitFile.read`: every
instruction decoded by the layout `make isa` writes into `RegCodes` and
`Opcodes`, its labels and positions made again) and links them as above:
the program is the same bytes as the one `rune --units` wrote.

Units name each other by keys, so a unit's file links with those of the
units it names whichever compile made them; the linker wants each unit's
names among the units before it, and refuses one that names another.

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
found among what those exported, by their identities and numbers, so they
must be loaded first. A
unit's top level, which in a program linked by the compiler goes on to the
next unit's, here returns to the caller.

A unit loaded twice is two units: the second has globals of its own, and
the units loaded after it name the second's. So loading `a.rbu`, then
`b.rbu` twice, runs `b` twice against one `a`; loading `a`, `b`, `a`, `b`
runs each `b` against the `a` before it (`tests/units/twice`). An image of
the program carries the units loaded and what they export, so that a world
saved after loading some units goes on loading the rest when it is
restored (`tests/units/loadsave.sml`).

A load grows the JIT's tables and keeps the code it compiled: compiled
code reads where the tables are when it runs, so they may move
([runtime.md](runtime.md), *Loading a program*). A REPL that loads a unit
per declaration pays for its compiler and not for the JIT again
([repl.md](repl.md)).

## The cache

A compile in units keeps what it made of each unit -- its basis and its
code -- in a cache, and a compile after it takes a unit from there rather
than compiling it again where nothing it depends on changed (`UnitCache`,
`src/driver/unitcache.sml`; the incremental roadmap's D14):

* the cache is a directory: `--cache-dir DIR`, else `$RUNE_CACHE` (empty:
  none), else `.rune` beside the first input; `--no-cache` compiles every
  unit; `--explain-rebuild` says of each unit whether it was taken from the
  cache or why it was compiled; `--verify-cache`, or `RUNE_VERIFY_CACHE`
  set and not empty (for the REPL's `use`, which takes no flags), compiles
  each unit the cache has too, and fails where the cache's is not the same
  bytes as what compiling it gives;
* in it, a directory per *configuration*: the hash of the compiler's
  identity (`Config.identity`, a hash of the compiler's sources, which
  `scripts/gen-build-files.sh` writes), the versions of the files, the
  instruction set, and the options that change what the compiler makes
  (`-O`, `--passes`, `--int-bits`, `--fuel`). A compiler built from other
  sources, or another level, finds none of another's entries, and two
  configurations live side by side;
* in that, a directory per *key*, the hash of the unit's name, its source
  and whether it may use `_prim`; a file of the library is named by its
  place in the library (`lib/basis/list.sml`), so that a cache follows the
  library where it is moved, and a unit taken from the cache names its
  source in its code's files where it is now -- its own, and those of the
  functors' bodies it applied, which an entry keeps with the unit each is
  the source of (S56);
* in that, an entry per set of *usages* the unit was compiled with: every
  name its compile looked up -- values, types, structures, signatures,
  functors, and the fixity of every identifier it parsed (`Usage`) -- with
  the unit that bound the name then (`UnitBasis.binders`; none for the
  initial basis). Overloading resolved at a type is a usage too, of the
  type's name (`UnitBasis.stableName`), which the unit that registered the
  type's overloading binds: `widestring.sml` registers it for a type
  `widechar.sml` declares, and a unit that writes a wide string at
  `WideCharVector.vector` uses it without naming `WideString` (S28 of
  `tests/incremental/SCENARIOS.md`). A name is recorded only where what was found is the
  binding the session had for it, and not one of the unit's own or of a
  scope in it: a functor's parameter named `Array` uses no `Array` of the
  units before. An entry serves a compile where every one of its usages
  holds: each name is bound by the same unit, whose identity is its
  basis, so the name means the same and the compile would be the same.
  So a unit is compiled again where a unit whose basis it used changed, or
  a name it used is bound by another unit -- one inserted before it that
  shadows it -- and not where a unit it did not use changed, was inserted,
  removed or moved; and a unit whose body changed and whose basis did not
  keeps its identity, and the units that used it keep their entries: the
  cut-off;
* a functor's body is elaborated again at each application, in the basis
  of its declaration, as it was parsed there: what its names were bound to
  and the fixity it had are the functor's as much as its text is. So a
  unit that declares a functor has in its basis, and so in its identity,
  the unit that bound each name its compile looked up, and a unit that
  applies one of its functors is compiled again where one of them changed,
  though it names none of them and another unit may bind them where it is
  (S49 to S51);
* in the REPL, what a declaration of a file used echoes is compiled with
  it: two usages more say what that was compiled by, `echo on` whether it
  echoed at all (the print depth was above 0) and `p KEY` whether a printer
  was installed for the type `KEY` names (`Compiler.addPrettyPrinter`),
  and each holds where the REPL decides the same now (S53, S54);
* an entry whose code names a unit the session has not -- one its usages
  should have found changed -- is no entry, and the unit is compiled
  rather than the link finding nothing to take the name from;
* an entry keeps the warnings its compile gave, which a compile that takes
  it from the cache gives again;
* an entry is one file, its usages, warnings, basis and code with the hash
  of them, written under a name of its own and renamed into place, so that
  two compiles at once never see half of one. One that cannot be read, or
  does not hold what its hash says, is no entry, and the unit is compiled
  and the entry written again. A cache that cannot be written is one that
  is not there. Nothing in a key is a time.

**Fingerprints** (GHC's rule; the incremental roadmap's M6, the third
part). A usage keeps, beside the unit that bound the name, the
fingerprint of what the name named: the hash of an entry -- a value's
scheme and where it is from, a type's definition with its constructors and
realisation, a structure's entries, a signature, an identifier's fixity --
with every name in it written by its unit's name and the path that reaches
it there (`a.sml:A.shape`, `a.sml:sig:SHAPE.area`), so that a change under
a name changes every fingerprint that mentions it, and a change beside it
none. A usage holds where its binder is the same unit, or where what the
name names now has the same fingerprint. A functor, an overloading and the
REPL's settings hold by their binder alone.

So a unit whose usages hold may have been compiled against a unit that has
changed since -- a value added to `a.sml` changes its identity, not what
`b.sml` used of it. Its entry is then loaded against the unit of the same
name that is there now: the cache keeps, by each unit's identity, the
path to each of its names (in `units/` of the configuration's directory),
and each name of the old unit the entry's basis and code name is read by
its path in the old and found by the same path in the new. Where one has
no path, or none in the new unit, the entry is a miss and the unit is
compiled. An entry whose usages hold by their binders is taken before one
that needs this. `--explain-rebuild` says "from the cache X, across A
changed". So S3 of `tests/incremental/SCENARIOS.md` compiles the unit that
used the changed type and those after it whose usages changed, and S4,
a value added, the changed unit alone.

The cost is precision, not correctness, where a usage holds only by its
binder: every unit that applies a functor of a changed unit, or resolved an
overloading one registered, is compiled again.

**One program of the units' Mid** (`--units --whole`; the incremental
roadmap's M7 and D6). A compile in units links its units' code; with
`--whole` it makes one program as a whole-program compile does. Each unit's
Mid -- what `ToMid` made of it, before the optional passes, with the
datatypes its types name and its functions' names, which the next unit's
compile does not keep -- is written with its names by key, as a basis
writes them (`UnitMid`), kept in its cache entry, and read back as the
session names it, whether the unit was compiled or taken from the cache;
the units' Mid is concatenated, renumbered canonically (`MidCanon`: every
name by where it first appears), and the passes of a whole program run
over it before `Lower` and the target. A whole-program compile renumbers
its Mid the same way, so the two are one program and the same bytes:
`check-units` builds every program of `tests/lang` and `tests/perf` both
ways, through the cache and from it, `check-levels` at both levels, and
`check-cross` the compiler (S42 of `tests/incremental/SCENARIOS.md`).

**The frozen Basis Library** (D8): `make basis-cache`, part of `make all`,
compiles every unit of `lib/basis` once, for each bytecode, into
`lib/cache`, which `make install` installs read-only beside the library. A
compile reads it after its own cache and never writes it, so that a
program's first compile takes the Basis Library's units from there where
their usages hold, which they do but for the seals of structures the
program does not name.

**`use`** in the REPL ([repl.md](repl.md)) takes a file's declarations
from the cache the same way, each a unit named by the file and its place
in it, kept in `$RUNE_CACHE`, else `.rune` beside the file: a file used
again links its units from there, its top level run again with globals of
its own.

`make check-units` builds every program in units without the cache, then
through a cache all the programs share, and again from it, every unit
taken from there, and wants the same bytes three times; `tests/units`
does the same for its programs of several files; `make test-incremental`
runs the scenarios of `tests/incremental/SCENARIOS.md` it can be held to.

## The graph

`rune --deps FILE...` puts files in an order where each comes after the
files that declare the modules it uses (`Deps`, `src/driver/deps.sml`; the
incremental roadmap's M8 and D15), and `--deps-dot` gives the graph in DOT,
each file to the files it needs. A file declares the structures,
signatures, functors and top-level type abbreviations of its top level;
it uses the first structure of a long name (`A` in `A.B.x`), a signature's
or a functor's name, and a type named without a structure, where nothing in
scope binds it -- a structure of its own, a functor's parameter, a
signature's specification. The order keeps the order given wherever the
uses allow it: the compiler's own sources in the order of `sources.txt`
come back as they are, and in any order as an order it builds in.

The order is the files' only where each file keeps a discipline (CM's): its
top-level declarations declare structures, signatures, functors, type
abbreviations or (the Basis Library's) overloading, and none declares a
value, a function, an exception, a datatype -- whose constructors are
values -- or a fixity, or opens a structure, because a use of a value or of
an operator names no module, and the analysis cannot see it. A file that
breaks it is named, with the line; so are a name two files declare and a
cycle. Inside a structure anything goes, but a name a structure `open`ed
may bring in is counted as a use where a file of the group declares it,
which the analysis cannot tell apart.

**An entry point.** With `-I DIR`, the one input is a program's entry
point: the `.sml` files of its directory and of each `-I DIR` are analysed,
and those its uses reach -- the files declaring what it names, and those
they need -- are compiled before it, in the graph's order. A file that
breaks the discipline is none of them; where it declares a module the
program names, the compiler says so.

**The Basis Library's MANIFEST** says what each of its files provides and
requires (`lib/basis/MANIFEST`), and `rune --basis-check` checks both
columns against the sources: the requires column is what `Deps` derives.

## Dynamic modules

A program can load a module while it runs and use it through a signature
alone (the incremental roadmap's M9; D17 and D18):

```sml
(* the program, compiled against SHAPE alone *)
structure S = _dynamic "impl.rbu" : SHAPE
val () = print (S.name ^ "\n")

(* the module, compiled to impl.rbu: rune --units --emit-units DIR shape.sml impl.sml *)
_export structure Impl : SHAPE = struct ... end
```

Both sides agree on the signature's ABI: a slot for each value and
exception it specifies -- its values and exceptions by name, then its
structures', by name, recursively -- the tags of each datatype it
specifies in the order of its specification, which the module's datatype
of that name is given whatever order it declares its constructors in, and
abstract types that stay abstract to the program. Its fingerprint is the
hash of what the signature's specifications say, every type named by its
unit's name and path (`UnitBasis.fpSigma`): a program and a module compiled
against one signature, from the same library, agree on it.

When the program reaches the declaration, `RuneDynamic.load` loads the
unit (`Runtime.load`), runs its top level -- which ends by handing its
slots and the fingerprint to `RuneDynamic.export` -- and gives the program
the slots, where the fingerprints agree, or raises `Dynamic.Mismatch`
naming both. The module's code names what it uses of the program's units by
their identities, which a program linked from units keeps (*The units
section of a program*, [bytecode.md](bytecode.md)): so a program compiled
whole, whose units are one, cannot load a module, and is refused one at
compile time. Two modules compiled against one library share its types
with each other and with the program. `Dynamic.load file` is the untyped
form, for a unit that registers what it offers through a structure of the
program. `tests/dynamic/run.sh` (`make test-dynamic`) is each of these.

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

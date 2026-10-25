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

## Source modes

A source is read in a *mode* (`Source.mode`; the utf8 roadmap's D1): the
default, or Unicode text in an encoding, UTF-8 or Latin-1. A mode is a
file's and not the compile's. A unit's comes from:

* its build file's annotation, `ascii`, `unicode` (or `unicode=utf8`) or
  `unicode=latin1` ([build.md](build.md), *Annotations*); else
* the command line, `--unicode` or `--unicode=utf8`, and
  `--unicode=latin1`, the last of them given; else
* the default.

The encoding is taken only after an `=`: `--unicode latin1` names an input
file `latin1`, and one that cannot be read is answered "cannot read latin1
(did you mean --unicode=latin1?)". The Basis Library and the libraries
beside it (`--library`) are read in the default, whatever the command line
says. `Compiler.compile` reads in the default, and `Compiler.compileIn`
in the mode it is given, by the annotations' names. The REPL reads the
files it uses -- by `use`, `:reload` and its command line -- in the mode
of `rune-repl --unicode[=ENC]`, and what is typed as UTF-8 under
`--unicode`, whatever the files' encoding.

A unit's mode is in its key where it is not the default (*The cache*), so
that a unit read in one mode is not taken for one read in another (S63 of
`tests/incremental/SCENARIOS.md`).

The modes differ in what a literal holds ([language.md](language.md),
*Strings*). By default it holds ASCII alone, and `\U` is refused. Under
`--unicode` a raw character above 127 means its code point, which only
the wide types take, and `\U` is taken. Under `--unicode=latin1` the file
is Latin-1, made UTF-8 as it is read, and a raw character is its own byte;
a file that holds the UTF-8 of a character is refused as one that looks
like UTF-8. What else a source may hold raw is the same in every mode
(*Source text*).

The modes differ too in what a name holds ([language.md](language.md),
*Identifiers*). By default an alphanumeric identifier is ASCII. Under
`--unicode` and `--unicode=latin1` it may hold the letters, marks and
digits of `lib/unicode`'s identifier profile, in NFC, and the compiler
warns of what UTS #39 finds in the names unless `--no-unicode-lints`
is given. A library is read in the default, so what it exports is
ASCII, and a unit in any mode can name it (*A library's build file* of
[build.md](build.md)).

## The export basis

Once a unit is compiled, what the units after it need of it -- its
*export basis* (the incremental roadmap's D4) -- is written as bytes
(`UnitBasis.export`, `lib/compiler/driver/unitbasis.sml`; [bytecode.md](bytecode.md),
*A unit's basis*): the environment it declared, its fixity directives,
signatures, functors and overloading, and the compiler's tables of what it
declared: each value's scheme, each exception's argument, each datatype's
constructors, what each opaque type stands for, the primitives some of its
values are, its functions that may be called by name, and the constructors
the REPL prints a datatype's values by. A functor is compiled to a
function (*Functors compiled once* in [ir.md](ir.md)), and its entry is
its signature -- its parameter's, and the summary its declaration left,
the environment the body gave and the type names it made, by which every
application is typed (rule 54; [plans/functors.md](plans/functors.md)) --
and the global of its function, which the units that apply it call:
nothing of its body, so that a unit whose functor's body changed and whose
signature did not keeps its identity, and the units that apply the
functor are taken from the cache. The summary's values and exceptions are
named by placeholders, which are no names of the unit's. A functor marked
to be inlined ([build.md](build.md), *Inline functors*) has its
function's Mid written too, its positions in the unit's own source by
nothing but that, and a unit that expands it depends on it (the usage
`inl F`). The tables give each instance of a body's datatype the layout
the body fixed (`Ty.pinned`), unless the unit expanded the application
that named it (an application of a functor the unit declares or marks,
*The expansion* in [ir.md](ir.md)), whose instance is laid out from its
realised types. Until functors-units' M7 a functor's body was parsed
again from the source on loading, and elaborated again by each unit that
applied it, which then depended on the unit that declared it and on what
the body's names were bound to.

Static analysis can also record lexical origins in a version-7 basis:
source ranges for bindings and the specification/implementation relation
introduced by signature matching. These origins are separate from value,
exception and generative type stamps. Exception replication shares a
runtime exception identity while introducing a distinct lexical name.
Analysis
freezes query data before replacing a unit's mutable annotations; replay
restores origins together with its checked basis. The batch driver and
analysis share build-scope visibility through `CompilerBuildContext`.

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

A unit loaded where a unit of its identity is loaded already -- a file the
REPL uses again, the same text against the same units -- is loaded and
linked under its identity with `~2` after it (`~3`, ... where that is
taken too; `UnitBasis.unused`), so that its globals are its own and what
named the first unit's still does; its name is the same, and its entry in
the cache keeps its basis's identity (S38, S74).

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
`lib/compiler/driver/unitcache.sml`; the incremental roadmap's D14):

* the cache is a directory: `--cache-dir DIR`, else `$RUNE_CACHE` (empty:
  none), else `.rune` beside the first input; `--no-cache` compiles every
  unit; `--explain-rebuild` says of each unit whether it was taken from the
  cache or why it was compiled; `--verify-cache`, or `RUNE_VERIFY_CACHE`
  set and not empty (for the REPL's `use`, which takes no flags), compiles
  each unit the cache has too, and fails where the cache's is not the same
  bytes as what compiling it gives -- an entry whose usages hold by binder;
  one that holds by fingerprint alone names the old unit it was compiled
  against, and is compiled again rather than compared (issue 15); `RUNE_VERIFY_DUMP=DIR` writes the
  entry of each unit that does not verify, and what compiling it gave, to
  DIR (`NAME.cached.pickle`, `NAME.fresh.code`, ...) to compare. A unit's
  code lists the names it uses of other units in the order of their places
  in the code, so a unit compiled in two sessions is the same bytes,
  whatever order the sessions loaded those units in (S59); `--pass-stats`
  with `RUNE_MEM` set says after each unit how many bytes its basis and
  its code took and how much the heap holds, collected;
* in it, a directory per *configuration*: the hash of the compiler's
  identity (`Config.identity`, a hash of the compiler's sources, which
  `scripts/gen-version.sh` writes), the versions of the files, the
  instruction set, the options that change what the compiler makes, and
  the probe of its hash (`Pickle.probe`, the digest of a fixed text): the
  hash's values depend on the width of the `Word` of the host that built
  the compiler, so a compiler whose hash differs has a configuration of its
  own, never takes another's entries, and `--explain-rebuild` says so when
  it finds only those (S71); a basis says the probe too, and one of another
  is not read (S70). The configuration's `units/about` lists what it is
  made of
  (`-O`, `--passes`, `--int-bits`, `--fuel`). A compiler built from other
  sources, or another level, finds none of another's entries, and two
  configurations live side by side;
* in that, a directory per *key*, the hash of the unit's name, its source
  and whether it may use `_prim`, and of an input file's unit the settings
  that hold for the input files and not the libraries (`--default-type`,
  `--or-patterns`; S62; and `--no-unicode-lints`, since an entry keeps
  the warnings it leaves out; S64), and of any unit its mode where it is not the
  default (*Source modes*; S63); a file of the library is named by its
  place in the library (`lib/basis/list.sml`), so that a cache follows the
  library where it is moved, and a unit taken from the cache names its
  source in its code's files where it is now -- its own, and those of the
  bodies of the functors marked to be inlined that it expanded, which an
  entry keeps with the unit each is the source of (S56);
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
* a functor is compiled once, in the unit that declares it, and a unit
  that applies it calls its function and uses its signature alone (the
  usage `fun F`): what the body's names were bound to and the fixity it was
  parsed with are the declaring unit's, which is compiled again where they
  change (S49 to S51), and the units that apply the functor are not, nor
  where a functor its body applies changes body (S66). A functor marked to
  be inlined is the exception: a unit that expands its application uses
  its function's Mid too (`inl F`). Until functors-units' M7 a unit that
  applied a functor elaborated a copy of its body, and used the units of
  the names the body looked up and of the functors it applied in turn
  (the usage `funat IDENTITY`);
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
* an entry is one file, its usages, warnings, basis, the basis's identity
  (which loading takes from it rather than hashing the basis again) and
  code with the hash of them, written under a name of its own and renamed
  into place, so that
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
name names now has the same fingerprint and the unit that bound it then is
not in the session: the entry's code names that unit's globals, which the
unit of its name there now takes over (below), while a unit still there
keeps them -- in the REPL, where a file used again binds the name now, or
another unit than the first does (S75). A functor's fingerprint is its
signature, its parameter's and its summary's (S65, S66); a functor with no
summary, an overloading and the REPL's settings hold by their binder
alone. A fingerprint is of what the name names at the unit's start, as
its binder is, though the unit declares another of the name before its
usages are worked out (S72); it says which type variables admit equality,
and the arity and equality of a signature's own type names (S68, S69).
A fingerprint is the hash of tokens -- a tag for each kind of node, a
length before each list and string -- rather than of text; a structure's,
a signature's and a functor's is the hash of their entries' names and
fingerprints, and an entry of a structure a usage names is worked out once
a session, as the usage of it is, by its binder and name. A recursive
group of datatypes is hashed as one, its members named in it by their
units' names and paths, so that each member's fingerprint is the same
whichever is asked for first (functors-units, M4). `--pass-stats=hash` counts what is hashed,
and where ([ir.md](ir.md), *What a compile in units hashes*);
`bin/rune-incremental soundness` checks that a change to how fingerprints
are worked out tells apart all that the old way did
(`tests/incremental/SCENARIOS.md`).

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
binder: every unit that resolved an overloading a changed unit registered,
or expanded an application of a functor marked to be inlined there whose
Mid changed, is compiled again; its basis is the same where what it used
is, and the units after it are taken from the cache. A unit that applies
a functor of a changed unit whose signature did not change is taken from
the cache (S65).

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

**The frozen libraries** (D8): `make basis-cache`, part of `make all`,
compiles every unit of `lib/basis` and `lib/compiler` once, with the
compiler library's Unicode and JSON dependencies, for each bytecode, into
`lib/cache`, which `make install` installs read-only beside the library. A
compile reads it after its own cache and never writes it, so that a
program's first compile takes the Basis Library's units from there where
their usages hold, which they do but for the seals of structures the
program does not name.

The public [compiler library](lib/compiler/README.md) writes units with
`.rbi` checked-basis, `.rbm` Mid and `.rbs` source companions. The source
companion is a `Pickle` encoding: `RCS`, version 2, then strings containing
the source filename, source-mode name, decoded source text, unit-code
hash, basis hash and Mid hash, with no trailing data. Text is UTF-8 in
Unicode modes. Readers check the artifact hashes, source hash and mode
against the checked basis; this detects mismatched or partially published
sets. Each file is replaced atomically and the source record is published
last. This is not a multi-file filesystem transaction.

The source companion is an API addition; ordinary CLI units remain
compatible when their matching original source is available. A unit read
without Mid can be compiled against and executed but cannot be exported
through `writeMid`. The [compiler-library roadmap](plans/compiler-library.md) records the remaining
session and client-migration acceptance gates.

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
files that declare the modules it uses (`Deps`, `lib/compiler/driver/deps.sml`; the
incremental roadmap's M8 and D15), and `--deps-dot` gives the graph in DOT,
each file to the files it needs. A file declares the structures,
signatures, functors and top-level type abbreviations of its top level;
it uses the first structure of a long name (`A` in `A.B.x`), a signature's
or a functor's name, and a type named without a structure, where nothing in
scope binds it -- a structure of its own, a functor's parameter, a
signature's specification. The order keeps the order given wherever the
uses allow it: the compiler's own sources in the order of `rune.build`
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
requires (`lib/basis/MANIFEST`). It is made from the library's build file
(`lib/basis/library.build`, docs/build.md) by `rune --basis-index DIR`:
the provides column is what a file declares and the requires column what
`Deps` derives, so neither is written by hand.

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

Both sides agree on the signature's ABI: a structure's record, as a
functor's argument and result are (functors-units' D3) -- a slot for each
value and exception it specifies, by name, then a record of its own for
each of its structures, by name, in a slot -- the tags of each datatype
it specifies by its constructors' names, as every datatype's are, and
abstract types that stay abstract to the program. Its fingerprint is the
hash of what the signature's specifications say, every type named by its
unit's name and path (`UnitBasis.fpSigma`), and of the records' form: a
program and a module compiled against one signature, from the same
library, agree on it (`tests/runner/scenarios.sml`'s `nested`). Until
functors-units' M7 the record was flat, its substructures' slots in its
own, and a module's datatypes were numbered in the signature's order.

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
program. `tests/dynamic/run.sh` (`make test-dynamic`) is each of these. A
virtual module (`structure X = _virtual : SIG`, [build.md](build.md),
*Virtual modules*) is the same boundary inside one program, its
implementation chosen by the build file.

## Parallel builds

`rune -j N` compiles the units of a build in up to N processes at once
(the incremental roadmap's M11, `Parallel`), with the cache as the way
they hand units on, so it wants the cache. The parent goes through the
units in order as a build by one process does, each through the cache.
Before each unit it starts a child for every unit after it that will
likely be compiled -- one the cache has no entry of, or one that needs a
unit compiled in this build -- whose units before it are done, and whose
text is big enough to be worth a process (`RUNE_PARALLEL_MIN` bytes, 16384
if not set). A unit the parent reaches and misses it compiles itself,
unless a child has it, whose end it waits for. A unit needs the units
before it that declare a name it uses (*The graph*; a Basis file by its
MANIFEST); a unit that breaks the discipline, and an `always` file of the
Basis, is needed by every unit after it. `RUNE_PARALLEL_DEBUG` set prints
each child's start and end.

A child is a fork of the parent at the unit it was started at, so it has
the parent's basis without reading it again. It goes on through the units
its own unit needs, which the cache has, skips the others, compiles its
unit into the cache and ends. What the build gives is what the parent's
pass through the cache gives, which is a build by one process: an entry
that a child compiled in a basis without some unit is one whose usages
the parent checks, and compiles again where they do not hold. So `-j`
changes how long a build takes and nothing else -- the program, the
warnings, the errors, and what `--explain-rebuild` prints, in the units'
order (S58). `make check-reproducible` (the oracle `reproducible` of `tests/runner/oracles.sml`)
holds the compiler to one set of bytes over eleven builds: in units and
whole, without the cache, through a cold cache and warm, by one process and
by several, and from a copy of its sources in another directory; the whole
ones are `bin/rune.rbc`.

On Rune's own builds `-j` gives no speed-up (the incremental roadmap,
*M11, as built*): a unit compiles in tens of milliseconds, the compiler's
units have a critical path of almost half their work, and under every
build is the parent's pass through the cache, which a child cannot share.

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

`make check-units` (the oracle `units` of `tests/runner/oracles.sml`) compiles every program of
`tests/lang` and `tests/perf` whole and with `--units` at `-O0`, `-O1` and
`-O2`, the lint of every pass on, runs them as `bin/rune-suite` does,
and wants the same output on both streams, traces included, and the same
exit status. It is to separate compilation what `make check-levels` is to
the optimisations. Those programs are of one file; `tests/units`
(`tests/units/run.sh`) has programs of several, each built whole and in
units for both bytecodes and held to what it expects: functions, workers,
datatypes, exceptions, a functor and fixity used across files, a
structure shadowed by a later file, the trace of an exception raised in
the last file, the errors of two files, a flexible record left to a
later file, which only the whole build accepts, and functors applied to a
structure of an earlier file (a fixture's
`flags`, the compiler's flags in each of its builds). Last, the compiler is
compiled in units and made to compile its own sources whole, which must
give `bin/rune.rbc` byte for byte.

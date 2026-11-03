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
settled at the end of the context `--overloading` names (by default each
declaration at structure level), as in a whole program; the flexible
records at the end of each top-level declaration, in the default mode of
`--flex-records` ([language.md](language.md), *Overloading*, *Flexible
records*), a file's end ending one; the free type
variables where the topdec ends, or at the end of the unit under
`--free-tyvars=later` and `later-monotype` (*Free type variables*); the
reports of the matches at the end of the unit. So nothing of a unit waits
on the units after it. Under `--flex-records=program`, which settles
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
`inl F`), by the hash kept beside it: of the Mid, of what the copies take
of the globals it names, and of its lines, of which the basis keeps only
the hash, so that a basis written again from what it loads as is the same
bytes. A function marked to be inlined ([build.md](build.md), *Inline
functions*), and every function that only applies a primitive to its
parameter, has its Mid written too, as the expansion leaves it, with the
functions of the unit it calls while the group is under 400 Mid nodes,
the schemes of the unit's globals it names that nothing else types (a
copy's own), and its positions in another unit's source by that unit's
name; a later unit that names it copies it (functors-units' M10), and
depends on it by the usage `inlv NAME`. The tables give each instance of a body's datatype the layout
the body fixed (`Ty.pinned`), unless the unit expanded the application
that named it (an application of a functor the unit declares or marks,
*The expansion* in [ir.md](ir.md)), whose instance is laid out from its
realised types.

In a unit's signatures and functors, an environment that is a structure
of a signature written before, renamed, is a reference to it
(functors-units' M11; `UnitBasis.version` 14). The reference gives the
signature by its unit -- an earlier one, or this one, whose signatures
come before its functors -- and its name, the path in it, and the
renaming: the image of each of the structure's own type names, and its
values' stamps and whether they are global where they are not the
structure's own. The structure is found as a fingerprint finds one it
names by reference (*Fingerprints*, below), or among the unit's own
signatures written before by its first value's stamp; a functor's
result, among the structures its parameter is written as references to.
A walk checks that reading the structure's names again makes the
environment -- the same type variables and type names but the
structure's own, the same constructors and exceptions -- and where it
does not, the environment is written whole. MLton's bases are 22 MB,
from 222 MB. A unit loaded against another of the same name (below)
reads a reference into that unit's signature, as it reads its other
names, by their paths: its usages hold, so the structure is the same but
for its names. Until functors-units' M7 a functor's body was parsed
again from the source on loading, and elaborated again by each unit that
applied it, which then depended on the unit that declared it and on what
the body's names were bound to.

Static analysis can also record lexical origins: source ranges for
bindings and the specification/implementation relation introduced by
signature matching. These origins are separate from value, exception and
generative type stamps. Exception replication shares a runtime exception
identity while introducing a distinct lexical name. Origins are written
to a sidecar, apart from the basis and from every hash: `UnitBasis.export`
gives it beside the bytes, `UnitBasis.load` reads it beside them in the
order the basis meets them, and a comment that moves a span moves no
identity. A batch compile records none, so its sidecar is empty. The one
position a basis keeps is that of a body kept for a later unit to copy,
whose line table the copy's code holds: its hash is in the usages `inl` and
`inlv` (*The cache*), so a comment above a marked function is a rebuild of
what copied it. Analysis freezes query data before replacing a unit's
mutable annotations; replay restores origins together with its checked
basis. The batch driver and analysis share build-scope visibility through
`CompilerBuildContext`.

**Layers** (the build-system roadmap's D1). A basis is two layers, each its
own bytes, read side by side:

| Layer | Holds | Read by |
|---|---|---|
| static | fixity, names, schemes, type names, constructors and how they lie, a primitive's name, signatures, a functor's parameter and summary, an overloading's operators | a compile, an analysis |
| ABI | a value's and an exception's stamp and flags, a reference's stamps and flags, a functor's global, bodies to copy and their hashes, an overloading's targets, and by name the type a value has in the IRs, primitives, globals that are others, functions known by name, a datatype's table, a realisation, a layout a body fixed | a compile |

The static layer is written whole before the rest of the ABI layer, and
nothing in it depends on the other: an own name is numbered as the static
layer meets it, and an import by its place among the static layer's. So a
compile and an analysis of a unit, which elaborate it alike, write the same
bytes of the static layer, and only a compile has much to write in the other
(`make test-layers`). A type name's realisation is the ABI layer's, whole: a
client's code reads it (`Ty.convert`, `Ty.shapeOf`) and holds what it is made
of, a word, an int, a pointer, so a key that held its layout alone took a
client across `int` made `word` behind `:>`, and the link refused the two
units. How a constructor lies is
the one fact of a layout elaboration reads, for a parameter's open
constructor (`Elaborate.descriptors`), so the static layer holds it.

Each export, at every depth, has a hash of the static layer and a hash of both
(`UnitBasis.exportHashes`): a fingerprint (*Fingerprints*, below) worked out
without what a client's code is built on, or with it. A compile reads both
layers, so a usage holds the second and a key of the static layer alone would
take a client across a function made a closure, an opaque type's new
realisation or another exception's name (E17). The header holds the hash of
the static layer with its imports' static fingerprints, beside the identity's.

`RUNE_LAYER_DUMP=DIR` writes each unit's exports and hashes to a file of `DIR`
as a unit is bound, in a compile or an analysis, and `RUNE_STATIC_LOAD` makes a
load where no code is made enter nothing of the ABI layer in the compiler's
tables, which is what an analysis must not need.

**Codecs** (the build-system roadmap's D21 and M5). What a basis says of a
binding is described once, in `tools/codecs/compiler.sml`: each type -- a
value's status, a constructor's and an exception's information, a type's
status and its type function, an environment written whole, a signature, a
functor, an overloading, an origin, a fixity directive, the types of the IRs,
and every type of Mid and of a unit's Mid -- is its constructors, each its
fields, and each field has its marks: the layer it is written to (static, ABI
or the sidecar: the marks are the layers), its codec, and, for a binding's
types, which of its fields its fingerprint holds, by what canonical bytes and
in which layers' (an anchor and a fact of the tables are the full
fingerprint's), and which its sameness compares (`envDelta`). From it
`bin/rune-codecs` writes each type's writer, reader, sameness and fingerprint,
the key a value written once is kept by, and the names a function of Mid
binds, into the parts of `lib/compiler/driver/unitbasis.sml`,
`lib/compiler/core/midcodec.sml` and `lib/compiler/driver/unitmid.sml` marked
as generated, which are committed (`make codecs`; `make check-codecs` fails
where they are stale). So a fingerprint is no traversal of its own: it is the
hash of the canonical bytes of the fields marked for a layer, as SML/NJ's
`pickle2hash` and MLKit's `pu` combinators make theirs of the value they
pickle. A field no traversal names is refused unless the description says,
with a reason, that the traversal leaves it out; and every generated pattern
names every field, so a field added to a type and not to its description is a
compile error, and one added to both is written, read, compared and
fingerprinted (`rune-codecs --test`, `--toy`). MidCodec and UnitMid write one
encoding of Mid by one codec, each with its own hooks for names.

What stays by hand, and why: a type of the elaborator (`ty`, `keyedTy`, `rty`,
`fpTy`, `sameType`), whose parts are written once by a key of their structure
and whose variables are cells a reader shares and a fingerprint numbers by
first occurrence; a type name, written once by its stamp, and fingerprinted by
the strongly connected group of its definition (`fpTycon`, `definition`); an
environment written as a reference to a signature's structure (`env`'s other
branch, `renamedEnv`, `fpChild`), which is a renaming, not a field list; the
reads of the compiler's tables -- a fingerprint's facts of a value
(`valFacts`), a type name's definition, an import's (`importStamp`), and a
basis's tables of its own names (`staticTables`, `abiTables` and their
readers in `load`), which a description of fields cannot say where to find;
the header and the identities; a functor's fingerprint (`fpFunctor`,
`Elaborate.functorFingerprint`), of its parameter's and its result's
signatures over one numbering of both's type names; a structure's fingerprint
as a usage names it, of its entries' hashes (`fpEnv`); and the walks that
name a binding by its path (`walkPaths`, `bindKeys`). The generated writer,
reader, sameness and fingerprint write the bytes, and the hashes, the hand
ones did, on the Basis, `rune.build` and MLton.

**The fingerprint oracle** (the build-system roadmap's D20). With
`RUNE_FP_ORACLE=FILE`, of each value, type and structure a unit binds, as it
is bound, each field is changed alone (`perturbVal`, `perturbTy`,
`perturbEnv`, generated from the same description): the fingerprint must move
in the layers the description marks the field in and no other, and the
sameness say another where the description has it compare the field and the
same where it leaves it out. Each fact a fingerprint reads of the tables by
hand is changed alone too -- a value's primitive, its being known by name, the
global it is, its primitive function -- which must move the full fingerprint
and not the static one, and of a type name the unit declares its equality,
its constructors and its realisation. `FILE` gets a line for each check, and
the scenario `fp-oracle` of `make test-incremental` wants every check to hold
and each kind of change made at least once.

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
* one of an earlier unit's is its place in the unit's *imports*, a table of
  each kind that says its unit's identity and its number there.

A unit's identity is its logical name (below) and the hash of its basis,
without what its compile used of the session's counters and without the
imports' table: an import is hashed as what it is, not as whose it is. A type
name is its fingerprint (below), a value or an exception its anchor, the
facts a client reads of it, what a copy of it is and its type, a signature
referred to its fingerprint. A unit whose body changed and whose basis did
not keeps its identity, so that what was compiled against it stays valid, and
so does a unit whose imports changed in nothing it names (S121), which is
what a fresh compile of it gives. A unit that names what changed moves, even
where its own bytes do not (S122, S123): a client that names only it holds
by its binder, and what it may read through it must have moved it. Loading a
basis gives the unit's numbers a range of each kind of name -- stamps, type
names, type variables -- after the session's, and registers the range, which
is how a name of the session is written back as a unit's identity and number.

**A unit's logical name** says where its file is, and nothing of how a path
spelt it (`Workspace`, `lib/compiler/driver/workspace.sml`; the build-system
roadmap's D3). It is what a key, an identity and an anchor hold. The paths a
program names its files by stay in its code's tables, for its traces and
messages, and a unit from the cache has them made where the file is now.

* A file of a library is `LIBRARY:PATH`, its path below the library: the
  deepest directory above it with a `library.build`, so that `lib/basis/list.sml`
  is `basis:list.sml` and `lib/compiler/driver/deps.sml`, reached by a path of
  `rune.build` or through `--library compiler`, is `compiler:driver/deps.sml`.
  A library is named by its place under a directory of libraries -- `--lib`,
  then the workspace's roots ([build.md](build.md), *The workspace*) --
  so `lib/ffi/runtime` is `ffi/runtime`, and else by its directory's name, so
  that it keeps its name where it moves. A library's name holds no `:` and no
  `@` (each is made `_`), which leaves room for a version, `LIBRARY@1.2:PATH`.
* Any other file of a build is named from the workspace's root, or without a
  root file from the build file's directory: `src/driver/main.sml`, spelt
  `../../src/driver/main.sml` in `tests/lsp/worker.build` too.
* Files given on the command line are named from the directory of the first
  (with `-I`, of the entry point), whether or not a workspace is around them.
  They have no build file to hold them together, and they move together: a
  project moved to another directory keeps its cache (S29). They may be
  given in any spelling, relative or absolute.
* A file outside the root is named by the path to it from the root, with `..`
  in it (`../out/a.sml`), which holds nothing of the machine, so that a tree
  that moves keeps its cache (S96). Only a file on another drive than the
  root, which no relative path reaches, has its whole path for a name. A
  library above or beside the root is found as far up as the directory it
  shares with the root; nothing above the root has a say.

Links are not followed: a name is of the path after `.` and `..` are taken
out, so a file reached through a link and through its real path are two
names, and at worst two entries.

**A rank.** Two units of one build never have one name. A file given twice is
two units, as it is two declarations in a program compiled whole, and so are
two files of one path in two libraries of one name: the second has `#2` after
its name, in the order of the build, then `#3`, and so has its key and its
identity. Each has its own globals, so `a.sml keep.sml a.sml main.sml` prints
in units what it prints compiled whole (S91, S94).

A unit the REPL loads where a unit of its identity is loaded already -- a
file used again, the same text against the same units -- is loaded and
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

**The interfaces** (the linting roadmap's D15 and M9). A unit's register
code says what it expects of the units before it (`Code.expects`, which
`Regs` gathers): for each function of another unit it calls, how many
arguments it passes, the representations of each and the representation
it takes the result as; for each global it reads, the representation it
reads it as. The link holds each against what the unit that defines the
function or global declares (its `Code.meta`, and the unit's `globalReps`),
once every unit is in, in time linear in the imports: an arity that is
not the callee's, or a representation that does not fit the declared one
(one is the other's, under RegVerify's order), and the units do not fit
together -- `rune` fails with "the units do not fit together:" and up to
three of them (`Link.Mismatch`), and the compiler library's
`Session.writeProgram` raises `Fail` with the same. Each unit's code was
checked whole when it was compiled (`RegVerify`; [ir.md](ir.md), *The
register target*), so this is what is left to check of the program. The
whole linked program is checked at level 2 of the lint, so in every test,
and where `RUNE_REGVERIFY_LINK` is set and not empty: interfaces see a
function misnumbered but not a global of the same representation.
`RUNE_LINK_CHECK=0` leaves the interfaces out, to measure them. The check runs at every link, at
level 0 of the lint, which is always on but where `--lint=off` says
(`Pass.checkAt`; `--pass-stats` counts it as `link`). A unit file keeps what its unit
expects (version 4), so a unit relinked from its file against another
build of an import is held to it too (S80 of
`tests/incremental/SCENARIOS.md`). The stack code expects nothing.

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

* the cache is a directory, the workspace's store (*The store*, below):
  `--cache-dir DIR`, else `$RUNE_CACHE` (empty: none), else `.rune` in the
  workspace, beside its `rune.workspace`; `--no-cache` compiles every
  unit; `--explain-rebuild` says of each unit whether it was taken from the
  cache or why it was compiled; `--verify-cache`, or `RUNE_VERIFY_CACHE`
  set and not empty (for the REPL's `use`, which takes no flags), compiles
  each unit the cache has too, and fails where the cache's is not what
  compiling it gives: the same bytes, for an entry whose usages hold by
  binder. One that holds by fingerprint alone names the old unit it was
  compiled against, so it is loaded with its names remapped, as a build
  would load it, and its basis written again and its code read and written
  are compared with the same made of the unit compiled, a unit's identity
  left out and what only a hash reads (build-cache issue 15, which closes
  when a basis written again is the same bytes). Its Mid is not compared.
  One that does not load there is what a build would miss, and is compiled
  and says so (`src/driver/cachecheck.sml`; the REPL's `use` compiles such an
  entry again without comparing it); `RUNE_VERIFY_DUMP=DIR` writes the
  entry of each unit that does not verify, and what compiling it gave, to
  DIR (`NAME.cached.pickle`, `NAME.fresh.code`, ...) to compare. A unit's
  code lists the names it uses of other units in the order of their places
  in the code, so a unit compiled in two sessions is the same bytes,
  whatever order the sessions loaded those units in (S59); `--pass-stats`
  with `RUNE_MEM` set says after each unit how many bytes its basis and
  its code took and how much the heap holds, collected;
* in it, a directory per *configuration*: the hash of the compiler's
  identity (`Config.identity`, a hash of the compiler's plan and of the
  files of its closure, which `scripts/gen-version.sh` writes: [building.md](building.md),
  *The compiler's identity*), the versions of the files, the
  instruction set, the options that change what the compiler makes, and
  the probe of its hash (`Pickle.probe`, the digest of a fixed text): the
  hash's values depend on the width of the `Word` of the host that built
  the compiler, so a compiler whose hash differs has a configuration of its
  own, never takes another's entries, and `--explain-rebuild` says so when
  it finds only those (S71); a basis says the probe too, and one of another
  is not read (S70). The configuration's `units/about` lists what it is
  made of
  (`-O`, `--passes`, `--int-bits`, `--fuel`, `--flex-records`,
  `--overloading`, `--free-tyvars`, and the limits `--functor-budget`,
  `--type-work` and `--match-work`, which change what a compile gives;
  S84). A compiler built from other
  sources, or another level, finds none of another's entries, and two
  configurations live side by side;
* in that, a directory per *key*, the hash of the unit's name, its source
  and whether it may use `_prim`, and of an input file's unit the settings
  that hold for the input files and not the libraries (`--default-type`,
  `--or-patterns`; S62; and `--no-unicode-lints`, since an entry keeps
  the warnings it leaves out; S64), and of any unit its mode where it is not the
  default (*Source modes*; S63); the name is the unit's logical name (*Names*,
  above), so that no spelling of a path reaches the key, a cache follows a
  library where it is moved (S93), and a unit taken from the cache names its
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
* a function marked to be inlined, or that only applies a primitive, is
  copied into a unit that names it, which uses its Mid too (`inlv NAME`,
  by the name the unit used, held by the hash of the Mid and of the lines
  and columns of its positions, which a copy's line table takes from the
  source of the unit that declares it): an edit of its body compiles the
  units that copied it again, and so does one that moves it a line, and an
  edit beside it does not (S78, S83); which functions the libraries mark is in the cache's
  configuration, as which functors they do;
* in the REPL, what a declaration of a file used echoes is compiled with
  it: two usages more say what that was compiled by, `echo on` whether it
  echoed at all (the print depth was above 0) and `p KEY` whether a printer
  was installed for the type `KEY` names (`Compiler.addPrettyPrinter`),
  and each holds where the REPL decides the same now (S53, S54);
* an entry whose code names a unit the session has not -- one its usages
  should have found changed -- is no entry, and the unit is compiled
  rather than the link finding nothing to take the name from;
* an entry keeps the warnings its compile gave, as spans and messages,
  which a compile that takes it from the cache gives again as its own, in
  whatever form it was asked for (S85);
* an entry is marked with the level of the lint its compile ran
  (`UnitCache.level`: `--lint=N` or `RUNE_LINT`, else the program's own,
  0 for `rune`; at most 2, level 3's round trips not being asked of an
  entry, and at most 0 where `RUNE_REGVERIFY=0` leaves the register code
  unchecked; [ir.md](ir.md), *Levels*), its Mid linted and its register
  code verified at that level; a compile takes an entry of its own level or
  above without checking it again, and to a compile at a higher level an
  entry of a lower is no entry ("its entry was checked at a lower level of
  the lint (N)"): the unit is compiled again, checked, and stored marked
  where the cache can be written (S81; the linting roadmap's M9);
* an entry keeps the schemes of what its code names of other units, as
  text (`UnitBasis.importedSchemes`). A build does not hold them to the
  units there now when it takes the entry: where its usages hold by their
  binders, the binders' identities are the bases that hold those schemes,
  and a hit that loads no basis (*A warm build*, below) could not read them;
  where usages hold by fingerprint, the fingerprints are of the schemes
  already. `--verify-cache` compares them with what compiling the unit gives,
  and fails where they differ ("its entry had another scheme of ...", S82;
  the build-system roadmap's M6). The REPL's `use` and the compiler library
  still hold them, a check of level 0;
* an entry is one file, written under a name of its own and renamed into
  place, so that two compiles at once never see half of one: first its
  head -- its usages, the level of the lint that checked it and the units
  its basis names, all a lookup judges it by -- with the hash of the head's
  bytes, then four sections, each with the hash of its own: its warnings,
  file, other files and identity, which loading takes rather than hashing
  the basis again; its basis; its code; its Mid (`UnitCache.version` 12;
  the build-system roadmap's M7). A lookup reads the head of each of a
  key's entries -- its first four kilobytes, more where a head is longer --
  and of one whose head does not stand reads no more and hashes nothing: a
  damage that makes a head refuse is a miss. A head that stands is held to
  its hash, and each section to its own as its client takes it; a build of
  the units' code takes no Mid, and holds none to its hash, and `--whole`,
  `--verify-cache` and the compiler library take it
  (`UnitStore`, `lib/compiler/driver/unitstore.sml`, which keeps entries
  and what is kept beside them by a name and knows nothing of what a unit
  is: the head and the sections are its client's to write and read, and
  its client's `holds` says of a head which entry stands;
  `tests/lib/compiler/store.sml` holds it to that with a client of its own
  and no compiler). One that cannot be read, or does not hold what its
  hashes say, is no entry, and the unit is compiled and the entry written
  again. A cache that cannot be written is one that
  is not there. Nothing in a key is a time. A `.tmp-` file an hour old is
  one a compile that died left, and a compile removes it where it comes
  across it: in the directory of a key it looks in, and in `units/` when
  it writes there (S86). Temporary publication names
  come from an OS reservation held until the write finishes, as for
  bytecode output; generating them does not format clocks or process ids;
* beside the configurations, `steps/` holds what a build's declared steps and
  preprocessors made ([build.md](build.md), *Generated sources*): the key a
  step last ran under, with the hash of each output, and a preprocessor's
  output of each file, by the tool and the file's bytes. A unit of a
  preprocessed file is keyed by that output, as any unit is by its text.

**What a boundary does to a key.** A client's usages are by name, so what
its entry holds of a library is what it could see and did name: a boundary
needs no hash of its own, as SML/NJ's filter does, whose clients depend on a
unit's one hash (D8 asks for "what would have been pickled for the smaller
environment"; a usage is finer than that). A name a boundary hides is bound
in no client's scope: `UnitBasis.binders` follows the filter, so a usage of it
does not hold there, and a build that is no friend compiles the unit again and
is refused rather than served. An edit behind a boundary compiles no client,
whichever unit it is in, unless the client is a program that keeps its units'
identities: the usage holds by its fingerprint, across the unit that changed
(`keys` of `tests/runner/librarymodel.sml`). What it did not name it does not
depend on. A library's own files are keyed the same way, in the scope its
header gives them, so a unit is one entry whatever else a program loads.

**Fingerprints** (GHC's rule; the incremental roadmap's M6, the third
part). A usage keeps, beside the unit that bound the name, the
fingerprint of what the name named: the hash of an entry -- a value's
scheme and where it is from, a type's definition with its constructors and
realisation, a structure's entries, a signature, an identifier's fixity --
with every name in it written by its unit's logical name and the path that
reaches it there (`a.sml:A.shape`, `a.sml:sig:SHAPE.area`), so that a change
under a name changes every fingerprint that mentions it, a change beside it
none, and a change of spelling none: a `_dynamic` client of `./ty.sml` is the
bytes of one of `ty.sml` (S92). A usage holds where its binder is the same unit, or where what the
name names now has the same fingerprint and the unit that bound it then is
not in the session: the entry's code names that unit's globals, which the
unit of its name there now takes over (below), while a unit still there
keeps them -- in the REPL, where a file used again binds the name now, or
another unit than the first does (S75). A functor's fingerprint is its
signature, its parameter's and its summary's (S65, S66); an overloading
and the REPL's settings hold by their binder alone. A fingerprint is of what the name names at the unit's start, as
its binder is, though the unit declares another of the name before its
usages are worked out (S72); it says which type variables admit equality,
and the arity and equality of a signature's own type names (S68, S69).
A fingerprint is the hash of tokens -- a tag for each kind of node, a
length before each list and string -- rather than of text; a structure's
is the hash of its entries' names and fingerprints, and an entry of a
structure a usage names is worked out once a session, as the usage of it
is, by its binder and name. A signature's and a functor's is one stream of
their entries' tokens, in which a structure that is a structure of a loaded
signature, realised, is a reference: that structure's fingerprint, worked
out once a session, and the realisation, what each of its own type names
is there (functors-units M11; `UnitCache.version` 9). The structure is
found by the path its first value's stamp has in the unit that declared
the signature (a specification's stamp is kept by instantiation,
realisation and the bases); a functor's result, whose values are its
summary's placeholders, is looked up by the names of its entries among the
structures its parameter's were found to be. A walk of both checks that
the one is the other realised -- the same entries, the same stamps (in a
functor's stream, which writes no anchor, stamps may differ where neither
has a primitive or a known function behind it), each of the structure's
own type names the same image wherever it is -- and where it is not, the
structure is written whole (S77). A recursive
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
`lib/cache`, which `make install` installs read-only beside the library and
`make dist` ships (*The store*, below). A compile reads it after its own
store and never writes it, so that a program's first compile takes the
Basis Library's units from there where their usages hold, which they do but
for the seals of structures the program does not name. It is made with the
lint at level 2, so its entries are marked 2 and a compile at any level
takes them.

An analysis names its units as a build does (*Names*, above), `file#rank`
being gone: `CompilerApi.Project.read` takes the workspace, and the same
source in a build and in the editor has one name. So far only the name is the
same: an analysis's sidecar holds origins, which a build's does not, and an
analysis knows no back-end fact, so the bases differ.

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
from the cache the same way, each a unit named by the file's path from where
the session began, however `use` spelt it (S97), and by its place in the
file, kept in `$RUNE_CACHE`, else the store of the file's workspace, else
`.rune` beside the file: a file used again links its units from there, its
top level run again with globals of its own.

`make check-units` builds every program in units without the cache, then
through a cache all the programs share, and again from it, every unit
taken from there, and wants the same bytes three times; `tests/units`
does the same for its programs of several files; `make test-incremental`
runs the scenarios of `tests/incremental/SCENARIOS.md` it can be held to.

## The store

What a compile in units keeps is one store, used by every client the same
way (the build-system roadmap's D24 and M7): the batch compiler, `--serve`,
the REPL's `use`, `--verify-cache`, the memos of a warm build (*A warm
build*, below) and the records of a build's steps. A store is a directory:

```
DIR/                 .rune, or lib/cache, or --cache-dir's
  CONFIG/            one for each compiler and set of options
    KEY/             one for each unit: its logical name, its text, its settings
      HEAD           an entry, one for each set of usages
    units/           what is kept by a unit's identity: the paths to its
                     names, the keys it binds; about, what CONFIG is made of;
                     the stat memo; the link memo
  memo/units/        the records of up-to-date builds, copies of outputs, and
                     trimmed, whose time is when the store was last trimmed
  steps/             what a build's steps and preprocessors made
  index/units/       each library's index, by its place, with what it was made
                     of (docs/build.md, A library's index)
```

**Layers.** A compile writes one store, its *overlay*, and reads after it
read-only stores, its *layers*, in order: the frozen libraries, `cache`
beside the library (`lib/cache` in a checkout, `<prefix>/lib/rune/cache`
installed). The two are one mechanism, the same code, layout, entries and
rule for a hit; what differs is who writes them and for how long they are
good. A layer is valid for exactly the compiler that made it, so it is made
again whole when the compiler changes, needs no trimming, and sits beside
that compiler in an install; the overlay outlives compilers and holds what
they left. A hit in a layer is not copied into the overlay. The keys a
unit's identity binds and the paths to its names are read from the first
store that has them, the overlay first. A compile that writes a layer --
`make basis-cache`, `--cache-dir lib/cache` -- keeps no memo of its build
there and never trims it.

**Where it is.** `--cache-dir DIR`, else `$RUNE_CACHE` (empty: none), which
is how worktrees share one, else `.rune` in the workspace: the directory of
the nearest `rune.workspace` above the build file, or above the first input
for files given by themselves (*Names*; [build.md](build.md), *The
workspace*), else beside that file. So every build of a workspace, whatever
file its plan begins with, has one store, as do the REPL's `use` of a file in
it and a build of a library in it; before M7 a store went beside the first
input, which put `rune.build`'s in `build/.rune`, by its first line
`build/config.sml`, and `tests/lsp/worker.build`'s in `src/lsp/.rune`. Its
paths are from the root of the filesystem where a compile in another
directory could mean another file by them (the stat memo, the link memo), so
that compiles in several directories share it.

**Keys and entries.** A unit's key is its logical name, the hash of its
text and its settings (*The cache*, above); an entry's head is what the
client judges it by, which the store holds and never reads, and its
sections are hashed apart. Nothing in a key is a time, and nothing is ever
invalidated: an edit gives a new key or breaks a usage, and the old entry
stays until the store is trimmed.

**What keeps it small.** What a compile takes from the overlay -- an entry,
or a file kept beside the entries -- has its time set to now where it is an
hour old or more (Go's rule), so that a file's time is when a compile last
took it, within the hour; a unit taken keeps the paths to its names so too,
which a unit compiled against it reads only once it changes. Trimming removes from the overlay what no compile
has taken for longer than `--cache-max-age DAYS` (7 unless given), then, the
least recently taken first, what makes it larger than `--cache-max-size
SIZE` (4G unless given), then the directories that leaves empty, and a
`.tmp-` file a compile that died left (`UnitStore.trim`). A compile in units
trims its store after its work is done, where it was last trimmed a day ago
or more (one stat where it was not), never during a build, and never in a
child of `-j`, whose parent is still building; `rune --cache-trim` trims it
now. Within the hour, then, the least recently taken is the first written:
a size smaller than what builds take may remove what the next build takes,
which it compiles again. Another compile may be reading the store as it is
trimmed: any failure is a miss. An entry gone is compiled again, a key bound or a path gone loads
the unit whole or compiles it, a memo gone does the work again, and a step's
record gone runs the step; what a compile takes it reads whole first, so
that nothing is read from the store after it is taken. `make clean` removes
the overlays of the tree, and `lib/cache` stays until the next `make
basis-cache`.

**Install and dist.** `make install` copies `lib/cache` read-only to
`<prefix>/lib/rune/cache`, and `make dist` ships it (`rune-build make-dist
--cache lib/cache`), each configuration's entries and what is kept beside
them, read-only in the tar, not the memos of the build that made it: a
dist's first `--units` compile builds no unit of the Basis Library
(`frozen` of `tests/runner/distchecks.sml`). Its entries serve the
compiler with the configuration that made them: the same `Config.identity`,
the default options and a hash whose probe is the same.

**What reads which.** The batch compiler and `--serve`: the overlay, then
the layers. The REPL's `use`: the overlay of the file's workspace. The
compiler library: the frozen libraries alone, and it writes `.rbi`, `.rbm`
and `.rbs` beside its outputs. The language server keeps its analysis in
memory and reads no store yet.

## A warm build

A build whose units are all in the cache costs what reading them back costs
(the build-system roadmap's D25 and M6). Four things keep that small, each
with `--units` and a cache, and none in a key: a memo says that work need not
be done again, and is believed only where every file it rests on has the stat
it had or the bytes it had. `RUNE_WARM=off` turns all four off.

**A unit taken without its basis.** An entry whose usages all hold by their
binders, and whose basis names only units of the session, needs nothing of
the session checked but the binders (`UnitCache.findExact`): its unit is
registered -- its identity, the ranges of its names -- and the names it binds
are bound to it by the keys the cache keeps of its identity
(`UnitBasis.bindKeys`, a file beside the entries), and nothing of its basis
is read (`UnitBasis.lightLoad`). Its code is read for the link, and its
warnings are given again. A unit whose basis is wanted later -- by a compile,
or by a hit that is not light -- is loaded then (`UnitBasis.materialise`), at
the names it was registered at, with the units its basis names in turn and
every unit that registered an overloading, which a compile reads by no name.

**A compile that sees what it names.** A unit that is compiled sees a *view*
(`UnitBasis.view`): the initial basis, and of each name its text has, the
binding the binders say, which is what the environment of all the units
before it would give for that name; its signatures and functors the same
way. Only the units those bindings come from are loaded, and those their
bases name. What the compile then looked up must have been in the view, and
what its basis and code name must have been loaded (`UnitBasis.closed`); a
compile that read outside its view is a missed lazy read, and the build is
compiled again with every basis loaded (`UnitBasis.Unviewable`,
`compiledAgain`), never taken. Not where every basis is wanted anyway --
`--whole`, `--emit-units`, `--typecheck-only`, `--verify-cache`, `-j` -- nor
for a program that loads units, nor where an import renames a name (a
binder's names are its own unit's), nor where an editor's buffer stands in
for a file's text (`--serve`), which no stat says anything of. A
preprocessor's output stands in for its file too (*Generated sources* in
[build.md](build.md)), but a compile sees a view all the same: its unit's key
holds the output's hash, taken whole and not from the stat memo, since the
file's stat says nothing of the tool.

**The stat memo.** A unit's key holds the hash of its source, which a warm
build need not read: the store keeps, by a file's path and mode, the hash its
text had, its stat then -- device, inode, size, the times it was written and
changed -- and when the stat was taken (`UnitStore.hashBy`, `units/` of the
configuration). A hash is taken from the memo only where the stat is the same
and the file was last written at least two seconds before the stat was taken,
git's rule for an index that is racily clean, with a second more for a clock
that is not the filesystem's; anything else reads the file. A span of another
unit's code that names a source not read -- a function copied from it, a
warning given again -- loads it (`Source.fault`). A stat is what Rune's own
`rune` asks of `Posix.FileSys.stat` (`UnitStore.stat`, which
`src/main/rune-main.sml` sets); a compiler built by another host has none,
since MLKit's Basis Library has no `ctime`, and keeps and believes no memo:
it reads every source and links every time.

**An output.** What a build writes and reads again -- its program, and what
a step made -- is held by its stat and by a copy of its bytes, which the
cache keeps with the stat they were read back at (`UnitMemo.written`,
`memo/units/copy-*`, one a path): where the stat is the same and racily
clean, by the stat; where it is the same but was taken within the second of
the write, by its bytes against the copy. A copy compared costs what reading
it costs; a hash the VM works out of an output of megabytes costs more than a
no-op (0.31G instructions of `rune.build`'s 6 MB program, against a no-op's
0.27G). The price is the copy: a cache holds each output once more.

**The link memo.** The program a link made is kept by the hash of what was
linked, each unit's code by its entry's hash or its bytes' and where its
files are now, with the output (`UnitMemo.linked`). The same units linked to
an output that is what that link wrote are not linked again; an output that
was changed, or written within the second of its stat and not the same
bytes, is.

**Up to date.** A compile in units keeps what it read once its plan was made
-- every source, every build file and source each library's index rests on,
every file its declared steps and preprocessors read, with the stat each had when it was read, and whether
each `library.build` it asked of was there -- with what its steps made and
its output, each held as an output is, and the warnings it gave, under a key
of all its plan rests on: the command line, the directory, every `RUNE_`
variable, the compiler's identity, the text of its build files, its inputs
and its workspace (`UnitMemo.upToDate`, `memo/` of the cache). A compile
with the same key, all of whose files have the stats they had and racily
clean, whose questions have the same answers, and whose steps' outputs and
own output are what were made, runs no step, gives the warnings again and
ends. A step's output is held as an output because the build itself writes
it, within the second of its stat; and the check comes before the steps, so
an up-to-date build runs none. Not with `--explain-rebuild` or
`--pass-stats`, which say what each unit did, nor with `-I`, whose plan
lists directories, nor where an editor's buffer stands in for a file, nor
where a step declares no inputs and so runs on every build, nor where the
warm path is off; with `-j` too, so that a no-op parses no input.

What a no-op costs (the build-system roadmap's M6): machine instructions
(`perf stat -e instructions:u`, the compiler at tier 2) and the VM's
(`runevm --count`), of a build made again with nothing changed, against the
same build before M6; the first no-op after a build reads its output and the
copy once more, since the output was written within the second of its stat.
`rune.build` is a git checkout in which make has written `build/config.sml`;
its row is of the build without the config step it had for a while, whose
stamp asked git on every no-op, 0.046G of the 0.274G a no-op was then:

| Build | Before | No-op | First no-op | VM, before | VM, no-op |
|---|---:|---:|---:|---:|---:|
| `rune.build`, 257 units | 11.30G | 0.229G (2.0%) | 0.252G (2.2%) | 1.151G | 0.002G |
| HOL4's closure, 910 units | 25.78G | 0.261G (1.0%) | 0.314G (1.2%) | 2.872G | 0.006G |
| MLton, 791 units | 87.27G | 0.284G (0.3%) | 0.335G (0.4%) | 9.011G | 0.007G |

A no-op's floor is the VM's start, 0.173G for `rune --version`. An edit of the
last unit costs 9% fewer VM instructions than before on `rune.build` and HOL4
(the units before it taken without their bases; its view loads most of them),
and a build that links keeps a copy of its output in the cache. `-j 4` makes
a no-op of `rune.build` 0.229G, against 13.30G before, since it parses no
input; a build that is not up to date still parses every input with `-j`.

`tests/runner/warmchecks.sml` (`make test-incremental`) holds the warm path to
what a build without it gives: each unit of two projects compiled alone under
its view and under the mask of its usages while the others are taken without
their bases ([testing.md](testing.md), *The checks of the cache*), E15's racy edits, and a compile that is up to
date against a touch, an edit, the output removed and overwritten, and a
`library.build` that makes a unit another library's.

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

Each file is read in the fixity the files before it leave, as a compile
reads it. A cycle is refused. Inside a structure anything goes, but a name a
structure `open`ed may bring in is counted as a use where another of the
files declares it, which the analysis cannot tell apart.

The names say the order only where a file is *well-formed* (below). One that
is not stays where it is written: all before it stays before it and all
after it after, so that what it binds is in scope as the text says, and a use
that reaches past it means what the text means, the binder before it or none.
`rune --deps` says which, with the line, and goes on.

`rune --deps --build FILE` reads a build instead of a list. The order is the
build's, a library's boundary and `use` hold as they do in a compile, a file is
read in the fixity its place in the build gives it, and the classes and the
scopes below are the build's.

**An entry point.** With `-I DIR`, the one input is a program's entry
point: the `.sml` files of its directory and of each `-I DIR` are analysed,
and those its uses reach -- the files declaring what it names, and those
they need -- are compiled before it, in the graph's order. They have no
written order to fall back on, so a file that is not well-formed is none of
them, and a name two of them declare is refused; where a file left out
declares a module the program names, the compiler says so.

**The Basis Library's index** says what each of its files provides and
requires. It is derived from the library's build file
(`lib/basis/library.build`, docs/build.md) and its sources, and kept in the
store, never in the tree (docs/build.md, *A library's index*): what a file
provides is what it declares and what it requires what `Deps` derives, so
neither is written by hand, and `rune --basis-index DIR` prints it.

## Well-formed units

A unit is *well-formed* (CM's word) when its top level says what it binds in
names a use can be found by. Four rules, the build-system roadmap's D17:

1. No top-level `val`, `fun`, `exception`, `datatype`, `abstype` or
   replication, because a use of what they bind names no module.
2. No top-level `open`, which binds what the text does not show.
3. No top-level fixity directive, because the parse of what follows depends
   on it.
4. No module name declared by two units of one scope. A scope is what a
   library's boundary or an `implements` holds, or the rest of the build, so
   two libraries may each have their own. Two that let
   out one name into a scope are a clash of imports, a library's matter
   ([build.md](build.md), *Clashes*), not two units'.

A unit's top level may declare structures, signatures, functors and type
abbreviations. The rest is free, since nothing needs it: an effect (`val _ =
e`, `val () = e`, a bare expression) binds no name, what a top-level `local`'s
head binds is private to it, a `use` does not exist in batch, a structure
needs no signature, and inside a structure anything goes.

**A correct program is never refused for these.** They are about finding an
order and a closure from syntax, not about what a program means, and a unit
that breaks one costs speed, never correctness: it keeps its place in the
written order, as every unit has in a program. The 1990 Definition had such a
subset and the 1997 revision took it out; Rune holds to the language it says
it accepts ([language.md](language.md), row `mod.wellformed`).

**The rules are for shared units.** A unit is of one of three classes:

| Class | What it is | The rules |
|---|---|---|
| *shared* | others depend on it | hold |
| *entry* | nothing depends on it: a program's main file, a script | all of Standard ML |
| *prelude* | it defines the language for what follows: `annotate "prelude"` in a build ([build.md](build.md), *Annotations*), or an `always` file of a library | all of Standard ML; what it leaves is everyone's after it |

Shared and entry come from the graph. A unit is shared if a unit after it
names what it declares, by a module's name, or by an identifier that is one of
its values: another unit's local variable of that name counts too, since the
syntax cannot tell them apart. One whose `open` or replication binds what it
does not show is shared if any unit comes after it. In a library the build
says the class: a `final` file is an entry unit, and `demand` and `seal` files
are their clients' to depend on, so shared.

A prelude's fixity is known to the graph: `rune --deps` reads each file in the
fixity the files before it leave, a prelude's among them, so a unit that needs
it parses and shows its uses. So does choosing what of the libraries a program
loads, by the names its files use (`--basis-deps` shows the choice), from what
the libraries it sees export. A file that does not parse even so, because its
fixity comes from a library with no header, which no index holds, is taken
there by its tokens, and `rune --deps --build` keeps it where it is written;
its compile has the last word. A prelude stays where it is written too.

**Where it shows.** A warning, and `--no-warnings` silences it:

* `rune --deps` lists every break, with its line. That is the question being
  asked, and nothing is lost by the length of the answer.
* `rune --basis-index` warns once a library, with how many units and the
  first, as it does of a library with no header: the person indexing it is the
  person changing it, and a client cannot act on it.

A `rune --build`, and `rune FILE...`, do not warn: nothing there asks for the
graph, since a build lists its files in the order they are compiled and the
written order holds whatever the units are; and a warm build does not parse
a unit it has no use for, which checking would cost it every time (parsing
all of a build's files cost a no-op 9.2%: the build-system roadmap, M1). Ask
with `rune --deps --build`.

**`strict`.** A library says `strict` in its header ([build.md](build.md), *A
library's header*) to make `--basis-index` refuse a unit that is not
well-formed. It needs a header: a library without one keeps today's meaning,
all of which is public and any of which may be named.

So nothing of this reaches a program's meaning, and `--flex-records=program`,
`--free-tyvars=later` and `later-monotype` are the only ways for anything to
wait past a unit's end (*Compiling a unit*): they are refused in `--units` and
stay outside builds.

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
compile time.

A program compiled in units keeps that section where it *loads units*: it has
a dynamic module (`lib/basis/dynamic.sml` is among its units), or a unit of
it names one of `Runtime.load`, `link`, `linkedUnits` and
`linkedUnitSources`. So does every client of `CompilerApi`, through the
library's own file that links compiled code. The members are told apart by
the keys a unit's code names, of the functions those members are in
`lib/basis/runtime.sml`'s code, so an alias, an `open` or a functor's argument
counts where a member is used and not where it is not, and a program that
names `Runtime` for its counters, or has a structure `Runtime` of its own,
does not load units. Such a program keeps no section, so nothing in its file
depends on a unit's identity, and an entry taken from the cache across a unit
that changed gives it the bytes a build from source gives (*The cache*). A
program that loads units takes no such entry, since a unit loaded into it
names the identities of a build from source. Where that shows only once
such an entry has been taken -- the first unit to name a member does so by
an alias, after the edit -- the program is compiled again as what it is, and
`--explain-rebuild` says so. `--emit-units`, which gives the units'
identities to whoever reads the files, takes no such entry either for a
program that has `Runtime`.
 Two modules compiled against one library share its types
with each other and with the program. `Dynamic.load file` is the untyped
form, for a unit that registers what it offers through a structure of the
program. The scenarios `dynamic` of `tests/runner/scenarios.sml` (`make test-dynamic`) are each of these. A
virtual module (`structure X = _virtual : SIG`, [build.md](build.md),
*Virtual modules*) is the same boundary inside one program, its
implementation chosen by the build file.

**A dynamic functor** (the build-system roadmap's M21 and D22) is the same
for a functor, applied by its signature alone:

```sml
(* the program, compiled against KEY and TABLE alone *)
functor Table = _dynamic "table.rbu" (K : KEY) : TABLE where type key = K.t
structure Squares = Table (IntKey)

(* the module, compiled to table.rbu *)
_export functor Table (K : KEY) : TABLE where type key = K.t = struct ... end
```

`A` and `B` of `functor F = _dynamic "path" (X : A) : B` are its parameter's
signature and its result's, in which `X` is the parameter. An application is
typed by them alone, as rule 54 types any functor's (its types and
exceptions new at each, `B`'s abstract types as an opaque ascription's), and
compiled as a call of the functor's function over its argument's record and
its result's, as an application of a functor of an earlier unit is ([ir.md](ir.md),
*Functors compiled once*): there is no body to copy, so nothing of an
implementation reaches the program, and the expansion leaves the call. The
declaration sets the global of that function from what the module exports,
the one slot of its record: `_export functor F (X : A) : B = strexp` is a
functor of the module, its body ascribed to `B` opaquely, whose function its
unit exports. `functor F = _virtual (X : A) : B` takes it from the program,
as a virtual structure does ([build.md](build.md), *Virtual modules*).
`Dynamic.reload` of the file gives the declaration the new module's
function: an application after it is of the new code, and one before keeps
its own slots and types, which no later application shares.

The two sides agree on the functor's ABI where they agree on its
fingerprint (`UnitBasis`, `Elaborate.functorFingerprint`), the hash of: the
ABI's version and its calling convention; the parameter's record and the
result's, each slot by name in order, the descriptors of the parameter's
open constructors among them (`Elaborate.functorShape`); and `A` and `B`, their
own type names by their places among both lists -- `B` names `A`'s where the
result's types are the parameter's -- and every other type name by its
unit's logical name and path, with what defines it, as the ABI layer's
fingerprints are worked out (*Layers*, above). Nothing of where a signature
was written is in it, so a client and a module whose files were spelt
otherwise agree (E10's probe; `spelling` of the scenarios `dynamic`), and
`Pickle.hash` gives every host the same value but `smlnj32`, which has a
hash of its own, and so a fingerprint and a configuration of its own
(`check-cross`'s `virtual-table`).
Where they differ, the declaration raises `Dynamic.Mismatch`, which names
both; each field has a mutant that is refused so (S128 to S130 of
`tests/incremental/SCENARIOS.md`, the mutants of the cache A1 to A6). A
datatype `B` specifies is read by the program as the specification lays it
out, a constructor whose argument is an abstract type of `B` boxed, so an
implementation that lays it out otherwise is refused where it is compiled,
as an exported structure's is (`tests/errors/err.export_layout`); a
datatype of `A` whose constructor takes `A`'s abstract type is laid out as
the argument's datatype lays it, by the descriptor the caller gives, as for
any functor. `examples/virtual/table` is both forms, and the scenarios
`functor-*` of `dynamic` and `virtual-table-*` of `buildfile` are each of
these. A dynamic or virtual functor is not `inline functor`: it has no body
for its applications to copy.

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
index); a unit that is not well-formed, and an `always` file of the
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

**What a hit claims.** A compile takes a configuration, a unit's text and the
environment before it to code and exports; an entry is kept under a key of the
first two, with usages that say what the compile read of the third. If every
usage holds in another environment, compiling the unit there gives the entry's
code and exports, up to a renaming of imports. The argument is one line, a
compile that reads only that much cannot tell the two apart, and everything
hard is in its premises: that the compile is a function of those inputs, and
that the usages and fingerprints cover what it reads, which are two pieces of
code with nothing but tests between them. `tests/incremental/model.sml` is a
model of this, and not Rune's code: three units, six policies, every edit
between 54 projects. Each policy that reads more than its key holds breaks
S41 silently and looks like an improvement from the rebuilds alone; one that
reads no more is sound whatever its key holds. `make test-incremental` holds
its output to `tests/incremental/model.expected`, and
[testing.md](testing.md), *The checks of the cache*, says how each premise
is checked.

`make check-units` (the oracle `units` of `tests/runner/oracles.sml`) compiles every program of
`tests/lang` and `tests/perf` whole and with `--units` at `-O0`, `-O1` and
`-O2`, the lint of every pass on, runs them as `bin/rune-suite` does,
and wants the same output on both streams, traces included, and the same
exit status. It is to separate compilation what `make check-levels` is to
the optimisations. Those programs are of one file; `tests/units`
(the scenarios `units` of `tests/runner/scenarios.sml`) has programs of several, each built whole and in
units for both bytecodes and held to what it expects: functions, workers,
datatypes, exceptions, a functor and fixity used across files, a
structure shadowed by a later file, the trace of an exception raised in
the last file, the errors of two files, a flexible record left to a
later file, which only the whole build accepts, and functors applied to a
structure of an earlier file (a fixture's
`flags`, the compiler's flags in each of its builds). Last, the compiler is
compiled in units and made to compile its own sources whole, which must
give `bin/rune.rbc` byte for byte.

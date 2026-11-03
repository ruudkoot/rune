# Build files

A build file says what a program, a library or the Basis Library is made of:
its files, in what order, which of them are a library's and which names the
library exports, which implementation a virtual module has, and what each
unit may do (the incremental roadmap's M10; D16). `rune --build FILE`
compiles what a build file says, in units (docs/units.md), through the
cache. The file's extension is `.build`.

Its model is that of MLB (MLton's ML Basis system): a *basis* -- the
structures, signatures, functors, types, values and fixity in scope -- is a
value; a file is compiled in the basis before it and adds what it declares
to it; `local` and export lists say what of a basis the files after it see;
each build file is elaborated once. It differs from MLB in one thing: `use`
elaborates a build file in the basis of its caller, where an `.mlb` starts
from an empty one, so a file used sees what comes before the `use`. There
is no renaming. Its syntax is Rune's own.

## The language

```
build    ::= dec ...
dec      ::= path                            a file, compiled in the basis before it
           | "files" path ... "end"          files, in the order given
           | "group" path ... "end"          files, in the order the modules they
                                             declare and use give (docs/units.md, The graph);
                                             one that is not well-formed stays where it is
           | "local" dec ... "in" dec ... "end"
                                             the second part sees the first; what
                                             follows sees the second part only
           | "library" exports "=" dec ... "end"
                                             what follows sees the exports only
           | "use" path                      another build file, elaborated once
           | "implements" id "=" dec ... "end"
                                             the implementation of the virtual
                                             module id (below)
           | "annotate" string ... "in" dec ... "end"
                                             what the units inside may do (below)
           | "cache" path                    where the cache of the build is
           | "libraries" name ... "end"      libraries selected by this build,
                                             or what a library with no header is
                                             written on
           | "inline" "functor" id ... "end" functors copied into every unit that
                                             applies them (below)
           | "inline" "val" name ... "end"   functions copied into every unit that
                                             names them (below)
header   ::= ( "requires" name ... "end"      what a library's build file says
             | "exports" exports              first (A library's header, below)
             | "friends" path ... "end"
             | "view" id exports
             | "strict" ) ...
exports  ::= "(" export "," ... ")"          export ::= kind id
kind     ::= "structure" | "signature" | "functor" | "type" | "fixity"
path     ::= a file's path, relative to the build file's directory, in which
             $(NAME) is the path variable NAME (--path NAME=DIR, below)
name     ::= a long name of a value, as a word, or as a string where it holds
             characters a path does not ("Word32.>>")
string   ::= "..."
```

Comments are SML's, `(* ... *)`. A path is a word of letters, digits and
`/ . _ - + ~ #`, with `$(NAME)` anywhere in it, or a string, which holds any
other character.

A path that begins with a variable whose value is relative is relative to
the directory of the build file given to `--build`, so that one value serves
every build file the build uses, whatever directory it is in, and no path of
the machine need enter a build. An absolute value is used as it is; so is
a relative value in the middle of a path, which is relative to the build
file that names it, as any other path is.

## Units and bases

Every file is a unit, and a file given twice is two ([units.md](units.md),
*Names*). A build file elaborates to the list of its units in order, each with the basis it is compiled in, which is what `rune --build`
compiles: the cache serves each unit whose usages hold, in that basis
(docs/units.md, The cache), and `--whole` makes one program of them all
(M7).

`rune --build-list FILE` prints the build's closure in order: the files of
the libraries it names and of those they are written on, each library's in
its load order and each before what is written on it, then the build's own
files, then the libraries' `final` files. A whole library is listed, all a
program may name: `--basis-deps` says which of its files a compile takes.
The Basis Library is every program's and is not listed. The other SML
systems' build files do not come from here: `scripts/gen-build-files.sh`
makes them from the `files ... end` blocks of the build files, through
`scripts/build-files.sh`, which needs no compiler.

* A sequence of declarations elaborates each in the basis the ones before
  it leave.
* `local A in B end`: B is elaborated in the basis A leaves; the files
  after it see what was before it and what B declared.
* `library (structure X, signature S) = D end`: the files after it see X
  and S of what D declared, and nothing else of D.
* `use FILE`: the declarations of another build file, in place, in the
  basis of the `use`; a build file used twice is elaborated once, the second
  use adding what the first declared, as far as the files after the second
  use may see it. A build file with a boundary of its own adds what that
  boundary exports at every use, so that libraries can share it whatever
  order they come in. Of one without, a boundary that has closed around the
  first use -- a `library`, an `implements`, the first part of a `local` --
  stands between the two: the second use adds what that boundary lets out,
  and nothing more. Inside the same boundary, it adds all of it. (A first
  `use` of a build file under another library's boundary is another matter:
  that reaches in, below.)

## The workspace

A workspace is the directory of a root file, `rune.workspace`, the nearest
above the build file (or above the first file given, for what it says of
libraries). It says two things:

```
(* The root file of this tree. *)
roots lib vendor end
target rune = rune.build end
target tools = tools/tools.build "--target=stack" end
```

```
workspace ::= item ...
item      ::= "roots" path ... "end"             directories libraries are found under
            | "target" name "=" path string ... "end"
                                                 a named target: a build and its options
```

The words and comments are a build file's. Paths are relative to the root
file, and one that is absolute or holds a variable is refused: a root file
says nothing of a machine. An unknown word, a list that does not end, a target
with no build file and two targets of one name are refused too.

* **Roots.** `libraries NAME` and `--library NAME` find a library under
  `--lib`, then under each root, in order. (A library that `--lib` has is
  taken from there.)
* **Names.** A build's units are named from the root, so one file has one
  name in every build of the workspace, however each spells it; without a
  root file, from the build file's directory ([units.md](units.md), *Names*).
* **Targets.** An editor offers them ([language-server.md](language-server.md),
  *Workspaces and build contexts*). A target's options are those of a
  compiler session: `--target=`, `--unicode`, `--library NAME` and the rest
  of `RuneCompiler.session`.

Nothing else is in the compiler's identity for it: one compiler has one
`Config.identity` in every workspace, and a root file is no input of a unit
but through the names it gives.

## Annotations

`annotate "NAME" ... in D end` gives the units of D:

| Annotation | What it does |
|---|---|
| `allowPrim` | the units may use `_prim` and `_overload` (the Basis Library's) |
| `noWarnings` | their warnings are not printed |
| `prelude` | the units define the language for what follows: what they leave, a fixity among it, is everyone's after them, and they need not be well-formed ([units.md](units.md), *Well-formed units*) |
| `ascii`, `unicode` (or `unicode=utf8`), `unicode=latin1` | the mode the units are read in, over the command line's `--unicode[=ENC]`; the last such annotation in force wins ([units.md](units.md), *Source modes*) |

An annotation that is none of these, or of a library's below, is an error.

Annotations also apply through a `use` edge. For example,
`annotate "unicode" "allowPrim" in use implementation.build end` gives
those annotations to the included units; annotations inside the included
build can override their source mode. Repeated `use` still elaborates
the build once, in its first occurrence's context.

## Exports

`library (...)` exports what the declarations inside it declare, from a file
or from a build file used there. An export that names nothing in scope at
the end of it is an error. One that names what was in scope before it, a
structure of the Basis Library say, is allowed and changes nothing: that name
stays in scope. A library's own build file is held to more: `--basis-index`
wants each export declared by one of its files. `type t` exports
a type abbreviation. A datatype is not exported so: it would keep its
constructors, which a replication (`datatype u = datatype t`) gets back
past the boundary; export a structure that holds it, or the abbreviation of
a type behind a signature. `fixity NAME` exports the fixity the name has
at the end of the boundary. No other fixity crosses it.

A boundary hides names, not representation. A private type that an exported
signature mentions is usable by a client, equality and ascription included,
but not nameable: that is what `:>` is for, in the structure's own source. A
friend (below) sees private names and is held to `:>` like any client.

## Reaching in

A directory with a `library.build` is a library, and the deepest over a
path is the one it is in. A library is reached through its interface,
`libraries NAME end` and what it exports. A build file that names a path
under a library it is not in reaches in, and the compiler warns of it once
per build file and library, unless `--no-warnings` is given:

```
rune.build: warning: this build reaches into the library lib/compiler (1 path), which is reached through its interface
```

The compiler's own programs and the tests of its internals do this today
(the build-system roadmap's D10), so it is a warning and changes nothing
that is compiled. A path that a variable gives is not counted, and neither
is a generated pointer: a `current.build` naming what is under `sets/` beside
it, which nobody wrote and whose generator cannot be told otherwise yet.

The compiler library's `RuneCompiler.Project` API uses this same scoped
planner. It can discover ordered files without parsing their programs;
`group` orders by the rules of a well-formed unit, its files read in the
fixity the preludes before it leave, and records the source inputs needed
to determine its order. Windows project resolution handles
absolute drive and UNC paths explicitly, including expanded path variables.

Levels per unit (`O0` ... `O2`) are not built: a build has the level of
its command line.

## A library's build file

A library of `--lib` -- a directory under `lib` with a `library.build`, 33
of them in this tree: the Basis Library (`lib/basis/library.build`), 27 more
written by hand and 5 generated sets of `lib/ffi` -- has a build file that
lists its files in load order, each in an `annotate` block that says what it
is to a program:

| Annotation | What it does |
|---|---|
| `always` | the file is compiled before every program |
| `demand` | it is compiled before the programs that name what it provides, and the files that need it |
| `seal` | as `demand`, but for no file of the library: it binds a structure again as its signature shows it |
| `final` | it is compiled after every program |
| `host=swap`, `host=no` | how `bin/rune-generate host-basis` gives the file to the other SML systems |
| `host=only` | the file is the other SML systems' alone, in place of a `host=no` file of the same module after it, and Rune does not compile it: one module of a name in a scope ([units.md](units.md), *Well-formed units*) |

`libraries random end` names the libraries it is written on, where it has
no header. In an ordinary program build, the declaration selects those
libraries as `--library random` does; explicit command-line selections are
retained. What each
file provides and requires is not written down: `rune --basis-index DIR`
works it out from the sources (`Deps`, docs/units.md, The graph) and writes
`DIR/MANIFEST`, which is what the compiler reads (`BasisManifest`). `make
manifests` makes them all, and they are not committed.

### A library's header

What a library is to the outside comes first in its `library.build`, before
its first file:

```
requires json unicode end
exports (structure Api, signature API, functor Make, type item, fixity "<+>")
friends ../../tests/api/internals.build end
view small (structure Api)
annotate "demand" in
  use implementation.build
end
```

Its parts come in any order, each once but for `view`, and `exports` is the
one a header must have. A `use`d build file and a program have no header.
`strict` holds the library's units to the rules of a well-formed unit:
`--basis-index` refuses one that breaks them, where another library is warned of
it once ([units.md](units.md), *Well-formed units*). An `always` file is a
prelude and a `final` file an entry unit, which they need not keep.
`requires` is what a program's build calls `libraries`; a library with a
header does not write `libraries`.

* **`requires` says what may be named, and is not transitive.** The files of
  a library with a header are compiled in the Basis Library and what it
  requires, whatever else a program has loaded. A name of another library
  used undeclared is an error: `--basis-index` says so where a library it
  requires is written on the name, and the compile says the name is unbound
  in any case. A program is held to the same: it sees what its `libraries`
  and `--library` name, and a library that one of those requires is not among
  them. What is named is what loads, as ever: `requires` makes a library
  available, and the closure of what is named of it links.
* **`exports` is the boundary:** the files after it are inside it. Files inside
  can use each other's private declarations, and a program or another library
  sees the listed exports. This applies to whole-program compilation,
  compilation in units and cache reuse. Private fixity declarations stay
  inside the library, and its final files are elaborated in its private
  context. An export must be declared before the program; `--basis-index` and
  `--basis-check` reject a missing export or the wrong kind of declaration, and
  `--basis-index` rejects a `fixity` export no file directs and a file that
  uses a name a library it requires does not export, which would otherwise show
  only when a client failed to compile. An invalid index leaves the existing
  manifest intact. A fixity directive at the top level of a file belongs in an
  `always` file, as a demand file declares modules and types only; that file
  loads with the library, so an exported fixity is active wherever the library
  is imported, and only there.
* **`friends` names the build files that see all the library declares,** each
  a path from the library's directory: the compiler's drivers, or a test of a
  library's internals (D11). A friend sees private names and nothing more: `:>`
  holds for it, and what the library requires is not its. A build that is not
  named is refused, even with a friend's entries in its cache, since a usage
  holds only of a name in scope.
* **`view NAME` is a named subset of the exports.** `libraries lib#NAME end`,
  `requires lib#NAME end` or `--library lib#NAME` see that subset, and the
  files that link are the closure of what they name of it, as for the whole
  library. A view has no files of its own, needs no loading primitive and costs
  no second copy of anything (D8).

`--basis-index` writes a header to the manifest's comment lines, `# library:`
for what is required, as the readers of a manifest have always read it, and
`# exports:`, `# friends:`, `# view:` and `# fixity:` for the rest, with words
such as `structure:Api signature:API`. `runedoc` uses the boundary when
selecting public pages and elaborating dependencies.

### A library with no header

A library with no header keeps the meaning it has always had, and a file shows
by its own form whether it has moved: its files see all that is compiled before
them, everything it declares is public, and `libraries` is transitive through
it. A library with a header that requires one sees what that one is written
on too. A build of libraries none of which has a header goes as it always has,
byte for byte.

`--basis-index` warns of each, once, when it writes the manifest:

```
lib/json/library.build: warning: this library has no header: all it declares is public, and its libraries are transitive (docs/build.md, A library's header)
```

That is the only place it shows. A client cannot act on it, and 31 of this
tree's libraries have no header yet, 26 written by hand and the 5 generated
sets, which would be a line in every compile of a program that uses one; the
index runs when the library changes, for the person changing it.
`--no-warnings` silences it.

Such a library may keep a boundary of its own in the older form, a `library`
block around its files, which leaves the rest of its meaning as it is:

```sml
libraries json end
library (structure Api, signature API, functor Make, type item) =
  use implementation.build
end
```

The manifest records that boundary in an optional sixth column, and every
row of one library has the same one.

### Clashes

Two imports of one name in one scope are a clash: two libraries that export
it, or a library and the Basis Library. The later shadows the earlier, in the
order the libraries are compiled, and the compiler warns once a scope:

```
tool.sml:1:1: warning: this scope has RuneCompiler from both the Basis Library and the library lib/compiler, and the second shadows the first (docs/build.md, Clashes)
```

A program's clashes show when it is compiled and a library's when it is
indexed, not in its clients. At least one of the two must have a header: two
libraries with none shadow each other as they always have. What a library
declares itself wins over what it imports, and is no clash. Private names
never clash, since a unit's identity holds them apart. `--no-warnings`
silences this too. Renaming at import will answer a clash, which will then be
an error (the build-system roadmap's M10).

### What a library exports is ASCII

Standard ML has no escape for a
name, so a program read in the default mode could not name `Foo.λ`:
the structures, signatures and functors of a library, and their
members, constructors and fields, are spelt in ASCII, whatever mode its
files are read in (the utf8 roadmap's X11 and D10). Today a library is
read in the default mode, whatever its build file and the command line
say ([units.md](units.md), *Source modes*), and the compiler refuses a
name beyond ASCII in it; should a library's files ever be read in
another mode, its exports stay ASCII all the same.

## Functors inlined across units

`inline functor F G ... end` marks functors to be copied into every unit
that applies them (docs/plans/functors-units.md, M6b). A functor is
compiled once, to a function, and in a build in units the expansion
copies an application back in only where the functor is declared in the
same unit ([ir.md](ir.md), *Functors compiled once*). A marked functor is
also compiled once. Its unit's basis also keeps the function's Mid, so a
later unit that applies it expands the application in its own Mid, as it
does for its own functors and within the same budget. Such a unit depends on
the body: an edit of the body compiles it again, and an edit that leaves the
body alone does not. The declaration names functors and declares nothing,
so the sources stay standard SML. `--build-list` and the hosts' build files
ignore it, as they do `inline val` (below).

The Basis Library marks its own functors in `lib/basis/library.build`.
These are the functors that make its structures in units other than their
own: the words, ints, vectors, arrays and slices, the packing, and the
streams. `--basis-index` writes them to the manifest's header (`# inline:`), and
every compile marks them unless `--no-inline-functors` is given.
A program marks its own functors in its build file (`inline functor ...
end`); there is no option for it (`--inline-functor` was retired by
functors-units' M10, which no build used).

## Functions inlined across units

`inline val NAME ... end` marks functions to be copied into every unit
that names them (docs/plans/functors-units.md, M10). A name is a long
name of the value as the unit that declares it binds it: `not`,
`Word32.andb`, and as a string where it holds characters a path does not
take, `"Word32.>>"`. The unit's basis keeps the function's Mid as the
expansion leaves it, with the functions of the same unit it calls, while
the group is under 400 Mid nodes, and a later unit that names it, by any
name -- `List.app` is `app` -- has a copy of it as a function of its own
top level. Simplify then puts the copy where it is called, or specialises
it, by its own rules, as it does in a whole program. Such a unit depends on
the body ([units.md](units.md), the usage `inlv NAME`): an edit of the
body, or of what it calls, compiles it again, and an edit beside it does
not (S78 of `tests/incremental/SCENARIOS.md`). A whole compile and
`--units --whole` are the same bytes with the marks and without. A
function that only applies a primitive to its parameter (`fun sub (s, i)
= RuneReals.sub (s, i)`) needs no mark: its unit's basis keeps every such
function, and a later unit's copy is the primitive's application, which
keeps the function's frame in a trace, as a whole program does.

The Basis Library marks the functions that a profile of MLton's
benchmarks built in units found called across units on their hot paths:
`not`, `o`, `valOf`, `app`, `foldl` and `foldr`; `Word32.+`, `Word32.>>`,
`Word32.andb` and `Word32.fromLarge`; and `Word8Array.sub`,
`PackWord32Little.subArr` and `PackWord32Big.subArr`. `--basis-index`
writes them to the manifest's header (`# inline val:`), every compile
marks them as it does the functors, and `--no-inline-functors` leaves them
out too. A program marks its own in its build file.

## Virtual modules

A virtual module is a structure that units are compiled against by its
signature alone, and whose implementation the program's build file chooses
(D17; the brief's case: the Basis Library's `IntInf` swapped for another).
A unit declares it in SML:

```sml
structure BigInt = _virtual : BIGINT
```

and the build file says, before that unit, which files implement it:

```
bigint_sig.sml
implements BigInt = digits.sml end
bigint.sml                          (* structure BigInt = _virtual : BIGINT *)
main.sml
```

The implementing files end by exporting a structure of the module's name
and signature (`_export structure BigInt : BIGINT = ...`), and the virtual
declaration takes its slots, as `_dynamic` takes a loaded module's
(docs/units.md, Dynamic modules): `RuneDynamic.take` finds the export of
that name, where the fingerprints of the signature agree. The files after
an `implements` block see nothing that it declares, so the units compiled
against the virtual module name nothing of the implementation, and another
implementation compiles none of them again: `examples/virtual/bigint` has two,
the Basis Library's `IntInf` (`intinf.build`) and lists of digits
(`digits.build`), and the second build through the first one's cache
compiles `digits.sml` alone (`virtual-cache` of `tests/runner/scenarios.sml`). A program has one
implementation of each virtual module: two are refused. One without any is
compiled, and raises `Dynamic.Mismatch` when the declaration runs. Unlike a
loaded module, a virtual module is part of the program, which can be
compiled whole (`--whole`).

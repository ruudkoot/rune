# Build files

A build file says what a program, a library or the Basis Library is made of:
its files, in what order, which of them are a library's and which names the
library exports, which implementation a virtual module has, and what each
unit may do (the incremental roadmap's M10; D16). `rune --build FILE`
compiles what a build file says, in units (docs/units.md), through the
cache. The file's extension is `.build`.

Its semantics is MLB's (MLton's ML Basis system): a *basis* -- the
structures, signatures, functors, types, values and fixity in scope -- is a
value; a file is compiled in the basis before it and adds what it declares
to it; `local`, export lists and renaming say what of a basis the files
after it see; each build file is elaborated once. Its syntax is Rune's own.

## The language

```
build    ::= dec ...
dec      ::= path                            a file, compiled in the basis before it
           | "files" path ... "end"          files, in the order given
           | "group" path ... "end"          files, in the order the modules they
                                             declare and use give (docs/units.md, The graph)
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
                                             or dependencies in library metadata
           | "inline" "functor" id ... "end" functors copied into every unit that
                                             applies them (below)
           | "inline" "val" name ... "end"   functions copied into every unit that
                                             names them (below)
exports  ::= "(" export "," ... ")"          export ::= kind id
kind     ::= "structure" | "signature" | "functor" | "type"
path     ::= a file's path, relative to the build file's directory, in which
             $(NAME) is the path variable NAME (--path NAME=DIR)
name     ::= a long name of a value, as a word, or as a string where it holds
             characters a path does not ("Word32.>>")
string   ::= "..."
```

Comments are SML's, `(* ... *)`. A path is a word of letters, digits and `/
. _ - $ ( )`, or a string.

## Units and bases

Every file is a unit. A build file elaborates to the list of its units in
order, each with the basis it is compiled in, which is what `rune --build`
compiles: the cache serves each unit whose usages hold, in that basis
(docs/units.md, The cache), and `--whole` makes one program of them all
(M7). `rune --build-list FILE` prints the files in order, which is what the
hosts' build files are made from (`scripts/gen-build-files.sh`).

* A sequence of declarations elaborates each in the basis the ones before
  it leave.
* `local A in B end`: B is elaborated in the basis A leaves; the files
  after it see what was before it and what B declared.
* `library (structure X, signature S) = D end`: the files after it see X
  and S of what D declared, and nothing else of D.
* `use FILE`: the declarations of another build file, in place; a build
  file used twice is elaborated once, the second use adding what the first
  declared.

## Annotations

`annotate "NAME" ... in D end` gives the units of D:

| Annotation | What it does |
|---|---|
| `allowPrim` | the units may use `_prim` and `_overload` (the Basis Library's) |
| `noWarnings` | their warnings are not printed |
| `ascii`, `unicode` (or `unicode=utf8`), `unicode=latin1` | the mode the units are read in, over the command line's `--unicode[=ENC]`; the last such annotation in force wins ([units.md](units.md), *Source modes*) |

Annotations also apply through a `use` edge. For example,
`annotate "unicode" "allowPrim" in use implementation.build end` gives
those annotations to the included units; annotations inside the included
build can override their source mode. Repeated `use` still elaborates
the build once, in its first occurrence's context.

The compiler library's `RuneCompiler.Project` API uses this same scoped
planner. It can discover ordered files without parsing their programs;
`group` uses the compiler's dependency discipline and records the source
inputs needed to determine its order. Windows project resolution handles
absolute drive and UNC paths explicitly, including expanded path variables.

Levels per unit (`O0` ... `O2`) are not built: a build has the level of
its command line.

## A library's build file

A library of `--lib` -- the Basis Library (`lib/basis/library.build`),
`lib/random`, `lib/test/property`, `lib/test/property/basis` -- has a
build file `library.build` that lists its files in load order, each in an
`annotate` block that says what it is to a program:

| Annotation | What it does |
|---|---|
| `always` | the file is compiled before every program |
| `demand` | it is compiled before the programs that name what it provides, and the files that need it |
| `seal` | as `demand`, but for no file of the library: it binds a structure again as its signature shows it |
| `final` | it is compiled after every program |
| `host=swap`, `host=no` | how `bin/rune-generate host-basis` gives the file to the other SML systems |

`libraries random end` names the libraries it is written on. In an
ordinary program build, the declaration selects those libraries as
`--library random` does; explicit command-line selections are retained.
What each
file provides and requires is not written down: `rune --basis-index DIR`
works it out from the sources (`Deps`, docs/units.md, The graph) and writes
`DIR/MANIFEST`, which is what the compiler reads (`BasisManifest`). `make
manifests` makes them all, and they are not committed.

A library can put all its sources inside one explicit export boundary:

```sml
libraries json end
library (structure Api, signature API, functor Make, type item) =
  use implementation.build
end
```

Files inside that boundary can use each other's private declarations. A
program or another library sees the listed exports. This applies to
whole-program compilation, compilation in units and cache reuse. Private
fixity declarations stay inside the library, and its final files are
elaborated in its private context. An export must be declared before the
program; `--basis-index` and `--basis-check` reject missing exports or the
wrong kind of declaration. An invalid index leaves the existing manifest
intact.

The generated manifest records the complete boundary in an optional sixth
column, using words such as `structure:Api signature:API`. Every row of
one library has the same boundary. Existing five-column manifests keep
their existing visibility. `runedoc` uses the boundary when selecting
public pages and elaborating dependencies. A library without an explicit
boundary retains its existing names.

**What a library exports is ASCII.** Standard ML has no escape for a
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
not (S77 of `tests/incremental/SCENARIOS.md`). A whole compile and
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
compiles `digits.sml` alone (`tests/buildfile/run.sh`). A program has one
implementation of each virtual module: two are refused. One without any is
compiled, and raises `Dynamic.Mismatch` when the declaration runs. Unlike a
loaded module, a virtual module is part of the program, which can be
compiled whole (`--whole`).

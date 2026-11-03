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
to it; a library's exports say what of a basis the files after it see;
each build file is elaborated once. It differs from MLB in one thing: `use`
elaborates a build file in the basis of its caller, where an `.mlb` starts
from an empty one, so a file used sees what comes before the `use`. A module
is renamed where a library is imported, and nowhere else (*Clashes*, below).
Its syntax is Rune's own.

There is one way to say each thing (the build-system roadmap's D6). Files are
compiled in the order written, which is their meaning: the order of effects
cannot be worked out from the sources, and an order worked out from them is
for `-j` alone. A boundary is a library's (*A library's build file*, below).
What a build file says is read by one reader, `CompilerProject`, whatever
reads it -- a compile, an editor, a library's index, `--plan` -- and what the
command line says is a plan too (*The plan*, below).

## The language

```
build    ::= dec ...
dec      ::= path                            a file, compiled in the basis before it
           | "files" path ... "end"          files, in the order given
           | "use" path                      another build file, elaborated once
           | "implements" id "=" dec ... "end"
                                             the implementation of the virtual
                                             module or functor id (below)
           | "annotate" string ... "in" dec ... "end"
                                             what the units inside may do (below)
           | "libraries" import ... "end"    libraries selected by this build,
                                             or what a library with no header is
                                             written on
           | "view" id                       the program's view of the Basis
                                             Library (below)
           | "inline" "functor" id ... "end" functors copied into every unit that
                                             applies them (below)
           | "inline" "val" name ... "end"   functions copied into every unit that
                                             names them (below)
           | "generate" path [ arguments ] [ "inputs" path ... "end" ]
               "outputs" path ... "end"      a step: a tool the build runs before
                                             it reads a source (Generated sources)
           | "preprocessor" id path [ arguments ] [ "inputs" path ... "end" ]
                                             a class of files, each given to a
                                             tool, whose output is compiled
                                             (Generated sources)
arguments ::= "(" arg "," ... ")"            arg ::= a word or a string, given
                                             to the tool as written
header   ::= ( "requires" import ... "end"    what a library's build file says
             | "exports" exports              first (A library's header, below)
             | "friends" path ... "end"
             | "view" id exports              a named subset of its exports
             | "shadows" exports              Basis Library names its exports take
             | "strict"                       its units held to be well-formed
             | "virtual" modules              the virtual modules it declares
             | "implements" modules ) ...     those of a library it requires that
                                             it implements (Virtual libraries)
import   ::= path [ "(" rename "," ... ")" ]  a library, and what is renamed of it
rename   ::= kind id "as" id                  kind not fixity (Clashes, below)
older    ::= "library" exports "=" dec ... "end"
                                             a library with no header: its boundary,
                                             around all its files (below)
exports  ::= "(" export "," ... ")"          export ::= kind id
modules  ::= "(" module "," ... ")"          module ::= ("structure" | "functor") id
kind     ::= "structure" | "signature" | "functor" | "type" | "fixity"
path     ::= a file's path, relative to the build file's directory, in which
             $(NAME) is the path variable NAME (--path NAME=DIR, below)
name     ::= a long name of a value, as a word, or as a string where it holds
             characters a path does not ("Word32.>>")
string   ::= "..."
```

Comments are SML's, `(* ... *)`. A path is a word of letters, digits and
`/ . _ - + ~ #`, with `$(NAME)` anywhere in it, or a string, which holds any
other character. A word the language does not know is an error, an annotation
included, and so are the words it no longer has (*What is gone*, below).

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

`rune --build-list FILE` prints the build's closure in order, which is its
plan flattened (*The plan*, below): the files of the libraries it names and
of those they are written on, each library's in its load order and each
before what is written on it, then the build's own files, then the
libraries' `final` files. A whole library is listed, all a program may name:
`--basis-deps` says which of its files a compile takes. The Basis Library is
every program's and is not listed. The other SML systems, which build the
compiler before there is one, read the same list from the plans committed
beside the build files of the programs they build (`rune.plan`, ...) with
`scripts/plan-files.sh`, which needs no compiler ([building.md](building.md),
*How a host gets its list*).

* A sequence of declarations elaborates each in the basis the ones before
  it leave.
* `use LIB/library.build`, a library's build file with a boundary: the files
  after it see what the library exports, and nothing else of what it
  declared.
* `use FILE`: the declarations of another build file, in place, in the
  basis of the `use`; a build file used twice is elaborated once, the second
  use adding what the first declared, as far as the files after the second
  use may see it. A build file with a boundary of its own adds what that
  boundary exports at every use, so that libraries can share it whatever
  order they come in. Of one without, a boundary that has closed around the
  first use -- a library's, an `implements` -- stands between the two: the
  second use adds what that boundary lets out, and nothing more. Inside the
  same boundary, it adds all of it. (A first `use` of a build file under
  another library's boundary is another matter: that reaches in, below.)

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
| `preprocess=NAME` | the units are in the class of the preprocessor NAME: what they compile is what its tool makes of each (*Generated sources*, below); the last such annotation in force wins |

An annotation that is none of these, or of a library's below, is an error.

Annotations also apply through a `use` edge. For example,
`annotate "unicode" "allowPrim" in use implementation.build end` gives
those annotations to the included units; annotations inside the included
build can override their source mode. Repeated `use` still elaborates
the build once, in its first occurrence's context.

## Exports

A library exports what a source of it declares: a file inside its boundary,
or a build file used there, again too. An export that names anything else is
an error, by one rule wherever a boundary is read: the index
(`--basis-index`) and a compile that uses the library's build file say so
alike. A name that was only in scope is not the library's to export: a
structure of the Basis Library is in every client's scope already, and so is
one of a library a client requires. A library that means to pass such a name
on declares it in a source, `structure List = List` or a structure that adds
to it, which makes it its own. `type t` exports
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
planner, which reads build files and never a source. Windows project
resolution handles absolute drive and UNC paths explicitly, including
expanded path variables.

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
| `view=NAME` | with `seal`, in the Basis Library's build alone: the file is a seal of its view `NAME` (*Views of the Basis Library*, below) |
| `host=only` | the file is the other SML systems' alone, in place of a `host=no` file of the same module after it, and Rune does not compile it: one module of a name in a scope ([units.md](units.md), *Well-formed units*) |

`libraries random end` names the libraries it is written on, where it has
no header. In an ordinary program build, the declaration selects those
libraries as `--library random` does; explicit command-line selections are
retained. What each
file provides and requires is not written down: `rune --basis-index DIR`
works it out from the sources (`Deps`, docs/units.md, The graph) and writes
`DIR/MANIFEST`, which is what the compiler reads (`BasisManifest`). It reads
the build file as a compile does, through `CompilerProject`, and lives in
`LibraryIndex`, which the compiler's driver and `runedoc` both reach. `make
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
one a header must have, but for an implementing library's, which says
`implements` in its place (*Virtual libraries*, below). A `use`d build file and
a program have no header.
`strict` holds the library's units to the rules of a well-formed unit:
`--basis-index` refuses one that breaks them, where another library is warned of
it once ([units.md](units.md), *Well-formed units*). An `always` file is a
prelude and a `final` file an entry unit, which they need not keep.
`requires` is what a program's build calls `libraries`, renames included
(*Clashes*, below); a library with a header does not write `libraries`.
`shadows (structure RuneCompiler)` says which names of the Basis Library its
exports take the place of (*Clashes*), as `lib/compiler`'s does.

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
* **`view NAME (...)` is a named subset of the exports.** `libraries lib#NAME end`,
  `requires lib#NAME end` or `--library lib#NAME` see that subset, and the
  files that link are the closure of what they name of it, as for the whole
  library. A view has no files of its own, needs no loading primitive and costs
  no second copy of anything (D8). It is a library's, and has a list; a
  program's `view NAME`, with none, is a view of the Basis Library, another
  thing (*Views of the Basis Library*, below).

`--basis-index` writes a header to the manifest's comment lines, `# library:`
for what is required, as the readers of a manifest have always read it, and
`# exports:`, `# friends:`, `# view:`, `# shadows:`, `# virtual:`,
`# implements:` and `# fixity:` for the rest, with words such as
`structure:Api signature:API`, and `-` for none. A library required
with renames is one word on its `# library:` line, `same(structure:Same=One)`,
which is how every reader of a list of libraries keeps it. `runedoc` uses the boundary when
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
block around all its files, which leaves the rest of its meaning as it is:

```sml
libraries json end
library (structure Api, signature API, functor Make, type item) =
  use implementation.build
end
```

The manifest records that boundary in an optional sixth column, and every
row of one library has the same one. The block is a library's: it stands in a
`library.build`, around every file of it, and nowhere else. It stays for the
libraries that have not moved to a header, and goes when the last has
(the build-system roadmap's D15).

### Clashes

Two imports of one name in one scope are a clash, and an error (the
build-system roadmap's D9): two libraries that export it, or a library and the
Basis Library. A program's clashes show when it is compiled and a library's
when it is indexed, not in its clients:

```
tool.sml:1:1: error: this scope has Same from both the library lib/one and the library lib/two: rename one where it is imported, as two (KIND Same as OTHER) does (docs/build.md, Clashes)
```

A rename at import answers it. After a library's name, wherever a list of
libraries has one -- `libraries`, a header's `requires`, `--library` --
parentheses give what the scope takes of it under another name:

```
libraries terminal test/runner (structure History as RunnerHistory, signature HISTORY as RUNNER_HISTORY) end
```

This is how a program has both of this tree's `History` structures, the line
editor's (`lib/terminal`) and the test runner's (`lib/test/runner`), which
before it no order of the two libraries reached. On the command line it is one
argument, `--library 'test/runner (structure History as RunnerHistory)'`.

* A structure, a signature, a functor and a type can be renamed, not a value or
  a fixity: a value would lose its status as a constructor. What is renamed is
  the binding, which keeps what it is: `Two.v` is the same value as the
  library's `Same.v`, and a type is the same type.
* The scope has the new name in place of the old; it may rename two names to
  each other's. A rename names something the library exports (or, with no
  header, declares), each name once, and gives a name the import does not have
  already; two imports of one library in one scope rename alike.
* A rename is the scope's: the library's own files, and its other clients, see
  its names as they are. The cache holds a client to the binding it named,
  whatever the name (*Units and bases*, above): renames that change places
  compile the client again.
* What a library declares itself wins over what it imports, and is no clash.
  Private names never clash, since a unit's identity holds them apart.
* A library with no header keeps its meaning (D15): two with none shadow each
  other as they always have, the later in the order they are compiled, unless
  a rename gives the name, which is held to the rule. A library with no header
  renames nothing it is written on: its files see all that comes before them.

The Basis Library cannot be renamed, since nothing imports it by name. A library
takes a name of it only where its header says so, `shadows (structure
RuneCompiler)`: then a scope that imports the library has the library's in
place of the Basis Library's, and no clash. `lib/compiler` does this, so that
`RuneCompiler` is the compiler's API in its clients and the REPL's controls
(`lib/basis/compiler.sml`) everywhere else; a client that wants both renames
the library's, `compiler (structure RuneCompiler as Api)`. `--basis-index`
refuses a `shadows` that names no export, or no name of the Basis Library; a
rename onto a name of the Basis Library is a clash.

Clashes are compared by name, not by kind: no name of this tree is two kinds.
`--no-warnings` does not silence a clash, which is an error.

### Views of the Basis Library

A view of the Basis Library is the same code under narrower signatures (D12),
as SML/NJ's `basis-2004.cm` and MLton's `basis-2002.mlb` are: a set of seal
files in the Basis Library's build, each annotated `view=NAME`, which bind
structures again as the view shows them:

```
annotate "seal" "view=narrow" "host=no" in
  view_narrow_list.sml
end
```

```sml
(* view_narrow_list.sml *)
signature LIST_NARROW = sig ... end
signature LIST = LIST_NARROW
structure List : LIST = List
```

A program chooses one with `view NAME` in its build file, or `--basis-view
NAME`; both must agree. The Basis Library this tree ships has no view yet; the
mechanism is tested on a fixture's (`tests/runner/librarymodel.sml`,
Namespaces).

* **The seals load after the libraries,** in the program's scope alone, so a
  library sees the Basis Library whole and its values and types cross to a
  client in the view. Before them, the compiler's own library would fail:
  it uses members a narrower view hides (E4).
* **A view is a filter of names, not a capability.** A library that declares
  `structure L = List` gives its clients the whole `List`. A functor of a
  library that wants `LIST` is refused a client's narrower `List`: that is the
  signature system working.
* **What is wired in stays outside.** A view's file declares structures and
  signatures, nothing else (`--basis-check`).
* **No new cache configuration.** A view's seals are units; a program in the
  view names their bindings, which the cache holds it to, so one cache serves
  every view, in any order.
* A library's own view of the Basis Library needs none of this: a seal file
  inside its boundary, which its clients do not see. `view NAME` in a
  library's build is refused, and so is `view=NAME` outside the Basis
  Library's.

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

## The plan

`rune --plan FILE.build` prints the plan of a build: what it compiles, in
the order it compiles it, as text that any program can read without Rune and
without a parser (D5). Given files and `--library` instead, it prints the
plan the command line makes, which is the plan a compile of them follows:
`--library`, `--basis`, `--no-prelude`, `-I` and a list of files say what a
build file says, and there is one plan either way. Given a `FILE.plan`, it
reads that and prints it again, the same bytes.

The plan of `app/app.build`, which says `libraries json end`, `use
part.build`, `main.sml` and `use part.build` again, made at the top of the
checkout (`unit unicode:` lines left out):

```
rune-plan 1
basis demand
library unicode lib/unicode
  form open
end
library json lib/json
  form open
  requires unicode
  unit json:json_sig.sml lib/json/json_sig.sml ascii demand
  unit json:json.sml lib/json/json.sml ascii demand
end
program
  requires json
  use app/part.build
    unit app/part.sml app/part.sml ascii
  end
  unit app/main.sml app/main.sml ascii
  replay app/part.build
end
provenance
  input app/app.build ca0d3cfe08b9b5d794694319ffc6a47fd7a1b0a1d616688b4a8b93c6d27dee2d
  input app/part.build ec7f89648f9fc1c61929d8c1754c0c1dd4c0a8174b6fb5598c1460dc02e19e2c
  input lib/unicode/library.build 18c62bc8047180ebbce66622b16acab697f4ffca2509d432710d25273253b855
  input lib/json/library.build 452367689d73def6ab952443ca574e1a8ff0d920167ddd35a54e3d2d59eac449
end
```

A line is words: what it is, and its fields, indented by what holds it. A
field holds no space: `%`, a space and what is not printable ASCII are
`%xx`, and an empty field is `%-`. So `awk '$1=="unit"{print $3}'` lists the
files, as `--build-list` does but for the libraries' final files, which come
last there.

| Line | What it says |
|---|---|
| `rune-plan 1`, `rune-plan 2` | the version of the text: 2 where the plan has a step, a preprocessor or a virtual library, which version 1 has not, and 1 where it has none |
| `basis B` | `demand`, `all` (`--basis all`) or `none` (`--no-prelude`); the Basis Library itself is implicit, as in a build file |
| `view NAME` | the program's view of the Basis Library, where it has one (`view NAME`, `--basis-view`) |
| `inline functor F`, `inline val f` | what the program's build files mark to be inlined, sorted |
| `preprocessor NAME TOOL DIR` ... `end` | a preprocessor's class: its tool, the directory it runs in (its build file's), `argument A` for each argument and `reads PATH` for each input (*Generated sources*) |
| `generate TOOL DIR` ... `end` | a step, in the order declared: as a preprocessor, then `closure PLAN` and `stamp TOOL ARG ...` where it has them, and `writes PATH` for each output; printed, never run |
| `library NAME DIR` ... `end` | each library the program names, with those they are written on, each before what is written on it: its name, as a unit's name begins, and its directory |
| `form F` | `header`, `block` (the older form) or `open` (no boundary) |
| `requires L` | the libraries it is written on, as written, in order: `requires` or `libraries`, a library with renames as one word, `same(structure:Same=One)` |
| `export KIND NAME`, `view V` ... `end`, `friend PATH`, `shadow KIND NAME` | its boundary, its views, its friends and what it shadows of the Basis Library, sorted |
| `virtual KIND NAME`, `implements KIND NAME` | the virtual modules a library declares, and those of another that it implements, sorted (*Virtual libraries*, below) |
| `continue NAME` ... `end` | a virtual library's steps from the first file that declares a virtual module on, after the last library that implements one |
| `program` ... `end` | the program, with what it `requires` (`libraries` and `--library`) |
| `unit NAME PATH MODE ANNOTATION ...` | a file: its unit's name, as a compile names it (units.md, *Names*), its path, the mode it is read in and its annotations |
| `use KEY` ... `end`, `replay KEY` | a build file's steps the first time it is used, and its second use, which adds what the first declared as `use` says above |
| `boundary` ... `end` | a library's build file used by a build, with its exports, then its steps |
| `implements NAME` ... `end` | a virtual module's or functor's implementation |
| `provenance` ... `end` | how the plan was made, outside what two forms of one plan compare on: each build file read, `input PATH SHA256`, which `sha256sum` checks |

A path is from the current directory, a library's too, wherever `--lib` is:
a plan made at the top of a checkout holds no directory of the machine, and
one made elsewhere spells the way there. Nothing in a cache reads a plan, and
the plan is Rune's: it says what the build language says, in a form that a
host, a tool or another build system reads without the compiler. The words
`edge` and `scc` are kept for what a plan discovered from the sources would
add, an edge between units and a group of units that use each other; a plan
of version 1 has neither, and a reader refuses them, as it refuses any word
it does not know. Version 2 is version 1 with steps and preprocessors, and
with virtual libraries, and a plan with none of them is printed as version 1,
so that every plan a reader of version 1 could read is one it can: of the five
committed plans, `rune.plan` and `runedoc.plan` are of version 2, for their
step (*Generated sources*), and the rest of version 1. `scripts/plan-files.sh`
reads both; it lists a step's outputs as the files they are, since a host
makes them itself, refuses a file that a preprocessor makes what is compiled
of, and lists a virtual library's files in the order the plan gives them,
which is the order a compile takes them in.

## Generated sources

A build may say what makes its sources, as a *step* or a *preprocessor*,
and runs them before it reads a source: the build-system roadmap's D16, in
the manner of Bazel's declared outputs and holbuild's `[[generate]]`.
Planning runs neither: `--plan`, `--build-list` and an editor read a build
as it is written, and a step is in the plan's text (*The plan*, above) as
what it is, not what it made. So the graph is static, and a step cannot
add a unit or an edge. A step and a preprocessor belong to a program's
build files, and a library's `library.build` declares neither.

```
(* a step: the tool, its arguments, what it reads, what it makes *)
generate gen/tables.sh (tables.txt, tables.sml)
  inputs gen/tables.sh tables.txt end
  outputs tables.sml end
tables.sml                          (* a unit, as any file is *)

(* a step that reads a plan's files, and git, which its stamp asks *)
generate scripts/gen-version.sh (--config, rune.plan, build/config.sml)
  inputs scripts/plan-files.sh end
  closure rune.plan
  stamp scripts/gen-version.sh (--stamp)
  outputs build/config.sml end

(* a preprocessor, and the files it is given *)
preprocessor quote $(HOLDIR)/bin/unquote inputs $(HOLDIR)/tools-rune/bin/unquote.rbc end
annotate "preprocess=quote" in
  files src/boolScript.sml src/boolLib.sml end
end
```

A tool is a path, as a source's is, and runs in the directory of the build
file that declares it: a step as `TOOL ARG ...`, a preprocessor as
`TOOL ARG ... INPUT OUTPUT` for each file of its class, where INPUT is the
file and OUTPUT a file the tool writes. A tool that exits other than 0 stops
the build.

**A step** is run before the units are read, in the order the build file
declares the steps, the directory of each of its outputs made first, and
each of its outputs must be there after it, or the build stops. It says
what it reads, in that order after its arguments:

* `inputs PATH ... end`, files;
* `closure PLAN`, a plan (*The plan*, above) and every file it names, as
  `scripts/plan-files.sh` names them to a tool: the build files it was
  made from, then the files it lists, less the step's own outputs;
* `stamp TOOL (ARG, ...)`, a command, run where the tool runs, whose output
  stands for what the step reads that no file names: git's state, for
  `scripts/gen-version.sh --stamp`, which prints the version alone. A stamp
  is asked on every build, an up-to-date one too, and one that fails stops
  the build.

Its key is its tool's bytes, its arguments, its inputs' paths and bytes,
its closure's, and its stamp's tool's bytes, arguments and output. The cache
(`--cache-dir`) keeps, under `steps/`, the key a step last ran under and the
hash of each output it made:

* a step whose key and outputs are as kept is not run;
* one whose key is not runs again: its outputs are stale, and a tool that
  fails or leaves one unmade stops the build, so that what was there is not
  compiled;
* an output that is not what its step made under the key it still has is
  refused, since it was changed after: by hand, or by another tool. Remove
  it, and the build makes it again;
* a step that says nothing of what it reads runs on every build, since
  nothing says when it is due, and its build is never up to date;
* with `--no-cache` nothing is kept, and every step runs.

`rune.build`'s first step, above, writes `build/config.sml`: the version,
git's, and the compiler's identity, a hash of `rune.plan` and its closure
([building.md](building.md), *The compiler's identity*), which is what the
hosts' build runs too. Its stamp is the version as the step would write it,
so a commit, a checkout, a tag, an edit of a tracked file or a `git add`
that changes `-dirty` each run it again, as an edit of a file of
`rune.plan`'s closure does.

A build that is up to date ([units.md](units.md), *A warm build*) runs no
step: what each step read and its stamp's answer are in what the build
rests on, and what each step made is held by its bytes.

A step's outputs are files of the tree, which units name as they name any
file: a unit is not told what made its file, and its key is the file's
bytes. The other SML systems read a step's outputs from the plan as files
they have, and make them by their own means (`build/config.sml`, by make).

**A preprocessor's** output is what a unit of its class compiles, under the
file's name, so that a diagnostic names the file, at the line of the output
(a filter that keeps the lines, as HOL4's does, keeps them right). A unit's
key is the output's bytes, so that a build after an edit of the file is the
build of what the edit makes of it, warm as cold. Outputs are kept in the
cache by the tool's bytes, its arguments, its inputs' bytes and the file's,
and the tool is given a file only where none is kept. `rune --deps --build`
preprocesses as a compile does; an editor reads the files as they are. A
host has no preprocessor, and `scripts/plan-files.sh` refuses a plan with a
file in the class of one.

A set of generated sources that its generator writes once, and that is
committed, is not a step: `runeffi` writes the sets under `lib/ffi/*/generated`
by an explicit command, with the text of each set's build files in its hash
(docs/plans/runeffi.md). `runeffi rehash --out DIR` gives a set its hash
again after an edit of its build files, without the headers it was generated
from.

## What is gone

The language had more ways to say a thing, which it no longer has (D6).
Each is an error now, which says what to write:

| Was | Now |
|---|---|
| `group a.sml b.sml end`, files in the order their modules give | the files in the order they are compiled; `rune --deps` prints an order the modules give |
| `local A in B end` | a library: A and B behind a boundary that exports what B declares, used where the `local` was |
| `cache DIR` | `--cache-dir DIR` |
| `library (...) = ... end` in a program's build | a library's own `library.build`, with a header, used where the block was: `use DIR/library.build` |

A `library.build` with a `library` block keeps it (*A library with no
header*, above). `RuneCompiler.Project` has no cache directories, and its
inputs are the build files alone.

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

A functor can be virtual too (the build-system roadmap's M21):

```sml
functor Table = _virtual (K : KEY) : TABLE where type key = K.t
```

is a functor of the parameter's signature `KEY` and the result's `TABLE`, in
which `K` is the parameter, and nothing else; its implementation ends a file
of an `implements Table = ... end` block with `_export functor Table (K : KEY)
: TABLE where type key = K.t = ...`. An application is typed by the two
signatures alone, its table and its exception new, its key the parameter's,
and compiled as a call of the implementation's function, which the
declaration takes (`RuneDynamic.take`, as for a structure) where the
fingerprints of the two ABIs agree (docs/units.md, Dynamic modules): no unit
after the block names the implementation, and none copies its body.
`examples/virtual/table` has two, an association list (`list.build`) and a
balanced tree (`tree.build`), each applied to two kinds of key; the second
build through the first one's cache compiles `tree.sml` alone, each gives
the same output, and `--whole` the bytes of the same files compiled whole
(`virtual-table-*` of `tests/runner/scenarios.sml`). With no implementation
the program compiles, and the declaration raises `Dynamic.Mismatch` when it
runs; with two the build is refused; an implementation compiled against
another `KEY`, which only the block sees, is refused when the declaration
runs. `functor Table = _dynamic "table.rbu" (K : KEY) : TABLE where type key
= K.t` (`dynamic.sml`, `dynamic.build`) takes it from a unit instead, a
plugin compiled apart (`plugin.build`). `implements NAME` names a structure
or a functor, and a build implements a name once. `where type` between two
virtual modules is not built: a virtual functor's result names its own
parameter's types alone.

## Virtual libraries

A library can be virtual too (the build-system roadmap's D22, M22): its
header says which of the modules it exports are virtual, and another library,
whose header says it implements them, is their implementation. A program names
the virtual library and one implementation of it, and its units are compiled
against the virtual library alone: another implementation compiles none of
them again, as dune's virtual libraries do. `examples/virtual/table` builds
so as well as by its build files above, from three libraries under
`libraries`, which its root file names (*The workspace*):

```
(* libraries/table/library.build: the virtual library *)
exports (signature KEY, signature TABLE, functor Table)
virtual (functor Table)
../../key_sig.sml
../../table_sig.sml
../../table.sml                     (* functor Table = _virtual (K : KEY) : TABLE where type key = K.t *)
```

```
(* libraries/table-list/library.build: an implementation *)
requires table end
implements (functor Table)
../../list.sml                      (* _export functor Table (K : KEY) : TABLE where type key = K.t = ... *)
```

```
(* list-libraries.build: the program, with Table an association list *)
libraries table table-list end
main.sml
```

`tree-libraries.build` names `table-tree` instead, and through the cache
`list-libraries.build` made it compiles `tree.sml` alone: `main.sml` and the
virtual library's three files come from the cache (`virtual-libraries` of
`tests/runner/librarymodel.sml`).

* **A virtual module is declared in its library,** with `_virtual` at the top
  level of a file that the library's build lists itself, as a structure or a
  functor (*Virtual modules*, above), and it is exported. `--basis-index`
  refuses a `virtual` that no file declares so, a `_virtual` the header does
  not name, and a file before the declaration that declares its name.
* **An implementing library adds no public module.** Its header says
  `implements (KIND NAME, ...)` in place of `exports`, and it exports nothing:
  what it implements is reached through the virtual library, and all else it
  declares is its own. Each module it names is a virtual module of a library
  it requires, of one library, and its files end with `_export KIND NAME ...`
  of each and of nothing else. `--basis-index` refuses one that does not, and a
  file of it that names what the virtual library declares from its first
  virtual module on, which is compiled after it (below).
* **One implementation per program.** Two libraries of a program that
  implement one virtual module, or declare one, are refused, and so is an
  `implements NAME = ... end` of a program's build that names a library's
  virtual module: a program's files come after its libraries'. A program
  with no implementation is compiled, and the declaration raises
  `Dynamic.Mismatch` when it runs, as a virtual module's of a build does.
* **The order.** The libraries are compiled each after what it requires; an
  implementation comes right after its virtual library, after what else it
  requires, and runs before the virtual library's files from the first that
  declares a virtual module on, which take what it exported. Those files, and
  a library written on the virtual library, come after it. So
  `list-libraries.build` compiles `key_sig.sml`, `table_sig.sml`, `list.sml`,
  `table.sml` and `main.sml`, in that order, which `--build-list` prints and
  the plan says: the virtual library's rest is a `continue table` after
  `table-list`. What is named is what loads: a program that names no virtual
  module of the library takes nothing of its implementation.

The kind is part of the name here: an implementing library names a structure
or a functor, and a program can have a virtual structure and a virtual
functor of one name from its libraries. A build file's `implements NAME =
... end` names neither, and keeps to one of a name. The win32 work's three
drivers, `native`, `sdl` and `mock` of `ffi/win32`, one virtual `Win32`, have
this form; they move to it with that work (the roadmap's D15).

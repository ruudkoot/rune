# The REPL

`bin/rune-repl` -- or `rune -i`, which every `rune` wrapper turns into the
`rune-repl` beside it -- reads top-level declarations, compiles and runs
each, and says what it declared:

```
$ bin/rune-repl
- val l = map (fn x => x * 2) [1, 2, 3];
val l = [2, 4, 6] : int list
- datatype 'a tree = Leaf | Node of 'a tree * 'a * 'a tree;
datatype 'a tree = Leaf | Node of 'a tree * 'a * 'a tree
- Node (Leaf, "x", Leaf);
val it = Node (Leaf, "x", Leaf) : string tree
```

A declaration ends with a `;` at the top level, as in every SML REPL: the
REPL reads lines, `- ` before the first of a declaration and `= ` before the
others (`Compiler.prompt1`, `Compiler.prompt2`), until what it has read
parses and ends with one. Files given on the command line are `use`d before
it reads anything, and the end of the input ends it.

## What a declaration does

The REPL follows Chapter 8 of the Definition, a declaration at a time:

* A declaration that does not elaborate is reported, with its file, line and
  column, and the session is as it was before it: nothing it declared is
  there, and the declarations after it go on.
* A declaration whose running raises an exception nothing handles is
  reported (`uncaught exception ...`). What it did before it raised is done
  -- a `ref` it assigned stays assigned -- and it binds nothing.
* A declaration that completes extends the session; an expression `exp;`
  binds `it`.

Each declaration is compiled against what the ones before it declared, so a
function keeps what it saw: `val x = 1; fun h () = x; val x = "two"; h ();`
gives `1`.

## `use`

`use file` (`Compiler.use`) compiles the declarations of `file` and runs
them, one after another, as if they had been typed: each declaration the
file completes stays in the session, even when a later one fails. A
declaration that does not compile stops the file there and `use` raises
`Fail`; one that raises an exception stops it too, and the exception goes on
to the caller of `use`. A file may `use` another, and a declaration of the
session may call `use`: what it compiles is the session's at once, and the
declaration's own bindings join it once it has run.

A file's declarations are units named by the file and their place in it,
kept in the cache of units -- `$RUNE_CACHE`, else `.rune` beside the file
([units.md](units.md), *The cache*) -- and a declaration whose usages hold,
the names it uses bound as they were, is linked from there rather than
compiled: a file used again, unchanged, compiles nothing, and its top level
runs again with globals of its own.

## Interrupts

Ctrl-C interrupts the declaration that is running: it is reported,
`Interrupt`, and is as one that raised -- what it did is done, and it binds
nothing -- and the session goes on. A handler of the declaration's own
takes it as any exception: it is `SML90.Interrupt`. At the prompt it drops
what has been typed of a declaration. The REPL catches it from its start
(`Runtime.catchInterrupt`, [runtime.md](runtime.md), *Interrupts*), and
masks it while it does its own work -- reading what it has been given,
compiling, echoing -- so that an interrupt then waits, and is taken by the
declaration once it runs, or by the wait for the next line; a `use` masks it
the same way, a declaration at a time.

## Printing

The REPL echoes every value a declaration binds, `val x = ... : t`, in the
order of the names, and the other things it declared by kind: `datatype`
with its constructors, `type`, `exception`, `structure`.

A value is printed by code made from its type (the incremental roadmap's
D10): for each declaration the REPL writes a printer of the types it bound,
compiles it with the declaration, and runs it after (`src/repl/show.sml`).
The printer is Standard ML, built from the pieces of `RuneShow` in the
library, so it takes a value apart as the rest of the program does --
`case` over a datatype's constructors, `#1` of a tuple, `!` of a `ref` --
and never looks at a value's bits, which since the word layout say nothing
of its type ([runtime.md](runtime.md), *Values and objects*):

* an `int`, a `word`, a `real`, a `char` and a `string` as their `toString`
  shows them, a `word` with `0wx`, a `char` and a `string` quoted;
* a tuple, a record, a list, `ref`, an array (`fromList[...]`) and a vector
  (`#[...]`) by their parts;
* a datatype by its constructors, an argument that is an application in
  parentheses, whether or not the constructors are in scope: the printer
  names them by names of its own (`rune'c<stamp>'<tag>`), bound to the
  constructors the elaborator registered for the type (`Elaborate.dataCons`);
* a function as `fn`; an abstract type -- one made by `:>` -- and a type
  variable as `?`; an exception by its name.

`Compiler.printDepth` (20) is how many levels of a value are shown, from the
outside in, before the rest prints as `...`.

## How it is built

The REPL is one program with what it compiles, and they share one Basis
Library (the incremental roadmap's D8): `TextIO.stdOut` is the same stream
for the REPL's echo and for a declaration's `print`, and `Compiler.use` is
the REPL's own `use`, put into `RuneCompiler.useHook` when it starts.

* `bin/rune-repl.units/` is the compiler and the REPL compiled a unit per
  file (`rune --units --emit-units`, [units.md](units.md)): the files of the
  Basis Library they use, the compiler's, the REPL's (`src/repl/`), each
  unit's code (`.rbu`) and basis (`.rbi`), and `units` and `sources`, their
  files and their sources in order.
* `bin/rune-repl` runs `bin/rune-repl.load.rbc` (`src/repl/load.sml`), which
  loads those units one by one with `Runtime.load` and runs each, the last
  being the REPL's main (`src/main/repl-main.sml`). So what the REPL program
  exports is in the VM's table of the units loaded, by each unit's
  identity, which the units it makes name too ([units.md](units.md),
  *Names*).
* At start the resident compiler (`src/repl/session.sml`) loads the bases
  of the Basis Library's units, in the order the build did, from the files
  beside their code: the environment the declarations are compiled in, and
  the identities their code names those units by. A functor's body is
  parsed again from the library's source, which must be the one the build
  compiled: its hash is in the basis. A declaration is then a unit after
  them, compiled and loaded again from its basis as the build's units were.
* `bin/rune-repl.img` is the REPL saved once it has done all that
  (`--make-image`): `bin/rune-repl` restores it, `runevm --restore
  bin/rune-repl.img -- FILE...`, the files after `--` its arguments, so that
  it starts at once ([bytecode.md](bytecode.md), `--restore`); without it,
  loading the units and the bases takes a third of a second. The image holds the Basis's environment and the units
  loaded, and none of the code the JIT made, which it makes again.
* `make install` installs it too: the image in `lib/rune`, and
  `rune-repl` beside `rune` (`scripts/install.sh`).
* A declaration is a unit of its own: elaborated against the session,
  translated with its printer, made into the bytes of a unit's file and
  appended to the running program by `Runtime.link`
  ([runtime.md](runtime.md), *Loading a program*). Its functions are
  compiled by the JIT as they get hot, as any others; a load grows the JIT's
  tables and keeps what it compiled.

`use` of a file of 5,000 lines (1,250 small functions) takes 1.2 seconds,
about a millisecond a declaration (incremental roadmap, M4).

## Tests

`tests/repl/run.sh` (`make test-repl`) types each `tests/repl/NAME.in` to
the REPL and wants `NAME.expected`, both of its streams, on every mode of
the JIT: the values of every kind of type; Chapter 8's cases; datatypes in
and out of scope, at their instances, abstract, and a printing depth;
`use` of a library of files, of one that does not compile and of one that
raises; Ctrl-C, which `tests/repl/drive.py` sends the REPL as `SIGINT`
where `interrupt.in` says, while a declaration loops, one with a handler of
its own and one without; and a session saved with `Runtime.save`
(`session.in`) and restored, `session.then` typed to the world restored,
which has the bindings made before the save and reads its own input, not
what the session that saved it had read ahead.

## Not yet

An exception's argument is not printed; a type is printed without the structure it is in; there is no
history or editing of lines. The incremental roadmap's M4 lists what comes
next.

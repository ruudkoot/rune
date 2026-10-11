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
ends with one -- a `;` outside brackets, `let` ... `end` and the like,
strings and comments, which a scanner follows as the lines come
(`src/repl/scan.sml`) -- and parses. Files given on the command line are
`use`d before it reads anything, and the end of the input ends it.

On a terminal the REPL reads with lib/terminal's line editor, and colours
what it says and what is typed (*On a terminal*); on a pipe, a file, under
Emacs or with `--basic`, it is in its basic mode, a prompt and a line at a
time, as above, and what it writes is the same byte for byte as it always
was.

## The command line

```
rune-repl [-q] [-e DECLARATIONS]... [--no-init] [--color=WHEN] [--basic] [FILE]...
```

* `-q`: no banner on a terminal.
* `-e TEXT`: the declarations of `TEXT` run, after the init file and the
  files, and the REPL ends, with a failure status where one of them did not
  compile or raised. A `;` is added where `TEXT` has none at its end.
* `--no-init`: the init file is not used. It is
  `$XDG_CONFIG_HOME/rune/init.sml`, `%APPDATA%\rune\init.sml` on Windows,
  or `~/.config/rune/init.sml`, by the first of those variables that is
  set: `use`d before the files, as any file is, where it is there.
* `--color=always|never|auto`: whether the REPL's output and its
  diagnostics are coloured; `auto`, the default, by the rule of
  [diagnostics.md](diagnostics.md) (a terminal, `NO_COLOR`, `FORCE_COLOR`,
  `TERM`), each stream by itself.
* `--basic`: the basic mode on a terminal too.

On Windows, `rune-repl.cmd` beside `runevm.exe` is `rune-repl` for the
command prompt and PowerShell.

## On a terminal

Where the standard input and output are a terminal that can be edited on
-- not `TERM=dumb`, `unknown`, `cons25` or `emacs`, not Emacs's comint
(`INSIDE_EMACS`), not `RUNE_BASIC_REPL` or `--basic`, and on Windows a
console that takes VT input -- an entry is read with `LineEdit` of
lib/terminal ([plans/repl.md](plans/repl.md), M5 and M6):

* **Editing.** Emacs's keys, as in readline: Ctrl-A, Ctrl-E, Alt-B, Alt-F,
  Ctrl-K, Ctrl-Y, Ctrl-_ to undo, and the rest that `LINE_EDIT` lists.
  Enter submits an entry that a `;` ends at the top, and the parser takes;
  in one that does not end yet, it begins a new line, and Alt-Enter always
  does. A string that a line ends inside is reported at Enter. A paste is
  one entry. Ctrl-C drops the entry, and Ctrl-D on an empty one ends the
  session.
* **Colours.** What is typed is coloured as it is typed by the compiler's
  own lexer, in a mode that never fails (`Lexer.scan`;
  `src/repl/highlight.sml`): keywords, strings, comments, numbers, type
  variables, what the lexer does not take, and names by what they are in
  the session -- a constructor, a type, a structure. The prompt, the names
  and types of the echo, `uncaught exception` and `Interrupt` have the
  roles of the palette (`src/util/color.sml`; `RUNE_COLORS` restyles them).
  A diagnostic shows the line it is about, with `^` under the place
  ([diagnostics.md](diagnostics.md)).
* **Completion.** Tab completes what the cursor is in: after a `:` at the
  start, a command; in a string after `use`, a file; after a structure's
  name and a dot, its members; elsewhere the session's values,
  constructors and structures, and its types after `:`, `of`, `->` or
  `*`. One Tab completes as far as every candidate agrees, a second shows
  them under the entry; they come by how often the session has used them,
  then in order, and the library's own (`Rune...`) only when what is
  typed begins so (`src/repl/complete.sml`).
* **History.** Up and Down go through the entries of this session and of
  every other, kept in `$XDG_STATE_HOME/rune/history`
  (`%LOCALAPPDATA%\rune\history`, `~/.local/state/rune/history`), and
  Ctrl-R searches them; an entry of several lines comes back whole.
* **While a declaration runs** the terminal is quiet (`Terminal.quiet`):
  keys typed ahead are neither echoed into what it writes nor lost, and
  are the editor's at the next prompt; Ctrl-C is the interrupt. A program
  that reads `TextIO.stdIn` gets each read as at a shell, echoed and
  edited by lines.
* **A line left unfinished** by the program -- `print "abc"` -- is marked
  `%` (zsh's way) and what the REPL writes next starts on a line of its
  own.
* **Marks.** On a terminal known to take them -- Windows Terminal, VS
  Code's, WezTerm, iTerm2, kitty, Ghostty -- the prompt, the output and
  the end of each entry with whether it failed are marked for the terminal
  (OSC 133), which can then go from entry to entry and mark the ones that
  failed.

`tests/terminal/MANUAL.md` lists what is checked by hand, terminal by
terminal.

## What a declaration does

The REPL follows Chapter 8 of the Definition, a top-level declaration at a
time: the declarations to a `;`, or to the end of a file `use`d, compiled
and run as one, as Poly/ML does (in the default mode of `--flex-records`,
which settles flexible records there; in the others, each declaration
alone). What follows says "a declaration" for it:

* A declaration that does not elaborate is reported, with its file, line and
  column, and the session is as it was before it: nothing it declared is
  there, and the declarations after it go on. Every error of it that does
  not follow from another is reported: its declarations are elaborated one
  by one, each that fails left out of those after it (`Elaborate.recover`),
  and then none of it is kept.
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
to the caller of `use`. A file that cannot be read raises `IO.Io`, as in
Poly/ML. A file may `use` another, and a declaration of the
session may call `use`: what it compiles is the session's at once, and the
declaration's own bindings join it once it has run.

`Compiler.compile {read, file, line}` is the same for the characters a
reader gives, up to a `;` that ends a declaration or to the reader's end:
the function it returns runs them, and raises `Fail` where one does not
compile. It is what a program that reads its source itself -- HOL4 puts
its quotations through a filter of its own -- compiles with, as Poly/ML's
`PolyML.compiler` is. At a `Compiler.printDepth` of 0 the REPL says
nothing of what a declaration declared.

A file's declarations are units named by the file and their place in it,
kept in the cache of units -- `$RUNE_CACHE`, else `.rune` beside the file
([units.md](units.md), *The cache*) -- and a declaration whose usages hold,
the names it uses bound as they were, is linked from there rather than
compiled: a file used again, unchanged, compiles nothing, and its top level
runs again with globals of its own. With `RUNE_VERIFY_CACHE` set (not
empty), a declaration found there is compiled all the same, and one whose
entry is not what compiling it gives stops the file with an error, as
`--verify-cache` does for `rune`.

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
of its type ([runtime.md](runtime.md), *Values and objects*). It makes a
document, a `Compiler.pretty` in Poly/ML's shape whose parts carry their
roles of the palette, which the REPL lays out with lib/pretty at the
terminal's width, or `Compiler.lineLength` (80) where there is no terminal,
and styles on a terminal ([plans/repl.md](plans/repl.md), D16):

* an `int`, a `word`, a `char` and a `string` as their `toString` shows
  them, a `word` with `0wx`, a `char` and a `string` quoted; a `real` so
  that it reads back as a real (`5.0`, `1E10`);
* a type `S.t` of a structure that has `S.toString : t -> string` by it:
  `0wx3 : Word8.word`, an `IntInf.int`, a `Time.time`;
* a tuple, a record, a list, `ref`, an array (`fromList[...]`) and a vector
  (`#[...]`) by their parts; a list, an array and a vector filling its lines
  where it is wider than the line, a tuple and a record one part to a line;
* a datatype by its constructors, an argument that is an application in
  parentheses, whether or not the constructors are in scope: the printer
  names them by names of its own (`rune'c<stamp>'<tag>`), bound to the
  constructors the elaborator registered for the type (`Elaborate.dataCons`);
* an exception with its argument: each declaration that declares an
  exception constructor with an argument registers a printer of it with
  `RuneShow.addExn`, compiled where the constructor is in scope, and the
  REPL registers those of the Basis's (`Fail`, `IO.Io`, `OS.SysErr`); an
  exception none of them takes -- one declared in a `local` or a functor's
  body -- by its name;
* a function as `fn`; an abstract type -- one made by `:>` -- and a type
  variable as `?`.

A type is named by the shortest path that names it in the session --
`OS.FileSys.file_id`, `Runtime.world` rather than the library's own
`RuneRuntime.world` -- and `?.t` where no path does, as SML/NJ names a type a
later declaration hid or a `local` declared. Four limits cut a value short
with `...`: `Compiler.printDepth` (20) levels from the outside in,
`Compiler.printLength` (100) items of a list, an array or a vector,
`Compiler.stringLength` (1,000) characters of a string, and 10,000 parts of
a value in all (`RuneCompiler.printNodes`).

How much the REPL says of a declaration is `RuneCompiler.feedback`:
`"normal"`; `"concise"`, its values and not the types it declared;
`"verbose"`, a structure with its signature too; and `"silent"`, nothing.

### Printers of one's own

`Compiler.addPrettyPrinter f` installs `f` as the printer of a type, as
Poly/ML's `PolyML.addPrettyPrinter` does, so that HOL4's printers port
([plans/hol4.md](plans/hol4.md)); it takes the place of the printer the
REPL would make, an abstract type's `?` included. `f depth args v` gives a
`Compiler.pretty` -- blocks, breaks and strings in Poly/ML's shape, laid out
by `Compiler.prettyPrint` in `Compiler.lineLength` (80) columns -- and
`args` shows the type's arguments: `()` for none, for one a function of a
value and a depth, a tuple of them for more.

The type is the one `f`'s third argument has where `addPrettyPrinter` is
applied, which only the compiler sees, so the application is special (the
incremental roadmap's D10, item 6): `Translate` makes it, where the REPL
compiles, a call of `RuneShow.addPrinterAt` with the name of the type, and
the printer of a later declaration asks `RuneShow` for a printer by the
name of the type it shows. Another name for `addPrettyPrinter` -- HOL's
`PolyML.addPrettyPrinter` is one -- is the same special, since
`addPrettyPrinter` is bound to a primitive and the compiler follows the
names of primitives. The name of a type is not its stamp, which is the
session's: it is the identity of the unit that declared the type and its
place among the unit's own (`UnitBasis.stableName`), the same in another
session and for a unit taken from the cache. Where the type is a type
variable or one the same top-level declaration declares, nothing is
installed; a program compiled by `rune` installs nothing either.

## How it is built

The REPL is one program with what it compiles, and they share one Basis
Library (the incremental roadmap's D8): `TextIO.stdOut` is the same stream
for the REPL's echo and for a declaration's `print`, and `Compiler.use` is
the REPL's own `use`, put into `RuneCompiler.useHook` when it starts.

* `bin/rune-repl.units/` is the compiler and the REPL compiled a unit per
  file (`rune --units --emit-units`, [units.md](units.md)): the files of the
  Basis Library they use, the compiler's, lib/terminal's editor, the
  REPL's (`src/repl/`), each
  unit's code (`.rbu`) and basis (`.rbi`), and `units` and `sources`, their
  files and their sources in order.
* `bin/rune-repl` runs `bin/rune-repl.load.rbc` (`src/repl/load.sml`), which
  reads every one of those units and then links them one by one with
  `Runtime.link` and runs each, the REPL's main (`src/main/repl-main.sml`)
  the last but the Basis's final units. Reading them all first puts the
  units after the main into the image too, so the REPL runs from any
  directory. So what the REPL program
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
the REPL -- with the arguments of `NAME.args` where there is one, else
`--no-init` -- and wants `NAME.expected`, both of its streams, on every mode of
the JIT: `-e` and the init file; the values of every kind of type; Chapter 8's cases; datatypes in
and out of scope, at their instances, abstract, and a printing depth;
`use` of a library of files, of one that does not compile and of one that
raises; Ctrl-C, which `tests/repl/drive.py` sends the REPL as `SIGINT`
where `interrupt.in` says, while a declaration loops, one with a handler of
its own and one without; and a session saved with `Runtime.save`
(`session.in`) and restored, `session.then` typed to the world restored,
which has the bindings made before the save and reads its own input, not
what the session that saved it had read ahead.

`tests/terminal` (`make test-terminal`, and on Windows through WSL interop
in `make test-windows`) drives the REPL in a tmux pane and waits for the
screen: the prompt and the banner, colours as typed, completion, the
history, an entry of several lines, errors with their lines, an open
string, keys typed ahead while code runs, a program that reads a line,
Ctrl-C, the basic mode under Emacs, and the marks of OSC 133 byte for byte
on a pty; on Windows, `rune-repl.cmd` from `cmd.exe` too.

## Not yet

There are no commands (`:type` and the rest, and `:set` for the limits
and the feedback, M8 of [plans/repl.md](plans/repl.md)). `Compiler.prettyPrint` ignores a block's context
(`ContextLocation`, `ContextProperty`), which Poly/ML's IDE support reads.
[plans/repl.md](plans/repl.md) lists what comes next.

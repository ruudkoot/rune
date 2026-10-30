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

This file is the REPL's manual: [The command line](#the-command-line), [On
a terminal](#on-a-terminal) (editing, Vi's keys, completion, the history
and its menu, what the terminal is asked), [Commands](#commands),
[Settings](#settings), [Configuration](#configuration), [Reload](#reload),
[What a declaration does](#what-a-declaration-does), [`use`](#use),
[Interrupts](#interrupts), [The debugger](#the-debugger),
[Printing](#printing), [Other fronts](#other-fronts), and how it is built
and tested. [plans/repl.md](plans/repl.md) is the roadmap it was built by,
with the reasons for what it does.

## The command line

```
rune-repl [-q] [-e DECLARATIONS]... [--no-init] [--color=WHEN] [--basic] [--unicode[=ENC]] [--no-unicode-lints] [FILE]...
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
* `--unicode[=ENC]`: the files the REPL uses -- by `use`, `:reload` and
  the command line -- are read in the mode `rune --unicode[=ENC]` reads
  its inputs in, Unicode text in the encoding `utf8` (the default) or
  `latin1`, and what is typed is read as UTF-8 ([units.md](units.md),
  *Source modes*). The encoding is taken only after an `=`, as by `rune`:
  `--unicode latin1` uses a file `latin1`. Under it a name may hold the
  letters of `lib/unicode`'s identifier profile, which the REPL, its
  completion and the debugger show as they are written.
* `--no-unicode-lints`: the warnings of UTS #39 on the names, and of a
  lookalike of `*)` in a comment, are left out, as `rune` leaves them out
  ([language.md](language.md), *Identifiers*).
* `--no-inline-functors`: the Basis Library's functors and functions
  marked to be inlined are not ([build.md](build.md), *Functors inlined
  across units*, *Functions inlined across units*), as `rune` takes the
  option.

On Windows, `rune-repl.cmd` beside `runevm.exe` is `rune-repl` for the
command prompt and PowerShell.

`rune-repl --engine` and `rune-repl --engine-connect PORT` are the session
for a front in another process -- an editor, the Jupyter kernel -- in the
place of the terminal: JSON-RPC 2.0 on the descriptors 3 and 4, or on a
connection to `127.0.0.1:PORT`, which [repl-protocol.md](repl-protocol.md)
describes. An `eval` there is an entry as at the prompt, and its answer is
data: the values with their types and handles, the diagnostics in
rune-ide's schema, the exception and its trace.

`rune-repl --dap` is the debugger of an editor -- the Debug Adapter
Protocol on the standard input and output, over an engine of its own
([dap.md](dap.md)).

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
* **Vi's keys.** With `:set keys vi` (or `Repl.set ("keys", "vi")` in the
  init file) the editor has Vi's modes: what is typed is inserted until
  Escape, which goes to the normal mode, where `h l w b e 0 ^ $` move, `d
  c y` take a motion or are doubled for the line, `x X D C s S r ~ p P u`
  edit, a count goes before either, `j` and `k` go through the lines and
  the history, `G` and `gg` to the end and the start, and `i a I A o O`
  go back to inserting; Enter submits in either mode. The cursor is a
  block in the normal mode and a bar while inserting.
* **Colours.** What is typed is coloured as it is typed by the compiler's
  own lexer, in a mode that never fails (`Lexer.scan`;
  `src/repl/highlight.sml`): keywords, strings, characters, comments,
  numbers, type variables, what the lexer does not take, and names by where
  they stand -- in a type, among a datatype's constructors, after
  `exception` or `structure` -- and elsewhere by what they are in the
  session: a constructor, a type, a structure. What the REPL says in SML is
  coloured by the same rules: the echo of a value (`val`, `fn`, the value's
  numbers, strings and constructors, its type) and of a declaration, and
  what `:type`, `:info`, `:browse`, `:search` and `:doc` say, and the line
  the debugger stopped at; a command's name is coloured as a keyword. On a
  terminal of 256 colours code is coloured in full -- keywords blue and
  bold, strings purple, numbers green, constructors orange, types teal,
  comments grey -- in colours that read on dark and light backgrounds alike
  (the theme `wide`); elsewhere in the 16 colours' few, which do too
  ([diagnostics.md](diagnostics.md), *Themes*). The prompt, the names of
  the echo, `uncaught exception` and `Interrupt` have the roles of the
  palette (`lib/compiler/util/color.sml`; `RUNE_COLORS` restyles them). A diagnostic
  shows the line it is about, with `^` under the place.
* **Completion.** Tab completes what the cursor is in: after a `:` at the
  start, a command; in a string after `use`, a file; after a structure's
  name and a dot, its members; elsewhere the session's values,
  constructors and structures, and its types after `:`, `of`, `->` or
  `*`. One Tab completes as far as every candidate agrees, a second shows
  them under the entry; they come by how often the session has used them,
  then in order, and the library's own (`Rune...`) only when what is
  typed begins so (`src/repl/complete.sml`). What one Tab would add is
  shown faintly after the end of the entry as it is typed -- `fol` after
  `List.` shows `d`, where `foldl` and `foldr` agree -- and Tab, Right or
  Ctrl-E takes it; not in a comment. Finding it costs a search down the
  session's maps, so that typing is no slower in a session of thousands of
  names.
* **History.** Up and Down go through the entries of this session and of
  every other, kept in `$XDG_STATE_HOME/rune/history`
  (`%LOCALAPPDATA%\rune\history`, `~/.local/state/rune/history`), and with
  text typed only those that begin with it. Ctrl-R searches them for what
  is typed after it, Ctrl-R again for an older one; beneath it a menu
  lists the eight entries that have the typed characters in order, the
  best first -- one after another, or at a word's start, counts more --
  which Down and Up choose from and Enter runs. An entry of several lines
  comes back whole.
* **What the terminal is asked.** At the first prompt the editor asks,
  invisibly, how wide the terminal draws a cluster of joined emoji, which
  says how it measures text (by cluster or by code point, D9), and
  whether it speaks the kitty keyboard protocol; where it does, the
  protocol is on while an entry is read, so that Escape needs no wait
  and Ctrl-I is not Tab. A terminal that answers neither is measured by
  `TERM_PROGRAM`, as before.
* **While a declaration or command runs** the terminal is quiet (`Terminal.quiet`):
  keys typed ahead are neither echoed into what it writes nor lost, and
  are the editor's at the next prompt, also those that reach the REPL in
  one burst with the Enter of the entry before them; Ctrl-C is the
  interrupt. A program that reads `TextIO.stdIn` gets each read as at a
  shell, echoed and edited by lines. `:sh` and `:edit` likewise give their
  external program the terminal as at a shell, then make it quiet again.
  Blank entries also keep keys typed ahead quiet until the next prompt.
* **A line left unfinished** by the program -- `print "abc"` -- is marked
  `%` (zsh's way) and what the REPL writes next starts on a line of its
  own.
* **Marks.** On a terminal known to take them -- Windows Terminal, VS
  Code's, WezTerm, iTerm2, kitty, Ghostty -- the prompt, the output and
  the end of each entry with whether it failed are marked for the terminal
  (OSC 133), which can then go from entry to entry and mark the ones that
  failed. The prompt's mark goes out once the editor has the terminal raw,
  just before it draws the prompt: a key typed as soon as the terminal sees
  the mark is the editor's, where a cooked terminal would echo it and make
  its return a newline.

`tests/terminal/MANUAL.md` lists what is checked by hand, terminal by
terminal.

## Commands

A line that begins with `:` and a letter is a command
([plans/repl.md](plans/repl.md), D15): no SML begins so, it needs no `;`,
and any unique prefix of a command's name names it (`:t` for `:type`).

| Command | Does |
|---|---|
| `:help [command]` | the commands, or one |
| `:quit` | ends the session, as Ctrl-D on an empty entry does |
| `:type exp` | the type of an expression, which is not evaluated |
| `:info name` | what a name is -- a value and its type, a constructor and its datatype, a type, a structure and its signature, a signature, a functor, a fixity -- and the file and line it was defined at, or the Basis's file |
| `:browse name` | a structure's or a signature's specifications |
| `:doc name` | the documentation of a name of the Basis Library, its Markdown laid out for the terminal |
| `:search text` | values whose name holds the text; with `->`, values whose type is like it, arguments in any order, curried or tupled, the nearest first |
| `:use file` | `use` |
| `:reload`, `:reload!` | uses again the files that changed and those that name what they bind; `!` goes back to the start or the mark first (*Reload*) |
| `:mark` | where `:reload!` comes back to from now on |
| `:edit [name or file]` | `$VISUAL` or `$EDITOR` at a name's definition or at a file, and the file used again |
| `:cd dir`, `:pwd` | the directory |
| `:sh command` | a command of the shell, on the terminal as it was |
| `:set setting value`, `:show` | the settings: `depth`, `length`, `string`, `width`, `feedback`, `prompt`, `prompt2`, `time`, `watch`, `debug`, `pause` |
| `:time [on or off]` | after each entry, its time in all, compiling and running apart, the CPU it took, what it allocated and the collections |
| `:history` | the entries of the session, `!` beside those that failed |
| `:save file` | the entries that went well, as a script to `use` |
| `:save-image file` | the whole session as an image, which `runevm --restore file` starts again |
| `:bt` | where the last exception that ended an entry was raised, frame by frame; at a stop of the debugger, its frames |
| `:break [file:]line`, `:break raise [all]`, `:break` | a breakpoint at a line (of the file of the frame looked at, or of the file used last, where none is named); a stop at a raise nothing of the program's handles, or at every raise; the breakpoints (*The debugger*) |
| `:delete n`, `:delete raise`, `:delete all` | a breakpoint, the stops at a raise, or all of them |
| `:step`, `:next`, `:finish`, `:continue`, `:abort` | at a stop: on to the next line, into what it calls; to the next line of the function, or where it returns; to where it returns; on; the program interrupted where it stopped |
| `:frame [n, up or down]`, `:locals` | at a stop: the frame looked at; its variables |

`:doc` reads what runedoc wrote of the Basis for programs to read
(`docs/lib/basis/members.json`), once, before the REPL's image is
saved. `:bt` reads the frames the VM recorded as the exception left the code
the REPL ran (`RuneRuntime.raiseMark`, `raiseTrace`;
[runtime.md](runtime.md), *Stacks, calls and exceptions*); on a terminal, an
uncaught exception says where it was raised. The structure `Repl` of the
session has the same as functions -- `Repl.command ":set depth 5"`,
`Repl.typeOf`, `Repl.info`, `Repl.doc`, `Repl.search`, `Repl.set`,
`Repl.settings` -- for init files, scripts and HOL4; outside the REPL each
raises `Fail`.

## Settings

`:set NAME VALUE` changes one, `:show` lists them, `Repl.set (NAME,
VALUE)` from the init file:

| Setting | Values | Says |
|---|---|---|
| `depth` | a number, 20 | levels of a value printed (`Compiler.printDepth`) |
| `length` | a number, 100 | items of a list, an array or a vector printed (`Compiler.printLength`) |
| `string` | a number, 1000 | characters of a string printed (`Compiler.stringLength`) |
| `width` | a number, 80 | columns a value is laid out in where there is no terminal (`Compiler.lineLength`) |
| `feedback` | `normal`, `concise`, `verbose`, `silent` | what is said of a declaration (*Printing*) |
| `prompt`, `prompt2` | text | the prompts (`Compiler.prompt1`, `prompt2`) |
| `time` | `on`, `off` | the time and memory of each entry (`:time`) |
| `watch` | `on`, `off` | a file used is used again at the prompt where it has changed (*Reload*) |
| `keys` | `emacs`, `vi` | the editor's keys (*On a terminal*) |
| `debug` | `on`, `off` | what is entered and used is compiled for the debugger (`:break` puts it on) |
| `pause` | `on`, `off` | Ctrl-C pauses the program in the debugger rather than interrupting it |

## Configuration

**The init file**, `$XDG_CONFIG_HOME/rune/init.sml`
(`%APPDATA%\rune\init.sml`, `~/.config/rune/init.sml`), is SML that the
REPL `use`s at start, before the files of the command line; `--no-init`
skips it. For example:

```
val () = Repl.set ("keys", "vi");
val () = Compiler.printLength := 30;
val () = Compiler.addPrettyPrinter (fn _ => fn _ => fn (s : Word8Vector.vector) =>
           Compiler.PrettyString ("<" ^ Int.toString (Word8Vector.length s) ^ " bytes>"));
```

**The environment** the REPL reads:

| Variable | Says |
|---|---|
| `NO_COLOR`, `FORCE_COLOR`, `CLICOLOR_FORCE` | whether to colour, where `--color` does not say ([diagnostics.md](diagnostics.md)) |
| `RUNE_COLORS` | the palette's roles restyled (`lib/compiler/util/color.sml`) |
| `TERM`, `INSIDE_EMACS`, `RUNE_BASIC_REPL` | the basic mode (*On a terminal*) |
| `TERM_PROGRAM` | how the terminal measures text, until it is asked, and whether it takes marks |
| `XDG_CONFIG_HOME`, `XDG_STATE_HOME`, `APPDATA`, `LOCALAPPDATA` | where the init file and the history are |
| `RUNE_CACHE` | where a file's compiled units are cached (empty: nowhere; [units.md](units.md)) |
| `VISUAL`, `EDITOR` | `:edit`'s editor |

## Reload

The REPL remembers the files used from the top -- at the prompt, by
`:use`, the init file, the command line; not by another file, which its
user uses again -- in order, with their texts and their times
([plans/repl.md](plans/repl.md), D19):

* `:reload` finds the first that changed, and uses it again, and every
  file after it that changed or names something a file used again before
  it binds, each in its place and through the cache, so that a declaration
  that did not change is linked rather than compiled. It says first what
  it shadows, and after which values made at the prompt are of a type the
  reload replaced -- ghosts, which print `?.t` and match no value of the
  new type, because a datatype declared again is another type.
* `:reload!` puts the session back as it was at its start, or at the last
  `:mark` (undoing what was declared since, `UnitBasis.undo`), and uses
  again the files used since then: DrScheme's Run. What was made at the
  prompt since is gone.
* `:set watch on` checks the files' times at each prompt and reloads when
  one changed; `:edit` reloads the file it edited.

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
`PolyML.compiler` is. It reads the characters in the default mode, and
`Compiler.compileIn MODE {read, file, line}` in the one that `MODE` names
as a build file's annotation does (`"ascii"`, `"unicode"`,
`"unicode=latin1"`; [units.md](units.md), *Source modes*). At a
`Compiler.printDepth` of 0 the REPL says nothing of what a declaration
declared.

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

## The debugger

A breakpoint stops the program at a line; so does a step, the user's
interrupt where `:set pause on` says so, and a raise where `:break raise`
does ([plans/repl.md](plans/repl.md), D22 and M12; [runtime.md](runtime.md),
*The debugger*). At a stop the REPL says where, with the line, and reads
entries at its own prompt, `debug>`, until one says how the program goes
on:

```
- :break lib/shapes.sml:9
breakpoint 1 at lib/shapes.sml:9 (no code there yet: ...)
- use "lib/shapes.sml";
- total [Circle 1.0, Square 2];
stopped at a breakpoint: in total at lib/shapes.sml:9:17
    9 |     val parts = map area shapes
debug> :locals
val shapes = [Circle 1.0, Square 2] : shape list
val label = "total" : string
debug> size label + length shapes;
val it = 7 : int
debug> :next
```

* **What is debugged.** From the first `:break` (or `:set debug on`) what is
  entered and used is compiled for the debugger: at `-O0`, each variable a
  register of its own, and what each function binds kept with its name and
  type. What was compiled before has no variables to show, and a function
  of it may have been inlined where it was called; `:reload!` compiles it
  again. While anything can stop the program -- a breakpoint, a step, the
  stop at a raise -- it runs in the VM's debug loop, interpreted, which
  costs it, and the REPL's own work with it, perhaps a factor of three; with
  nothing to stop at, the program runs as it ran before.
* **Lines and files.** A breakpoint is a line of a file as `use` named it,
  or of an entry, `stdIn#k`; once debugging is on, entries are numbered in
  the basic mode too. It stops where the code of the line begins, and again
  only where the code comes to the line from another; a line of no code --
  `in`, `end`, a variable alone -- has none to stop at. A breakpoint set
  before its file is used stops once it is.
* **Steps.** `:step` stops at the next line of the session's code, into what
  it calls; `:next` at the next line of the function, or of one it returns
  to; `:finish` where the function returns. A step stops in the session's
  code only: the Basis, and the REPL's own program, are the library, which a
  step goes through as through code with no source. A tail call leaves no
  frame, so `:next` over one stops in what it called.
* **A raise.** `:break raise` stops at a raise that nothing of the
  program's handles, before anything unwinds, with the exception;
  `:break raise all` at every raise of the program's. `:continue` goes on
  with the raise, `:abort` raises `Interrupt` in its place.
* **The variables.** `:locals` shows the variables of the frame looked at
  (`:frame`) that hold a value there -- bound by where it is, and of a type
  whose value it holds -- the last bound of each name, as echoes, with the
  printers of *Printing*; a variable of an enclosing function is read from
  the closure. One whose binding a later binding hides is not shown.
* **In a frame.** An expression at the `debug>` prompt, or `val x = exp`, is
  evaluated with the frame's variables in scope, as `(fn (x : t, ...) =>
  exp) values` would be, where the session names their types; anything else
  is an entry as at the prompt. Nothing stops while it runs.
* **Pause.** With `:set pause on`, Ctrl-C stops the program where it is
  rather than interrupting it; `:abort` then interrupts it there.

The engine has the same as requests (`debug/*`,
[repl-protocol.md](repl-protocol.md), *The debugger*), which the Debug
Adapter Protocol's adapter ([dap.md](dap.md)) and the Jupyter kernel's
debugger ([kernel.md](kernel.md)) drive.

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
* a `WideString.string` and a `WideChar.char` quoted, their text in UTF-8
  (`"λx"`, `#"λ"`), but for what would not show or could make the
  line read otherwise: a control (C0, DEL, C1), a bidirectional control or
  another default-ignorable character, and a surrogate, as an escape --
  `\n` and the others of Standard ML, else `\u202E` (`\U000E0001` above
  U+FFFF) -- and the quote and the backslash escaped
  (`RuneShow.wideString`; docs/plans/utf8.md, D14). A `string` is bytes,
  and prints as `String.toString` shows it (`"caf\195\169"`);
* a type `S.t` of a structure that has `S.toString : t -> string` by it:
  `0wx3 : Word8.word`, an `IntInf.int`, a `Time.time`. A matching formatter
  takes precedence over datatype constructors, so both small and large
  `IntInf` values print as decimal integers. Formatter lookup follows type
  identity through visible aliases independently of the displayed type name;
* a tuple, a record, a list, `ref`, an array (`fromList[...]`) and a vector
  (`#[...]`) by their parts; a list, an array and a vector filling its lines
  where it is wider than the line, a tuple and a record one part to a line;
* a datatype without a matching formatter by its constructors, an argument
  that is an application in parentheses, whether or not the constructors are
  in scope: the printer names them by names of its own
  (`rune'c<stamp>'<tag>`), bound to the constructors the elaborator registered
  for the type (`Elaborate.dataCons`);
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

## Other fronts

The session is the engine's, which a front in another process drives
through a protocol of its own ([repl-protocol.md](repl-protocol.md);
`rune-repl --engine`): an evaluation's answer is data, its values with
handles to open them a level at a time, its diagnostics, its exception
and frames, and the debugger is requests and a notification. Two fronts
come with it:

* **Jupyter**, `rune-kernel` ([kernel.md](kernel.md)): cells are entries,
  values come back as text and as HTML in the palette's colours, `Display`
  shows rich output, and JupyterLab's debugger stops in cells.
* **An editor's debugger**, `rune-repl --dap` ([dap.md](dap.md)): the
  Debug Adapter Protocol for VS Code, Emacs's dape, Neovim's nvim-dap.

Each starts the engine as its child: on its descriptors 3 and 4 where the
system forks, and on Windows over a connection of the loopback with a
token (`--engine-connect`, `src/front/engine.sml`).

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
  loading the units and the bases takes a third of a second. The image
  holds the Basis's environment and the units loaded, and none of the code
  the JIT made, which it makes again.
* `make install` installs it too: the image in `lib/rune`, and
  `rune-repl` beside `rune` (`scripts/install.sh`).
* The loader takes options before `--make-image` (`runevm
  bin/rune-repl.load.rbc UNITS OPTIONS --make-image IMAGE`), which the
  image keeps for every session started from it: the Basis Library's
  marked functors and functions are inlined across units unless
  `--no-inline-functors` is given there, and `--lint` makes every session from the image check
  what each pass makes, as `rune --lint` does.
* A declaration is a unit of its own: elaborated against the session,
  translated with its printer, made into the bytes of a unit's file and
  appended to the running program by `Runtime.link`
  ([runtime.md](runtime.md), *Loading a program*). Its functions are
  compiled by the JIT as they get hot, as any others; a load grows the JIT's
  tables and keeps what it compiled.

`use` of a file of 5,000 lines (1,250 small functions) takes 1.2 seconds,
about a millisecond a declaration (incremental roadmap, M4).

## Tests

The runner (`repl/*` of `tests/runner/protocols.sml`; `make test-repl`) types each `tests/repl/NAME.in` to
the REPL -- with the arguments of `NAME.args` where there is one, else
`--no-init` -- and wants `NAME.expected`, both of its streams, on every mode
of the JIT: `-e` and the init file; the values of every kind of type;
Chapter 8's cases; datatypes in and out of scope, at their instances,
abstract, and a printing depth; `use` of a library of files, of one that
does not compile and of one that raises; Ctrl-C, which the runner
sends the REPL as `SIGINT` where `interrupt.in` says, while a declaration
loops, one with a handler of its own and one without; and a session saved
with `Runtime.save` (`session.in`) and restored, `session.then` typed to the
world restored, which has the bindings made before the save and reads its
own input, not what the session that saved it had read ahead; and the
debugger (`debug.in`): a breakpoint in a file used after it was set, the
frames, the variables of each and an expression among them, steps into, over
and out of a function the library calls, a variable of an enclosing
function, one a later binding hides, and a stop at a raise ended with
`:abort` -- the same frames and values on every mode of the JIT; and a
functor declared by one declaration and applied by others and by a file
used again from the cache (`functors.in`), the functor marked to be
inlined (`functors.args`).

`tests/terminal` (`make test-terminal`, and on Windows through WSL interop
in `make test-windows`) drives the REPL through a runtime PTY or ConPTY and waits for the
screen: the prompt and the banner, colours as typed, completion, the
history, an entry of several lines, errors with their lines, an open
string, keys typed ahead while code runs, a program that reads a line,
Ctrl-C, the debugger's stop and its prompt and Ctrl-C pausing a loop
(`repl-debug`), Vi's modes and the history's menu (`repl-vi`), the basic
mode under Emacs, and on a pty the marks of OSC 133 byte for byte and
two entries typed at once; on
Windows, the scripts whose first line is `# windows`, and `rune-repl.cmd`
from `cmd.exe`. lib/terminal's own tests (`tests/lib/terminal`) give the
editor keys and look at its state: Vi's commands and counts, the menu and
its order, the answers to what the terminal is asked, the kitty
protocol's keys among them, what the terminal is -- raw, quiet or put
back -- when the prompt is announced and after an entry, and keys typed
ahead in one read with the end of a line.
`tests/terminal/MANUAL.md` is the list checked by hand.

## Not yet

`Compiler.prettyPrint` ignores a block's context (`ContextLocation`,
`ContextProperty`), which Poly/ML's IDE support reads. The debugger has no
conditional breakpoints, no watchpoints, no stepping back, and no `BREAK`
written over an instruction in place of the debug loop.
[plans/repl.md](plans/repl.md) lists what comes next.

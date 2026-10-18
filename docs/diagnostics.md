# Diagnostics and colour

How `rune` and `runedoc` show their errors and warnings, when they colour
them, and the palette that the compiler, runedoc and the REPL share.
`docs/plans/repl.md` (D1 to D3, D17 and M2) gives the reasons; the code is
`src/util/color.sml` (the palette) and `src/util/diagnostic.sml` (the
rendering).

## The format

A diagnostic's first line is the one the compiler has always printed:

```
FILE:LINE:COL: error: MESSAGE
FILE:LINE:COL: warning: MESSAGE
```

`LINE` counts from 1 and `COL` counts characters from 1: the code points
before the position on its line, a byte that is not UTF-8 counting one,
as rustc and Emacs count (*Columns* below). On a line of ASCII that is
the byte column it always was, so programs and editors that read this
line need not change: when the standard error is not a terminal and
nothing asks for more, this line is all that is printed (`tests/errors`
and every other suite compare it). `FILE` is the file's name with what
would not show, or could make the line read otherwise, escaped as in the
excerpt below: a control (C0, DEL, C1), a bidirectional control or
another default-ignorable character as `\u{202E}`, a byte that is not
UTF-8 as `\xE9`.

A type in a message is named as the top level of the program names it. A
type that the top level does not name by its own name gets the path that
reaches it, the structure named for the type first: `WideString.string`
where `string` is `String.string`, `S.t`, and `A.d` and `B.d` for the
datatypes of two applications of one functor. A type that no path reaches,
such as one of the structure being elaborated, keeps its own name, and a
stamp where two of one name meet in a message (`t/102`).

In the **full** form the lines of source that the diagnostic is about
follow, under a gutter of line numbers, with carets under the span:

```
t.sml:3:9: error: unbound variable or constructor: lenght
  |
3 | val n = lenght xs
  |         ^^^^^^
```

* The carets are placed by display columns, not bytes: a CJK character or
  an emoji takes two columns, a combining mark none (`lib/unicode`'s
  tables, Unicode 18). A tab in the source stays a tab under it, so the
  carets line up whatever width the terminal gives a tab.
* A span over several lines shows its first and its last line, with `...`
  between them when there are lines in between.
* Control characters and the bidirectional controls (U+202A to U+202E,
  U+2066 to U+2069, U+200E, U+200F, U+061C) are shown escaped, as
  `\u{202E}`, so a line cannot read otherwise than it is. A byte that is
  not UTF-8 is shown as `\xNN`.
* When the source's text is gone (a warning replayed from the cache, a
  file the REPL `use`d), only the first line is printed.

## Columns

A position is a byte offset of the source everywhere inside the compiler,
and so is a column in what programs read; a column a person reads counts
characters, and one an editor's protocol reads counts UTF-16 units, as
the editor does (docs/plans/utf8.md, D15). Those are counted only where
they are shown: counting characters for every position of the line table
would cost 4.1% of a compile (E10).

| Where | A column counts |
|---|---|
| a diagnostic's first line, `FILE:LINE:COL` (`rune`, `runedoc`, the REPL) | characters, from 1 |
| the carets of the excerpt | display columns: a CJK character or an emoji two, a combining mark none |
| `--diagnostics-json` | `startByte` and `endByte` bytes; `range` UTF-16 units, from 1 |
| the REPL's traces (`raised in`, `:bt`) and its debugger's frames | characters, from 1 |
| the REPL's engine ([repl-protocol.md](repl-protocol.md)): the diagnostics' `range`, an exception's `trace` and `debug/frames` | UTF-16 units, from 1; a Jupyter notebook's trace shows these |
| `rune-dap` ([dap.md](dap.md)) | UTF-16 units, from 1, as DAP counts by default |
| `rune --serve` | bytes: offsets, and `line` and `column` |
| the bytecode's line table, `Runtime.trace`'s frames, `Runtime.printTrace` and `runevm`'s trace of an uncaught exception, the native code's DWARF | bytes, from 1 |

The REPL counts a frame's column in the text of its file: one it used
keeps, once it is compiled, only the lines that hold a character above
ASCII (`Source.keepLines`), and a file it did not read is read from disk.
Its entries take one name in turn -- `stdIn` in the basic mode, and an
entry typed at a stop the name of the entry that stopped -- so a column
past the end of the line of the text it has is of another text, and
keeps its bytes.
The VM has no source, so the traces it prints itself give the line
table's byte columns, which on a line of ASCII are its characters too.

## The flags

Both `rune` and `runedoc` take:

| Flag | Meaning |
|---|---|
| `--color=auto` | colour when the standard error is a terminal (the default; see below) |
| `--color=always` | colour whatever the standard error is |
| `--color=never` | no colour |
| `--diagnostics=full` | the excerpt under the first line, also into a pipe |
| `--diagnostics=short` | the first line only, also on a terminal |
| `--diagnostics-json FILE` | also write every diagnostic of the run to `FILE` |

Without `--diagnostics`, the form is full when the standard error is a
terminal and `TERM` is not `dumb`, and short otherwise.

## When there is colour

With `--color=auto`, the first rule that applies decides:

1. `NO_COLOR` set and not empty (no-color.org): no colour; on a terminal
   that is not dumb (rule 4) the attributes stay (bold, underline),
   without colours.
2. `FORCE_COLOR` or `CLICOLOR_FORCE` set to anything but empty, `0` or
   `false`: colour.
3. `CLICOLOR=0`: no colour.
4. `TERM=dumb`, or `TERM` unset on a system other than Windows (Emacs's
   `M-x compile`, cron, a CI log): no colour. On Windows the VM sets
   `TERM=dumb` for itself where a console refuses escapes (before Windows
   10 1511, or the legacy console; [runtime.md](runtime.md), *The
   terminal*).
5. Otherwise colour exactly when the standard error is a terminal.

The test runners and `make` unset `FORCE_COLOR` and `CLICOLOR_FORCE`, so
that a CI that forces colour changes nothing that the tests compare.

## Themes and `RUNE_COLORS`

Each piece of text has a **role** (`error`, `diag.gutter`, `syn.keyword`,
`repl.prompt`, ...); `Color.table` gives the style of each role in three
themes, and `Color.wide` that of the roles of code and the prompt in a
fourth:

| Theme | For |
|---|---|
| `auto` | the default, for a background not known: bright red and magenta with bold, faint and underline |
| `wide` | `auto` on a terminal of 256 colours: code in full -- keywords blue and bold, strings purple, numbers green, constructors orange, types teal, comments grey -- in colours of the 256 that read on dark and light backgrounds alike |
| `dark` | a dark background: the bright colours, cyan and green among them |
| `light` | a light background: red, blue and magenta |
| `mono` | the attributes of `auto` without its colours |
| `none` | no styles at all |

The theme is the one `RUNE_COLORS` names; else `dark` or `light` when
`COLORFGBG` (which some terminals set, as `fg;bg`) gives the background;
else `auto`, which is `wide` where the terminal draws 256 colours: by
`COLORTERM` (`truecolor`, `24bit`), a `TERM` that ends in `256color` or
names such a terminal (kitty, Alacritty, foot, WezTerm, Ghostty),
`WT_SESSION` (Windows Terminal), `TERM_PROGRAM` (VS Code, iTerm2,
Terminal.app, WezTerm, Ghostty), and on Windows, whose console draws them
wherever it takes VT. `RUNE_COLORS=auto` keeps the 16 colours. Every role
also carries a word or a mark (`error:`, `^`), so colour is never the only
cue.

`auto` has so few colours because the others fail somewhere:
`tests/color/contrast.py` draws each role on the default palettes of
xterm, VTE, Windows Terminal, the legacy console and VS Code, on the
backgrounds its theme is for, also as seen with protanopia, deuteranopia
and tritanopia, and requires WCAG's 3:1 (2.5:1 with a deficiency). On
white, xterm's green and cyan reach 2.0 to 2.3; on black, the legacy
console's red 1.9 and blue 1.3. Only bright red and magenta pass on both.
The colours from 16 up are the same in every terminal, and `wide`'s are
mid tones whose contrast is at least 3.1:1 on black, on VS Code's dark grey
and on white (2.7:1 with a deficiency). Its keywords are coloured as well
as bold: a terminal may draw bold text in its default colour no
differently, as Windows Terminal did for the REPL under WSL (2026-10-10),
where the console of Windows, for `runevm.exe`, made it bright.

`RUNE_COLORS` follows `GCC_COLORS`: fields separated by colons, each a
theme's name or `ROLE=STYLE`, where a style is SGR parameters separated by
semicolons (`1` bold, `2` faint, `3` italic, `4` underline, `7` reverse,
`9` struck through, `30` to `37` and `90` to `97` the colours, `38;5;N`
and `38;2;R;G;B` for terminals that have more). A style with anything but
digits and semicolons is ignored, so the variable cannot write another
escape. For example:

```
RUNE_COLORS='dark:error=1;38;5;203:diag.gutter=2'
```

## The JSON

`--diagnostics-json FILE` writes, when the program ends, the form that
rune-ide reads (`/home/ruud/rune-ide/docs/ide-protocol.md`):

```json
{"version":1,"success":false,"compilerVersion":"...","diagnostics":[
  {"severity":"error","message":"...","path":"t.sml","startByte":24,"endByte":30,
   "range":{"startLineNumber":3,"startColumn":9,"endLineNumber":3,"endColumn":15},
   "rendered":"t.sml:3:9: error: ...\n  |\n3 | ...\n  |         ^^^^^^"}]}
```

* `startByte` and `endByte` are offsets in the file; `range` counts lines
  from 1 and columns in UTF-16 units from 1, as an editor does; `range`
  is `null` when the source's text is gone. `path` is the file's name as
  it is, not escaped, so that an editor finds the file by it.
* `rendered` is the full form without colour.
* The file is written also when the run succeeds, with no diagnostics or
  with its warnings.

## The palette for pages and editors

`runedoc --palette DIR` writes the palette for what is not a terminal:

* `palette.css`: for each role, custom properties
  (`--rune-ROLE-color`, `-background`, `-weight`, `-style`,
  `-decoration`, `-opacity`) in the light theme, the dark theme's under
  `prefers-color-scheme: dark`, and a class `.rune-ROLE` that uses them.
  The colours are those of a reference terminal: VS Code's light
  terminal, and Windows Terminal's Campbell.
* `palette.json`: the rules of a Monaco theme, dark and light, for the
  tokens rune-ide's highlighter names.

`make docs` writes them to `docs/lib/palette`, and `make check-docs`
fails when they are not what the table gives. `RUNE_COLORS` does not
change them.

## Tests

* Every suite compares output that is not to a terminal, byte for byte.
* `tests/diagnostics/`: programs with errors and warnings, rendered with
  `--color=always --diagnostics=full`; each expected rendering was read
  line by line, its column in characters (`emoji.sml`, `wide.sml`). Also
  the JSON of one run, a file whose name is Latin-1 (`latin1-name`), and
  two whose names are escaped in the first line, one with its column
  after a character above ASCII (`escaped-names`).
* `tests/repl/unicode`: the REPL's traces and frames in characters;
  `tests/dap/run.py`: a frame's column in UTF-16 units.
* `tests/color/contrast.py`: the contrast of every role's colour against
  the backgrounds of the reference palettes, and under simulated
  deficient colour vision (above).

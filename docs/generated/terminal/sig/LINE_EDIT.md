# signature LINE_EDIT

[Terminal](../README.md) &rsaquo; Terminals &rsaquo; **LINE_EDIT**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 2 |
| Documentation | 16 of 16 entries documented |
| Tests | not listed |
| Source | [lib/terminal/line\_edit\_sig.sml](../../../../lib/terminal/line_edit_sig.sml) |

## Synopsis

```sml
signature LINE_EDIT
structure LineEdit : LINE_EDIT
functor LineEditFn (...) :> LINE_EDIT
```

| Implementation |  | Source |
| --- | --- | --- |
| [`LineEdit`](../str/LineEdit.md) | LineEdit: the line editor on Rune's terminal. | [lib/terminal/line\_edit.sml](../../../../lib/terminal/line_edit.sml) |
| `LineEditFn` | LineEditFn: the line editor over a terminal device; LineEdit is it over Device, and a program on another compiler applies it to PosixDevice. | [lib/terminal/line\_edit\_fn.sml](../../../../lib/terminal/line_edit_fn.sml) |

A line editor: what is typed at a prompt, edited with Emacs's keys,
drawn on a terminal, of one line or many.

The editor is a pure core under a thin loop (docs/plans/repl.md, D7).
[`step`](#val-step) takes a state and a key to the next state and what it asks of
the loop; [`layout`](#val-layout) turns a state into a frame, the rows of cells the
terminal should show and where the cursor is, wrapping by display
width itself; [`diff`](#val-diff) turns the frame the terminal shows and the next
into the bytes that change one into the other, with relative moves and
only the rows that changed. [`readLine`](#val-readline) is the loop: it reads keys,
steps and draws, and falls back to a basic mode -- a prompt and
[`TextIO.inputLine`](../../basis/sig/TEXT_IO.md#val-inputline) \-- where the terminal cannot be edited on.

The keys are readline's: Ctrl-A, Ctrl-E, Ctrl-B, Ctrl-F, Alt-B, Alt-F
and the arrows to move; Ctrl-D, Delete, Backspace, Ctrl-K, Ctrl-U,
Ctrl-W, Alt-D and Alt-Backspace to delete, killing into a ring that
Ctrl-Y and Alt-Y yank from; Ctrl-T, Alt-U, Alt-L and Alt-C; Ctrl-\_ to
undo; Up and Down through the lines and then the history, searching
it by what was typed; Ctrl-R to search it incrementally; Tab to
complete; Enter to accept a complete input or begin a new line, and
Alt-Enter for a new line always; Ctrl-L to clear the screen; Ctrl-C to
cancel; Ctrl-Z to suspend. `bindings` changes them.

## Interface

<pre>
signature LINE_EDIT =
sig
  datatype <a href="#type-command">command</a> =
      <a href="#con-insert">Insert</a>
    | <a href="#con-beginningofline">BeginningOfLine</a> | <a href="#con-endofline">EndOfLine</a> | <a href="#con-forwardchar">ForwardChar</a> | <a href="#con-backwardchar">BackwardChar</a> | <a href="#con-forwardword">ForwardWord</a> | <a href="#con-backwardword">BackwardWord</a>
    | <a href="#con-previousline">PreviousLine</a> | <a href="#con-nextline">NextLine</a> | <a href="#con-previoushistory">PreviousHistory</a> | <a href="#con-nexthistory">NextHistory</a> | <a href="#con-beginningofhistory">BeginningOfHistory</a> | <a href="#con-endofhistory">EndOfHistory</a>
    | <a href="#con-beginningofbuffer">BeginningOfBuffer</a> | <a href="#con-endofbuffer">EndOfBuffer</a>
    | <a href="#con-deletechar">DeleteChar</a> | <a href="#con-deletecharorend">DeleteCharOrEnd</a> | <a href="#con-backwarddeletechar">BackwardDeleteChar</a> | <a href="#con-killline">KillLine</a> | <a href="#con-backwardkillline">BackwardKillLine</a>
    | <a href="#con-killword">KillWord</a> | <a href="#con-backwardkillword">BackwardKillWord</a> | <a href="#con-killwordbehind">KillWordBehind</a> | <a href="#con-yank">Yank</a> | <a href="#con-yankpop">YankPop</a>
    | <a href="#con-transposechars">TransposeChars</a> | <a href="#con-upcaseword">UpcaseWord</a> | <a href="#con-downcaseword">DowncaseWord</a> | <a href="#con-capitalizeword">CapitalizeWord</a> | <a href="#con-undo">Undo</a>
    | <a href="#con-acceptornewline">AcceptOrNewline</a> | <a href="#con-newline">Newline</a> | <a href="#con-complete">Complete</a> | <a href="#con-reversesearch">ReverseSearch</a> | <a href="#con-abort">Abort</a> | <a href="#con-cancel">Cancel</a> | <a href="#con-clearscreen">ClearScreen</a> | <a href="#con-suspend">Suspend</a>
    | <a href="#con-ignore">Ignore</a>
  val <a href="#val-emacs">emacs</a> : (Key.event * command) list
  type <a href="#type-config">config</a> = {
    <a href="#fld-config.prompt">prompt</a> : string, <a href="#fld-config.continuation">continuation</a> : string,
    <a href="#fld-config.iscomplete">isComplete</a> : string -&gt; bool,
    <a href="#fld-config.complete">complete</a> : string * int -&gt; {start : int, candidates : string list},
    <a href="#fld-config.hint">hint</a> : string -&gt; string option,
    <a href="#fld-config.highlight">highlight</a> : string -&gt; (int * int * Style.style) list,
    <a href="#fld-config.styles">styles</a> : {prompt : Style.style, hint : Style.style, menu : Style.style, search : Style.style,
              control : Style.style, mark : Style.style},
    <a href="#fld-config.bindings">bindings</a> : (Key.event * command) list,
    <a href="#fld-config.escapetimeout">escapeTimeout</a> : Time.time,
    <a href="#fld-config.policy">policy</a> : Grapheme.policy,
    <a href="#fld-config.basic">basic</a> : bool}
  val <a href="#val-defaults">defaults</a> : config
  type <a href="#type-state">state</a>
  datatype <a href="#type-outcome">outcome</a> = <a href="#con-continue">Continue</a> | <a href="#con-accept">Accept</a> of string | <a href="#con-cancelled">Cancelled</a> | <a href="#con-endofinput">EndOfInput</a> | <a href="#con-clear">Clear</a> | <a href="#con-stop">Stop</a>
  val <a href="#val-start">start</a> : string vector * string -&gt; state
  val <a href="#val-step">step</a> : config * state * Key.event -&gt; state * outcome
  val <a href="#val-text">text</a> : state -&gt; string
  val <a href="#val-cursor">cursor</a> : state -&gt; int
  type <a href="#type-cell">cell</a> = {<a href="#fld-cell.text">text</a> : string, <a href="#fld-cell.style">style</a> : Style.style}
  type <a href="#type-frame">frame</a> = {<a href="#fld-frame.rows">rows</a> : cell list vector, <a href="#fld-frame.cursor">cursor</a> : int * int}
  val <a href="#val-layout">layout</a> : config * state * int -&gt; frame
  val <a href="#val-diff">diff</a> : {<a href="#fld-diff.old">old</a> : frame option, <a href="#fld-diff.new">new</a> : frame, <a href="#fld-diff.columns">columns</a> : int, <a href="#fld-diff.drawn">drawn</a> : int} -&gt; string * int
  datatype <a href="#type-result">result</a> = <a href="#con-line">Line</a> of string | <a href="#con-interrupted">Interrupted</a> | <a href="#con-end">End</a>
  val <a href="#val-readline">readLine</a> : config * History.history option -&gt; result
end
</pre>

### <a name="type-command"></a>`command`

```sml
datatype command =
    Insert
  | BeginningOfLine | EndOfLine | ForwardChar | BackwardChar | ForwardWord | BackwardWord
  | PreviousLine | NextLine | PreviousHistory | NextHistory | BeginningOfHistory | EndOfHistory
  | BeginningOfBuffer | EndOfBuffer
  | DeleteChar | DeleteCharOrEnd | BackwardDeleteChar | KillLine | BackwardKillLine
  | KillWord | BackwardKillWord | KillWordBehind | Yank | YankPop
  | TransposeChars | UpcaseWord | DowncaseWord | CapitalizeWord | Undo
  | AcceptOrNewline | Newline | Complete | ReverseSearch | Abort | Cancel | ClearScreen | Suspend
  | Ignore
```

What a key does. [`Insert`](#con-insert) types the character of the key; the others
are named as in readline.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-insert"></a>`Insert` |  |  |
| <a name="con-beginningofline"></a>`BeginningOfLine` |  |  |
| <a name="con-endofline"></a>`EndOfLine` |  |  |
| <a name="con-forwardchar"></a>`ForwardChar` |  |  |
| <a name="con-backwardchar"></a>`BackwardChar` |  |  |
| <a name="con-forwardword"></a>`ForwardWord` |  |  |
| <a name="con-backwardword"></a>`BackwardWord` |  |  |
| <a name="con-previousline"></a>`PreviousLine` |  |  |
| <a name="con-nextline"></a>`NextLine` |  |  |
| <a name="con-previoushistory"></a>`PreviousHistory` |  |  |
| <a name="con-nexthistory"></a>`NextHistory` |  |  |
| <a name="con-beginningofhistory"></a>`BeginningOfHistory` |  |  |
| <a name="con-endofhistory"></a>`EndOfHistory` |  |  |
| <a name="con-beginningofbuffer"></a>`BeginningOfBuffer` |  |  |
| <a name="con-endofbuffer"></a>`EndOfBuffer` |  |  |
| <a name="con-deletechar"></a>`DeleteChar` |  |  |
| <a name="con-deletecharorend"></a>`DeleteCharOrEnd` |  |  |
| <a name="con-backwarddeletechar"></a>`BackwardDeleteChar` |  |  |
| <a name="con-killline"></a>`KillLine` |  |  |
| <a name="con-backwardkillline"></a>`BackwardKillLine` |  |  |
| <a name="con-killword"></a>`KillWord` |  |  |
| <a name="con-backwardkillword"></a>`BackwardKillWord` |  |  |
| <a name="con-killwordbehind"></a>`KillWordBehind` |  |  |
| <a name="con-yank"></a>`Yank` |  |  |
| <a name="con-yankpop"></a>`YankPop` |  |  |
| <a name="con-transposechars"></a>`TransposeChars` |  |  |
| <a name="con-upcaseword"></a>`UpcaseWord` |  |  |
| <a name="con-downcaseword"></a>`DowncaseWord` |  |  |
| <a name="con-capitalizeword"></a>`CapitalizeWord` |  |  |
| <a name="con-undo"></a>`Undo` |  |  |
| <a name="con-acceptornewline"></a>`AcceptOrNewline` |  |  |
| <a name="con-newline"></a>`Newline` |  |  |
| <a name="con-complete"></a>`Complete` |  |  |
| <a name="con-reversesearch"></a>`ReverseSearch` |  |  |
| <a name="con-abort"></a>`Abort` |  |  |
| <a name="con-cancel"></a>`Cancel` |  |  |
| <a name="con-clearscreen"></a>`ClearScreen` |  |  |
| <a name="con-suspend"></a>`Suspend` |  |  |
| <a name="con-ignore"></a>`Ignore` |  |  |

### <a name="val-emacs"></a>`emacs`

```sml
val emacs : (Key.event * command) list
```

Readline's keys, as the comment above lists them.

### <a name="type-config"></a>`config`

```sml
type config = {
  prompt : string, continuation : string,
  isComplete : string -> bool,
  complete : string * int -> {start : int, candidates : string list},
  hint : string -> string option,
  highlight : string -> (int * int * Style.style) list,
  styles : {prompt : Style.style, hint : Style.style, menu : Style.style, search : Style.style,
            control : Style.style, mark : Style.style},
  bindings : (Key.event * command) list,
  escapeTimeout : Time.time,
  policy : Grapheme.policy,
  basic : bool}
```

What the editor is given: the prompts, what it asks of the program,
its styles and keys.

`prompt` begins the first line and `continuation` the others. `isComplete text` says whether Enter
accepts [`text`](#val-text) or begins a new line. `complete (text, i)` is where
the word before byte `i` begins and what it can be completed to.
`hint text` is text shown faintly after the end, which Right or
Ctrl-E there accepts. `highlight text` is styles for byte ranges of
the text, `(start, stop, style)`. `styles` are those of the parts the
editor draws itself. `escapeTimeout` is how long Escape waits for
the rest of a sequence; `policy` how the terminal measures clusters;
`basic` asks for the basic mode.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-config.prompt"></a>`prompt` | `string` |  |
| <a name="fld-config.continuation"></a>`continuation` | `string` |  |
| <a name="fld-config.iscomplete"></a>`isComplete` | `string -> bool` |  |
| <a name="fld-config.complete"></a>`complete` | `string * int -> {start : int, candidates : string list}` |  |
| <a name="fld-config.hint"></a>`hint` | `string -> string option` |  |
| <a name="fld-config.highlight"></a>`highlight` | `string -> (int * int * Style.style) list` |  |
| <a name="fld-config.styles"></a>`styles` | `{prompt : Style.style, hint : Style.style, menu : Style.style, search : Style.style, control : Style.style, mark : Style.style}` |  |
| <a name="fld-config.bindings"></a>`bindings` | `(Key.event * command) list` |  |
| <a name="fld-config.escapetimeout"></a>`escapeTimeout` | `Time.time` |  |
| <a name="fld-config.policy"></a>`policy` | `Grapheme.policy` |  |
| <a name="fld-config.basic"></a>`basic` | `bool` |  |

### <a name="val-defaults"></a>`defaults`

```sml
val defaults : config
```

A configuration for an input of one line at the prompt `"> "`.

Every input is complete; there is nothing to complete, hint or
highlight; hints are faint and a search bold; the keys are Emacs's,
Escape waits 50 ms, and clusters are measured whole.

### <a name="type-state"></a>`state`

```sml
type state
```

What the editor holds: the text, the cursor, the kill ring, what can
be undone, the history and where in it the text came from.

### <a name="type-outcome"></a>`outcome`

```sml
datatype outcome = Continue | Accept of string | Cancelled | EndOfInput | Clear | Stop
```

What a key asks of the loop: nothing more, to return the text or no
text, to clear the screen, or to suspend the process.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-continue"></a>`Continue` |  |  |
| <a name="con-accept"></a>`Accept` | `string` |  |
| <a name="con-cancelled"></a>`Cancelled` |  |  |
| <a name="con-endofinput"></a>`EndOfInput` |  |  |
| <a name="con-clear"></a>`Clear` |  |  |
| <a name="con-stop"></a>`Stop` |  |  |

### <a name="val-start"></a>`start`

```sml
val start : string vector * string -> state
```

`start (history, text)` is the state of a new input with `text`
typed and the cursor after it, `history` the entries Up goes back
through, the oldest first.

### <a name="val-step"></a>`step`

```sml
val step : config * state * Key.event -> state * outcome
```

`step (c, s, e)` is the state after the key `e`, and what it asks.

**Example** `text (#1 (step (defaults, start (Vector.fromList [], ""), Key.Char (97, Key.none)))) = "a"`

### <a name="val-text"></a>`text`

```sml
val text : state -> string
```

`text s` is the text, its lines joined by newlines.

### <a name="val-cursor"></a>`cursor`

```sml
val cursor : state -> int
```

`cursor s` is the byte of the text the cursor is at.

### <a name="type-cell"></a>`cell`

```sml
type cell = {text : string, style : Style.style}
```

A cell of the screen: a cluster (" " blank, "" the right half of a
wide one) and its style, as the emulator has them.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-cell.text"></a>`text` | `string` |  |
| <a name="fld-cell.style"></a>`style` | `Style.style` |  |

### <a name="type-frame"></a>`frame`

```sml
type frame = {rows : cell list vector, cursor : int * int}
```

What the terminal shows of the editor: rows of cells, without the
blank cells of plain style at their ends, and the cursor's row and
column.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-frame.rows"></a>`rows` | `cell list vector` |  |
| <a name="fld-frame.cursor"></a>`cursor` | `int * int` |  |

### <a name="val-layout"></a>`layout`

```sml
val layout : config * state * int -> frame
```

`layout (c, s, columns)` is the frame of `s` on a terminal that wide.

It holds the prompt, the lines wrapped at `columns`, the hint, the
matches of a completion and the line of a search.

### <a name="val-diff"></a>`diff`

```sml
val diff : {old : frame option, new : frame, columns : int, drawn : int} -> string * int
```

`diff {old, new, columns, drawn}` is the bytes that change what the
terminal shows from `old` to `new`, and the rows drawn on since.

`old` is `NONE` when nothing is drawn yet and the cursor is at the
start of an empty line; `drawn` is the rows drawn on before. Rows that
did not change are not written; a row is written from its first
changed cell; the cursor moves relative to where it was, by rows, and
to a column. Neither frame may be taller than the terminal.

tests/lib/terminal/edit.sml checks, for random edits at random
widths, that [`Emulator`](../str/Emulator.md) shows `new` once it has been given what
[`diff`](#val-diff) writes over a screen that shows `old`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-diff.old"></a>`old` | `frame option` |  |
| <a name="fld-diff.new"></a>`new` | `frame` |  |
| <a name="fld-diff.columns"></a>`columns` | `int` |  |
| <a name="fld-diff.drawn"></a>`drawn` | `int` |  |

### <a name="type-result"></a>`result`

```sml
datatype result = Line of string | Interrupted | End
```

What [`readLine`](#val-readline) read: a line, a cancelled one, or the end of the
input.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-line"></a>`Line` | `string` |  |
| <a name="con-interrupted"></a>`Interrupted` |  |  |
| <a name="con-end"></a>`End` |  |  |

### <a name="val-readline"></a>`readLine`

```sml
val readLine : config * History.history option -> result
```

`readLine (c, h)` reads an input at the terminal with the editor,
going back through the history `h` and adding the input to it.

It puts the terminal back before it returns. It is the basic mode when
`#basic c`, when the standard input or output is not a terminal,
when `TERM` is `dumb`, `unknown`, `cons25` or [`emacs`](#val-emacs), when
`INSIDE_EMACS` names comint, or when `RUNE_BASIC_REPL` is set.

---

<sub>Generated by runedoc from lib/terminal/line\_edit\_sig.sml; do not edit.</sub>

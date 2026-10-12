(* A line editor: what is typed at a prompt, edited with Emacs's keys,
   drawn on a terminal, of one line or many.

   The editor is a pure core under a thin loop (docs/plans/repl.md, D7).
   `step` takes a state and a key to the next state and what it asks of
   the loop; `layout` turns a state into a frame, the rows of cells the
   terminal should show and where the cursor is, wrapping by display
   width itself; `diff` turns the frame the terminal shows and the next
   into the bytes that change one into the other, with relative moves and
   only the rows that changed. `readLine` is the loop: it reads keys,
   steps and draws, and falls back to a basic mode -- a prompt and
   `TextIO.inputLine` -- where the terminal cannot be edited on.

   The keys are readline's: Ctrl-A, Ctrl-E, Ctrl-B, Ctrl-F, Alt-B, Alt-F
   and the arrows to move; Ctrl-D, Delete, Backspace, Ctrl-K, Ctrl-U,
   Ctrl-W, Alt-D and Alt-Backspace to delete, killing into a ring that
   Ctrl-Y and Alt-Y yank from; Ctrl-T, Alt-U, Alt-L and Alt-C; Ctrl-_ to
   undo; Up and Down through the lines and then the history, searching
   it by what was typed; Ctrl-R to search it incrementally; Tab to
   complete; Enter to accept a complete input or begin a new line, and
   Alt-Enter for a new line always; Ctrl-L to clear the screen; Ctrl-C to
   cancel; Ctrl-Z to suspend. `bindings` changes them.

   With `keys = Vi` the editor has Vi's modes: what is typed is inserted,
   as with Emacs's keys, until Escape, which goes to the normal mode,
   where letters are commands -- counts, the motions h l w b e 0 ^ $, the
   operators d c y with a motion or doubled, x X D C s S r ~ p P u, j and
   k through the lines and the history, G and gg, and i a I A o O back to
   inserting. The cursor is a block in the normal mode and a bar while
   inserting.

   Area: Terminals *)
signature LINE_EDIT =
sig
  (* What a key does. `Insert` types the character of the key; the others
     are named as in readline. *)
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

  (* Readline's keys, as the comment above lists them. *)
  val emacs : (Key.event * command) list

  (* Whether letters are typed always (Emacs's keys), or are Vi's commands
     in its normal mode. *)
  datatype keys = Emacs | Vi

  (* What the editor is given: the prompts, what it asks of the program,
     its styles and keys.

     `prompt` begins the first line and `continuation` the others. `isComplete text` says whether Enter
     accepts `text` or begins a new line. `complete (text, i)` is where
     the word before byte `i` begins and what it can be completed to.
     `hint text` is text shown faintly after the end, which Right or
     Ctrl-E there accepts. `highlight text` is styles for byte ranges of
     the text, `(start, stop, style)`. `styles` are those of the parts the
     editor draws itself. `escapeTimeout` is how long Escape waits for
     the rest of a sequence; `policy` how the terminal measures clusters;
     `basic` asks for the basic mode; `keys` whether Vi's modes are on
     (`bindings` are those of both modes but the normal mode's letters). *)
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
    basic : bool,
    keys : keys}

  (* A configuration for an input of one line at the prompt `"> "`.

     Every input is complete; there is nothing to complete, hint or
     highlight; hints are faint and a search bold; the keys are Emacs's,
     Escape waits 50 ms, and clusters are measured whole. *)
  val defaults : config

  (* What the editor holds: the text, the cursor, the kill ring, what can
     be undone, the history and where in it the text came from, and Vi's
     mode. *)
  type state

  (* `normal s` is whether `s` is in Vi's normal mode. *)
  val normal : state -> bool

  (* What a key asks of the loop: nothing more, to return the text or no
     text, to clear the screen, or to suspend the process. *)
  datatype outcome = Continue | Accept of string | Cancelled | EndOfInput | Clear | Stop

  (* `start (history, text)` is the state of a new input with `text`
     typed and the cursor after it, `history` the entries Up goes back
     through, the oldest first. *)
  val start : string vector * string -> state

  (* `step (c, s, e)` is the state after the key `e`, and what it asks.

     Example: `text (#1 (step (defaults, start (Vector.fromList [], ""), Key.Char (97, Key.none)))) = "a"` *)
  val step : config * state * Key.event -> state * outcome

  (* `text s` is the text, its lines joined by newlines. *)
  val text : state -> string

  (* `cursor s` is the byte of the text the cursor is at. *)
  val cursor : state -> int

  (* A cell of the screen: a cluster (" " blank, "" the right half of a
     wide one) and its style, as the emulator has them. *)
  type cell = {text : string, style : Style.style}

  (* What the terminal shows of the editor: rows of cells, without the
     blank cells of plain style at their ends, and the cursor's row and
     column. *)
  type frame = {rows : cell list vector, cursor : int * int}

  (* `layout (c, s, columns)` is the frame of `s` on a terminal that wide.

     It holds the prompt, the lines wrapped at `columns`, the hint, the
     matches of a completion and the line of a search. *)
  val layout : config * state * int -> frame

  (* `diff {old, new, columns, drawn}` is the bytes that change what the
     terminal shows from `old` to `new`, and the rows drawn on since.

     `old` is `NONE` when nothing is drawn yet and the cursor is at the
     start of an empty line; `drawn` is the rows drawn on before. Rows that
     did not change are not written; a row is written from its first
     changed cell; the cursor moves relative to where it was, by rows, and
     to a column. Neither frame may be taller than the terminal.

     tests/lib/terminal/edit.sml checks, for random edits at random
     widths, that `Emulator` shows `new` once it has been given what
     `diff` writes over a screen that shows `old`. *)
  val diff : {old : frame option, new : frame, columns : int, drawn : int} -> string * int

  (* What `readLine` read: a line, a cancelled one, or the end of the
     input. *)
  datatype result = Line of string | Interrupted | End

  (* `basic c` is whether `readLine` keeps to its basic mode with `c`, by
     the rule `readLine` gives.

     A program with a basic mode of its own, as the REPL has, asks it
     before it reads. *)
  val basic : config -> bool
  (* `keepRaw`, when set, asks `readLine` to leave the terminal quiet
     after an accepted line: the echo off, and Ctrl-C a signal.

     The REPL sets it. Putting the terminal back would turn the echo on,
     and a key typed before quiet mode would show up in what the code
     writes. Full raw mode would instead take Ctrl-C as a byte. An
     interrupt and the end of the input put the terminal back either way. *)
  val keepRaw : bool ref
  (* `promptHook` is what to run once the terminal is raw, just before the
     prompt is drawn. *)
  type promptHook = unit -> unit
  (* `beforePrompt`, when set, is run once the terminal is raw, just
     before the prompt is drawn. The basic mode does not run it.

     The REPL announces the prompt there. A key typed at that
     announcement is then read as itself: in the cooked mode a return is
     translated, and echoed, before the editor can see it. *)
  val beforePrompt : promptHook ref
  (* `readLine (c, h)` reads an input at the terminal with the editor,
     going back through the history `h` and adding the input to it.

     It puts the terminal back before it returns, unless `keepRaw` is set
     and it read a line, when the terminal stays quiet. Where `beforePrompt`
     is set, it is called once the terminal is raw and just before the
     prompt is drawn. It is the basic mode when `#basic c`, when the
     standard input or output is not a terminal, when `TERM` is `dumb`,
     `unknown`, `cons25` or `emacs`, when `INSIDE_EMACS` names comint, or
     when `RUNE_BASIC_REPL` is set. *)
  val readLine : config * History.history option -> result

  (* `terminal ()` is what the terminal said of itself at the first
     `readLine`, once its answers have come.

     How it measures a cluster, which `readLine` then uses in place of the
     config's `policy`, and whether it speaks the kitty keyboard protocol,
     which `readLine` turns on while it reads (keys told apart: Escape at
     once, Ctrl-I apart from Tab). `NONE` and false where it has not
     answered. *)
  val terminal : unit -> {policy : Grapheme.policy option, kitty : bool}
end

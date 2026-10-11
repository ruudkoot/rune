# Testing the REPL by hand

What the scripts of `tests/terminal` cannot see: the terminals people use,
each with its own way of drawing, of measuring characters and of taking
keys (docs/plans/repl.md, D23). The scripts drive tmux, and on Windows
ConPTY through WSL interop; everything below is checked by a person, on
each terminal of the list, when the REPL's terminal front or the runtime's
console changes, and at M13, which records the results at the end of this
file.

## The terminals

| Terminal | System | How it is started |
|---|---|---|
| The legacy console window (conhost, "Use legacy console") | Windows 10 or 11 | `rune-repl.cmd` from `cmd.exe` |
| Windows' console (conhost) | Windows 10 or 11 | `rune-repl.cmd` from `cmd.exe` |
| Windows Terminal | Windows 11 | `rune-repl.cmd` in a profile of PowerShell |
| VS Code's terminal | Windows | `rune-repl.cmd` |
| VS Code's terminal | Linux (and WSL) | `rune-repl` |
| GNOME Terminal (VTE) | Linux | `rune-repl` |
| kitty | Linux | `rune-repl` |
| xterm | Linux | `rune-repl` |
| tmux inside any of them | Linux | `rune-repl` |
| ssh from Windows Terminal to Linux | | `rune-repl` |
| A screen reader with the basic mode (NVDA on Windows, Orca on Linux) | | `rune-repl --basic` |
| Emacs's `M-x shell` and `run-sml` (comint) | Linux | `rune-repl` (basic by `INSIDE_EMACS`) |

## What to check

Start the REPL in an empty directory with `XDG_STATE_HOME` and
`XDG_CONFIG_HOME` pointed at fresh directories (on Windows,
`LOCALAPPDATA` and `APPDATA`), so that no history or init file of one's
own takes part.

1. **The start.** One line of banner in the faint style, then the prompt
   `- ` in bold. With `-q`, no banner.
2. **Colours as typed.** `val s = "two" (* c *) : string;` -- `val` bold, the
   string coloured, the comment faint, before Enter. In the light and
   dark themes (`RUNE_COLORS=theme=light`, `theme=dark`) every role reads
   on the terminal's background. With `NO_COLOR=1`, bold and faint only;
   with `--color=never`, nothing.
3. **Editing.** Ctrl-A, Ctrl-E, Alt-B, Alt-F, the arrows, Ctrl-K and Ctrl-Y,
   Ctrl-_ to undo, Alt-Enter for a new line in the middle of an entry.
   Home, End, Delete and the arrows with Ctrl on each terminal.
4. **Several lines.** `fun f 0 = 1` Enter `| f n = n * f (n - 1);` Enter: the
   continuation prompt `= ` on the second line, the entry run once.
   Up brings back both lines as one entry.
5. **Completion.** `Lis` Tab gives `List`; `List.fi` Tab Tab shows the
   menu under the entry; `use "` Tab lists the files of the directory.
6. **History.** Up and Down; Ctrl-R and a word; a second REPL started
   meanwhile sees the entries of the first at its next prompt.
7. **Paste.** A block of twenty declarations pasted at once is one entry
   (bracketed paste), drawn once, run at Enter.
8. **Width.** `"日本語 and 😀";` and a line longer than the window: the
   cursor stays where the text is; the window made narrower and wider
   while an entry of three lines is typed draws it again below, legibly.
9. **Errors.** `val x = undefinedName;` shows the line with `^` under the
   name; `val s = "no end` Enter reports the string at once.
10. **The partial line.** `print "abc";` leaves `abc%` and the echo on the
    next line; `print "abc\n";` leaves no `%`.
11. **Interrupts.** `fun loop () = loop (); loop ();` then Ctrl-C:
    `Interrupt` and a new prompt. Ctrl-C at the prompt cancels the entry
    and shows `^C`; Ctrl-D on an empty entry ends the session.
12. **Keys typed ahead.** `Posix.Process.sleep (Time.fromSeconds 3);`
    then, before it ends, `7;` and Enter: nothing appears until the sleep
    ends, then `- 7;` is run at the next prompt.
13. **A program reading.** `TextIO.inputLine TextIO.stdIn;` and a line
    typed: echoed as typed, Backspace working, the value shown.
14. **Stop and continue** (POSIX). Ctrl-Z in the middle of an entry, `fg`:
    the entry drawn again as it was.
15. **The terminal put back.** After `OS.Process.exit OS.Process.failure;`,
    after `kill -TERM` of the REPL from another shell, and after a stack
    overflow (`fun f n = 1 + f n; f 0;`): the shell echoes and edits lines.
16. **Marks** (Windows Terminal, VS Code). Each entry is a command the
    terminal knows: VS Code's decorations beside the prompt, red for an
    entry that failed; Windows Terminal's marks on its scroll bar.
17. **The basic mode.** `rune-repl --basic`, `TERM=dumb rune-repl`, and in
    Emacs: a prompt and a line at a time, no escapes at all in what is
    written (`rune-repl --basic | od -c` shows none).

## Results

| Date | Terminal | Version | Steps that failed | Notes |
|---|---|---|---|---|

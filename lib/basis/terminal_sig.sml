(* The terminal of a program that edits what is typed at it, as a line
   editor does: the window's size and its changes, keys read one by one
   with a time limit, and a terminal put back as it was whatever way the
   program ends (docs/plans/repl.md, D4 and D5).

   The terminal is the process's own: keys are read from the standard
   input and the program draws on the standard output. `Posix.TTY` sets a
   terminal's modes too, but where this structure differs is in what the
   runtime does beside: it puts the terminal back at exit, at a fatal
   error and at a signal that ends the process, which a program cannot
   do for itself; it counts the window's changes of size (`SIGWINCH`); and
   on Windows it reads the console's records, with the console making the
   same bytes of each key that a terminal of Unix sends, so that a program
   decodes one language of keys everywhere. `lib/terminal` is built on it.

   What `TextIO.stdIn` has read ahead into its buffer is not seen by
   `read`: a program reads its terminal with one or the other while it is
   raw.

   Area: The runtime

   Status: extension

   Deviation: `TERMINAL/not-in-the-specification`. The specification
   has `Posix.TTY` for a terminal's modes and nothing for a window's size,
   a key read with a time limit or a console of Windows; this signature is
   Rune's alone, and a program that uses it does not port.

   See also: `POSIX_TTY`, `RUNTIME` *)
signature TERMINAL =
sig
  (* `size ()` is the columns and rows of the terminal's window, or `NONE`
     when no standard stream is a terminal.

     The terminal is the standard output's, or, when that is not one, the
     standard input's or error's. A terminal that does not know its size
     says 0 for both. *)
  val size : unit -> {columns : int, rows : int} option

  (* `resizes ()` is how many times the window has changed its size since
     the first call of `resizes`, which starts the count.

     A program asks it before it draws and draws the whole screen again
     when it has grown. On Windows the changes are seen by `read`, while
     the terminal is raw. `~1` where the system cannot count them. *)
  val resizes : unit -> int

  (* `enter {undo}` puts the terminal of the standard input in raw mode,
     which the runtime undoes however the program ends.

     Raw is each byte as it is typed, nothing echoed, no signal from a key
     -- Ctrl-C is the byte 3 -- and the output still translated, a newline
     written as a carriage return and a newline. On Windows the console
     makes each key the bytes a terminal of Unix sends, in UTF-8.

     `undo` is what to write to the standard output to take back what the
     program turned on itself with escapes (bracketed paste, a hidden
     cursor): it is written when the terminal is put back, by `leave` or by
     the runtime. The runtime puts the terminal back at exit, at a fatal
     error, at `SIGTERM`, `SIGHUP` and `SIGQUIT`, and on a stop (`SIGTSTP`),
     making it raw again when the process is continued and counting that
     as a resize, since the screen may have changed meanwhile.

     What the terminal was is kept from the first call, so a program can
     enter and leave as often as it likes; to enter while raw changes
     `undo`.

     Raises: `OS.SysErr` when the standard input is not a terminal, or a
     console of Windows refuses VT input (before Windows 10 1511, or the
     legacy console), or `undo` is longer than 256 bytes. *)
  val enter : {undo : string} -> unit

  (* `leave ()` puts the terminal back as it was before `enter`, writing
     `undo`; nothing when it is not raw. *)
  val leave : unit -> unit

  (* `read wait` is the bytes typed at the terminal since the last `read`,
     waiting for them at most `wait` (`NONE`: as long as it takes).

     It is `SOME ""` when the time is up or a resize ended the wait, and
     `NONE` at the end of the input. A key can arrive in two reads; the
     bytes are those the terminal sent, so a key is decoded from what the
     reads gave, not from one read.

     Raises: `OS.SysErr` when the standard input is not a terminal, or the
     read fails. The user's interrupt, where the program catches it
     (`Runtime`), is raised where it ends the wait. *)
  val read : Time.time option -> string option
end

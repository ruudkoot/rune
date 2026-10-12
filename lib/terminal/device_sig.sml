(* The terminal as the line editor uses it: the standard input and output,
   put in raw mode and read key by key, the window's size, and how the
   terminal measures what it draws.

   `Device` is Rune's, over the Basis's `Terminal`: the runtime puts the
   terminal back however the program ends, counts the window's changes of
   size, and reads a console of Windows. `PosixDevice` is the same
   signature over `Posix.TTY` and `OS.IO.poll` alone, for the other
   compilers of Standard ML: it knows no size but `COLUMNS` and `LINES`,
   sees no resize, and puts the terminal back at `leave` only.

   Area: Terminals *)
signature DEVICE =
sig
  (* `available ()` is whether the standard input and output are both a
     terminal and `TERM` is not `dumb`: whether a program can edit there. *)
  val available : unit -> bool

  (* `size ()` is the columns and rows of the window, 80 and 24 where it
     cannot be known. *)
  val size : unit -> {columns : int, rows : int}

  (* `resizes ()` is how many times the window has changed its size since
     the first call.

     A program draws everything again when it has grown. It stays 0 where
     changes cannot be seen. *)
  val resizes : unit -> int

  (* `enter {undo}` puts the terminal in raw mode: each byte as it is
     typed, no echo, no signal from a key.

     `undo` is what to write when it is put back, to take back what the
     program turned on with escapes.

     Raises: `OS.SysErr` when the standard input is not a terminal. *)
  val enter : {undo : string} -> unit

  (* `quiet ()` turns the echo off and leaves a return as it was typed,
     and a signal key is a signal again.

     Raw mode has taken the signals. `quiet` puts them back without
     turning the echo on. It clears the undo text `enter` stored: the
     caller writes that text first, since `leave` would otherwise write
     it later.

     Raises: `OS.SysErr` when the standard input is not a terminal. *)
  val quiet : unit -> unit

  (* `leave ()` puts the terminal back as it was, writing `undo`. *)
  val leave : unit -> unit

  (* `read wait` is the bytes typed, waiting at most `wait`, or `NONE` at
     the end of the input.

     `wait` `NONE` waits as long as it takes; `SOME ""` is nothing in the
     time, or a resize that ended the wait.

     Raises: `OS.SysErr` when the read fails. *)
  val read : Time.time option -> string option

  (* `write s` writes `s` to the standard output at once. *)
  val write : string -> unit

  (* `policy ()` is how the terminal measures a grapheme cluster.

     By code point in VS Code's terminal on Windows (`TERM_PROGRAM`),
     which draws each code point of a cluster as wide as its own width,
     and by cluster everywhere else. *)
  val policy : unit -> Grapheme.policy
end

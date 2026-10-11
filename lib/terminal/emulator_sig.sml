(* A terminal emulated in memory: what a screen shows after a program has
   written to it, for testing what a program draws without a terminal.

   It knows what a line editor writes: text, with grapheme clusters as wide
   as the width policy says and a wide one wrapped whole; carriage return,
   newline (which scrolls at the bottom), backspace and tab; ECMA-48's
   cursor movements (CUU, CUD, CUF, CUB, CHA, CUP), erasing in a line and
   in the display (EL, ED), and SGR; and xterm's pending wrap -- after a
   character in the last column the cursor stays there until the next
   character, which goes to the start of the next line. Modes are
   recorded (bracketed paste, a hidden cursor); other escapes are
   ignored.

   Area: Terminals *)
signature EMULATOR =
sig
  (* A cell of the screen: the cluster it shows (" " when blank, "" for
     the right half of a wide cluster) and its style. *)
  type cell = {text : string, style : Style.style}

  (* A screen and its cursor. *)
  type screen

  (* `new {columns, rows, policy}` is a blank screen of that size with the
     cursor at its top left, measuring clusters by `policy`.

     Example: `cursor (new {columns = 80, rows = 24, policy = Grapheme.ByCluster}) = (0, 0)` *)
  val new : {columns : int, rows : int, policy : Grapheme.policy} -> screen

  (* `write (s, bytes)` is the screen after `bytes` were written to `s`.

     Bytes of a UTF-8 character or an escape split between two writes
     are joined, as a terminal joins them. *)
  val write : screen * string -> screen

  (* `cursor s` is the cursor's row and column, from 0. *)
  val cursor : screen -> int * int

  (* `row (s, i)` is the cells of row `i`, without the blank cells of
     default style at its end.

     Raises: `Subscript` when there is no row `i`. *)
  val row : screen * int -> cell list

  (* `text s` is the screen as text, a line a row, without the blanks at
     the ends of rows and the empty rows at the end.

     Example: `text (write (new {columns = 4, rows = 2, policy = Grapheme.ByCluster}, "abcde")) = "abcd\ne"` *)
  val text : screen -> string

  (* `scrolled s` is how many rows have scrolled off the top. *)
  val scrolled : screen -> int

  (* `modes s` is whether bracketed paste is on (mode 2004) and whether
     the cursor is shown (mode 25). *)
  val modes : screen -> {bracketedPaste : bool, cursorVisible : bool}
end

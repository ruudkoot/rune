(* Haskell source text: spans, positions and the errors of the front end.

   A position is a byte offset of the file everywhere inside the front end,
   as it is inside Rune's compiler (docs/diagnostics.md, Columns), and a
   span is the compiler's `Source.span`, so that a driver can show a
   diagnostic of `lib/language/haskell` as it shows its own. A line and a
   column are worked out only where a diagnostic is shown.

   Area: Languages *)
signature HS_SOURCE =
sig
  (* The bytes from `start` up to `stop` of the file named `file`. *)
  type span = {file : string, start : int, stop : int}

  (* The span of no text, for a node that a tool made rather than the
     parser read. *)
  val noSpan : span

  (* `join (a, b)` is the span from the first byte of either to the last
     of either; the file is `a`'s. *)
  val join : span * span -> span

  (* A file's name and bytes, with where each of its lines begins. *)
  type text

  (* `text {file, bytes}` is the text of a file, with its table of lines. *)
  val text : {file : string, bytes : string} -> text

  (* `file t` is the name `t` was made with. *)
  val file : text -> string

  (* `bytes t` is the bytes `t` was made with. *)
  val bytes : text -> string

  (* `position (t, offset)` is the line of the byte `offset`, from 1, and
     its column, from 1, counting the characters before it on its line: a
     code point of UTF-8 counts one, and so does a byte that is not UTF-8.
     A tab counts one, as rustc and Emacs count (docs/diagnostics.md). *)
  val position : text * int -> {line : int, column : int}

  (* An error of the front end: where, and what, in a message that starts
     lowercase and names the construct. *)
  exception Error of span * string

  (* `message (t, span, msg)` is the first line of a diagnostic, as Rune's
     compiler prints it: `FILE:LINE:COL: error: MESSAGE`, where `FILE` has
     its control characters escaped as `\u{1B}`. *)
  val message : text * span * string -> string
end

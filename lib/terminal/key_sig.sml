(* Keys: the bytes a terminal sends turned into the keys that were pressed.

   A terminal sends a printable key as its UTF-8, a key with Ctrl as a
   control character, a key with Alt as Escape and the key, and the
   arrows, the function keys and the rest as escape sequences: CSI
   (`ESC [`, parameters, a final byte) or SS3 (`ESC O` and a byte), with
   the modifiers in xterm's parameter. The decoder reads a CSI sequence to
   its final byte before it looks it up, so that a sequence it does not
   know is reported as `Unknown` and never typed as text. Bracketed paste
   (mode 2004) arrives as one `Paste`. It also reads the kitty keyboard
   protocol's `CSI code ; modifiers u` and xterm's `CSI 27 ; modifiers ;
   code ~`, where a terminal sends them.

   Escape alone is ambiguous: it begins every sequence. The decoder keeps
   it pending, and `flush` -- called when no byte has come for a while, 50
   ms by default in `LineEdit` -- says it was the key Escape (or Alt and
   `[` or `O`, when those followed it).

   The decoder is a value: `feed` takes it and some bytes to the keys they
   complete and the decoder that waits for the rest, so the bytes of one
   key may come in any number of reads.

   Area: Terminals *)
signature KEY =
sig
  (* The keys that are not characters. *)
  datatype name =
      Up | Down | Left | Right | Home | End | Insert | Delete | PageUp | PageDown
    | Enter | Tab | Backspace | Escape | F of int

  (* The modifiers held with a key. Shift is reported for the named keys
     only: a character typed with Shift is the shifted character. *)
  type mods = {shift : bool, alt : bool, ctrl : bool}

  (* What was pressed or sent.

     `Char (c, m)` is the code point `c` with the modifiers `m`: Ctrl and
     a letter is the lower-case letter with `ctrl` (Ctrl-A is `Char (97,
     ...)`), and the control characters that are not keys of their own are
     `@`, `\`, `]`, `^` and `_` with `ctrl`. A byte that is not UTF-8 is
     U+FFFD. `Named (n, m)` is a named key. `Paste s` is the text of a
     bracketed paste, as it came. `CursorAt (row, column)` is a terminal's
     report of its cursor (from 1), the answer to `ESC [ 6 n`. `Reply s` is
     another answer to a question, an escape sequence with a private
     parameter (`ESC [ ? ...`). `Focus b` is the window's focus gained or
     lost (mode 1004). `Unknown s` is a sequence the decoder does not
     know, as it came. *)
  datatype event =
      Char of int * mods
    | Named of name * mods
    | Paste of string
    | CursorAt of int * int
    | Reply of string
    | Focus of bool
    | Unknown of string

  (* No modifier.

     Example: `none = {shift = false, alt = false, ctrl = false}` *)
  val none : mods

  (* A decoder: the bytes of a key begun and not yet complete. *)
  type decoder

  (* The decoder that has seen nothing.

     Example: `pending empty = false` *)
  val empty : decoder

  (* `feed (d, s)` is the keys that `d`'s pending bytes and `s` complete,
     in the order they were sent, and the decoder that holds what is left
     of a key not complete.

     The keys do not depend on how the bytes were split between calls:
     tests/lib/terminal/key.sml checks that every split of many streams
     gives the same keys.

     Example: `#1 (feed (empty, "a\027[A")) = [Char (97, none), Named (Up, none)]` *)
  val feed : decoder * string -> event list * decoder

  (* `pending d` is whether `d` holds the beginning of a key. *)
  val pending : decoder -> bool

  (* `flush d` is the keys that `d`'s pending bytes are when no more come,
     and the empty decoder.

     Escape alone is the key Escape, Escape and `[` or `O` is that
     character with Alt, an incomplete sequence is `Unknown`, an
     incomplete UTF-8 character U+FFFD.

     Example: `#1 (flush (#2 (feed (empty, "\027")))) = [Named (Escape, none)]` *)
  val flush : decoder -> event list * decoder

  (* `toString e` is a key as Emacs writes one: `C-a`, `M-b`, `Up`,
     `S-Tab`, `F5`, `SPC`, a character as itself; the other events by
     their constructor and what they carry.

     Example: `toString (Char (97, {shift = false, alt = true, ctrl = true})) = "C-M-a"` *)
  val toString : event -> string
end

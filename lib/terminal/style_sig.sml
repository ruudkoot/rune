(* The look of text on a terminal: colours and attributes, the escapes of
   ECMA-48's SGR that give them, and whether a program should use them at
   all.

   A style is a record, so that a cell of a screen can carry one and two
   can be compared; `sgr` writes the escape that sets a style from nothing,
   and `change` the shortest that goes from one style to another. A colour
   is one of the terminal's 16, which follow the user's theme, one of 256,
   or a colour of 24 bits; `downgrade` maps one a terminal does not have
   to the nearest it has.

   Area: Terminals *)
signature STYLE =
sig
  (* A colour: the terminal's own, one of its 16 or of xterm's 256, or one
     of 24 bits.

     `Ansi` is 0 to 7 and their bright forms 8 to 15; `Rgb` is red, green
     and blue of 0 to 255. *)
  datatype color = Default | Ansi of int | Indexed of int | Rgb of int * int * int

  (* A style: the colours of the text and of its background, and the
     attributes. *)
  type style = {fg : color, bg : color, bold : bool, faint : bool, italic : bool,
                underline : bool, reverse : bool, struck : bool}

  (* The style of plain text: default colours, no attribute.

     Example: `sgr plain = "\027[0m"` *)
  val plain : style

  (* `sgr s` is the escape that sets `s` whatever the terminal had before:
     a reset and then the parameters of `s`.

     Example: `sgr {fg = Ansi 1, bg = Default, bold = true, faint = false, italic = false,
     underline = false, reverse = false, struck = false} = "\027[0;1;31m"` *)
  val sgr : style -> string

  (* `change (a, b)` is what to write to go from style `a` to style `b`:
     nothing when they are the same, else `sgr b`.

     Example: `change (plain, plain) = ""` *)
  val change : style * style -> string

  (* `parameters p` is the style that the SGR parameters `p` set from
     plain.

     They are written as in an escape or a `GCC_COLORS` value ("1;31",
     "38;5;203", "38;2;255;95;95"); parameters it does not know are left
     out, and so is everything after a part that is not a number.

     Example: `#bold (parameters "1;31") andalso #fg (parameters "1;31") = Ansi 1` *)
  val parameters : string -> style

  (* How many colours a terminal shows: none (attributes only), 16, 256,
     or 24 bits. *)
  datatype depth = Mono | Colors16 | Colors256 | TrueColor

  (* `depth ()` is the colours the environment says the terminal has.

     `Mono` when `NO_COLOR` is set and not empty, `TrueColor` when
     `COLORTERM` is `truecolor` or `24bit`, 256 when `TERM` ends in
     `256color`, else 16. *)
  val depth : unit -> depth

  (* `downgrade d s` is `s` with each colour that `d` lacks replaced by the
     nearest one it has.

     An `Rgb` becomes the nearest of the 256, one of the 256 the nearest of
     the 16, and every colour `Default` at `Mono`.

     Example: `#fg (downgrade Colors256 (parameters "38;2;255;0;0")) = Indexed 196` *)
  val downgrade : depth -> style -> style

  (* When to style: always, never, or when the stream is a terminal. *)
  datatype choice = Always | Never | Auto

  (* `enabled (c, isTerminal)` is whether a program should style a stream,
     `isTerminal` saying whether the stream is a terminal.

     For `Auto` it is the rule of Rune's compiler (docs/diagnostics.md):
     `NO_COLOR`, `FORCE_COLOR`, `CLICOLOR_FORCE`, `CLICOLOR` and `TERM`
     decide before `isTerminal` does.

     Example: `enabled (Never, true) = false` *)
  val enabled : choice * bool -> bool
end

# signature STYLE

[Terminal](../README.md) &rsaquo; Terminals &rsaquo; **STYLE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 11 of 11 entries documented |
| Tests | not listed |
| Source | [lib/terminal/style\_sig.sml](../../../../lib/terminal/style_sig.sml) |

## Synopsis

```sml
signature STYLE
structure Style :> STYLE
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Style`](../str/Style.md) | Style: SGR escapes, the depth of colour, and when to style. | [lib/terminal/style.sml](../../../../lib/terminal/style.sml) |

The look of text on a terminal: colours and attributes, the escapes of
ECMA-48's SGR that give them, and whether a program should use them at
all.

A style is a record, so that a cell of a screen can carry one and two
can be compared; [`sgr`](#val-sgr) writes the escape that sets a style from nothing,
and [`change`](#val-change) the shortest that goes from one style to another. A colour
is one of the terminal's 16, which follow the user's theme, one of 256,
or a colour of 24 bits; [`downgrade`](#val-downgrade) maps one a terminal does not have
to the nearest it has.

## Interface

<pre>
signature STYLE =
sig
  datatype <a href="#type-color">color</a> = <a href="#con-default">Default</a> | <a href="#con-ansi">Ansi</a> of int | <a href="#con-indexed">Indexed</a> of int | <a href="#con-rgb">Rgb</a> of int * int * int
  type <a href="#type-style">style</a> = {<a href="#fld-style.fg">fg</a> : color, <a href="#fld-style.bg">bg</a> : color, <a href="#fld-style.bold">bold</a> : bool, <a href="#fld-style.faint">faint</a> : bool, <a href="#fld-style.italic">italic</a> : bool,
                <a href="#fld-style.underline">underline</a> : bool, <a href="#fld-style.reverse">reverse</a> : bool, <a href="#fld-style.struck">struck</a> : bool}
  val <a href="#val-plain">plain</a> : style
  val <a href="#val-sgr">sgr</a> : style -&gt; string
  val <a href="#val-change">change</a> : style * style -&gt; string
  val <a href="#val-parameters">parameters</a> : string -&gt; style
  datatype <a href="#type-depth">depth</a> = <a href="#con-mono">Mono</a> | <a href="#con-colors16">Colors16</a> | <a href="#con-colors256">Colors256</a> | <a href="#con-truecolor">TrueColor</a>
  val <a href="#val-depth">depth</a> : unit -&gt; depth
  val <a href="#val-downgrade">downgrade</a> : depth -&gt; style -&gt; style
  datatype <a href="#type-choice">choice</a> = <a href="#con-always">Always</a> | <a href="#con-never">Never</a> | <a href="#con-auto">Auto</a>
  val <a href="#val-enabled">enabled</a> : choice * bool -&gt; bool
end
</pre>

### <a name="type-color"></a>`color`

```sml
datatype color = Default | Ansi of int | Indexed of int | Rgb of int * int * int
```

A colour: the terminal's own, one of its 16 or of xterm's 256, or one
of 24 bits.

[`Ansi`](#con-ansi) is 0 to 7 and their bright forms 8 to 15; [`Rgb`](#con-rgb) is red, green
and blue of 0 to 255.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-default"></a>`Default` |  |  |
| <a name="con-ansi"></a>`Ansi` | `int` |  |
| <a name="con-indexed"></a>`Indexed` | `int` |  |
| <a name="con-rgb"></a>`Rgb` | `int * int * int` |  |

### <a name="type-style"></a>`style`

```sml
type style = {fg : color, bg : color, bold : bool, faint : bool, italic : bool,
              underline : bool, reverse : bool, struck : bool}
```

A style: the colours of the text and of its background, and the
attributes.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-style.fg"></a>`fg` | `color` |  |
| <a name="fld-style.bg"></a>`bg` | `color` |  |
| <a name="fld-style.bold"></a>`bold` | `bool` |  |
| <a name="fld-style.faint"></a>`faint` | `bool` |  |
| <a name="fld-style.italic"></a>`italic` | `bool` |  |
| <a name="fld-style.underline"></a>`underline` | `bool` |  |
| <a name="fld-style.reverse"></a>`reverse` | `bool` |  |
| <a name="fld-style.struck"></a>`struck` | `bool` |  |

### <a name="val-plain"></a>`plain`

```sml
val plain : style
```

The style of plain text: default colours, no attribute.

**Example** `sgr plain = "\027[0m"`

### <a name="val-sgr"></a>`sgr`

```sml
val sgr : style -> string
```

`sgr s` is the escape that sets `s` whatever the terminal had before:
a reset and then the parameters of `s`.

**Example** `sgr {fg = Ansi 1, bg = Default, bold = true, faint = false, italic = false, underline = false, reverse = false, struck = false} = "\027[0;1;31m"`

### <a name="val-change"></a>`change`

```sml
val change : style * style -> string
```

`change (a, b)` is what to write to go from style `a` to style `b`:
nothing when they are the same, else `sgr b`.

**Example** `change (plain, plain) = ""`

### <a name="val-parameters"></a>`parameters`

```sml
val parameters : string -> style
```

`parameters p` is the style that the SGR parameters `p` set from
plain.

They are written as in an escape or a `GCC_COLORS` value ("1;31",
"38;5;203", "38;2;255;95;95"); parameters it does not know are left
out, and so is everything after a part that is not a number.

**Example** `#bold (parameters "1;31") andalso #fg (parameters "1;31") = Ansi 1`

### <a name="type-depth"></a>`depth`

```sml
datatype depth = Mono | Colors16 | Colors256 | TrueColor
```

How many colours a terminal shows: none (attributes only), 16, 256,
or 24 bits.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-mono"></a>`Mono` |  |  |
| <a name="con-colors16"></a>`Colors16` |  |  |
| <a name="con-colors256"></a>`Colors256` |  |  |
| <a name="con-truecolor"></a>`TrueColor` |  |  |

### <a name="val-depth"></a>`depth`

```sml
val depth : unit -> depth
```

`depth ()` is the colours the environment says the terminal has.

[`Mono`](#con-mono) when `NO_COLOR` is set and not empty, [`TrueColor`](#con-truecolor) when
`COLORTERM` is `truecolor` or `24bit`, 256 when `TERM` ends in
`256color`, else 16.

### <a name="val-downgrade"></a>`downgrade`

```sml
val downgrade : depth -> style -> style
```

`downgrade d s` is `s` with each colour that `d` lacks replaced by the
nearest one it has.

An [`Rgb`](#con-rgb) becomes the nearest of the 256, one of the 256 the nearest of
the 16, and every colour [`Default`](#con-default) at [`Mono`](#con-mono).

**Example** `#fg (downgrade Colors256 (parameters "38;2;255;0;0")) = Indexed 196`

### <a name="type-choice"></a>`choice`

```sml
datatype choice = Always | Never | Auto
```

When to style: always, never, or when the stream is a terminal.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-always"></a>`Always` |  |  |
| <a name="con-never"></a>`Never` |  |  |
| <a name="con-auto"></a>`Auto` |  |  |

### <a name="val-enabled"></a>`enabled`

```sml
val enabled : choice * bool -> bool
```

`enabled (c, isTerminal)` is whether a program should style a stream,
`isTerminal` saying whether the stream is a terminal.

For [`Auto`](#con-auto) it is the rule of Rune's compiler (docs/diagnostics.md):
`NO_COLOR`, `FORCE_COLOR`, `CLICOLOR_FORCE`, `CLICOLOR` and `TERM`
decide before `isTerminal` does.

**Example** `enabled (Never, true) = false`

---

<sub>Generated by runedoc from lib/terminal/style\_sig.sml; do not edit.</sub>

# signature KEY

[Terminal](../README.md) &rsaquo; Terminals &rsaquo; **KEY**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 10 of 10 entries documented |
| Tests | not listed |
| Source | [lib/terminal/key\_sig.sml](../../../../lib/terminal/key_sig.sml) |

## Synopsis

```sml
signature KEY
structure Key :> KEY
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Key`](../str/Key.md) | Key: the decoder of the bytes a terminal sends. | [lib/terminal/key.sml](../../../../lib/terminal/key.sml) |

Keys: the bytes a terminal sends turned into the keys that were pressed.

A terminal sends a printable key as its UTF-8, a key with Ctrl as a
control character, a key with Alt as Escape and the key, and the
arrows, the function keys and the rest as escape sequences: CSI
(`ESC [`, parameters, a final byte) or SS3 (`ESC O` and a byte), with
the modifiers in xterm's parameter. The decoder reads a CSI sequence to
its final byte before it looks it up, so that a sequence it does not
know is reported as [`Unknown`](#con-unknown) and never typed as text. Bracketed paste
(mode 2004) arrives as one [`Paste`](#con-paste). It also reads the kitty keyboard
protocol's `CSI code ; modifiers u` and xterm's `CSI 27 ; modifiers ; code ~`, where a terminal sends them.

Escape alone is ambiguous: it begins every sequence. The decoder keeps
it pending, and [`flush`](#val-flush) \-- called when no byte has come for a while, 50
ms by default in [`LineEdit`](../str/LineEdit.md) \-- says it was the key Escape (or Alt and
`[` or `O`, when those followed it).

The decoder is a value: [`feed`](#val-feed) takes it and some bytes to the keys they
complete and the decoder that waits for the rest, so the bytes of one
key may come in any number of reads.

## Interface

<pre>
signature KEY =
sig
  datatype <a href="#type-name">name</a> =
      <a href="#con-up">Up</a> | <a href="#con-down">Down</a> | <a href="#con-left">Left</a> | <a href="#con-right">Right</a> | <a href="#con-home">Home</a> | <a href="#con-end">End</a> | <a href="#con-insert">Insert</a> | <a href="#con-delete">Delete</a> | <a href="#con-pageup">PageUp</a> | <a href="#con-pagedown">PageDown</a>
    | <a href="#con-enter">Enter</a> | <a href="#con-tab">Tab</a> | <a href="#con-backspace">Backspace</a> | <a href="#con-escape">Escape</a> | <a href="#con-f">F</a> of int
  type <a href="#type-mods">mods</a> = {<a href="#fld-mods.shift">shift</a> : bool, <a href="#fld-mods.alt">alt</a> : bool, <a href="#fld-mods.ctrl">ctrl</a> : bool}
  datatype <a href="#type-event">event</a> =
      <a href="#con-char">Char</a> of int * mods
    | <a href="#con-named">Named</a> of name * mods
    | <a href="#con-paste">Paste</a> of string
    | <a href="#con-cursorat">CursorAt</a> of int * int
    | <a href="#con-reply">Reply</a> of string
    | <a href="#con-focus">Focus</a> of bool
    | <a href="#con-unknown">Unknown</a> of string
  val <a href="#val-none">none</a> : mods
  type <a href="#type-decoder">decoder</a>
  val <a href="#val-empty">empty</a> : decoder
  val <a href="#val-feed">feed</a> : decoder * string -&gt; event list * decoder
  val <a href="#val-pending">pending</a> : decoder -&gt; bool
  val <a href="#val-flush">flush</a> : decoder -&gt; event list * decoder
  val <a href="#val-tostring">toString</a> : event -&gt; string
end
</pre>

### <a name="type-name"></a>`name`

```sml
datatype name =
    Up | Down | Left | Right | Home | End | Insert | Delete | PageUp | PageDown
  | Enter | Tab | Backspace | Escape | F of int
```

The keys that are not characters.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-up"></a>`Up` |  |  |
| <a name="con-down"></a>`Down` |  |  |
| <a name="con-left"></a>`Left` |  |  |
| <a name="con-right"></a>`Right` |  |  |
| <a name="con-home"></a>`Home` |  |  |
| <a name="con-end"></a>`End` |  |  |
| <a name="con-insert"></a>`Insert` |  |  |
| <a name="con-delete"></a>`Delete` |  |  |
| <a name="con-pageup"></a>`PageUp` |  |  |
| <a name="con-pagedown"></a>`PageDown` |  |  |
| <a name="con-enter"></a>`Enter` |  |  |
| <a name="con-tab"></a>`Tab` |  |  |
| <a name="con-backspace"></a>`Backspace` |  |  |
| <a name="con-escape"></a>`Escape` |  |  |
| <a name="con-f"></a>`F` | `int` |  |

### <a name="type-mods"></a>`mods`

```sml
type mods = {shift : bool, alt : bool, ctrl : bool}
```

The modifiers held with a key. Shift is reported for the named keys
only: a character typed with Shift is the shifted character.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-mods.shift"></a>`shift` | `bool` |  |
| <a name="fld-mods.alt"></a>`alt` | `bool` |  |
| <a name="fld-mods.ctrl"></a>`ctrl` | `bool` |  |

### <a name="type-event"></a>`event`

```sml
datatype event =
    Char of int * mods
  | Named of name * mods
  | Paste of string
  | CursorAt of int * int
  | Reply of string
  | Focus of bool
  | Unknown of string
```

What was pressed or sent.

`Char (c, m)` is the code point `c` with the modifiers `m`: Ctrl and
a letter is the lower-case letter with `ctrl` (Ctrl-A is `Char (97, ...)`), and the control characters that are not keys of their own are
[`@`](../../basis/sig/LIST.md#val-op-at), `\`, `]`, [`^`](../../basis/sig/STRING.md#val-op-caret) and `_` with `ctrl`. A byte that is not UTF-8 is
U+FFFD. `Named (n, m)` is a named key. `Paste s` is the text of a
bracketed paste, as it came. `CursorAt (row, column)` is a terminal's
report of its cursor (from 1), the answer to `ESC [ 6 n`. `Reply s` is
another answer to a question, an escape sequence with a private
parameter (`ESC [ ? ...`). `Focus b` is the window's focus gained or
lost (mode 1004). `Unknown s` is a sequence the decoder does not
know, as it came.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-char"></a>`Char` | `int * mods` |  |
| <a name="con-named"></a>`Named` | `name * mods` |  |
| <a name="con-paste"></a>`Paste` | `string` |  |
| <a name="con-cursorat"></a>`CursorAt` | `int * int` |  |
| <a name="con-reply"></a>`Reply` | `string` |  |
| <a name="con-focus"></a>`Focus` | `bool` |  |
| <a name="con-unknown"></a>`Unknown` | `string` |  |

### <a name="val-none"></a>`none`

```sml
val none : mods
```

No modifier.

**Example** `none = {shift = false, alt = false, ctrl = false}`

### <a name="type-decoder"></a>`decoder`

```sml
type decoder
```

A decoder: the bytes of a key begun and not yet complete.

### <a name="val-empty"></a>`empty`

```sml
val empty : decoder
```

The decoder that has seen nothing.

**Example** `pending empty = false`

### <a name="val-feed"></a>`feed`

```sml
val feed : decoder * string -> event list * decoder
```

`feed (d, s)` is the keys that `d`'s pending bytes and `s` complete,
in the order they were sent, and the decoder that holds what is left
of a key not complete.

The keys do not depend on how the bytes were split between calls:
tests/lib/terminal/key.sml checks that every split of many streams
gives the same keys.

**Example** `#1 (feed (empty, "a\027[A")) = [Char (97, none), Named (Up, none)]`

### <a name="val-pending"></a>`pending`

```sml
val pending : decoder -> bool
```

`pending d` is whether `d` holds the beginning of a key.

### <a name="val-flush"></a>`flush`

```sml
val flush : decoder -> event list * decoder
```

`flush d` is the keys that `d`'s pending bytes are when no more come,
and the empty decoder.

Escape alone is the key Escape, Escape and `[` or `O` is that
character with Alt, an incomplete sequence is [`Unknown`](#con-unknown), an
incomplete UTF-8 character U+FFFD.

**Example** `#1 (flush (#2 (feed (empty, "\027")))) = [Named (Escape, none)]`

### <a name="val-tostring"></a>`toString`

```sml
val toString : event -> string
```

`toString e` is a key as Emacs writes one: `C-a`, `M-b`, [`Up`](#con-up),
`S-Tab`, `F5`, `SPC`, a character as itself; the other events by
their constructor and what they carry.

**Example** `toString (Char (97, {shift = false, alt = true, ctrl = true})) = "C-M-a"`

---

<sub>Generated by runedoc from lib/terminal/key\_sig.sml; do not edit.</sub>

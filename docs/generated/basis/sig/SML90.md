# signature SML90

[The Standard ML Basis Library](../README.md) &rsaquo; The language &rsaquo; **SML90**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 36 of 36 entries documented |
| Tests | 57 checks of 34 entries |
| Source | [lib/basis/sig\_sml90.sml](../../../../lib/basis/sig_sml90.sml) |

## Synopsis

```sml
signature SML90
structure SML90 : SML90  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `SML90` | SML90: the initial basis of the 1990 Definition, over Real.Math, String and TextIO. As in MLton's (unexposed) SML90, which Poly/ML agrees with: the arithmetic exceptions are Overflow and Mod is Div, which the Library raises in their place; Sqrt, Ln, Ord, Io and Interrupt are new, and sqrt, ln, ord and the functions on streams raise them. | [lib/basis/sml90.sml](../../../../lib/basis/sml90.sml) |

What the 1990 library looked like, kept so that old programs still run.

Before the Basis Library there was the library of the first Definition:
[`std_in`](#val-std_in) and [`open_in`](#val-open_in) instead of [`TextIO`](../sig/TEXT_IO.md), [`explode`](#val-explode) giving a list of
one-character strings instead of a list of characters, and an exception
for every arithmetic fault instead of [`Overflow`](../sig/GENERAL.md#exn-overflow) and [`Div`](../sig/GENERAL.md#exn-div). This signature
is that library, and nothing here is meant for a new program.

The exceptions are raised where the new library raises [`Overflow`](../sig/GENERAL.md#exn-overflow), [`Div`](../sig/GENERAL.md#exn-div)
or [`Domain`](../sig/GENERAL.md#exn-domain), and the arithmetic and text functions are the old spellings
of what [`MATH`](../sig/MATH.md), [`CHAR`](../sig/CHAR.md) and [`STRING`](../sig/STRING.md) now offer.

> **Limitation** `SML90/is-history`. The page that defined this signature is no
> longer among the specification's pages; it is transcribed from MLton's
> library, which follows it, in the order the page had.

## Interface

<pre>
signature SML90 =
sig
  type <a href="#type-instream">instream</a>

  type <a href="#type-outstream">outstream</a>

  exception <a href="#exn-abs">Abs</a>

  exception <a href="#exn-quot">Quot</a>

  exception <a href="#exn-prod">Prod</a>

  exception <a href="#exn-neg">Neg</a>

  exception <a href="#exn-sum">Sum</a>

  exception <a href="#exn-diff">Diff</a>

  exception <a href="#exn-floor">Floor</a>

  exception <a href="#exn-exp">Exp</a>

  exception <a href="#exn-sqrt">Sqrt</a>

  exception <a href="#exn-ln">Ln</a>

  exception <a href="#exn-ord">Ord</a>

  exception <a href="#exn-mod">Mod</a>

  exception <a href="#exn-io">Io</a> of string

  exception <a href="#exn-interrupt">Interrupt</a>

  val <a href="#val-sqrt">sqrt</a> : real -&gt; real

  val <a href="#val-exp">exp</a> : real -&gt; real

  val <a href="#val-ln">ln</a> : real -&gt; real

  val <a href="#val-sin">sin</a> : real -&gt; real

  val <a href="#val-cos">cos</a> : real -&gt; real

  val <a href="#val-arctan">arctan</a> : real -&gt; real

  val <a href="#val-ord">ord</a> : string -&gt; int

  val <a href="#val-chr">chr</a> : int -&gt; string

  val <a href="#val-explode">explode</a> : string -&gt; string list

  val <a href="#val-implode">implode</a> : string list -&gt; string

  val <a href="#val-lookahead">lookahead</a> : instream -&gt; string

  val <a href="#val-std_in">std_in</a> : instream

  val <a href="#val-std_out">std_out</a> : outstream

  val <a href="#val-open_in">open_in</a> : string -&gt; instream

  val <a href="#val-open_out">open_out</a> : string -&gt; outstream

  val <a href="#val-close_in">close_in</a> : instream -&gt; unit

  val <a href="#val-close_out">close_out</a> : outstream -&gt; unit

  val <a href="#val-input">input</a> : instream * int -&gt; string

  val <a href="#val-output">output</a> : outstream * string -&gt; unit

  val <a href="#val-end_of_stream">end_of_stream</a> : instream -&gt; bool
end
</pre>

### <a name="type-instream"></a>`instream`

```sml
type instream
```

The type of an input stream, as the old library had it.

### <a name="type-outstream"></a>`outstream`

```sml
type outstream
```

The type of an output stream, as the old library had it.

### <a name="exn-abs"></a>`Abs`

```sml
exception Abs
```

Raised where `abs` of the least integer would overflow.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `is-Overflow`

</details>

### <a name="exn-quot"></a>`Quot`

```sml
exception Quot
```

Raised by division that overflows; division by zero raises [`Mod`](#exn-mod).

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `handled`

</details>

### <a name="exn-prod"></a>`Prod`

```sml
exception Prod
```

Raised by multiplication that overflows.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `is-Overflow`

</details>

### <a name="exn-neg"></a>`Neg`

```sml
exception Neg
```

Raised by negation that overflows.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `is-Overflow`

</details>

### <a name="exn-sum"></a>`Sum`

```sml
exception Sum
```

Raised by addition that overflows.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `is-Overflow`

</details>

### <a name="exn-diff"></a>`Diff`

```sml
exception Diff
```

Raised by subtraction that overflows.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `is-Overflow`

</details>

### <a name="exn-floor"></a>`Floor`

```sml
exception Floor
```

Raised by [`floor`](../sig/REAL.md#val-floor) of a number no integer can hold.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `is-Overflow`

</details>

### <a name="exn-exp"></a>`Exp`

```sml
exception Exp
```

Raised by [`exp`](#val-exp) when the result is too large.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `is-Overflow`

</details>

### <a name="exn-sqrt"></a>`Sqrt`

```sml
exception Sqrt
```

Raised by [`sqrt`](#val-sqrt) of a negative number.

> **Reading** `SML90.Sqrt/is-its-own-exception`. [`Sqrt`](#exn-sqrt), [`Ln`](#exn-ln) and [`Ord`](#exn-ord) are
> exceptions of their own, as MLton and SML/NJ have them. Poly/ML makes
> all three [`Overflow`](../sig/GENERAL.md#exn-overflow), which loses what went wrong.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; another reading of the specification: Sqrt, Ln and Ord are Overflow; the test takes MLton's and SML/NJ's reading, exceptions of their own

</details>

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `new`

</details>

### <a name="exn-ln"></a>`Ln`

```sml
exception Ln
```

Raised by [`ln`](#val-ln) of a number that is not positive.

> **Reading** `SML90.Ln/is-its-own-exception`. As [`Sqrt`](#exn-sqrt): an exception of its
> own, not [`Overflow`](../sig/GENERAL.md#exn-overflow).

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; another reading of the specification: as SML90.Sqrt/new

</details>

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `new`

</details>

### <a name="exn-ord"></a>`Ord`

```sml
exception Ord
```

Raised by [`ord`](#val-ord) of the empty string.

> **Reading** `SML90.Ord/is-its-own-exception`. As [`Sqrt`](#exn-sqrt): an exception of
> its own, not [`Overflow`](../sig/GENERAL.md#exn-overflow) and not [`Subscript`](../sig/GENERAL.md#exn-subscript).

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `new`

</details>

### <a name="exn-mod"></a>`Mod`

```sml
exception Mod
```

Raised by the remainder of a division by zero.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `is-Div`

</details>

### <a name="exn-io"></a>`Io`

```sml
exception Io of string
```

Raised when an I/O operation fails, carrying the message alone.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `carries-a-string`

</details>

### <a name="exn-interrupt"></a>`Interrupt`

```sml
exception Interrupt
```

Meant for a program that is interrupted.

> **Limitation** `SML90.Interrupt/never-raised`. It is declared and nothing
> raises it: the VM handles no signal, so an interrupt ends the program.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `new`

</details>

### <a name="val-sqrt"></a>`sqrt`

```sml
val sqrt : real -> real
```

`sqrt x` is the square root of `x`.

**Raises** [`Sqrt`](#exn-sqrt) if `x` is negative.

<details><summary>Tests (3)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `4` &middot; `zero` &middot; `Sqrt-negative` (raises)

</details>

### <a name="val-exp"></a>`exp`

```sml
val exp : real -> real
```

`exp x` is `e` to the power `x`.

**Raises** [`Exp`](#exn-exp) if the result is too large.

<details><summary>Tests (3)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `zero` &middot; `underflow-is-zero` &middot; `Exp-overflow` (raises)

</details>

### <a name="val-ln"></a>`ln`

```sml
val ln : real -> real
```

`ln x` is the natural logarithm of `x`.

**Raises** [`Ln`](#exn-ln) if `x` is not positive.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; ln 0.0 is \~inf instead of raising Ln

</details>

<details><summary>Tests (4)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `one` &middot; `e` &middot; `Ln-zero` (raises) &middot; `Ln-negative` (raises)

</details>

### <a name="val-sin"></a>`sin`

```sml
val sin : real -> real
```

`sin x` is the sine of `x` radians.

<details><summary>Tests (2)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `zero` &middot; `half-pi`

</details>

### <a name="val-cos"></a>`cos`

```sml
val cos : real -> real
```

`cos x` is the cosine of `x` radians.

<details><summary>Tests (2)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `zero` &middot; `pi`

</details>

### <a name="val-arctan"></a>`arctan`

```sml
val arctan : real -> real
```

`arctan x` is the angle in radians whose tangent is `x`, between `~pi/2` and `pi/2`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; Math.atan 0.0 is \~0.0

</details>

<details><summary>Tests (2)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `zero` &middot; `one`

</details>

### <a name="val-ord"></a>`ord`

```sml
val ord : string -> int
```

`ord s` is the code of the first character of `s`.

**Raises** [`Ord`](#exn-ord) if `s` is empty.

**Example** `ord "a" = 97`

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; ord "" raises Subscript, not Ord

</details>

<details><summary>Tests (3)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `first-character` &middot; `255` &middot; `Ord-empty` (raises)

</details>

### <a name="val-chr"></a>`chr`

```sml
val chr : int -> string
```

`chr n` is the one-character string whose character has the code `n`.

**Raises** [`Chr`](../sig/GENERAL.md#exn-chr) if `n` is no character's code.

**Example** `chr 97 = "a"`

<details><summary>Tests (4)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `97` &middot; `zero` &middot; `Chr-256` (raises Chr) &middot; `Chr-negative` (raises Chr)

</details>

### <a name="val-explode"></a>`explode`

```sml
val explode : string -> string list
```

`explode s` is the characters of `s`, each as a string of its own.

The [`explode`](#val-explode) of [`STRING`](../sig/STRING.md) gives a list of characters; this is the older
one.

**Example** `explode "ab" = ["a", "b"]`

<details><summary>Tests (2)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `letters` &middot; `empty`

</details>

### <a name="val-implode"></a>`implode`

```sml
val implode : string list -> string
```

`implode l` is the strings of `l`, one after another.

**Example** `implode ["a", "bc"] = "abc"`

<details><summary>Tests (2)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `strings` &middot; `empty`

</details>

### <a name="val-lookahead"></a>`lookahead`

```sml
val lookahead : instream -> string
```

`lookahead f` is the next character of `f` as a string, without removing it, or the empty string at the end.

**Raises** [`Io`](#exn-io) if the stream cannot be read.

> **Reading** `SML90.lookahead/closed-stream-is-empty`. A stream that has been
> closed is at its end, so it gives the empty string as well, and not [`Io`](#exn-io).

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; lookahead raises Io at the end of the stream instead of returning ""

</details>

<details><summary>Tests (2)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `does-not-consume` &middot; `empty-file`

</details>

### <a name="val-std_in"></a>`std_in`

```sml
val std_in : instream
```

The standard input of the program.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `is-open`

</details>

### <a name="val-std_out"></a>`std_out`

```sml
val std_out : outstream
```

The standard output of the program.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `writes`

</details>

### <a name="val-open_in"></a>`open_in`

```sml
val open_in : string -> instream
```

`open_in name` is a stream reading the file `name`.

**Raises** [`Io`](#exn-io) if the file cannot be opened.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `Io-missing` (raises)

</details>

### <a name="val-open_out"></a>`open_out`

```sml
val open_out : string -> outstream
```

`open_out name` is a stream writing the file `name`, which it empties or creates.

**Raises** [`Io`](#exn-io) if the file cannot be opened.

<details><summary>Tests (2)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `truncates` &middot; `Io-bad-directory` (raises)

</details>

### <a name="val-close_in"></a>`close_in`

```sml
val close_in : instream -> unit
```

`close_in f` closes the input stream `f`.

<details><summary>Tests (2)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `then-input-is-empty` &middot; `twice`

</details>

### <a name="val-close_out"></a>`close_out`

```sml
val close_out : outstream -> unit
```

`close_out f` closes the output stream `f`.

<details><summary>Tests (1)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `twice`

</details>

### <a name="val-input"></a>`input`

```sml
val input : instream * int -> string
```

`input (f, n)` is at most `n` characters read from `f`, and fewer at the end of the stream.

**Raises** [`Io`](#exn-io) if the stream cannot be read.

<details><summary>Tests (2)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `at-most-n` &middot; `zero`

</details>

### <a name="val-output"></a>`output`

```sml
val output : outstream * string -> unit
```

`output (f, s)` writes `s` to `f`.

**Raises** [`Io`](#exn-io) if the stream cannot be written.

<details><summary>Tests (2)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `then-input` &middot; `Io-closed` (raises)

</details>

### <a name="val-end_of_stream"></a>`end_of_stream`

```sml
val end_of_stream : instream -> bool
```

`end_of_stream f` is `true` when nothing is left to read in `f`.

<details><summary>Tests (2)</summary>

For `SML90`, in [tests/basis/sml90.sml](../../../../tests/basis/sml90.sml): `before-and-after` &middot; `closed`

</details>

## See also

[`MATH`](../sig/MATH.md), [`STRING`](../sig/STRING.md), [`TEXT_IO`](../sig/TEXT_IO.md), [`GENERAL`](../sig/GENERAL.md)

---

<sub>Generated by runedoc from lib/basis/sig\_sml90.sml; do not edit.</sub>

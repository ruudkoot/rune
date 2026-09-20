# signature IMPERATIVE_IO

[The Standard ML Basis Library](../README.md) &rsaquo; Input and output &rsaquo; **IMPERATIVE_IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 2 |
| Documentation | 25 of 25 entries documented |
| Tests | 244 checks of 24 entries |
| Source | [lib/basis/sig\_imperative\_io.sml](../../../../lib/basis/sig_imperative_io.sml) |

## Synopsis

```sml
signature IMPERATIVE_IO
structure BinIO : IMPERATIVE_IO
structure TextIO : IMPERATIVE_IO
```

| Implementation |  | Source |
| --- | --- | --- |
| `BinIO` | BinIO: the imperative binary streams (signature BIN\_IO). | [lib/basis/binio.sml](../../../../lib/basis/binio.sml) |
| `TextIO` | TextIO: the imperative text streams (signature TEXT\_IO). | [lib/basis/textio.sml](../../../../lib/basis/textio.sml) |

Streams that remember where they are: a cell holding a functional stream,
which every operation replaces by what it left.

This is the layer a program normally uses. `input f` gives elements, not
elements and a stream, because `f` itself has moved on. [`TEXT_IO`](../sig/TEXT_IO.md) and
[`BIN_IO`](../sig/BIN_IO.md) are this signature with the element type fixed and the ways of
opening a file added.

[`StreamIO`](#str-streamio) is the functional stream underneath, and the stream in the cell
can be taken out and put back: [`getInstream`](#val-getinstream) gives the position the
imperative stream is at, and [`setInstream`](#val-setinstream) moves it. That is how a program
backtracks over an imperative stream -- keep what [`getInstream`](#val-getinstream) gave, read
on, and put it back to read the same elements again.

The end of a stream is not a state: an imperative stream sits at a place
in the chain of its functional stream, and a file that grows delivers what
it gained, as [`STREAM_IO`](../sig/STREAM_IO.md) describes.

> **Deviation** `IMPERATIVE_IO/functor-not-sealed`. The functor
> [`ImperativeIO`](../fun/ImperativeIO.md) is not ascribed this signature, because the library
> declares the signature after the structures that would need it; its result
> matches it, which `tests/basis` checks.

## Contents

[Reading](#reading) &middot;
[Writing](#writing) &middot;
[The stream underneath](#the-stream-underneath)

## Interface

<pre>
signature IMPERATIVE_IO =
sig
  structure <a href="#str-streamio">StreamIO</a> : STREAM_IO

  type <a href="#type-vector">vector</a> = StreamIO.vector

  type <a href="#type-elem">elem</a> = StreamIO.elem

  type <a href="#type-instream">instream</a>

  type <a href="#type-outstream">outstream</a>

  val <a href="#val-input">input</a> : instream -&gt; vector

  val <a href="#val-input1">input1</a> : instream -&gt; elem option

  val <a href="#val-inputn">inputN</a> : instream * int -&gt; vector

  val <a href="#val-inputall">inputAll</a> : instream -&gt; vector

  val <a href="#val-caninput">canInput</a> : instream * int -&gt; int option

  val <a href="#val-lookahead">lookahead</a> : instream -&gt; elem option

  val <a href="#val-closein">closeIn</a> : instream -&gt; unit

  val <a href="#val-endofstream">endOfStream</a> : instream -&gt; bool

  val <a href="#val-output">output</a> : outstream * vector -&gt; unit

  val <a href="#val-output1">output1</a> : outstream * elem -&gt; unit

  val <a href="#val-flushout">flushOut</a> : outstream -&gt; unit

  val <a href="#val-closeout">closeOut</a> : outstream -&gt; unit

  val <a href="#val-mkinstream">mkInstream</a> : StreamIO.instream -&gt; instream

  val <a href="#val-getinstream">getInstream</a> : instream -&gt; StreamIO.instream

  val <a href="#val-setinstream">setInstream</a> : instream * StreamIO.instream -&gt; unit

  val <a href="#val-mkoutstream">mkOutstream</a> : StreamIO.outstream -&gt; outstream

  val <a href="#val-getoutstream">getOutstream</a> : outstream -&gt; StreamIO.outstream

  val <a href="#val-setoutstream">setOutstream</a> : outstream * StreamIO.outstream -&gt; unit

  val <a href="#val-getposout">getPosOut</a> : outstream -&gt; StreamIO.out_pos

  val <a href="#val-setposout">setPosOut</a> : outstream * StreamIO.out_pos -&gt; unit
end
</pre>

### <a name="str-streamio"></a>`StreamIO`

```sml
structure StreamIO : STREAM_IO
```

A substructure: its members are described on the page of [`STREAM_IO`](../sig/STREAM_IO.md).

The functional streams these are built on.

### <a name="type-vector"></a>`vector`

```sml
type vector = StreamIO.vector
```

The type of vectors of elements, the one of [`StreamIO`](#str-streamio).

<details><summary>Tests (2)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `is-string`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `is-Word8Vector.vector`

</details>

### <a name="type-elem"></a>`elem`

```sml
type elem = StreamIO.elem
```

The type of the elements, the one of [`StreamIO`](#str-streamio).

<details><summary>Tests (2)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `is-char`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `is-Word8.word`

</details>

### <a name="type-instream"></a>`instream`

```sml
type instream
```

The type of the input streams.

> **Deviation** `IMPERATIVE_IO.instream/admits-equality`. The specification
> leaves the type abstract, and a program should not rely on more. In Rune
> it is a datatype holding a `ref`, so `=` may be written between two
> instreams and is true exactly when they are the same stream; the same
> holds for [`outstream`](#type-outstream).

<details><summary>Tests (2)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `two-on-one-file`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `two-on-one-file`

</details>

### <a name="type-outstream"></a>`outstream`

```sml
type outstream
```

The type of the output streams.

<details><summary>Tests (2)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `two-files`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `two-files`

</details>

## Reading

### <a name="val-input"></a>`input`

```sml
val input : instream -> vector
```

`input f` is the elements that are there without waiting for more, and moves `f` past them.

At an end of stream it is the empty vector and `f` moves past that end
of stream.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again

</details>

<details><summary>Tests (15)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `at-least-one-character` &middot; `empty-file` &middot; `pieces-make-the-file` &middot; `empty-again-at-end-of-stream` &middot; `large` &middot; `after-inputLine` &middot; `empty-after-input-and-inputAll` &middot; `closed-stream`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `at-least-one-byte` &middot; `empty-file` &middot; `pieces-make-the-file` &middot; `empty-again-at-end-of-stream` &middot; `large` &middot; `empty-after-input-and-inputAll` &middot; `closed-stream`

</details>

### <a name="val-input1"></a>`input1`

```sml
val input1 : instream -> elem option
```

`input1 f` is `SOME` of the next element, or `NONE` at an end of stream.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails.

> **Reading** `IMPERATIVE_IO.input1/passes-the-end-of-stream`. An [`input1`](#val-input1)
> that returns `NONE` leaves the stream positioned after the end of stream
> it found, as `StreamIO.inputN (f, 1)` does, so a following [`input1`](#val-input1)
> delivers what the source has gained since.

<details><summary>Other implementations (3)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **MLton** &mdash; the input1 that returns NONE leaves the stream before the end-of-stream; a second one consumes it
- **SML/NJ, SML/NJ 110.99.9** &mdash; input1 never moves past an end-of-stream

</details>

<details><summary>Tests (21)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `characters-then-NONE` &middot; `empty-file` &middot; `NONE-again-at-end-of-stream` &middot; `newline-NUL-and-high-characters` &middot; `removes-one-character` &middot; `NONE-after-input1-and-inputAll` &middot; `then-inputLine` &middot; `every-character` &middot; `large` &middot; `closed-stream` &middot; `file-grows-after-end-of-stream`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `bytes-then-NONE` &middot; `empty-file` &middot; `NONE-again-at-end-of-stream` &middot; `NUL-line-ends-and-control-Z` &middot; `every-byte` &middot; `removes-one-byte` &middot; `large` &middot; `closed-stream` &middot; `file-grows-after-end-of-stream`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `passes-an-end-of-stream`

</details>

### <a name="val-inputn"></a>`inputN`

```sml
val inputN : instream * int -> vector
```

`inputN (f, n)` is `n` elements, or all there are before the next end of stream.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0`, or if the vector to be returned would be too
long.

> **Reading** `IMPERATIVE_IO.inputN/Size-is-about-the-result`. The
> specification writes the condition two ways; [`Size`](../sig/GENERAL.md#exn-size) is raised when the
> number of elements to be returned exceeds the greatest length of a
> vector, as [`STREAM_IO`](../sig/STREAM_IO.md) puts it, not when `n` does.

<details><summary>Other implementations (2)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **SML/NJ** &mdash; inputN (strm, \~1) raises Subscript, not Size

</details>

<details><summary>Tests (30)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `pieces-then-empty` &middot; `exactly-the-rest` &middot; `more-than-there-is` &middot; `one` &middot; `zero-reads-nothing` &middot; `empty-after-inputN-and-inputAll` &middot; `empty-file` &middot; `does-not-stop-at-a-newline` &middot; `Size-negative` (raises Size) &middot; `Size-negative-at-end-of-stream` (raises Size) &middot; `negative-reads-nothing` &middot; `more-than-maxSize-of-a-short-file` &middot; `large` &middot; `closed-stream` &middot; `random-mix-of-operations-*` &middot; `random-mix-of-operations-large-*`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `pieces-then-empty` &middot; `exactly-the-rest` &middot; `more-than-there-is` &middot; `zero-reads-nothing` &middot; `empty-file` &middot; `NUL-line-ends-and-control-Z` &middot; `Size-negative` (raises Size) &middot; `Size-negative-at-end-of-stream` (raises Size) &middot; `negative-reads-nothing` &middot; `empty-after-inputN-and-inputAll` &middot; `large` &middot; `closed-stream` &middot; `random-mix-of-operations-*` &middot; `random-mix-of-operations-large-*`

</details>

### <a name="val-inputall"></a>`inputAll`

```sml
val inputAll : instream -> vector
```

`inputAll f` is everything up to the next end of stream.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails.

> **Reading** `IMPERATIVE_IO.inputAll/file-grows`. Several ends of stream are
> real for a file: a read after one delivers what was appended since, so a
> second [`inputAll`](#val-inputall) need not be empty.

<details><summary>Other implementations (3)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **Poly/ML** &mdash; another reading of the specification: inputAll after an end-of-stream does not read what the file has gained; the test takes the reading of MLton and SML/NJ
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it: the example of stream-io.html ("abc", end-of-stream, "defg") gives "abc" and then "" for good

</details>

<details><summary>Tests (23)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `whole-file` &middot; `empty-file` &middot; `again-at-end-of-stream` &middot; `rest-after-inputLine` &middot; `empty-after-inputLine-and-inputAll` &middot; `every-character` &middot; `large` &middot; `no-final-newline-added` &middot; `file-grows-after-end-of-stream` &middot; `empty-after-input1-and-inputAll` &middot; `empty-after-lookahead-and-inputAll` &middot; `empty-after-endOfStream-and-inputAll` &middot; `empty-after-canInput-and-inputAll`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `written-as-text` &middot; `whole-file` &middot; `empty-file` &middot; `again-at-end-of-stream` &middot; `every-byte` &middot; `large` &middot; `file-grows-after-end-of-stream` &middot; `empty-after-input1-and-inputAll` &middot; `empty-after-lookahead-and-inputAll`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `up-to-each-end-of-stream`

</details>

### <a name="val-caninput"></a>`canInput`

```sml
val canInput : instream * int -> int option
```

`canInput (f, n)` is how many of `n` elements, at most, can be read without waiting, or `NONE`.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0`.

<details><summary>Tests (18)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `characters-available` &middot; `one` &middot; `more-than-there-is` &middot; `empty-file` &middot; `at-end-of-stream` &middot; `removes-nothing` &middot; `zero` &middot; `Size-negative` (raises Size) &middot; `closed-stream`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `bytes-available` &middot; `one` &middot; `more-than-there-is` &middot; `empty-file` &middot; `at-end-of-stream` &middot; `removes-nothing` &middot; `zero` &middot; `Size-negative` (raises Size) &middot; `closed-stream`

</details>

### <a name="val-lookahead"></a>`lookahead`

```sml
val lookahead : instream -> elem option
```

`lookahead f` is `SOME` of the next element without removing it, or `NONE` at an end of stream.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails.

> **Reading** `IMPERATIVE_IO.lookahead/removes-nothing`. It removes nothing
> at all, an end of stream included: at one it gives `NONE` and leaves the
> stream before that end of stream, which a following [`input`](#val-input) then
> consumes.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again

</details>

<details><summary>Tests (15)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `does-not-remove` &middot; `then-inputAll` &middot; `NONE-after-lookahead-and-inputAll` &middot; `then-inputLine` &middot; `empty-file` &middot; `after-each-line` &middot; `newline-and-NUL` &middot; `closed-stream`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `does-not-remove` &middot; `then-inputAll` &middot; `empty-file` &middot; `NUL-and-255` &middot; `at-end-of-stream` &middot; `closed-stream`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `does-not-pass-an-end-of-stream`

</details>

### <a name="val-closein"></a>`closeIn`

```sml
val closeIn : instream -> unit
```

`closeIn f` closes the stream and its reader.

> **Reading** `IMPERATIVE_IO.closeIn/drops-what-was-read-ahead`. Closing
> "must also replace the functional stream with an empty stream": what the
> stream had read ahead of the program is dropped, so nothing can be read
> after [`closeIn`](#val-closein). Closing twice is allowed.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails while closing.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; characters buffered before closeIn are still read after it

</details>

<details><summary>Tests (14)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `twice` &middot; `then-inputAll-is-empty` &middot; `then-inputLine-is-NONE` &middot; `then-inputAll-again` &middot; `unread-characters-are-dropped` &middot; `unread-lines-are-dropped` &middot; `other-streams-stay-open` &middot; `file-can-be-rewritten`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `twice` &middot; `then-inputAll-is-empty` &middot; `then-inputAll-again` &middot; `other-streams-stay-open`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `shared-functional-stream` &middot; `closes-the-reader`

</details>

### <a name="val-endofstream"></a>`endOfStream`

```sml
val endOfStream : instream -> bool
```

`endOfStream f` is `true` when nothing is left before the next end of stream.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails.

> **Reading** `IMPERATIVE_IO.endOfStream/does-not-consume`. It does not
> consume the end of stream it finds: it stays `true` until a read does,
> that read gives nothing, and only afterwards is what the source gained
> seen.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again

</details>

<details><summary>Tests (16)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `empty-file` &middot; `characters-available` &middot; `removes-nothing` &middot; `true-after-endOfStream-and-inputAll` &middot; `around-each-line` &middot; `after-inputAll` &middot; `true-then-inputLine-is-NONE` &middot; `closed-stream` &middot; `file-grows-after-end-of-stream`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `empty-file` &middot; `bytes-available` &middot; `removes-nothing` &middot; `true-after-endOfStream-and-inputAll` &middot; `closed-stream` &middot; `file-grows-after-end-of-stream`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `more-after-an-end-of-stream`

</details>

## Writing

### <a name="val-output"></a>`output`

```sml
val output : outstream * vector -> unit
```

`output (f, v)` writes the elements of `v`.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the writer fails or the stream is closed.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again

</details>

<details><summary>Tests (29)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `in-order` &middot; `empty-string` &middot; `every-character` &middot; `no-line-end-translation` &middot; `large` &middot; `large-size` &middot; `Io-closed-stream` (raises) &middot; `Io-closed-stream-cause` &middot; `Io-closed-stream-function` &middot; `Io-closed-stream-name` &middot; `closed-stream-writes-nothing` &middot; `random-chunks-*` &middot; `random-chunks-large`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `in-order` &middot; `empty-vector` &middot; `every-byte` &middot; `every-byte-size` &middot; `NUL-line-ends-and-control-Z` &middot; `large` &middot; `large-size` &middot; `read-back-as-text` &middot; `Io-closed-stream` (raises) &middot; `Io-closed-stream-cause` &middot; `Io-closed-stream-function` &middot; `Io-closed-stream-name` &middot; `closed-stream-writes-nothing` &middot; `random-chunks-*` &middot; `random-chunks-large`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `shared-stream`

</details>

### <a name="val-output1"></a>`output1`

```sml
val output1 : outstream * elem -> unit
```

`output1 (f, x)` writes the single element `x`.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the writer fails or the stream is closed.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; output1 on a closed stream raises Io with function "output"

</details>

<details><summary>Tests (17)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `in-order` &middot; `mixed-with-output` &middot; `every-character` &middot; `Io-closed-stream` (raises) &middot; `Io-closed-stream-cause` &middot; `Io-closed-stream-function` &middot; `Io-closed-stream-name` &middot; `large`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `in-order` &middot; `mixed-with-output` &middot; `every-byte` &middot; `large` &middot; `appends` &middot; `Io-closed-stream` (raises) &middot; `Io-closed-stream-cause` &middot; `Io-closed-stream-function` &middot; `Io-closed-stream-name`

</details>

### <a name="val-flushout"></a>`flushOut`

```sml
val flushOut : outstream -> unit
```

`flushOut f` hands what the stream holds to its writer.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the writer fails.

<details><summary>Tests (8)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `makes-output-visible` &middot; `nothing-to-flush` &middot; `twice` &middot; `closed-stream-is-a-no-op`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `makes-output-visible` &middot; `nothing-to-flush` &middot; `closed-stream-is-a-no-op`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `flushes-the-stream`

</details>

### <a name="val-closeout"></a>`closeOut`

```sml
val closeOut : outstream -> unit
```

`closeOut f` flushes the stream and closes it and its writer.

Closing twice is allowed.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the flush or the writer fails.

<details><summary>Tests (7)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `flushes` &middot; `twice` &middot; `other-streams-stay-open`

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `flushes` &middot; `twice`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `shared-stream` (raises) &middot; `flushes-and-closes`

</details>

## The stream underneath

### <a name="val-mkinstream"></a>`mkInstream`

```sml
val mkInstream : StreamIO.instream -> instream
```

`mkInstream s` is an imperative stream holding the functional stream `s`.

<details><summary>Tests (3)</summary>

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `reads-the-functional-stream` &middot; `from-a-stream-part-read` &middot; `does-not-change-the-functional-stream`

</details>

### <a name="val-getinstream"></a>`getInstream`

```sml
val getInstream : instream -> StreamIO.instream
```

`getInstream f` is the functional stream that `f` is at.

<details><summary>Tests (4)</summary>

For `TextIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `current-version` &middot; `fresh` &middot; `input-from-it-is-read-again`

</details>

### <a name="val-setinstream"></a>`setInstream`

```sml
val setInstream : instream * StreamIO.instream -> unit
```

`setInstream (f, s)` makes `f` continue at `s`.

<details><summary>Tests (3)</summary>

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `redirects` &middot; `after-getInstream-and-input` &middot; `reread`

</details>

### <a name="val-mkoutstream"></a>`mkOutstream`

```sml
val mkOutstream : StreamIO.outstream -> outstream
```

`mkOutstream s` is an imperative stream holding the functional stream `s`.

<details><summary>Tests (2)</summary>

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `writes-to-the-stream` &middot; `keeps-the-buffer-mode`

</details>

### <a name="val-getoutstream"></a>`getOutstream`

```sml
val getOutstream : outstream -> StreamIO.outstream
```

`getOutstream f` flushes `f` and is the functional stream underneath.

<details><summary>Other implementations (1)</summary>

- **MLton, SML/NJ 110.99.9, Poly/ML** &mdash; getOutstream and setOutstream do not flush the stream ("flushes strm and returns the underlying StreamIO output stream", "flushes the stream underlying strm, and then assigns")

</details>

<details><summary>Tests (2)</summary>

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `the-same-stream` &middot; `flushes`

</details>

### <a name="val-setoutstream"></a>`setOutstream`

```sml
val setOutstream : outstream * StreamIO.outstream -> unit
```

`setOutstream (f, s)` flushes what `f` holds and then makes it write to `s`.

<details><summary>Other implementations (1)</summary>

- **MLton, SML/NJ 110.99.9, Poly/ML** &mdash; getOutstream and setOutstream do not flush the stream ("flushes strm and returns the underlying StreamIO output stream", "flushes the stream underlying strm, and then assigns")

</details>

<details><summary>Tests (3)</summary>

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `redirects` &middot; `flushes-the-old-stream` &middot; `save-and-restore`

</details>

### <a name="val-getposout"></a>`getPosOut`

```sml
val getPosOut : outstream -> StreamIO.out_pos
```

`getPosOut f` flushes `f` and is the position it is now at.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the writer has no positions, or the flush fails.

<details><summary>Tests (3)</summary>

For `TextIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

For `BinIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `offset`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`, `BinIO`: `Io-without-positions` (raises)

</details>

### <a name="val-setposout"></a>`setPosOut`

```sml
val setPosOut : outstream * StreamIO.out_pos -> unit
```

`setPosOut (f, opos)` flushes `f` and moves it to the position `opos`.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the writer has no positions, or the flush fails.

<details><summary>Other implementations (1)</summary>

- **SML/NJ 110.99.9** &mdash; setPosOut neither flushes nor moves the writer: output goes on at the end

</details>

<details><summary>Tests (3)</summary>

For `TextIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file-overwrites`

For `BinIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `overwrites` &middot; `file-overwrites`

</details>

## See also

[`STREAM_IO`](../sig/STREAM_IO.md), [`TEXT_IO`](../sig/TEXT_IO.md), [`BIN_IO`](../sig/BIN_IO.md), [`PRIM_IO`](../sig/PRIM_IO.md)

---

<sub>Generated by runedoc from lib/basis/sig\_imperative\_io.sml; do not edit.</sub>

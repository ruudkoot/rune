# signature TEXT_IO

[The Standard ML Basis Library](../README.md) &rsaquo; Input and output &rsaquo; **TEXT_IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 36 of 36 entries documented |
| Tests | 234 checks of 35 entries |
| Source | [lib/basis/sig\_text\_io.sml](../../../../lib/basis/sig_text_io.sml) |

## Synopsis

```sml
signature TEXT_IO
structure TextIO : TEXT_IO
```

| Implementation |  | Source |
| --- | --- | --- |
| [`TextIO`](../str/TextIO.md) | TextIO: the imperative text streams (signature TEXT\_IO). | [lib/basis/textio.sml](../../../../lib/basis/textio.sml) |

Text files and the standard streams: the imperative streams of characters,
with the ways of opening a file.

This is the signature a program reaches for first. It is [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md)
over characters, so everything written there holds; what it adds is
[`openIn`](#val-openin), [`openOut`](#val-openout), [`openAppend`](#val-openappend) and [`openString`](#val-openstring), the three standard
streams, [`inputLine`](#val-inputline), [`print`](#val-print) and [`scanStream`](#val-scanstream).

A text file holds characters; on the systems Rune runs on nothing is
translated, so what [`output`](#val-output) writes is what [`inputAll`](#val-inputall) reads back, newline
for newline. [`BIN_IO`](../sig/BIN_IO.md) is the same for bytes.

[`StreamIO`](#str-streamio) is the functional stream underneath, reached through
[`getInstream`](#val-getinstream) and [`getOutstream`](#val-getoutstream); [`TEXT_STREAM_IO`](../sig/TEXT_STREAM_IO.md) describes it.

> **Erratum** `TEXT_IO/include-rewritten`. The page writes `include IMPERATIVE_IO` and then specifies [`StreamIO`](#str-streamio) again as a
> [`TEXT_STREAM_IO`](../sig/TEXT_STREAM_IO.md), which is not valid SML. What it means is that a
> structure matching [`TEXT_IO`](TEXT_IO.md) also matches [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md) and has a
> [`StreamIO`](#str-streamio) matching [`TEXT_STREAM_IO`](../sig/TEXT_STREAM_IO.md); that is what stands here, with the
> substructure first, then the members of [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md) in full, then the
> ones of [`TEXT_IO`](TEXT_IO.md).

> **Deviation** `TEXT_IO/WideTextIO-not-matched`. The optional [`WideTextIO`](../str/WideTextIO.md) is
> not matched against this signature, because the types here are written
> `string` and `char`; the suite checks that its readers and writers match
> [`PRIM_IO`](../sig/PRIM_IO.md), and that its vectors are the strings of [`WideString`](../str/WideString.md) and its
> elements the characters of [`WideChar`](../str/WideChar.md), instead.

## Contents

[The members of IMPERATIVE\_IO](#the-members-of-imperativeio) &middot;
[The members of TEXT\_IO](#the-members-of-textio)

## Interface

<pre>
signature TEXT_IO =
sig
  structure <a href="#str-streamio">StreamIO</a> : TEXT_STREAM_IO
    where type reader = TextPrimIO.reader
    where type writer = TextPrimIO.writer
    where type pos = TextPrimIO.pos
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
  val <a href="#val-inputline">inputLine</a> : instream -&gt; string option
  val <a href="#val-outputsubstr">outputSubstr</a> : outstream * substring -&gt; unit
  val <a href="#val-openin">openIn</a> : string -&gt; instream
  val <a href="#val-openout">openOut</a> : string -&gt; outstream
  val <a href="#val-openappend">openAppend</a> : string -&gt; outstream
  val <a href="#val-openstring">openString</a> : string -&gt; instream
  val <a href="#val-stdin">stdIn</a> : instream
  val <a href="#val-stdout">stdOut</a> : outstream
  val <a href="#val-stderr">stdErr</a> : outstream
  val <a href="#val-print">print</a> : string -&gt; unit
  val <a href="#val-scanstream">scanStream</a> : ((Char.char, StreamIO.instream) StringCvt.reader
                    -&gt; ('a, StreamIO.instream) StringCvt.reader)
                   -&gt; instream -&gt; 'a option
end
</pre>

### <a name="str-streamio"></a>`StreamIO`

```sml
structure StreamIO : TEXT_STREAM_IO
  where type reader = TextPrimIO.reader
  where type writer = TextPrimIO.writer
  where type pos = TextPrimIO.pos
```

A substructure: its members are described on the page of [`TEXT_STREAM_IO`](../sig/TEXT_STREAM_IO.md).

The functional text streams underneath, with the readers and writers of [`TextPrimIO`](../str/TextPrimIO.md).

## The members of IMPERATIVE\_IO

### <a name="type-vector"></a>`vector`

```sml
type vector = StreamIO.vector
```

The type of what is read and written: `string`.

<details><summary>Tests (1)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `is-string`

</details>

### <a name="type-elem"></a>`elem`

```sml
type elem = StreamIO.elem
```

The type of the elements: `char`.

<details><summary>Tests (1)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `is-char`

</details>

### <a name="type-instream"></a>`instream`

```sml
type instream
```

The type of the input streams.

<details><summary>Tests (2)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `equal-when-the-same-stream` &middot; `two-on-one-file`

</details>

### <a name="type-outstream"></a>`outstream`

```sml
type outstream
```

The type of the output streams.

<details><summary>Tests (1)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `two-files`

</details>

### <a name="val-input"></a>`input`

```sml
val input : instream -> vector
```

`input f` is the characters that are there without waiting, and moves `f` past them.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again

</details>

<details><summary>Tests (8)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `at-least-one-character` &middot; `empty-file` &middot; `pieces-make-the-file` &middot; `empty-again-at-end-of-stream` &middot; `large` &middot; `after-inputLine` &middot; `empty-after-input-and-inputAll` &middot; `closed-stream`

</details>

### <a name="val-input1"></a>`input1`

```sml
val input1 : instream -> elem option
```

`input1 f` is `SOME` of the next character, or `NONE` at an end of stream.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails.

<details><summary>Other implementations (3)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **MLton** &mdash; the input1 that returns NONE leaves the stream before the end-of-stream; a second one consumes it
- **SML/NJ, SML/NJ 110.99.9** &mdash; input1 never moves past an end-of-stream

</details>

<details><summary>Tests (12)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `characters-then-NONE` &middot; `empty-file` &middot; `NONE-again-at-end-of-stream` &middot; `newline-NUL-and-high-characters` &middot; `removes-one-character` &middot; `NONE-after-input1-and-inputAll` &middot; `then-inputLine` &middot; `every-character` &middot; `large` &middot; `closed-stream` &middot; `file-grows-after-end-of-stream`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `passes-an-end-of-stream`

</details>

### <a name="val-inputn"></a>`inputN`

```sml
val inputN : instream * int -> vector
```

`inputN (f, n)` is `n` characters, or all there are before the next end of stream.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0`, or if the string to be returned would be
longer than [`String.maxSize`](../sig/STRING.md#val-maxsize).

<details><summary>Other implementations (2)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **SML/NJ** &mdash; inputN (strm, \~1) raises Subscript, not Size

</details>

<details><summary>Tests (16)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `pieces-then-empty` &middot; `exactly-the-rest` &middot; `more-than-there-is` &middot; `one` &middot; `zero-reads-nothing` &middot; `empty-after-inputN-and-inputAll` &middot; `empty-file` &middot; `does-not-stop-at-a-newline` &middot; `Size-negative` (raises Size) &middot; `Size-negative-at-end-of-stream` (raises Size) &middot; `negative-reads-nothing` &middot; `more-than-maxSize-of-a-short-file` &middot; `large` &middot; `closed-stream` &middot; `random-mix-of-operations-*` &middot; `random-mix-of-operations-large-*`

</details>

### <a name="val-inputall"></a>`inputAll`

```sml
val inputAll : instream -> vector
```

`inputAll f` is everything up to the next end of stream.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails; [`Size`](../sig/GENERAL.md#exn-size) if the result would be longer
than [`String.maxSize`](../sig/STRING.md#val-maxsize).

<details><summary>Other implementations (3)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **Poly/ML** &mdash; another reading of the specification: inputAll after an end-of-stream does not read what the file has gained; the test takes the reading of MLton and SML/NJ
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it: the example of stream-io.html ("abc", end-of-stream, "defg") gives "abc" and then "" for good

</details>

<details><summary>Tests (14)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `whole-file` &middot; `empty-file` &middot; `again-at-end-of-stream` &middot; `rest-after-inputLine` &middot; `empty-after-inputLine-and-inputAll` &middot; `every-character` &middot; `large` &middot; `no-final-newline-added` &middot; `file-grows-after-end-of-stream` &middot; `empty-after-input1-and-inputAll` &middot; `empty-after-lookahead-and-inputAll` &middot; `empty-after-endOfStream-and-inputAll` &middot; `empty-after-canInput-and-inputAll`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `up-to-each-end-of-stream`

</details>

### <a name="val-caninput"></a>`canInput`

```sml
val canInput : instream * int -> int option
```

`canInput (f, n)` is how many of `n` characters, at most, can be read without waiting, or `NONE`.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0`.

<details><summary>Tests (9)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `characters-available` &middot; `one` &middot; `more-than-there-is` &middot; `empty-file` &middot; `at-end-of-stream` &middot; `removes-nothing` &middot; `zero` &middot; `Size-negative` (raises Size) &middot; `closed-stream`

</details>

### <a name="val-lookahead"></a>`lookahead`

```sml
val lookahead : instream -> elem option
```

`lookahead f` is `SOME` of the next character without removing it, or `NONE` at an end of stream.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails.

**Example** `let val s = openString "ab" in (lookahead s, input1 s, input1 s, input1 s) end = (SOME #"a", SOME #"a", SOME #"b", NONE)`

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again

</details>

<details><summary>Tests (9)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `does-not-remove` &middot; `then-inputAll` &middot; `NONE-after-lookahead-and-inputAll` &middot; `then-inputLine` &middot; `empty-file` &middot; `after-each-line` &middot; `newline-and-NUL` &middot; `closed-stream`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `does-not-pass-an-end-of-stream`

</details>

### <a name="val-closein"></a>`closeIn`

```sml
val closeIn : instream -> unit
```

`closeIn f` closes the stream and the file underneath.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the file cannot be closed.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; characters buffered before closeIn are still read after it

</details>

<details><summary>Tests (10)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `twice` &middot; `then-inputAll-is-empty` &middot; `then-inputLine-is-NONE` &middot; `then-inputAll-again` &middot; `unread-characters-are-dropped` &middot; `unread-lines-are-dropped` &middot; `other-streams-stay-open` &middot; `file-can-be-rewritten`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `shared-functional-stream` &middot; `closes-the-reader`

</details>

### <a name="val-endofstream"></a>`endOfStream`

```sml
val endOfStream : instream -> bool
```

`endOfStream f` is `true` when nothing is left before the next end of stream.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again

</details>

<details><summary>Tests (10)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `empty-file` &middot; `characters-available` &middot; `removes-nothing` &middot; `true-after-endOfStream-and-inputAll` &middot; `around-each-line` &middot; `after-inputAll` &middot; `true-then-inputLine-is-NONE` &middot; `closed-stream` &middot; `file-grows-after-end-of-stream`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `more-after-an-end-of-stream`

</details>

### <a name="val-output"></a>`output`

```sml
val output : outstream * vector -> unit
```

`output (f, s)` writes the characters of `s`.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the stream is closed, with the cause `ClosedStream` and
nothing written, or if the file cannot be written to.

> **Implementation** `TextIO.output/no-translation`. On the POSIX systems the
> suite runs on, a text file holds exactly the characters written to it:
> no newline is translated and no character is dropped, for all 256
> of them.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again

</details>

<details><summary>Tests (14)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `in-order` &middot; `empty-string` &middot; `every-character` &middot; `no-line-end-translation` &middot; `large` &middot; `large-size` &middot; `Io-closed-stream` (raises) &middot; `Io-closed-stream-cause` &middot; `Io-closed-stream-function` &middot; `Io-closed-stream-name` &middot; `closed-stream-writes-nothing` &middot; `random-chunks-*` &middot; `random-chunks-large`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `shared-stream`

</details>

### <a name="val-output1"></a>`output1`

```sml
val output1 : outstream * elem -> unit
```

`output1 (f, c)` writes the single character `c`.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) as [`output`](#val-output) does.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; output1 on a closed stream raises Io with function "output"

</details>

<details><summary>Tests (8)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `in-order` &middot; `mixed-with-output` &middot; `every-character` &middot; `Io-closed-stream` (raises) &middot; `Io-closed-stream-cause` &middot; `Io-closed-stream-function` &middot; `Io-closed-stream-name` &middot; `large`

</details>

### <a name="val-flushout"></a>`flushOut`

```sml
val flushOut : outstream -> unit
```

`flushOut f` hands what the stream holds to the file.

> **Reading** `TextIO.flushOut/closed-is-a-no-op`. Through [`STREAM_IO`](../sig/STREAM_IO.md) ("a
> no-op on terminated streams", and a closed stream is terminated too),
> flushing a closed outstream does nothing rather than raising.

<details><summary>Tests (5)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `makes-output-visible` &middot; `nothing-to-flush` &middot; `twice` &middot; `closed-stream-is-a-no-op`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `flushes-the-stream`

</details>

### <a name="val-closeout"></a>`closeOut`

```sml
val closeOut : outstream -> unit
```

`closeOut f` flushes the stream and closes it and the file.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the flush or the close fails.

<details><summary>Tests (5)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `flushes` &middot; `twice` &middot; `other-streams-stay-open`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `shared-stream` (raises) &middot; `flushes-and-closes`

</details>

### <a name="val-mkinstream"></a>`mkInstream`

```sml
val mkInstream : StreamIO.instream -> instream
```

`mkInstream s` is an imperative stream holding the functional stream `s`.

<details><summary>Tests (3)</summary>

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `reads-the-functional-stream` &middot; `from-a-stream-part-read` &middot; `does-not-change-the-functional-stream`

</details>

### <a name="val-getinstream"></a>`getInstream`

```sml
val getInstream : instream -> StreamIO.instream
```

`getInstream f` is the functional stream that `f` is at.

<details><summary>Tests (4)</summary>

For `TextIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `current-version` &middot; `fresh` &middot; `input-from-it-is-read-again`

</details>

### <a name="val-setinstream"></a>`setInstream`

```sml
val setInstream : instream * StreamIO.instream -> unit
```

`setInstream (f, s)` makes `f` continue at `s`.

<details><summary>Tests (3)</summary>

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `redirects` &middot; `after-getInstream-and-input` &middot; `reread`

</details>

### <a name="val-mkoutstream"></a>`mkOutstream`

```sml
val mkOutstream : StreamIO.outstream -> outstream
```

`mkOutstream s` is an imperative stream holding the functional stream `s`.

<details><summary>Tests (2)</summary>

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `writes-to-the-stream` &middot; `keeps-the-buffer-mode`

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

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `the-same-stream` &middot; `flushes`

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

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `redirects` &middot; `flushes-the-old-stream` &middot; `save-and-restore`

</details>

### <a name="val-getposout"></a>`getPosOut`

```sml
val getPosOut : outstream -> StreamIO.out_pos
```

`getPosOut f` flushes `f` and is the position it is now at.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the file has no positions, or the flush fails.

<details><summary>Tests (2)</summary>

For `TextIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

In [tests/basis/fn/imperative\_io\_fn.sml](../../../../tests/basis/fn/imperative_io_fn.sml), applied to `TextIO`: `Io-without-positions` (raises)

</details>

### <a name="val-setposout"></a>`setPosOut`

```sml
val setPosOut : outstream * StreamIO.out_pos -> unit
```

`setPosOut (f, opos)` flushes `f` and moves it to the position `opos`.

What is written afterwards replaces what stood there.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the file has no positions, or the flush fails.

<details><summary>Other implementations (1)</summary>

- **SML/NJ 110.99.9** &mdash; setPosOut neither flushes nor moves the writer: output goes on at the end

</details>

<details><summary>Tests (1)</summary>

For `TextIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file-overwrites`

</details>

## The members of TEXT\_IO

### <a name="val-inputline"></a>`inputLine`

```sml
val inputLine : instream -> string option
```

`inputLine f` is `SOME` of the next line, with its newline, or `NONE` at an end of stream.

A last line that runs into an end of stream gets a newline appended, so
every line ends in one.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails.

> **Reading** `TextIO.inputLine/does-not-pass-the-end-of-stream`. An
> [`inputLine`](#val-inputline) that gives `NONE` does not consume the end of stream it
> found -- [`TEXT_STREAM_IO.inputLine`](../sig/TEXT_STREAM_IO.md#val-inputline) returns no stream in that case, so
> there is none to move on to -- and it keeps giving `NONE` even after the
> file has grown. Poly/ML reads on there.

**Example** `let val s = openString "a\nb" in (inputLine s, inputLine s, inputLine s) end = (SOME "a\n", SOME "b\n", NONE)`

<details><summary>Other implementations (2)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **Poly/ML** &mdash; another reading of the specification: inputLine that returned NONE reads on when the file has grown; the test takes the STREAM\_IO model, as MLton and SML/NJ do

</details>

<details><summary>Tests (15)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `NONE-after-inputLine-and-inputAll` &middot; `lines-then-NONE` &middot; `final-line-gets-newline` &middot; `one-character-without-newline` &middot; `empty-file` &middot; `NONE-again-at-end-of-stream` &middot; `empty-lines` &middot; `carriage-return-is-kept` &middot; `NUL-and-high-characters` &middot; `long-line-without-newline` &middot; `large` &middot; `after-inputAll` &middot; `file-grows-after-end-of-stream` &middot; `random-lines-*` &middot; `reads-on-after-a-consumed-end-of-stream`

</details>

### <a name="val-outputsubstr"></a>`outputSubstr`

```sml
val outputSubstr : outstream * substring -> unit
```

`outputSubstr (f, ss)` writes the characters of the substring `ss`.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the stream is closed or the file cannot be written to.

> **Reading** `TextIO.outputSubstr/Io-function-is-output`. It is "equivalent
> to [`output`](#val-output)", so the `function` of an [`IO.Io`](../sig/IO.md#exn-io) it raises is `"output"`, as
> MLton and Poly/ML report it. SML/NJ reports `"outputSubstr"`.

<details><summary>Other implementations (1)</summary>

- **SML/NJ** &mdash; another reading of the specification: reports function "outputSubstr"; the test takes outputSubstr to be "equivalent to" output, as MLton and Poly/ML do

</details>

<details><summary>Tests (9)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `part-of-a-string` &middot; `whole-string` &middot; `empty` &middot; `in-order` &middot; `mixed-with-output` &middot; `large` &middot; `Io-closed-stream-cause` &middot; `Io-closed-stream-function` &middot; `Io-closed-stream-name`

</details>

### <a name="val-openin"></a>`openIn`

```sml
val openIn : string -> instream
```

`openIn name` is a stream reading the file `name` from its start.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the file cannot be opened, with the system's error as
the cause and `"openIn"` as the `function`.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; another reading of the specification: reports the qualified name ("TextIO.openIn"); the test takes the unqualified name, as MLton and SML/NJ do

</details>

<details><summary>Tests (7)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `reads-the-file` &middot; `Io-file-does-not-exist` (raises) &middot; `Io-name` &middot; `Io-function` &middot; `Io-cause` &middot; `does-not-create-the-file` &middot; `Io-empty-name` (raises)

</details>

### <a name="val-openout"></a>`openOut`

```sml
val openOut : string -> outstream
```

`openOut name` is a stream writing the file `name`, which it empties or creates.

> **Implementation** `TextIO.openOut/buffer-mode`. The mode is `LINE_BUF`
> when the file is a terminal and `BLOCK_BUF` otherwise, as the
> specification asks; but the stream itself holds nothing back. The VM
> keeps the block and flushes every file at exit, so what a program writes
> with [`print`](#val-print) and what it writes through a stream reach the file in the
> order it wrote them.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the file cannot be opened.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; another reading of the specification: reports the qualified name ("TextIO.openIn"); the test takes the unqualified name, as MLton and SML/NJ do

</details>

<details><summary>Tests (9)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `creates-the-file` &middot; `truncates-an-existing-file` &middot; `truncates-at-open` &middot; `nothing-written` &middot; `Io-directory-does-not-exist` (raises) &middot; `Io-name` &middot; `Io-function` &middot; `Io-cause` &middot; `left-open-at-exit`

</details>

### <a name="val-openappend"></a>`openAppend`

```sml
val openAppend : string -> outstream
```

`openAppend name` is a stream writing at the end of the file `name`, which it creates if it is not there.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the file cannot be opened.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; another reading of the specification: reports the qualified name ("TextIO.openIn"); the test takes the unqualified name, as MLton and SML/NJ do

</details>

<details><summary>Tests (11)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `creates-the-file` &middot; `appends-to-an-existing-file` &middot; `keeps-the-contents` &middot; `three-times` &middot; `output1` &middot; `Io-directory-does-not-exist` (raises) &middot; `Io-name` &middot; `Io-function` &middot; `Io-cause` &middot; `Io-closed-stream` &middot; `random-pieces`

</details>

### <a name="val-openstring"></a>`openString`

```sml
val openString : string -> instream
```

`openString s` is a stream reading the characters of `s`, and no file.

**Example** `inputAll (openString "xyz") = "xyz"`

<details><summary>Other implementations (2)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **SML/NJ** &mdash; inputAll (openString "") raises Io {cause = Div, ...}

</details>

<details><summary>Tests (12)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `inputAll` &middot; `empty` &middot; `empty-inputLine` &middot; `inputLine` &middot; `streams-are-independent` &middot; `every-character` &middot; `large` &middot; `inputAll-twice` &middot; `closeIn` &middot; `random-lines-*` &middot; `random-mix-of-operations-*` &middot; `random-mix-of-operations-large`

</details>

### <a name="val-stdin"></a>`stdIn`

```sml
val stdIn : instream
```

The standard input of the program.

<details><summary>Tests (5)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `inputLine-at-end-of-stream` &middot; `inputAll-at-end-of-stream` &middot; `input-at-end-of-stream` &middot; `input1-at-end-of-stream` &middot; `endOfStream`

</details>

### <a name="val-stdout"></a>`stdOut`

```sml
val stdOut : outstream
```

The standard output of the program.

<details><summary>Tests (2)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `output-and-flushOut` &middot; `is-the-stream-of-print`

</details>

### <a name="val-stderr"></a>`stdErr`

```sml
val stdErr : outstream
```

The standard error of the program, which holds nothing back: its mode is `NO_BUF`.

<details><summary>Tests (1)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `output-and-flushOut`

</details>

### <a name="val-print"></a>`print`

```sml
val print : string -> unit
```

`print s` writes `s` to [`stdOut`](#val-stdout) and flushes it.

It is the [`print`](#val-print) of the top-level environment.

<details><summary>Tests (2)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `empty-string` &middot; `returns-unit`

</details>

### <a name="val-scanstream"></a>`scanStream`

```sml
val scanStream : ((Char.char, StreamIO.instream) StringCvt.reader
                  -> ('a, StreamIO.instream) StringCvt.reader)
                 -> instream -> 'a option
```

`scanStream scan f` runs a scanner over `f` and moves `f` to where it stopped.

`scan` is a function of the shape that [`StringCvt`](../str/StringCvt.md) describes: it takes a
reader and reads from a source, here the functional stream underneath.

> **Reading** `TextIO.scanStream/moves-only-on-success`. By the
> implementation the page gives, the stream is moved to where the scanner
> stopped when it returns `SOME`, and not at all when it returns `NONE`,
> whatever the scanner read while trying.

**Example** `scanStream (Int.scan StringCvt.DEC) (openString " 42 rest") = SOME 42`

<details><summary>Tests (16)</summary>

For `TextIO`, in [tests/basis/textio.sml](../../../../tests/basis/textio.sml): `number-then-rest` &middot; `stops-before-the-first-other-character` &middot; `negative-number` &middot; `NONE-reads-nothing` &middot; `NONE-keeps-skipped-whitespace` &middot; `NONE-keeps-a-sign` &middot; `empty-file` &middot; `number-up-to-end-of-stream` &middot; `one-after-another` &middot; `then-inputLine` &middot; `own-scanner` &middot; `own-scanner-fails-at-end-of-stream` &middot; `lookahead-is-not-lost` &middot; `scanner-that-reads-nothing` &middot; `closed-stream` &middot; `large`

</details>

## See also

[`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md), [`TEXT_STREAM_IO`](../sig/TEXT_STREAM_IO.md), [`BIN_IO`](../sig/BIN_IO.md), [`STRING_CVT`](../sig/STRING_CVT.md),
[`OS_FILE_SYS`](../sig/OS_FILE_SYS.md)

---

<sub>Generated by runedoc from lib/basis/sig\_text\_io.sml; do not edit.</sub>

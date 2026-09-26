# signature STREAM_IO

[The Standard ML Basis Library](../README.md) &rsaquo; Input and output &rsaquo; **STREAM_IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 3 |
| Documentation | 29 of 29 entries documented |
| Tests | 147 checks of 21 entries |
| Source | [lib/basis/streamio\_sig.sml](../../../../lib/basis/streamio_sig.sml) |

## Synopsis

```sml
signature STREAM_IO
structure BinIO.StreamIO : STREAM_IO where type vector = Word8Vector.vector where type elem = Word8.word where type reader = BinPrimIO.reader where type writer = BinPrimIO.writer where type pos = Position.int
functor StreamIO (...) : STREAM_IO  (* optional *)
structure TextIO.StreamIO : STREAM_IO
```

| Implementation |  | Source |
| --- | --- | --- |
| [`BinIO.StreamIO`](../str/BinIO.StreamIO.md) | "For binary streams, LINE\_BUF mode should be treated as a synonym for BLOCK\_BUF": no element is a newline. | [lib/basis/binio.sml](../../../../lib/basis/binio.sml) |
| `StreamIO` | Functional streams over a [`PRIM_IO`](../sig/PRIM_IO.md) of a new element type: the [`STREAM_IO`](STREAM_IO.md) of it. | [lib/basis/io\_functors.sml](../../../../lib/basis/io_functors.sml) |
| [`TextIO.StreamIO`](../str/TextIO.StreamIO.md) | TEXT\_STREAM\_IO: STREAM\_IO and the operations on lines and substrings. | [lib/basis/textio.sml](../../../../lib/basis/textio.sml) |

Streams as values: reading gives the elements and the stream that is left,
so a stream can be kept, read twice, and read from again where it was.

An instream is a position in a chain of segments that the reader fills in
as they are wanted, and reading never changes what a stream in hand holds:
`input f` twice gives the same elements twice, because the second call
works on the same `f`. That is what makes lookahead and backtracking
possible without a buffer of one's own, and what [`TEXT_IO.scanStream`](../sig/TEXT_IO.md#val-scanstream)
uses.

The chain goes on after an end of stream, because a file may grow: a
stream past an end of stream reads what was appended since. So an end of
stream is a place in the chain, not a state of the stream, and a stream
may pass several of them. [`input`](#val-input), [`input1`](#val-input1) and [`inputN`](#val-inputn) move past the one
they meet; [`endOfStream`](#val-endofstream) only looks.

An outstream, in contrast, is imperative: [`output`](#val-output) writes, and holds what
the buffer mode says to hold. [`getReader`](#val-getreader) and [`getWriter`](#val-getwriter) take the reader
or the writer back out and leave the stream truncated or terminated; after
that the stream is done with.

Whatever a reader or a writer raises is caught and raised again as the
`cause` of an [`IO.Io`](../sig/IO.md#exn-io), with the name of that reader or writer.

## Contents

[Reading](#reading) &middot;
[Writing](#writing) &middot;
[Readers and writers](#readers-and-writers) &middot;
[Buffering](#buffering)

## Interface

<pre>
signature STREAM_IO =
sig
  type <a href="#type-elem">elem</a>
  type <a href="#type-vector">vector</a>
  type <a href="#type-instream">instream</a>
  type <a href="#type-outstream">outstream</a>
  type <a href="#type-out_pos">out_pos</a>
  type <a href="#type-reader">reader</a>
  type <a href="#type-writer">writer</a>
  type <a href="#type-pos">pos</a>
  val <a href="#val-input">input</a> : instream -&gt; vector * instream
  val <a href="#val-input1">input1</a> : instream -&gt; (elem * instream) option
  val <a href="#val-inputn">inputN</a> : instream * int -&gt; vector * instream
  val <a href="#val-inputall">inputAll</a> : instream -&gt; vector * instream
  val <a href="#val-caninput">canInput</a> : instream * int -&gt; int option
  val <a href="#val-closein">closeIn</a> : instream -&gt; unit
  val <a href="#val-endofstream">endOfStream</a> : instream -&gt; bool
  val <a href="#val-output">output</a> : outstream * vector -&gt; unit
  val <a href="#val-output1">output1</a> : outstream * elem -&gt; unit
  val <a href="#val-flushout">flushOut</a> : outstream -&gt; unit
  val <a href="#val-closeout">closeOut</a> : outstream -&gt; unit
  val <a href="#val-mkinstream">mkInstream</a> : reader * vector -&gt; instream
  val <a href="#val-getreader">getReader</a> : instream -&gt; reader * vector
  val <a href="#val-fileposin">filePosIn</a> : instream -&gt; pos
  val <a href="#val-setbuffermode">setBufferMode</a> : outstream * IO.buffer_mode -&gt; unit
  val <a href="#val-getbuffermode">getBufferMode</a> : outstream -&gt; IO.buffer_mode
  val <a href="#val-mkoutstream">mkOutstream</a> : writer * IO.buffer_mode -&gt; outstream
  val <a href="#val-getwriter">getWriter</a> : outstream -&gt; writer * IO.buffer_mode
  val <a href="#val-getposout">getPosOut</a> : outstream -&gt; out_pos
  val <a href="#val-setposout">setPosOut</a> : out_pos -&gt; outstream
  val <a href="#val-fileposout">filePosOut</a> : out_pos -&gt; pos
end
</pre>

### <a name="type-elem"></a>`elem`

```sml
type elem
```

The type of the elements.

### <a name="type-vector"></a>`vector`

```sml
type vector
```

The type of vectors of them, which a read returns and [`output`](#val-output) takes.

### <a name="type-instream"></a>`instream`

```sml
type instream
```

The type of the functional input streams.

> **Reading** `StreamIO.instream/segments-are-shared`. Two streams that share
> a segment read the same elements from it: the reader is asked for a
> chunk once, and the chunk stays in the chain. The chain continues past
> an end of stream, so a stream that was kept from before an end of stream
> still reads what was there.

### <a name="type-outstream"></a>`outstream`

```sml
type outstream
```

The type of the output streams, which are not functional: [`output`](#val-output) changes what they hold.

### <a name="type-out_pos"></a>`out_pos`

```sml
type out_pos
```

A position in an outstream, together with the stream it is in.

### <a name="type-reader"></a>`reader`

```sml
type reader
```

The type of the readers the streams are built on, a [`PRIM_IO.reader`](../sig/PRIM_IO.md#type-reader).

### <a name="type-writer"></a>`writer`

```sml
type writer
```

The type of the writers the streams are built on, a [`PRIM_IO.writer`](../sig/PRIM_IO.md#type-writer).

### <a name="type-pos"></a>`pos`

```sml
type pos
```

The type of the positions of that reader and writer, a [`PRIM_IO.pos`](../sig/PRIM_IO.md#type-pos).

## Reading

### <a name="val-input"></a>`input`

```sml
val input : instream -> vector * instream
```

`input f` is the elements that are left in the current chunk and the stream after them.

At an end of stream it is the empty vector and the stream immediately
past that end of stream, so a following [`input`](#val-input) reads what the source
has gained since.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails, or if it offers no way to read that
waits.

> **Reading** `StreamIO.input/Io-carries-the-reader`. The page of [`IO`](../sig/IO.md) says
> what the fields hold: the exception the reader raised is the `cause` and
> the reader's own name is the `name`.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; input lets the exception of the reader through instead of raising Io with it as the cause

</details>

<details><summary>Tests (10)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `the-sequence-of-the-reader` &middot; `up-to-each-end-of-stream` &middot; `one-or-more-elements` &middot; `empty-at-end-of-stream` &middot; `same-result-twice` &middot; `up-to-date-with-the-reader` &middot; `earlier-streams-read-the-same` &middot; `Io-when-the-reader-fails` &middot; `Io-name-is-the-reader's` &middot; `after-a-failure-of-the-reader`

</details>

### <a name="val-input1"></a>`input1`

```sml
val input1 : instream -> (elem * instream) option
```

`input1 f` is `SOME` of the first element and the stream after it, or `NONE` at an end of stream.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails.

**Example** `let val s = TextIO.getInstream (TextIO.openString "abc") in (Option.map #1 (TextIO.StreamIO.input1 s), Option.map #1 (TextIO.StreamIO.input1 s)) end = (SOME #"a", SOME #"a")` for a stream is
a value, and reading from it gives another.

<details><summary>Tests (6)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `is-a-StringCvt.reader`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `elements-then-NONE` &middot; `empty-stream` &middot; `stops-at-end-of-stream` &middot; `NONE-again` &middot; `is-inputN-1`

</details>

### <a name="val-inputn"></a>`inputN`

```sml
val inputN : instream * int -> vector * instream
```

`inputN (f, n)` is `n` elements and the stream after them, or all there are before the next end of stream.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0`, or if the vector to be returned would be
longer than the greatest length of a vector.

> **Reading** `StreamIO.inputN/fewer-is-past-the-end-of-stream`. When fewer
> than `n` elements come before an end of stream, the stream returned is
> the one [`inputAll`](#val-inputall) would give: immediately past that end of stream.
> Exactly `n` elements that end at one leave the stream before it.

<details><summary>Other implementations (5)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again
- **SML/NJ** &mdash; inputN (strm, \~1) raises Subscript, not Size
- **SML/NJ 110.99.9** &mdash; inputN that finds fewer than n elements before an end-of-stream leaves the stream before it, where inputAll leaves it past it (allAndN)
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it, so that inputN and inputAll disagree (allAndN)
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it

</details>

<details><summary>Tests (8)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `zero` &middot; `Size-negative` (raises Size) &middot; `across-pieces` &middot; `fewer-then-past-the-end-of-stream` &middot; `continues-after-input1-NONE` &middot; `exactly-n-before-end-of-stream` &middot; `empty-stream` &middot; `allAndN-random-*`

</details>

### <a name="val-inputall"></a>`inputAll`

```sml
val inputAll : instream -> vector * instream
```

`inputAll f` is everything up to the next end of stream, and the stream past it.

<details><summary>Other implementations (2)</summary>

- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it: the example of stream-io.html ("abc", end-of-stream, "defg") gives "abc" and then "" for good
- **Poly/ML** &mdash; inputAll leaves the stream at the end-of-stream where it stops, not "immediately past" it as the definition by input does

</details>

<details><summary>Tests (5)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `up-to-each-end-of-stream` &middot; `pieces` &middot; `same-result-twice` &middot; `is-input-to-end-of-stream` &middot; `with-initial-elements`

</details>

### <a name="val-caninput"></a>`canInput`

```sml
val canInput : instream * int -> int option
```

`canInput (f, n)` is how many of `n` elements, at most, can be read without waiting, or `NONE`.

`NONE` means that not even one element can be had without waiting.

> **Reading** `StreamIO.canInput/what-is-counted`. Counted are the elements
> already in the chain, then what the reader's `readVecNB` yields, which
> the stream keeps: such a lookahead commits the stream to those elements.
> A reader without `readVecNB` is asked for `avail` instead.

**Raises** [`Size`](../sig/GENERAL.md#exn-size) if `n < 0`.

<details><summary>Other implementations (2)</summary>

- **MLton** &mdash; canInput on a stream whose elements input has already read answers SOME 0, which means end-of-stream (the noBlock predicate of stream-io.html)
- **SML/NJ 110.99.9** &mdash; canInput on a stream whose reader would block answers SOME 0 (end-of-stream), not NONE, and the elements it reads ahead are lost to the stream

</details>

<details><summary>Tests (7)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `Size-negative` (raises Size) &middot; `NONE-when-input-would-block` &middot; `elements-available` &middot; `then-inputN-k` &middot; `end-of-stream-is-zero` &middot; `determined-stream-does-not-block` &middot; `removes-nothing`

</details>

### <a name="val-closein"></a>`closeIn`

```sml
val closeIn : instream -> unit
```

`closeIn f` marks the stream closed and closes its reader.

Closing a truncated or an already closed stream is allowed and does
nothing more. A closed stream reads as if it ended where what had
already been read ends.

<details><summary>Other implementations (1)</summary>

- **MLton, Poly/ML** &mdash; closeIn of a stream that getReader truncated does not close the reader ("one can close a truncated or terminated string")

</details>

<details><summary>Tests (8)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `closes-the-reader` &middot; `twice` &middot; `any-stream-of-the-chain` &middot; `not-yet-determined-part-is-empty` &middot; `fresh-stream` &middot; `keeps-what-was-determined` &middot; `Io-when-the-reader-fails` &middot; `truncated-stream-closes-the-reader`

</details>

### <a name="val-endofstream"></a>`endOfStream`

```sml
val endOfStream : instream -> bool
```

`endOfStream f` is `true` when nothing is left before the next end of stream.

> **Reading** `StreamIO.endOfStream/does-not-consume`. It does not move past
> the end of stream it finds, so it stays `true` until a read consumes it;
> that read returns the empty vector, and only afterwards are elements
> that the source gained seen.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails while it is asked for more.

<details><summary>Tests (6)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `is-input-empty` &middot; `end-of-stream-then-more` &middot; `elements-available` &middot; `empty-stream` &middot; `removes-nothing` &middot; `closed-stream`

</details>

## Writing

### <a name="val-output"></a>`output`

```sml
val output : outstream * vector -> unit
```

`output (f, v)` writes the elements of `v`, holding back what the buffer mode allows.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the writer fails, or if the stream is closed or
terminated.

> **Reading** `StreamIO.output/Io-closed-writes-nothing`. The cause on a
> closed or terminated stream is `ClosedStream`, from the list of [`IO`](../sig/IO.md),
> and nothing is written.

<details><summary>Other implementations (1)</summary>

- **SML/NJ 110.99.9** &mdash; output and output1 on a stream that getWriter terminated go on writing instead of raising Io

</details>

<details><summary>Tests (11)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `NO_BUF-writes-at-once` &middot; `partial-writes-are-completed` &middot; `BLOCK_BUF-keeps-a-little` &middot; `LINE_BUF-flushes-at-a-newline` &middot; `LINE_BUF-is-BLOCK_BUF` &middot; `Io-closed` &middot; `Io-closed-name` &middot; `Io-terminated` &middot; `Io-terminated-writes-nothing` &middot; `Io-when-the-writer-fails` &middot; `Io-name-is-the-writer's`

</details>

### <a name="val-output1"></a>`output1`

```sml
val output1 : outstream * elem -> unit
```

`output1 (f, x)` writes the single element `x`.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) as [`output`](#val-output) does.

<details><summary>Other implementations (2)</summary>

- **MLton** &mdash; output1 lets the exception of the writer through instead of raising Io with it as the cause (output raises Io)
- **SML/NJ 110.99.9** &mdash; output and output1 on a stream that getWriter terminated go on writing instead of raising Io

</details>

<details><summary>Tests (6)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `NO_BUF-writes-at-once` &middot; `LINE_BUF-flushes-at-a-newline` &middot; `LINE_BUF-is-BLOCK_BUF` &middot; `Io-closed` &middot; `Io-terminated` &middot; `Io-when-the-writer-fails`

</details>

### <a name="val-flushout"></a>`flushOut`

```sml
val flushOut : outstream -> unit
```

`flushOut f` hands what the stream holds to its writer.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the writer fails.

> **Reading** `StreamIO.flushOut/empties-first`. The buffer is emptied before
> it is passed on, so a writer that fails cannot cause the same elements
> to be written twice. Flushing a terminated or a closed stream does
> nothing.

<details><summary>Tests (9)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `file`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `partial-writes-are-completed` &middot; `writes-the-buffer` &middot; `LINE_BUF` &middot; `NO_BUF` &middot; `terminated-is-a-no-op` &middot; `closed-is-a-no-op` &middot; `Io-when-the-writer-fails`

</details>

### <a name="val-closeout"></a>`closeOut`

```sml
val closeOut : outstream -> unit
```

`closeOut f` flushes the stream, marks it closed and closes its writer.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the flush or the writer fails.

> **Reading** `StreamIO.closeOut/a-failed-flush-leaves-it-open`. Closing an
> already closed stream does nothing; a terminated one is not flushed; and
> when the flush fails the stream stays open, so that it can be closed
> again. What it held is gone all the same: the buffer is emptied before
> the writer is asked, as [`flushOut`](#val-flushout) does it.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; closeOut of a stream that getWriter terminated does not close the writer ("one can close a truncated or terminated string")

</details>

<details><summary>Tests (7)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `flushes` &middot; `closes-the-writer` &middot; `twice` &middot; `terminated-closes-the-writer` &middot; `Io-when-flushing-fails` &middot; `left-open-when-flushing-fails`

</details>

## Readers and writers

### <a name="val-mkinstream"></a>`mkInstream`

```sml
val mkInstream : reader * vector -> instream
```

`mkInstream (rd, v)` is a stream that reads `v` first and then what `rd` gives.

`v` is what was taken from the reader already and is being handed back;
the reader is augmented, so the stream uses whatever reads can be built
from it.

<details><summary>Tests (6)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file-reader`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `initial-buffer-comes-first` &middot; `initial-buffer-input1` &middot; `input-of-initial-buffer` &middot; `reads-nothing` &middot; `empty-reader`

</details>

### <a name="val-getreader"></a>`getReader`

```sml
val getReader : instream -> reader * vector
```

`getReader f` is the reader of `f` and what was read ahead but not consumed, and truncates `f`.

The reader is the one that was given to [`mkInstream`](#val-mkinstream), not the augmented
one.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if `f` is closed or already truncated.

> **Reading** `StreamIO.getReader/Io-cause-is-ClosedStream`. A truncated
> stream is one that has given its reader away; the cause is
> `ClosedStream` for it as for a closed one.

<details><summary>Other implementations (1)</summary>

- **SML/NJ 110.99.9** &mdash; getReader of a closed or truncated stream raises nothing

</details>

<details><summary>Tests (11)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `file`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `fresh-stream` &middot; `unconsumed-data` &middot; `after-the-data` &middot; `initial-buffer` &middot; `truncates-the-stream` &middot; `truncated-stream-keeps-its-buffer` &middot; `does-not-close-the-reader` &middot; `Io-truncated` (raises) &middot; `Io-closed` (raises)

</details>

### <a name="val-fileposin"></a>`filePosIn`

```sml
val filePosIn : instream -> pos
```

`filePosIn f` is the position of the element that would be read next.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the stream has no positions, or if it has been
truncated or closed.

> **Reading** `StreamIO.filePosIn/what-is-unsupported`. "Does not support the
> operation" means that the reader has no `getPos`, and the cause of the
> [`IO.Io`](../sig/IO.md#exn-io) is then `RandomAccessNotSupported`, from the list of [`IO`](../sig/IO.md). A reader
> that has `getPos` may still fail to tell where it is (a pipe), and the
> chunks read then carry no position, which raises as well.

<details><summary>Other implementations (1)</summary>

- **MLton, SML/NJ 110.99.9** &mdash; filePosIn of a truncated stream raises nothing

</details>

<details><summary>Tests (9)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `setPos-then-readVec` &middot; `Io-truncated` (raises)

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `offsets` &middot; `reader-not-at-the-start` &middot; `setPos-then-readVec` &middot; `Io-truncated` (raises) &middot; `file-offsets`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `Io-without-positions` (raises) &middot; `Io-cause`

</details>

## Buffering

### <a name="val-setbuffermode"></a>`setBufferMode`

```sml
val setBufferMode : outstream * IO.buffer_mode -> unit
```

`setBufferMode (f, mode)` makes `f` hold back what `mode` says.

Changing to `NO_BUF` flushes what is held; changing between `LINE_BUF`
and `BLOCK_BUF` does not.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if that flush fails.

<details><summary>Tests (8)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `NO_BUF-file` &middot; `LINE_BUF-file` &middot; `NO_BUF-flushes-file`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `NO_BUF-file`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `NO_BUF-flushes` &middot; `BLOCK_BUF-to-LINE_BUF-does-not-flush` &middot; `LINE_BUF-to-BLOCK_BUF-does-not-flush` &middot; `then-output`

</details>

### <a name="val-getbuffermode"></a>`getBufferMode`

```sml
val getBufferMode : outstream -> IO.buffer_mode
```

`getBufferMode f` is the mode `f` holds back by.

<details><summary>Other implementations (1)</summary>

- **SML/NJ 110.99.9** &mdash; openAppend makes an unbuffered stream ("When opening a stream for writing, the stream will be block buffered by default")

</details>

<details><summary>Tests (5)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `openOut-is-BLOCK_BUF` &middot; `openAppend-is-BLOCK_BUF` &middot; `stdErr-is-NO_BUF`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `openOut-is-buffered`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `after-setBufferMode`

</details>

### <a name="val-mkoutstream"></a>`mkOutstream`

```sml
val mkOutstream : writer * IO.buffer_mode -> outstream
```

`mkOutstream (wr, mode)` is a stream that writes through `wr`, holding back what `mode` says.

> **Reading** `StreamIO.mkOutstream/the-writer-is-augmented`. The
> specification does not say whether the writer is augmented here; this
> one augments it, and [`getWriter`](#val-getwriter) still gives back the writer that was
> passed in.

<details><summary>Tests (3)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file-writer`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `buffer-mode` &middot; `writes-to-the-writer`

</details>

### <a name="val-getwriter"></a>`getWriter`

```sml
val getWriter : outstream -> writer * IO.buffer_mode
```

`getWriter f` flushes `f`, terminates it, and is its writer and its buffer mode.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if `f` is closed, or if the flush fails.

> **Reading** `StreamIO.getWriter/terminated-is-not-closed`. A stream that is
> already terminated gives its writer and its mode again without flushing;
> only a closed one raises.

<details><summary>Other implementations (1)</summary>

- **SML/NJ 110.99.9** &mdash; getWriter of a closed stream raises nothing

</details>

<details><summary>Tests (8)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `file`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `writer-and-mode` &middot; `flushes` &middot; `the-same-writer` &middot; `does-not-close-the-writer` &middot; `Io-closed` (raises) &middot; `Io-when-flushing-fails`

</details>

### <a name="val-getposout"></a>`getPosOut`

```sml
val getPosOut : outstream -> out_pos
```

`getPosOut f` flushes `f` and is the position it is now at, together with `f` itself.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the writer has no positions, if the flush fails, or if
`f` is terminated or closed.

> **Implementation** `StreamIO.getPosOut/is-a-file-offset`. For a stream over
> a file the position is the offset of a byte from the start of it, which
> is what [`BinPrimIO.pos`](../sig/PRIM_IO.md#type-pos) holds.

<details><summary>Tests (6)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `is-where-the-next-element-goes`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `flushes` &middot; `file-offsets`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `Io-without-positions` (raises) &middot; `Io-cause` &middot; `Io-terminated` (raises)

</details>

### <a name="val-setposout"></a>`setPosOut`

```sml
val setPosOut : out_pos -> outstream
```

`setPosOut opos` flushes the stream of `opos`, moves it to that position, and is that stream.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the writer has no positions, if the flush fails, or if
the stream is terminated or closed.

> **Reading** `StreamIO.setPosOut/writes-over`. What is written after it
> replaces what stood at that position; the stream is not truncated
> there.

<details><summary>Other implementations (1)</summary>

- **SML/NJ 110.99.9** &mdash; setPosOut neither flushes nor moves the writer: output goes on at the end

</details>

<details><summary>Tests (5)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file-overwrites`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `overwrites` &middot; `flushes` &middot; `returns-the-stream` &middot; `file-overwrites`

</details>

### <a name="val-fileposout"></a>`filePosOut`

```sml
val filePosOut : out_pos -> pos
```

`filePosOut opos` is the position that `opos` records, without its stream.

<details><summary>Tests (3)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `is-the-writer's-position`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `offsets` &middot; `writes-go-there`

</details>

## See also

[`IO`](../sig/IO.md), [`PRIM_IO`](../sig/PRIM_IO.md), [`TEXT_STREAM_IO`](../sig/TEXT_STREAM_IO.md), [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md), [`TEXT_IO`](../sig/TEXT_IO.md)

---

<sub>Generated by runedoc from lib/basis/streamio\_sig.sml; do not edit.</sub>

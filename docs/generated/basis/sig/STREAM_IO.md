# signature STREAM_IO

[The Standard ML Basis Library](../README.md) &rsaquo; **STREAM_IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 3 |
| Documentation | 0 of 29 entries documented |
| Tests | 147 checks of 21 entries |
| Source | [lib/basis/streamio\_sig.sml](../../../../lib/basis/streamio_sig.sml) |

## Synopsis

```sml
signature STREAM_IO
structure BinIO.StreamIO : STREAM_IO where type vector = Word8Vector.vector where type elem = Word8.word where type reader = BinPrimIO.reader where type writer = BinPrimIO.writer where type pos = Position.int
functor StreamIO (...) : STREAM_IO
structure TextIO.StreamIO : STREAM_IO
```

| Implementation |  | Source |
| --- | --- | --- |
| `BinIO.StreamIO` | "For binary streams, LINE\_BUF mode should be treated as a synonym for BLOCK\_BUF": no element is a newline. | [lib/basis/binio.sml](../../../../lib/basis/binio.sml) |
| `StreamIO` |  | [lib/basis/io\_functors.sml](../../../../lib/basis/io_functors.sml) |
| `TextIO.StreamIO` | TEXT\_STREAM\_IO: STREAM\_IO and the operations on lines and substrings. | [lib/basis/textio.sml](../../../../lib/basis/textio.sml) |

signature STREAM\_IO: the functional streams.

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

### <a name="type-vector"></a>`vector`

```sml
type vector
```

### <a name="type-instream"></a>`instream`

```sml
type instream
```

### <a name="type-outstream"></a>`outstream`

```sml
type outstream
```

### <a name="type-out_pos"></a>`out_pos`

```sml
type out_pos
```

### <a name="type-reader"></a>`reader`

```sml
type reader
```

### <a name="type-writer"></a>`writer`

```sml
type writer
```

### <a name="type-pos"></a>`pos`

```sml
type pos
```

### <a name="val-input"></a>`input`

```sml
val input : instream -> vector * instream
```

<details><summary>Tests (10)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `the-sequence-of-the-reader` &middot; `up-to-each-end-of-stream` &middot; `one-or-more-elements` &middot; `empty-at-end-of-stream` &middot; `same-result-twice` &middot; `up-to-date-with-the-reader` &middot; `earlier-streams-read-the-same` &middot; `Io-when-the-reader-fails` &middot; `Io-name-is-the-reader's` &middot; `after-a-failure-of-the-reader`

</details>

### <a name="val-input1"></a>`input1`

```sml
val input1 : instream -> (elem * instream) option
```

<details><summary>Tests (6)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `is-a-StringCvt.reader`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `elements-then-NONE` &middot; `empty-stream` &middot; `stops-at-end-of-stream` &middot; `NONE-again` &middot; `is-inputN-1`

</details>

### <a name="val-inputn"></a>`inputN`

```sml
val inputN : instream * int -> vector * instream
```

<details><summary>Tests (8)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `zero` &middot; `Size-negative` (raises Size) &middot; `across-pieces` &middot; `fewer-then-past-the-end-of-stream` &middot; `continues-after-input1-NONE` &middot; `exactly-n-before-end-of-stream` &middot; `empty-stream` &middot; `allAndN-random-*`

</details>

### <a name="val-inputall"></a>`inputAll`

```sml
val inputAll : instream -> vector * instream
```

<details><summary>Tests (5)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `up-to-each-end-of-stream` &middot; `pieces` &middot; `same-result-twice` &middot; `is-input-to-end-of-stream` &middot; `with-initial-elements`

</details>

### <a name="val-caninput"></a>`canInput`

```sml
val canInput : instream * int -> int option
```

<details><summary>Tests (7)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `Size-negative` (raises Size) &middot; `NONE-when-input-would-block` &middot; `elements-available` &middot; `then-inputN-k` &middot; `end-of-stream-is-zero` &middot; `determined-stream-does-not-block` &middot; `removes-nothing`

</details>

### <a name="val-closein"></a>`closeIn`

```sml
val closeIn : instream -> unit
```

<details><summary>Tests (8)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `closes-the-reader` &middot; `twice` &middot; `any-stream-of-the-chain` &middot; `not-yet-determined-part-is-empty` &middot; `fresh-stream` &middot; `keeps-what-was-determined` &middot; `Io-when-the-reader-fails` &middot; `truncated-stream-closes-the-reader`

</details>

### <a name="val-endofstream"></a>`endOfStream`

```sml
val endOfStream : instream -> bool
```

<details><summary>Tests (6)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `is-input-empty` &middot; `end-of-stream-then-more` &middot; `elements-available` &middot; `empty-stream` &middot; `removes-nothing` &middot; `closed-stream`

</details>

### <a name="val-output"></a>`output`

```sml
val output : outstream * vector -> unit
```

<details><summary>Tests (11)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `NO_BUF-writes-at-once` &middot; `partial-writes-are-completed` &middot; `BLOCK_BUF-keeps-a-little` &middot; `LINE_BUF-flushes-at-a-newline` &middot; `LINE_BUF-is-BLOCK_BUF` &middot; `Io-closed` &middot; `Io-closed-name` &middot; `Io-terminated` &middot; `Io-terminated-writes-nothing` &middot; `Io-when-the-writer-fails` &middot; `Io-name-is-the-writer's`

</details>

### <a name="val-output1"></a>`output1`

```sml
val output1 : outstream * elem -> unit
```

<details><summary>Tests (6)</summary>

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `NO_BUF-writes-at-once` &middot; `LINE_BUF-flushes-at-a-newline` &middot; `LINE_BUF-is-BLOCK_BUF` &middot; `Io-closed` &middot; `Io-terminated` &middot; `Io-when-the-writer-fails`

</details>

### <a name="val-flushout"></a>`flushOut`

```sml
val flushOut : outstream -> unit
```

<details><summary>Tests (9)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `file`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `partial-writes-are-completed` &middot; `writes-the-buffer` &middot; `LINE_BUF` &middot; `NO_BUF` &middot; `terminated-is-a-no-op` &middot; `closed-is-a-no-op` &middot; `Io-when-the-writer-fails`

</details>

### <a name="val-closeout"></a>`closeOut`

```sml
val closeOut : outstream -> unit
```

<details><summary>Tests (7)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `flushes` &middot; `closes-the-writer` &middot; `twice` &middot; `terminated-closes-the-writer` &middot; `Io-when-flushing-fails` &middot; `left-open-when-flushing-fails`

</details>

### <a name="val-mkinstream"></a>`mkInstream`

```sml
val mkInstream : reader * vector -> instream
```

<details><summary>Tests (6)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file-reader`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `initial-buffer-comes-first` &middot; `initial-buffer-input1` &middot; `input-of-initial-buffer` &middot; `reads-nothing` &middot; `empty-reader`

</details>

### <a name="val-getreader"></a>`getReader`

```sml
val getReader : instream -> reader * vector
```

<details><summary>Tests (11)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `file`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `fresh-stream` &middot; `unconsumed-data` &middot; `after-the-data` &middot; `initial-buffer` &middot; `truncates-the-stream` &middot; `truncated-stream-keeps-its-buffer` &middot; `does-not-close-the-reader` &middot; `Io-truncated` (raises) &middot; `Io-closed` (raises)

</details>

### <a name="val-fileposin"></a>`filePosIn`

```sml
val filePosIn : instream -> pos
```

<details><summary>Tests (9)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `setPos-then-readVec` &middot; `Io-truncated` (raises)

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `offsets` &middot; `reader-not-at-the-start` &middot; `setPos-then-readVec` &middot; `Io-truncated` (raises) &middot; `file-offsets`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `Io-without-positions` (raises) &middot; `Io-cause`

</details>

### <a name="val-setbuffermode"></a>`setBufferMode`

```sml
val setBufferMode : outstream * IO.buffer_mode -> unit
```

<details><summary>Tests (8)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `NO_BUF-file` &middot; `LINE_BUF-file` &middot; `NO_BUF-flushes-file`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `NO_BUF-file`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `NO_BUF-flushes` &middot; `BLOCK_BUF-to-LINE_BUF-does-not-flush` &middot; `LINE_BUF-to-BLOCK_BUF-does-not-flush` &middot; `then-output`

</details>

### <a name="val-getbuffermode"></a>`getBufferMode`

```sml
val getBufferMode : outstream -> IO.buffer_mode
```

<details><summary>Tests (5)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `openOut-is-BLOCK_BUF` &middot; `openAppend-is-BLOCK_BUF` &middot; `stdErr-is-NO_BUF`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `openOut-is-buffered`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `after-setBufferMode`

</details>

### <a name="val-mkoutstream"></a>`mkOutstream`

```sml
val mkOutstream : writer * IO.buffer_mode -> outstream
```

<details><summary>Tests (3)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file-writer`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `buffer-mode` &middot; `writes-to-the-writer`

</details>

### <a name="val-getwriter"></a>`getWriter`

```sml
val getWriter : outstream -> writer * IO.buffer_mode
```

<details><summary>Tests (8)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `file`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `writer-and-mode` &middot; `flushes` &middot; `the-same-writer` &middot; `does-not-close-the-writer` &middot; `Io-closed` (raises) &middot; `Io-when-flushing-fails`

</details>

### <a name="val-getposout"></a>`getPosOut`

```sml
val getPosOut : outstream -> out_pos
```

<details><summary>Tests (6)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `is-where-the-next-element-goes`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `flushes` &middot; `file-offsets`

In [tests/basis/fn/stream\_io\_fn.sml](../../../../tests/basis/fn/stream_io_fn.sml), applied to `TextIO.StreamIO`, `BinIO.StreamIO`: `Io-without-positions` (raises) &middot; `Io-cause` &middot; `Io-terminated` (raises)

</details>

### <a name="val-setposout"></a>`setPosOut`

```sml
val setPosOut : out_pos -> outstream
```

<details><summary>Tests (5)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file-overwrites`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `overwrites` &middot; `flushes` &middot; `returns-the-stream` &middot; `file-overwrites`

</details>

### <a name="val-fileposout"></a>`filePosOut`

```sml
val filePosOut : out_pos -> pos
```

<details><summary>Tests (3)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `is-the-writer's-position`

For `BinIO.StreamIO`, in [tests/basis/binio\_streamio.sml](../../../../tests/basis/binio_streamio.sml): `offsets` &middot; `writes-go-there`

</details>

---

<sub>Generated by runedoc from lib/basis/streamio\_sig.sml; do not edit.</sub>

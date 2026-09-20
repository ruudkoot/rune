# signature STREAM_IO

[The Standard ML Basis Library](../README.md) &rsaquo; **STREAM_IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 3 |
| Documentation | 0 of 29 entries documented |
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

### <a name="val-input1"></a>`input1`

```sml
val input1 : instream -> (elem * instream) option
```

### <a name="val-inputn"></a>`inputN`

```sml
val inputN : instream * int -> vector * instream
```

### <a name="val-inputall"></a>`inputAll`

```sml
val inputAll : instream -> vector * instream
```

### <a name="val-caninput"></a>`canInput`

```sml
val canInput : instream * int -> int option
```

### <a name="val-closein"></a>`closeIn`

```sml
val closeIn : instream -> unit
```

### <a name="val-endofstream"></a>`endOfStream`

```sml
val endOfStream : instream -> bool
```

### <a name="val-output"></a>`output`

```sml
val output : outstream * vector -> unit
```

### <a name="val-output1"></a>`output1`

```sml
val output1 : outstream * elem -> unit
```

### <a name="val-flushout"></a>`flushOut`

```sml
val flushOut : outstream -> unit
```

### <a name="val-closeout"></a>`closeOut`

```sml
val closeOut : outstream -> unit
```

### <a name="val-mkinstream"></a>`mkInstream`

```sml
val mkInstream : reader * vector -> instream
```

### <a name="val-getreader"></a>`getReader`

```sml
val getReader : instream -> reader * vector
```

### <a name="val-fileposin"></a>`filePosIn`

```sml
val filePosIn : instream -> pos
```

### <a name="val-setbuffermode"></a>`setBufferMode`

```sml
val setBufferMode : outstream * IO.buffer_mode -> unit
```

### <a name="val-getbuffermode"></a>`getBufferMode`

```sml
val getBufferMode : outstream -> IO.buffer_mode
```

### <a name="val-mkoutstream"></a>`mkOutstream`

```sml
val mkOutstream : writer * IO.buffer_mode -> outstream
```

### <a name="val-getwriter"></a>`getWriter`

```sml
val getWriter : outstream -> writer * IO.buffer_mode
```

### <a name="val-getposout"></a>`getPosOut`

```sml
val getPosOut : outstream -> out_pos
```

### <a name="val-setposout"></a>`setPosOut`

```sml
val setPosOut : out_pos -> outstream
```

### <a name="val-fileposout"></a>`filePosOut`

```sml
val filePosOut : out_pos -> pos
```

---

<sub>Generated by runedoc from lib/basis/streamio\_sig.sml; do not edit.</sub>

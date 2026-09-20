# signature TEXT_STREAM_IO

[The Standard ML Basis Library](../README.md) &rsaquo; Input and output &rsaquo; **TEXT_STREAM_IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 2 of 2 entries documented |
| Tests | 16 checks of 2 entries |
| Source | [lib/basis/sig\_text\_stream\_io.sml](../../../../lib/basis/sig_text_stream_io.sml) |

## Synopsis

```sml
signature TEXT_STREAM_IO
structure TextIO.StreamIO : TEXT_STREAM_IO where type reader = TextPrimIO.reader where type writer = TextPrimIO.writer where type pos = TextPrimIO.pos
```

| Implementation |  | Source |
| --- | --- | --- |
| `TextIO.StreamIO` | TEXT\_STREAM\_IO: STREAM\_IO and the operations on lines and substrings. | [lib/basis/textio.sml](../../../../lib/basis/textio.sml) |

The functional streams of [`STREAM_IO`](../sig/STREAM_IO.md) where the elements are characters,
with the two operations that only text has: reading a line and writing a
substring.

Everything of [`STREAM_IO`](../sig/STREAM_IO.md) holds here unchanged; the `include` fixes the
elements to `char` and the vectors to `string`.

## Interface

<pre>
signature TEXT_STREAM_IO =
sig
  include STREAM_IO
    where type vector = CharVector.vector
    where type elem = Char.char

  val <a href="#val-inputline">inputLine</a> : instream -&gt; (string * instream) option

  val <a href="#val-outputsubstr">outputSubstr</a> : outstream * substring -&gt; unit
end
</pre>

**Included from [`STREAM_IO`](../sig/STREAM_IO.md)**: `include STREAM_IO
  where type vector = CharVector.vector
  where type elem = Char.char`

| Member |  |  |
| --- | --- | --- |
| [`elem`](../sig/STREAM_IO.md#type-elem) | type | The type of the elements. |
| [`vector`](../sig/STREAM_IO.md#type-vector) | type | The type of vectors of them, which a read returns and `output` takes. |
| [`instream`](../sig/STREAM_IO.md#type-instream) | type | The type of the functional input streams. |
| [`outstream`](../sig/STREAM_IO.md#type-outstream) | type | The type of the output streams, which are not functional: `output` changes what they hold. |
| [`out_pos`](../sig/STREAM_IO.md#type-out_pos) | type | A position in an outstream, together with the stream it is in. |
| [`reader`](../sig/STREAM_IO.md#type-reader) | type | The type of the readers the streams are built on, a `PRIM_IO.reader`. |
| [`writer`](../sig/STREAM_IO.md#type-writer) | type | The type of the writers the streams are built on, a `PRIM_IO.writer`. |
| [`pos`](../sig/STREAM_IO.md#type-pos) | type | The type of the positions of that reader and writer, a `PRIM_IO.pos`. |
| [`input`](../sig/STREAM_IO.md#val-input) | val | `input f` is the elements that are left in the current chunk and the stream after them. |
| [`input1`](../sig/STREAM_IO.md#val-input1) | val | `input1 f` is `SOME` of the first element and the stream after it, or `NONE` at an end of stream. |
| [`inputN`](../sig/STREAM_IO.md#val-inputn) | val | `inputN (f, n)` is `n` elements and the stream after them, or all there are before the next end of stream. |
| [`inputAll`](../sig/STREAM_IO.md#val-inputall) | val | `inputAll f` is everything up to the next end of stream, and the stream past it. |
| [`canInput`](../sig/STREAM_IO.md#val-caninput) | val | `canInput (f, n)` is how many of `n` elements, at most, can be read without waiting, or `NONE`. |
| [`closeIn`](../sig/STREAM_IO.md#val-closein) | val | `closeIn f` marks the stream closed and closes its reader. |
| [`endOfStream`](../sig/STREAM_IO.md#val-endofstream) | val | `endOfStream f` is `true` when nothing is left before the next end of stream. |
| [`output`](../sig/STREAM_IO.md#val-output) | val | `output (f, v)` writes the elements of `v`, holding back what the buffer mode allows. |
| [`output1`](../sig/STREAM_IO.md#val-output1) | val | `output1 (f, x)` writes the single element `x`. |
| [`flushOut`](../sig/STREAM_IO.md#val-flushout) | val | `flushOut f` hands what the stream holds to its writer. |
| [`closeOut`](../sig/STREAM_IO.md#val-closeout) | val | `closeOut f` flushes the stream, marks it closed and closes its writer. |
| [`mkInstream`](../sig/STREAM_IO.md#val-mkinstream) | val | `mkInstream (rd, v)` is a stream that reads `v` first and then what `rd` gives. |
| [`getReader`](../sig/STREAM_IO.md#val-getreader) | val | `getReader f` is the reader of `f` and what was read ahead but not consumed, and truncates `f`. |
| [`filePosIn`](../sig/STREAM_IO.md#val-fileposin) | val | `filePosIn f` is the position of the element that would be read next. |
| [`setBufferMode`](../sig/STREAM_IO.md#val-setbuffermode) | val | `setBufferMode (f, mode)` makes `f` hold back what `mode` says. |
| [`getBufferMode`](../sig/STREAM_IO.md#val-getbuffermode) | val | `getBufferMode f` is the mode `f` holds back by. |
| [`mkOutstream`](../sig/STREAM_IO.md#val-mkoutstream) | val | `mkOutstream (wr, mode)` is a stream that writes through `wr`, holding back what `mode` says. |
| [`getWriter`](../sig/STREAM_IO.md#val-getwriter) | val | `getWriter f` flushes `f`, terminates it, and is its writer and its buffer mode. |
| [`getPosOut`](../sig/STREAM_IO.md#val-getposout) | val | `getPosOut f` flushes `f` and is the position it is now at, together with `f` itself. |
| [`setPosOut`](../sig/STREAM_IO.md#val-setposout) | val | `setPosOut opos` flushes the stream of `opos`, moves it to that position, and is that stream. |
| [`filePosOut`](../sig/STREAM_IO.md#val-fileposout) | val | `filePosOut opos` is the position that `opos` records, without its stream. |

### <a name="val-inputline"></a>`inputLine`

```sml
val inputLine : instream -> (string * instream) option
```

`inputLine f` is `SOME` of the next line, with its newline, and the stream after it, or `NONE` at an end of stream.

> **Reading** `TextIO.StreamIO.inputLine/last-line-without-a-newline`. A last
> line that runs into an end of stream gets a newline appended, so that
> every line returned ends in one, and the stream returned is past that
> end of stream. At an end of stream itself it is `NONE`.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the reader fails.

<details><summary>Tests (11)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `lines-then-NONE` &middot; `last-line-gets-a-newline` &middot; `empty-stream` &middot; `at-end-of-stream` &middot; `line-ends-at-end-of-stream` &middot; `empty-lines` &middot; `same-result-twice` &middot; `residual-stream` &middot; `does-not-change-the-stream` &middot; `long-line` &middot; `carriage-return-is-kept`

</details>

### <a name="val-outputsubstr"></a>`outputSubstr`

```sml
val outputSubstr : outstream * substring -> unit
```

`outputSubstr (f, ss)` writes the characters of the substring `ss`.

It is `output (f, Substring.string ss)`, and so raises what that raises,
with `"output"` as the `function` of the [`IO.Io`](../sig/IO.md#exn-io).

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the writer fails, or if the stream is closed or
terminated.

<details><summary>Tests (5)</summary>

For `TextIO.StreamIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `is-output-of-the-string` &middot; `empty` &middot; `buffered` &middot; `LINE_BUF` &middot; `Io-closed`

</details>

## See also

[`STREAM_IO`](../sig/STREAM_IO.md), [`TEXT_IO`](../sig/TEXT_IO.md), [`SUBSTRING`](../sig/SUBSTRING.md)

---

<sub>Generated by runedoc from lib/basis/sig\_text\_stream\_io.sml; do not edit.</sub>

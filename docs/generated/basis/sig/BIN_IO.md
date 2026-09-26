# signature BIN_IO

[The Standard ML Basis Library](../README.md) &rsaquo; Input and output &rsaquo; **BIN_IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 3 of 3 entries documented |
| Tests | 25 checks of 3 entries |
| Source | [lib/basis/sig\_bin\_io.sml](../../../../lib/basis/sig_bin_io.sml) |

## Synopsis

```sml
signature BIN_IO
structure BinIO : BIN_IO
```

| Implementation |  | Source |
| --- | --- | --- |
| [`BinIO`](../str/BinIO.md) | BinIO: the imperative binary streams (signature BIN\_IO). | [lib/basis/binio.sml](../../../../lib/basis/binio.sml) |

Binary files: the imperative streams of bytes, with the ways of opening a
file.

It is [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md) over [`Word8.word`](../sig/WORD.md#type-word), with the same three `open`
functions as [`TEXT_IO`](../sig/TEXT_IO.md) and nothing else: there are no lines in a binary
file, no standard streams of bytes, and no `openString`.

## Interface

<pre>
signature BIN_IO =
sig
  include IMPERATIVE_IO
    where type StreamIO.vector = Word8Vector.vector
    where type StreamIO.elem = Word8.word
    where type StreamIO.reader = BinPrimIO.reader
    where type StreamIO.writer = BinPrimIO.writer
    where type StreamIO.pos = BinPrimIO.pos
  val <a href="#val-openin">openIn</a> : string -&gt; instream
  val <a href="#val-openout">openOut</a> : string -&gt; outstream
  val <a href="#val-openappend">openAppend</a> : string -&gt; outstream
end
</pre>

**Included from [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md)**: `include IMPERATIVE_IO
  where type StreamIO.vector = Word8Vector.vector
  where type StreamIO.elem = Word8.word
  where type StreamIO.reader = BinPrimIO.reader
  where type StreamIO.writer = BinPrimIO.writer
  where type StreamIO.pos = BinPrimIO.pos`

| Member |  |  |
| --- | --- | --- |
| [`StreamIO`](../sig/IMPERATIVE_IO.md#str-streamio) | structure | The functional streams these are built on. |
| [`vector`](../sig/IMPERATIVE_IO.md#type-vector) | type | The type of vectors of elements, the one of `StreamIO`. |
| [`elem`](../sig/IMPERATIVE_IO.md#type-elem) | type | The type of the elements, the one of `StreamIO`. |
| [`instream`](../sig/IMPERATIVE_IO.md#type-instream) | type | The type of the input streams. |
| [`outstream`](../sig/IMPERATIVE_IO.md#type-outstream) | type | The type of the output streams. |
| [`input`](../sig/IMPERATIVE_IO.md#val-input) | val | `input f` is the elements that are there without waiting for more, and moves `f` past them. |
| [`input1`](../sig/IMPERATIVE_IO.md#val-input1) | val | `input1 f` is `SOME` of the next element, or `NONE` at an end of stream. |
| [`inputN`](../sig/IMPERATIVE_IO.md#val-inputn) | val | `inputN (f, n)` is `n` elements, or all there are before the next end of stream. |
| [`inputAll`](../sig/IMPERATIVE_IO.md#val-inputall) | val | `inputAll f` is everything up to the next end of stream. |
| [`canInput`](../sig/IMPERATIVE_IO.md#val-caninput) | val | `canInput (f, n)` is how many of `n` elements, at most, can be read without waiting, or `NONE`. |
| [`lookahead`](../sig/IMPERATIVE_IO.md#val-lookahead) | val | `lookahead f` is `SOME` of the next element without removing it, or `NONE` at an end of stream. |
| [`closeIn`](../sig/IMPERATIVE_IO.md#val-closein) | val | `closeIn f` closes the stream and its reader. |
| [`endOfStream`](../sig/IMPERATIVE_IO.md#val-endofstream) | val | `endOfStream f` is `true` when nothing is left before the next end of stream. |
| [`output`](../sig/IMPERATIVE_IO.md#val-output) | val | `output (f, v)` writes the elements of `v`. |
| [`output1`](../sig/IMPERATIVE_IO.md#val-output1) | val | `output1 (f, x)` writes the single element `x`. |
| [`flushOut`](../sig/IMPERATIVE_IO.md#val-flushout) | val | `flushOut f` hands what the stream holds to its writer. |
| [`closeOut`](../sig/IMPERATIVE_IO.md#val-closeout) | val | `closeOut f` flushes the stream and closes it and its writer. |
| [`mkInstream`](../sig/IMPERATIVE_IO.md#val-mkinstream) | val | `mkInstream s` is an imperative stream holding the functional stream `s`. |
| [`getInstream`](../sig/IMPERATIVE_IO.md#val-getinstream) | val | `getInstream f` is the functional stream that `f` is at. |
| [`setInstream`](../sig/IMPERATIVE_IO.md#val-setinstream) | val | `setInstream (f, s)` makes `f` continue at `s`. |
| [`mkOutstream`](../sig/IMPERATIVE_IO.md#val-mkoutstream) | val | `mkOutstream s` is an imperative stream holding the functional stream `s`. |
| [`getOutstream`](../sig/IMPERATIVE_IO.md#val-getoutstream) | val | `getOutstream f` flushes `f` and is the functional stream underneath. |
| [`setOutstream`](../sig/IMPERATIVE_IO.md#val-setoutstream) | val | `setOutstream (f, s)` flushes what `f` holds and then makes it write to `s`. |
| [`getPosOut`](../sig/IMPERATIVE_IO.md#val-getposout) | val | `getPosOut f` flushes `f` and is the position it is now at. |
| [`setPosOut`](../sig/IMPERATIVE_IO.md#val-setposout) | val | `setPosOut (f, opos)` flushes `f` and moves it to the position `opos`. |

### <a name="val-openin"></a>`openIn`

```sml
val openIn : string -> instream
```

`openIn name` is a stream reading the bytes of the file `name` from its start.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the file cannot be opened, with the system's error as
the cause.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; another reading of the specification: reports the qualified name ("TextIO.openIn"); the test takes the unqualified name, as MLton and SML/NJ do

</details>

<details><summary>Tests (6)</summary>

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `reads-the-file` &middot; `Io-file-does-not-exist` (raises) &middot; `Io-name` &middot; `Io-function` &middot; `Io-cause` &middot; `does-not-create-the-file`

</details>

### <a name="val-openout"></a>`openOut`

```sml
val openOut : string -> outstream
```

`openOut name` is a stream writing the file `name`, which it empties or creates.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the file cannot be opened.

> **Implementation** `BinIO.openOut/bytes-are-characters`. A byte written
> here is the character of the same code read by [`TEXT_IO`](../sig/TEXT_IO.md), and the other
> way round: on POSIX nothing is translated between the two, for all 256
> values.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; another reading of the specification: reports the qualified name ("TextIO.openIn"); the test takes the unqualified name, as MLton and SML/NJ do

</details>

<details><summary>Tests (9)</summary>

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `creates-the-file` &middot; `truncates-an-existing-file` &middot; `truncates-at-open` &middot; `nothing-written` &middot; `Io-directory-does-not-exist` (raises) &middot; `Io-name` &middot; `Io-function` &middot; `Io-cause` &middot; `left-open-at-exit`

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

<details><summary>Tests (10)</summary>

For `BinIO`, in [tests/basis/binio.sml](../../../../tests/basis/binio.sml): `creates-the-file` &middot; `appends-to-an-existing-file` &middot; `keeps-the-contents` &middot; `three-times` &middot; `Io-directory-does-not-exist` (raises) &middot; `Io-name` &middot; `Io-function` &middot; `Io-cause` &middot; `Io-closed-stream` &middot; `random-pieces`

</details>

## See also

[`TEXT_IO`](../sig/TEXT_IO.md), [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md), [`STREAM_IO`](../sig/STREAM_IO.md), [`PRIM_IO`](../sig/PRIM_IO.md), [`BYTE`](../sig/BYTE.md)

---

<sub>Generated by runedoc from lib/basis/sig\_bin\_io.sml; do not edit.</sub>

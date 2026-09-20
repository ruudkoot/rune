# signature PRIM_IO

[The Standard ML Basis Library](../README.md) &rsaquo; Input and output &rsaquo; **PRIM_IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 4 |
| Documentation | 14 of 14 entries documented |
| Tests | 64 checks of 6 entries |
| Source | [lib/basis/primio\_sig.sml](../../../../lib/basis/primio_sig.sml) |

## Synopsis

```sml
signature PRIM_IO
structure BinPrimIO : PRIM_IO where type array = Word8Array.array where type vector = Word8Vector.vector where type elem = Word8.word where type pos = Position.int
functor PrimIO (...) : PRIM_IO  (* optional *)
structure TextPrimIO : PRIM_IO where type array = CharArray.array where type vector = CharVector.vector where type elem = Char.char
structure WideTextPrimIO : PRIM_IO  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `BinPrimIO` | BinPrimIO: readers and writers of bytes. | [lib/basis/binprimio.sml](../../../../lib/basis/binprimio.sml) |
| `PrimIO` | Readers and writers of a new element type: the [`PRIM_IO`](PRIM_IO.md) of it, built from the vectors, arrays and slices of that type. | [lib/basis/io\_functors.sml](../../../../lib/basis/io_functors.sml) |
| `TextPrimIO` | TextPrimIO: readers and writers of characters. | [lib/basis/textprimio.sml](../../../../lib/basis/textprimio.sml) |
| `WideTextPrimIO` | WideTextPrimIO and WideTextIO (optional in the specification): the readers, writers and imperative streams of the wide character. | [lib/basis/widetextio.sml](../../../../lib/basis/widetextio.sml) |

The layer under the streams: a reader is a source of elements, a writer a
sink for them, and both are records of the operations they happen to have.

A reader or a writer is a plain value that a program can make itself, out
of a file descriptor, a vector, a network connection or nothing at all.
Every operation is an [`option`](../sig/OPTION.md#type-option), because a source need not offer all of
them: a pipe cannot be positioned, a file cannot promise not to wait. What
is `NONE` is what the source cannot do; [`augmentReader`](#val-augmentreader) and
[`augmentWriter`](#val-augmentwriter) fill in what can be built from the rest.

`readVec`, `readArr`, `writeVec` and `writeArr` are the operations that
may wait; the ones whose names end in `NB` never wait and answer `NONE`
instead. `block` waits until a read or a write would not; `canInput` and
`canOutput` say whether it would. A read returns fewer elements than asked
for when fewer are there, and the empty vector, or 0, at the end of the
stream.

[`STREAM_IO`](../sig/STREAM_IO.md) is the layer above: it buffers, keeps what was read, and turns
what these raise into the `cause` of an [`IO.Io`](../sig/IO.md#exn-io).

> **Erratum** `PRIM_IO/pos-of-the-instances`. The specification
> leaves [`vector_slice`](#type-vector_slice) and [`array_slice`](#type-array_slice) abstract; in [`TextPrimIO`](PRIM_IO.md) and
> [`BinPrimIO`](PRIM_IO.md) they are the slice types of the corresponding structures,
> which is what every implementation does and what the suite relies on.

## Interface

<pre>
signature PRIM_IO =
sig
  type <a href="#type-elem">elem</a>

  type <a href="#type-vector">vector</a>

  type <a href="#type-vector_slice">vector_slice</a>

  type <a href="#type-array">array</a>

  type <a href="#type-array_slice">array_slice</a>

  eqtype <a href="#type-pos">pos</a>

  val <a href="#val-compare">compare</a> : pos * pos -&gt; order

  datatype <a href="#type-reader">reader</a> =
    <a href="#con-rd">RD</a> of {<a href="#fld-rd.name">name</a> : string,
           <a href="#fld-rd.chunksize">chunkSize</a> : int,
           <a href="#fld-rd.readvec">readVec</a> : (int -&gt; vector) option,
           <a href="#fld-rd.readarr">readArr</a> : (array_slice -&gt; int) option,
           <a href="#fld-rd.readvecnb">readVecNB</a> : (int -&gt; vector option) option,
           <a href="#fld-rd.readarrnb">readArrNB</a> : (array_slice -&gt; int option) option,
           <a href="#fld-rd.block">block</a> : (unit -&gt; unit) option,
           <a href="#fld-rd.caninput">canInput</a> : (unit -&gt; bool) option,
           <a href="#fld-rd.avail">avail</a> : unit -&gt; int option,
           <a href="#fld-rd.getpos">getPos</a> : (unit -&gt; pos) option,
           <a href="#fld-rd.setpos">setPos</a> : (pos -&gt; unit) option,
           <a href="#fld-rd.endpos">endPos</a> : (unit -&gt; pos) option,
           <a href="#fld-rd.verifypos">verifyPos</a> : (unit -&gt; pos) option,
           <a href="#fld-rd.close">close</a> : unit -&gt; unit,
           <a href="#fld-rd.iodesc">ioDesc</a> : RuneIODesc.iodesc option}

  datatype <a href="#type-writer">writer</a> =
    <a href="#con-wr">WR</a> of {<a href="#fld-wr.name">name</a> : string,
           <a href="#fld-wr.chunksize">chunkSize</a> : int,
           <a href="#fld-wr.writevec">writeVec</a> : (vector_slice -&gt; int) option,
           <a href="#fld-wr.writearr">writeArr</a> : (array_slice -&gt; int) option,
           <a href="#fld-wr.writevecnb">writeVecNB</a> : (vector_slice -&gt; int option) option,
           <a href="#fld-wr.writearrnb">writeArrNB</a> : (array_slice -&gt; int option) option,
           <a href="#fld-wr.block">block</a> : (unit -&gt; unit) option,
           <a href="#fld-wr.canoutput">canOutput</a> : (unit -&gt; bool) option,
           <a href="#fld-wr.getpos">getPos</a> : (unit -&gt; pos) option,
           <a href="#fld-wr.setpos">setPos</a> : (pos -&gt; unit) option,
           <a href="#fld-wr.endpos">endPos</a> : (unit -&gt; pos) option,
           <a href="#fld-wr.verifypos">verifyPos</a> : (unit -&gt; pos) option,
           <a href="#fld-wr.close">close</a> : unit -&gt; unit,
           <a href="#fld-wr.iodesc">ioDesc</a> : RuneIODesc.iodesc option}

  val <a href="#val-openvector">openVector</a> : vector -&gt; reader

  val <a href="#val-nullrd">nullRd</a> : unit -&gt; reader

  val <a href="#val-nullwr">nullWr</a> : unit -&gt; writer

  val <a href="#val-augmentreader">augmentReader</a> : reader -&gt; reader

  val <a href="#val-augmentwriter">augmentWriter</a> : writer -&gt; writer
end
</pre>

### <a name="type-elem"></a>`elem`

```sml
type elem
```

The type of the elements read and written.

### <a name="type-vector"></a>`vector`

```sml
type vector
```

The type of vectors of them: what a read returns and a write takes.

### <a name="type-vector_slice"></a>`vector_slice`

```sml
type vector_slice
```

The type of stretches of such a vector, which `writeVec` writes.

### <a name="type-array"></a>`array`

```sml
type array
```

The type of arrays of them: what `readArr` reads into.

### <a name="type-array_slice"></a>`array_slice`

```sml
type array_slice
```

The type of stretches of such an array, which `readArr` and `writeArr` work on.

### <a name="type-pos"></a>`pos`

```sml
eqtype pos
```

The type of positions in the source or the sink.

> **Implementation** `PRIM_IO.pos/of-the-instances`. [`BinPrimIO.pos`](#type-pos) is the
> integer type of `Position`, and a position is the offset of a byte from
> the start of the file, so [`compare`](#val-compare) is the order of those numbers.
> [`TextPrimIO.pos`](#type-pos) is abstract: a program can compare positions and give
> them back to `setPos`, and nothing more.

### <a name="val-compare"></a>`compare`

```sml
val compare : pos * pos -> order
```

`compare (p, q)` orders two positions: earlier in the stream is less.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; after input1, inputLine, lookahead, endOfStream or canInput, inputAll returns the rest of the stream without consuming it: the same elements are read again

</details>

<details><summary>Tests (6)</summary>

For `TextPrimIO`, in [tests/basis/textio\_streamio.sml](../../../../tests/basis/textio_streamio.sml): `file-positions`

For `BinPrimIO`, in [tests/basis/io\_primio.sml](../../../../tests/basis/io_primio.sml): `less` &middot; `equal` &middot; `greater` &middot; `linear-order-*`

For `WideTextPrimIO`, in [tests/basis/widetextio\_sig.sml](../../../../tests/basis/widetextio_sig.sml): `of-positions`

</details>

### <a name="type-reader"></a>`reader`

```sml
datatype reader =
  RD of {name : string,
         chunkSize : int,
         readVec : (int -> vector) option,
         readArr : (array_slice -> int) option,
         readVecNB : (int -> vector option) option,
         readArrNB : (array_slice -> int option) option,
         block : (unit -> unit) option,
         canInput : (unit -> bool) option,
         avail : unit -> int option,
         getPos : (unit -> pos) option,
         setPos : (pos -> unit) option,
         endPos : (unit -> pos) option,
         verifyPos : (unit -> pos) option,
         close : unit -> unit,
         ioDesc : RuneIODesc.iodesc option}
```

A source of elements: its name, how much it likes to be read at a time, and the operations it has.

`readVec n` reads at most `n` elements and waits for at least one;
`readArr sl` reads into a stretch of an array and gives the number of
elements read; the `NB` pair do the same without waiting, and answer
`NONE` when they would have to. `block` waits until a read would not.
`canInput` says whether one would wait. `avail` is how many elements are
there without waiting, or `NONE` when that cannot be told. `getPos`,
`setPos`, `endPos` and `verifyPos` are the positions; `close` releases
the source; `ioDesc` is the descriptor the operating system knows it by,
for [`OS.IO.poll`](../sig/OS_IO.md#val-poll).

> **Reading** `PRIM_IO.reader/after-close`. Once `close` has been called,
> every function of the reader but `close` and `getPos` raises [`IO.Io`](../sig/IO.md#exn-io)
> with the cause [`IO.ClosedStream`](../sig/IO.md#exn-closedstream). The specification says both that and
> "raise [`IO.ClosedStream`](../sig/IO.md#exn-closedstream)", so the suite accepts either from a reader
> that Rune did not make.

> **Implementation** `PRIM_IO.reader/what-a-file-has`. The readers Rune makes
> for a file offer `readVec`, `avail`, `close` and `ioDesc`, and the
> positions only when the file has them; [`augmentReader`](#val-augmentreader) derives the rest
> that can be derived.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-rd"></a>`RD` | `{name : string, chunkSize : int, readVec : (int -> vector) option, readArr : (array_slice -> int) option, readVecNB : (int -> vector option) option, readArrNB : (array_slice -> int option) option, block : (unit -> unit) option, canInput : (unit -> bool) option, avail : unit -> int option, getPos : (unit -> pos) option, setPos : (pos -> unit) option, endPos : (unit -> pos) option, verifyPos : (unit -> pos) option, close : unit -> unit, ioDesc : RuneIODesc.iodesc option}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.name"></a>`name` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.chunksize"></a>`chunkSize` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.readvec"></a>`readVec` | `(int -> vector) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.readarr"></a>`readArr` | `(array_slice -> int) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.readvecnb"></a>`readVecNB` | `(int -> vector option) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.readarrnb"></a>`readArrNB` | `(array_slice -> int option) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.block"></a>`block` | `(unit -> unit) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.caninput"></a>`canInput` | `(unit -> bool) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.avail"></a>`avail` | `unit -> int option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.getpos"></a>`getPos` | `(unit -> pos) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.setpos"></a>`setPos` | `(pos -> unit) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.endpos"></a>`endPos` | `(unit -> pos) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.verifypos"></a>`verifyPos` | `(unit -> pos) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.close"></a>`close` | `unit -> unit` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-rd.iodesc"></a>`ioDesc` | `RuneIODesc.iodesc option` |  |

### <a name="type-writer"></a>`writer`

```sml
datatype writer =
  WR of {name : string,
         chunkSize : int,
         writeVec : (vector_slice -> int) option,
         writeArr : (array_slice -> int) option,
         writeVecNB : (vector_slice -> int option) option,
         writeArrNB : (array_slice -> int option) option,
         block : (unit -> unit) option,
         canOutput : (unit -> bool) option,
         getPos : (unit -> pos) option,
         setPos : (pos -> unit) option,
         endPos : (unit -> pos) option,
         verifyPos : (unit -> pos) option,
         close : unit -> unit,
         ioDesc : RuneIODesc.iodesc option}
```

A sink for elements, with the operations of a reader turned around.

`writeVec sl` and `writeArr sl` write a stretch and give the number of
elements written, which may be fewer than the stretch holds; the caller
writes the rest. The `NB` pair never wait. `canOutput` says whether a
write would wait. The positions and `close` are as for a reader, and
`ioDesc` is again the descriptor.

> **Reading** `PRIM_IO.writer/after-close`. Once `close` has been called,
> every function of the writer but `close` raises [`IO.Io`](../sig/IO.md#exn-io) with the cause
> [`IO.ClosedStream`](../sig/IO.md#exn-closedstream).

> **Reading** `PRIM_IO.writer/partial-writes`. A write may write only part of
> what it was given; [`STREAM_IO`](../sig/STREAM_IO.md) retries until everything is written.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-wr"></a>`WR` | `{name : string, chunkSize : int, writeVec : (vector_slice -> int) option, writeArr : (array_slice -> int) option, writeVecNB : (vector_slice -> int option) option, writeArrNB : (array_slice -> int option) option, block : (unit -> unit) option, canOutput : (unit -> bool) option, getPos : (unit -> pos) option, setPos : (pos -> unit) option, endPos : (unit -> pos) option, verifyPos : (unit -> pos) option, close : unit -> unit, ioDesc : RuneIODesc.iodesc option}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.name"></a>`name` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.chunksize"></a>`chunkSize` | `int` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.writevec"></a>`writeVec` | `(vector_slice -> int) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.writearr"></a>`writeArr` | `(array_slice -> int) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.writevecnb"></a>`writeVecNB` | `(vector_slice -> int option) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.writearrnb"></a>`writeArrNB` | `(array_slice -> int option) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.block"></a>`block` | `(unit -> unit) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.canoutput"></a>`canOutput` | `(unit -> bool) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.getpos"></a>`getPos` | `(unit -> pos) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.setpos"></a>`setPos` | `(pos -> unit) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.endpos"></a>`endPos` | `(unit -> pos) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.verifypos"></a>`verifyPos` | `(unit -> pos) option` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.close"></a>`close` | `unit -> unit` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-wr.iodesc"></a>`ioDesc` | `RuneIODesc.iodesc option` |  |

### <a name="val-openvector"></a>`openVector`

```sml
val openVector : vector -> reader
```

`openVector v` is a reader that delivers the elements of `v` and is then at the end of its stream.

The data are there already, so the reader has every read operation and
waits for nothing; its `name` is `"<vector>"`.

> **Reading** `PrimIO.openVector/readVecNB-is-there`. Nothing has to be
> waited for, so `readVecNB` is present and always `SOME`, with `SOME` of
> the empty vector once the vector is spent.

<details><summary>Tests (14)</summary>

For `WideTextPrimIO`, in [tests/basis/widetextio\_sig.sml](../../../../tests/basis/widetextio_sig.sml): `reads-a-wide-string`

In [tests/basis/fn/prim\_io\_fn.sml](../../../../tests/basis/fn/prim_io_fn.sml), applied to `TextPrimIO`, `BinPrimIO`: `content` &middot; `readVec-pieces` &middot; `readVec-zero` &middot; `empty` &middot; `readArr` &middot; `readArr-empty-slice` &middot; `chunkSize-positive` &middot; `avail` &middot; `readVecNB` &middot; `readVec-after-close` (raises) &middot; `readArr-after-close` (raises) &middot; `avail-after-close` (raises) &middot; `close-twice`

</details>

### <a name="val-nullrd"></a>`nullRd`

```sml
val nullRd : unit -> reader
```

`nullRd ()` is a reader that is at the end of its stream from the start.

> **Reading** `PrimIO.nullRd/is-a-closed-source`. It "acts like a reader that
> is always at end-of-stream": every read gives nothing and waits for
> nothing, it has no positions, and once closed it behaves as any other
> closed reader.

<details><summary>Tests (8)</summary>

For `WideTextPrimIO`, in [tests/basis/widetextio\_sig.sml](../../../../tests/basis/widetextio_sig.sml): `reads-nothing`

In [tests/basis/fn/prim\_io\_fn.sml](../../../../tests/basis/fn/prim_io_fn.sml), applied to `TextPrimIO`, `BinPrimIO`: `always-at-end-of-stream` &middot; `readArr` &middot; `readVecNB` &middot; `chunkSize-positive` &middot; `readVec-after-close` (raises) &middot; `close-twice` &middot; `independent`

</details>

### <a name="val-nullwr"></a>`nullWr`

```sml
val nullWr : unit -> writer
```

`nullWr ()` is a writer that accepts everything and keeps nothing.

> **Reading** `PrimIO.nullWr/is-a-sink`. It "serves as a sink": every write
> reports that it wrote all it was given, and once closed it behaves as
> any other closed writer.

<details><summary>Tests (6)</summary>

For `WideTextPrimIO`, in [tests/basis/widetextio\_sig.sml](../../../../tests/basis/widetextio_sig.sml): `takes-everything`

In [tests/basis/fn/prim\_io\_fn.sml](../../../../tests/basis/fn/prim_io_fn.sml), applied to `TextPrimIO`, `BinPrimIO`: `takes-everything` &middot; `writeVecNB` &middot; `chunkSize-positive` &middot; `writeVec-after-close` (raises) &middot; `close-twice`

</details>

### <a name="val-augmentreader"></a>`augmentReader`

```sml
val augmentReader : reader -> reader
```

`augmentReader rd` is `rd` with the read operations that can be built from the ones it has.

A vector read becomes an array read by copying and the other way round;
a blocking read is a non-blocking one done after `block`; a
non-blocking read is a blocking one that `canInput` says will not wait.
An operation the reader already has is kept as it is, and the fields
that are not reads are unchanged.

> **Reading** `PrimIO.augmentReader/what-cannot-be-built`. What the table
> does not reach stays `NONE`: there is no non-blocking read without
> `canInput` or an `NB` operation to build it from, and no blocking read
> without `block` or a blocking operation.

<details><summary>Tests (16)</summary>

For `WideTextPrimIO`, in [tests/basis/widetextio\_sig.sml](../../../../tests/basis/widetextio_sig.sml): `adds-what-the-reader-lacks`

In [tests/basis/fn/prim\_io\_fn.sml](../../../../tests/basis/fn/prim_io_fn.sml), applied to `TextPrimIO`, `BinPrimIO`: `keeps-what-the-reader-has` &middot; `keeps-the-other-fields` &middot; `readVec-from-readArr` &middot; `readVec-from-block-and-readVecNB` &middot; `readVec-from-block-and-readArrNB` &middot; `readArr-from-readVec` &middot; `readArr-from-block-and-readArrNB` &middot; `readArr-from-block-and-readVecNB` &middot; `readVecNB-from-readArrNB` &middot; `readVecNB-from-canInput-and-readVec` &middot; `readVecNB-from-canInput-and-readArr` &middot; `readArrNB-from-readVecNB` &middot; `readArrNB-from-canInput-and-readVec` &middot; `no-readVecNB-from-readVec-alone` &middot; `no-readVec-from-readVecNB-alone`

</details>

### <a name="val-augmentwriter"></a>`augmentWriter`

```sml
val augmentWriter : writer -> writer
```

`augmentWriter wr` is `wr` with the write operations that can be built from the ones it has.

> **Implementation** `PrimIO.augmentWriter/the-whole-table`. The same table
> as for a reader, turned around: every row of it is built, an operation
> the writer has is kept as it is, and what cannot be reached stays
> `NONE`.

<details><summary>Tests (14)</summary>

For `WideTextPrimIO`, in [tests/basis/widetextio\_sig.sml](../../../../tests/basis/widetextio_sig.sml): `adds-what-the-writer-lacks`

In [tests/basis/fn/prim\_io\_fn.sml](../../../../tests/basis/fn/prim_io_fn.sml), applied to `TextPrimIO`, `BinPrimIO`: `keeps-what-the-writer-has` &middot; `keeps-the-other-fields` &middot; `writeVec-from-writeArr` &middot; `writeArr-from-writeVec` &middot; `writeVec-from-block-and-writeVecNB` &middot; `writeVec-from-block-and-writeArrNB` &middot; `writeArr-from-block-and-writeVecNB` &middot; `writeVecNB-from-writeArrNB` &middot; `writeVecNB-from-canOutput-and-writeVec` &middot; `writeArrNB-from-writeVecNB` &middot; `writeArrNB-from-canOutput-and-writeArr` &middot; `no-writeVecNB-from-writeVec-alone` &middot; `no-writeVec-from-writeVecNB-alone`

</details>

## See also

[`IO`](../sig/IO.md), [`STREAM_IO`](../sig/STREAM_IO.md), [`TEXT_IO`](../sig/TEXT_IO.md), [`BIN_IO`](../sig/BIN_IO.md), [`POSIX_IO`](../sig/POSIX_IO.md)

---

<sub>Generated by runedoc from lib/basis/primio\_sig.sml; do not edit.</sub>

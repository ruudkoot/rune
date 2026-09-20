# signature PRIM_IO

[The Standard ML Basis Library](../README.md) &rsaquo; **PRIM_IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 4 |
| Documentation | 0 of 14 entries documented |
| Source | [lib/basis/primio\_sig.sml](../../../../lib/basis/primio_sig.sml) |

## Synopsis

```sml
signature PRIM_IO
structure BinPrimIO : PRIM_IO where type array = Word8Array.array where type vector = Word8Vector.vector where type elem = Word8.word where type pos = Position.int
functor PrimIO (...) : PRIM_IO
structure TextPrimIO : PRIM_IO where type array = CharArray.array where type vector = CharVector.vector where type elem = Char.char
structure WideTextPrimIO : PRIM_IO  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `BinPrimIO` | BinPrimIO: readers and writers of bytes. | [lib/basis/binprimio.sml](../../../../lib/basis/binprimio.sml) |
| `PrimIO` | The optional functors of the specification that build the I/O stack for other element types: PrimIO, StreamIO and ImperativeIO, on the functors TextIO and BinIO are made of. | [lib/basis/io\_functors.sml](../../../../lib/basis/io_functors.sml) |
| `TextPrimIO` | TextPrimIO: readers and writers of characters. | [lib/basis/textprimio.sml](../../../../lib/basis/textprimio.sml) |
| `WideTextPrimIO` | WideTextPrimIO and WideTextIO (optional in the specification): the readers, writers and imperative streams of the wide character. | [lib/basis/widetextio.sml](../../../../lib/basis/widetextio.sml) |

signature PRIM\_IO: the readers and writers under the stream layer.

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

### <a name="type-vector"></a>`vector`

```sml
type vector
```

### <a name="type-vector_slice"></a>`vector_slice`

```sml
type vector_slice
```

### <a name="type-array"></a>`array`

```sml
type array
```

### <a name="type-array_slice"></a>`array_slice`

```sml
type array_slice
```

### <a name="type-pos"></a>`pos`

```sml
eqtype pos
```

### <a name="val-compare"></a>`compare`

```sml
val compare : pos * pos -> order
```

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

### <a name="val-nullrd"></a>`nullRd`

```sml
val nullRd : unit -> reader
```

### <a name="val-nullwr"></a>`nullWr`

```sml
val nullWr : unit -> writer
```

### <a name="val-augmentreader"></a>`augmentReader`

```sml
val augmentReader : reader -> reader
```

### <a name="val-augmentwriter"></a>`augmentWriter`

```sml
val augmentWriter : writer -> writer
```

---

<sub>Generated by runedoc from lib/basis/primio\_sig.sml; do not edit.</sub>

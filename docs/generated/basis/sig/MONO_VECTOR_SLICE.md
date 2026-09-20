# signature MONO_VECTOR_SLICE

[The Standard ML Basis Library](../README.md) &rsaquo; **MONO_VECTOR_SLICE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 19 |
| Documentation | 0 of 26 entries documented |
| Source | [lib/basis/mono\_sigs.sml](../../../../lib/basis/mono_sigs.sml) |

## Synopsis

```sml
signature MONO_VECTOR_SLICE
structure BoolVectorSlice : MONO_VECTOR_SLICE where type vector = BoolVector.vector where type elem = bool  (* optional *)
structure CharVectorSlice : MONO_VECTOR_SLICE where type slice = Substring.substring where type vector = String.string where type elem = char
structure Int16VectorSlice : MONO_VECTOR_SLICE where type vector = Int16Vector.vector where type elem = Int16.int  (* optional *)
structure Int32VectorSlice : MONO_VECTOR_SLICE where type vector = Int32Vector.vector where type elem = Int32.int  (* optional *)
structure Int64VectorSlice : MONO_VECTOR_SLICE where type vector = Int64Vector.vector where type elem = Int64.int  (* optional *)
structure Int8VectorSlice : MONO_VECTOR_SLICE where type vector = Int8Vector.vector where type elem = Int8.int  (* optional *)
structure IntVectorSlice : MONO_VECTOR_SLICE where type vector = IntVector.vector where type elem = int  (* optional *)
structure LargeIntVectorSlice : MONO_VECTOR_SLICE where type vector = LargeIntVector.vector where type elem = LargeInt.int  (* optional *)
structure LargeRealVectorSlice : MONO_VECTOR_SLICE where type vector = LargeRealVector.vector where type elem = LargeReal.real  (* optional *)
structure LargeWordVectorSlice : MONO_VECTOR_SLICE where type vector = LargeWordVector.vector where type elem = LargeWord.word  (* optional *)
structure Real32VectorSlice : MONO_VECTOR_SLICE where type vector = Real32Vector.vector where type elem = Real32.real  (* optional *)
structure Real64VectorSlice : MONO_VECTOR_SLICE where type vector = Real64Vector.vector where type elem = Real64.real  (* optional *)
structure RealVectorSlice : MONO_VECTOR_SLICE where type vector = RealVector.vector where type elem = real  (* optional *)
structure WideCharVectorSlice : MONO_VECTOR_SLICE where type vector = WideCharVector.vector where type elem = WideChar.char  (* optional *)
structure Word16VectorSlice : MONO_VECTOR_SLICE where type vector = Word16Vector.vector where type elem = Word16.word  (* optional *)
structure Word32VectorSlice : MONO_VECTOR_SLICE where type vector = Word32Vector.vector where type elem = Word32.word  (* optional *)
structure Word64VectorSlice : MONO_VECTOR_SLICE where type vector = Word64Vector.vector where type elem = Word64.word  (* optional *)
structure Word8VectorSlice : MONO_VECTOR_SLICE where type vector = Word8Vector.vector where type elem = Word8.word
structure WordVectorSlice : MONO_VECTOR_SLICE where type vector = WordVector.vector where type elem = word  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `BoolVectorSlice` |  | [lib/basis/mono\_bool.sml](../../../../lib/basis/mono_bool.sml) |
| `CharVectorSlice` | CharVectorSlice: its slice is the substring of Substring, so it is written on Substring rather than being an instance of RuneMonoVectorSliceFn. The \-i functions pass the index in the slice. | [lib/basis/charvectorslice.sml](../../../../lib/basis/charvectorslice.sml) |
| `Int16VectorSlice` |  | [lib/basis/mono\_int16.sml](../../../../lib/basis/mono_int16.sml) |
| `Int32VectorSlice` |  | [lib/basis/mono\_int32.sml](../../../../lib/basis/mono_int32.sml) |
| `Int64VectorSlice` |  | [lib/basis/mono\_int64.sml](../../../../lib/basis/mono_int64.sml) |
| `Int8VectorSlice` |  | [lib/basis/mono\_int8.sml](../../../../lib/basis/mono_int8.sml) |
| `IntVectorSlice` |  | [lib/basis/mono\_int.sml](../../../../lib/basis/mono_int.sml) |
| `LargeIntVectorSlice` |  | [lib/basis/mono\_largeint.sml](../../../../lib/basis/mono_largeint.sml) |
| `LargeRealVectorSlice` |  | [lib/basis/mono\_largereal.sml](../../../../lib/basis/mono_largereal.sml) |
| `LargeWordVectorSlice` |  | [lib/basis/mono\_largeword.sml](../../../../lib/basis/mono_largeword.sml) |
| `Real32VectorSlice` |  | [lib/basis/mono\_real32.sml](../../../../lib/basis/mono_real32.sml) |
| `Real64VectorSlice` |  | [lib/basis/mono\_real64.sml](../../../../lib/basis/mono_real64.sml) |
| `RealVectorSlice` |  | [lib/basis/mono\_real.sml](../../../../lib/basis/mono_real.sml) |
| `WideCharVectorSlice` |  | [lib/basis/widechar.sml](../../../../lib/basis/widechar.sml) |
| `Word16VectorSlice` |  | [lib/basis/mono\_word16.sml](../../../../lib/basis/mono_word16.sml) |
| `Word32VectorSlice` |  | [lib/basis/mono\_word32.sml](../../../../lib/basis/mono_word32.sml) |
| `Word64VectorSlice` |  | [lib/basis/mono\_word64.sml](../../../../lib/basis/mono_word64.sml) |
| `Word8VectorSlice` | Word8VectorSlice: a Word8Vector.vector is a string, so a slice of one is a substring, and taking its vector is one primitive rather than a walk over the elements. | [lib/basis/word8vectorslice.sml](../../../../lib/basis/word8vectorslice.sml) |
| `WordVectorSlice` |  | [lib/basis/mono\_word.sml](../../../../lib/basis/mono_word.sml) |

## Interface

<pre>
signature MONO_VECTOR_SLICE =
sig
  type <a href="#type-elem">elem</a>
  type <a href="#type-vector">vector</a>
  type <a href="#type-slice">slice</a>
  val <a href="#val-length">length</a> : slice -&gt; int
  val <a href="#val-sub">sub</a> : slice * int -&gt; elem
  val <a href="#val-full">full</a> : vector -&gt; slice
  val <a href="#val-slice">slice</a> : vector * int * int option -&gt; slice
  val <a href="#val-subslice">subslice</a> : slice * int * int option -&gt; slice
  val <a href="#val-base">base</a> : slice -&gt; vector * int * int
  val <a href="#val-vector">vector</a> : slice -&gt; vector
  val <a href="#val-concat">concat</a> : slice list -&gt; vector
  val <a href="#val-isempty">isEmpty</a> : slice -&gt; bool
  val <a href="#val-getitem">getItem</a> : slice -&gt; (elem * slice) option
  val <a href="#val-appi">appi</a> : (int * elem -&gt; unit) -&gt; slice -&gt; unit
  val <a href="#val-app">app</a> : (elem -&gt; unit) -&gt; slice -&gt; unit
  val <a href="#val-mapi">mapi</a> : (int * elem -&gt; elem) -&gt; slice -&gt; vector
  val <a href="#val-map">map</a> : (elem -&gt; elem) -&gt; slice -&gt; vector
  val <a href="#val-foldli">foldli</a> : (int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; slice -&gt; 'b
  val <a href="#val-foldr">foldr</a> : (elem * 'b -&gt; 'b) -&gt; 'b -&gt; slice -&gt; 'b
  val <a href="#val-foldl">foldl</a> : (elem * 'b -&gt; 'b) -&gt; 'b -&gt; slice -&gt; 'b
  val <a href="#val-foldri">foldri</a> : (int * elem * 'b -&gt; 'b) -&gt; 'b -&gt; slice -&gt; 'b
  val <a href="#val-findi">findi</a> : (int * elem -&gt; bool) -&gt; slice -&gt; (int * elem) option
  val <a href="#val-find">find</a> : (elem -&gt; bool) -&gt; slice -&gt; elem option
  val <a href="#val-exists">exists</a> : (elem -&gt; bool) -&gt; slice -&gt; bool
  val <a href="#val-all">all</a> : (elem -&gt; bool) -&gt; slice -&gt; bool
  val <a href="#val-collate">collate</a> : (elem * elem -&gt; order) -&gt; slice * slice -&gt; order
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

### <a name="type-slice"></a>`slice`

```sml
type slice
```

### <a name="val-length"></a>`length`

```sml
val length : slice -> int
```

### <a name="val-sub"></a>`sub`

```sml
val sub : slice * int -> elem
```

### <a name="val-full"></a>`full`

```sml
val full : vector -> slice
```

### <a name="val-slice"></a>`slice`

```sml
val slice : vector * int * int option -> slice
```

### <a name="val-subslice"></a>`subslice`

```sml
val subslice : slice * int * int option -> slice
```

### <a name="val-base"></a>`base`

```sml
val base : slice -> vector * int * int
```

### <a name="val-vector"></a>`vector`

```sml
val vector : slice -> vector
```

### <a name="val-concat"></a>`concat`

```sml
val concat : slice list -> vector
```

### <a name="val-isempty"></a>`isEmpty`

```sml
val isEmpty : slice -> bool
```

### <a name="val-getitem"></a>`getItem`

```sml
val getItem : slice -> (elem * slice) option
```

### <a name="val-appi"></a>`appi`

```sml
val appi : (int * elem -> unit) -> slice -> unit
```

### <a name="val-app"></a>`app`

```sml
val app : (elem -> unit) -> slice -> unit
```

### <a name="val-mapi"></a>`mapi`

```sml
val mapi : (int * elem -> elem) -> slice -> vector
```

### <a name="val-map"></a>`map`

```sml
val map : (elem -> elem) -> slice -> vector
```

### <a name="val-foldli"></a>`foldli`

```sml
val foldli : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
```

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (elem * 'b -> 'b) -> 'b -> slice -> 'b
```

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (elem * 'b -> 'b) -> 'b -> slice -> 'b
```

### <a name="val-foldri"></a>`foldri`

```sml
val foldri : (int * elem * 'b -> 'b) -> 'b -> slice -> 'b
```

### <a name="val-findi"></a>`findi`

```sml
val findi : (int * elem -> bool) -> slice -> (int * elem) option
```

### <a name="val-find"></a>`find`

```sml
val find : (elem -> bool) -> slice -> elem option
```

### <a name="val-exists"></a>`exists`

```sml
val exists : (elem -> bool) -> slice -> bool
```

### <a name="val-all"></a>`all`

```sml
val all : (elem -> bool) -> slice -> bool
```

### <a name="val-collate"></a>`collate`

```sml
val collate : (elem * elem -> order) -> slice * slice -> order
```

---

<sub>Generated by runedoc from lib/basis/mono\_sigs.sml; do not edit.</sub>

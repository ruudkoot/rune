# signature PACK_WORD

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; **PACK_WORD**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 6 |
| Documentation | 7 of 7 entries documented |
| Tests | 26 checks of 7 entries |
| Source | [lib/basis/sig\_pack\_word.sml](../../../../lib/basis/sig_pack_word.sml) |

## Synopsis

```sml
signature PACK_WORD
structure PackWord16Big : PACK_WORD  (* optional *)
structure PackWord16Little : PACK_WORD  (* optional *)
structure PackWord32Big : PACK_WORD  (* optional *)
structure PackWord32Little : PACK_WORD  (* optional *)
structure PackWord64Big : PACK_WORD  (* optional *)
structure PackWord64Little : PACK_WORD  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| [`PackWord16Big`](../str/PackWord16Big.md) |  | [lib/basis/pack\_word.sml](../../../../lib/basis/pack_word.sml) |
| [`PackWord16Little`](../str/PackWord16Little.md) |  | [lib/basis/pack\_word.sml](../../../../lib/basis/pack_word.sml) |
| [`PackWord32Big`](../str/PackWord32Big.md) |  | [lib/basis/pack\_word.sml](../../../../lib/basis/pack_word.sml) |
| [`PackWord32Little`](../str/PackWord32Little.md) |  | [lib/basis/pack\_word.sml](../../../../lib/basis/pack_word.sml) |
| [`PackWord64Big`](../str/PackWord64Big.md) |  | [lib/basis/pack\_word.sml](../../../../lib/basis/pack_word.sml) |
| [`PackWord64Little`](../str/PackWord64Little.md) |  | [lib/basis/pack\_word.sml](../../../../lib/basis/pack_word.sml) |

Reading and writing a word in a vector or an array of bytes, in a fixed
byte order.

A structure of this signature packs words of [`bytesPerElem`](#val-bytesperelem) bytes: the
name says how many bits and which end comes first, so [`PackWord32Big`](../str/PackWord32Big.md) puts
the most significant byte first and [`PackWord32Little`](../str/PackWord32Little.md) the least. This is
what a program uses to read a binary file or a protocol whose layout is
given in bytes, whatever the byte order of the machine it runs on.

Positions are counted in words, not in bytes: element `i` of a vector is
the bytes from `bytesPerElem * i` on.

> **Implementation** `PackWord/sizes`. The library has `PackWord16`,
> `PackWord32` and `PackWord64`, each `Big` and `Little`.

## Interface

<pre>
signature PACK_WORD =
sig
  val <a href="#val-bytesperelem">bytesPerElem</a> : int
  val <a href="#val-isbigendian">isBigEndian</a> : bool
  val <a href="#val-subvec">subVec</a> : Word8Vector.vector * int -&gt; LargeWord.word
  val <a href="#val-subvecx">subVecX</a> : Word8Vector.vector * int -&gt; LargeWord.word
  val <a href="#val-subarr">subArr</a> : Word8Array.array * int -&gt; LargeWord.word
  val <a href="#val-subarrx">subArrX</a> : Word8Array.array * int -&gt; LargeWord.word
  val <a href="#val-update">update</a> : Word8Array.array * int * LargeWord.word -&gt; unit
end
</pre>

### <a name="val-bytesperelem"></a>`bytesPerElem`

```sml
val bytesPerElem : int
```

The number of bytes of one word.

**Example** `PackWord32Big.bytesPerElem = 4`

<details><summary>Tests (1)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `value`

</details>

### <a name="val-isbigendian"></a>`isBigEndian`

```sml
val isBigEndian : bool
```

Whether the most significant byte comes first.

<details><summary>Tests (1)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `value`

</details>

### <a name="val-subvec"></a>`subVec`

```sml
val subVec : Word8Vector.vector * int -> LargeWord.word
```

`subVec (v, i)` is the word at position `i` of the byte vector `v`, with zeros in the bits above it.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or if the bytes of element `i` are not
all in `v`.

> **Reading** `PackWord.subVec/Subscript-not-Overflow`. The bound is tested
> without the product `bytesPerElem * (i + 1)`, so a huge `i` raises
> [`Subscript`](../sig/GENERAL.md#exn-subscript) and not [`Overflow`](../sig/GENERAL.md#exn-overflow).

**Example** `PackWord16Big.subVec (Word8Vector.fromList [0w1, 0w2], 0) = 0wx102`

**Example** `PackWord16Little.subVec (Word8Vector.fromList [0w1, 0w2, 0w3, 0w4], 1) = 0wx403` for the index counts elements of two bytes, not bytes.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; subVec, subVecX, subArr, subArrX and update raise Overflow for an index near the largest int (bytesPerElem \* (i + 1) overflows), not Subscript

</details>

<details><summary>Tests (6)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `element-*` &middot; `high-element-*` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-partial-element` (raises) &middot; `Subscript-maxInt` (raises)

</details>

### <a name="val-subvecx"></a>`subVecX`

```sml
val subVecX : Word8Vector.vector * int -> LargeWord.word
```

`subVecX (v, i)` is the word at position `i` of `v`, with its top bit copied into the bits above it.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if the bytes of element `i` are not all in `v`.

**Example** `PackWord16Big.subVecX (Word8Vector.fromList [0wxFF, 0wxFE], 0) = 0wxFFFFFFFFFFFFFFFE`

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; subVec, subVecX, subArr, subArrX and update raise Overflow for an index near the largest int (bytesPerElem \* (i + 1) overflows), not Subscript

</details>

<details><summary>Tests (4)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `sign-extended-*` &middot; `non-negative-*` &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

</details>

### <a name="val-subarr"></a>`subArr`

```sml
val subArr : Word8Array.array * int -> LargeWord.word
```

`subArr (arr, i)` is the word at position `i` of the byte array `arr`, with zeros above it.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if the bytes of element `i` are not all in `arr`.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; subVec, subVecX, subArr, subArrX and update raise Overflow for an index near the largest int (bytesPerElem \* (i + 1) overflows), not Subscript

</details>

<details><summary>Tests (5)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `element-*` &middot; `high-element-*` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

</details>

### <a name="val-subarrx"></a>`subArrX`

```sml
val subArrX : Word8Array.array * int -> LargeWord.word
```

`subArrX (arr, i)` is the word at position `i` of `arr`, with its top bit copied into the bits above it.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if the bytes of element `i` are not all in `arr`.

<details><summary>Other implementations (1)</summary>

- **Poly/ML** &mdash; subVec, subVecX, subArr, subArrX and update raise Overflow for an index near the largest int (bytesPerElem \* (i + 1) overflows), not Subscript

</details>

<details><summary>Tests (4)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `sign-extended-*` &middot; `non-negative-*` &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

</details>

### <a name="val-update"></a>`update`

```sml
val update : Word8Array.array * int * LargeWord.word -> unit
```

`update (arr, i, w)` writes the low [`bytesPerElem`](#val-bytesperelem) bytes of `w` at position `i` of `arr`.

What does not fit in that many bytes is dropped.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if the bytes of element `i` are not all in `arr`.

**Example** `let val a = Word8Array.array (2, 0w0) in PackWord16Big.update (a, 0, 0wx1234); Word8Array.vector a end = Word8Vector.fromList [0wx12, 0wx34]`

<details><summary>Other implementations (2)</summary>

- **Poly/ML** &mdash; subVec, subVecX, subArr, subArrX and update raise Overflow for an index near the largest int (bytesPerElem \* (i + 1) overflows), not Subscript
- **SML/NJ (32-bit)** &mdash; update writes the wrong bytes: the low half of the word for PackWord64, and the second byte of a PackWord16 or PackWord32 element unchanged

</details>

<details><summary>Tests (5)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `element-1` &middot; `read-back` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

</details>

## See also

[`WORD`](../sig/WORD.md), [`PACK_REAL`](../sig/PACK_REAL.md), [`BYTE`](../sig/BYTE.md), [`MONO_VECTOR`](../sig/MONO_VECTOR.md)

---

<sub>Generated by runedoc from lib/basis/sig\_pack\_word.sml; do not edit.</sub>

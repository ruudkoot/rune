# signature PACK_WORD

[The Standard ML Basis Library](../README.md) &rsaquo; **PACK_WORD**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 6 |
| Documentation | 0 of 7 entries documented |
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
| `PackWord16Big` |  | [lib/basis/pack\_word.sml](../../../../lib/basis/pack_word.sml) |
| `PackWord16Little` |  | [lib/basis/pack\_word.sml](../../../../lib/basis/pack_word.sml) |
| `PackWord32Big` |  | [lib/basis/pack\_word.sml](../../../../lib/basis/pack_word.sml) |
| `PackWord32Little` |  | [lib/basis/pack\_word.sml](../../../../lib/basis/pack_word.sml) |
| `PackWord64Big` |  | [lib/basis/pack\_word.sml](../../../../lib/basis/pack_word.sml) |
| `PackWord64Little` |  | [lib/basis/pack\_word.sml](../../../../lib/basis/pack_word.sml) |

signature PACK\_WORD, transcribed from <https://smlfamily.github.io/Basis/pack-word.html>

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

<details><summary>Tests (1)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `value`

</details>

### <a name="val-isbigendian"></a>`isBigEndian`

```sml
val isBigEndian : bool
```

<details><summary>Tests (1)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `value`

</details>

### <a name="val-subvec"></a>`subVec`

```sml
val subVec : Word8Vector.vector * int -> LargeWord.word
```

<details><summary>Tests (6)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `element-*` &middot; `high-element-*` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-partial-element` (raises) &middot; `Subscript-maxInt` (raises)

</details>

### <a name="val-subvecx"></a>`subVecX`

```sml
val subVecX : Word8Vector.vector * int -> LargeWord.word
```

<details><summary>Tests (4)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `sign-extended-*` &middot; `non-negative-*` &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

</details>

### <a name="val-subarr"></a>`subArr`

```sml
val subArr : Word8Array.array * int -> LargeWord.word
```

<details><summary>Tests (5)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `element-*` &middot; `high-element-*` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

</details>

### <a name="val-subarrx"></a>`subArrX`

```sml
val subArrX : Word8Array.array * int -> LargeWord.word
```

<details><summary>Tests (4)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `sign-extended-*` &middot; `non-negative-*` &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

</details>

### <a name="val-update"></a>`update`

```sml
val update : Word8Array.array * int * LargeWord.word -> unit
```

<details><summary>Tests (5)</summary>

In [tests/basis/fn/pack\_word\_fn.sml](../../../../tests/basis/fn/pack_word_fn.sml), applied to `PackWord16Big`, `PackWord16Little`, `PackWord32Big`, `PackWord32Little`, `PackWord64Big`, `PackWord64Little`: `element-1` &middot; `read-back` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_pack\_word.sml; do not edit.</sub>

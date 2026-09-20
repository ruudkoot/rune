# signature PACK_REAL

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; **PACK_REAL**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 6 |
| Documentation | 8 of 8 entries documented |
| Tests | 44 checks of 7 entries |
| Source | [lib/basis/sig\_pack\_real.sml](../../../../lib/basis/sig_pack_real.sml) |

## Synopsis

```sml
signature PACK_REAL
structure PackReal32Big : PACK_REAL where type real = Real32.real  (* optional *)
structure PackReal32Little : PACK_REAL where type real = Real32.real  (* optional *)
structure PackReal64Big : PACK_REAL where type real = Real64.real  (* optional *)
structure PackReal64Little : PACK_REAL where type real = Real64.real  (* optional *)
structure PackRealBig : PACK_REAL where type real = Real.real  (* optional *)
structure PackRealLittle : PACK_REAL where type real = Real.real  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `PackReal32Big` |  | [lib/basis/pack\_real32.sml](../../../../lib/basis/pack_real32.sml) |
| `PackReal32Little` |  | [lib/basis/pack\_real32.sml](../../../../lib/basis/pack_real32.sml) |
| `PackReal64Big` |  | [lib/basis/pack\_real.sml](../../../../lib/basis/pack_real.sml) |
| `PackReal64Little` |  | [lib/basis/pack\_real.sml](../../../../lib/basis/pack_real.sml) |
| `PackRealBig` |  | [lib/basis/pack\_real.sml](../../../../lib/basis/pack_real.sml) |
| `PackRealLittle` |  | [lib/basis/pack\_real.sml](../../../../lib/basis/pack_real.sml) |

Reading and writing a real number in a vector or an array of bytes, in its
IEEE 754 encoding and a fixed byte order.

[`PackRealBig`](PACK_REAL.md) writes the most significant byte of the encoding first and
[`PackRealLittle`](PACK_REAL.md) the least, so a program can read or write a binary file
whose layout is given, whatever the byte order of the machine. The bytes
are the encoding itself: the sign, the exponent and the significand as
IEEE 754 lays them out.

> **Implementation** `PackReal/encodings`. `PackReal` and `PackReal64` write
> the 8 bytes of binary64; `PackReal32` the 4 bytes of binary32, and a NaN
> becomes the quiet NaN of its sign, so a payload is lost.

## Interface

<pre>
signature PACK_REAL =
sig
  type <a href="#type-real">real</a>

  val <a href="#val-bytesperelem">bytesPerElem</a> : int

  val <a href="#val-isbigendian">isBigEndian</a> : bool

  val <a href="#val-tobytes">toBytes</a> : real -&gt; Word8Vector.vector

  val <a href="#val-frombytes">fromBytes</a> : Word8Vector.vector -&gt; real

  val <a href="#val-subvec">subVec</a> : Word8Vector.vector * int -&gt; real

  val <a href="#val-subarr">subArr</a> : Word8Array.array * int -&gt; real

  val <a href="#val-update">update</a> : Word8Array.array * int * real -&gt; unit
end
</pre>

### <a name="type-real"></a>`real`

```sml
type real
```

The type of the reals this structure packs: [`Real.real`](../sig/REAL.md#type-real) for `PackReal`, [`Real32.real`](../sig/REAL.md#type-real) for `PackReal32`.

### <a name="val-bytesperelem"></a>`bytesPerElem`

```sml
val bytesPerElem : int
```

The number of bytes of one real: 8 for binary64, 4 for binary32.

<details><summary>Tests (2)</summary>

In [tests/basis/fn/pack\_real\_fn.sml](../../../../tests/basis/fn/pack_real_fn.sml), applied to `PackRealBig`, `PackRealLittle`, `PackReal64Big`, `PackReal64Little`: `eight`

In [tests/basis/fn/pack\_real32\_fn.sml](../../../../tests/basis/fn/pack_real32_fn.sml), applied to `PackReal32Big`, `PackReal32Little`: `four`

</details>

### <a name="val-isbigendian"></a>`isBigEndian`

```sml
val isBigEndian : bool
```

Whether the most significant byte of the encoding comes first.

<details><summary>Tests (2)</summary>

In [tests/basis/fn/pack\_real\_fn.sml](../../../../tests/basis/fn/pack_real_fn.sml), applied to `PackRealBig`, `PackRealLittle`, `PackReal64Big`, `PackReal64Little`: `value`

In [tests/basis/fn/pack\_real32\_fn.sml](../../../../tests/basis/fn/pack_real32_fn.sml), applied to `PackReal32Big`, `PackReal32Little`: `value`

</details>

### <a name="val-tobytes"></a>`toBytes`

```sml
val toBytes : real -> Word8Vector.vector
```

`toBytes r` is the encoding of `r` as a vector of [`bytesPerElem`](#val-bytesperelem) bytes.

<details><summary>Tests (4)</summary>

In [tests/basis/fn/pack\_real\_fn.sml](../../../../tests/basis/fn/pack_real_fn.sml), applied to `PackRealBig`, `PackRealLittle`, `PackReal64Big`, `PackReal64Little`: `*` &middot; `nan-exponent`

In [tests/basis/fn/pack\_real32\_fn.sml](../../../../tests/basis/fn/pack_real32_fn.sml), applied to `PackReal32Big`, `PackReal32Little`: `*` &middot; `nan-exponent`

</details>

### <a name="val-frombytes"></a>`fromBytes`

```sml
val fromBytes : Word8Vector.vector -> real
```

`fromBytes v` is the real whose encoding is the bytes of `v`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `v` has fewer than [`bytesPerElem`](#val-bytesperelem) bytes; a longer
vector is read from its start.

**Law** `fromBytes (toBytes r) = r`, except that a NaN comes back as some
NaN

<details><summary>Tests (10)</summary>

In [tests/basis/fn/pack\_real\_fn.sml](../../../../tests/basis/fn/pack_real_fn.sml), applied to `PackRealBig`, `PackRealLittle`, `PackReal64Big`, `PackReal64Little`: `*` &middot; `nan` &middot; `longer-uses-the-first` &middot; `Subscript-short` (raises) &middot; `inverts-toBytes`

In [tests/basis/fn/pack\_real32\_fn.sml](../../../../tests/basis/fn/pack_real32_fn.sml), applied to `PackReal32Big`, `PackReal32Little`: `*` &middot; `nan` &middot; `longer-uses-the-first` &middot; `Subscript-short` (raises) &middot; `inverts-toBytes`

</details>

### <a name="val-subvec"></a>`subVec`

```sml
val subVec : Word8Vector.vector * int -> real
```

`subVec (v, i)` is the real at position `i` of the byte vector `v`, counting in reals.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if the bytes of element `i` are not all in `v`.

<details><summary>Tests (10)</summary>

In [tests/basis/fn/pack\_real\_fn.sml](../../../../tests/basis/fn/pack_real_fn.sml), applied to `PackRealBig`, `PackRealLittle`, `PackReal64Big`, `PackReal64Little`: `element-1` &middot; `element-2` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

In [tests/basis/fn/pack\_real32\_fn.sml](../../../../tests/basis/fn/pack_real32_fn.sml), applied to `PackReal32Big`, `PackReal32Little`: `element-1` &middot; `element-2` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

</details>

### <a name="val-subarr"></a>`subArr`

```sml
val subArr : Word8Array.array * int -> real
```

`subArr (arr, i)` is the real at position `i` of the byte array `arr`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if the bytes of element `i` are not all in `arr`.

<details><summary>Tests (8)</summary>

In [tests/basis/fn/pack\_real\_fn.sml](../../../../tests/basis/fn/pack_real_fn.sml), applied to `PackRealBig`, `PackRealLittle`, `PackReal64Big`, `PackReal64Little`: `element-0` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

In [tests/basis/fn/pack\_real32\_fn.sml](../../../../tests/basis/fn/pack_real32_fn.sml), applied to `PackReal32Big`, `PackReal32Little`: `element-0` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

</details>

### <a name="val-update"></a>`update`

```sml
val update : Word8Array.array * int * real -> unit
```

`update (arr, i, r)` writes the encoding of `r` at position `i` of `arr`.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if the bytes of element `i` are not all in `arr`.

<details><summary>Tests (8)</summary>

In [tests/basis/fn/pack\_real\_fn.sml](../../../../tests/basis/fn/pack_real_fn.sml), applied to `PackRealBig`, `PackRealLittle`, `PackReal64Big`, `PackReal64Little`: `element-1` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

In [tests/basis/fn/pack\_real32\_fn.sml](../../../../tests/basis/fn/pack_real32_fn.sml), applied to `PackReal32Big`, `PackReal32Little`: `element-1` &middot; `Subscript-negative` (raises) &middot; `Subscript-past-the-end` (raises) &middot; `Subscript-maxInt` (raises)

</details>

## See also

[`REAL`](../sig/REAL.md), [`PACK_WORD`](../sig/PACK_WORD.md), [`BYTE`](../sig/BYTE.md), [`IEEE_REAL`](../sig/IEEE_REAL.md)

---

<sub>Generated by runedoc from lib/basis/sig\_pack\_real.sml; do not edit.</sub>

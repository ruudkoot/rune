# signature BYTE

[The Standard ML Basis Library](../README.md) &rsaquo; Text and characters &rsaquo; **BYTE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 7 of 7 entries documented |
| Tests | 67 checks of 7 entries |
| Source | [lib/basis/sig\_byte.sml](../../../../lib/basis/sig_byte.sml) |

## Synopsis

```sml
signature BYTE
structure Byte : BYTE
```

| Implementation |  | Source |
| --- | --- | --- |
| `Byte` | Byte: between bytes and characters. A Word8Vector.vector is a string, so the conversions of whole vectors cost nothing. | [lib/basis/byte.sml](../../../../lib/basis/byte.sml) |

Between bytes and characters: the same eight bits read as a [`Word8.word`](../sig/WORD.md#type-word)
and as a `char`.

The conversions are of the codes, not of any encoding: the byte 200 is the
character whose code is 200, whatever a locale would make of it. Text that
comes in as bytes (from [`BinIO`](../sig/BIN_IO.md), a socket, [`Word8Array`](../sig/MONO_ARRAY.md)) becomes a string
here, and the other way round.

> **Implementation** `Byte/free`. A [`Word8Vector.vector`](../sig/MONO_VECTOR.md#type-vector) is a `string` in this
> library, so [`bytesToString`](#val-bytestostring) and [`stringToBytes`](#val-stringtobytes) copy nothing.

## Interface

<pre>
signature BYTE =
sig
  val <a href="#val-bytetochar">byteToChar</a> : Word8.word -&gt; char

  val <a href="#val-chartobyte">charToByte</a> : char -&gt; Word8.word

  val <a href="#val-bytestostring">bytesToString</a> : Word8Vector.vector -&gt; string

  val <a href="#val-stringtobytes">stringToBytes</a> : string -&gt; Word8Vector.vector

  val <a href="#val-unpackstringvec">unpackStringVec</a> : Word8VectorSlice.slice -&gt; string

  val <a href="#val-unpackstring">unpackString</a> : Word8ArraySlice.slice -&gt; string

  val <a href="#val-packstring">packString</a> : Word8Array.array * int * substring -&gt; unit
end
</pre>

### <a name="val-bytetochar"></a>`byteToChar`

```sml
val byteToChar : Word8.word -> char
```

`byteToChar b` is the character whose code is `b`.

> **Reading** `Byte.byteToChar/high-bytes-are-not-negative`. A byte is an
> unsigned number: 200 is the character with code 200, and not the one
> that a signed byte of \~56 would name.

**Law** `Char.ord (byteToChar b) = Word8.toInt b`

**Example** `byteToChar 0w65 = #"A"`

<details><summary>Tests (7)</summary>

For `Byte`, in [tests/basis/byte.sml](../../../../tests/basis/byte.sml): `basic` &middot; `zero` &middot; `255` &middot; `newline` &middot; `every-byte` &middot; `inverts-charToByte` &middot; `high-bytes-are-not-negative`

</details>

### <a name="val-chartobyte"></a>`charToByte`

```sml
val charToByte : char -> Word8.word
```

`charToByte c` is the code of `c` as a byte.

**Law** `charToByte (byteToChar b) = b`

**Example** `charToByte #"a" = 0w97`

<details><summary>Tests (6)</summary>

For `Byte`, in [tests/basis/byte.sml](../../../../tests/basis/byte.sml): `basic` &middot; `zero` &middot; `255` &middot; `newline` &middot; `every-character` &middot; `inverts-byteToChar`

</details>

### <a name="val-bytestostring"></a>`bytesToString`

```sml
val bytesToString : Word8Vector.vector -> string
```

`bytesToString v` is the string of the characters whose codes are the bytes of `v`, in order.

**Example** `bytesToString (stringToBytes "hi") = "hi"`

<details><summary>Tests (7)</summary>

For `Byte`, in [tests/basis/byte.sml](../../../../tests/basis/byte.sml): `basic` &middot; `empty` &middot; `one` &middot; `no-translation` &middot; `every-byte` &middot; `size` &middot; `random-inverts-stringToBytes-*`

</details>

### <a name="val-stringtobytes"></a>`stringToBytes`

```sml
val stringToBytes : string -> Word8Vector.vector
```

`stringToBytes s` is the vector of the codes of the characters of `s`, in order.

**Law** `bytesToString (stringToBytes s) = s`

<details><summary>Tests (8)</summary>

For `Byte`, in [tests/basis/byte.sml](../../../../tests/basis/byte.sml): `basic` &middot; `empty` &middot; `one` &middot; `no-translation` &middot; `every-character` &middot; `length` &middot; `random-elementwise-*` &middot; `random-inverts-bytesToString-*`

</details>

### <a name="val-unpackstringvec"></a>`unpackStringVec`

```sml
val unpackStringVec : Word8VectorSlice.slice -> string
```

`unpackStringVec sl` is the string of the bytes of the vector slice `sl`.

**Example** `unpackStringVec (Word8VectorSlice.slice (stringToBytes "hello", 1, SOME 3)) = "ell"`

<details><summary>Tests (11)</summary>

For `Byte`, in [tests/basis/byte.sml](../../../../tests/basis/byte.sml): `full` &middot; `middle` &middot; `to-the-end` &middot; `first` &middot; `last` &middot; `empty-slice` &middot; `empty-slice-at-the-end` &middot; `empty-vector` &middot; `no-translation` &middot; `slice-of-a-slice` &middot; `random-*`

</details>

### <a name="val-unpackstring"></a>`unpackString`

```sml
val unpackString : Word8ArraySlice.slice -> string
```

`unpackString sl` is the string of the bytes of the array slice `sl`.

> **Reading** `Byte.unpackString/sees-the-current-contents`. An array can
> change: the bytes are read when [`unpackString`](#val-unpackstring) is called, so the string
> holds what the slice had at that moment and is not touched by a later
> update.

<details><summary>Tests (9)</summary>

For `Byte`, in [tests/basis/byte.sml](../../../../tests/basis/byte.sml): `full` &middot; `middle` &middot; `to-the-end` &middot; `empty-slice` &middot; `empty-slice-at-the-end` &middot; `empty-array` &middot; `no-translation` &middot; `sees-the-current-contents` &middot; `random-*`

</details>

### <a name="val-packstring"></a>`packString`

```sml
val packString : Word8Array.array * int * substring -> unit
```

`packString (arr, i, ss)` writes the characters of the substring `ss` into `arr`, from position `i` on.

**Raises** [`Subscript`](../sig/GENERAL.md#exn-subscript) if `i < 0` or if the characters would not fit, that
is if `i + Substring.size ss > Word8Array.length arr`.

<details><summary>Other implementations (1)</summary>

- **MLton** &mdash; packString of an empty substring does not check the offset

</details>

<details><summary>Tests (19)</summary>

For `Byte`, in [tests/basis/byte.sml](../../../../tests/basis/byte.sml): `at-the-start` &middot; `in-the-middle` &middot; `up-to-the-end` &middot; `whole-array` &middot; `part-of-a-string` &middot; `empty-substring` &middot; `empty-substring-at-the-end` &middot; `empty-array` &middot; `no-translation` &middot; `keeps-the-other-elements` &middot; `twice` &middot; `Subscript-negative-offset` (raises Subscript) &middot; `Subscript-negative-offset-empty-substring` (raises Subscript) &middot; `Subscript-one-too-long` (raises Subscript) &middot; `Subscript-offset-is-the-length` (raises Subscript) &middot; `Subscript-offset-beyond-the-length-empty-substring` (raises Subscript) &middot; `Subscript-longer-than-the-array` (raises Subscript) &middot; `Subscript-empty-array` (raises Subscript) &middot; `random-*`

</details>

## See also

[`CHAR`](../sig/CHAR.md), [`STRING`](../sig/STRING.md), [`SUBSTRING`](../sig/SUBSTRING.md), [`MONO_VECTOR`](../sig/MONO_VECTOR.md)

---

<sub>Generated by runedoc from lib/basis/sig\_byte.sml; do not edit.</sub>

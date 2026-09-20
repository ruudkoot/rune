# signature TEXT

[The Standard ML Basis Library](../README.md) &rsaquo; **TEXT**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 2 |
| Documentation | 0 of 7 entries documented |
| Tests | 25 checks of 7 entries |
| Source | [lib/basis/sig\_text.sml](../../../../lib/basis/sig_text.sml) |

## Synopsis

```sml
signature TEXT
structure Text : TEXT where type Char.char = Char.char where type String.string = String.string where type Substring.substring = Substring.substring where type CharArray.array = CharArray.array where type CharVectorSlice.slice = CharVectorSlice.slice where type CharArraySlice.slice = CharArraySlice.slice
structure WideText : TEXT  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Text` | Text: the structures of the default character type. | [lib/basis/text.sml](../../../../lib/basis/text.sml) |
| `WideText` | WideText: the structures of the wide character (optional in the specification), as Text is of char. | [lib/basis/widetext.sml](../../../../lib/basis/widetext.sml) |

signature TEXT, transcribed from <https://smlfamily.github.io/Basis/text.html>

The signatures of the substructures are those of tests/basis/spec-sigs:
CHAR.sml, STRING.sml, SUBSTRING.sml, MONO\_VECTOR.sml, MONO\_ARRAY.sml,
MONO\_VECTOR\_SLICE.sml and MONO\_ARRAY\_SLICE.sml. The constraints of
`structure Text :> TEXT where type Char.char = Char.char ...` are in
tests/basis/text\_sig.sml.

## Interface

<pre>
signature TEXT =
sig
  structure <a href="#str-char">Char</a> : CHAR
  structure <a href="#str-string">String</a> : STRING
  structure <a href="#str-substring">Substring</a> : SUBSTRING
  structure <a href="#str-charvector">CharVector</a> : MONO_VECTOR
  structure <a href="#str-chararray">CharArray</a> : MONO_ARRAY
  structure <a href="#str-charvectorslice">CharVectorSlice</a> : MONO_VECTOR_SLICE
  structure <a href="#str-chararrayslice">CharArraySlice</a> : MONO_ARRAY_SLICE
  sharing type Char.char = String.char = Substring.char
    = CharVector.elem = CharArray.elem = CharVectorSlice.elem
    = CharArraySlice.elem
  sharing type Char.string = String.string = Substring.string
    = CharVector.vector = CharArray.vector
    = CharVectorSlice.vector = CharArraySlice.vector
  sharing type CharArray.array = CharArraySlice.array
  sharing type CharVectorSlice.slice
    = CharArraySlice.vector_slice
end
</pre>

### <a name="str-char"></a>`Char`

```sml
structure Char : CHAR
```

A substructure: its members are described on the page of [`CHAR`](../sig/CHAR.md).

<details><summary>Tests (5)</summary>

For `Text`, in [tests/basis/text.sml](../../../../tests/basis/text.sml): `ord-of-a-char` &middot; `chr-is-a-char` &middot; `maxOrd-is-that-of-Char` &middot; `same-functions` &middot; `chr-raises-Chr` (raises Chr)

</details>

### <a name="str-string"></a>`String`

```sml
structure String : STRING
```

A substructure: its members are described on the page of [`STRING`](../sig/STRING.md).

<details><summary>Tests (4)</summary>

For `Text`, in [tests/basis/text.sml](../../../../tests/basis/text.sml): `size-of-a-string` &middot; `concat-is-a-string` &middot; `same-functions` &middot; `char-is-char`

</details>

### <a name="str-substring"></a>`Substring`

```sml
structure Substring : SUBSTRING
```

A substructure: its members are described on the page of [`SUBSTRING`](../sig/SUBSTRING.md).

<details><summary>Tests (3)</summary>

For `Text`, in [tests/basis/text.sml](../../../../tests/basis/text.sml): `of-a-Substring.substring` &middot; `is-a-Substring.substring` &middot; `base`

</details>

### <a name="str-charvector"></a>`CharVector`

```sml
structure CharVector : MONO_VECTOR
```

A substructure: its members are described on the page of [`MONO_VECTOR`](../sig/MONO_VECTOR.md).

<details><summary>Tests (3)</summary>

For `Text`, in [tests/basis/text.sml](../../../../tests/basis/text.sml): `vector-is-a-string` &middot; `of-a-CharVector.vector` &middot; `is-a-CharVector.vector`

</details>

### <a name="str-chararray"></a>`CharArray`

```sml
structure CharArray : MONO_ARRAY
```

A substructure: its members are described on the page of [`MONO_ARRAY`](../sig/MONO_ARRAY.md).

<details><summary>Tests (3)</summary>

For `Text`, in [tests/basis/text.sml](../../../../tests/basis/text.sml): `of-a-CharArray.array` &middot; `is-a-CharArray.array` &middot; `same-array-is-equal`

</details>

### <a name="str-charvectorslice"></a>`CharVectorSlice`

```sml
structure CharVectorSlice : MONO_VECTOR_SLICE
```

A substructure: its members are described on the page of [`MONO_VECTOR_SLICE`](../sig/MONO_VECTOR_SLICE.md).

<details><summary>Tests (4)</summary>

For `Text`, in [tests/basis/text.sml](../../../../tests/basis/text.sml): `of-a-CharVectorSlice.slice` &middot; `is-a-CharVectorSlice.slice` &middot; `is-a-substring` &middot; `of-a-substring`

</details>

### <a name="str-chararrayslice"></a>`CharArraySlice`

```sml
structure CharArraySlice : MONO_ARRAY_SLICE
```

A substructure: its members are described on the page of [`MONO_ARRAY_SLICE`](../sig/MONO_ARRAY_SLICE.md).

<details><summary>Tests (3)</summary>

For `Text`, in [tests/basis/text.sml](../../../../tests/basis/text.sml): `of-a-CharArraySlice.slice` &middot; `is-a-CharArraySlice.slice` &middot; `copyVec-of-a-CharVectorSlice.slice`

</details>

---

<sub>Generated by runedoc from lib/basis/sig\_text.sml; do not edit.</sub>

# signature WORD

[The Standard ML Basis Library](../README.md) &rsaquo; **WORD**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 5 |
| Documentation | 0 of 38 entries documented |
| Tests | 286 checks of 38 entries |
| Source | [lib/basis/word\_sig.sml](../../../../lib/basis/word_sig.sml) |

## Synopsis

```sml
signature WORD
structure Word : WORD
structure Word16 : WORD  (* optional *)
structure Word32 : WORD  (* optional *)
structure Word64 : WORD  (* optional *)
structure Word8 :> WORD
```

| Implementation |  | Source |
| --- | --- | --- |
| `Word` | Word: unsigned words: 64 bits on the VM. The size is found by shifting a bit out, so that this file means the same to a system whose word is narrower. | [lib/basis/word.sml](../../../../lib/basis/word.sml) |
| `Word16` | Word16: words of 16 bits. | [lib/basis/word16.sml](../../../../lib/basis/word16.sml) |
| `Word32` | Word32: words of 32 bits. | [lib/basis/word32.sml](../../../../lib/basis/word32.sml) |
| `Word64` | Word64 is Word, which has 64 bits. | [lib/basis/word64.sml](../../../../lib/basis/word64.sml) |
| `Word8` | Word8: 8-bit words. A value is a word whose upper bits are zero; every operation that could set one of them clears it again. (The only member of the WordN family so far; see docs/plans/basis.md.) | [lib/basis/word8.sml](../../../../lib/basis/word8.sml) |

signature WORD

## Interface

<pre>
signature WORD =
sig
  eqtype <a href="#type-word">word</a>
  val <a href="#val-wordsize">wordSize</a> : int
  val <a href="#val-tolarge">toLarge</a> : word -&gt; LargeWord.word
  val <a href="#val-tolargex">toLargeX</a> : word -&gt; LargeWord.word
  val <a href="#val-tolargeword">toLargeWord</a> : word -&gt; LargeWord.word
  val <a href="#val-tolargewordx">toLargeWordX</a> : word -&gt; LargeWord.word
  val <a href="#val-fromlarge">fromLarge</a> : LargeWord.word -&gt; word
  val <a href="#val-fromlargeword">fromLargeWord</a> : LargeWord.word -&gt; word
  val <a href="#val-tolargeint">toLargeInt</a> : word -&gt; LargeInt.int
  val <a href="#val-tolargeintx">toLargeIntX</a> : word -&gt; LargeInt.int
  val <a href="#val-fromlargeint">fromLargeInt</a> : LargeInt.int -&gt; word
  val <a href="#val-toint">toInt</a> : word -&gt; int
  val <a href="#val-tointx">toIntX</a> : word -&gt; int
  val <a href="#val-fromint">fromInt</a> : int -&gt; word
  val <a href="#val-andb">andb</a> : word * word -&gt; word
  val <a href="#val-orb">orb</a> : word * word -&gt; word
  val <a href="#val-xorb">xorb</a> : word * word -&gt; word
  val <a href="#val-notb">notb</a> : word -&gt; word
  val <a href="#val-op-lt-lt">&lt;&lt;</a> : word * Word.word -&gt; word
  val <a href="#val-op-gt-gt">&gt;&gt;</a> : word * Word.word -&gt; word
  val <a href="#val-op-tilde-gt-gt">~&gt;&gt;</a> : word * Word.word -&gt; word
  val <a href="#val-op-plus">+</a> : word * word -&gt; word
  val <a href="#val-op-minus">-</a> : word * word -&gt; word
  val <a href="#val-op-star">*</a> : word * word -&gt; word
  val <a href="#val-div">div</a> : word * word -&gt; word
  val <a href="#val-mod">mod</a> : word * word -&gt; word
  val <a href="#val-compare">compare</a> : word * word -&gt; order
  val <a href="#val-op-lt">&lt;</a> : word * word -&gt; bool
  val <a href="#val-op-lt-eq">&lt;=</a> : word * word -&gt; bool
  val <a href="#val-op-gt">&gt;</a> : word * word -&gt; bool
  val <a href="#val-op-gt-eq">&gt;=</a> : word * word -&gt; bool
  val <a href="#val-op-tilde">~</a> : word -&gt; word
  val <a href="#val-min">min</a> : word * word -&gt; word
  val <a href="#val-max">max</a> : word * word -&gt; word
  val <a href="#val-fmt">fmt</a> : StringCvt.radix -&gt; word -&gt; string
  val <a href="#val-tostring">toString</a> : word -&gt; string
  val <a href="#val-scan">scan</a> : StringCvt.radix -&gt; (char, 'a) StringCvt.reader -&gt; (word, 'a) StringCvt.reader
  val <a href="#val-fromstring">fromString</a> : string -&gt; word option
end
</pre>

### <a name="type-word"></a>`word`

```sml
eqtype word
```

<details><summary>Tests (2)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `is-toplevel-word` &middot; `toplevel-is-Word.word`

</details>

### <a name="val-wordsize"></a>`wordSize`

```sml
val wordSize : int
```

<details><summary>Tests (9)</summary>

For `Word8`, in [tests/basis/word8.sml](../../../../tests/basis/word8.sml): `eight`

For `Word16`, in [tests/basis/intn\_word16.sml](../../../../tests/basis/intn_word16.sml): `16`

For `Word32`, in [tests/basis/intn\_word32.sml](../../../../tests/basis/intn_word32.sml): `32`

For `Word64`, in [tests/basis/intn\_word64.sml](../../../../tests/basis/intn_word64.sml): `64`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `at-least-8` &middot; `top-bit-is-not-zero` &middot; `two-to-the-wordSize-is-zero` &middot; `all-ones-is-not-zero`

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `at-most-LargeWord.wordSize`

</details>

### <a name="val-tolarge"></a>`toLarge`

```sml
val toLarge : word -> LargeWord.word
```

<details><summary>Tests (5)</summary>

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `zero` &middot; `200` &middot; `all-ones` &middot; `top-bit` &middot; `model*`

</details>

### <a name="val-tolargex"></a>`toLargeX`

```sml
val toLargeX : word -> LargeWord.word
```

<details><summary>Tests (6)</summary>

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `zero` &middot; `100` &middot; `all-ones` &middot; `top-bit` &middot; `below-top-bit` &middot; `model*`

</details>

### <a name="val-tolargeword"></a>`toLargeWord`

```sml
val toLargeWord : word -> LargeWord.word
```

<details><summary>Tests (2)</summary>

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `200` &middot; `synonym*`

</details>

### <a name="val-tolargewordx"></a>`toLargeWordX`

```sml
val toLargeWordX : word -> LargeWord.word
```

<details><summary>Tests (2)</summary>

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `all-ones` &middot; `synonym*`

</details>

### <a name="val-fromlarge"></a>`fromLarge`

```sml
val fromLarge : LargeWord.word -> word
```

<details><summary>Tests (10)</summary>

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `zero` &middot; `200` &middot; `all-ones` &middot; `low-ones` &middot; `two-to-the-wordSize` &middot; `two-to-the-wordSize-plus-five` &middot; `high-ones` &middot; `model*` &middot; `toLarge*` &middot; `toLargeX*`

</details>

### <a name="val-fromlargeword"></a>`fromLargeWord`

```sml
val fromLargeWord : LargeWord.word -> word
```

<details><summary>Tests (2)</summary>

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `200` &middot; `synonym*`

</details>

### <a name="val-tolargeint"></a>`toLargeInt`

```sml
val toLargeInt : word -> LargeInt.int
```

<details><summary>Tests (5)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `200` &middot; `all-ones` &middot; `top-bit` &middot; `model*`

</details>

### <a name="val-tolargeintx"></a>`toLargeIntX`

```sml
val toLargeIntX : word -> LargeInt.int
```

<details><summary>Tests (6)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `100` &middot; `all-ones` &middot; `top-bit` &middot; `below-top-bit` &middot; `model*`

</details>

### <a name="val-fromlargeint"></a>`fromLargeInt`

```sml
val fromLargeInt : LargeInt.int -> word
```

<details><summary>Tests (15)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `200` &middot; `minus-one` &middot; `minus-three` &middot; `all-ones` &middot; `two-to-the-wordSize` &middot; `two-to-the-wordSize-plus-five` &middot; `minus-two-to-the-wordSize-minus-three` &middot; `two-to-twice-the-wordSize-plus-seven` &middot; `minus-two-to-twice-the-wordSize-minus-one` &middot; `minus-top-bit` &middot; `model*` &middot; `plus-multiple*` &middot; `minus-multiple*` &middot; `signed*`

</details>

### <a name="val-toint"></a>`toInt`

```sml
val toInt : word -> int
```

<details><summary>Tests (12)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `constant`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `200` &middot; `sum` &middot; `all-ones` &middot; `top-bit` &middot; `Overflow-all-ones` &middot; `Overflow-top-bit` &middot; `below-top-bit` &middot; `Overflow-below-top-bit` &middot; `model*`

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `through-LargeWord*`

</details>

### <a name="val-tointx"></a>`toIntX`

```sml
val toIntX : word -> int
```

<details><summary>Tests (15)</summary>

For `Word8`, in [tests/basis/word8.sml](../../../../tests/basis/word8.sml): `all-ones-constant`

For `Word16`, in [tests/basis/intn\_word16.sml](../../../../tests/basis/intn_word16.sml): `all-ones-constant`

For `Word32`, in [tests/basis/intn\_word32.sml](../../../../tests/basis/intn_word32.sml): `all-ones-constant`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `100` &middot; `all-ones` &middot; `all-ones-but-one` &middot; `fromInt-negative` &middot; `below-top-bit` &middot; `top-bit` &middot; `Overflow-below-top-bit` &middot; `Overflow-top-bit` &middot; `model*` &middot; `fromInt*`

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `through-LargeWord*`

</details>

### <a name="val-fromint"></a>`fromInt`

```sml
val fromInt : int -> word
```

<details><summary>Tests (13)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `decimal-constant` &middot; `hexadecimal-constant`

For `Word8`, in [tests/basis/word8.sml](../../../../tests/basis/word8.sml): `keeps-the-low-byte`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `distinct` &middot; `minus-one` &middot; `minus-two` &middot; `minus-128` &middot; `round-trip` &middot; `Int.maxInt` &middot; `Int.minInt` &middot; `model*` &middot; `samples-built`

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `through-LargeWord*`

</details>

### <a name="val-andb"></a>`andb`

```sml
val andb : word * word -> word
```

<details><summary>Tests (5)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones` &middot; `top-bit` &middot; `model*` &middot; `de-morgan*`

</details>

### <a name="val-orb"></a>`orb`

```sml
val orb : word * word -> word
```

<details><summary>Tests (5)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones` &middot; `top-bit` &middot; `model*` &middot; `de-morgan*`

</details>

### <a name="val-xorb"></a>`xorb`

```sml
val xorb : word * word -> word
```

<details><summary>Tests (4)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `top-bit` &middot; `model*` &middot; `orb-minus-andb*`

</details>

### <a name="val-notb"></a>`notb`

```sml
val notb : word -> word
```

<details><summary>Tests (9)</summary>

For `Word8`, in [tests/basis/word8.sml](../../../../tests/basis/word8.sml): `eight-bits`

For `Word16`, in [tests/basis/intn\_word16.sml](../../../../tests/basis/intn_word16.sml): `16-bits`

For `Word32`, in [tests/basis/intn\_word32.sml](../../../../tests/basis/intn_word32.sml): `32-bits`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `all-ones` &middot; `top-bit` &middot; `ten` &middot; `model*` &middot; `plus-self-is-all-ones*`

</details>

### <a name="val-op-lt-lt"></a>`<<`

```sml
val << : word * Word.word -> word
```

<details><summary>Tests (11)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `amount-is-a-word`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `one-to-top-bit` &middot; `three-to-top-bit` &middot; `all-ones-to-top-bit` &middot; `all-ones-by-one` &middot; `top-bit-by-one` &middot; `by-*` &middot; `one-by-*` &middot; `model*` &middot; `times-power*`

</details>

### <a name="val-op-gt-gt"></a>`>>`

```sml
val >> : word * Word.word -> word
```

<details><summary>Tests (11)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `amount-is-a-word`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `top-bit-to-one` &middot; `all-ones-to-one` &middot; `all-ones-by-one` &middot; `all-ones-by-zero` &middot; `below-top-bit` &middot; `by-*` &middot; `top-bit-by-*` &middot; `model*` &middot; `by-power*`

</details>

### <a name="val-op-tilde-gt-gt"></a>`~>>`

```sml
val ~>> : word * Word.word -> word
```

<details><summary>Tests (18)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `amount-is-a-word`

For `Word8`, in [tests/basis/word8.sml](../../../../tests/basis/word8.sml): `sign-bit-constant`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `top-bit-to-all-ones` &middot; `top-bit-by-one` &middot; `all-ones-by-one` &middot; `all-ones-by-zero` &middot; `minus-two-by-one` &middot; `minus-three-by-one` &middot; `minus-100-by-three` &middot; `below-top-bit-to-one` &middot; `below-top-bit-to-zero` &middot; `negative-by-*` &middot; `all-ones-by-*` &middot; `non-negative-by-*` &middot; `one-by-*` &middot; `model*` &middot; `floor-by-power*`

</details>

### <a name="val-op-plus"></a>`+`

```sml
val + : word * word -> word
```

<details><summary>Tests (14)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*` &middot; `toplevel-wraps`

For `Word8`, in [tests/basis/word8.sml](../../../../tests/basis/word8.sml): `wraps-at-256` &middot; `overloaded`

For `Word16`, in [tests/basis/intn\_word16.sml](../../../../tests/basis/intn_word16.sml): `wraps`

For `Word32`, in [tests/basis/intn\_word32.sml](../../../../tests/basis/intn_word32.sml): `wraps`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones-plus-one` &middot; `one-plus-all-ones` &middot; `all-ones-twice` &middot; `top-bit-twice` &middot; `below-top-bit-plus-one` &middot; `model*` &middot; `andb-plus-orb*`

</details>

### <a name="val-op-minus"></a>`-`

```sml
val - : word * word -> word
```

<details><summary>Tests (10)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*` &middot; `toplevel-wraps`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `zero-minus-one` &middot; `three-minus-five` &middot; `top-bit-minus-one` &middot; `zero-minus-all-ones` &middot; `below-top-bit-minus-all-ones` &middot; `model*` &middot; `plus-complement*`

</details>

### <a name="val-op-star"></a>`*`

```sml
val * : word * word -> word
```

<details><summary>Tests (9)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones-squared` &middot; `all-ones-times-two` &middot; `top-bit-times-two` &middot; `top-bit-times-three` &middot; `top-bit-squared` &middot; `all-ones-times-five` &middot; `model*`

</details>

### <a name="val-div"></a>`div`

```sml
val div : word * word -> word
```

<details><summary>Tests (15)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*` &middot; `toplevel-Div` (raises Div)

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones-by-one` &middot; `all-ones-by-all-ones` &middot; `all-ones-by-two` &middot; `one-by-all-ones` &middot; `top-bit-by-all-ones` &middot; `all-ones-by-top-bit` &middot; `top-bit-by-two` &middot; `Div` &middot; `Div-zero-by-zero` &middot; `Div-all-ones` &middot; `model*` &middot; `law*`

</details>

### <a name="val-mod"></a>`mod`

```sml
val mod : word * word -> word
```

<details><summary>Tests (13)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*` &middot; `toplevel-Div` (raises Div)

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones-by-two` &middot; `all-ones-by-top-bit` &middot; `top-bit-by-all-ones` &middot; `all-ones-by-all-ones` &middot; `one-by-all-ones` &middot; `Div` &middot; `Div-zero-by-zero` &middot; `Div-all-ones` &middot; `model*` &middot; `less-than-divisor*`

</details>

### <a name="val-compare"></a>`compare`

```sml
val compare : word * word -> order
```

<details><summary>Tests (3)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `model*` &middot; `reflexive*`

</details>

### <a name="val-op-lt"></a>`<`

```sml
val < : word * word -> bool
```

<details><summary>Tests (5)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*` &middot; `toplevel-unsigned`

For `Word8`, in [tests/basis/word8.sml](../../../../tests/basis/word8.sml): `overloaded`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `model*`

</details>

### <a name="val-op-lt-eq"></a>`<=`

```sml
val <= : word * word -> bool
```

<details><summary>Tests (3)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `model*`

</details>

### <a name="val-op-gt"></a>`>`

```sml
val > : word * word -> bool
```

<details><summary>Tests (3)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `model*`

</details>

### <a name="val-op-gt-eq"></a>`>=`

```sml
val >= : word * word -> bool
```

<details><summary>Tests (3)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `model*`

</details>

### <a name="val-op-tilde"></a>`~`

```sml
val ~ : word -> word
```

<details><summary>Tests (8)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `one` &middot; `all-ones` &middot; `top-bit` &middot; `five` &middot; `fromInt-negative` &middot; `model*` &middot; `notb-plus-one*`

</details>

### <a name="val-min"></a>`min`

```sml
val min : word * word -> word
```

<details><summary>Tests (2)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `model*`

</details>

### <a name="val-max"></a>`max`

```sml
val max : word * word -> word
```

<details><summary>Tests (2)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `model*`

</details>

### <a name="val-fmt"></a>`fmt`

```sml
val fmt : StringCvt.radix -> word -> string
```

<details><summary>Tests (2)</summary>

In [tests/basis/fn/word\_scan\_fn.sml](../../../../tests/basis/fn/word_scan_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `*` &middot; `model*`

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : word -> string
```

<details><summary>Tests (6)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones` &middot; `top-bit` &middot; `below-top-bit` &middot; `model*`

In [tests/basis/fn/word\_scan\_fn.sml](../../../../tests/basis/fn/word_scan_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `fmt-HEX-*`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : StringCvt.radix -> (char, 'a) StringCvt.reader -> (word, 'a) StringCvt.reader
```

<details><summary>Tests (5)</summary>

In [tests/basis/fn/word\_scan\_fn.sml](../../../../tests/basis/fn/word_scan_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `*` &middot; `string-position` &middot; `model*` &middot; `model-prefix-lower-case-rest*` &middot; `fmt-round-trip*`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> word option
```

<details><summary>Tests (16)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones` &middot; `all-ones-lower-case` &middot; `all-ones-with-prefix` &middot; `all-ones-with-leading-zeros` &middot; `top-bit` &middot; `Overflow-two-to-the-wordSize` &middot; `Overflow-with-prefix` &middot; `Overflow-two-to-the-wordSize-plus-one` &middot; `Overflow-one-more-digit` &middot; `Overflow-after-whitespace` &middot; `Overflow-many-digits` &middot; `model*` &middot; `model-lower-case-with-prefix*` &middot; `round-trip*`

In [tests/basis/fn/word\_scan\_fn.sml](../../../../tests/basis/fn/word_scan_fn.sml), applied to `Word`, `Word16`, `Word32`, `Word64`: `scanString-*`

</details>

---

<sub>Generated by runedoc from lib/basis/word\_sig.sml; do not edit.</sub>

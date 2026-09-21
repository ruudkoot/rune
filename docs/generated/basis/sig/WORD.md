# signature WORD

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; **WORD**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 7 |
| Documentation | 38 of 38 entries documented |
| Tests | 288 checks of 38 entries |
| Source | [lib/basis/word\_sig.sml](../../../../lib/basis/word_sig.sml) |

## Synopsis

```sml
signature WORD
structure LargeWord : WORD
structure SysWord : WORD  (* optional *)
structure Word : WORD
structure Word16 : WORD  (* optional *)
structure Word32 : WORD  (* optional *)
structure Word64 :> WORD  (* optional *)
structure Word8 : WORD
```

| Implementation |  | Source |
| --- | --- | --- |
| `LargeWord` |  | [lib/basis/word.sml](../../../../lib/basis/word.sml) |
| `SysWord` |  | [lib/basis/word.sml](../../../../lib/basis/word.sml) |
| `Word` | Word: unsigned words: 64 bits on the VM. The size is found by shifting a bit out, so that this file means the same to a system whose word is narrower. | [lib/basis/word.sml](../../../../lib/basis/word.sml) |
| `Word16` | Word16: words of 16 bits. | [lib/basis/word16.sml](../../../../lib/basis/word16.sml) |
| `Word32` | Word32: words of 32 bits. | [lib/basis/word32.sml](../../../../lib/basis/word32.sml) |
| `Word64` | Word64: the 64-bit words. | [lib/basis/word64.sml](../../../../lib/basis/word64.sml) |
| `Word8` | Word8: words of 8 bits, the element type of the byte-oriented structures. | [lib/basis/word8.sml](../../../../lib/basis/word8.sml) |

Words: integers of a fixed number of bits, without a sign, whose
arithmetic wraps round instead of overflowing, and which can be taken
apart bit by bit.

A word of [`wordSize`](#val-wordsize) bits holds the numbers from 0 to `2^wordSize - 1`;
every operation that would leave that range is taken modulo `2^wordSize`,
so nothing raises [`Overflow`](../sig/GENERAL.md#exn-overflow) but the conversions to a type that cannot
hold the value. This is the type for bit sets, masks, hashes and whatever
is counted in bits rather than in numbers.

Where a word is read as a signed number ([`toIntX`](#val-tointx), [`toLargeX`](#val-tolargex), [`~>>`](#val-op-tilde-gt-gt)) the
top bit is the sign, as in two's complement. The functions with an `X` in
their name are those that sign-extend; the others fill with zeros.

The structures differ in their width: [`Word`](WORD.md) is the default one and
[`Word8`](WORD.md), [`Word16`](WORD.md), [`Word32`](WORD.md) and [`Word64`](WORD.md) are the sized ones; [`LargeWord`](WORD.md)
is the widest, and [`SysWord`](WORD.md) is what the operating system's flags are
counted in.

## Contents

[The type and its width](#the-type-and-its-width) &middot;
[Conversions between word structures](#conversions-between-word-structures) &middot;
[Conversions to and from integers](#conversions-to-and-from-integers) &middot;
[Bits](#bits) &middot;
[Arithmetic](#arithmetic) &middot;
[Comparing](#comparing) &middot;
[Text](#text)

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

## The type and its width

### <a name="type-word"></a>`word`

```sml
eqtype word
```

The type of words of this structure.

> **Implementation** `Word.word/64-bits`. [`Word.word`](#type-word) is the top-level
> [`word`](#type-word), of 64 bits, and so are [`LargeWord`](WORD.md), [`SysWord`](WORD.md) and [`Word64`](WORD.md);
> [`Word8`](WORD.md), [`Word16`](WORD.md) and [`Word32`](WORD.md) are kept in a word of the machine whose
> upper bits are zero.

> **Implementation** `Word.word/constants-overloaded`. A word constant has the
> word type that its context asks for, [`Word8.word`](#type-word) as well as [`word`](#type-word), and
> is checked against the range of that type when the program is compiled;
> [`~`](#val-op-tilde) is there for words too. Integer constants are overloaded at
> [`IntInf.int`](../sig/INTEGER.md#type-int) and the `IntN`, real ones at [`Real32.real`](../sig/REAL.md#type-real), and character and
> string constants at [`WideChar.char`](../sig/CHAR.md#type-char) and [`WideString.string`](../sig/STRING.md#type-string).

<details><summary>Tests (2)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `is-toplevel-word` &middot; `toplevel-is-Word.word`

</details>

### <a name="val-wordsize"></a>`wordSize`

```sml
val wordSize : int
```

[`wordSize`](#val-wordsize) is the number of bits of a word of this structure.

**Example** `Word8.wordSize = 8` and `Word.wordSize = 64`

<details><summary>Tests (11)</summary>

For `LargeWord`, in [tests/basis/word\_large.sml](../../../../tests/basis/word_large.sml): `at-most-LargeInt.precision` &middot; `at-least-Word.wordSize`

For `Word8`, in [tests/basis/word8.sml](../../../../tests/basis/word8.sml): `eight`

For `Word16`, in [tests/basis/intn\_word16.sml](../../../../tests/basis/intn_word16.sml): `16`

For `Word32`, in [tests/basis/intn\_word32.sml](../../../../tests/basis/intn_word32.sml): `32`

For `Word64`, in [tests/basis/intn\_word64.sml](../../../../tests/basis/intn_word64.sml): `64`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `at-least-8` &middot; `top-bit-is-not-zero` &middot; `two-to-the-wordSize-is-zero` &middot; `all-ones-is-not-zero`

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `at-most-LargeWord.wordSize`

</details>

## Conversions between word structures

### <a name="val-tolarge"></a>`toLarge`

```sml
val toLarge : word -> LargeWord.word
```

`toLarge w` is `w` as a word of [`LargeWord`](WORD.md), with zeros in the bits above [`wordSize`](#val-wordsize).

<details><summary>Tests (5)</summary>

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `200` &middot; `all-ones` &middot; `top-bit` &middot; `model*`

</details>

### <a name="val-tolargex"></a>`toLargeX`

```sml
val toLargeX : word -> LargeWord.word
```

`toLargeX w` is `w` as a word of [`LargeWord`](WORD.md), with the top bit of `w` copied into the bits above it.

**Law** `toLargeX w = toLarge w` when `w < 2^(wordSize-1)`

<details><summary>Tests (6)</summary>

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `100` &middot; `all-ones` &middot; `top-bit` &middot; `below-top-bit` &middot; `model*`

</details>

### <a name="val-tolargeword"></a>`toLargeWord`

```sml
val toLargeWord : word -> LargeWord.word
```

`toLargeWord w` is another name for [`toLarge`](#val-tolarge).

<details><summary>Tests (2)</summary>

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `200` &middot; `synonym*`

</details>

### <a name="val-tolargewordx"></a>`toLargeWordX`

```sml
val toLargeWordX : word -> LargeWord.word
```

`toLargeWordX w` is another name for [`toLargeX`](#val-tolargex).

<details><summary>Tests (2)</summary>

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `all-ones` &middot; `synonym*`

</details>

### <a name="val-fromlarge"></a>`fromLarge`

```sml
val fromLarge : LargeWord.word -> word
```

`fromLarge w` is the word of this structure with the low [`wordSize`](#val-wordsize) bits of `w`.

What does not fit is dropped: nothing is raised.

<details><summary>Tests (10)</summary>

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `200` &middot; `all-ones` &middot; `low-ones` &middot; `two-to-the-wordSize` &middot; `two-to-the-wordSize-plus-five` &middot; `high-ones` &middot; `model*` &middot; `toLarge*` &middot; `toLargeX*`

</details>

### <a name="val-fromlargeword"></a>`fromLargeWord`

```sml
val fromLargeWord : LargeWord.word -> word
```

`fromLargeWord w` is another name for [`fromLarge`](#val-fromlarge).

<details><summary>Tests (2)</summary>

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `200` &middot; `synonym*`

</details>

## Conversions to and from integers

### <a name="val-tolargeint"></a>`toLargeInt`

```sml
val toLargeInt : word -> LargeInt.int
```

`toLargeInt w` is the number that `w` stands for, between 0 and `2^wordSize - 1`.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if that number is no [`LargeInt.int`](../sig/INTEGER.md#type-int), which cannot
happen where [`LargeInt`](../sig/INTEGER.md) is [`IntInf`](../sig/INT_INF.md).

<details><summary>Tests (5)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `200` &middot; `all-ones` &middot; `top-bit` &middot; `model*`

</details>

### <a name="val-tolargeintx"></a>`toLargeIntX`

```sml
val toLargeIntX : word -> LargeInt.int
```

`toLargeIntX w` is the number that `w` stands for read as a signed one, between `~(2^(wordSize-1))` and `2^(wordSize-1) - 1`.

<details><summary>Tests (6)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `100` &middot; `all-ones` &middot; `top-bit` &middot; `below-top-bit` &middot; `model*`

</details>

### <a name="val-fromlargeint"></a>`fromLargeInt`

```sml
val fromLargeInt : LargeInt.int -> word
```

`fromLargeInt i` is the word with the low [`wordSize`](#val-wordsize) bits of `i`.

A negative `i` is taken in two's complement, and what does not fit is
dropped.

**Law** `fromLargeInt (toLargeIntX w) = w`

<details><summary>Tests (15)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `200` &middot; `minus-one` &middot; `minus-three` &middot; `all-ones` &middot; `two-to-the-wordSize` &middot; `two-to-the-wordSize-plus-five` &middot; `minus-two-to-the-wordSize-minus-three` &middot; `two-to-twice-the-wordSize-plus-seven` &middot; `minus-two-to-twice-the-wordSize-minus-one` &middot; `minus-top-bit` &middot; `model*` &middot; `plus-multiple*` &middot; `minus-multiple*` &middot; `signed*`

</details>

### <a name="val-toint"></a>`toInt`

```sml
val toInt : word -> int
```

`toInt w` is the number that `w` stands for as an [`Int.int`](../sig/INTEGER.md#type-int).

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if that number is outside the range of [`Int.int`](../sig/INTEGER.md#type-int),
which a word as wide as an `int` can reach.

<details><summary>Other implementations (1)</summary>

- **SML/NJ (64-bit)** &mdash; LargeWord.toLargeInt of a word with its top bit set is negative, so the conversion through LargeWord that the specification gives for toInt raises no Overflow where toInt does

</details>

<details><summary>Tests (12)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `constant`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `200` &middot; `sum` &middot; `all-ones` &middot; `top-bit` &middot; `Overflow-all-ones` &middot; `Overflow-top-bit` &middot; `below-top-bit` &middot; `Overflow-below-top-bit` &middot; `model*`

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `through-LargeWord*`

</details>

### <a name="val-tointx"></a>`toIntX`

```sml
val toIntX : word -> int
```

`toIntX w` is the number that `w` stands for read as a signed one, as an [`Int.int`](../sig/INTEGER.md#type-int).

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if that number is outside the range of [`Int.int`](../sig/INTEGER.md#type-int).

**Example** `Word8.toIntX 0wxFF = ~1`, where `Word8.toInt 0wxFF` is 255.

<details><summary>Tests (15)</summary>

For `Word8`, in [tests/basis/word8.sml](../../../../tests/basis/word8.sml): `all-ones-constant`

For `Word16`, in [tests/basis/intn\_word16.sml](../../../../tests/basis/intn_word16.sml): `all-ones-constant`

For `Word32`, in [tests/basis/intn\_word32.sml](../../../../tests/basis/intn_word32.sml): `all-ones-constant`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `100` &middot; `all-ones` &middot; `all-ones-but-one` &middot; `fromInt-negative` &middot; `below-top-bit` &middot; `top-bit` &middot; `Overflow-below-top-bit` &middot; `Overflow-top-bit` &middot; `model*` &middot; `fromInt*`

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `through-LargeWord*`

</details>

### <a name="val-fromint"></a>`fromInt`

```sml
val fromInt : int -> word
```

`fromInt i` is the word with the low [`wordSize`](#val-wordsize) bits of `i`.

A negative `i` is taken in two's complement.

**Example** `Word8.fromInt 256 = 0w0`

<details><summary>Tests (13)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `decimal-constant` &middot; `hexadecimal-constant`

For `Word8`, in [tests/basis/word8.sml](../../../../tests/basis/word8.sml): `keeps-the-low-byte`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `distinct` &middot; `minus-one` &middot; `minus-two` &middot; `minus-128` &middot; `round-trip` &middot; `Int.maxInt` &middot; `Int.minInt` &middot; `model*` &middot; `samples-built`

In [tests/basis/fn/word\_large\_fn.sml](../../../../tests/basis/fn/word_large_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `through-LargeWord*`

</details>

## Bits

### <a name="val-andb"></a>`andb`

```sml
val andb : word * word -> word
```

`andb (a, b)` is the bitwise "and".

**Example** `andb (0wxF0, 0wx3C) = 0wx30`

<details><summary>Tests (5)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones` &middot; `top-bit` &middot; `model*` &middot; `de-morgan*`

</details>

### <a name="val-orb"></a>`orb`

```sml
val orb : word * word -> word
```

`orb (a, b)` is the bitwise "or".

<details><summary>Tests (5)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones` &middot; `top-bit` &middot; `model*` &middot; `de-morgan*`

</details>

### <a name="val-xorb"></a>`xorb`

```sml
val xorb : word * word -> word
```

`xorb (a, b)` is the bitwise exclusive "or".

**Example** `xorb (0wxFF, 0wx0F) = 0wxF0`

<details><summary>Tests (4)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `top-bit` &middot; `model*` &middot; `orb-minus-andb*`

</details>

### <a name="val-notb"></a>`notb`

```sml
val notb : word -> word
```

`notb w` is `w` with every bit inverted.

**Law** `notb w = ~w - 0w1`

**Example** `Word.notb 0w0 = 0wxFFFFFFFFFFFFFFFF`

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

`<< (w, n)` is `w` shifted left by `n` bits, with zeros coming in and what leaves the width dropped.

A shift of [`wordSize`](#val-wordsize) bits or more gives 0.

**Law** `<< (w, n) = w * 0w2 ^ n` in the arithmetic of this structure

**Example** `<< (0w1, 0w4) = 0w16`

**Example** `Word.<< (0w1, 0w64) = 0w0` for every bit is shifted out.

<details><summary>Tests (11)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `amount-is-a-word`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `one-to-top-bit` &middot; `three-to-top-bit` &middot; `all-ones-to-top-bit` &middot; `all-ones-by-one` &middot; `top-bit-by-one` &middot; `by-*` &middot; `one-by-*` &middot; `model*` &middot; `times-power*`

</details>

### <a name="val-op-gt-gt"></a>`>>`

```sml
val >> : word * Word.word -> word
```

`>> (w, n)` is `w` shifted right by `n` bits, with zeros coming in.

A shift of [`wordSize`](#val-wordsize) bits or more gives 0.

**Law** `>> (w, n) = w div 0w2 ^ n`

**Example** `Word8.>> (0wx80, 0w1) = 0wx40`

<details><summary>Tests (11)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `amount-is-a-word`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `top-bit-to-one` &middot; `all-ones-to-one` &middot; `all-ones-by-one` &middot; `all-ones-by-zero` &middot; `below-top-bit` &middot; `by-*` &middot; `top-bit-by-*` &middot; `model*` &middot; `by-power*`

</details>

### <a name="val-op-tilde-gt-gt"></a>`~>>`

```sml
val ~>> : word * Word.word -> word
```

`~>> (w, n)` is `w` shifted right by `n` bits, with the top bit of `w` coming in.

A shift of [`wordSize`](#val-wordsize) bits or more gives 0 for a word whose top bit is
clear and a word of all ones for one whose top bit is set: it is the
division of a signed number by a power of two, rounded towards negative
infinity.

**Example** `Word8.~>> (0wx80, 0w1) = 0wxC0`

<details><summary>Other implementations (3)</summary>

- **Poly/ML** &mdash; Word8.\~\>\> by a shift of all ones does not give the sign-filled byte
- **Poly/ML** &mdash; \~\>\> by a shift of all ones gives 0, not the word filled with its sign bit
- **Poly/ML** &mdash; Word64.\~\>\> by a shift of 64 or more does not give 0 or all ones: it keeps the word as it is, or only its sign bit (0wx8000000000000000)

</details>

<details><summary>Tests (18)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `amount-is-a-word`

For `Word8`, in [tests/basis/word8.sml](../../../../tests/basis/word8.sml): `sign-bit-constant`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `top-bit-to-all-ones` &middot; `top-bit-by-one` &middot; `all-ones-by-one` &middot; `all-ones-by-zero` &middot; `minus-two-by-one` &middot; `minus-three-by-one` &middot; `minus-100-by-three` &middot; `below-top-bit-to-one` &middot; `below-top-bit-to-zero` &middot; `negative-by-*` &middot; `all-ones-by-*` &middot; `non-negative-by-*` &middot; `one-by-*` &middot; `model*` &middot; `floor-by-power*`

</details>

## Arithmetic

### <a name="val-op-plus"></a>`+`

```sml
val + : word * word -> word
```

`a + b` is the sum, taken modulo `2^wordSize`.

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

`a - b` is the difference, taken modulo `2^wordSize`: it wraps round for `a < b`.

**Example** `Word.- (0w0, 0w1) = 0wxFFFFFFFFFFFFFFFF`

<details><summary>Tests (10)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*` &middot; `toplevel-wraps`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `zero-minus-one` &middot; `three-minus-five` &middot; `top-bit-minus-one` &middot; `zero-minus-all-ones` &middot; `below-top-bit-minus-all-ones` &middot; `model*` &middot; `plus-complement*`

</details>

### <a name="val-op-star"></a>`*`

```sml
val * : word * word -> word
```

`a * b` is the product, taken modulo `2^wordSize`.

<details><summary>Tests (9)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones-squared` &middot; `all-ones-times-two` &middot; `top-bit-times-two` &middot; `top-bit-times-three` &middot; `top-bit-squared` &middot; `all-ones-times-five` &middot; `model*`

</details>

### <a name="val-div"></a>`div`

```sml
val div : word * word -> word
```

`a div b` is the quotient of two unsigned numbers.

**Raises** [`Div`](../sig/GENERAL.md#exn-div) if `b` is zero.

<details><summary>Tests (15)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*` &middot; `toplevel-Div` (raises Div)

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones-by-one` &middot; `all-ones-by-all-ones` &middot; `all-ones-by-two` &middot; `one-by-all-ones` &middot; `top-bit-by-all-ones` &middot; `all-ones-by-top-bit` &middot; `top-bit-by-two` &middot; `Div` &middot; `Div-zero-by-zero` &middot; `Div-all-ones` &middot; `model*` &middot; `law*`

</details>

### <a name="val-mod"></a>`mod`

```sml
val mod : word * word -> word
```

`a mod b` is what [`div`](#val-div) leaves over.

**Raises** [`Div`](../sig/GENERAL.md#exn-div) if `b` is zero.

**Law** `(a div b) * b + (a mod b) = a`

<details><summary>Tests (13)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*` &middot; `toplevel-Div` (raises Div)

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones-by-two` &middot; `all-ones-by-top-bit` &middot; `top-bit-by-all-ones` &middot; `all-ones-by-all-ones` &middot; `one-by-all-ones` &middot; `Div` &middot; `Div-zero-by-zero` &middot; `Div-all-ones` &middot; `model*` &middot; `less-than-divisor*`

</details>

## Comparing

### <a name="val-compare"></a>`compare`

```sml
val compare : word * word -> order
```

`compare (a, b)` orders two words as unsigned numbers.

<details><summary>Tests (3)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `model*` &middot; `reflexive*`

</details>

### <a name="val-op-lt"></a><a name="val-op-lt-eq"></a><a name="val-op-gt"></a><a name="val-op-gt-eq"></a>`<`, `<=`, `>`, `>=`

```sml
val < : word * word -> bool
val <= : word * word -> bool
val > : word * word -> bool
val >= : word * word -> bool
```

`a < b`, `a <= b`, `a > b` and `a >= b` compare two words as unsigned numbers.

A word whose top bit is set is the larger, not the smaller: at [`Word8`](WORD.md),
`0wxFF > 0w1`.

<details><summary>Tests (5)</summary>

For `Word`, in [tests/basis/word.sml](../../../../tests/basis/word.sml): `toplevel*` &middot; `toplevel-unsigned`

For `Word8`, in [tests/basis/word8.sml](../../../../tests/basis/word8.sml): `overloaded`

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `model*`

</details>

### <a name="val-op-tilde"></a>`~`

```sml
val ~ : word -> word
```

`~w` is the negation modulo `2^wordSize`: the two's complement of `w`.

**Law** `~w = notb w + 0w1`, and `~0w0 = 0w0`

<details><summary>Tests (8)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `zero` &middot; `one` &middot; `all-ones` &middot; `top-bit` &middot; `five` &middot; `fromInt-negative` &middot; `model*` &middot; `notb-plus-one*`

</details>

### <a name="val-min"></a>`min`

```sml
val min : word * word -> word
```

`min (a, b)` is the smaller of the two, as unsigned numbers.

<details><summary>Tests (2)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `model*`

</details>

### <a name="val-max"></a>`max`

```sml
val max : word * word -> word
```

`max (a, b)` is the larger of the two, as unsigned numbers.

<details><summary>Tests (2)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `model*`

</details>

## Text

### <a name="val-fmt"></a>`fmt`

```sml
val fmt : StringCvt.radix -> word -> string
```

`fmt radix w` is the text of `w` in the given base, without a prefix and without a sign.

> **Erratum** `WORD/fmt-Ow`. The specification writes the hexadecimal prefix
> of the samples as `Ow` with the letter O; it is `0w` with the digit
> zero.

**Example** `fmt StringCvt.HEX 0w255 = "FF"`

<details><summary>Tests (2)</summary>

In [tests/basis/fn/word\_scan\_fn.sml](../../../../tests/basis/fn/word_scan_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `model*`

</details>

### <a name="val-tostring"></a>`toString`

```sml
val toString : word -> string
```

`toString w` is the text of `w` in base 16, with the digits `A` to `F` and no prefix.

**Law** `toString w = fmt StringCvt.HEX w`

**Example** `toString 0w255 = "FF"`

<details><summary>Tests (6)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones` &middot; `top-bit` &middot; `below-top-bit` &middot; `model*`

In [tests/basis/fn/word\_scan\_fn.sml](../../../../tests/basis/fn/word_scan_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `fmt-HEX-*`

</details>

### <a name="val-scan"></a>`scan`

```sml
val scan : StringCvt.radix -> (char, 'a) StringCvt.reader -> (word, 'a) StringCvt.reader
```

`scan radix getc strm` reads a word in the given base from `strm`.

It skips initial white space and then takes an optional prefix and the
digits: `0w` in the bases other than [`StringCvt.HEX`](../sig/STRING_CVT.md#con-hex), and in that one
`0wx`, `0wX`, `0x` or `0X`, where `0w` alone is no prefix: of `"0w1F"`
the zero is read. There is no sign. The answer is `SOME (w, rest)`, or `NONE`
when no digit is there.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if the digits name a number of more than [`wordSize`](#val-wordsize)
bits.

> **Reading** `Word.scan/DEC-bare-prefix-0w`. A prefix that no digit follows
> is not a prefix, but its leading `0` is a digit: `"0wxg"` scans as 0 and
> leaves `"wxg"`.

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; scan does not skip vertical tab, form feed and carriage return
- **Poly/ML** &mdash; 0w is not a prefix of the hexadecimal format, but 0w12 is read as 0wx12

</details>

<details><summary>Tests (5)</summary>

In [tests/basis/fn/word\_scan\_fn.sml](../../../../tests/basis/fn/word_scan_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `string-position` &middot; `model*` &middot; `model-prefix-lower-case-rest*` &middot; `fmt-round-trip*`

</details>

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> word option
```

`fromString s` is the word that the text `s` begins with in base 16, or `NONE`.

**Raises** [`Overflow`](../sig/GENERAL.md#exn-overflow) if the digits name a number of more than [`wordSize`](#val-wordsize) bits.

**Law** `fromString s = StringCvt.scanString (scan StringCvt.HEX) s`

**Example** `fromString "0wxff" = SOME 0w255`

**Example** `fromString "ff" = SOME 0w255`

<details><summary>Other implementations (2)</summary>

- **SML/NJ** &mdash; IntInf.fromString and Word.fromString do not skip vertical tab, form feed and carriage return
- **Poly/ML** &mdash; reads 0w12 as 0wx12, but 0w is not a prefix of the hexadecimal format

</details>

<details><summary>Tests (16)</summary>

In [tests/basis/fn/word\_fn.sml](../../../../tests/basis/fn/word_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `*` &middot; `all-ones` &middot; `all-ones-lower-case` &middot; `all-ones-with-prefix` &middot; `all-ones-with-leading-zeros` &middot; `top-bit` &middot; `Overflow-two-to-the-wordSize` &middot; `Overflow-with-prefix` &middot; `Overflow-two-to-the-wordSize-plus-one` &middot; `Overflow-one-more-digit` &middot; `Overflow-after-whitespace` &middot; `Overflow-many-digits` &middot; `model*` &middot; `model-lower-case-with-prefix*` &middot; `round-trip*`

In [tests/basis/fn/word\_scan\_fn.sml](../../../../tests/basis/fn/word_scan_fn.sml), applied to `Word`, `Word8`, `Word16`, `Word32`, `Word64`: `scanString-*`

</details>

## See also

[`INTEGER`](../sig/INTEGER.md), [`INT_INF`](../sig/INT_INF.md), [`BYTE`](../sig/BYTE.md), [`STRING_CVT`](../sig/STRING_CVT.md), [`PACK_WORD`](../sig/PACK_WORD.md)

---

<sub>Generated by runedoc from lib/basis/word\_sig.sml; do not edit.</sub>

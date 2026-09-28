# structure Word64

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; [Structures](../structures.md) &rsaquo; **Word64**

|  |  |
| --- | --- |
| Signature | [`WORD`](../sig/WORD.md) |
| Status | optional |
| Members | 38 |
| Tests | 248 checks |
| Source | [lib/basis/word64.sml](../../../../lib/basis/word64.sml) |

## Synopsis

```sml
structure Word64 :> WORD
```

Word64: the 64-bit words.

The implementation is [`Word`](../str/Word.md), whose width the VM decides, but the type is
sealed away from [`Word.word`](../sig/WORD.md#type-word) so that no program can take the two for one,
which leaves the VM free to choose the width of [`Word`](../str/Word.md). Every operation is
[`Word`](../str/Word.md)'s, so the seal costs nothing.

## Members

What each means is on [`WORD`](../sig/WORD.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`word`](../sig/WORD.md#type-word) | *a type of its own* |
| val | [`*`](../sig/WORD.md#val-op-star) | `Word64.word * Word64.word -> Word64.word` |
| val | [`+`](../sig/WORD.md#val-op-plus) | `Word64.word * Word64.word -> Word64.word` |
| val | [`-`](../sig/WORD.md#val-op-minus) | `Word64.word * Word64.word -> Word64.word` |
| val | [`<`](../sig/WORD.md#val-op-lt) | `Word64.word * Word64.word -> bool` |
| val | [`<<`](../sig/WORD.md#val-op-lt-lt) | `Word64.word * word -> Word64.word` |
| val | [`<=`](../sig/WORD.md#val-op-lt-eq) | `Word64.word * Word64.word -> bool` |
| val | [`>`](../sig/WORD.md#val-op-gt) | `Word64.word * Word64.word -> bool` |
| val | [`>=`](../sig/WORD.md#val-op-gt-eq) | `Word64.word * Word64.word -> bool` |
| val | [`>>`](../sig/WORD.md#val-op-gt-gt) | `Word64.word * word -> Word64.word` |
| val | [`andb`](../sig/WORD.md#val-andb) | `Word64.word * Word64.word -> Word64.word` |
| val | [`compare`](../sig/WORD.md#val-compare) | `Word64.word * Word64.word -> order` |
| val | [`div`](../sig/WORD.md#val-div) | `Word64.word * Word64.word -> Word64.word` |
| val | [`fmt`](../sig/WORD.md#val-fmt) | `StringCvt.radix -> Word64.word -> string` |
| val | [`fromInt`](../sig/WORD.md#val-fromint) | `int -> Word64.word` |
| val | [`fromLarge`](../sig/WORD.md#val-fromlarge) | `word -> Word64.word` |
| val | [`fromLargeInt`](../sig/WORD.md#val-fromlargeint) | `IntInf.int -> Word64.word` |
| val | [`fromLargeWord`](../sig/WORD.md#val-fromlargeword) | `word -> Word64.word` |
| val | [`fromString`](../sig/WORD.md#val-fromstring) | `string -> Word64.word option` |
| val | [`max`](../sig/WORD.md#val-max) | `Word64.word * Word64.word -> Word64.word` |
| val | [`min`](../sig/WORD.md#val-min) | `Word64.word * Word64.word -> Word64.word` |
| val | [`mod`](../sig/WORD.md#val-mod) | `Word64.word * Word64.word -> Word64.word` |
| val | [`notb`](../sig/WORD.md#val-notb) | `Word64.word -> Word64.word` |
| val | [`orb`](../sig/WORD.md#val-orb) | `Word64.word * Word64.word -> Word64.word` |
| val | [`scan`](../sig/WORD.md#val-scan) | `StringCvt.radix -> ('a -> (char * 'a) option) -> 'a -> (Word64.word * 'a) option` |
| val | [`toInt`](../sig/WORD.md#val-toint) | `Word64.word -> int` |
| val | [`toIntX`](../sig/WORD.md#val-tointx) | `Word64.word -> int` |
| val | [`toLarge`](../sig/WORD.md#val-tolarge) | `Word64.word -> word` |
| val | [`toLargeInt`](../sig/WORD.md#val-tolargeint) | `Word64.word -> IntInf.int` |
| val | [`toLargeIntX`](../sig/WORD.md#val-tolargeintx) | `Word64.word -> IntInf.int` |
| val | [`toLargeWord`](../sig/WORD.md#val-tolargeword) | `Word64.word -> word` |
| val | [`toLargeWordX`](../sig/WORD.md#val-tolargewordx) | `Word64.word -> word` |
| val | [`toLargeX`](../sig/WORD.md#val-tolargex) | `Word64.word -> word` |
| val | [`toString`](../sig/WORD.md#val-tostring) | `Word64.word -> string` |
| val | [`wordSize`](../sig/WORD.md#val-wordsize) | `int` |
| val | [`xorb`](../sig/WORD.md#val-xorb) | `Word64.word * Word64.word -> Word64.word` |
| val | [`~`](../sig/WORD.md#val-op-tilde) | `Word64.word -> Word64.word` |
| val | [`~>>`](../sig/WORD.md#val-op-tilde-gt-gt) | `Word64.word * word -> Word64.word` |

<details><summary>Other implementations (8)</summary>

- **MLKit** &mdash; fromLargeInt raises Overflow for a number below \~2^63 instead of taking its low-order wordSize bits: IntInfRep.toWord64 converts a negative number through a checked int64 (a positive one wraps modulo 2^64)
- **SML/NJ** &mdash; IntInf.fromString and Word.fromString do not skip vertical tab, form feed and carriage return
- **MLKit, Poly/ML** &mdash; reads 0w12 as 0wx12, but 0w is not a prefix of the hexadecimal format
- **SML/NJ** &mdash; scan does not skip vertical tab, form feed and carriage return
- **MLKit, Poly/ML** &mdash; 0w is not a prefix of the hexadecimal format, but 0w12 is read as 0wx12
- **SML/NJ (64-bit)** &mdash; Int.fromLarge (LargeWord.toLargeInt w) is fused into a signed test, so the conversion through LargeWord that the specification gives for toInt raises no Overflow where toInt does (docs/bugreport/smlnj/Int.fromLarge/fused-conversions)
- **Poly/ML** &mdash; \~\>\> by a shift of all ones gives 0, not the word filled with its sign bit
- **Poly/ML** &mdash; Word64.\~\>\> by a shift of 64 or more does not give 0 or all ones: it keeps the word as it is, or only its sign bit (0wx8000000000000000)

</details>

---

<sub>Generated by runedoc from lib/basis/word64.sml; do not edit.</sub>

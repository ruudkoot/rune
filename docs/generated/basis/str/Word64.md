# structure Word64

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; [Structures](../structures.md) &rsaquo; **Word64**

|  |  |
| --- | --- |
| Signature | [`WORD`](../sig/WORD.md) |
| Status | optional |
| Members | 38 |
| Tests | 250 checks |
| Source | [lib/basis/word64.sml](../../../../lib/basis/word64.sml) |

## Synopsis

```sml
structure Word64 : WORD
```

Word64: the 64-bit words, and LargeWord, the widest ones, which is the same
structure.

The type is the VM's own 64-bit word and not [`Word.word`](../sig/WORD.md#type-word), whose width the
VM decides (63 bits: a word of the VM with a bit taken for its tag). A
number here is kept in such a word where it fits and in a small object
where it needs the 64th bit. This is the type for hashes, checksums,
random number generators and whatever else is written for 64 bits.

## Members

What each means is on [`WORD`](../sig/WORD.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`word`](../sig/WORD.md#type-word) | `word64` |
| val | [`*`](../sig/WORD.md#val-op-star) | `word64 * word64 -> word64` |
| val | [`+`](../sig/WORD.md#val-op-plus) | `word64 * word64 -> word64` |
| val | [`-`](../sig/WORD.md#val-op-minus) | `word64 * word64 -> word64` |
| val | [`<`](../sig/WORD.md#val-op-lt) | `word64 * word64 -> bool` |
| val | [`<<`](../sig/WORD.md#val-op-lt-lt) | `word64 * word -> word64` |
| val | [`<=`](../sig/WORD.md#val-op-lt-eq) | `word64 * word64 -> bool` |
| val | [`>`](../sig/WORD.md#val-op-gt) | `word64 * word64 -> bool` |
| val | [`>=`](../sig/WORD.md#val-op-gt-eq) | `word64 * word64 -> bool` |
| val | [`>>`](../sig/WORD.md#val-op-gt-gt) | `word64 * word -> word64` |
| val | [`andb`](../sig/WORD.md#val-andb) | `word64 * word64 -> word64` |
| val | [`compare`](../sig/WORD.md#val-compare) | `word64 * word64 -> order` |
| val | [`div`](../sig/WORD.md#val-div) | `word64 * word64 -> word64` |
| val | [`fmt`](../sig/WORD.md#val-fmt) | `StringCvt.radix -> word64 -> string` |
| val | [`fromInt`](../sig/WORD.md#val-fromint) | `int -> word64` |
| val | [`fromLarge`](../sig/WORD.md#val-fromlarge) | `word64 -> word64` |
| val | [`fromLargeInt`](../sig/WORD.md#val-fromlargeint) | `IntInf.int -> word64` |
| val | [`fromLargeWord`](../sig/WORD.md#val-fromlargeword) | `word64 -> word64` |
| val | [`fromString`](../sig/WORD.md#val-fromstring) | `string -> word64 option` |
| val | [`max`](../sig/WORD.md#val-max) | `word64 * word64 -> word64` |
| val | [`min`](../sig/WORD.md#val-min) | `word64 * word64 -> word64` |
| val | [`mod`](../sig/WORD.md#val-mod) | `word64 * word64 -> word64` |
| val | [`notb`](../sig/WORD.md#val-notb) | `word64 -> word64` |
| val | [`orb`](../sig/WORD.md#val-orb) | `word64 * word64 -> word64` |
| val | [`scan`](../sig/WORD.md#val-scan) | `StringCvt.radix -> ('a -> (char * 'a) option) -> 'a -> (word64 * 'a) option` |
| val | [`toInt`](../sig/WORD.md#val-toint) | `word64 -> int` |
| val | [`toIntX`](../sig/WORD.md#val-tointx) | `word64 -> int` |
| val | [`toLarge`](../sig/WORD.md#val-tolarge) | `word64 -> word64` |
| val | [`toLargeInt`](../sig/WORD.md#val-tolargeint) | `word64 -> IntInf.int` |
| val | [`toLargeIntX`](../sig/WORD.md#val-tolargeintx) | `word64 -> IntInf.int` |
| val | [`toLargeWord`](../sig/WORD.md#val-tolargeword) | `word64 -> word64` |
| val | [`toLargeWordX`](../sig/WORD.md#val-tolargewordx) | `word64 -> word64` |
| val | [`toLargeX`](../sig/WORD.md#val-tolargex) | `word64 -> word64` |
| val | [`toString`](../sig/WORD.md#val-tostring) | `word64 -> string` |
| val | [`wordSize`](../sig/WORD.md#val-wordsize) | `int` |
| val | [`xorb`](../sig/WORD.md#val-xorb) | `word64 * word64 -> word64` |
| val | [`~`](../sig/WORD.md#val-op-tilde) | `word64 -> word64` |
| val | [`~>>`](../sig/WORD.md#val-op-tilde-gt-gt) | `word64 * word -> word64` |

<details><summary>Other implementations (8)</summary>

- **MLKit** &mdash; fromLargeInt raises Overflow for a number below \~2^63 instead of taking its low-order wordSize bits: IntInfRep.toWord64 converts a negative number through a checked int64 (a positive one wraps modulo 2^64)
- **SML/NJ** &mdash; IntInf.fromString and Word.fromString do not skip vertical tab, form feed and carriage return
- **MLKit, Poly/ML** &mdash; reads 0w12 as 0wx12, but 0w is not a prefix of the hexadecimal format
- **SML/NJ** &mdash; scan does not skip vertical tab, form feed and carriage return
- **MLKit, Poly/ML** &mdash; 0w is not a prefix of the hexadecimal format, but 0w12 is read as 0wx12
- **SML/NJ (64-bit), SML/NJ development** &mdash; Int.fromLarge (LargeWord.toLargeInt w) is fused into a signed test, so the conversion through LargeWord that the specification gives for toInt raises no Overflow where toInt does (docs/bugreport/smlnj/Int.fromLarge/fused-conversions)
- **Poly/ML** &mdash; \~\>\> by a shift of all ones gives 0, not the word filled with its sign bit
- **Poly/ML** &mdash; Word64.\~\>\> by a shift of 64 or more does not give 0 or all ones: it keeps the word as it is, or only its sign bit (0wx8000000000000000)

</details>

---

<sub>Generated by runedoc from lib/basis/word64.sml; do not edit.</sub>

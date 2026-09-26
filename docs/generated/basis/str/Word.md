# structure Word

[The Standard ML Basis Library](../README.md) &rsaquo; Numbers &rsaquo; [Structures](../structures.md) &rsaquo; **Word**

|  |  |
| --- | --- |
| Signature | [`WORD`](../sig/WORD.md) |
| Status | required |
| Members | 38 |
| Tests | 141 checks |
| Source | [lib/basis/word.sml](../../../../lib/basis/word.sml) |

## Synopsis

```sml
structure Word : WORD
```

Word: unsigned words: 64 bits on the VM. The size is found by shifting a
bit out, so that this file means the same to a system whose word is
narrower.

## Members

What each means is on [`WORD`](../sig/WORD.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`word`](../sig/WORD.md#type-word) | *a type of its own* |
| val | [`*`](../sig/WORD.md#val-op-star) | `word * word -> word` |
| val | [`+`](../sig/WORD.md#val-op-plus) | `word * word -> word` |
| val | [`-`](../sig/WORD.md#val-op-minus) | `word * word -> word` |
| val | [`<`](../sig/WORD.md#val-op-lt) | `word * word -> bool` |
| val | [`<<`](../sig/WORD.md#val-op-lt-lt) | `word * word -> word` |
| val | [`<=`](../sig/WORD.md#val-op-lt-eq) | `word * word -> bool` |
| val | [`>`](../sig/WORD.md#val-op-gt) | `word * word -> bool` |
| val | [`>=`](../sig/WORD.md#val-op-gt-eq) | `word * word -> bool` |
| val | [`>>`](../sig/WORD.md#val-op-gt-gt) | `word * word -> word` |
| val | [`andb`](../sig/WORD.md#val-andb) | `word * word -> word` |
| val | [`compare`](../sig/WORD.md#val-compare) | `word * word -> order` |
| val | [`div`](../sig/WORD.md#val-div) | `word * word -> word` |
| val | [`fmt`](../sig/WORD.md#val-fmt) | `StringCvt.radix -> word -> string` |
| val | [`fromInt`](../sig/WORD.md#val-fromint) | `int -> word` |
| val | [`fromLarge`](../sig/WORD.md#val-fromlarge) | `word -> word` |
| val | [`fromLargeInt`](../sig/WORD.md#val-fromlargeint) | `IntInf.int -> word` |
| val | [`fromLargeWord`](../sig/WORD.md#val-fromlargeword) | `word -> word` |
| val | [`fromString`](../sig/WORD.md#val-fromstring) | `string -> word option` |
| val | [`max`](../sig/WORD.md#val-max) | `word * word -> word` |
| val | [`min`](../sig/WORD.md#val-min) | `word * word -> word` |
| val | [`mod`](../sig/WORD.md#val-mod) | `word * word -> word` |
| val | [`notb`](../sig/WORD.md#val-notb) | `word -> word` |
| val | [`orb`](../sig/WORD.md#val-orb) | `word * word -> word` |
| val | [`scan`](../sig/WORD.md#val-scan) | `StringCvt.radix -> ('a -> (char * 'a) option) -> 'a -> (word * 'a) option` |
| val | [`toInt`](../sig/WORD.md#val-toint) | `word -> int` |
| val | [`toIntX`](../sig/WORD.md#val-tointx) | `word -> int` |
| val | [`toLarge`](../sig/WORD.md#val-tolarge) | `word -> word` |
| val | [`toLargeInt`](../sig/WORD.md#val-tolargeint) | `word -> IntInf.int` |
| val | [`toLargeIntX`](../sig/WORD.md#val-tolargeintx) | `word -> IntInf.int` |
| val | [`toLargeWord`](../sig/WORD.md#val-tolargeword) | `word -> word` |
| val | [`toLargeWordX`](../sig/WORD.md#val-tolargewordx) | `word -> word` |
| val | [`toLargeX`](../sig/WORD.md#val-tolargex) | `word -> word` |
| val | [`toString`](../sig/WORD.md#val-tostring) | `word -> string` |
| val | [`wordSize`](../sig/WORD.md#val-wordsize) | `int` |
| val | [`xorb`](../sig/WORD.md#val-xorb) | `word * word -> word` |
| val | [`~`](../sig/WORD.md#val-op-tilde) | `word -> word` |
| val | [`~>>`](../sig/WORD.md#val-op-tilde-gt-gt) | `word * word -> word` |

## Notes

### scan

> **Reading** `Word.scan/DEC-bare-prefix-0w`. A prefix that no digit follows
> is not a prefix, but its leading `0` is a digit: `"0wxg"` scans as 0 and
> leaves `"wxg"`.

### word

> **Implementation** `Word.word/64-bits`. [`Word.word`](../sig/WORD.md#type-word) is the top-level
> [`word`](../sig/WORD.md#type-word), of 64 bits, and so are [`LargeWord`](Word.md), [`SysWord`](Word.md) and [`Word64`](Word.md);
> [`Word8`](../str/Word8.md), [`Word16`](../str/Word16.md) and [`Word32`](../str/Word32.md) are kept in a word of the machine whose
> upper bits are zero.

> **Implementation** `Word.word/constants-overloaded`. A word constant has the
> word type that its context asks for, [`Word8.word`](../sig/WORD.md#type-word) as well as [`word`](../sig/WORD.md#type-word), and
> is checked against the range of that type when the program is compiled;
> [`~`](../sig/WORD.md#val-op-tilde) is there for words too. Integer constants are overloaded at
> [`IntInf.int`](../sig/INTEGER.md#type-int) and the `IntN`, real ones at [`Real32.real`](../sig/REAL.md#type-real), and character and
> string constants at [`WideChar.char`](../sig/CHAR.md#type-char) and [`WideString.string`](../sig/STRING.md#type-string).

<details><summary>Other implementations (4)</summary>

- **SML/NJ** &mdash; IntInf.fromString and Word.fromString do not skip vertical tab, form feed and carriage return
- **Poly/ML** &mdash; reads 0w12 as 0wx12, but 0w is not a prefix of the hexadecimal format
- **SML/NJ** &mdash; scan does not skip vertical tab, form feed and carriage return
- **Poly/ML** &mdash; 0w is not a prefix of the hexadecimal format, but 0w12 is read as 0wx12

</details>

---

<sub>Generated by runedoc from lib/basis/word.sml; do not edit.</sub>

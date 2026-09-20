# signature WORD

[The Standard ML Basis Library](../README.md) &rsaquo; **WORD**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 5 |
| Documentation | 0 of 38 entries documented |
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

### <a name="val-wordsize"></a>`wordSize`

```sml
val wordSize : int
```

### <a name="val-tolarge"></a>`toLarge`

```sml
val toLarge : word -> LargeWord.word
```

### <a name="val-tolargex"></a>`toLargeX`

```sml
val toLargeX : word -> LargeWord.word
```

### <a name="val-tolargeword"></a>`toLargeWord`

```sml
val toLargeWord : word -> LargeWord.word
```

### <a name="val-tolargewordx"></a>`toLargeWordX`

```sml
val toLargeWordX : word -> LargeWord.word
```

### <a name="val-fromlarge"></a>`fromLarge`

```sml
val fromLarge : LargeWord.word -> word
```

### <a name="val-fromlargeword"></a>`fromLargeWord`

```sml
val fromLargeWord : LargeWord.word -> word
```

### <a name="val-tolargeint"></a>`toLargeInt`

```sml
val toLargeInt : word -> LargeInt.int
```

### <a name="val-tolargeintx"></a>`toLargeIntX`

```sml
val toLargeIntX : word -> LargeInt.int
```

### <a name="val-fromlargeint"></a>`fromLargeInt`

```sml
val fromLargeInt : LargeInt.int -> word
```

### <a name="val-toint"></a>`toInt`

```sml
val toInt : word -> int
```

### <a name="val-tointx"></a>`toIntX`

```sml
val toIntX : word -> int
```

### <a name="val-fromint"></a>`fromInt`

```sml
val fromInt : int -> word
```

### <a name="val-andb"></a>`andb`

```sml
val andb : word * word -> word
```

### <a name="val-orb"></a>`orb`

```sml
val orb : word * word -> word
```

### <a name="val-xorb"></a>`xorb`

```sml
val xorb : word * word -> word
```

### <a name="val-notb"></a>`notb`

```sml
val notb : word -> word
```

### <a name="val-op-lt-lt"></a>`<<`

```sml
val << : word * Word.word -> word
```

### <a name="val-op-gt-gt"></a>`>>`

```sml
val >> : word * Word.word -> word
```

### <a name="val-op-tilde-gt-gt"></a>`~>>`

```sml
val ~>> : word * Word.word -> word
```

### <a name="val-op-plus"></a>`+`

```sml
val + : word * word -> word
```

### <a name="val-op-minus"></a>`-`

```sml
val - : word * word -> word
```

### <a name="val-op-star"></a>`*`

```sml
val * : word * word -> word
```

### <a name="val-div"></a>`div`

```sml
val div : word * word -> word
```

### <a name="val-mod"></a>`mod`

```sml
val mod : word * word -> word
```

### <a name="val-compare"></a>`compare`

```sml
val compare : word * word -> order
```

### <a name="val-op-lt"></a>`<`

```sml
val < : word * word -> bool
```

### <a name="val-op-lt-eq"></a>`<=`

```sml
val <= : word * word -> bool
```

### <a name="val-op-gt"></a>`>`

```sml
val > : word * word -> bool
```

### <a name="val-op-gt-eq"></a>`>=`

```sml
val >= : word * word -> bool
```

### <a name="val-op-tilde"></a>`~`

```sml
val ~ : word -> word
```

### <a name="val-min"></a>`min`

```sml
val min : word * word -> word
```

### <a name="val-max"></a>`max`

```sml
val max : word * word -> word
```

### <a name="val-fmt"></a>`fmt`

```sml
val fmt : StringCvt.radix -> word -> string
```

### <a name="val-tostring"></a>`toString`

```sml
val toString : word -> string
```

### <a name="val-scan"></a>`scan`

```sml
val scan : StringCvt.radix -> (char, 'a) StringCvt.reader -> (word, 'a) StringCvt.reader
```

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> word option
```

---

<sub>Generated by runedoc from lib/basis/word\_sig.sml; do not edit.</sub>

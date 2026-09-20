# signature INTEGER

[The Standard ML Basis Library](../README.md) &rsaquo; **INTEGER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 7 |
| Documentation | 0 of 30 entries documented |
| Source | [lib/basis/int\_sig.sml](../../../../lib/basis/int_sig.sml) |

## Synopsis

```sml
signature INTEGER
structure Int : INTEGER
structure Int16 : INTEGER  (* optional *)
structure Int32 : INTEGER  (* optional *)
structure Int64 : INTEGER  (* optional *)
structure Int8 : INTEGER  (* optional *)
structure IntInf : INTEGER  (* optional *)
structure LargeInt : INTEGER
```

| Implementation |  | Source |
| --- | --- | --- |
| `Int` | Int: fixed precision integers with Overflow checking: 64 bits on the VM. The bounds are found with the arithmetic itself (2n + 1 until it overflows), so that this file means the same to a system whose int is narrower; see tests/basis/README.md on the xc1 configurations. | [lib/basis/int.sml](../../../../lib/basis/int.sml) |
| `Int16` | Int16: integers of 16 bits. | [lib/basis/int16.sml](../../../../lib/basis/int16.sml) |
| `Int32` | Int32: integers of 32 bits. | [lib/basis/int32.sml](../../../../lib/basis/int32.sml) |
| `Int64` | Int64 is Int, which has 64 bits, and so is FixedInt, the largest of the fixed-precision integers. | [lib/basis/int64.sml](../../../../lib/basis/int64.sml) |
| `Int8` | Int8: integers of 8 bits. | [lib/basis/int8.sml](../../../../lib/basis/int8.sml) |
| `IntInf` | IntInf: arbitrary precision integers implemented in SML on top of the 64-bit int. A value is a sign and a little-endian list of base-2^30 limbs without high zero limbs; zero is never negative. The representation is therefore canonical and structural equality is value equality. | [lib/basis/intinf.sml](../../../../lib/basis/intinf.sml) |
| `LargeInt` | The largest integers are the arbitrary precision ones. | [lib/basis/intinf.sml](../../../../lib/basis/intinf.sml) |

signature INTEGER, which the IntN structures are sealed with.

## Interface

<pre>
signature INTEGER =
sig
  eqtype <a href="#type-int">int</a>
  val <a href="#val-tolarge">toLarge</a> : int -&gt; LargeInt.int
  val <a href="#val-fromlarge">fromLarge</a> : LargeInt.int -&gt; int
  val <a href="#val-toint">toInt</a> : int -&gt; Int.int
  val <a href="#val-fromint">fromInt</a> : Int.int -&gt; int
  val <a href="#val-precision">precision</a> : Int.int option
  val <a href="#val-minint">minInt</a> : int option
  val <a href="#val-maxint">maxInt</a> : int option
  val <a href="#val-op-plus">+</a> : int * int -&gt; int
  val <a href="#val-op-minus">-</a> : int * int -&gt; int
  val <a href="#val-op-star">*</a> : int * int -&gt; int
  val <a href="#val-div">div</a> : int * int -&gt; int
  val <a href="#val-mod">mod</a> : int * int -&gt; int
  val <a href="#val-quot">quot</a> : int * int -&gt; int
  val <a href="#val-rem">rem</a> : int * int -&gt; int
  val <a href="#val-compare">compare</a> : int * int -&gt; order
  val <a href="#val-op-lt">&lt;</a> : int * int -&gt; bool
  val <a href="#val-op-lt-eq">&lt;=</a> : int * int -&gt; bool
  val <a href="#val-op-gt">&gt;</a> : int * int -&gt; bool
  val <a href="#val-op-gt-eq">&gt;=</a> : int * int -&gt; bool
  val <a href="#val-op-tilde">~</a> : int -&gt; int
  val <a href="#val-abs">abs</a> : int -&gt; int
  val <a href="#val-min">min</a> : int * int -&gt; int
  val <a href="#val-max">max</a> : int * int -&gt; int
  val <a href="#val-sign">sign</a> : int -&gt; Int.int
  val <a href="#val-samesign">sameSign</a> : int * int -&gt; bool
  val <a href="#val-fmt">fmt</a> : StringCvt.radix -&gt; int -&gt; string
  val <a href="#val-tostring">toString</a> : int -&gt; string
  val <a href="#val-scan">scan</a> : StringCvt.radix -&gt; (char, 'a) StringCvt.reader -&gt; (int, 'a) StringCvt.reader
  val <a href="#val-fromstring">fromString</a> : string -&gt; int option
end
</pre>

### <a name="type-int"></a>`int`

```sml
eqtype int
```

### <a name="val-tolarge"></a>`toLarge`

```sml
val toLarge : int -> LargeInt.int
```

### <a name="val-fromlarge"></a>`fromLarge`

```sml
val fromLarge : LargeInt.int -> int
```

### <a name="val-toint"></a>`toInt`

```sml
val toInt : int -> Int.int
```

### <a name="val-fromint"></a>`fromInt`

```sml
val fromInt : Int.int -> int
```

### <a name="val-precision"></a>`precision`

```sml
val precision : Int.int option
```

### <a name="val-minint"></a>`minInt`

```sml
val minInt : int option
```

### <a name="val-maxint"></a>`maxInt`

```sml
val maxInt : int option
```

### <a name="val-op-plus"></a>`+`

```sml
val + : int * int -> int
```

### <a name="val-op-minus"></a>`-`

```sml
val - : int * int -> int
```

### <a name="val-op-star"></a>`*`

```sml
val * : int * int -> int
```

### <a name="val-div"></a>`div`

```sml
val div : int * int -> int
```

### <a name="val-mod"></a>`mod`

```sml
val mod : int * int -> int
```

### <a name="val-quot"></a>`quot`

```sml
val quot : int * int -> int
```

### <a name="val-rem"></a>`rem`

```sml
val rem : int * int -> int
```

### <a name="val-compare"></a>`compare`

```sml
val compare : int * int -> order
```

### <a name="val-op-lt"></a>`<`

```sml
val < : int * int -> bool
```

### <a name="val-op-lt-eq"></a>`<=`

```sml
val <= : int * int -> bool
```

### <a name="val-op-gt"></a>`>`

```sml
val > : int * int -> bool
```

### <a name="val-op-gt-eq"></a>`>=`

```sml
val >= : int * int -> bool
```

### <a name="val-op-tilde"></a>`~`

```sml
val ~ : int -> int
```

### <a name="val-abs"></a>`abs`

```sml
val abs : int -> int
```

### <a name="val-min"></a>`min`

```sml
val min : int * int -> int
```

### <a name="val-max"></a>`max`

```sml
val max : int * int -> int
```

### <a name="val-sign"></a>`sign`

```sml
val sign : int -> Int.int
```

### <a name="val-samesign"></a>`sameSign`

```sml
val sameSign : int * int -> bool
```

### <a name="val-fmt"></a>`fmt`

```sml
val fmt : StringCvt.radix -> int -> string
```

### <a name="val-tostring"></a>`toString`

```sml
val toString : int -> string
```

### <a name="val-scan"></a>`scan`

```sml
val scan : StringCvt.radix -> (char, 'a) StringCvt.reader -> (int, 'a) StringCvt.reader
```

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> int option
```

---

<sub>Generated by runedoc from lib/basis/int\_sig.sml; do not edit.</sub>

# signature REAL

[The Standard ML Basis Library](../README.md) &rsaquo; **REAL**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 3 |
| Documentation | 0 of 64 entries documented |
| Source | [lib/basis/sig\_real.sml](../../../../lib/basis/sig_real.sml) |

## Synopsis

```sml
signature REAL
structure LargeReal : REAL
structure Real : REAL where type real = real
structure Real32 :> REAL  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `LargeReal` |  | [lib/basis/real.sml](../../../../lib/basis/real.sml) |
| `Real` | Real: IEEE double precision. | [lib/basis/real.sml](../../../../lib/basis/real.sml) |
| `Real32` |  | [lib/basis/real32.sml](../../../../lib/basis/real32.sml) |

signature REAL, transcribed from <https://smlfamily.github.io/Basis/real.html>

Uses MATH (spec-sigs/MATH.sml), which has to be loaded first: the page
specifies `structure Math : MATH where type real = real`.

## Interface

<pre>
signature REAL =
sig
  type <a href="#type-real">real</a>

  structure <a href="#str-math">Math</a> : MATH where type real = real

  val <a href="#val-radix">radix</a> : int
  val <a href="#val-precision">precision</a> : int
  val <a href="#val-maxfinite">maxFinite</a> : real
  val <a href="#val-minpos">minPos</a> : real
  val <a href="#val-minnormalpos">minNormalPos</a> : real
  val <a href="#val-posinf">posInf</a> : real
  val <a href="#val-neginf">negInf</a> : real

  val <a href="#val-op-plus">+</a> : real * real -&gt; real
  val <a href="#val-op-minus">-</a> : real * real -&gt; real
  val <a href="#val-op-star">*</a> : real * real -&gt; real
  val <a href="#val-op-slash">/</a> : real * real -&gt; real
  val <a href="#val-rem">rem</a> : real * real -&gt; real
  val <a href="#val-op-star-plus">*+</a> : real * real * real -&gt; real
  val <a href="#val-op-star-minus">*-</a> : real * real * real -&gt; real
  val <a href="#val-op-tilde">~</a> : real -&gt; real
  val <a href="#val-abs">abs</a> : real -&gt; real

  val <a href="#val-min">min</a> : real * real -&gt; real
  val <a href="#val-max">max</a> : real * real -&gt; real

  val <a href="#val-sign">sign</a> : real -&gt; int
  val <a href="#val-signbit">signBit</a> : real -&gt; bool
  val <a href="#val-samesign">sameSign</a> : real * real -&gt; bool
  val <a href="#val-copysign">copySign</a> : real * real -&gt; real

  val <a href="#val-compare">compare</a> : real * real -&gt; order
  val <a href="#val-comparereal">compareReal</a> : real * real -&gt; IEEEReal.real_order
  val <a href="#val-op-lt">&lt;</a> : real * real -&gt; bool
  val <a href="#val-op-lt-eq">&lt;=</a> : real * real -&gt; bool
  val <a href="#val-op-gt">&gt;</a> : real * real -&gt; bool
  val <a href="#val-op-gt-eq">&gt;=</a> : real * real -&gt; bool
  val <a href="#val-op-eq-eq">==</a> : real * real -&gt; bool
  val <a href="#val-op-bang-eq">!=</a> : real * real -&gt; bool
  val <a href="#val-op-question-eq">?=</a> : real * real -&gt; bool
  val <a href="#val-unordered">unordered</a> : real * real -&gt; bool

  val <a href="#val-isfinite">isFinite</a> : real -&gt; bool
  val <a href="#val-isnan">isNan</a> : real -&gt; bool
  val <a href="#val-isnormal">isNormal</a> : real -&gt; bool
  val <a href="#val-class">class</a> : real -&gt; IEEEReal.float_class

  val <a href="#val-tomanexp">toManExp</a> : real -&gt; {<a href="#fld-tomanexp.man">man</a> : real, <a href="#fld-tomanexp.exp">exp</a> : int}
  val <a href="#val-frommanexp">fromManExp</a> : {<a href="#fld-frommanexp.man">man</a> : real, <a href="#fld-frommanexp.exp">exp</a> : int} -&gt; real
  val <a href="#val-split">split</a> : real -&gt; {<a href="#fld-split.whole">whole</a> : real, <a href="#fld-split.frac">frac</a> : real}
  val <a href="#val-realmod">realMod</a> : real -&gt; real

  val <a href="#val-nextafter">nextAfter</a> : real * real -&gt; real
  val <a href="#val-checkfloat">checkFloat</a> : real -&gt; real

  val <a href="#val-realfloor">realFloor</a> : real -&gt; real
  val <a href="#val-realceil">realCeil</a> : real -&gt; real
  val <a href="#val-realtrunc">realTrunc</a> : real -&gt; real
  val <a href="#val-realround">realRound</a> : real -&gt; real
  val <a href="#val-floor">floor</a> : real -&gt; int
  val <a href="#val-ceil">ceil</a> : real -&gt; int
  val <a href="#val-trunc">trunc</a> : real -&gt; int
  val <a href="#val-round">round</a> : real -&gt; int
  val <a href="#val-toint">toInt</a> : IEEEReal.rounding_mode -&gt; real -&gt; int
  val <a href="#val-tolargeint">toLargeInt</a> : IEEEReal.rounding_mode -&gt; real -&gt; LargeInt.int
  val <a href="#val-fromint">fromInt</a> : int -&gt; real
  val <a href="#val-fromlargeint">fromLargeInt</a> : LargeInt.int -&gt; real
  val <a href="#val-tolarge">toLarge</a> : real -&gt; LargeReal.real
  val <a href="#val-fromlarge">fromLarge</a> : IEEEReal.rounding_mode -&gt; LargeReal.real -&gt; real

  val <a href="#val-fmt">fmt</a> : StringCvt.realfmt -&gt; real -&gt; string
  val <a href="#val-tostring">toString</a> : real -&gt; string
  val <a href="#val-scan">scan</a> : (char, 'a) StringCvt.reader -&gt; (real, 'a) StringCvt.reader
  val <a href="#val-fromstring">fromString</a> : string -&gt; real option

  val <a href="#val-todecimal">toDecimal</a> : real -&gt; IEEEReal.decimal_approx
  val <a href="#val-fromdecimal">fromDecimal</a> : IEEEReal.decimal_approx -&gt; real option
end
</pre>

### <a name="type-real"></a>`real`

```sml
type real
```

### <a name="str-math"></a>`Math`

```sml
structure Math : MATH where type real = real
```

A substructure: its members are described on the page of [`MATH`](../sig/MATH.md).

### <a name="val-radix"></a>`radix`

```sml
val radix : int
```

### <a name="val-precision"></a>`precision`

```sml
val precision : int
```

### <a name="val-maxfinite"></a>`maxFinite`

```sml
val maxFinite : real
```

### <a name="val-minpos"></a>`minPos`

```sml
val minPos : real
```

### <a name="val-minnormalpos"></a>`minNormalPos`

```sml
val minNormalPos : real
```

### <a name="val-posinf"></a>`posInf`

```sml
val posInf : real
```

### <a name="val-neginf"></a>`negInf`

```sml
val negInf : real
```

### <a name="val-op-plus"></a>`+`

```sml
val + : real * real -> real
```

### <a name="val-op-minus"></a>`-`

```sml
val - : real * real -> real
```

### <a name="val-op-star"></a>`*`

```sml
val * : real * real -> real
```

### <a name="val-op-slash"></a>`/`

```sml
val / : real * real -> real
```

### <a name="val-rem"></a>`rem`

```sml
val rem : real * real -> real
```

### <a name="val-op-star-plus"></a>`*+`

```sml
val *+ : real * real * real -> real
```

### <a name="val-op-star-minus"></a>`*-`

```sml
val *- : real * real * real -> real
```

### <a name="val-op-tilde"></a>`~`

```sml
val ~ : real -> real
```

### <a name="val-abs"></a>`abs`

```sml
val abs : real -> real
```

### <a name="val-min"></a>`min`

```sml
val min : real * real -> real
```

### <a name="val-max"></a>`max`

```sml
val max : real * real -> real
```

### <a name="val-sign"></a>`sign`

```sml
val sign : real -> int
```

### <a name="val-signbit"></a>`signBit`

```sml
val signBit : real -> bool
```

### <a name="val-samesign"></a>`sameSign`

```sml
val sameSign : real * real -> bool
```

### <a name="val-copysign"></a>`copySign`

```sml
val copySign : real * real -> real
```

### <a name="val-compare"></a>`compare`

```sml
val compare : real * real -> order
```

### <a name="val-comparereal"></a>`compareReal`

```sml
val compareReal : real * real -> IEEEReal.real_order
```

### <a name="val-op-lt"></a>`<`

```sml
val < : real * real -> bool
```

### <a name="val-op-lt-eq"></a>`<=`

```sml
val <= : real * real -> bool
```

### <a name="val-op-gt"></a>`>`

```sml
val > : real * real -> bool
```

### <a name="val-op-gt-eq"></a>`>=`

```sml
val >= : real * real -> bool
```

### <a name="val-op-eq-eq"></a>`==`

```sml
val == : real * real -> bool
```

### <a name="val-op-bang-eq"></a>`!=`

```sml
val != : real * real -> bool
```

### <a name="val-op-question-eq"></a>`?=`

```sml
val ?= : real * real -> bool
```

### <a name="val-unordered"></a>`unordered`

```sml
val unordered : real * real -> bool
```

### <a name="val-isfinite"></a>`isFinite`

```sml
val isFinite : real -> bool
```

### <a name="val-isnan"></a>`isNan`

```sml
val isNan : real -> bool
```

### <a name="val-isnormal"></a>`isNormal`

```sml
val isNormal : real -> bool
```

### <a name="val-class"></a>`class`

```sml
val class : real -> IEEEReal.float_class
```

### <a name="val-tomanexp"></a>`toManExp`

```sml
val toManExp : real -> {man : real, exp : int}
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-tomanexp.man"></a>`man` | `real` |  |
| <a name="fld-tomanexp.exp"></a>`exp` | `int` |  |

### <a name="val-frommanexp"></a>`fromManExp`

```sml
val fromManExp : {man : real, exp : int} -> real
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-frommanexp.man"></a>`man` | `real` |  |
| <a name="fld-frommanexp.exp"></a>`exp` | `int` |  |

### <a name="val-split"></a>`split`

```sml
val split : real -> {whole : real, frac : real}
```

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-split.whole"></a>`whole` | `real` |  |
| <a name="fld-split.frac"></a>`frac` | `real` |  |

### <a name="val-realmod"></a>`realMod`

```sml
val realMod : real -> real
```

### <a name="val-nextafter"></a>`nextAfter`

```sml
val nextAfter : real * real -> real
```

### <a name="val-checkfloat"></a>`checkFloat`

```sml
val checkFloat : real -> real
```

### <a name="val-realfloor"></a>`realFloor`

```sml
val realFloor : real -> real
```

### <a name="val-realceil"></a>`realCeil`

```sml
val realCeil : real -> real
```

### <a name="val-realtrunc"></a>`realTrunc`

```sml
val realTrunc : real -> real
```

### <a name="val-realround"></a>`realRound`

```sml
val realRound : real -> real
```

### <a name="val-floor"></a>`floor`

```sml
val floor : real -> int
```

Also in the [top-level environment](../top-level.md): `floor`.

### <a name="val-ceil"></a>`ceil`

```sml
val ceil : real -> int
```

Also in the [top-level environment](../top-level.md): `ceil`.

### <a name="val-trunc"></a>`trunc`

```sml
val trunc : real -> int
```

Also in the [top-level environment](../top-level.md): `trunc`.

### <a name="val-round"></a>`round`

```sml
val round : real -> int
```

Also in the [top-level environment](../top-level.md): `round`.

### <a name="val-toint"></a>`toInt`

```sml
val toInt : IEEEReal.rounding_mode -> real -> int
```

### <a name="val-tolargeint"></a>`toLargeInt`

```sml
val toLargeInt : IEEEReal.rounding_mode -> real -> LargeInt.int
```

### <a name="val-fromint"></a>`fromInt`

```sml
val fromInt : int -> real
```

Also in the [top-level environment](../top-level.md): `real`.

### <a name="val-fromlargeint"></a>`fromLargeInt`

```sml
val fromLargeInt : LargeInt.int -> real
```

### <a name="val-tolarge"></a>`toLarge`

```sml
val toLarge : real -> LargeReal.real
```

### <a name="val-fromlarge"></a>`fromLarge`

```sml
val fromLarge : IEEEReal.rounding_mode -> LargeReal.real -> real
```

### <a name="val-fmt"></a>`fmt`

```sml
val fmt : StringCvt.realfmt -> real -> string
```

### <a name="val-tostring"></a>`toString`

```sml
val toString : real -> string
```

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (real, 'a) StringCvt.reader
```

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : string -> real option
```

### <a name="val-todecimal"></a>`toDecimal`

```sml
val toDecimal : real -> IEEEReal.decimal_approx
```

### <a name="val-fromdecimal"></a>`fromDecimal`

```sml
val fromDecimal : IEEEReal.decimal_approx -> real option
```

---

<sub>Generated by runedoc from lib/basis/sig\_real.sml; do not edit.</sub>

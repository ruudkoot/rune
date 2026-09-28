# signature PROP

[Property testing](../README.md) &rsaquo; Property testing &rsaquo; **PROP**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 13 of 13 entries documented |
| Tests | not listed |
| Source | [lib/test/property/prop\_sig.sml](../../../../../lib/test/property/prop_sig.sml) |

## Synopsis

```sml
signature PROP
structure Prop :> PROP
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Prop`](../str/Prop.md) |  | [lib/test/property/prop.sml](../../../../../lib/test/property/prop.sml) |

Properties: what must hold for every value a generator draws.

A property is run on many cases, each drawn from its own source. It
passes, fails with a class (`false`, or the exception a side raised) and a
message, or is discarded because a condition does not hold. Two sides of
a law are compared as outcomes: equal values, or the same exception
(docs/plans/quickcheck.md, D6).

## Interface

<pre>
signature PROP =
sig
  type <a href="#type-prop">prop</a>
  datatype <a href="#type-verdict">verdict</a> = <a href="#con-pass">Pass</a> | <a href="#con-fail">Fail</a> of {<a href="#fld-fail.class">class</a> : string, <a href="#fld-fail.message">message</a> : string} | <a href="#con-discard">Discard</a>
  type <a href="#type-result">result</a> = {<a href="#fld-result.verdict">verdict</a> : verdict, <a href="#fld-result.shown">shown</a> : string list, <a href="#fld-result.labels">labels</a> : string list,
                 <a href="#fld-result.covers">covers</a> : (string * real * bool) list}
  val <a href="#val-run">run</a> : prop -&gt; PropertySource.source * Word64.word -&gt; result
  val <a href="#val-holds">holds</a> : bool -&gt; prop
  val <a href="#val-forall">forAll</a> : 'a Arb.arb -&gt; ('a -&gt; prop) -&gt; prop
  val <a href="#val-forallgen">forAllGen</a> : 'a Gen.gen * ('a -&gt; string) -&gt; ('a -&gt; prop) -&gt; prop
  val <a href="#val-equal">equal</a> : 'a Arb.arb -&gt; (unit -&gt; 'a) * (unit -&gt; 'a) -&gt; prop
  val <a href="#val-law">law</a> : 'a Arb.arb * 'b Arb.arb -&gt; ('a -&gt; 'b) * ('a -&gt; 'b) -&gt; prop
  val <a href="#val-op-eq-eq-gt">==&gt;</a> : bool * (unit -&gt; prop) -&gt; prop
  val <a href="#val-label">label</a> : string -&gt; prop -&gt; prop
  val <a href="#val-classify">classify</a> : bool -&gt; string -&gt; prop -&gt; prop
  val <a href="#val-cover">cover</a> : real -&gt; bool -&gt; string -&gt; prop -&gt; prop
end
</pre>

### <a name="type-prop"></a>`prop`

```sml
type prop
```

A property.

### <a name="type-verdict"></a>`verdict`

```sml
datatype verdict = Pass | Fail of {class : string, message : string} | Discard
```

What a property does with one case.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-pass"></a>`Pass` |  |  |
| <a name="con-fail"></a>`Fail` | `{class : string, message : string}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-fail.class"></a>`class` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-fail.message"></a>`message` | `string` |  |
| <a name="con-discard"></a>`Discard` |  |  |

### <a name="type-result"></a>`result`

```sml
type result = {verdict : verdict, shown : string list, labels : string list,
               covers : (string * real * bool) list}
```

What a case gave: its verdict, the values drawn (shown, outermost
first), and its labels, with the coverages it asks for.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-result.verdict"></a>`verdict` | `verdict` |  |
| <a name="fld-result.shown"></a>`shown` | `string list` |  |
| <a name="fld-result.labels"></a>`labels` | `string list` |  |
| <a name="fld-result.covers"></a>`covers` | `(string * real * bool) list` |  |

### <a name="val-run"></a>`run`

```sml
val run : prop -> PropertySource.source * Word64.word -> result
```

`run p (source, address)` runs `p` on the case of `source`: what the
runner does.

### <a name="val-holds"></a>`holds`

```sml
val holds : bool -> prop
```

`holds b` passes when `b` is `true`.

### <a name="val-forall"></a>`forAll`

```sml
val forAll : 'a Arb.arb -> ('a -> prop) -> prop
```

`forAll a f` is the property `f x` for every `x` that `a` draws. An
exception that `f x` raises fails the case, with the exception's name as
its class.

### <a name="val-forallgen"></a>`forAllGen`

```sml
val forAllGen : 'a Gen.gen * ('a -> string) -> ('a -> prop) -> prop
```

`forAllGen (g, show) f` is [`forAll`](#val-forall) with a generator and a printer.

### <a name="val-equal"></a>`equal`

```sml
val equal : 'a Arb.arb -> (unit -> 'a) * (unit -> 'a) -> prop
```

`equal a (l, r)` passes when `l ()` and `r ()` have the same outcome:
values equal by `a`, or the same exception.

### <a name="val-law"></a>`law`

```sml
val law : 'a Arb.arb * 'b Arb.arb -> ('a -> 'b) * ('a -> 'b) -> prop
```

`law (a, b) (l, r)` is the property that `l x` and `r x` have the same outcome.

It is `forAll a` of `equal b (fn () => l x, fn () => r x)`, except that
each side is given its own `x`, drawn anew from the same part of the
tree: a side that changes an array or calls a function with effects does
not change what the other side sees.

### <a name="val-op-eq-eq-gt"></a>`==>`

```sml
val ==> : bool * (unit -> prop) -> prop
```

`==> (cond, p)` is `p ()` where `cond` holds, and discards the case where it does not.

With `infix ==>` it is written `cond ==> p`.

### <a name="val-label"></a>`label`

```sml
val label : string -> prop -> prop
```

`label l p` is `p`, with the case counted under `l` in the report.

### <a name="val-classify"></a>`classify`

```sml
val classify : bool -> string -> prop -> prop
```

`classify b l p` is `label l p` where `b` holds, and `p` otherwise.

### <a name="val-cover"></a>`cover`

```sml
val cover : real -> bool -> string -> prop -> prop
```

`cover pct b l p` is `classify b l p`, and asks that at least `pct`
percent of the cases be so; the report fails a run that falls short.

---

<sub>Generated by runedoc from lib/test/property/prop\_sig.sml; do not edit.</sub>

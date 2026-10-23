# signature C_INTEGER

[C declaration frontend](../README.md) &rsaquo; Languages &rsaquo; **C_INTEGER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 13 of 13 entries documented |
| Tests | not listed |
| Source | [lib/language/c/integer\_sig.sml](../../../../../lib/language/c/integer_sig.sml) |

## Synopsis

```sml
signature C_INTEGER
structure CInteger : C_INTEGER
```

| Implementation |  | Source |
| --- | --- | --- |
| [`CInteger`](../str/CInteger.md) |  | [lib/language/c/integer.sml](../../../../../lib/language/c/integer.sml) |

Target integer types and the usual C arithmetic conversions.

## Interface

<pre>
signature C_INTEGER =
sig
  datatype <a href="#type-rank">rank</a> = <a href="#con-char">Char</a> | <a href="#con-short">Short</a> | <a href="#con-int">Int</a> | <a href="#con-long">Long</a> | <a href="#con-longlong">LongLong</a>
  type <a href="#type-integertype">integerType</a> = {<a href="#fld-integertype.rank">rank</a> : rank, <a href="#fld-integertype.width">width</a> : int, <a href="#fld-integertype.signed">signed</a> : bool}
  type <a href="#type-value">value</a> = {<a href="#fld-value.integer">integer</a> : IntInf.int, <a href="#fld-value.ty">ty</a> : integerType}
  type <a href="#type-target">target</a> = {<a href="#fld-target.char">char</a> : int, <a href="#fld-target.short">short</a> : int, <a href="#fld-target.int">int</a> : int, <a href="#fld-target.long">long</a> : int, <a href="#fld-target.longlong">longLong</a> : int}
  exception <a href="#exn-error">Error</a> of CLex.location * string
  val <a href="#val-integertype">integerType</a> : target -&gt; rank -&gt; bool -&gt; integerType
  val <a href="#val-limits">limits</a> : integerType -&gt; IntInf.int * IntInf.int
  val <a href="#val-literal">literal</a> : target -&gt; CLex.token -&gt; value
  val <a href="#val-convert">convert</a> : integerType -&gt; value -&gt; value
  val <a href="#val-promote">promote</a> : target -&gt; value -&gt; value
  val <a href="#val-common">common</a> : target -&gt; integerType * integerType -&gt; integerType
  val <a href="#val-unary">unary</a> : target -&gt; CLex.token -&gt; value -&gt; value
  val <a href="#val-binary">binary</a> : target -&gt; CLex.token -&gt; value * value -&gt; value
end
</pre>

### <a name="type-rank"></a>`rank`

```sml
datatype rank = Char | Short | Int | Long | LongLong
```

Integer rank, independent of the generator host's widths.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-char"></a>`Char` |  |  |
| <a name="con-short"></a>`Short` |  |  |
| <a name="con-int"></a>`Int` |  |  |
| <a name="con-long"></a>`Long` |  |  |
| <a name="con-longlong"></a>`LongLong` |  |  |

### <a name="type-integertype"></a>`integerType`

```sml
type integerType = {rank : rank, width : int, signed : bool}
```

One target C integer type.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-integertype.rank"></a>`rank` | `rank` |  |
| <a name="fld-integertype.width"></a>`width` | `int` |  |
| <a name="fld-integertype.signed"></a>`signed` | `bool` |  |

### <a name="type-value"></a>`value`

```sml
type value = {integer : IntInf.int, ty : integerType}
```

An integer constant and its C type.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-value.integer"></a>`integer` | `IntInf.int` |  |
| <a name="fld-value.ty"></a>`ty` | `integerType` |  |

### <a name="type-target"></a>`target`

```sml
type target = {char : int, short : int, int : int, long : int, longLong : int}
```

Standard target integer widths, in bits.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-target.char"></a>`char` | `int` |  |
| <a name="fld-target.short"></a>`short` | `int` |  |
| <a name="fld-target.int"></a>`int` | `int` |  |
| <a name="fld-target.long"></a>`long` | `int` |  |
| <a name="fld-target.longlong"></a>`longLong` | `int` |  |

### <a name="exn-error"></a>`Error`

```sml
exception Error of CLex.location * string
```

A source-located invalid conversion or undefined arithmetic result.

### <a name="val-integertype"></a>`integerType`

```sml
val integerType : target -> rank -> bool -> integerType
```

`integerType target rank signed` resolves an explicit target type.

### <a name="val-limits"></a>`limits`

```sml
val limits : integerType -> IntInf.int * IntInf.int
```

`limits ty` returns the inclusive range of a target integer type.

### <a name="val-literal"></a>`literal`

```sml
val literal : target -> CLex.token -> value
```

`literal target token` selects the C type from base, suffix and range.

**Raises** [`Error`](#exn-error) when no supported target integer type holds the value.

### <a name="val-convert"></a>`convert`

```sml
val convert : integerType -> value -> value
```

`convert ty value` applies the target's two's-complement conversion.

### <a name="val-promote"></a>`promote`

```sml
val promote : target -> value -> value
```

`promote target value` applies C integer promotion.

### <a name="val-common"></a>`common`

```sml
val common : target -> integerType * integerType -> integerType
```

`common target (left, right)` computes the usual arithmetic type.

### <a name="val-unary"></a>`unary`

```sml
val unary : target -> CLex.token -> value -> value
```

`unary target token value` applies a checked promoted unary operator.

**Raises** [`Error`](#exn-error) for signed negation overflow or an unknown operator.

### <a name="val-binary"></a>`binary`

```sml
val binary : target -> CLex.token -> value * value -> value
```

`binary target token (left, right)` evaluates a checked binary operator.

**Raises** [`Error`](#exn-error) for undefined shifts, division or signed overflow.

---

<sub>Generated by runedoc from lib/language/c/integer\_sig.sml; do not edit.</sub>

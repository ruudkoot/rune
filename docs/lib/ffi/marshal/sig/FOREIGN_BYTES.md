# signature FOREIGN_BYTES

[Foreign byte marshalling](../README.md) &rsaquo; Foreign interfaces &rsaquo; **FOREIGN_BYTES**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 7 of 7 entries documented |
| Tests | not listed |
| Source | [lib/ffi/marshal/bytes\_sig.sml](../../../../../lib/ffi/marshal/bytes_sig.sml) |

## Synopsis

```sml
signature FOREIGN_BYTES
structure ForeignBytes : FOREIGN_BYTES
```

| Implementation |  | Source |
| --- | --- | --- |
| [`ForeignBytes`](../str/ForeignBytes.md) |  | [lib/ffi/marshal/bytes.sml](../../../../../lib/ffi/marshal/bytes.sml) |

Target byte representations independent of the SML host's widths.

## Interface

<pre>
signature FOREIGN_BYTES =
sig
  exception <a href="#exn-error">Error</a> of string
  val <a href="#val-integer">integer</a> : {<a href="#fld-integer.width">width</a> : int, <a href="#fld-integer.signed">signed</a> : bool, <a href="#fld-integer.littleendian">littleEndian</a> : bool, <a href="#fld-integer.value">value</a> : IntInf.int} -&gt; string
  val <a href="#val-value">value</a> : {<a href="#fld-value.signed">signed</a> : bool, <a href="#fld-value.littleendian">littleEndian</a> : bool, <a href="#fld-value.bytes">bytes</a> : string} -&gt; IntInf.int
  val <a href="#val-real64">real64</a> : {<a href="#fld-real64.littleendian">littleEndian</a> : bool, <a href="#fld-real64.value">value</a> : real} -&gt; string
  val <a href="#val-real64value">real64Value</a> : {<a href="#fld-real64value.littleendian">littleEndian</a> : bool, <a href="#fld-real64value.bytes">bytes</a> : string} -&gt; real
  val <a href="#val-real32">real32</a> : {<a href="#fld-real32.littleendian">littleEndian</a> : bool, <a href="#fld-real32.value">value</a> : real} -&gt; string
  val <a href="#val-real32value">real32Value</a> : {<a href="#fld-real32value.littleendian">littleEndian</a> : bool, <a href="#fld-real32value.bytes">bytes</a> : string} -&gt; real
end
</pre>

### <a name="exn-error"></a>`Error`

```sml
exception Error of string
```

Invalid widths, malformed byte counts or out-of-range values.

### <a name="val-integer"></a>`integer`

```sml
val integer : {width : int, signed : bool, littleEndian : bool, value : IntInf.int} -> string
```

`integer {width, signed, littleEndian, value}` encodes one C integer.

Width is in bytes, from one through sixteen. Values are range checked;
negative signed values use two's complement.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-integer.width"></a>`width` | `int` |  |
| <a name="fld-integer.signed"></a>`signed` | `bool` |  |
| <a name="fld-integer.littleendian"></a>`littleEndian` | `bool` |  |
| <a name="fld-integer.value"></a>`value` | `IntInf.int` |  |

### <a name="val-value"></a>`value`

```sml
val value : {signed : bool, littleEndian : bool, bytes : string} -> IntInf.int
```

`value {signed, littleEndian, bytes}` decodes a bounded integer object.

**Raises** [`Error`](#exn-error) unless the string contains one through sixteen bytes.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-value.signed"></a>`signed` | `bool` |  |
| <a name="fld-value.littleendian"></a>`littleEndian` | `bool` |  |
| <a name="fld-value.bytes"></a>`bytes` | `string` |  |

### <a name="val-real64"></a>`real64`

```sml
val real64 : {littleEndian : bool, value : real} -> string
```

`real64 {littleEndian, value}` encodes an IEEE binary64 object.

**Raises** [`Error`](#exn-error) when the host's default SML real has another width.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-real64.littleendian"></a>`littleEndian` | `bool` |  |
| <a name="fld-real64.value"></a>`value` | `real` |  |

### <a name="val-real64value"></a>`real64Value`

```sml
val real64Value : {littleEndian : bool, bytes : string} -> real
```

`real64Value {littleEndian, bytes}` decodes exactly eight bytes.

**Raises** [`Error`](#exn-error) for another byte count.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-real64value.littleendian"></a>`littleEndian` | `bool` |  |
| <a name="fld-real64value.bytes"></a>`bytes` | `string` |  |

### <a name="val-real32"></a>`real32`

```sml
val real32 : {littleEndian : bool, value : real} -> string
```

`real32 {littleEndian, value}` rounds binary64 to IEEE binary32 bytes.

Rounding is to nearest, ties to even. Overflow produces signed infinity;
NaNs use a canonical quiet payload. This is independent of the C process
floating-point rounding mode.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-real32.littleendian"></a>`littleEndian` | `bool` |  |
| <a name="fld-real32.value"></a>`value` | `real` |  |

### <a name="val-real32value"></a>`real32Value`

```sml
val real32Value : {littleEndian : bool, bytes : string} -> real
```

`real32Value {littleEndian, bytes}` widens an IEEE binary32 object exactly.

**Raises** [`Error`](#exn-error) unless exactly four bytes are supplied.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-real32value.littleendian"></a>`littleEndian` | `bool` |  |
| <a name="fld-real32value.bytes"></a>`bytes` | `string` |  |

---

<sub>Generated by runedoc from lib/ffi/marshal/bytes\_sig.sml; do not edit.</sub>

# signature JSON

[JSON](../README.md) &rsaquo; Data formats &rsaquo; **JSON**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 9 of 9 entries documented |
| Tests | not listed |
| Source | [lib/json/json\_sig.sml](../../../../lib/json/json_sig.sml) |

## Synopsis

```sml
signature JSON
structure Json :> JSON
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Json`](../str/Json.md) |  | [lib/json/json.sml](../../../../lib/json/json.sml) |

JSON (RFC 8259): values read from text and written back.

Reading is strict: the grammar of RFC 8259 and nothing beside it -- no
comments, no trailing commas, no single quotes, no NaN -- in UTF-8, as the
RFC requires of text exchanged between systems; a string's escapes must
name scalar values, so a lone surrogate is an error. A number is kept as
the text it was written in, so that nothing is lost to a conversion that
the program did not ask for; [`int`](#val-int) and [`toInt`](#val-toint) convert. An object keeps
its members in the order they were written, a repeated name included.
Nesting deeper than [`maxDepth`](#val-maxdepth) is refused rather than followed.

## Interface

<pre>
signature JSON =
sig
  datatype <a href="#type-value">value</a> =
      <a href="#con-null">Null</a>
    | <a href="#con-bool">Bool</a> of bool
    | <a href="#con-number">Number</a> of string
    | <a href="#con-string">String</a> of string
    | <a href="#con-array">Array</a> of value list
    | <a href="#con-object">Object</a> of (string * value) list
  exception <a href="#exn-syntax">Syntax</a> of int * string
  val <a href="#val-maxdepth">maxDepth</a> : int
  val <a href="#val-decode">decode</a> : string -&gt; value
  val <a href="#val-encode">encode</a> : value -&gt; string
  val <a href="#val-encodeindented">encodeIndented</a> : int -&gt; value -&gt; string
  val <a href="#val-int">int</a> : int -&gt; value
  val <a href="#val-toint">toInt</a> : value -&gt; int option
  val <a href="#val-member">member</a> : string * value -&gt; value option
end
</pre>

### <a name="type-value"></a>`value`

```sml
datatype value =
    Null
  | Bool of bool
  | Number of string
  | String of string
  | Array of value list
  | Object of (string * value) list
```

A JSON value.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-null"></a>`Null` |  |  |
| <a name="con-bool"></a>`Bool` | `bool` |  |
| <a name="con-number"></a>`Number` | `string` | as written: `-? int frac? exp?` of the RFC's grammar |
| <a name="con-string"></a>`String` | `string` | UTF-8 |
| <a name="con-array"></a>`Array` | `value list` |  |
| <a name="con-object"></a>`Object` | `(string * value) list` |  |

### <a name="exn-syntax"></a>`Syntax`

```sml
exception Syntax of int * string
```

What [`decode`](#val-decode) raises: the byte offset where the text stops being JSON,
and what is wrong there.

### <a name="val-maxdepth"></a>`maxDepth`

```sml
val maxDepth : int
```

How deeply arrays and objects may nest in a text [`decode`](#val-decode) reads.

**Example** `maxDepth = 512`

### <a name="val-decode"></a>`decode`

```sml
val decode : string -> value
```

`decode s` is the value the JSON text `s` is.

**Raises** [`Syntax`](#exn-syntax) if `s` is not one JSON value with only blanks around
it, or nests deeper than [`maxDepth`](#val-maxdepth).

**Example** `decode " [1, \"two\", null] " = Array [Number "1", String "two", Null]`

### <a name="val-encode"></a>`encode`

```sml
val encode : value -> string
```

`encode v` is `v` written as compact JSON text: no blank between
tokens, `"`, `\` and the control characters escaped, the rest of the
UTF-8 of strings left as it is.

A byte of a string that is not part of its UTF-8 is written as the
character of the same number, `\u00XX`, as Latin-1 would read it: JSON
text holds characters, not bytes, and so a file name or a message in
another encoding can still be written.

**Raises** [`Domain`](../../basis/sig/GENERAL.md#exn-domain) if a [`Number`](#con-number) is not a number of the RFC's grammar.

Reading back what it writes gives `v` again where its strings are
UTF-8; tests/lib/json/roundtrip.sml checks that on random values.

**Example** `encode (Object [("a", Array [Bool true, String "\n"])]) = "{\"a\":[true,\"\\n\"]}"`

**Example** `encode (String "caf\233") = "\"caf\\u00E9\""`

### <a name="val-encodeindented"></a>`encodeIndented`

```sml
val encodeIndented : int -> value -> string
```

`encodeIndented n v` is `v` written as JSON text with each element and
member on a line of its own, indented by `n` blanks a level.

**Raises** [`Domain`](../../basis/sig/GENERAL.md#exn-domain) where [`encode`](#val-encode) would.

**Example** `encodeIndented 2 (Array [Null]) = "[\n  null\n]"`

### <a name="val-int"></a>`int`

```sml
val int : int -> value
```

`int i` is the number `i`.

**Example** `int ~3 = Number "-3"`

### <a name="val-toint"></a>`toInt`

```sml
val toInt : value -> int option
```

`toInt v` is the integer `v` is, when it is a [`Number`](#con-number) with no
fraction or exponent that fits an [`int`](#val-int); `NONE` otherwise.

**Example** `toInt (Number "-42") = SOME ~42 andalso toInt (Number "4.2") = NONE`

### <a name="val-member"></a>`member`

```sml
val member : string * value -> value option
```

`member (name, v)` is the value of the first member called `name` of
the object `v`, or `NONE` when `v` is not an object or has none.

**Example** `member ("b", Object [("a", Null), ("b", Bool false)]) = SOME (Bool false)`

---

<sub>Generated by runedoc from lib/json/json\_sig.sml; do not edit.</sub>

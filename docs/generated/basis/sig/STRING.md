# signature STRING

[The Standard ML Basis Library](../README.md) &rsaquo; **STRING**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 2 |
| Documentation | 0 of 31 entries documented |
| Source | [lib/basis/sig\_string.sml](../../../../lib/basis/sig_string.sml) |

## Synopsis

```sml
signature STRING
structure String : STRING where type string = string where type char = Char.char
structure WideString :> STRING where type string = WideCharVector.vector where type char = WideChar.char  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `String` | String: 8-bit byte strings. | [lib/basis/string.sml](../../../../lib/basis/string.sml) |
| `WideString` |  | [lib/basis/widestring.sml](../../../../lib/basis/widestring.sml) |

signature STRING, transcribed from <https://smlfamily.github.io/Basis/string.html>

The page writes the types of toString, scan, fromString, toCString and
fromCString with [`String.string`](#type-string), because the signature is also that of
WideString; they are kept as written. The constraints of `structure String :> STRING where type string = string where type string = CharVector.vector where type char = Char.char` are in tests/basis/string\_sig.sml.

## Interface

<pre>
signature STRING =
sig
  eqtype <a href="#type-string">string</a>
  eqtype <a href="#type-char">char</a>

  val <a href="#val-maxsize">maxSize</a> : int
  val <a href="#val-size">size</a> : string -&gt; int
  val <a href="#val-sub">sub</a> : string * int -&gt; char
  val <a href="#val-extract">extract</a> : string * int * int option -&gt; string
  val <a href="#val-substring">substring</a> : string * int * int -&gt; string
  val <a href="#val-op-caret">^</a> : string * string -&gt; string
  val <a href="#val-concat">concat</a> : string list -&gt; string
  val <a href="#val-concatwith">concatWith</a> : string -&gt; string list -&gt; string
  val <a href="#val-str">str</a> : char -&gt; string
  val <a href="#val-implode">implode</a> : char list -&gt; string
  val <a href="#val-explode">explode</a> : string -&gt; char list
  val <a href="#val-map">map</a> : (char -&gt; char) -&gt; string -&gt; string
  val <a href="#val-translate">translate</a> : (char -&gt; string) -&gt; string -&gt; string
  val <a href="#val-tokens">tokens</a> : (char -&gt; bool) -&gt; string -&gt; string list
  val <a href="#val-fields">fields</a> : (char -&gt; bool) -&gt; string -&gt; string list
  val <a href="#val-isprefix">isPrefix</a> : string -&gt; string -&gt; bool
  val <a href="#val-issubstring">isSubstring</a> : string -&gt; string -&gt; bool
  val <a href="#val-issuffix">isSuffix</a> : string -&gt; string -&gt; bool

  val <a href="#val-compare">compare</a> : string * string -&gt; order
  val <a href="#val-collate">collate</a> : (char * char -&gt; order) -&gt; string * string -&gt; order
  val <a href="#val-op-lt">&lt;</a> : string * string -&gt; bool
  val <a href="#val-op-lt-eq">&lt;=</a> : string * string -&gt; bool
  val <a href="#val-op-gt">&gt;</a> : string * string -&gt; bool
  val <a href="#val-op-gt-eq">&gt;=</a> : string * string -&gt; bool

  val <a href="#val-tostring">toString</a> : string -&gt; String.string
  val <a href="#val-scan">scan</a> : (char, 'a) StringCvt.reader -&gt; (string, 'a) StringCvt.reader
  val <a href="#val-fromstring">fromString</a> : String.string -&gt; string option
  val <a href="#val-tocstring">toCString</a> : string -&gt; String.string
  val <a href="#val-fromcstring">fromCString</a> : String.string -&gt; string option
end
</pre>

### <a name="type-string"></a>`string`

```sml
eqtype string
```

### <a name="type-char"></a>`char`

```sml
eqtype char
```

### <a name="val-maxsize"></a>`maxSize`

```sml
val maxSize : int
```

### <a name="val-size"></a>`size`

```sml
val size : string -> int
```

### <a name="val-sub"></a>`sub`

```sml
val sub : string * int -> char
```

### <a name="val-extract"></a>`extract`

```sml
val extract : string * int * int option -> string
```

### <a name="val-substring"></a>`substring`

```sml
val substring : string * int * int -> string
```

### <a name="val-op-caret"></a>`^`

```sml
val ^ : string * string -> string
```

### <a name="val-concat"></a>`concat`

```sml
val concat : string list -> string
```

### <a name="val-concatwith"></a>`concatWith`

```sml
val concatWith : string -> string list -> string
```

### <a name="val-str"></a>`str`

```sml
val str : char -> string
```

### <a name="val-implode"></a>`implode`

```sml
val implode : char list -> string
```

### <a name="val-explode"></a>`explode`

```sml
val explode : string -> char list
```

### <a name="val-map"></a>`map`

```sml
val map : (char -> char) -> string -> string
```

### <a name="val-translate"></a>`translate`

```sml
val translate : (char -> string) -> string -> string
```

### <a name="val-tokens"></a>`tokens`

```sml
val tokens : (char -> bool) -> string -> string list
```

### <a name="val-fields"></a>`fields`

```sml
val fields : (char -> bool) -> string -> string list
```

### <a name="val-isprefix"></a>`isPrefix`

```sml
val isPrefix : string -> string -> bool
```

### <a name="val-issubstring"></a>`isSubstring`

```sml
val isSubstring : string -> string -> bool
```

### <a name="val-issuffix"></a>`isSuffix`

```sml
val isSuffix : string -> string -> bool
```

### <a name="val-compare"></a>`compare`

```sml
val compare : string * string -> order
```

### <a name="val-collate"></a>`collate`

```sml
val collate : (char * char -> order) -> string * string -> order
```

### <a name="val-op-lt"></a>`<`

```sml
val < : string * string -> bool
```

### <a name="val-op-lt-eq"></a>`<=`

```sml
val <= : string * string -> bool
```

### <a name="val-op-gt"></a>`>`

```sml
val > : string * string -> bool
```

### <a name="val-op-gt-eq"></a>`>=`

```sml
val >= : string * string -> bool
```

### <a name="val-tostring"></a>`toString`

```sml
val toString : string -> String.string
```

### <a name="val-scan"></a>`scan`

```sml
val scan : (char, 'a) StringCvt.reader -> (string, 'a) StringCvt.reader
```

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : String.string -> string option
```

### <a name="val-tocstring"></a>`toCString`

```sml
val toCString : string -> String.string
```

### <a name="val-fromcstring"></a>`fromCString`

```sml
val fromCString : String.string -> string option
```

---

<sub>Generated by runedoc from lib/basis/sig\_string.sml; do not edit.</sub>

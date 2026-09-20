# signature CHAR

[The Standard ML Basis Library](../README.md) &rsaquo; **CHAR**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 2 |
| Documentation | 0 of 35 entries documented |
| Source | [lib/basis/sig\_char.sml](../../../../lib/basis/sig_char.sml) |

## Synopsis

```sml
signature CHAR
structure Char : CHAR where type char = char where type string = String.string
structure WideChar :> CHAR where type char = WideChar.char where type string = WideString.string  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Char` | Char: 8-bit characters. | [lib/basis/char.sml](../../../../lib/basis/char.sml) |
| `WideChar` |  | [lib/basis/widechar.sml](../../../../lib/basis/widechar.sml) |

signature CHAR, transcribed from <https://smlfamily.github.io/Basis/char.html>

The page writes the types of toString, scan, fromString, toCString and
fromCString with [`String.string`](../sig/STRING.md#type-string) and [`Char.char`](#type-char), because the signature
is also that of WideChar; they are kept as written. The constraints of
`structure Char :> CHAR where type char = char where type string = String.string` are in tests/basis/char\_sig.sml.

## Interface

<pre>
signature CHAR =
sig
  eqtype <a href="#type-char">char</a>
  eqtype <a href="#type-string">string</a>

  val <a href="#val-minchar">minChar</a> : char
  val <a href="#val-maxchar">maxChar</a> : char
  val <a href="#val-maxord">maxOrd</a> : int

  val <a href="#val-ord">ord</a> : char -&gt; int
  val <a href="#val-chr">chr</a> : int -&gt; char
  val <a href="#val-succ">succ</a> : char -&gt; char
  val <a href="#val-pred">pred</a> : char -&gt; char

  val <a href="#val-compare">compare</a> : char * char -&gt; order
  val <a href="#val-op-lt">&lt;</a> : char * char -&gt; bool
  val <a href="#val-op-lt-eq">&lt;=</a> : char * char -&gt; bool
  val <a href="#val-op-gt">&gt;</a> : char * char -&gt; bool
  val <a href="#val-op-gt-eq">&gt;=</a> : char * char -&gt; bool

  val <a href="#val-contains">contains</a> : string -&gt; char -&gt; bool
  val <a href="#val-notcontains">notContains</a> : string -&gt; char -&gt; bool

  val <a href="#val-isascii">isAscii</a> : char -&gt; bool
  val <a href="#val-tolower">toLower</a> : char -&gt; char
  val <a href="#val-toupper">toUpper</a> : char -&gt; char
  val <a href="#val-isalpha">isAlpha</a> : char -&gt; bool
  val <a href="#val-isalphanum">isAlphaNum</a> : char -&gt; bool
  val <a href="#val-iscntrl">isCntrl</a> : char -&gt; bool
  val <a href="#val-isdigit">isDigit</a> : char -&gt; bool
  val <a href="#val-isgraph">isGraph</a> : char -&gt; bool
  val <a href="#val-ishexdigit">isHexDigit</a> : char -&gt; bool
  val <a href="#val-islower">isLower</a> : char -&gt; bool
  val <a href="#val-isprint">isPrint</a> : char -&gt; bool
  val <a href="#val-isspace">isSpace</a> : char -&gt; bool
  val <a href="#val-ispunct">isPunct</a> : char -&gt; bool
  val <a href="#val-isupper">isUpper</a> : char -&gt; bool

  val <a href="#val-tostring">toString</a> : char -&gt; String.string
  val <a href="#val-scan">scan</a> : (Char.char, 'a) StringCvt.reader -&gt; (char, 'a) StringCvt.reader
  val <a href="#val-fromstring">fromString</a> : String.string -&gt; char option
  val <a href="#val-tocstring">toCString</a> : char -&gt; String.string
  val <a href="#val-fromcstring">fromCString</a> : String.string -&gt; char option
end
</pre>

### <a name="type-char"></a>`char`

```sml
eqtype char
```

### <a name="type-string"></a>`string`

```sml
eqtype string
```

### <a name="val-minchar"></a>`minChar`

```sml
val minChar : char
```

### <a name="val-maxchar"></a>`maxChar`

```sml
val maxChar : char
```

### <a name="val-maxord"></a>`maxOrd`

```sml
val maxOrd : int
```

### <a name="val-ord"></a>`ord`

```sml
val ord : char -> int
```

### <a name="val-chr"></a>`chr`

```sml
val chr : int -> char
```

### <a name="val-succ"></a>`succ`

```sml
val succ : char -> char
```

### <a name="val-pred"></a>`pred`

```sml
val pred : char -> char
```

### <a name="val-compare"></a>`compare`

```sml
val compare : char * char -> order
```

### <a name="val-op-lt"></a>`<`

```sml
val < : char * char -> bool
```

### <a name="val-op-lt-eq"></a>`<=`

```sml
val <= : char * char -> bool
```

### <a name="val-op-gt"></a>`>`

```sml
val > : char * char -> bool
```

### <a name="val-op-gt-eq"></a>`>=`

```sml
val >= : char * char -> bool
```

### <a name="val-contains"></a>`contains`

```sml
val contains : string -> char -> bool
```

### <a name="val-notcontains"></a>`notContains`

```sml
val notContains : string -> char -> bool
```

### <a name="val-isascii"></a>`isAscii`

```sml
val isAscii : char -> bool
```

### <a name="val-tolower"></a>`toLower`

```sml
val toLower : char -> char
```

### <a name="val-toupper"></a>`toUpper`

```sml
val toUpper : char -> char
```

### <a name="val-isalpha"></a>`isAlpha`

```sml
val isAlpha : char -> bool
```

### <a name="val-isalphanum"></a>`isAlphaNum`

```sml
val isAlphaNum : char -> bool
```

### <a name="val-iscntrl"></a>`isCntrl`

```sml
val isCntrl : char -> bool
```

### <a name="val-isdigit"></a>`isDigit`

```sml
val isDigit : char -> bool
```

### <a name="val-isgraph"></a>`isGraph`

```sml
val isGraph : char -> bool
```

### <a name="val-ishexdigit"></a>`isHexDigit`

```sml
val isHexDigit : char -> bool
```

### <a name="val-islower"></a>`isLower`

```sml
val isLower : char -> bool
```

### <a name="val-isprint"></a>`isPrint`

```sml
val isPrint : char -> bool
```

### <a name="val-isspace"></a>`isSpace`

```sml
val isSpace : char -> bool
```

### <a name="val-ispunct"></a>`isPunct`

```sml
val isPunct : char -> bool
```

### <a name="val-isupper"></a>`isUpper`

```sml
val isUpper : char -> bool
```

### <a name="val-tostring"></a>`toString`

```sml
val toString : char -> String.string
```

### <a name="val-scan"></a>`scan`

```sml
val scan : (Char.char, 'a) StringCvt.reader -> (char, 'a) StringCvt.reader
```

### <a name="val-fromstring"></a>`fromString`

```sml
val fromString : String.string -> char option
```

### <a name="val-tocstring"></a>`toCString`

```sml
val toCString : char -> String.string
```

### <a name="val-fromcstring"></a>`fromCString`

```sml
val fromCString : String.string -> char option
```

---

<sub>Generated by runedoc from lib/basis/sig\_char.sml; do not edit.</sub>

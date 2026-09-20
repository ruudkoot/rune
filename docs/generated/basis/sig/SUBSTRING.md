# signature SUBSTRING

[The Standard ML Basis Library](../README.md) &rsaquo; **SUBSTRING**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 2 |
| Documentation | 0 of 39 entries documented |
| Source | [lib/basis/sig\_substring.sml](../../../../lib/basis/sig_substring.sml) |

## Synopsis

```sml
signature SUBSTRING
structure Substring : SUBSTRING where type string = string where type char = Char.char
structure WideSubstring :> SUBSTRING where type substring = WideCharVectorSlice.slice where type string = WideCharVector.vector where type char = WideChar.char
```

| Implementation |  | Source |
| --- | --- | --- |
| `Substring` | Substring: a string, a start index and a length. | [lib/basis/substring.sml](../../../../lib/basis/substring.sml) |
| `WideSubstring` |  | [lib/basis/widestring.sml](../../../../lib/basis/widestring.sml) |

signature SUBSTRING, transcribed from <https://smlfamily.github.io/Basis/substring.html>

The constraints of `structure Substring :> SUBSTRING where type substring = CharVectorSlice.slice where type string = String.string where type char = Char.char` are in tests/basis/substring\_sig.sml. The exception Span that
span raises is that of General; the signature does not specify it.

## Interface

<pre>
signature SUBSTRING =
sig
  type <a href="#type-substring">substring</a>
  eqtype <a href="#type-char">char</a>
  eqtype <a href="#type-string">string</a>

  val <a href="#val-sub">sub</a> : substring * int -&gt; char
  val <a href="#val-size">size</a> : substring -&gt; int
  val <a href="#val-base">base</a> : substring -&gt; string * int * int
  val <a href="#val-extract">extract</a> : string * int * int option -&gt; substring
  val <a href="#val-substring">substring</a> : string * int * int -&gt; substring
  val <a href="#val-full">full</a> : string -&gt; substring
  val <a href="#val-string">string</a> : substring -&gt; string
  val <a href="#val-isempty">isEmpty</a> : substring -&gt; bool
  val <a href="#val-getc">getc</a> : substring -&gt; (char * substring) option
  val <a href="#val-first">first</a> : substring -&gt; char option
  val <a href="#val-triml">triml</a> : int -&gt; substring -&gt; substring
  val <a href="#val-trimr">trimr</a> : int -&gt; substring -&gt; substring
  val <a href="#val-slice">slice</a> : substring * int * int option -&gt; substring
  val <a href="#val-concat">concat</a> : substring list -&gt; string
  val <a href="#val-concatwith">concatWith</a> : string -&gt; substring list -&gt; string
  val <a href="#val-explode">explode</a> : substring -&gt; char list
  val <a href="#val-isprefix">isPrefix</a> : string -&gt; substring -&gt; bool
  val <a href="#val-issubstring">isSubstring</a> : string -&gt; substring -&gt; bool
  val <a href="#val-issuffix">isSuffix</a> : string -&gt; substring -&gt; bool
  val <a href="#val-compare">compare</a> : substring * substring -&gt; order
  val <a href="#val-collate">collate</a> : (char * char -&gt; order) -&gt; substring * substring -&gt; order
  val <a href="#val-splitl">splitl</a> : (char -&gt; bool) -&gt; substring -&gt; substring * substring
  val <a href="#val-splitr">splitr</a> : (char -&gt; bool) -&gt; substring -&gt; substring * substring
  val <a href="#val-splitat">splitAt</a> : substring * int -&gt; substring * substring
  val <a href="#val-dropl">dropl</a> : (char -&gt; bool) -&gt; substring -&gt; substring
  val <a href="#val-dropr">dropr</a> : (char -&gt; bool) -&gt; substring -&gt; substring
  val <a href="#val-takel">takel</a> : (char -&gt; bool) -&gt; substring -&gt; substring
  val <a href="#val-taker">taker</a> : (char -&gt; bool) -&gt; substring -&gt; substring
  val <a href="#val-position">position</a> : string -&gt; substring -&gt; substring * substring
  val <a href="#val-span">span</a> : substring * substring -&gt; substring
  val <a href="#val-translate">translate</a> : (char -&gt; string) -&gt; substring -&gt; string
  val <a href="#val-tokens">tokens</a> : (char -&gt; bool) -&gt; substring -&gt; substring list
  val <a href="#val-fields">fields</a> : (char -&gt; bool) -&gt; substring -&gt; substring list
  val <a href="#val-app">app</a> : (char -&gt; unit) -&gt; substring -&gt; unit
  val <a href="#val-foldl">foldl</a> : (char * 'a -&gt; 'a) -&gt; 'a -&gt; substring -&gt; 'a
  val <a href="#val-foldr">foldr</a> : (char * 'a -&gt; 'a) -&gt; 'a -&gt; substring -&gt; 'a
end
</pre>

### <a name="type-substring"></a>`substring`

```sml
type substring
```

### <a name="type-char"></a>`char`

```sml
eqtype char
```

### <a name="type-string"></a>`string`

```sml
eqtype string
```

### <a name="val-sub"></a>`sub`

```sml
val sub : substring * int -> char
```

### <a name="val-size"></a>`size`

```sml
val size : substring -> int
```

### <a name="val-base"></a>`base`

```sml
val base : substring -> string * int * int
```

### <a name="val-extract"></a>`extract`

```sml
val extract : string * int * int option -> substring
```

### <a name="val-substring"></a>`substring`

```sml
val substring : string * int * int -> substring
```

### <a name="val-full"></a>`full`

```sml
val full : string -> substring
```

### <a name="val-string"></a>`string`

```sml
val string : substring -> string
```

### <a name="val-isempty"></a>`isEmpty`

```sml
val isEmpty : substring -> bool
```

### <a name="val-getc"></a>`getc`

```sml
val getc : substring -> (char * substring) option
```

### <a name="val-first"></a>`first`

```sml
val first : substring -> char option
```

### <a name="val-triml"></a>`triml`

```sml
val triml : int -> substring -> substring
```

### <a name="val-trimr"></a>`trimr`

```sml
val trimr : int -> substring -> substring
```

### <a name="val-slice"></a>`slice`

```sml
val slice : substring * int * int option -> substring
```

### <a name="val-concat"></a>`concat`

```sml
val concat : substring list -> string
```

### <a name="val-concatwith"></a>`concatWith`

```sml
val concatWith : string -> substring list -> string
```

### <a name="val-explode"></a>`explode`

```sml
val explode : substring -> char list
```

### <a name="val-isprefix"></a>`isPrefix`

```sml
val isPrefix : string -> substring -> bool
```

### <a name="val-issubstring"></a>`isSubstring`

```sml
val isSubstring : string -> substring -> bool
```

### <a name="val-issuffix"></a>`isSuffix`

```sml
val isSuffix : string -> substring -> bool
```

### <a name="val-compare"></a>`compare`

```sml
val compare : substring * substring -> order
```

### <a name="val-collate"></a>`collate`

```sml
val collate : (char * char -> order) -> substring * substring -> order
```

### <a name="val-splitl"></a>`splitl`

```sml
val splitl : (char -> bool) -> substring -> substring * substring
```

### <a name="val-splitr"></a>`splitr`

```sml
val splitr : (char -> bool) -> substring -> substring * substring
```

### <a name="val-splitat"></a>`splitAt`

```sml
val splitAt : substring * int -> substring * substring
```

### <a name="val-dropl"></a>`dropl`

```sml
val dropl : (char -> bool) -> substring -> substring
```

### <a name="val-dropr"></a>`dropr`

```sml
val dropr : (char -> bool) -> substring -> substring
```

### <a name="val-takel"></a>`takel`

```sml
val takel : (char -> bool) -> substring -> substring
```

### <a name="val-taker"></a>`taker`

```sml
val taker : (char -> bool) -> substring -> substring
```

### <a name="val-position"></a>`position`

```sml
val position : string -> substring -> substring * substring
```

### <a name="val-span"></a>`span`

```sml
val span : substring * substring -> substring
```

### <a name="val-translate"></a>`translate`

```sml
val translate : (char -> string) -> substring -> string
```

### <a name="val-tokens"></a>`tokens`

```sml
val tokens : (char -> bool) -> substring -> substring list
```

### <a name="val-fields"></a>`fields`

```sml
val fields : (char -> bool) -> substring -> substring list
```

### <a name="val-app"></a>`app`

```sml
val app : (char -> unit) -> substring -> unit
```

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (char * 'a -> 'a) -> 'a -> substring -> 'a
```

### <a name="val-foldr"></a>`foldr`

```sml
val foldr : (char * 'a -> 'a) -> 'a -> substring -> 'a
```

---

<sub>Generated by runedoc from lib/basis/sig\_substring.sml; do not edit.</sub>

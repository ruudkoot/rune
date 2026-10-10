# signature UTF8

[Unicode](../README.md) &rsaquo; Unicode &rsaquo; **UTF8**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 10 of 10 entries documented |
| Tests | not listed |
| Source | [lib/unicode/utf8\_sig.sml](../../../../lib/unicode/utf8_sig.sml) |

## Synopsis

```sml
signature UTF8
structure Utf8 :> UTF8
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Utf8`](../str/Utf8.md) |  | [lib/unicode/utf8.sml](../../../../lib/unicode/utf8.sml) |

UTF-8: code points written as bytes and read back, strictly.

A string holds bytes, and text in it is UTF-8 by convention. Reading is
strict in the sense of the Unicode Standard (its section 3.9): an
overlong form, a surrogate, a code point past 0x10FFFF, a sequence cut
short and a continuation byte with no lead are ill-formed, and [`decode`](#val-decode)
gives `NONE` for them. Where a program must read whatever bytes it gets
\-- what a terminal sends, a file of unknown origin -- [`next`](#val-next) and the
functions over whole strings never fail: they read each ill-formed part
as one replacement character, U+FFFD, as long as the maximal subpart the
standard recommends, so that the same bytes give the same characters in
every program that follows it.

## Interface

<pre>
signature UTF8 =
sig
  val <a href="#val-replacement">replacement</a> : int
  val <a href="#val-isscalar">isScalar</a> : int -&gt; bool
  val <a href="#val-encode">encode</a> : int -&gt; string
  val <a href="#val-decode">decode</a> : string * int -&gt; (int * int) option
  val <a href="#val-next">next</a> : string * int -&gt; int * int
  val <a href="#val-isvalid">isValid</a> : string -&gt; bool
  val <a href="#val-explode">explode</a> : string -&gt; int list
  val <a href="#val-implode">implode</a> : int list -&gt; string
  val <a href="#val-foldl">foldl</a> : (int * 'a -&gt; 'a) -&gt; 'a -&gt; string -&gt; 'a
  val <a href="#val-size">size</a> : string -&gt; int
end
</pre>

### <a name="val-replacement"></a>`replacement`

```sml
val replacement : int
```

The replacement character, U+FFFD, which the readers that never fail
give for each ill-formed part.

**Example** `replacement = 0xFFFD`

### <a name="val-isscalar"></a>`isScalar`

```sml
val isScalar : int -> bool
```

`isScalar c` is whether `c` is a Unicode scalar value, a code point
that UTF-8 can write: from 0 to 0x10FFFF, and not a surrogate (0xD800
to 0xDFFF).

**Example** `isScalar 0x10FFFF andalso not (isScalar 0xD800)`

### <a name="val-encode"></a>`encode`

```sml
val encode : int -> string
```

`encode c` is the bytes of the code point `c`: one for ASCII, up to
four.

**Raises** [`Chr`](../../basis/sig/GENERAL.md#exn-chr) if `c` is not a scalar value.

**Example** `encode 0x20AC = "\226\130\172"`

### <a name="val-decode"></a>`decode`

```sml
val decode : string * int -> (int * int) option
```

`decode (s, i)` is the code point whose bytes begin at byte `i` of
`s`, and how many bytes it has; `NONE` when the bytes there are
ill-formed, or `i` is the end of `s`.

**Raises** [`Subscript`](../../basis/sig/GENERAL.md#exn-subscript) if `i < 0` or `i > size s`.

**Example** `decode ("\226\130\172", 0) = SOME (0x20AC, 3)`

**Example** `decode ("\192\128", 0) = NONE`, an overlong form of 0

### <a name="val-next"></a>`next`

```sml
val next : string * int -> int * int
```

`next (s, i)` is the code point at byte `i` of `s` and its length, or
[`replacement`](#val-replacement) where the bytes there are ill-formed.

A well-formed code point is what [`decode`](#val-decode) gives; an ill-formed part is
as long as its maximal subpart.

**Raises** [`Subscript`](../../basis/sig/GENERAL.md#exn-subscript) unless `0 <= i` and `i < size s`.

**Example** `next ("\240\128\128", 0) = (0xFFFD, 1)`

### <a name="val-isvalid"></a>`isValid`

```sml
val isValid : string -> bool
```

`isValid s` is whether all of `s` is well-formed UTF-8.

**Example** `isValid "caf\195\169" andalso not (isValid "\237\160\128")`

### <a name="val-explode"></a>`explode`

```sml
val explode : string -> int list
```

`explode s` is the code points of `s`, read by [`next`](#val-next).

**Law** `implode (explode s) = s` when `isValid s` (for every `s : string`)

**Example** `explode "a\195\169\255" = [0x61, 0xE9, 0xFFFD]`

### <a name="val-implode"></a>`implode`

```sml
val implode : int list -> string
```

`implode cs` is the bytes of the code points `cs`, one after another.

**Raises** [`Chr`](../../basis/sig/GENERAL.md#exn-chr) if one of `cs` is not a scalar value.

**Law** `explode (implode cs) = cs` when `List.all isScalar cs` (for every `cs : int list`)

### <a name="val-foldl"></a>`foldl`

```sml
val foldl : (int * 'a -> 'a) -> 'a -> string -> 'a
```

`foldl f init s` is `f` applied to the code points of `s` from the
left, read by [`next`](#val-next), starting from `init`.

**Example** `foldl (fn (c, n) => c + n) 0 "\195\169" = 0xE9`

### <a name="val-size"></a>`size`

```sml
val size : string -> int
```

`size s` is the number of code points of `s`, read by [`next`](#val-next).

**Example** `size "caf\195\169" = 4`

---

<sub>Generated by runedoc from lib/unicode/utf8\_sig.sml; do not edit.</sub>

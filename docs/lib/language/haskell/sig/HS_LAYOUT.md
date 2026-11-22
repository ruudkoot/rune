# signature HS_LAYOUT

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_LAYOUT**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 13 of 13 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/layout\_sig.sml](../../../../../lib/language/haskell/layout_sig.sml) |

## Synopsis

```sml
signature HS_LAYOUT
structure HsLayout :> HS_LAYOUT
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsLayout`](../str/HsLayout.md) |  | [lib/language/haskell/layout.sml](../../../../../lib/language/haskell/layout.sml) |

The layout algorithm of Haskell 98, the function `L` of the Report's
section 9.3, run on demand: the parser pulls one token at a time, so
that when it takes an implicit close, the side condition
`parse-error(t)` of the equation for `t`, the stack of layout contexts
is that of the point it has reached and nothing past that token has
been laid out (the haskell98 roadmap's D27).

The equations and where they are kept:

- `<n>` with `m = n`, `n < m`, and otherwise: a token first on its line;
- `{n}` with `n > m`, `n > 0`, and otherwise: a token after `let`,
  `where`, `do` or `of` that is not `{`, and the first of a module that
  is neither `{` nor `module`; an empty block makes the next token's
  `{n}` an `<n>`;
- `}` with an explicit context on top, `{`, and the end of the input:
  [`advance`](#val-advance);
- `t` with an implicit context on top and `parse-error(t)`:
  [`closeImplicit`](#val-closeimplicit), which the parser calls.

It makes two readings of the roadmap's evidence (`results/E9/readings.md`):
R2, an explicit `}` may close an implicit block, as section 2.7 reads,
where 9.3's Note 3 alone would refuse it; and R3, a block opens only
at a column strictly greater than the enclosing one, so that a `do`
at the column of its context is empty.

There is one stream at a time: [`start`](#val-start) begins it, and the parser reads
and moves it.

## Interface

<pre>
signature HS_LAYOUT =
sig
  val <a href="#val-start">start</a> : string * HsToken.item vector -&gt; unit
  val <a href="#val-current">current</a> : HsToken.token ref
  val <a href="#val-here">here</a> : unit -&gt; HsSource.span
  val <a href="#val-currentstart">currentStart</a> : unit -&gt; int
  val <a href="#val-trivia">trivia</a> : unit -&gt; HsToken.trivium list
  val <a href="#val-laststop">lastStop</a> : unit -&gt; int
  val <a href="#val-advance">advance</a> : unit -&gt; unit
  val <a href="#val-closeimplicit">closeImplicit</a> : unit -&gt; bool
  val <a href="#val-peek">peek</a> : int -&gt; HsToken.token
  type <a href="#type-mark">mark</a>
  val <a href="#val-save">save</a> : unit -&gt; mark
  val <a href="#val-restore">restore</a> : mark -&gt; unit
  val <a href="#val-fail">fail</a> : string -&gt; 'a
end
</pre>

### <a name="val-start"></a>`start`

```sml
val start : string * HsToken.item vector -> unit
```

`start (file, tokens)` begins the stream of the tokens of the file
`file`, laid out, and reads its first token.

### <a name="val-current"></a>`current`

```sml
val current : HsToken.token ref
```

The token the stream is at, written or layout's.

### <a name="val-here"></a>`here`

```sml
val here : unit -> HsSource.span
```

`here ()` is the span of the current token; a token of layout's
covers no byte, and stands where the next written token begins.

### <a name="val-currentstart"></a>`currentStart`

```sml
val currentStart : unit -> int
```

`currentStart ()` is where the current token begins: `#start (here ())`.

### <a name="val-trivia"></a>`trivia`

```sml
val trivia : unit -> HsToken.trivium list
```

`trivia ()` is the trivia before the current token; none for
layout's.

### <a name="val-laststop"></a>`lastStop`

```sml
val lastStop : unit -> int
```

`lastStop ()` is where the last written token that [`advance`](#val-advance) passed
ends: 0 before the first.

### <a name="val-advance"></a>`advance`

```sml
val advance : unit -> unit
```

`advance ()` passes the current token and reads the next.

**Raises** [`HsSource.Error`](../sig/HS_SOURCE.md#exn-error) for a `}` that no `{` opened, and for the
end of the input inside braces.

### <a name="val-closeimplicit"></a>`closeImplicit`

```sml
val closeImplicit : unit -> bool
```

`closeImplicit ()` is the equation of `t` with `parse-error(t)`: the
parser can go no further with the current token in its block.

Where that block is implicit it is closed and the result is `true`;
where it is explicit, or there is none, nothing changes and the
result is `false`.

### <a name="val-peek"></a>`peek`

```sml
val peek : int -> HsToken.token
```

`peek k` is the `k`th written token after the current one, from 0,
as the lexer read it: layout does not see that far.

### <a name="type-mark"></a>`mark`

```sml
type mark
```

Where the stream is, to go back to.

### <a name="val-save"></a>`save`

```sml
val save : unit -> mark
```

`save ()` is where the stream is now.

### <a name="val-restore"></a>`restore`

```sml
val restore : mark -> unit
```

`restore m` puts the stream back where it was at `m`.

### <a name="val-fail"></a>`fail`

```sml
val fail : string -> 'a
```

`fail msg` raises an error at the current token.

**Raises** [`HsSource.Error`](../sig/HS_SOURCE.md#exn-error) always.

---

<sub>Generated by runedoc from lib/language/haskell/layout\_sig.sml; do not edit.</sub>

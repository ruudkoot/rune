# signature HS_MATCH

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_MATCH**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 12 of 12 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/match\_sig.sml](../../../../../lib/language/haskell/match_sig.sml) |

## Synopsis

```sml
signature HS_MATCH
structure HsMatch :> HS_MATCH
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsMatch`](../str/HsMatch.md) |  | [lib/language/haskell/match.sml](../../../../../lib/language/haskell/match.sml) |

Pattern matching in the Report's order (the haskell98 roadmap's M15,
D34), and decision trees in Sestoft's order.

The rules of 3.17.3 are taken literally at `-O0` and `-O1`; the trees
are rhc's at `-O2` and above (D34, the owner's decision of 2026-11-15).

The Report's order: the clauses one after another, and in each the
patterns from left to right, each from the outside in (3.17.2). A
clause that fails goes to the next, which a lazy `let` of the rest of
the match holds (rule (c)'s `y`), so no clause is copied (defect 14).
A constructor's pattern forces its value and matches its fields left
to right (rule (g)); a newtype's casts and forces nothing (rules (k),
(l)); a numeric literal compares by `==` at its type with the
dictionaries the checker chose (rule (h)), a character literal by a
case on its code point, a string literal as the list of its characters
(defect 7); `~p` binds each variable of `p` to a match of its own that
is made only when the variable is forced (rule (d)); `x@p` binds `x`
to the value (rule (e)); `n+k` compares by `>=` and binds `n` to the
value less `k` (rule (s)); a record pattern tests its constructor and
matches its fields in the pattern's order (rules (m) to (o)).

Sestoft's order (Sestoft 1996) matches the same patterns in the same
order, but makes no test whose outcome the tests made already decide:
a decision tree whose right-hand sides are functions of their
variables, so that none is copied. Its only freedom is in tests on
values already forced (D34). A clause with a pattern it does not take
apart (a literal, `~p`, `n+k`, a newtype's or a record's) is matched
from there on in the Report's way.

## Interface

<pre>
signature HS_MATCH =
sig
  datatype <a href="#type-order">order</a> = <a href="#con-report">Report</a> | <a href="#con-sestoft">Sestoft</a>
  val <a href="#val-order">order</a> : order ref
  type <a href="#type-occurrence">occurrence</a> = Core.atom * Core.ty
  val <a href="#val-tupleform">tupleForm</a> : int -&gt; bool
  val <a href="#val-plaintuple">plainTuple</a> : HsAst.pat -&gt; bool
  val <a href="#val-selector">selector</a> : string * Core.ty * (string * Core.ty) list * int -&gt; HsDsCore.texp
  val <a href="#val-marks">marks</a> : string * Core.ty * (string * Core.ty) list * HsDsCore.texp -&gt; HsDsCore.texp
  type <a href="#type-clause">clause</a> = HsAst.pat list * (HsDsEnv.env * HsDsCore.texp -&gt; HsDsCore.texp)
  val <a href="#val-clauses">clauses</a> : HsDsEnv.env * occurrence list * clause list * (Core.ty -&gt; HsDsCore.texp) -&gt; HsDsCore.texp
  val <a href="#val-pattern">pattern</a> : HsDsEnv.env * occurrence * HsAst.pat * (HsDsEnv.env -&gt; HsDsCore.texp) * HsDsCore.texp
                -&gt; HsDsCore.texp
  val <a href="#val-variables">variables</a> : HsAst.pat -&gt; HsAst.name list
  val <a href="#val-lazy">lazy</a> : HsAst.pat -&gt; bool
end
</pre>

### <a name="type-order"></a>`order`

```sml
datatype order = Report | Sestoft
```

How clauses are matched.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-report"></a>`Report` |  |  |
| <a name="con-sestoft"></a>`Sestoft` |  |  |

### <a name="val-order"></a>`order`

```sml
val order : order ref
```

[`order`](#val-order) is the order of every match: [`Report`](#con-report) unless set; rhc sets it
by `--match`, or by the level, [`Sestoft`](#con-sestoft) at `-O2` and above.

### <a name="type-occurrence"></a>`occurrence`

```sml
type occurrence = Core.atom * Core.ty
```

What is matched: an atom of Core and its type.

### <a name="val-tupleform"></a>`tupleForm`

```sml
val tupleForm : int -> bool
```

`tupleForm n` is whether a pattern binding or a lazy pattern of `n`
variables takes the tuple form (the roadmap's D17, C).

The tuple of the variables' components is bound once, and each variable
is its selector, which the collector reduces once the tuple is
evaluated (Wadler 1987); otherwise rule (d), each variable a match of
its own.

### <a name="val-plaintuple"></a>`plainTuple`

```sml
val plainTuple : HsAst.pat -> bool
```

`plainTuple p` is whether `p` is a tuple of variables alone, whose
value is the tuple of their components already.

### <a name="val-selector"></a>`selector`

```sml
val selector : string * Core.ty * (string * Core.ty) list * int -> HsDsCore.texp
```

`selector (t, tupleTy, vs, i)` is the selector of the i-th of the
variables `vs` from `t`, the tuple of their components: its i-th field.

`vs` are Core names and types, and `tupleTy` the tuple's type.

### <a name="val-marks"></a>`marks`

```sml
val marks : string * Core.ty * (string * Core.ty) list * HsDsCore.texp -> HsDsCore.texp
```

`marks (t, tupleTy, vs, body)` is `body` after each of the selectors
`vs` of the tuple `t` is marked one for the collector (sel\_mark,
the VM's thunk\_selector).

### <a name="type-clause"></a>`clause`

```sml
type clause = HsAst.pat list * (HsDsEnv.env * HsDsCore.texp -> HsDsCore.texp)
```

A clause: its patterns, and its right-hand side, made in the scope of
the patterns' variables and given what to do where its guards all
fail.

### <a name="val-clauses"></a>`clauses`

```sml
val clauses : HsDsEnv.env * occurrence list * clause list * (Core.ty -> HsDsCore.texp) -> HsDsCore.texp
```

`clauses (env, occurrences, rows, failure)` matches the occurrences
against each clause of `rows` in turn.

Each pattern is matched against its occurrence; the match is the
right-hand side of the first clause that matches, or `failure t` where
none does, `t` the type of the match.

### <a name="val-pattern"></a>`pattern`

```sml
val pattern : HsDsEnv.env * occurrence * HsAst.pat * (HsDsEnv.env -> HsDsCore.texp) * HsDsCore.texp
              -> HsDsCore.texp
```

`pattern (env, occurrence, p, success, failure)` matches one
occurrence against `p` in the Report's way.

It is `success` in the scope of `p`'s variables where it matches, and
`failure`, an atom, where it does not.

### <a name="val-variables"></a>`variables`

```sml
val variables : HsAst.pat -> HsAst.name list
```

`variables p` is the variables `p` binds, in order, by their names in
the renamed tree.

### <a name="val-lazy"></a>`lazy`

```sml
val lazy : HsAst.pat -> bool
```

`lazy p` is whether `p` never fails and forces nothing: a variable,
`_`, `~p` and `x@p` of one of these.

---

<sub>Generated by runedoc from lib/language/haskell/match\_sig.sml; do not edit.</sub>

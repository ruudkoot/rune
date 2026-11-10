# signature CORE_SIMPLIFY

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **CORE_SIMPLIFY**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 9 of 9 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/coresimplify\_sig.sml](../../../../../lib/language/haskell/coresimplify_sig.sml) |

## Synopsis

```sml
signature CORE_SIMPLIFY
structure CoreSimplify : CORE_SIMPLIFY
```

| Implementation |  | Source |
| --- | --- | --- |
| [`CoreSimplify`](../str/CoreSimplify.md) | The Core simplifier's passes (coresimplify\_sig.sml). | [lib/language/haskell/coresimplify.sml](../../../../../lib/language/haskell/coresimplify.sml) |

The Core simplifier (the haskell98 roadmap's M23; D47, D48, D49): rhc's
optimiser, on Core, at -O2; Mid's passes run below it unchanged (D47).

Its passes, in order, each a function of a program to a program whose
every rewrite keeps the program well typed (CoreLint) and keeps what is
shared and what is bottom:

- [`simplify`](#val-simplify): inlining of small functions and of bindings used once,
  beta, a case of a known constructor or literal, a case of a case,
  floating of lets, the folding of primitives and of `fromInteger` and
  `fromRational` of literals at the Prelude's instances (Augustsson 1993,
  §4.3), and with the whole program the values main does not reach
  dropped (CoreSimplifySimp);
- [`specialise`](#val-specialise): each overloaded function applied to closed types and
  constant dictionaries copied at them, local overloaded bindings too,
  under fuel, with [`simplify`](#val-simplify) after (D49's C; CoreSimplifySpec);
- [`eta`](#val-eta): lambdas added where an expression takes more arguments at no
  cost, under the pedantic rule (D48's C) or GHC's default (D48's D, to
  be measured; CoreSimplifyEta).

What it refuses of GHC's: foldr/build, which `seq` makes unsound (Hudak
et al. 2007, §10.3); general full laziness, which changes strictness
(Pałka 2012); eta through a case, and through [`IO`](../../../basis/sig/IO.md), the state hack,
but as D's option. A thunk is never copied where it may run twice: a
binding is inlined into a lambda only where it is a value.

## Interface

<pre>
signature CORE_SIMPLIFY =
sig
  datatype <a href="#type-eta">eta</a> = <a href="#con-pedantic">Pedantic</a> | <a href="#con-ghc">Ghc</a>
  type <a href="#type-options">options</a> = {<a href="#fld-options.spend">spend</a> : unit -&gt; bool, <a href="#fld-options.whole">whole</a> : bool, <a href="#fld-options.eta">eta</a> : eta}
  val <a href="#val-passes">passes</a> : unit -&gt; (string * (options -&gt; Core.program -&gt; Core.program)) list
  val <a href="#val-simplify">simplify</a> : options -&gt; Core.program -&gt; Core.program
  val <a href="#val-specialise">specialise</a> : options -&gt; Core.program -&gt; Core.program
  val <a href="#val-eta">eta</a> : options -&gt; Core.program -&gt; Core.program
  val <a href="#val-counts">counts</a> : unit -&gt; (string * int) list
  val <a href="#val-resetcounts">resetCounts</a> : unit -&gt; unit
  val <a href="#val-unfoldings">unfoldings</a> : Core.program -&gt; Core.decl list
end
</pre>

### <a name="type-eta"></a>`eta`

```sml
datatype eta = Pedantic | Ghc
```

How eta-expansion is done: by the pedantic rule (D48's C), or as GHC
does by default, through a case and through [`IO`](../../../basis/sig/IO.md) (D48's D, built to be
measured).

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-pedantic"></a>`Pedantic` |  |  |
| <a name="con-ghc"></a>`Ghc` |  |  |

### <a name="type-options"></a>`options`

```sml
type options = {spend : unit -> bool, whole : bool, eta : eta}
```

What the passes are given: what is asked before each rewrite, whether
the program is whole, and the eta rule.

`spend` is asked before each rewrite (Pass.spend, so that --fuel stops
them); with `whole` a value main does not reach may go.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-options.spend"></a>`spend` | `unit -> bool` |  |
| <a name="fld-options.whole"></a>`whole` | `bool` |  |
| <a name="fld-options.eta"></a>`eta` | `eta` |  |

### <a name="val-passes"></a>`passes`

```sml
val passes : unit -> (string * (options -> Core.program -> Core.program)) list
```

`passes ()` is each pass, by its name for --dump-after, in the order
they run: core-simplify, core-specialise, core-eta, core-simplify-2.

### <a name="val-simplify"></a>`simplify`

```sml
val simplify : options -> Core.program -> Core.program
```

`simplify opts p` is p simplified, its rounds run until one makes no
rewrite or so many have run.

### <a name="val-specialise"></a>`specialise`

```sml
val specialise : options -> Core.program -> Core.program
```

`specialise opts p` is p with its overloaded functions specialised at
the constant dictionaries they are given, each round simplified.

### <a name="val-eta"></a>`eta`

```sml
val eta : options -> Core.program -> Core.program
```

`eta opts p` is p eta-expanded by the rule of `opts`, then
simplified.

### <a name="val-counts"></a>`counts`

```sml
val counts : unit -> (string * int) list
```

`counts ()` is each kind of rewrite made since [`resetCounts`](#val-resetcounts), with how
many, in the order they were first made.

`eta-refused` (or `eta-ghc-candidate`) counts what GHC's default would
expand and the pedantic rule does not.

### <a name="val-resetcounts"></a>`resetCounts`

```sml
val resetCounts : unit -> unit
```

`resetCounts ()` forgets the counts.

### <a name="val-unfoldings"></a>`unfoldings`

```sml
val unfoldings : Core.program -> Core.decl list
```

`unfoldings p` is the values of p a client of p's unit may inline or
specialise, as Core declarations.

They are its small functions, its dictionaries and its overloaded
functions, each `(val x TYPE EXP)` of p, in p's order: HsIface's section
of unfoldings (D44, M21), whose text is CoreText's.

---

<sub>Generated by runedoc from lib/language/haskell/coresimplify\_sig.sml; do not edit.</sub>

# signature HS_LANGUAGE

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_LANGUAGE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 21 of 21 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/language\_sig.sml](../../../../../lib/language/haskell/language_sig.sml) |

## Synopsis

```sml
signature HS_LANGUAGE
structure HsLanguage :> HS_LANGUAGE
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsLanguage`](../str/HsLanguage.md) |  | [lib/language/haskell/language.sml](../../../../../lib/language/haskell/language.sml) |

The language a module of Haskell is read and checked under (the
haskell2010 roadmap's D4, D5, D8 and D10): an edition, the Report of
Haskell 98 or of Haskell 2010, and the set of rhc's features the module
has, resolved once from the command line and the module's header, as GHC
resolves them. The edition is a base, the last named winning; a step
turns a feature on or off, and the steps are replayed over the edition's
own set in the order they are written, the command line's first, then
the header's. Every stage asks a module's language whether it has a
feature ([`has`](#val-has)), the lexer and the parser of the file they read, the
checker and HsLint of the module a binding belongs to; never a setting
of the run. A unit's key holds each member's set in its canonical form,
without the edition ([`key`](#val-key)), Haskell 98's own set as nothing, so that two
spellings of one set are one key and a store of Haskell 98's keeps its
keys.

A name a command line or a LANGUAGE pragma writes is read by [`read`](#val-read): an
edition, a feature or its `No` form, or a name rhc does not know. In a
module whose edition is Haskell 98 the header's names other than the
editions are not read at all ([`ofHeader`](#val-ofheader), the roadmap's D6), as the 98
Report asks of a pragma an implementation does not handle; the command
line's steps apply to every module of the program alike. The library is
read under its own language, whatever the program's.

## Contents

[Names](#names) &middot;
[A module's language](#a-modules-language)

## Interface

<pre>
signature HS_LANGUAGE =
sig
  datatype <a href="#type-edition">edition</a> =
      <a href="#con-haskell98">Haskell98</a>
    | <a href="#con-haskell2010">Haskell2010</a>
  datatype <a href="#type-feature">feature</a> =
      <a href="#con-cycledefaultscc">CycleDefaultScc</a>
    | <a href="#con-doandifthenelse">DoAndIfThenElse</a>
    | <a href="#con-emptydatadecls">EmptyDataDecls</a>
    | <a href="#con-foreignfunctioninterface">ForeignFunctionInterface</a>
    | <a href="#con-greatestfixpointnames">GreatestFixpointNames</a>
    | <a href="#con-hierarchicalmodules">HierarchicalModules</a>
    | <a href="#con-npluskpatterns">NPlusKPatterns</a>
    | <a href="#con-patternguards">PatternGuards</a>
    | <a href="#con-relaxedpolyrec">RelaxedPolyRec</a>
  datatype <a href="#type-step">step</a> =
      <a href="#con-on">On</a> of feature
    | <a href="#con-off">Off</a> of feature
  type <a href="#type-t">t</a>
  val <a href="#val-ofedition">ofEdition</a> : edition -&gt; t
  val <a href="#val-resolve">resolve</a> : edition * step list -&gt; t
  val <a href="#val-edition">edition</a> : t -&gt; edition
  val <a href="#val-features">features</a> : t -&gt; feature list
  val <a href="#val-has">has</a> : t * feature -&gt; bool
  val <a href="#val-same">same</a> : t * t -&gt; bool
  val <a href="#val-canonical">canonical</a> : t -&gt; string
  val <a href="#val-key">key</a> : t -&gt; string
  val <a href="#val-editionname">editionName</a> : edition -&gt; string
  val <a href="#val-featurename">featureName</a> : feature -&gt; string
  datatype <a href="#type-reading">reading</a> =
      <a href="#con-edition">Edition</a> of edition
    | <a href="#con-steps">Steps</a> of step list
    | <a href="#con-unknown">Unknown</a>
  val <a href="#val-read">read</a> : string -&gt; reading
  type <a href="#type-setting">setting</a> = {<a href="#fld-setting.edition">edition</a> : edition, <a href="#fld-setting.steps">steps</a> : step list}
  val <a href="#val-ofsetting">ofSetting</a> : setting -&gt; t
  val <a href="#val-settingkey">settingKey</a> : setting -&gt; string
  exception <a href="#exn-refused">Refused</a> of int * string
  val <a href="#val-ofheader">ofHeader</a> : setting * {<a href="#fld-ofheader.name">name</a> : string, <a href="#fld-ofheader.at">at</a> : int} list -&gt; t
end
</pre>

### <a name="type-edition"></a>`edition`

```sml
datatype edition =
    Haskell98
  | Haskell2010
```

The Reports rhc reads a module by.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-haskell98"></a>`Haskell98` |  |  |
| <a name="con-haskell2010"></a>`Haskell2010` |  |  |

### <a name="type-feature"></a>`feature`

```sml
datatype feature =
    CycleDefaultScc
  | DoAndIfThenElse
  | EmptyDataDecls
  | ForeignFunctionInterface
  | GreatestFixpointNames
  | HierarchicalModules
  | NPlusKPatterns
  | PatternGuards
  | RelaxedPolyRec
```

A rule a stage of rhc tests, which a module's language has or not.

Haskell 2010's are on in its edition, Haskell 98's n+k patterns in
Haskell 98's; the two settings of a cycle are rhc's own options, set
from the command line alone (the roadmap's D8), and a cycle's modules
agree on them.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-cycledefaultscc"></a>`CycleDefaultScc` |  | one `default` and Rule 2 for a cycle of modules: --cycle-default=scc (98's D30) |
| <a name="con-doandifthenelse"></a>`DoAndIfThenElse` |  | `then` and `else` after a semicolon (2010's 3.14) |
| <a name="con-emptydatadecls"></a>`EmptyDataDecls` |  | a data declaration without constructors (2010's 4.2.1) |
| <a name="con-foreignfunctioninterface"></a>`ForeignFunctionInterface` |  | `foreign` declarations (2010's chapter 8) |
| <a name="con-greatestfixpointnames"></a>`GreatestFixpointNames` |  | a cycle's exports at the greatest fixpoint: --names=greatest (98's D29) |
| <a name="con-hierarchicalmodules"></a>`HierarchicalModules` |  | a module name with dots (2010's 5.1), and --dotted-names in 98 (98's D35) |
| <a name="con-npluskpatterns"></a>`NPlusKPatterns` |  | n+k patterns (98's 3.17.2), which 2010 removes |
| <a name="con-patternguards"></a>`PatternGuards` |  | a guard of qualifiers (2010's 3.13) |
| <a name="con-relaxedpolyrec"></a>`RelaxedPolyRec` |  | a signature cuts a dependency between bindings (2010's 4.5.1) |

### <a name="type-step"></a>`step`

```sml
datatype step =
    On of feature
  | Off of feature
```

A step of a setting: a feature turned on, or off.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-on"></a>`On` | `feature` |  |
| <a name="con-off"></a>`Off` | `feature` |  |

### <a name="type-t"></a>`t`

```sml
type t
```

A language resolved: its edition and its set of features.

### <a name="val-ofedition"></a>`ofEdition`

```sml
val ofEdition : edition -> t
```

`ofEdition e` is the language of the edition `e`, no step after it.

### <a name="val-resolve"></a>`resolve`

```sml
val resolve : edition * step list -> t
```

`resolve (e, steps)` is the language of the edition `e` with `steps`
replayed over its own set, the first first.

A feature a step turns on is in it, one it turns off is not, whatever
the steps before.

### <a name="val-edition"></a>`edition`

```sml
val edition : t -> edition
```

`edition t` is the edition of `t`, which only a message names.

### <a name="val-features"></a>`features`

```sml
val features : t -> feature list
```

`features t` is the set of `t`, in canonical order.

### <a name="val-has"></a>`has`

```sml
val has : t * feature -> bool
```

`has (t, f)` is whether `t` has the feature `f`.

### <a name="val-same"></a>`same`

```sml
val same : t * t -> bool
```

`same (a, b)` is whether `a` and `b` have one set, whatever their
editions.

### <a name="val-canonical"></a>`canonical`

```sml
val canonical : t -> string
```

`canonical t` is the set of `t` as text: its features' names in order
of their names, joined by commas, without the edition.

### <a name="val-key"></a>`key`

```sml
val key : t -> string
```

`key t` is what a unit's key holds of a member under `t`.

It is nothing where `t`'s set is Haskell 98's own, and its canonical
form in braces otherwise, the empty set's among them.

### <a name="val-editionname"></a>`editionName`

```sml
val editionName : edition -> string
```

`editionName e` is the name of `e` that a pragma writes.

### <a name="val-featurename"></a>`featureName`

```sml
val featureName : feature -> string
```

`featureName f` is the name of `f` in a canonical form and in a
message: the name a pragma writes, or for rhc's own, the option that
sets it.

## Names

### <a name="type-reading"></a>`reading`

```sml
datatype reading =
    Edition of edition
  | Steps of step list
  | Unknown
```

What a name of a pragma or of `-X` on the command line means.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-edition"></a>`Edition` | `edition` | an edition, which replaces the edition |
| <a name="con-steps"></a>`Steps` | `step list` | a feature's name or its `No` form: steps, in order |
| <a name="con-unknown"></a>`Unknown` |  | no name rhc knows |

### <a name="val-read"></a>`read`

```sml
val read : string -> reading
```

`read name` is what `name` means, as it is written: names are
case-sensitive.

## A module's language

### <a name="type-setting"></a>`setting`

```sml
type setting = {edition : edition, steps : step list}
```

The setting the command line gives every module of a program: an
edition and steps.

The edition is the last it names (`--language=`, `-XHaskell2010`),
haskell98 where it names none; the steps are in its order (`-X`,
`--dotted-names`, `--names=`, `--cycle-default=`).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-setting.edition"></a>`edition` | `edition` |  |
| <a name="fld-setting.steps"></a>`steps` | `step list` |  |

### <a name="val-ofsetting"></a>`ofSetting`

```sml
val ofSetting : setting -> t
```

`ofSetting s` is the language the setting `s` gives a module whose
header names nothing.

### <a name="val-settingkey"></a>`settingKey`

```sml
val settingKey : setting -> string
```

`settingKey s` is the setting `s` as text, nothing for Haskell 98
with no step: what decides how a header is read beside its text.

### <a name="exn-refused"></a>`Refused`

```sml
exception Refused of int * string
```

A name of the header refused: its offset in the module's text, and
why.

### <a name="val-ofheader"></a>`ofHeader`

```sml
val ofHeader : setting * {name : string, at : int} list -> t
```

`ofHeader (s, names)` is the language of a module under the setting
`s` whose header's LANGUAGE pragmas write `names`.

Each name is given with its offset in the module's text, in order. The
edition is the last the header names, else `s`'s. Where it is Haskell
98, the header's other names are dropped unread; else each is read, its
steps after `s`'s.

**Raises** [`Refused`](#exn-refused) for a name rhc does not know, in a module whose
edition is not Haskell 98, with the name's offset and why (12.3: a
request rhc cannot honour fails).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-ofheader.name"></a>`name` | `string` |  |
| <a name="fld-ofheader.at"></a>`at` | `int` |  |

---

<sub>Generated by runedoc from lib/language/haskell/language\_sig.sml; do not edit.</sub>

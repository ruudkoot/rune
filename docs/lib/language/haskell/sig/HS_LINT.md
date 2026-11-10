# signature HS_LINT

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_LINT**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 9 of 9 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/hslint\_sig.sml](../../../../../lib/language/haskell/hslint_sig.sml) |

## Synopsis

```sml
signature HS_LINT
structure HsLint :> HS_LINT
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsLint`](../str/HsLint.md) |  | [lib/language/haskell/hslint.sml](../../../../../lib/language/haskell/hslint.sml) |

HsLint (the haskell98 roadmap's M16, D54): the independent check of
rhc's types, as AstLint is Rune's. Its first part is a second
inference: a transliteration of Typing Haskell in Haskell (Jones 1999)
in the form its 11.6.3 calls conformant, with kinds and dependency
groups recomputed, the monomorphism restriction and defaulting as the
roadmap's D32 reads the Report (R18, R20, R21, R22), over the renamed
tree. It shares nothing with rhc's checker but the renamer: its
unifier, its kinds and its context reduction are its own, so that a
disagreement between the two is a finding. rhc runs it among the
checks of level 2 (`--lint=2`, `RUNE_LINT=2`), where a refusal of a
program the compile accepts is a bug of rhc's.

## Interface

<pre>
signature HS_LINT =
sig
  type <a href="#type-module">module</a> = {<a href="#fld-module.id">id</a> : string, <a href="#fld-module.ast">ast</a> : HsAst.module, <a href="#fld-module.library">library</a> : bool}
  type <a href="#type-binding">binding</a> = {<a href="#fld-binding.module">module</a> : string, <a href="#fld-binding.name">name</a> : string, <a href="#fld-binding.scheme">scheme</a> : string, <a href="#fld-binding.signed">signed</a> : bool, <a href="#fld-binding.span">span</a> : HsSource.span}
  type <a href="#type-default">default</a> = {<a href="#fld-default.module">module</a> : string, <a href="#fld-default.span">span</a> : HsSource.span, <a href="#fld-default.preds">preds</a> : string, <a href="#fld-default.choice">choice</a> : string}
  type <a href="#type-kind">kind</a> = {<a href="#fld-kind.module">module</a> : string, <a href="#fld-kind.name">name</a> : string, <a href="#fld-kind.kind">kind</a> : string}
  type <a href="#type-derived">derived</a> = {<a href="#fld-derived.module">module</a> : string, <a href="#fld-derived.instance">instance</a> : string}
  type <a href="#type-report">report</a> = {<a href="#fld-report.bindings">bindings</a> : binding list, <a href="#fld-report.defaults">defaults</a> : default list, <a href="#fld-report.kinds">kinds</a> : kind list, <a href="#fld-report.derived">derived</a> : derived list}
  exception <a href="#exn-refused">Refused</a> of HsSource.span * string
  val <a href="#val-infer">infer</a> : {<a href="#fld-infer.groups">groups</a> : module list list, <a href="#fld-infer.main">main</a> : string option, <a href="#fld-infer.cycledefault">cycleDefault</a> : bool} -&gt; report
  val <a href="#val-dump">dump</a> : report * (HsSource.span -&gt; string) * bool -&gt; string
end
</pre>

### <a name="type-module"></a>`module`

```sml
type module = {id : string, ast : HsAst.module, library : bool}
```

A module of a program as HsLint reads it: its identity, its tree as
[`HsRename`](../str/HsRename.md) renamed it and [`HsFixity`](../str/HsFixity.md) resolved it, and whether it is
one of rhc's library's.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-module.id"></a>`id` | `string` |  |
| <a name="fld-module.ast"></a>`ast` | `HsAst.module` |  |
| <a name="fld-module.library"></a>`library` | `bool` |  |

### <a name="type-binding"></a>`binding`

```sml
type binding = {module : string, name : string, scheme : string, signed : bool, span : HsSource.span}
```

A binding of the top level as the second inference left it: its
module, its name, its type as text, whether a signature declared it.

The type is written as the Report writes one, `Eq a => [a] -> a -> Bool`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-binding.module"></a>`module` | `string` |  |
| <a name="fld-binding.name"></a>`name` | `string` |  |
| <a name="fld-binding.scheme"></a>`scheme` | `string` |  |
| <a name="fld-binding.signed"></a>`signed` | `bool` |  |
| <a name="fld-binding.span"></a>`span` | `HsSource.span` |  |

### <a name="type-default"></a>`default`

```sml
type default = {module : string, span : HsSource.span, preds : string, choice : string}
```

A default the second inference chose (4.3.4): the module, where, the
predicates it resolved and the type, as text.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-default.module"></a>`module` | `string` |  |
| <a name="fld-default.span"></a>`span` | `HsSource.span` |  |
| <a name="fld-default.preds"></a>`preds` | `string` |  |
| <a name="fld-default.choice"></a>`choice` | `string` |  |

### <a name="type-kind"></a>`kind`

```sml
type kind = {module : string, name : string, kind : string}
```

The kind inferred for a type constructor or a class's variable (4.6):
the module, the name and the kind, as text.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-kind.module"></a>`module` | `string` |  |
| <a name="fld-kind.name"></a>`name` | `string` |  |
| <a name="fld-kind.kind"></a>`kind` | `string` |  |

### <a name="type-derived"></a>`derived`

```sml
type derived = {module : string, instance : string}
```

A derived instance with the context inferred for it (4.3.3, 10.1):
the module of its type, and the instance as text, `Eq a => Eq (T a)`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-derived.module"></a>`module` | `string` |  |
| <a name="fld-derived.instance"></a>`instance` | `string` |  |

### <a name="type-report"></a>`report`

```sml
type report = {bindings : binding list, defaults : default list, kinds : kind list, derived : derived list}
```

What the second inference found: bindings, defaults, kinds and
derived instances.

The bindings of the top level of every module and the defaults are in
the order it met them; the kinds are of the type constructors and the
classes.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-report.bindings"></a>`bindings` | `binding list` |  |
| <a name="fld-report.defaults"></a>`defaults` | `default list` |  |
| <a name="fld-report.kinds"></a>`kinds` | `kind list` |  |
| <a name="fld-report.derived"></a>`derived` | `derived list` |  |

### <a name="exn-refused"></a>`Refused`

```sml
exception Refused of HsSource.span * string
```

A refusal of the second inference: where, and why, the why naming the
row of the conformance table it is for where there is one.

### <a name="val-infer"></a>`infer`

```sml
val infer : {groups : module list list, main : string option, cycleDefault : bool} -> report
```

`infer {groups, main, cycleDefault}` is the report of the second
inference over the program whose groups of modules are `groups`.

The groups are the strongly connected ones, dependencies first;
`main` is the identity of the module whose `main` must have the type
`IO t` (5), if any; and `cycleDefault` is whether a group's modules
share one [`default`](#type-default) and Rule 2 closes at the group's end (D30's
`--cycle-default=scc`) rather than each module's.

**Raises** [`Refused`](#exn-refused) at the first breach of the Report's static rules
the second inference finds.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-infer.groups"></a>`groups` | `module list list` |  |
| <a name="fld-infer.main"></a>`main` | `string option` |  |
| <a name="fld-infer.cycledefault"></a>`cycleDefault` | `bool` |  |

### <a name="val-dump"></a>`dump`

```sml
val dump : report * (HsSource.span -> string) * bool -> string
```

`dump (report, where_, library)` is the report as text, a line each.

The lines are `KIND MODULE NAME :: KIND` for a type constructor or a
class, `DERIVED MODULE INSTANCE`, `TYPE MODULE NAME :: TYPE` for a
binding, `SIGNED` for one with a signature, and `DEFAULT MODULE WHERE PREDS -> TYPE`, where `where_` gives a span's place: of the program's
modules, and of the library's too where `library` is set, but its
signed bindings.

---

<sub>Generated by runedoc from lib/language/haskell/hslint\_sig.sml; do not edit.</sub>

# signature HS_LINT

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_LINT**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 20 of 20 entries documented |
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
  type <a href="#type-binding">binding</a> = {<a href="#fld-binding.module">module</a> : string, <a href="#fld-binding.name">name</a> : string, <a href="#fld-binding.scheme">scheme</a> : string, <a href="#fld-binding.signed">signed</a> : bool, <a href="#fld-binding.restricted">restricted</a> : bool,
                  <a href="#fld-binding.span">span</a> : HsSource.span}
  type <a href="#type-default">default</a> = {<a href="#fld-default.module">module</a> : string, <a href="#fld-default.span">span</a> : HsSource.span, <a href="#fld-default.preds">preds</a> : string, <a href="#fld-default.choice">choice</a> : string, <a href="#fld-default.ruletwo">ruleTwo</a> : bool}
  type <a href="#type-kind">kind</a> = {<a href="#fld-kind.module">module</a> : string, <a href="#fld-kind.name">name</a> : string, <a href="#fld-kind.kind">kind</a> : string}
  type <a href="#type-class_">class_</a> = {<a href="#fld-class_.name">name</a> : string, <a href="#fld-class_.numeric">numeric</a> : bool, <a href="#fld-class_.standard">standard</a> : bool}
  type <a href="#type-derived">derived</a> = {<a href="#fld-derived.module">module</a> : string, <a href="#fld-derived.instance">instance</a> : string}
  type <a href="#type-report">report</a> = {<a href="#fld-report.bindings">bindings</a> : binding list, <a href="#fld-report.defaults">defaults</a> : default list, <a href="#fld-report.kinds">kinds</a> : kind list, <a href="#fld-report.derived">derived</a> : derived list,
                 <a href="#fld-report.classes">classes</a> : class_ list}
  exception <a href="#exn-refused">Refused</a> of HsSource.span * string
  val <a href="#val-infer">infer</a> : {<a href="#fld-infer.groups">groups</a> : module list list, <a href="#fld-infer.main">main</a> : string option, <a href="#fld-infer.cycledefault">cycleDefault</a> : bool} -&gt; report
  type <a href="#type-claims">claims</a>
  val <a href="#val-claims">claims</a> : string -&gt; claims
  val <a href="#val-rules">rules</a> : (string * string) list
  val <a href="#val-compare">compare</a> : report * claims * (HsSource.span -&gt; string) * string -&gt; unit
  val <a href="#val-replayrules">replayRules</a> : (string * string) list
  type <a href="#type-target">target</a>
  type <a href="#type-library">library</a>
  val <a href="#val-check">check</a> : {<a href="#fld-check.groups">groups</a> : module list list, <a href="#fld-check.main">main</a> : string option, <a href="#fld-check.cycledefault">cycleDefault</a> : bool,
               <a href="#fld-check.records">records</a> : {table : HsEvidence.table, env : HsInfer.env,
                          derived : (string * string * HsAst.decl list) list} option,
               <a href="#fld-check.claims">claims</a> : claims option, <a href="#fld-check.where_">where_</a> : HsSource.span -&gt; string, <a href="#fld-check.fault">fault</a> : string, <a href="#fld-check.library">library</a> : library option}
              -&gt; {report : report, target : target, library : library option}
  val <a href="#val-targetrules">targetRules</a> : (string * string) list
  val <a href="#val-target">target</a> : target * Core.program * string -&gt; unit
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
type binding = {module : string, name : string, scheme : string, signed : bool, restricted : bool,
                span : HsSource.span}
```

A binding of the top level as the second inference left it: its
module, its name, its type as text, whether a signature declared it.

`restricted` is whether its group is restricted (4.5.5, Rule 1). The
type is written as the Report writes one, `Eq a => [a] -> a -> Bool`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-binding.module"></a>`module` | `string` |  |
| <a name="fld-binding.name"></a>`name` | `string` |  |
| <a name="fld-binding.scheme"></a>`scheme` | `string` |  |
| <a name="fld-binding.signed"></a>`signed` | `bool` |  |
| <a name="fld-binding.restricted"></a>`restricted` | `bool` |  |
| <a name="fld-binding.span"></a>`span` | `HsSource.span` |  |

### <a name="type-default"></a>`default`

```sml
type default = {module : string, span : HsSource.span, preds : string, choice : string, ruleTwo : bool}
```

A default the second inference chose (4.3.4): the module, where, the
predicates it resolved and the type, as text.

`ruleTwo` is whether Rule 2 chose it, where the module was inferred.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-default.module"></a>`module` | `string` |  |
| <a name="fld-default.span"></a>`span` | `HsSource.span` |  |
| <a name="fld-default.preds"></a>`preds` | `string` |  |
| <a name="fld-default.choice"></a>`choice` | `string` |  |
| <a name="fld-default.ruletwo"></a>`ruleTwo` | `bool` |  |

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

### <a name="type-class_"></a>`class_`

```sml
type class_ = {name : string, numeric : bool, standard : bool}
```

A class by its name: whether it is numeric and standard (4.3.4).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-class_.name"></a>`name` | `string` |  |
| <a name="fld-class_.numeric"></a>`numeric` | `bool` |  |
| <a name="fld-class_.standard"></a>`standard` | `bool` |  |

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
type report = {bindings : binding list, defaults : default list, kinds : kind list, derived : derived list,
               classes : class_ list}
```

What the second inference found: bindings, defaults, kinds, derived
instances and classes.

The bindings of the top level of every module and the defaults are in
the order it met them; the kinds are of the type constructors and the
classes.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-report.bindings"></a>`bindings` | `binding list` |  |
| <a name="fld-report.defaults"></a>`defaults` | `default list` |  |
| <a name="fld-report.kinds"></a>`kinds` | `kind list` |  |
| <a name="fld-report.derived"></a>`derived` | `derived list` |  |
| <a name="fld-report.classes"></a>`classes` | `class_ list` |  |

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

### <a name="type-claims"></a>`claims`

```sml
type claims
```

What a record claims of a program, in the form [`dump`](#val-dump) prints.

The claims are kinds, derived instances, the types of the bindings of
its modules' top levels and the defaults.

### <a name="val-claims"></a>`claims`

```sml
val claims : string -> claims
```

`claims text` is the claims of `text`, lines in the form of [`dump`](#val-dump);
a line of another form claims nothing.

### <a name="val-rules"></a>`rules`

```sml
val rules : (string * string) list
```

[`rules`](#val-rules) is each rule of [`compare`](#val-compare) with what it holds, its name being
the first word of its breach's message, in brackets: `[rule1] ...`.

### <a name="val-compare"></a>`compare`

```sml
val compare : report * claims * (HsSource.span -> string) * string -> unit
```

`compare (report, claims, where_, fault)` holds the claims to the
report, of the program's modules, `where_` giving a default's place.

`fault`, a rule's name or "", reads the first claim that rule checks
corrupted, so that the rule must refuse it.

**Raises** [`Refused`](#exn-refused) at the first claim a rule refuses.

### <a name="val-replayrules"></a>`replayRules`

```sml
val replayRules : (string * string) list
```

[`replayRules`](#val-replayrules) is each rule of replay with what it holds (Faxén's
rules and rhc's), its name the first word of its breach's message, in
brackets: `[bindg] ...`.

### <a name="type-target"></a>`target`

```sml
type target
```

What the second inference found that the target check reads.

They are the types of the top level, the selectors and default
methods, the classes' dictionaries and the instances' dictionary
functions, as Core's types.

### <a name="type-library"></a>`library`

```sml
type library
```

HsLint's inference of a library's modules, as a saved world keeps it.

It is their environment and what their inference found, from which a
program's own modules are inferred alone (D45).

### <a name="val-check"></a>`check`

```sml
val check : {groups : module list list, main : string option, cycleDefault : bool,
             records : {table : HsEvidence.table, env : HsInfer.env,
                        derived : (string * string * HsAst.decl list) list} option,
             claims : claims option, where_ : HsSource.span -> string, fault : string, library : library option}
            -> {report : report, target : target, library : library option}
```

`check {groups, main, cycleDefault, records, claims, where_, fault, library}` is [`infer`](#val-infer)'s report, with the checker's records replayed and
compared.

With `library`, the groups of its modules are not inferred again: the
rest are inferred after its environment and findings, and only the
records of those modules are replayed, the library's having been
replayed where the library was inferred. The report is of the modules
inferred. Where every module of `groups` is the library's, the result
holds their inference, for a saved world; NONE otherwise.

It gives what the target check reads with the report. With `records`,
the checker's evidence records and environment (HsEvidence, HsInfer) and the derived instances it made as trees
(HsDerive: each one's module, identity and methods), the second
inference checks those instances' methods as any instance's, each
record is replayed by Faxén's rules and rhc's ([`replayRules`](#val-replayrules)), the
derived methods' records too, and the records are then held to the
inference as claims ([`compare`](#val-compare)); with `claims`, those are too.
`fault` is as [`compare`](#val-compare)'s, for every rule.

**Raises** [`Refused`](#exn-refused) at the first breach.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-check.groups"></a>`groups` | `module list list` |  |
| <a name="fld-check.main"></a>`main` | `string option` |  |
| <a name="fld-check.cycledefault"></a>`cycleDefault` | `bool` |  |
| <a name="fld-check.records"></a>`records` | `{table : HsEvidence.table, env : HsInfer.env, derived : (string * string * HsAst.decl list) list} option` |  |
| <a name="fld-check.claims"></a>`claims` | `claims option` |  |
| <a name="fld-check.where_"></a>`where_` | `HsSource.span -> string` |  |
| <a name="fld-check.fault"></a>`fault` | `string` |  |
| <a name="fld-check.library"></a>`library` | `library option` |  |

### <a name="val-targetrules"></a>`targetRules`

```sml
val targetRules : (string * string) list
```

[`targetRules`](#val-targetrules) is each rule of the target check with what it holds,
its name the first word of its breach's message, in brackets:
`[target] ...`.

### <a name="val-target"></a>`target`

```sml
val target : target * Core.program * string -> unit
```

`target (t, program, fault)` holds `program`, the Core made of what
[`check`](#val-check) read, to `t`, what the second inference found.

The program is what desugaring made and CoreLint accepted. Each value
of the top level, selector and default method, each class's
dictionary and each instance's dictionary function is held to the
translation of its source type, as the second inference has it (Hall
et al.'s soundness of the translation), up to the names and order of
its variables and the order of its dictionaries. `fault` is as
[`compare`](#val-compare)'s.

**Raises** [`Refused`](#exn-refused) at the first breach.

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

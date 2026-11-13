# signature HS_DESUGAR

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_DESUGAR**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 10 of 10 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/desugar\_sig.sml](../../../../../lib/language/haskell/desugar_sig.sml) |

## Synopsis

```sml
signature HS_DESUGAR
structure HsDesugar :> HS_DESUGAR
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsDesugar`](../str/HsDesugar.md) |  | [lib/language/haskell/desugar.sml](../../../../../lib/language/haskell/desugar.sml) |

Desugaring to Core (the haskell98 roadmap's M15, D34): a checked
program made the Core program it means.

The program's renamed and resolved trees and the checker's evidence
records (D31) are translated by chapter 3's translations and 4.4.3's,
taken literally (`-O0`, D34's A), with dictionaries for classes.

- Expressions: a literal is `fromInteger` or `fromRational` of its value
  (3.2), but where the checker chose the Prelude's [`Int`](../../../basis/str/Int.md), `Integer`,
  `Float` or `Double`, whose value it is; `e1 op e2` is `(op) e1 e2`
  and `-e` the Prelude's `negate` (3.4); a section is a lambda, its
  operand bound once outside it (3.5, R11's sharing); `if` a `case` on
  `True` and `False` (3.6); a list the constructors it abbreviates
  (3.7); an arithmetic sequence the method of `Enum` (3.10); a list
  comprehension `concatMap` over a local `ok` (3.11); `let` a `let` or
  a `letrec` by dependency, a pattern binding each of its variables a
  lazy match of its own (3.12, rule (d)); `do` `>>=`, `>>` and `fail`
  (3.14); records by their constructors' fields (3.15); `e :: t` a
  binding of its own scheme (3.16); a string literal unpacked lazily
  by the runtime (D24).
- Bindings: a function's clauses one lambda of as many parameters as
  its patterns, matched in the Report's order (4.4.3.1, HsMatch); a
  guarded binding falls to the next clause, or for a pattern binding to
  an error (4.4.3.2); a binding the checker generalised a type lambda
  over its variables and a lambda over its dictionaries, in the order
  of its scheme, so that every use is the variable at its types and its
  dictionaries, as the use's record gives them.
- Classes and instances: a class the data type of its dictionaries,
  with a selector for each method and each direct superclass, and a
  value for each default method; an instance a function of its
  context's dictionaries giving its dictionary, a method it does not
  define its class's default, or an error where there is none (4.3.2).
- A strict constructor used as a value forces its strict arguments,
  the last first (4.2.1, defect 17); a newtype's constructor is a cast.
- `main` is the program's main as Core's `main` wants it.

The names a translation uses are the Prelude's entities, whatever a
program defines (3, E9): [`translationNames`](#val-translationnames) lists them, with Ratio's
`:%`, for a cache's key (H9).

## Contents

[Units (M21) ----

A unit is a strongly connected group of modules, desugared after the
units before it from their interfaces alone: every type, class,
instance and value its modules declare, a value's Core the same in
every unit and in the whole program, its names numbered from the first
within it (HsDsCore.canonical) and a pattern binding of the top level
named after its first variable. The first unit also declares Core's
own types the desugaring makes (IO's newtype, \`()\`, \`\[\]\`, the tuples
to 15), the raisers (HsDsCore.raisers) and the leaves' values.](#units-m21-----a-unit-is-a-strongly-connected-group-of-modules-desugared-after-theunits-before-it-from-their-interfaces-alone-every-type-classinstance-and-value-its-modules-declare-a-values-core-the-same-inevery-unit-and-in-the-whole-program-its-names-numbered-from-the-firstwithin-it-hsdscorecanonical-and-a-pattern-binding-of-the-top-levelnamed-after-its-first-variable-the-first-unit-also-declares-coresown-types-the-desugaring-makes-ios-newtype---the-tuplesto-15-the-raisers-hsdscoreraisers-and-the-leaves-values) &middot;
[The library's units, once](#the-librarys-units-once)

## Interface

<pre>
signature HS_DESUGAR =
sig
  type <a href="#type-module_">module_</a> = {<a href="#fld-module_.id">id</a> : string, <a href="#fld-module_.ast">ast</a> : HsAst.module, <a href="#fld-module_.library">library</a> : bool}
  val <a href="#val-program">program</a> : {<a href="#fld-program.modules">modules</a> : module_ list, <a href="#fld-program.groups">groups</a> : string list list, <a href="#fld-program.infer">infer</a> : HsInfer.env, <a href="#fld-program.evidence">evidence</a> : HsEvidence.table,
                 <a href="#fld-program.derived">derived</a> : (string * string * HsAst.decl list) list, <a href="#fld-program.prelude">prelude</a> : string * string -&gt; string option,
                 <a href="#fld-program.entity">entity</a> : string * string * string -&gt; string, <a href="#fld-program.runtime">runtime</a> : Core.program, <a href="#fld-program.leaves">leaves</a> : (string * string list) list,
                 <a href="#fld-program.main">main</a> : string}
                -&gt; Core.program
  type <a href="#type-interface">interface</a> = {<a href="#fld-interface.core">core</a> : Core.program, <a href="#fld-interface.primtypes">primTypes</a> : (string * string) list, <a href="#fld-interface.builtincons">builtinCons</a> : (string * string) list,
                    <a href="#fld-interface.fields">fields</a> : (string * string list) list, <a href="#fld-interface.constructors">constructors</a> : (string * string list) list,
                    <a href="#fld-interface.leaves">leaves</a> : string list, <a href="#fld-interface.defaults">defaults</a> : string list, <a href="#fld-interface.forced">forced</a> : (string * bool list) list}
  val <a href="#val-unit">unit</a> : {<a href="#fld-unit.interfaces">interfaces</a> : interface list, <a href="#fld-unit.modules">modules</a> : module_ list, <a href="#fld-unit.infer">infer</a> : HsInfer.env, <a href="#fld-unit.evidence">evidence</a> : HsEvidence.table,
              <a href="#fld-unit.derived">derived</a> : (string * string * HsAst.decl list) list, <a href="#fld-unit.prelude">prelude</a> : string * string -&gt; string option,
              <a href="#fld-unit.entity">entity</a> : string * string * string -&gt; string, <a href="#fld-unit.runtime">runtime</a> : Core.program, <a href="#fld-unit.leaves">leaves</a> : (string * string list) list,
              <a href="#fld-unit.main">main</a> : string option}
             -&gt; Core.program * interface
  type <a href="#type-library">library</a>
  val <a href="#val-library">library</a> : {<a href="#fld-library.modules">modules</a> : module_ list, <a href="#fld-library.groups">groups</a> : string list list, <a href="#fld-library.infer">infer</a> : HsInfer.env, <a href="#fld-library.evidence">evidence</a> : HsEvidence.table,
                 <a href="#fld-library.derived">derived</a> : (string * string * HsAst.decl list) list, <a href="#fld-library.prelude">prelude</a> : string * string -&gt; string option,
                 <a href="#fld-library.entity">entity</a> : string * string * string -&gt; string, <a href="#fld-library.runtime">runtime</a> : Core.program, <a href="#fld-library.leaves">leaves</a> : (string * string list) list}
                -&gt; library
  val <a href="#val-prepare">prepare</a> : library -&gt; unit
  val <a href="#val-programon">programOn</a> : library * {<a href="#fld-programon.modules">modules</a> : module_ list, <a href="#fld-programon.groups">groups</a> : string list list, <a href="#fld-programon.infer">infer</a> : HsInfer.env,
                             <a href="#fld-programon.evidence">evidence</a> : HsEvidence.table, <a href="#fld-programon.derived">derived</a> : (string * string * HsAst.decl list) list,
                             <a href="#fld-programon.prelude">prelude</a> : string * string -&gt; string option, <a href="#fld-programon.entity">entity</a> : string * string * string -&gt; string,
                             <a href="#fld-programon.main">main</a> : string}
                  -&gt; Core.program
  val <a href="#val-translationnames">translationNames</a> : (string * string * string) list
  val <a href="#val-missingprimitives">missingPrimitives</a> : unit -&gt; string list
end
</pre>

### <a name="type-module_"></a>`module_`

```sml
type module_ = {id : string, ast : HsAst.module, library : bool}
```

A module of the program: its identity, its renamed tree with fixity
resolved, and whether it is the library's.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-module_.id"></a>`id` | `string` |  |
| <a name="fld-module_.ast"></a>`ast` | `HsAst.module` |  |
| <a name="fld-module_.library"></a>`library` | `bool` |  |

### <a name="val-program"></a>`program`

```sml
val program : {modules : module_ list, groups : string list list, infer : HsInfer.env, evidence : HsEvidence.table,
               derived : (string * string * HsAst.decl list) list, prelude : string * string -> string option,
               entity : string * string * string -> string, runtime : Core.program, leaves : (string * string list) list,
               main : string}
              -> Core.program
```

`program {modules, groups, infer, evidence, derived, prelude, entity, runtime, leaves, main}` is the Core program of the checked `modules`.

The modules are every module of the program and of the library it
reaches, in `groups`, their strongly connected groups by identity in
order, each desugared as a unit after those before it ([`unit`](#val-unit)). Their
checking left the environment `infer`, the records `evidence` and the
methods of the derived instances, `derived`, each with its module and
its instance's identity (HsDerive, M14), which are desugared as a
written instance's.

`prelude` and `entity` find what the translations name (HsDsEnv);
`runtime` is rhc's runtime in Core, whose types it is written against
and which it does not repeat; `leaves` are the modules of primitives
that no file holds, each with what it exports, the runtime's values of
those names; `main` is the key of the program's `main`. The result
holds what `main` reaches, and the data types it names, each body made
only where `main` reaches it.

**Raises** [`Fail`](../../../basis/sig/GENERAL.md#exn-fail) for what the checker should have refused, or a form
this desugaring does not take, with a message.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-program.modules"></a>`modules` | `module_ list` |  |
| <a name="fld-program.groups"></a>`groups` | `string list list` |  |
| <a name="fld-program.infer"></a>`infer` | `HsInfer.env` |  |
| <a name="fld-program.evidence"></a>`evidence` | `HsEvidence.table` |  |
| <a name="fld-program.derived"></a>`derived` | `(string * string * HsAst.decl list) list` |  |
| <a name="fld-program.prelude"></a>`prelude` | `string * string -> string option` |  |
| <a name="fld-program.entity"></a>`entity` | `string * string * string -> string` |  |
| <a name="fld-program.runtime"></a>`runtime` | `Core.program` |  |
| <a name="fld-program.leaves"></a>`leaves` | `(string * string list) list` |  |
| <a name="fld-program.main"></a>`main` | `string` |  |

## Units (M21) ----

A unit is a strongly connected group of modules, desugared after the
units before it from their interfaces alone: every type, class,
instance and value its modules declare, a value's Core the same in
every unit and in the whole program, its names numbered from the first
within it (HsDsCore.canonical) and a pattern binding of the top level
named after its first variable. The first unit also declares Core's
own types the desugaring makes (IO's newtype, \`()\`, \`\[\]\`, the tuples
to 15), the raisers (HsDsCore.raisers) and the leaves' values.

### <a name="type-interface"></a>`interface`

```sml
type interface = {core : Core.program, primTypes : (string * string) list, builtinCons : (string * string) list,
                  fields : (string * string list) list, constructors : (string * string list) list,
                  leaves : string list, defaults : string list, forced : (string * bool list) list}
```

What a unit's desugaring leaves the units after it.

`core` is its types and its values as imports (`(import x TYPE)`);
`primTypes` each type of the library with no constructor, by key, made
Core's own, and `builtinCons` Bool's constructors, Core's; `fields`
each constructor's fields' keys (`""` for one with no name), and
`constructors` each data type's constructors' keys, in order; `leaves`
the keys of the leaves' values, and `defaults` the methods with a
default (a `%dm:` value); `forced` each constructor with a strict field
of a newtype's type, lazy in Core, by the fields it forces where it is
applied (HsDsCore.forced).

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-interface.core"></a>`core` | `Core.program` |  |
| <a name="fld-interface.primtypes"></a>`primTypes` | `(string * string) list` |  |
| <a name="fld-interface.builtincons"></a>`builtinCons` | `(string * string) list` |  |
| <a name="fld-interface.fields"></a>`fields` | `(string * string list) list` |  |
| <a name="fld-interface.constructors"></a>`constructors` | `(string * string list) list` |  |
| <a name="fld-interface.leaves"></a>`leaves` | `string list` |  |
| <a name="fld-interface.defaults"></a>`defaults` | `string list` |  |
| <a name="fld-interface.forced"></a>`forced` | `(string * bool list) list` |  |

### <a name="val-unit"></a>`unit`

```sml
val unit : {interfaces : interface list, modules : module_ list, infer : HsInfer.env, evidence : HsEvidence.table,
            derived : (string * string * HsAst.decl list) list, prelude : string * string -> string option,
            entity : string * string * string -> string, runtime : Core.program, leaves : (string * string list) list,
            main : string option}
           -> Core.program * interface
```

`unit p` is the Core of the unit of the modules of `p`, after the units
of its interfaces, in order, and its interface.

The Core is its types, a copy of each type of the units before that it
names, an import of each of their values that it names, and every
value it defines; the runtime's names are left to the runtime's unit.
`infer` and `evidence` are a checking that holds the unit's modules and
what they import; `leaves` is the first unit's, and `main`, the key of
the program's `main`, the unit's that defines it, whose Core then has
Core's `main`. The rest is as [`program`](#val-program) takes it.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-unit.interfaces"></a>`interfaces` | `interface list` |  |
| <a name="fld-unit.modules"></a>`modules` | `module_ list` |  |
| <a name="fld-unit.infer"></a>`infer` | `HsInfer.env` |  |
| <a name="fld-unit.evidence"></a>`evidence` | `HsEvidence.table` |  |
| <a name="fld-unit.derived"></a>`derived` | `(string * string * HsAst.decl list) list` |  |
| <a name="fld-unit.prelude"></a>`prelude` | `string * string -> string option` |  |
| <a name="fld-unit.entity"></a>`entity` | `string * string * string -> string` |  |
| <a name="fld-unit.runtime"></a>`runtime` | `Core.program` |  |
| <a name="fld-unit.leaves"></a>`leaves` | `(string * string list) list` |  |
| <a name="fld-unit.main"></a>`main` | `string option` |  |

## The library's units, once

### <a name="type-library"></a>`library`

```sml
type library
```

The library's units, desugared once (D45's saved world), each value's
body made the first time it is wanted.

### <a name="val-library"></a>`library`

```sml
val library : {modules : module_ list, groups : string list list, infer : HsInfer.env, evidence : HsEvidence.table,
               derived : (string * string * HsAst.decl list) list, prelude : string * string -> string option,
               entity : string * string * string -> string, runtime : Core.program, leaves : (string * string list) list}
              -> library
```

`library p` is the units of the groups of `p` that hold modules marked
[`library`](#val-library).

`p` is a checking of the library alone (every instance of its
environment is the library's), in [`program`](#val-program)'s form without `main`.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-library.modules"></a>`modules` | `module_ list` |  |
| <a name="fld-library.groups"></a>`groups` | `string list list` |  |
| <a name="fld-library.infer"></a>`infer` | `HsInfer.env` |  |
| <a name="fld-library.evidence"></a>`evidence` | `HsEvidence.table` |  |
| <a name="fld-library.derived"></a>`derived` | `(string * string * HsAst.decl list) list` |  |
| <a name="fld-library.prelude"></a>`prelude` | `string * string -> string option` |  |
| <a name="fld-library.entity"></a>`entity` | `string * string * string -> string` |  |
| <a name="fld-library.runtime"></a>`runtime` | `Core.program` |  |
| <a name="fld-library.leaves"></a>`leaves` | `(string * string list) list` |  |

### <a name="val-prepare"></a>`prepare`

```sml
val prepare : library -> unit
```

`prepare lib` makes every body of `lib` now, as a saved world keeps
them; a body that fails is failed again where a program reaches it.

### <a name="val-programon"></a>`programOn`

```sml
val programOn : library * {modules : module_ list, groups : string list list, infer : HsInfer.env,
                           evidence : HsEvidence.table, derived : (string * string * HsAst.decl list) list,
                           prelude : string * string -> string option, entity : string * string * string -> string,
                           main : string}
                -> Core.program
```

`programOn (lib, p)` is [`program`](#val-program) of `p` with the library's units
`lib`: the groups of `p` that hold no module of the library desugared
after them.

The modules, environment, records and derived instances of `p` are the
whole checking's, the library's among them, as [`program`](#val-program) takes them;
a value of the library is `lib`'s.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-programon.modules"></a>`modules` | `module_ list` |  |
| <a name="fld-programon.groups"></a>`groups` | `string list list` |  |
| <a name="fld-programon.infer"></a>`infer` | `HsInfer.env` |  |
| <a name="fld-programon.evidence"></a>`evidence` | `HsEvidence.table` |  |
| <a name="fld-programon.derived"></a>`derived` | `(string * string * HsAst.decl list) list` |  |
| <a name="fld-programon.prelude"></a>`prelude` | `string * string -> string option` |  |
| <a name="fld-programon.entity"></a>`entity` | `string * string * string -> string` |  |
| <a name="fld-programon.main"></a>`main` | `string` |  |

### <a name="val-translationnames"></a>`translationNames`

```sml
val translationNames : (string * string * string) list
```

[`translationNames`](#val-translationnames) is each entity the translations name, by its
space, its module and its name.

### <a name="val-missingprimitives"></a>`missingPrimitives`

```sml
val missingPrimitives : unit -> string list
```

`missingPrimitives ()` is each primitive of the library that the last
desugaring found neither in Core nor in the runtime, or of another
type.

It is of the bodies the desugaring made, the library's made once among
them.

Each is an error where it is used.

---

<sub>Generated by runedoc from lib/language/haskell/desugar\_sig.sml; do not edit.</sub>

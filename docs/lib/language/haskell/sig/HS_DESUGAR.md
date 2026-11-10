# signature HS_DESUGAR

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_DESUGAR**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 4 of 4 entries documented |
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

## Interface

<pre>
signature HS_DESUGAR =
sig
  type <a href="#type-module_">module_</a> = {<a href="#fld-module_.id">id</a> : string, <a href="#fld-module_.ast">ast</a> : HsAst.module, <a href="#fld-module_.library">library</a> : bool}
  val <a href="#val-program">program</a> : {<a href="#fld-program.modules">modules</a> : module_ list, <a href="#fld-program.infer">infer</a> : HsInfer.env, <a href="#fld-program.evidence">evidence</a> : HsEvidence.table,
                 <a href="#fld-program.derived">derived</a> : (string * string * HsAst.decl list) list, <a href="#fld-program.prelude">prelude</a> : string * string -&gt; string option, <a href="#fld-program.entity">entity</a> : string * string * string -&gt; string,
                 <a href="#fld-program.runtime">runtime</a> : Core.program, <a href="#fld-program.leaves">leaves</a> : (string * string list) list, <a href="#fld-program.main">main</a> : string}
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
val program : {modules : module_ list, infer : HsInfer.env, evidence : HsEvidence.table,
               derived : (string * string * HsAst.decl list) list, prelude : string * string -> string option, entity : string * string * string -> string,
               runtime : Core.program, leaves : (string * string list) list, main : string}
              -> Core.program
```

`program {modules, infer, evidence, derived, prelude, entity, runtime, leaves, main}` is the Core program of the checked `modules`.

The modules are every module of the program and of the library it
reaches, whose checking left the environment `infer`, the records
`evidence` and the methods of the derived instances, `derived`, each
with its module and its instance's identity (HsDerive, M14), which are
desugared as a written instance's.

`prelude` and `entity` find what the translations name (HsDsEnv);
`runtime` is rhc's runtime in Core, whose types it is written against
and which it does not repeat; `leaves` are the modules of primitives
that no file holds, each with what it exports, the runtime's values of
those names; `main` is the key of the program's `main`. The result
holds what `main` reaches, and the data types of the program.

**Raises** [`Fail`](../../../basis/sig/GENERAL.md#exn-fail) for what the checker should have refused, or a form
this desugaring does not take, with a message.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-program.modules"></a>`modules` | `module_ list` |  |
| <a name="fld-program.infer"></a>`infer` | `HsInfer.env` |  |
| <a name="fld-program.evidence"></a>`evidence` | `HsEvidence.table` |  |
| <a name="fld-program.derived"></a>`derived` | `(string * string * HsAst.decl list) list` |  |
| <a name="fld-program.prelude"></a>`prelude` | `string * string -> string option` |  |
| <a name="fld-program.entity"></a>`entity` | `string * string * string -> string` |  |
| <a name="fld-program.runtime"></a>`runtime` | `Core.program` |  |
| <a name="fld-program.leaves"></a>`leaves` | `(string * string list) list` |  |
| <a name="fld-program.main"></a>`main` | `string` |  |

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
[`program`](#val-program) found neither in Core nor in the runtime, or of another type.

Each is an error where it is used.

---

<sub>Generated by runedoc from lib/language/haskell/desugar\_sig.sml; do not edit.</sub>

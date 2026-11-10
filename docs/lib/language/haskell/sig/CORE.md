# signature CORE

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **CORE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 21 of 21 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/core\_sig.sml](../../../../../lib/language/haskell/core_sig.sml) |

## Synopsis

```sml
signature CORE
structure Core : CORE
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Core`](../str/Core.md) | Core: its terms and types, and what is done to types (core\_sig.sml). | [lib/language/haskell/core.sml](../../../../../lib/language/haskell/core.sml) |

Core, rhc's typed lazy intermediate language (the haskell98 roadmap, D2):
System F with type constructors applied to types (`m a`), a lazy `let`
and `letrec`, and a `case` that is the only thing that forces. A value
is passed by an atom, a variable or a literal, so every allocation is a
`let` and every evaluation a `case`.

A type says whether a value may be unevaluated. A binding of a lifted
type `T` may hold a suspension; one of `!T` holds a value evaluated to
weak head normal form. [`!`](../../../basis/sig/GENERAL.md#val-op-bang) stands only where a value is bound: at a
lambda's binder, a function's parameter, a constructor's field and a
component of an unboxed tuple, and the binder of a `case` and the
fields it binds are of the evaluated type. So a strictness result has
a type to go to, and Core to Mid knows which positions are `susp T` and
which `T`. Where an evaluated value meets a lazy position, `!T` is taken
for `T`; the other way is a `case`.

An unlifted type, the state token `World` and an unboxed tuple, is
never suspended: no `let` binds it, and a `case` takes it apart. `IO a`
is `World -> (utuple World a)` in the Prelude's Core (D25).

## Contents

[Types](#types) &middot;
[Terms](#terms) &middot;
[What is built in](#what-is-built-in) &middot;
[Types, taken apart and compared](#types-taken-apart-and-compared)

## Interface

<pre>
signature CORE =
sig
  datatype <a href="#type-kind">kind</a> =
      <a href="#con-star">Star</a>
    | <a href="#con-unlifted">Unlifted</a>
    | <a href="#con-arrow">Arrow</a> of kind * kind
  datatype <a href="#type-ty">ty</a> =
      <a href="#con-tvar">TVar</a> of string
    | <a href="#con-tcon">TCon</a> of string
    | <a href="#con-tapp">TApp</a> of ty * ty
    | <a href="#con-tfun">TFun</a> of ty * ty
    | <a href="#con-tforall">TForall</a> of string * kind * ty
    | <a href="#con-teval">TEval</a> of ty
    | <a href="#con-tutuple">TUTuple</a> of ty list
  datatype <a href="#type-lit">lit</a> =
      <a href="#con-lint">LInt</a> of IntInf.int
    | <a href="#con-linteger">LInteger</a> of IntInf.int
    | <a href="#con-lchar">LChar</a> of int
    | <a href="#con-ldouble">LDouble</a> of string
    | <a href="#con-lfloat">LFloat</a> of string
    | <a href="#con-lstr">LStr</a> of string
  datatype <a href="#type-atom">atom</a> = <a href="#con-var">Var</a> of string | <a href="#con-lit">Lit</a> of lit
  datatype <a href="#type-arg">arg</a> = <a href="#con-tyarg">TyArg</a> of ty | <a href="#con-valarg">ValArg</a> of atom
  datatype <a href="#type-binder">binder</a> = <a href="#con-tybinder">TyBinder</a> of string * kind | <a href="#con-valbinder">ValBinder</a> of string * ty
  datatype <a href="#type-exp">exp</a> =
      <a href="#con-atom">Atom</a> of atom
    | <a href="#con-app">App</a> of exp * arg list
    | <a href="#con-lam">Lam</a> of binder list * exp
    | <a href="#con-let">Let</a> of string * ty * exp * exp
    | <a href="#con-letrec">LetRec</a> of (string * ty * exp) list * exp
    | <a href="#con-case">Case</a> of exp * string * alt list
    | <a href="#con-con">Con</a> of string * ty list * atom list
    | <a href="#con-prim">Prim</a> of string * ty list * atom list
    | <a href="#con-utuple">UTuple</a> of atom list
    | <a href="#con-cast">Cast</a> of exp * ty
  and <a href="#type-alt">alt</a> =
      <a href="#con-altcon">AltCon</a> of string * string list * exp
    | <a href="#con-altlit">AltLit</a> of lit * exp
    | <a href="#con-altutuple">AltUTuple</a> of string list * exp
    | <a href="#con-altdefault">AltDefault</a> of exp
  datatype <a href="#type-decl">decl</a> =
      <a href="#con-data">Data</a> of string * (string * kind) list * (string * ty list) list
    | <a href="#con-newtype">Newtype</a> of string * (string * kind) list * string * ty
    | <a href="#con-val">Val</a> of string * ty * exp
  type <a href="#type-program">program</a> = decl list
  val <a href="#val-builtintypes">builtinTypes</a> : (string * kind) list
  val <a href="#val-builtindata">builtinData</a> : decl list
  val <a href="#val-stripeval">stripEval</a> : ty -&gt; ty
  val <a href="#val-iseval">isEval</a> : ty -&gt; bool
  val <a href="#val-spine">spine</a> : ty -&gt; ty * ty list
  val <a href="#val-apply">apply</a> : ty * ty list -&gt; ty
  val <a href="#val-freetyvars">freeTyVars</a> : ty -&gt; string list
  val <a href="#val-substty">substTy</a> : (string * ty) list * ty -&gt; ty
  val <a href="#val-equalty">equalTy</a> : ty * ty -&gt; bool
  val <a href="#val-litty">litTy</a> : lit -&gt; ty
  val <a href="#val-lamty">lamTy</a> : binder list * ty -&gt; ty
end
</pre>

## Types

### <a name="type-kind"></a>`kind`

```sml
datatype kind =
    Star
  | Unlifted
  | Arrow of kind * kind
```

The kind of a type.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-star"></a>`Star` |  | a lifted type, whose values may be suspended |
| <a name="con-unlifted"></a>`Unlifted` |  | `World` and an unboxed tuple: always evaluated |
| <a name="con-arrow"></a>`Arrow` | `kind * kind` | a type constructor, from types of one kind to another |

### <a name="type-ty"></a>`ty`

```sml
datatype ty =
    TVar of string
  | TCon of string
  | TApp of ty * ty
  | TFun of ty * ty
  | TForall of string * kind * ty
  | TEval of ty
  | TUTuple of ty list
```

A type.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-tvar"></a>`TVar` | `string` | a type variable, bound by `forall` or a type binder |
| <a name="con-tcon"></a>`TCon` | `string` | a type constructor: declared by the program or built in |
| <a name="con-tapp"></a>`TApp` | `ty * ty` | `f a`, a constructor or a variable applied |
| <a name="con-tfun"></a>`TFun` | `ty * ty` | a function; its parameter may be `!` |
| <a name="con-tforall"></a>`TForall` | `string * kind * ty` |  |
| <a name="con-teval"></a>`TEval` | `ty` | `!T`: a value of `T`, evaluated |
| <a name="con-tutuple"></a>`TUTuple` | `ty list` | an unboxed tuple, `(utuple T ...)`; a component may be `!` |

## Terms

### <a name="type-lit"></a>`lit`

```sml
datatype lit =
    LInt of IntInf.int
  | LInteger of IntInf.int
  | LChar of int
  | LDouble of string
  | LFloat of string
  | LStr of string
```

A literal. A floating literal keeps the digits it was written with.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-lint"></a>`LInt` | `IntInf.int` | an `Int` |
| <a name="con-linteger"></a>`LInteger` | `IntInf.int` | an `Integer`, written `5I` |
| <a name="con-lchar"></a>`LChar` | `int` | a `Char`, a code point |
| <a name="con-ldouble"></a>`LDouble` | `string` | a `Double`, written `2.5` |
| <a name="con-lfloat"></a>`LFloat` | `string` | a `Float`, written `2.5F` |
| <a name="con-lstr"></a>`LStr` | `string` | a `Str`, a string of bytes |

### <a name="type-atom"></a>`atom`

```sml
datatype atom = Var of string | Lit of lit
```

An argument: a variable or a literal.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-var"></a>`Var` | `string` |  |
| <a name="con-lit"></a>`Lit` | `lit` |  |

### <a name="type-arg"></a>`arg`

```sml
datatype arg = TyArg of ty | ValArg of atom
```

What an application gives a function.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-tyarg"></a>`TyArg` | `ty` |  |
| <a name="con-valarg"></a>`ValArg` | `atom` |  |

### <a name="type-binder"></a>`binder`

```sml
datatype binder = TyBinder of string * kind | ValBinder of string * ty
```

What a lambda binds.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-tybinder"></a>`TyBinder` | `string * kind` |  |
| <a name="con-valbinder"></a>`ValBinder` | `string * ty` |  |

### <a name="type-exp"></a>`exp`

```sml
datatype exp =
    Atom of atom
  | App of exp * arg list
  | Lam of binder list * exp
  | Let of string * ty * exp * exp
  | LetRec of (string * ty * exp) list * exp
  | Case of exp * string * alt list
  | Con of string * ty list * atom list
  | Prim of string * ty list * atom list
  | UTuple of atom list
  | Cast of exp * ty
```

An expression. A binder named `_` binds nothing.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-atom"></a>`Atom` | `atom` |  |
| <a name="con-app"></a>`App` | `exp * arg list` | a function applied to types and atoms |
| <a name="con-lam"></a>`Lam` | `binder list * exp` |  |
| <a name="con-let"></a>`Let` | `string * ty * exp * exp` | a lazy `let`: the binding is suspended |
| <a name="con-letrec"></a>`LetRec` | `(string * ty * exp) list * exp` |  |
| <a name="con-case"></a>`Case` | `exp * string * alt list` | forces the scrutinee and binds its value |
| <a name="con-con"></a>`Con` | `string * ty list * atom list` | a constructor of a data type, saturated |
| <a name="con-prim"></a>`Prim` | `string * ty list * atom list` | a primitive, saturated (CorePrim) |
| <a name="con-utuple"></a>`UTuple` | `atom list` | an unboxed tuple |
| <a name="con-cast"></a>`Cast` | `exp * ty` | into or out of a newtype, at its head |

### <a name="type-alt"></a>`alt`

```sml
datatype alt =
    AltCon of string * string list * exp
  | AltLit of lit * exp
  | AltUTuple of string list * exp
  | AltDefault of exp
```

An alternative of a `case`.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-altcon"></a>`AltCon` | `string * string list * exp` | a constructor and the binders of its fields |
| <a name="con-altlit"></a>`AltLit` | `lit * exp` | an `Int`, `Integer` or `Char` |
| <a name="con-altutuple"></a>`AltUTuple` | `string list * exp` | the components of an unboxed tuple |
| <a name="con-altdefault"></a>`AltDefault` | `exp` | anything else; last |

### <a name="type-decl"></a>`decl`

```sml
datatype decl =
    Data of string * (string * kind) list * (string * ty list) list
  | Newtype of string * (string * kind) list * string * ty
  | Val of string * ty * exp
```

A declaration of a program. Every value of the top level is in the
scope of all of them.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-data"></a>`Data` | `string * (string * kind) list * (string * ty list) list` | a data type, its parameters and its constructors, each with the types of its fields |
| <a name="con-newtype"></a>`Newtype` | `string * (string * kind) list * string * ty` | a newtype, its parameters, its constructor and the type it wraps |
| <a name="con-val"></a>`Val` | `string * ty * exp` | a value of the top level |

### <a name="type-program"></a>`program`

```sml
type program = decl list
```

A program: what it declares, in order. `main`, of type
`World -> (utuple World T)`, is what runs.

## What is built in

### <a name="val-builtintypes"></a>`builtinTypes`

```sml
val builtinTypes : (string * kind) list
```

[`builtinTypes`](#val-builtintypes) is each type constructor built in with its kind: [`Int`](../../../basis/str/Int.md),
`Integer`, [`Char`](../../../basis/str/Char.md), `Double`, `Float`, `Str`, `Exn`, [`Bool`](../../../basis/str/Bool.md), `World`
and `Ref`.

### <a name="val-builtindata"></a>`builtinData`

```sml
val builtinData : decl list
```

[`builtinData`](#val-builtindata) is the data types built in: [`Bool`](../../../basis/str/Bool.md), whose constructors
`False` and `True` are 0 and 1, as Mid's [`bool`](../../../basis/sig/BOOL.md#type-bool).

## Types, taken apart and compared

### <a name="val-stripeval"></a>`stripEval`

```sml
val stripEval : ty -> ty
```

`stripEval t` is `t` without a [`!`](../../../basis/sig/GENERAL.md#val-op-bang) at its head.

### <a name="val-iseval"></a>`isEval`

```sml
val isEval : ty -> bool
```

`isEval t` is whether `t` has a [`!`](../../../basis/sig/GENERAL.md#val-op-bang) at its head.

### <a name="val-spine"></a>`spine`

```sml
val spine : ty -> ty * ty list
```

`spine t` is the head of the type application `t` and its arguments.

### <a name="val-apply"></a>`apply`

```sml
val apply : ty * ty list -> ty
```

`apply (t, args)` applies `t` to `args`, left to right.

### <a name="val-freetyvars"></a>`freeTyVars`

```sml
val freeTyVars : ty -> string list
```

`freeTyVars t` is the type variables free in `t`, each once.

### <a name="val-substty"></a>`substTy`

```sml
val substTy : (string * ty) list * ty -> ty
```

`substTy (s, t)` replaces each variable of `s` free in `t` by its type,
renaming a binder of `t` that would capture a variable of those types.

### <a name="val-equalty"></a>`equalTy`

```sml
val equalTy : ty * ty -> bool
```

`equalTy (a, b)` is whether `a` and `b` are the same type, up to the
names of their bound variables.

### <a name="val-litty"></a>`litTy`

```sml
val litTy : lit -> ty
```

`litTy l` is the type of the literal `l`, without [`!`](../../../basis/sig/GENERAL.md#val-op-bang).

### <a name="val-lamty"></a>`lamTy`

```sml
val lamTy : binder list * ty -> ty
```

`lamTy (binders, t)` is the type of a lambda of `binders` whose body
has type `t`.

---

<sub>Generated by runedoc from lib/language/haskell/core\_sig.sml; do not edit.</sub>

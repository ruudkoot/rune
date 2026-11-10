# structure HsDsEnv

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; [Structures](../structures.md) &rsaquo; **HsDsEnv**

|  |  |
| --- | --- |
| Signature | [`HS_DS_ENV`](../sig/HS_DS_ENV.md) |
| Status | required |
| Members | 49 |
| Tests | not listed |
| Source | [lib/language/haskell/desugar\_env.sml](../../../../../lib/language/haskell/desugar_env.sml) |

## Synopsis

```sml
structure HsDsEnv :> HS_DS_ENV
```

## Members

What each means is on [`HS_DS_ENV`](../sig/HS_DS_ENV.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`env`](../sig/HS_DS_ENV.md#type-env) | *a type of its own* |
| type | [`program`](../sig/HS_DS_ENV.md#type-program) | `{entity : string * string * string -> string, evidence : HsEvidence.table, infer : HsInfer.env, library : string -> bool, prelude : string * string -> string option}` |
| val | [`bind`](../sig/HS_DS_ENV.md#val-bind) | `env * string * Core.atom * Core.ty -> env` |
| val | [`bindOf`](../sig/HS_DS_ENV.md#val-bindof) | `{file : string, start : int, stop : int} -> HsEvidence.record option` |
| val | [`bindTypes`](../sig/HS_DS_ENV.md#val-bindtypes) | `env * (string * Core.kind) list -> env` |
| val | [`builtinCon`](../sig/HS_DS_ENV.md#val-builtincon) | `string * string -> unit` |
| val | [`classes`](../sig/HS_DS_ENV.md#val-classes) | `unit -> HsClasses.env` |
| val | [`conName`](../sig/HS_DS_ENV.md#val-conname) | `string -> string` |
| val | [`coreName`](../sig/HS_DS_ENV.md#val-corename) | `string -> string` |
| val | [`defaultName`](../sig/HS_DS_ENV.md#val-defaultname) | `string -> string` |
| val | [`dfunName`](../sig/HS_DS_ENV.md#val-dfunname) | `string -> string` |
| val | [`dict`](../sig/HS_DS_ENV.md#val-dict) | `env -> HsEvidence.dict -> Core.exp * Core.ty` |
| val | [`dictCon`](../sig/HS_DS_ENV.md#val-dictcon) | `string -> string` |
| val | [`empty`](../sig/HS_DS_ENV.md#val-empty) | `env` |
| val | [`fieldsOf`](../sig/HS_DS_ENV.md#val-fieldsof) | `string -> string list` |
| val | [`genScheme`](../sig/HS_DS_ENV.md#val-genscheme) | `{ctx : {cls : string, ty : HsTypes.ty} list, ty : HsTypes.ty, vars : int} -> Core.ty` |
| val | [`global`](../sig/HS_DS_ENV.md#val-global) | `string -> Core.exp * Core.ty` |
| val | [`haskellForm`](../sig/HS_DS_ENV.md#val-haskellform) | `Core.ty -> Core.ty` |
| val | [`homeOf`](../sig/HS_DS_ENV.md#val-homeof) | `string -> string` |
| val | [`instantiate`](../sig/HS_DS_ENV.md#val-instantiate) | `env -> (Core.exp * Core.ty) * HsTypes.ty list * HsEvidence.dict list -> Core.exp * Core.ty` |
| val | [`integerLit`](../sig/HS_DS_ENV.md#val-integerlit) | `env -> IntInf.int * HsTypes.ty * HsEvidence.dict -> Core.exp * Core.ty` |
| val | [`ioTy`](../sig/HS_DS_ENV.md#val-ioty) | `Core.ty -> Core.ty` |
| val | [`isLibrary`](../sig/HS_DS_ENV.md#val-islibrary) | `string -> bool` |
| val | [`isPrimType`](../sig/HS_DS_ENV.md#val-isprimtype) | `string -> bool` |
| val | [`libraryEntity`](../sig/HS_DS_ENV.md#val-libraryentity) | `string * string * string -> string` |
| val | [`lookup`](../sig/HS_DS_ENV.md#val-lookup) | `env * string -> (Core.atom * Core.ty) option` |
| val | [`matchType`](../sig/HS_DS_ENV.md#val-matchtype) | `Core.ty * string list * Core.ty -> Core.ty list option` |
| val | [`method`](../sig/HS_DS_ENV.md#val-method) | `env -> string * Core.ty list * (Core.exp * Core.ty) list -> Core.exp * Core.ty` |
| val | [`nameOf`](../sig/HS_DS_ENV.md#val-nameof) | `string -> string` |
| val | [`overloadedOf`](../sig/HS_DS_ENV.md#val-overloadedof) | `string * {file : string, start : int, stop : int} -> HsTypes.ty * (string * HsEvidence.dict) list` |
| val | [`predTy`](../sig/HS_DS_ENV.md#val-predty) | `env -> {cls : string, ty : HsTypes.ty} -> Core.ty` |
| val | [`prelude`](../sig/HS_DS_ENV.md#val-prelude) | `string * string -> string` |
| val | [`primType`](../sig/HS_DS_ENV.md#val-primtype) | `string * string -> unit` |
| val | [`rationalLit`](../sig/HS_DS_ENV.md#val-rationallit) | `env -> string * HsTypes.ty * HsEvidence.dict -> Core.exp * Core.ty` |
| val | [`records`](../sig/HS_DS_ENV.md#val-records) | `string * {file : string, start : int, stop : int} -> HsEvidence.record list` |
| val | [`scheme`](../sig/HS_DS_ENV.md#val-scheme) | `env -> {ctx : {cls : string, ty : HsTypes.ty} list, ty : HsTypes.ty, vars : string list} -> Core.ty * (string * Core.kind) list` |
| val | [`setFields`](../sig/HS_DS_ENV.md#val-setfields) | `string * string list -> unit` |
| val | [`start`](../sig/HS_DS_ENV.md#val-start) | `program -> unit` |
| val | [`stringLit`](../sig/HS_DS_ENV.md#val-stringlit) | `int list -> Core.exp * Core.ty` |
| val | [`superDict`](../sig/HS_DS_ENV.md#val-superdict) | `env -> HsEvidence.dict * string * string -> HsEvidence.dict` |
| val | [`superName`](../sig/HS_DS_ENV.md#val-supername) | `string * string -> string` |
| val | [`toHaskell`](../sig/HS_DS_ENV.md#val-tohaskell) | `(Core.exp * Core.ty) * Core.ty -> Core.exp * Core.ty` |
| val | [`ty`](../sig/HS_DS_ENV.md#val-ty) | `env -> HsTypes.ty -> Core.ty` |
| val | [`tyGen`](../sig/HS_DS_ENV.md#val-tygen) | `env * Core.ty list -> HsTypes.ty -> Core.ty` |
| val | [`tyconName`](../sig/HS_DS_ENV.md#val-tyconname) | `string -> string` |
| val | [`typeVars`](../sig/HS_DS_ENV.md#val-typevars) | `env -> (string * Core.kind) list` |
| val | [`useOf`](../sig/HS_DS_ENV.md#val-useof) | `{file : string, start : int, stop : int} -> {dicts : HsEvidence.dict list, tys : HsTypes.ty list}` |
| val | [`valueKey`](../sig/HS_DS_ENV.md#val-valuekey) | `HsAst.name -> string` |
| val | [`valueScheme`](../sig/HS_DS_ENV.md#val-valuescheme) | `string -> {ctx : {cls : string, ty : HsTypes.ty} list, ty : HsTypes.ty, vars : int} option` |

---

<sub>Generated by runedoc from lib/language/haskell/desugar\_env.sml; do not edit.</sub>

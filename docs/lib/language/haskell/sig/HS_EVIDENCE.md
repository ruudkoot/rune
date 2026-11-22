# signature HS_EVIDENCE

[Haskell 98 front end](../README.md) &rsaquo; Languages &rsaquo; **HS_EVIDENCE**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 11 of 11 entries documented |
| Tests | not listed |
| Source | [lib/language/haskell/evidence\_sig.sml](../../../../../lib/language/haskell/evidence_sig.sml) |

## Synopsis

```sml
signature HS_EVIDENCE
structure HsEvidence :> HS_EVIDENCE
```

| Implementation |  | Source |
| --- | --- | --- |
| [`HsEvidence`](../str/HsEvidence.md) |  | [lib/language/haskell/evidence.sml](../../../../../lib/language/haskell/evidence.sml) |

The evidence records of Haskell 98's checker (the haskell98 roadmap's
D31, M13): what inference chose at each node of the renamed tree, by
node, in the manner of Rune's `Witness` (lib/compiler/elab/witness.sml),
for desugaring to Core (M15) to translate and HsLint (M16, D54) to
check: each overloaded use's dictionaries, each binder's type and the
dictionary parameters it is abstracted over, each instance's
dictionaries, and each defaulting, with what it chose from.

A type here is closed: a constructor applied to types and the type
variables of schemes, signatures and instance heads, each a rigid
variable with a name unique to the program ([`HsTypes.TRigid`](../sig/HS_TYPES.md#con-trigid)); a
scheme's variables are those names. A dictionary is Faxén's [`dict`](#type-dict)
judgement made explicit: a parameter in scope, an instance's dictionary
function at the types of its head's variables applied to the
dictionaries of its context ("dict inst"), or a superclass's taken from
a dictionary of its subclass ("dict super").

A node is the kind of record and the span of the node of the renamed
tree it belongs to, `KIND@FILE:START-STOP`: the name of a variable or a
constructor where it is used or bound, a literal, a negation, an
enumeration, a `do`, a pattern, an instance declaration.

## Interface

<pre>
signature HS_EVIDENCE =
sig
  datatype <a href="#type-dict">dict</a> =
      <a href="#con-dparam">DParam</a> of string
    | <a href="#con-dinst">DInst</a> of {<a href="#fld-dinst.inst">inst</a> : string, <a href="#fld-dinst.tys">tys</a> : HsTypes.ty list, <a href="#fld-dinst.args">args</a> : dict list}
    | <a href="#con-dsuper">DSuper</a> of {<a href="#fld-dsuper.dict">dict</a> : dict, <a href="#fld-dsuper.cls">cls</a> : string, <a href="#fld-dsuper.super">super</a> : string}
  type <a href="#type-scheme">scheme</a> = {<a href="#fld-scheme.vars">vars</a> : string list, <a href="#fld-scheme.ctx">ctx</a> : HsTypes.pred list, <a href="#fld-scheme.ty">ty</a> : HsTypes.ty}
  datatype <a href="#type-record">record</a> =
      <a href="#con-use">Use</a> of {<a href="#fld-use.tys">tys</a> : HsTypes.ty list, <a href="#fld-use.dicts">dicts</a> : dict list}
    | <a href="#con-overloaded">Overloaded</a> of {<a href="#fld-overloaded.ty">ty</a> : HsTypes.ty, <a href="#fld-overloaded.dicts">dicts</a> : (string * dict) list}
    | <a href="#con-binding">Binding</a> of {<a href="#fld-binding.scheme">scheme</a> : scheme, <a href="#fld-binding.params">params</a> : string list}
    | <a href="#con-mono">Mono</a> of HsTypes.ty
    | <a href="#con-instance">Instance</a> of {<a href="#fld-instance.inst">inst</a> : string, <a href="#fld-instance.vars">vars</a> : string list, <a href="#fld-instance.params">params</a> : string list, <a href="#fld-instance.supers">supers</a> : dict list}
    | <a href="#con-class">Class</a> of {<a href="#fld-class.param">param</a> : string}
    | <a href="#con-defaulted">Defaulted</a> of {<a href="#fld-defaulted.var">var</a> : string, <a href="#fld-defaulted.preds">preds</a> : HsTypes.pred list, <a href="#fld-defaulted.candidates">candidates</a> : HsTypes.ty list, <a href="#fld-defaulted.module_">module_</a> : string,
                    <a href="#fld-defaulted.choice">choice</a> : HsTypes.ty}
  val <a href="#val-node">node</a> : string * HsSource.span -&gt; string
  type <a href="#type-table">table</a>
  val <a href="#val-empty">empty</a> : unit -&gt; table
  val <a href="#val-add">add</a> : table * string * record -&gt; unit
  val <a href="#val-find">find</a> : table * string -&gt; record list
  val <a href="#val-all">all</a> : table -&gt; (string * record list) list
  val <a href="#val-showdict">showDict</a> : dict -&gt; string
  val <a href="#val-showrecord">showRecord</a> : record -&gt; string
end
</pre>

### <a name="type-dict"></a>`dict`

```sml
datatype dict =
    DParam of string
  | DInst of {inst : string, tys : HsTypes.ty list, args : dict list}
  | DSuper of {dict : dict, cls : string, super : string}
```

A dictionary.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-dparam"></a>`DParam` | `string` | a dictionary parameter, by name |
| <a name="con-dinst"></a>`DInst` | `{inst : string, tys : HsTypes.ty list, args : dict list}` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-dinst.inst"></a>`inst` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-dinst.tys"></a>`tys` | `HsTypes.ty list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-dinst.args"></a>`args` | `dict list` |  |
| <a name="con-dsuper"></a>`DSuper` | `{dict : dict, cls : string, super : string}` | an instance, at its head's variables, of its context's dictionaries |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-dsuper.dict"></a>`dict` | `dict` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-dsuper.cls"></a>`cls` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-dsuper.super"></a>`super` | `string` |  |

the dictionary of `super`, a superclass of `cls`, in one of `cls`

### <a name="type-scheme"></a>`scheme`

```sml
type scheme = {vars : string list, ctx : HsTypes.pred list, ty : HsTypes.ty}
```

A scheme as the records hold it: its variables by name, its context
and its type, over those names.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-scheme.vars"></a>`vars` | `string list` |  |
| <a name="fld-scheme.ctx"></a>`ctx` | `HsTypes.pred list` |  |
| <a name="fld-scheme.ty"></a>`ty` | `HsTypes.ty` |  |

### <a name="type-record"></a>`record`

```sml
datatype record =
    Use of {tys : HsTypes.ty list, dicts : dict list}
  | Overloaded of {ty : HsTypes.ty, dicts : (string * dict) list}
  | Binding of {scheme : scheme, params : string list}
  | Mono of HsTypes.ty
  | Instance of {inst : string, vars : string list, params : string list, supers : dict list}
  | Class of {param : string}
  | Defaulted of {var : string, preds : HsTypes.pred list, candidates : HsTypes.ty list, module_ : string,
                  choice : HsTypes.ty}
```

A record.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-use"></a>`Use` | `{tys : HsTypes.ty list, dicts : dict list}` | a variable or a constructor used: the types its scheme's variables are instantiated at, in order, and the dictionaries of its context, in order |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-use.tys"></a>`tys` | `HsTypes.ty list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-use.dicts"></a>`dicts` | `dict list` |  |
| <a name="con-overloaded"></a>`Overloaded` | `{ty : HsTypes.ty, dicts : (string * dict) list}` | a construct the Report translates through a class, at a type: a numeric literal (`fromInteger`: Num; `fromRational`: Fractional), a negation (`negate`: Num), an enumeration (Enum), a `do` (Monad), a numeric literal pattern (Eq and Num) or an n+k pattern (Integral); each dictionary by its class |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-overloaded.ty"></a>`ty` | `HsTypes.ty` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-overloaded.dicts"></a>`dicts` | `(string * dict) list` |  |
| <a name="con-binding"></a>`Binding` | `{scheme : scheme, params : string list}` | a binder generalised: its scheme, and the dictionary parameters it is abstracted over, one for each predicate of the scheme's context, in order |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-binding.scheme"></a>`scheme` | `scheme` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-binding.params"></a>`params` | `string list` |  |
| <a name="con-mono"></a>`Mono` | `HsTypes.ty` | a binder not generalised, of a lambda, a case, a generator, a restricted group, or an instance's method: its type |
| <a name="con-instance"></a>`Instance` | `{inst : string, vars : string list, params : string list, supers : dict list}` | an instance declaration: its head's variables, the dictionary parameters of its context, in order, and the dictionaries of its class's direct superclasses at its type, in the class's order |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-instance.inst"></a>`inst` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-instance.vars"></a>`vars` | `string list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-instance.params"></a>`params` | `string list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-instance.supers"></a>`supers` | `dict list` |  |
| <a name="con-class"></a>`Class` | `{param : string}` | a class declaration's default methods: the dictionary parameter of the class |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-class.param"></a>`param` | `string` |  |
| <a name="con-defaulted"></a>`Defaulted` | `{var : string, preds : HsTypes.pred list, candidates : HsTypes.ty list, module_ : string, choice : HsTypes.ty}` | a type variable defaulted (4.3.4): its predicates, the types the `default` in force offers, from the module named, and the type chosen |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-defaulted.var"></a>`var` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-defaulted.preds"></a>`preds` | `HsTypes.pred list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-defaulted.candidates"></a>`candidates` | `HsTypes.ty list` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-defaulted.module_"></a>`module_` | `string` |  |
| &nbsp;&nbsp;&nbsp;&nbsp;<a name="fld-defaulted.choice"></a>`choice` | `HsTypes.ty` |  |

### <a name="val-node"></a>`node`

```sml
val node : string * HsSource.span -> string
```

`node (kind, span)` is the key of a node.

### <a name="type-table"></a>`table`

```sml
type table
```

A table of records by node.

### <a name="val-empty"></a>`empty`

```sml
val empty : unit -> table
```

`empty ()` is a new table with no record.

### <a name="val-add"></a>`add`

```sml
val add : table * string * record -> unit
```

`add (t, node, r)` adds the record `r` at `node`, after any there.

### <a name="val-find"></a>`find`

```sml
val find : table * string -> record list
```

`find (t, node)` is the records at `node`, in the order added.

### <a name="val-all"></a>`all`

```sml
val all : table -> (string * record list) list
```

`all t` is every record, by node, in the order of the nodes' keys.

### <a name="val-showdict"></a><a name="val-showrecord"></a>`showDict`, `showRecord`

```sml
val showDict : dict -> string
val showRecord : record -> string
```

`showDict d` and `showRecord r` are as a dump prints them.

---

<sub>Generated by runedoc from lib/language/haskell/evidence\_sig.sml; do not edit.</sub>

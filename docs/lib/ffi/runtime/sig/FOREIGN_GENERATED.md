# signature FOREIGN_GENERATED

[Foreign runtime support](../README.md) &rsaquo; Foreign interfaces &rsaquo; **FOREIGN_GENERATED**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 10 of 10 entries documented |
| Tests | not listed |
| Source | [lib/ffi/runtime/generated\_sig.sml](../../../../../lib/ffi/runtime/generated_sig.sml) |

## Synopsis

```sml
signature FOREIGN_GENERATED
structure ForeignGenerated :> FOREIGN_GENERATED
```

| Implementation |  | Source |
| --- | --- | --- |
| [`ForeignGenerated`](../str/ForeignGenerated.md) |  | [lib/ffi/runtime/generated.sml](../../../../../lib/ffi/runtime/generated.sml) |

Explicit sessions for generated dynamic foreign declarations.

## Interface

<pre>
signature FOREIGN_GENERATED =
sig
  type <a href="#type-descriptor">descriptor</a> = {<a href="#fld-descriptor.name">name</a> : string, <a href="#fld-descriptor.symbol">symbol</a> : string, <a href="#fld-descriptor.abi">abi</a> : int,
    <a href="#fld-descriptor.result">result</a> : RuneForeign.scalar, <a href="#fld-descriptor.arguments">arguments</a> : RuneForeign.scalar list}
  type <a href="#type-abifacts">abiFacts</a> = {<a href="#fld-abifacts.architecture">architecture</a> : string, <a href="#fld-abifacts.charbits">charBits</a> : int, <a href="#fld-abifacts.charsigned">charSigned</a> : bool,
    <a href="#fld-abifacts.scalars">scalars</a> : {name : string, size : int, alignment : int} list}
  type <a href="#type-session">session</a>
  exception <a href="#exn-closed">Closed</a>
  val <a href="#val-create">create</a> : {<a href="#fld-create.libraries">libraries</a> : string list, <a href="#fld-create.descriptors">descriptors</a> : descriptor list,
    <a href="#fld-create.target">target</a> : {pointerBytes : int, littleEndian : bool, stdcall : bool}} -&gt; session
  val <a href="#val-createchecked">createChecked</a> : {<a href="#fld-createchecked.libraries">libraries</a> : string list, <a href="#fld-createchecked.descriptors">descriptors</a> : descriptor list,
    <a href="#fld-createchecked.target">target</a> : {pointerBytes : int, littleEndian : bool, stdcall : bool},
    <a href="#fld-createchecked.abifacts">abiFacts</a> : abiFacts} -&gt; session
  val <a href="#val-prepare">prepare</a> : session -&gt; string -&gt; RuneForeign.resource
  val <a href="#val-invoke">invoke</a> : session -&gt; string -&gt; RuneForeign.argument list -&gt; RuneForeign.result
  val <a href="#val-invokedeferred">invokeDeferred</a> : session -&gt; string -&gt; RuneForeign.argument list -&gt;
    {<a href="#fld-invokedeferred.result">result</a> : RuneForeign.result, <a href="#fld-invokedeferred.callbackexception">callbackException</a> : exn option}
  val <a href="#val-close">close</a> : session -&gt; unit
end
</pre>

### <a name="type-descriptor"></a>`descriptor`

```sml
type descriptor = {name : string, symbol : string, abi : int,
  result : RuneForeign.scalar, arguments : RuneForeign.scalar list}
```

A fixed native descriptor; its spelling retains the original declaration.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-descriptor.name"></a>`name` | `string` |  |
| <a name="fld-descriptor.symbol"></a>`symbol` | `string` |  |
| <a name="fld-descriptor.abi"></a>`abi` | `int` |  |
| <a name="fld-descriptor.result"></a>`result` | `RuneForeign.scalar` |  |
| <a name="fld-descriptor.arguments"></a>`arguments` | `RuneForeign.scalar list` |  |

### <a name="type-abifacts"></a>`abiFacts`

```sml
type abiFacts = {architecture : string, charBits : int, charSigned : bool,
  scalars : {name : string, size : int, alignment : int} list}
```

Measured C object facts, in addition to pointer size and byte order.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-abifacts.architecture"></a>`architecture` | `string` |  |
| <a name="fld-abifacts.charbits"></a>`charBits` | `int` |  |
| <a name="fld-abifacts.charsigned"></a>`charSigned` | `bool` |  |
| <a name="fld-abifacts.scalars"></a>`scalars` | `{name : string, size : int, alignment : int} list` |  |

### <a name="type-session"></a>`session`

```sml
type session
```

A lazily opened collection of native libraries and prepared calls.

### <a name="exn-closed"></a>`Closed`

```sml
exception Closed
```

Access after successful close.

### <a name="val-create"></a>`create`

```sml
val create : {libraries : string list, descriptors : descriptor list,
  target : {pointerBytes : int, littleEndian : bool, stdcall : bool}} -> session
```

`create {libraries, descriptors, target}` creates a session without loading.

Target facts must agree with the executing VM before any native entry.
Library names are searched in their declared order for each symbol.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-create.libraries"></a>`libraries` | `string list` |  |
| <a name="fld-create.descriptors"></a>`descriptors` | `descriptor list` |  |
| <a name="fld-create.target"></a>`target` | `{pointerBytes : int, littleEndian : bool, stdcall : bool}` |  |

### <a name="val-createchecked"></a>`createChecked`

```sml
val createChecked : {libraries : string list, descriptors : descriptor list,
  target : {pointerBytes : int, littleEndian : bool, stdcall : bool},
  abiFacts : abiFacts} -> session
```

`createChecked {libraries, descriptors, target, abiFacts}` checks the full ABI.

Generated code uses this constructor. Every scalar size and alignment,
architecture and plain-char representation must match before loading.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-createchecked.libraries"></a>`libraries` | `string list` |  |
| <a name="fld-createchecked.descriptors"></a>`descriptors` | `descriptor list` |  |
| <a name="fld-createchecked.target"></a>`target` | `{pointerBytes : int, littleEndian : bool, stdcall : bool}` |  |
| <a name="fld-createchecked.abifacts"></a>`abiFacts` | `abiFacts` |  |

### <a name="val-prepare"></a>`prepare`

```sml
val prepare : session -> string -> RuneForeign.resource
```

`prepare session name` returns the cached descriptor for a declared name.

**Raises** [`Closed`](#exn-closed), [`Fail`](../../../basis/sig/GENERAL.md#exn-fail) for an undeclared name, or a native bridge error.
The resource belongs to the session and must not be released separately.

### <a name="val-invoke"></a>`invoke`

```sml
val invoke : session -> string -> RuneForeign.argument list -> RuneForeign.result
```

`invoke session name arguments` executes a declared, fixed native call.

Native status bytes and immediately captured errors remain available.

### <a name="val-invokedeferred"></a>`invokeDeferred`

```sml
val invokeDeferred : session -> string -> RuneForeign.argument list ->
  {result : RuneForeign.result, callbackException : exn option}
```

`invokeDeferred session name arguments` exposes ownership before propagation.

Register cleanup for an owned pointer result, then propagate a saved
callback exception. The native result and its captured errors survive.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-invokedeferred.result"></a>`result` | `RuneForeign.result` |  |
| <a name="fld-invokedeferred.callbackexception"></a>`callbackException` | `exn option` |  |

### <a name="val-close"></a>`close`

```sml
val close : session -> unit
```

`close session` releases prepared calls, symbols and libraries in order.

A live native dependent can prevent unloading. Successfully released
entries are removed, so closing can be retried after dependents close.

---

<sub>Generated by runedoc from lib/ffi/runtime/generated\_sig.sml; do not edit.</sub>

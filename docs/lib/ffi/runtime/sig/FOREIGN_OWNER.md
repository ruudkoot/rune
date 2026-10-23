# signature FOREIGN_OWNER

[Foreign runtime support](../README.md) &rsaquo; Foreign interfaces &rsaquo; **FOREIGN_OWNER**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 12 of 12 entries documented |
| Tests | not listed |
| Source | [lib/ffi/runtime/owner\_sig.sml](../../../../../lib/ffi/runtime/owner_sig.sml) |

## Synopsis

```sml
signature FOREIGN_OWNER
structure ForeignOwner :> FOREIGN_OWNER
```

| Implementation |  | Source |
| --- | --- | --- |
| [`ForeignOwner`](../str/ForeignOwner.md) |  | [lib/ffi/runtime/owner.sml](../../../../../lib/ffi/runtime/owner.sml) |

Explicit ownership and borrowed-use scopes for native pointers.

## Interface

<pre>
signature FOREIGN_OWNER =
sig
  type <a href="#type-owner">owner</a>
  type <a href="#type-destructor">destructor</a> = {<a href="#fld-destructor.call">call</a> : RuneForeign.resource,
    <a href="#fld-destructor.arguments">arguments</a> : RuneForeign.resource -&gt; RuneForeign.argument list, <a href="#fld-destructor.failure">failure</a> : RuneForeign.failure}
  exception <a href="#exn-closed">Closed</a>
  exception <a href="#exn-busy">Busy</a>
  exception <a href="#exn-alreadyowned">AlreadyOwned</a>
  exception <a href="#exn-failed">Failed</a> of RuneForeign.result
  val <a href="#val-adopt">adopt</a> : {<a href="#fld-adopt.pointer">pointer</a> : RuneForeign.resource, <a href="#fld-adopt.destructor">destructor</a> : destructor} -&gt; owner
  val <a href="#val-isclosed">isClosed</a> : owner -&gt; bool
  val <a href="#val-withborrow">withBorrow</a> : owner -&gt; (RuneForeign.resource -&gt; 'a) -&gt; 'a
  val <a href="#val-retain">retain</a> : owner -&gt; (unit -&gt; unit)
  val <a href="#val-close">close</a> : owner -&gt; unit
  val <a href="#val-inscope">inScope</a> : ForeignScope.scope * owner -&gt; ForeignScope.ticket
end
</pre>

### <a name="type-owner"></a>`owner`

```sml
type owner
```

A shared owner identity; copies observe the same closing/closed state.

### <a name="type-destructor"></a>`destructor`

```sml
type destructor = {call : RuneForeign.resource,
  arguments : RuneForeign.resource -> RuneForeign.argument list, failure : RuneForeign.failure}
```

A prepared native destructor and its argument projection.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-destructor.call"></a>`call` | `RuneForeign.resource` |  |
| <a name="fld-destructor.arguments"></a>`arguments` | `RuneForeign.resource -> RuneForeign.argument list` |  |
| <a name="fld-destructor.failure"></a>`failure` | `RuneForeign.failure` |  |

### <a name="exn-closed"></a>`Closed`

```sml
exception Closed
```

An operation on an already retired native identity.

### <a name="exn-busy"></a>`Busy`

```sml
exception Busy
```

An attempt to close an active borrower or a destructor in progress.

### <a name="exn-alreadyowned"></a>`AlreadyOwned`

```sml
exception AlreadyOwned
```

A second owner for the same live native address.

### <a name="exn-failed"></a>`Failed`

```sml
exception Failed of RuneForeign.result
```

A native destructor returned its annotated failure status.

### <a name="val-adopt"></a>`adopt`

```sml
val adopt : {pointer : RuneForeign.resource, destructor : destructor} -> owner
```

`adopt {pointer, destructor}` takes ownership of a native-owned pointer.

The pointer must come from an ownership-annotated foreign result.
Failure leaves responsibility with the caller. Destruction also checks
native provenance and rejects Rune-owned storage before native entry.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-adopt.pointer"></a>`pointer` | `RuneForeign.resource` |  |
| <a name="fld-adopt.destructor"></a>`destructor` | `destructor` |  |

### <a name="val-isclosed"></a>`isClosed`

```sml
val isClosed : owner -> bool
```

`isClosed owner` refreshes its shared state from the native registry.

### <a name="val-withborrow"></a>`withBorrow`

```sml
val withBorrow : owner -> (RuneForeign.resource -> 'a) -> 'a
```

`withBorrow owner body` guards one synchronous use of its raw identity.

The borrowed identity must not outlive this use without an explicit raw
retention contract. Native views additionally retain their source.

**Raises** [`Closed`](#exn-closed) or [`Busy`](#exn-busy) when the owner cannot be borrowed.

### <a name="val-retain"></a>`retain`

```sml
val retain : owner -> (unit -> unit)
```

`retain owner` holds a borrow guard until its returned release function runs.

The release function is idempotent. Retained callback contexts and
buffers release their lease only after native code unregisters them.
This guards ownership; it never copies storage or creates a native view.

**Raises** [`Closed`](#exn-closed) or [`Busy`](#exn-busy) before acquiring a lease.

### <a name="val-close"></a>`close`

```sml
val close : owner -> unit
```

`close owner` invokes its destructor and retires its native identity.

A failed native destructor preserves ownership for retry and raises
[`Failed`](#exn-failed) with the raw status/error. Native bridge failures propagate.

**Raises** [`Closed`](#exn-closed), [`Busy`](#exn-busy) or [`Failed`](#exn-failed).

### <a name="val-inscope"></a>`inScope`

```sml
val inScope : ForeignScope.scope * owner -> ForeignScope.ticket
```

`inScope (scope, owner)` registers at-most-once scoped destruction.

An already closed owner needs no second destructor call. Cancel the
returned cleanup ticket to transfer responsibility beyond this scope.

---

<sub>Generated by runedoc from lib/ffi/runtime/owner\_sig.sml; do not edit.</sub>

# signature FOREIGN_MEMORY

[Foreign runtime support](../README.md) &rsaquo; Foreign interfaces &rsaquo; **FOREIGN_MEMORY**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 16 of 16 entries documented |
| Tests | not listed |
| Source | [lib/ffi/runtime/memory\_sig.sml](../../../../../lib/ffi/runtime/memory_sig.sml) |

## Synopsis

```sml
signature FOREIGN_MEMORY
structure ForeignMemory :> FOREIGN_MEMORY
```

| Implementation |  | Source |
| --- | --- | --- |
| [`ForeignMemory`](../str/ForeignMemory.md) |  | [lib/ffi/runtime/memory.sml](../../../../../lib/ffi/runtime/memory.sml) |

Bounded native buffers and scoped borrowed SML array copies.

## Interface

<pre>
signature FOREIGN_MEMORY =
sig
  type <a href="#type-buffer">buffer</a>
  datatype <a href="#type-direction">direction</a> = <a href="#con-input">Input</a> | <a href="#con-output">Output</a> | <a href="#con-inputoutput">InputOutput</a>
  type <a href="#type-argument">argument</a> = {<a href="#fld-argument.array">array</a> : Word8Array.array, <a href="#fld-argument.offset">offset</a> : int, <a href="#fld-argument.length">length</a> : int, <a href="#fld-argument.direction">direction</a> : direction}
  exception <a href="#exn-bounds">Bounds</a>
  val <a href="#val-allocate">allocate</a> : int -&gt; buffer
  val <a href="#val-frombytes">fromBytes</a> : string -&gt; buffer
  val <a href="#val-release">release</a> : buffer -&gt; unit
  val <a href="#val-length">length</a> : buffer -&gt; int
  val <a href="#val-raw">raw</a> : buffer -&gt; RuneForeign.resource
  val <a href="#val-slice">slice</a> : buffer * int * int -&gt; buffer
  val <a href="#val-pointer">pointer</a> : {<a href="#fld-pointer.pointer">pointer</a> : RuneForeign.resource, <a href="#fld-pointer.length">length</a> : int} -&gt; buffer
  val <a href="#val-read">read</a> : buffer * int * int -&gt; string
  val <a href="#val-write">write</a> : buffer * int * string -&gt; unit
  val <a href="#val-terminated">terminated</a> : {<a href="#fld-terminated.buffer">buffer</a> : buffer, <a href="#fld-terminated.unitbytes">unitBytes</a> : int} -&gt; string
  val <a href="#val-withbytes">withBytes</a> : string -&gt; (buffer -&gt; 'a) -&gt; 'a
  val <a href="#val-witharrays">withArrays</a> : argument list -&gt; (buffer list -&gt; 'a) -&gt; 'a
end
</pre>

### <a name="type-buffer"></a>`buffer`

```sml
type buffer
```

A checked native allocation, view or explicitly bounded pointer view.

### <a name="type-direction"></a>`direction`

```sml
datatype direction = Input | Output | InputOutput
```

Input snapshots, copied outputs, or both.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-input"></a>`Input` |  |  |
| <a name="con-output"></a>`Output` |  |  |
| <a name="con-inputoutput"></a>`InputOutput` |  |  |

### <a name="type-argument"></a>`argument`

```sml
type argument = {array : Word8Array.array, offset : int, length : int, direction : direction}
```

One array range passed as a native pointer during a scoped call.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-argument.array"></a>`array` | `Word8Array.array` |  |
| <a name="fld-argument.offset"></a>`offset` | `int` |  |
| <a name="fld-argument.length"></a>`length` | `int` |  |
| <a name="fld-argument.direction"></a>`direction` | `direction` |  |

### <a name="exn-bounds"></a>`Bounds`

```sml
exception Bounds
```

A negative size or range beyond its known object extent.

### <a name="val-allocate"></a>`allocate`

```sml
val allocate : int -> buffer
```

`allocate length` creates retained zeroed storage; its caller releases it.

Native bridge failures propagate.

**Raises** [`Bounds`](#exn-bounds) for a negative size.

### <a name="val-frombytes"></a>`fromBytes`

```sml
val fromBytes : string -> buffer
```

`fromBytes bytes` makes a retained native copy, released by its caller.

### <a name="val-release"></a>`release`

```sml
val release : buffer -> unit
```

`release buffer` releases its registry identity after all views close.

The native bridge rejects stale storage and live dependents.

### <a name="val-length"></a>`length`

```sml
val length : buffer -> int
```

`length buffer` returns its annotated byte extent.

### <a name="val-raw"></a>`raw`

```sml
val raw : buffer -> RuneForeign.resource
```

`raw buffer` returns its opaque pointer identity for raw native calls.

### <a name="val-slice"></a>`slice`

```sml
val slice : buffer * int * int -> buffer
```

`slice (buffer, offset, length)` creates a sharing view retaining its owner.

**Raises** [`Bounds`](#exn-bounds) for an invalid range.

### <a name="val-pointer"></a>`pointer`

```sml
val pointer : {pointer : RuneForeign.resource, length : int} -> buffer
```

`pointer {pointer, length}` bounds an annotated native pointer.

The caller establishes the foreign extent and ownership. Releasing this
view never calls a native deallocator; it retains the pointer identity.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-pointer.pointer"></a>`pointer` | `RuneForeign.resource` |  |
| <a name="fld-pointer.length"></a>`length` | `int` |  |

### <a name="val-read"></a>`read`

```sml
val read : buffer * int * int -> string
```

`read (buffer, offset, length)` copies a checked range to SML.

### <a name="val-write"></a>`write`

```sml
val write : buffer * int * string -> unit
```

`write (buffer, offset, bytes)` updates storage visible through all views.

### <a name="val-terminated"></a>`terminated`

```sml
val terminated : {buffer : buffer, unitBytes : int} -> string
```

`terminated {buffer, unitBytes}` reads through a native NUL code unit.

Unit width is one or two bytes; the terminator must fit in the extent.
Reads stop at the terminator, avoiding a copy beyond the foreign string.

**Raises** [`Bounds`](#exn-bounds) if no complete terminator is present.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-terminated.buffer"></a>`buffer` | `buffer` |  |
| <a name="fld-terminated.unitbytes"></a>`unitBytes` | `int` |  |

### <a name="val-withbytes"></a>`withBytes`

```sml
val withBytes : string -> (buffer -> 'a) -> 'a
```

`withBytes bytes body` scopes one copied native input buffer.

### <a name="val-witharrays"></a>`withArrays`

```sml
val withArrays : argument list -> (buffer list -> 'a) -> 'a
```

`withArrays arguments body` supplies native views in argument order.

Ranges of the same SML array share one backing allocation, preserving
overlap and pointer aliasing. Inputs are snapshots; outputs copy back on
every returning path. Output bytes supersede callback-side SML writes.
Temporary views close first; outputs then copy back before allocations
close.

---

<sub>Generated by runedoc from lib/ffi/runtime/memory\_sig.sml; do not edit.</sub>

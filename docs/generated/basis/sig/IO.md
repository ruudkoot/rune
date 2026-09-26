# signature IO

[The Standard ML Basis Library](../README.md) &rsaquo; Input and output &rsaquo; **IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 6 of 6 entries documented |
| Tests | 32 checks of 6 entries |
| Source | [lib/basis/sig\_io.sml](../../../../lib/basis/sig_io.sml) |

## Synopsis

```sml
signature IO
structure IO : IO
```

| Implementation |  | Source |
| --- | --- | --- |
| [`IO`](../str/IO.md) | IO: the exceptions and the buffering modes shared by the I/O structures. | [lib/basis/io.sml](../../../../lib/basis/io.sml) |

What the whole of the I/O stack shares: the exception it raises and the
ways a stream may hold output back.

Every operation of [`PRIM_IO`](../sig/PRIM_IO.md), [`STREAM_IO`](../sig/STREAM_IO.md), [`IMPERATIVE_IO`](../sig/IMPERATIVE_IO.md), [`TEXT_IO`](../sig/TEXT_IO.md) and
[`BIN_IO`](../sig/BIN_IO.md) reports failure as [`Io`](#exn-io), whatever the reason: a file that cannot
be opened, a reader that fails, an operation on a stream that is closed.
The `cause` says which. What a reader or a writer raises is caught and
becomes the cause, so a program has one exception to handle and can still
see what happened underneath; a failure of the system arrives that way as
[`OS.SysErr`](../sig/OS.md#exn-syserr).

The other four exceptions are the causes that the layers raise themselves.
A reader or a writer need not offer every operation, and when a stream
wants one that is missing it raises [`Io`](#exn-io) with the matching cause:
[`BlockingNotSupported`](#exn-blockingnotsupported) for a read or a write that would have to wait,
[`NonblockingNotSupported`](#exn-nonblockingnotsupported) for one that must not wait,
[`RandomAccessNotSupported`](#exn-randomaccessnotsupported) for a position.

## Interface

<pre>
signature IO =
sig
  exception <a href="#exn-io">Io</a> of {<a href="#fld-io.name">name</a> : string, <a href="#fld-io.function">function</a> : string, <a href="#fld-io.cause">cause</a> : exn}
  exception <a href="#exn-blockingnotsupported">BlockingNotSupported</a>
  exception <a href="#exn-nonblockingnotsupported">NonblockingNotSupported</a>
  exception <a href="#exn-randomaccessnotsupported">RandomAccessNotSupported</a>
  exception <a href="#exn-closedstream">ClosedStream</a>
  datatype <a href="#type-buffer_mode">buffer_mode</a>
    = <a href="#con-no_buf">NO_BUF</a>
    | <a href="#con-line_buf">LINE_BUF</a>
    | <a href="#con-block_buf">BLOCK_BUF</a>
end
</pre>

### <a name="exn-io"></a>`Io`

```sml
exception Io of {name : string, function : string, cause : exn}
```

The exception of every I/O operation, which says where it happened and why.

`name` names the stream, the file or the reader the operation was on;
`function` is the operation that raised; `cause` is the exception behind
it.

> **Reading** `IO.Io/function-is-unqualified`. "The name of the function
> raising the exception" is taken unqualified: `"openIn"`, not
> `"TextIO.openIn"`, as MLton and SML/NJ take it. Poly/ML writes the
> qualified name.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-io.name"></a>`name` | `string` |  |
| <a name="fld-io.function"></a>`function` | `string` |  |
| <a name="fld-io.cause"></a>`cause` | `exn` |  |

<details><summary>Tests (10)</summary>

For `IO`, in [tests/basis/io.sml](../../../../tests/basis/io.sml): `carries-name-function-cause` &middot; `fields-in-any-order` &middot; `cause-is-any-exn` &middot; `cause-may-be-Io` &middot; `empty-strings` &middot; `is-raised` (raises) &middot; `is-not-its-cause` &middot; `value-of-type-exn` &middot; `distinct` &middot; `exnName`

</details>

### <a name="exn-blockingnotsupported"></a>`BlockingNotSupported`

```sml
exception BlockingNotSupported
```

The cause of an [`Io`](#exn-io) when an operation would have to wait and nothing can make it wait.

A reader with neither a blocking read nor `block` cannot serve `input`;
a writer with neither a blocking write nor `block` cannot serve
`output`.

<details><summary>Tests (5)</summary>

For `IO`, in [tests/basis/io.sml](../../../../tests/basis/io.sml): `raise-handle` &middot; `as-cause` &middot; `is-not-ClosedStream` &middot; `distinct` &middot; `exnName`

</details>

### <a name="exn-nonblockingnotsupported"></a>`NonblockingNotSupported`

```sml
exception NonblockingNotSupported
```

The cause of an [`Io`](#exn-io) when an operation must not wait and nothing can promise that.

The reader or the writer has no non-blocking operation, and no
`canInput` or `canOutput` to tell whether the blocking one would
wait.

<details><summary>Tests (5)</summary>

For `IO`, in [tests/basis/io.sml](../../../../tests/basis/io.sml): `raise-handle` &middot; `as-cause` &middot; `is-not-ClosedStream` &middot; `distinct` &middot; `exnName`

</details>

### <a name="exn-randomaccessnotsupported"></a>`RandomAccessNotSupported`

```sml
exception RandomAccessNotSupported
```

The cause of an [`Io`](#exn-io) when a position is asked of a stream whose reader or writer has none.

[`STREAM_IO.filePosIn`](../sig/STREAM_IO.md#val-fileposin), `getPosOut` and `setPosOut` raise it. A regular
file has positions; a pipe, a socket and a terminal have none.

<details><summary>Tests (5)</summary>

For `IO`, in [tests/basis/io.sml](../../../../tests/basis/io.sml): `raise-handle` &middot; `as-cause` &middot; `is-not-ClosedStream` &middot; `distinct` &middot; `exnName`

</details>

### <a name="exn-closedstream"></a>`ClosedStream`

```sml
exception ClosedStream
```

The cause of an [`Io`](#exn-io) when the stream, the reader or the writer is closed or has been given away.

A stream is also unusable once `getReader` or `getWriter` has handed the
reader or the writer over; such a stream is called truncated or
terminated.

<details><summary>Tests (6)</summary>

For `IO`, in [tests/basis/io.sml](../../../../tests/basis/io.sml): `raise-handle` &middot; `as-cause` &middot; `is-not-Io` &middot; `is-not-a-General-exception` &middot; `distinct` &middot; `exnName`

</details>

### <a name="type-buffer_mode"></a>`buffer_mode`

```sml
datatype buffer_mode
  = NO_BUF
  | LINE_BUF
  | BLOCK_BUF
```

How much a stream holds back before it passes what is written to its writer.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-no_buf"></a>`NO_BUF` |  | nothing: every output reaches the writer at once |
| <a name="con-line_buf"></a>`LINE_BUF` |  | a line: what is held goes out when a newline is written |
| <a name="con-block_buf"></a>`BLOCK_BUF` |  | a block: what is held goes out at the writer's chunkSize |

<details><summary>Tests (1)</summary>

For `IO`, in [tests/basis/io.sml](../../../../tests/basis/io.sml): `type`

</details>

## See also

[`PRIM_IO`](../sig/PRIM_IO.md), [`STREAM_IO`](../sig/STREAM_IO.md), [`TEXT_IO`](../sig/TEXT_IO.md), [`BIN_IO`](../sig/BIN_IO.md), [`OS_IO`](../sig/OS_IO.md)

---

<sub>Generated by runedoc from lib/basis/sig\_io.sml; do not edit.</sub>

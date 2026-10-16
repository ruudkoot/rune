# structure OS.IO

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; [Structures](../structures.md) &rsaquo; **OS.IO**

|  |  |
| --- | --- |
| Signature | [`OS_IO`](../sig/OS_IO.md) |
| Status | required |
| Members | 19 |
| Tests | 63 checks |
| Source | [lib/basis/os.sml](../../../../lib/basis/os.sml) |

## Synopsis

```sml
structure OS.IO : OS_IO
```

OS.IO: the descriptors of what the system has opened for the program,
and waiting until they are ready. A descriptor is the system's own file
descriptor, wrapped in a constructor that the signature does not name.

## Members

What each means is on [`OS_IO`](../sig/OS_IO.md); the types are this structure's own.

|  | Member | Is |
| --- | --- | --- |
| type | [`iodesc`](../sig/OS_IO.md#type-iodesc) | `RuneIODesc.iodesc` |
| type | [`iodesc_kind`](../sig/OS_IO.md#type-iodesc_kind) | *a type of its own* |
| type | [`poll_desc`](../sig/OS_IO.md#type-poll_desc) | *a type of its own* |
| type | [`poll_info`](../sig/OS_IO.md#type-poll_info) | *a type of its own* |
| exception | [`Poll`](../sig/OS_IO.md#exn-poll) |  |
| val | [`compare`](../sig/OS_IO.md#val-compare) | `RuneIODesc.iodesc * RuneIODesc.iodesc -> order` |
| val | [`hash`](../sig/OS_IO.md#val-hash) | `RuneIODesc.iodesc -> word` |
| val | [`infoToPollDesc`](../sig/OS_IO.md#val-infotopolldesc) | `poll_info -> poll_desc` |
| val | [`isIn`](../sig/OS_IO.md#val-isin) | `poll_info -> bool` |
| val | [`isOut`](../sig/OS_IO.md#val-isout) | `poll_info -> bool` |
| val | [`isPri`](../sig/OS_IO.md#val-ispri) | `poll_info -> bool` |
| val | [`kind`](../sig/OS_IO.md#val-kind) | `RuneIODesc.iodesc -> iodesc_kind` |
| val | [`poll`](../sig/OS_IO.md#val-poll) | `poll_desc list * Time.time option -> poll_info list` |
| val | [`pollDesc`](../sig/OS_IO.md#val-polldesc) | `RuneIODesc.iodesc -> poll_desc option` |
| val | [`pollIn`](../sig/OS_IO.md#val-pollin) | `poll_desc -> poll_desc` |
| val | [`pollOut`](../sig/OS_IO.md#val-pollout) | `poll_desc -> poll_desc` |
| val | [`pollPri`](../sig/OS_IO.md#val-pollpri) | `poll_desc -> poll_desc` |
| val | [`pollToIODesc`](../sig/OS_IO.md#val-polltoiodesc) | `poll_desc -> RuneIODesc.iodesc` |
| structure | [`Kind`](../str/OS.IO.Kind.md) |  |

## Notes

### Poll

> **Implementation** `OS.IO.Poll/never`. It is never raised: the operating
> system is asked about every event, and answers when [`poll`](../sig/OS_IO.md#val-poll) is called.

### hash

> **Implementation** `OS.IO.hash/descriptor-number`. The hash is the number of
> the descriptor, and two [`iodesc`](../sig/OS_IO.md#type-iodesc) are equal when the numbers are: the
> [`iodesc`](../sig/OS_IO.md#type-iodesc) of the reader under [`TextIO.stdIn`](../sig/TEXT_IO.md#val-stdin) is `Posix.FileSys.fdToIOD Posix.FileSys.stdin`.

### iodesc

> **Implementation** `OS.IO.iodesc/descriptor`. The file descriptor of the
> operating system, a small integer in a datatype of its own.

### kind

> **Reading** `OS.IO.kind/other-kinds`. "A given implementation may define
> other iodesc values": the result need not be one of the seven of [`Kind`](../sig/OS_IO.md#str-kind),
> and the suite allows for that. Here it always is one: what is none of
> the others is a `device`.

> **Implementation** `OS.IO.kind/what-is-looked-at`. The kind is that of the
> open file, so a descriptor that was opened through a symbolic link has
> the kind of what the link names and never `symlink`. A descriptor is a
> `tty` exactly when [`Posix.ProcEnv.isatty`](../sig/POSIX_PROC_ENV.md#val-isatty) says so, which is asked first:
> `/dev/null` is a `device`.

### poll

> **Reading** `OS.IO.poll/closed-SysErr`. The specification gives "one of the
> file descriptors refers to a closed file" as an example of what raises
> [`OS.SysErr`](../sig/OS.md#exn-syserr). The operating system itself reports such a descriptor as
> ready, so every descriptor is looked at before the wait, and a closed one
> raises [`OS.SysErr`](../sig/OS.md#exn-syserr).

### pollDesc

> **Implementation** `OS.IO.pollDesc/always`. Every descriptor can be polled:
> the answer is never `NONE`.

### poll\_desc

> **Implementation** `OS.IO.poll_desc/a-descriptor-and-its-conditions`. A
> [`poll_desc`](../sig/OS_IO.md#type-poll_desc) is the descriptor with the set of conditions asked for, so
> asking twice is asking once, the order of asking does not matter, and one
> that asks for input is not equal to one that asks for output.

<details><summary>Other implementations (4)</summary>

- **Poly/ML 5.9.2** &mdash; the descriptor of TextIO.stdIn and Posix.FileSys.fdToIOD Posix.FileSys.stdin compare EQUAL but are not = (the equality of the eqtype iodesc is that of the object that holds the descriptor)
- **MLton** &mdash; poll of a descriptor that has been closed returns \[\] instead of raising OS.SysErr
- **Poly/ML** &mdash; poll returns the poll\_info values in the reverse order of the argument list ("The returned list respects the order of the argument list")
- **MLKit** &mdash; poll of a descriptor that has been closed returns a poll\_info with no condition instead of raising OS.SysErr: the runtime ignores POLLNVAL

</details>

---

<sub>Generated by runedoc from lib/basis/os.sml; do not edit.</sub>

# signature OS_IO

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **OS_IO**

|  |  |
| --- | --- |
| Status | required |
| Implementations | 1 |
| Documentation | 26 of 26 entries documented |
| Source | [lib/basis/sig\_os\_io.sml](../../../../lib/basis/sig_os_io.sml) |

## Synopsis

```sml
signature OS_IO
structure OS.IO : OS_IO
```

| Implementation |  | Source |
| --- | --- | --- |
| `OS.IO` | A descriptor is the handle of the VM's file table. | [lib/basis/os.sml](../../../../lib/basis/os.sml) |

Descriptors of open files, devices, pipes and sockets, and waiting until
some of them are ready for input or output.

An [`iodesc`](#type-iodesc) stands for something the operating system has opened for the
program. The readers and writers of [`PRIM_IO`](../sig/PRIM_IO.md) give theirs (`ioDesc`), and a
socket gives its own ([`Socket.ioDesc`](../sig/SOCKET.md#val-iodesc)). [`poll`](#val-poll) waits for several descriptors
at once, which is how a program serves more than one connection without
threads. The structure is [`OS.IO`](../sig/OS.md#str-io).

> **Erratum** `OS_IO/kind-on-one-line`. The transcription of this signature in
> the test suite writes the substructure [`Kind`](#str-kind) on one line, for the sake of
> the script that reads it; here it is written out.

## Contents

[Descriptors](#descriptors) &middot;
[Polling](#polling)

## Interface

<pre>
signature OS_IO =
sig

  eqtype <a href="#type-iodesc">iodesc</a>

  val <a href="#val-hash">hash</a> : iodesc -&gt; word

  val <a href="#val-compare">compare</a> : iodesc * iodesc -&gt; order

  eqtype <a href="#type-iodesc_kind">iodesc_kind</a>

  val <a href="#val-kind">kind</a> : iodesc -&gt; iodesc_kind

  structure <a href="#str-kind">Kind</a> :
  sig
    val <a href="#val-kind.file">file</a> : iodesc_kind
    val <a href="#val-kind.dir">dir</a> : iodesc_kind
    val <a href="#val-kind.symlink">symlink</a> : iodesc_kind
    val <a href="#val-kind.tty">tty</a> : iodesc_kind
    val <a href="#val-kind.pipe">pipe</a> : iodesc_kind
    val <a href="#val-kind.socket">socket</a> : iodesc_kind
    val <a href="#val-kind.device">device</a> : iodesc_kind
  end

  eqtype <a href="#type-poll_desc">poll_desc</a>

  type <a href="#type-poll_info">poll_info</a>

  val <a href="#val-polldesc">pollDesc</a> : iodesc -&gt; poll_desc option

  val <a href="#val-polltoiodesc">pollToIODesc</a> : poll_desc -&gt; iodesc

  exception <a href="#exn-poll">Poll</a>

  val <a href="#val-pollin">pollIn</a> : poll_desc -&gt; poll_desc

  val <a href="#val-pollout">pollOut</a> : poll_desc -&gt; poll_desc

  val <a href="#val-pollpri">pollPri</a> : poll_desc -&gt; poll_desc

  val <a href="#val-poll">poll</a> : poll_desc list * Time.time option -&gt; poll_info list

  val <a href="#val-isin">isIn</a> : poll_info -&gt; bool

  val <a href="#val-isout">isOut</a> : poll_info -&gt; bool

  val <a href="#val-ispri">isPri</a> : poll_info -&gt; bool

  val <a href="#val-infotopolldesc">infoToPollDesc</a> : poll_info -&gt; poll_desc
end
</pre>

## Descriptors

### <a name="type-iodesc"></a>`iodesc`

```sml
eqtype iodesc
```

A descriptor of something the operating system has opened. Two
descriptors are equal when they stand for the same open file.

> **Implementation** `OS.IO.iodesc/descriptor`. The file descriptor of the
> operating system, a small integer in a datatype of its own.

### <a name="val-hash"></a>`hash`

```sml
val hash : iodesc -> word
```

`hash d` is a word that is the same for equal descriptors, for use in a
hash table.

### <a name="val-compare"></a>`compare`

```sml
val compare : iodesc * iodesc -> order
```

`compare (d, e)` orders descriptors in some total order, which has no
meaning beyond that.

### <a name="type-iodesc_kind"></a>`iodesc_kind`

```sml
eqtype iodesc_kind
```

What a descriptor is a descriptor of. The known kinds are the values of
[`Kind`](#str-kind).

### <a name="val-kind"></a>`kind`

```sml
val kind : iodesc -> iodesc_kind
```

`kind d` is what `d` is a descriptor of.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the operating system cannot tell, as for a
descriptor that is closed.

> **Reading** `OS.IO.kind/other-kinds`. "A given implementation may define
> other iodesc values": the result need not be one of the seven of [`Kind`](#str-kind).
> An [`iodesc_kind`](#type-iodesc_kind) is a name here, and a descriptor of something else has
> a name that [`Kind`](#str-kind) does not list.

### <a name="str-kind"></a>`Kind`

The kinds of descriptor that every system knows.

#### <a name="val-kind.file"></a>`file`

```sml
val file : iodesc_kind
```

a regular file

#### <a name="val-kind.dir"></a>`dir`

```sml
val dir : iodesc_kind
```

a directory

#### <a name="val-kind.symlink"></a>`symlink`

```sml
val symlink : iodesc_kind
```

a symbolic link

#### <a name="val-kind.tty"></a>`tty`

```sml
val tty : iodesc_kind
```

a terminal

#### <a name="val-kind.pipe"></a>`pipe`

```sml
val pipe : iodesc_kind
```

a pipe

#### <a name="val-kind.socket"></a>`socket`

```sml
val socket : iodesc_kind
```

a socket

#### <a name="val-kind.device"></a>`device`

```sml
val device : iodesc_kind
```

a device

## Polling

### <a name="type-poll_desc"></a>`poll_desc`

```sml
eqtype poll_desc
```

A descriptor together with the events to wait for on it: input, output,
urgent input.

### <a name="type-poll_info"></a>`poll_info`

```sml
type poll_info
```

What [`poll`](#val-poll) found out about one [`poll_desc`](#type-poll_desc): which of the events it asked
about have come.

### <a name="val-polldesc"></a>`pollDesc`

```sml
val pollDesc : iodesc -> poll_desc option
```

`pollDesc d` is a [`poll_desc`](#type-poll_desc) for `d` that asks about no event yet, or
`NONE` if `d` cannot be polled.

> **Implementation** `OS.IO.pollDesc/always`. Every descriptor can be polled:
> the answer is never `NONE`.

### <a name="val-polltoiodesc"></a>`pollToIODesc`

```sml
val pollToIODesc : poll_desc -> iodesc
```

`pollToIODesc pd` is the descriptor that `pd` was made from.

### <a name="exn-poll"></a>`Poll`

```sml
exception Poll
```

Raised by [`pollIn`](#val-pollin), [`pollOut`](#val-pollout) and [`pollPri`](#val-pollpri) for a descriptor that does not
support that kind of event.

> **Implementation** `OS.IO.Poll/never`. It is never raised: the operating
> system is asked about every event, and answers when [`poll`](#val-poll) is called.

### <a name="val-pollin"></a>`pollIn`

```sml
val pollIn : poll_desc -> poll_desc
```

`pollIn pd` is `pd` with input added to the events to wait for: data to
read, or the end of the stream.

**Raises** [`Poll`](#exn-poll) if the descriptor does not support input.

### <a name="val-pollout"></a>`pollOut`

```sml
val pollOut : poll_desc -> poll_desc
```

`pollOut pd` is `pd` with output added to the events to wait for: room to
write without waiting.

**Raises** [`Poll`](#exn-poll) if the descriptor does not support output.

### <a name="val-pollpri"></a>`pollPri`

```sml
val pollPri : poll_desc -> poll_desc
```

`pollPri pd` is `pd` with urgent input added to the events to wait for,
such as the out-of-band data of a socket.

**Raises** [`Poll`](#exn-poll) if the descriptor does not support it.

### <a name="val-poll"></a>`poll`

```sml
val poll : poll_desc list * Time.time option -> poll_info list
```

`poll (pds, timeout)` waits until an event that one of `pds` asks about
has come, and says which have.

The result has a [`poll_info`](#type-poll_info) for each descriptor with an event, in the
order of `pds`; the others are left out, so the result is empty when the
time runs out first. `timeout` is how long to wait at most: `NONE` waits
for as long as it takes, and `SOME Time.zeroTime` does not wait at all.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the operating system refuses the request.

> **Reading** `OS.IO.poll/closed-SysErr`. The specification gives "one of the
> file
> descriptors refers to a closed file" as an example of what raises
> [`OS.SysErr`](../sig/OS.md#exn-syserr). The operating system itself reports such a descriptor as
> ready, so every descriptor is looked at before the wait, and a closed one
> raises [`OS.SysErr`](../sig/OS.md#exn-syserr).

### <a name="val-isin"></a>`isIn`

```sml
val isIn : poll_info -> bool
```

`isIn info` is `true` when the descriptor has input, or is at its end.

### <a name="val-isout"></a>`isOut`

```sml
val isOut : poll_info -> bool
```

`isOut info` is `true` when the descriptor can take output.

### <a name="val-ispri"></a>`isPri`

```sml
val isPri : poll_info -> bool
```

`isPri info` is `true` when the descriptor has urgent input.

### <a name="val-infotopolldesc"></a>`infoToPollDesc`

```sml
val infoToPollDesc : poll_info -> poll_desc
```

`infoToPollDesc info` is the [`poll_desc`](#type-poll_desc) that `info` answers.

## See also

[`OS`](../sig/OS.md), [`PRIM_IO`](../sig/PRIM_IO.md), [`SOCKET`](../sig/SOCKET.md), [`TIME`](../sig/TIME.md)

---

<sub>Generated by runedoc from lib/basis/sig\_os\_io.sml; do not edit.</sub>

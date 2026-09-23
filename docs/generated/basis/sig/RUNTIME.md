# signature RUNTIME

[The Standard ML Basis Library](../README.md) &rsaquo; The runtime &rsaquo; **RUNTIME**

|  |  |
| --- | --- |
| Status | extension |
| Implementations | 1 |
| Documentation | 2 of 2 entries documented |
| Tests | 16 checks of 2 entries |
| Source | [lib/basis/runtime\_sig.sml](../../../../lib/basis/runtime_sig.sml) |

## Synopsis

```sml
signature RUNTIME
structure Runtime : RUNTIME  (* extension *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Runtime` |  | [lib/basis/runtime.sml](../../../../lib/basis/runtime.sml) |

What a program can ask about the machine it is running on: how much work it
has done, and how much memory that took.

The VM keeps these counters whether or not a program asks for them --
`runevm --count` and `runevm --stats` print them when it ends -- so reading
one costs a call and nothing else. None of them allocates, which is what
makes the six numbers of a [`stats`](#val-stats) one consistent set: nothing but an
allocation moves the numbers of the heap, so they cannot drift apart while
they are being read.

This signature is Rune's own. Nothing here is portable, and a program that
only wants the time a computation took should use [`Timer`](../sig/TIMER.md), which is.

> **Deviation** `RUNTIME/not-in-the-specification`. The specification says
> nothing about the implementation a program is running on: it has no
> structure for allocation, for collection, or for what a call costs, and
> deliberately so, since those are where implementations differ most. This
> signature is therefore Rune's alone and a program that uses it does not
> port. What the specification does give is [`Timer`](../sig/TIMER.md), whose `checkGCTime` is
> the one thing it says about a collector.

## Interface

<pre>
signature RUNTIME =
sig
  type <a href="#type-stats">stats</a> = { <a href="#fld-stats.instructions">instructions</a> : int, <a href="#fld-stats.bytes">bytes</a> : int, <a href="#fld-stats.objects">objects</a> : int,
                 <a href="#fld-stats.collections">collections</a> : int, <a href="#fld-stats.live">live</a> : int, <a href="#fld-stats.heapsize">heapSize</a> : int }

  val <a href="#val-stats">stats</a> : unit -&gt; stats
end
</pre>

### <a name="type-stats"></a>`stats`

```sml
type stats = { instructions : int, bytes : int, objects : int,
               collections : int, live : int, heapSize : int }
```

The counters of the VM, all of them since the program started.

`instructions` is the bytecode instructions executed, `bytes` and
`objects` what has been allocated in the heap -- including everything
since collected -- and `collections` the number of collections made.

`live` is the bytes of the current semispace that are in use: what the
last collection kept, plus what has been allocated since. It is an upper
bound on the live data, and is exactly the live data just after a
collection. `heapSize` is the size of one semispace, which grows as the
collector needs it to.

The first four depend on the program and its input alone -- not on the
machine, the pointer width, the heap size or when the collector ran --
so two runs of one program report the same. The last two depend on the
heap size and so on `runevm --heap-size`.

A value is 16 bytes and an object costs an 8-byte header and a payload
rounded up to 16, so the smallest object is 24 bytes and a list cell,
which is two objects, is 64.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-stats.instructions"></a>`instructions` | `int` |  |
| <a name="fld-stats.bytes"></a>`bytes` | `int` |  |
| <a name="fld-stats.objects"></a>`objects` | `int` |  |
| <a name="fld-stats.collections"></a>`collections` | `int` |  |
| <a name="fld-stats.live"></a>`live` | `int` |  |
| <a name="fld-stats.heapsize"></a>`heapSize` | `int` |  |

<details><summary>Tests (8)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `instructions-grow` &middot; `bytes-count-a-list-cell` &middot; `objects-count-a-list-cell` &middot; `bytes-count-the-smallest-object` &middot; `objects-count-the-smallest-object` &middot; `live-is-within-the-semispace` &middot; `bytes-cover-what-is-in-use` &middot; `collections-and-objects-are-not-negative`

</details>

### <a name="val-stats"></a>`stats`

```sml
val stats : unit -> stats
```

`stats ()` is the counters as they stand.

Reading them is itself work, so two calls with nothing between them do
not report the same `instructions`. Nothing between them allocates,
though, so the other five agree.

<details><summary>Tests (8)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `instructions-grow` &middot; `bytes-count-a-list-cell` &middot; `objects-count-a-list-cell` &middot; `bytes-count-the-smallest-object` &middot; `objects-count-the-smallest-object` &middot; `live-is-within-the-semispace` &middot; `bytes-cover-what-is-in-use` &middot; `collections-and-objects-are-not-negative`

</details>

## See also

[`TIMER`](../sig/TIMER.md), [`OS_PROCESS`](../sig/OS_PROCESS.md)

---

<sub>Generated by runedoc from lib/basis/runtime\_sig.sml; do not edit.</sub>

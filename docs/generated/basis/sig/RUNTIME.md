# signature RUNTIME

[The Standard ML Basis Library](../README.md) &rsaquo; The runtime &rsaquo; **RUNTIME**

|  |  |
| --- | --- |
| Status | extension |
| Implementations | 1 |
| Documentation | 9 of 9 entries documented |
| Tests | 38 checks of 8 entries |
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

  val <a href="#val-profile">profile</a> : (unit -&gt; 'a) -&gt; 'a * stats

  val <a href="#val-collect">collect</a> : unit -&gt; unit

  type <a href="#type-frame">frame</a> = { <a href="#fld-frame.function">function</a> : string, <a href="#fld-frame.file">file</a> : string, <a href="#fld-frame.line">line</a> : int, <a href="#fld-frame.column">column</a> : int }

  val <a href="#val-trace">trace</a> : unit -&gt; frame list

  val <a href="#val-printtrace">printTrace</a> : TextIO.outstream -&gt; unit

  val <a href="#val-same">same</a> : 'a * 'a -&gt; bool

  val <a href="#val-version">version</a> : string
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

### <a name="val-profile"></a>`profile`

```sml
val profile : (unit -> 'a) -> 'a * stats
```

`profile f` is what `f ()` returned, and what it cost: the difference
between the counters after it and the counters before.

What measuring costs is part of the answer, so `profile (fn () => ())`
is not zero -- it is that cost, and subtracting it from another answer
removes it. It is the same number on every run and on every VM, since
the counters depend on the program and its input alone.

If `f` raises, the exception passes through and there are no counters:
this measures a call that returns.

**Example** `#objects (#2 (profile (fn () => ()))) = 1`

<details><summary>Tests (7)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `returns-what-the-call-returned` &middot; `reports-what-was-allocated` &middot; `reports-the-objects-allocated` &middot; `costs-the-same-every-time` &middot; `allocates-one-record-of-its-own` &middot; `counts-a-collection` &middot; `an-exception-passes-through` (raises Fail)

</details>

### <a name="val-collect"></a>`collect`

```sml
val collect : unit -> unit
```

`collect ()` collects the heap now.

Every unreachable object is freed and every surviving one moves, which
costs time proportional to the live data and to nothing else: a copying
collector never visits what it does not keep. After it, the `live` of a
[`stats`](#val-stats) is exactly the live data, where otherwise it is an upper bound.

Nothing an SML program can see changes. Equality on a `ref` or an
`array` is the identity the collector maintains, not an address of the
moment, so this says when the cost of collecting is paid and never what
the program means.

<details><summary>Tests (3)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `makes-one-collection` &middot; `drops-what-is-unreachable` &middot; `identity-survives-it`

</details>

### <a name="type-frame"></a>`frame`

```sml
type frame = { function : string, file : string, line : int, column : int }
```

One function on the call stack: its name as the compiler recorded it,
qualified by the structures it is in, and where in the source it has got
to -- the call it is waiting on, or, for the innermost, the expression
being evaluated.

A function the source gives no name is `fn`. Where the program carries
no position for the instruction, `file` is `""` and both numbers are 0.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-frame.function"></a>`function` | `string` |  |
| <a name="fld-frame.file"></a>`file` | `string` |  |
| <a name="fld-frame.line"></a>`line` | `int` |  |
| <a name="fld-frame.column"></a>`column` | `int` |  |

### <a name="val-trace"></a>`trace`

```sml
val trace : unit -> frame list
```

`trace ()` is the frames, innermost first, of the call stack as it
stands, beginning with the function that called [`trace`](#val-trace).

A tail call does not appear. It replaces the frame it is made from --
that is what makes a tail-recursive loop run in constant space -- so the
function it was made from is not on the stack to be reported.

<details><summary>Tests (4)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `names-the-caller` &middot; `leaves-out-its-own-frames` &middot; `a-call-adds-a-frame` &middot; `says-where-in-this-file`

</details>

### <a name="val-printtrace"></a>`printTrace`

```sml
val printTrace : TextIO.outstream -> unit
```

`printTrace out` writes the frames of `trace ()` to `out`, one to a
line, as the VM writes them under an uncaught exception.

<details><summary>Tests (1)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `writes-a-line-for-each-frame`

</details>

### <a name="val-same"></a>`same`

```sml
val same : 'a * 'a -> bool
```

`same (x, y)` is true when `x` and `y` are one object rather than two
equal ones.

It is the identity that `=` uses for a `ref` and an `array`, and it is
available where `=` is not: at a function type, at [`real`](../sig/REAL.md#val-fromint), and at any
type that admits no equality. A collection does not change an answer.

What it says of anything else is not specified, and a program should not
ask. A value that is not in the heap at all -- an `int`, a `word`, a
`char`, `unit`, a constructor with no argument -- has no identity, and
the comparison is of the values themselves, so `same (1, 1)` is true and
`same (0.0, ~0.0)` is false because the two are different reals. Of the
rest, whether two equal values are one object is whatever the compiler
shared: two equal string constants are one, and two lists written
separately are two.

**Example** `let val r = ref 0 in same (r, r) end = true`

<details><summary>Tests (6)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `a-ref-is-itself` &middot; `two-equal-refs-are-two` &middot; `agrees-with-equality-on-refs` &middot; `an-array-is-itself` &middot; `compares-what-is-not-in-the-heap` &middot; `works-where-equality-does-not`

</details>

### <a name="val-version"></a>`version`

```sml
val version : string
```

The version of Rune that this program is running on, as
`runevm --version` prints it.

The compiler and the VM are built from one string, so `rune --version`
says the same. It is not the version of the bytecode, which the VM
checks when it loads a program and which changes only when the file
format does.

<details><summary>Tests (1)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `is-numbers-separated-by-dots`

</details>

## See also

[`TIMER`](../sig/TIMER.md), [`OS_PROCESS`](../sig/OS_PROCESS.md)

---

<sub>Generated by runedoc from lib/basis/runtime\_sig.sml; do not edit.</sub>

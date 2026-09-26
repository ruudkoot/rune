# signature RUNTIME

[The Standard ML Basis Library](../README.md) &rsaquo; The runtime &rsaquo; **RUNTIME**

|  |  |
| --- | --- |
| Status | extension |
| Implementations | 1 |
| Documentation | 12 of 12 entries documented |
| Tests | 43 checks of 10 entries |
| Source | [lib/basis/runtime\_sig.sml](../../../../lib/basis/runtime_sig.sml) |

## Synopsis

```sml
signature RUNTIME
structure Runtime : RUNTIME  (* extension *)
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Runtime`](../str/Runtime.md) |  | [lib/basis/runtime.sml](../../../../lib/basis/runtime.sml) |

What a program can ask about the machine it is running on: how much work it
has done, and how much memory that took.

The VM keeps these counters whether or not a program asks for them --
`runevm --count` and `runevm --stats` print them when it ends -- so reading
one costs a call and nothing else. None of them allocates, which is what
makes the six numbers of a [`stats`](#val-stats) one consistent set: nothing but an
allocation moves the numbers of the heap, so they cannot drift apart while
they are being read.

This signature is Rune's own. Nothing here is portable, and a program that
only wants the time a computation took should use [`Timer`](../str/Timer.md), which is.

> **Deviation** `RUNTIME/not-in-the-specification`. The specification says
> nothing about the implementation a program is running on: it has no
> structure for allocation, for collection, or for what a call costs, and
> deliberately so, since those are where implementations differ most. This
> signature is therefore Rune's alone and a program that uses it does not
> port. What the specification does give is [`Timer`](../str/Timer.md), whose `checkGCTime` is
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
  datatype <a href="#type-world">world</a> = <a href="#con-saved">Saved</a> | <a href="#con-restored">Restored</a>
  val <a href="#val-save">save</a> : string -&gt; world
  val <a href="#val-restore">restore</a> : string -&gt; 'a
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
one object of two fields, is 40.

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
is not all zero -- it is that cost, the instructions that read the
counters and at most one record, and subtracting it from another answer
removes it. It is the same number on every run and on every VM, since
the counters depend on the program and its input alone.

If `f` raises, the exception passes through and there are no counters:
this measures a call that returns.

**Example** `#objects (#2 (profile (fn () => ()))) <= 1`

<details><summary>Tests (7)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `returns-what-the-call-returned` &middot; `reports-what-was-allocated` &middot; `reports-the-objects-allocated` &middot; `costs-the-same-every-time` &middot; `allocates-at-most-one-record-of-its-own` &middot; `counts-a-collection` &middot; `an-exception-passes-through` (raises Fail)

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

One function on the call stack, and where in the source it has got to.

`function` is the name the compiler recorded, qualified by the structures
it is in; a function the source gives no name is `fn`. The position is
the call the function is waiting on, or, for the innermost frame, the
expression being evaluated. Where the program carries no position for
that instruction, `file` is `""` and both numbers are 0.

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

### <a name="type-world"></a>`world`

```sml
datatype world = Saved | Restored
```

Which of the two worlds a [`save`](#val-save) came back in: the one that wrote the
image, or the one that was started from it.

| Constructor | Argument | Description |
| --- | --- | --- |
| <a name="con-saved"></a>`Saved` |  |  |
| <a name="con-restored"></a>`Restored` |  |  |

### <a name="val-save"></a>`save`

```sml
val save : string -> world
```

`save file` writes the whole running program to `file` and is [`Saved`](#con-saved).

A VM started as `runevm --restore file` carries on from inside that same
call, where it is [`Restored`](#con-restored): one call and two worlds, as
[`Posix.Process.fork`](../sig/POSIX_PROCESS.md#val-fork) gives a pid to one process and 0 to another. The
file is not used up by being restored.

What is written is everything the program is made of -- the heap, the
stacks, the counters, and the files it has open, which are opened again
by name and put back where they were left. What belongs to the process
rather than to the program is not: a socket, a directory stream and a
pipe are the system's, and a restored world does not have them.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the image cannot be written.

<details><summary>Tests (2)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `writes-a-file-and-says-Saved` &middot; `a-file-it-cannot-write` (raises)

</details>

### <a name="val-restore"></a>`restore`

```sml
val restore : string -> 'a
```

`restore file` becomes the world that [`save`](#val-save) wrote to `file`. It does
not come back.

Where [`save`](#val-save) gives two worlds one call, this gives one world another
call: the program carries on from inside the [`save`](#val-save) that wrote the
image, where it is [`Restored`](#con-restored). `runevm --restore file` does the same to
a VM that has just started; this does it to one that is running.

The image carries its own bytecode, so the program that runs afterwards
may be another program entirely -- it is a whole world, not a heap
dropped into this one. Nothing of the world that called [`restore`](#val-restore)
survives it: not its code, not its stack, not the files it had open.
Nothing written after the call is reached.

> **Implementation** `RUNTIME.restore/reads-before-it-replaces`. The image is
> read into a world of its own and moved over only once it is whole, so a
> file that is not an image, or is cut short, leaves the calling world
> running and able to handle the exception. That is what makes the type
> honest: [`restore`](#val-restore) either does not return or raises. The world it leaves
> behind is let go at that moment -- its files closed, its heap and its
> program freed -- so a program may restore as often as it likes without
> growing.

**Raises** [`OS.SysErr`](../sig/OS.md#exn-syserr) if the image cannot be read.

<details><summary>Tests (3)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `a-file-that-is-not-an-image` (raises) &middot; `a-file-that-is-not-there` (raises) &middot; `leaves-this-world-running`

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

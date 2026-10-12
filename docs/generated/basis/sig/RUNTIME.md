# signature RUNTIME

[The Standard ML Basis Library](../README.md) &rsaquo; The runtime &rsaquo; **RUNTIME**

|  |  |
| --- | --- |
| Status | extension |
| Implementations | 1 |
| Documentation | 19 of 19 entries documented |
| Tests | 50 checks of 16 entries |
| Source | [lib/basis/runtime\_sig.sml](../../../../lib/basis/runtime_sig.sml) |

## Synopsis

```sml
signature RUNTIME
structure Runtime : RUNTIME  (* extension *)
```

| Implementation |  | Source |
| --- | --- | --- |
| [`Runtime`](../str/Runtime.md) | Runtime: the VM's view of the running program -- its counters, its call stack, the identity of objects, saving and restoring the whole of it, units appended to it, and the user's interrupt. It is Rune's own and not of the specification. | [lib/basis/runtime.sml](../../../../lib/basis/runtime.sml) |

What a program can ask about the machine it is running on: how much work it
has done, and how much memory that took.

The VM keeps these counters whether or not a program asks for them --
`runevm --count` and `runevm --stats` print them when it ends -- so reading
one costs a call and nothing else. None of them allocates, which is what
makes the nine numbers of a [`stats`](#val-stats) one consistent set: nothing but an
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
                 <a href="#fld-stats.collections">collections</a> : int, <a href="#fld-stats.live">live</a> : int, <a href="#fld-stats.heapsize">heapSize</a> : int,
                 <a href="#fld-stats.minorcollections">minorCollections</a> : int, <a href="#fld-stats.majorcollections">majorCollections</a> : int, <a href="#fld-stats.promoted">promoted</a> : int }
  val <a href="#val-stats">stats</a> : unit -&gt; stats
  val <a href="#val-profile">profile</a> : (unit -&gt; 'a) -&gt; 'a * stats
  val <a href="#val-collect">collect</a> : unit -&gt; unit
  val <a href="#val-share">share</a> : unit -&gt; int
  type <a href="#type-frame">frame</a> = { <a href="#fld-frame.function">function</a> : string, <a href="#fld-frame.file">file</a> : string, <a href="#fld-frame.line">line</a> : int, <a href="#fld-frame.column">column</a> : int }
  val <a href="#val-trace">trace</a> : unit -&gt; frame list
  val <a href="#val-printtrace">printTrace</a> : TextIO.outstream -&gt; unit
  val <a href="#val-same">same</a> : 'a * 'a -&gt; bool
  datatype <a href="#type-world">world</a> = <a href="#con-saved">Saved</a> | <a href="#con-restored">Restored</a>
  val <a href="#val-save">save</a> : string -&gt; world
  val <a href="#val-restore">restore</a> : string -&gt; 'a
  val <a href="#val-link">link</a> : Word8Vector.vector -&gt; unit -&gt; unit
  val <a href="#val-load">load</a> : string -&gt; unit -&gt; unit
  val <a href="#val-catchinterrupt">catchInterrupt</a> : unit -&gt; bool
  val <a href="#val-maskinterrupt">maskInterrupt</a> : bool -&gt; bool
  val <a href="#val-version">version</a> : string
  val <a href="#val-clock">clock</a> : unit -&gt; Time.time
  val <a href="#val-processors">processors</a> : unit -&gt; int
end
</pre>

### <a name="type-stats"></a>`stats`

```sml
type stats = { instructions : int, bytes : int, objects : int,
               collections : int, live : int, heapSize : int,
               minorCollections : int, majorCollections : int, promoted : int }
```

The counters of the VM, all of them since the program started.

`instructions` is the bytecode instructions executed, `bytes` and
`objects` what has been allocated in the heap -- including everything
since collected -- and `collections` the number of collections made:
`minorCollections` of them minor ones, which copy what of the nursery
is reached into the old space, `promoted` the bytes they copied, and
`majorCollections` of the whole heap -- full collections, and the
cycles of incremental marking of `runevm --gc low-pause`.

`live` is the bytes of objects in the heap: what the last collection
kept -- a minor one keeps every old object, dead or not -- plus what has
been allocated since. It is an upper bound on the live data, and is
exactly the live data just after a full collection, which [`collect`](#val-collect)
makes.
`heapSize` is the heap's size, the bytes of objects it holds before it
is collected, which grows as the collector needs it to.

The first three depend on the program and its input alone -- not on the
machine, the pointer width, the heap's size or when the collector ran --
so two runs of one program report the same. The other six depend on
the heap's size too, and so on `runevm --heap-size`, `--heap-fill`,
`--nursery` and `--gc`: two runs with the same options make the same
collections. None is a time: the collector's time is [`Timer`](../str/Timer.md)'s
(`checkGCTime`) and `runevm --stats`'. `bytes` and
`live` leave out the boxes the representation makes for a real that
has no immediate, as `--count` does.

A value is 8 bytes and an object costs an 8-byte header and a payload
of 8-byte fields, so the smallest object is 16 bytes and a list cell,
one object of two fields, is 24.

| Field | Type | Description |
| --- | --- | --- |
| <a name="fld-stats.instructions"></a>`instructions` | `int` |  |
| <a name="fld-stats.bytes"></a>`bytes` | `int` |  |
| <a name="fld-stats.objects"></a>`objects` | `int` |  |
| <a name="fld-stats.collections"></a>`collections` | `int` |  |
| <a name="fld-stats.live"></a>`live` | `int` |  |
| <a name="fld-stats.heapsize"></a>`heapSize` | `int` |  |
| <a name="fld-stats.minorcollections"></a>`minorCollections` | `int` |  |
| <a name="fld-stats.majorcollections"></a>`majorCollections` | `int` |  |
| <a name="fld-stats.promoted"></a>`promoted` | `int` |  |

### <a name="val-stats"></a>`stats`

```sml
val stats : unit -> stats
```

`stats ()` is the counters as they stand.

Reading them is itself work, so two calls with nothing between them do
not report the same `instructions`. Nothing between them allocates,
though, so the other five agree.

**Example** `#live (stats ()) <= #heapSize (stats ()) = true`

<details><summary>Tests (12)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `instructions-grow` &middot; `bytes-count-a-list-cell` &middot; `objects-count-a-list-cell` &middot; `bytes-count-the-smallest-object` &middot; `objects-count-the-smallest-object` &middot; `bytes-count-an-array-of-bytes` &middot; `bytes-count-an-array-of-reals` &middot; `live-is-within-the-semispace` &middot; `bytes-cover-what-is-in-use` &middot; `collections-and-objects-are-not-negative` &middot; `collections-are-minor-or-major` &middot; `collect-is-a-major-collection`

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

`collect ()` collects the heap now: a full collection.

Every unreachable object is freed. Under the collectors `runevm --gc`
chooses, what lives is marked where it lies -- the throughput
collector, the default, moves the objects of its sparsest blocks, and
the low-pause collector moves nothing -- which costs time proportional
to the live data and a little for every block of the heap; the copier
of `runevm --nursery 0` moves every surviving object but a large one,
which costs time proportional to the live data and to nothing else.
After it, the `live` of a [`stats`](#val-stats) is exactly the live data, where
otherwise it is an upper bound.

Nothing an SML program can see changes. Equality on a `ref` or an
`array` is the identity the collector maintains, not an address of the
moment, so this says when the cost of collecting is paid and never what
the program means.

**Example** `(collect (); #collections (stats ()) >= 1) = true`

<details><summary>Tests (3)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `makes-one-collection` &middot; `drops-what-is-unreachable` &middot; `identity-survives-it`

</details>

### <a name="val-share"></a>`share`

```sml
val share : unit -> int
```

`share ()` makes the equal immutable values of the heap one object
each, and is the bytes it freed.

It is what Poly/ML's PolyML.shareCommonData does before a heap is
saved.

Equal is as `=` has it, at any type: tuples, records, vectors and
values of a datatype whose fields are equal, strings of the same
characters, reals of the same bits, exception values of the same
constructor and argument. A `ref`, an `array`, a function and an
exception constructor keep their identity. A program that builds the
same values again and again --
terms, types, environments -- keeps one of each, the more so in an
image [`save`](#val-save) writes after it.

It collects first and after, and it needs memory of its own about the
number of objects times 24 bytes; where it cannot have it, it shares
nothing and is 0. Nothing an SML program can see changes but [`same`](#val-same),
which may now say of two equal values that they are one.

**Example** `share () >= 0 = true`

<details><summary>Tests (3)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `equal-values-become-one` &middot; `a-ref-keeps-its-identity` &middot; `while-a-vector-is-made`

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

**Example** `null (trace ()) = false`

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
separately are two, until [`share`](#val-share) makes them one.

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

What is written is everything the program is made of -- the heap,
collected first ([`collect`](#val-collect)) so that it is the live data and no more,
the stacks, the counters, and the files it has open, which are opened again
by name and put back where they were left. What belongs to the process
rather than to the program is not: a socket, a directory stream and a
pipe are the system's, and a restored world does not have them. Nor is
what the program read ahead of its standard input and has not taken:
[`TextIO.stdIn`](../sig/TEXT_IO.md#val-stdin) in the restored world reads that world's standard input
from where it begins.

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

### <a name="val-link"></a>`link`

```sml
val link : Word8Vector.vector -> unit -> unit
```

`link bytes` appends to the running program the unit that `bytes` is
the file of, and is the function that runs the unit's top-level
declarations.

A unit is a file of a program compiled a file at a time
(`rune --units --emit-units DIR`, docs/units.md): its code, and what it
names of the units compiled before it. Those must have been linked
first; what the unit names is found among what they declared, and its
code is checked as the VM checks a program's file. Nothing runs until
the function is called, and calling it again runs the declarations
again. A unit linked twice is two units, each with globals of its own;
the units linked after it see the second.

> **Implementation** `RUNTIME.link/the-last-unit-returns`. The top level of
> a unit compiled with others ends by calling the next one's; linked
> here, it returns to the caller instead.

**Raises** [`Fail`](../sig/GENERAL.md#exn-fail) if `bytes` is not a unit's file, is of another
instruction set, or names what no unit linked before it declared;
the message says which.

<details><summary>Tests (1)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `bytes-that-are-no-unit` (raises)

</details>

### <a name="val-load"></a>`load`

```sml
val load : string -> unit -> unit
```

`load file` is [`link`](#val-link) of what `file` holds.

**Raises** [`IO.Io`](../sig/IO.md#exn-io) if the file cannot be read, and [`Fail`](../sig/GENERAL.md#exn-fail) as [`link`](#val-link)
does.

<details><summary>Tests (1)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `a-file-that-is-not-there` (raises)

</details>

### <a name="val-catchinterrupt"></a>`catchInterrupt`

```sml
val catchInterrupt : unit -> bool
```

`catchInterrupt ()` makes Ctrl-C, the user's interrupt, raise
[`SML90.Interrupt`](../sig/SML90.md#exn-interrupt) in the program from now on rather than end it.

It is true; it is false where the system has no interrupt to catch,
and the program goes on as before. The exception is raised where the
program next jumps back, as a loop does, or calls a function, or in a
read from a terminal that the interrupt cuts short, as a `raise` there
would raise it: the handlers, the frames and [`trace`](#val-trace) are what they
would be. A primitive that is running finishes first. The interrupt is
caught even where the program was started with it ignored, as a shell
starts one in the background, and a world started from an image that
[`save`](#val-save) wrote catches it as the program that saved it did.

> **Implementation** `RUNTIME.catchInterrupt/polled`. The VM looks at the
> interrupt at a jump back and at a call, in the interpreters and in the
> code the JIT makes; the code of `runeopt` does not, and an interrupt
> never comes to it.

<details><summary>Tests (1)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `caught-where-the-system-has-one`

</details>

### <a name="val-maskinterrupt"></a>`maskInterrupt`

```sml
val maskInterrupt : bool -> bool
```

`maskInterrupt b` says whether an interrupt waits rather than being
raised, and is what it said before.

From `maskInterrupt true` on, one waits until `maskInterrupt false`,
which raises it, if one came, as it returns. A section that an
interrupt must not cut in two is

```sml
let val was = maskInterrupt true
in (f () before ignore (maskInterrupt was))
   handle e => (ignore (maskInterrupt was); raise e)
end
```

The mask is off when a program starts, and a world started from an
image has the mask its program had.

**Raises** [`SML90.Interrupt`](../sig/SML90.md#exn-interrupt), from `maskInterrupt false`, where one
waited.

**Example** `maskInterrupt (maskInterrupt true) = true`

<details><summary>Tests (2)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `gives-back-what-it-was` &middot; `with-nothing-waiting-raises-nothing`

</details>

### <a name="val-version"></a>`version`

```sml
val version : string
```

The version of Rune that this program is running on, as
`runevm --version` prints it.

It is the name of the git tag of the commit Rune was built from, or
else that commit's abbreviated hash, with `-dirty` after it when the
tree had changes that were not committed.

The compiler and the VM are built from one string, so `rune --version`
says the same. It is not the version of the bytecode, which the VM
checks when it loads a program and which changes only when the file
format does.

**Example** `size version > 0 = true`

<details><summary>Tests (1)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `is-a-word`

</details>

### <a name="val-clock"></a>`clock`

```sml
val clock : unit -> Time.time
```

`clock ()` is the time on a clock that never goes back, from a start
the system chooses.

[`Time.now`](../sig/TIME.md#val-now) is the time of day, which the system may set back or
forward; the difference of two [`clock`](#val-clock)s is time that passed. Its
resolution is the microsecond of a [`Time.time`](../sig/TIME.md#type-time). A runner of tests times
its children by it (docs/plans/unit-testing.md, G1).

**Example** `Time.<= (clock (), clock ()) = true`

<details><summary>Tests (2)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `never-goes-back` &middot; `goes-on`

</details>

### <a name="val-processors"></a>`processors`

```sml
val processors : unit -> int
```

`processors ()` is the number of processors this program may run on,
at least 1.

On Linux it counts the processors of the program's affinity mask, as
`nproc` does, and elsewhere the system's.

**Example** `processors () >= 1 = true`

<details><summary>Tests (1)</summary>

For `Runtime`, in [tests/basis/runtime.sml](../../../../tests/basis/runtime.sml): `at-least-one`

</details>

## See also

[`TIMER`](../sig/TIMER.md), [`OS_PROCESS`](../sig/OS_PROCESS.md)

---

<sub>Generated by runedoc from lib/basis/runtime\_sig.sml; do not edit.</sub>

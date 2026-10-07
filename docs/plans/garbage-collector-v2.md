# Roadmap: the second-generation collector

Every Rune program today is collected by one Cheney copier: two
semispaces, every live object copied at every collection, the whole
program stopped while it runs. The heap-layout roadmap (merged as PR #33,
`ca87fa07`) put that copier on the tagged 8-byte word and left the
hooks for what comes after it: four bits of the header, the barrier as
one operation, young objects told by address, the allocation state as
the thread's, roots by what is live. This roadmap plans what comes
after it: the collector Rune runs on one thread, on every width, until
the third generation brings threads -- and the collector the 32-bit
targets keep for good. It covers the nursery, the old space and how it
fights fragmentation, large objects, the barrier and the remembered
set, short pauses, the cache, memory on machines that have little of it,
and what the compiler and the bytecode can do to help; the decisions
with their evidence; and the milestones that build it behind an
interface, with a gate where two old spaces are prototyped at full
scale before one is chosen. It was written on 2026-10-05 against
`ca87fa07`, on branch `gc2`, and amended on 2026-10-06 after the owner
asked whether the nursery and the chunks should be 2 MiB and large
objects start at 4 KiB, the sizes of a huge page and of a page (D2, D5,
D10, D11).

What it rests on:
* a reading of the runtime as the heap-layout roadmap left it
  (`runtime/heap.c`, `vm.h`, `value.h`, `image.c`, `prims.c`, both
  loops, the JIT's macro-assembler and emitters, `runeopt`'s templates)
  and of every plan that puts a demand on the collector (*Where we
  are*, *Prerequisites and flags*);
* the experiments made for it (*The experiments*): the census VM
  ported to the word layout and extended, and new traces of the
  bootstrap and of the other workloads; the simulator extended with an
  exact nursery, an address model and eight old spaces, incremental
  marking, a time model and memory over time; a C harness that measured
  on the reference machine what each unit of collector work and each
  barrier costs and what the cache does to a nursery; a prototype of a
  nursery in front of today's copier, in the real VM, that the
  simulator was checked against and the pause model fitted to; and
  today's copier measured as the baseline, on 32-bit as well. Every
  number below names the script that made it (*Measuring*);
* the source of the collectors under `/home/ruud/reference` (*What the
  implementations do*) and the literature (*What the literature says*,
  *References*). Below, `performance.md` alone means
  [plans/performance.md](performance.md), the plan; `heap-layout.md` is
  [plans/heap-layout.md](heap-layout.md) and `collector.md` the brief
  [plans/collector.md](collector.md) that roadmap's M7 left.

## Status

| Milestone | What | State |
|---|---|---|
| M0 | This roadmap | done |
| M1 | Measure in the tree | done 2026-10-07: `--gc-log` and `RUNE_MEMSTAT` in the copier (`01bba940`); `tests/gcbench` and `check-gcbench` (`bb1b1152`); the latency workloads, `tools/mmu.py`, `scripts/gc-eval.sh` with the evaluation set, and the 32-bit probe (`4d88489a`); the census VM on the word layout and the simulators on its traces, `test-census`, the validation of `check-heapsim` and `check-gcsim` in `make check` (`5dad8248`). The traces of the bootstrap and of compile-sigs made in the tree pass `checktrace` and the validation against `runevm --stats`; `gc-eval.sh` gives the copier against itself T 1.01, M 1.00, P 0.99 and its bootstrap as *Where we are* has it. The harness's H5 numbers below were made with a nursery 8 times too small and are to be measured again (`tests/gcbench/README.md`) |
| M2 | The collector behind an interface | done 2026-10-07: the barrier with the object, the field and the value in every engine, `runeopt`'s `:=` and `Array.update` included, through `ms_set_field` and its template (`4cc8ae69`); `--gc-verify` and `make test-heap` in `make check` (`8fb0fc18`, `1065a541`); the heap of 2 MiB chunks over `sys_mem_reserve`, images and `heap_relocate` over them, the copier, the log and the check in `runtime/gc/` (`04cd4345`); the corrections of *Where the documents are wrong*. Output, `--count` and every collection as before on all 271 programs of `tests/lang` on both VMs, and every portability VM and image direction; the evaluation set T 1.011, M 0.841, P 1.030 against the copier of `1065a541`, the short programs' worst T within the noise on five rounds. The old-space interface's operations come with their first users: promotion with M3's nursery, marking and sweeping with M4's old spaces |
| M3 | The nursery, its remembered set, the watermark, large objects | done 2026-10-07, its targets not met: the barrier with the VM, the field and the value in every engine (`233a8e6b`); the nursery of 1 MiB (`--nursery N`; 0 the copier as before) with promotion at the first survival, the cards and dirty bytes in the chunks' tables with a crossing map, the large-object space from 8 KiB with the large objects made since the last minor collection scanned whole, and `--gc-verify` of the remembered set (`d34ff907`); the watermark and the liveness by a hash of the return pc (`bdf2ed77`) -- the watermark an index of the lowest frame that ran since the last minor collection, which every pop lowers, rather than D9's bit in each frame record: the same frames scanned, a comparison a return, `Frame` unchanged; and what the evaluation found: a dirty card of a large array scanned from its first field, each minor collection logged as its own, the collector's calls per object made inline (`b1c9a930`). Correct: the whole chain, `--gc-verify` at 4 KiB, 64 KiB and 1 MiB on both interpreters, the JIT at both tiers and `runeopt`'s code, and `--nursery 0` as M2 in output, `--count` and every collection on all 271 programs of both VMs. Against M2's copier (`results/m3-eval.md`): T 1.011, M 0.685, P 1.010; the bootstrap 0.833 of the task-clock (target 0.85) and 0.648 of the peak (target 0.5), its 99th-percentile pause 1.1 ms against 67; `merge` 2.05 (target 1.0); Rune compiling MLton 1.33 (target 1.0). What misses is promotion at the first survival into a copying old space: where a program's short-lived data is as large as the nursery most of it is promoted, and the full collections copy it again (DLXSimulator promotes 81% of each nursery, Rune compiling MLton 52%). No nursery from 128 KiB to 16 MiB meets the targets (the sweep there: 16 MiB mends `merge` and DLXSimulator at M 0.94 and P 1.63); the gate decides D2 -- the size, and promotion at the second survival -- and D3, an old space that is marked, on M4's prototypes |
| M4 | Two old spaces at full scale; the gate | |
| M5 | The chosen old space, complete | |
| M6 | Short pauses | |
| M7 | The cache, and the compiler's help | |
| M8 | What the second generation leaves | |

The owner took every recommendation on 2026-10-06 (*Decisions*); D2 to
D5, D7 and D8 provisionally, to be decided again at the gate of M4 on the
prototypes' numbers, as heap-layout's D1 to D5 were. The milestones
after the gate are planned again with those numbers.

## The request

The owner's brief, as written:

> - this is a draft roadmap for v2 of the garbage collector
> - please research the literature and exisiting implementations
>   - implemenations can be found under /home/ruud/reference
>   - let me know if you need further access to literature and implementation and i can provide them locally
> - choices should be supported by emperical evidence: simulations, prototypes and benchmarks
> - the second generation collectors will not support multithreading as the runtime does not support this yet. this will be part of the third generations collector so do bear it in mind
>   - so no parallel collection
>   - concurrent collection on a single thread may be considered as may partial and incremental collection
> - features to be considered for the second generation collector:
>   - generational collection (e.g. nursery, large object space)
>   - mark-and-sweep/compact for memory efficiency
>   - prevention of heap fragmentation
>   - good interaction with the cache hierarchy
>   - short/no pausing so rune has good real-time behaviour
> - 32-bit targets will likely remain on the second generation collector and not move to the third generation collector. so this collector is prefered to be memory efficient (both phyisical and virtual memory as both are limited on 32-bit targets). tricks that can be done with a 64-bit address space will have to be deferred to the third generation collector.
> - rune is a research compiler and you are allowed to make changes to the bytecode, compiler analyses and optimization, and heap layout if this is beneficial for the v2 collector. backwards compatibiblity and implementation effort are not a concern.
> - take your notes into considerations:
>   - /home/ruud/rune/docs/plans/collector.md
>   - /home/ruud/rune/docs/plans/heap-layout.md
>   - /home/ruud/rune/docs/plans/performance.md

Three of the owner's notes frame it. `garbage-collector-v3.md`, the
brief of the generation after this one, lists what that one is to have:
"generational", "nursery", "large object space", "bibop", "concurrent",
"cpu and numa topology aware", "reserved header bits", with OCaml 5's "2
colour bits, per-domain minor heaps, a deletion barrier" as the
example. `~/notes/virtual-machine.md` sets the end state: "very
high-core count NUMA machines", "no global locks and avoiding cache line
bouncing and a concurrent no-pause garbage collector", "millions of green
threads", "an in-VM isolated process framework", an FFI "missing in
current Rune but it will be there", escape analysis "to predict memory
allocation (size, shape etc.) ... and exploit that in the VM & GC", and
"a number of increasingly complex JIT compilers and garbage collectors
as we go along the roadmap. We may need to evaluate several variant
emperically before decing on one or more strategies." And `collector.md`,
the brief heap-layout's M7 wrote for this roadmap on 2026-10-04, asks
ten questions of it, which the table below answers beside the brief's
own lines.

The owner's answers when this roadmap was asked for (2026-10-05): it is
written in the worktree `.worktrees/gc2` on a new branch `gc2` from
master `ca87fa07`; the evidence made while writing it is the simulator
extended, a C harness and one prototype in a scratch copy, a nursery in
front of today's copier, with full prototypes of the old spaces left
to a gate inside the roadmap; it is committed as `gc2 M0`.

| The brief asks | Answered in |
|---|---|
| a roadmap for the second-generation collector | this file; *The milestones* |
| research the literature and the implementations under `/home/ruud/reference` | *What the literature says*, *What the implementations do*, *References* |
| further literature on request | *References* lists what was read in full and what only in abstract |
| choices supported by simulations, prototypes and benchmarks | *The experiments*; every decision names its evidence; M4's gate |
| no multithreading now; the third generation brings it; bear it in mind | *Constraints*, D16 |
| no parallel collection | *Constraints* |
| concurrent on one thread, partial and incremental collection may be considered | D7, *The candidate collectors*, M6 |
| generational collection: a nursery, a large-object space | D2, D5, M3 |
| mark-and-sweep or compact, for memory | D3, D4, *The candidate collectors*, M4 |
| no fragmentation of the heap | D4, *The experiments* (fragmentation) |
| good interaction with the cache hierarchy | D11, *The experiments* (the harness), M7 |
| short or no pauses, for real-time behaviour | D1, D7, D9, M6 |
| 32-bit targets stay on this collector: memory-efficient, physical and virtual | D10, D13, *The experiments* (32-bit), *Constraints* |
| no tricks that need a 64-bit address space | *Constraints*, D10, D16 |
| the bytecode, the compiler's analyses and the heap layout may change | D8, D15, M7 |
| backwards compatibility and effort are not a concern | *The milestones*: each says what it breaks (images, budgets) |
| `collector.md` | its ten questions below; *Where we are* |
| `heap-layout.md` | *Where we are*; D6 to D10 of that roadmap carried in D5, D10, D14, D16, D17, *A lazy front end* in D18 |
| `performance.md` | item 13 and the sections of 2026-10-05 in *Where we are* and D1 |
| *collector.md* 1: is it worth building for the programs Rune has, and for what | D1, *The experiments* |
| *collector.md* 2: the nursery's size, against the cache and survival | D2, D11 |
| *collector.md* 3: promotion at the first survival or the second | D2 |
| *collector.md* 4: the old space: copied, marked in place, or Immix's blocks | D3, D4, M4 |
| *collector.md* 5: the barrier's body; whether `SETENV` needs one | D6 |
| *collector.md* 6: growth and memory; what the heap flags and an image mean | D10 |
| *collector.md* 7: pauses: what is promised, measured how | D1, D7, D12 |
| *collector.md* 8: determinism and `--count` | D12 |
| *collector.md* 9: threads: a nursery per thread, the shared old space | D16 |
| *collector.md* 10: a lazy front end | D18 |

## Where we are

### The collector today

One collector serves every engine -- the stack VM, the register VM's
loop, both tiers of the JIT and `runeopt`'s native code -- since they
all link the same runtime (`runtime/heap.c`, `vm.h`, `value.h`). It is
the Cheney copier the first runtime had (`c8880bc3`, 2026-09-17),
precise, moving, stop-the-world, collecting only when an allocation does
not fit (`docs/runtime.md`, *The garbage collector*):

* **Two semispaces, kept.** `collect_into` (`runtime/heap.c:257-301`)
  copies the roots, then scans what it copied, following every field of
  an object that has fields (`obj_scanned_fields`: an indirection's first
  alone). `copy_obj` (`:169-204`) copies an object of one to six fields
  as a move the compiler unrolls, leaves `K_FORWARD` and the new address
  behind (`value.h`, `obj_forward`), and counts the boxes apart. The
  space collected from is kept as the next one collected into while the
  heap keeps its size (`:253-264`, `:288`), which the M12 of the
  codegen roadmap found saved the kernel's work of fresh pages (21% of the native
  bootstrap's CPU time).
* **The heap doubles** until what survives fills at most `--heap-fill`
  percent of it, 50 by default (`fill_of`, `grown`, `:303-331`). `vm_gc`
  (`:333-364`) first guesses what will survive from the last two
  collections and grows before collecting; a guess too low collects
  a second time into a larger space (`:353-355`). While it grows, the
  old space, the space it copies from and the new, doubled one are all
  held: three times the old semispace for the length of a collection.
* **The spaces are `malloc`'d** (`space_new`, `:94-98`), 8-aligned so
  that bits 1 and 2 of a pointer are clear (`PTR_SPARE_BITS`, the codes
  heap-layout kept open). There is no reservation of address space, no
  return of memory but the `free` of a space that was outgrown, and no
  large-object space.
* **Limits:** `--heap-size` (the first semispace; 4 MiB by default),
  `--heap-limit` (a cap on a semispace; `vm_limit` past it), `--heap-fill`
  (`runtime/main.c:80-102`). `--gc-stress N` collects at every Nth
  allocation and sends the fast paths of the JIT and `runeopt` to their
  slow paths (`heap.c:133-136`; `masm.c:1109-1110`).
* **What it reports:** `--stats` prints the collections, bytes allocated,
  the semispace, what is live, bytes copied, the most a collection kept,
  the collector's time and its longest collection (`runtime/runtime.c`,
  `heap.c:360-363`; the time is `getrusage`'s, user and system, read
  around the whole of `vm_gc`). `Runtime.stats` gives instructions,
  bytes, objects, collections, live and the heap's size
  (`lib/basis/runtime_sig.sml`).

### Allocation

One `AllocState` (`runtime/vm.h:161-170`: `from`, `size`, and `used`, an
offset) is the state of the one thread that allocates; heap-layout M7
made it so, and its comment says a nursery is this struct and the three
fast paths changed together. Four paths bump it:

* `vm_alloc` (`heap.c:130-146`), for the interpreters, the primitives
  and every slow path: it compares the size with what is left, collects
  if it does not fit, bumps, counts boxes (`K_REAL`, `K_BOX`) apart from
  other objects, and writes the header;
* the JIT's `ms_alloc` (`runtime/register/jit/masm.c:1107-1123`): a test
  of `gc_stress`, a load of `alloc.used`, a `lea` of the new end, a
  compare with `alloc.size`, the store, two counters, and the header as
  two 32-bit stores; the slow path is `SLOW_ALLOC` to `jit_h_alloc`, which
  calls `vm_alloc_fields` (`compile.c`);
* `runeopt`'s template, generated from `ms_alloc` by the text backend of
  the macro-assembler (`src/opt/x64_layout.sml:244-256`, the offsets from
  `runtime/native/native_offsets.h`);
* images, which `malloc` one space and refill it object by object at the
  offsets the writer had (`runtime/image.c:565-574`).

Every allocating opcode makes an immutable object (`TUPLE`, `CON`,
`CONN`, `CLOSURE`, `NEWEXN`, `MKEXN`); the mutable ones come only from
primitives (`ref_new`, which the JIT puts in line, `array_new`,
`array_from_list`, `bytes_new`, `reals_new`), and a closure is written
once after it is made, by `SETENV`, to close a recursive group. So the
kind of an object says whether it can ever be written, at every site.

### Stores and the barrier

Four kinds of store write into an object that exists: `:=`,
`Array.update`, `SETENV`, and the update of an indirection that no SML
program makes yet (`obj_become_ind`). In C they go through
`obj_set_field` (`value.h:298-300`), which calls `BARRIER(o)` before the
store; in compiled code through `ms_barrier` (`masm.c:1146-1155`) after
it, at `emit.c:527` (`ref_set`), `:543` (`array_update`, given the
element's address rather than the object's) and `:739` (`SETENV`). The
body is empty. Under `RUNE_BARRIER_CARDS` it is a card mark: one byte
for every 512 bytes of address, in a table of 2^20 bytes that the
address is folded into (`value.h:282-297`, `heap.c:81-90`), written and
never read; heap-layout M7 measured it at 0.3% more instructions on the
bootstrap and 4.7% on `imp-for`, a loop of `:=`.

Three things about the barrier as it stands matter to this roadmap:

* **`runeopt` has none.** Its inline `ref_set` and `array_update`
  (`src/opt/x64.sml:245-249`, `:270-274`) store with `L.storeField` and
  no barrier operation; its `SETENV` goes to C (`native_setenv`), which
  has one. `collector.md` says the templates "take the barrier when it
  has a body"; they do not.
* **No barrier sees a value.** `BARRIER(o)` has the object, `ms_barrier`
  a register with the object or the slot's address. A barrier that
  remembers only stores of a young value into an old object, or a
  snapshot barrier that marks the value overwritten, needs the old or
  the new value: a new signature at every store.
* **Initialising stores pass it by.** A fresh object's fields are filled
  without it (`obj_fill_field`; `jit_fill`, `compile.c:509-542`; the
  loops' `f[i] =`; `vm_alloc_fields`' fill with unit, `heap.c:151`; the
  primitives that fill an array they made, `prims.c:1716`, `:1742`;
  images). That is right while the object is the youngest in the heap,
  and wrong as soon as an allocation between the making and the filling
  can promote it, or a large object is made old.

### Roots

`stack_roots` (`heap.c:236-251`) scans the value stack. Where the engine
says which registers of a frame are live (`VM.frame_live`, the register
VM's `reg_frame_live`, `runtime/register/live.c`, heap-layout M6), the
registers of a frame that waits for a call are roots only where live,
and a dead pointer is made unit; the frame that runs keeps every
register, and so do registers past the 64th and every slot of the stack
VM and of `runeopt`'s frames. `OTHER_ROOTS` (`:213-225`) is the rest,
listed once for the collector and for `heap_relocate`: globals,
constants, each frame's closure, the eight built-in exceptions, the six
boxes of the reals the VM keeps (zero, the infinities, NaN), and the
handles C holds (`vm_handle_new`). Tier 2's homes never hold a pointer;
they are written back at every safepoint, so the slots are the roots
(`masm.h`). A primitive keeps its arguments on the stack until its
result exists and reads pointers again after it allocates.

There are no polls: code that does not allocate is never interrupted
(`docs/runtime.md`), and the only ways into the collector are `vm_alloc`
and `Runtime.collect`. A collector whose work is paced by allocation
needs none; one paced by time would need the compiler to emit them.

### What the heap-layout roadmap left for this one

Built and tested in its M6 and M7 (`make test-heap`; `docs/runtime.md`,
*What is in place for a collector to come*):

| Hook | Where | Cost today |
|---|---|---|
| four bits of the header: two of age or colour, remembered, pinned | `value.h:234-258`, `OBJ_GC_*` | nothing; under `RUNE_GC_BITS`, which masks the kind wherever it is read and sets the bits at every copy, 2.5% more instructions in the interpreter and 4.4% at the default tiering on the bootstrap, 9.8% on `tailmerge` (heap-layout, *M7, done*) |
| the barrier as one operation | `BARRIER`, `obj_set_field`; `ms_barrier` | nothing; a card mark 0.3% (bootstrap) to 4.7% (`imp-for`) |
| young by address | `heap_is_young`, `vm.h:286-292` | nothing |
| an object made an indirection in place | `obj_become_ind`; the collector follows its first field | nothing |
| the allocation state as the thread's, the collector's as the VM's | `AllocState`, `GcState` | nothing |
| roots by what is live | `VM.frame_live`, `live.c` | saves 12% of the bootstrap's copying |
| handles for what C holds; a copy for C of a byte or real array | `vm_handle_*`, `vm_pin`/`vm_unpin` (`heap.c:383-429`) | a copy in and out around a call |
| `K_THUNK`, `K_IND` reserved; bits 1-2 of a pointer free | `value.h:68-75`, `PTR_SPARE_BITS` | nothing |

### Images, `--count`, determinism

An image is written by walking the one space from `alloc.from` to
`alloc.used` and writing each pointer as its offset (`image.c:118-166`,
`put_value`, `put_obj`, `put_heap`), and read back into one `malloc`'d space at the same
offsets, after which `heap_relocate` (`heap.c:431-454`) moves every
pointer by the distance; both assume one contiguous heap, and so does
`heap_is_young`. A collector of several spaces either collects into one
before it writes an image or gives the image format spaces.

`--count` (instructions, bytes and objects allocated) is the same on
every engine and every width, and is checked byte for byte across
`runevm`, `runevm.exe` and `runevm32.exe` (`docs/runtime.md`, *The same
run twice*). Boxes are counted apart because they depend on the engine.
A collection happens at the same allocation in every run of the same
program with the same flags; its addresses do not repeat. The documents
disagree on one point: `runtime_sig.sml:41-44` says the first four
counters of `Runtime.stats`, collections among them, do not depend on
the heap's size; `docs/runtime.md:361-363` says the number of
collections does. The second is true.

### Who depends on the collector

| File | What it knows | Changes when |
|---|---|---|
| `runtime/heap.c` | everything: spaces, copying, roots, growth, handles, relocation | always |
| `runtime/vm.h` | `AllocState`, `GcState`, `heap_is_young`, the counters, the handles | spaces, the nursery |
| `runtime/value.h` | the header's GC bits, `BARRIER`, `obj_set_field`, `obj_fill_field`, `obj_become_ind`, forwarding, sizes | the barrier, metadata |
| `runtime/register/jit/masm.c`, `emit.c`, `compile.c` | `ms_alloc` (the limit), `ms_barrier` (three sites), `SLOW_ALLOC`, `jit_fill` | the fast path, the barrier |
| `src/opt/x64_layout.sml`, `x64.sml`, `templates.c`, `native_offsets.h` | the allocation template, the inline stores without a barrier | the fast path, the barrier |
| `runtime/stack/*`, `runtime/register/reg_cases.h` (generated from `src/isa`) | allocation through `vm_alloc`, `SETENV` through `obj_set_field`, fills | the barrier's signature |
| `runtime/prims.c`, `runtime/register/fastprim.h` | `ref_set`, `array_update` and their fast paths; fills of arrays they make | the barrier, large objects |
| `runtime/image.c` | one contiguous heap, offsets from `alloc.from` | spaces |
| `runtime/runtime.c`, `lib/basis/runtime_sig.sml` | `--stats`, `Runtime.stats`, `collect` | the statistics |
| `runtime/census/*`, `tools/heapsim` | the trace of what is allocated, the models | the experiments |
| `tests/runtime/heap_test.c`, `tests/lang/rt.gc_*`, `make test-heap`, `test-stress` | the hooks, the limits, stress | always |
| `docs/runtime.md`, `docs/plans/collector.md` | the collector as documented | always |

### Memory today, and on 32-bit

Measured for this roadmap on the stock copier with a log of every
collection (*The experiments*, the baselines; `results/workloads-baseline.md`,
`results/workloads-32bit.md`):

* **The copier holds five to ten times the live data.** The bootstrap
  keeps 41 MB live at most and peaks at 272 MB resident (6.6 times): two
  semispaces of 134 MB. The latency window with 104 MB live ran in
  semispaces of 512 MiB and 1,027 MB resident; with 937 MB live, in 4 GiB
  semispaces and 2.9 GB resident, 6.4 GB of address space. The doubling
  has a cliff, made worse by the survivor guess: 0.93 GB of live data
  already asks for 4 GiB semispaces.
* **First touch costs the mutator.** After a new semispace is mapped the
  program runs at half speed until its pages exist: with 1 GB live, 14.8
  s of system time against 15.3 s of user time.
* **On 32-bit the heap is the same as on 64-bit** (heap-layout's D13 A:
  the 8-byte word everywhere) -- the same collections, bytes and peaks --
  but the address space is the limit. A program growing its live data on
  `runevm32` failed every time when the copier's `malloc` of its next
  semispace failed: with the whole 4 GiB a 32-bit process has on a 64-bit
  kernel, no collection completed with more than 1 GiB live, and at the
  default `--heap-fill` the copier asks to grow at 512 MiB, asking then for
  one contiguous 2 GiB block beside a 1 GiB one, which never fits. Under a
  2 GiB limit (a 32-bit Windows process's user space) the ceiling is 255
  MiB of live data. `docs/runtime.md`'s estimate of "about 512 MiB" is
  confirmed without a limit, and halves with one. At their peaks the
  copier's address space per byte live was 4.9 (`tsp`) to 10 (the
  latency window) times.

### Pauses today

Every collection copies all that is live, so the longest pause grows
with the live data, about 1.5 ms per MB on the latency window (6-7 ms at
11 MB live, 151-158 ms at 104 MB, 1.41 s at 937 MB; the map variant, with
more objects per byte, 2.49 s at 973 MB) and 2.47 s for a 791 MB static
map with requests that allocate. The bootstrap's longest pause is 73-96
ms, its median 38 ms, and its minimum mutator utilisation (the least
share of any window the program had) is zero at every window up to 50
ms. Most of MLton's programs keep under 2 MB live and pause under 2.5
ms, but `tsp` pauses 323-341 ms (134 MB live), `fft` 50-64 ms, and the
two `wc` programs 52-87 ms for 8.4 MB live (a 2 MB string a line grows
the heap). Rune compiling MLton pauses up to 5.1 s (5.14 s in this roadmap's
baseline; 4.9 s at `88342575`). Allocation
alone costs almost nothing: `md5`, `output1`, `psdes-random` and the
like, with under 0.1 MB live, make 10,000 to 23,000 collections of 0.01
to 0.2 ms each.

### What the collector costs

* **The bootstrap** (the word layout, default tiering): 887 MB allocated,
  10 collections from 64 MiB, 306 MB copied, 0.39 s of 2.3 s in the
  collector (`collector.md`).
* **Rune compiling MLton** (MLton `5fe943391`, the heap capped at 5 GB):
  509.7 s of user time, 158 s of it (31%) in the collector; 219 GB
  allocated and 180 GB copied in 106 collections (`performance.md`,
  *The gap to MLton*).
* **MLton built by Rune, building MLton:** 72% of a 30-second profile in
  the collector (`copy_obj` 58%, `collect_into` 15%); it did not finish
  beside the editor's memory. MLton built by MLton spends 82 of 466 s
  (18%) in its own generational collector.
* `performance.md` closes its assessment of the JIT on this: "For the
  large programs that matter most (the compiler, MLton), item 13's
  generational collector likely matters more than either."

### Where the documents are wrong

Found while this roadmap was written, at `ca87fa07`:

* **`runeopt`'s barrier.** `collector.md:141-142` says the templates
  "take the barrier when it has a body". They have no barrier template
  (`runtime/register/jit/templates.c` has `storeField` and
  `storeFieldImm` and no barrier), so a body given to `ms_barrier` would not reach `runeopt`'s `:=`
  and `Array.update`; heap-layout's D15 target 4 ("the next roadmap's
  nursery is a change to `heap.c` and the barrier's body alone",
  `heap-layout.md:4539-4540`) is not true of `runeopt`.
* **`make check` checks neither the census VM nor the simulator.**
  `test-census` is an `echo` since heap-layout's M4 (`Makefile:489-490`,
  stubbed in `ac21d418`), though the comment above it and
  `heap-layout.md:1630-1631` say it runs; `check-heapsim`
  (`Makefile:507-509`) runs the simulator's unit tests and skips its
  validation against the VM. Heap-layout's risk 5 says `--gc-stress 1`
  and the sanitiser run under `make check`; they run under `make
  test-stress` and `make test-register-asan`, which the rules require
  and `make check` does not include.
* **Collections and the heap's size.** `runtime_sig.sml:41-44` says the
  first four counters of `Runtime.stats`, collections among them,
  depend on the program and its input alone; `docs/runtime.md:361-363`
  says the number of collections follows the heap's size, which is
  true. The same signature does not say that `live` leaves the boxes
  out, and `--stats` prints the collector's user and system time where
  `Timer.checkGCTime` reads user time alone (`runtime.c:346`,
  `lib/basis/timer.sml:36`).
* **`performance.md`'s item 13** (`:428-450`) names `heap_from`,
  `heap_used` and `heap_size` (now `AllocState`), puts the remembered
  bit in the `pad` byte (now kept for a descriptor of raw fields; the
  bit is `OBJ_GC_REMEMBERED`), and says images are unchanged because the
  heap is collected before it is written, which it is not
  (`docs/runtime.md:215-217`).
* **A promise of heap-layout's D8 was not kept:** "a closure written by
  `SETENV` -- M5 gives such closures their own kind or bit"
  (`heap-layout.md:4345-4347`). There is only `K_CLOSURE`, and every one
  of the fifteen kinds the header's four bits can say is taken
  (`value.h:53-75`): a new kind -- a closure still to be written, a
  large object -- needs room the header does not have (D8).
* **Stale figures and lists:** `weak-points.md:130-131` ("every value
  takes 16 bytes"); `docs/runtime.md:92-94` and `:121-124` quote the
  bootstrap at the 64 MiB start `bin/rune` uses (`Makefile:140`) without
  saying so (from the default 4 MiB it makes 18 collections and copies
  383 MB); the lists of options at `docs/runtime.md:416-418` and
  `:436-437` lack `--heap-limit`, `--stack-size` and `--equality-work`;
  `AGENTS.md:246-249` lists fewer targets than `make check` runs.
* **A citation in `heap-layout.md`:** the "5.1%, 4.8% and 1.8%" it
  gives as Blackburn and Hosking's (2004) read-barrier averages
  (`heap-layout.md:2490-2494` and its table) are their zone write
  barrier's; their read barriers averaged 8.05/5.04/0.85%
  unconditional and 21.24/15.91/6.49% conditional (*What the literature
  says*). And `/home/ruud/reference/papers/appel1989.pdf` is Appel's
  "Runtime tags aren't necessary", not his 1989 paper on generational
  collection.
* **The raw traces** that `collector.md` and the heap-layout drafts'
  README say are kept in the drafts directory were archived to the slow
  disk (`/mnt/h/HEAPSIM/heap-layout/traces`), and every one of them
  predates the word layout (M5), the dead registers dropped as roots
  (M6) and the flat arrays (M8).

And what a collector that does not copy everything will make false,
for M5 and M8 to rewrite: `runtime_sig.sml:78-80` ("every surviving one
moves ... a copying collector never visits what it does not keep") and
its "semispace"; `docs/runtime.md:116-127` (stop-the-world, in
proportion to what is live, every object moved), `:136` (no pinning)
and `:345-348` (the 32-bit ceiling "because the heap holds both
semispaces").

M2 corrects the first four in the tree.

## What is different for SML, and for Rune

A collector is designed for the programs it serves. These are the
properties of Rune's that the decisions below lean on; most are old
facts about ML, a few are Rune's own.

* **Data is immutable, and so points backwards in time.** An object
  made by `TUPLE`, `CON`, `CONN`, `CLOSURE`, `NEWEXN` or `MKEXN` is
  filled once, as it is made, with values that existed before it. So an
  immutable object can only point at objects older than itself, and a
  pointer from an old object to a young one can only be made by a store
  into an object that exists: `:=`, `Array.update`, the one `SETENV`
  that closes a recursive group, and, for a lazy front end, the update
  of a suspension. This is what made a generational collector cheap for
  ML from the start (Appel 1989; Reppy 1993 found under 1% of the live
  data of SML/NJ programs mutable), what lets Erlang's per-process heaps
  have no barrier at all, and what Doligez and Leroy built OCaml's
  concurrent collector on. It also means that a snapshot barrier has
  nothing to do at an initialising store, and that objects allocated
  during a marking cycle can be allocated marked.
* **Mutable objects are few, and known by kind at their site.** Only
  `K_REF`, `K_ARRAY` and, raw, `K_BYTES` and `K_REALS` can be written
  after they are made, and closures once. The compiler knows at every
  site which kind it makes (*Where we are*, *Allocation*), so a
  collector can put mutable objects in a space of their own (Poly/ML's
  way) or have the compiler say which sites they come from.
* **Allocation is fast and objects are small.** The bootstrap allocates
  898 MB in 34.2 million objects (the census) in about 2.5 s on the
  word layout, 26 bytes an object; a list cell is 24 bytes, a ref 16, a
  pair 24. Most of it dies young, but a compiler keeps much: of the
  bootstrap's allocation, 19-21% outlives a nursery of 1 MB and 14.5% one
  of 32 MB (`results/sim-survival.md`), where the median of the 33
  traces that allocate more than 64 MB, most of them MLton's programs,
  is 1.8% at 1 MB (from nothing
  on `peek` to 98% on `tsp`, which builds one large structure).
* **Stacks are deep.** SML recurses where other languages loop:
  `List.map`, `foldr`, a parser's descent, the compiler's walks over its
  trees. Rune's frames are on the VM's own stack, not the machine's, and
  every collection scans the whole of it today. At the census's samples
  (every 32 KiB of allocation; `results/lead/stackdepth.txt`) the
  bootstrap's stack held 2,384 slots at the median, 34,845 at the 99th
  percentile and 397,872 at the most, in up to 20,881 frames; `hamlet`'s
  26,702 at the median, `exp3_8-lazy`'s 22,996; but `lexgen`, `mlyacc`,
  `boyer` and `fxp` stay under 4,300. And almost all of it is unchanged
  from one sample to the next: of the slots a collection scanned, 95.9%
  on the bootstrap were in frames that had not run since the previous
  sample, 98.2% on `hamlet`, 99.2% on `knuth-bendix`, 83-92% on
  `compile-sigs`, `runedoc-page`, `fxp` and `exp3_8-lazy`, 55-74% on
  `lexgen` and `mlyacc`, 13% on `primes-lazy`. A collector that collects
  often -- a nursery -- pays for the depth at every minor collection
  unless it scans only what changed since the last (D9).
* **Tail calls reuse frames, and exceptions cut the stack.** A frame
  that a tail call reuses changes in place; a handler discards the
  frames above it. Both matter to anything that remembers how much of
  the stack is unchanged.
* **Precise, and self-describing.** Every slot and every field is a
  tagged word: bit 0 says whether it is a pointer, and an object's kind
  says whether its payload holds values at all. The collector needs no
  maps and no descriptors to scan, the interpreter none to find its
  roots, and nothing is conservative. The JIT keeps pointers out of
  registers for this reason (`performance.md`, *Tier 2's registers*).
* **No identity in the object model.** Polymorphic equality is
  structural, but for refs, arrays and exception names, which compare
  by address; there is no identity hash, no finaliser and no weak
  reference in the Basis or the runtime. Moving an object costs nothing
  but the move.
* **Collection only at allocation.** There are no polls; the compiler
  emits none and the JIT keeps no safepoints but allocations and calls
  into C. A collector paced by allocation fits that; one paced by a clock
  would need polls in loops that do not allocate.
* **One collector for every engine, and the same run every time.**
  `--count` is exact across the engines and the widths and is the oracle
  of the test suites; a collection happens at the same allocation in
  every run. Images cross machines, widths and byte orders. The 32-bit
  and big-endian VMs are kept, and the 32-bit ones will stay on this
  collector (the brief).
* **A lazy front end may come.** Updating a suspension writes into an
  object that may be old, which is common in lazy programs (Sansom and
  Peyton Jones 1993) and where the remembered set, not survival, is what
  laziness costs; heap-layout measured 0.02% to 6.7% of the updates of
  six lazy programs as old to young (*M4, for a lazy front end so far*).
  `K_THUNK`, `K_IND` and the pointer's third code are reserved for it.

## What the literature says

What the published record says about the features the brief names, for
a strict ML on one thread that must also run in a small 32-bit address
space. It builds on `heap-layout.md`'s section of the same name and does
not repeat it. Every DOI was fetched from Crossref on 2026-10-05 and its
title, authors, year and pages compared; the papers the owner supplied
on 2026-10-06 (`/home/ruud/reference/papers`) were read in full or for
their results, *The Garbage Collection Handbook* (2nd ed.) as a
cross-check; *References* marks how each was read. The numbers are the
papers' own, with the conditions they were measured under, which are
rarely Rune's: they say what to measure and roughly what to expect, not
what Rune will get.

### Generations and promotion

The generational idea is Lieberman and Hewitt's (1983); the collector
that made it cheap is Ungar's generation scavenging (1984): on a 68010,
a 140 KB creation space and two 28 KB survivor spaces cost 1.5% of the
CPU, against about 7% for semispaces, in 200 KB where semispaces needed
360 KB, with pauses of 150 ms median and 330 ms at most. Appel (1989)
made it simple for SML: the nursery the upper half of the free space,
survivors merged into an old area copied when it fills half the heap, a
store list for the barrier (about four instructions; pointer stores
under 1% of the SML compiler's instructions). His sizing rule is the
one that matters to the brief: with γ the memory over the live data, γ
under 2 fails, "γ should be 3 or more", and the SML compiler's GC
overhead was about 11% at γ = 3 and 6% at γ = 7. A copying old space
needs the live data to be at most a third of the memory -- exactly what
a small 32-bit target cannot pay. Zorn (1990), simulating large Lisp
programs, found generational mark-and-sweep "at most a small amount of
additional CPU overhead (3-6%)" for 20% (up to 40%) less memory at the
same page-fault rate. Hansen and Clinger (2002) measured stop-and-copy
needing 68% more CPU and 35% more heap than a two-generation collector
on `earley`. Cheng, Harper and Lee (1998) attributed TIL's 10-35%
speedups from generational collection to the allocation area staying in
the secondary cache.

On promotion: Wilson and Moher (1989) age objects by two buckets and a
high-water mark rather than by counts, the scheme Reppy (1993) used for
SML/NJ -- a survivor stays one collection young, then is promoted -- and
schedule scavenges at the user's pauses. Ungar and Jackson (1988, 1992)
found scavenging degrades when many objects live a fairly long time and
then die; their adaptive tenuring, driven by the volume of survivors,
cut the longest pauses from 1.3 s to 440 ms and from 140 to 66 ms, and
they advise keeping large bitmaps and strings out of the scavenged
space. The handbook (§9.6) adds that a copy count of two sharply cuts
promotion, and that an eden-to-survivor ratio of 8:1 needs a copy
reserve of only 6.25% of the young generation. Clinger and Hansen (1997,
in part) remind that if lifetimes were exponential, age would predict
nothing -- the heuristic that picks which generation to collect matters
more than predicting lifetimes, and whether a generation pays depends on
the real demographics, which for Rune are the traces' (*The
experiments*). Older-first and Beltway (Stefanović et al. 1999,
Blackburn et al. 2002) beat classic generational copying by 5-10% in
small heaps, at remembered sets that Hansen and Clinger saw grow past 3%
of the heap; Beltway's point for Rune is that "classical generational
and semi-space collectors must reserve half the heap", and a copying old
space need not.

**Pretenuring by site.** Barrett and Zorn (1993): over 90% of the bytes
allocated are short-lived, and the allocation site identifies 42-99% of
them. Blackburn, Singhai et al. (2001): site advice was accurate enough
to combine across programs; in Jalapeño it cut GC time 20-32% and total
time 7% in a tight heap, 3.4% of it harmful. Cheng, Harper and Lee
(1998), in TIL: 90% of the allocation came from sites whose objects
never survived, and pretenuring the others cut GC time 12-50% on four
programs, total time about 4%. Harris (2000) did it online for 60 ms of
sampling in a 30 s run; Jones and Ryder (2008) found sites carry phases
as well as lifetimes; Hayes (1991), that objects allocated together tend
to die together.

**The stack.** Cheng, Harper and Lee (1998) are also the measurement of
what deep recursion does to a minor collection in an ML: scanning the
stack was up to 95% of GC time in deep programs; in Knuth-Bendix only
117 of 1,337 frames scanned had changed since the last collection;
markers in return addresses every 25 frames, so that a minor collection
stops at the first unchanged one, cut GC time 13-74% for about 3% elsewhere.
The handbook's stack barriers (§11.5) are the same mechanism.

### Old spaces

**Mark-region.** Immix (Blackburn and McKinley 2008): blocks of 32 KB in
lines of 128 B, bump allocation through free lines, objects over 8 KB to
a large-object space, a "medium" object that misses the current hole to
an overflow block; metadata a byte a line and four a block, 0.8%;
conservative line marking, since exact marking was "quite expensive";
opportunistic evacuation of the blocks with the most holes into a 2.5%
headroom. On 20 Java benchmarks and three machines it was 5-25% faster
than the best canonical collector, its minimum heap 3% above
mark-compact's and 15% below mark-sweep's. Without the evacuation the
minimum heap grew 45% on average and up to 361%; line size mattered
more than block size and is tied to the language's objects (the worst
case with 8 B objects is 97% line fragmentation; the handbook ties the
128 B line to the cache line, the paper to object sizes, and this
roadmap follows the paper). SML objects are two to four words, not
Java's: the line size is Rune's to derive. RC Immix (Shahriyar et al.
2013) located the cost of free lists: a free-list heap ran 9.3% slower
in mutator time than Sticky Immix, with 9.2% more instructions and 33%
more L1 misses, all from where objects were put. LXR (Zhao, Blackburn
and McKinley 2022), short reference-counting epochs on Immix with an
occasional snapshot trace and one field-logging barrier for everything
(1.6% mutator cost), is the third generation's material; what transfers
is that regular short pauses and one barrier for several purposes beat
concurrent copying.

**Non-moving, segregated.** Ueno, Ohori and Otomo (2011) is SML#'s
collector, on a Xeon with 32-bit words: ten power-of-two sub-heaps from
8 B to 4 KB, cut from 128 KB segments; marks in bitmaps, whose clearing
cost 0.06-2.4% of GC time; allocation by searching the bitmaps
hierarchically; never moving, for C. Against copying it needed a smaller
minimum heap and less GC time but ran the mutator slower (a bitmap
search where copying bumps), and its generational form beat generational
copying at twice the minimum heap and matched it at larger heaps. Its
concurrent successor (Ueno and Ohori 2016) cost about 12% over the
sequential one. Gamari and Dietz (2020) put the design under GHC's
oldest generation: longest pauses fell 99% (680.6 ms to 3.5 ms) at
11-94% more run time, occupancy stayed 70-90%, and promotion into the
free-list heap made minor collections 30-50% slower. Printezis and
Detlefs (2000) saw the same: promotion into CMS's free lists raised
young pauses from 24.6 to 32.8 ms on average. Promoted objects should be
bump-allocated, or aged first so fewer are promoted.

**Generational mark-sweep against copying.** *Myths and realities*
(Blackburn, Cheng and McKinley 2004): bump allocation has fewer misses
than free lists, a generational collector wins "in virtually all
circumstances", barrier costs are "often 2% or less", and a mark-sweep
mature space wins in small heaps. It also found each collection scanning
about 64 KB of roots, so that GC cost tapered only between 4 and 8 MB of
nursery, debunking "the myth that the nursery size should be matched to
the L2 cache size" -- on a 900 MB Java heap; the small-machine studies
below say otherwise, and Rune must measure. Hertz and Berger (2005)
found generational mark-sweep the best collector and more
space-efficient than generational copying, and under memory pressure
garbage collection "visits far more pages than the application": 10 to
15 times slower than `malloc` with 36-63 MB of RAM.

**Copying, compacting, or both.** Sansom (1991, found in the Glasgow
workshop's proceedings) built the dual-mode collector MLton's descends
from: copy below a residency of about 30%, compact in place above it,
since Jonkers' compaction costs about 3.5 times a copy per collection at
a third residency; and he proposed an Appel-style collector with
compacting majors for machines without virtual memory. Mark-copy
(Sachindran and Moss 2003) divides the old generation into windows,
marks once to build per-window remembered sets, and copies a few windows
at a time into free ones, unmapping what it vacates: 75-85% less space
overhead than copying. MC² (Sachindran, Moss and Berger 2004), for PDAs
and phones, makes it incremental: a nursery of 64 KB to 1 MB, 40
windows, incremental marking and window copying, overhead beyond the
bitmap at most 7.5%; on a 1.7 GHz Pentium 4 with 256 KB L2 at 1.8 times
the live data, its longest pauses were 10 to 17 times shorter than
generational mark-compact's, most under 10 ms, at comparable throughput:
the closest published design to Rune's 32-bit constraints. McGachey and
Hosking (2006, known through the handbook, §9.9): a copy reserve of 10%
with a fall-back, on the fly, to marking and Jonkers compaction when it
runs out was 4% faster on average (up to 20%) than MMTk's generational
collectors. Sticky mark bits (Demers et al. 1990) give generations
without a copying nursery.

### Fragmentation and compaction

"Fragmentation is caused by isolated deaths" (Wilson, Johnstone, Neely
and Boles 1995): objects placed together that die together leave no
holes, programs run in ramps, peaks and plateaus, and "fragmentation at
peaks is important", not on average. Johnstone and Wilson (1998) found
address-ordered first fit and best fit under 1% fragmentation on eight
real C and C++ programs, allocators that never coalesce over 50%, and
headers and alignment the larger cost. Metronome (Bacon, Cheng and
Rajan, LCTES 2003) bounds the internal waste of its size classes by
spacing them at a ratio of 1/8 -- at most 12.5%, measured at 2% or less
-- in 16 KB pages with a 2 KB largest block and large arrays split into
arraylets; power-of-two classes (SML#, Alligator) can waste up to half a
block. For an ML's old space the defences are therefore classes spaced
finely, allocating contemporaries together (bump into lines or
segments), and evacuating occasionally. Schism (Pizlo et al. 2010) shows
what guaranteed tolerance costs -- 1.4-1.5 times the space, 65-84% of
HotSpot's throughput -- a real-time option, not this roadmap's.

On compaction the sources agree on the routine case and differ on the
fall-back. Cohen and Nicolau (1983): Lisp-2 is fastest but needs a word
per cell, Morris' threaded compactor slowest; Sansom's 3.5 times a copy
for Jonkers; Abuaiadh et al. (2004) replaced IBM's threaded compactor
with per-block relocation tables (2.3-3.9% of the heap) and found it
"substantial[ly]" faster "even on a uniprocessor"; the Compressor
(Kermany and Petrank 2006) slides in one pass from a mark bitmap and an
offset per 512 B block, so any object's new address is computed, in
"usually less than a factor of 2" of a full collection, with tables of
1/32 plus 4/512 of the heap and no second space (its concurrent form
needs two virtual spaces and page traps, which a 32-bit target cannot
spare). But McGachey and Hosking's Jonkers fall-back above paid off,
since it ran rarely; the handbook suggests the Compressor for that role.
So: threaded compaction is a measured loser as a routine compactor and
acceptable as a rare fall-back when there is no room for anything else.

### Barriers and remembered sets

The question for Rune's rare stores is not the barrier's cost at a store
-- every study puts a generational barrier at 1-2% -- but what the
collector does with what it records. Hosking, Moss and Stefanović
(1992): remembered sets were the best scheme everywhere, GC at 1.5-2.7%
of run time against 2.9-20% for cards, because they "compactly record
just those locations" that can hold old-to-young pointers; with cards
summarised into remembered sets at each scavenge, 1 KB cards were best
of the card schemes (Hosking and Hudson 1993), and page protection lost
(a trap cost 210-250 µs). Hölzle (1993) made the card mark two SPARC
instructions by marking the object's card. Blackburn and McKinley
(2002): inline the fast path only, which beat full inlining by 1.5% of
mutator time. Blackburn and Hosking (2004) on three processors: the
object-remembering barrier (a header bit) 1.23-1.76% on average, worst
5.45%; card marking 0.80-4.59% (card scanning not counted); "barrier
costs have often been overstated", are "very architecturally
dependent", and card marking being cheapest "is questionable". Yang et
al. (2012): on a Core i7 a card mark 0.9%, an object barrier 1.6%; on an
in-order Atom the card mark doubled (1.8%), and an unconditional read
barrier cost 5.4% -- the price of any design that moves objects under
the mutator. Brooks' indirection word (1984) cost 37.5% a `CDR` against
125% for Baker's barrier, and half again the space of a cons. Rune
measured its card mark at 0.3% on the bootstrap and 4.7% on a loop of
`:=` (heap-layout M7).

(A correction to `heap-layout.md`: the "5.1%, 4.8% and 1.8%" it gives as
Blackburn and Hosking's read-barrier averages are their **zone write
barrier**'s; the read barriers averaged 8.05/5.04/0.85% unconditional and
21.24/15.91/6.49% conditional on Athlon, Pentium 4 and PowerPC.)

### Incremental collection and short pauses

The tricolour invariant and the insertion barrier are Dijkstra et al.'s
(1978). Yuasa (1990) is the snapshot (deletion) barrier: on destructive
stores only, the overwritten value marked, new objects allocated black,
no final re-mark -- but the stack is snapshotted at the flip, which
Yuasa does by copying the whole stack, assuming "tens of KB"; with 20
steps of marking or sweeping per allocation the heap needs about 1.22
times the most live data. An incremental-update barrier (V8; Printezis
and Detlefs 2000) can reuse the generational card table, but a minor
collection cleans the cards, so a "mod-union" bit per card is needed,
and roots and dirty cards are rescanned at the end (handbook §15.2).
Either way the stack's scan must be bounded. Printezis and Detlefs,
mostly-concurrent on `javac` in a 139 MB heap: two old-generation
collections of 3.2 s became 90 pauses of 22 ms on average (59 ms at
most), for 190.6 s of run time against 184.6 s.

Allocation-paced work is Baker's (1978): k units of scanning per
allocation, storage at most N(2 + 2/k), and a read barrier on every
load, which is what incremental copying costs. Appel, Ellis and Li
(1988) put that barrier behind page protection in an early ML: flips of
9.5 s became 0.16 s, 11% slower overall; without an MMU there is no
such barrier. Boehm, Demers and Shenker (1991), with 10 MB of RAM: a full
collection's longest pause 63 s, mostly-parallel generational 329 ms.
Nettles and O'Toole (1993) replicated instead of moving under the
mutator: ML's rare mutation lets the mutator keep the originals while
all writes are logged in SML/NJ's store list and replayed -- 84 ms
longest pauses against 988 ms, under 10% overhead on the compiler, at
twice the space during a cycle.

Metronome (Bacon, Cheng and Rajan, POPL 2003), on one 500 MHz PowerPC:
time-based slices, 10 ms of collector to 12.2 ms of mutator, gave
utilisation of 0.441-0.446 against a target of 0.45 and longest pauses
of 12.3-12.4 ms, in 1.6 to 2.5 times the most live data, with
defragmentation copying at most 4% of what was traced and a 4% read
barrier; work-based scheduling had a tail to about 100 ms. The J9
product (Bacon et al. 2005) held 2.4 ms against a 3 ms target. That is
time-based scheduling, which Rune's determinism rules out (*Constraints*);
what transfers is its accounting of utilisation and space.

Doligez and Leroy (1993) built a concurrent generational collector for
Caml Light and noted that it "can be simplified into an incremental,
generational collector for uniprocessors ... perform a small part of the
major collection at each minor collection": OCaml's major heap, and the
brief's "concurrent collection on a single thread" in an ML bytecode VM.
Cheng and Blelloch (2001) defined minimum mutator utilisation (MMU)
with TILT, an SML: their parallel real-time collector held pauses to
3-5 ms, but the program could have only 10-15% of the processor in a 10
ms window -- short pauses can hide poor utilisation -- and split stacks
into "stacklets" so deep SML stacks are scanned a piece at a time. The
handbook warns that MMU is not the whole story either: report it with
the pause percentiles. Sivaramakrishnan et al. (2020) measured what
OCaml's allocation-paced slices do to latency: a burst of allocation
makes a huge slice, 1,125 ms on `menhir`; capping slices at 10 ms gave a
10 ms worst case, but the major heap grew from 3.3 GB to 6.07 GB. On
32-bit there is no room for that: pacing must start early, cap each
slice, and fall back to finishing the cycle. Boehm (2000) adds that
incremental collection "essentially requires lazy sweeping", and that
eager sweeping was at least 50% slower than lazy, from the cache alone.
Degenbaev et al. (2016): V8 marks incrementally on its one thread in
steps under 5 ms, and scheduling them into idle time cut frame-time
discrepancy from 212 to 138 ms. HotSpot's G1 (Detlefs et al. 2004), Ossia et al.'s
mostly concurrent compaction, Pauseless and C4 are the third
generation's.

### Collectors for functional languages

Reppy (1993) is the nearest ancestor: a nursery of the secondary cache's
size (total CPU least when the 1 MB arena matched the 1 MB L2),
promotion by a per-arena high-water mark, arrays over 512 words
allocated straight into the first generation, code in a mark-swept
big-object space of 4 KB pages, a BIBOP of 64 KB pages, cards holding
the youngest generation they point to; and, as future work, the two
things 32-bit needs -- arenas that are not contiguous, and mark-sweep for
old generations, since "older generations tend to yield little free
space". Stefanović and Moss (1994) found SML/NJ's survival about 2%
already at a 35 KB nursery, decaying "faster than exponential" because
heap-allocated closures and continuations dominate, and judged 500-700
KB enough; Rune keeps its continuations on its stack, so its survival is
higher (the bootstrap's is a quarter at 1 MB), which is why the traces,
not SML/NJ's figures, decide. Diwan, Tarditi and Moss (1994): SML/NJ ran
only 16% slower than with a perfect memory on caches that allocate on
write with sub-block placement, often over 100% slower on others.
Gonçalves and Appel (1995): a word allocated every six instructions, 96%
of writes allocation, more than half of reads to objects just
allocated; fitting the allocation space in the 512 KB L2 helped
significantly. Huelsbergen and Larus (1993, the scan unreadable in
part) report concurrent copying for an ML with pauses of "a few
milliseconds", which Reppy found costlier overall. Marlow et al. (2008):
4 KB blocks with descriptors in 1 MB-aligned megablocks; generations as
chains of blocks that need no contiguous address space; large objects in
block groups never copied. Elsman and Hallenberg (2021): MLKit's
generational collector has no barrier -- every minor collection
traverses every reachable ref and array -- the barrier-free design point
to measure against a remembered set. SML# and Alligator are under *Old
spaces*. Perceus (Reinking et al. 2021) is reference counting with
reuse, outside a tracing design.

### The cache and locality

Wilson, Lam and Moher (1992; measured on Scheme-48, a bytecode VM like
Rune's): a semispace collector with 2 MB spaces needed about a 4 MB
cache to hold its reuse cycle; a generational one with 141 KB
semispaces reused memory every ~280 KB, and a separate creation space
brought that to 200-280 KB, "roughly thirty percent" less. On marking,
Boehm (2000) found prefetching on greying removes most of the mark
phase's misses on trees; Cher, Hosking and Vijaykumar (2004) and Garner,
Blackburn and Frampton (2007): a FIFO of prefetched edges ahead of the
mark stack cut GC time 20-30%, side mark bitmaps helped marking alone (a
gain "completely neutralized" by the rest of the loop), and header mark
bits for tracing with a side byte per block for lazy sweeping did best.
On copy order: Moon (1984) found approximately depth-first copying for
6% of GC time and ephemeral collection bringing page faults down to 60%
of running without a collector; Wilson, Lam and Moher (1991) cut
repeated page faults about tenfold with a hierarchical order; Chilimbi
and Larus (1998) placed objects cache-consciously at copying for miss
rates 21-42% lower and programs 14-37% faster than in Cheney's order;
Huang et al. (2004): static orders differ "often low, but up to 25%",
with no consistent winner.

### Small machines and 32-bit

Bookmarking (Hertz, Feng and Berger 2005): a bump nursery, a mark-sweep
mature space of 16 KB superpages compacted under pressure, empty pages
returned with `madvise`, full collections that never touch evicted
pages: up to 5 times the throughput and 45 times shorter pauses under
pressure. Yang et al. (2004) found the real memory a collected process
needs linear in its heap's size, and CRAMM (Yang et al. 2006, in part)
sizes the heap against the RAM available, not a multiple of the live
data. Squeak (Ingalls et al. 1997) collects its young space in place by
mark-compact, with no copy reserve, in 5-8 ms, and runs with 200 KB
free. MicroPython is mark-sweep over 16-byte blocks with two bits of
state a block (1.6% of the heap). Chen et al. (2003): in Sun's KVM,
compressing objects by their frequent field values cut peak heap demand
35% on average (16-54%) at under 2% cost -- on tiny heaps representation
buys more than collector cleverness. And an extra 32-bit header word cost
2.5% of total time and 6.2% of GC time (Shahriyar et al. 2012):
collector state belongs in spare header bits or side tables.

### What the numbers say

| Figure | Source | Conditions |
|---|---|---|
| a copying old space needs ≥ 3 × the live data; GC overhead ~11% at 3×, ~6% at 7× | Appel 1989 | SML/NJ compiler, VAX-8650 |
| generational mark-sweep: +3-6% CPU, 20% (up to 40%) less memory at equal page faults | Zorn 1990 | Allegro CL traces, simulated |
| stop-and-copy: +68% CPU, +35% heap against two generations | Hansen & Clinger 2002 | Larceny, `earley` |
| scavenging 1.5% of CPU; pauses median 150 ms, max 330 ms, in 200 KB | Ungar 1984 | Smalltalk, 68010 |
| adaptive tenuring: longest pause 1.3 s → 440 ms, 140 → 66 ms | Ungar & Jackson 1988/1992 | Smalltalk |
| total CPU least at arena = L2 (1 MB) | Reppy 1993 | HOL-90, SGI Indigo |
| a creation space cuts the cache needed by ~30% (to 200-280 KB) | Wilson, Lam & Moher 1992 | Scheme-48, simulated caches |
| GC cost tapers only at 4-8 MB of nursery; ~64 KB of roots a collection | Blackburn, Cheng & McKinley 2004 | Java, 900 MB heap |
| stack scanning up to 95% of GC time; 117 of 1,337 frames changed; markers every 25 frames: GC time −13-74% | Cheng, Harper & Lee 1998 | TIL (an ML) |
| pretenuring: GC time −12-50%, total ~4%; 90% of allocation from never-surviving sites | Cheng, Harper & Lee 1998 | TIL |
| pretenuring: GC time −20-32%, total −7% | Blackburn et al. 2001 | Jalapeño, tight heap |
| Immix: minimum heap +3% vs mark-compact, −15% vs mark-sweep; 5-25% faster; metadata 0.8% | Blackburn & McKinley 2008 | 20 Java programs, 3 machines |
| Immix without defragmentation: minimum heap +45% (up to +361%) | Blackburn & McKinley 2008 | same |
| free-list heap: +9.3% mutator time, +33% L1 misses vs Sticky Immix | Shahriyar et al. 2013 | Core i7, 2 × minimum heap |
| SML#: smaller minimum heap and less GC time than copying, slower mutator; generational form ahead at 2 × minimum heap | Ueno, Ohori & Otomo 2011 | Xeon 5150, 32-bit words |
| promotion into free lists: minor collections +30-50% (GHC), young pauses 24.6 → 32.8 ms (CMS) | Gamari & Dietz 2020; Printezis & Detlefs 2000 | GHC 8.10; Java |
| MC²: overhead ≤ 7.5% beyond the bitmap; longest pauses 10-17 × below mark-compact | Sachindran, Moss & Berger 2004 | P4, 256 KB L2, heap 1.8 × live |
| Jonkers compaction ~3.5 × a copy at a third residency | Sansom 1991 | Haskell, 1991 |
| 10% copy reserve with a Jonkers fall-back: 4% faster than generational (up to 20%) | McGachey & Hosking 2006 (via the handbook) | MMTk |
| block-table compaction beats threaded, even on one CPU; tables 2.3-3.9% | Abuaiadh et al. 2004 | IBM JVM |
| Compressor: compaction < 2 × a full collection; tables 1/32 + 4/512 of the heap | Kermany & Petrank 2006 | Jikes RVM |
| size classes at a ratio of 1/8: internal waste ≤ 12.5%, measured ≤ 2% | Bacon, Cheng & Rajan 2003 (LCTES) | Metronome |
| best fit / address-ordered first fit < 1% fragmentation | Johnstone & Wilson 1998 | 8 C/C++ programs |
| remembered sets: GC 1.5-2.7% of run time, cards 2.9-20% | Hosking, Moss & Stefanović 1992 | Smalltalk, DECstation 3100 |
| write barriers 0.8-2.5% (card, object, boundary); read barriers 0.85-21% | Blackburn & Hosking 2004 | Jikes, three CPUs |
| card 0.9%, object 1.6%, read barrier 5.4% (i7); card 1.8% on an in-order Atom | Yang et al. 2012 | Jikes |
| snapshot barrier with 20 steps per allocation: heap ≈ 1.22 × the most live data | Yuasa 1990 | analytical |
| mostly-concurrent: two 3.2 s collections → 90 pauses of 22 ms; run time 190.6 vs 184.6 s | Printezis & Detlefs 2000 | `javac`, 139 MB heap |
| Metronome: utilisation 0.44-0.45, pauses 12.3 ms, 1.6-2.5 × the live data | Bacon, Cheng & Rajan 2003 (POPL) | 500 MHz PowerPC |
| replication: longest pause 84 ms vs 988 ms; overhead < 10% on the compiler | Nettles & O'Toole 1993 | SML/NJ, DECstation 5000 |
| real-time ML collector: pauses 3-5 ms, MMU only 10-15% at 10 ms | Cheng & Blelloch 2001 | TILT, 64-way |
| OCaml slices uncapped: 1,125 ms; capped at 10 ms: heap 3.3 → 6.07 GB | Sivaramakrishnan et al. 2020 | menhir, x86-64 |
| non-moving segregated old generation: longest pause −99% | Gamari & Dietz 2020 | GHC 8.10 |
| eager sweeping ≥ 50% slower than lazy, from the cache | Boehm 2000 | Boehm collector |
| cache-conscious placement: 14-37% faster than Cheney's order | Chilimbi & Larus 1998 | Cecil |
| at 10 MB of RAM: full collection 63 s, mostly-parallel 329 ms | Boehm, Demers & Shenker 1991 | Cedar, SPARCstation 2 |
| under paging, GC 10-15 × slower than malloc | Hertz & Berger 2005 | Java, 36-63 MB RAM |
| object compression: peak heap demand −35% (16-54%) at < 2% cost | Chen et al. 2003 | KVM |
| an extra header word: +2.5% total time | Shahriyar et al. 2012 | Jikes |

### What transfers to Rune

1. **Keep a copying nursery; do not copy the old space.** Every study
   that varies the mature space finds bump-allocated young objects and a
   non-moving or space-efficient mature space best when memory is
   tight; Appel's γ ≥ 3 is what a copying old space costs, and a small
   32-bit target cannot pay it.
2. **Mark-region or segments for the old space,** with the line size
   derived from Rune's objects (two to four words, not Java's), a small
   evacuation headroom, and promoted objects bump-allocated into free
   lines -- free lists cost the mutator (RC Immix, SML#) and make
   promotion slower (Alligator, CMS).
3. **Defragment occasionally, never routinely,** by opportunistic
   evacuation, or a one-pass table-driven compaction (2-4% of the heap
   in tables); threaded compaction is a loser as a routine compactor and
   acceptable as a rare fall-back when there is no room for anything
   else (McGachey and Hosking).
4. **Measure the nursery's size, starting at L2.** The small-machine
   studies favour a cache-sized nursery, the large-heap ones 4-8 MB for
   the fixed root cost; Rune's survival is higher than SML/NJ's, and its
   roots include a deep stack.
5. **Promote by address and by volume, not by counts:** a high-water
   mark for one collection of aging, adaptive by survivor volume (Ungar
   and Jackson); keep strings and raw arrays out of the nursery's copy,
   and allocate large arrays old.
6. **A large-object space of block groups**, never copied, freed by the
   block, with no contiguous reservation.
7. **One barrier, cheap, filtering in line:** an object-remembering bit
   or a card mark costs 1-2%; remembered sets beat cards at collection
   time (Hosking et al.); the same hook can feed the remembered set and
   incremental marking. Inline the fast path only. In-order 32-bit cores
   pay twice for card marks.
8. **Short pauses on one thread are incremental marking of the old
   space, interleaved with minor collections, with lazy sweeping**
   (Doligez and Leroy's uniprocessor form; Boehm). A non-moving old space
   needs no read barrier. A snapshot barrier needs no final re-mark and
   lets new objects be allocated black; an incremental-update barrier can
   share the card table but needs a mod-union bit and a final rescan.
9. **Pace by allocation, cap each slice, measure MMU with the pause
   percentiles,** start cycles early and fall back to finishing a cycle
   -- on 32-bit there is no heap to grow into.
10. **Deep stacks need generational stack scanning** once collections
    are frequent: TIL's markers cut GC time 13-74%, since stack scanning
    was up to 95% of it.
11. **Small machines punish full-heap traversals:** size the heap
    against the memory available, return empty blocks, keep metadata in
    side tables or block headers.
12. **Collector state in spare header bits or side tables, not a new
    header word;** size classes spaced at 1/8 bound internal waste to
    12.5%, where power-of-two classes waste up to half; the whole
    incremental, defragmenting design can fit in about 1.1 times the
    live data (MC²).
13. **Pretenuring by site is cheap and pays** (GC time down 12-50% in
    TIL, 20-32% in Jalapeño), since Rune's compiler knows its sites and
    its own build is the profile.

## What the implementations do

The collectors of the runtimes under `/home/ruud/reference`, read for
this roadmap (`heap-layout.md`'s section of the same name surveyed their
headers, tags and floats, and is not repeated). Every path below is
relative to `/home/ruud/reference`; within a runtime's paragraph, a path
after the first is relative to that runtime's directory. Versions: OCaml 4.14.4 and 5.5.1,
MLton 20241230, SML/NJ 2026.2 and 110.99.9, Poly/ML 5.9.2, MLKit 4.7.23,
Chez 10, GHC 9.14.1, Go 1.27.1, HotSpot at about JDK 27, Dart 3.13.4,
Julia 1.13, CPython 3.14.7. Nothing was built or run; the claims rest on
the code, and the ones the decisions lean on -- the barriers' fast
paths, the rules for copying or marking, the pacing formulas, the stack
at a minor collection -- were read twice. The .NET collector, PUC Lua's
`lgc.c` and Whippet are not in the tree.

Seven things differ from what is commonly written about these
collectors, each checked in the tree: MLton's cross map records the
*last* object that starts in a card, not the first
(`mlton/runtime/gc/generational.h:40-46`); Spur has no incremental
collector (`shutDownIncrementalGC:` is a stub) and its default compactor
is the sliding one, not the selective one; OCaml 5 compacts only when
`Gc.compact` is called and has no `max_overhead`; Shenandoah's
allocation pacer was deleted in July 2025, and HotSpot G1's post barrier now
swaps two card tables; CPython 3.14.0-3.14.4 shipped an incremental cycle
collector that 3.14.5 took out again "due to ... significant memory
pressure in production environments"
(`python/MetaPython/Doc/whatsnew/3.14.rst:961-990`); PyPy's marking step
is four nurseries in the code (`incminimark.py:505`) where its
documentation says two; and Dart's incremental marking runs only inside
a concurrent cycle, so with no marker tasks its old space is collected
stopping the world.

### The table

"Minor" is a collection of the youngest generation; "w" is words.

| Runtime | Nursery and promotion | Old space | Fragmentation | Large objects | Barrier and remembered set | Incremental, and its pacing | Metadata | Sizing, return to the OS | 32-bit | The stack at a minor |
|---|---|---|---|---|---|---|---|---|---|---|
| OCaml 4.14 | 256 Kw (2 MB) bump-down; every survivor promoted at its first minor | incremental mark-sweep over a best-fit free list (16 exact lists and a splay tree) in `malloc`'d chunks | coalescing in the sweep; threaded sliding compaction when free/live > `max_overhead` 500% | > 256 w into the major free list | out-of-line `caml_modify`: slots in `ref_table`; the overwritten value darkened while marking | a slice per nursery fill, asked for at half; work ∝ words promoted, at most 0.3 of a cycle a slice | 2 colour bits | chunks grow ≥ 15%; freed only after compaction | yes | whole; POWER stops at a return-address bit |
| OCaml 5.5 | 256 Kw per domain in one reservation; every survivor promoted | concurrent mark-sweep; 32 KB pools in 32 size classes ≤ 128 w; lazy sweep | classes waste ≤ 10.1%; compaction only on `Gc.compact` | ≥ 128 w `malloc`'d, freed by the sweep | deletion barrier while marking, `major_ref` slots | `alloc_counter` against `work_counter`; one budget for mark and sweep | 2 colour bits, meanings rotated each cycle | a pool at a time; unmapped only by compaction | bytecode only | arm64, POWER, RISC-V: a return-address bit; amd64 whole |
| MLton | none while roomy; when tight, the upper half of the free space; first survival | Cheney while heap and maps fit in half the RAM, else mark-compact (Deutsch-Schorr-Waite + Jonkers) | both compact | sequences ≥ 1 MiB straight to the old generation | unconditional `card[obj >> 8] = 1`; 256 B cards and a cross map | none | header mark bit, 11-bit counter | from live/RAM; `munmap`/`mremap` the tail | yes, with an address-hint search | whole |
| SML/NJ | 512 KB arena; aging by a high-water mark, two collections a generation; 5 generations | copying generations, an arena per kind | copying | code mark-swept; raw > 512 w into generation 1 | store list in the nursery; byte cards (256 B) holding the youngest generation, on the array arena | none | a 16-bit arena id per BIBOP page | ratio-sized arenas | legacy tree | no stack (CPS) |
| Poly/ML | 1 MB allocation spaces; first survival | parallel mark, compacting copy, update | compaction at every major | own space | none: every mutable area a minor root | none | header mark bit + a bit a word | a cost model aiming at 1/9 GC time, with a paging term | yes, and 32-in-64 | whole |
| MLKit | regions of 8 KB pages, collected by copying | copying in regions | copying | > a page `malloc`'d, mark-swept | none: old refs and arrays are minor roots | none | tag bit, a page bit | heap-to-live 3; never returned | historical | whole |
| Chez 10 | bump through 16 KB segments; collect every 8 MB (4 MB on 32-bit); a generation up per collection, 0 to 4 | copying generations, the oldest marked in place segment by segment | evacuate segments < 75% live or in chunks < 25% used | whole segments; > 128 segments immobile | store buffer below the top of the allocation segment; byte cards (512 B) = youngest generation pointed to | none | a `seginfo` per segment: 32 card bytes, a lazy bit-per-word mark mask | empty chunks freed above a reserve ratio of 1.0 | 8 KB segments, 256 B cards, a flat table | the current stack segment only |
| GHC 9.14 | 4 MB per capability; ages one collection, promoted at the second survival | copying; `-c` Jonkers; `-w` mark-region; `-xn` non-moving | block coalescing; mark-region evacuates blocks < 3/4 live | ≥ 3276 B in its own block group, relinked | per-generation mutable lists; dirty info pointers; cards of 128 elements on arrays | none without threads; concurrent non-moving mark with them | 16 flags per 4 KB block descriptor; non-moving a byte a cell | old generation to 2 × live; `-Fd` returns memory | wasm32: 64 KB megablocks | a dirty bit per 32 KB stack chunk |
| Spur (Pharo) | eden + 2 survivors (5:1:1), 4 MB (32-bit) / 7 MB; tenures the oldest 10% when a survivor space is > 90% full | segmented free lists; stop-the-world mark | sliding by default; selective evacuation of segments < 81% full | > 65535 slots allocated old | `isRemembered` bit; a set of old objects | none | isMarked, isRemembered, isPinned, isGrey | 16 MB headroom; full collection at +1/3 growth | yes; a 1 GB window | whole |
| Dart 3.13 | semispaces of 512 KB pages, 2 → 16 MB (1 → 8 MB on 32-bit); second survival; early tenuring at ≥ 66% | 512 KB pages, 128 exact free lists; concurrent mark and sweep | incremental evacuation of pages ≤ half live | ≥ 64 KB on large pages | header-bit shift and mask; a store buffer of objects; cards on arrays > 256 KB | concurrent tasks; mutator assist of 1.25 × allocation | 6 tag bits | aims at 80% utilisation, 3% time | smaller defaults; IA32 never compacts | whole |
| PyPy incminimark | half the last-level cache (4 MB fallback); not zeroed; first survival | incremental mark-sweep; arenas of 8 KB pages, a class per word ≤ 35 w | none (fullest arena first) | > 132 KB raw, carded | `TRACK_YOUNG_PTRS` flag; a list of objects; 128-element cards | a step per minor: mark max(4 × nursery, 2 × survivors), sweep 3 × nursery | 13 header flags | 1.82 × live, ≤ 1.4× a cycle | 4 KB pages | a frame's mask: only frames pushed since the last minor |
| SpiderMonkey | 256 KB-64 MB, sized by promotion (2%) and duty (1%); all tenured; pretenuring by site | incremental mark, background sweep; 4 KB arenas of one kind in 1 MB chunks | compaction in shrinking collections, least-full arenas | cells ≤ 255 B; buffers ≥ 1 MB from the OS | post barrier by a chunk test; typed store buffers; snapshot pre-barrier | 5 ms slices (embedder), a slice per 1 MB allocated | side bitmap, 2 bits per 8 B | growth 1.5; `madvise` per page | same | whole |
| V8 | semispaces 1-32 MB; second survival (age mark) | concurrent mark-compact on 256 KB pages | evacuate pages ≥ 70% free | > 128 KB in a large-object space | page-flag tests; per-page slot sets | 1-5 ms steps on a 500 ms schedule | side bitmap | growth for 97% utilisation | ia32, arm kept | whole |
| JavaScriptCore | no physical nursery: eden = unmarked; first survival | 16 KB blocks, 16 B atoms; mark-sweep | none; blocks > 90% live retired | > ~8 KB `malloc`'d | source `CellState` → grey, pushed | concurrent (Riptide); sweeper 10 ms in 100 | versioned side bitmaps; a state byte | ×2 / 1.5 / 1.24 | stop-the-world on 32-bit | conservative, whole |
| Julia 1.13 | no nursery: 2 sticky header bits; second survival | 16 KB pages, 49 classes ≤ 2032 B | none | `malloc`'d lists | parent old-marked and child young | parallel stop-the-world mark | 2 header bits | MemBalancer | yes | whole |
| Go 1.27 | none | concurrent non-moving mark-sweep; 8 KB pages, 68 classes | none | > 32 KB own span | Yuasa + Dijkstra, a 512-entry buffer | 25% of a processor + allocation assists | alloc and mark bitmaps | goal + 10% resident | 4 MB arenas | each stack once a cycle |
| HotSpot Serial | eden + 2 survivors; ages ≤ 15 | contiguous tenured space; sliding full collection | 5% dead wood, full compaction every 4th | old if larger than young | `card[addr >> 9] = 0`, 512 B cards | none | 4 age bits | free ratios 40/70 | ARM32 | whole |
| HotSpot G1 | young regions | regions 1-32 MB; mixed evacuation | skip regions > 85% live | humongous > half a region | region filter + conditional card; SATB | 200 ms pause goal | side bitmap | asynchronous uncommit | ARM32 | whole |
| SubstrateVM | eden + up to 15 survivor ages; 512 KB chunks | compacting in place | sliding | arrays ≥ 128 KB own chunks | a header filter bit + 512 B cards | none | 3 header bits | a free-chunk reserve | 64-bit only | whole |
| LuaJIT 2.1 | none | incremental mark-sweep over `malloc` | `malloc` | `malloc` | forward barrier; backward for tables | stepmul 200, pause 200 | marked byte, two whites | `malloc` trim | low 2 GB | whole |
| Erlang/OTP | per-process young heap; second survival (high-water mark) | per-process copying | copying | binaries > 64 B refcounted off-heap | none: immutable | none | move marker | Fibonacci then +20% | yes | whole |

Koka (Perceus, reference counting with reuse), Wasmtime (deferred
reference counting, a semispace or none), Guile 3.0.11 (Boehm; Whippet's
Immix-like `nofl` only on a branch), Swift (ARC) and CPython (reference
counts and a generational cycle collector) are outside the design space
of a precise tracing collector for an ML and are left there.

### Ten in more detail

**OCaml 4** (`ocaml4/runtime/{minor_gc,major_gc,freelist,compact,memory}.c`)
is the closest template: one thread, an ML, a copying minor heap and an
incremental old one, on 32-bit too. The minor heap is 256 Kw (2 MB, 1 MB
on 32-bit), allocated downwards; reaching its middle asks for a major
slice and its start for a minor collection (`minor_gc.c:46-61`). Every
survivor is promoted. One out-of-line barrier, `caml_modify`
(`memory.c:617-655`), serves both invariants: it remembers the slot when
an old object gets a young value, and darkens the overwritten value
while the major collector marks (a Yuasa deletion barrier). Objects
allocated during marking are black. A slice owes the fraction of a cycle
that the words promoted since the last one stand for, at most 0.3 with a
backlog (`major_gc.c:943-1107`). The free list has been best-fit since
4.13 (16 exact lists, a splay tree; next-fit 28 s/855 MiB, first-fit
47 s/566 MiB, best-fit 27 s/545 MiB on the documented comparison,
`gc.mli:186-188`). When free over live passes 500% at the end of a cycle,
confirmed after another, the heap is compacted by threaded sliding
(Jonkers), which is the only way it gives memory back
(`compact.c:466-501`). The stack is walked whole at every minor, but on
POWER, where a bit in a frame's saved return address says it was scanned.

**OCaml 5** (`ocaml5/runtime/{shared_heap,major_gc,minor_gc}.c`,
`caml/sizeclasses.h`) replaced the free list with pools of 4096 words
(32 KB; 16 KB on 32-bit) of one size class each, 32 classes up to 128
words with at most 10.1% waste, swept lazily when a pool is wanted; a
larger object is `malloc`'d and freed by the sweep. Its two colour bits
change meaning at each cycle (`MARKED`, `UNMARKED`, `GARBAGE` rotate),
so no pass ever turns the survivors white again. Marking and sweeping
share one budget, `alloc_counter` against `work_counter`, in words of
allocation (`major_gc.c:863-1078`). A minor collection stops at the
first frame whose return address carries a mark bit -- on arm64, POWER
and RISC-V; amd64 walks every frame (`fiber.c:278-296`). Compaction is
only on request.

**Chez Scheme** (`ChezScheme/c/{gc.c,segment.c,segment.h}`,
`s/cmacros.ss`; the design paper is Dybvig, Eby and Bruggeman's 1994
TR400, `papers/TR400.pdf`) is the closest non-Immix example of a
segmented, marked-in-place old space, and runs on 32-bit with no tricks.
Segments are 16 KB with 512 B cards (8 KB and 256 B on 32-bit), 32 cards
a segment, described by a side table. Each segment has a space -- pure,
impure, data (never scanned), code, and others -- and a record type with
no mutable field goes to the pure space, where a dirty card is an error:
for SML, tuples and constructors are pure, refs and arrays impure. A card
byte holds the youngest generation it may point to, which the collector
writes back after sweeping it; Reppy measured that for SML/NJ at about
80% fewer cards swept than a plain dirty bit. The barrier logs the
address in a buffer that grows down from the top of the thread's
allocation segment while allocation bumps up. The oldest generation is
marked in place, segment by segment, except that a segment found under
75% live, or in a chunk under 25% used, is evacuated instead
(`gc.c:1008-1045`); a marked segment's holes are not reused until a later
collection evacuates it. Stacks are segments of about 64 KB whose older
frames become immutable continuation objects that a minor never scans
again.

**Spur** (`smalltalk/pharo-vm/.../SpurMemoryManager.class.st`,
`SpurGenerationScavenger`, `SpurSelectiveCompactor`) is Ungar's
scavenger -- eden and two survivor spaces, 5:1:1, 4 MB on 32-bit -- in
front of a segmented old space with free lists. It tenures the oldest
tenth of a survivor space when the other is over 90% full, and has an
object-granular remembered set flagged by an `isRemembered` header bit;
the JIT's barrier skips immediates, compares the address with the
spaces' bounds, tests the bit, and calls. Its selective compactor
evacuates segments under 81% occupied and fixes the pointers to them
lazily at the next mark. Every frame is scanned at every scavenge.

**Dart** (`dart-lang/sdk/runtime/vm/heap/`, `runtime/docs/gc.md`) has
the one barrier for two invariants: the source's tag byte shifted by two
and masked with the target's and the thread's mask
(`raw_object.h:826`; on x64 `movb; shrl 2; andl [THR+mask]; testb
[value.tags]; jz`). The mask is generational alone, and generational and
incremental while marking. A store is barrier-free when the compiler
shows the value immediate or the object just allocated, made safe by
re-remembering live temporaries after a scavenge. The scavenger promotes
at the second survival by an address watermark, everything when two
thirds survive. The incremental compactor picks pages at most half live
at the start of marking and evacuates them in the last pause, capped so
that pause stays near the scavenger's longest. Marking runs at 20 words
a microsecond and scavenging at 40 on a phone, by its comments.

**MLton** (`mlton/runtime/gc/`) chooses its collector by memory: copying
while the heap and its maps fit in half the RAM and a second space can be
had, Deutsch-Schorr-Waite marking and Jonkers compaction -- no mark
stack, O(1) extra memory -- when not (`garbage-collection.c:28-35`,
`heap.c:40-146`). Its generational mode runs only when memory is tight:
with the heap at eight times the live data, minors are off. The barrier
is two unconditional instructions on the object's base, so a store into
a large array rescans the whole array. On a 32-bit machine with a
fragmented address space it searches for a heap with address hints and
grows by copying 32 MiB at a time while it unmaps behind itself.

**PyPy incminimark** (`python/pypy/rpython/memory/gc/incminimark.py`,
`minimarkpage.py`) is the one-threaded nursery-plus-incremental-old
space in readable form. The nursery is half the last-level cache. The
barrier tests one header flag of the source and remembers the object
once per minor cycle; at each minor while marking, the remembered
objects are greyed again (Steele's barrier, applied in a batch), so the
same flag serves both invariants -- which holds only because the one
mutator stops at every minor. A major step follows every minor. And the
stack has a watermark: each frame's mask word is negated by the minor
that scans it, the next minor stops at the first negative one, and
compiled code makes it positive again whenever it pushes. Its stated
goal is no pause over 1 ms, with "occasionally ... pauses between
10-100ms" (`pypy/doc/gc_info.rst:25-28`).

**SpiderMonkey** (`javascript/SpiderMonkey/src/gc/`, `src/doc/gc.md`)
has the clearest incremental snapshot marking in slices: a pre-barrier
that is "usually just an extra branch", objects allocated black, slices
of a time budget (5 ms in browsers) due every megabyte allocated, and a
fall-back to finishing at once past 1.1 to 1.7 times the start
threshold. Arenas of 4 KB hold one kind; marks are in a side bitmap, two
bits per 8 B; the nursery is sized by promotion rate and duty; sites
whose objects are 90% promoted after 200 allocations are pretenured.
Compaction runs only in shrinking collections, moving the least-full
arenas into the free cells of the rest.

**GHC** (`ghc/rts/sm/`) shows a block-structured heap (4 KB blocks, 1 MB
megablocks, 64 KB on wasm32 where 6.25% of each is lost to descriptors),
aging for one collection by block destination, large objects promoted by
relinking their block group, and a dirty flag per 32 KB stack chunk so
that a minor skips a chunk not run since it was scanned. Its non-moving
collector (Ueno and Ohori's design: 32 KB segments of one cell size, a
mark byte a cell compared with an epoch, a snapshot barrier) is, in the
non-threaded runtime, a stop-the-world mark-sweep with size classes, and
nothing defragments it.

**Julia and JavaScriptCore** (`JuliaLang/julia/src/gc-stock.c`;
`javascript/JavaScriptCore/heap/`) are generational without moving:
"sticky" marks survive a minor collection, which traces only what is
not yet marked old from the roots and a remembered set. Julia's two
header bits promote after two survivals and its barrier tests source and
target; JSC's barrier tests the source's state byte alone, its marks are
versioned side bitmaps cleared in O(1) by bumping a version, and its
concurrent marker is off on 32-bit. Neither can compact.

### Numbers and rules

| Question | What the implementations do |
|---|---|
| **The nursery's size** | SML/NJ 512 KB, chosen where total time was least, at the secondary cache's size (Reppy); OCaml 2 MB (1 MB on 32-bit); GHC 4 MB, with a warning that 4 MB or more can be slower single-threaded; PyPy half the last-level cache; Chez a collection every 8 MB (4 MB on 32-bit); Spur 4-7 MB; Dart 2-16 MB (1-8 MB on 32-bit); SpiderMonkey 256 KB-64 MB by promotion and duty. Wilson, Lam and Moher (1992): capacity misses vanish once the cache is a little larger than the nursery's reuse cycle |
| **Promotion** | at the first survival: OCaml, MLton, Poly/ML, PyPy, SpiderMonkey, JSC, Chez (one generation a collection); at the second by an address watermark, with no header bit: GHC, V8, Dart, Erlang, SML/NJ; by header bits: Julia; counted ages: HotSpot (≤ 15), SubstrateVM |
| **Units** | Chez segments 16 KB (8 KB on 32-bit); OCaml 5 pools 32 KB (16 KB); GHC blocks 4 KB, non-moving segments 32 KB; SpiderMonkey arenas 4 KB; JSC and Julia 16 KB; Go 8 KB pages; PyPy 8 KB pages (4 KB); Dart 512 KB pages; Whippet's Immix-like `nofl`: 16 B lines, 64 KB blocks |
| **Size classes** | OCaml 5: 32 up to 128 words, ≤ 10.1% waste (1 2 3 4 5 6 7 8 10 12 14 16 17 19 22 25 28 32 33 37 42 47 53 59 65 73 81 89 99 108 118 128); GHC non-moving: 16 from 8 to 128 B, then powers of two; PyPy one a word to 35; Julia 49 to 2 KB; Go 68 to 32 KB |
| **Large objects** | OCaml 5 ≥ 1 KB; GHC ≥ 3.2 KB; OCaml 4 > 2 KB; SML/NJ > 4 KB; Julia > 2 KB; JSC > 8 KB; Go > 32 KB; Dart ≥ 64 KB; V8, PyPy > 128 KB; MLton ≥ 1 MiB. Most never move them, and promote them by relinking |
| **Cards** | 256 B: MLton, SML/NJ, Chez on 32-bit; 512 B: Chez, HotSpot, SubstrateVM; 128 elements: GHC, PyPy arrays. A card byte holding the youngest generation pointed to: Chez, SML/NJ. A remembered set of objects deduplicated by a header bit or state: Spur, PyPy, Dart, Julia, JSC |
| **Compaction and evacuation** | Chez: segments < 75% live; Dart: pages ≤ 50% live, bounded; V8: pages ≥ 70% free; Spur: segments < 81% full; GHC `-w`: blocks < 3/4 live; HotSpot G1: skip regions > 85% live; OCaml 4: free/live > 500%; MLton: live > RAM/8, whole heap |
| **Pacing** | by allocation: OCaml (a slice per nursery fill, a fraction of a cycle ∝ promotion), PyPy (a step per minor), LuaJIT, Racket, Dart's and Go's assists; by time: SpiderMonkey's slices, JSC's sweeper, idle collections in Dart and V8. Only the first kind collects at the same points in every run |
| **Growth and memory** | OCaml 4: ≥ 15% a step, memory back only after compaction; GHC: old generation to 2 × live, returned after idle collections; Chez: free segments ≤ 1 × in use; PyPy: 1.82 × live, ≤ 1.4× a cycle; MLton: 8 × live when RAM is plentiful, down to 1.04 ×; Spur: a full collection at +1/3 |
| **Header bits** | OCaml 2 colour bits; Spur marked, grey, pinned, remembered; Dart 6; Julia 2; HotSpot 4 age bits; SubstrateVM 3. Side metadata instead: Chez (per segment), GHC (per block), SpiderMonkey and V8 (bitmaps), JSC (versioned bitmaps) |

**The stack at a minor collection.** Only four scan less than the whole
stack: OCaml 5 (a bit in the saved return address, on three machines),
PyPy (a frame's mask negated when scanned, restored at every push), GHC
(a dirty flag per 32 KB chunk) and Chez (older frames split off into
immutable continuations). All rest on one rule: a frame a minor
collection scanned cannot point into a later nursery unless it is
written again. So "written since it was scanned?" must be a bit the
mutator clears for nothing: the return in OCaml, the push in PyPy, the
scheduler in GHC. Rune's register VM writes a waiting frame's registers
only when the frame runs again, so PyPy's shape fits: a bit set by the
minor collector and cleared when the frame is re-entered, with
`VM.frame_live` giving the roots of the frames scanned (D9; the property
is measured in *The experiments*, not assumed).

### What fits Rune

For a single-threaded ML that must run frugally on 32-bit, the designs
that fit share three properties: they reserve no address space they will
not use, they keep no second copy of the old space, and their cost
follows what changed, not what is live. That rules out a copying old
space -- which doubles the old generation and is the copier's cost today
-- and the reservations of OCaml 5 (256 MB for minor heaps), GHC (1 TB),
Dart (a 4 GB cage) and SpiderMonkey (1 MB-aligned chunks, whose alignment
it counts as its cost on 32-bit).

The closest fit is Chez's design scaled to an ML: a small contiguous
nursery near the size of a cache; an old space of segments of 8 to 32 KB
described by a side table, the segment the unit of everything (its
space -- immutable, mutable, raw, large --, its card bytes, a mark
bitmap made lazily); the old space marked in place with sparse segments
evacuated (Chez's 75%, Dart's half, Spur's 81%); and MLton's mark-compact
with O(1) extra memory as the fall-back when there is no room left even
to evacuate. SML's own statistics make the barrier cheap: mutation is
rare, immutable data can live in segments that never need cards, and
the remembered set of the bootstrap is small (*The experiments*). Either
Chez's youngest-generation card bytes on mutable segments alone, or an
object list deduplicated by the header's remembered bit (Spur, PyPy),
would do. Promotion at the second survival needs no header bit with an
address watermark; pacing by allocation, a slice per minor, keeps the
schedule deterministic; and a frame bit bounds the stack's cost at a
minor.

What would not block the third generation's threads: allocation areas
per thread over a shared segmented old space (OCaml 5, GHC, Chez, Go
and Dart all converged on that, and `AllocState` is its shape); a
snapshot barrier for incremental marking, which OCaml kept from 4 to 5
and a concurrent marker needs anyway; marks in side bitmaps or bytes per
segment, which atomic byte operations can set later without racing the
mutator's header writes; colours that rotate or carry a version (OCaml
5, JSC, GHC's epochs), so a sweep never rewrites headers. What would:
Poly/ML's and MLKit's scan of every mutable object at every minor, whose
cost grows with the mutable data and would be paid by every thread;
bits set with plain stores where two threads may race; PyPy's
regreying at the minor, which holds only because the one mutator
stops; and pacing by time, which would also cost Rune its determinism.

## The candidate collectors

Seven design points, each a nursery (or not) and an old space; any of
the non-moving ones can have its marking made incremental (D7), and any
can have a large-object space (D5). They are the points the simulator
models (*The experiments*); their numbers are there, and what each costs
the rest of Rune is here.

### G0: the copier

Today's: two semispaces, everything live copied at every collection
(*Where we are*). Simple, compacting, cache-friendly allocation and
copying in breadth-first order, no barrier. Its costs are the brief's
complaints: memory (two semispaces held, three for the length of a
collection that grows the heap; on 32-bit the live data a process can
keep is a fraction of its address space), pauses that grow with the live
data (73-96 ms on the bootstrap, 5.1 s on Rune compiling MLton), and the
compiler's long-lived data copied at every collection. It is the
baseline every candidate is measured against, and the fall-back the
others keep for a full collection until M5.

### G1: a nursery in front of a copying old space

Appel's simple generational collector (1989): a fixed nursery,
survivors copied into an old space that is itself a semispace copier.
It is the smallest change -- `AllocState` points at the nursery, the
barrier gets a body, the copier stays as the major collection -- and it
is the calibration prototype of this roadmap. It makes minor pauses
short and independent of the old space's size, and copies the
long-lived data only at majors. It keeps the copier's memory (two
semispaces for the old space) and its major pauses. On its own it does
not answer the brief's "memory efficiency", but it is the first half of
every other candidate.

### G2: a nursery, and a segregated mark-sweep old space

OCaml 5's design on one thread: the old space in pools of one size
class each, marked in place (in a side bitmap or the header's bits),
swept lazily into the free lists of their class; large objects apart.
It holds the old generation once, with the classes' internal waste
(about 10% by OCaml's table) and the free cells between survivors
instead of a second copy. It does not move objects, so it never
compacts unless a compactor is added; fragmentation is bounded by the
size classes for small objects and is the large-object space's problem
for the rest. Pinning is free. Its cost is the sweep (proportional to
the heap, made lazy) and allocation from free lists where the nursery
bumps; promotion copies a survivor into a cell of its class.

### G3: a nursery, and a mark-region old space (Immix)

Blackburn and McKinley's Immix (2008): the old space in blocks of 32
KB cut into lines of 128 or 256 B; marking sets object marks and line
marks; free lines are bump-allocated into; a block whose holes cost too
much is evacuated opportunistically during a later marking, given some
headroom. It keeps the locality of bump allocation and of objects
allocated together, compacts only what is fragmented, and its metadata
is a byte a line. Promotion bumps survivors into free lines in the order
they are copied. A medium object that does not fit a hole goes to an
overflow block. Its costs are the line granularity (a live object keeps
its whole line, and the next line by the conservative marking rule) and
evacuation, which needs a forwarding and a barrier-free moment, which a
single thread has at every major.

### G4: sticky mark-region, no copying nursery

Sticky Immix (Shahriyar et al. 2013), and what Julia and JSC do with
mark-sweep: young objects are allocated into the old space's free lines
and become old by keeping their mark bit; a minor collection marks only
what is unmarked from the roots and the remembered set, and frees the
rest. Nothing is copied at a minor and there is no nursery to size, so
the memory is one space; but young objects are spread over the old
space's holes, a minor must find and clear its young lines, and the
allocation is never as dense as a nursery's. It tests whether copying
the young pays at all for Rune's survival.

### G5: a nursery, and mark-compact (MLton's hybrid)

The old space marked and compacted by sliding (Lisp-2, or Jonkers'
threading with no extra space), possibly chosen at each major against
copying by how much memory is left, as MLton does. Sliding keeps the
allocation order, so locality, and needs no free lists; it costs two or
three passes over the heap at every compacting major. On 32-bit it is
the collector that can still collect when there is no room for a copy or
for evacuation headroom.

### G6: Chez's segments, copied or marked per segment

The old space in segments described by a side table, each segment
copied out when sparse and marked in place when dense (Chez: evacuate
under 75% live); immutable and mutable objects in segments of their own,
so only mutable segments carry cards. It is G3 with segments for blocks
and a decision per segment for opportunistic evacuation, with the space
of each segment as the place to put mutability, rawness and size.

### What each needs from the rest of Rune

| | G0 | G1 | G2 | G3 | G4 | G5 | G6 |
|---|---|---|---|---|---|---|---|
| a barrier with a body | -- | yes | yes | yes | yes | yes | yes |
| the old value at a store (incremental marking) | -- | -- | if incremental | if incremental | if incremental | if incremental | if incremental |
| mark bits (header or side table) | -- | -- | yes | yes, and line marks | yes, sticky | yes | yes, per segment |
| spaces that are not contiguous (images, `heap_relocate`, `heap_is_young`) | -- | two | yes | yes | yes | -- | yes |
| allocation from free lists or holes at promotion | -- | -- | free lists | holes | holes, for every object | -- | holes |
| a fast path changed | -- | the limit | the limit | the limit | holes in the fast path | the limit | the limit |
| moving objects | all | all | none | some | some | all, at majors | some |
| pinning | copy around a call | copy | in place | in place (no evacuation of the block) | in place | copy | in place |

## The experiments

Five pieces of evidence were made for this roadmap, in copies of the tree
at `ca87fa07`, between 2026-10-05 19:30 and 2026-10-06 18:45: the census
VM ported to the word layout and the traces it made; a simulator that
replays them under every candidate collector; a C harness that measured
what each unit of collector work costs on the reference machine; a
prototype of a nursery in front of today's copier, in the real VM; and
the copier measured as the baseline on every workload, 32-bit included,
and then the prototype on the same workloads. Everything they made is
kept under `~/.cache/claude-rune-drafts/gc2/` (its `README.md` says what
is where; the traces are archived on `/mnt/h/HEAPSIM/gc2/`), and M1
brings the tools into the tree. The numbers below name the file under
`results/` that has them with the command that made them.

The reference machine is a Xeon E5-1680 v3 (Haswell) under WSL2: L1d 32
KiB, L2 256 KiB, L3 20 MiB shared, 31 GB. Two of its properties matter to
a collector and are this machine's, not the design's: the hypervisor
backs the guest with 4 KiB pages, so the second-level TLB reaches only 4
MiB (random loads past 4 MiB of working set pay a nested page walk, 84-94
ns, and transparent huge pages extend the reach only to about 7 MiB); and a page
touched for the first time costs a hypervisor fault of 1.6 µs. One
thread's effective L3, for data walked in order, is about 10-12 MiB
(`results/gcbench-H10.md`).

### The workloads

Fixed, with weights, before any result was in (`results/workloads-evaluation-set.md`).
Each candidate is scored on three weighted geometric means of its
ratio to the copier: **T** (task-clock), **M** (peak resident memory)
and **P** (the mean of the longest pause, the 99th-percentile pause and
1 - MMU at 10 ms):

| Workload | T | M | P |
|---|---:|---:|---:|
| the bootstrap, default tiering (and `--jit=off`) | 25 | 20 | 15 |
| `compile-sigs`, `runedoc-page` | 10 | 10 | 10 |
| MLton's benchmarks, the 35 under 2 GB (geometric mean; the worst kept) | 25 | 15 | 10 |
| MLton's 14 over 2 GB (the GC-stress tier) | 10 | 5 | 5 |
| the six lazy programs (their strict twins reported) | 5 | 5 | 5 |
| `binary-trees` at depth 18, `many_refs`, `safe-for-space`, `hamlet`, `string-concat`, `vector-rev` | 10 | 10 | 5 |
| the latency workloads (a message window of 10 MB, 100 MB, 1 GB live, as a ring and as a map; a 200 MB static map with requests) | 0 | 10 | 40 |
| Rune compiling MLton (MLton `5fe943391`, 219 GB allocated, up to 3.3 GB live) | 15 | 20 | 5 |

(The M and P columns sum to 95, an arithmetic slip found after the set
was fixed; the scores divide by the weight present. The MMU part of P is
taken as 1 - MMU, since the copier's MMU at 10 ms is zero on most
workloads, and pauses under 1 ms count as 1 ms.)

The latency workloads were written for this roadmap
(`workloads/latency/`), in the shape of `examples/benchmarks`: a window
of N messages of 1 KiB, one added and the oldest evicted at each step --
as a ring array, so that an old array gets a young message at every step,
or as a persistent tree, with no mutation at all -- and a large static
map with requests that make garbage. They time every step with a
histogram that does not allocate, and print a digest that does not
depend on the timing, so that `--count` stays exact.

### The census on the word layout

The census VM records every object's allocation, every field, every
store into an object that exists, and when each object was last live;
heap-layout's M1 built it, and its M4 left it unbuildable on the word
layout. It was ported (a patch of 1,543 lines in 16 files) and extended:
a sample every 32 KiB of allocation instead of 256 KiB (nurseries
modelled from 128 KiB); at each sample the stack's depth, the frames, and the
lowest frame reached since the previous sample (what a stack watermark
would let a minor collection skip); the instruction count (a
deterministic mutator clock); the overwritten value's id at every store
(a snapshot barrier's traffic); optionally the pointee of every field at
allocation (the object graph). `results/A-census-report.md`.

* **54 traces**, each checked four ways -- the census's `--count` equal to
  the stock VM's, the same output, a consistency check that recomputes
  every sample's live bytes from the deaths, and the old-value ids
  against each field's history (100% on 12 traces): the bootstrap (32
  KiB and 256 KiB samples, 34.2 million objects, 898 MB, 27,225 samples,
  1.3 GB of trace, 21 minutes), `compile-sigs`, `runedoc-page`, five of
  `tests/perf`, the six lazy programs and four strict twins, and 33 of
  MLton's programs with two variants; and five of the over-2 GB tier in summary form.
* **Against the VM:** the copier's model run over the traces gives the
  same collections, semispaces and bytes as `runevm --stats` on all 55
  rows of a validation of 11 workloads at 5 heap settings, and bytes
  copied within the model's band on 54 (the 55th is 1,504 bytes off: a
  census sample keeps the running frame's dead registers as roots).
* **What it cannot see:** reads (no locality), a field filled after a
  later allocation, objects past 32 GiB of allocation. Counts depend on
  the input's kind and the compiler's output path, as heap-layout found;
  within one run the stock VM and the census always agree.

### The simulator

`tools/heapsim` gained `gcsim` (a patch of 3,598 lines): an exact nursery
(a minor collection where the next object does not fit), promotion at the
first or second survival, an address model for the old space, and eight
old spaces -- copying, mark-compact (Lisp-2 or Jonkers), MLton's hybrid,
Immix (blocks, lines, conservative or exact line marks, recyclable and
overflow blocks, opportunistic evacuation), sticky Immix, OCaml 5's
segregated fits, OCaml 4's best, next and first fit with coalescing and
its compaction trigger, and Chez's per-segment copying or marking --
with a large-object space, cards at real addresses, a mutable space
scanned at every minor, pretenuring by site, the share of marked bytes
born early, placement orders, and incremental snapshot marking paced by
allocation; and `timeline.py`, which turns its per-collection events
into pauses and MMU with the unit costs of the harness and the
prototype. `results/B-sim-report.md` and `results/sim-*.md`.

**How it was checked** (`results/sim-validation.md`): 94 checks against
traces with closed-form answers (alternate deaths leave exactly half the
slots or lines free; one survivor per line frees no line; compaction
moves exactly the live bytes; snapshot marking floats exactly the
objects that die during the cycle); exact identities with the old
simulator for the copier, its nursery and its sticky model; the copier
model against the stock VM on 146 runs (140 exact, the rest explained:
large arrays move liveness further within a sample than the band can
follow, and the census clears dead registers the stock VM keeps); the
nursery model against the prototype on the bootstrap at 256 KiB, 1 MiB
and 4 MiB -- the same number of minor collections and of full ones
(3,407 + 7, 851 + 6, 210 + 6), promoted bytes within the band (at 1 MiB,
176.5 MB against 169.1-183.8) -- and on six other programs (16 of 18
within the band; `mlyacc` at 4 MiB promotes 17.6% more in the real VM:
nepotism, dead old objects keeping young ones alive, which a model that
knows only when objects die cannot see); and its fragmentation against
the harness's replay allocators, an independent implementation fed the
same stream (segregated fits the same, best fit 2.4% apart on average and 25% at
one major, Immix 10.7% apart on average, the same ranking everywhere; `results/gcbench-fragmentation.md`).
Its modelled times are relative: against the measured copier it is 1.7
times low for a major copy, which the prototype's fit explains (a major
copies at 32 ns an object, not the harness's 8.5-26).

**Survival** (`results/sim-survival.md`). Of the bootstrap's allocation,
at promotion on the first survival (the lower and upper band):

| nursery | 128K | 256K | 512K | 1M | 2M | 4M | 8M | 16M | 32M |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| survives | 22.5-34.5% | 21.0-27.4% | 19.9-23.1% | 18.9-20.5% | 18.2-19.1% | 17.5-17.9% | 16.8-17.0% | 16.1-16.2% | 14.5% |

Lower than heap-layout's 16-byte traces said (25.7% at 1 MiB): the word
and the dead registers dropped as roots (heap-layout M5, M6) changed what
lives. Across MLton's 33 programs that allocate more than 64 MB the
median is 1.8% at 1 MiB, from nothing (`peek`) to 98% (`tsp`).

**A nursery now saves copying** (`results/sim-nursery.md`), where on the
old traces it did not: on the bootstrap a 1 MiB nursery copies 159 MB in
minor collections and 83 MB in majors, 242 MB, against the copier's 292
MB from 64 MiB (365 MB from 4 MiB); 231 MB at 4 MiB, 196 MB at 32 MiB.
Promotion at the second survival copies 55% more (376 MB at 1 MiB) and
saves one major in six: for Rune's compiler, aging does not pay.

**The stack.** At 1 MiB the bootstrap's 851 minor collections scan 5.79
million stack slots; a watermark (scan only frames that ran since the
last minor collection) leaves 0.89 million: 85% less. At the census's
samples, 95.9% of the bootstrap's scanned slots, 98.2% of `hamlet`'s and
99.2% of `knuth-bendix`'s were in frames unchanged since the previous
sample (`results/lead/stackdepth.txt`).

**The remembered set** (`results/sim-remset.md`). At 1 MiB at most 21,340
slots between two minor collections (455,000 over the run) and 510 cards
of 512 B; 811,000 stores made an old object point at a young one (315,000
by `:=`, 496,000 by `Array.update`) of 3.37 million stores into old
objects; `SETENV` never does at 256 KiB and above. A space for mutable
objects scanned at every minor (Poly/ML's way) would scan 5.39 GB over
the run, 21.8 MB at most at one minor: not for Rune (`results/sim-mutable.md`).

**Old spaces** (`results/sim-oldspaces.md`), each behind a 1 MiB nursery:

| old space | bootstrap: peak committed / most live, no limit | majors at a limit of 1.25 × / 1.5 × the most live | median (worst) peak / most live, the 12 traces with ≥ 4 MiB live |
|---|---:|---:|---:|
| copying | 4.25 | does not fit | 3.63 (7.10) |
| mark-compact | 1.42 | 5 / 4 | 1.12 |
| Immix | 1.84 | 25 / 17 | 1.13 |
| Chez's segments | 1.97 | 29 / 27 | 1.15 |
| segregated fits | 1.76 | 57, overflowing the limit / 9 | 1.21 |
| best fit | 1.48 | 5 / 4 | 1.48 |
| next fit | 2.23 | -- | 1.81 |
| MLton's hybrid | 6.49 | -- | 2.48 |

(Without a limit a space grows by its trigger, so the bootstrap's peaks
include slack; the median over the traces with live data to speak of,
and the majors at a fixed limit, are the comparison.) What does not copy
holds the old generation in 1.12 to 1.21 times its live data, where
copying holds 3.6 times; mark-compact is the tightest and the slowest
(its modelled GC time 2.6 times Immix's), Immix and segregated fits are
cheap, and at a tight limit segregated fits thrash where Immix and the
compactors do not.

**Fragmentation** (`results/sim-fragmentation.md`). Immix on the
bootstrap: a peak of 79.5 MB with 64-byte lines, 83.6 MB with 128, 87.3
MB with 256; exact line marking is worth the same as 64-byte lines;
evacuating the blocks with the most holes takes 7 MB off the peak for 4
MB moved; block size (16-64 KiB) barely matters, nor does the
large-object threshold (2-32 KiB) while it decides only where promoted
objects go (allocating them straight into their space is another matter,
below). The harness's replay agrees on the order: peak
footprint over peak occupancy 1.00 compacted, 1.02 best and first fit,
1.24 Immix with exact lines, 1.26 with 64-byte lines, 1.34 segregated
fits, 1.38 Immix with 128-byte lines, 1.55 next fit
(`results/gcbench-H5.md`).

**Placement order** does not matter to the footprint: placing promoted
objects in the order of a breadth-first or depth-first walk of the graph
instead of allocation order moves the peak by about 2%; only random
placement costs (12% on Immix) (`results/sim-order.md`). So the
graph is not needed for these questions.

**Incremental marking** (`results/sim-satb.md`): a snapshot cycle that
starts at three quarters of the stop-the-world trigger and marks k bytes
for every byte allocated runs 15 cycles on the bootstrap; at k = 2 the
marker is busy 20% of the time with 3.5 MB of floating garbage on
average, at k = 8, 6% with 0.5 MB; 251,767 stores log an old value, 38,305 of them a pointer to an old object.
Started at half the trigger, marking never stops. Modelled, it takes the
longest pause from 11.5 ms (stop-the-world marking of Immix) to 3.1 ms
(p99 1.0 ms; 0.44 ms for segregated fits sliced every 64 KiB) and MMU at 10 ms from 0 to 0.35, for
169 to 215 ms of total collector time.

**Pretenuring** (`results/sim-pretenure.md`): sites whose objects survived
80% of the time in `compile-sigs` pretenured 24.9 MB of the bootstrap,
saving 24.1 MB of copying for 0.8 MB of garbage (95%: 16.3 MB saved, no
garbage); learned on the bootstrap's first half, the sites predict almost
nothing of its second. Advice transfers across inputs of one program, not
across its phases.

**An image or boot space** (`results/sim-image.md`): of the bytes Immix
marks over the bootstrap, 11.7% were born in the first 1% of its
allocation, 27.6% in the first 5%, 45.0% in the first 10%.

**Large objects and the page** (`results/lead-los-threshold.md`, made on
2026-10-06 by `results/lead/los/run.sh` and `run2.sh`), over the 38
traces that allocate 16 MB or more, Immix behind a 1 MiB nursery, large
objects in runs of 4 KiB units. Allocating every object of 8 KiB or
more straight into the space, as D5 recommends, against allocating it in
the nursery and moving it there when promoted: the peak 2.5% higher at
the geometric mean, 3-8% less promoted on the compiler's traces, and one
outlier, `mlton-tensor` at 2.6 times (4.5 MB against 1.7), whose objects
of about 13 KiB die young; straight in only from 32 KiB removes the
outlier and is level on average, and costs the bootstrap 7%. From 4 KiB
instead of 8 the peak is 4% higher at the geometric mean, 8% on the
bootstrap with one major more, 2.2 times on `fxp`, 19-30% on
`wc-input1`, `wc-scanStream` and `runedoc-page`, and 3% lower nowhere.
Rounding to the operating system's pages instead of the space's units
costs the 8 KiB threshold 0.7% at 16 KiB pages and 7.5% at 64 KiB
(`mlton-tensor` 3.3 times), and the 4 KiB one 8% and 28% over the 8 KiB
one in units (the bootstrap 69%, `wc-scanStream` 4.2 times, `fxp` 15
times). A 2 MiB nursery puts the bootstrap's peak at 72 MB against 80,
and the peak of the 13 traces with 2 MB or more live 6.6% higher at the
geometric mean.

**32-bit** (`results/sim-footprint.md`): with 4-byte words and headers
the spaces of small objects roughly halve (Immix 83.6 to 43.5 MB,
segregated fits 79.9 to 41.3; best fit only 67.0 to 57.4); pointer-sized
metadata at 4 bytes changes it by about 2%. The collector's memory claims
do not need the 4-byte word, which stays `32-bit-vm.md`'s.

### The harness

`tests/gcbench` (3,990 lines of C, one binary, counters read in the
process so that the mutator and the collector are counted apart) measured
nine things on the reference machine (H1-H3, H5-H10), timed alone on one core, the least
of several runs; instructions and misses are exact, cycles carry about 10%
noise. `results/C-gcbench-report.md`, `results/coefficients.md`,
`results/gcbench-H*.md`.

* **The nursery's size** (H1: the bootstrap's object sizes and
  lifetimes): a minor collection costs least per KiB allocated between 1
  and 4 MiB (516 and 508 cycles), more below (595 at 64 KiB, from higher
  survival) and much more above (787 at 16 MiB, 860 at 32 MiB), where the
  survivors leave the cache and the TLB's reach; the mutator's cost is
  flat at 950-1,000 cycles a KiB. Prefetching ahead of the bump pointer
  changed nothing; huge pages, nothing at 1 MiB.
* **Copying and marking** (H2), cycles an object: a Cheney copy in cache
  16-19 + 0.25 a byte, in L3 in creation order the same, shuffled 30-42;
  from DRAM in creation order 26-81 at 32 B, shuffled 400-480 (a miss an
  object), 2.3 times faster with prefetch on a tree; marking in cache
  7-10 (a header bit and a side bitmap within a cycle of each other),
  from DRAM shuffled 240-470, a prefetching edge queue hiding half a miss
  where the graph has breadth and nothing on lists.
* **The stack** (H8): 6-7 cycles a slot and about 20 a frame when frames
  are alike; 25-30 a slot when they differ (mispredicted tests; a
  branch-free loop takes 30-50% off); the liveness lookup per frame adds
  45-220 cycles by binary search, 1.3-1.6 times less by a hash on the
  return address.
* **Barriers** (H6), on an array of ints, a loop of `:=`, the lazy update
  of old suspensions and a ref filled with conses: every barrier is within
  noise in the mutator's cycles; in instructions a masked card mark adds
  4.5-6.6 a store, a card mark only for a young value 0 for immediates and
  14-20 for an old-to-young store, an object buffer with a remembered
  byte 11-17, Dart's combined test 7-14, a snapshot barrier 2 while
  marking is off and 6-17 while it is on. What differs is the minor
  collection's work per store: 136 cycles for the plain card, 96-101 for
  the card with a young filter, the object buffer and Dart's (with no
  barrier at all, a minor collection must scan the whole old space: 781).
* **Sweeping** (H3), a 128 MiB heap of 32 B objects: clearing marks costs
  17 cycles an object by walking headers, 0.12 by clearing a bitmap, 0.06
  by line marks; sweeping 19-28 by headers, 12-18 by bitmap, 0.7-2.8 by
  Immix lines; allocating after a sweep at 90% live, 292 cycles after an
  eager sweep, 51 with lazy sweeping.
* **Allocators and the mutator after them** (H5): above, under
  fragmentation; first fit took 270,000 cycles an allocation on the
  bootstrap; traversing the live data afterwards cost 72-74 cycles an
  object compacted, 86-89 on Immix, segregated fits and next fit, and
  110-116 on best fit (twice the cache misses).
* **Placement and the mutator** (H7): lookups in a map of a million nodes
  cost 1,867 cycles laid out depth-first, 1,857 slid, 2,625 with holes,
  and 3,093 in Cheney's breadth-first order, the worst.
* **Pages** (H9): a first touch 1.6 µs a page (0.35 with huge pages);
  `mmap` and `munmap` 2.2-2.7 µs a call; returning a page with
  `MADV_DONTNEED` 0.16-0.6 µs and faulting it back 1.3-1.6 µs; with
  `MADV_FREE`, 0.03-0.5 µs and no fault back.

### The prototype

A nursery in front of today's copier, built in a scratch copy and never
committed (`proto.patch`, 1,230 lines, 606 of them in `heap.c`):
`--nursery N` points `AllocState` at a fixed nursery, so no fast path
changes; objects over N/4 go to old space and are remembered by address;
a minor collection copies the young objects to the end of old space from
the stack, the other roots and the dirty cards (a card per 512 B of the
field's address, walked from a crossing map); a full collection is
today's copier over both spaces; `--gc-log` writes every collection's
deterministic counts and its pause; `--gc-verify` checks that every old
object pointing into the nursery is in a dirty card or remembered.
`runeopt` is refused (its stores have no barrier). `results/D-proto-report.md`,
`results/proto-measurements.md`, `results/proto-coefficients.md`.

**It is correct:** `tests/lang` with `--gc-verify` at 256 KiB and 4 MiB on
the interpreter, the default tiering and `--jit=all`, and at 4 KiB with
`--gc-stress 1`; the sanitiser build; the 32-bit VM; the Basis suite; the
lazy programs and MLton's set with the stock VM's output; the bootstrap's
fixed point; `--count` identical to the stock VM's in all 40 bootstrap
configurations, and the same collections in every run.

**On the bootstrap** (64 MiB heap, default tiering):

| | stock | 128K | 256K | 1M | 2M | 4M | 16M |
|---|---:|---:|---:|---:|---:|---:|---:|
| task-clock ms | 2,197 | 2,500 | 2,143 | 2,015 | 2,045 | 1,976 | 1,938 |
| peak RSS MB | 273 | 173 | 143 | 120 | 110 | 107 | 143 |
| minor collections | -- | 6,816 | 3,411 | 853 | 426 | 212 | 52 |
| 99th-percentile pause ms | 61.6 | 0.32 | 0.39 | 1.17 | 3.48 | 6.63 | 49.9 |
| longest pause ms | 61.6 | 89 | 56 | 60 | 64 | 54 | 50 |

The 99th percentile is the minor collections' own: taken alone it is
1.08, 2.74 and 4.98 ms at 1, 2 and 4 MiB, set mostly by the minor
collections in which much of the nursery survives
(`results/lead-minor-pauses.md`; D2).

So the nursery buys the memory (0.39-0.44 of the copier's peak) and the
typical pause (from 62 ms to 0.3-6.6 ms at the 99th percentile, from 128
KiB to 4 MiB), and a little time (7-10% at 1-4 MiB); the longest pause is still a full collection of
the copier. On MLton's 35 programs at 1 MiB: task-clock 1.03 times the
copier's (geometric mean), peak memory 0.81; the worst was `merge`, 2.1
times, whose every minor collection scans 882,000 stack slots in 98,000
frames -- the stack watermark's case.

**Its pauses, fitted** over 60,788 minor and 348 full collections: a
minor collection costs 5.8 µs + 1.23 ns a stack slot + 15.6 ns a frame +
0.13 ns a card-table entry swept + 21 ns an object + 0.72 ns a byte
copied (R² 0.95, median error 15%); a full one 31-33 ns an object plus
0.72 ns a byte copied into fresh memory, which is the first touch of its
pages, 30% of a full pause. The real VM copies at two to three times the
harness's cost (scattered survivors, more fields, a copy loop not in
line), which is why the simulator's times are relative.

**Its flaw:** every minor collection sweeps the card table of the whole
old space, and the table is one global array folded by the address. On
Rune compiling MLton, with up to 3.3 GB live in a 5 GiB old space, that
is 10.48 million entries a minor collection (about 1.4 ms), and the
folding makes cards alias above 512 MiB: with a 1 MiB nursery the build
took 1.60 times the copier's task-clock, with 4 MiB 1.29 times (209,110
and 52,243 minor collections; promoted 114 GB). The remembered set must
cost what was written, not what is old (D6).

### The baselines

Today's copier with a log of every collection, on the whole set
(`results/workloads-baseline.md`, `results/workloads-32bit.md`,
`results/workloads-mlton-compile.md`); what they show is in *Where we
are*. In short: the copier holds 5 to 10 times the live data; its
pauses grow by about 1.5 ms a megabyte live, to 2.5 s at 1 GB; Rune
compiling MLton spends 30% of its time in it, with pauses up to 5.1 s,
77 of them over a second; and a 32-bit process cannot keep more than 512
MiB live, 255 MiB under a 2 GiB limit.

And the prototype on the same set (`results/workloads-nursery.md`), as
scores against the copier:

| nursery | T | M | P |
|---|---:|---:|---:|
| 1 MiB | 1.03 | 0.69 | 1.02 |
| 4 MiB | 0.98 | 0.75 | 1.04 |

The bootstrap gains most (T 0.78 in these runs, against a copier at
2.57 s, where agent D's own runs give 0.90-0.93; M 0.39-0.44; P 0.63); MLton's normal
tier is level (1.02-1.03); the stress tier and the MLton build lose (1.10
to 1.60) to the card sweep and to large vectors that force full
collections (`vector-rev` 2.8 times at 1 MiB); P does not improve
because the longest pause is still the copier's. The memory is won, the
typical pause is won, and the two things the prototype leaves -- the old
space's pause and the remembered set's cost -- are this roadmap's
decisions.

### What the experiments settle, and what only the gate can

Settled here, within the stated error: survival and its curve, what a
nursery copies, that aging does not pay, the remembered set's size and
its sources, that a mutable space does not fit, the stack's depth and
what a watermark saves, the footprint of every old space against the
live data and the order among them under a limit, the line size, that
placement order does not matter to the footprint, what incremental
marking costs in floating garbage and duty, which pretenuring transfers,
the unit costs on this machine, the copier's baselines, and the
nursery's effect in the real VM.

Left to the gate's prototypes (M4): fragmentation and locality in a real
heap over hours of allocation, not a trace's minutes; the barrier's cost
inside compiled code with a body and a filter; the cost of allocating
promoted objects into holes or free lists in the real promotion path;
incremental marking's real pauses and MMU; the old space under the 32-bit
address space; and everything the WSL2 host distorts (the TLB's reach,
the first-touch fault), which a measurement on bare metal and on a real
32-bit machine would settle.

## Constraints

* **One mutator thread, and no parallel collection** (the brief). The
  collector runs on the thread that allocates. What it may do is spread
  its work out: collect the young part of the heap alone (partial),
  mark or sweep the old part a slice at a time between the mutator's
  allocations (incremental), and leave work to be done as allocation
  needs it (lazy sweeping). That is what "concurrent collection on a
  single thread" means here: the mutator and the collector take turns
  on one thread, at points the mutator's allocation sets, and never run
  at once (D7). Helper threads, signals and the operating system's page
  protection as a barrier are out.
* **Nothing that needs a 64-bit address space** (the brief). No
  reservation of terabytes, no colours in the pointer, no address that
  says the generation by its high bits, no virtual memory treated as
  free. Everything here works in the 2 to 4 GB a 32-bit process has,
  next to the C library's own allocations, and does not need its spaces
  to be contiguous (D10, D13).
* **Pages are the machine's.** The page is 4 KiB on x86 and x86-64 but
  16 or 64 KiB on some aarch64 systems and on ppc64, and a huge page
  is 2 MiB on x86-64, 4 MiB on 32-bit x86 without PAE, and on aarch64
  2 MiB with 4 KiB pages but 32 or 512 MiB with 16 or 64 KiB pages
  (where 2 MiB is reached only through the contiguous hint). The
  collector reads the page at run time, as `sys_code_page` does
  (`runtime/sys/sys_posix.c:1215-1218`), and ties none of its own sizes
  to it (D5, D10, D11).
* **Nothing that rules out the third generation's threads**
  (`garbage-collector-v3.md`): allocation state a thread can own
  (`AllocState`), no collector state that is the process's (`GcState`),
  a barrier with a shape concurrent marking can use, metadata that a
  parallel marker can share (D16).
* **One collector for every engine.** The stack VM, the register VM's
  loop, both tiers of the JIT and `runeopt`'s code share the runtime,
  and so the collector; the interpreter stays complete without the JIT.
  Every engine's fast path for allocation and every store goes through
  the operations `value.h` and the macro-assembler give (heap-layout's
  rule, `AGENTS.md`).
* **C, behind `value.h`; C17 behind `#ifdef`s.** The owner's rule
  (`jit.md`, *Constraints*): the VM builds with a C compiler alone from a
  clean checkout, with what `runeisa` generates committed.
* **The same run every time.** `--count` (instructions, bytes and
  objects allocated) stays exact on every engine and equal across
  widths and byte orders, and stays the oracle of the suites. A
  collection, minor or major, and every slice of incremental work
  happens at the same point of the program's allocation in every run
  with the same flags: work is clocked by allocation, never by a timer
  (D7, D12). Pauses are measured in time, but the schedule is not made
  by it.
* **Images cross machines.** An image written by the 64-bit VM restores
  on the 32-bit and the PowerPC ones; the format stays in bytecode
  terms, values as words and pointers as offsets (D14).
* **The 32-bit and big-endian VMs stay**, and this is the collector the
  32-bit ones keep (the brief): `make test-portability` passes before
  any change to the heap is done, `make test-windows` before a change to
  the VM's core (`AGENTS.md`).
* **Tests stay deterministic and the stress builds stay green:**
  `--gc-stress 1`, the sanitiser build, `make test-heap` (which this
  roadmap puts into `make check`, M2), `make test-stress`.
* **The repository's rules.** One commit a milestone with `make check`
  green; a change to `runtime/` also passes `make test-stress`, the
  sanitiser builds, `make test-windows` and `make test-portability`; the
  documents that describe the collector change with it
  (`docs/runtime.md`, `runtime/register/README.md`,
  `docs/native.md`).
* **The lasting record is `docs/`, not this file.** What is built goes
  into `docs/runtime.md` as it lands, and this roadmap is retired when
  done.

## The architecture

What the runtime looks like when this roadmap is done, on the
recommendations; the gate of M4 may change the old space's inside, not
its place.

```
   mutator (every engine)                       collector (runtime/gc/)
   ----------------------                       -----------------------
   allocation fast path --- AllocState ------> nursery (one region, N bytes)
     (vm_alloc, ms_alloc,     from/size/used        |  minor collection: copy the young
      runeopt's template)                           |  survivors, roots = stack above the
                                                    |  watermark + other roots + dirty cards
   slow path: nursery full -------------------------+
              object >= 8 KiB --------------------> large-object space (4 KiB units,
                                                       never moved, carded within, pinnable)
   store into an object that exists                 |
     BARRIER(obj, field, new [, old]) ---------+    v
       filter: new value in the nursery?       +--> card byte in the field's chunk header
       marking? log the old value              +--> + dirty byte of its block
                                               +--> snapshot log (while a cycle runs)

                                               old space: chunks of 2 MiB, blocks of 32 KiB,
                                               lines of 64 B (D3: Immix; at the gate also
                                               segregated fits behind the same interface)
                                                 - promotion bumps into free lines
                                                 - major: incremental snapshot marking in
                                                   slices paced by allocation, lazy sweeping,
                                                   bounded evacuation of sparse blocks
                                                 - full: the same, stop-the-world
                                                 - last resort at --heap-limit: sliding
                                                   compaction from the mark bitmap
                                               side tables per chunk: block descriptors,
                                               line bytes, mark bits, cards, dirty bytes
```

* **The spaces.** The nursery is one region of N bytes and is
  `AllocState` (heap-layout M7's struct): the fast paths of C, the JIT
  and `runeopt` do not change, and young is a range test. The old space
  and the large objects live in chunks of 2 MiB aligned to 2 MiB, mapped
  as needed from the `sys` layer (`sys_mem_reserve`, `sys_mem_commit`,
  `sys_mem_release`, new in M2 beside the JIT's executable memory), whose
  first part holds the chunk's side tables. A chunk is found from any
  address in it by a mask; nothing assumes two chunks are adjacent.
* **Collections.** A *minor* collection copies the nursery's survivors
  into the old space's free lines in Cheney's order, from the roots, the
  dirty cards and the large objects' cards; promotion is at the first
  survival. A *major* cycle marks the old space incrementally under a
  snapshot barrier, a slice at each minor collection, sweeps lazily as
  allocation reaches each block, and evacuates the sparse blocks it
  chose within a bound in its last pause. A *full* collection does the
  same at once, when a cycle cannot finish before the heap's trigger or
  `Runtime.collect` asks. A *compaction* slides the old space when an
  allocation fails at `--heap-limit` after a full collection.
* **The barrier** is one operation with one signature in every engine:
  the object, the field's address, the new value, and the old value while
  marking. Its fast path filters in line -- a new value inside the
  nursery's range; marking on -- and its work is a byte store into the
  card and the block's dirty byte, or a push of the old value onto the
  snapshot log. Initialising stores have none.
* **The roots.** The stack, from the top down to the first frame a
  minor collection already scanned (a bit in the frame, cleared when the
  frame runs); the other roots of `OTHER_ROOTS`; the dirty cards of the
  old space and of large objects. A major cycle snapshots the whole stack
  at its start and rescans the frames that ran at its end.
* **The interface the old spaces plug into.** The gate's two prototypes
  implement one set of operations in C, chosen at build time:
  `old_alloc_promoted(size)`, `old_alloc_direct(size)` (pretenuring),
  `old_mark_object`, `old_trace_slice(budget)`, `old_sweep_lazily`,
  `old_evacuation_candidates`, `old_footprint`, `old_check` (for
  `--gc-verify`). M3's copying old space is the first implementation.
* **What a collection reports:** `--gc-log` (a line per collection: its
  kind, the deterministic counts of allocation, roots, cards, copying,
  marking and sweeping, and its times), `--stats`, `Runtime.stats` (the
  deterministic counters).
* **What stays as it is:** the value and the object (heap-layout's
  layout, the header's GC bits zero); `--count`; the image format in
  bytecode terms; the census VM as the trace's source; the interpreter
  complete without the JIT.

## Decisions

Each gives the options, what favours each, the evidence of *The
experiments* and the literature it turns on, and the recommendation it
was written with. D2 to D5, D7 and D8 are recommended provisionally here
and decided again at the gate of M4, on the two old spaces measured in
the real VM, as heap-layout's D1 to D5 were at its M4. Some decisions are
less choices than consequences of the others (D12, D14, D16 to D18); they
are written out so that the plans around this one can cite them. The
owner took every recommendation on 2026-10-06, the six of the gate
provisionally:

| Decision | Recommended | Chosen |
|---|---|---|
| D1. What the second generation is for | A: four measurable targets -- memory, pauses, throughput, and the rest unchanged | A |
| D2. The nursery | A: a fixed nursery of 1 MiB; promotion at the first survival | A, until the gate of M4 |
| D3. The old space | A: mark-region (Immix) with 64-byte lines and 32 KiB blocks; segregated fits the gate's second prototype | A, until the gate of M4 |
| D4. Fragmentation | A: opportunistic evacuation of sparse blocks, bounded; a stop-the-world sliding compaction only when the limit is reached | A, until the gate of M4 |
| D5. Large objects | A: from 8 KiB, straight into runs of the space's own 4 KiB units (not the operating system's pages), never moved, carded within; not from 4 KiB | A, until the gate of M4 |
| D6. The barrier and the remembered set | B: a card mark only for a young value, cards in each chunk's header, a dirty byte per block; one barrier with the snapshot log | B |
| D7. Pauses | B: incremental snapshot marking paced by allocation, lazy sweeping, bounded evacuation | B, until the gate of M4 |
| D8. The collector's metadata | C: side tables per block; the header's GC bits stay unused | C, until the gate of M4 |
| D9. Roots and the stack | B: a watermark in the frames; the liveness lookup by a hash | B |
| D10. Sizing and the operating system | A: aligned chunks of 2 MiB committed as used, free blocks returned lazily; old space sized by what lives | A |
| D11. The cache and the TLB | A: the nursery within the TLB's reach; prefetched marking; lazy sweeping; promotion order measured; huge pages, if any, for the old space, measured in M7 | A |
| D12. Determinism, `--count` and the statistics | as recommended: work clocked by allocation; deterministic counters only in `Runtime.stats` | as recommended |
| D13. 32-bit | A: the same collector; the 4-byte word not a prerequisite | A |
| D14. Every engine | as recommended: one barrier signature everywhere, `runeopt`'s two stores included; images over chunks | as recommended |
| D15. Help from the compiler and the bytecode | B: pretenuring by site from the compiler's own build, measured in M7; elision where a value is known immediate | B |
| D16. Threads and the third generation | as recommended: what is fixed now and what is left | as recommended |
| D17. The FFI and pinning | as recommended: large objects pinned in place | as recommended |
| D18. A lazy front end | as recommended: indirections shortcut at copy and at mark; updates through the barrier | as recommended |
| D19. Order against the other plans | A: M1 now; nothing waits for this, and the resident compiler wants M3 | A |

### D1. What the second generation is for

**Recommended: A**, four targets on the evaluation set, measured at every
milestone from M3 against today's copier at `ca87fa07`.

* **A. Targets for memory, pauses and throughput, and the rest held.**
  1. *Memory.* Peak resident memory at most twice the most live data
     plus 16 MB on the bootstrap and the latency workloads (the copier
     holds 6.6 times on the bootstrap, 5 to 10 elsewhere), and the score M
     at most 0.6. On a 32-bit process, at least 1.5 GiB of live data with
     the whole address space and 768 MiB under a 2 GiB limit -- three
     times today's 512 and 255 MiB.
  2. *Pauses.* The longest pause at most 10 ms on the bootstrap and on
     the 100 MB latency workloads, and at most 20 ms with 1 GB live; the
     99th percentile at most 2 ms; MMU at 10 ms at least 0.3 on the
     bootstrap and 0.5 on the latency workloads. A compaction forced by
     `--heap-limit` (D4) is reported apart, not counted.
  3. *Throughput.* The score T at most 0.95; the bootstrap at most 0.85
     of today's task-clock; Rune compiling MLton at most 0.8 (it copies
     180 GB today); no workload of the set more than 1.10.
  4. *What holds.* `--count` exact, collections at the same allocations,
     every engine, both widths and byte orders, images, the suites
     (*Constraints*).
* **B. Throughput first:** a nursery and a stop-the-world old space, no
  incremental marking. Simpler by M6, and the longest pause stays a
  major's: 11.5 ms on the bootstrap modelled, and a whole marking of
  the old space with a gigabyte live (the copier takes 1.4-2.5 s there
  today). It does not answer the brief's "short/no
  pausing".
* **C. Memory first:** mark-compact as the old space, everywhere. The
  tightest footprint measured (1.12 times the live data) and the best
  locality, at 2.6 times Immix's collector time and compaction pauses that
  grow with the heap.

The prototype makes the targets plausible: the nursery alone gave the
bootstrap 0.78-0.93 of the time (two series of runs) and 0.39-0.44 of
the memory, and a 99th percentile of 1.2 ms at 1 MiB; an old space that does not copy holds 1.12-1.21
times what lives (the simulator) where a copying old space holds 3.6
(and today's copier 6.6 on the bootstrap); incremental
marking took the modelled longest pause to 3.1 ms. The 32-bit target
follows from an old space of chunks that need no contiguous block and
no second copy. These are the numbers M4's gate and M6 are judged on.

### D2. The nursery

**Recommended: A**, a fixed nursery of 1 MiB on every width, promotion at
the first survival, `--nursery N` to set it.

* **A. Fixed, 1 MiB.** The harness's minor collection costs about the
  same per KiB anywhere between 1 and 4 MiB (516 and 508 cycles); above 8
  MiB the survivors leave the cache and, on the reference machine, the
  TLB's 4 MiB reach. In the prototype, on the bootstrap at the default
  tiering, 1, 2 and 4 MiB were within 3.5% of one another in time (2,015,
  2,045, 1,976 ms) and their 99th-percentile pauses were 1.17, 3.48 and
  6.63 ms (all collections); on the evaluation set 1 MiB scored T 1.03, M
  0.69 and 4 MiB T 0.98, M 0.75. The tail is the minor collections',
  not the two full ones': taken alone, their 99th percentile is 1.08,
  2.74 and 4.98 ms and their longest 1.45, 3.89 and 6.63 ms (1.08-1.39,
  1.92-2.74 and 4.45-5.72 ms at the 99th percentile over both engines
  and both first heaps; `results/lead-minor-pauses.md`). The longest
  are mostly those in which much of the nursery survives (52-96% for
  the longest four at 1 and 2 MiB on the 64 MiB heap) -- the compiler
  building what it keeps -- and a minor collection's worst case is the
  nursery copied whole, so the tail grows with the nursery, at 1.2-3 ms
  a MiB copied on the reference machine; neither the watermark (D9) nor
  the card summary (D6) shortens it. 1 MiB is the size that meets
  D1's 2 ms 99th percentile, holds the least memory across the set (though not on
  the bootstrap alone: 120 MB against 107 at 4 MiB), and costs 2-5% of
  time against 4 MiB -- a cost that falls with the two things that made
  small nurseries lose in the prototype: the whole stack scanned at every
  minor collection (D9) and the whole card table swept (D6).
* **B. 2 MiB**, a huge page on x86-64 and on aarch64 with 4 KiB pages.
  Its minor collections' 99th percentile, 2.7 ms (1.9-2.7), is at or
  above D1's target; otherwise it is level with A or a little ahead:
  time within noise, 4.5% fewer bytes promoted (168.6 against 176.5
  MB), the bootstrap's peak 110 MB against 120 (the simulator: 72
  against 80 MB on Immix), though over the 13 traces with 2 MB or more
  live the simulator's peak is 6.6% higher at the geometric mean
  (`results/lead-los-threshold.md`). Huge pages do not help a nursery:
  the harness's minor collection cost 516 cycles a KiB at 1 MiB with and
  without them (H1), allocation walks the nursery's pages in order, and
  1-2 MiB is within the TLB's reach of every core at hand; where huge
  pages can pay is the old space, which marking and the mutator walk at
  random (D10, D11). With D1's 99th percentile relaxed to 3-4 ms, B
  would be a fair default.
* **C. 4 MiB:** the least time of the three (the bootstrap at 0.90 of the
  copier's task-clock; 16 MiB was faster still, at a 50 ms 99th
  percentile), a 6.6 ms 99th percentile.
* **D. Adaptive** (SpiderMonkey: grow when promotion is high, shrink
  when idle). The right end state for programs whose survival changes;
  nothing measured here needs it yet. M7 measures it.
* **E. No nursery** (sticky marks, G4). Young objects in the old space's
  holes, nothing copied at a minor collection. The prototype measured
  what the nursery's dense allocation and copying buy; sticky Immix would
  have to win it back. Not recommended.

*Promotion:* at the first survival. On the bootstrap, promotion at the
second copies 376 MB against 242 at 1 MiB and saves one major in six; the
literature's case for aging (Ungar, Ungar and Jackson) is for programs
whose objects live a little longer than a nursery, and Rune's compiler
keeps what it keeps for long. Aging by an address watermark (Dart, GHC)
needs no header bit if a program ever needs it. The size is a target
property, chosen at start from the machine (the cache, and the TLB's
reach where it can be read) in M7, with A's value as the default and 2 and 4 MiB measured again at the gate
(M4), once the watermark and the remembered set are in. The nursery is
a region of its own, so its size and the chunks' (D10) are chosen
apart.

### D3. The old space

**Recommended: A**, a mark-region old space (G3) of 32 KiB blocks and
64-byte lines, conservative line marking, promoted objects bump-allocated
into free lines, with D4's evacuation and fall-back; and, as the gate's
second prototype, segregated fits (G2).

* **A. Mark-region (Immix).** Footprint 1.13 times the live data at the
  median of the 12 traces with live data to speak of, 1.84 on the
  bootstrap without a limit (where the trigger, not fragmentation, sets
  the peak); 25 and 17 majors at limits of 1.25 and 1.5 times the most
  live; 64-byte lines take the bootstrap's peak from 83.6 to 79.8 MB at 32
  KiB blocks
  (SML's objects are two to four words, and the literature says the line
  belongs to the language's sizes); evacuation takes 3.3 MB off for 3.8 MB moved
  with 64-byte lines (7 MB for 4 MB with 128-byte ones). Promotion bumps into lines, so it keeps the nursery's order, and
  the literature's two warnings against free lists -- the mutator 9.3%
  slower (RC Immix) and promotion 30-50% slower (Alligator, CMS) -- do
  not apply. Metadata 1.6% for the line bytes. Its costs: a live object
  holds its line and, by the conservative rule, the next; evacuation is a
  mechanism to build and to test.
* **B. Segregated fits (OCaml 5, SML#).** Never moves -- pinning, the FFI
  and incremental marking are simplest -- and its fragmentation is
  bounded by the classes. But its footprint is 1.21 times at the median,
  it thrashed at a limit of 1.25 times (57 majors, overflowing), and
  promotion allocates from free lists. On 32-bit the gate measures which
  holds less: the simulator's 4-byte word puts segregated fits ahead on
  the bootstrap (41.3 against 43.5 MB) and Immix ahead on `compile-sigs`
  and `runedoc-page`. It is the gate's second prototype because it is
  the real alternative school, and because the owner should see both in
  the real VM.
* **C. Mark-compact (MLton's, Lisp-2 or Jonkers).** The tightest (1.12
  times; 5 majors at 1.25 times) and the best locality (the harness's
  walk of the live data, 72-74 cycles an object against 86-89), but
  every major moves the heap: 2.6 times Immix's collector time modelled,
  and a pause that cannot be made incremental without a read barrier.
  It is D4's fall-back.
* **D. Chez's segments (G6).** 1.15 times; much like A with segments for
  blocks. Its idea worth taking -- the space of a segment says what is in
  it -- is A's block descriptor.
* **E. A copying old space (G1)**, the prototype's. Simple and quick
  (the bootstrap at 0.90), but 3.6 times the live data: it is the
  memory the brief asks to save, and on 32-bit it is the ceiling of
  *Where we are*. It is M3's old space until M5 replaces it.

*Tie-breakers stated:* if headerless pairs come back (branch
`heap-layout-pairs`), a segregated space holds them most naturally; A
can hold them in blocks of their own. A sticky-mark generational mode
over A (no copying nursery) stays possible for a future roadmap.

### D4. Fragmentation

**Recommended: A + B.**

* **A. Opportunistic evacuation of sparse blocks.** At each major the
  blocks with the most free lines are chosen as candidates, up to a
  bound (Dart: the bytes a scavenge moves; here, at most the nursery's
  size per cycle), and their live objects are evacuated into free blocks
  while they are marked; a block with a pinned object is never a
  candidate. Measured: 3.3 MB of the bootstrap's peak for 3.8 MB moved with 64-byte
  lines (7 MB for 4 MB with 128-byte ones);
  without it Immix's minimum heap grew 45% on average in its paper.
* **B. A stop-the-world sliding compaction as the last resort**, when an
  allocation fails at `--heap-limit` after a full collection with
  evacuation: table-driven, in one pass from the mark bitmap (the
  Compressor's form: tables of about 1/32 of the heap, no second space),
  or Jonkers' threading if the tables do not fit; it is rare, and
  McGachey and Hosking found such a fall-back paid off. On 32-bit it is
  what lets a heap near the address space's limit still collect. Its
  pause is reported apart (D1).
* **C. Routine compaction** (every major, or by OCaml's 500%): not
  needed on these numbers, and every compacting major is a long pause.
* **D. Size classes spaced at 1/8** (Metronome) apply only to B's
  segregated space at the gate.

### D5. Large objects

**Recommended: A.** Objects from 8 KiB are allocated straight into a
large-object space, never in the nursery and never moved. The space
hands out runs of 4 KiB units from the chunks (D10): its own unit, not
the operating system's page, which is 4 KiB on x86 but 16 or 64 KiB on
some aarch64 systems and on ppc64 (*Constraints*); pages matter only
when memory is given back. An object is marked by a bit in its run's
descriptor and freed by the run at the sweep, and the run's pages go
back when they are free. Raw objects (strings, byte and real arrays)
there are never scanned. A large array of values
carries its own card bytes, one per 512 B, so that a store dirties one
card and a minor collection scans one card, not the array (MLton marks
the array's first card and rescans it all). This is also what pinning
needs (D17). The prototype's worst case, `vector-rev` at 2.8 times the
copier, came from large vectors made in old space that forced full
collections; in A they are old from birth and collected only at majors.

The evidence is the simulator's over the 38 traces that allocate 16 MB
or more, Immix behind a 1 MiB nursery (`results/lead-los-threshold.md`;
the earlier sweep of `results/sim-fragmentation.md` varied the threshold
only for where promoted objects go):

* **A. Straight into the space from 8 KiB**, Immix's limit for medium
  objects: a quarter of a block, which bounds what a medium object can
  waste at a block's end. Against B its peak is 2.5% higher at the
  geometric mean, and it promotes 3-8% less on the compiler's traces;
  the one outlier is `mlton-tensor` (4.5 MB against 1.7), whose objects
  of about 13 KiB die young and in A wait for a major. If the gate finds
  such programs common, the remedy is V8's young large-object space or
  G1's eager reclaim: a large object born young is freed at the next
  minor collection if nothing reached it and promoted in place if
  something did (`javascript/v8/src/heap/large-spaces.h`,
  `NewLargeObjectSpace`; `java/jdk/src/hotspot/share/gc/g1/g1YoungCollector.cpp`),
  at the price of a barrier that can tell such an object young -- a flag
  in its chunk's header beside the nursery's range test.
* **B. In the nursery, moved into the space when promoted** (straight in
  only above a quarter of the nursery, as in the prototype). The
  simulator's best on average, but every surviving large object is
  copied once -- a 256 KiB one in about 0.2 ms of a minor collection --
  and fills the nursery while it waits. Allocating straight in only from
  32 KiB, and moving objects of 8-32 KiB at promotion, is level with B
  on average and removes `mlton-tensor`'s outlier, but costs the
  bootstrap 7%. The gate measures it against A in the real VM.
* **C. From 4 KiB, the page's size.** Not recommended: a page-sized
  payload with its 8-byte header is just over a page. Rune's Basis reads
  in chunks of 4,096 bytes (`chunkSize`, `lib/basis/posix_io.sml:157`,
  `:178`), the bootstrap makes 424 strings of exactly that length, and
  a 512-element array is the same 4,104 bytes; from 4 KiB each takes two
  units, half empty, and waits for a major. The peak grows 4% at the
  geometric mean, 8% on the bootstrap (one major more; 1,557 large
  objects against 293), 2.2 times on `fxp`, 19-30% on `wc-input1`,
  `wc-scanStream` and `runedoc-page`, and is 3% lower nowhere.
* **D. Rounded to the operating system's pages.** Simplest where pages
  are 4 KiB, and costly where they are not: at 64 KiB pages A's peak
  grows 7.5% at the geometric mean (`mlton-tensor` 3.3 times) and C's
  28% over A's (the bootstrap 69%, `wc-scanStream` 4.2 times, `fxp` 15
  times). With the space's own unit, a large page costs only a coarser
  return of memory.

### D6. The barrier and the remembered set

**Recommended: B**, a card mark only for a young value, in cards kept in
each old-space chunk's header, with a dirty byte per block that a minor
collection reads first; the same barrier logging the overwritten value
while incremental marking runs.

* **A. Today's card mark, every store, one table folded by the address.**
  The prototype's. Its cost is in the minor collection, not the store:
  a sweep of the whole table every time (10.48 million entries at a 5 GiB
  old space: 1.4 ms a minor collection) and aliasing above 512 MiB, which
  made Rune compiling MLton 1.29-1.60 times slower.
* **B. A filtered card mark in per-chunk cards with a summary.** The
  barrier marks the card of the field's address only when the new value
  is a pointer into the nursery: one subtraction and one unsigned compare
  against the nursery's range, which an immediate always fails (H6: no
  instruction for `:=` of an int; 14-20 for an old-to-young store). The
  cards are bytes in the header of the 2 MiB chunk the field is in, found
  by masking the address -- no global table, no folding, no contiguous
  reservation -- and the card's block gets a dirty byte, so a minor
  collection visits only dirty blocks and only their dirty cards (D's
  recommendation; about 20 µs to sweep the summary of 5 GiB). The harness
  measured the young filter's minor-collection cost at 96 cycles a store
  against 136 for the plain card.
* **C. An object buffer deduplicated by a remembered byte** (Spur, PyPy):
  as cheap at the minor collection (100 cycles) and precise; it needs a
  side byte per object or the header's bit (D8 rules the header out), and
  its buffer overflow path in compiled code.
* **D. Dart's one test of two header bytes:** elegant, but it needs bits
  in the header, which every reader of a kind would then mask (D8).
* **E. No barrier, a mutable space scanned at every minor** (Poly/ML,
  MLKit): 5.39 GB scanned on the bootstrap: no.

*The signature,* at every store into an object that exists: the object,
the field's address, the new value, and -- while marking (D7) -- the old
value read before the store, logged when it is a pointer (H6: two
instructions while marking is off). Initialising stores need nothing: a
fresh object is young, or old from birth and remembered by address (the
prototype's rule, held in A's large-object space by its cards). `SETENV`
never makes an old-to-young pointer at a nursery of 256 KiB or more, but
keeps the barrier: it costs nothing measurable and correctness does not
rest on a measurement. `runeopt`'s inline `:=` and `Array.update` get the
barrier (D14).

### D7. Pauses

**Recommended: B**: the old space marked incrementally with a snapshot
barrier, in slices paced by allocation; swept lazily; evacuated in a
bounded final pause.

* **A. Stop-the-world majors** behind the nursery. The modelled longest
  pause on the bootstrap is 11.5 ms; at a gigabyte live it is a full
  marking of the gigabyte. Fails D1.
* **B. Incremental snapshot-at-the-beginning marking.** A cycle starts
  when the old space reaches three quarters of its trigger; its first
  pause snapshots the roots (the stack in full -- under 1 ms at the
  bootstrap's deepest, 398,000 slots in 20,881 frames, by the prototype's
  fit -- the globals, the
  remembered cards); then each minor collection marks k bytes for each
  byte allocated since the last (k from 2 to 8: the marker busy 20-6% of
  the time, floating garbage 3.5-0.5 MB on the bootstrap), with every
  slice capped so that a burst of allocation cannot make a long one
  (Sivaramakrishnan et al.'s 1,125 ms slice) and a fall-back that
  finishes the cycle at once when the heap reaches its trigger; objects
  allocated or promoted during a cycle are marked; the final pause
  rescans the stack (incrementally, from the watermark, D9) and the
  dirty cards, and evacuates within D4's bound. Sweeping is lazy:
  blocks are swept when allocation reaches them (H3: allocation after a
  sweep 51 cycles against 292 eagerly). Modelled: longest pause 3.1 ms,
  p99 1.0 ms, MMU at 10 ms 0.35, total collector time 1.27 times. A
  snapshot barrier needs no final re-marking of the heap, fires only on
  stores, and is what a concurrent marker of the third generation uses
  (OCaml kept it from 4 to 5).
* **C. Incremental update (Dijkstra),** sharing the card table with the
  generational barrier (Printezis and Detlefs): a minor collection
  cleans the cards, so it needs a second bit per card and a final rescan
  of every dirty card and the roots; the final pause is longer and less
  bounded.
* **D. Concurrent on a second thread**: excluded by the brief.

"Concurrent collection on a single thread" is B: the collector's work
interleaved with the mutator's at points the mutator's allocation sets,
never at once. The pacing is in bytes, so the schedule is the same in
every run (D12). Large objects are marked with the rest and freed at the
sweep. What is promised is D1's second target.

### D8. The collector's metadata

**Recommended: C**, side tables per block -- a byte a line (1.6%), a mark
bit per 8-byte granule (1.6%), a card byte per 512 B (0.2%), a descriptor
per block and per page -- and the header's four GC bits left unused.

* **A. The header's kind byte.** Every reader of a kind then masks it:
  measured at heap-layout M7 at 2.5% more instructions in the interpreter
  and 4.4% at the default tiering on the bootstrap, 9.8% on `tailmerge`.
  A cost paid by the mutator everywhere for the collector's convenience.
* **B. The header's second byte** (`pad`), read by no mutator: free, but
  it is the byte kept for a descriptor of raw fields, which the owner
  deferred to a future roadmap; taking it closes that.
* **C. Side tables.** The harness: marking by a bitmap within a cycle of
  a header bit; clearing a bitmap 0.12 cycles an object against 17 for a
  walk of the headers; sweeping by line marks 0.7-2.8 cycles an object
  against 19-28 by headers. About 3.4% of the old space, on 32-bit as on
  64-bit. Byte-granular tables are what a parallel marker sets with
  atomic byte operations later (D16). Forwarding during copying stays
  `K_FORWARD` over the header, as today.

The four bits stay reserved and zero, as heap-layout left them; a future
collector that wants one pays the mask, measured.

### D9. Roots and the stack

**Recommended: B**, a watermark in the frames, and the liveness lookup by
a hash of the return address.

* **A. The whole stack at every minor collection**, as today and as most
  runtimes do. On the bootstrap at 1 MiB, 5.79 million slots over the
  run; on `merge`, 882,000 slots and 98,000 frames at every one of 471
  minor collections, which made it 2.1 times slower in the prototype.
* **B. A frame that a minor collection scanned is not scanned again
  until it runs.** A bit in the frame record, set by the minor
  collection, cleared when the frame becomes the one that runs (a return
  into it, a handler in it) or is reused by a tail call; a minor
  collection scans from the top down to the first frame with the bit
  set. It holds because a waiting frame's registers are written only when
  it runs again (a callee's result is written as the caller resumes; the
  JIT's homes are the running frame's), which M3 verifies with
  `--gc-verify` and the census's `fp_low`. Measured: 85% fewer slots on
  the bootstrap; 96-99% of the stack unchanged between samples on the
  bootstrap, `hamlet` and `knuth-bendix`. Cheng, Harper and Lee's TIL
  markers cut GC time 13-74%.
* **C. Stacklets** (Cheng and Blelloch): the stack in fixed pieces,
  scanned a piece at a time. More than v2 needs; the third generation's
  green threads may want it.

The lookup of a waiting frame's live registers (heap-layout M6) by a hash
on the return address is 1.3-1.6 times faster than today's binary search
(H8). Majors and the start of an incremental cycle scan the whole stack.

### D10. Sizing and the operating system

**Recommended: A.**

* **Chunks.** The old space and the large objects are made of chunks of 2
  MiB aligned to 2 MiB (mapped with room to spare and trimmed; no
  reservation beyond what is used, no contiguity between chunks), each its
  side tables (block descriptors, line bytes, mark bits, cards: about 1.1
  KB a block, 67 KB in all, so three blocks' worth) and 61 blocks of 32
  KiB, or runs of large-object units; a larger object gets a chunk
  of its own. 2 MiB rather than 1: the tables round up to whole blocks,
  so a 1 MiB chunk keeps 30 of its 32 blocks (93.8%) and a 2 MiB one 61
  of 64 (95.3%); a chunk aligned to 2 MiB can be backed by one huge page
  on x86-64 and on aarch64 with 4 KiB pages, a 1 MiB one only by luck
  (D11); and there are half as many chunks. What it costs: a chunk is
  less often wholly empty, so memory goes back by the block (below); and
  the alignment. `mmap` and `VirtualAlloc` take none, and the sure way --
  map 4 MiB, unmap the unaligned head and tail -- needs a 4 MiB hole for
  that moment, which a 32-bit process near its limit may not have where
  a 2 MiB one would still serve. So a chunk is first asked for at its
  exact size with the address just past the last chunk as a hint, which
  the kernel honours when that range is free, and then it is aligned;
  only when it comes back elsewhere is it over-mapped (GHC's megablocks,
  `ghc/rts/posix/OSMem.c:287-357`). Near the limit it is asked for at
  an aligned address inside a hole read from `/proc/self/maps`, with
  `MAP_FIXED_NOREPLACE` so that nothing mapped is replaced (Linux 4.17
  and later; an older kernel takes it as a hint, and the address is
  checked); on Windows `VirtualQuery` finds the holes, and `VirtualAlloc`
  at an address fails rather than replacing. Windows cannot trim a
  reservation: there the over-reservation
  is released and the aligned range reserved again, retried if something
  took it meanwhile (Go's `sysReserveAligned`,
  `golang/go/src/runtime/mem.go:185-220`), or the alignment is asked of
  `VirtualAlloc2` (Windows 10 version 1803 and later). The nursery is one
  region of its own size (D2), not a chunk. An address's chunk
  is its address masked, so `heap_is_young` stays a range test and a
  card is a mask and an index.
* **Growth by what lives.** A major cycle starts when the old space has
  taken `live × (100/fill - 1)` since the last one, `--heap-fill` (the
  old space's target occupancy) 66% by default on 64-bit and 80% on
  32-bit; growth is by chunks, so the steps are fine -- what the copier
  could not afford (heap-layout M7).
* **Memory back.** Free blocks and free runs of the large-object space
  are given back with `MADV_FREE`, a call for each run of them (about
  3.8 µs for a lone 32 KiB block, 30-50 ns a page for runs of 256 KiB
  and more; nothing to fault back; H9), in whole pages of the machine's
  size, when the free memory exceeds what is in use (Chez's reserve
  ratio of 1); empty chunks are unmapped beyond a cap; on Windows the
  same with `VirtualFree` decommit and `DiscardVirtualMemory`.
* **The flags.** `--heap-size`: the old space's first trigger.
  `--heap-limit`: a cap on all committed heap memory -- the nursery, the
  chunks, the tables -- past which a full collection, then D4's
  compaction, then `vm_limit`. `--nursery`. The image carries them, as
  now.
* **On 32-bit** nothing needs a contiguous block larger than a chunk, and
  nothing is held twice: the address space per byte live falls from the
  copier's 4.9-10 to about 1.3 (the old space's footprint plus the
  nursery and the tables), which is D1's ceiling.

### D11. The cache and the TLB

**Recommended: A**: the nursery within the TLB's reach and a quarter of
the L3 (D2's 1 MiB is both, on every machine at hand); marking from an
edge queue with a prefetching FIFO (H2: half a miss hidden where the
graph has breadth; Garner et al.); lazy sweeping (H3, Boehm); allocation
order for promotion, which the simulator found as good as any for the
footprint. Huge pages are not for the nursery, which gains nothing from
them (H1: a minor collection 516 cycles a KiB at 1 MiB with and without)
because it is walked in order and fits the TLB's reach; they may be for
the old space, which marking and the mutator walk at random and which
D10's 2 MiB chunks leave eligible. They are off by default: a huge page
is committed whole at its first touch, against D10's committing
memory as it is used, and giving one block of it back splits it; under WSL2 the host's
small pages defeat them (the TLB's reach goes from 4 to about 7 MiB,
H10); on bare metal they are a measurement for M7. One thing
to try in M7: promoting in an approximately depth-first order (Moon;
Wilson, Lam and Moher 1991), since Cheney's breadth-first order was the
worst layout for the mutator's lookups in the harness (3,093 cycles
against 1,867 depth-first).

### D12. Determinism, `--count` and the statistics

**As recommended.** Every collection, minor or major, every incremental
slice and every evacuation is triggered by allocation, so a program
collects at the same points in every run with the same flags, as today;
`--count` is unchanged by the collector. `--gc-log FILE` (the prototype's,
one line per collection with its deterministic counts and its times)
enters the tree in M1. `Runtime.stats` gains the deterministic counters
alone -- minor and major collections, bytes promoted, the remembered
set's largest -- and not times, which are `--stats`', and `Timer`'s.
`runtime_sig.sml`'s claim that collections do not depend on the heap's
size is corrected in M2.

### D13. 32-bit

**Recommended: A**: the same collector on every width, as one runtime
serves every engine. The 4-byte word (`32-bit-vm.md`) would halve every
space again (the simulator: Immix's peak 83.6 to 43.5 MB on the
bootstrap) and is decided there, on its own evidence; nothing here
waits for it or forbids it. What 32-bit asks of this roadmap is
answered by D10's chunks and D3's old space: no reservation, no
contiguous block, no second copy. D2's 1 MiB suits the 32-bit machines' smaller
caches too.

### D14. Every engine

**As recommended.** One barrier signature (D6) in C (`obj_set_field`, now
given the field and the value), in both loops (generated from `src/isa`),
in the JIT (`ms_barrier` given the value's register and the field's
address, with the filter in line and the rest out of line), and in
`runeopt`'s templates, which gain a barrier template and use it at the
inline `:=` and `Array.update` (*Where we are*). The allocation fast paths
keep their shape: the nursery is `AllocState`. Images are written by a
full collection into a run of chunks and written as offsets, as now, and
read back into chunks; `heap_relocate` works chunk by chunk. The census
VM follows the nursery's allocation path; the stack VM and `runeopt` are
supported from M3 (the prototype refused `runeopt`).

### D15. Help from the compiler and the bytecode

**Recommended: B.**

* **A. Nothing:** the collector alone. Everything above works without
  the compiler.
* **B. Pretenuring by site, from the compiler's own build,** and the
  barrier elided where the compiler knows the stored value is immediate.
  Sites learned on `compile-sigs` pretenured 24.9 MB of the bootstrap and
  saved 24.1 MB of copying for 0.8 MB of garbage; the bootstrap's own
  first half predicts nothing of its second. So advice is per program,
  made by a profiling run, and the program that matters most -- the
  compiler -- has its build to learn from (the literature's "build-time
  advice"). It needs a bit per allocation site, in the representations
  section, and an allocation path into the old space. Measured in M7
  and built if it pays on the evaluation set.
* **C. Mutable objects in blocks of their own,** so that cards exist only
  there: the filtered barrier already marks only what matters; not now.
* **D. Escape analysis and stack allocation** (`~/notes/virtual-machine.md`):
  a compiler project; the collector needs nothing for it but the frame
  layout.

A boot space for the data a program makes first (45% of what Immix marks
on the bootstrap was born in its first tenth) is measured, not
recommended: incremental marking already hides that work, and a third
generation is a mechanism to justify later.

### D16. Threads and the third generation

**As recommended.** What this roadmap fixes so that the third generation
need not undo it: allocation state per thread (`AllocState`; a nursery
per thread is this struct made many); no collector state that is the
process's; marks and cards in side tables of bytes, which threads can set
with atomic byte operations; card marks that are idempotent plain stores,
safe under races as HotSpot's are; a snapshot barrier, which a
concurrent marker uses unchanged; pacing by allocation, never by a
timer. What it leaves: allocation of promoted objects into a shared old
space by many threads, parallel marking and sweeping, the safepoint
protocol for many mutators, NUMA placement, and whether the old space
stays one or becomes per-thread (`garbage-collector-v3.md`).

### D17. The FFI and pinning

**As recommended.** Large objects (D5) never move, so a byte or real
array of 8 KiB or more is pinned in place and `vm_pin` returns its
address; a smaller one is copied as today, or moved into the
large-object space at its first pin. A block holding a pinned object is
never an evacuation candidate (D4). Handles stay. The FFI roadmap
decides the rest.

### D18. A lazy front end

**As recommended.** An indirection (`K_IND`) is shortcut when the nursery
copies it -- the referring field gets the target -- and when the marker
meets it, the field is updated to the target (one thread: no race). An
update of a suspension is a store through the barrier: an old suspension
given a young value is remembered by its card (heap-layout measured
0.02-6.7% of lazy programs' updates as old to young). Nothing reserves
more than heap-layout reserved: `K_THUNK`, `K_IND` and the pointer's
spare bits.

### D19. Order against the other plans

**Recommended: A.** M1 can start at once; nothing in the other plans
must come first. The incremental-compilation roadmap's resident compiler
keeps a large basis live for long, which a copier copies at every
collection and a generational collector does not: it wants M3 before its
M4. The FFI's pinning wants M5. The third generation comes after M6.
`32-bit-vm.md` and `real-encoding.md` are independent of this roadmap
in both directions; the JIT's pointers in registers (stack maps,
`performance.md`, *Tier 2's registers*) interacts with D9's watermark
through the frame layout, and whichever comes second adapts.

## The milestones

Each says what it builds, why now, when it is done, what it touches and
its size (lines changed, a guess). Every milestone is one commit or a
few, each with `make check` green; a change to the runtime also passes
`make test-stress`, the sanitiser builds, `make test-heap` (in `make
check` from M2), `make test-windows` and `make test-portability`
(*Constraints*). The milestones after the gate of M4 are planned again
with its numbers.

### M1. Measure in the tree (M, about 3,000, mostly written)

* **What:** the tools of *The experiments*, from their drafts:
  - the census VM on the word layout and its extensions (`census.patch`,
    1,543 lines), `test-census` and the validation of `check-heapsim`
    back in `make check`;
  - `gcsim`, `timeline.py` and the sweeps (`heapsim.patch`, 3,598
    lines), `check-gcsim`;
  - `tests/gcbench` (3,990 lines);
  - `--gc-log` in the stock collector and `RUNE_MEMSTAT`;
  - `tools/mmu.py`;
  - the latency workloads into `examples/benchmarks`;
  - the evaluation set as a script that runs it and scores a VM against
    a baseline (`scripts/gc-eval.sh`).
* **Why now:** every later milestone is measured with these; the census
  has not built since heap-layout's M4.
* **Done when:** the traces of the bootstrap and of `compile-sigs` are
  made in the tree and pass `checktrace`; the simulator's validation
  against `runevm --stats` passes in `make check`; `scripts/gc-eval.sh`
  reproduces *Where we are*'s baselines within the noise.
* **Touches:** `runtime/census/*`, `tools/heapsim/*`, `tests/gcbench/`,
  `runtime/heap.c` (the log), `scripts/`, `examples/benchmarks/`,
  `docs/census.md`, `docs/testing.md`.

### M2. The collector behind an interface (L, about 1,500)

* **What:**
  - `runtime/heap.c` split into `runtime/gc/`: the allocator of D10's
    2 MiB chunks over new `sys` calls (reserve, commit, release, on POSIX and Windows); the
    nursery as `AllocState`; the old-space interface (*The
    architecture*), with today's copier as its implementation; the root
    scan.
  - The barrier's new signature in every engine:
    - `obj_set_field` and `obj_become_ind` in C;
    - both loops' `SETENV` (from `src/isa`);
    - `ms_barrier` with the value and the field;
    - and `runeopt`'s two missing barriers, as a template.
  - Images and `heap_relocate` over chunks.
  - `--gc-verify`, and `make test-heap` into `make check`.
  - The corrections of *Where the documents are wrong*.
* **Why now:** the nursery (M3) and both old-space prototypes (M4) plug
  in here, so the gate's comparison is of old spaces, not of plumbing --
  heap-layout's M3, for the collector.
* **Done when:**
  - byte-identical output and `--count` on every suite and engine, the
    same collections as before, and every portability VM and image
    direction;
  - `runeopt`'s barrier is checked by `check-templates`;
  - the evaluation set's T within 2% of the copier's.
* **Touches:** `runtime/heap.c` → `runtime/gc/`, `runtime/sys/`, `value.h`,
  `vm.h`, `image.c`, `masm.c`, `emit.c`, `src/isa`, `src/opt/x64.sml`,
  `templates.c`, `docs/runtime.md`, `lib/basis/runtime_sig.sml`, `AGENTS.md`.

### M3. The nursery, its remembered set, the watermark, large objects (L, about 1,500)

* **What:**
  - The prototype, made real: a fixed nursery (D2), promotion at the
    first survival into the copying old space of M2.
  - D6's filtered barrier with cards in the chunks' headers and dirty
    bytes per block.
  - D9's watermark and the hashed liveness lookup.
  - D5's large-object space, in runs of its own 4 KiB units.
  - The stack VM and `runeopt` supported.
* **Why now:** it is most of the memory and of the typical pause
  (*The experiments*), shippable on its own, and the base the old spaces
  are measured on.
* **Done when:**
  - Correct: the prototype's whole chain passes -- `--gc-verify` at
    three sizes on every engine, `--gc-stress 1`, the sanitiser, the
    32-bit VM, the Basis suite, MLton's set, the bootstrap's fixed point,
    `--count` unchanged.
  - On the evaluation set: the bootstrap at most 0.85 of today's
    task-clock and 0.5 of its peak; `merge` no slower than the copier.
  - Rune compiling MLton at most 1.0 of the copier, where the prototype
    took 1.29-1.60.
* **Touches:** `runtime/gc/`, the barrier's sites, `live.c`, `vm.h`
  (the frame's bit), `docs/runtime.md`, the budgets of `tests/perf`
  where the boxes' placement moves bytes (they should not).

### M4. Two old spaces at full scale, and the gate (XL, about 3,000)

* **What:** behind M2's interface and on M3's nursery, two prototypes,
  each in a branch:
  - **A:** mark-region with 64-byte lines, 32 KiB blocks, conservative
    line marking, recyclable and overflow blocks, bounded opportunistic
    evacuation;
  - **B:** segregated fits with size classes spaced at 1/8, mark bits in
    bitmaps, lazy sweeping.

  Both mark and sweep stop-the-world first, since incremental marking is
  M6's. Each is measured on the evaluation set, on the 32-bit VM with
  the address-space probe, and on Rune compiling MLton, with its
  fragmentation over the long runs and its promotion path's cost.
* **Why now:** the questions only a real heap answers (*What the
  experiments settle*).
* **Done when:** both pass M3's chain, and the tables of D1's targets
  are written for both against the copier and against M3. **The gate:**
  the owner decides D2 to D5, D7 and D8 again on them, and M5 to M8 are
  planned again.
* **Touches:** `runtime/gc/` (a file per old space), the census VM (the
  new allocation paths), `tools/heapsim` (the models recalibrated on the
  real ones).

### M5. The chosen old space, complete (L, about 1,500)

* **What:**
  - The winner made the default.
  - D4's fall-back compaction.
  - D10's growth, `--heap-fill`, `--heap-limit` and return of memory
    by free blocks.
  - Pinning in place (D17).
  - Images over chunks.
  - Windows, the 32-bit and big-endian VMs.
  - The rewritten pages of `docs/runtime.md` and of `runtime_sig.sml`'s
    `collect`.
* **Done when:** D1's memory target is met on both widths, and every
  suite, engine and portability VM passes.
* **Touches:** `runtime/gc/`, `runtime/sys/`, `image.c`, `docs/`.

### M6. Short pauses (L, about 1,200)

* **What:** D7:
  - incremental snapshot marking in slices paced by allocation and
    capped;
  - the snapshot log in the barrier, in every engine;
  - allocation black during a cycle;
  - lazy sweeping;
  - evacuation bounded in the final pause;
  - the fall-back that finishes a cycle;
  - `--gc-log` and `Runtime.stats` for cycles.
* **Done when:** D1's pause targets are met (longest at most 10 ms on the
  bootstrap and 100 MB, 20 ms at 1 GB live; 99th percentile at most 2
  ms; MMU at 10 ms at least 0.3 and 0.5), with the throughput target
  held; the schedule the same in every run; `--gc-stress` given a mode
  that starts a cycle at every Nth allocation.
* **Touches:** `runtime/gc/`, the barrier's sites, `masm.c`, the
  templates.

### M7. The cache, and the compiler's help (M, about 800)

* **What:**
  - The nursery's size chosen from the machine, and the adaptive sizing
    of D2 D, measured.
  - Prefetched marking (D11) and approximately depth-first promotion,
    measured.
  - Huge pages for the old space's chunks, measured on bare metal (D11).
  - Pretenuring by site from the compiler's build (D15 B), and the
    barrier elided where the JIT knows a value is immediate.

  Each is kept only if it pays on the evaluation set.
* **Touches:** `runtime/gc/`, `src/` (the site bit in the representations
  section), `runtime/register/jit/`.

### M8. What the second generation leaves (S, about 400)

* **What:**
  - `docs/runtime.md`'s collector as built.
  - `Runtime.stats` final.
  - Indirections shortcut at copy and mark (D18).
  - The third generation's brief (`garbage-collector-v3.md`) updated with
    what this one fixed and left (D16).
  - `collector.md` and this roadmap retired into `docs/`.

### Why this order

Measurement first (M1), because every decision after it is a number.
The interface before any collector (M2), so the gate compares old spaces
and not their plumbing, and so `runeopt`'s missing barrier is fixed
before anything depends on it. The nursery before the old space (M3)
because it is most of the gain the experiments measured, it is
shippable alone, and both old spaces sit behind it. The gate (M4) where
the evidence runs out. Pauses (M6) after the old space they mark is
chosen, since incremental marking is written against it. The cache and
the compiler's help last, because they are tuning on a collector that
exists.

## Prerequisites and flags

What this roadmap gives each plan around it, and when it becomes critical
to it.

* **The incremental compilation roadmap.** A resident compiler or a REPL
  keeps the basis and the user's program live for the whole session
  (`incremental-compilation.md`, D9 and its risk 4: "the copying
  collector copies the live basis ... at every collection"). M3 stops
  copying it at every collection, M5 holds it once; its M4 (the resident
  compiler) should come after this M3.
* **The FFI** (no roadmap yet). Large objects pinned in place from M3,
  every byte or real array of 8 KiB or more (D17); blocks with pinned
  objects never evacuated (M5). Handles as today.
* **The third generation** (`garbage-collector-v3.md`). What D16 fixes and
  leaves. Its threads need this roadmap's M6 at least.
* **A lazy front end.** D18: indirections shortcut by the copier and the
  marker, updates through the barrier; the remembered set measured on
  lazy programs at M3.
* **The JIT.** The barrier's fast path in line (M2, M6); the frame's
  watermark bit (M3). Pointers in registers with stack maps
  (`performance.md`, *Tier 2's registers*) touches the root scan and the
  watermark; whichever lands second adapts.
* **`runeopt`.** Its two inline stores get the barrier (M2); its template
  for allocation is unchanged (the nursery is `AllocState`).
* **A 32-bit VM's own word** (`32-bit-vm.md`). Independent; it would
  halve every space again, and the collector's metadata is sized per
  width already.
* **The real's encoding** (`real-encoding.md`): zero as a pointer to the
  VM's box makes the marker follow a pointer where it skipped an
  immediate; nothing more.
* **Green threads, delimited continuations** (`~/notes/virtual-machine.md`):
  stacks that are many and small; D9's watermark per frame and D16's
  allocation state per thread are the parts they build on.

## Relation to the other plans

| Elsewhere | Here |
|---|---|
| `performance.md` item 13, a generational collector | M3; its design (a nursery in front of the two spaces) is the prototype's, and this roadmap goes past it to an old space that does not copy |
| `performance.md`, *The gap to MLton* item 1: what is allocated and a collector that copies all that lives | the evaluation set's Rune compiling MLton; D1's target 3 |
| `performance.md`, *How good the JIT was*: "item 13's generational collector likely matters more" | M3 to M6 |
| `collector.md`, the brief, and its ten questions | *The request*'s table; D1 to D18 |
| heap-layout D6 (allocation: the bump kept, a large-object space designed in) | D5, D10: the large-object space built |
| heap-layout D7 (two roadmaps; a nursery pays at tight heaps) | revised by *The experiments*: on the word layout a nursery saves copying at today's heap too |
| heap-layout D8 (threads: allocation state per thread, header bits, mutability known by kind) | D16; the header's bits are not used (D8 here) |
| heap-layout D9 (the FFI: pin bit, copy around the call until a space does not move) | D17 |
| heap-layout D10 (images: the heap not collected before it is written) | D14: written by a full collection into chunks |
| heap-layout, *A lazy front end* | D18 |
| heap-layout D15 target 4 ("the nursery is a change to `heap.c` and the barrier's body alone") | not true of `runeopt`; M2 |
| heap-layout M7's growth table (doubling kept; the finer step for an old space not copied) | D10 |
| `32-bit-vm.md` (the collector's brief expects 32-bit targets to stay on it) | D13, D1's target 1 |
| `incremental-compilation.md` D9, risk 4 | *Prerequisites and flags* |
| `lazy-evaluation.md` (shared thunks, remembered set on update) | D18, D16 |
| `garbage-collector-v3.md` (generational, LOS, BIBOP, concurrent, NUMA, header bits) | D16; this roadmap's chunks and side tables are its BIBOP |
| `benchmarks.md` (allocation, peak live and process memory distinct; GCBench) | the evaluation set; the latency workloads join `examples/benchmarks` (M1) |
| `docs/runtime.md`, `runtime_sig.sml`, `AGENTS.md` | corrected in M2, rewritten in M5 and M8 |

## Risks

1. **The reference machine is not a typical one.** Under WSL2 the TLB
   reaches 4 MiB and a first touch costs a hypervisor fault; the nursery's
   size and the cost of fresh memory were measured there. *Mitigation:*
   M4 and M7 measure on bare metal where one is at hand, and the nursery
   size is a flag and, from M7, a property of the machine.
2. **The simulator knows when objects die, not why.** Nepotism (dead old
   objects keeping young ones alive) promoted 17.6% more on one program
   in the real VM; liveness between samples is banded; reads are not
   traced, so locality is modelled by the harness only. *Mitigation:* the
   old spaces are decided in the real VM at M4's gate, not on the
   simulator; the simulator chose what to prototype.
3. **Fragmentation over hours.** A trace is minutes of allocation; a
   resident compiler or a server runs for hours, where a non-moving
   space's holes accumulate. *Mitigation:* evacuation and the fall-back
   compaction (D4) bound it; M4 runs the latency workloads for long and
   reports the footprint over time.
4. **The barrier inside compiled code.** The harness measured gcc's C;
   the JIT's and `runeopt`'s barriers are emitted code, with the filter in
   line and a slow path out of line. *Mitigation:* `--count` cannot see
   it, so M2 and M6 measure instructions and cycles of the barrier's
   worst programs (`imp-for`, `many_refs`, the ring) at every tier.
5. **The watermark's invariant.** If any engine writes a waiting frame
   (a callee writing into its caller's registers, a deoptimisation, an
   image restore), a minor collection misses a root. *Mitigation:*
   `--gc-verify` checks every frame below the watermark at every minor
   collection in the test suites; the census records the lowest frame
   reached to check the invariant over the traces.
6. **Incremental marking and the budgets.** Slices paced by allocation
   keep the schedule deterministic but not the pauses' length; a burst
   of allocation can make a long slice (OCaml's 1,125 ms). *Mitigation:*
   capped slices and the finish-the-cycle fall-back (D7), measured on the
   latency workloads at M6.
7. **Memory on 32-bit is promised from a model.** The ceiling of D1 is
   reasoned from the chunks and the old space's footprint, not yet
   measured. *Mitigation:* M4 and M5 run the address-space probe on the
   32-bit VM with each old space.
8. **The prototype's numbers were made with a copying old space.** The
   memory and pauses of M3 alone are measured; what the old spaces add is
   modelled until M4. *Mitigation:* the gate.
9. **Other sessions, other branches.** The runtime moves under this
   roadmap (heap-layout moved under its own). *Mitigation:* M2 is the
   interface every later change goes through; each milestone rebases
   and re-measures its baseline.
10. **Session limits and the machine's memory.** This roadmap's own
    experiments lost a night to a simulator that took all the memory and
    to session limits. *Mitigation:* the drafts' rules (`ulimit -v` on
    every heavy process, a schedule with two slots and a timed lock, a
    new tool measured on a small input first) go into `docs/testing.md`
    with M1.

## Testing a collector change

* **The oracle** stays `--count`: unchanged by the collector, on every
  engine and width; and the program's output.
* **`--gc-verify`**: before every minor collection, every old object
  pointing into the nursery is in a dirty card or remembered, and every
  frame below the watermark holds no nursery pointer; after every
  collection, the chunks' tables agree with the objects. In `make
  test-heap`, which joins `make check` (M2), on `tests/lang` at three
  nursery sizes on every engine.
* **Stress**: `--gc-stress N` makes a minor collection at every Nth
  allocation, a mode makes a major cycle start at every Nth, and another
  forces evacuation of every block it can (M5, M6), each with
  `--gc-verify`.
* **The sanitiser builds** with the collector's tables poisoned where
  they are not in use.
* **The bootstrap's fixed point** at the nursery's and the old space's
  extreme sizes; the Basis suite; MLton's set against the stock output;
  the lazy programs; the latency workloads' digests.
* **Portability**: images across widths and byte orders over chunks;
  `make test-portability` and `make test-windows` before any change to
  the heap is done (`AGENTS.md`).
* **Rules for `AGENTS.md`** (M2): every store into an object that exists
  goes through the barrier with the value; nothing outside `runtime/gc/`
  knows a chunk's layout; a new allocation path names its space.

## Measuring

* **The evaluation set** (`scripts/gc-eval.sh`, M1): every workload of
  *The experiments* run on a candidate VM and the baseline, interleaved,
  the least task-clock of three rounds, alone on the machine (the
  drafts' timed lock); the scores T, M and P and the worst cases.
* **Pauses and MMU** from `--gc-log` by `tools/mmu.py`, on the wall
  clock (monotonic, never the program's `Time.now`, which WSL2 steps)
  and on the instruction clock.
* **Memory**: peak resident (`/usr/bin/time %M`), VmPeak and VmHWM, and
  the chunks committed, from `--gc-log`.
* **The census and the simulator** (`scripts/census.sh`, `bin/gcsim`,
  `tools/heapsim/sweep2.sh`) for the questions of survival, footprint,
  fragmentation and the remembered set; every new model checked against
  closed-form traces and against the real VM before its numbers are
  used.
* **Unit costs** by `tests/gcbench`; pauses fitted from `--gc-log` by the
  prototype's regression (`proto-coefficients.md`).
* **Instructions** (`perf stat -e instructions:u`) are exact; cycles only
  from interleaved runs on an idle machine; task-clock and page faults
  for anything that touches memory.

## References

The literature, as *What the literature says* cites it, sorted by first
author. Every DOI was fetched from Crossref again on 2026-10-06 and each
entry was rebuilt from its Crossref record (authors, year, title, venue,
pages); where Crossref misspells a name or a title (Demers, Zorn's
"mark-and-sweep", Hosking's "implementations") the paper's own spelling
is kept. The bracket says how each was read: in full, in part, or not
for this roadmap (the papers the owner supplied in
`/home/ruud/reference/papers` on 2026-10-06 were read in full or for
their results). Longer notes on each are in
`~/.cache/claude-rune-drafts/gc2/research/literature-review.md`.

* Diab Abuaiadh, Yoav Ossia, Erez Petrank and Uri Silbershtein. 2004. "An efficient parallel heap compaction algorithm." *OOPSLA 2004*, 224-236. doi:10.1145/1028976.1028995 (read in full)
* Andrew W. Appel, John R. Ellis and Kai Li. 1988. "Real-time concurrent collection on stock multiprocessors." *PLDI 1988*, 11-20. doi:10.1145/53990.53992 (read in full)
* Andrew W. Appel. 1989. "Simple generational garbage collection and fast allocation." *Software: Practice and Experience* 19(2), 171-183. doi:10.1002/spe.4380190206 (read in full)
* David F. Bacon, Perry Cheng and V. T. Rajan. 2003. "A real-time garbage collector with low overhead and consistent utilization." *POPL 2003*, 285-298. doi:10.1145/604131.604155 (read in full)
* David F. Bacon, Perry Cheng and V. T. Rajan. 2003. "Controlling fragmentation and space consumption in the Metronome, a real-time garbage collector for Java." *LCTES 2003*, 81-92. doi:10.1145/780732.780744; also registered as doi:10.1145/780742.780744 (read in full)
* David F. Bacon, Perry Cheng, David Grove, Michael Hind, V. T. Rajan, Eran Yahav, Matthias Hauswirth, Christoph M. Kirsch, Daniel Spoonhower and Martin T. Vechev. 2005. "High-level real-time programming in Java." *EMSOFT 2005*, 68-78. doi:10.1145/1086228.1086242 (read in full)
* Henry G. Baker. 1978. "List processing in real time on a serial computer." *Communications of the ACM* 21(4), 280-294. doi:10.1145/359460.359470 (read in full)
* Henry G. Baker. 1992. "The treadmill: real-time garbage collection without motion sickness." *ACM SIGPLAN Notices* 27(3), 66-70. doi:10.1145/130854.130862 (read in full)
* David A. Barrett and Benjamin G. Zorn. 1993. "Using lifetime predictors to improve memory allocation performance." *PLDI 1993*, 187-196. doi:10.1145/155090.155108 (read in full)
* Stephen M. Blackburn, Sharad Singhai, Matthew Hertz, Kathryn S. McKinley and J. Eliot B. Moss. 2001. "Pretenuring for Java." *OOPSLA 2001*, 342-352. doi:10.1145/504282.504307 (read in full)
* Stephen M. Blackburn and Kathryn S. McKinley. 2002. "In or out? Putting write barriers in their place." *ISMM 2002*, 175-184. doi:10.1145/512429.512452 (read in full)
* Stephen M. Blackburn, Richard Jones, Kathryn S. McKinley and J. Eliot B. Moss. 2002. "Beltway: getting around garbage collection gridlock." *PLDI 2002*, 153-164. doi:10.1145/512529.512548 (read in full)
* Stephen M. Blackburn and Kathryn S. McKinley. 2003. "Ulterior reference counting: fast garbage collection without a long wait." *OOPSLA 2003*, 344-358. doi:10.1145/949305.949336 (read in full)
* Stephen M. Blackburn and Antony L. Hosking. 2004. "Barriers: friend or foe?" *ISMM 2004*, 143-151. doi:10.1145/1029873.1029891 (read in full)
* Stephen M. Blackburn, Perry Cheng and Kathryn S. McKinley. 2004. "Myths and realities: the performance impact of garbage collection." *SIGMETRICS 2004*, 25-36. doi:10.1145/1005686.1005693 (read in full)
* Stephen M. Blackburn and Kathryn S. McKinley. 2008. "Immix: a mark-region garbage collector with space efficiency, fast collection, and mutator performance." *PLDI 2008*, 22-32. doi:10.1145/1375581.1375586 (read in full)
* Hans-J. Boehm, Alan J. Demers and Scott Shenker. 1991. "Mostly parallel garbage collection." *PLDI 1991*, 157-164. doi:10.1145/113445.113459 (read in full)
* Hans-J. Boehm. 2000. "Reducing garbage collector cache misses." *ISMM 2000*, 59-64. doi:10.1145/362422.362438 (read in full)
* Rodney A. Brooks. 1984. "Trading data space for reduced time and code space in real-time garbage collection on stock hardware." *LFP 1984*, 256-262. doi:10.1145/800055.802042 (read in full)
* G. Chen, M. Kandemir, N. Vijaykrishnan, M. J. Irwin, B. Mathiske and M. Wolczko. 2003. "Heap compression for memory-constrained Java environments." *OOPSLA 2003*, 282-301. doi:10.1145/949305.949330 (read in full)
* Perry Cheng, Robert Harper and Peter Lee. 1998. "Generational stack collection and profile-driven pretenuring." *PLDI 1998*, 162-173. doi:10.1145/277650.277718 (read in full)
* Perry Cheng and Guy E. Blelloch. 2001. "A parallel, real-time garbage collector." *PLDI 2001*, 125-136. doi:10.1145/378795.378823 (read in full)
* Chen-Yong Cher, Antony L. Hosking and T. N. Vijaykumar. 2004. "Software prefetching for mark-sweep garbage collection: hardware analysis and software redesign." *ASPLOS 2004*, 199-210. doi:10.1145/1024393.1024417 (read in full)
* Trishul M. Chilimbi and James R. Larus. 1998. "Using generational garbage collection to implement cache-conscious data placement." *ISMM 1998*, 37-48. doi:10.1145/286860.286865 (read in full)
* Cliff Click, Gil Tene and Michael Wolf. 2005. "The pauseless GC algorithm." *VEE 2005*, 46-56. doi:10.1145/1064979.1064988 (read in full)
* William D. Clinger and Lars T. Hansen. 1997. "Generational garbage collection and the radioactive decay model." *PLDI 1997*, 97-108. doi:10.1145/258915.258925 (read in part)
* Jacques Cohen and Alexandru Nicolau. 1983. "Comparison of compacting algorithms for garbage collection." *ACM Transactions on Programming Languages and Systems* 5(4), 532-553. doi:10.1145/69575.357226 (read in full)
* Ulan Degenbaev, Jochen Eisinger, Manfred Ernst, Ross McIlroy and Hannes Payer. 2016. "Idle time garbage collection scheduling." *PLDI 2016*, 570-583. doi:10.1145/2908080.2908106 (read in full)
* Alan Demers, Mark Weiser, Barry Hayes, Hans Boehm, Daniel Bobrow and Scott Shenker. 1990. "Combining generational and conservative garbage collection: framework and implementations." *POPL 1990*, 261-269. doi:10.1145/96709.96735 (read in full)
* David Detlefs, Christine Flood, Steve Heller and Tony Printezis. 2004. "Garbage-first garbage collection." *ISMM 2004*, 37-48. doi:10.1145/1029873.1029879 (read in full)
* Edsger W. Dijkstra, Leslie Lamport, A. J. Martin, C. S. Scholten and E. F. M. Steffens. 1978. "On-the-fly garbage collection: an exercise in cooperation." *Communications of the ACM* 21(11), 966-975. doi:10.1145/359642.359655 (read in full)
* Amer Diwan, David Tarditi and Eliot Moss. 1994. "Memory subsystem performance of programs using copying garbage collection." *POPL 1994*, 1-14. doi:10.1145/174675.174710 (read in full)
* Damien Doligez and Xavier Leroy. 1993. "A concurrent, generational garbage collector for a multithreaded implementation of ML." *POPL 1993*, 113-123. doi:10.1145/158511.158611 (read in full)
* Damien Doligez and Georges Gonthier. 1994. "Portable, unobtrusive garbage collection for multiprocessor systems." *POPL 1994*, 70-83. doi:10.1145/174675.174673 (read in full)
* R. Kent Dybvig, David Eby and Carl Bruggeman. 1994. "Don't stop the BIBOP: flexible and efficient storage management for dynamically-typed languages." Technical Report 400, Computer Science Department, Indiana University. No DOI (read in full)
* Martin Elsman and Niels Hallenberg. 2021. "Integrating region memory management and tag-free generational garbage collection." *Journal of Functional Programming* 31, e4. doi:10.1017/s0956796821000010 (read in full)
* Ben Gamari and Laura Dietz. 2020. "Alligator collector: a latency-optimized garbage collector for functional programming languages." *ISMM 2020*, 87-99. doi:10.1145/3381898.3397214 (read in full)
* Robin Garner, Stephen M. Blackburn and Daniel Frampton. 2007. "Effective prefetch for mark-sweep garbage collection." *ISMM 2007*, 43-54. doi:10.1145/1296907.1296915 (read in full)
* Marcelo J. R. Gonçalves and Andrew W. Appel. 1995. "Cache performance of fast-allocating programs." *FPCA 1995*, 293-305. doi:10.1145/224164.224219 (read in full)
* Niels Hallenberg, Martin Elsman and Mads Tofte. 2002. "Combining region inference and garbage collection." *PLDI 2002*, 141-152. doi:10.1145/512529.512547 (read in full)
* Lars T. Hansen and William D. Clinger. 2002. "An experimental study of renewal-older-first garbage collection." *ICFP 2002*, 247-258. doi:10.1145/581478.581502 (read in full)
* Timothy L. Harris. 2000. "Dynamic adaptive pre-tenuring." *ISMM 2000*, 127-136. doi:10.1145/362422.362476 (read in full)
* Barry Hayes. 1991. "Using key object opportunism to collect old objects." *OOPSLA 1991*, 33-46. doi:10.1145/117954.117957 (read in full)
* Matthew Hertz and Emery D. Berger. 2005. "Quantifying the performance of garbage collection vs. explicit memory management." *OOPSLA 2005*, 313-326. doi:10.1145/1094811.1094836 (read in full)
* Matthew Hertz, Yi Feng and Emery D. Berger. 2005. "Garbage collection without paging." *PLDI 2005*, 143-153. doi:10.1145/1065010.1065028 (read in full)
* Urs Hölzle. 1993. "A fast write barrier for generational garbage collectors." *OOPSLA '93 Workshop on Garbage Collection and Memory Management*. No DOI (read in full)
* Antony L. Hosking, J. Eliot B. Moss and Darko Stefanović. 1992. "A comparative performance evaluation of write barrier implementations." *OOPSLA 1992*, 92-109. doi:10.1145/141936.141946; also *ACM SIGPLAN Notices* 27(10), doi:10.1145/141937.141946 (read in full)
* Antony L. Hosking and Richard L. Hudson. 1993. "Remembered sets can also play cards." *OOPSLA '93 Workshop on Garbage Collection and Memory Management*. No DOI (read in full)
* Xianglong Huang, Stephen M. Blackburn, Kathryn S. McKinley, J. Eliot B. Moss, Zhenlin Wang and Perry Cheng. 2004. "The garbage collection advantage: improving program locality." *OOPSLA 2004*, 69-80. doi:10.1145/1028976.1028983 (read in full)
* Lorenz Huelsbergen and James R. Larus. 1993. "A concurrent copying garbage collector for languages that distinguish (im)mutable data." *PPoPP 1993*, 73-82. doi:10.1145/155332.155340 (read in part)
* Dan Ingalls, Ted Kaehler, John Maloney, Scott Wallace and Alan Kay. 1997. "Back to the future: the story of Squeak, a practical Smalltalk written in itself." *OOPSLA 1997*, 318-326. doi:10.1145/263698.263754 (read in full)
* Mark S. Johnstone and Paul R. Wilson. 1998. "The memory fragmentation problem: solved?" *ISMM 1998*, 26-36. doi:10.1145/286860.286864 (read in full)
* Richard E. Jones and Chris Ryder. 2008. "A study of Java object demographics." *ISMM 2008*, 121-130. doi:10.1145/1375634.1375652 (read in full)
* Richard Jones, Antony Hosking and Eliot Moss. 2023. *The Garbage Collection Handbook: The Art of Automatic Memory Management*, 2nd edition. Chapman and Hall/CRC. doi:10.1201/9781003276142 (read in part: the table of contents, and sections 9.6-9.9, 10.1, 10.6-10.8, 11.5, 11.9, 11.11, 15.2, 16.2-16.3 and 19.2-19.7 as a cross-check)
* H. B. M. Jonkers. 1979. "A fast garbage compaction algorithm." *Information Processing Letters* 9(1), 26-30. doi:10.1016/0020-0190(79)90103-0 (read in full)
* Haim Kermany and Erez Petrank. 2006. "The Compressor: concurrent, incremental, and parallel compaction." *PLDI 2006*, 354-363. doi:10.1145/1133981.1134023 (read in full)
* Henry Lieberman and Carl Hewitt. 1983. "A real-time garbage collector based on the lifetimes of objects." *Communications of the ACM* 26(6), 419-429. doi:10.1145/358141.358147 (read in full)
* Simon Marlow, Tim Harris, Roshan P. James and Simon Peyton Jones. 2008. "Parallel generational-copying garbage collection with a block-structured heap." *ISMM 2008*, 11-20. doi:10.1145/1375634.1375637 (read in full)
* Simon Marlow and Simon Peyton Jones. 2011. "Multicore garbage collection with local heaps." *ISMM 2011*, 21-32. doi:10.1145/1993478.1993482 (read in full)
* Phil McGachey and Antony L. Hosking. 2006. "Reducing generational copy reserve overhead with fallback compaction." *ISMM 2006*, 17-28. doi:10.1145/1133956.1133960 (not read; known through the handbook, section 9.9)
* MicroPython project. n.d. "Memory management." *MicroPython documentation*, docs.micropython.org/en/latest/develop/memorymgt.html. No DOI (read in full)
* David A. Moon. 1984. "Garbage collection in a large LISP system." *LFP 1984*, 235-246. doi:10.1145/800055.802040 (read in full)
* Scott Nettles and James O'Toole. 1993. "Real-time replication garbage collection." *PLDI 1993*, 217-226. doi:10.1145/155090.155111 (read in full)
* James O'Toole and Scott Nettles. 1994. "Concurrent replicating garbage collection." *LFP 1994*, 34-42. doi:10.1145/182409.182425 (read in full)
* Yoav Ossia, Ori Ben-Yitzhak and Marc Segal. 2004. "Mostly concurrent compaction for mark-sweep GC." *ISMM 2004*, 25-36. doi:10.1145/1029873.1029877 (read in full)
* Pekka P. Pirinen. 1998. "Barrier techniques for incremental tracing." *ISMM 1998*, 20-25. doi:10.1145/286860.286863 (read in full)
* Filip Pizlo, Daniel Frampton, Erez Petrank and Bjarne Steensgaard. 2007. "Stopless: a real-time garbage collector for multiprocessors." *ISMM 2007*, 159-172. doi:10.1145/1296907.1296927 (read in full)
* Filip Pizlo, Erez Petrank and Bjarne Steensgaard. 2008. "A study of concurrent real-time garbage collectors." *PLDI 2008*, 33-44. doi:10.1145/1375581.1375587 (read in full)
* Filip Pizlo, Lukasz Ziarek, Petr Maj, Antony L. Hosking, Ethan Blanton and Jan Vitek. 2010. "Schism: fragmentation-tolerant real-time garbage collection." *PLDI 2010*, 146-159. doi:10.1145/1806596.1806615 (read in full)
* Tony Printezis and David Detlefs. 2000. "A generational mostly-concurrent garbage collector." *ISMM 2000*, 143-154. doi:10.1145/362422.362480 (read in full)
* Alex Reinking, Ningning Xie, Leonardo de Moura and Daan Leijen. 2021. "Perceus: garbage free reference counting with reuse." *PLDI 2021*, 96-111. doi:10.1145/3453483.3454032 (read in full)
* John H. Reppy. 1993. "A high-performance garbage collector for Standard ML." Technical Memorandum BL011261-940329-12TM, AT&T Bell Laboratories. No DOI (read in full)
* Narendran Sachindran and J. Eliot B. Moss. 2003. "Mark-copy: fast copying GC with less space overhead." *OOPSLA 2003*, 326-343. doi:10.1145/949305.949335 (read in full)
* Narendran Sachindran, J. Eliot B. Moss and Emery D. Berger. 2004. "MC²: high-performance garbage collection for memory-constrained environments." *OOPSLA 2004*, 81-98. doi:10.1145/1028976.1028984 (read in full)
* Patrick M. Sansom. 1992. "Combining single-space and two-space compacting garbage collectors." In *Functional Programming, Glasgow 1991*, Workshops in Computing, Springer, 312-323 (an earlier version: "Dual-mode garbage collection"). No DOI (read in full)
* Patrick M. Sansom and Simon L. Peyton Jones. 1993. "Generational garbage collection for Haskell." *FPCA 1993*, 106-116. doi:10.1145/165180.165195 (not read for this roadmap; cited as heap-layout cites it)
* Rifat Shahriyar, Stephen M. Blackburn and Daniel Frampton. 2012. "Down for the count? Getting reference counting back in the ring." *ISMM 2012*, 73-84. doi:10.1145/2258996.2259008 (read in full)
* Rifat Shahriyar, Stephen M. Blackburn, Xi Yang and Kathryn S. McKinley. 2013. "Taking off the gloves with reference counting Immix." *OOPSLA 2013*, 93-110. doi:10.1145/2509136.2509527 (read in full)
* KC Sivaramakrishnan, Stephen Dolan, Leo White, Sadiq Jaffer, Tom Kelly, Anmol Sahoo, Sudha Parimala, Atul Dhiman and Anil Madhavapeddy. 2020. "Retrofitting parallelism onto OCaml." *Proceedings of the ACM on Programming Languages* 4(ICFP), 113:1-113:30. doi:10.1145/3408995 (read in full)
* Guy L. Steele Jr. 1975. "Multiprocessing compactifying garbage collection." *Communications of the ACM* 18(9), 495-508. doi:10.1145/361002.361005 (read in full)
* Darko Stefanović and J. Eliot B. Moss. 1994. "Characterization of object behaviour in Standard ML of New Jersey." *LFP 1994*, 43-54. doi:10.1145/182409.182428 (read in full)
* Darko Stefanović, Kathryn S. McKinley and J. Eliot B. Moss. 1999. "Age-based garbage collection." *OOPSLA 1999*, 370-381. doi:10.1145/320384.320425 (read in full)
* David Tarditi and Amer Diwan. 1996. "Measuring the cost of storage management." *Lisp and Symbolic Computation* 9(4), 323-342. doi:10.1007/bf01806316 (not read for this roadmap; heap-layout read the technical report)
* Gil Tene, Balaji Iyengar and Michael Wolf. 2011. "C4: the continuously concurrent compacting collector." *ISMM 2011*, 79-88. doi:10.1145/1993478.1993491 (read in full)
* Katsuhiro Ueno, Atsushi Ohori and Toshiaki Otomo. 2011. "An efficient non-moving garbage collector for functional languages." *ICFP 2011*, 196-208. doi:10.1145/2034773.2034802 (read in full)
* Katsuhiro Ueno and Atsushi Ohori. 2016. "A fully concurrent garbage collector for functional programs on multicore processors." *ICFP 2016*, 421-433. doi:10.1145/2951913.2951944 (read in full)
* David Ungar. 1984. "Generation scavenging: a non-disruptive high performance storage reclamation algorithm." *SDE 1: ACM SIGSOFT/SIGPLAN Software Engineering Symposium on Practical Software Development Environments*, 157-167. doi:10.1145/800020.808261 (read in full)
* David Ungar and Frank Jackson. 1988. "Tenuring policies for generation-based storage reclamation." *OOPSLA 1988*, 1-17. doi:10.1145/62083.62085 (read in full)
* David Ungar and Frank Jackson. 1992. "An adaptive tenuring policy for generation scavengers." *ACM Transactions on Programming Languages and Systems* 14(1), 1-27. doi:10.1145/111186.116734 (read in full)
* Paul R. Wilson and Thomas G. Moher. 1989. "Design of the opportunistic garbage collector." *OOPSLA 1989*, 23-35. doi:10.1145/74877.74882 (read in full)
* Paul R. Wilson, Michael S. Lam and Thomas G. Moher. 1991. "Effective 'static-graph' reorganization to improve locality in garbage-collected systems." *PLDI 1991*, 177-191. doi:10.1145/113445.113461 (read in full)
* Paul R. Wilson, Michael S. Lam and Thomas G. Moher. 1992. "Caching considerations for generational garbage collection." *LFP 1992*, 32-42. doi:10.1145/141471.141500; also *ACM SIGPLAN Lisp Pointers* V(1), doi:10.1145/141478.141500 (read in full)
* Paul R. Wilson, Mark S. Johnstone, Michael Neely and David Boles. 1995. "Dynamic storage allocation: a survey and critical review." *Memory Management (IWMM 1995)*, Lecture Notes in Computer Science 986, 1-116. doi:10.1007/3-540-60368-9_19 (read in part)
* Ting Yang, Matthew Hertz, Emery D. Berger, Scott F. Kaplan and J. Eliot B. Moss. 2004. "Automatic heap sizing: taking real memory into account." *ISMM 2004*, 61-72. doi:10.1145/1029873.1029881 (read in full)
* Ting Yang, Emery D. Berger, Scott F. Kaplan and J. Eliot B. Moss. 2006. "CRAMM: virtual memory support for garbage-collected applications." *OSDI 2006*. No DOI (read in part)
* Xi Yang, Stephen M. Blackburn, Daniel Frampton and Antony L. Hosking. 2012. "Barriers reconsidered, friendlier still!" *ISMM 2012*, 37-48. doi:10.1145/2258996.2259004 (read in full)
* Taiichi Yuasa. 1990. "Real-time garbage collection on general-purpose machines." *Journal of Systems and Software* 11(3), 181-198. doi:10.1016/0164-1212(90)90084-Y (read in full)
* Wenyu Zhao, Stephen M. Blackburn and Kathryn S. McKinley. 2022. "Low-latency, high-throughput garbage collection." *PLDI 2022*, 76-91. doi:10.1145/3519939.3523440 (read in full)
* Benjamin Zorn. 1990. "Comparing mark-and-sweep and stop-and-copy garbage collection." *LFP 1990*, 87-98. doi:10.1145/91556.91597 (read in full)

### The implementations

The collectors read for *What the implementations do*; every path is
relative to `/home/ruud/reference`.

* OCaml 4.14.4: `ocaml4/runtime/{minor_gc,major_gc,freelist,compact,memory}.c`, `ocaml4/runtime/caml/config.h`
* OCaml 5.5.1: `ocaml5/runtime/{shared_heap,major_gc,minor_gc,fiber,domain}.c`, `ocaml5/runtime/caml/sizeclasses.h`
* MLton 20241230: `mlton/runtime/gc/` (`garbage-collection.c`, `heap.c`, `generational.h`, `init.c`), `mlton/mlton/backend/ssa2-to-rssa.fun` (the barrier)
* SML/NJ 2026.2 and 110.99.9: `smlnj/runtime/gc/`, `smlnj-legacy/base/runtime/gc/`
* Poly/ML 5.9.2: `polyml/libpolyml/` (`gc.cpp`, `gc_mark_phase.cpp`, `gc_copy_phase.cpp`, `gc_update_phase.cpp`, `quick_gc.cpp`, `heapsizing.cpp`, `memmgr.cpp`)
* MLKit 4.7.23: `mlkit/src/Runtime/` (`GC.c`, `Region.c`)
* Chez Scheme 10: `ChezScheme/c/{gc.c,segment.c,segment.h}`, `ChezScheme/s/cmacros.ss`
* GHC 9.14.1: `ghc/rts/sm/`, `ghc/rts/include/rts/Constants.h`
* Spur (Pharo): `smalltalk/pharo-vm/smalltalksrc/VMMaker/SpurMemoryManager.class.st`, `SpurGenerationScavenger.class.st`
* Dart 3.13.4: `dart-lang/sdk/runtime/vm/heap/`, `dart-lang/sdk/runtime/vm/raw_object.h`, `dart-lang/sdk/runtime/docs/gc.md`
* PyPy incminimark: `python/pypy/rpython/memory/gc/{incminimark.py,minimarkpage.py,env.py}`, `python/pypy/pypy/doc/gc_info.rst`
* CPython 3.14.7: `python/MetaPython/Python/gc.c`, `python/MetaPython/Doc/whatsnew/3.14.rst`
* SpiderMonkey: `javascript/SpiderMonkey/src/gc/`, `javascript/SpiderMonkey/public/HeapAPI.h`, `javascript/SpiderMonkey/src/doc/gc.md`
* V8: `javascript/v8/src/heap/`
* JavaScriptCore: `javascript/JavaScriptCore/heap/`
* Julia 1.13: `JuliaLang/julia/src/gc-stock.c`, `JuliaLang/julia/src/gc-common.c`
* Go 1.27.1: `golang/go/src/runtime/` (`mgc.go` and its neighbours)
* HotSpot (about JDK 27): `java/jdk/src/hotspot/share/gc/{serial,g1,shenandoah,shared}/`
* SubstrateVM: `java/graal/substratevm/src/com.oracle.svm.core.genscavenge/`
* LuaJIT 2.1: `lua/LuaJIT/src/lj_gc.c`
* Erlang/OTP: `erlang/otp/erts/emulator/beam/erl_gc.c`
* Outside the design space: Koka `koka/kklib/`, Wasmtime `wasmtime/crates/wasmtime/src/runtime/gc/`, Guile `guile/libguile/gc.c`, Swift `swiftlang/swift`

### The owner's copies

The PDFs in `/home/ruud/reference/papers`, and the entry each is:

* `1029873.1029891.pdf`: Blackburn and Hosking 2004
* `141478.141500.pdf`: Wilson, Lam and Moher 1992 (the *Lisp Pointers* DOI)
* `TR400.pdf`: Dybvig, Eby and Bruggeman 1994
* `The-Garbage-Collection-Handbook.pdf`: Jones, Hosking and Moss 2023
* `bacon2003.pdf`: Bacon, Cheng and Rajan 2003 (POPL); `bacon2003b.pdf`: Bacon, Cheng and Rajan 2003 (LCTES); `bacon2005.pdf`: Bacon et al. 2005
* `barrett1993.pdf`: Barrett and Zorn 1993
* `boehm2000.pdf`: Boehm 2000
* `brooks1984.pdf`: Brooks 1984
* `chen2003.pdf`: Chen et al. 2003
* `cheng1998.pdf`: Cheng, Harper and Lee 1998
* `chilimbi1998.pdf`: Chilimbi and Larus 1998
* `click2005.pdf`: Click, Tene and Wolf 2005
* `clinger1997.pdf`: Clinger and Hansen 1997
* `cohen1983.pdf`: Cohen and Nicolau 1983
* `demmers1990.pdf`: Demers et al. 1990
* `doligez1994.pdf`: Doligez and Gonthier 1994
* `functional-programming-glasgow-1991-1992.pdf`: Sansom 1992 (pp. 321-330 of the PDF)
* `hansen2002.pdf`: Hansen and Clinger 2002
* `harris2000.pdf`: Harris 2000
* `hayes1991.pdf`: Hayes 1991
* `hosking1992.pdf`: Hosking, Moss and Stefanović 1992
* `huelsbergen1993.pdf`: Huelsbergen and Larus 1993 (its text layer is garbled)
* `jones2008.pdf`: Jones and Ryder 2008
* `jonkers1979.pdf`: Jonkers 1979
* `moon1984.pdf`: Moon 1984
* `ossia2004.pdf`: Ossia, Ben-Yitzhak and Segal 2004
* `pirinen1998.pdf`: Pirinen 1998
* `printezis2000.pdf`: Printezis and Detlefs 2000
* `steele1975.pdf`: Steele 1975
* `tene2011.pdf`: Tene, Iyengar and Wolf 2011
* `tm-gc.pdf`: Reppy 1993
* `ueno2011.pdf`: Ueno, Ohori and Otomo 2011; `ueno2016.pdf`: Ueno and Ohori 2016
* `ungar1988.pdf`: Ungar and Jackson 1988; `ungar1992.pdf`: Ungar and Jackson 1992
* `wilson1989.pdf`: Wilson and Moher 1989
* `wilson1991.pdf`: Wilson, Lam and Moher 1991
* `yang2004.pdf`: Yang, Hertz, Berger, Kaplan and Moss 2004
* `yuasa1990.pdf`: Yuasa 1990
* Not references of this roadmap: `appel1989.pdf` (Appel, "Runtime tags aren't necessary", *Lisp and Symbolic Computation* 2, 1989 -- not Appel 1989 above), `Bacon02Space.pdf` (Bacon, Fink and Grove, the Java object model, ECOOP 2002), `TR93-27.pdf` and `10.1.1.39.4394.pdf` (Gudeman 1993, type representation), `tyde24-final67.pdf` (Reppy and Soss, a type- and control-flow analysis for System FC)

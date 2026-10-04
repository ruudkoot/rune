# A 32-bit VM's own word: experiments left to run

Claude, 2026-10-04, at the gate of heap-layout M4. `heap-layout.md`
had decided that a 32-bit VM gets the machine's word (D13 B) with a
4-byte header and a layout table (D4 B and D). None of that was
prototyped, and at the gate the owner chose the 8-byte word on every
width for M5 (D13 A). This file is what is known, and the experiments
that would say whether a 32-bit VM's own layout is worth building
after M5, each with how to run it and what its result would change.
None of them blocks M5.

## Where it stands

**What M5 builds.** One layout on every machine: a value is an 8-byte
tagged word, two machine words on i386, a pointer in the low half;
`Int` and `Word` are 63 bits everywhere, in software on a 32-bit
machine; the header is 8 bytes. Bytes allocated, objects and images
are equal across widths, which is what `make test-portability` and
`make test-windows` check today, and both prototypes pass them.

**What had been decided and is not built** (`heap-layout.md`, D13 B
and D4):

* A 4-byte tagged word: `Int` and `Word` 31 bits immediate, a pointer
  the machine's, `IntN` and `WordN` above the word boxed.
* A 4-byte header: kind (4 bits), the collector's four bits, a 12-bit
  index into a per-program layout table (the constructor's tag and
  which fields are raw), a 12-bit length whose all-ones value says the
  length follows in the next word.
* One bytecode for both widths: the compiler folds an integer constant
  only when the result fits 32 bits, so that the 32-bit VM raises
  `Overflow` where the 64-bit one computes.
* `--count`'s bytes per width (instructions and objects still equal);
  an image of a 64-bit VM restored on a 32-bit one only when every
  integer in it fits.

A list cell is 40 bytes today, 24 under M5's word on any machine, and
would be 12 under the 4-byte word and header.

**The 32-bit VMs that exist:** `bin/runevm32` and `bin/runevm-stack32`
(i386 Linux, `-m32 -msse2`), their Windows builds (`bin/runevm32.exe`,
`bin/runevm-stack32.exe`). They interpret; the JIT is x86-64 and
aarch64, `runeopt` x86-64. wasm32 is a brief (`web-native.md`). The
collector's brief (`garbage-collector-v2.md`) expects the 32-bit
targets to stay on the second collector and asks it to be frugal with
physical and virtual memory for their sake.

**First figures** (2026-10-04, while another suite ran on the machine,
so instructions only; `perf stat`, one run):

| Program | 16-byte layout: 32-bit interpreter against the 64-bit one | 32-bit interpreter: M5's word against the 16-byte layout |
|---|---:|---:|
| bootstrap | 1.50 (41.0G against 27.3G) | 1.03 |
| fib | 1.62 | 1.02 |
| tak | 1.62 | 1.01 |
| word_bits | 1.48 | 1.01 |
| real_nbody | 1.44 | 1.22 |
| list_ops | 1.55 | 1.02 |
| string_ops | 1.38 | 1.03 |
| array_sieve | 1.61 | 1.05 |
| intinf_fact | 1.56 | 1.02 |

"M5's word" is `bin/runevm32` of branch `heap-layout-word` built with
`-DRUNE_INT63 -DRUNE_REAL_ROT`. Its bootstrap allocates 0.59 of the
16-byte layout's bytes, as on a 64-bit machine. So M5 gives the 32-bit
VMs the memory and leaves the time where it is: a few per cent more
instructions (the tag's shift in two-word arithmetic), a fifth more
on reals, and the 1.4 to 1.6 times they are behind the 64-bit
interpreter untouched. With Koka's encoding `real_nbody` is 2.04 on
the 32-bit interpreter, which is one more reason for the rotation.

## The experiments

Ordered so that the cheap ones, which can end the question, come
first.

### 1. The baseline, on an idle machine

* **The question.** What M5's word gives a 32-bit VM in cycles and in
  resident memory, which is what any layout of its own has to beat.
  The table above has instructions alone, from a busy machine.
* **How.** `bin/runevm32` and `bin/runevm-stack32` of the 16-byte
  layout and of the finished M5 layout: cycles, `task-clock`, the peak
  resident set (`/usr/bin/time %M`), collections and bytes copied
  (`--stats`), on the bootstrap, the eight programs of `tests/perf` and
  MLton's set (`tests/external/run-mlton-bench.sh --vm`), the least of
  three runs.
* **What it changes.** If the word is already level or ahead in
  cycles with half the memory, the remaining gain is the next
  experiment's to size.

### 2. Where the 32-bit interpreter's 1.5 times goes

* **The question.** A 32-bit VM is 1.4 to 1.6 times the instructions
  of the 64-bit one on the same bytecode. A 4-byte word removes the
  64-bit arithmetic in software and the two-word move of every value;
  it does not remove what i386 itself costs (seven general registers
  for the dispatch loop, arguments on the stack).
* **How.** `perf record` by symbol and `perf annotate` of the hot
  cases of the loop on `fib`, `list_ops` and the bootstrap, under
  `bin/runevm32` and `bin/runevm --jit=off`; the share in `__divdi3`
  and its kin, in overflow checks, in moves of values. Then the upper
  bound without building a layout: the layout harness
  (`tests/layouts`) compiled with `-m32`, its `L1` against a copy with
  a 4-byte `val`, on `int_loop`, `list_ops`, `intmap` and `closures`.
* **What it changes.** Whether there is time to win at all. If most of
  the gap is i386's, the case for a layout of its own rests on memory
  alone.

### 3. The bytes of a 4-byte word, from the traces that exist

* **The question.** How much smaller the heap is under a 4-byte word
  and header, and how many integers it boxes at 31 bits.
* **How.** A variant in `runtime/census/layouts.h` and `tools/heapsim`:
  word 4, header 4 with the length escape above 4,095, alignment 8 (a
  pointer needs its low bits) and 4 beside it, an integer or word
  above 31 bits boxed, a real boxed. The census records each field's
  bits class (at most 8, 31, 48, 51, 62, 63, 64), so the traces
  archived under `/mnt/h/HEAPSIM/heap-layout/traces` (the bootstrap,
  `compile-sigs`, the programs of `tests/perf`, MLton's set) answer it
  with no new run: bytes, boxes, bytes copied, and L, the most a
  collection keeps.
* **What it changes.** The memory side of the decision: a process's
  peak is two semispaces, and the bootstrap's is 533 MB today and
  274 MB under M5's word (measured on the 64-bit VM; the heap is the
  same on a 32-bit one).

### 4. What breaks at 31 bits

* **The question.** `Int.precision` 31 and `Word.wordSize` 31 on a
  32-bit VM: which programs and which of the Basis' checks notice.
  At 63 bits it was seven programs and 34 checks.
* **How.** A switch on the word prototype that holds integers and
  words to 31 bits in the 8-byte word (`Overflow` past them, words
  wrapping), which needs no new layout: `tests/lang`, the Basis suite,
  `make test-lib`, MLton's set, and the compiler compiling itself. The
  compiler's sources are known to run on a 31-bit host (SML/NJ's
  32-bit build makes `bin/rune-smlnj32`), so the bootstrap should
  pass; the libraries are the unknown (`lib/random` is `Word64`
  throughout).
* **What it changes.** The size of the Basis and library work, and
  whether "one bytecode for both widths" is honest: a program whose
  results differ between a 31-bit and a 63-bit `Int` is two programs.

### 5. One bytecode, two precisions

* **The question.** The rule that the compiler folds a constant only
  when it fits 32 bits costs the 64-bit code something, or nothing.
  The other way is a bytecode per precision, chosen when compiling.
* **How.** Count, in the middle end's folding, the folds whose result
  is above 31 bits on the bootstrap, the Basis and the benchmarks, and
  the cycles of the 64-bit VMs with those folds refused. `Int.maxInt`,
  `Int.precision` and `Word.wordSize` must then be values the VM
  supplies and not constants in the bytecode: count their uses too.
* **What it changes.** Which of the two the 32-bit VM is built on. If
  refusing the folds shows in the 64-bit numbers, it is a bytecode per
  precision, and images and `.rbc` files say which they are.

### 6. Reals on a 4-byte word

* **The question.** A double does not fit a 4-byte word with any
  encoding. Either every real is a box (12 or 16 bytes, an allocation
  at every result the interpreter keeps) or a real takes two slots,
  which needs slots whose kind the VM knows (D5 B). On the 8-byte word
  the 32-bit interpreter pays 1.22 for the rotation and 2.04 for
  Koka's on `real_nbody`.
* **How.** In the harness built with `-m32`: `real_regs` and
  `real_array` with reals boxed, and with a two-word real in a typed
  slot; then `real_nbody` and the eight programs of reals on a VM
  build that boxes every real (`-DRUNE_REAL_BOXED` gives the 64-bit
  figure today: 2.80 times the instructions in the interpreter).
* **What it changes.** Possibly the whole plan: if boxed reals cost a
  32-bit VM a factor of two or three on numeric code, the 4-byte word
  wants typed slots with it, and that is a larger milestone than the
  word.

### 7. The 4-byte header and the layout table

* **The question.** D4 B and D as designed: does a 12-bit length with
  an escape and a 12-bit table index hold (the bootstrap has 1,435
  shapes and its largest constructor tag is 31), and what does the
  branch at every length read cost.
* **How.** The harness has `L1+HDR4`, a 4-byte header on the 8-byte
  word, where alignment gives the saving back (0.03% in the census).
  With `-m32` and a 4-byte `val` it is the real thing: the kernels'
  bytes and cycles, strings and arrays over 4,095 elements among them.
  The shapes per program from the static census (`static.tsv`) for the
  corpora, to see how far 4,096 layouts are from full.
* **What it changes.** The header's bit split, or the table dropped
  for an 8-byte header on the 4-byte word if the escape and the index
  cost more than four bytes an object.

### 8. What the tests compare across widths

* **The question.** Today one `--count` line and one image serve every
  VM. With a word per width the bytes differ, and an image crosses
  from 64 to 32 bits only if its integers fit.
* **How.** No measurement but one: how many integers above 31 bits
  the heap of a typical image holds (the census's bits classes at the
  end of the bootstrap and of the REPL's start). The rest is design:
  instructions and objects compared across widths, bytes within one;
  the budgets the 64-bit machine's; `Runtime.restore` refusing what
  does not fit.
* **What it changes.** `tests/run-portability.sh`,
  `tests/run-windows.sh`, and incremental-compilation.md's images.

### 9. wasm32

* **The question.** `web-native.md` wants WebAssembly. wasm32 has
  32-bit pointers and 64-bit integers that cost nothing, so it is not
  i386: the 8-byte word may simply be right there. Or the heap is the
  host's (WasmGC, whose `i31ref` is a 31-bit immediate) and this
  layout does not apply at all.
* **How.** The interpreter built for wasm32 with the WASI SDK, the
  programs of `tests/perf` under a WebAssembly runtime, against the
  native 64-bit interpreter: the first number that plan needs.
* **What it changes.** Whether wasm32 is counted with the 32-bit VMs
  in this question or apart from them.

## What would decide it

* **Stop** if experiment 1 shows M5's word level in time and
  experiment 2 puts the rest of the gap on i386 itself, and nobody
  needs a 32-bit VM in less memory than M5 gives.
* **Go for memory** if the 32-bit targets are where memory is short
  (the collector's brief says so) and experiment 3 shows the heap
  halving again: then 4, 5 and 8 size the work, 6 decides whether
  typed slots come with it, and 7 fixes the header.
* **The order of building,** if it goes ahead: the harness under
  `-m32` first (6 and 7), then a prototype VM behind `value.h` as M4's
  were, then a gate of its own.

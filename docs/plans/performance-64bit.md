# 64-bit values under the tagged word: where the time goes

Claude, 2026-10-04, during heap-layout M5. The new layout makes
everything that fits 63 bits smaller and faster (the bootstrap runs in
0.83 of the 16-byte layout's cycles, MLton's 33 programs in 0.81 in
the mean). What it costs is code whose values need all 64 bits: a
`Word64.word` or an `Int64.int` past 63 bits, and a real. This file is
what was measured of that cost, where it is, and what is left to try.
The owner's decision on 2026-10-04 was to keep M5 as planned and write
these notes; nothing here is in M5.

## What a 64-bit value is now

A value word is 64 bits and its low bit says "immediate, not a
pointer", so 63 are free (`heap-layout.md`, D1 to D3).

* **`Int64.int`, `Word64.word`** (M5's first step): an immediate where
  the number fits 63 bits, a 16-byte box where it does not. Tier 2 of
  the JIT keeps the 64 bits themselves in a register (a raw home) and
  gives the number its word, or its box, when it goes to a slot of the
  frame or a field of an object. A box is made by a helper in C.
* **A real** (M5's second step): an immediate by the rotation where
  its exponent allows, seven instructions to decode and six to encode;
  a box otherwise, one that the VM keeps for each of zero, the
  infinities and NaN. Tier 2 keeps a real in an XMM register.
* **`int` and `word`** are 63 bits and never a box.

## The programs that lose

Against the 16-byte layout, at the default tiering. Instructions are
the machine's (`perf stat`, `instructions:u`), which do not move with
the machine's load; a box is counted by `runevm --stats`.

**64-bit words** (2026-10-04, the VM of M5's first step):

| Program | 16-byte | M5 | ratio | boxes |
|---|---:|---:|---:|---:|
| SplitMix64 as `lib/random` has it: 3 million words, then a tree of 2^18 splits | 1.01G | 2.20G | 2.2 | 11.7M |
| the 3 million words alone (`stream`) | 0.39G | 0.96G | 2.4 | 6.0M: 2.0 a word |
| the tree alone (`tree`) | 0.62G | 1.24G | 2.0 | 5.7M: 21.7 a split, its leaf's draw counted in |
| the same generator written out in the loop, no record and no call (`inline`) | 0.32G | 0.90G | 2.8 | 6.0M: 2.0 a word |
| a linear congruential generator, one multiply and one add a step (`lcg`) | 0.13G | 0.28G | 2.2 | 1.5M: 0.5 a step |
| the same with two more words carried round the loop (`lcg2`) | 0.22G | 0.54G | 2.4 | 3.0M: 1.0 a step |
| FNV-1a over 8 MB of characters (`fnv`) | 1.38G | 1.92G | 1.4 | 4.2M: 0.5 a character |

In cycles the whole SplitMix64 program is 0.95G against 0.46G (2.1
times), on a quiet machine. Under the interpreter (`--jit=off`) the
ratios are smaller, 1.3 to 1.7, because the 16-byte interpreter is
slow there too. Every program prints what it prints on the 16-byte
VM. M4's prototype, which kept 64 bits for every int and word and had
no raw homes, ran the first row in 9.36G.

**Reals** (M4's build with 63-bit integers and the rotation, an idle
machine, cycles; `heap-layout.md`, *M4, what was measured for the
gate*):

| Program | cycles against 16-byte | instructions |
|---|---:|---:|
| raytrace | 1.15 to 1.16 | 1.33 |
| nucleic | 1.09 to 1.12 | 1.36 |
| tsp | 1.08 | 1.24 |
| mandelbrot | 1.07 to 1.08 | 1.33 |
| ray | 1.05 | 1.22 |
| barnes-hut, fft, simple | 0.88 to 0.99 | 1.20 to 1.48 |

Two runs of one binary differ by up to 17% on `nucleic` and `ray`,
which run a second or less. These are to be measured again on the
finished M5 layout.

## Where the cost is

What is measured, and what is inferred from it.

1. **A box costs about a hundred instructions.** `lcg` runs 152
   million instructions more than on the 16-byte VM and makes 1.5
   million boxes; `stream` 566 million more for 6.0 million. That is
   the test for the 64th bit where a number goes to a slot, and for
   the half that have it the helper: every live register saved, a
   call into C, an allocation, every register loaded again, and the
   box read back where the number is next used.
2. **Numbers are boxed inside a loop that keeps nothing.** `inline`
   and `lcg` have no record, no call and no data structure, and still
   make 2.0 and 0.5 boxes a turn. Tier 2 has three general homes (rbx,
   rsi and rdi on x86-64; x24 to x26 on aarch64) for the ints, words,
   characters, tags and 64-bit numbers of a function together. The
   counts fit this reading: a value of the loop that has no home, a
   temporary between two operations among them, is written to its
   slot as a word, which for half of all 64-bit words is a box, and is
   read back by the next instruction. One such value a turn in `lcg`,
   two in `lcg2`, four in `inline`. *This is an inference from the
   counts and is the first thing to confirm* (experiment 1).
3. **A field is a word.** A generator is a record of two
   `Word64.word`, `Random.split` returns two of them, and the tree
   makes 21.7 boxes a split (the draw at each leaf counted in).
4. **A call passes words.** An argument and a result go through slots.
   `mandelbrot` allocates 353 objects in its whole run and is 1.08
   times slower: its reals are encoded and decoded at a call a pixel
   and around a primitive that is called through C.
5. **Reals have homes enough** (fourteen XMM registers), so what is
   left for them is the seven instructions at calls and at fields, and
   zero as a pointer to its box (`real-encoding.md`).
6. **The interpreter** does a 64-bit operation in its fast path only
   where the result fits 63 bits; the rest go to the primitive's C,
   which boxes.

## What would recover it

Smallest first. None changes what a program computes.

* **A. Temporaries kept out of slots.** More general homes in tier 2,
  or a result that the next instruction consumes left in a scratch
  register. If the inference above holds, this takes most of the
  boxes out of `inline`, `lcg`, `fnv` and the stream, and needs no
  change to the layout: it is the JIT's.
* **B. A box allocated in line.** The JIT bumps the heap for a tuple
  in line and calls C for a box. In line a box is ten to fifteen
  instructions where it is about a hundred. It removes no box. The
  owner declined it for M5.
* **C. Raw typed fields** (D1 B's second half, deferred at the gate
  of M4). A field that holds the 64 bits, or the double, the header's
  descriptor saying so. It removes the boxes of a generator's record
  and the encoding of a real in a tuple. Its cost is a descriptor in
  the header, a test in a polymorphic reader, and the compiler
  emitting field kinds (`heap-layout.md`, D1 and D4 A).
* **D. 64-bit values across calls in registers,** or slots whose kind
  the VM knows (D5 B, not built). It removes the boxes and the
  encodings at calls, which is all of `mandelbrot`'s loss.
* **E. Flat arrays** of `Word64.word` and of reals (M8, planned): an
  element is its 8 bytes.
* **F. Arithmetic and allocation in line.** Compiled code still calls
  C for primitives that are an instruction or two (`real_abs`,
  `int_to_real`, `ptr_eq`) and for ones that only allocate (a box, a
  one-character string, an array). A call into C is for what the
  operating system or the C library does, not for these (experiment
  10).

## The experiments

Each is small unless it says otherwise. The programs are at the end.

### 1. Count the boxes by cause

* **The question.** Which of temporaries, write-backs at a safepoint,
  arguments, results and fields makes the boxes of each program.
* **How.** A counter per cause under `--jit-profile` where `masm.c`
  gives a number its word (`num_to_slot`, `ms_set_num64`) and where
  the helper boxes (`jit_h_box_num`); the same for reals
  (`real_to_slot`, `jit_h_box_real`). The six programs above, the
  eight programs of reals, the property library's tests.
* **What it changes.** It orders A to D by what they would remove.

### 2. The registers, laid out again

* **The question.** Not "three homes or five" alone: which of the
  machine's registers should hold what. The assignment was made for
  tier 1 and grew a tier 2 beside it, and x86-64's registers are not
  alike, so the whole table is reconsidered, and how many homes there
  are falls out of it. The owner asked for this on 2026-10-04.
* **The assignment today** (`runtime/register/jit/asm.h`). On x86-64
  all sixteen are spoken for: six pinned (`rsp`; `r12` the VM, `r13`
  the value stack, `rbp` and `r14` the frame's base as an index and as
  a pointer, `r15` the instruction count), seven scratch (`rax`,
  `rcx`, `rdx`, `r8` to `r11`) and three homes (`rbx`, `rsi`, `rdi`).
  Of the scratch ones `rax`, `rcx`, `rdx` and `r8` do nearly all the
  emitters' work; `r9`, `r10` and `r11` are named in a few dozen
  places (a call's frame, the profile's counters, some slow paths).
  Reals have fourteen homes of their own, `xmm2` to `xmm15`.
* **What is not alike on x86-64**, each a constraint on the table:
  - *Instructions that name their registers.* A shift by a variable
    count takes it in `cl`; a division takes `rdx:rax` and leaves the
    quotient in `rax` and the remainder in `rdx`; the widening multiply
    and `cqo` use the same pair. So `rax`, `rcx` and `rdx` are scratch
    whatever else is decided, unless shifts go through BMI2's `shlx`,
    `shrx` and `sarx`, which not every x86-64 has.
  - *What a call into C keeps.* On Linux C preserves `rbx`, `rbp` and
    `r12` to `r15`, six registers; on Windows also `rsi` and `rdi`,
    eight, and `xmm6` to `xmm15` where Linux preserves no XMM
    register. A home in a preserved register needs no reload after a
    helper; today five of Linux's six hold pinned state and only one
    home, `rbx`, is preserved.
  - *Where C's arguments go.* `rdi`, `rsi`, `rdx`, `rcx` on Linux,
    `rcx`, `rdx`, `r8`, `r9` on Windows. Two of the three homes are
    Linux's first two argument registers, so every call into C there
    both loses them and has to move them out of the way first.
  - *What an address costs to encode.* A base of `rsp` or `r12` takes
    a SIB byte in every memory operand, and a base of `rbp` or `r13`
    cannot be written without a displacement. The VM is in `r12`, so
    every field of the VM that the code touches -- the allocation
    pointer and its limit, the counters, the VM's boxes -- is a byte
    longer than it would be from `rbx`, `rsi`, `rdi`, `r14` or `r15`.
  - *The prefix.* `r8` to `r15` need a REX prefix. A 64-bit operation
    has one anyway, so it costs a byte only on 32-bit and byte
    operations (a header's fields, a tag test), and `sil`, `dil` and
    `bpl` need one as bytes too.
  - *Registers with a use of their own.* `r11` is lost to a `syscall`
    and is what a linker's stub may use; `r10` is C's static chain.
    Neither matters while they are scratch.
* **What the pinned state is worth.** Whether each of the six needs a
  register at all is part of the question: the frame's base is kept
  twice (`rbp` as an index into the value stack, `r14` as the pointer
  that index gives), and `r15` is incremented at every bytecode
  instruction for `--count` and the tiering's budgets, which a block
  could add once at its end if every exit corrected it.
* **What a home costs.** One that is live is written back to its slot
  before a call that may collect or raise and loaded again after it;
  in a preserved register the load goes away for helpers that touch no
  frame, the write-back does not. So more homes help a loop that calls
  nothing and can hurt code that calls at every step, which is what
  the compiler is.
* **How.** (1) Audit: for every `R_S4`, `R_S5`, `R_S6`, `R_T` and
  `R_GO` in `masm.c`, `emit.c` and `compile.c`, what it holds and
  across what; for every pinned register, the instructions that read
  it, counted in tier 2's code for the bootstrap. (2) Make the table
  one place: the enum of `asm.h` already is, and the emitters name
  roles (`R_VM`, `R_S0`, `R_H0`) and no machine register, so a
  candidate layout is an edit there plus whatever the audit found
  hard-wired (the division and the shift in
  `asm_x64.c`, `as_arg`, the entry and leave stubs, and `runeopt`'s
  `src/opt/x64.sml`, which writes `(%r13,%rbp)` itself). (3)
  Candidates, each measured: the VM out of `r12`; homes in preserved
  registers first; five homes and eight; the frame's base once; the
  count out of a register; and one layout for Linux and Windows or one
  each, since what C preserves differs. (4) Measured by the bytes of
  code tier 2 makes (`--jit-stats`), and by instructions and cycles in
  runs that alternate, on the six programs above, the eight programs
  of reals, the bootstrap and `compile-sigs`; `make test-windows` and
  `make test-native` hold the Windows convention and `runeopt` to the
  result. aarch64's registers are alike and its table is a separate,
  smaller question: the convention leaves `x28`, `x15` and `x16`
  untouched and uses `x1` to `x8` for C's arguments alone.
* **What it changes.** Whether A is this or experiment 3, and the
  JIT's convention for both tiers and for `runeopt`.
* **Size.** The audit a day; each candidate a day or two once the
  table is one place; the frame's base and the count are changes to
  the calling sequence, a week.

### 3. A temporary that is never a word

* **The question.** Where an instruction's result is used once, by the
  next instruction, it need not reach its slot at all.
* **How.** In tier 2's emitter, a result register that liveness says
  dies at the next instruction stays in a scratch register. Measured
  as experiment 2 is.
* **What it changes.** A, without taking registers from code that
  calls.

### 4. What a box costs in line

* **The question.** How much of the hundred instructions an in-line
  allocation takes away, and what is left (the test, the box's load).
* **How.** `ms_alloc` already bumps the heap for objects; a box is an
  object of one raw word. Measure `tree` and `stream`, where boxes
  are owed whatever A does.
* **What it changes.** B, if the owner takes it up.

### 5. Raw fields, counted before they are built

* **The question.** How many of a program's boxes and encodings are
  fields of tuples and records, and how many of those are read by
  polymorphic code.
* **How.** Experiment 1's counter for fields, and the census's field
  table (`scripts/census.sh --summary`) extended to count loads by the
  reader's representation, on `tree`, `nucleic`, `raytrace` and
  `barnes-hut`. The same count is experiment 3 of `real-encoding.md`.
* **What it changes.** The decision the gate of M4 left for after M5.
* **Size.** The count a day; the fields themselves a milestone.

### 6. Across calls

* **The question.** What a convention that passes 64-bit numbers and
  reals in registers between two compiled functions would save.
* **How.** Experiment 1's counter for arguments and results first.
  `mandelbrot` and `tsp` for reals, `tree` for words. It is experiment
  5 of `real-encoding.md`.
* **Size.** The count small; the convention is the JIT's roadmap.

### 7. The interpreter's fast path

* **The question.** The fast path leaves a result past 63 bits to the
  primitive. It has the VM at hand since M5's second step, so it could
  box.
* **How.** `FAST_INT64` and `FAST_WORD64` in
  `runtime/register/fastprim.h` allocate where they give up today,
  with the registers as roots. `--jit=off` on the six programs.
* **What it changes.** The first seconds of a program, before tier 2,
  and the 32-bit VMs, which have no JIT.

### 8. What other systems do with the same programs

* **The question.** SML/NJ and Poly/ML keep 63-bit ints and box
  `Word64`; MLton has it unboxed by type. What do they take for these
  six programs, and so what is the target?
* **How.** The programs are plain SML but for `lib/random`, which the
  hosts compile (`tests/lib/run-hosts.sh`).
* **What it changes.** Whether 2.2 times the 16-byte layout is a loss
  to recover or the price every tagged runtime pays.

### 9. Keep them measured

* **The question.** None of these programs is in `tests/perf` or in
  `examples/benchmarks`, so no budget moves when 64-bit code gets
  slower or faster.
* **How.** `stream`, `tree`, `fnv` and one of the programs of reals as
  workloads of `scripts/perf-cycles.sh`, with count budgets, when M5
  re-bases the budgets.

### 10. Arithmetic and allocation that still call C

* **The question.** The owner's, on 2026-10-04: calling C makes sense
  for a system call, not for arithmetic or for an allocation. Which
  primitives does compiled code still reach through C, how often, and
  what does each call cost beside the work itself?
* **What a call costs.** Before a helper that may collect or raise the
  code writes every live home back to its slot and stores the pc and
  the stack pointer (`ms_sync`), calls through `rax`, and loads the
  homes again; a helper that touches nothing of the VM
  (`ms_call_lean`) skips the stores and still loses the homes that C
  does not preserve. Experiment 1 of this file found a box, which is
  such a call and sixteen bytes of heap, at about a hundred
  instructions.
* **First figures** (`runevm --jit-stats`, the VM of M5, the calls
  from compiled code alone):

  | Program | calls | the primitives |
  |---|---:|---|
  | bootstrap | 959,597 | `string_from_char` 268,106, `string_concat` 209,986, `string_extract` 131,558, `string_implode` 81,721, `int_to_string` 80,267, `array_new` 70,863, `string_concat_list` 56,053, `string_explode` 25,759 |
  | string_ops | 781,270 | `string_from_char` 311,021, `string_extract` 310,447, `int_to_string` 79,901, `string_concat` 79,901 |
  | raytrace | 1,134,032 | `real_trunc` 359,703, `real_abs` 342,056, `int_to_real` 240,026, `real_floor` 81,443, `real_pow` 56,052, `real_atan2` 49,608 |
  | nucleic | 1,445,733 | `real_atan` 482,109, `real_sin` 481,812, `real_cos` 481,812 |
  | mandelbrot (2048 by 2048) | 4,196,154 | `int_to_real`, once a pixel |
  | hamlet | 133,823 | `ptr_eq` 133,302 |
  | stream, tree, fnv, list_ops | none | their boxes are a helper's, which this does not count |

* **What the figures say already.** Three kinds are in there. *An
  instruction or two:* `real_abs`, `int_to_real`, `ptr_eq`, and
  `real_trunc`, `real_floor`, `real_ceil` and `real_round` where the
  result fits an int (a conversion and a range test, the primitive
  for the rest); `int_abs`, `word_neg`, `word64_asr` and the reals'
  bits are of this kind too and are not in line either. *Allocation
  with a little work:* a box, `string_from_char` (the 256 of them
  could be made once), `array_new`, `string_concat`, `string_extract`,
  `string_implode`. *The C library's and the system's:* `real_sin`,
  `real_atan`, `real_pow`, `file_write`, which is where a call
  belongs.
* **How.** (1) The ranking for every workload: the bootstrap,
  `tests/perf`, MLton's set, the six programs of this file, with the
  helpers that box counted beside the primitives. (2) What one call
  costs: a loop around each candidate, instructions with it in line
  against through C. (3) The first two kinds in line, the most called
  first, each measured in runs that alternate on the program that
  calls it most and on the bootstrap; an allocation in line bumps the
  heap as `ms_alloc` does for a tuple and goes to C only when the heap
  is full. The interpreter's fast path (`prim_fast`) has the same
  list to go through. `runeopt` gets what the macro-assembler gets,
  its templates being made from it.
* **What it changes.** `raytrace` and `mandelbrot` among the programs
  of reals (their calls are a conversion a pixel or a ray), the
  compiler's strings, and experiment 4's box, which is one of these.
* **Size.** The ranking an hour; each primitive of the first kind a
  few lines of `emit.c`; the allocating ones a day each.

## What would decide it

* If experiment 1 puts most boxes on temporaries, A comes first: it
  is the JIT's work, it needs no layout change, and it may bring
  `stream` and `fnv` close to the 16-byte VM by itself.
* Raw fields (C) are decided on what is left after A: `tree`,
  `nucleic` and `raytrace` are the programs to read.
* D is the JIT roadmap's, and worth its cost only if `mandelbrot` and
  `tsp` matter.

## The programs

```sml
(* stream: compile with --library random *)
fun stream (0, _, acc) = acc
  | stream (i, g, acc) = let val (x, g) = Random.word64 g in stream (i - 1, g, Word64.xorb (acc, x)) end
val () = print (Word64.toString (stream (3000000, Random.fromSeed 0w42, 0w0)) ^ "\n")

(* tree: compile with --library random *)
fun tree (0, g) = #1 (Random.int (0, 1000) g)
  | tree (d, g) = let val (l, r) = Random.split g in tree (d - 1, l) + tree (d - 1, r) end
val () = print (Int.toString (tree (18, Random.fromSeed 0w7)) ^ "\n")

(* inline *)
fun stream (0, _, acc : Word64.word) = acc
  | stream (i, s : Word64.word, acc) =
      let
        val s = Word64.+ (s, 0wx9E3779B97F4A7C15)
        val z = Word64.* (Word64.xorb (s, Word64.>> (s, 0w30)), 0wxBF58476D1CE4E5B9)
        val z = Word64.* (Word64.xorb (z, Word64.>> (z, 0w27)), 0wx94D049BB133111EB)
        val z = Word64.xorb (z, Word64.>> (z, 0w31))
      in stream (i - 1, s, Word64.xorb (acc, z)) end
val () = print (Word64.toString (stream (3000000, 0w42, 0w0)) ^ "\n")

(* lcg *)
fun loop (0, s : Word64.word) = s
  | loop (i, s) = loop (i - 1, Word64.+ (Word64.* (s, 0wx5851F42D4C957F2D), 0wx14057B7EF767814F))
val () = print (Word64.toString (loop (3000000, 0w42)) ^ "\n")

(* lcg2 *)
fun loop (0, s : Word64.word, a : Word64.word, b : Word64.word) = Word64.xorb (s, Word64.xorb (a, b))
  | loop (i, s, a, b) =
      let val s = Word64.+ (Word64.* (s, 0wx5851F42D4C957F2D), 0wx14057B7EF767814F)
      in loop (i - 1, s, Word64.xorb (a, s), Word64.+ (b, Word64.>> (s, 0w7))) end
val () = print (Word64.toString (loop (3000000, 0w42, 0w0, 0w0)) ^ "\n")

(* fnv *)
val text = CharVector.tabulate (1048576, fn i => chr ((i * 7 + i div 13) mod 251))
fun fnv (s : string) : Word64.word =
  let
    val n = size s
    fun go (i, h : Word64.word) =
      if i = n then h
      else go (i + 1, Word64.* (Word64.xorb (h, Word64.fromInt (ord (String.sub (s, i)))), 0wx100000001B3))
  in go (0, 0wxCBF29CE484222325) end
fun rep (0, acc) = acc | rep (k, acc) = rep (k - 1, Word64.xorb (acc, fnv text))
val () = print (Word64.toString (rep (8, 0w1)) ^ "\n")
```

Each is run as `bin/runevm --count --stats FILE.rbc` under `perf stat
-e instructions:u,cycles:u`, on the 16-byte VM (branch `heap-layout`
before M5, where `Word64` is `Word`) and on M5's.

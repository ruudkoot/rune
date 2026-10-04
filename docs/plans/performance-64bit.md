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
  `string_implode`. *The C library's functions of reals:* `real_sin`,
  `real_cos`, `real_atan`, `real_atan2`, `real_pow`, which are no
  system calls either (the next two items). *The system's:*
  `file_write` and its like, which is where a primitive's call
  belongs.
* **Whether the machine has an instruction for a function of the
  library.** Three different answers. SSE2 has none, and neither has
  anything later on x86-64: of this kind there is `sqrtsd`, and
  SSE4.1's `roundsd` for `floor`, `ceil`, `trunc` and `round`
  (`Math.sqrt` is in line already). The x87 unit has them: `fsin`,
  `fcos`, `fpatan`, and `fyl2x` with `f2xm1` and `fscale` for a power.
  aarch64 has none at all.
* **The x87 instructions, measured** (the owner asked for the
  experiment, 2026-10-04). Three million calls with the argument in
  [0, 3), the x87 instruction in line with its argument and result
  moved between an XMM register and the x87 stack through memory, as
  compiled code of Rune would have to; Xeon E5-1680 v3 (Haswell),
  glibc 2.39; cycles and instructions a call, the loop taken off:

  | Function | library, cycles | x87, cycles | library, instructions | x87, instructions |
  |---|---:|---:|---:|---:|
  | `sin` | 33 | 113 | 86 | 4 |
  | `cos` | 34 | 112 | 88 | 4 |
  | `atan` | 35 | 156 | 73 | 5 |
  | `atan2` | 65 | 163 | 156 | 9 |
  | `pow` | 73 | 182 | 137 | 15 |

  The instructions are microcoded: a twentieth of the library's
  instructions and 2.5 to 4.5 times its cycles (a count of
  instructions, which the rest of this file leans on, says the
  opposite here). Their results against the library's over a million
  random arguments: in [0, 3) one in a thousand differs, by a unit in
  the last place (`cos`: eight of them by up to three); `atan`,
  `atan2` and `pow` stayed within one unit wherever tried. `fsin` and
  `fcos` reduce their argument by a 66-bit pi: between 3.14159 and
  3.1416 every sine differs, by up to five million units; over
  [0, 10^6) 72% differ by more than one; past 2^63 the instruction
  hands its argument back. So x87 in line is ruled out by
  measurement, not by assumption: it is slower than the call it would
  replace (113 cycles against the 91 below), and its results differ
  from aarch64's and from the other engines'.
* **What the call costs around the library's work.** `Math.sin` three
  million times in a loop, from compiled code, the arguments from 0.5
  to 3000.5:

  | | cycles a call | instructions a call |
  |---|---:|---:|
  | the library's `sin`, called from C | 49 | 103 |
  | `Math.sin`, the 16-byte VM | 74 | 163 |
  | `Math.sin`, M5's VM | 91 | 225 |

  The 41 cycles and 120 instructions over the library's on M5 are the
  primitive's convention -- the argument encoded and pushed, decoded
  in the primitive, the result encoded there and decoded again, the
  homes written back and loaded -- and a call straight to the library
  with the argument in an XMM register has none of them, since such a
  function neither allocates nor raises. That is what is proposed for
  this kind: the library's code, reached directly.
* **The library's algorithm in line, measured** (the owner's second
  question). glibc 2.39's own source of the sine
  (`sysdeps/ieee754/dbl-64/s_sin.c` with its table and its reduction
  of large arguments), compiled as the library compiles the variant
  this machine runs (`-O2 -mfma -mavx2 -frounding-math`), and agreeing
  with the library's result on every one of two million random
  arguments in each of five ranges. The same loop from C, a call:

  | The sine | cycles, arguments 0.5 to 3000.5 | instructions | cycles, arguments in [0, 3) | instructions |
  |---|---:|---:|---:|---:|
  | the library's, as a C program calls it (through the PLT) | 49.1 | 102.5 | 32.3 | 85.7 |
  | the same source in the program, called directly | 47.6 | 98.5 | 31.3 | 81.7 |
  | the same source in line in the loop | 41.1 | 84.7 | 26.5 | 67.8 |
  | in line, without the test of the rounding mode | 37.7 | 71.7 | 24.5 | 56.4 |

  In line saves 6.5 cycles of 47.6 over the direct call, 14%; against
  the 91 that `Math.sin` costs on M5 today, a direct call would be
  about 48 and in line about 41 (estimates from the C loop: neither
  is built, and a direct call still saves the real homes that are
  live across it, every XMM register being the callee's to use under
  the System V convention). The 41 is a lower bound for code the
  JIT would emit: the C compiler also keeps the sine's constants in
  registers across the loop, which a copy emitted at a call site does
  not get. The library asks for the rounding mode at every call
  (`stmxcsr` and a test); leaving that out is three or four cycles
  more and is right only if the VM knows the mode, which
  `IEEEReal.setRoundingMode` can change. What in line costs: some 85
  instructions of FMA code at every call site (and the variant
  without FMA for a machine that lacks it, which the library chooses
  by itself), the table and the large arguments' reduction still a
  call, the same again for aarch64, and one obligation that is the
  real price: the interpreter, the stack VM and `runeopt`'s code call
  the system's library, so a JIT with its own copy of one version's
  algorithm gives another answer wherever the system's library is not
  that version (musl, Windows, another glibc). In line means Rune
  carries its own sine for every engine, as V8 and the JVM do for
  that reason.
* **Decided** (the owner, 2026-10-04): `sin` and its like stay calls
  to the C library; maths functions of Rune's own, in line or not,
  are deferred until later. What is left of this kind for the
  experiment is how the library is reached: the direct call, which is
  43 of the 50 cycles that were to be had and no new code to keep.
* **How.** (1) The ranking for every workload: the bootstrap,
  `tests/perf`, MLton's set, the six programs of this file, with the
  helpers that box counted beside the primitives. (2) What one call
  costs: a loop around each candidate, instructions with it in line
  against through C. (3) The first two kinds in line, the most called
  first, and the third as a direct call to the library, each measured
  in runs that alternate on the program that calls it most and on the
  bootstrap; an allocation in line bumps the
  heap as `ms_alloc` does for a tuple and goes to C only when the heap
  is full. The interpreter's fast path (`prim_fast`) has the same
  list to go through. `runeopt` gets what the macro-assembler gets,
  its templates being made from it.
* **What it changes.** `raytrace` and `mandelbrot` among the programs
  of reals (their calls are a conversion a pixel or a ray), `nucleic`
  (1.4 million calls of the library at some 40 cycles of convention
  each, 60M of its 1.3G cycles), the compiler's strings, and experiment 4's box, which is one of these.
* **Size.** The ranking an hour; each primitive of the first kind a
  few lines of `emit.c`; the allocating ones a day each.

## Experiments 1 and 5, run

On 2026-10-04, after the heap layout's M7, for the decision on raw real
fields. The instrument is a VM built with `-DRUNE_JIT_CONV`
(`bin/runevm-conv`, x86-64): compiled code counts, as it runs, every
conversion between a raw number in a home and its word -- a real
decoded or encoded, a 64-bit number decoded, encoded or boxed -- by the
instruction that makes it and by whether it is that instruction's own
work, a write-back at a safepoint or a reload of the homes; and every
read of a field by what the reader's register holds. `runevm-conv
--jit-stats` prints the table. All of each program's compiled code was
at tier 2.

**The reals.** MLton's eight programs of reals at their benchmark
sizes; a decode is seven instructions and a branch, an encode six:

| Program | conversions | per 100 bytecode instructions | fields | arrays and refs | primitives through C | calls of SML functions | arithmetic on a register in its slot, and the rest |
|---|---:|---:|---:|---:|---:|---:|---:|
| nucleic | 122.6M | 49 | 49.4M (40%) | 0 | 26.6M (22%) | 11.3M (9%) | 35.2M (29%) |
| raytrace | 499.4M | 37 | 299.2M (60%) | 118.7M (24%) | 14.6M (3%) | 60.1M (12%) | 6.8M (1%) |
| mandelbrot | 13,959M | 44 | 0 | 0 | 4,295M (31%) | 7,516M (54%) | 2,148M (15%) |
| tsp | 1,883M | 35 | 680.0M (36%) | 0 | 383.9M (20%) | 806.2M (43%) | 12.6M (1%) |
| ray | 53.2M | 39 | 37.2M (70%) | 0 | 4.7M (9%) | 10.7M (20%) | 0.5M (1%) |
| barnes-hut | 69.4M | 70 | 27.0M (39%) | 1.3M (2%) | 3.6M (5%) | 37.4M (54%) | 0.1M |
| fft | 1,281M | 51 | 33.6M (3%) | 777.3M (61%) | 327.1M (26%) | 109.0M (9%) | 33.6M (3%) |
| simple | 33.9M | 19 | 1.9M (6%) | 0.5M (2%) | 8.7M (26%) | 22.4M (66%) | 0.3M (1%) |

* *Fields:* a real read from a tuple or a constructor into a home
  (decoded) and written into one from a home (encoded). This is what
  raw real fields would make a move.
* *Arrays and refs:* `Array.sub`, `Array.update` and their like on
  elements that are reals. These are arrays of the polymorphic `Array`
  at the type `real` (`fft`'s `array (n, 0.0)`), which hold words. The
  heap layout's M8 makes `RealArray` and `Real64Array` flat, and no
  program of the eight uses either: M8 as planned does not reach
  these. A `real array` made flat is a representation chosen by type,
  with the test of the object's kind at a reader that does not know
  the element, the question raw fields ask for a tuple; the test is
  cheaper here, since a read of an array tests its kind already.
* *Primitives through C:* the homes written back before the call and
  loaded again after it, and the result. `nucleic`'s 1.4 million calls
  of `sin`, `cos` and `atan` are 18 conversions each (experiment 10
  measured 120 instructions a call in a loop with two reals live;
  here there are more); `mandelbrot`'s are one
  `Real.fromInt` a pixel, three homes loaded again for it.
* *Calls of SML functions:* the homes written back before a call,
  loaded again after it and at a function's entry, and a real
  returned. An argument and a result cross as words.
* *Arithmetic on a register in its slot:* `real_mul`, `real_add` and
  the comparisons on an operand that has no home or has just come as a
  word. `nucleic` has functions of more reals than the fourteen XMM
  homes.

No loop that is a jump makes any: `mandelbrot`'s inner loop, a
function calling itself in tail position, converts nothing, and all of
its 14 billion are the 13 a pixel around it. So what the programs of
reals lose is at the boundaries a real crosses as a word: a field, an
element, a call, a primitive in C.

**What raw real fields would have to pay for.** The fields' reads and
fills, by what the register holds:

| Program | reads of a real into a home | into a slot | field reads at `any` | at another representation | fills of a real from a home | from a slot |
|---|---:|---:|---:|---:|---:|---:|
| nucleic | 35.8M | 8.4M | 45.8M | 18.1M | 13.6M | 0.9M |
| raytrace | 235.4M | 0 | 0.9M | 72.3M | 63.8M | 0 |
| tsp | 675.6M | 0 | 0 | 520.8M | 4.3M | 0 |
| ray | 27.3M | 0 | 0.5M | 17.8M | 10.0M | 0 |
| barnes-hut | 18.4M | 0 | 0.1M | 9.8M | 8.6M | 0 |
| fft | 16.8M | 0 | 130 | 16.8M | 16.8M | 0 |
| simple | 1.8M | 0 | 1.9M | 48.9M | 0.1M | 0 |

A raw field saves about six instructions at a read into a home and
five at a fill from one. It costs a test of the object's descriptor at
every read whose reader does not know the field (the reads at `any`:
more of them in `nucleic` than its reads of reals), an encode where a
raw field is read into a slot, and, unless the compiler proves that
every tuple of a type is built with the same layout, the same test at
the reads that do know, since a tuple of reals built by polymorphic
code holds words.

**An estimate from the counts, not a measurement.** The instructions a
program runs more than on the 16-byte layout are its conversions: 6.4
to 7.9 for each, on seven of the eight (10.7 on `simple`). At six
saved a read, five a fill, two for a test and six for an encode, the
lower figure with the test at every read of a real and the higher
without:

| Program | instructions, 16-byte | M5 | more | raw fields would save | of M5's | of the more | cycles, M5 against 16-byte |
|---|---:|---:|---:|---:|---:|---:|---:|
| raytrace | 10.80G | 14.30G | 3.49G | 1.26G to 1.73G | 9% to 12% | 36% to 50% | 1.14 |
| ray | 1.62G | 1.97G | 0.35G | 0.16G to 0.21G | 8% to 11% | 46% to 62% | 1.05 |
| barnes-hut | 0.97G | 1.43G | 0.46G | 0.12G to 0.15G | 8% to 11% | 25% to 33% | 0.95 |
| tsp | 62.9G | 77.9G | 15.0G | 2.7G to 4.1G | 3% to 5% | 18% to 27% | 1.06 |
| nucleic | 2.18G | 2.96G | 0.78G | 0.07G to 0.14G | 2% to 5% | 9% to 18% | 1.15 |
| fft | 23.3G | 33.1G | 9.8G | 0.15G to 0.19G | 0.5% | 2% | 0.93 |
| simple | 1.90G | 2.27G | 0.36G | under 0.01G | 0.3% | 2% | 0.84 |
| mandelbrot | 299G | 397G | 98G | none | | | 1.07 |

If the cycles a program loses go as its conversions do, raw fields
would bring `raytrace` from 1.14 to about 1.08, `ray` from 1.05 to
1.02 or 1.03, `tsp` from 1.06 to 1.04 or 1.05, and `nucleic` from 1.15
to between 1.12 and 1.14.

**The 64-bit words.** The six programs of this file:

| Program | boxes | made at a primitive's result | at a move | at a fill or a call | 64-bit values written into fields |
|---|---:|---:|---:|---:|---:|
| stream | 6.0M | 4.5M | 1.5M | 10 | 6.0M |
| tree | 5.7M | 5.4M | 3,610 | 0.4M | 2.1M |
| inline | 6.0M | 4.5M | 1.5M | 0 | 0 |
| lcg | 1.5M | 1.5M | 0 | 0 | 0 |
| lcg2 | 3.0M | 0 | 3.0M | 0 | 0 |
| fnv | 4.2M | 4.2M | 0 | 0 | 0 |

Every box is made where a result or a copy goes to a register that has
no home: tier 2 has three general homes, and `lcg`'s loop wants them
for its counter, its state, a product and two constants, which it
decodes again at every turn (six million decodes of constants in three
million turns). None is made at a fill. `stream` writes two 64-bit
values into a tuple at every step, which would need their words there
if they did not have them already; `inline`, `lcg`, `lcg2` and `fnv`
keep nothing and box all the same. So for these programs the order is
A (homes, experiments 2 and 3) before anything about fields.

**The flat arrays, measured on variants** (the owner's request of
2026-10-04, with the heap layout's M8). `fft-realarray` is `fft` with
`open RealArray Math` for `open Array Math`, and `raytrace-realarray`
is `raytrace` with its matrices (`float array`, sixteen reals) as
`RealArray.array`; each is a sed script over MLton's source
(`tests/external/mlton-bench/NAME.from` and `NAME.sed`), a line of
`tests/perf/mlton-bench.txt`, and draws or computes what the original
does. Runs that alternate on a quiet machine, the least of five,
against the 16-byte layout:

| Program | cycles | instructions | conversions |
|---|---:|---:|---:|
| fft, on M8 | 0.94 | 1.42 | 1,281M |
| fft-realarray | 0.83 | 1.20 | 503M |
| raytrace, on M8 | 1.14 | 1.33 | 499M |
| raytrace-realarray | 1.06 | 1.27 | 382M |

The conversions that went are the ones the table above has under
arrays, to the million: `fft`'s 777M, `raytrace`'s 117M decodes of
`array_sub`. So a flat array of reals is worth 12% of `fft`'s cycles
and seven points of `raytrace`'s, where a program asks for one; an
`Array` at the type `real` does not.

**What it says for the decision.**

* Raw real fields reach 36% to 70% of the conversions of five
  programs (`ray`, `raytrace`, `nucleic`, `barnes-hut`, `tsp`) and
  nothing of the other three.
* Arrays are 61% of `fft`'s and 24% of `raytrace`'s, and they are
  `real array`s of the polymorphic `Array`, which M8's flat
  `RealArray` does not change. Reaching them means an `'a array` that
  is flat where it is made at `real`, with every array primitive
  taking both kinds: a decision of its own, beside raw fields.
* Calls and primitives through C are all of `mandelbrot`'s, 92% of
  `simple`'s, 63% of `tsp`'s, 59% of `barnes-hut`'s and 31% of
  `nucleic`'s: the JIT's calling convention (D) and experiment 10.
* A raw field is not free at the reader: a test at every read that
  does not know the field's type, and at those that do unless tuples
  are built by type.

## What would decide it

* If experiment 1 puts most boxes on temporaries, A comes first: it
  is the JIT's work, it needs no layout change, and it may bring
  `stream` and `fnv` close to the 16-byte VM by itself.
* Raw fields (C) are decided on what is left after A: `tree`,
  `nucleic` and `raytrace` are the programs to read. The owner decides
  them after experiments 1, 5 and 10 (2026-10-04, at the end of the
  heap layout's M5, whose tables are in `heap-layout.md`, *M5, done*);
  experiments 1 and 5 are run, above.
* **Decided by the owner on 2026-10-04, on experiments 1 and 5:** raw
  real fields are deferred to a future roadmap. The heap layout's M8
  is measured with variants of `fft` and `raytrace` that use
  `RealArray`. After M8 comes the JIT's work on what the tables above
  put first for the most programs: calls of SML functions (D) and the
  primitives that go through C (experiment 10; `sin` and its like
  stay calls of the C library).
* D is the JIT roadmap's, and worth its cost only if `mandelbrot` and
  `tsp` matter.

## The work after the heap layout, in order

The owner's, on 2026-10-04, once the heap layout's M8 is in: the
JIT's calls and the primitives that go through C, with more general
homes and the registers laid out again. Each step is measured with the
VM that counts conversions (`bin/runevm-conv`) and with runs that
alternate, and committed by itself.

1. **The primitives that are an instruction or two, in line**
   (experiment 10's first kind): `int_to_real`, `real_abs`, and
   `real_trunc`, `real_floor`, `real_ceil` and `real_round` where the
   result fits an int. A few lines of `emit.c` each, and nothing of
   the register table. `mandelbrot` (a `Real.fromInt` a pixel, 31% of
   its conversions), `raytrace`, `fft`, `tsp`.
2. **The registers, laid out again, and more general homes**
   (experiments 2 and 3). Before the two steps about calls, because
   both are shaped by which registers are homes: two of today's three
   general homes, `rsi` and `rdi`, are C's to clobber, so they are
   saved and loaded around every call into C; homes that a call
   preserves make step 3 cheaper before it is written, and step 4's
   convention is designed once. First the audit of every scratch
   register an emitter names, on both machines; then the table (five
   or six general homes where there are three, in registers a call
   preserves where the machine has them, each pinned register asked
   what it is worth, x86-64's fixed roles kept: `rcx` for a shift,
   `rax` and `rdx` for a product and a quotient, the arguments of a
   call into C, which Windows has in other registers); then homes
   given by live range, if the counts still show boxes after the
   table (`lcg`'s loop wants a counter, a state, a product and two
   constants). The six programs of 64-bit words, the bootstrap and
   the programs of reals. The riskiest of the four: every emitter,
   both targets, the Windows convention and `runeopt`'s templates.
3. **A cheaper call for the primitives that stay in C** (`sin`,
   `cos`, `atan`, `ln`, `pow`: calls of the C library, as decided):
   the live homes saved as they are instead of written to their slots
   as words and read back, and the library called directly with the
   argument in a register. `nucleic` (18 conversions a call), `fft`,
   `tsp`.
4. **Reals and 64-bit numbers across calls of SML functions** (D):
   the largest share for the most programs (`simple` 66%, `mandelbrot`
   and `barnes-hut` 54%, `tsp` 43%), and the one that needs a design:
   a frame that waits must have words in its slots for the collector
   and for the interpreter that may take it over. A design and a
   prototype that measures the upper bound on `mandelbrot` and
   `simple` first, and the numbers to the owner before it is built.

Not in this: the C library's functions as Rune's own code, raw real
fields, an `Array` at `real` made flat (deferred or not decided).

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

Experiment 10's library in line is glibc 2.39's `s_sin.c`,
`sincostab.c` and `branred.c` unchanged (the last without the FMA
flags, as the library builds it), with stand-ins of a few lines for
the private headers they include (`endian.h`, `math_private.h`,
`fenv_private.h` with the SSE functions of
`sysdeps/x86/fpu/fenv_private.h`, `math-underflow.h`,
`libm-alias-double.h`); the source is included once with `SECTION`
empty in a file of its own (the direct call) and once with `SECTION`
as `static inline __attribute__ ((always_inline))` in the file of the
loop.

Experiment 10's loop of `Math.sin`, and the x87 instructions it was
measured against (gcc, `-O2 -fno-math-errno`; each function summed
over three million arguments under `perf stat`, the loop alone taken
off, and its results compared with the library's bit by bit):

```sml
fun loop (0, x : real, acc : real) = acc
  | loop (i, x, acc) = loop (i - 1, x + 0.001, acc + Math.sin x)
val () = print (Real.toString (loop (3000000, 0.5, 0.0)) ^ "\n")
```

```c
static inline double x_sin(double x) { double r; __asm__("fsin" : "=t"(r) : "0"(x)); return r; }
static inline double x_cos(double x) { double r; __asm__("fcos" : "=t"(r) : "0"(x)); return r; }
static inline double x_atan(double x) { double r; __asm__("fld1\n\tfpatan" : "=t"(r) : "0"(x)); return r; }
static inline double x_atan2(double y, double x) {
  double r; __asm__("fpatan" : "=t"(r) : "0"(x), "u"(y) : "st(1)"); return r;
}
/* x > 0: 2^(y log2 x), the exponent split into its integer and the rest */
static inline double x_pow(double x, double y) {
  double r;
  __asm__("fyl2x\n\tfld %%st(0)\n\tfrndint\n\tfxch\n\tfsub %%st(1), %%st\n\t"
          "f2xm1\n\tfld1\n\tfaddp\n\tfscale\n\tfstp %%st(1)"
          : "=t"(r) : "0"(x), "u"(y) : "st(1)", "st(2)");
  return r;
}
```

# How a real sits in the word: experiments left to run

Claude, 2026-10-04, at the gate of heap-layout M4. The decision this
follows is D3 of `heap-layout.md` as the owner settled it at the gate:
a real in a value word is encoded by the *rotation*, with a box for
what does not fit. This file is what was measured to get there, what
that leaves unanswered, and the experiments that would answer it, each
with how to run it and what its result would change. None of them
blocks M5.

## Where it stands

A value word is 64 bits and its low bit says "immediate, not a
pointer", so 63 bits are free and a double has 64. Tier 2 of the JIT
keeps a real in an XMM register as the IEEE double; the encoding is
paid wherever a real leaves a register for a word: an argument or a
result of a call, a home written back around a primitive that may
collect, a field of an object, an array element, a constant.

```
IEEE double   [sign 1][exponent 11][mantissa 52]
Koka's        [mantissa 52][sign 1][exponent 10][1]       rotate left 12, squeeze the exponent by cases
rotation      [exponent 10][mantissa 52][sign 1][1]       add 2^61, rotate left 2
```

| | Koka's | rotation |
|---|---|---|
| exponents that are immediates | 0, 0x201 to 0x5fe, 0x7ff | 0x200 to 0x5ff |
| normal numbers that are immediates | 2^-510 up to 2^512 | 2^-511 up to 2^513 |
| `+0.0`, `-0.0` | immediates | boxes; `+0.0` one box the VM keeps |
| subnormals, infinities, NaN | immediates | boxed where made |
| to decode, in the JIT's code | 15 instructions, 4 branches | 7 instructions, 1 branch |
| to encode | 14 instructions | 6 instructions |

Both carry the sign and the 52 mantissa bits whole, so every double
comes back bit for bit, as an immediate or from its box.

What was measured (`heap-layout.md`, *M4, what was measured for the
gate*; branch `heap-layout-word`, `-DRUNE_REAL_ROT`,
`bin/runevm-realrot`):

* The eight programs of reals of MLton's set, cycles against the
  16-byte layout, geometric mean: Koka's 1.30, the rotation 1.10; with
  63-bit integers 1.29 and 1.03 (0.88 to 1.16). Instructions 1.70 and
  1.36.
* The interpreter, `real_nbody` with `--jit=off`, instructions against
  the 16-byte layout: Koka's 1.57, the rotation 1.13, every real boxed
  2.80. On the 32-bit interpreter 2.04 and 1.21.
* The census of the eight programs: a real crosses a call as often as
  it is stored in an object, or more often, on four of them;
  `mandelbrot` stores none. Zero is a fifth of what `ray` and
  `raytrace` compute, a third of `simple`'s, half of what `fft` stores
  in new objects. Reals outside the encodable range other than zero
  are a few thousand in hundreds of millions.
* What is left after the rotation: `raytrace` 1.16, `nucleic` 1.12,
  `mandelbrot` and `tsp` 1.08 (63-bit integers). Two runs of one
  binary differ by up to 17% on `nucleic` and `ray`, which run a
  second or less.

## What M5 builds anyway

Not experiments; listed so that the experiments below are read against
them. The rotation as the one encoding; a box the VM keeps for each of
`+0.0`, `-0.0`, the two infinities and NaN, made at start; the
interpreter's fast path handed the VM, so that a zero result does not
fall to the primitive; `runeopt`'s templates regenerated; the 32-bit
and big-endian builds through `make test-portability`. Koka's encoding
stays on the prototype's branch for comparison, and every real boxed
(`-DRUNE_REAL_BOXED`) stays a switch.

## The experiments

Each is small unless it says otherwise. The instruments exist: the
census (`scripts/census.sh --summary`, its `## reals` table), the eight
programs (`tests/external/run-mlton-bench.sh`), `scripts/perf-cycles.sh`,
and `perf stat` on an idle machine, the least of three runs.

### 1. Zero as a pointer

* **The question.** With the rotation a zero in a field is a pointer
  to the VM's one box: the collector follows it where it skipped an
  immediate, a reader takes the box's branch and a load, and where
  zeros and other reals mix the branch is data-dependent. `ray`'s
  instructions fall by 17% under the rotation and its cycles by 8%;
  `simple`, a third of whose results are zero, did not gain with
  64-bit integers. Is zero's box what holds them back?
* **How.** `perf stat -e branch-misses,L1-dcache-load-misses` on
  `ray`, `raytrace`, `simple` and `fft` under both encodings; the
  collector's time from `--stats` on `fft` (16.8 million zeros stored
  in new objects). Then the alternative built behind a switch: zero as
  an immediate, by giving one encodable double's word to zero (that
  double is boxed instead) and a compare with a conditional move in
  the decode, two instructions more on every decode and no branch.
* **What it changes.** Which of the two M5 keeps for zero. If neither
  is clearly better, the box, since it is built.

### 2. Which exponents get the immediates

* **The question.** One tag bit gives half the doubles an immediate,
  and the offset chooses which half: 2^61 puts it at exponents 0x200
  to 0x5ff, centred on 1.0. The census counts only "fits Koka's range
  or not".
* **How.** A histogram of the biased exponent (2,048 buckets, the
  sign apart) in the census's `## reals` table, by where the real
  arises; run on the eight programs, `real_nbody`, the Basis suite's
  real tests and `examples/benchmarks`' numeric programs.
* **What it changes.** The offset, if some workload lives outside the
  half (physical constants near 1e-300 or 1e300, counters as reals).
  Expected: nothing; the experiment is a day and closes the question.

### 3. Raw real fields (D1 B's second half; the decision left for after M5)

* **The question.** A field that holds the double's own bits, the
  header's descriptor saying so, read and written with no encoding
  where the reader's register is a real's. It would take the seven
  instructions off every crossing at a field. Does that pay for a
  descriptor in the header, a test in polymorphic readers, and the
  compiler emitting field kinds at allocating sites?
* **How.** First the count, which is cheap: the census extended to
  count real loads from fields by the reader's representation (it
  counts stores today), so that the share of crossings that are
  fields, and the share of those read through `'a`, are known for
  `nucleic`, `raytrace`, `barnes-hut`. Only if fields are the larger
  part of what is left: the prototype, on the finished M5 layout, for
  tuples and records of the `TUPLE` and `CONN` instructions whose
  operands are reals (`heap-layout.md`, D1 and D4 A, has the design
  and what makes it unsound for a tuple read by polymorphic code).
* **What it changes.** M8, where the fields would be built beside the
  flat arrays; the header's free byte, which M5 keeps for the
  descriptor until this is decided.
* **Size.** The count a day; the prototype a milestone (the compiler,
  the collector, equality, images).

### 4. Flat real arrays (M8, decided; measure it early)

* **The question.** `fft` stores 272 million reals into arrays after
  allocation. M8 makes `RealArray` and `Real64Array` flat;
  how much of `fft`'s and `tsp`'s remaining distance to the 16-byte
  layout is the array element's encoding?
* **How.** The harness has the kernel (`tests/layouts`, `real_array`
  under `L1+FLATREAL`); in the VM, a `Real64Array` whose `sub` and
  `update` primitives read and write raw doubles, on the finished M5
  layout, measured on `fft`, `tsp`, `simple` and `real_nbody`.
* **What it changes.** Nothing in the plan (M8 builds it); it says
  how much of experiment 3's gain the arrays already take.

### 5. Reals across calls in registers

* **The question.** `mandelbrot` has no heap at all and is still 1.08
  to 1.11: its reals cross a call and a write-back per pixel. Two
  ways out, neither built: typed slots (D5 B: the slot holds the
  double and a map tells the collector), or tier-2 code passing reals
  to tier-2 code in XMM registers and writing back only where a
  collection or a deoptimisation can see the frame.
* **How.** Count first: a counter under `--jit-profile` for the
  encodes and decodes executed, by cause (call argument, result,
  write-back around a primitive, field, constant), on the eight
  programs. Then the smaller mechanism: no write-back around a
  primitive that can neither collect nor raise (`mandelbrot` calls
  `int_to_real` through C once per pixel).
* **What it changes.** Whether D5 B is worth its maps for the reals'
  sake, and jit.md's calling convention between compiled functions.
* **Size.** The count and the skipped write-backs small; typed slots
  a milestone of their own (D5 B, which the gate left unbuilt).

### 6. The encoding on other machines

* **The question.** The rotation was measured on x86-64 with the JIT.
  On aarch64 the JIT's macro-assembler emits the same operations and
  the constant 2^61 is one `movz`; on a 32-bit machine the word is two
  machine words and the rotation by two crosses them.
* **How.** `bin/runevm-aarch64` under its emulator for instructions
  (not cycles); `bin/runevm32` built with `-DRUNE_REAL_ROT` (first
  figures above). A 32-bit decode that adds to and rotates the high
  half alone, where the exponent is, is the thing to try there.
* **What it changes.** `32-bit-vm.md`: if a 32-bit VM gets its own
  4-byte word, a double does not fit a word at all and the choices are
  a box for every real or two words; this encoding is then the 64-bit
  machines' alone.

### 7. `Real32`

* **The question.** `Real32` is a rounded double today. As a type of
  its own its 32 bits always fit the word beside a tag (Poly/ML tags a
  `Real32` in the upper half: `heap-layout.md`, *What the
  implementations do*), with no range and no box.
* **How.** Count `Real32` in the corpora first (the Basis suite, the
  benchmarks): if nothing uses it, stop. Else a representation of its
  own in `Rep`, as M5 gives `Int64`.
* **What it changes.** `basis.md`; not this roadmap.

### 8. Read the paper

* **The question.** The rotation is in the line of Melançon, Serrano
  and Feeley, "Float self-tagging" (PACMPL 9, OOPSLA2, 2025,
  doi:10.1145/3763108), which this plan knows by its abstract alone:
  invertible transformations of the float's bits that leave the tag in
  the word for the floats met in practice, in two Scheme compilers on
  four microarchitectures. What do they do about zero, which ranges do
  their variants cover, and what did they measure against?
* **How.** Read it; put its variants beside the two here in
  `tests/layouts` (the harness's `real_regs` and `real_array` kernels
  under each).
* **What it changes.** Experiments 1 and 2, which it may already
  answer.

## Order

1 and 2 before M5's second step fixes the encoding's details (they are
days). 8 beside them. 5's count and 3's count once M5's layout runs,
since both are read against the finished layout's numbers and decide
the one thing the gate left open, raw real fields. 4 with M8. 6 and 7
when their owners (`32-bit-vm.md`, `basis.md`) are taken up.

# Performance

What each configuration of Rune costs to run a program and to compile one,
against the SML systems Rune is built with. Why it costs that, and what is
being done about it, is in [plans/performance.md](plans/performance.md)
(the VMs and native code), [plans/jit.md](plans/jit.md) (the JIT of `vm/new`)
and [plans/middle-end.md](plans/middle-end.md) (the compiler's
optimisations); how native code is made is in [native.md](native.md).

## The configurations

| Configuration | What runs |
|---|---|
| `rune` | the stack bytecode of the self-hosted compiler, on `runevm` ([bytecode.md](bytecode.md)) |
| `rune:opt` | the same bytecode translated into x86-64 code by `runeopt` ([native.md](native.md)) |
| `rune:new` | the register bytecode on `vm/new` ([bytecode.md](bytecode.md), The register bytecode), at one of the JIT levels below |
| `native:HOST` | the program on the host's own Basis Library, compiled by the host |
| `xc1:HOST` | the program on Rune's Basis Library (`lib/basis`), compiled by the host ([basis-compat.md](basis-compat.md)) |

The hosts are MLton 20241230, SML/NJ 110.99.9 (64 and 32 bits), SML/NJ
2026.2, Poly/ML 5.9.2 and MLKit 4.7.23 (`make hosts`).

`vm/new` runs its register bytecode at a JIT level
([vm/new/ARCHITECTURE.md](../vm/new/ARCHITECTURE.md), Tier 1 and Tier 2),
chosen by `--jit=MODE` and `--jit-tier=N`, or by `RUNEVM_JIT` and
`RUNEVM_JIT_TIER` where the VM is started by a runner:

| Level | Options | What is compiled |
|---|---|---|
| `off` | `--jit=off` | nothing: the interpreter alone |
| `baseline` | `--jit=baseline` | a function at tier 1, the baseline compiler, when its counters say it is hot |
| `opt` | `--jit=opt` (the default) | a function at tier 2, which gives registers homes, when the same counters say so |
| `all` | `--jit=all` | every function at tier 1, when the program is loaded |
| `all+t2` | `--jit=all --jit-tier=2` | every function at tier 2, when the program is loaded (`rune:jit` of the matrix) |

`--jit=baseline --jit-tier=2` is `opt` by another name, and is not measured
apart.

## Running programs

`make perf` on an x86_64 machine with 16 CPUs (Xeon E5-1680 v3), on
2026-10-02 at `4652d4a`. One single-threaded job of another worktree and an
editor's language server were running beside it, so the times are those of a
machine that is nearly, not wholly, idle. Each cell is the milliseconds of
one run of a program of `tests/perf`: the program is run R times in a row
(the `wall R` line of its `.budget` file) in three rounds, and the fastest
round counts; the SML systems compile it before the timer starts, like the
others. In parentheses: the time divided by the baseline of the same
configuration, the geometric mean of `fib` and `tak`, which use no Basis
Library. That ratio separates what a library costs from how fast a system
runs code at all.

Rune on `runevm`, as native code, and on `vm/new` at each JIT level:

| Program | rune | rune:opt | rune:new off | rune:new baseline | rune:new opt | rune:new all | rune:new all+t2 |
|---|---:|---:|---:|---:|---:|---:|---:|
| array_sieve | 8.69 (2.5) | 4.62 (3.9) | 8.20 (2.5) | 3.93 (3.3) | 2.34 (2.4) | 3.95 (3.4) | 2.38 (2.4) |
| fib | 6.42 (1.8) | 2.27 (1.9) | 5.49 (1.7) | 2.28 (1.9) | 1.66 (1.7) | 2.20 (1.9) | 1.72 (1.7) |
| intinf_fact | 52.76 (15.2) | 26.62 (22.6) | 54.98 (17.1) | 24.02 (20.4) | 23.73 (24.2) | 25.04 (21.4) | 23.65 (23.7) |
| list_ops | 5.79 (1.7) | 2.65 (2.3) | 5.60 (1.7) | 2.81 (2.4) | 2.78 (2.8) | 3.29 (2.8) | 2.51 (2.5) |
| real_nbody | 2.91 (0.8) | 1.28 (1.1) | 2.17 (0.7) | 0.87 (0.7) | 0.52 (0.5) | 0.87 (0.7) | 0.53 (0.5) |
| string_ops | 10.77 (3.1) | 5.70 (4.8) | 10.20 (3.2) | 6.14 (5.2) | 5.80 (5.9) | 6.67 (5.7) | 5.91 (5.9) |
| tak | 1.88 (0.5) | 0.61 (0.5) | 1.89 (0.6) | 0.61 (0.5) | 0.58 (0.6) | 0.62 (0.5) | 0.58 (0.6) |
| word_bits | 4.67 (1.3) | 1.28 (1.1) | 3.72 (1.2) | 1.00 (0.8) | 0.43 (0.4) | 1.07 (0.9) | 0.43 (0.4) |

The hosts, each on its own Basis Library (`native`) and on Rune's (`xc1`):

| Program | native:mlton | native:smlnj-legacy | native:smlnj32 | native:smlnj-dev | native:polyml | native:mlkit |
|---|---:|---:|---:|---:|---:|---:|
| array_sieve | 0.50 (2.0) | 1.20 (3.7) | 0.97 (2.7) | 0.72 (2.4) | 0.64 (2.9) | 0.86 (1.0) |
| fib | 0.42 (1.7) | 0.43 (1.3) | 0.45 (1.3) | 0.39 (1.3) | 0.33 (1.5) | 1.46 (1.8) |
| intinf_fact | 0.03 (0.1) | 0.25 (0.8) | 0.43 (1.2) | 0.21 (0.7) | 0.13 (0.6) | 2.48 (3.0) |
| list_ops | 1.96 (7.8) | 1.96 (6.0) | 1.40 (3.9) | 1.21 (4.0) | 1.43 (6.4) | 1.43 (1.7) |
| real_nbody | 0.58 (2.3) | 0.51 (1.6) | 0.52 (1.5) | 0.50 (1.6) | 1.28 (5.8) | 1.43 (1.7) |
| string_ops | 1.58 (6.3) | 2.12 (6.5) | 2.14 (6.0) | 1.42 (4.6) | 2.02 (9.1) | 3.03 (3.7) |
| tak | 0.15 (0.6) | 0.25 (0.8) | 0.28 (0.8) | 0.24 (0.8) | 0.15 (0.7) | 0.47 (0.6) |
| word_bits | 0.12 (0.5) | 0.28 (0.9) | 0.25 (0.7) | 0.13 (0.4) | 0.17 (0.8) | 0.30 (0.4) |

| Program | xc1:mlton | xc1:smlnj-legacy | xc1:smlnj32 | xc1:smlnj-dev | xc1:polyml | xc1:mlkit |
|---|---:|---:|---:|---:|---:|---:|
| array_sieve | 0.46 (1.8) | 1.33 (3.9) | n/a | 1.15 (4.0) | 0.63 (2.8) | 0.76 (0.9) |
| fib | 0.39 (1.5) | 0.47 (1.4) | n/a | 0.35 (1.2) | 0.34 (1.5) | 1.36 (1.6) |
| intinf_fact | n/a | n/a | n/a | n/a | n/a | n/a |
| list_ops | 1.14 (4.4) | 1.89 (5.5) | n/a | 1.19 (4.1) | 1.53 (6.8) | 1.73 (2.1) |
| real_nbody | 0.59 (2.3) | 0.51 (1.5) | n/a | 0.50 (1.7) | 1.13 (5.0) | 1.45 (1.7) |
| string_ops | 2.62 (10.2) | 3.63 (10.6) | n/a | 2.51 (8.7) | 3.24 (14.3) | 4.35 (5.2) |
| tak | 0.17 (0.7) | 0.25 (0.7) | n/a | 0.24 (0.8) | 0.15 (0.7) | 0.51 (0.6) |
| word_bits | 0.13 (0.5) | 0.53 (1.5) | n/a | 0.13 (0.4) | 0.17 (0.8) | 0.31 (0.4) |

Not measured: `intinf_fact` in the `xc1` configurations, whose `IntInf`
constants a host types at its own `IntInf`, not at that of `lib/basis`; and
anything on `xc1:smlnj32`, where the `LargeInt` the wrapper times with is
not that of `lib/basis`, which does not load on a 31-bit `int`.

What the tables say:

* **`runevm` runs plain code 7 to 19 times slower than the native code of
  MLton, SML/NJ and Poly/ML**: `fib` 6.4 ms against 0.33 to 0.45, `tak`
  1.9 against 0.15 to 0.28. Against MLKit, whose calls are slow, it is 4
  times slower. This is the interpreter; [plans/performance.md](plans/performance.md)
  is about it.
* **Native code (`rune:opt`) runs these programs 1.9 to 3.6 times faster
  than `runevm`** (`fib` 2.27 ms, `tak` 0.61, `word_bits` 1.28 against
  4.67), and 2 to 11 times slower than MLton, SML/NJ and Poly/ML on `fib`,
  `tak` and `word_bits`.
* **`vm/new` interpreting alone (`off`) is as fast as `runevm`**, and up to
  25% faster where reals are involved (`real_nbody` 2.17 ms against 2.91):
  `tak` is 1.89 against 1.88, `fib` 5.49 against 6.42.
* **Tier 1 (`baseline`) is 1.7 to 3.7 times faster than `off`**, the more so
  the more of the time is in calls and in arithmetic of the program's own:
  `word_bits` 3.7 times, `tak` 3.1, `fib` 2.4; `string_ops` 1.7.
* **Tier 2 (`opt`, the default) adds nothing where the time is in the
  runtime, and up to 2.3 times where it is in arithmetic**: `word_bits`
  1.00 to 0.43 ms, `array_sieve` 3.93 to 2.34, `real_nbody` 0.87 to 0.52,
  `fib` 2.28 to 1.66, while `intinf_fact`, `list_ops`, `string_ops` and
  `tak` change by 6% or less. The default is 1.9 to 11 times faster than
  `runevm` and is faster than `rune:opt` on all but `list_ops` (2.78 ms
  against 2.65) and `string_ops` (5.80 against 5.70), which are about equal.
  On `real_nbody` it is as fast as MLton, SML/NJ and Poly/ML do it (0.52 ms
  against 0.50 to 0.58, 1.28 for Poly/ML); on `fib` and `tak` it is 4
  times MLton's.
* **Compiling every function when the program is loaded (`all`, `all+t2`)
  gives the code of the counters' levels**: the times of `all` are those of
  `baseline`, and the times of `all+t2` those of `opt`, to within 20%
  (`list_ops` 3.29 against 2.81 for the first pair, 2.51 against 2.78 for
  the second). What it costs is in *Compiling* below, where the
  whole compiler is compiled at the start.
* **Relative to its baseline, the library costs Rune less than it costs
  the hosts**: `list_ops` 1.7 times the baseline on Rune, 3.9 to 7.8 on the
  hosts but MLKit; `string_ops` 3.1 against 4.6 to 9.1 on the same. `IntInf` is the
  exception: 15 times the baseline on `runevm`, 0.1 to 1.2 on the hosts,
  which use GMP (MLton) or native code, and 3.0 on MLKit. Its limbs of 30
  bits are an SML datatype, and every limb operation is a call.
* **MLKit is slow at calls and relatively quick in its Basis Library**: its
  baseline, `fib` and `tak`, is 3 to 4 times MLton's, while `list_ops`
  takes 0.7 and `array_sieve` 1.7 times as long as MLton's, so that its
  ratios to the baseline are among the lowest of the tables.
* **The `xc1` columns** run Rune's library compiled by each host, between
  0.6 and 1.9 times as slow as that host's own library (`list_ops` 1.14 ms
  on MLton against 1.96 native, `string_ops` 2.62 against 1.58): the
  algorithms of `lib/basis` are not what makes Rune slow.

## Compiling

Each build of the compiler compiling `examples/hello.sml`, and compiling
the compiler itself (`BOOT_SRCS`, the bootstrap's input), the same day at
the same commit and on the same machine as above: wall-clock time, the
fastest of three rounds, a round of `hello` being 20 compiles. The builds
of the hosts are what `make host-builds` makes (`bin/rune-mlton`,
`bin/rune-smlnj-legacy`, `bin/rune-smlnj32`, `bin/rune-smlnj-dev`,
`bin/rune-polyml`, `bin/rune-mlkit`); the others are the self-hosted
compiler, `bin/rune.rbc`, on `runevm` and translated by `runeopt`, and
`bin/rune.new.rbc` on `vm/new` at each JIT level.

| Build | `hello` | the compiler |
|---|---:|---:|
| MLton | 6.7 ms | 1.12 s |
| Poly/ML | 9.3 ms | 1.08 s |
| MLKit | 8.4 ms | 1.90 s |
| SML/NJ 110.99.9, 64 bits | 21.8 ms | 2.56 s |
| SML/NJ 110.99.9, 32 bits | 21.2 ms | 2.34 s |
| SML/NJ 2026.2 | 24.9 ms | 2.38 s |
| `runevm` (`bin/rune`, what is shipped) | 26.2 ms | 6.01 s |
| native code (`runeopt` of `bin/rune.rbc`) | 17.0 ms | 3.12 s |
| `vm/new`, `off` | 22.9 ms | 5.44 s |
| `vm/new`, `baseline` | 36.1 ms | 3.24 s |
| `vm/new`, `opt` (the default) | 37.8 ms | 3.04 s |
| `vm/new`, `all` | 157.1 ms | 3.23 s |
| `vm/new`, `all+t2` | 187.9 ms | 3.18 s |

Not measured: the VMs built for Windows, 32-bit Linux and PowerPC.

* The shipped compiler compiles itself in 6.0 s, 5.4 times as long as the
  build MLton makes; translated into native code, in 3.1 s, 2.8 times.
* `vm/new` with its JIT on (`baseline`, `opt`) compiles the compiler in 3.0
  to 3.2 s, twice as fast as `runevm`, as fast as native code, 1.2 to 1.3
  times SML/NJ's builds and 2.7 times MLton's. Tier 2 is no faster than
  tier 1 here, as on `list_ops` and `string_ops`.
* A small program costs little on any: `hello` is 26 ms on `runevm`, most
  of it reading and elaborating the part of the Basis Library it uses. The
  JIT makes it dearer, 36 to 38 ms against 23 for the interpreter alone,
  and compiling all of the compiler up front (`all`) costs 157 to 188 ms.
* The counts that do not depend on the machine -- instructions executed,
  and bytes and objects allocated, by the compiler compiling `hello`, by
  the bootstrap and by `runedoc` -- are the budgets of `make perf-check`
  (`tests/perf/*.budget`). At this commit the bootstrap executes 951
  million instructions of stack bytecode and 515 million of register
  bytecode and allocates 1.17 GB in 26.0 million objects; compiling `hello`
  takes 3.08 million instructions, 3.5 MB and 53.6 thousand objects.

## Why `vm/new` at `opt` is slower than MLton

Measured on the same day and machine as the tables above, with `perf stat`
(user cycles and instructions of the wrapped `tests/perf` programs),
MLton's generated assembly (`-keep g`), and the tier-2 machine code of the
hot functions, dumped from a running `runevm-new --jit-perf-map` and
single-stepped under gdb for 20 to 30 thousand instructions each. The
traces are samples of the steady state of one function, not of a whole run.

| Program | Time, opt / MLton | Instructions, opt / MLton | IPC, opt and MLton | Dominant cause |
|---|---:|---:|---:|---|
| fib | 4.0 | 5.0 | 2.3, 2.0 | call and return protocol |
| tak | 3.9 | 4.1 | 2.4, 2.1 | call and return protocol |
| word_bits | 3.6 | 4.7 | 3.4, 3.2 | work around every operation |
| array_sieve | 4.7 | 4.6 | 1.7, 1.9 | work around every operation, 16-byte elements |
| real_nbody | 0.9 | 4.0 | 1.2, 0.3 | floating-point latency |
| string_ops | 3.7 | 2.9 | 1.8, 2.1 | lists of characters, runtime C code |
| list_ops | 1.4 (user cycles 2.8) | 1.9 | 1.2, 1.8 | cache misses; MLton's page faults |
| intinf_fact | about 800 | n/a | n/a | the algorithms of `lib/basis/intinf.sml` |

Where the cycle ratio follows the instruction ratio, which it does for
every program but `real_nbody`, `list_ops` and `intinf_fact`, the cost is
the number of instructions, not stalls.

* **`fib` and `tak`: the cost of a call.** A call of `fib` costs 84.5
  instructions on `vm/new` and about 17 on MLton. The trace of `fib`
  divides the 84.5 into 32 for the call (spilling the live registers as
  16-byte tagged Values, checking the register stack and the frame depth,
  building a 40-byte frame record on a separate frame stack, jumping, and
  loading the registers back after the return), 22 for the return (popping
  the record, storing the result as a Value in the caller's register,
  an indirect jump), 6 to fill the callee's registers with unit at its
  entry, 5.5 for the `--count` counter (`lea r15, [r15+N]`), 5 to make a
  comparison a stored boolean Value and test it, 8 for constants and
  operands moved through scratch registers, and 6 for the rest. MLton calls
  with a return address stored in a 16-byte frame, `fib` having a stack
  check, a compare and a jump; Rune's frame is a window of 6 registers of 16
  bytes plus the 40-byte record.
* **`word_bits` and `array_sieve`: work around every operation.** An
  iteration of `bits` is about 50 instructions against 11 for MLton: 7 are
  counters, 10 store the tag and payload of each result into its register
  slot, 3 load constants through a table (two loads each), 4 are tag checks
  and materialised booleans, and the loop's word goes through its slot in
  memory, so that an iteration takes 16.8 cycles against 3.8. The `strike`
  loop of `array_sieve` is 36 instructions per element against about 8: the
  global `n` is tag-checked each time, and the bounds check, the compare and
  the store of a 16-byte element are separate. MLton's array holds 4 bytes
  per element, Rune's 16, so that it allocates 3.4 times as much (37.6 MB
  against 11.1 MB) and has 2.5 times the L1 load misses. About 40% of
  `array_sieve` is in `Array.foldli`, `Vector` and `List` code, not in
  `strike`.
* **`real_nbody`: latency.** The loop is a chain of `sqrt` and two
  divisions. A C loop of the same computation at `-O2` takes 80 cycles per
  iteration on this CPU; `vm/new` takes 88 and MLton 94. `vm/new` executes
  about 108 instructions per iteration and MLton 27, but the instructions
  are hidden behind the latency.
* **`string_ops`: lists and the runtime.** `vm/new` allocates 1.8 times as
  much (136.6 MB against 77.0 MB), spends about 37% of its cycles in the
  runtime's C code (`p_string_*`, `vm_alloc`, `vm_cons`, `vm_string_from`)
  and 10% in the collector, and has 3.5 times the L1 load misses. `String.map`
  and `String.translate` are `implode (List.map f (explode s))`
  (`lib/basis/string.sml`), so each character is a list cell.
* **`list_ops`: the cache, and MLton's page faults.** In user cycles MLton
  is 2.8 times faster, in wall-clock time 1.4 times. `vm/new` has 4.3 times
  the L1 load misses and spends 12.5% of its cycles in the collector, though
  both allocate the same amount (56.6 MB and 58.0 MB). MLton spends half of
  its time in the kernel, faulting in 12.1 thousand pages (`vm/new`: 7.2
  thousand). A recursion over a list, like `List.filter`, costs about 62
  instructions per element on `vm/new`, the call and return being most of
  it. What makes the misses 4.3 times as many is not isolated.
* **`intinf_fact`: algorithms.** `vm/new` allocates 76 MB, MLton (GMP) 0.38
  MB. An `IntInf` is a list of 30-bit limbs; `mulMag` does, for each limb
  of its right operand, a `mulSmall`, a `shiftLimbs` that allocates a
  list of zeros, and an `addMag` that copies the accumulator, so a
  multiplication is quadratic in the length of the big operand even when the
  other is one limb, as in `fact`. `divModMag` finds each quotient limb by a
  binary search of 30 steps, each a `mulSmall` and a `cmpMag` (which takes
  two `List.length` and two `List.rev`). Of the 15 million VM instructions
  of one run, about 10 million are `fact 300` and 5 million the `divMod`;
  `toString` and `pow` are almost nothing.

What recurs: the tagged 16-byte Values written to memory at every result,
the frame record of every call, the instruction counter of `--count` in
compiled code, the registers filled with unit at entry, constants loaded
through a table; and MLton's whole-program optimisation, which inlines and
defunctionalises closures, folds `n` in `array_sieve` to a constant, and
uses 4-byte `bool`, `int` and `word`. None of these was switched off to
measure its share: the figures are instruction counts of the traces.

## How to reproduce

```sh
make                              # bin/rune, bin/runevm
make host-builds runeopt bin/runevm-opt bin/rune-new bin/runevm-new
make hosts                        # MLton, SML/NJ, Poly/ML and MLKit, once
make perf PERF_CONFIGS=rune,rune:opt,rune:new,hosts,xc1
                                  # the tables, in tests/out/perf/wall.md
```

`rune:new` runs at `--jit=opt` unless the environment names another level:
the other columns are `RUNEVM_JIT=off`, `RUNEVM_JIT=baseline`,
`RUNEVM_JIT=all` and `RUNEVM_JIT=all RUNEVM_JIT_TIER=2` before `make perf
PERF_CONFIGS=rune:new`.

The compile times: `make bin/rune.new.rbc`, then `bin/runeopt-mlton
--options "--heap-size 67108864" bin/rune.rbc -o bin/rune-native` for the
native compiler, and each build run as `BUILD -o out.rbc examples/hello.sml`
and `BUILD -o out.rbc $(BOOT_SRCS)`, where `BUILD` is `bin/rune-HOST`, or
`VM --heap-size 67108864 bin/rune.rbc --lib lib` (`bin/rune.new.rbc` on
`bin/runevm-new`, with the JIT options of the level), or `bin/rune-native
--lib lib`. `scripts/perf-cycles.sh` measures cycles and instructions of the
same runs, with `jit-off`, `jit-baseline`, `jit-all` and `+t2` for the levels.

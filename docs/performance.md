# Performance

What Rune costs to run a program and to compile one, as it is shipped,
against the SML systems Rune is built with. Rune as shipped is the register
bytecode of `bin/rune` on `bin/runevm`, which tiers up to tier 2 of its JIT
([runtime/register/README.md](../runtime/register/README.md)), with values
of 8 bytes ([plans/heap-layout.md](plans/heap-layout.md)), the generational
collector ([plans/garbage-collector-v2.md](plans/garbage-collector-v2.md))
and frames in the value stack ([plans/native-frames.md](plans/native-frames.md)).
Why it costs what it does, and what was done about it, is in
[plans/performance.md](plans/performance.md), retired on 2026-10-20: its
*Where we ended* compares every table below with the compiler and VMs of
2026-10-11, and what it left is in the plans that take it. How native code
is made is in [native.md](native.md).

**When and how.** Measured on 2026-10-20, 17:42 to 20:15, with the
compiler and VMs of `a6a024ab1` (branch `performance`: that roadmap's M1 to
M9 and native-frames.md's M1 to M9, on master `1dd139fee`), by the
commands of *Measuring* below, on a Xeon E5-1680 v3 (Haswell, 8 cores, 16
threads) under WSL2 with 31 GB.

**The load.** Every timed run was pinned to a core of its own (`taskset`),
at most six at a time on six of the eight cores, with nothing on their
second threads; VS Code and the Windows host ran beside them. Each table
gives the 1-minute load average its runs started at. Read the tables so:

* **counts** -- machine instructions (`instructions:u` of `perf stat`) and
  the bytecode instructions and allocation of `runevm --count` -- repeat to
  within a few thousand in billions, whatever the load: they are the
  measurements;
* **ratios** of Rune to MLton and to Poly/ML are of runs in the same
  session;
* **seconds and cycles** are indications: the least of several runs, and
  higher the more runs share the machine. At a load of 9 to 12, six runs at
  once, the compiler compiling itself took 12.5G cycles, where it took 8.5G
  alone. So the tables of `tests/perf` against MLton and Poly/ML, of `make
  perf` and of HOL4 were taken one run at a time, at a load of 2 to 3 (the
  one other run beside them a program of the benchmark suite, on another
  core).

## The configurations

| Configuration | What runs |
|---|---|
| `rune` | Rune as shipped: `bin/rune`'s register bytecode on `bin/runevm`, tiering up to tier 2 |
| `rune:stack` (`stack` in `perf-cycles.sh`) | the stack bytecode on `runevm-stack` ([bytecode.md](bytecode.md)) |
| `rune:opt` (`opt`) | the stack bytecode translated into x86-64 code by `runeopt` ([native.md](native.md)) |
| `native:HOST` (`mlton`, `polyml`, ...) | the program on the host's own Basis Library, compiled by the host |
| `xc1:HOST` | the program on Rune's Basis Library (`lib/basis`), compiled by the host ([basis-compat.md](basis-compat.md)) |

The hosts are MLton 20241230, SML/NJ 110.99.9 (64 and 32 bits), SML/NJ
2026.2, Poly/ML 5.9.2 and MLKit 4.7.25 (`make hosts`). For the compiler
itself, `mlton`, `polyml` and the rest are the host's build of it
(`bin/rune-HOST`, `make host-builds`); the Poly/ML builds start with a heap
of 1 GB (`POLYML_HEAP`).

`bin/runevm` runs at a JIT level chosen by `--jit=MODE` and `--jit-tier=N`,
or by `RUNEVM_JIT` and `RUNEVM_JIT_TIER` where a runner starts it
([runtime/register/README.md](../runtime/register/README.md), Tier 1 and
Tier 2); `bin/rune-measure perf-cycles` names them `jit-MODE`:

| Level | Options | What is compiled |
|---|---|---|
| `off` | `--jit=off` | nothing: the interpreter alone |
| `baseline` | `--jit=baseline` | a function at tier 1, when its counters say it is hot |
| `opt` | `--jit=opt` (the default) | a function at tier 2, which gives registers homes, when the same counters say so |
| `all` | `--jit=all` | every function at tier 1, when the program is loaded |
| `all+t2` | `--jit=all --jit-tier=2` | every function at tier 2, when the program is loaded |

## Running programs

### The programs of `tests/perf`, against MLton and Poly/ML

Each program wrapped as `make perf` wraps it (its body a function called R
times, R from the `wall R` line of its `.budget`), and the compiler and
`runedoc` on the inputs of `compile-sigs`, `runedoc-page` and the
bootstrap: for those, MLton and Poly/ML are their builds of the compiler
and of `runedoc`. Machine instructions, and the ratios of instructions and
of cycles, of the run with the least cycles of five
(`bin/rune-measure perf-cycles`; one run at a time, a load of 3 to 6):

| Program | Rune, instructions | MLton | Poly/ML | Rune / MLton | Rune / Poly/ML | cycles: Rune / MLton | Rune / Poly/ML |
|---|---:|---:|---:|---:|---:|---:|---:|
| `array_sieve` | 143M | 55M | 54M | 2.6 | 2.7 | 1.80 | 1.47 |
| `fib` | 196M | 128M | 112M | 1.5 | 1.7 | 1.02 | 1.15 |
| `hash_mod` | 597M | 234M | 341M | 2.6 | 1.8 | 0.99 | 0.39 |
| `intinf_fact` | 25M | 0.9M | 4.8M | 30 | 5.2 | 15.14 | 2.93 |
| `list_ops` | 258M | 109M | 147M | 2.4 | 1.7 | 1.89 | 1.18 |
| `real_nbody` | 175M | 54M | 315M | 3.2 | 0.6 | 0.94 | 0.62 |
| `string_ops` | 863M | 232M | 224M | 3.7 | 3.9 | 2.61 | 2.06 |
| `tak` | 62M | 45M | 47M | 1.4 | 1.3 | 1.05 | 1.01 |
| `word_bits` | 174M | 53M | 96M | 3.3 | 1.8 | 2.96 | 1.77 |
| `compile-sigs` | 820M | 129M | 94M | 6.4 | 8.7 | 3.46 | 4.13 |
| `runedoc-page` | 508M | 251M | 96M | 2.0 | 5.3 | 1.67 | 2.44 |
| `bootstrap` | 13.45G | 4.99G | 5.70G | 2.7 | 2.4 | 1.38 | 1.20 |

* **Calls cost what they cost in MLton's code.** `fib` and `tak` take
  within 5% of the cycles of MLton's build of them, with 1.4 to 1.5 times
  its instructions; a call is 26 instructions and 8 cycles at tier 2 against
  MLton's 17 and 8.7 ([plans/native-frames.md](plans/native-frames.md),
  M9).
* **Arrays, strings and words** are 2.6 to 3.7 times MLton's instructions
  and 1.8 to 3 times its cycles (`array_sieve`, `string_ops`, `word_bits`):
  the body of tier 2's code, and the Basis's own code, more than the call.
* **`real_nbody` runs as fast as MLton's code** in cycles, with three
  times its instructions, hidden behind the latency of `sqrt` and division,
  and faster than Poly/ML's.
* **`intinf_fact` is IntInf**, on GMP since master's `gmp` work: 30 times
  MLton's instructions and 5 times Poly/ML's ([plans/gmp.md](plans/gmp.md)).
* **`hash_mod` is the loop `Pickle.hash` had** until functors-units M4
  replaced it with rx2fw (lib/compiler/util/pickle.sml), four `mod`s by
  literal primes a byte, kept as the case of a division by
  a constant ([plans/functors-units.md](plans/functors-units.md), M1),
  which tier 2 makes a multiplication by a magic number since that
  milestone: MLton's cycles, with 2.6 times its instructions, where the
  VM before it, each `mod` a `cqo; idiv` behind three tests, took 651M
  cycles and 667M instructions for the same bytecode, 3.5 times the
  cycles (the row and that run taken alone on 2026-10-24 at a load of
  2.5, not with the rest of the table; at a load of 12, 300M cycles
  against MLton's 238M and the VM before's 827M).
* **The compiler compiling itself** executes 2.7 times the instructions of
  MLton's build and takes 1.4 times its cycles (1.38 here, 1.46 in five
  more runs of each one after another); `compile-sigs`, the module
  language, is still 6.4 times the instructions and 3.5 times the cycles.

### Rune's engines

The same programs on the JIT's levels, on `runevm-stack` and as native code
(`runeopt`): instructions, then cycles, each with its ratio to tier 2
(`bin/rune-measure perf-cycles --runs 3`; a load of 4 to 11, `runedoc-page` taken
again alone).

| Program | tier 2 (default) | tier 1 | interpreter | runevm-stack | runeopt |
|---|---:|---:|---:|---:|---:|
| `array_sieve` | 143M | 241M (1.7) | 1.03G (7.2) | 1.47G (10.3) | 273M (1.9) |
| `fib` | 196M | 339M (1.7) | 2.48G (12.6) | 2.45G (12.5) | 605M (3.1) |
| `intinf_fact` | 25M | 26M (1.0) | 41M (1.6) | 89M (3.5) | 25M (1.0) |
| `list_ops` | 258M | 321M (1.2) | 1.04G (4.0) | 1.17G (4.5) | 359M (1.4) |
| `real_nbody` | 175M | 810M (4.6) | 2.33G (13.3) | 3.48G (19.9) | 969M (5.5) |
| `string_ops` | 863M | 937M (1.1) | 1.98G (2.3) | 2.02G (2.3) | 948M (1.1) |
| `tak` | 62M | 99M (1.6) | 655M (10.6) | 714M (11.5) | 167M (2.7) |
| `word_bits` | 174M | 323M (1.9) | 1.66G (9.5) | 2.26G (12.9) | 389M (2.2) |
| `compile-sigs` | 820M | 852M (1.0) | 1.59G (1.9) | 1.84G (2.2) | 588M (0.7) |
| `runedoc-page` | 508M | 584M (1.2) | 1.46G (2.9) | 1.74G (3.4) | 531M (1.0) |
| `bootstrap` | 13.45G | 17.18G (1.3) | 60.68G (4.5) | 71.14G (5.3) | 21.88G (1.6) |

| Program | cycles: tier 2 | tier 1 | interpreter | runevm-stack | runeopt |
|---|---:|---:|---:|---:|---:|
| `array_sieve` | 54M | 109M (2.0) | 455M (8.4) | 622M (11.5) | 158M (2.9) |
| `fib` | 77M | 171M (2.2) | 1.22G (15.9) | 1.26G (16.4) | 295M (3.8) |
| `intinf_fact` | 16M | 12M (0.7) | 29M (1.8) | 53M (3.3) | 15M (0.9) |
| `list_ops` | 144M | 170M (1.2) | 449M (3.1) | 472M (3.3) | 197M (1.4) |
| `real_nbody` | 178M | 418M (2.3) | 955M (5.4) | 1.86G (10.4) | 462M (2.6) |
| `string_ops` | 390M | 491M (1.3) | 822M (2.1) | 893M (2.3) | 384M (1.0) |
| `tak` | 21M | 46M (2.1) | 286M (13.4) | 310M (14.5) | 77M (3.6) |
| `word_bits` | 58M | 113M (1.9) | 656M (11.3) | 976M (16.8) | 169M (2.9) |
| `compile-sigs` | 651M | 686M (1.1) | 874M (1.3) | 1.02G (1.6) | 581M (0.9) |
| `runedoc-page` | 254M | 297M (1.2) | 624M (2.5) | 693M (2.7) | 262M (1.0) |
| `bootstrap` | 10.86G | 14.23G (1.3) | 36.06G (3.3) | 43.57G (4.0) | 18.62G (1.7) |

* **Tier 2 executes the fewest instructions** but on `intinf_fact`, whose
  time is GMP's, and on the compiler on small inputs, where `runeopt`'s
  code takes 0.7 (`compile-sigs`) and 1.0 times them (`runedoc-page`):
  tier 1 1.0 to 1.9 times them (4.6 on `real_nbody`), `runeopt`'s native
  code 1.1 to 3.1 times on the programs (5.5 on `real_nbody`), the
  interpreter 1.6 to 13 times.
* **On the compiler** tier 1 is 1.3 times tier 2's instructions, `runeopt`
  1.6 times and the interpreter 4.5 times; on 2026-10-12 tier 2 and
  `runeopt` were level ([plans/performance.md](plans/performance.md),
  *Where we ended*).

### Wall-clock time (`make perf`)

Milliseconds of one run of each program of `tests/perf` (`make perf`): the
program run R times in a row (the `wall R` line of its `.budget`) in three
rounds, the fastest round counting, and the least of three such passes;
the SML systems compile it before the timer starts. In parentheses: Rune's
time divided by the configuration's. Three passes one after another, at a
load of 2.2 to 2.3; Rune's library compiled by the hosts (`xc1`) in a
table of its own, below the hosts' own.

| Program | rune | rune:stack | rune:opt | mlton | smlnj-legacy | smlnj32 | smlnj-dev | polyml | mlkit |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `array_sieve` | 0.84 | 6.40 (0.1) | 1.70 (0.5) | 0.42 (2.0) | 1.10 (0.8) | 0.80 (1.0) | 0.52 (1.6) | 0.51 (1.6) | 0.69 (1.2) |
| `fib` | 0.34 | 4.91 (0.1) | 1.57 (0.2) | 0.40 (0.8) | 0.38 (0.9) | 0.36 (0.9) | 0.33 (1.0) | 0.29 (1.2) | 1.31 (0.3) |
| `intinf_fact` | 0.49 | 3.17 (0.2) | 1.16 (0.4) | 0.03 (16) | 0.21 (2.3) | 0.37 (1.3) | 0.15 (3.3) | 0.07 (7.0) | 2.32 (0.2) |
| `list_ops` | 1.56 | 6.18 (0.3) | 2.45 (0.6) | 1.58 (1.0) | 1.56 (1.0) | 1.24 (1.3) | 1.04 (1.5) | 1.19 (1.3) | 1.27 (1.2) |
| `real_nbody` | 0.48 | 3.87 (0.1) | 1.16 (0.4) | 0.52 (0.9) | 0.45 (1.1) | 0.46 (1.0) | 0.44 (1.1) | 0.94 (0.5) | 1.37 (0.4) |
| `string_ops` | 5.09 | 11.64 (0.4) | 5.68 (0.9) | 1.40 (3.6) | 2.03 (2.5) | 1.81 (2.8) | 1.69 (3.0) | 1.80 (2.8) | 2.72 (1.9) |
| `tak` | 0.13 | 1.87 (0.1) | 0.52 (0.2) | 0.12 (1.1) | 0.21 (0.6) | 0.23 (0.6) | 0.20 (0.7) | 0.12 (1.1) | 0.41 (0.3) |
| `word_bits` | 0.27 | 3.94 (0.1) | 0.80 (0.3) | 0.09 (3.0) | 0.22 (1.2) | 0.21 (1.3) | 0.10 (2.7) | 0.14 (1.9) | 0.28 (1.0) |

| Program | rune | xc1:mlton | xc1:smlnj-legacy | xc1:smlnj-dev | xc1:polyml | xc1:mlkit |
|---|---:|---:|---:|---:|---:|---:|
| `array_sieve` | 0.84 | 0.42 (2.0) | 1.16 (0.7) | 0.71 (1.2) | 0.67 (1.3) | 0.78 (1.1) |
| `fib` | 0.34 | 0.37 (0.9) | 0.37 (0.9) | 0.35 (1.0) | 0.29 (1.2) | 1.32 (0.3) |
| `list_ops` | 1.56 | 0.94 (1.7) | 1.75 (0.9) | 1.18 (1.3) | 1.33 (1.2) | 1.64 (1.0) |
| `real_nbody` | 0.48 | 0.55 (0.9) | 0.46 (1.0) | 0.44 (1.1) | 0.89 (0.5) | 1.29 (0.4) |
| `string_ops` | 5.09 | 1.81 (2.8) | 3.41 (1.5) | 2.13 (2.4) | 3.40 (1.5) | 3.77 (1.4) |
| `tak` | 0.13 | 0.12 (1.1) | 0.21 (0.6) | 0.20 (0.7) | 0.12 (1.1) | 0.41 (0.3) |
| `word_bits` | 0.27 | 0.09 (3.0) | 0.27 (1.0) | 0.10 (2.7) | 0.14 (1.9) | 0.27 (1.0) |

* **Rune as shipped is level with the hosts on calls and reals:** `fib`,
  `tak` and `real_nbody` take 0.8 to 1.2 times MLton's and Poly/ML's time
  (Poly/ML's `real_nbody` twice Rune's); `list_ops` as long as MLton's;
  `array_sieve`, `word_bits` and `string_ops` 2 to 3.6 times MLton's, the
  last 1.9 to 3.6 times every host's.
* **`xc1`**, Rune's library compiled by a host, takes as long as the host's
  own library on `fib`, `tak`, `real_nbody` and `word_bits`, 1.3 to 1.9
  times on `string_ops` on every host, and up to 1.4 times on `array_sieve`
  and `list_ops` (where on MLton it is 0.6 times). Not measured: `xc1:smlnj32`,
  whose library lacks the `Timer` the wrapper that times a program needs,
  and `intinf_fact`, whose IntInf constants a host types at its own IntInf.

### MLton's benchmark programs

MLton's own benchmarks (`benchmark/tests` of MLton, at the sizes of
`tests/perf/mlton-bench.txt`, built as `bin/rune-measure perf-cycles
--mlton-bench` builds them): the 38 that run without MLton's input files,
on Rune as shipped, MLton and Poly/ML (`peek` and `vector64-concat` use
`Int64`, which Poly/ML lacks). Cycles, the least of three rounds
(`smith-normal-form` one), with the instructions of the same run; bytes
allocated by `runevm --count` beside MLton's `@MLton gc-summary`. A load
of 3.6 to 13.

* **The geometric mean** of Rune's cycles over MLton's is 3.66 (median
  3.36, 0.50 for `even-odd` to 22.4 for `output1`), and over Poly/ML's
  1.48 (36 programs, median 1.38).
* **Programs of calls and closures are within 1.5 times MLton:** `fib`,
  `tak`, `tyan`, `logic`; `model-elimination`, `boyer`, `nucleic` and
  `barnes-hut` 1.9 to 3.6, which spend most of their time outside calls.
* **The farthest are the Basis's code and allocation MLton removes:**
  `output1` 22 and `psdes-random` 5.3 (MLton allocates nothing in them),
  `checksum` 18, `md5` 12, `vector-rev` 12, `matrix-multiply` 11, `life` 8.

| Program | Rune, cycles | Rune / MLton, cycles | instructions | Rune / Poly/ML, cycles | bytes: Rune / MLton |
|---|---:|---:|---:|---:|---:|
| `even-odd` | 6.27G | 0.50 | 1.12 | 1.96 | 0.46 |
| `tailfib` | 6.25G | 1.07 | 2.01 | 1.68 | 0.45 |
| `fib` | 13.49G | 1.18 | 1.52 | 1.28 | 0.13 |
| `tak` | 7.97G | 1.25 | 1.81 | 1.39 | 0.12 |
| `tyan` | 586M | 1.40 | 2.00 | 1.27 | 1.59 |
| `logic` | 720M | 1.46 | 1.62 | 1.05 | 1.58 |
| `tsp` | 16.01G | 1.62 | 5.77 | 0.37 | 1.00 |
| `fft` | 28.76G | 1.93 | 4.08 | 0.16 | 1.00 |
| `model-elimination` | 82.26G | 1.94 | 2.28 | 1.34 | 3.13 |
| `boyer` | 791M | 2.07 | 3.07 | 0.80 | 1.17 |
| `simple` | 323M | 2.24 | 2.81 | 0.78 | 0.80 |
| `mpuz` | 2.52G | 2.37 | 3.06 | 1.34 | 0.70 |
| `nucleic` | 941M | 2.39 | 3.13 | 1.05 | 1.18 |
| `knuth-bendix` | 173M | 2.48 | 3.80 | 0.84 | 16 |
| `smith-normal-form` | 2.02G | 2.88 | 4.70 | 2.52 | 0.05 |
| `DLXSimulator` | 57.78G | 2.96 | 4.67 | 3.26 | 0.75 |
| `imp-for` | 656M | 2.98 | 4.29 | 1.37 | 0.56 |
| `count-graphs` | 27.32G | 3.03 | 3.36 | 1.45 | 4.45 |
| `mandelbrot` | 71.41G | 3.17 | 5.42 | 1.35 | 8.73 |
| `string-concat` | 466M | 3.55 | 3.29 | 2.20 | 1.00 |
| `barnes-hut` | 357M | 3.56 | 4.19 | 0.89 | 1.21 |
| `merge` | 1.23G | 3.76 | 6.82 | 1.39 | 0.77 |
| `vector64-concat` | 6.29G | 4.04 | 6.61 | n/a | 1.00 |
| `peek` | 3.62G | 4.09 | 3.72 | n/a | 0.90 |
| `tailmerge` | 621M | 4.19 | 6.92 | 0.62 | 1.84 |
| `wc-input1` | 845M | 4.51 | 5.67 | 0.33 | 3.99 |
| `wc-scanStream` | 773M | 4.69 | 5.43 | 0.34 | 3.76 |
| `psdes-random` | 97.57G | 5.33 | 8.00 | 7.44 | (MLton: 1112 bytes) |
| `zebra` | 9.55G | 5.97 | 8.88 | 3.97 | 11 |
| `vector32-concat` | 8.74G | 7.90 | 8.98 | 2.43 | 2.00 |
| `life` | 40.47G | 8.13 | 16.08 | 9.96 | 2.63 |
| `matrix-multiply` | 14.07G | 10.67 | 9.45 | 0.65 | 2.51 |
| `raytrace` | 5.3M | 11.11 | 32.23 | 1.48 | 2.54 |
| `vector-rev` | 17.36G | 11.63 | 9.37 | 4.70 | 4.00 |
| `md5` | 168.88G | 12.32 | 15.31 | 4.94 | 234 |
| `pidigits` | 19M | 17.05 | 25.36 | 3.14 | 1.56 |
| `checksum` | 617M | 18.38 | 14.05 | 4.70 | 1.00 |
| `output1` | 219.32G | 22.38 | 21.40 | 2.91 | (MLton: 6024 bytes) |

### Where the time goes

The compiler compiling itself (`bootstrap`) and HOL4's kernel work on Rune
as shipped, by part of the runtime: samples of `perf record -e cycles:u`
over `runevm --jit-perf-map`, grouped by `bin/rune-measure perf-groups` (the
compiler at a load of 8 among the session's runs, HOL alone at 2.3).

| Part | The compiler compiling itself | HOL4's kernel work |
|---|---:|---:|
| the JIT's code, tier 2 | 54.2% | 76.5% |
| the collector: minor collections | 20.0% | 7.6% |
| the collector: the old generation | 13.9% | 2.1% |
| the JIT compiling | 3.5% | 1.8% |
| the interpreter | 1.1% | 0.8% |
| allocation outside the code (slow paths) | 1.5% | 1.2% |
| the frames' walks, liveness and return barrier | 0.3% | 0.4% |
| string order in the runtime | 1.1% | 1.1% |
| equality in the runtime | 0.2% | 0.2% |
| IntInf's primitives (GMP) | 0.0% | 1.0% |
| the primitives | 0.8% | 0.2% |
| restoring the image, loading | 0.2% | 2.9% |
| the C library's malloc and printf | 1.4% | 1.1% |
| memcpy and memmove (not the collector's) | 1.1% | 0.8% |
| the rest | 0.8% | 2.2% |

So the code is half the compiler's time and three quarters of HOL's, and
the collector a third of the compiler's: more cycles than the whole gap to
MLton's build ([plans/garbage-collector-v3.md](plans/garbage-collector-v3.md),
*Left by the performance plan*). A program of small arithmetic is the code
alone: `fib` is 98.6% `jit2:fib`. A deep recursion is the walk of its
frames: on MLton's `merge` the frames' walks, liveness and return barrier
take 37% of the cycles, the collector 42% and the code 19%.

## The benchmark suite

The programs of [`examples/benchmarks`](../examples/benchmarks/README.md)
at the normal input (`make bench BENCH_SAMPLES=3`): the median of three
fresh processes, in seconds by GNU time to the hundredth, startup included
and compilation not. Rune compiles at `-O2`; the hosts at their defaults.
In parentheses: Rune's time divided by the host's, where Rune took at least
0.02 s. The suite has 510 programs since the ports of nofib and Sandmark
([plans/benchmarks.md](plans/benchmarks.md)). This run measured the first
258 of them, which include the 152 of the suite before them (the table),
and was stopped there: the others take hours on the slower hosts
(`cryptarithm1-strict` 760 s a run on SML/NJ). A load of 4 to 12, the
session's other runs beside it; the ratios are of the same session.

* **Against MLton**, of the 152, the 57 programs of at least 0.10 s on Rune
  take 126.2 s against 51.8 s, 2.4 times. The geometric mean of the ratios
  is 2.34 (median 2.00, the 71 programs of at least 0.05 s on Rune and 0.02
  s on MLton); of the 258, 2.26 (median 2.00, 123 programs).
* **Against Poly/ML** the geometric mean is 1.19 (median 1.22, 74
  programs), and against SML/NJ 110.99.9 0.83 (median 0.86, 73 programs):
  Rune as shipped is faster than SML/NJ on most of them. Of the 258, 1.19
  and 0.81.
* **The farthest from MLton:** `mandelbrot-rat` 17 (IntInf, on GMP);
  `flat-array` 11, `zebra` and `klife_eq` 6.3, `life-smlnj` 5.9,
  `many_refs` 5.8, `ratio-regions_tp` and `life` 5.5; of the others,
  `stack_push_pop` 28, `ansi-strict` 13, `rsa-lazy` and `rsa-strict` 10
  and 9.
* **The closest:** the latency workloads, which measure the collector
  (`latency-static-map` 0.8, `latency-ring` 1.0); `kitfib35` 0.9,
  `primes-strict`, `exp3_8-strict` and `tak` 1.0.
* **Not timed:** on SML/NJ 110.99.9 `aobench`, `barnes-hut`,
  `black-scholes` and `tsp-smlnj`, which fail their checks, and `id-ray`,
  which reads its input while it is elaborated; on Poly/ML `id-ray`, and
  `peek` and `vector64-concat`, which use `Int64`.

| Program | Rune | MLton | SML/NJ 110.99.9 | Poly/ML |
|---|---:|---:|---:|---:|
| tak | 0.09 | 0.09 (1.0) | 0.13 (0.7) | 0.06 (1.5) |
| kittmergesort | 0.05 | 0.04 (1.2) | 0.06 (0.8) | 0.03 (1.7) |
| primes-lazy | 0.03 | 0.01 (3.0) | 0.05 (0.6) | 0.04 (0.8) |
| primes-strict | 0.31 | 0.32 (1.0) | 0.69 (0.4) | 0.30 (1.0) |
| bdd | 0.06 | 0.02 (3.0) | 0.07 (0.9) | 0.03 (2.0) |
| fib | 0.01 | 0.01 | 0.02 | 0.01 |
| tailfib | 0.00 | 0.00 | 0.01 | 0.00 |
| even-odd | 0.00 | 0.00 | 0.02 | 0.00 |
| merge | 0.02 | 0.00 | 0.03 (0.7) | 0.01 (2.0) |
| tailmerge | 0.02 | 0.01 (2.0) | 0.02 (1.0) | 0.01 (2.0) |
| imp-for | 0.00 | 0.00 | 0.01 | 0.00 |
| vector-rev | 0.01 | 0.00 | 0.02 | 0.00 |
| vector32-concat | 0.00 | 0.00 | 0.02 | 0.00 |
| vector64-concat | 0.00 | 0.00 | 0.02 | n/a |
| string-concat | 0.00 | 0.00 | 0.01 | 0.00 |
| wc-input1 | 0.04 | 0.01 (4.0) | 0.06 (0.7) | 0.07 (0.6) |
| wc-scanStream | 0.06 | 0.01 (6.0) | 0.04 (1.5) | 0.05 (1.2) |
| checksum | 0.15 | 0.01 (15) | 0.06 (2.5) | 0.04 (3.8) |
| boyer | 0.10 | 0.07 (1.4) | 0.12 (0.8) | 0.15 (0.7) |
| nucleic | 0.10 | 0.04 (2.5) | 0.08 (1.2) | 0.13 (0.8) |
| life | 0.11 | 0.02 (5.5) | 0.23 (0.5) | 0.02 (5.5) |
| matrix-multiply | 0.01 | 0.00 | 0.02 | 0.01 |
| md5 | 0.02 | 0.00 | 0.02 (1.0) | 0.01 (2.0) |
| fft | 0.02 | 0.00 | 0.04 (0.5) | 0.03 (0.7) |
| binary-trees | 0.01 | 0.01 | 0.03 | 0.01 |
| flat-array | 0.34 | 0.03 (11) | 1.19 (0.3) | 0.80 (0.4) |
| peek | 1.79 | 0.34 (5.3) | 1.16 (1.5) | n/a |
| psdes-random | 0.09 | 0.02 (4.5) | 0.11 (0.8) | 0.04 (2.2) |
| mandelbrot | 0.03 | 0.01 (3.0) | 0.03 (1.0) | 0.04 (0.8) |
| pidigits | 0.02 | 0.00 | 0.03 (0.7) | 0.01 (2.0) |
| logic | 3.17 | 1.92 (1.7) | 2.53 (1.3) | 2.16 (1.5) |
| zebra | 0.38 | 0.06 (6.3) | 0.63 (0.6) | 0.13 (2.9) |
| count-graphs | 0.03 | 0.01 (3.0) | 0.03 (1.0) | 0.03 (1.0) |
| many_refs | 0.23 | 0.04 (5.8) | 0.43 (0.5) | 0.18 (1.3) |
| tensor | 0.52 | 0.10 (5.2) | 0.38 (1.4) | 0.60 (0.9) |
| zern | 0.02 | 0.01 (2.0) | 0.02 (1.0) | 0.04 (0.5) |
| smith-normal-form | 0.01 | 0.00 | 0.02 | 0.00 |
| ratio-regions | 0.03 | 0.01 (3.0) | 0.08 (0.4) | 0.03 (1.0) |
| mpuz | 9.73 | 3.14 (3.1) | 13.36 (0.7) | 5.93 (1.6) |
| DLXSimulator | 43.86 | 11.01 (4.0) | 36.92 (1.2) | 9.97 (4.4) |
| knuth-bendix | 0.54 | 0.20 (2.7) | 0.65 (0.8) | 0.60 (0.9) |
| tyan | 0.33 | 0.26 (1.3) | 0.27 (1.2) | 0.26 (1.3) |
| lexgen | 0.13 | 0.09 (1.4) | 0.15 (0.9) | 0.19 (0.7) |
| mlyacc | 0.10 | 0.05 (2.0) | 0.10 (1.0) | 0.05 (2.0) |
| hamlet | 0.04 | 0.00 | 0.01 (4.0) | 0.00 |
| kitfib35 | 0.13 | 0.14 (0.9) | 0.15 (0.9) | 0.10 (1.3) |
| fib0 | 0.01 | 0.01 | 0.02 | 0.01 |
| kitreynolds2 | 0.16 | 0.08 (2.0) | 0.31 (0.5) | 0.16 (1.0) |
| kitreynolds3 | 0.07 | 0.02 (3.5) | 0.23 (0.3) | 0.12 (0.6) |
| kitloop2 | 0.00 | 0.00 | 0.01 | 0.00 |
| kitdangle | 0.02 | 0.00 | 0.02 (1.0) | 2.03 (0.0) |
| kitdangle3 | 0.05 | 0.00 | 0.05 (1.0) | 2.47 (0.0) |
| msort | 0.04 | 0.04 (1.0) | 0.04 (1.0) | 0.04 (1.0) |
| kittmergesort_tp | 0.93 | 0.70 (1.3) | 0.99 (0.9) | 0.83 (1.1) |
| barnes-hut | 0.30 | 0.09 (3.3) | n/a | 0.44 (0.7) |
| tsp | 0.01 | 0.00 | 0.02 | 0.01 |
| fannkuch | 0.00 | 0.00 | 0.02 | 0.00 |
| f-arith | 0.01 | 0.01 | 0.02 | 0.03 |
| stream-sieve | 0.03 | 0.02 (1.5) | 0.04 (0.8) | 0.03 (1.0) |
| simple | 0.33 | 0.18 (1.8) | 0.26 (1.3) | 0.38 (0.9) |
| twenty-four | 0.15 | 0.11 (1.4) | 0.17 (0.9) | 0.10 (1.5) |
| nbody | 0.81 | 0.51 (1.6) | 0.38 (2.1) | 2.67 (0.3) |
| output1 | 0.09 | 0.00 | 0.04 (2.2) | 0.03 (3.0) |
| ray | 0.21 | 0.04 (5.2) | 0.08 (2.6) | 0.15 (1.4) |
| raytrace | 1.49 | 0.66 (2.3) | 1.73 (0.9) | 1.94 (0.8) |
| vliw | 0.19 | 0.06 (3.2) | 0.12 (1.6) | 0.09 (2.1) |
| fxp | 0.21 | 0.11 (1.9) | 0.27 (0.8) | 0.39 (0.5) |
| model-elimination | 17.64 | 8.96 (2.0) | 20.77 (0.8) | 13.45 (1.3) |
| sat | 0.30 | 0.07 (4.3) | 0.19 (1.6) | 0.25 (1.2) |
| boyer-smlnj | 1.08 | 0.71 (1.5) | 1.47 (0.7) | 1.24 (0.9) |
| logic-smlnj | 18.67 | 13.60 (1.4) | 17.01 (1.1) | 16.16 (1.2) |
| life-smlnj | 5.06 | 0.86 (5.9) | 7.79 (0.6) | 0.73 (6.9) |
| minimax | 1.94 | 0.98 (2.0) | 4.64 (0.4) | 8.78 (0.2) |
| iter-pidigits | 0.01 | 0.00 | 0.02 | 0.00 |
| mazefun | 0.12 | 0.08 (1.5) | 0.22 (0.5) | 0.13 (0.9) |
| queens-lazy | 0.01 | 0.01 | 0.03 | 0.02 |
| queens-strict | 0.02 | 0.04 (0.5) | 0.03 (0.7) | 0.03 (0.7) |
| nqueens | 0.01 | 0.00 | 0.03 | 0.01 |
| rec_seq_ack | 0.01 | 0.01 | 0.03 | 0.02 |
| klife_eq | 0.19 | 0.03 (6.3) | 0.23 (0.8) | 0.04 (4.8) |
| kitlife35u_smlnj | 0.05 | 0.03 (1.7) | 0.06 (0.8) | 0.03 (1.7) |
| kitqsort_no_basislib | 0.02 | 0.01 (2.0) | 0.03 (0.7) | 0.03 (0.7) |
| tailfib-mlkit | 0.00 | 0.00 | 0.01 | 0.00 |
| tak-mlkit | 0.03 | 0.01 (3.0) | 0.06 (0.5) | 0.01 (3.0) |
| matrix-multiply-mlkit | 0.04 | 0.00 | 0.06 (0.7) | 0.03 (1.3) |
| vector-rev-mlkit | 0.01 | 0.00 | 0.04 | 0.01 |
| vector-rev_smlnj | 0.01 | 0.00 | 0.03 | 0.01 |
| vector-concat | 0.00 | 0.00 | 0.01 | 0.00 |
| vector-concat_smlnj | 0.01 | 0.00 | 0.03 | 0.01 |
| peek-mlkit | 0.00 | 0.00 | 0.02 | 0.01 |
| wc-input1-mlkit | 0.04 | 0.01 (4.0) | 0.05 (0.8) | 0.04 (1.0) |
| wc-scanStream-mlkit | 0.03 | 0.00 | 0.04 (0.8) | 0.02 (1.5) |
| psdes-random-mlkit | 0.01 | 0.00 | 0.02 | 0.01 |
| safe-for-space | 0.07 | 0.02 (3.5) | 0.15 (0.5) | 0.07 (1.0) |
| pidigits-smlnj | 0.02 | 0.00 | 0.02 (1.0) | 0.00 |
| fft-smlnj | 0.01 | 0.00 | 0.02 | 0.01 |
| nucleic-smlnj | 0.10 | 0.07 (1.4) | 0.05 (2.0) | 0.17 (0.6) |
| count-graphs-smlnj | 0.01 | 0.00 | 0.01 | 0.00 |
| matrix-multiply-ramp | 0.01 | 0.00 | 0.02 | 0.01 |
| kitreynolds2_no_basislib | 0.01 | 0.00 | 0.03 | 0.01 |
| kitreynolds3_no_basislib | 0.00 | 0.00 | 0.02 | 0.00 |
| kittmergesort_no_basislib | 0.02 | 0.02 (1.0) | 0.03 (0.7) | 0.02 (1.0) |
| hanoi | 0.00 | 0.00 | 0.01 | 0.00 |
| fib-mlkit | 0.00 | 0.00 | 0.01 | 0.00 |
| mandelbrot-smlnj | 0.03 | 0.02 (1.5) | 0.04 (0.8) | 0.08 (0.4) |
| mandelbrot-rat | 5.19 | 0.31 (17) | 3.13 (1.7) | 0.18 (29) |
| kitmandelbrot | 0.00 | 0.00 | 0.01 | 0.01 |
| FuhMishra | 0.02 | 0.01 (2.0) | 0.03 (0.7) | 0.01 (2.0) |
| black-scholes | 0.03 | 0.03 (1.0) | n/a | 0.04 (0.8) |
| professor2 | 0.05 | 0.04 (1.2) | 0.15 (0.3) | 0.04 (1.2) |
| professor2_tp | 0.05 | 0.03 (1.7) | 0.18 (0.3) | 0.05 (1.0) |
| professor_game | 0.05 | 0.03 (1.7) | 0.18 (0.3) | 0.06 (0.8) |
| professor_game-mlkit | 0.05 | 0.03 (1.7) | 0.19 (0.3) | 0.06 (0.8) |
| professor_game_debug | 0.00 | 0.00 | 0.01 | 0.00 |
| kkb_eq | 0.16 | 0.05 (3.2) | 0.13 (1.2) | 0.14 (1.1) |
| kitkbjul9_smlnj | 0.16 | 0.06 (2.7) | 0.14 (1.1) | 0.13 (1.2) |
| kkb36c_smlnj | 0.15 | 0.05 (3.0) | 0.15 (1.0) | 0.12 (1.2) |
| ratio-regions-mlkit | 0.02 | 0.01 (2.0) | 0.04 (0.5) | 0.01 (2.0) |
| ratio-regions_tp | 0.11 | 0.02 (5.5) | 0.16 (0.7) | 0.05 (2.2) |
| ratio-regions-smlnj | 0.03 | 0.01 (3.0) | 0.05 (0.6) | 0.02 (1.5) |
| count-graphs-mlkit | 0.01 | 0.00 | 0.01 | 0.01 |
| mpuz-mlkit | 0.74 | 0.31 (2.4) | 1.22 (0.6) | 0.56 (1.3) |
| knuth-bendix-smlnj | 0.17 | 0.07 (2.4) | 0.23 (0.7) | 0.19 (0.9) |
| tyan-smlnj | 0.45 | 0.35 (1.3) | 0.35 (1.3) | 0.35 (1.3) |
| tyan-mlkit | 0.28 | 0.21 (1.3) | 0.26 (1.1) | 0.22 (1.3) |
| smith-normal-form-mlkit | 0.01 | 0.00 | 0.01 | 0.00 |
| smith-nf | 0.00 | 0.00 | 0.01 | 0.00 |
| lexgen-smlnj | 0.09 | 0.07 (1.3) | 0.12 (0.8) | 0.16 (0.6) |
| mlyacc-smlnj | 0.09 | 0.03 (3.0) | 0.06 (1.5) | 0.04 (2.2) |
| kitsimple | 0.01 | 0.00 | 0.01 | 0.01 |
| kitsimple_tp | 0.03 | 0.01 (3.0) | 0.03 (1.0) | 0.02 (1.5) |
| kitsimple_no_basislib | 0.01 | 0.00 | 0.02 | 0.01 |
| simple-smlnj | 0.05 | 0.01 (5.0) | 0.03 (1.7) | 0.03 (1.7) |
| tsp-smlnj | 0.01 | 0.00 | n/a | 0.01 |
| DLXSimulator-mlkit | 0.10 | 0.05 (2.0) | 0.11 (0.9) | 0.04 (2.5) |
| aobench | 0.17 | 0.16 (1.1) | n/a | 0.05 (3.4) |
| id-ray | 1.11 | 0.34 (3.3) | n/a | n/a |
| plclub-ray | 0.06 | 0.02 (3.0) | 0.05 (1.2) | 0.06 (1.0) |
| mc-ray | 0.32 | 0.12 (2.7) | 0.12 (2.7) | 0.44 (0.7) |
| ray-smlnj | 0.04 | 0.00 | 0.02 (2.0) | 0.03 (1.3) |
| kitmolgard | 0.02 | 0.01 (2.0) | 0.05 (0.4) | 0.03 (0.7) |
| vliw-smlnj | 0.26 | 0.12 (2.2) | 0.24 (1.1) | 0.21 (1.2) |
| rfib | 0.01 | 0.00 | 0.02 | 0.01 |
| tak-nofib-strict | 0.00 | 0.00 | 0.01 | 0.00 |
| tak-nofib-lazy | 0.00 | 0.00 | 0.01 | 0.01 |
| exp3_8-lazy | 0.85 | 0.23 (3.7) | 0.84 (1.0) | 2.22 (0.4) |
| exp3_8-strict | 0.06 | 0.06 (1.0) | 0.09 (0.7) | 0.06 (1.0) |
| digits-of-e1-lazy | 0.12 | 0.06 (2.0) | 0.33 (0.4) | 0.06 (2.0) |
| digits-of-e2-lazy | 0.70 | 0.15 (4.7) | 0.93 (0.8) | 0.25 (2.8) |
| latency-ring | 0.92 | 0.94 (1.0) | 5.81 (0.2) | 2.51 (0.4) |
| latency-map | 1.61 | 1.52 (1.1) | 6.81 (0.2) | 3.76 (0.4) |
| latency-static-map | 0.77 | 0.96 (0.8) | 1.52 (0.5) | 0.99 (0.8) |

## Compiling

Each build of the compiler compiling `examples/hello.sml`, the signatures
of `tests/perf/compile-sigs.sml`, and itself (the bootstrap's input), every
build making the register bytecode: machine instructions of the run with
the least cycles of five (`bin/rune-measure perf-cycles`; `compile-hello`,
`compile-sigs` and `bootstrap`; a load of 8 to 12, so the cycles are a
quarter above a quiet machine's). The builds of the hosts are what `make
host-builds` makes; the others run the compiler's own bytecode,
`bin/rune.rbc` on `bin/runevm` at three JIT levels and `bin/rune.stack.rbc`
on `runevm-stack` and through `runeopt`.

| Build | `hello` | `compile-sigs` | the compiler | the compiler / MLton's build | the compiler, cycles (indication) |
|---|---:|---:|---:|---:|---:|
| Rune as shipped (tier 2) | 214M | 820M | 13.45G | 2.7 | 12.51G |
| `bin/runevm`, tier 1 | 204M | 852M | 17.18G | 3.4 | 16.56G |
| `bin/runevm`, the interpreter | 166M | 1.59G | 60.68G | 12.2 | 43.28G |
| `runevm-stack` | 174M | 1.84G | 71.14G | 14.2 | 50.06G |
| `runeopt`'s native code | 103M | 588M | 21.88G | 4.4 | 19.85G |
| MLton's build | 9.7M | 129M | 4.99G | 1.0 | 8.21G |
| Poly/ML's build | 8.8M | 94M | 5.70G | 1.1 | 8.84G |
| MLKit's build | 27M | 388M | 12.91G | 2.6 | 16.82G |
| SML/NJ 110.99.9, 64 bits | 25M | 471M | 21.06G | 4.2 | 20.61G |
| SML/NJ 110.99.9, 32 bits | 25M | 397M | 21.11G | 4.2 | 19.81G |
| SML/NJ 2026.2 | 25M | 384M | 19.39G | 3.9 | 20.64G |

* **The compiler on Rune as shipped executes 2.7 times the instructions of
  MLton's build** compiling itself, about as many as MLKit's build (2.6)
  and fewer than SML/NJ's (3.9 to 4.2), and takes 1.4 times its cycles
  alone (*Running programs*).
* **A small compile pays for starting the compiler and for the JIT:**
  `hello` is 214M instructions at tier 2 and 166M interpreted, against 9.7M
  on MLton's build; at tier 2, 0.03 s of its 0.07 s is `startup`, loading
  the compiler's bytecode and running its top-level declarations.
* **`runeopt`'s native code** takes the fewest instructions on the small
  compiles, and 1.6 times tier 2's on the compiler.

Where the compile of the compiler goes, by `--pass-stats`
(`bin/rune-measure perf-units`, the run of five with the least wall time; the stages add up to the
compile's processor time, [ir.md](ir.md); a load of 8 to 12). A
collection's time falls in the stage it happens in, so one stage of one
run can carry a major collection (`lift` and `emit` on Poly/ML's build
here):

| Stage | Rune as shipped | MLton's build | Poly/ML's build |
|---|---:|---:|---:|
| `startup` | 0.5% | 0.0% | 0.1% |
| `lex` | 3.1% | 3.5% | 2.9% |
| `select` | 0.9% | 2.0% | 2.7% |
| `parse` | 3.5% | 6.2% | 3.2% |
| `elaborate` | 11.8% | 8.4% | 8.2% |
| `translate` | 10.0% | 13.1% | 5.9% |
| `mid` | 5.1% | 3.3% | 3.9% |
| `midcanon` | 4.9% | 3.4% | 3.4% |
| `shake` | 3.7% | 2.5% | 2.5% |
| `lift` | 3.5% | 3.1% | 12.4% |
| `workers` | 4.1% | 2.8% | 1.8% |
| `simplify` | 15.2% | 19.6% | 10.2% |
| `refs` | 1.1% | 1.5% | 1.0% |
| `lower` | 14.1% | 12.8% | 10.6% |
| `registers` | 13.5% | 10.4% | 13.3% |
| `emit` | 3.1% | 3.8% | 15.6% |
| `stats` (the sizes `--pass-stats` counts) | 1.8% | 3.6% | 2.2% |
| the total, seconds (indication) | 4.23 | 3.02 | 3.57 |

### MLton's compiler compiled by Rune

MLton's compiler at `5fe943391` (606 files, 198,458 lines;
`scripts/setup-mlton.sh` makes them ready) compiled by Rune as shipped at tier 2 and by MLton's
build of the same compiler, with `--type-work=1000000000 --pass-stats`,
once each (a load of 7 to 11):

| | Rune as shipped | MLton's build | Rune / MLton's build |
|---|---:|---:|---:|
| the whole program: processor time | 84.0 s | 60.4 s | 1.39 |
| ... of it elaboration | 71.3 s | 49.0 s | 1.45 |
| ... instructions | 303.6G | 117.5G | 2.58 |
| ... the largest resident set | 5.9 GB | 6.7 GB | |
| in units (`--units --no-cache`): processor time | 433 s | | |
| ... of it the units' interfaces (`unit-usages`, `unit-export`, `unit-load`, `link`) | 367 s | | |
| ... of it elaboration | 56 s | | |
| type-checked in units (`--typecheck-only`), instructions | | 93.7G | |

* **Elaboration is 81 to 85% of the whole compile** on both; the passes
  after it take 0.1 to 2.9 s each at tier 2.
* **In units the compile is the units' interfaces:** recording what each
  unit uses of the others' bases (174 s) and exporting its own (148 s)
  take three quarters of it, most of that hashing the text of signatures'
  and functors' fingerprints, elaboration 13%
  ([plans/incremental-compilation.md](plans/incremental-compilation.md),
  *After M12: what is left*).
* **MLton built by Rune** (the whole compile's output, run by `runevm`)
  against MLton 20241230 built by MLton, compiling MLton's benchmark
  programs and MLton itself: the whole compile in processor time,
  assembler and linker included, once each (a load of 7 to 10, MLton
  itself at 3 to 6). Building MLton takes 7.1 times the instructions
  (7,798G against 1,104G) and 8.9 GB at its largest against 8.3 GB.

| Program compiled | MLton built by Rune | MLton built by MLton | Ratio |
|---|---:|---:|---:|
| `boyer` | 15.6 s | 5.6 s | 2.8 |
| `barnes-hut` | 14.7 s | 5.8 s | 2.5 |
| `nucleic` | 14.2 s | 5.1 s | 2.8 |
| `model-elimination` | 43.4 s | 14.1 s | 3.1 |
| `mlyacc` | 53.1 s | 17.5 s | 3.0 |
| `hamlet` | 73.9 s | 19.9 s | 3.7 |
| MLton itself (`mlton.mlb`) | 1,952 s | 427 s | 4.6 |

### The counts

What does not depend on the machine is held by `make perf-check` to
budgets 10% above it (`tests/perf/*.budget`, on Rune as shipped;
`tests/perf/stack`, on `runevm-stack`). At this commit the bootstrap
executes 1,305 million bytecode instructions on `bin/runevm` (2,142
million on `runevm-stack`) and allocates 1.55 GB in 57.9 million objects
(1.29 GB in 47.4 million on `runevm-stack`); compiling `hello` takes 1.95
million instructions, 2.4 MB and 57 thousand objects. The compiler on the
programs that scale the module language, type-checked only or compiled
(`compile-*.budget`): the sharing of 200 specifications 16 ways takes 22.2
million instructions, the same nested 20.5 million, a chain of 400 `where
type` 15.8 million, a signature of 2,000 specifications 26.6 million, a
functor applied 80 times 49.6 million, nested functors 141 million, and
`exponential.sml` at 20 applications 2.39 million.

## HOL4

HOL4 `3d15b18a8` built by Rune as shipped (`bin/build -j 8`; its
`hol.state` in 1,054 s, on a loaded machine), against HOL4 `bdc6917ee`
built by Poly/ML 5.9.2: the same HOL but for the five commits that port it
to Rune.
The theories are rebuilt and the kernel's work run one at a time, at a
load of 2.1 to 2.5: the least of three rebuilds by HOL's clock, with that
run's cycles and instructions, and the least of five runs of the kernel's
work, its workloads each the least of the five by HOL's processor time.

| | Rune | Poly/ML | Ratio | Rune, instructions | Poly/ML, instructions | Ratio |
|---|---:|---:|---:|---:|---:|---:|
| theory `logroot`, HOL's clock | 6.8 s | 4.0 s | 1.7 | 35.4G | 14.2G | 2.5 |
| theory `mergesort` | 7.9 s | 4.9 s | 1.6 | 42.2G | 16.8G | 2.5 |
| the kernel's work, cycles | 18.77G | 8.78G | 2.14 | 39.21G | 11.12G | 3.5 |

| The kernel's work, processor time | Rune | Poly/ML | Ratio |
|---|---:|---:|---:|
| `EVAL ``FACT 60``` | 0.375 s | 0.204 s | 1.8 |
| `EVAL ``FACT 150``` | 4.39 s | 2.19 s | 2.0 |
| `PROVE_TAC`, 20 times | 0.073 s | 0.011 s | 6.6 |
| `SIMP_CONV arith_ss`, 200 times | 0.244 s | 0.085 s | 2.9 |
| `DECIDE`, 200 times | 0.290 s | 0.101 s | 2.9 |
| `Arbnum` multiplication, 200,000 times | 0.102 s | 0.011 s | 9.3 |

* **Rebuilding a theory** takes 1.6 to 1.7 times Poly/ML's time by HOL's
  own clock (from `new_theory` to `export_theory`), and 2.5 times its
  instructions.
* **The kernel's work** is 2.1 times Poly/ML's cycles in all, from 1.8
  times on `EVAL` to 6.6 times on `PROVE_TAC` and 9 on `Arbnum`'s
  multiplication (IntInf's, on GMP), and 3.5 times its instructions. Where the time goes is
  in *Where the time goes* above: three quarters the code.

## Measuring

Each table above is one command, from the repository's root, after `make
all bin/rune.stack.rbc bin/runedoc.stack.rbc` (and, for the hosts and
native code, `make hosts host-builds runeopt bin/runevm-native`). The
scripts say in their heads what they do; `docs/plans/performance.md`
(*Measuring*, *Where we ended*) says how its own numbers were taken.

| Table | Command |
|---|---|
| `tests/perf`, wall-clock time | `make perf PERF_CONFIGS=rune,rune:stack,rune:opt,hosts,xc1` (`tests/out/perf/wall.md`) |
| `tests/perf`, cycles against MLton and Poly/ML | `bin/rune-measure perf-cycles` |
| Rune's engines | `bin/rune-measure perf-cycles --runs 3 --configs rune,jit-baseline,jit-off,stack,opt` |
| Where the time goes | `bin/rune-measure perf-cycles --runs 1 --configs rune --profile rune bootstrap` (any program for `bootstrap`); for HOL4, `perf record` over `RUNEVM_OPTS=--jit-perf-map bin/rune-measure hol-kernel HOL`, then `perf script -F period,ip,sym,dso \| bin/rune-measure perf-groups` |
| MLton's benchmark set | `bin/rune-measure perf-cycles --mlton-bench DIR tests/perf/mlton-bench.txt`, DIR MLton's `benchmark/tests` |
| `examples/benchmarks` | `make bench BENCH_SAMPLES=3` (the report's directory is printed) |
| The compiler's builds | `bin/rune-measure perf-cycles --configs rune,jit-baseline,jit-off,stack,opt,mlton,polyml,mlkit,smlnj-legacy,smlnj32,smlnj-dev bootstrap` (and `compile-hello`, `compile-sigs`) |
| The compile by stage | `bin/rune-measure perf-units --configs tier2,interp,baseline,stack,mlton,polyml,mlkit,smlnj-legacy,smlnj32,smlnj-dev phases` |
| MLton's compiler compiled by Rune | `scripts/setup-mlton.sh DIR` once, then `bin/rune-measure perf-units --mlton DIR --configs tier2,mlton phases` |
| HOL4's theories | `bin/rune-measure hol-theory HOL logroot` (or `mergesort`, `string`, `toto`), HOL a built HOL4 tree, Poly/ML's or Rune's |
| HOL4's kernel | `bin/rune-measure hol-kernel HOL` |
| The counts | `make perf-check` (`tests/perf/run-perf.sh`), `make bench-count` |

**The conventions.**

* **Counts are the measurements; cycles and seconds are indications.** The
  instructions and allocation of `runevm --count` depend on the program
  and its input alone, and `instructions:u` repeats to within a few
  thousand in billions. Cycles and times vary by up to 40% on a busy
  machine: take the least of several runs, compare only numbers taken in
  one session, and pin a single-threaded run to a core of its own
  (`taskset -c N`), its second thread left free.
* **`rune` is Rune as shipped** in every timing target: `bin/rune`'s
  register bytecode on `bin/runevm`, tiering up to tier 2. The other
  engines are named: `rune:stack` and `stack` (the stack VM), `rune:opt`
  and `opt` (native code), `jit-off`, `jit-baseline`, `jit-all` and
  `jit-all+t2` (the JIT's levels, `RUNEVM_JIT` in a matrix run).
* **`--pass-stats`** times every stage of a compile; the stages add up to
  the process's processor time, which its last line gives (`total: ...`;
  [ir.md](ir.md)).
* **`bin/rune-measure perf-groups`** groups the samples of `perf record` by part
  of the runtime (`perf-cycles.sh --profile` uses it): the JIT's code by
  tier, the interpreter, the frames' walks, liveness and return barrier,
  the collector's minor and major work, allocation, the runtime's
  equality, strings and exceptions, the primitives, and the JIT compiling.
* **HOL4**: `hol-theory.py` rebuilds a theory with Holmake on a fresh copy
  of its directory, under `--out` (`tests/out/hol`), and prints HOL's own
  clock (`new_theory` to `export_theory`), perf's task-clock, cycles and
  instructions, and the largest resident set; `hol-kernel.sh` runs
  `scripts/hol-kernel.sml` in a restored `hol.state` and prints the
  processor time of each workload, measured inside HOL. Neither writes
  into the HOL tree: a Rune-built HOL gets a copy of its cache of units,
  and runs on `--vm` or `$RUNEVM` where given -- for a theory only where
  the HOL's `bin/buildheap` passes `$RUNEVM` and `$RUNEVM_OPTS` on, which
  the one `tools-rune/configure.sh` writes at `3d15b18a8` does not (it
  runs the VM it was configured with).

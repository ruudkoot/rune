# Performance

What Rune costs to run a program and to compile one, as it is shipped,
against the SML systems Rune is built with. Rune as shipped is the register
bytecode of `bin/rune` on `bin/runevm`, which tiers up to tier 2 of its JIT
([runtime/register/README.md](../runtime/register/README.md)), with values
of 8 bytes ([plans/heap-layout.md](plans/heap-layout.md)) and the
generational collector ([plans/garbage-collector-v2.md](plans/garbage-collector-v2.md)).
Why it costs what it does, and what is being done about it, is
[plans/performance.md](plans/performance.md): the compiler's own speed, and
the speed of the code it makes, with the experiments behind each number
there. How native code is made is in [native.md](native.md).

**When and how.** Measured on 2026-10-12, 01:30 to 04:45, with the compiler
and VMs of master `921af2cc` (branch `perf-m1`, whose changes are to the
tools that measure them, and to the Poly/ML build's initial heap), by the
commands of *Measuring* below, on a Xeon E5-1680 v3 (Haswell, 8 cores, 16
threads) under WSL2 with 31 GB.

**The machine was busy.** Other builds and test suites ran beside these
measurements, at a load average of 20 to 33 on its 16 threads. Each timed
run was pinned to a core (`taskset`), Poly/ML's collector threads with it,
but other processes ran on that core too. So the tables lead with what
holds under load:

* **counts**: machine instructions (`instructions:u` of `perf stat`) and
  the bytecode instructions and allocation of `runevm --count`, which
  repeat to within a few thousand in billions;
* **ratios** of Rune to MLton and to Poly/ML, measured in the same session;
* **seconds and cycles** only as indications. They are the least of
  several runs, and still above what the same runs took on a quieter
  machine on 2026-10-11 ([plans/performance.md](plans/performance.md),
  *Where we are*): the seconds by 1.5 to 2.5 times (`tak` 0.47 s against
  0.24, `model-elimination` 113 s against 43), the cycles by up to a third
  (`fib` 320M against 240M; the compiler compiling itself 12.8G against
  11.95G).

The roadmap's M10 times them again on a quiet machine.

## The configurations

| Configuration | What runs |
|---|---|
| `rune` | Rune as shipped: `bin/rune`'s register bytecode on `bin/runevm`, tiering up to tier 2 |
| `rune:stack` (`stack` in `perf-cycles.sh`) | the stack bytecode on `runevm-stack` ([bytecode.md](bytecode.md)) |
| `rune:opt` (`opt`) | the stack bytecode translated into x86-64 code by `runeopt` ([native.md](native.md)) |
| `native:HOST` (`mlton`, `polyml`, ...) | the program on the host's own Basis Library, compiled by the host |
| `xc1:HOST` | the program on Rune's Basis Library (`lib/basis`), compiled by the host ([basis-compat.md](basis-compat.md)); not timed again here (M10) |

The hosts are MLton 20241230, SML/NJ 110.99.9 (64 and 32 bits), SML/NJ
2026.2, Poly/ML 5.9.2 and MLKit 4.7.23 (`make hosts`). `rune:new`, the name
of the register VM before it was shipped, is `rune`. For the compiler
itself, `mlton`, `polyml` and the rest are the host's build of it
(`bin/rune-HOST`, `make host-builds`).

`bin/runevm` runs at a JIT level chosen by `--jit=MODE` and `--jit-tier=N`,
or by `RUNEVM_JIT` and `RUNEVM_JIT_TIER` where a runner starts it
([runtime/register/README.md](../runtime/register/README.md), Tier 1 and
Tier 2); `scripts/perf-cycles.sh` names them `jit-MODE`:

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
of cycles, of the run with the least cycles of five (`scripts/perf-cycles.sh`):

| Program | Rune, instructions | MLton | Poly/ML | Rune / MLton | Rune / Poly/ML | cycles: Rune / MLton | Rune / Poly/ML |
|---|---:|---:|---:|---:|---:|---:|---:|
| `array_sieve` | 266M | 55M | 54M | 4.8 | 5.0 | 3.0 | 2.4 |
| `fib` | 620M | 128M | 112M | 4.9 | 5.5 | 3.4 | 4.7 |
| `intinf_fact` | 281M | 0.9M | 4.8M | 312.6 | 58.6 | 176.8 | 40.8 |
| `list_ops` | 329M | 109M | 147M | 3.0 | 2.2 | 2.5 | 1.6 |
| `real_nbody` | 224M | 54M | 315M | 4.1 | 0.7 | 1.0 | 0.5 |
| `string_ops` | 1.0G | 232M | 229M | 4.3 | 4.4 | 4.8 | 3.3 |
| `tak` | 177M | 45M | 47M | 3.9 | 3.7 | 3.4 | 3.2 |
| `word_bits` | 242M | 53M | 96M | 4.5 | 2.5 | 4.2 | 2.4 |
| `compile-sigs` | 1.2G | 184M | 120M | 6.5 | 10.0 | 4.2 | 4.4 |
| `runedoc-page` | 611M | 246M | 92M | 2.5 | 6.6 | 1.9 | 2.6 |
| `bootstrap` | 17.4G | 4.0G | 3.7G | 4.3 | 4.7 | 2.0 | 2.1 |

* **Programs of calls are four to five times MLton's instructions** (`fib`,
  `tak`, `array_sieve`, `word_bits`), and three to five times its cycles;
  [plans/performance.md](plans/performance.md), *The call*, has where the
  instructions go.
* **`real_nbody` runs as fast as MLton's code** in cycles, with four times
  its instructions, hidden behind the latency of `sqrt` and division, and
  faster than Poly/ML's.
* **`intinf_fact` is IntInf**, 313 times MLton's instructions and 59 times
  Poly/ML's: [plans/gmp.md](plans/gmp.md).
* **The compiler compiling itself** is 4.3 times the instructions of
  MLton's build and 4.7 times Poly/ML's. Poly/ML's build is now level with
  MLton's: its heap starts at 1 GB ([plans/performance.md](plans/performance.md),
  *Where we are*, Poly/ML's slowdown).

### Rune's engines

The same programs on the JIT's levels, on `runevm-stack` and as native code
(`runeopt`): instructions, then cycles, each with its ratio to tier 2
(`scripts/perf-cycles.sh --runs 3`).

| Program | tier 2 (default) | tier 1 | interpreter | runevm-stack | runeopt |
|---|---:|---:|---:|---:|---:|
| `array_sieve` | 266M | 335M (1.3) | 1.2G (4.5) | 1.6G (6.0) | 333M (1.3) |
| `fib` | 620M | 673M (1.1) | 2.3G (3.7) | 2.4G (3.9) | 604M (1.0) |
| `intinf_fact` | 281M | 329M (1.2) | 1.2G (4.3) | 1.5G (5.3) | 319M (1.1) |
| `list_ops` | 329M | 371M (1.1) | 979M (3.0) | 1.2G (3.6) | 352M (1.1) |
| `real_nbody` | 224M | 844M (3.8) | 2.4G (10.7) | 3.5G (15.6) | 969M (4.3) |
| `string_ops` | 1.0G | 1.1G (1.1) | 2.0G (2.0) | 2.0G (2.0) | 929M (0.9) |
| `tak` | 177M | 185M (1.0) | 606M (3.4) | 710M (4.0) | 167M (0.9) |
| `word_bits` | 242M | 354M (1.5) | 1.6G (6.6) | 2.3G (9.5) | 389M (1.6) |
| `compile-sigs` | 1.2G | 1.3G (1.1) | 2.3G (1.9) | 2.7G (2.2) | 868M (0.7) |
| `runedoc-page` | 611M | 665M (1.1) | 1.5G (2.5) | 1.8G (2.9) | 553M (0.9) |
| `bootstrap` | 17.4G | 19.3G (1.1) | 49.2G (2.8) | 57.9G (3.3) | 18.8G (1.1) |

| Program | cycles: tier 2 | tier 1 | interpreter | runevm-stack | runeopt |
|---|---:|---:|---:|---:|---:|
| `array_sieve` | 125M | 165M (1.3) | 554M (4.4) | 673M (5.4) | 177M (1.4) |
| `fib` | 279M | 260M (0.9) | 896M (3.2) | 1.1G (3.9) | 321M (1.2) |
| `intinf_fact` | 186M | 231M (1.2) | 452M (2.4) | 692M (3.7) | 252M (1.4) |
| `list_ops` | 191M | 180M (0.9) | 392M (2.1) | 448M (2.4) | 197M (1.0) |
| `real_nbody` | 179M | 409M (2.3) | 914M (5.1) | 1.5G (8.4) | 474M (2.6) |
| `string_ops` | 399M | 468M (1.2) | 882M (2.2) | 872M (2.2) | 484M (1.2) |
| `tak` | 83M | 83M (1.0) | 277M (3.3) | 325M (3.9) | 96M (1.2) |
| `word_bits` | 85M | 160M (1.9) | 722M (8.5) | 1.3G (15.3) | 221M (2.6) |
| `compile-sigs` | 1.2G | 1.3G (1.1) | 1.8G (1.5) | 2.1G (1.8) | 727M (0.6) |
| `runedoc-page` | 447M | 436M (1.0) | 863M (1.9) | 974M (2.2) | 382M (0.9) |
| `bootstrap` | 15.1G | 15.4G (1.0) | 29.3G (1.9) | 35.2G (2.3) | 15.4G (1.0) |

* **On code of calls and on the compiler, tier 2 and `runeopt`'s native
  code execute about as many instructions**: 0.7 to 1.1 times tier 2's for
  `runeopt` (`fib`, `tak`, `string_ops`, `compile-sigs`, the bootstrap),
  and tier 1 1.0 to 1.3 times.
* **On numbers tier 2 executes far fewer**: `real_nbody` 3.8 times fewer
  instructions than tier 1 and 4.3 times fewer than `runeopt`, `word_bits`
  1.5 and 1.6 times.
* **The interpreter** executes 2.0 (`string_ops`) to 10.7 (`real_nbody`)
  times tier 2's instructions, and `runevm-stack` as many or more.

### Wall-clock time (`make perf`)

Milliseconds of one run of each program of `tests/perf` (`make perf`): the
program run R times in a row (the `wall R` line of its `.budget`) in three
rounds, the fastest round counting, and the least of three such passes;
the SML systems compile it before the timer starts. In parentheses: Rune's
time divided by the configuration's. These are the seconds of a busy
machine (*When and how*): `string_ops` on Rune took 10.8 ms here, with
about the cycles it had on 2026-10-11 (399M against 367M, of its 40 runs);
read the cycles and instructions above first. Rune's library compiled by
the hosts (`xc1`) was not timed again (M10).

| Program | rune | rune:stack | rune:opt | mlton | smlnj-legacy | smlnj32 | smlnj-dev | polyml | mlkit |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `array_sieve` | 2.08 | 9.09 (0.2) | 2.64 (0.8) | 0.44 (4.7) | 1.17 (1.8) | 0.86 (2.4) | 0.80 (2.6) | 0.60 (3.5) | 0.78 (2.7) |
| `fib` | 1.74 | 6.39 (0.3) | 2.32 (0.8) | 0.50 (3.5) | 0.40 (4.3) | 0.41 (4.2) | 0.43 (4.0) | 0.32 (5.4) | 1.46 (1.2) |
| `intinf_fact` | 17.68 | 48.25 (0.4) | 27.82 (0.6) | 0.04 (442) | 0.25 (71) | 0.52 (34) | 0.19 (93) | 0.08 (221) | 2.75 (6.4) |
| `list_ops` | 2.60 | 5.75 (0.5) | 3.93 (0.7) | 1.60 (1.6) | 1.82 (1.4) | 1.57 (1.7) | 1.14 (2.3) | 1.47 (1.8) | 1.47 (1.8) |
| `real_nbody` | 0.57 | 3.43 (0.2) | 2.38 (0.2) | 0.56 (1.0) | 0.51 (1.1) | 0.50 (1.1) | 0.50 (1.1) | 1.07 (0.5) | 1.83 (0.3) |
| `string_ops` | 10.83 | 10.43 (1.0) | 10.24 (1.1) | 1.57 (6.9) | 2.42 (4.5) | 2.16 (5.0) | 1.60 (6.8) | 2.00 (5.4) | 3.92 (2.8) |
| `tak` | 0.76 | 2.25 (0.3) | 0.91 (0.8) | 0.15 (5.1) | 0.26 (2.9) | 0.28 (2.7) | 0.23 (3.3) | 0.14 (5.4) | 0.51 (1.5) |
| `word_bits` | 0.62 | 4.85 (0.1) | 1.34 (0.5) | 0.12 (5.2) | 0.27 (2.3) | 0.27 (2.3) | 0.13 (4.8) | 0.15 (4.1) | 0.32 (1.9) |

### Where the time goes

The compiler compiling itself (`bootstrap`) on Rune as shipped, by part of
the runtime: samples of `perf record -e cycles:u` over `runevm
--jit-perf-map`, grouped by `scripts/perf-groups.awk`.

| Part | Share of the samples |
|---|---:|
| the JIT's code, tier 2 | 67.1% |
| the collector: minor collections (`minor_pass`, `promote_*`, the cards) | 13.4% |
| the collector: the old generation (marking, Immix's lines, segregated fits, the large objects) | 10.0% |
| the JIT compiling | 2.3% |
| string order and equality in the runtime | 2.4% |
| `memcpy` and `memmove` (not the collector's) | 1.2% |
| the C library's `malloc` and `printf` (the JIT compiler's, and the perf map) | 1.1% |
| allocation outside the code (slow paths) | 0.8% |
| the interpreter | 0.7% |
| the primitives | 0.5% |
| the rest | 0.6% |

So two thirds of the compiler's time is the code tier 2 makes, and a
quarter the collector. Within the code, half the instructions are calls
and returns: [plans/performance.md](plans/performance.md), *Track B*, has
the call's cost by role, and the plan for it (M6 and M9). A program of
small arithmetic is the code alone: `fib` is 99.2% `jit2:fib`.

## The benchmark suite

The 152 programs of [`examples/benchmarks`](../examples/benchmarks/README.md)
at the normal input (`make bench BENCH_SAMPLES=3`): the median of three
fresh processes, in seconds by GNU time to the hundredth, startup included
and compilation not. Rune compiles at `-O2`; the hosts at their defaults.
In parentheses: Rune's time divided by the host's, where Rune took at least
0.02 s. The seconds are indications (*When and how*, above): on 2026-10-11
the same runs on Rune took a third to two thirds of these. The ratios are
measured in the same session.

* **Against MLton**, the 86 programs of at least 0.10 s on Rune take 515.5
  s against 78.5 s, 6.6 times; without `mandelbrot-rat` (IntInf) and `mpuz`,
  84 programs, 361.7 s against 72.7 s, 5.0 times. The geometric mean of
  the ratios is 5.1 (median 4.2, the 82 programs of at least 0.05 s on Rune
  and 0.02 s on MLton). On 2026-10-11, at the same commit, it was 5.2
  ([plans/performance.md](plans/performance.md), E3).
* **Against Poly/ML** the geometric mean is 2.6 (median 2.7, 97 programs),
  and against SML/NJ 110.99.9 2.2 (median 2.0, 102 programs).
* **The farthest from MLton:** `mandelbrot-rat` 289 and `digits-of-e1-lazy`
  23, both IntInf ([plans/gmp.md](plans/gmp.md)); `flat-array` 54,
  `knuth-bendix-smlnj` 24, `ratio-regions_tp` 20, `zebra` 19, `life-smlnj`
  19, `peek` 18. [plans/performance.md](plans/performance.md), *The Basis's
  own code* and *Allocation*, has what is known of them.
* **The closest:** the latency workloads, which measure the collector
  (`latency-static-map` 0.5, `latency-ring` 0.9), `queens-strict` 1.2,
  `black-scholes` 1.3, `msort` 1.6, `kittmergesort` 1.7.
* **Not timed:** on SML/NJ 110.99.9 `aobench`, `barnes-hut`,
  `black-scholes` and `tsp-smlnj`, which fail their checks, and `id-ray`,
  which reads its input while it is elaborated; on Poly/ML `id-ray`, and
  `peek` and `vector64-concat`, which use `Int64`.

| Program | Rune | MLton | SML/NJ 110.99.9 | Poly/ML |
|---|---:|---:|---:|---:|
| tak | 0.47 | 0.08 (5.9) | 0.17 (2.8) | 0.09 (5.2) |
| kittmergesort | 0.10 | 0.06 (1.7) | 0.07 (1.4) | 0.05 (2.0) |
| primes-lazy | 0.09 | 0.01 (9.0) | 0.08 (1.1) | 0.06 (1.5) |
| primes-strict | 0.80 | 0.36 (2.2) | 0.40 (2.0) | 0.27 (3.0) |
| bdd | 0.11 | 0.02 (5.5) | 0.07 (1.6) | 0.03 (3.7) |
| fib | 0.03 | 0.01 (3.0) | 0.02 (1.5) | 0.01 (3.0) |
| tailfib | 0.00 | 0.00 | 0.01 | 0.00 |
| even-odd | 0.00 | 0.00 | 0.02 | 0.00 |
| merge | 0.05 | 0.01 (5.0) | 0.04 (1.2) | 0.01 (5.0) |
| tailmerge | 0.05 | 0.01 (5.0) | 0.03 (1.7) | 0.01 (5.0) |
| imp-for | 0.01 | 0.00 | 0.02 | 0.01 |
| vector-rev | 0.05 | 0.00 | 0.03 (1.7) | 0.00 |
| vector32-concat | 0.01 | 0.00 | 0.02 | 0.00 |
| vector64-concat | 0.01 | 0.00 | 0.02 | n/a |
| string-concat | 0.00 | 0.00 | 0.02 | 0.00 |
| wc-input1 | 0.10 | 0.04 (2.5) | 0.10 (1.0) | 0.18 (0.6) |
| wc-scanStream | 0.13 | 0.01 (13) | 0.06 (2.2) | 0.05 (2.6) |
| checksum | 0.34 | 0.01 (34) | 0.09 (3.8) | 0.06 (5.7) |
| boyer | 0.26 | 0.08 (3.2) | 0.14 (1.9) | 0.16 (1.6) |
| nucleic | 0.20 | 0.05 (4.0) | 0.08 (2.5) | 0.14 (1.4) |
| life | 0.33 | 0.02 (16) | 0.22 (1.5) | 0.03 (11) |
| matrix-multiply | 0.01 | 0.00 | 0.02 | 0.00 |
| md5 | 0.02 | 0.00 | 0.02 (1.0) | 0.00 |
| fft | 0.03 | 0.00 | 0.03 (1.0) | 0.02 (1.5) |
| binary-trees | 0.03 | 0.01 (3.0) | 0.03 (1.0) | 0.01 (3.0) |
| flat-array | 1.08 | 0.02 (54) | 1.10 (1.0) | 0.84 (1.3) |
| peek | 5.72 | 0.32 (18) | 1.09 (5.2) | n/a |
| psdes-random | 0.20 | 0.01 (20) | 0.11 (1.8) | 0.04 (5.0) |
| mandelbrot | 0.04 | 0.01 (4.0) | 0.03 (1.3) | 0.06 (0.7) |
| pidigits | 6.91 | 0.01 (691) | 0.06 (115) | 0.01 (691) |
| logic | 7.96 | 1.97 (4.0) | 2.67 (3.0) | 2.48 (3.2) |
| zebra | 1.14 | 0.06 (19) | 0.77 (1.5) | 0.13 (8.8) |
| count-graphs | 0.10 | 0.01 (10) | 0.03 (3.3) | 0.02 (5.0) |
| many_refs | 0.69 | 0.04 (17) | 0.40 (1.7) | 0.19 (3.6) |
| tensor | 1.11 | 0.08 (14) | 0.52 (2.1) | 0.98 (1.1) |
| zern | 0.05 | 0.02 (2.5) | 0.06 (0.8) | 0.05 (1.0) |
| smith-normal-form | 0.02 | 0.00 | 0.05 (0.4) | 0.01 (2.0) |
| ratio-regions | 0.16 | 0.06 (2.7) | 0.14 (1.1) | 0.03 (5.3) |
| mpuz | 58.56 | 5.43 (11) | 20.67 (2.8) | 8.44 (6.9) |
| DLXSimulator | 88.34 | 15.01 (5.9) | 63.14 (1.4) | 16.26 (5.4) |
| knuth-bendix | 2.88 | 0.31 (9.3) | 0.93 (3.1) | 0.89 (3.2) |
| tyan | 1.02 | 0.34 (3.0) | 0.41 (2.5) | 0.37 (2.8) |
| lexgen | 0.42 | 0.14 (3.0) | 0.24 (1.8) | 0.30 (1.4) |
| mlyacc | 0.25 | 0.11 (2.3) | 0.14 (1.8) | 0.09 (2.8) |
| hamlet | 0.08 | 0.00 | 0.03 (2.7) | 0.03 (2.7) |
| kitfib35 | 1.04 | 0.26 (4.0) | 0.33 (3.2) | 0.17 (6.1) |
| fib0 | 0.05 | 0.01 (5.0) | 0.04 (1.2) | 0.02 (2.5) |
| kitreynolds2 | 0.41 | 0.09 (4.6) | 0.44 (0.9) | 0.20 (2.0) |
| kitreynolds3 | 0.21 | 0.04 (5.2) | 0.37 (0.6) | 0.13 (1.6) |
| kitloop2 | 0.00 | 0.00 | 0.02 | 0.01 |
| kitdangle | 0.05 | 0.01 (5.0) | 0.04 (1.2) | 2.94 (0.0) |
| kitdangle3 | 0.22 | 0.01 (22) | 0.09 (2.4) | 3.48 (0.1) |
| msort | 0.08 | 0.05 (1.6) | 0.06 (1.3) | 0.06 (1.3) |
| kittmergesort_tp | 2.09 | 0.81 (2.6) | 1.37 (1.5) | 0.99 (2.1) |
| barnes-hut | 0.92 | 0.16 (5.8) | n/a | 0.65 (1.4) |
| tsp | 0.03 | 0.01 (3.0) | 0.03 (1.0) | 0.01 (3.0) |
| fannkuch | 0.01 | 0.00 | 0.02 | 0.01 |
| f-arith | 0.01 | 0.01 | 0.03 | 0.04 |
| stream-sieve | 0.07 | 0.03 (2.3) | 0.05 (1.4) | 0.05 (1.4) |
| simple | 0.99 | 0.30 (3.3) | 0.40 (2.5) | 0.73 (1.4) |
| twenty-four | 0.51 | 0.12 (4.2) | 0.23 (2.2) | 0.14 (3.6) |
| nbody | 2.53 | 0.61 (4.1) | 0.50 (5.1) | 3.77 (0.7) |
| output1 | 0.34 | 0.01 (34) | 0.08 (4.2) | 0.04 (8.5) |
| ray | 0.55 | 0.06 (9.2) | 0.14 (3.9) | 0.23 (2.4) |
| raytrace | 4.01 | 0.81 (5.0) | 3.31 (1.2) | 3.03 (1.3) |
| vliw | 0.46 | 0.09 (5.1) | 0.17 (2.7) | 0.12 (3.8) |
| fxp | 0.56 | 0.15 (3.7) | 0.30 (1.9) | 0.59 (0.9) |
| model-elimination | 112.53 | 23.13 (4.9) | 17.02 (6.6) | 14.44 (7.8) |
| sat | 0.68 | 0.09 (7.6) | 0.24 (2.8) | 0.28 (2.4) |
| boyer-smlnj | 3.46 | 0.78 (4.4) | 1.62 (2.1) | 1.30 (2.7) |
| logic-smlnj | 39.05 | 11.60 (3.4) | 12.77 (3.1) | 12.14 (3.2) |
| life-smlnj | 14.69 | 0.78 (19) | 6.10 (2.4) | 0.64 (23) |
| minimax | 5.15 | 1.21 (4.3) | 3.92 (1.3) | 8.30 (0.6) |
| iter-pidigits | 3.22 | 0.00 | 0.02 (161) | 0.00 |
| mazefun | 0.45 | 0.07 (6.4) | 0.21 (2.1) | 0.09 (5.0) |
| queens-lazy | 0.03 | 0.01 (3.0) | 0.03 (1.0) | 0.01 (3.0) |
| queens-strict | 0.05 | 0.04 (1.2) | 0.04 (1.2) | 0.03 (1.7) |
| nqueens | 0.02 | 0.00 | 0.02 (1.0) | 0.01 (2.0) |
| rec_seq_ack | 0.05 | 0.02 (2.5) | 0.07 (0.7) | 0.06 (0.8) |
| klife_eq | 0.32 | 0.08 (4.0) | 0.51 (0.6) | 0.08 (4.0) |
| kitlife35u_smlnj | 0.51 | 0.04 (13) | 0.09 (5.7) | 0.04 (13) |
| kitqsort_no_basislib | 0.04 | 0.03 (1.3) | 0.05 (0.8) | 0.05 (0.8) |
| tailfib-mlkit | 0.00 | 0.00 | 0.02 | 0.00 |
| tak-mlkit | 0.09 | 0.03 (3.0) | 0.07 (1.3) | 0.05 (1.8) |
| matrix-multiply-mlkit | 0.21 | 0.01 (21) | 0.09 (2.3) | 0.04 (5.2) |
| vector-rev-mlkit | 0.05 | 0.00 | 0.05 (1.0) | 0.01 (5.0) |
| vector-rev_smlnj | 0.04 | 0.00 | 0.06 (0.7) | 0.01 (4.0) |
| vector-concat | 0.03 | 0.01 (3.0) | 0.02 (1.5) | 0.01 (3.0) |
| vector-concat_smlnj | 0.18 | 0.01 (18) | 0.06 (3.0) | 0.02 (9.0) |
| peek-mlkit | 0.02 | 0.00 | 0.06 (0.3) | 0.02 (1.0) |
| wc-input1-mlkit | 0.16 | 0.01 (16) | 0.05 (3.2) | 0.05 (3.2) |
| wc-scanStream-mlkit | 0.18 | 0.01 (18) | 0.10 (1.8) | 0.04 (4.5) |
| psdes-random-mlkit | 0.02 | 0.00 | 0.02 (1.0) | 0.01 (2.0) |
| safe-for-space | 0.13 | 0.02 (6.5) | 0.11 (1.2) | 0.07 (1.9) |
| pidigits-smlnj | 3.16 | 0.00 | 0.02 (158) | 0.00 |
| fft-smlnj | 0.00 | 0.00 | 0.02 | 0.01 |
| nucleic-smlnj | 0.20 | 0.09 (2.2) | 0.07 (2.9) | 0.51 (0.4) |
| count-graphs-smlnj | 0.04 | 0.00 | 0.02 (2.0) | 0.00 |
| matrix-multiply-ramp | 0.02 | 0.00 | 0.02 (1.0) | 0.01 (2.0) |
| kitreynolds2_no_basislib | 0.02 | 0.00 | 0.03 (0.7) | 0.02 (1.0) |
| kitreynolds3_no_basislib | 0.01 | 0.00 | 0.01 | 0.00 |
| kittmergesort_no_basislib | 0.03 | 0.02 (1.5) | 0.03 (1.0) | 0.02 (1.5) |
| hanoi | 0.00 | 0.00 | 0.02 | 0.00 |
| fib-mlkit | 0.00 | 0.00 | 0.01 | 0.00 |
| mandelbrot-smlnj | 0.04 | 0.02 (2.0) | 0.04 (1.0) | 0.07 (0.6) |
| mandelbrot-rat | 95.31 | 0.33 (289) | 3.24 (29) | 0.34 (280) |
| kitmandelbrot | 0.01 | 0.00 | 0.02 | 0.01 |
| FuhMishra | 0.04 | 0.01 (4.0) | 0.04 (1.0) | 0.02 (2.0) |
| black-scholes | 0.08 | 0.06 (1.3) | n/a | 0.11 (0.7) |
| professor2 | 0.20 | 0.06 (3.3) | 0.35 (0.6) | 0.15 (1.3) |
| professor2_tp | 0.34 | 0.07 (4.9) | 0.49 (0.7) | 0.16 (2.1) |
| professor_game | 0.25 | 0.06 (4.2) | 0.22 (1.1) | 0.06 (4.2) |
| professor_game-mlkit | 0.21 | 0.07 (3.0) | 0.86 (0.2) | 0.20 (1.0) |
| professor_game_debug | 0.01 | 0.00 | 0.03 | 0.03 |
| kkb_eq | 2.83 | 0.19 (15) | 0.30 (9.4) | 0.50 (5.7) |
| kitkbjul9_smlnj | 3.64 | 0.21 (17) | 0.31 (12) | 0.22 (17) |
| kkb36c_smlnj | 1.89 | 0.20 (9.4) | 0.47 (4.0) | 0.52 (3.6) |
| ratio-regions-mlkit | 0.36 | 0.04 (9.0) | 0.19 (1.9) | 0.05 (7.2) |
| ratio-regions_tp | 1.22 | 0.06 (20) | 0.83 (1.5) | 0.12 (10) |
| ratio-regions-smlnj | 0.12 | 0.01 (12) | 0.07 (1.7) | 0.03 (4.0) |
| count-graphs-mlkit | 0.03 | 0.00 | 0.03 (1.0) | 0.01 (3.0) |
| mpuz-mlkit | 5.20 | 0.50 (10) | 2.03 (2.6) | 2.35 (2.2) |
| knuth-bendix-smlnj | 2.19 | 0.09 (24) | 0.28 (7.8) | 0.25 (8.8) |
| tyan-smlnj | 1.38 | 0.40 (3.4) | 0.41 (3.4) | 0.41 (3.4) |
| tyan-mlkit | 0.68 | 0.29 (2.3) | 0.43 (1.6) | 0.29 (2.3) |
| smith-normal-form-mlkit | 0.01 | 0.00 | 0.02 | 0.00 |
| smith-nf | 0.01 | 0.00 | 0.01 | 0.01 |
| lexgen-smlnj | 0.46 | 0.12 (3.8) | 0.18 (2.6) | 0.24 (1.9) |
| mlyacc-smlnj | 0.22 | 0.08 (2.8) | 0.11 (2.0) | 0.05 (4.4) |
| kitsimple | 0.03 | 0.01 (3.0) | 0.03 (1.0) | 0.02 (1.5) |
| kitsimple_tp | 0.08 | 0.02 (4.0) | 0.04 (2.0) | 0.03 (2.7) |
| kitsimple_no_basislib | 0.04 | 0.01 (4.0) | 0.03 (1.3) | 0.01 (4.0) |
| simple-smlnj | 0.10 | 0.02 (5.0) | 0.04 (2.5) | 0.03 (3.3) |
| tsp-smlnj | 0.01 | 0.00 | n/a | 0.01 |
| DLXSimulator-mlkit | 0.14 | 0.06 (2.3) | 0.20 (0.7) | 0.06 (2.3) |
| aobench | 0.50 | 0.19 (2.6) | n/a | 0.08 (6.2) |
| id-ray | 10.29 | 1.10 (9.4) | n/a | n/a |
| plclub-ray | 0.17 | 0.02 (8.5) | 0.08 (2.1) | 0.08 (2.1) |
| mc-ray | 1.17 | 0.45 (2.6) | 0.41 (2.9) | 1.11 (1.1) |
| ray-smlnj | 0.11 | 0.00 | 0.03 (3.7) | 0.03 (3.7) |
| kitmolgard | 0.08 | 0.01 (8.0) | 0.06 (1.3) | 0.04 (2.0) |
| vliw-smlnj | 0.56 | 0.16 (3.5) | 0.34 (1.6) | 0.28 (2.0) |
| rfib | 0.02 | 0.00 | 0.02 (1.0) | 0.03 (0.7) |
| tak-nofib-strict | 0.00 | 0.00 | 0.02 | 0.00 |
| tak-nofib-lazy | 0.04 | 0.00 | 0.03 (1.3) | 0.01 (4.0) |
| exp3_8-lazy | 1.48 | 0.30 (4.9) | 1.27 (1.2) | 4.35 (0.3) |
| exp3_8-strict | 0.19 | 0.08 (2.4) | 0.12 (1.6) | 0.08 (2.4) |
| digits-of-e1-lazy | 1.59 | 0.07 (23) | 0.44 (3.6) | 0.08 (20) |
| digits-of-e2-lazy | 2.95 | 0.17 (17) | 1.43 (2.1) | 0.85 (3.5) |
| latency-ring | 2.90 | 3.08 (0.9) | 8.04 (0.4) | 4.33 (0.7) |
| latency-map | 3.85 | 1.83 (2.1) | 7.53 (0.5) | 6.16 (0.6) |
| latency-static-map | 1.02 | 2.05 (0.5) | 1.79 (0.6) | 1.11 (0.9) |

## Compiling

Each build of the compiler compiling `examples/hello.sml`, the signatures
of `tests/perf/compile-sigs.sml`, and itself (the bootstrap's input), every
build making the register bytecode: machine instructions of the run with
the least cycles of five (`scripts/perf-cycles.sh`; `compile-hello`,
`compile-sigs` and `bootstrap`). The builds of the hosts are what `make
host-builds` makes; the others run the compiler's own bytecode,
`bin/rune.rbc` on `bin/runevm` at three JIT levels and `bin/rune.stack.rbc`
on `runevm-stack` and through `runeopt`.

| Build | `hello` | `compile-sigs` | the compiler | the compiler / MLton's build | the compiler, cycles (indication) |
|---|---:|---:|---:|---:|---:|
| Rune as shipped (tier 2) | 198M | 1.21G | 17.37G | 4.6 | 12.81G |
| `bin/runevm`, tier 1 | 188M | 1.25G | 19.31G | 5.2 | 12.50G |
| `bin/runevm`, the interpreter | 148M | 2.35G | 49.21G | 13.2 | 25.83G |
| `runevm-stack` | 155M | 2.74G | 57.92G | 15.5 | 29.32G |
| `runeopt`'s native code | 84M | 868M | 18.81G | 5.0 | 13.09G |
| MLton's build | 8.9M | 183M | 3.74G | 1.0 | 4.75G |
| Poly/ML's build | 8.5M | 120M | 3.70G | 1.0 | 4.91G |
| MLKit's build | 24M | 601M | 10.75G | 2.9 | 11.16G |
| SML/NJ 110.99.9, 64 bits | 25M | 700M | 17.35G | 4.6 | 19.44G |
| SML/NJ 110.99.9, 32 bits | 24M | 622M | 18.38G | 4.9 | 16.07G |
| SML/NJ 2026.2 | 26M | 623M | 15.09G | 4.0 | 14.68G |

* **The compiler on Rune as shipped executes 4.6 times the instructions of
  MLton's build** compiling itself, as SML/NJ's builds do (4.0 to 4.9);
  MLKit's build 2.9 times. Poly/ML's build is level with MLton's since
  its heap starts at 1 GB.
* **A small compile pays for starting the compiler and for the JIT:**
  `hello` is 198M instructions at tier 2 and 148M interpreted, against 9M
  on MLton's build; at tier 2, 0.02 s of its 0.05 s is `startup`, loading
  the compiler's bytecode and running its top-level declarations.
* **`runeopt`'s native code** takes the fewest instructions on the small
  compiles, and 8% more than tier 2 on the compiler.

Where the compile of the compiler goes, by `--pass-stats` (`scripts/perf-units.sh`,
the run of five with the least wall time; the stages add up to the
compile's processor time, [ir.md](ir.md)). A collection's time falls in the
stage it happens in, so one stage of one run can carry a major collection
(`workers` on Poly/ML's build here):

| Stage | Rune as shipped | MLton's build | Poly/ML's build |
|---|---:|---:|---:|
| `startup` | 0.5% | 0.0% | 0.2% |
| `lex` | 2.5% | 3.8% | 2.6% |
| `select` | 2.0% | 1.9% | 3.4% |
| `parse` | 4.4% | 2.6% | 4.3% |
| `elaborate` | 13.8% | 14.4% | 10.6% |
| `translate` | 7.3% | 4.7% | 6.4% |
| `mid` | 6.6% | 9.8% | 4.2% |
| `midcanon` | 9.8% | 4.3% | 6.9% |
| `shake` | 2.5% | 2.4% | 2.5% |
| `lift` | 4.1% | 2.8% | 4.4% |
| `workers` | 5.2% | 2.4% | 21.5% |
| `simplify` | 15.1% | 20.4% | 8.8% |
| `lower` | 8.0% | 7.4% | 6.5% |
| `registers` | 14.0% | 14.3% | 9.2% |
| `emit` | 2.5% | 5.7% | 6.1% |
| `stats` (the sizes `--pass-stats` counts) | 1.7% | 3.1% | 2.2% |
| the total, seconds (indication) | 5.27 | 3.47 | 2.67 |

MLton's compiler, 606 files and 198,458 lines compiled by Rune, is timed
by `scripts/perf-units.sh --mlton` once `scripts/setup-mlton.sh` has made
its sources (*Measuring*); [plans/performance.md](plans/performance.md),
*Large programs*, has its last numbers (elaboration 795 s of 878 s at tier
2 on a busy machine, 2026-10-11), and its M2 and M3 are about them.

### The counts

What does not depend on the machine is held by `make perf-check` to
budgets 10% above it (`tests/perf/*.budget`, on Rune as shipped;
`tests/perf/stack`, on `runevm-stack`). At this commit the bootstrap
executes 1,031 million bytecode instructions on `bin/runevm` (1,623
million on `runevm-stack`) and allocates 1.47 GB in 56.1 million objects
(1.16 GB in 43.7 million on `runevm-stack`); compiling `hello` takes 1.96
million instructions, 2.5 MB and 68 thousand objects. The compiler on the
programs that scale the module language, type-checked only or compiled
(`compile-*.budget`), is in [plans/performance.md](plans/performance.md),
M1: the sharing of 200 specifications 16 ways takes 2,369 million
instructions, and is what M2 is to bring down.

## Measuring

Each table above is one command, from the repository's root, after `make
all bin/rune.stack.rbc` (and, for the hosts and native code, `make hosts
host-builds runeopt bin/runevm-native`). The scripts say in their heads
what they do; `docs/plans/performance.md` (*Measuring*) says how its own
numbers were taken.

| Table | Command |
|---|---|
| `tests/perf`, wall-clock time | `make perf PERF_CONFIGS=rune,rune:stack,rune:opt,hosts` (`tests/out/perf/wall.md`; `xc1` adds Rune's library on the hosts) |
| `tests/perf`, cycles against MLton and Poly/ML | `scripts/perf-cycles.sh` |
| Rune's engines | `scripts/perf-cycles.sh --runs 3 --configs rune,jit-baseline,jit-off,stack,opt` |
| Where the time goes | `scripts/perf-cycles.sh --runs 1 --configs rune --profile rune bootstrap` (any program for `bootstrap`) |
| MLton's benchmark set | `scripts/perf-cycles.sh --mlton-bench DIR tests/perf/mlton-bench.txt`, DIR MLton's `benchmark/tests` |
| `examples/benchmarks` | `make bench BENCH_SAMPLES=3` (the report's directory is printed) |
| The compiler's builds | `scripts/perf-cycles.sh --configs rune,jit-baseline,jit-off,stack,opt,mlton,polyml,mlkit,smlnj-legacy,smlnj32,smlnj-dev bootstrap` (and `compile-hello`, `compile-sigs`) |
| The compile by stage | `scripts/perf-units.sh --configs tier2,interp,baseline,stack,mlton,polyml,mlkit,smlnj-legacy,smlnj32,smlnj-dev phases` |
| MLton's compiler compiled by Rune | `scripts/setup-mlton.sh DIR` once, then `scripts/perf-units.sh --mlton DIR --configs tier2,mlton phases` |
| HOL4's theories | `scripts/hol-theory.py HOL logroot` (or `mergesort`, `string`, `toto`), HOL a built HOL4 tree, Poly/ML's or Rune's |
| HOL4's kernel | `scripts/hol-kernel.sh HOL` |
| The counts | `make perf-check` (`tests/perf/run-perf.sh`), `make bench-count` |

**The conventions.**

* **Counts are the measurements; cycles and seconds are indications.** The
  instructions and allocation of `runevm --count` depend on the program
  and its input alone, and `instructions:u` repeats to within a few
  thousand in billions. Cycles and times vary by up to 40% on a busy
  machine: take the least of several runs, compare only numbers taken in
  one session, and pin a single-threaded run to a core of its own
  (`taskset -c N`).
* **`rune` is Rune as shipped** in every timing target: `bin/rune`'s
  register bytecode on `bin/runevm`, tiering up to tier 2. The other
  engines are named: `rune:stack` and `stack` (the stack VM), `rune:opt`
  and `opt` (native code), `jit-off`, `jit-baseline`, `jit-all` and
  `jit-all+t2` (the JIT's levels, `RUNEVM_JIT` in a matrix run).
* **`--pass-stats`** times every stage of a compile; the stages add up to
  the process's processor time, which its last line gives (`total: ...`;
  [ir.md](ir.md)).
* **`scripts/perf-groups.awk`** groups the samples of `perf record` by part
  of the runtime (`perf-cycles.sh --profile` uses it): the JIT's code by
  tier, the interpreter, the collector's minor and major work, allocation,
  the runtime's equality, strings and exceptions, the primitives, and the
  JIT compiling.
* **HOL4**: `hol-theory.py` rebuilds a theory with Holmake on a fresh copy
  of its directory, under `--out` (`tests/out/hol`), and prints HOL's own
  clock (`new_theory` to `export_theory`), perf's task-clock, cycles and
  instructions, and the largest resident set; `hol-kernel.sh` runs
  `scripts/hol-kernel.sml` in a restored `hol.state` and prints the
  processor time of each workload, measured inside HOL. Neither writes
  into the HOL tree: a Rune-built HOL gets a copy of its cache of units,
  and runs on `--vm` or `$RUNEVM` where given.

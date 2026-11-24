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
*Where we ended* compares the October 2026 results with the compiler and VMs of
2026-10-11, and what it left is in the plans that take it. How native code
is made is in [native.md](native.md).

Measurements on 2026-11-23 used the compiler and VMs built from
master at `9c0999f9c713736d3ca1c7bd300a10383e54deee`.
The host was a Xeon E5-1680 v3 under WSL2 with 8 cores, 16 threads, and
31 GiB of RAM. The VM linked the system GMP 6.3.0. The single-threaded
measurement jobs ran serially on CPU 6. Repository validation and
the HOL4 builds ran on other cores during part of the session.

Hardware-counter tables use instructions and cycles from the same
sample. Wall and processor times vary with system load. Each table
describes its sampling rule. The run’s raw counters, sample timings,
commands, failures, and executable hashes are in
`tests/out/performance-master-refresh/` on the measurement machine.

## The configurations

| Configuration | What runs |
|---|---|
| `rune` | Rune as shipped: `bin/rune`'s register bytecode on `bin/runevm`, tiering up to tier 2 |
| `rune:stack` (`stack` in `perf-cycles`) | the stack bytecode on `runevm-stack` ([bytecode.md](bytecode.md)) |
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

Each benchmark runs the body of the test the number of times given by
its `wall` budget. The three compiler and `runedoc` workloads run once
per sample. Each cell uses the instructions and cycles from the
least-cycle sample of five in the same session. The hosts run their own
builds of the compiler and `runedoc` on those workloads.

| Program | Rune, instructions | MLton | Poly/ML | Instructions / MLton | Instructions / Poly/ML | Cycles / MLton | Cycles / Poly/ML |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `array_sieve` | 138.8M | 55.2M | 53.7M | 2.51 | 2.58 | 1.82 | 1.47 |
| `fib` | 196.6M | 127.8M | 112.3M | 1.54 | 1.75 | 1.14 | 1.24 |
| `hash_mod` | 561.4M | 233.6M | 341.1M | 2.40 | 1.65 | 1.18 | 0.40 |
| `intinf_fact` | 13.4M | 860.1k | 4.8M | 15.56 | 2.76 | 6.38 | 1.18 |
| `list_ops` | 254.7M | 108.6M | 149.4M | 2.35 | 1.71 | 1.92 | 1.20 |
| `real_nbody` | 175M | 54.5M | 319.7M | 3.21 | 0.55 | 0.97 | 0.54 |
| `string_ops` | 862.9M | 232.2M | 242.5M | 3.72 | 3.56 | 2.93 | 2.38 |
| `tak` | 62M | 44.8M | 47.4M | 1.38 | 1.31 | 1.20 | 1.04 |
| `word_bits` | 174.4M | 53.4M | 96M | 3.27 | 1.82 | 2.99 | 1.94 |
| `compile-sigs` | 972.2M | 175.6M | 119.3M | 5.54 | 8.15 | 3.88 | 4.62 |
| `runedoc-page` | 563.9M | 307.6M | 132.2M | 1.83 | 4.26 | 1.55 | 2.56 |
| `bootstrap` | 28.65G | 11.51G | 14.03G | 2.49 | 2.04 | 1.42 | 1.32 |

Rune compiling itself used 1.42 times the cycles and
2.49 times the instructions of MLton’s build. The ratios
to Poly/ML’s build were 1.32 for cycles and 2.04
for instructions.

### Rune's engines

Instructions and cycles from the least-cycle sample of three for each
configuration. The first table gives instructions and the second gives
cycles. Parentheses give the ratio to tier 2 for the same workload.

| Program | Tier 2 | Tier 1 | Interpreter | `runevm-stack` | `runeopt` |
| --- | ---: | ---: | ---: | ---: | ---: |
| `array_sieve` | 138.8M | 237.7M (1.7) | 1.04G (7.5) | 1.47G (10.6) | 271M (2.0) |
| `fib` | 196.6M | 339.1M (1.7) | 2.56G (13.0) | 2.51G (12.8) | 604.6M (3.1) |
| `hash_mod` | 561.4M | 897.8M (1.6) | 3.79G (6.7) | 5.53G (9.9) | 987.1M (1.8) |
| `intinf_fact` | 13.4M | 13.3M (1.0) | 13M (1.0) | 16.7M (1.3) | 8.7M (0.7) |
| `list_ops` | 254.7M | 324.1M (1.3) | 1.06G (4.2) | 1.18G (4.6) | 360.7M (1.4) |
| `real_nbody` | 175M | 810.7M (4.6) | 2.61G (14.9) | 3.5G (20.0) | 969M (5.5) |
| `string_ops` | 862.9M | 937.3M (1.1) | 2.03G (2.4) | 2.03G (2.4) | 949.7M (1.1) |
| `tak` | 62M | 98.8M (1.6) | 675.1M (10.9) | 726.5M (11.7) | 166.7M (2.7) |
| `word_bits` | 174.4M | 323.4M (1.9) | 1.73G (9.9) | 2.27G (13.0) | 388.5M (2.2) |
| `compile-sigs` | 972.2M | 986.2M (1.0) | 1.62G (1.7) | 1.8G (1.9) | 628.7M (0.6) |
| `runedoc-page` | 563.9M | 639.5M (1.1) | 1.55G (2.8) | 1.81G (3.2) | 561.1M (1.0) |
| `bootstrap` | 28.65G | 36.35G (1.3) | 129.69G (4.5) | 147.88G (5.2) | 46.29G (1.6) |

| Program | Tier 2 | Tier 1 | Interpreter | `runevm-stack` | `runeopt` |
| --- | ---: | ---: | ---: | ---: | ---: |
| `array_sieve` | 73.8M | 132.3M (1.8) | 505.1M (6.8) | 753M (10.2) | 164.2M (2.2) |
| `fib` | 80.5M | 191.1M (2.4) | 1.41G (17.5) | 1.37G (17.1) | 388.9M (4.8) |
| `hash_mod` | 273.4M | 1.03G (3.7) | 2.51G (9.2) | 3.73G (13.7) | 1.1G (4.0) |
| `intinf_fact` | 8.5M | 9.9M (1.2) | 7.4M (0.9) | 12.6M (1.5) | 6.8M (0.8) |
| `list_ops` | 149.8M | 235.6M (1.6) | 526.6M (3.5) | 617.6M (4.1) | 251.7M (1.7) |
| `real_nbody` | 184.7M | 469.1M (2.5) | 1.47G (8.0) | 2.07G (11.2) | 631.7M (3.4) |
| `string_ops` | 480.8M | 529.2M (1.1) | 1.05G (2.2) | 1.05G (2.2) | 578.1M (1.2) |
| `tak` | 27.6M | 49.4M (1.8) | 389.4M (14.1) | 413.2M (15.0) | 104.8M (3.8) |
| `word_bits` | 74.9M | 137.9M (1.8) | 757.5M (10.1) | 1.03G (13.8) | 212M (2.8) |
| `compile-sigs` | 838.4M | 911.2M (1.1) | 1.16G (1.4) | 1.26G (1.5) | 556.7M (0.7) |
| `runedoc-page` | 393.7M | 517.6M (1.3) | 1.01G (2.6) | 1.26G (3.2) | 471.6M (1.2) |
| `bootstrap` | 32.12G | 36.97G (1.2) | 97.19G (3.0) | 108.46G (3.4) | 43.51G (1.4) |

### Wall-clock time (`make perf`)

Milliseconds per execution of the test body. Each pass measures three
rounds of the repetitions in the `wall` budget. The table takes the
fastest round across three passes. Parentheses give Rune’s time divided
by the configuration’s time. The second table uses Rune’s Basis built
by each host. The 32-bit `xc1:smlnj32` configuration lacks the timer
used by the wrapper. The `xc1` builds exclude `intinf_fact` because the
hosts type its constants at their own IntInf type.

| Program | rune | rune:stack | rune:opt | mlton | smlnj-legacy | smlnj32 | smlnj-dev | polyml | mlkit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `array_sieve` | 0.89 | 9.64 (0.1) | 2.15 (0.4) | 0.53 (1.7) | 1.27 (0.7) | 0.93 (1.0) | 0.66 (1.3) | 0.57 (1.5) | 0.77 (1.2) |
| `fib` | 0.37 | 6.44 (0.1) | 1.76 (0.2) | 0.45 (0.8) | 0.48 (0.8) | 0.45 (0.8) | 0.43 (0.9) | 0.39 (0.9) | 1.56 (0.2) |
| `hash_mod` | 1.05 | 17.97 (0.1) | 5.95 (0.2) | 1.65 (0.6) | 3.68 (0.3) | 1.37 (0.8) | 1.10 (1.0) | 3.32 (0.3) | 5.40 (0.2) |
| `intinf_fact` | 0.49 | 0.63 (0.8) | 0.40 (1.2) | 0.03 (17.8) | 0.23 (2.1) | 0.43 (1.1) | 0.18 (2.7) | 0.08 (6.3) | 2.98 (0.2) |
| `list_ops` | 1.62 | 7.23 (0.2) | 3.49 (0.5) | 1.81 (0.9) | 1.94 (0.8) | 1.70 (1.0) | 1.23 (1.3) | 1.33 (1.2) | 1.47 (1.1) |
| `real_nbody` | 0.55 | 4.90 (0.1) | 1.42 (0.4) | 0.59 (0.9) | 0.50 (1.1) | 0.52 (1.1) | 0.50 (1.1) | 1.18 (0.5) | 1.87 (0.3) |
| `string_ops` | 6.16 | 13.77 (0.4) | 6.75 (0.9) | 1.91 (3.2) | 3.14 (2.0) | 2.82 (2.2) | 1.53 (4.0) | 2.23 (2.8) | 3.59 (1.7) |
| `tak` | 0.17 | 2.25 (0.1) | 0.71 (0.2) | 0.13 (1.3) | 0.25 (0.7) | 0.26 (0.6) | 0.23 (0.7) | 0.13 (1.2) | 0.49 (0.3) |
| `word_bits` | 0.29 | 5.12 (0.1) | 0.99 (0.3) | 0.10 (2.9) | 0.27 (1.1) | 0.26 (1.1) | 0.11 (2.6) | 0.17 (1.7) | 0.29 (1.0) |

| Program | rune | xc1:mlton | xc1:smlnj-legacy | xc1:smlnj32 | xc1:smlnj-dev | xc1:polyml | xc1:mlkit |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `array_sieve` | 0.89 | 0.54 (1.6) | 1.30 (0.7) | n/a | 0.63 (1.4) | 0.81 (1.1) | 0.83 (1.1) |
| `fib` | 0.37 | 0.41 (0.9) | 0.46 (0.8) | n/a | 0.40 (0.9) | 0.34 (1.1) | 1.68 (0.2) |
| `hash_mod` | 1.05 | 3.27 (0.3) | 3.74 (0.3) | n/a | 1.07 (1.0) | 3.62 (0.3) | 4.18 (0.3) |
| `intinf_fact` | 0.49 | n/a | n/a | n/a | n/a | n/a | n/a |
| `list_ops` | 1.62 | 1.24 (1.3) | 2.06 (0.8) | n/a | 1.41 (1.1) | 1.40 (1.2) | 1.84 (0.9) |
| `real_nbody` | 0.55 | 0.60 (0.9) | 0.50 (1.1) | n/a | 0.50 (1.1) | 1.21 (0.5) | 1.61 (0.3) |
| `string_ops` | 6.16 | 2.80 (2.2) | 4.53 (1.4) | n/a | 2.39 (2.6) | 3.40 (1.8) | 4.15 (1.5) |
| `tak` | 0.17 | 0.16 (1.1) | 0.25 (0.7) | n/a | 0.22 (0.8) | 0.14 (1.2) | 0.46 (0.4) |
| `word_bits` | 0.29 | 0.10 (3.0) | 0.30 (1.0) | n/a | 0.11 (2.7) | 0.16 (1.9) | 0.33 (0.9) |

### MLton's benchmark programs

The 38 published workloads from MLton’s `benchmark/tests` at
`b15e2d289`, with sizes from `tests/perf/mlton-bench.txt`. Cycles and
instructions come from the least-cycle sample of three.
`smith-normal-form` uses one sample at dimension 26 with the repository
fixture. Allocation comes from separate runs with `runevm --count`
and `@MLton gc-summary`. Poly/ML 5.9.2 lacks the `Int64` structure
required by `peek` and `vector64-concat`. The allocation column shows
MLton’s allocation directly for the two workloads with only a few
thousand native bytes.

Rune’s `pidigits` compile uses `--overloading=toplevel` for the
upstream program’s integer literals. Its output matched both hosts.

`model-elimination` uses CPU time to slice its search. Its traces
differed across hosts. Each configuration completed 14 proofs.

Across 38 paired workloads the geometric mean cycle ratio to MLton
was 3.74, with a median of 3.33.
Across 36 paired workloads the geometric mean cycle ratio to Poly/ML
was 1.51, with a median of 1.39.

| Program | Rune cycles | Rune / MLton cycles | Rune / MLton instructions | Rune / Poly/ML cycles | Rune / MLton bytes |
| --- | ---: | ---: | ---: | ---: | ---: |
| `even-odd` | 6.84G | 0.54 | 1.12 | 1.97 | 0.46 |
| `fib` | 12.89G | 1.07 | 1.52 | 1.28 | 0.13 |
| `tailfib` | 6.82G | 1.08 | 2.01 | 1.62 | 0.45 |
| `tak` | 7.45G | 1.21 | 1.81 | 1.34 | 0.12 |
| `tyan` | 499.5M | 1.30 | 1.97 | 1.39 | 1.59 |
| `logic` | 765.6M | 1.59 | 1.62 | 1.22 | 1.58 |
| `fft` | 27.45G | 1.80 | 4.05 | 0.16 | 1.00 |
| `tsp` | 18.78G | 1.86 | 5.72 | 0.36 | 1.00 |
| `model-elimination` | 87.65G | 1.93 | 2.30 | 1.35 | 3.05 |
| `simple` | 348.8M | 2.21 | 2.77 | 0.70 | 0.74 |
| `knuth-bendix` | 151.5M | 2.31 | 3.14 | 0.80 | 9.78 |
| `nucleic` | 858.6M | 2.32 | 3.12 | 0.99 | 1.18 |
| `boyer` | 797M | 2.38 | 3.07 | 0.89 | 1.17 |
| `mpuz` | 2.84G | 2.63 | 3.06 | 1.40 | 0.70 |
| `imp-for` | 655.3M | 2.98 | 4.29 | 1.30 | 0.56 |
| `count-graphs` | 28.37G | 3.00 | 3.46 | 1.43 | 4.45 |
| `mandelbrot` | 72.08G | 3.16 | 4.43 | 1.41 | 8.04 |
| `barnes-hut` | 371.8M | 3.23 | 4.21 | 0.88 | 1.21 |
| `string-concat` | 542.2M | 3.28 | 3.29 | 2.10 | 1.00 |
| `DLXSimulator` | 59.75G | 3.38 | 4.70 | 3.40 | 0.75 |
| `merge` | 1.34G | 3.80 | 7.04 | 1.27 | 0.77 |
| `vector64-concat` | 7.73G | 4.01 | 6.55 | n/a | 1.00 |
| `peek` | 3.93G | 4.08 | 3.72 | n/a | 0.90 |
| `tailmerge` | 656.1M | 4.17 | 6.79 | 0.59 | 1.84 |
| `wc-input1` | 815.1M | 4.51 | 5.04 | 0.31 | 4.00 |
| `wc-scanStream` | 814.6M | 4.94 | 4.79 | 0.36 | 3.76 |
| `zebra` | 11.31G | 5.88 | 9.13 | 4.18 | 10.66 |
| `psdes-random` | 121.41G | 6.16 | 8.17 | 8.83 | MLton allocated 1,112 bytes |
| `matrix-multiply` | 14.98G | 7.46 | 9.45 | 0.63 | 2.51 |
| `vector32-concat` | 10.13G | 7.66 | 8.92 | 2.33 | 2.00 |
| `life` | 43.4G | 8.62 | 15.75 | 9.63 | 1.61 |
| `pidigits` | 10.2M | 9.59 | 16.15 | 2.53 | 0.56 |
| `vector-rev` | 19.18G | 11.03 | 9.16 | 4.60 | 4.00 |
| `raytrace` | 5.5M | 11.84 | 34.38 | 1.68 | 2.65 |
| `md5` | 165.23G | 11.90 | 14.18 | 4.63 | 234.43 |
| `checksum` | 364.3M | 12.23 | 10.98 | 3.54 | 1.00 |
| `smith-normal-form` | 241.7M | 16.25 | 25.16 | 7.13 | 0.67 |
| `output1` | 272.4G | 24.68 | 22.71 | 3.32 | MLton allocated 6,024 bytes |

### Where the time goes

Weighted samples from `perf record -e cycles:u`, with JIT symbols
from `runevm --jit-perf-map` and categories from
`bin/rune-measure perf-groups`.

| Part of the runtime | Compiler compiling itself | HOL4 kernel work |
| --- | ---: | ---: |
| tier 2 code | 54.1% | 68.3% |
| interpreter | 0.6% | 1.3% |
| frames: walks, liveness, the barrier | 0.2% | 0.4% |
| collector: minor | 10.3% | 4.0% |
| collector: major | 17.5% | 2.0% |
| allocation | 1.0% | 1.2% |
| equality (runtime) | 0.1% | 0.2% |
| string order (runtime) | 1.1% | 1.4% |
| IntInf primitives | 0.0% | 1.0% |
| primitives | 0.4% | 0.5% |
| JIT compiler | 1.9% | 2.9% |
| image and loader | 0.1% | 3.0% |
| libc: malloc and printf | 1.0% | 2.6% |
| memmove/memcpy (other callers) | 1.2% | 0.9% |
| other | 10.5% | 10.2% |

Tier 2 code accounted for 100.0% of the `fib` profile. In MLton’s `merge`, tier 2 code accounted for 19.8%, frame walks and barriers for 30.1%, and collection for 29.9%.

## The benchmark suite

The [benchmark suite](../examples/benchmarks/README.md) uses normal
inputs and three fresh processes per configuration. Each cell is the
median wall time in seconds, with startup included. Rune compiles at
`-O2` and the hosts use their defaults. Parentheses give Rune’s time
divided by the host’s for Rune times of at least 0.02 s and positive
host times.

The run attempted all 258 workloads in the published cohort.
It produced 257 Rune timings. The tables of ratios use paired
programs with at least 0.05 s on Rune and 0.02 s on the host. A timing
requires a passing correctness run and three passing samples. Unavailable cells are marked `n/a`.

- Poly/ML lacks `Int64` for `peek` and `vector64-concat`.
- SML/NJ’s output checks failed for `aobench`, `barnes-hut`,
  `black-scholes`, `gen_regexps-lazy`, and `tsp-smlnj`.
- SML/NJ and Poly/ML both try to open `DATA/spheres.txt` while loading
  `id-ray`. The runner supplies those files when executing the program.
- All four configurations rejected `reverse-complement`. Its normal
  profile omits the source file that defines `BenchInput`.

First 152 workloads

| Host | Paired programs | Geometric mean | Median |
| --- | ---: | ---: | ---: |
| MLton | 63 | 2.07 | 2.00 |
| SML/NJ 110.99.9 | 67 | 0.77 | 0.83 |
| Poly/ML | 68 | 1.06 | 1.04 |

First 258 workloads

| Host | Paired programs | Geometric mean | Median |
| --- | ---: | ---: | ---: |
| MLton | 113 | 2.01 | 1.86 |
| SML/NJ 110.99.9 | 121 | 0.70 | 0.70 |
| Poly/ML | 122 | 1.05 | 1.06 |

| Program | Rune | MLton | SML/NJ 110.99.9 | Poly/ML |
| --- | ---: | ---: | ---: | ---: |
| tak | 0.07 | 0.06 (1.2) | 0.10 (0.7) | 0.06 (1.2) |
| kittmergesort | 0.03 | 0.04 (0.8) | 0.04 (0.8) | 0.04 (0.8) |
| primes-lazy | 0.03 | 0.01 (3.0) | 0.05 (0.6) | 0.03 (1.0) |
| primes-strict | 0.25 | 0.26 (1.0) | 0.36 (0.7) | 0.26 (1.0) |
| bdd | 0.04 | 0.02 (2.0) | 0.06 (0.7) | 0.03 (1.3) |
| fib | 0.01 | 0.00 | 0.02 | 0.01 |
| tailfib | 0.00 | 0.00 | 0.01 | 0.00 |
| even-odd | 0.00 | 0.00 | 0.02 | 0.00 |
| merge | 0.01 | 0.00 | 0.03 | 0.01 |
| tailmerge | 0.01 | 0.00 | 0.02 | 0.01 |
| imp-for | 0.00 | 0.00 | 0.01 | 0.00 |
| vector-rev | 0.00 | 0.00 | 0.02 | 0.00 |
| vector32-concat | 0.00 | 0.00 | 0.01 | 0.00 |
| vector64-concat | 0.00 | 0.00 | 0.01 | n/a |
| string-concat | 0.00 | 0.00 | 0.01 | 0.00 |
| wc-input1 | 0.04 | 0.00 | 0.05 (0.8) | 0.06 (0.7) |
| wc-scanStream | 0.04 | 0.00 | 0.04 (1.0) | 0.03 (1.3) |
| checksum | 0.09 | 0.00 | 0.05 (1.8) | 0.04 (2.2) |
| boyer | 0.07 | 0.05 (1.4) | 0.12 (0.6) | 0.13 (0.5) |
| nucleic | 0.09 | 0.04 (2.2) | 0.07 (1.3) | 0.09 (1.0) |
| life | 0.10 | 0.02 (5.0) | 0.17 (0.6) | 0.02 (5.0) |
| matrix-multiply | 0.00 | 0.00 | 0.01 | 0.00 |
| md5 | 0.01 | 0.00 | 0.01 | 0.00 |
| fft | 0.01 | 0.00 | 0.03 | 0.02 |
| binary-trees | 0.01 | 0.00 | 0.01 | 0.01 |
| flat-array | 0.22 | 0.01 (22.0) | 0.84 (0.3) | 0.69 (0.3) |
| peek | 0.97 | 0.24 (4.0) | 0.82 (1.2) | n/a |
| psdes-random | 0.07 | 0.01 (7.0) | 0.07 (1.0) | 0.04 (1.8) |
| mandelbrot | 0.03 | 0.01 (3.0) | 0.02 (1.5) | 0.03 (1.0) |
| pidigits | 0.01 | 0.00 | 0.02 | 0.00 |
| logic | 2.12 | 1.52 (1.4) | 1.97 (1.1) | 1.83 (1.2) |
| zebra | 0.29 | 0.04 (7.2) | 0.58 (0.5) | 0.10 (2.9) |
| count-graphs | 0.02 | 0.00 | 0.02 (1.0) | 0.02 (1.0) |
| many_refs | 0.14 | 0.03 (4.7) | 0.30 (0.5) | 0.12 (1.2) |
| tensor | 0.42 | 0.06 (7.0) | 0.29 (1.4) | 0.43 (1.0) |
| zern | 0.01 | 0.00 | 0.02 | 0.03 |
| smith-normal-form | 0.00 | 0.00 | 0.01 | 0.00 |
| ratio-regions | 0.03 | 0.01 (3.0) | 0.04 (0.8) | 0.01 (3.0) |
| mpuz | 7.40 | 2.77 (2.7) | 9.88 (0.7) | 5.46 (1.4) |
| DLXSimulator | 31.35 | 10.20 (3.1) | 30.61 (1.0) | 9.64 (3.3) |
| knuth-bendix | 0.37 | 0.18 (2.1) | 0.54 (0.7) | 0.52 (0.7) |
| tyan | 0.28 | 0.21 (1.3) | 0.27 (1.0) | 0.24 (1.2) |
| lexgen | 0.13 | 0.07 (1.9) | 0.14 (0.9) | 0.18 (0.7) |
| mlyacc | 0.09 | 0.05 (1.8) | 0.08 (1.1) | 0.04 (2.2) |
| hamlet | 0.04 | 0.00 | 0.01 (4.0) | 0.00 |
| kitfib35 | 0.13 | 0.14 (0.9) | 0.16 (0.8) | 0.11 (1.2) |
| fib0 | 0.01 | 0.01 | 0.02 | 0.01 |
| kitreynolds2 | 0.15 | 0.07 (2.1) | 0.31 (0.5) | 0.15 (1.0) |
| kitreynolds3 | 0.08 | 0.02 (4.0) | 0.20 (0.4) | 0.08 (1.0) |
| kitloop2 | 0.00 | 0.00 | 0.01 | 0.00 |
| kitdangle | 0.02 | 0.00 | 0.02 (1.0) | 1.48 (0.0) |
| kitdangle3 | 0.05 | 0.00 | 0.05 (1.0) | 2.11 (0.0) |
| msort | 0.03 | 0.03 (1.0) | 0.03 (1.0) | 0.04 (0.8) |
| kittmergesort_tp | 0.70 | 0.57 (1.2) | 0.87 (0.8) | 0.63 (1.1) |
| barnes-hut | 0.25 | 0.10 (2.5) | n/a | 0.35 (0.7) |
| tsp | 0.01 | 0.00 | 0.01 | 0.00 |
| fannkuch | 0.00 | 0.00 | 0.01 | 0.00 |
| f-arith | 0.01 | 0.01 | 0.02 | 0.02 |
| stream-sieve | 0.03 | 0.02 (1.5) | 0.03 (1.0) | 0.03 (1.0) |
| simple | 0.28 | 0.14 (2.0) | 0.25 (1.1) | 0.31 (0.9) |
| twenty-four | 0.16 | 0.09 (1.8) | 0.16 (1.0) | 0.07 (2.3) |
| nbody | 0.64 | 0.44 (1.5) | 0.34 (1.9) | 1.94 (0.3) |
| output1 | 0.07 | 0.00 | 0.03 (2.3) | 0.02 (3.5) |
| ray | 0.18 | 0.05 (3.6) | 0.06 (3.0) | 0.12 (1.5) |
| raytrace | 1.34 | 0.45 (3.0) | 1.20 (1.1) | 1.35 (1.0) |
| vliw | 0.09 | 0.04 (2.2) | 0.10 (0.9) | 0.07 (1.3) |
| fxp | 0.14 | 0.09 (1.6) | 0.19 (0.7) | 0.32 (0.4) |
| model-elimination | 12.31 | 6.50 (1.9) | 15.58 (0.8) | 10.98 (1.1) |
| sat | 0.18 | 0.06 (3.0) | 0.17 (1.1) | 0.16 (1.1) |
| boyer-smlnj | 0.83 | 0.40 (2.1) | 1.05 (0.8) | 0.91 (0.9) |
| logic-smlnj | 12.65 | 10.13 (1.2) | 12.27 (1.0) | 10.62 (1.2) |
| life-smlnj | 3.32 | 0.91 (3.6) | 6.10 (0.5) | 0.66 (5.0) |
| minimax | 1.50 | 0.71 (2.1) | 3.15 (0.5) | 5.09 (0.3) |
| iter-pidigits | 0.00 | 0.00 | 0.01 | 0.00 |
| mazefun | 0.10 | 0.05 (2.0) | 0.20 (0.5) | 0.08 (1.2) |
| queens-lazy | 0.01 | 0.00 | 0.02 | 0.01 |
| queens-strict | 0.02 | 0.02 (1.0) | 0.02 (1.0) | 0.02 (1.0) |
| nqueens | 0.01 | 0.00 | 0.01 | 0.00 |
| rec_seq_ack | 0.01 | 0.01 | 0.02 | 0.01 |
| klife_eq | 0.15 | 0.02 (7.5) | 0.18 (0.8) | 0.03 (5.0) |
| kitlife35u_smlnj | 0.04 | 0.03 (1.3) | 0.04 (1.0) | 0.03 (1.3) |
| kitqsort_no_basislib | 0.01 | 0.01 | 0.02 | 0.02 |
| tailfib-mlkit | 0.00 | 0.00 | 0.01 | 0.00 |
| tak-mlkit | 0.02 | 0.01 (2.0) | 0.04 (0.5) | 0.01 (2.0) |
| matrix-multiply-mlkit | 0.04 | 0.00 | 0.06 (0.7) | 0.03 (1.3) |
| vector-rev-mlkit | 0.01 | 0.00 | 0.03 | 0.00 |
| vector-rev_smlnj | 0.00 | 0.00 | 0.02 | 0.00 |
| vector-concat | 0.00 | 0.00 | 0.01 | 0.00 |
| vector-concat_smlnj | 0.00 | 0.00 | 0.02 | 0.00 |
| peek-mlkit | 0.00 | 0.00 | 0.01 | 0.01 |
| wc-input1-mlkit | 0.03 | 0.01 (3.0) | 0.04 (0.8) | 0.04 (0.8) |
| wc-scanStream-mlkit | 0.03 | 0.00 | 0.03 (1.0) | 0.02 (1.5) |
| psdes-random-mlkit | 0.01 | 0.00 | 0.01 | 0.01 |
| safe-for-space | 0.06 | 0.01 (6.0) | 0.08 (0.8) | 0.06 (1.0) |
| pidigits-smlnj | 0.01 | 0.00 | 0.02 | 0.00 |
| fft-smlnj | 0.00 | 0.00 | 0.01 | 0.00 |
| nucleic-smlnj | 0.08 | 0.04 (2.0) | 0.03 (2.7) | 0.11 (0.7) |
| count-graphs-smlnj | 0.00 | 0.00 | 0.01 | 0.00 |
| matrix-multiply-ramp | 0.00 | 0.00 | 0.01 | 0.00 |
| kitreynolds2_no_basislib | 0.01 | 0.00 | 0.02 | 0.01 |
| kitreynolds3_no_basislib | 0.00 | 0.00 | 0.01 | 0.00 |
| kittmergesort_no_basislib | 0.01 | 0.01 | 0.03 | 0.01 |
| hanoi | 0.00 | 0.00 | 0.01 | 0.00 |
| fib-mlkit | 0.00 | 0.00 | 0.01 | 0.00 |
| mandelbrot-smlnj | 0.02 | 0.02 (1.0) | 0.03 (0.7) | 0.05 (0.4) |
| mandelbrot-rat | 0.93 | 0.29 (3.2) | 2.02 (0.5) | 0.18 (5.2) |
| kitmandelbrot | 0.00 | 0.00 | 0.01 | 0.00 |
| FuhMishra | 0.03 | 0.01 (3.0) | 0.02 (1.5) | 0.02 (1.5) |
| black-scholes | 0.04 | 0.02 (2.0) | n/a | 0.03 (1.3) |
| professor2 | 0.05 | 0.03 (1.7) | 0.16 (0.3) | 0.05 (1.0) |
| professor2_tp | 0.04 | 0.02 (2.0) | 0.16 (0.2) | 0.04 (1.0) |
| professor_game | 0.05 | 0.02 (2.5) | 0.17 (0.3) | 0.04 (1.2) |
| professor_game-mlkit | 0.05 | 0.02 (2.5) | 0.15 (0.3) | 0.04 (1.2) |
| professor_game_debug | 0.00 | 0.00 | 0.01 | 0.00 |
| kkb_eq | 0.13 | 0.05 (2.6) | 0.11 (1.2) | 0.12 (1.1) |
| kitkbjul9_smlnj | 0.12 | 0.06 (2.0) | 0.12 (1.0) | 0.12 (1.0) |
| kkb36c_smlnj | 0.11 | 0.05 (2.2) | 0.12 (0.9) | 0.12 (0.9) |
| ratio-regions-mlkit | 0.04 | 0.00 | 0.06 (0.7) | 0.01 (4.0) |
| ratio-regions_tp | 0.08 | 0.02 (4.0) | 0.18 (0.4) | 0.06 (1.3) |
| ratio-regions-smlnj | 0.03 | 0.01 (3.0) | 0.04 (0.8) | 0.01 (3.0) |
| count-graphs-mlkit | 0.01 | 0.00 | 0.01 | 0.01 |
| mpuz-mlkit | 0.77 | 0.27 (2.9) | 0.99 (0.8) | 0.56 (1.4) |
| knuth-bendix-smlnj | 0.12 | 0.06 (2.0) | 0.18 (0.7) | 0.20 (0.6) |
| tyan-smlnj | 0.42 | 0.35 (1.2) | 0.36 (1.2) | 0.31 (1.4) |
| tyan-mlkit | 0.26 | 0.20 (1.3) | 0.24 (1.1) | 0.24 (1.1) |
| smith-normal-form-mlkit | 0.00 | 0.00 | 0.01 | 0.00 |
| smith-nf | 0.00 | 0.00 | 0.01 | 0.00 |
| lexgen-smlnj | 0.08 | 0.06 (1.3) | 0.09 (0.9) | 0.14 (0.6) |
| mlyacc-smlnj | 0.07 | 0.03 (2.3) | 0.07 (1.0) | 0.03 (2.3) |
| kitsimple | 0.01 | 0.00 | 0.01 | 0.01 |
| kitsimple_tp | 0.03 | 0.01 (3.0) | 0.02 (1.5) | 0.01 (3.0) |
| kitsimple_no_basislib | 0.01 | 0.00 | 0.01 | 0.00 |
| simple-smlnj | 0.04 | 0.01 (4.0) | 0.02 (2.0) | 0.02 (2.0) |
| tsp-smlnj | 0.00 | 0.00 | n/a | 0.00 |
| DLXSimulator-mlkit | 0.10 | 0.05 (2.0) | 0.09 (1.1) | 0.03 (3.3) |
| aobench | 0.07 | 0.15 (0.5) | n/a | 0.04 (1.8) |
| id-ray | 1.00 | 0.30 (3.3) | n/a | n/a |
| plclub-ray | 0.06 | 0.01 (6.0) | 0.05 (1.2) | 0.07 (0.9) |
| mc-ray | 0.24 | 0.11 (2.2) | 0.09 (2.7) | 0.29 (0.8) |
| ray-smlnj | 0.02 | 0.00 | 0.01 (2.0) | 0.02 (1.0) |
| kitmolgard | 0.02 | 0.01 (2.0) | 0.03 (0.7) | 0.02 (1.0) |
| vliw-smlnj | 0.18 | 0.10 (1.8) | 0.25 (0.7) | 0.19 (0.9) |
| rfib | 0.01 | 0.00 | 0.01 | 0.01 |
| tak-nofib-strict | 0.00 | 0.00 | 0.01 | 0.00 |
| tak-nofib-lazy | 0.00 | 0.00 | 0.01 | 0.01 |
| exp3_8-lazy | 0.65 | 0.21 (3.1) | 0.74 (0.9) | 2.13 (0.3) |
| exp3_8-strict | 0.06 | 0.05 (1.2) | 0.07 (0.9) | 0.06 (1.0) |
| digits-of-e1-lazy | 0.05 | 0.04 (1.2) | 0.28 (0.2) | 0.05 (1.0) |
| digits-of-e2-lazy | 0.22 | 0.12 (1.8) | 0.84 (0.3) | 0.22 (1.0) |
| latency-ring | 0.56 | 0.66 (0.8) | 4.77 (0.1) | 2.90 (0.2) |
| latency-map | 1.24 | 1.29 (1.0) | 5.45 (0.2) | 3.27 (0.4) |
| latency-static-map | 0.48 | 0.64 (0.8) | 1.02 (0.5) | 0.61 (0.8) |

## Compiling

Each build compiles the hello example, the signatures in
`tests/perf/compile-sigs.sml`, and the compiler itself to register
bytecode. The table uses the machine instructions and cycles from the
least-cycle sample of five. The Rune and host columns use builds from the
same source revision. Rune’s engines and the host builds were
measured in separate passes after checking that their bootstrap outputs
were byte-identical.

| Build | `hello` instructions | `compile-sigs` instructions | Bootstrap instructions | Bootstrap instructions / MLton’s build | Bootstrap cycles |
| --- | ---: | ---: | ---: | ---: | ---: |
| Rune as shipped (tier 2) | 350M | 972.2M | 28.65G | 2.39 | 28.4G |
| `bin/runevm`, tier 1 | 336.3M | 986.2M | 36.35G | 3.03 | 37.04G |
| `bin/runevm`, interpreter | 262.4M | 1.62G | 129.69G | 10.82 | 89.45G |
| `runevm-stack` | 251.9M | 1.8G | 147.88G | 12.34 | 101.72G |
| `runeopt` | 179.9M | 628.7M | 46.29G | 3.86 | 43.49G |
| MLton’s build | 56.1M | 175.6M | 11.98G | 1.00 | 16.42G |
| Poly/ML’s build | 38.1M | 119.3M | 14.03G | 1.17 | 20.11G |
| MLKit’s build | 165.2M | 482.4M | 26.86G | 2.24 | 33.32G |
| SML/NJ 110.99.9, 64 bits | 120.1M | 549.1M | 164.77G | 13.75 | 160.34G |
| SML/NJ 110.99.9, 32 bits | 273.2M | 680.3M | 46.58G | 3.89 | 44.48G |
| SML/NJ 2026.2 | 88.9M | 448.9M | 137.45G | 11.47 | 129.6G |

The phase breakdown uses `--pass-stats` from the fastest wall-clock
sample of five. The phase where a collection occurs includes its time.

| Stage | Rune as shipped | MLton’s build | Poly/ML’s build |
| --- | ---: | ---: | ---: |
| `startup` | 0.8% | 0.0% | 0.1% |
| `index` | 0.1% | 0.3% | 0.2% |
| `lex` | 3.2% | 2.8% | 2.7% |
| `select` | 1.4% | 0.9% | 2.0% |
| `parse` | 3.0% | 5.7% | 2.3% |
| `elaborate` | 13.1% | 8.0% | 7.7% |
| `translate` | 5.9% | 5.5% | 16.8% |
| `mid` | 3.9% | 2.7% | 2.1% |
| `midcanon` | 4.5% | 6.2% | 2.5% |
| `expand` | 2.6% | 1.9% | 1.5% |
| `shake` | 1.8% | 2.2% | 1.4% |
| `lift` | 4.5% | 2.4% | 2.4% |
| `workers` | 2.8% | 2.2% | 2.3% |
| `simplify` | 16.9% | 15.3% | 18.8% |
| `refs` | 1.0% | 1.1% | 1.0% |
| `uncurry` | 3.0% | 2.8% | 2.3% |
| `lower` | 14.8% | 14.7% | 13.2% |
| `registers` | 12.4% | 17.8% | 15.2% |
| `emit` | 2.4% | 4.3% | 3.2% |
| `stats` | 1.7% | 3.0% | 2.2% |
| Total processor time | 8.66 s | 6.99 s | 6.74 s |

### MLton's compiler compiled by Rune

MLton `5fe943391`, prepared with `bin/rune-build setup-mlton`
(606 files), compiled with `--type-work=1000000000 --pass-stats`.
Rune runs at tier 2. The second column runs the same Rune compiler
sources built by MLton. Each measurement is one run. The unit
compilation uses `--units --no-cache`.
The whole-program pair used the same library path and emitted identical bytecode.

| Workload and metric | Rune as shipped | Rune built by MLton | Rune / host build |
| --- | ---: | ---: | ---: |
| Whole program, processor time | 68.28 s | 66.12 s | 1.03 |
| Elaboration | 43.93 s | 50.53 s | 0.87 |
| Instructions | 345,900,882,464 | 139,628,455,255 | 2.48 |
| Peak resident set (GiB) | 5.70 | 9.53 | 0.60 |
| Units, processor time | 102.44 s | n/a | n/a |
| Unit interfaces and link | 44.26 s | n/a | n/a |
| Units, elaboration | 42.80 s | n/a | n/a |
| Typecheck in units, instructions | n/a | 50,062,104,168 | n/a |

The whole-program result runs on the current `runevm` as an MLton
compiler. The table compares it with the MLton 20241230 native compiler.
The processor times include the assembler and linker. Each of the
six benchmark sources calls `Main.doit` with its size from
`tests/perf/mlton-bench.txt`.

| Program compiled | MLton built by Rune | MLton built by MLton | Ratio |
| --- | ---: | ---: | ---: |
| `boyer` | 11.87 s | 3.94 s | 3.01 |
| `barnes-hut` | 10.70 s | 4.04 s | 2.65 |
| `nucleic` | 10.50 s | 4.20 s | 2.50 |
| `model-elimination` | 40.07 s | 9.85 s | 4.07 |
| `mlyacc` | 47.60 s | 11.69 s | 4.07 |
| `hamlet` | 68.85 s | 17.01 s | 4.05 |
| `mlton.mlb` | 1866.68 s | 415.14 s | 4.50 |

For `mlton.mlb`, the Rune-hosted compiler used 9.87T machine instructions and peaked at 8.26 GiB. The native compiler used 1.11T instructions and peaked at 15.67 GiB.

### The counts

`make perf-check` runs these workloads with `runevm --count` and
checks the results against the limits in `tests/perf/*.budget` and
`tests/perf/stack/*.budget`. The table gives the counters from the
runs. For workloads with a scaling check, the runner’s summary
gives the counts for the input listed here. The budget files record
the inputs and parameters for each workload.

| Workload | Engine | Bytecode instructions | Bytes allocated | Objects |
| --- | ---: | ---: | ---: | ---: |
| Bootstrap | Register | 2,679,050,400 | 3,200,358,624 | 121,045,419 |
| Bootstrap | Stack | 4,398,504,823 | 2,629,184,960 | 98,149,684 |
| Compile hello | Register | 1,821,580 | 3,132,456 | 75,402 |
| Compile hello | Stack | 3,193,138 | 3,131,408 | 75,345 |
| Compile signatures | Register | 32,331,384 | 32,281,760 | 1,159,686 |
| Compile signatures | Stack | 57,119,603 | 32,173,352 | 1,155,227 |
| Sharing specifications (`share 200 16`) | Register | 24,018,299 | 23,018,520 | 664,033 |
| Nested sharing specifications (`sharenest 200 16`) | Register | 22,376,477 | 21,484,832 | 643,781 |
| Where-type chain (`where 1000 400`) | Register | 14,994,384 | 21,565,920 | 769,184 |
| Large signature (`sig 2000`) | Register | 25,166,403 | 56,195,856 | 2,147,142 |
| Functor applications (`funapp 40 80`) | Register | 48,445,775 | 63,087,112 | 2,043,606 |
| Nested functors (`funnest 8 2 8`) | Register | 133,790,974 | 159,229,728 | 5,105,474 |
| Exponential functor input (`expo 20`) | Register | 2,272,157 | 3,539,488 | 91,317 |

## HOL4

HOL4 `3d15b18a8` built by Rune with the
[overloading annotations](plans/hol4-overloading-declaration.patch),
compared with HOL4 `bdc6917ee` built by Poly/ML 5.9.2. The Rune build reached `hol.state` after 561 s from the start of `bin/build -j 8`.

Theory rows use HOL’s own clock and the counters from the fastest
rebuild of three. The kernel counters are from the least-cycle run of
five. Individual kernel workloads use the least processor time of
their five runs.

| Workload | Rune | Poly/ML | Ratio | Rune instructions | Poly/ML instructions | Ratio |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| `logroot` theory | 6.30 s | 3.80 s | 1.66 | 35.12G | 14.03G | 2.50 |
| `mergesort` theory | 7.20 s | 4.30 s | 1.67 | 41.94G | 16.78G | 2.50 |
| Kernel work, cycles | 18.48G | 8.97G | 2.06 | 37.38G | 11.63G | 3.21 |

| Kernel workload | Rune processor time | Poly/ML processor time | Ratio |
| --- | ---: | ---: | ---: |
| `EVAL-FACT-60` | 0.359 s | 0.175 s | 2.05 |
| `EVAL-FACT-150` | 4.060 s | 1.982 s | 2.05 |
| `PROVE_TAC-x20` | 0.070 s | 0.009 s | 7.78 |
| `SIMP_CONV-arith-x200` | 0.231 s | 0.080 s | 2.89 |
| `DECIDE-x200` | 0.242 s | 0.099 s | 2.44 |
| `Arbnum-mul-x200000` | 0.102 s | 0.011 s | 9.27 |
| `type_of-term-x200000` | 0.003 s | 0.001 s | 3.00 |

## Measuring

Run from the repository root after a fresh `make boot vm runedoc repl`.
Build `bin/rune.stack.rbc`, `bin/runedoc.stack.rbc`, `bin/rune-measure`,
`runeopt` and `bin/runevm-native` for the engine comparisons. Use
`make hosts host-builds` to prepare the pinned host toolchains and builds.

| Table | Command |
|---|---|
| `tests/perf` wall-clock time | `make perf PERF_CONFIGS=rune,rune:stack,rune:opt,hosts,xc1`, three passes |
| `tests/perf` hardware counters | `bin/rune-measure perf-cycles --runs 5 --configs rune,mlton,polyml` |
| Rune’s engines | `bin/rune-measure perf-cycles --runs 3 --configs rune,jit-baseline,jit-off,stack,opt` |
| Compiler profile | `bin/rune-measure perf-cycles --runs 1 --configs rune --profile rune:bootstrap bootstrap` |
| MLton’s benchmark set | `bin/rune-measure perf-cycles --mlton-bench DIR NFILE --runs 3`, with MLton’s `benchmark/tests` as DIR and the published rows from `tests/perf/mlton-bench.txt` as NFILE. Use one sample for the separate `smith-normal-form` fixture. |
| Rune’s benchmark suite | `bin/rune-measure benchmarks time --profile normal --samples 3 --configs rune,native:mlton,native:smlnj-legacy,native:polyml --filter =NAME`, for each of the first 258 normal-profile workloads |
| The compiler’s builds | `bin/rune-measure perf-cycles --runs 5 --configs rune,jit-baseline,jit-off,stack,opt,mlton,polyml,mlkit,smlnj-legacy,smlnj32,smlnj-dev WORKLOAD`, with `compile-hello`, `compile-sigs`, or `bootstrap` |
| Compiler phases | `bin/rune-measure perf-units --runs 5 --configs tier2,mlton,polyml phases` |
| Rune compiling MLton | `bin/rune-build setup-mlton DIR` prepares the pinned source list. The whole and unit runs use that list and `--type-work=1000000000 --pass-stats`. |
| HOL4 theories | `bin/rune-measure hol-theory HOL THEORY --runs 3`, for each build and theory |
| HOL4 kernel | `perf stat -e cycles:u,instructions:u -- bin/rune-measure hol-kernel HOL`, five times for each build |
| HOL4 kernel profile | Run `perf record -e cycles:u` with `RUNEVM_OPTS=--jit-perf-map` over the kernel command, then pass `perf script -F period,ip,sym,dso` output to `bin/rune-measure perf-groups`. |
| Bytecode instruction and allocation counts | `make perf-check` |

Use `taskset -c N` to pin single-threaded timings to one logical CPU.
The timing runs use the default JIT tier unless the configuration
specifies another. Run allocation counts and profiles separately from
the timing samples. A single `perf-units` run emits phase data in
`tests/out/perf-units`. `hol-theory` rebuilds a private copy of the
theory and `hol-kernel` runs workloads in a restored `hol.state`.

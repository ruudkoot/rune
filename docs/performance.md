# Performance

What each configuration of Rune costs to run a program and to compile one,
against the SML systems Rune is built with. Why it costs that, and what is
being done about it, is in [plans/performance.md](plans/performance.md)
(the VMs and native code), [plans/jit.md](plans/jit.md) (the JIT of `runtime/register`)
and [plans/middle-end.md](plans/middle-end.md) (the compiler's
optimisations); how native code is made is in [native.md](native.md).

## The configurations

| Configuration | What runs |
|---|---|
| `rune` | the stack bytecode of the self-hosted compiler, on `runevm-stack` ([bytecode.md](bytecode.md)) |
| `rune:opt` | the same bytecode translated into x86-64 code by `runeopt` ([native.md](native.md)) |
| `rune:new` | the register bytecode on `runtime/register` ([bytecode.md](bytecode.md), The register bytecode), at one of the JIT levels below |
| `native:HOST` | the program on the host's own Basis Library, compiled by the host |
| `xc1:HOST` | the program on Rune's Basis Library (`lib/basis`), compiled by the host ([basis-compat.md](basis-compat.md)) |

The hosts are MLton 20241230, SML/NJ 110.99.9 (64 and 32 bits), SML/NJ
2026.2, Poly/ML 5.9.2 and MLKit 4.7.23 (`make hosts`).

`runtime/register` runs its register bytecode at a JIT level
([runtime/register/README.md](../runtime/register/README.md), Tier 1 and Tier 2),
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
others. In parentheses: the time divided by `rune:new opt` for that
same program, so that column is 1.0.

Rune on `runevm-stack`, as native code, and on `runtime/register` at each JIT level:

| Program | rune | rune:opt | rune:new off | rune:new baseline | rune:new opt | rune:new all | rune:new all+t2 |
|---|---:|---:|---:|---:|---:|---:|---:|
| array_sieve | 8.69 (3.7) | 4.62 (2.0) | 8.20 (3.5) | 3.93 (1.7) | 2.34 (1.0) | 3.95 (1.7) | 2.38 (1.0) |
| fib | 6.42 (3.9) | 2.27 (1.4) | 5.49 (3.3) | 2.28 (1.4) | 1.66 (1.0) | 2.20 (1.3) | 1.72 (1.0) |
| intinf_fact | 52.76 (2.2) | 26.62 (1.1) | 54.98 (2.3) | 24.02 (1.0) | 23.73 (1.0) | 25.04 (1.1) | 23.65 (1.0) |
| list_ops | 5.79 (2.1) | 2.65 (1.0) | 5.60 (2.0) | 2.81 (1.0) | 2.78 (1.0) | 3.29 (1.2) | 2.51 (0.9) |
| real_nbody | 2.91 (5.6) | 1.28 (2.5) | 2.17 (4.2) | 0.87 (1.7) | 0.52 (1.0) | 0.87 (1.7) | 0.53 (1.0) |
| string_ops | 10.77 (1.9) | 5.70 (1.0) | 10.20 (1.8) | 6.14 (1.1) | 5.80 (1.0) | 6.67 (1.2) | 5.91 (1.0) |
| tak | 1.88 (3.2) | 0.61 (1.1) | 1.89 (3.3) | 0.61 (1.1) | 0.58 (1.0) | 0.62 (1.1) | 0.58 (1.0) |
| word_bits | 4.67 (10.9) | 1.28 (3.0) | 3.72 (8.7) | 1.00 (2.3) | 0.43 (1.0) | 1.07 (2.5) | 0.43 (1.0) |

The hosts, each on its own Basis Library (`native`) and on Rune's (`xc1`).
The first column is `rune:new opt` from the table above, the register VM
that is shipped, so a host can be read against it. A number in parentheses
is that program's time divided by this column.

| Program | rune:new opt | native:mlton | native:smlnj-legacy | native:smlnj32 | native:smlnj-dev | native:polyml | native:mlkit |
|---|---:|---:|---:|---:|---:|---:|---:|
| array_sieve | 2.34 (1.0) | 0.50 (0.2) | 1.20 (0.5) | 0.97 (0.4) | 0.72 (0.3) | 0.64 (0.3) | 0.86 (0.4) |
| fib | 1.66 (1.0) | 0.42 (0.3) | 0.43 (0.3) | 0.45 (0.3) | 0.39 (0.2) | 0.33 (0.2) | 1.46 (0.9) |
| intinf_fact | 23.73 (1.0) | 0.03 (0.0) | 0.25 (0.0) | 0.43 (0.0) | 0.21 (0.0) | 0.13 (0.0) | 2.48 (0.1) |
| list_ops | 2.78 (1.0) | 1.96 (0.7) | 1.96 (0.7) | 1.40 (0.5) | 1.21 (0.4) | 1.43 (0.5) | 1.43 (0.5) |
| real_nbody | 0.52 (1.0) | 0.58 (1.1) | 0.51 (1.0) | 0.52 (1.0) | 0.50 (1.0) | 1.28 (2.5) | 1.43 (2.8) |
| string_ops | 5.80 (1.0) | 1.58 (0.3) | 2.12 (0.4) | 2.14 (0.4) | 1.42 (0.2) | 2.02 (0.3) | 3.03 (0.5) |
| tak | 0.58 (1.0) | 0.15 (0.3) | 0.25 (0.4) | 0.28 (0.5) | 0.24 (0.4) | 0.15 (0.3) | 0.47 (0.8) |
| word_bits | 0.43 (1.0) | 0.12 (0.3) | 0.28 (0.7) | 0.25 (0.6) | 0.13 (0.3) | 0.17 (0.4) | 0.30 (0.7) |

| Program | rune:new opt | xc1:mlton | xc1:smlnj-legacy | xc1:smlnj32 | xc1:smlnj-dev | xc1:polyml | xc1:mlkit |
|---|---:|---:|---:|---:|---:|---:|---:|
| array_sieve | 2.34 (1.0) | 0.46 (0.2) | 1.33 (0.6) | n/a | 1.15 (0.5) | 0.63 (0.3) | 0.76 (0.3) |
| fib | 1.66 (1.0) | 0.39 (0.2) | 0.47 (0.3) | n/a | 0.35 (0.2) | 0.34 (0.2) | 1.36 (0.8) |
| intinf_fact | 23.73 (1.0) | n/a | n/a | n/a | n/a | n/a | n/a |
| list_ops | 2.78 (1.0) | 1.14 (0.4) | 1.89 (0.7) | n/a | 1.19 (0.4) | 1.53 (0.6) | 1.73 (0.6) |
| real_nbody | 0.52 (1.0) | 0.59 (1.1) | 0.51 (1.0) | n/a | 0.50 (1.0) | 1.13 (2.2) | 1.45 (2.8) |
| string_ops | 5.80 (1.0) | 2.62 (0.5) | 3.63 (0.6) | n/a | 2.51 (0.4) | 3.24 (0.6) | 4.35 (0.8) |
| tak | 0.58 (1.0) | 0.17 (0.3) | 0.25 (0.4) | n/a | 0.24 (0.4) | 0.15 (0.3) | 0.51 (0.9) |
| word_bits | 0.43 (1.0) | 0.13 (0.3) | 0.53 (1.2) | n/a | 0.13 (0.3) | 0.17 (0.4) | 0.31 (0.7) |

Not measured: `intinf_fact` in the `xc1` configurations, whose `IntInf`
constants a host types at its own `IntInf`, not at that of `lib/basis`; and
anything on `xc1:smlnj32`, where the `LargeInt` the wrapper times with is
not that of `lib/basis`, which does not load on a 31-bit `int`.

What the tables say:

* **`runevm-stack` runs plain code 7 to 19 times slower than the native code of
  MLton, SML/NJ and Poly/ML**: `fib` 6.4 ms against 0.33 to 0.45, `tak`
  1.9 against 0.15 to 0.28. Against MLKit, whose calls are slow, it is 4
  times slower. This is the interpreter; [plans/performance.md](plans/performance.md)
  is about it.
* **Native code (`rune:opt`) runs these programs 1.9 to 3.6 times faster
  than `runevm-stack`** (`fib` 2.27 ms, `tak` 0.61, `word_bits` 1.28 against
  4.67), and 2 to 11 times slower than MLton, SML/NJ and Poly/ML on `fib`,
  `tak` and `word_bits`.
* **`runtime/register` interpreting alone (`off`) is as fast as `runevm-stack`**, and up to
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
  `runevm-stack` and is faster than `rune:opt` on all but `list_ops` (2.78 ms
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
* **Relative to the geometric mean of `fib` and `tak`, the library costs
  Rune less than it costs the hosts**: `list_ops` is 1.7 times that mean on
  Rune, 3.9 to 7.8 on the hosts but MLKit; `string_ops` 3.1 against 4.6 to
  9.1 on the same. `IntInf` is the exception: 15 times that mean on
  `runevm-stack`, 0.1 to 1.2 on the hosts, which use GMP (MLton) or native code,
  and 3.0 on MLKit. Its limbs of 30 bits are an SML datatype, and every
  limb operation is a call.
* **MLKit is slow at calls and relatively quick in its Basis Library**: its
  `fib` and `tak` are 3 to 4 times MLton's, while `list_ops` takes 0.7 and
  `array_sieve` 1.7 times as long as MLton's.
* **The `xc1` columns** run Rune's library compiled by each host, between
  0.6 and 1.9 times as slow as that host's own library (`list_ops` 1.14 ms
  on MLton against 1.96 native, `string_ops` 2.62 against 1.58): the
  algorithms of `lib/basis` are not what makes Rune slow.

## The benchmark suite

The tables above time the eight programs of `tests/perf`. This table times
the 149 programs of [`examples/benchmarks`](../examples/benchmarks/README.md)
at the normal input, on the same machine, on 2026-10-03 at `6618017`. Each
cell is the median of three fresh processes, in seconds, measured by GNU
time to the hundredth of a second. Compilation is not included. A fresh
process includes startup and shutdown. The tool's default is ten samples;
this pass used three. It is a first indicative run, and the machine was not
wholly idle. In parentheses: the time divided by `rune:new opt` for that
same program, so that column is 1.0. Where `rune:new opt` is 0.00 the ratio
is omitted. The columns are the configurations of the first table above,
and the programs are in the order of the catalogue.

The six native hosts are in the tables after the notes on `hamlet` and
`twenty-four`. The benchmark runner has no `xc1` export, so this pass does
not time Rune's library on the hosts. The `xc1` columns of the eight
programs above remain the figures from `make perf`.

| Program | rune | rune:opt | rune:new off | rune:new baseline | rune:new opt | rune:new all | rune:new all+t2 |
|---|---:|---:|---:|---:|---:|---:|---:|
| tak | 0.81 (3.4) | 0.23 (1.0) | 0.76 (3.2) | 0.27 (1.1) | 0.24 (1.0) | 0.26 (1.1) | 0.23 (1.0) |
| kittmergesort | 0.21 (2.3) | 0.11 (1.2) | 0.18 (2.0) | 0.10 (1.1) | 0.09 (1.0) | 0.12 (1.3) | 0.11 (1.2) |
| primes-lazy | 0.15 (2.5) | 0.07 (1.2) | 0.12 (2.0) | 0.07 (1.2) | 0.06 (1.0) | 0.07 (1.2) | 0.06 (1.0) |
| primes-strict | 1.48 (2.5) | 0.69 (1.1) | 1.38 (2.3) | 0.68 (1.1) | 0.60 (1.0) | 0.67 (1.1) | 0.60 (1.0) |
| bdd | 0.40 (3.6) | 0.13 (1.2) | 0.30 (2.7) | 0.13 (1.2) | 0.11 (1.0) | 0.14 (1.3) | 0.12 (1.1) |
| fib | 0.14 (3.5) | 0.05 (1.2) | 0.12 (3.0) | 0.05 (1.2) | 0.04 (1.0) | 0.06 (1.5) | 0.04 (1.0) |
| tailfib | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.01 | 0.01 |
| even-odd | 0.06 (6.0) | 0.03 (3.0) | 0.04 (4.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.01 (1.0) |
| merge | 0.12 (2.0) | 0.05 (0.8) | 0.11 (1.8) | 0.06 (1.0) | 0.06 (1.0) | 0.07 (1.2) | 0.06 (1.0) |
| tailmerge | 0.13 (2.2) | 0.05 (0.8) | 0.10 (1.7) | 0.05 (0.8) | 0.06 (1.0) | 0.07 (1.2) | 0.06 (1.0) |
| imp-for | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) |
| vector-rev | 0.08 (2.0) | 0.03 (0.8) | 0.06 (1.5) | 0.03 (0.8) | 0.04 (1.0) | 0.04 (1.0) | 0.04 (1.0) |
| vector32-concat | 0.04 (2.0) | 0.01 (0.5) | 0.03 (1.5) | 0.02 (1.0) | 0.02 (1.0) | 0.03 (1.5) | 0.03 (1.5) |
| vector64-concat | 0.03 (1.5) | 0.01 (0.5) | 0.03 (1.5) | 0.02 (1.0) | 0.02 (1.0) | 0.03 (1.5) | 0.03 (1.5) |
| string-concat | 0.03 (3.0) | 0.01 (1.0) | 0.02 (2.0) | 0.02 (2.0) | 0.01 (1.0) | 0.02 (2.0) | 0.02 (2.0) |
| wc-input1 | 0.26 (2.6) | 0.11 (1.1) | 0.20 (2.0) | 0.09 (0.9) | 0.10 (1.0) | 0.10 (1.0) | 0.10 (1.0) |
| wc-scanStream | 0.24 (2.4) | 0.10 (1.0) | 0.20 (2.0) | 0.10 (1.0) | 0.10 (1.0) | 0.10 (1.0) | 0.09 (0.9) |
| checksum | 1.99 (3.4) | 0.91 (1.6) | 1.54 (2.7) | 0.73 (1.3) | 0.58 (1.0) | 0.77 (1.3) | 0.60 (1.0) |
| boyer | 0.50 (1.9) | 0.23 (0.9) | 0.47 (1.8) | 0.24 (0.9) | 0.26 (1.0) | 0.22 (0.8) | 0.23 (0.9) |
| nucleic | 0.61 (4.7) | 0.19 (1.5) | 0.49 (3.8) | 0.18 (1.4) | 0.13 (1.0) | 0.18 (1.4) | 0.14 (1.1) |
| life | 0.56 (2.3) | 0.29 (1.2) | 0.53 (2.2) | 0.29 (1.2) | 0.24 (1.0) | 0.29 (1.2) | 0.23 (1.0) |
| matrix-multiply | 0.06 (6.0) | 0.01 (1.0) | 0.04 (4.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.02 (2.0) |
| md5 | 0.06 (3.0) | 0.02 (1.0) | 0.04 (2.0) | 0.02 (1.0) | 0.02 (1.0) | 0.03 (1.5) | 0.02 (1.0) |
| fft | 0.08 (4.0) | 0.02 (1.0) | 0.05 (2.5) | 0.02 (1.0) | 0.02 (1.0) | 0.03 (1.5) | 0.02 (1.0) |
| binary-trees | 0.08 (2.7) | 0.03 (1.0) | 0.07 (2.3) | 0.03 (1.0) | 0.03 (1.0) | 0.04 (1.3) | 0.03 (1.0) |
| flat-array | 2.81 (2.1) | 1.48 (1.1) | 2.35 (1.7) | 1.54 (1.1) | 1.36 (1.0) | 1.35 (1.0) | 1.43 (1.1) |
| peek | 15.51 (3.5) | 5.22 (1.2) | 15.43 (3.5) | 5.81 (1.3) | 4.41 (1.0) | 5.84 (1.3) | 4.64 (1.1) |
| psdes-random | 0.88 (4.4) | 0.29 (1.4) | 0.61 (3.0) | 0.25 (1.2) | 0.20 (1.0) | 0.26 (1.3) | 0.20 (1.0) |
| mandelbrot | 0.27 (6.8) | 0.11 (2.8) | 0.17 (4.2) | 0.08 (2.0) | 0.04 (1.0) | 0.08 (2.0) | 0.05 (1.2) |
| pidigits | 16.79 (2.8) | 7.61 (1.3) | 13.02 (2.2) | 6.57 (1.1) | 5.99 (1.0) | 6.68 (1.1) | 6.16 (1.0) |
| logic | 19.24 (2.9) | 8.23 (1.2) | 16.73 (2.5) | 7.45 (1.1) | 6.70 (1.0) | 7.62 (1.1) | 6.90 (1.0) |
| zebra | 2.65 (2.8) | 1.06 (1.1) | 2.53 (2.7) | 1.10 (1.2) | 0.95 (1.0) | 1.13 (1.2) | 1.24 (1.3) |
| count-graphs | 0.22 (2.8) | 0.10 (1.2) | 0.19 (2.4) | 0.08 (1.0) | 0.08 (1.0) | 0.10 (1.2) | 0.12 (1.5) |
| many_refs | 2.96 (3.7) | 1.49 (1.8) | 2.44 (3.0) | 1.26 (1.6) | 0.81 (1.0) | 1.37 (1.7) | 0.93 (1.1) |
| tensor | 7.02 (2.7) | 3.08 (1.2) | 6.50 (2.5) | 2.94 (1.1) | 2.61 (1.0) | 3.01 (1.2) | 2.87 (1.1) |
| zern | 0.15 (1.7) | 0.09 (1.0) | 0.14 (1.6) | 0.09 (1.0) | 0.09 (1.0) | 0.10 (1.1) | 0.09 (1.0) |
| smith-normal-form | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.02 (2.0) |
| ratio-regions | 0.29 (3.6) | 0.10 (1.2) | 0.20 (2.5) | 0.10 (1.2) | 0.08 (1.0) | 0.10 (1.2) | 0.09 (1.1) |
| mpuz | 148.47 (3.1) | 64.54 (1.3) | 141.62 (2.9) | 57.61 (1.2) | 48.53 (1.0) | 58.05 (1.2) | 52.53 (1.1) |
| DLXSimulator | 102.37 (2.9) | 45.76 (1.3) | 90.87 (2.5) | 42.08 (1.2) | 35.66 (1.0) | 42.04 (1.2) | 39.85 (1.1) |
| knuth-bendix | 4.04 (2.1) | 2.15 (1.1) | 4.59 (2.4) | 2.09 (1.1) | 1.94 (1.0) | 2.08 (1.1) | 2.21 (1.1) |
| tyan | 3.22 (3.4) | 1.07 (1.1) | 2.93 (3.1) | 1.07 (1.1) | 0.94 (1.0) | 1.02 (1.1) | 1.01 (1.1) |
| lexgen | 0.76 (2.3) | 0.32 (1.0) | 0.80 (2.4) | 0.35 (1.1) | 0.33 (1.0) | 0.38 (1.2) | 0.38 (1.2) |
| mlyacc | 0.45 (2.5) | 0.17 (0.9) | 0.42 (2.3) | 0.20 (1.1) | 0.18 (1.0) | 0.19 (1.1) | 0.28 (1.6) |
| hamlet | 0.04 (0.6) | 0.02 (0.3) | 0.05 (0.7) | 0.05 (0.7) | 0.07 (1.0) | 0.11 (1.6) | 0.16 (2.3) |
| kitfib35 | 1.77 (3.2) | 0.86 (1.5) | 2.22 (4.0) | 0.85 (1.5) | 0.56 (1.0) | 0.87 (1.6) | 0.72 (1.3) |
| fib0 | 0.12 (3.0) | 0.05 (1.2) | 0.14 (3.5) | 0.05 (1.2) | 0.04 (1.0) | 0.06 (1.5) | 0.05 (1.2) |
| kitreynolds2 | 0.63 (2.2) | 0.27 (1.0) | 0.64 (2.3) | 0.29 (1.0) | 0.28 (1.0) | 0.31 (1.1) | 0.30 (1.1) |
| kitreynolds3 | 0.81 (4.8) | 0.23 (1.4) | 0.65 (3.8) | 0.20 (1.2) | 0.17 (1.0) | 0.21 (1.2) | 0.19 (1.1) |
| kitloop2 | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) |
| kitdangle | 0.10 (1.7) | 0.05 (0.8) | 0.13 (2.2) | 0.06 (1.0) | 0.06 (1.0) | 0.07 (1.2) | 0.07 (1.2) |
| kitdangle3 | 0.30 (1.9) | 0.15 (0.9) | 0.36 (2.2) | 0.19 (1.2) | 0.16 (1.0) | 0.18 (1.1) | 0.18 (1.1) |
| msort | 0.17 (1.5) | 0.09 (0.8) | 0.17 (1.5) | 0.11 (1.0) | 0.11 (1.0) | 0.12 (1.1) | 0.10 (0.9) |
| kittmergesort_tp | 3.81 (2.5) | 1.71 (1.1) | 3.76 (2.4) | 1.75 (1.1) | 1.54 (1.0) | 1.70 (1.1) | 1.92 (1.2) |
| barnes-hut | 1.84 (3.5) | 0.74 (1.4) | 1.77 (3.4) | 0.66 (1.3) | 0.52 (1.0) | 0.70 (1.3) | 0.67 (1.3) |
| tsp | 0.04 (1.3) | 0.02 (0.7) | 0.04 (1.3) | 0.03 (1.0) | 0.03 (1.0) | 0.03 (1.0) | 0.03 (1.0) |
| fannkuch | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) |
| f-arith | 0.07 (7.0) | 0.03 (3.0) | 0.05 (5.0) | 0.02 (2.0) | 0.01 (1.0) | 0.03 (3.0) | 0.02 (2.0) |
| stream-sieve | 0.10 (1.7) | 0.05 (0.8) | 0.10 (1.7) | 0.06 (1.0) | 0.06 (1.0) | 0.06 (1.0) | 0.08 (1.3) |
| twenty-four | 0.68 (2.1) | 0.37 (1.2) | 0.97 (3.0) | 0.35 (1.1) | 0.32 (1.0) | 0.38 (1.2) | 0.41 (1.3) |
| simple | 2.32 (2.9) | 0.95 (1.2) | 2.04 (2.6) | 0.96 (1.2) | 0.79 (1.0) | 0.92 (1.2) | 1.01 (1.3) |
| nbody | 6.45 (4.2) | 2.91 (1.9) | 5.35 (3.5) | 2.07 (1.3) | 1.54 (1.0) | 1.94 (1.3) | 1.82 (1.2) |
| output1 | 0.48 (2.7) | 0.22 (1.2) | 0.43 (2.4) | 0.22 (1.2) | 0.18 (1.0) | 0.26 (1.4) | 0.27 (1.5) |
| ray | 1.10 (3.4) | 0.43 (1.3) | 0.95 (3.0) | 0.41 (1.3) | 0.32 (1.0) | 0.39 (1.2) | 0.42 (1.3) |
| raytrace | 10.32 (5.5) | 3.01 (1.6) | 9.20 (4.9) | 2.77 (1.5) | 1.88 (1.0) | 2.79 (1.5) | 2.60 (1.4) |
| vliw | 0.62 (2.4) | 0.27 (1.0) | 0.63 (2.4) | 0.30 (1.2) | 0.26 (1.0) | 0.30 (1.2) | 0.35 (1.3) |
| fxp | 1.25 (2.9) | 0.50 (1.2) | 1.26 (2.9) | 0.48 (1.1) | 0.43 (1.0) | 0.56 (1.3) | 0.75 (1.7) |
| model-elimination | 97.53 (2.3) | 48.47 (1.1) | 105.44 (2.5) | 46.89 (1.1) | 42.84 (1.0) | 47.33 (1.1) | 52.16 (1.2) |
| sat | 2.43 (3.6) | 0.93 (1.4) | 1.86 (2.7) | 0.85 (1.2) | 0.68 (1.0) | 0.85 (1.2) | 0.79 (1.2) |
| boyer-smlnj | 5.31 (2.5) | 2.25 (1.1) | 4.88 (2.3) | 2.33 (1.1) | 2.09 (1.0) | 2.23 (1.1) | 2.92 (1.4) |
| logic-smlnj | 129.52 (2.6) | 58.44 (1.2) | 109.51 (2.2) | 53.70 (1.1) | 49.63 (1.0) | 53.05 (1.1) | 58.06 (1.2) |
| life-smlnj | 19.95 (2.1) | 10.78 (1.1) | 20.15 (2.1) | 11.05 (1.2) | 9.50 (1.0) | 10.94 (1.2) | 11.64 (1.2) |
| minimax | 16.74 (2.5) | 7.40 (1.1) | 14.68 (2.2) | 6.91 (1.0) | 6.78 (1.0) | 6.90 (1.0) | 7.37 (1.1) |
| iter-pidigits | 9.48 (2.9) | 3.98 (1.2) | 6.77 (2.1) | 3.29 (1.0) | 3.22 (1.0) | 3.38 (1.0) | 3.76 (1.2) |
| mazefun | 1.55 (3.3) | 0.56 (1.2) | 1.24 (2.6) | 0.48 (1.0) | 0.47 (1.0) | 0.54 (1.1) | 0.48 (1.0) |
| queens-lazy | 0.15 (7.5) | 0.03 (1.5) | 0.09 (4.5) | 0.03 (1.5) | 0.02 (1.0) | 0.04 (2.0) | 0.03 (1.5) |
| queens-strict | 0.16 (4.0) | 0.05 (1.2) | 0.13 (3.2) | 0.06 (1.5) | 0.04 (1.0) | 0.06 (1.5) | 0.06 (1.5) |
| nqueens | 0.11 (3.7) | 0.03 (1.0) | 0.09 (3.0) | 0.03 (1.0) | 0.03 (1.0) | 0.03 (1.0) | 0.03 (1.0) |
| rec_seq_ack | 0.25 (4.2) | 0.07 (1.2) | 0.19 (3.2) | 0.07 (1.2) | 0.06 (1.0) | 0.07 (1.2) | 0.07 (1.2) |
| klife_eq | 0.48 (2.2) | 0.22 (1.0) | 0.43 (2.0) | 0.19 (0.9) | 0.22 (1.0) | 0.22 (1.0) | 0.23 (1.0) |
| kitlife35u_smlnj | 0.85 (5.0) | 0.27 (1.6) | 0.62 (3.6) | 0.26 (1.5) | 0.17 (1.0) | 0.26 (1.5) | 0.20 (1.2) |
| kitqsort_no_basislib | 0.11 (1.6) | 0.06 (0.9) | 0.09 (1.3) | 0.07 (1.0) | 0.07 (1.0) | 0.07 (1.0) | 0.08 (1.1) |
| tailfib-mlkit | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.01 | 0.01 |
| tak-mlkit | 0.25 (4.2) | 0.06 (1.0) | 0.18 (3.0) | 0.07 (1.2) | 0.06 (1.0) | 0.07 (1.2) | 0.08 (1.3) |
| matrix-multiply-mlkit | 0.89 (5.6) | 0.18 (1.1) | 0.53 (3.3) | 0.16 (1.0) | 0.16 (1.0) | 0.20 (1.2) | 0.15 (0.9) |
| vector-rev-mlkit | 0.14 (2.8) | 0.05 (1.0) | 0.08 (1.6) | 0.04 (0.8) | 0.05 (1.0) | 0.07 (1.4) | 0.05 (1.0) |
| vector-rev_smlnj | 0.09 (2.2) | 0.04 (1.0) | 0.07 (1.8) | 0.04 (1.0) | 0.04 (1.0) | 0.05 (1.2) | 0.04 (1.0) |
| vector-concat | 0.02 (2.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.02 (2.0) |
| vector-concat_smlnj | 0.15 (2.5) | 0.05 (0.8) | 0.11 (1.8) | 0.05 (0.8) | 0.06 (1.0) | 0.08 (1.3) | 0.06 (1.0) |
| peek-mlkit | 0.09 (4.5) | 0.03 (1.5) | 0.07 (3.5) | 0.03 (1.5) | 0.02 (1.0) | 0.04 (2.0) | 0.03 (1.5) |
| wc-input1-mlkit | 0.16 (2.7) | 0.09 (1.5) | 0.11 (1.8) | 0.06 (1.0) | 0.06 (1.0) | 0.09 (1.5) | 0.07 (1.2) |
| wc-scanStream-mlkit | 0.16 (2.7) | 0.06 (1.0) | 0.12 (2.0) | 0.06 (1.0) | 0.06 (1.0) | 0.07 (1.2) | 0.06 (1.0) |
| psdes-random-mlkit | 0.09 (4.5) | 0.03 (1.5) | 0.06 (3.0) | 0.03 (1.5) | 0.02 (1.0) | 0.04 (2.0) | 0.03 (1.5) |
| safe-for-space | 0.30 (2.1) | 0.13 (0.9) | 0.25 (1.8) | 0.15 (1.1) | 0.14 (1.0) | 0.17 (1.2) | 0.16 (1.1) |
| pidigits-smlnj | 8.95 (2.9) | 3.94 (1.3) | 6.56 (2.1) | 3.32 (1.1) | 3.12 (1.0) | 3.40 (1.1) | 3.20 (1.0) |
| fft-smlnj | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.02 (2.0) |
| nucleic-smlnj | 0.66 (4.7) | 0.21 (1.5) | 0.47 (3.4) | 0.20 (1.4) | 0.14 (1.0) | 0.20 (1.4) | 0.18 (1.3) |
| count-graphs-smlnj | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.03 (3.0) |
| matrix-multiply-ramp | 0.05 (2.5) | 0.02 (1.0) | 0.04 (2.0) | 0.02 (1.0) | 0.02 (1.0) | 0.03 (1.5) | 0.06 (3.0) |
| kitreynolds2_no_basislib | 0.03 (1.5) | 0.01 (0.5) | 0.03 (1.5) | 0.02 (1.0) | 0.02 (1.0) | 0.02 (1.0) | 0.04 (2.0) |
| kitreynolds3_no_basislib | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.01 | 0.01 |
| kittmergesort_no_basislib | 0.09 (2.2) | 0.05 (1.2) | 0.08 (2.0) | 0.05 (1.2) | 0.04 (1.0) | 0.06 (1.5) | 0.07 (1.8) |
| hanoi | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.01 | 0.01 |
| fib-mlkit | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.01 | 0.01 |
| mandelbrot-smlnj | 0.57 (19.0) | 0.16 (5.3) | 0.31 (10.3) | 0.09 (3.0) | 0.03 (1.0) | 0.10 (3.3) | 0.05 (1.7) |
| mandelbrot-rat | 219.66 (4.0) | 73.59 (1.3) | 149.92 (2.7) | 66.47 (1.2) | 55.59 (1.0) | 67.35 (1.2) | 70.56 (1.3) |
| kitmandelbrot | 0.01 | 0.00 | 0.01 | 0.00 | 0.00 | 0.01 | 0.01 |
| FuhMishra | 0.05 (1.2) | 0.03 (0.8) | 0.05 (1.2) | 0.04 (1.0) | 0.04 (1.0) | 0.04 (1.0) | 0.06 (1.5) |
| black-scholes | 0.19 (2.7) | 0.08 (1.1) | 0.17 (2.4) | 0.08 (1.1) | 0.07 (1.0) | 0.10 (1.4) | 0.10 (1.4) |
| professor2 | 0.29 (2.9) | 0.11 (1.1) | 0.25 (2.5) | 0.11 (1.1) | 0.10 (1.0) | 0.12 (1.2) | 0.13 (1.3) |
| professor2_tp | 0.27 (2.7) | 0.11 (1.1) | 0.26 (2.6) | 0.12 (1.2) | 0.10 (1.0) | 0.13 (1.3) | 0.14 (1.4) |
| professor_game | 0.28 (2.8) | 0.10 (1.0) | 0.25 (2.5) | 0.12 (1.2) | 0.10 (1.0) | 0.12 (1.2) | 0.14 (1.4) |
| professor_game-mlkit | 0.29 (2.9) | 0.11 (1.1) | 0.25 (2.5) | 0.13 (1.3) | 0.10 (1.0) | 0.14 (1.4) | 0.15 (1.5) |
| professor_game_debug | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.01 | 0.01 |
| kkb_eq | 1.01 (1.9) | 0.52 (1.0) | 0.98 (1.9) | 0.54 (1.0) | 0.52 (1.0) | 0.53 (1.0) | 0.69 (1.3) |
| kitkbjul9_smlnj | 1.01 (1.9) | 0.50 (0.9) | 0.96 (1.8) | 0.53 (1.0) | 0.53 (1.0) | 0.51 (1.0) | 0.75 (1.4) |
| kkb36c_smlnj | 1.03 (2.2) | 0.49 (1.0) | 0.97 (2.1) | 0.54 (1.1) | 0.47 (1.0) | 0.54 (1.1) | 0.67 (1.4) |
| ratio-regions-mlkit | 0.25 (3.1) | 0.10 (1.2) | 0.20 (2.5) | 0.10 (1.2) | 0.08 (1.0) | 0.10 (1.2) | 0.13 (1.6) |
| ratio-regions_tp | 1.07 (3.8) | 0.38 (1.4) | 0.78 (2.8) | 0.37 (1.3) | 0.28 (1.0) | 0.38 (1.4) | 0.39 (1.4) |
| ratio-regions-smlnj | 0.25 (3.1) | 0.09 (1.1) | 0.21 (2.6) | 0.10 (1.2) | 0.08 (1.0) | 0.11 (1.4) | 0.12 (1.5) |
| count-graphs-mlkit | 0.06 (3.0) | 0.03 (1.5) | 0.04 (2.0) | 0.03 (1.5) | 0.02 (1.0) | 0.03 (1.5) | 0.04 (2.0) |
| mpuz-mlkit | 15.25 (3.2) | 6.31 (1.3) | 12.62 (2.6) | 5.73 (1.2) | 4.82 (1.0) | 5.84 (1.2) | 6.06 (1.3) |
| knuth-bendix-smlnj | 1.18 (1.8) | 0.67 (1.0) | 1.24 (1.9) | 0.70 (1.1) | 0.64 (1.0) | 0.72 (1.1) | 0.86 (1.3) |
| tyan-smlnj | 4.62 (3.4) | 1.59 (1.2) | 3.88 (2.8) | 1.57 (1.1) | 1.37 (1.0) | 1.54 (1.1) | 1.93 (1.4) |
| tyan-mlkit | 3.02 (3.2) | 1.08 (1.2) | 2.48 (2.7) | 1.07 (1.2) | 0.93 (1.0) | 1.05 (1.1) | 1.19 (1.3) |
| smith-normal-form-mlkit | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.02 (2.0) |
| smith-nf | 0.01 (1.0) | 0.00 (0.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.03 (3.0) |
| lexgen-smlnj | 0.54 (2.6) | 0.23 (1.1) | 0.46 (2.2) | 0.24 (1.1) | 0.21 (1.0) | 0.27 (1.3) | 0.25 (1.2) |
| mlyacc-smlnj | 0.25 (2.3) | 0.11 (1.0) | 0.23 (2.1) | 0.14 (1.3) | 0.11 (1.0) | 0.15 (1.4) | 0.14 (1.3) |
| kitsimple | 0.07 (2.3) | 0.02 (0.7) | 0.05 (1.7) | 0.03 (1.0) | 0.03 (1.0) | 0.04 (1.3) | 0.04 (1.3) |
| kitsimple_tp | 0.20 (3.3) | 0.07 (1.2) | 0.16 (2.7) | 0.08 (1.3) | 0.06 (1.0) | 0.08 (1.3) | 0.07 (1.2) |
| kitsimple_no_basislib | 0.07 (2.3) | 0.02 (0.7) | 0.06 (2.0) | 0.03 (1.0) | 0.03 (1.0) | 0.04 (1.3) | 0.04 (1.3) |
| simple-smlnj | 0.20 (2.9) | 0.07 (1.0) | 0.18 (2.6) | 0.08 (1.1) | 0.07 (1.0) | 0.09 (1.3) | 0.09 (1.3) |
| tsp-smlnj | 0.02 (2.0) | 0.01 (1.0) | 0.02 (2.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.02 (2.0) |
| DLXSimulator-mlkit | 0.19 (1.9) | 0.10 (1.0) | 0.20 (2.0) | 0.11 (1.1) | 0.10 (1.0) | 0.13 (1.3) | 0.13 (1.3) |
| aobench | 0.78 (3.4) | 0.33 (1.4) | 0.63 (2.7) | 0.30 (1.3) | 0.23 (1.0) | 0.32 (1.4) | 0.27 (1.2) |
| id-ray | 22.42 (3.2) | 9.20 (1.3) | 19.37 (2.8) | 8.27 (1.2) | 6.95 (1.0) | 8.43 (1.2) | 7.40 (1.1) |
| plclub-ray | 0.30 (4.3) | 0.09 (1.3) | 0.22 (3.1) | 0.09 (1.3) | 0.07 (1.0) | 0.11 (1.6) | 0.10 (1.4) |
| mc-ray | 3.24 (4.2) | 1.27 (1.6) | 2.48 (3.2) | 1.07 (1.4) | 0.77 (1.0) | 1.09 (1.4) | 0.77 (1.0) |
| ray-smlnj | 0.15 (3.8) | 0.06 (1.5) | 0.12 (3.0) | 0.06 (1.5) | 0.04 (1.0) | 0.07 (1.8) | 0.05 (1.2) |
| kitmolgard | 0.18 (3.0) | 0.07 (1.2) | 0.14 (2.3) | 0.07 (1.2) | 0.06 (1.0) | 0.09 (1.5) | 0.09 (1.5) |
| vliw-smlnj | 1.08 (2.5) | 0.45 (1.0) | 0.93 (2.1) | 0.46 (1.0) | 0.44 (1.0) | 0.50 (1.1) | 0.43 (1.0) |
| rfib | 0.04 (2.0) | 0.02 (1.0) | 0.04 (2.0) | 0.02 (1.0) | 0.02 (1.0) | 0.03 (1.5) | 0.02 (1.0) |
| tak-nofib-lazy | 0.02 (2.0) | 0.01 (1.0) | 0.02 (2.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.02 (2.0) |
| tak-nofib-strict | 0.00 | 0.00 | 0.00 | 0.00 | 0.00 | 0.01 | 0.01 |
| exp3_8-lazy | 1.34 (1.6) | 0.72 (0.9) | 1.41 (1.7) | 0.80 (1.0) | 0.83 (1.0) | 0.80 (1.0) | 0.80 (1.0) |
| exp3_8-strict | 0.27 (1.7) | 0.14 (0.9) | 0.30 (1.9) | 0.17 (1.1) | 0.16 (1.0) | 0.17 (1.1) | 0.19 (1.2) |
| digits-of-e1-lazy | 3.29 (3.0) | 1.27 (1.2) | 2.79 (2.5) | 1.22 (1.1) | 1.10 (1.0) | 1.19 (1.1) | 1.11 (1.0) |
| digits-of-e2-lazy | 7.38 (3.0) | 2.84 (1.2) | 5.95 (2.4) | 2.77 (1.1) | 2.46 (1.0) | 2.77 (1.1) | 2.45 (1.0) |

Two rows are worth reading on their own. The counts are from the bytecode
this run compiled: the function table of each image, and a decode of every
instruction. The native-host tables follow these notes.

### `hamlet`

`hamlet` is Andreas Rossberg's HaMLet, an interpreter for Standard ML,
including the parser ml-yacc generated, in
`examples/benchmarks/hamlet/benchmark.sml` (22,907 lines). The normal input
runs it once on `DATA/normal.sml`, nine lines of Peano arithmetic computing
`(4^2)^2`. The result is 256.

The image has 1608 functions in either bytecode. The register code is
585752 bytes. The median function is 161 bytes, 1071 functions are under
200 bytes and 580 are under 100. `Parse.LrVals` is 125138 bytes in 38
functions, and `Parse.LrVals.ParserData.Actions.actions` alone is 115412
bytes with 18 locals. `Parse.Lexer` is 23352 bytes in 26 functions. The
stack code is 432004 bytes, and that same actions function is 103917 bytes
with 11 locals. The call sites match: 653 `CALL`, 56 `TAILCALL`, 2513
`CALLK`, 1151 `TAILCALLK`, 970 `CLOSURE` and 3026 `PRIM`. The register
image has 48560 instructions and the stack image 79452. The difference is
mostly locals: 1867 `MOVE` against 24091 `LOCAL`, 10185 `SETLOCAL` and
1438 `TEELOCAL`.

The work inside the timer is that one evaluation. `rune` takes 0.04 s
(fresh samples 0.04, 0.04, 0.04) and `rune:new off` takes 0.05 s (0.04,
0.05, 0.05). `rune:opt` takes 0.02 s, all three samples: `runeopt` has
translated the bytecode before GNU time starts. `rune:new opt` takes 0.07 s,
`all` 0.11 s and `all+t2` 0.16 s. The fresh samples of `all` are 0.11, 0.12
and 0.11, and of `all+t2` 0.14, 0.16 and 0.18. Those two ranges sit clear
of the interpreter samples.

`--jit=all` compiles every function when the program is loaded.
`runtime/register/jit.c` calls `jit_tier_up` across the function table, and that
compile is part of the fresh process the table times. `all` compiles each
of the 1608 functions at tier 1. `all+t2` compiles each at tier 2, the
larger compile, and that cell is the slowest. `opt` compiles a function
when its counters say it is hot. On one evaluation of 256 the median is
0.02 s above `off`, and the fresh samples of the two still meet (0.05 on
both). The two interpreters land within 0.01 s. `twenty-four` is the
program where the wider register frames have a run long enough to see.

### `twenty-four`

`twenty-four` counts the ways to make 24. The normal input takes every
4-card combination from 1 to 10, 210 hands, and counts solutions through
the continuation passed to `TwentyFour.solve`
(`examples/benchmarks/twenty-four/benchmark.sml`). It does this once. The
expected total is 9603. The search is tail calls and `Real` arithmetic.

Both images have 161 functions and the same call sites: 45 `CALL`, 17
`TAILCALL`, 223 `CALLK`, 46 `TAILCALLK`, 84 `CLOSURE` and 478 `PRIM`. The
stack bytecode is 5337 instructions and 27509 bytes, 1926 of them `LOCAL`,
`SETLOCAL` or `TEELOCAL`. The register bytecode is 3819 instructions and
42607 bytes, with 150 `MOVE`. A register frame keeps every local for the
whole function, so the search frames are wider. The columns are `nlocals`
in the stack bytecode and in the register bytecode:

| Function | stack | register |
|---|---:|---:|
| `TwentyFour.eval` | 3 | 8 |
| `TwentyFour.split` | 4 | 13 |
| `TwentyFour.p` | 5 | 12 |
| `TwentyFour.allTrees` | 4 | 10 |
| `TwentyFour.insert` | 6 | 9 |
| `TwentyFour.permutations` | 4 | 7 |
| `TwentyFour.solve` | 3 | 6 |
| `Benchmark.allHands` | 2 | 11 |
| `Benchmark.one` | 1 | 4 |

A register `TAILCALLK` reads the arguments out of those registers into a
side buffer, moves them into the callee's frame and fills every remaining
local with unit (`runtime/register/reg_cases.h`). The stack `TAILCALLK` moves the
arguments from the operand stack into a smaller frame and fills what that
frame still has empty (`runtime/stack/interp_cases.h`). A value is 16 bytes in both.
`rune:new off` takes 0.97 s where `rune` takes 0.68 s. The fresh samples
are 0.90, 1.05, 0.97 and 0.68, 0.64, 0.72. The slower stack sample is
0.72 s and the faster register sample is 0.90 s.

The JIT takes that work out of the interpreter. `rune:new baseline` takes
0.35 s and `rune:new opt` 0.32 s, under `rune:opt` at 0.37 s. `all` takes
0.38 s and `all+t2` 0.41 s. Those two compile every function at load, as
`hamlet` does, here across 161 functions. The fresh samples sit above
`opt`: 0.35, 0.38, 0.38 and 0.41, 0.43, 0.41, against 0.32, 0.32, 0.33.

The hosts, each on its own Basis Library. The first column is `rune:new opt`
from the table above. In parentheses: the time divided by that column. Where
that column is 0.00 the ratio is omitted. `n/a` means the host did not compile
the program, or the program failed its own check, so there is no median of
three fresh runs.

SML/NJ 110.99.9, 64 bits has no time for `barnes-hut`, `black-scholes`,
`tsp-smlnj`, `aobench` and `id-ray`. SML/NJ 110.99.9, 32 bits has none for
`tsp-smlnj`, `aobench`, `mc-ray` and `id-ray`. SML/NJ 2026.2 has none for
`id-ray`. Poly/ML 5.9.2 has none for `vector64-concat` and `peek`, where
`Int64` is not declared, and for `id-ray`. On every SML/NJ column and on
Poly/ML, `id-ray` opens `DATA/spheres.txt` while the source is elaborated.
MLKit 4.7.23 did not compile `boyer`, `boyer-smlnj`, `knuth-bendix`,
`knuth-bendix-smlnj`, `tyan`, `tyan-smlnj` and `tyan-mlkit`, and failed its
check on `raytrace`, `mandelbrot-rat` and `plclub-ray`. MLton passed all 149.

| Program | rune:new opt | native:mlton | native:smlnj-legacy | native:smlnj32 | native:smlnj-dev | native:polyml | native:mlkit |
|---|---:|---:|---:|---:|---:|---:|---:|
| tak | 0.24 (1.0) | 0.06 (0.2) | 0.10 (0.4) | 0.12 (0.5) | 0.13 (0.5) | 0.05 (0.2) | 0.18 (0.8) |
| kittmergesort | 0.09 (1.0) | 0.04 (0.4) | 0.05 (0.6) | 0.04 (0.4) | 0.05 (0.6) | 0.03 (0.3) | 0.05 (0.6) |
| primes-lazy | 0.06 (1.0) | 0.01 (0.2) | 0.05 (0.8) | 0.04 (0.7) | 0.05 (0.8) | 0.04 (0.7) | 0.03 (0.5) |
| primes-strict | 0.60 (1.0) | 0.26 (0.4) | 0.38 (0.6) | 0.20 (0.3) | 0.35 (0.6) | 0.27 (0.5) | 0.35 (0.6) |
| bdd | 0.11 (1.0) | 0.02 (0.2) | 0.06 (0.5) | 0.05 (0.5) | 0.06 (0.5) | 0.03 (0.3) | 0.04 (0.4) |
| fib | 0.04 (1.0) | 0.01 (0.2) | 0.02 (0.5) | 0.02 (0.5) | 0.03 (0.8) | 0.01 (0.2) | 0.02 (0.5) |
| tailfib | 0.00 | 0.00 | 0.01 | 0.01 | 0.01 | 0.00 | 0.00 |
| even-odd | 0.01 (1.0) | 0.00 (0.0) | 0.02 (2.0) | 0.02 (2.0) | 0.02 (2.0) | 0.00 (0.0) | 0.00 (0.0) |
| merge | 0.06 (1.0) | 0.01 (0.2) | 0.03 (0.5) | 0.02 (0.3) | 0.03 (0.5) | 0.01 (0.2) | 0.02 (0.3) |
| tailmerge | 0.06 (1.0) | 0.01 (0.2) | 0.02 (0.3) | 0.02 (0.3) | 0.04 (0.7) | 0.01 (0.2) | 0.02 (0.3) |
| imp-for | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.03 (3.0) | 0.00 (0.0) | 0.00 (0.0) |
| vector-rev | 0.04 (1.0) | 0.00 (0.0) | 0.02 (0.5) | 0.02 (0.5) | 0.03 (0.8) | 0.00 (0.0) | 0.01 (0.2) |
| vector32-concat | 0.02 (1.0) | 0.00 (0.0) | 0.02 (1.0) | 0.01 (0.5) | 0.03 (1.5) | 0.00 (0.0) | 0.00 (0.0) |
| vector64-concat | 0.02 (1.0) | 0.00 (0.0) | 0.02 (1.0) | 0.02 (1.0) | 0.03 (1.5) | n/a | 0.00 (0.0) |
| string-concat | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.00 (0.0) | 0.00 (0.0) |
| wc-input1 | 0.10 (1.0) | 0.01 (0.1) | 0.05 (0.5) | 0.04 (0.4) | 0.06 (0.6) | 0.07 (0.7) | 0.03 (0.3) |
| wc-scanStream | 0.10 (1.0) | 0.01 (0.1) | 0.04 (0.4) | 0.03 (0.3) | 0.04 (0.4) | 0.04 (0.4) | 0.10 (1.0) |
| checksum | 0.58 (1.0) | 0.00 (0.0) | 0.06 (0.1) | 0.08 (0.1) | 0.06 (0.1) | 0.03 (0.1) | 0.09 (0.2) |
| boyer | 0.26 (1.0) | 0.07 (0.3) | 0.11 (0.4) | 0.12 (0.5) | 0.12 (0.5) | 0.09 (0.3) | n/a |
| nucleic | 0.13 (1.0) | 0.03 (0.2) | 0.07 (0.5) | 0.06 (0.5) | 0.07 (0.5) | 0.12 (0.9) | 0.06 (0.5) |
| life | 0.24 (1.0) | 0.02 (0.1) | 0.18 (0.8) | 0.20 (0.8) | 0.17 (0.7) | 0.02 (0.1) | 0.06 (0.2) |
| matrix-multiply | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.00 (0.0) | 0.00 (0.0) |
| md5 | 0.02 (1.0) | 0.00 (0.0) | 0.01 (0.5) | 0.01 (0.5) | 0.02 (1.0) | 0.00 (0.0) | 0.00 (0.0) |
| fft | 0.02 (1.0) | 0.00 (0.0) | 0.03 (1.5) | 0.03 (1.5) | 0.04 (2.0) | 0.02 (1.0) | 0.02 (1.0) |
| binary-trees | 0.03 (1.0) | 0.00 (0.0) | 0.02 (0.7) | 0.02 (0.7) | 0.02 (0.7) | 0.01 (0.3) | 0.02 (0.7) |
| flat-array | 1.36 (1.0) | 0.02 (0.0) | 0.91 (0.7) | 0.74 (0.5) | 1.20 (0.9) | 0.47 (0.3) | 0.27 (0.2) |
| peek | 4.41 (1.0) | 0.22 (0.0) | 0.76 (0.2) | 1.21 (0.3) | 0.76 (0.2) | n/a | 3.40 (0.8) |
| psdes-random | 0.20 (1.0) | 0.01 (0.0) | 0.08 (0.4) | 0.05 (0.2) | 0.09 (0.4) | 0.04 (0.2) | 0.15 (0.7) |
| mandelbrot | 0.04 (1.0) | 0.01 (0.2) | 0.02 (0.5) | 0.02 (0.5) | 0.02 (0.5) | 0.04 (1.0) | 0.02 (0.5) |
| pidigits | 5.99 (1.0) | 0.00 (0.0) | 0.02 (0.0) | 0.03 (0.0) | 0.03 (0.0) | 0.00 (0.0) | 0.08 (0.0) |
| logic | 6.70 (1.0) | 1.42 (0.2) | 2.06 (0.3) | 2.06 (0.3) | 2.00 (0.3) | 1.63 (0.2) | 5.35 (0.8) |
| zebra | 0.95 (1.0) | 0.05 (0.1) | 0.58 (0.6) | 0.64 (0.7) | 0.54 (0.6) | 0.10 (0.1) | 0.48 (0.5) |
| count-graphs | 0.08 (1.0) | 0.00 (0.0) | 0.02 (0.2) | 0.03 (0.4) | 0.03 (0.4) | 0.02 (0.2) | 0.03 (0.4) |
| many_refs | 0.81 (1.0) | 0.03 (0.0) | 0.30 (0.4) | 0.37 (0.5) | 0.55 (0.7) | 0.13 (0.2) | 0.28 (0.3) |
| tensor | 2.61 (1.0) | 0.06 (0.0) | 0.29 (0.1) | 0.39 (0.1) | 0.31 (0.1) | 0.39 (0.1) | 0.61 (0.2) |
| zern | 0.09 (1.0) | 0.00 (0.0) | 0.02 (0.2) | 0.02 (0.2) | 0.02 (0.2) | 0.02 (0.2) | 0.01 (0.1) |
| smith-normal-form | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.00 (0.0) | 0.00 (0.0) |
| ratio-regions | 0.08 (1.0) | 0.01 (0.1) | 0.04 (0.5) | 0.06 (0.8) | 0.06 (0.8) | 0.01 (0.1) | 0.03 (0.4) |
| mpuz | 48.53 (1.0) | 2.66 (0.1) | 9.86 (0.2) | 15.73 (0.3) | 8.25 (0.2) | 5.35 (0.1) | 9.21 (0.2) |
| DLXSimulator | 35.66 (1.0) | 10.19 (0.3) | 32.51 (0.9) | 25.47 (0.7) | 17.02 (0.5) | 9.62 (0.3) | 12.55 (0.4) |
| knuth-bendix | 1.94 (1.0) | 0.20 (0.1) | 0.68 (0.4) | 0.74 (0.4) | 0.43 (0.2) | 0.48 (0.2) | n/a |
| tyan | 0.94 (1.0) | 0.20 (0.2) | 0.57 (0.6) | 0.30 (0.3) | 0.18 (0.2) | 0.24 (0.3) | n/a |
| lexgen | 0.33 (1.0) | 0.07 (0.2) | 0.24 (0.7) | 0.18 (0.5) | 0.10 (0.3) | 0.20 (0.6) | 0.22 (0.7) |
| mlyacc | 0.18 (1.0) | 0.05 (0.3) | 0.15 (0.8) | 0.11 (0.6) | 0.08 (0.4) | 0.06 (0.3) | 0.10 (0.6) |
| hamlet | 0.07 (1.0) | 0.00 (0.0) | 0.02 (0.3) | 0.01 (0.1) | 0.02 (0.3) | 0.01 (0.1) | 0.01 (0.1) |
| kitfib35 | 0.56 (1.0) | 0.14 (0.2) | 0.22 (0.4) | 0.16 (0.3) | 0.13 (0.2) | 0.11 (0.2) | 0.51 (0.9) |
| fib0 | 0.04 (1.0) | 0.01 (0.2) | 0.03 (0.8) | 0.02 (0.5) | 0.02 (0.5) | 0.01 (0.2) | 0.03 (0.8) |
| kitreynolds2 | 0.28 (1.0) | 0.07 (0.2) | 0.39 (1.4) | 0.36 (1.3) | 0.21 (0.7) | 0.15 (0.5) | 0.10 (0.4) |
| kitreynolds3 | 0.17 (1.0) | 0.02 (0.1) | 0.31 (1.8) | 0.21 (1.2) | 0.15 (0.9) | 0.09 (0.5) | 0.07 (0.4) |
| kitloop2 | 0.01 (1.0) | 0.00 (0.0) | 0.02 (2.0) | 0.01 (1.0) | 0.01 (1.0) | 0.00 (0.0) | 0.00 (0.0) |
| kitdangle | 0.06 (1.0) | 0.00 (0.0) | 0.03 (0.5) | 0.03 (0.5) | 0.02 (0.3) | 0.84 (14.0) | 0.08 (1.3) |
| kitdangle3 | 0.16 (1.0) | 0.00 (0.0) | 0.07 (0.4) | 0.05 (0.3) | 0.04 (0.2) | 1.11 (6.9) | 0.14 (0.9) |
| msort | 0.11 (1.0) | 0.03 (0.3) | 0.05 (0.5) | 0.03 (0.3) | 0.03 (0.3) | 0.03 (0.3) | 0.04 (0.4) |
| kittmergesort_tp | 1.54 (1.0) | 0.59 (0.4) | 1.20 (0.8) | 0.86 (0.6) | 0.60 (0.4) | 0.56 (0.4) | 0.93 (0.6) |
| barnes-hut | 0.52 (1.0) | 0.08 (0.2) | n/a | 0.24 (0.5) | 0.16 (0.3) | 0.36 (0.7) | 0.37 (0.7) |
| tsp | 0.03 (1.0) | 0.00 (0.0) | 0.02 (0.7) | 0.02 (0.7) | 0.01 (0.3) | 0.01 (0.3) | 0.01 (0.3) |
| fannkuch | 0.01 (1.0) | 0.00 (0.0) | 0.02 (2.0) | 0.02 (2.0) | 0.01 (1.0) | 0.00 (0.0) | 0.00 (0.0) |
| f-arith | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.02 (2.0) | 0.02 (2.0) | 0.02 (2.0) | 0.02 (2.0) |
| stream-sieve | 0.06 (1.0) | 0.02 (0.3) | 0.04 (0.7) | 0.03 (0.5) | 0.03 (0.5) | 0.03 (0.5) | 0.06 (1.0) |
| twenty-four | 0.32 (1.0) | 0.08 (0.2) | 0.19 (0.6) | 0.20 (0.6) | 0.13 (0.4) | 0.11 (0.3) | 0.24 (0.8) |
| simple | 0.79 (1.0) | 0.16 (0.2) | 0.38 (0.5) | 0.49 (0.6) | 0.19 (0.2) | 0.25 (0.3) | 0.46 (0.6) |
| nbody | 1.54 (1.0) | 0.46 (0.3) | 0.43 (0.3) | 0.42 (0.3) | 0.36 (0.2) | 1.98 (1.3) | 2.00 (1.3) |
| output1 | 0.18 (1.0) | 0.00 (0.0) | 0.04 (0.2) | 0.04 (0.2) | 0.02 (0.1) | 0.03 (0.2) | 0.04 (0.2) |
| ray | 0.32 (1.0) | 0.04 (0.1) | 0.10 (0.3) | 0.10 (0.3) | 0.06 (0.2) | 0.13 (0.4) | 0.23 (0.7) |
| raytrace | 1.88 (1.0) | 0.48 (0.3) | 1.69 (0.9) | 1.79 (1.0) | 1.19 (0.6) | 1.27 (0.7) | n/a |
| vliw | 0.26 (1.0) | 0.06 (0.2) | 0.12 (0.5) | 0.08 (0.3) | 0.07 (0.3) | 0.08 (0.3) | 0.17 (0.7) |
| fxp | 0.43 (1.0) | 0.09 (0.2) | 0.22 (0.5) | 0.18 (0.4) | 0.14 (0.3) | 0.32 (0.7) | 0.58 (1.3) |
| model-elimination | 42.84 (1.0) | 6.53 (0.2) | 21.60 (0.5) | 17.69 (0.4) | 11.50 (0.3) | 9.24 (0.2) | 36.27 (0.8) |
| sat | 0.68 (1.0) | 0.06 (0.1) | 0.19 (0.3) | 0.23 (0.3) | 0.14 (0.2) | 0.19 (0.3) | 0.96 (1.4) |
| boyer-smlnj | 2.09 (1.0) | 0.39 (0.2) | 1.23 (0.6) | 1.25 (0.6) | 0.85 (0.4) | 0.76 (0.4) | n/a |
| logic-smlnj | 49.63 (1.0) | 9.89 (0.2) | 16.97 (0.3) | 12.58 (0.3) | 9.60 (0.2) | 9.32 (0.2) | 41.03 (0.8) |
| life-smlnj | 9.50 (1.0) | 0.77 (0.1) | 10.19 (1.1) | 8.31 (0.9) | 4.72 (0.5) | 0.64 (0.1) | 2.18 (0.2) |
| minimax | 6.78 (1.0) | 0.75 (0.1) | 3.37 (0.5) | 3.33 (0.5) | 2.35 (0.3) | 2.13 (0.3) | 1.82 (0.3) |
| iter-pidigits | 3.22 (1.0) | 0.00 (0.0) | 0.02 (0.0) | 0.03 (0.0) | 0.02 (0.0) | 0.00 (0.0) | 0.06 (0.0) |
| mazefun | 0.47 (1.0) | 0.05 (0.1) | 0.16 (0.3) | 0.20 (0.4) | 0.12 (0.3) | 0.07 (0.1) | 0.29 (0.6) |
| queens-lazy | 0.02 (1.0) | 0.00 (0.0) | 0.02 (1.0) | 0.02 (1.0) | 0.02 (1.0) | 0.01 (0.5) | 0.01 (0.5) |
| queens-strict | 0.04 (1.0) | 0.02 (0.5) | 0.03 (0.8) | 0.03 (0.8) | 0.03 (0.8) | 0.02 (0.5) | 0.03 (0.8) |
| nqueens | 0.03 (1.0) | 0.00 (0.0) | 0.01 (0.3) | 0.02 (0.7) | 0.02 (0.7) | 0.01 (0.3) | 0.01 (0.3) |
| rec_seq_ack | 0.06 (1.0) | 0.01 (0.2) | 0.03 (0.5) | 0.03 (0.5) | 0.03 (0.5) | 0.01 (0.2) | 0.03 (0.5) |
| klife_eq | 0.22 (1.0) | 0.02 (0.1) | 0.22 (1.0) | 0.19 (0.9) | 0.14 (0.6) | 0.03 (0.1) | 0.08 (0.4) |
| kitlife35u_smlnj | 0.17 (1.0) | 0.02 (0.1) | 0.06 (0.4) | 0.06 (0.4) | 0.04 (0.2) | 0.03 (0.2) | 0.10 (0.6) |
| kitqsort_no_basislib | 0.07 (1.0) | 0.01 (0.1) | 0.02 (0.3) | 0.02 (0.3) | 0.02 (0.3) | 0.02 (0.3) | 0.03 (0.4) |
| tailfib-mlkit | 0.00 | 0.00 | 0.01 | 0.01 | 0.01 | 0.00 | 0.00 |
| tak-mlkit | 0.06 (1.0) | 0.01 (0.2) | 0.03 (0.5) | 0.05 (0.8) | 0.03 (0.5) | 0.01 (0.2) | 0.05 (0.8) |
| matrix-multiply-mlkit | 0.16 (1.0) | 0.00 (0.0) | 0.05 (0.3) | 0.09 (0.6) | 0.05 (0.3) | 0.03 (0.2) | 0.05 (0.3) |
| vector-rev-mlkit | 0.05 (1.0) | 0.00 (0.0) | 0.04 (0.8) | 0.03 (0.6) | 0.03 (0.6) | 0.00 (0.0) | 0.01 (0.2) |
| vector-rev_smlnj | 0.04 (1.0) | 0.00 (0.0) | 0.02 (0.5) | 0.02 (0.5) | 0.02 (0.5) | 0.00 (0.0) | 0.02 (0.5) |
| vector-concat | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.00 (0.0) | 0.00 (0.0) |
| vector-concat_smlnj | 0.06 (1.0) | 0.00 (0.0) | 0.03 (0.5) | 0.02 (0.3) | 0.02 (0.3) | 0.00 (0.0) | 0.02 (0.3) |
| peek-mlkit | 0.02 (1.0) | 0.00 (0.0) | 0.01 (0.5) | 0.02 (1.0) | 0.01 (0.5) | 0.01 (0.5) | 0.02 (1.0) |
| wc-input1-mlkit | 0.06 (1.0) | 0.00 (0.0) | 0.04 (0.7) | 0.04 (0.7) | 0.03 (0.5) | 0.03 (0.5) | 0.02 (0.3) |
| wc-scanStream-mlkit | 0.06 (1.0) | 0.00 (0.0) | 0.03 (0.5) | 0.03 (0.5) | 0.02 (0.3) | 0.03 (0.5) | 0.07 (1.2) |
| psdes-random-mlkit | 0.02 (1.0) | 0.00 (0.0) | 0.02 (1.0) | 0.02 (1.0) | 0.02 (1.0) | 0.01 (0.5) | 0.01 (0.5) |
| safe-for-space | 0.14 (1.0) | 0.01 (0.1) | 0.09 (0.6) | 0.08 (0.6) | 0.05 (0.4) | 0.06 (0.4) | 0.09 (0.6) |
| pidigits-smlnj | 3.12 (1.0) | 0.00 (0.0) | 0.02 (0.0) | 0.03 (0.0) | 0.02 (0.0) | 0.00 (0.0) | 0.06 (0.0) |
| fft-smlnj | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.00 (0.0) | 0.00 (0.0) |
| nucleic-smlnj | 0.14 (1.0) | 0.06 (0.4) | 0.05 (0.4) | 0.05 (0.4) | 0.03 (0.2) | 0.13 (0.9) | 0.09 (0.6) |
| count-graphs-smlnj | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.00 (0.0) | 0.00 (0.0) |
| matrix-multiply-ramp | 0.02 (1.0) | 0.00 (0.0) | 0.02 (1.0) | 0.02 (1.0) | 0.02 (1.0) | 0.00 (0.0) | 0.00 (0.0) |
| kitreynolds2_no_basislib | 0.02 (1.0) | 0.00 (0.0) | 0.03 (1.5) | 0.03 (1.5) | 0.02 (1.0) | 0.01 (0.5) | 0.00 (0.0) |
| kitreynolds3_no_basislib | 0.00 | 0.00 | 0.01 | 0.01 | 0.01 | 0.00 | 0.00 |
| kittmergesort_no_basislib | 0.04 (1.0) | 0.02 (0.5) | 0.03 (0.8) | 0.03 (0.8) | 0.03 (0.8) | 0.02 (0.5) | 0.03 (0.8) |
| hanoi | 0.00 | 0.00 | 0.02 | 0.01 | 0.01 | 0.00 | 0.00 |
| fib-mlkit | 0.00 | 0.00 | 0.02 | 0.01 | 0.01 | 0.00 | 0.00 |
| mandelbrot-smlnj | 0.03 (1.0) | 0.02 (0.7) | 0.04 (1.3) | 0.03 (1.0) | 0.03 (1.0) | 0.06 (2.0) | 0.02 (0.7) |
| mandelbrot-rat | 55.59 (1.0) | 0.26 (0.0) | 2.08 (0.0) | 3.85 (0.1) | 1.38 (0.0) | 0.17 (0.0) | n/a |
| kitmandelbrot | 0.00 | 0.00 | 0.01 | 0.01 | 0.01 | 0.00 | 0.00 |
| FuhMishra | 0.04 (1.0) | 0.01 (0.2) | 0.03 (0.8) | 0.04 (1.0) | 0.03 (0.8) | 0.02 (0.5) | 0.02 (0.5) |
| black-scholes | 0.07 (1.0) | 0.03 (0.4) | n/a | 0.05 (0.7) | 0.03 (0.4) | 0.03 (0.4) | 0.07 (1.0) |
| professor2 | 0.10 (1.0) | 0.03 (0.3) | 0.16 (1.6) | 0.14 (1.4) | 0.08 (0.8) | 0.05 (0.5) | 0.06 (0.6) |
| professor2_tp | 0.10 (1.0) | 0.03 (0.3) | 0.23 (2.3) | 0.14 (1.4) | 0.08 (0.8) | 0.05 (0.5) | 0.05 (0.5) |
| professor_game | 0.10 (1.0) | 0.03 (0.3) | 0.33 (3.3) | 0.13 (1.3) | 0.09 (0.9) | 0.04 (0.4) | 0.05 (0.5) |
| professor_game-mlkit | 0.10 (1.0) | 0.02 (0.2) | 0.23 (2.3) | 0.14 (1.4) | 0.08 (0.8) | 0.04 (0.4) | 0.06 (0.6) |
| professor_game_debug | 0.00 | 0.00 | 0.01 | 0.01 | 0.01 | 0.00 | 0.00 |
| kkb_eq | 0.52 (1.0) | 0.05 (0.1) | 0.24 (0.5) | 0.15 (0.3) | 0.10 (0.2) | 0.13 (0.2) | 0.31 (0.6) |
| kitkbjul9_smlnj | 0.53 (1.0) | 0.06 (0.1) | 0.18 (0.3) | 0.18 (0.3) | 0.12 (0.2) | 0.13 (0.2) | 0.28 (0.5) |
| kkb36c_smlnj | 0.47 (1.0) | 0.05 (0.1) | 0.12 (0.3) | 0.20 (0.4) | 0.10 (0.2) | 0.14 (0.3) | 0.22 (0.5) |
| ratio-regions-mlkit | 0.08 (1.0) | 0.01 (0.1) | 0.04 (0.5) | 0.07 (0.9) | 0.04 (0.5) | 0.01 (0.1) | 0.03 (0.4) |
| ratio-regions_tp | 0.28 (1.0) | 0.02 (0.1) | 0.15 (0.5) | 0.25 (0.9) | 0.14 (0.5) | 0.06 (0.2) | 0.16 (0.6) |
| ratio-regions-smlnj | 0.08 (1.0) | 0.01 (0.1) | 0.04 (0.5) | 0.06 (0.8) | 0.04 (0.5) | 0.01 (0.1) | 0.03 (0.4) |
| count-graphs-mlkit | 0.02 (1.0) | 0.00 (0.0) | 0.01 (0.5) | 0.02 (1.0) | 0.02 (1.0) | 0.01 (0.5) | 0.01 (0.5) |
| mpuz-mlkit | 4.82 (1.0) | 0.28 (0.1) | 1.02 (0.2) | 2.06 (0.4) | 0.80 (0.2) | 0.50 (0.1) | 1.13 (0.2) |
| knuth-bendix-smlnj | 0.64 (1.0) | 0.06 (0.1) | 0.17 (0.3) | 0.38 (0.6) | 0.15 (0.2) | 0.15 (0.2) | n/a |
| tyan-smlnj | 1.37 (1.0) | 0.33 (0.2) | 0.35 (0.3) | 0.46 (0.3) | 0.27 (0.2) | 0.32 (0.2) | n/a |
| tyan-mlkit | 0.93 (1.0) | 0.28 (0.3) | 0.24 (0.3) | 0.28 (0.3) | 0.20 (0.2) | 0.23 (0.2) | n/a |
| smith-normal-form-mlkit | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.00 (0.0) | 0.00 (0.0) |
| smith-nf | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.01 (1.0) | 0.00 (0.0) | 0.00 (0.0) |
| lexgen-smlnj | 0.21 (1.0) | 0.06 (0.3) | 0.10 (0.5) | 0.11 (0.5) | 0.07 (0.3) | 0.13 (0.6) | 0.13 (0.6) |
| mlyacc-smlnj | 0.11 (1.0) | 0.04 (0.4) | 0.06 (0.5) | 0.07 (0.6) | 0.05 (0.5) | 0.04 (0.4) | 0.07 (0.6) |
| kitsimple | 0.03 (1.0) | 0.00 (0.0) | 0.01 (0.3) | 0.02 (0.7) | 0.02 (0.7) | 0.01 (0.3) | 0.01 (0.3) |
| kitsimple_tp | 0.06 (1.0) | 0.01 (0.2) | 0.02 (0.3) | 0.03 (0.5) | 0.02 (0.3) | 0.02 (0.3) | 0.02 (0.3) |
| kitsimple_no_basislib | 0.03 (1.0) | 0.00 (0.0) | 0.01 (0.3) | 0.02 (0.7) | 0.02 (0.7) | 0.01 (0.3) | 0.01 (0.3) |
| simple-smlnj | 0.07 (1.0) | 0.01 (0.1) | 0.03 (0.4) | 0.04 (0.6) | 0.03 (0.4) | 0.03 (0.4) | 0.05 (0.7) |
| tsp-smlnj | 0.01 (1.0) | 0.00 (0.0) | n/a | n/a | 0.02 (2.0) | 0.01 (1.0) | 0.00 (0.0) |
| DLXSimulator-mlkit | 0.10 (1.0) | 0.05 (0.5) | 0.09 (0.9) | 0.10 (1.0) | 0.08 (0.8) | 0.03 (0.3) | 0.03 (0.3) |
| aobench | 0.23 (1.0) | 0.15 (0.7) | n/a | n/a | 0.04 (0.2) | 0.06 (0.3) | 0.26 (1.1) |
| id-ray | 6.95 (1.0) | 0.33 (0.0) | n/a | n/a | n/a | n/a | 0.74 (0.1) |
| plclub-ray | 0.07 (1.0) | 0.01 (0.1) | 0.04 (0.6) | 0.06 (0.9) | 0.05 (0.7) | 0.05 (0.7) | n/a |
| mc-ray | 0.77 (1.0) | 0.10 (0.1) | 0.08 (0.1) | n/a | 0.07 (0.1) | 0.33 (0.4) | 0.29 (0.4) |
| ray-smlnj | 0.04 (1.0) | 0.00 (0.0) | 0.01 (0.2) | 0.02 (0.5) | 0.02 (0.5) | 0.02 (0.5) | 0.03 (0.8) |
| kitmolgard | 0.06 (1.0) | 0.01 (0.2) | 0.03 (0.5) | 0.04 (0.7) | 0.04 (0.7) | 0.02 (0.3) | 0.04 (0.7) |
| vliw-smlnj | 0.44 (1.0) | 0.11 (0.2) | 0.20 (0.5) | 0.23 (0.5) | 0.16 (0.4) | 0.19 (0.4) | 0.51 (1.2) |
| rfib | 0.02 (1.0) | 0.00 (0.0) | 0.01 (0.5) | 0.02 (1.0) | 0.02 (1.0) | 0.01 (0.5) | 0.01 (0.5) |
| tak-nofib-lazy | 0.01 (1.0) | 0.00 (0.0) | 0.01 (1.0) | 0.01 (1.0) | 0.02 (2.0) | 0.01 (1.0) | 0.01 (1.0) |
| tak-nofib-strict | 0.00 | 0.00 | 0.01 | 0.01 | 0.01 | 0.00 | 0.00 |
| exp3_8-lazy | 0.83 (1.0) | 0.22 (0.3) | 0.72 (0.9) | 0.77 (0.9) | 0.63 (0.8) | 0.81 (1.0) | 0.73 (0.9) |
| exp3_8-strict | 0.16 (1.0) | 0.06 (0.4) | 0.07 (0.4) | 0.07 (0.4) | 0.06 (0.4) | 0.06 (0.4) | 0.20 (1.2) |
| digits-of-e1-lazy | 1.10 (1.0) | 0.06 (0.1) | 0.26 (0.2) | 0.45 (0.4) | 0.22 (0.2) | 0.06 (0.1) | 1.11 (1.0) |
| digits-of-e2-lazy | 2.46 (1.0) | 0.12 (0.0) | 0.84 (0.3) | 0.87 (0.4) | 0.61 (0.2) | 0.18 (0.1) | 2.44 (1.0) |

Of the programs where `rune:new opt` is at least 0.10 s and MLton is above
0.00 s, there are 69. MLton is faster on every one of them. Together they
take 307 s against MLton's 39 s, 7.8 times. A figure below is `rune:new opt`
divided by MLton, the reciprocal of the parentheses in the table. The 4
times gap of `fib` and `tak`, in the eight-program section, is the common
case here, and the suite's time lies in a few programs that are much
further away. The five longest are `mandelbrot-rat`, `logic-smlnj`, `mpuz`,
`model-elimination` and `DLXSimulator`.

* **Three of the five long programs match `fib`.** `DLXSimulator` is 3.5
  times (35.66 s against 10.19), `logic-smlnj` 5.0 times (49.63 s against
  9.89) and `model-elimination` 6.6 times (42.84 s against 6.53).
  `lexgen`, `mlyacc` and `vliw` are 3.6 to 4.7 times.
* **`mandelbrot-rat` and `mpuz` are much further away, as are the pi-digit
  runs.** `mandelbrot-rat` is 214 times (55.59 s against 0.26). It does
  rational arithmetic in `IntInf`, and the loop counters are `IntInf` too.
  `mpuz` is 18 times (48.53 s against 2.66): it enumerates decimal
  assignments and hashes the text. `pidigits`, `iter-pidigits` and
  `pidigits-smlnj` take 5.99 s, 3.22 s and 3.12 s, and 0.00 s on MLton, so
  the cell reads `(0.0)`. `digits-of-e1-lazy` and `digits-of-e2-lazy` are
  18 and 21 times. Without `mandelbrot-rat` and `mpuz`, the other 67
  programs are 5.6 times.
* **The tie of `real_nbody` with MLton does not recur.** The closest
  program at or above 0.10 s is `aobench`, at 1.5 times (0.23 s against
  0.15). `nbody` is 3.3 times. `tensor`, contractions of real arrays, is
  44 times (2.61 s against 0.06). `id-ray` is 21 times. `many_refs`, a
  retained table of boxed real refs, is 27 times (0.81 s against 0.03).
  In the eight-program table, `list_ops` has MLton close on wall-clock
  time.
* **`rune:opt` shows the same split, a little further from MLton.**
  `mandelbrot-rat` is 283 times, `mpuz` 24 times and `DLXSimulator` 4.5
  times. On the programs that dominate this suite, both Rune backends
  carry the gap.

## Compiling

Each build of the compiler compiling `examples/hello.sml` to the stack
bytecode (`--target=stack`, which was the default when this was measured),
and compiling the compiler itself (`BOOT_SRCS`, the bootstrap's input), the same day at
the same commit and on the same machine as above: wall-clock time, the
fastest of three rounds, a round of `hello` being 20 compiles. The builds
of the hosts are what `make host-builds` makes (`bin/rune-mlton`,
`bin/rune-smlnj-legacy`, `bin/rune-smlnj32`, `bin/rune-smlnj-dev`,
`bin/rune-polyml`, `bin/rune-mlkit`); the others are the self-hosted
compiler, `bin/rune.stack.rbc`, on `runevm-stack` and translated by `runeopt`, and
`bin/rune.rbc` on `runtime/register` at each JIT level.

| Build | `hello` | the compiler |
|---|---:|---:|
| MLton | 6.7 ms | 1.12 s |
| Poly/ML | 9.3 ms | 1.08 s |
| MLKit | 8.4 ms | 1.90 s |
| SML/NJ 110.99.9, 64 bits | 21.8 ms | 2.56 s |
| SML/NJ 110.99.9, 32 bits | 21.2 ms | 2.34 s |
| SML/NJ 2026.2 | 24.9 ms | 2.38 s |
| `runevm-stack` (`bin/rune.stack.rbc`) | 26.2 ms | 6.01 s |
| native code (`runeopt` of `bin/rune.stack.rbc`) | 17.0 ms | 3.12 s |
| `runtime/register`, `off` | 22.9 ms | 5.44 s |
| `runtime/register`, `baseline` | 36.1 ms | 3.24 s |
| `runtime/register`, `opt` (the default; `bin/rune`, what is shipped) | 37.8 ms | 3.04 s |
| `runtime/register`, `all` | 157.1 ms | 3.23 s |
| `runtime/register`, `all+t2` | 187.9 ms | 3.18 s |

Not measured: the VMs built for Windows, 32-bit Linux and PowerPC.

* The compiler on `runevm-stack` compiles itself in 6.0 s, 5.4 times as long as
  the build MLton makes; translated into native code, in 3.1 s, 2.8 times.
  The shipped one, on `runtime/register`, takes 3.0 s.
* `runtime/register` with its JIT on (`baseline`, `opt`) compiles the compiler in 3.0
  to 3.2 s, twice as fast as `runevm-stack`, as fast as native code, 1.2 to 1.3
  times SML/NJ's builds and 2.7 times MLton's. Tier 2 is no faster than
  tier 1 here, as on `list_ops` and `string_ops`.
* A small program costs little on any: `hello` is 26 ms on `runevm-stack`, most
  of it reading and elaborating the part of the Basis Library it uses. The
  JIT makes it dearer, 36 to 38 ms against 23 for the interpreter alone,
  and compiling all of the compiler up front (`all`) costs 157 to 188 ms.
* The counts that do not depend on the machine -- instructions executed,
  and bytes and objects allocated, by the compiler compiling `hello`, by
  the bootstrap and by `runedoc` -- are the budgets of `make perf-check`
  (`tests/perf/*.budget`). At this commit the bootstrap executes 951
  million instructions of stack bytecode and 585 million of register
  bytecode and allocates 1.17 GB in 26.0 million objects; compiling `hello`
  takes 3.10 million instructions, 3.6 MB and 54.1 thousand objects.

## Why `runtime/register` at `opt` is slower than MLton

Measured on the same day and machine as the tables above, with `perf stat`
(user cycles and instructions of the wrapped `tests/perf` programs),
MLton's generated assembly (`-keep g`), and the tier-2 machine code of the
hot functions, dumped from a running `runevm --jit-perf-map` and
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
  instructions on `runtime/register` and about 17 on MLton. The trace of `fib`
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
  iteration on this CPU; `runtime/register` takes 88 and MLton 94. `runtime/register` executes
  about 108 instructions per iteration and MLton 27, but the instructions
  are hidden behind the latency.
* **`string_ops`: lists and the runtime.** `runtime/register` allocates 1.8 times as
  much (136.6 MB against 77.0 MB), spends about 37% of its cycles in the
  runtime's C code (`p_string_*`, `vm_alloc`, `vm_cons`, `vm_string_from`)
  and 10% in the collector, and has 3.5 times the L1 load misses. `String.map`
  and `String.translate` are `implode (List.map f (explode s))`
  (`lib/basis/string.sml`), so each character is a list cell.
* **`list_ops`: the cache, and MLton's page faults.** In user cycles MLton
  is 2.8 times faster, in wall-clock time 1.4 times. `runtime/register` has 4.3 times
  the L1 load misses and spends 12.5% of its cycles in the collector, though
  both allocate the same amount (56.6 MB and 58.0 MB). MLton spends half of
  its time in the kernel, faulting in 12.1 thousand pages (`runtime/register`: 7.2
  thousand). A recursion over a list, like `List.filter`, costs about 62
  instructions per element on `runtime/register`, the call and return being most of
  it. What makes the misses 4.3 times as many is not isolated.
* **`intinf_fact`: algorithms.** `runtime/register` allocates 76 MB, MLton (GMP) 0.38
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
make                              # bin/rune, bin/runevm, bin/runevm-stack
make host-builds runeopt bin/runevm-native bin/rune bin/runevm
make hosts                        # MLton, SML/NJ, Poly/ML and MLKit, once
make perf PERF_CONFIGS=rune,rune:opt,rune:new,hosts,xc1
                                  # the tables, in tests/out/perf/wall.md
```

`rune:new` runs at `--jit=opt` unless the environment names another level:
the other columns are `RUNEVM_JIT=off`, `RUNEVM_JIT=baseline`,
`RUNEVM_JIT=all` and `RUNEVM_JIT=all RUNEVM_JIT_TIER=2` before `make perf
PERF_CONFIGS=rune:new`.

The compile times: `make bin/rune.stack.rbc`, then `bin/runeopt-mlton
--options "--heap-size 67108864" bin/rune.stack.rbc -o bin/rune-native` for the
native compiler, and each build run as `BUILD -o out.rbc examples/hello.sml`
and `BUILD -o out.rbc $(BOOT_SRCS)`, where `BUILD` is `bin/rune-HOST`, or
`bin/runevm-stack --heap-size 67108864 bin/rune.stack.rbc --lib lib` (`bin/rune.rbc` on
`bin/runevm`, with the JIT options of the level), or `bin/rune-native
--lib lib`. `scripts/perf-cycles.sh` measures cycles and instructions of the
same runs, with `jit-off`, `jit-baseline`, `jit-all` and `+t2` for the levels.

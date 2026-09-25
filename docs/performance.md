# Performance

What each configuration of Rune costs to run a program and to compile one,
against the SML systems Rune is built with. Why it costs that, and what is
being done about it, is in [plans/performance.md](plans/performance.md)
(the VMs and native code) and [plans/middle-end.md](plans/middle-end.md)
(the compiler's optimisations); how native code is made is in
[native.md](native.md).

## The configurations

| Configuration | What runs |
|---|---|
| `rune` | the stack bytecode of the self-hosted compiler, on `runevm` ([bytecode.md](bytecode.md)) |
| `rune:opt` | the same bytecode translated into x86-64 code by `runeopt` ([native.md](native.md)) |
| `rune:new` | the register bytecode, on the first loop of `vm/new` ([bytecode.md](bytecode.md), The register bytecode) |
| `rune:windows`, `rune:windows32` | `runevm` built for 64- and 32-bit Windows (`make windows`), run from WSL |
| `rune:linux32` | `runevm` built for 32-bit x86 Linux (`make portability`) |
| `rune:ppc64` | `runevm` built for big-endian 64-bit PowerPC (`make portability`), run under qemu: its times are qemu's |
| `native:HOST` | the program on the host's own Basis Library, compiled by the host |
| `xc1:HOST` | the program on Rune's Basis Library (`lib/basis`), compiled by the host ([basis-compat.md](basis-compat.md)) |

The hosts are MLton 20241230, SML/NJ 110.99.9 (64 and 32 bits) and Poly/ML
5.9.2 (`make hosts`).

## Running programs

`make perf` on an x86_64 machine with 16 CPUs, idle but for the one program
being timed, on 2026-09-25 at `a1a145c`. Each cell is the milliseconds of
one run of a program of `tests/perf`: the program is run R times in a row
(the `wall R` line of its `.budget` file) in three rounds, and the fastest
round counts; SML/NJ and Poly/ML compile it before the timer starts, like
the others. In parentheses: the time divided by the baseline of the same
configuration, the geometric mean of `fib` and `tak`, which use no Basis
Library. That ratio separates what a library costs from how fast a system
runs code at all.

| Program | rune | rune:opt | rune:new | rune:windows | rune:windows32 | rune:linux32 | rune:ppc64 | native:mlton | native:smlnj | native:smlnj32 | native:polyml | xc1:mlton | xc1:smlnj | xc1:smlnj32 | xc1:polyml |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| array_sieve | 8.42 (2.7) | 4.67 (4.0) | 17.79 (2.4) | 9.10 (2.4) | 15.75 (2.9) | 11.89 (2.8) | 90.47 (2.7) | 0.43 (1.7) | 1.19 (3.9) | 0.94 (3.0) | 0.58 (3.1) | 0.47 (2.1) | 1.27 (3.7) | n/a | 0.66 (3.5) |
| fib | 5.50 (1.8) | 2.35 (2.0) | 12.35 (1.7) | 6.42 (1.7) | 9.30 (1.7) | 7.72 (1.8) | 53.49 (1.6) | 0.42 (1.6) | 0.40 (1.3) | 0.41 (1.3) | 0.30 (1.6) | 0.37 (1.6) | 0.38 (1.1) | n/a | 0.29 (1.6) |
| intinf_fact | 55.19 (17.9) | 25.28 (21.5) | 88.23 (11.9) | 55.01 (14.5) | 86.33 (16.0) | 75.75 (17.8) | 533.95 (16.1) | 0.04 (0.2) | 0.25 (0.8) | 0.41 (1.3) | 0.07 (0.4) | n/a | n/a | n/a | n/a |
| list_ops | 5.40 (1.8) | 2.57 (2.2) | 9.32 (1.3) | 7.30 (1.9) | 8.40 (1.6) | 7.61 (1.8) | 54.93 (1.7) | 1.74 (6.7) | 1.62 (5.3) | 1.40 (4.5) | 1.15 (6.1) | 1.15 (5.0) | 1.75 (5.1) | n/a | 1.22 (6.5) |
| real_nbody | 2.84 (0.9) | 1.28 (1.1) | 7.41 (1.0) | 3.38 (0.9) | 5.15 (1.0) | 4.09 (1.0) | 47.62 (1.4) | 0.56 (2.2) | 0.50 (1.7) | 0.51 (1.6) | 1.10 (5.8) | 0.59 (2.6) | 0.47 (1.4) | n/a | 1.13 (6.0) |
| string_ops | 10.29 (3.3) | 5.62 (4.8) | 15.79 (2.1) | 10.85 (2.9) | 14.53 (2.7) | 13.08 (3.1) | 100.35 (3.0) | 1.52 (5.9) | 2.25 (7.4) | 2.00 (6.4) | 1.96 (10.3) | 2.00 (8.8) | 3.54 (10.3) | n/a | 3.30 (17.6) |
| tak | 1.72 (0.6) | 0.59 (0.5) | 4.42 (0.6) | 2.23 (0.6) | 3.12 (0.6) | 2.35 (0.6) | 20.63 (0.6) | 0.16 (0.6) | 0.23 (0.8) | 0.24 (0.8) | 0.12 (0.6) | 0.14 (0.6) | 0.31 (0.9) | n/a | 0.12 (0.6) |
| word_bits | 4.61 (1.5) | 1.33 (1.1) | 10.24 (1.4) | 4.80 (1.3) | 9.00 (1.7) | 6.71 (1.6) | 53.24 (1.6) | 0.10 (0.4) | 0.25 (0.8) | 0.22 (0.7) | 0.14 (0.7) | 0.10 (0.4) | 0.34 (1.0) | n/a | 0.14 (0.7) |

Not measured: `intinf_fact` in the `xc1` configurations, whose `IntInf`
constants a host types at its own `IntInf`, not at that of `lib/basis`; and
anything on `xc1:smlnj32`, where the `LargeInt` the wrapper times with is
not that of `lib/basis`, which does not load on a 31-bit `int`.

What the table says:

* **`runevm` runs plain code 10 to 25 times slower than the hosts' native
  code**: `fib` 5.5 ms against 0.30 to 0.42, `tak` 1.7 against 0.12 to
  0.24. This is the interpreter; [plans/performance.md](plans/performance.md)
  is about it.
* **Native code (`rune:opt`) runs these programs 1.8 to 3.5 times faster
  than `runevm`** (`fib` 2.35 ms, `tak` 0.59, `word_bits` 1.33 against
  4.61), and 3 to 15 times slower than the hosts.
* **`vm/new` is 1.5 to 2.6 times slower than `runevm`.** Its loop is the
  first one (middle-end M5), with none of the work that made `runevm`'s
  fast (middle-end M6: the state in locals, computed goto); making it fast
  belongs to `vm/new`'s own plan.
* **The same VM elsewhere:** on 64-bit Windows about as fast as on Linux
  (5 to 30% slower, for starting a process from WSL); built for 32 bits,
  1.4 (Linux) to 1.8 (Windows) times slower, since a value of 64 bits is
  two words there. The PowerPC column is qemu's emulation, about ten times
  slower.
* **Relative to its baseline, the library costs Rune less than it costs
  the hosts**: `list_ops` 1.8 times the baseline on Rune, 4.5 to 6.7 on the
  hosts; `string_ops` 3.3 against 5.9 to 10.3. `IntInf` is the exception:
  18 times the baseline on Rune, 0.2 to 1.3 on the hosts, which use GMP
  (MLton) or native code. Its limbs of 30 bits are an SML datatype, and
  every limb operation is a call.
* **The `xc1` columns** run Rune's library compiled by each host, about as
  fast as that host's own library (`list_ops` 1.15 ms on MLton against
  1.74 native, `string_ops` 2.00 against 1.52): the algorithms of
  `lib/basis` are not what makes Rune slow.

## Compiling

Each build of the compiler compiling `examples/hello.sml`, and compiling
the compiler itself (`BOOT_SRCS`, the bootstrap's input), the same day at
the same commit: wall-clock time, the fastest of three rounds, a round of
`hello` being 20 compiles. The builds of the hosts are what `make
host-builds` makes (`bin/rune-mlton`, `bin/rune-smlnj`, `bin/rune-smlnj32`,
`bin/rune-polyml`); the others are the self-hosted compiler, `bin/rune.rbc`,
on each VM, and translated by `runeopt`.

| Build | `hello` | the compiler |
|---|---:|---:|
| MLton | 5.9 ms | 0.89 s |
| Poly/ML | 8.1 ms | 0.83 s |
| SML/NJ, 64 bits | 19.1 ms | 2.16 s |
| SML/NJ, 32 bits | 18.1 ms | 1.71 s |
| `runevm` (`bin/rune`, what is shipped) | 21.7 ms | 5.03 s |
| native code (`runeopt` of `bin/rune.rbc`) | 14.5 ms | 2.82 s |
| `vm/new` (`bin/rune.new.rbc`) | 29.3 ms | 6.01 s |
| `runevm`, 32-bit Linux | 25.4 ms | 5.39 s |
| `runevm`, PowerPC under qemu | 193.8 ms | 31.54 s |

Not measured: the Windows VMs, which need the program and its library in a
directory on the Windows side (`tests/windows-dir.sh`).

* The shipped compiler compiles itself in 5.0 s, 5.7 times as long as the
  build MLton makes; translated into native code, in 2.8 s, 3.2 times.
* A small program costs little on any: `hello` is 22 ms on `runevm`, most
  of it reading and elaborating the part of the Basis Library it uses.
* The counts that do not depend on the machine -- instructions executed,
  and bytes and objects allocated, by the compiler compiling `hello`, by
  the bootstrap and by `runedoc` -- are the budgets of `make perf-check`
  (`tests/perf/*.budget`).

## Since the middle end

The tables this page replaces were taken on 2026-09-20 (`rune`) and
2026-09-24 (`rune:opt`), before the middle-end roadmap
([plans/middle-end.md](plans/middle-end.md)) and codegen's M10 to M15.
Milliseconds of one run then and now, on the same machine:

| Program | rune, 09-20 | rune, now | faster | rune:opt, 09-24 | rune:opt, now | faster |
|---|---:|---:|---:|---:|---:|---:|
| array_sieve | 39.61 | 8.42 | 4.7x | 16.26 | 4.67 | 3.5x |
| fib | 11.19 | 5.50 | 2.0x | 5.64 | 2.35 | 2.4x |
| intinf_fact | 295.00 | 55.19 | 5.3x | 110.69 | 25.28 | 4.4x |
| list_ops | 34.27 | 5.40 | 6.3x | 16.75 | 2.57 | 6.5x |
| real_nbody | 9.53 | 2.84 | 3.4x | 2.50 | 1.28 | 2.0x |
| string_ops | 33.67 | 10.29 | 3.3x | 18.36 | 5.62 | 3.3x |
| tak | 9.07 | 1.72 | 5.3x | 3.74 | 0.59 | 6.3x |
| word_bits | 14.62 | 4.61 | 3.2x | 6.02 | 1.33 | 4.5x |

On 2026-09-24 the compiler compiled itself in 10.2 s on `runevm` and 5.5 s
in native code; it is 5.0 and 2.8 now.

## How to reproduce

```sh
make                              # bin/rune, bin/runevm
make host-builds runeopt bin/runevm-opt bin/rune-new bin/runevm-new
make windows portability          # the VMs of rune:windows*, rune:linux32, rune:ppc64
make hosts                        # MLton, SML/NJ and Poly/ML, once
make perf PERF_CONFIGS=rune,rune:opt,rune:new,rune:windows,rune:windows32,rune:linux32,rune:ppc64,hosts,xc1
                                  # the table, in tests/out/perf/wall.md
```

The compile times: `make bin/rune.new.rbc`, then `bin/runeopt-mlton
bin/rune.rbc -o bin/rune-native` for the native compiler, and each build
run as `BUILD -o out.rbc examples/hello.sml` and `BUILD -o out.rbc
$(BOOT_SRCS)`, where `BUILD` is `bin/rune-HOST`, or `VM --heap-size
67108864 bin/rune.rbc --lib lib` (`bin/rune.new.rbc` on `bin/runevm-new`),
or `bin/rune-native --lib lib`.

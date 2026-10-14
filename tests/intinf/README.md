# IntInf correctness and performance corpus

`python3 tests/intinf/run.py` compiles the current Basis implementation and
the saved list oracle into one program. It checks independent exact answers
and identities on bounded operands, including signs and representation
boundaries. The Python fixture arithmetic follows floor division and explicit
truncation; the saved SML arithmetic is an additional independent check.
The test-only oracle needs a 63-bit `Int`; it runs on Rune rather than on
narrow host implementations. Native host and xc1 coverage remains in the
Basis suite.

`python3 tests/intinf/run.py --bench --paired-oracle --compiler-workloads --out
tests/out/intinf/m1` adds the fixed workloads of `workloads.json`, five measured
process runs after a warmup, separate instruction/allocation statistics, and
compiler workloads. Each command is bounded to 180 seconds and 4 GiB of
address space. Outputs, commands, statuses, generated inputs, expected
answers, source/tool hashes, timings, and memory observations stay in the
output directory. `report.json` is the portable measurement record.

The workload manifest and generator are frozen in M1. The `muldiv` group
defines the SML speed gate; `muldiv` plus `large` defines the GMP gate.
`small` and the compiler workloads define regression checks. Compile time is
separate from program timing. Headline arithmetic timings use `Time.now`
around the loop, with microsecond resolution; process wall time, CPU time,
and peak RSS are recorded separately. A short sample needs more fixed
iterations before M1 closes, not a claim based on timer precision.
No instrumented execution supplies a headline timing sample.

`--paired-oracle` alternates which arithmetic implementation runs first in
each sample pair. It records each sample and the median paired speedup, so
machine load or clock changes between two complete runs need not masquerade
as an arithmetic improvement. M1 calibrates this with the original code on
both sides; M2 compares the replacement to the saved implementation. Compiler
workloads keep their separate end-to-end timing records.

`compare-compilers.py --baseline-root DIR --samples 25` alternates complete
compiler processes. DIR contains M1's sources, Basis, configuration, and the
`bin/runevm` and `bin/rune.rbc` artifacts whose hashes `baseline.json`
records. Each revision compiles its own Basis and the fixed hello,
signature, and bootstrap inputs. The old output hashes must match M1; the
current outputs must match the host-compiled Rune compiler (or the hashes
of a supplied `--current-record` from `run.py`). The normal bootstrap check
also verifies self-reproduction. Library path spellings affect debug paths
in the output, so all paired invocations explicitly use `--lib lib`.

The comparison records each pair and its ratio, with two warmup pairs.
`--workload NAME` limits exploratory runs; acceptance uses all workloads.

The benchmark result is printed and checked after every run. Operands vary
through a fixed 17-value cycle and every result is stored, so arithmetic
cannot disappear as an unused expression. The final iteration and therefore
its expected value are determined independently before running Rune.

M4 adds `run.py --paired-sml --vm-options=--intinf=gmp` to alternate identical
bytecode between GMP and forced SML. `dispatch.py` explores operation sizes
and operand shapes separately from the unchanged acceptance corpus.
`conversion.py` measures import/copy/export through a power-one primitive
and packed-storage roundtrips; the former includes result allocation and is
not an isolated import measurement. Both retain input hashes and raw samples.

`compare-kernels.py` pairs recorded bytecodes with hash-verified baseline
VMs. `compare-compilers.py --baseline-record FILE --vm-options OPTIONS`
also supports comparisons to M2 and a selected current backend. Affinity,
all paired samples, and compiler CPU times accompany wall timings; retain
noisy or unsuccessful runs when investigating the 5% regression gate.
Both comparison drivers accept `--baseline-options` to force the same backend
on M4 and the current build, or to compare SML and GMP using the same VM and
bytecode. Leave it empty for M1, whose VM predates backend selection.

`make test-intinf-hardening` checks malformed arguments, fork policy, native
option precedence, malformed images, and allocator failures in bounded
subprocesses. `alloc-failure.c` redirects allocation only inside its included
IntInf implementation, leaving the ordinary VM allocator intact.

M4's committed measurements are in [gmp-performance.json](gmp-performance.json),
including all final samples, flagged/repeated comparisons and conversion costs.
[gmp-hardening.json](gmp-hardening.json) indexes the acceptance evidence and
source hashes. Raw local transcripts remain under `tests/out/intinf/m4`;
GMP-enabled cross builds and release validation follow in M5.


M5's `make test-intinf-cross` preserves physical GMP-free VMs and rebuilds the
enabled counterparts, then runs `dependency.py --require-all` and `cross.py`.
The same arithmetic bytecode runs on native Linux, Linux32, big-endian
PowerPC64, AArch64, and Windows64/32. JIT tiers are tested only where supported;
image producers and consumers cross architectures, builds and runtime backend
choices, checking stricter saved/invocation limits. Every process is bounded.
The dependency probe retains the minimized PowerPC division failure; the
runtime itself continues to use only public `mpz` operations.

`install.py --mode gmp|sml --out DIR` tests the currently built installation
in a fresh staging directory, moves it to a path containing spaces, compiles
and runs arithmetic and native output, rebuilds the VM from the installed
source material, and checks removal preserves an unrelated marker. The M5
acceptance sequence builds each mode and restores the pinned enabled build.


`cpu-family.py` tests the fat native x86-64 package under QEMU's baseline,
Conroe, Opteron G1 and maximum-feature models, across the interpreter and both
JIT tiers. The recipe uses a generic host triple as well as fat assembly
selection: a CPU-specific auto-detected host can enable instructions in C
helpers that are unsuitable for older processors.


M5's final acceptance is indexed by [gmp-release.json](gmp-release.json).
[gmp-release-performance.json](gmp-release-performance.json) retains the fixed
arithmetic and compiler samples, direct same-bytecode backend comparisons,
flagged/repeated measurements and final-package conversion costs. Raw local
transcripts are under `tests/out/intinf/m5`. Initial host-matrix and Windows
failures remain recorded alongside successful reruns; remote CI is unrun.

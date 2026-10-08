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

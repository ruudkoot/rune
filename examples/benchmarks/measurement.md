# Measurements and comparisons

`make bench` runs normal profiles serially on Rune, MLton, SML/NJ and Poly/ML.
Each configuration is freshly compiled once, checked before measurement,
then executed in ten fresh processes. Every sample must pass its result
checker. Configuration resolution reuses the Basis matrix and hosts supplied
by `make hosts`; missing hosts are explicit failures.

```sh
make bench BENCH_FILTER=primes
make bench BENCH_FILTER=tak BENCH_LEVEL=0
make bench BENCH_FILTER=tak BENCH_MODE=repeated BENCH_REPETITIONS=20
make bench-count BENCH_PROFILE=smoke BENCH_FILTER=primes
make bench-stats BENCH_PROFILE=normal BENCH_FILTER=kittmergesort
```

`BENCH_PROFILE`, `BENCH_CONFIGS` and the substring `BENCH_FILTER` select
inputs, configurations and workloads. `BENCH_SAMPLES` changes the process
count; `BENCH_LEVEL` selects Rune `-O0` or `-O2`. Other compilers use their
recorded defaults, so the level column does not claim an equivalent option
on each host. Use explicit matrix configuration names. Timing defaults to
the four primary systems; counts and runtime statistics default to Rune's
four engines. `rune:new` explicitly disables the JIT here; `rune:jit` uses
the matrix's all-functions tier-2 wrapper. Standalone `xc1` measurements
remain unavailable pending an export adapter for its generated library;
requests are recorded as missing configurations.

Every invocation prints an isolated directory under
`tests/out/benchmarks/measurement.XXXXXX`. It retains:

- `samples.tsv`: every compilation, correctness attempt, process sample,
  in-process round, counter sample and failure, with OS user/system time
  and peak RSS in KiB where available. No round is discarded as warmup.
- `report.md`: accepted/attempted counts, every failure category, median,
  and Q1/Q3 using linear interpolation at `(n-1)*p`.
- `metadata.tsv`, `configurations.tsv`, `machine.txt`: revision, dirty state,
  options, versions, commands, mode, CPU/OS/RAM and limits.
- Source/data snapshots, expected fixtures, SHA-256 identities, portable
  driver/tool sources, Rune library/payload identities, dirty patch/status.
  Generated inputs are reproduced by the recorded SML recipe.
- Every phase's actual command, stdout, stderr, exit status and OS metrics.
  Compilation, native translation and execution have separate artifacts.

Fresh-process wall time includes startup/shutdown, quota setup and result
validation. GNU time prints wall time to hundredths of a second; small smoke
runs can round to zero and are unsuitable for ranking. Repeated execution
brackets each `Benchmark.run` with portable `Time.now`; effective clock
resolution depends on the host. It excludes outer reporting and equality
comparison, while including generation/checking inside `Benchmark.run`.
Every round has process/round indices, and all rounds must validate before
any are accepted from that process. Results do not establish steady state;
see [Barrett et al.](https://arxiv.org/abs/1602.00602) and the
[literature review](literature.md).

The same kernel and portable entrypoint are compiled on each host. SML/NJ
exports a heap entrypoint; Poly/ML exports a linked executable. Their module
initialization runs during export. MLton and Rune initialize modules on
process startup. Kernel timings use `Benchmark.run` on all hosts; startup
differences remain part of fresh-process comparisons and matter for sources
with substantial top-level initialization. Snapshot copying and compilation
are outside execution timings.

Profile limits apply separately to compilation and execution. Poly/ML uses
a data quota because it reserves substantial uncommitted address space;
execution also caps its managed heap at half the quota. Other systems use an
address-space quota. Observed peak RSS is separate from the enforced quota.
Fresh directories, fixed program/data names and controlled stdin isolate
filesystem state. Repeated mode deliberately reuses process state; a workload
that cannot safely repeat fails its checks and supplies no accepted samples.

Missing configurations, compile errors, incorrect results, runtime failures,
timeouts, memory limits and quota-setup failures have distinct statuses.
Native compilation is measured separately. `bench-stats` retains Rune's
runtime/GC output in a separate instrumented run. Hardware counters are an
optional future adapter; these reports make no hardware-counter claim.
Timing rejects count/statistics/trace instrumentation inherited through
`RUNEVM_OPTIONS`, so it cannot silently enter headline samples.

`bench-count` uses the deterministic correctness driver without clocks.
Instructions agree within stack/native or register/JIT execution models;
allocation bytes/objects agree across applicable Rune engines. Reviewed
`count-budgets.tsv` bounds use the existing 10-percent headroom convention.
Unbudgeted entries are reported explicitly and still undergo correctness
and engine comparisons. Deliberately update selected baselines with:

```sh
sh scripts/measure-benchmarks.sh count --profile smoke --filter tak --update-budgets
```

Updates require all selected runs/comparisons to pass, preserve unrelated
bounds and write atomically. Review changed bounds and record the reason.
Timing thresholds remain outside `make check`. New measurement tooling must
pass `sh tests/benchmarks/check-measurement.sh` and required acceptance checks.

# Initial measurement record

These runs demonstrate the protocol on the pilots, rather than a coverage or
performance conclusion. The two primes variants have identical mathematical
results but different evaluation/allocation. Do not infer compiler rankings
or steady state from these short workloads and one machine.

- [Fresh report](fresh/report.md): normal inputs, ten fresh processes per
  variant/configuration, 80 accepted runtime samples. Compile and prerequisite
  correctness phases remain separate.
- [Repeated report](repeated/report.md): two fresh processes with five
  retained rounds each, 80 accepted round samples, including every first round.
- [Counts](counts/report.md) and [budget check](budget-check/report.md): eight
  `-O2` smoke comparisons across Rune engines, reviewed ten-percent budgets,
  then a separate run checking those bounds.
- [Count -O0](count-o0/report.md): Tak compares stack/native and register/JIT
  instruction counts, plus allocation across all four engines. Its bounds
  are explicitly unbudgeted; agreement and correctness still passed.
- [Runtime statistics](stats/report.md): separate instrumented primes runs.

All raw rows, per-phase logs, metrics, commands, settings, source/data
snapshots, expected fixtures and identities accompany the reports. Generated
executables/heap images/bytecode are omitted; their hashes remain recorded.
The run revision was `e2f183f` with an explicitly dirty worktree. Portable
sources and tool snapshots record the implementation actually measured,
including the in-progress routine catalogue validation. This is not a clean
revision claim. Absolute artifact paths identify the original machine/run;
adapt them when compiling the provided ordered source snapshots elsewhere.

The commands were, serially after repository acceptance and correctness work:

```sh
make JOBS=4 bench BENCH_PROFILE=normal BENCH_FILTER=primes BENCH_SAMPLES=10
make JOBS=4 bench BENCH_PROFILE=normal BENCH_FILTER=primes BENCH_SAMPLES=2 BENCH_MODE=repeated BENCH_REPETITIONS=5
sh scripts/measure-benchmarks.sh count --profile smoke --filter primes --update-budgets
make JOBS=4 bench-count BENCH_PROFILE=smoke BENCH_FILTER=primes
make JOBS=4 bench-count BENCH_PROFILE=smoke BENCH_FILTER=tak BENCH_LEVEL=0
make JOBS=4 bench-stats BENCH_PROFILE=smoke BENCH_FILTER=primes
```

See [measurement semantics and limits](../../measurement.md). Each package's
manifest preserves the exact arguments, resource limits and source order.
The OS wall clock has hundredth-second output resolution; the reports retain
this limitation and every sample rather than hide rounding or variation.

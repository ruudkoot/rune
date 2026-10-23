# FFI performance acceptance — 2026-10-23

The schema 2 tool is committed as `59e58b96d118d1d4d2c9792144aaa666b03fc761`.
Final measurements use the frozen production checkout at
`dd0f0e7d82f222040650dd6cce350984952c64c6`, with its current generator, C
frontend, binding/runtime libraries and VM. The VM identifies `f79b70b3a`;
its actual SHA256 is
`950252eeffe865ce86ac40e2349e1d96426ecef3d1bc00a62c5799df2d876944`.
All three runs finish their source/compiler/VM identity checks unchanged.

The host is an Intel Xeon E5-1680 v3 at nominal 3.20 GHz (8 cores/16 logical
processors), WSL2 Linux x86-64, about 31.3 GiB visible memory, GCC 13.3.0.
Exact OS/tool versions and executable hashes are in the raw reports;
[machine facts and report digests](performance-v2-linux-x86_64-machine.json)
also record the relevant runtime environment. Other repository jobs were
active. CPU frequency and filesystem/CPU caches were not controlled.

## Validation

- Report-model tests: **7/7** with collection stress 7 and heap verification.
  These include hand-calculated percentiles/even medians, valid scalar/buffer
  rows and planted checksum, resource, payload, counter and phase-inventory errors.
- Three 100-iteration paired smoke samples pass in each of interpreter, baseline
  JIT and optimizing JIT modes. Strict C17 compilation, production generator
  compilation and safe-fixture optional shim compilation all pass.
- Final acceptance is **five alternating C/Rune pairs of 50,000 operations per
  mode**, collected serially. Each report has **105 validated raw rows**,
  **21 phase/implementation distributions** and **393 source hashes**.
- Independent C and Rune checks agree on scalar/callback totals and the complete
  256-byte mutation result. Every phase preserves live resource count and each
  runtime worker closes with **zero** live native resources. Generator phases
  also retain zero native resources. First and repeated generation output sizes
  agree; full generation determinism remains a separate generator correctness gate.

## Timings

Median process CPU microseconds per operation, with prepared calls outside the
warm-call intervals. Warmups run outside timers. The loop is a separate control
and has not been subtracted. Complete min/p25/median/p75/p95/max distributions
and paired C ratios are retained in the raw reports.

| Phase | Interpreter | Baseline JIT | Optimizing JIT |
| --- | ---: | ---: | ---: |
| loop | 0.024 | 0.005 | 0.002 |
| load-symbol-first | 115.000 | 109.000 | 117.000 |
| load-symbol | 57.656 | 62.688 | 62.680 |
| prepare-first | 7.000 | 8.000 | 7.000 |
| prepare | 0.640 | 0.376 | 0.346 |
| scalar-first | 17.000 | 16.000 | 16.000 |
| scalar | 2.648 | 0.915 | 0.628 |
| marshal-256-first | 72.000 | 130.000 | 154.000 |
| marshal-256 | 47.258 | 11.452 | 7.043 |
| callback-first | 19.000 | 20.000 | 25.000 |
| callback | 7.196 | 4.759 | 4.417 |

Generator medians in milliseconds per operation. First use runs in a fresh
worker VM; ten repeated operations run in that VM. Preprocessing includes header
reads, parsing reuses tokens, projection/emission reuses declarations/macros,
and packaging reuses artifacts. These stage medians do not add exactly to the
complete pipeline because input/policy decoding, dependency records and timing
context also contribute.

| Phase | Interpreter | Baseline JIT | Optimizing JIT |
| --- | ---: | ---: | ---: |
| generation-first | 30.988 | 17.174 | 16.867 |
| generation-warm | 32.414 | 9.722 | 9.285 |
| preprocess | 1.133 | 0.638 | 0.340 |
| parse | 0.124 | 0.188 | 0.132 |
| projection-generation | 4.204 | 2.703 | 2.063 |
| packaging | 21.597 | 4.018 | 1.894 |

Generated safe-fixture shim compilation/linking is independent of the scalar
generator fixture. Five compiler invocations per mode have median child CPU
of 60 ms, 70 ms, 70 ms respectively; median wall times are 203.5 ms, 213.7 ms, 203.9 ms.
Child CPU includes compiler descendants and uses host tick-resolution accounting.
Wall time includes process startup, linking and supervisor polling.

Direct C median CPU times are small: scalar 1.76 ns, 1.76 ns, 2.18 ns; buffer 129.08 ns, 128.44 ns, 129.80 ns; callback 2.60 ns, 2.60 ns, 2.60 ns.
Clock resolution and host activity limit ratio precision. The generic Rune
path includes argument/result conversion, captured error records and VM reentry;
the direct C baseline calls the same subject across a DSO boundary.

## Allocation and native memory

Warm-call SML allocations are stable across modes. Rounded per operation:

| Phase | SML bytes | SML objects | Native temporary payload |
| --- | ---: | ---: | ---: |
| scalar | 664 | 27 | 0 buffer bytes |
| marshal-256 | 9328 | 365 | 256 bytes |
| callback | 1536 | 66 | 0 buffer bytes |

The loop control allocates 88 bytes/3 objects for the complete 50,000-operation
batch in these samples; snapshot/resource/timer scaffolding is included in the
raw deltas. A 256-byte buffer is allocated and released each marshalling
operation: **12,800,000 requested payload bytes per sample, 256 bytes peak**, in
both implementations. Allocator bookkeeping, resource registries, libffi
prepared-call metadata, executable closures and JIT code memory are **not
measured**. Those native costs remain unquantified; payload totals are not total
process native-memory consumption.

## Attribution and limits

- [Interpreter report](performance-v2-linux-x86_64-off.json)
- [Baseline JIT report](performance-v2-linux-x86_64-baseline.json)
- [Optimizing JIT report](performance-v2-linux-x86_64-opt.json)

Every report retains exact source and binary identities, all samples, distributions
and per-pair ratios. Commands, stdout/stderr, statuses, generated shims and workers
remain in `tests/out/ffi-v2-final-{off,baseline,opt}`. The reports measure the
generic dynamic bridge on Linux x86-64; they do not measure public policy wrappers,
GUI throughput, stack-bytecode performance or other platforms. No aggregate score
or regression threshold follows from these non-idle-host runs.

The older [schema 1 report](performance-linux-x86_64.json) is preserved as a
preliminary component snapshot (tool `fb1d42cbc`, library `8a94f1313`). Its
fixture/phase/warmup definitions differ, so it is not a like-for-like regression
baseline for schema 2. The initial integer/word assertion error and the schema 2
compile rejection of an infix `before` binding were corrected before passing
measurements; neither failed attempt is counted as acceptance.

Reproduction from a complete current checkout:

```sh
for mode in off baseline opt; do
  make ffi-performance FFI_PERF_OUT="tests/out/ffi-performance-new-$mode" \
    FFI_PERF_ITERATIONS=50000 FFI_PERF_SAMPLES=5 FFI_PERF_MODE="$mode"
done
```

For isolated checkouts, set `RUNE`, `RUNEVM` and `RUNE_LIB` to the same frozen
production snapshot. The coordinator derives `src/ffi/main.sml` and the CLI
entrypoint from the parent of the resolved library root.

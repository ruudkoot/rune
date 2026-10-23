# Measuring foreign interfaces

`make ffi-performance` writes `tests/out/ffi-performance/results.json` and
retains each subprocess argument vector, status, CPU/wall observations, stdout
and stderr. Use a fresh `FFI_PERF_OUT`. `FFI_PERF_ITERATIONS` defaults to 10,000
and `FFI_PERF_SAMPLES` to five; `FFI_PERF_MODE` selects `off`, `baseline`, `opt`
or `all`. The default measures register interpretation. No timing threshold is
part of correctness acceptance.

The Standard ML coordinator builds a separate C subject DSO and direct C
executable, checks independent checksums and alternates C/Rune execution order
between paired samples. It compiles the production generator main from the
checkout containing `RUNE_LIB`, then generates and separately compiles the safe
fixture's optional adapters. For isolated worktrees, `RUNE`, `RUNEVM` and
`RUNE_LIB` select the actual compiler, VM and production library/source snapshot.

Schema 2 retains all samples and reports min, p25, median, p75, p95 and max CPU
nanoseconds per operation, plus wall time and SML allocations where measured.
Percentiles use nearest rank; an even-sized sample's median is the midpoint of
its two middle observations. Matching steady-state phases have distributions
of paired Rune/direct-C CPU ratios. Zero-duration C intervals produce no ratio.
Source, VM, compiler, worker, subject, generated shim and compiled shim hashes
identify the inputs. The coordinator rejects source/compiler/VM changes during
a run. Compilation and worker startup are outside the runtime phase timers.

| Phase | Measured work | Direct C comparison |
| --- | --- | --- |
| generation-first | First complete scalar-fixture input/preprocess/parse/analyze/emit/hash/package operation in a fresh VM | None |
| generation-warm | Ten repeated complete operations in the same VM | None |
| preprocess | Ten reads/preprocessing passes over original headers and their transitive include | None |
| parse | Ten declaration-parser passes over already preprocessed tokens | None |
| projection-generation | Ten target-analysis, projection and artifact-emission passes over existing declarations/macros | None |
| packaging | Ten hashes and immutable-set packaging operations over existing emitted artifacts | None |
| shim-compile | One C compiler/linker invocation per sample for generated safe-fixture shared adapters | Compiler child CPU and elapsed wall time, separate implementation label |
| loop | Warmed SML loop and Word64 increment, with the same measurement scaffolding | Control baseline, not subtracted from call costs |
| load-symbol-first, load-symbol | First then repeated library open/symbol resolution/release | None |
| prepare-first, prepare | First then repeated fixed-call preparation/release, with an existing symbol | None |
| scalar-first, scalar | First then warmed prepared `uint64_t -> uint64_t` call and result decoding | Same function in a separate DSO; cross-unit inlining is unavailable |
| marshal-256-first, marshal-256 | First then warmed 256-byte input/output allocation/copy/call/copy-back/release | Same C allocation/copies/mutation/free and full-array verification |
| callback-first, callback | First then warmed outward call, synchronous SML callback entry and result decoding | Same C function through a C callback pointer |

Runtime warmups use `min(1000,max(10,iterations div 10))` operations, outside the
timers and allocation deltas. The marshalling array is reset before its timed
steady-state loop. First-use observations include the first operation on that
path after instrumentation; they do not include VM startup. Generator first-use
means a fresh VM, not a flushed filesystem or CPU cache. Warm generator passes
still read their inputs; OS caches are uncontrolled. Stage results reuse the
preceding stage's outputs, so their timings do not sum exactly to the complete
pipeline (policy/profile decoding and dependency records also have costs).

`Runtime.stats` deltas report SML bytes, objects and collections. They include a
small constant cost from taking snapshots, resource counts and clocks; the
separate loop control makes that visible, without assuming subtraction produces
a universal foreign-call cost. Resource counts before/after every phase agree,
and each runtime worker closes with zero live native resources.

Native memory figures count exactly the benchmark-owned buffer payload: 256
bytes per marshalling operation and 256 bytes peak, in both implementations.
They exclude allocator bookkeeping, foreign-resource registries, prepared libffi
metadata and executable closure storage, whose native byte costs are **not
measured**. Those fields remain null rather than claiming zero native overhead.
C compiler CPU uses reaped-child user plus system deltas from
`Posix.ProcEnv.times`; it includes compiler descendants and has host clock-tick
resolution. Its wall interval also includes process startup, linking and the
supervisor's polling. Direct C phase CPU uses `clock()` and small intervals have
resolution noise.

Measurements describe this generic dynamic bridge, including result/error
capture and conversion. Generated public wrappers add policy and ownership work.
There is no aggregate score, GUI-throughput prediction or claim about future
direct linking. Use an otherwise idle machine and the dated evidence before
making performance decisions.

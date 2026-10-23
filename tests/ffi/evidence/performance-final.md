# Final Runeffi performance measurements — 2026-10-23

**PASS**, five alternating C/Rune pairs with 50,000 steady-state operations in
each of register interpretation, baseline JIT and optimizing JIT. The modes
ran serially with singleton CPU affinity **15**. Each schema 2 report contains
105 validated observations and 21 phase/implementation distributions. All
checksums, full-buffer comparisons and native-resource invariants pass; every
runtime worker finishes with zero live native resources.
The current report-model suite also passes **7/7** with collection stress 7
and heap verification, including its planted invalid-observation checks.

The complete source snapshot is `ddba4faad`. Final production compiler/VM
assets were copied into the isolated measurement worktree. Before and after
collection, **500 snapshot files** were verified unchanged, including matches
to 379 production source/build/fixture files and 91 runtime/ISA files, 26
copied library manifests and four launcher/binary assets. Every report also
independently verified its **393 actual source hashes**, compiler executable,
compiler bytecode, C compiler and VM during its run. These counts come from
the captured inventories. Main sources and binaries were never modified.

| Final asset | SHA-256 |
| --- | --- |
| VM | `eef487c7081c347cabee509ed1e71945997190dbfe6a99b2bdc0a84a96aa1531` |
| Compiler RBC | `36225003fa50774cf84419b904d5c0e74de65bb97eddd7b7525c0ab704695be0` |
| Compatible release REPL image, copied for identity only | `e7b2fbdb2ff8730307adcacda8b9bb7b66d5bc433cb1af3d8fccbd2ab954ba51` |

The host reports an Intel Xeon E5-1680 v3, nominal 3.20 GHz, 16 logical CPUs,
32,812,676 KiB visible memory, WSL2 Linux and GCC 13.3.0. CPU 15 shares a
physical core with logical CPU 7. Other release/matrix jobs could run on the
host; affinity provides no exclusive CPU reservation. Clock frequency and
filesystem/CPU caches were not controlled. These observations establish no
timing regression threshold or cross-platform performance claim.

## Phase timings

Median process CPU **microseconds per operation**. First use includes one
operation on that path after instrumentation; warmups and preparation remain
outside warmed call intervals. The control-loop result is not subtracted.
Reports retain all samples, min/p25/median/p75/p95/max distributions and
paired ratios against direct C.

| Phase | Interpreter | Baseline JIT | Optimizing JIT |
| --- | ---: | ---: | ---: |
| loop | 0.023 | 0.008 | 0.003 |
| scalar | 3.202 | 1.189 | 0.790 |
| marshal 256 bytes | 55.141 | 11.561 | 7.244 |
| callback | 8.259 | 5.002 | 5.188 |

Median process CPU **milliseconds per operation** for generation and the
separately invoked C compiler. Full first generation uses a fresh VM; warm
generation repeats ten times in that VM. Parsing reuses preprocessed tokens;
projection/emission reuses parsed declarations; packaging reuses artifacts.
Their intervals do not sum exactly to the complete pipeline. Shim compilation
uses reaped compiler-child user/system CPU, distinct from Rune process CPU.

| Phase | Interpreter | Baseline JIT | Optimizing JIT |
| --- | ---: | ---: | ---: |
| generation first | 36.185 | 20.025 | 17.328 |
| generation warm | 35.579 | 11.185 | 8.287 |
| preprocessing | 1.649 | 0.432 | 0.364 |
| parsing | 0.134 | 0.118 | 0.126 |
| projection/emission | 4.252 | 2.377 | 2.149 |
| hashing/packaging | 22.936 | 3.827 | 2.531 |
| optional shim C compilation | 70.000 | 60.000 | 70.000 |

Loading/symbol lookup, preparation and first-call costs remain separate
distributions in the reports. The direct C subject lives in a separate DSO,
and paired execution order alternates. C scalar/callback intervals are small;
their ratios are sensitive to timer and scheduling variation. No aggregate
score is inferred from them.

## Memory and reproducibility

Rounded SML allocations per warmed operation remain 664 bytes/27 objects for
scalar calls, 9,328 bytes/365 objects for marshalling and 1,536 bytes/66 objects
for callbacks, in all modes. Each measurement includes constant scaffolding
overhead; the separate 50,000-operation control batch allocates 88 bytes and
three objects. Native marshalling requests exactly 256 buffer payload bytes
per operation: **12,800,000 per sample, 256 peak**, with release on each path.
Native allocator/resource/libffi metadata, executable callback thunks and JIT
code memory are unmeasured and remain explicitly null in the raw accounting.
Payload counts are not process native-memory totals.

- [Interpreter report](performance-final-linux-x86_64-off.json)
- [Baseline JIT report](performance-final-linux-x86_64-baseline.json)
- [Optimizing JIT report](performance-final-linux-x86_64-opt.json)
- [Machine, before/after freeze manifest and report digests](performance-final-linux-x86_64-machine.json)

All three runs exited 0. Coordinator wall times were 45.04, 30.85 and 29.02
seconds respectively. Complete command arguments, stdout/stderr, workers,
native subjects and optional shim artifacts remain under
`tests/out/ffi-release-final-{off,baseline,opt}`. The method is documented in
[`docs/ffi/performance.md`](../../../docs/ffi/performance.md).
The prior schema 1 and [earlier schema 2 component snapshots](performance.md)
are preserved unchanged and are not relabeled as final-core measurements.

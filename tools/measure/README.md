# Measurement tools

Build `bin/rune-measure` with Make after building Rune. The controller and
reporters are Standard ML. They share the benchmark catalogue, process
supervision, GC-log parser, exact integer counters and MMU calculation.
`--help` identifies this document. Each mode rejects incomplete options.

| Mode | Input / purpose |
|---|---|
| `benchmarks [time\|count\|stats]` | Benchmark manifest; `--profile`, `--filter`, `--configs`, `--samples`, `--mode fresh\|repeated`, `--repetitions`, `--level`, `--update-budgets` |
| `provenance ROLE TOOL BUNDLE` | Repository and payload identity, including foreign checkouts |
| `classify STATUS DIR FAILURE` / `validate STATUS DIR ROUNDS` | Captured `stdout`/`stderr`; category on stdout |
| `census [OPTIONS] WORKLOAD...` | Stock/census execution agreement, static and binary traces, atomic DONE |
| `gc-eval [OPTIONS] CANDIDATE BASELINE` | Paired collector workloads, bounded parallel execution and verified resume |
| `gc-eval-score DIRECTORY` | Collector comparison report; failed or missing results are failures |
| `gc-probe32 [OPTIONS]` | 32-bit live-space probes; `--vm`, `--fill`, `--latency`, `--out`; `--report` reads retained logs |
| `mmu [OPTIONS] LOG` | GC pauses, counts and utilisation; `--json`, `--row`, `--per-pass`, `--windows`, `--wall`, `--self-test` |
| `jit-dump DIRECTORY [FILTER]` | Code/role views, Callgrind counters, opcode/role summaries, store and diff modes |
| `elab-stats [--top N] [FILES...]` | Elaboration profiling, otherwise stdin |
| `perf-groups [--top N] [FILES...]` | Weighted perf symbols and callchains, otherwise stdin |
| `perf-cycles [OPTIONS] [FILTER]` | Hardware counters; compiler/native/JIT modes, profiling and heap sweep |
| `perf-units [OPTIONS] [phases\|mid\|globals]...` | Compiler phase, Mid roundtrip and global-root experiments |
| `perf-repl [RUNS]` | PTY-based REPL latency with private state/history |
| `hol-kernel HOL [FILE]` / `hol-theory HOL THEORY [OPTIONS]` | HOL kernel/theory builds in private copies and unit caches |
| `lex-corpus [OPTIONS] DIRECTORY` | Lexer modes, accepted intersection, baseline and finite-difference cost |
| `opt [ARGS...]` / `bisect-fuel PROGRAM [ARGS...]` | Native optimizer convenience and fuel bisection |
| `gcbench-measure NAME [OPTIONS] -- COMMAND...` | Idle-gated samples, least-cycle selection, spread and event sets |
| `gcbench-roadmap [EXPERIMENT...]` | Original GC experiment schedule; traces/ops supplied through GCB variables |
| `gcbench-report DIRECTORY` / `gcbench-tables [OPTIONS]` | Captured GC harness tables and calibrated fits |
| `layout-measure [-c CCS] [-k KERNELS] [CONFIG...]` | Idle-gated native layout samples |
| `layout-micro [CONFIG...]` / `layout-tables [DIRECTORY]` | Native operation samples / six layout reports |
| `sweep [NAME...]` / `sweep2 [OPTIONS]` | Layout/simulator configurations with bounded parallel jobs |
| `sim-report [DIRECTORY]`, `sim-report2 [DIRECTORY]`, `sim-report3 [DIRECTORY]` | Captured simulator/layout question reports |
| `validate2`, `validate-proto`, `pretenure` | Simulator replay against recorded VM execution |
| `timeline`, `pauses`, `checkold` | Trace models, calibrated pauses and old-field provenance |
| `intinf-compilers [OPTIONS]` | Complete compiler pairs against revision-specific expected bytecode hashes |
| `intinf-kernels [OPTIONS]` | Retained fixed arithmetic bytecodes across implementations |
| `intinf-paths [OPTIONS]` | Same retained source, freshly compiled current arithmetic paths |
| `intinf-design [OPTIONS]` | Test-only constant backend selection, exact-answer checks and normal compiler controls |
| `intinf-dispatch [OPTIONS]` | Frozen exploratory operation/shape inputs; verified `--reuse-run` |
| `intinf-conversion [OPTIONS]` | Import/copy/export and packed-storage roundtrips, reported separately |

Instrumentation uses external `perf`, GNU `time`, `objdump`, `taskset`, `flock`
and ordinary compiler/build tools. They supply hardware, decoding, scheduling
and host execution. SML owns parsing, orchestration, comparisons and reports.
Python remains only where an explicitly retained independent arithmetic or
latency oracle supplies expected answers. No measurement invokes a retired
Python or shell measurement controller.

Timing selections are outside `make check`: `bin/rune-test --tier
measurement-runs` runs exclusively. The MMU closed forms and frozen independent
scan vectors are deterministic checks. `make bench`, `make bench-count` and
`make bench-stats` use the same public controller. Timed and instrumented
phases remain separate; failed output or missing counters cannot produce a
successful numeric sample. Keep the raw run directory and tool/input hashes.

The original idle thresholds, CPU 5 defaults, warmups and sample counts remain.
`LAYOUT_CPU` can select another permitted CPU. `LAYOUT_LOADMAX` and
`LAYOUT_RERUNMAX` permit explicitly non-idle exploratory runs; default to 1.5
and 3.0. GC harness admission retains `LOADMAX`/`SPARE`. Load/memory waits and
retries are finite, and controllers kill and reap failed child groups.
Reports retain historical command names where they describe the measurements
that produced a captured dataset; current invocations use the modes above.

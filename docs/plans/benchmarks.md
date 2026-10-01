# Benchmark suite roadmap

Status: **in progress**, 2026-10-01. M0 and M1 are complete with
[recorded validation](../../examples/benchmarks/validation.md). M2, M3 and M5 are in progress; M6 is complete with recorded evidence; M4 and M7-M8 remain planned. Source inventory entries are scheduled work, not passing ports.

## Goal and current baseline

Build a documented, reproducible benchmark suite under
`examples/benchmarks/`, covering the classic Standard ML collections,
Haskell's nofib, and OCaml's Sandmark in stages. Inventory every upstream
workload, import suitable programs, and record concrete reasons for
duplicates, exclusions, and deferred ports. Include correctness checks,
measurement tooling, compiler comparisons, and a literature review.

Rune already has useful starting points:

* `tests/perf/run-perf.sh` checks deterministic instruction and allocation
  budgets and expected output for a small performance suite. `make perf`
  measures those programs through the existing configuration matrix.
* The external MLton runner and shims on commit `3a3c504` are adaptation
  references from the heap-layout branch, not files in this `origin/master`
  baseline. Their allocation table does not supply a general result check:
  each imported program also needs an independent correctness oracle.
* `scripts/perf-cycles.sh` supports cycle measurements and profiling.
  [runtime.md](../runtime.md) describes the counts, and
  [performance.md](../performance.md) records the existing timing method.
  The new suite must control inputs and its execution environment for
  comparable counts.

Build on these tools rather than creating a second configuration matrix.
Keep the existing performance checks as the baseline while the broader
suite grows. Implementation starts with the
[pinned source inventory and audit](../../examples/benchmarks/audit.md).
The [runnable catalogue](../../examples/benchmarks/README.md) contains the M1
pilots and the growing M2 classic collection. M2 remains open while its
scheduled imports and normal-profile validation are reconciled.

## Sources, naming, and portable programs

### Upstream collections

| Collection | Starting point | Audit requirements |
|---|---|---|
| Classic SML: SML/NJ | [smlnj/benchmarks](https://github.com/smlnj/benchmarks) | Programs, drivers, data, known broken workloads, and runtime-specific facilities. |
| Classic SML: MLton | [MLton/mlton/benchmark](https://github.com/MLton/mlton/tree/master/benchmark) | Individual programs, `Main.doit` drivers, datasets, numeric assumptions, and Rune's existing adaptations. |
| Classic SML: ML Kit | [melsman/mlkit/test](https://github.com/melsman/mlkit/tree/master/test) | Use benchmark entries in the test manifests to distinguish workloads from language and Basis regression tests; inspect related development variants. |
| nofib | [ghc/nofib](https://github.com/ghc/nofib) | All categories, nested workloads, drivers, input modes, expected output, dependencies, and reliance on demand and sharing. |
| Sandmark | [ocaml-bench/sandmark](https://github.com/ocaml-bench/sandmark) | Individual executables and run configurations, not just collection directories; dependencies, data, and sequential versus runtime-specific workloads. |

Pin upstream revisions before implementation. The inventory records each
workload's repository, revision, source paths, original name, authors,
notices, dataset origins, related variants, proposed Rune name, milestone,
and disposition. Inspect notices for individual programs and datasets
rather than assuming one repository license describes every file.

Every discovered workload receives an explicit disposition:

* **Import:** suitable for portable SML97, with dependencies and a planned
  milestone identified.
* **Duplicate:** the same implementation and workload are already covered;
  name the retained entry and preserve the additional provenance.
* **Defer:** name the missing capability or dependency and the condition for
  reconsideration.
* **Exclude:** give the reason and supporting source evidence, such as a
  regression test with no benchmark workload.

An import entry is a commitment, not evidence that a program is runnable.
Materially different algorithms, representations, inputs, or evaluation
strategies remain distinct variants.

### Naming and variants

* Put each benchmark under `examples/benchmarks/<benchmark-name>/`.
* Use the MLton variants already supported by Rune's external runner as
  the starting point. Add unique SML/NJ and ML Kit workloads, preserving
  materially different variants.
* Preserve established names, preferring names used in the literature.
  Document aliases such as **Pseudoknot**, `nucleic`, and `nucleic2`,
  including whether they identify different variants.
* Give classic SML benchmarks the unsuffixed name. Use `-nofib` and
  `-sandmark` for collisions; add an upstream category or source qualifier
  only when necessary to disambiguate further.
* Give demand-sensitive nofib ports explicit `-lazy` and `-strict`
  names. Where needed, put the collision suffix before the style suffix.
* Exact duplicates share one implementation and retain all provenance.
  Similar names alone do not establish duplication.

### Translation policy

Keep kernels, input generation, checks, and translation support in SML97.
Use thin shell adapters for compilation, process execution, and
operating-system measurements. Preserve algorithms, data structures,
numeric semantics, and input distributions. Record changes to stopping
conditions, representations, library calls, and output.

Implement faithful lazy variants with explicit memoized delays where demand
and sharing matter. Add strict SML variants when evaluation or allocation
patterns differ materially. Ordinary non-memoized thunks do not preserve
sharing. Both variants must compute the specified result; their counts
and times remain separate measurements. This support must not depend on
implementing separate language or runtime laziness features.

Make arbitrary-precision arithmetic, modular arithmetic, integer-width
assumptions, and floating-point validation explicit. Do not replace
arbitrary-precision arithmetic merely because smoke inputs fit in machine
integers. Preserve observable evaluation order in OCaml ports and document
library replacements and representation changes.

Defer workloads requiring parallelism, effect handlers, FFI, or unavailable
runtime facilities. Record the missing capability and the condition for
reconsideration. Do not add prerequisite compiler or runtime features
through this roadmap, or silently replace those workloads with sequential
or CPS adaptations.

## Suite contract and documentation

### Runnable benchmark contract

Each benchmark directory contains ordered SML sources, a small driver,
fixed input profiles, reviewed expected results or a numerical checker,
and provenance. Use portable drivers around existing entrypoints rather
than rewriting kernels to fit an artificial common API.

A machine-readable manifest identifies source order, profiles, arguments,
input files, result checks, resource limits, diagnostic tags, and
implementation status. Preserve meaningful upstream parameters instead of
forcing every program into a universal size argument.

| Profile | Purpose | Default time limit | Default memory limit |
|---|---|---|---|
| Smoke | Small inputs for correctness and routine checks. | 30 seconds | 1 GiB |
| Normal | Fixed inputs for comparative measurements. | 600 seconds | 4 GiB |
| Large | Explicitly selected workloads for scaling and memory studies. | 3,600 seconds | 8 GiB |

Record overrides and the platform's memory-limit accounting and enforcement
mechanism. Missing enforcement support must be visible; do not silently
disable a requested limit. Distinguish cumulative allocated bytes from peak
live memory and process memory when selecting inputs.

Programs must consume and validate their results, including repeated
invocations. Numerical programs use documented, benchmark-specific error
bounds. Clock-dependent searches use a documented deterministic work limit
for correctness and count measurements. Input files, seeded generators,
and expected results are part of the workload identity.

### README contract

`examples/benchmarks/README.md` contains the requested linked overview
table: **name**, **source**, and **one-sentence description**. The name
links to the benchmark's section below the table.

Every imported benchmark receives a section covering:

1. Algorithm and workload, including what the selected inputs exercise.
2. History, authorship, upstream revision, source paths, and aliases.
3. Differences between known variants.
4. Changes made for Rune, including translation decisions.
5. Compiler and runtime behavior likely to affect performance.
6. Inputs, result validation, and useful literature references.

Distinguish explanations supported by papers, hypotheses inferred from
source inspection, and findings established by measurements. A benchmark
does not isolate a compiler feature merely because it exercises that
feature. Deferred programs belong in the inventory with their blockers,
rather than appearing as runnable benchmarks in the overview.

Validate consistency between the manifest, overview, per-benchmark sections,
and runnable directories, including local links, names, ordered sources,
fixture references, and profile completeness.

## Milestones and dependencies

| Milestone | Status | Work | Completion criteria |
|---|---|---|---|
| **M0 — Inventory and literature review** | Complete | Audit SML/NJ, MLton, ML Kit, nofib, and Sandmark at pinned revisions. Inspect build manifests, nested workloads, dependencies, datasets, and existing Rune adaptations. Group related variants and map workloads to compiler and runtime concerns. | Every discovered workload has an explicit disposition: import, duplicate, defer, or exclude. Every disposition has evidence or a reason. The bibliography and naming map are recorded. |
| **M1 — Suite foundation and pilots** | Complete | Establish the directory contract, manifest, documentation template, portable drivers, deterministic inputs, and correctness runner. Pilot classic `tak` and list sorting, nofib primes in lazy and strict forms, and Sandmark `bdd`. | Pilots build and validate on Rune, MLton, SML/NJ, and Poly/ML. Lazy and strict variants agree on results. Negative checks demonstrate that incorrect output and resource-limit failures are detected. |
| **M2 — Classic SML collection** | In progress | Import suitable workloads from the three SML sources. Begin with recursive kernels, rewriting, sorting, numerical programs, and search; then add larger generators, simulators, and applications. Reuse reviewed external-runner adaptations. | Every suitable classic SML workload is imported and documented. Remaining entries have concrete blockers. Each import passes smoke checks and has a validated normal profile. |
| **M3 — nofib kernels and GC workloads** | In progress | Port suitable `imaginary`, `spectral`, `shootout`, and `gc` workloads, including nested collections such as `spectral/hartel`. Cover streams, higher-order functions, symbolic processing, graphs, arithmetic, and allocation patterns. | Every suitable kernel has a validated port. Each port records its treatment of laziness, sharing, numeric types, and forcing. Materially different lazy and strict variants are separately named and measured. |
| **M4 — nofib applications** | Planned | Port suitable `real` applications in dependency order. Prioritize parsing, type inference, compression, interpreters, symbolic algebra, rendering, and scientific workloads. | Each application includes its required portable modules and deterministic data. Results agree with upstream fixtures or the original Haskell program. Feature-dependent applications have explicit blockers. |
| **M5 — Sandmark sequential workloads** | In progress | Port self-contained sequential workloads first, including decision diagrams, rewriting, streams, numerical programs, rendering, and graph processing. Audit individual executables within collection directories. | Every suitable workload is imported or scheduled with its dependencies. OCaml library replacements and evaluation-order changes are documented. Ecosystem applications and runtime-specific workloads have explicit dispositions. |
| **M6 — Measurement and comparisons** | Complete | Extend Rune's existing matrix, count, and profiling tools to consume the manifest. Add serial timing runs, compile measurements, raw results, and reports. | A recorded run reproduces selected inputs and configurations. Reports include correctness status, complete samples, configuration metadata, and separate failure categories. |
| **M7 — Routine verification** | Planned | Select a bounded smoke set covering the main workload families and translation styles. Add metadata validation and smoke correctness to routine checks; retain broader explicit targets. | Routine checks remain practical. Every imported benchmark is covered by a broader correctness target. Incorrect results cannot contribute timing results. |
| **M8 — Coverage closure and maintenance** | Planned | Reconcile imports against pinned inventories, close documentation gaps, publish the initial report, and rank additional candidates. Document upstream refresh and baseline-update procedures. | Every inventory entry is accounted for. Imported programs satisfy the suite contract. Recorded validation and outstanding checks are clearly distinguished. |

M1 depends on M0. M2, M3, and M5 build on M1; M4 follows M3's translation
support. M6 starts with the pilots and expands with each import wave. M7
follows validated coverage across all three source families. M8 closes the
initial roadmap. The numbered order is the default implementation sequence;
measurement tools grow alongside the imports.

For M2, begin with existing runner workloads such as `fib`, `tailfib`,
`tak`, `boyer`, `knuth-bendix`, `merge`, `fft`, `barnes-hut`,
`nucleic`, and `tsp`, then larger programs such as `lexgen`, `mlyacc`,
`hamlet`, and `vliw`. This is an initial order, not a permanent selection.

For M3 and M4, preserve nofib's distinction between toy programs,
algorithmic kernels, and applications. Do not let the easiest recursive
kernels stand in for the complete collection. Audit older GC variants and
nested Hartel workloads individually before assuming they build or
duplicate another entry.

For M5, use executable inventories and run configurations to identify
workloads within `bdd`, `kb`, `hamming`, `almabench`,
`numerical-analysis`, `minilight`, `graph500seq`, and other suitable
sequential collections. Inspect larger applications' dependency graphs
before classifying them as self-contained ports.

### Evidence and status updates

For each milestone, record the commit, date, delivered artifacts, exact
validation commands, tested configurations and profiles, and outstanding
checks. Partial delivery stays **in progress**. Missing-host,
sandbox-limited, or otherwise unrecorded validation is outstanding, not a
pass.

M5 may establish a dependency order before all its imports are complete;
scheduled entries remain planned. M8 cannot close while suitable workloads
are merely scheduled: every import commitment must be delivered or
reclassified with a concrete, documented blocker.

## Correctness, measurement, and integration

### Correctness and portability

* Validate smoke and normal inputs on Rune and supported SML hosts, using
  hosts supplied by `make hosts`.
* Check Rune at `-O0` and `-O2`, and check applicable stack, register
  interpreter, JIT, and native configurations.
* Obtain expected results from independent implementations or upstream
  fixtures and review them before committing. Check the full result or a
  meaningful summary, not just successful termination.
* Test numerical tolerances against deliberately perturbed results. Test
  demand and sharing in lazy ports where essential to the workload.
* Follow Rune's execution rules: fixed program names and working
  directories, controlled streams, deterministic seeds, and fresh filesystem
  state. Arguments and stream kinds can affect allocation counts.
* Include small-input checks across applicable widths and platforms.
  Emulated platforms supply correctness evidence, not native timing claims.

The runner's negative scenarios cover incorrect output, numerical results
outside tolerance, compile errors, runtime failures, timeouts, memory
limits, and unavailable requested configurations. A failed correctness
check must prevent acceptance of a timing result.

### Measurement policy

Make comparisons between identical SML sources on Rune, MLton, SML/NJ, and
Poly/ML the standard report. Use Haskell and OCaml originals as correctness
references, not mandatory cross-language timing baselines. Reuse the
existing matrix's distinction between hosts' own Basis Libraries and Rune's
Basis Library compiled by hosts for library-sensitive workloads.

Report fresh-process execution separately from repeated in-process
execution. Preserve warmup samples and label repeated execution without
assuming it reached steady state. Barrett et al.'s
[*Virtual Machine Warmup Blows Hot and Cold*](https://arxiv.org/abs/1602.00602)
demonstrates why discarding a fixed warmup does not establish that assumption.

* Run timings serially. Use ten fresh-process samples by default; publish
  all samples, the median, and the interquartile range. Retain failures in
  the record rather than selecting only favorable samples.
* Use the same fixed inputs for every compared configuration. Record batch
  repetitions and whether setup and data loading are included. Do not
  calibrate different amounts of work for different engines.
* Record compiler versions and options, Rune revision and dirty state,
  source and input identities, machine details, runtime settings, and mode.
* Keep compilation, runtime, allocation, GC statistics, and optional
  hardware counters distinct. Profiling and count instrumentation run
  separately from headline timings.
* Reuse deterministic count checks and budget conventions. Compare
  instruction counts only where the execution model promises agreement;
  compare allocation counts across applicable Rune engines on identical
  inputs. Different source variants need not allocate identically.
* Enforce profile time and memory limits and record overrides. Distinguish
  missing configurations, compile errors, incorrect results, runtime
  failures, timeouts, and memory limits.
* Require correctness before accepting measurements. Keep per-benchmark
  results visible; any aggregate states its included workloads, variants,
  profiles, and missing configurations.

The new ten-sample report records its own method. Existing performance
reports retain their original method and are not silently reinterpreted.

### Commands and routine checks

Provide these targets, with profile, configuration, and benchmark filters:

| Target | Behavior |
|---|---|
| `make bench-check` | Validate metadata and run result checks for selected workloads; default to the bounded smoke set. |
| `make bench-count` | Collect deterministic Rune counts for selected workloads; default to smoke inputs. |
| `make bench` | Run correctness-gated serial measurements; default to normal inputs and the standard SML comparison configurations. |

The manifest marks the bounded routine set; explicit selection can cover
the full imported collection. Large inputs always require explicit
selection. Missing selected configurations are reported separately from
failures, and reports state which comparisons remain incomplete.

Add metadata validation and the bounded smoke correctness set to
`make check` in M7. Keep noisy timing thresholds outside that target.
Only promote reviewed deterministic counts to performance budgets, and
update them deliberately with the reason recorded. Run the repository's
required acceptance checks when implementing the suite and tooling.

## Literature review and diagnostic coverage

The following is the initial referenced survey. M0 expands it using the
actual inventories, and every import needs useful benchmark-specific
references. Follow source ancestry as well as names: an algorithm paper
explains the algorithm but does not identify a particular port by itself.

| Benchmark family | Literature anchor | Diagnostic questions to investigate |
|---|---|---|
| Classic recursive and symbolic benchmarks | Gabriel, [*Performance and Evaluation of Lisp Systems*](https://dreamsongs.com/Files/Timrep.pdf), 1985. | Calls, recursion, branching, symbolic structures, and benchmark-specific optimization. |
| nofib kernels and applications | Partain, [*The nofib Benchmark Suite of Haskell Programs*](https://doi.org/10.1007/978-1-4471-3215-8_17), 1992, plus [the maintained suite](https://github.com/ghc/nofib). | Coverage beyond small kernels; effects of demand, sharing, and realistic applications. |
| Pseudoknot / nucleic | Hartel et al., [*Benchmarking Implementations of Functional Languages with Pseudoknot, a Float-Intensive Benchmark*](https://doi.org/10.1017/S0956796800001891), 1996. | Floating-point representation, search, pruning, and delayed coordinate calculations. |
| FFT | Cooley and Tukey, [*An Algorithm for the Machine Calculation of Complex Fourier Series*](https://www.cs.jhu.edu/~misha/ReadingSeminar/Papers/Cooley65.pdf), 1965. | Numerical operations, recursive decomposition, representations, locality, and intermediate allocation. |
| Barnes-Hut | Barnes and Hut, [*A hierarchical O(N log N) force-calculation algorithm*](https://www.nature.com/articles/324446a0), 1986. | Numerical operations, tree representation, traversal, locality, and allocation. |
| Classic SML and ML Kit workloads | [MLton's optimization documentation](https://www.mlton.org/guide/20241230/WholeProgramOptimization); Elsman and Hallenberg, [*Integrating region memory management and tag-free generational garbage collection*](https://elsman.com/mlkit/pdf/jfp2021.pdf), 2021. | Specialization, unboxing, higher-order functions, object lifetimes, and the memory/time tradeoff. |
| Sandmark | [Suite sources](https://github.com/ocaml-bench/sandmark/tree/main/benchmarks); Sivaramakrishnan et al., [*Retrofitting Parallelism onto OCaml*](https://arxiv.org/abs/2004.11663), 2020, and [*Retrofitting Effect Handlers onto OCaml*](https://arxiv.org/abs/2104.00250), 2021. | Sequential runtime costs and the boundary between portable workloads and runtime-specific tests. |
| GC diagnostics | [Ellis-Kovac-Boehm GCBench](https://www.hboehm.info/gc/gc_bench.html). | Allocation, retained data, and object lifetimes, with the benchmark's documented limitations. |
| Measurement methodology | Kalibera and Jones, [*Rigorous Benchmarking in Reasonable Time*](https://kar.kent.ac.uk/33611/), 2013; Barrett et al., [*Virtual Machine Warmup Blows Hot and Cold*](https://arxiv.org/abs/1602.00602), 2017. | Experimental variation, warmup behavior, and the strength of performance claims. |

Treat these diagnostic questions as hypotheses until supported by source
analysis or measurements. Cover both small diagnostic programs and larger
applications. Report sensitivity to a compiler transformation only with an
explanation of the source behavior and appropriate evidence.

### Additional candidates

Consider these sources after mapping overlap with the main families:

* **Gabriel and Larceny/R6RS:** additional recursive, symbolic, and
  allocation workloads. Consult the [Gabriel Scheme archive](https://www.cs.cmu.edu/afs/cs/project/ai-repository/ai/lang/scheme/code/bench/gabriel/0.html)
  and [Larceny's R6RS benchmark descriptions](https://www.ccs.neu.edu/home/will/Larceny/benchmarksAboutR6.html)
  for ancestry and missing coverage.
* **GCBench:** consider a portable SML version where existing collections
  do not cover the relevant lifetime patterns. Keep its role as an
  artificial GC diagnostic explicit.
* **Computer Language Benchmarks Game:** inspect [the workloads](https://benchmarksgame-team.pages.debian.net/benchmarksgame/index.html)
  after accounting for nofib's `shootout` and related Sandmark ports.
  Different implementations may use materially different algorithms.
* **PBBS:** consider [the Problem Based Benchmark Suite](https://www.cs.cmu.edu/~pbbs/)
  for additional graph, sorting, and geometry coverage. Keep parallel
  candidates deferred under the agreed feature policy.

M8 records ranked candidates, overlap, likely contribution, and blockers.
Adding a further collection is a subsequent scope decision, not an implicit
requirement to port every candidate in this roadmap.

## Completion and maintenance

The initial suite is complete when every pinned inventory entry is
accounted for, every suitable import commitment is delivered, and imported
programs satisfy the source, correctness, documentation, and measurement
contracts. Publish the initial report with raw evidence, clearly identifying
checks that remain unavailable or incomplete.

For upstream refreshes, record the new revision and inventory changes,
review source and data differences, reconsider duplicate and deferred
entries, and rerun affected correctness checks before accepting new
measurements. Preserve historical result identities. Update counts and
budgets deliberately rather than regenerating them to hide a failure.

The defaults remain broad staged coverage, portable SML97, separately named
meaningful variants, SML compiler comparisons, and documented deferral of
unsupported facilities. Performance improvements themselves belong to the
relevant compiler, JIT, heap-layout, and collector roadmaps.

# lexifi-g2pp provenance

### Algorithm and workload

Calibrate the source five-parameter G2++ model against its 196 embedded
swaption quotes. Retain Gregorian-minute dates, fixed schedules, the
error-function approximation, Brent-style root search, eleven-point Gaussian
quadrature and differential-evolution least-squares optimization. Each
calibration creates its pricer closures and mutable work arrays; do not cache
a completed calibration across Benchmark.run calls.

### History, aliases and notices

[LexiFi's Sandmark workload](https://github.com/ocaml-bench/sandmark/tree/5605805954a00497ed197c930641cddd580e1507/benchmarks/lexifi-g2pp),
pinned at 5605805954a00497ed197c930641cddd580e1507, credits LexiFi SAS, copyright 2000-2013, under GPL version
3 or later. Preserve all selected .ml/.mli files, README, Dune, output fixture
and COPYING under upstream. The supplied 196 quote records remain in source
order. No separate quote-provider credit or dataset notice is stated there;
the fixture is historical input rather than current market data.

The executable main.exe is named lexifi-g2pp by its established collection
name. It is distinct from unrelated main executables. The source README
describes a stripped-down calibration application; do not replace it with a
small root-finding or optimizer-only kernel.

### Translation, parameters and numeric behavior

Use portable SML97 records, arrays, closures, exceptions and default binary64
reals. Read-only schedule/quadrature/quote containers use vectors; mutable
population and pricer arrays retain their update scopes and ordering.
Methods of the OCaml modules become explicit SML structures and functions.
The fixed Random.State.make [|0|] state is independently observed and stored as
55 initial words; all subsequent source draws, rejection loops and their order
remain in the common OCaml-random adapter. Precomputation replaces the source
seed-expansion work, not the generated sequence.

Preserve tuple/right-operand order where callbacks affect observations.
Original observations establish initial Brent evaluation order and complete
sphere-optimizer improvement traces. Population mutation/recombination order,
strict improvements, source best/random base selection and inclusive stopping
conditions remain. A full generation precedes the maxf < ncalls check:
the published budget 2000 finishes at 2040 evaluations.

The source black_price variable sqrtt contains a year fraction without a
square root; preserve its actual expression. Source date division truncates
toward zero, including negative-epoch helper observations. Profiles retain
today 2012-01-01 and finite bounded dates. Integer calculations fit signed
31-bit values; floating operations remain binary64. Source feedback text and
optional OCAML_GC_STATS file output are suppressed; complete checked numerical
results replace rounded progress printing. No compiler/runtime prerequisite
is introduced.

### Fixed inputs and result checks

| Profile | Evaluation-budget parameter | View of the source workload |
|---|---:|---|
| Smoke | 40 | All 196 quotes; reduced optimizer budget. |
| Normal | 2000 | Original published budget and quote set. |
| Large | 20000 | Explicit optimizer scaling selection; same quotes. |

The parameter is the source optimizer budget, not a universal data size.
Profiles include reviewed reference files containing all five parameters,
RMS, and every calibrated/market price pair. All values must be finite.
Parameters use 1e-8 absolute plus 1e-8 relative error; RMS uses 1e-7 absolute
plus 1e-8 relative error; both price arrays use 1e-9 absolute plus 1e-8
relative error. The shared price bound is much narrower than the original
0.01/10000 printed-price resolution. CDF support observations use 1e-10
absolute plus relative tolerance; exact dates, counters and draw sequences
remain exact.

Original export-only observers supply full precision, and a separate model
recomputes RMS from all 196 price pairs. Independent calendar differences,
erf/square-root observations and original optimizer traces support smaller
components. Checker controls reject two-bound perturbations, NaN, infinity,
wrong model parameters and wrong RMS; small roundoff remains accepted.
Raw original stdout is preserved separately from the full-precision oracle.

### Compiler/runtime behavior and validation

Investigate closure specialization, shared scratch arrays, transcendental
operations, root-search branches, numeric boxing and population updates.
These are source-based questions rather than attributed timing explanations.
Compare identical SML sources on the standard host set; use OCaml as an
independent correctness reference.

The private Rune smoke and original normal-budget pilot validates complete
results. Final semantic probes distinguish the known native 32-bit SML/NJ
bounded-random Overflow from legacy 64-bit numerical/GC failures. Five
default legacy diagnostics fail and five 64 MiB nursery diagnostics pass;
this is consistent with the existing GC report, not a causal reduction or a
changed suite default. SML/NJ 2026.2 passes the uniform price bounds. Retain
all default failures and exclude incorrect results from measurements.
The initial tighter market-price-only bound and optional diagnostics remain
development evidence. Full final SML large runs remain unrecorded unless
listed explicitly in the validation ledger.

### Literature and evidence scope

[Storn and Price (1997)](https://link.springer.com/article/10.1023/A:1008202821328),
publisher abstract inspected, supplies global-optimization context.
[Brigo and Mercurio, second edition](https://link.springer.com/book/10.1007/978-3-540-34604-3),
publisher metadata inspected, records 2006; the source comment gives 2005.
No full article/book derivation review is claimed. Preserved source, independent
numerical observations and measured validation results remain distinct from
these literature anchors and from performance hypotheses.

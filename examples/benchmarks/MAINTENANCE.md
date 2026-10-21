# Benchmark suite maintenance

A source-inventory disposition records a curation decision. An implemented
manifest row records a runnable port. Recorded validation identifies the
source/configuration epoch actually checked. Keep those claims separate.

## Adding or changing a workload

1. Review algorithm, data structures, numeric widths, evaluation/demand,
   sharing, stopping conditions, input distribution and individual notices.
   Pin the exact upstream revision and retain original source/input identities.
2. Map established names and aliases before choosing a directory. Give classic
   SML names priority, use family suffixes for collisions, and name materially
   different lazy/strict variants explicitly.
3. Implement kernels, input generation and result checks in SML97. Keep shell
   code to compilation, process/stream handling and operating-system measures.
   Preserve meaningful upstream parameters and document each adaptation.
4. Add ordered sources, fixed smoke/normal profiles and deliberately chosen
   large profiles to manifest.tsv. Keep expected results independently
   established and reviewed; numerical programs need specific validated
   tolerances, including planted perturbations.
5. Supply the linked three-column README row, benchmark section, provenance,
   source notices, dataset origins and references. Unsupported facilities
   receive a concrete disposition and reconsideration condition.
6. Run make bench-coverage, metadata rejection checks and affected semantic
   checks. Validate smoke/normal on Rune O0/O2 and applicable engines/hosts.
   Obtain hosts through make hosts; record unavailable configurations, failed
   compiles, wrong results, runtime failures and resource limits separately.
7. Run normal allocation comparisons under the established process-tree guard.
   Run serial timing adapters with fixed streams, names, directories and
   seeds. Single samples are diagnostics; comparative reports use ten fresh
   process samples by default and publish every sample, median and IQR.
8. Run the required repository acceptance checks. Commit the recorded source,
   input, configuration, failure and validation evidence with the change.

Every imported workload is covered by make bench-check-all. The bounded
make check smoke set stays practical; timing thresholds stay outside it.
Broader runs accept benchmark, profile and configuration filters. Repeated
execution retains global sharing; preserve first rounds and identify warmup
without asserting steady state.

## Refreshing upstreams

Use fresh clean checkouts outside the runnable directories. Read upstreams.tsv
for the current pins. Before changing a pin, inventory additions/removals,
compare complete algorithms and data, inspect new notices and libraries,
revisit duplicates/deferrals and preserve previous identities.

Supply all five clean pinned roots to the existing audit command, for example:

    bin/rune-generate inventory --source mlton=PATH --source smlnj=PATH --source mlkit=PATH --source nofib=PATH --source sandmark=PATH --check

The command rejects a wrong revision or modified/untracked upstream source.
Review intentional changes before updating locks and invoking --write.
Replay inventory regressions. Audit runtime_files data and auxiliary or
multiline entrypoints as well as default build manifests; standalone helpers
need explicit companion dispositions even when not timed by upstream.

Re-establish affected original-language reference fixtures, source/input
identities and SML result checks. Run affected smoke/normal and semantic
checks before accepting measurements. Preserve historical raw failures and
source epochs; do not overwrite an older report to make it appear current.
Run make bench-coverage and reconcile every scheduled import before closing
a refresh. Regenerate coverage.tsv with bin/runevm build/bench-coverage.rbc
--report and review its diff alongside the inventory. Refresh the per-program
evidence index and report using actual recorded source epochs and outcomes.
Additional collections require their own scoped import decision.

## Updating expected results and budgets

A changed expected result needs an independent original implementation,
fixture or reviewed checker, with the reason recorded. A result disagreement
is an investigation, not an automatic baseline update. Retain deliberately
wrong result/resource tests. Incorrect results supply no accepted timing.

Deterministic count budgets are distinct from wall-clock samples. Establish
correctness first, compare instruction counts only within compatible
execution models, and compare allocation across applicable Rune engines.
Review the reason for an intentional count change and retain old/new raw
samples, source/options and allowance. After review, an explicit update uses:

    bin/rune-measure benchmarks count --profile smoke --filter '=NAME' --update-budgets

The adapter refuses baseline publication after failed comparisons. Re-run the
ordinary count target against the proposed table before committing it.
Do not loosen counts or resource limits merely to hide a regression. Default
smoke/normal/large limits remain 30/600/3600 seconds and 1/4/8 GiB; any override
needs profile metadata and concrete evidence.

Noisy timing baselines and optional hardware-counter studies are explicit
experiments. Keep profiling, runtime statistics, compilation and timing
phases separate, with complete samples and machine/compiler/runtime metadata.
A compiler or host fix is tested with the original valid benchmark source.
Private causal probes stay separate from runnable ports and accepted timings.

## Compiler overrides

When selecting RUNE, RUNEVM or RUNEOPT from another worktree, keep the
selected tool repository, revision, dirty state, actual payload hashes and
compiler Basis identities with the run. The suite checkout remains a separate
subject. For installed/custom launchers outside Git, repository identity is
explicitly unavailable; retain executable hashes and the deployment manifest
needed to identify indirect payloads. Repository metadata describes the
measurement-time checkout; payload hashes identify the executed bytes.

## Evidence retention

Store bulk run evidence outside the Rune repository, in the sibling
[rune-benchmark-results archive](../../../rune-benchmark-results/README.md).
Relative archive links assume `{PREFIX}/rune` beside
`{PREFIX}/rune-benchmark-results`. Keep runnable sources, reviewed expected
results, required input data and correctness tests in Rune. Preserve concise
provenance and validation explanations with each benchmark; link to the
external archive for historical reports and complete observations.

Retain useful source/input identities, reference-generation code, notices,
compiler status/streams, samples and reports in the external archive. Preserve
each report's source/configuration epoch and distinguish incomplete attempts
from completed checks. Review repeated snapshots and verbose raw logs before
retaining them; the archive README describes what is safe to discard later.
Compiled caches, executables and heap images stay excluded; record their
identities when useful.
ASCII hexadecimal can preserve binary protocol observations without adding
binary payload exceptions. Preserve notices and raw fixture bytes.

Review every milestone's actual evidence before changing its status to
Complete. Keep unavailable optional platforms and historical failed groups
visible in the report; a missing or interrupted check is never a pass.

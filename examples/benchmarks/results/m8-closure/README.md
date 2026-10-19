# Coverage closure and maintenance, 2026-10-19

M8 closes the initial benchmark roadmap with 507 portable programs and 1473
fixed profiles. Every one of the 861 pinned primary entries has a disposition:
321 import, 36 duplicate, 155 defer and 349 exclude. All 321 suitable paths
map to implemented programs. The companion inventory accounts for 38
historical, helper and alternate variants, including Anna's separate Monster
utility.

## Coverage and metadata checks

The portable SML coverage checker validates source dispositions and identities,
complete import coverage, absence of runnable deferred/excluded sources,
companion metadata and the 507 linked overview rows, benchmark sections and
provenance documents. Its six assertions, including planted omissions,
duplicate sources and deferred-source leakage, pass on Rune, MLton, legacy
SML/NJ and Poly/ML. An earlier fresh-working-directory fixture failure is
retained separately from the corrected four-host run.

The inventory has 163 passing regression tests and replays at all five pinned
upstreams. The closure audit explicitly indexes 21 previously implicit
alternate nofib data/result files, covering all 43 tracked runtime_files
members. [Dataset review](runtime-files.tsv) records individual credits and
notice inspection. The complete historical Project Gutenberg notice remains
with the paragraph dataset.

[The evidence index](evidence-index.tsv) maps every program to recorded
validation. These are per-wave source epochs and actual host outcomes; this
index does not claim a fresh all-program sweep at one compiler revision.
Source identities, known source defects, numerical bounds, host failures and
large checks left unrecorded remain visible in each bundle.

## Measurement provenance

Compiler overrides now record the actual selected tool repository, revision,
dirty state, payloads and compiler Basis identities separately from the suite
checkout. A planted foreign compiler repository with changed Basis content and
an unknown custom launcher verifies these distinctions. The existing
measurement regression suite also passes.

The full repository check passes after 2236.0 seconds.
Its recorded subject includes the final Veritas kernels, manifest, coverage
checker and inventory. The subsequent metadata-only provenance helper and
coverage-regression fixture transport are checked separately. Final metadata,
routine smoke and documentation checks are recorded with their commands and
exit codes. No workload, compiler or runtime source changed after the full
acceptance subject.

## Evidence retention

The closure retains 50815 previously ignored readable files, totalling
158138605 bytes. This includes generated build descriptions, source/input
snapshots, streams and metadata below ignored build directories. The
[identity ledger](retained-text-identities.tsv) preserves their exact bytes
and original locations.

Twenty-one text observations whose names ended in .state have byte-identical
.observations copies, recorded in [the alias ledger](text-state-aliases.tsv).
Original local files are not deleted. The established executable/compiled
payload policy remains unchanged. The [excluded identity ledger](excluded-binary-identities.tsv)
records 812 binary payloads without importing them. Veritas binary protocol
fixtures use lossless ASCII hexadecimal.

The final staged-file audit checks every added/modified blob under the
existing payload rules in bounded batches and records whitespace and
physical/index coverage. This distinguishes retained evidence from compiled
products and incomplete attempts from passing groups.

## Delivered report and maintenance procedures

[The initial report](../../REPORT.md) publishes coverage, correctness and
measurement-method evidence without extrapolating pilot timings to the whole
suite. [Maintenance](../../MAINTENANCE.md) defines upstream refreshes, reviewed
expected results, count baselines and evidence retention.
[Ranked additional candidates](../../CANDIDATES.md) identify overlap and
conditions for future work across Gabriel, Larceny, Benchmarks Game and PBBS.
Parallel and runtime-specific candidates stay deferred under the agreed
feature policy.

The original timing reports retain ten fresh-process samples per pilot and
complete repeated rounds. Existing performance checks remain the baseline;
no noisy timing threshold enters make check.

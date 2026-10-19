# Initial Rune benchmark suite report

Recorded 2026-10-19. The rebased catalogue contains 510 runnable SML97 programs and 1482
fixed profiles, including three Rune-authored latency workloads from master.
The original pinned-collection imports account for 507 programs and 1473 profiles. This report concerns coverage, correctness and reproducible
measurement tooling. It does not rank compilers or claim steady-state
performance from the single-sample adapter diagnostics.

## Coverage

| Source | Runnable programs |
|---|---:|
| Classic MLton | 49 |
| Classic SML/NJ | 35 |
| Classic ML Kit | 51 |
| nofib | 248 |
| Sandmark | 124 |
| Rune latency workloads | 3 |
| Total | 510 |

Programs are not distinct algorithms: meaningful variants, evaluation
policies and shared provenance are recorded explicitly. The primary pinned
inventory contains 861 entries: 321 import, 36 duplicate, 155 defer and 349
exclude. All 321 suitable primary paths map to implemented profiles.
Rune-authored workloads name their local source file rather than an external
inventory entry. The companion inventory accounts for 38 historical/auxiliary variants,
including Anna's separately built Monster utility. Deferred entries retain
concrete facility/source blockers; they do not appear as runnable programs.

[The catalogue](README.md) supplies the linked overview and benchmark
sections. Each directory has ordered sources, a driver, reviewed checks,
provenance and fixed profiles. [Machine-readable coverage](coverage.tsv)
reconciles all primary entries; make bench-coverage checks omissions,
non-import leakage, companion metadata and documentation links.

The closure audit adds 21 previously implicit alternate runtime data/result
files, accounting for all 43 tracked nofib runtime_files members. Individual
credits, identities and notice review are recorded in the closure evidence.
Historical paragraph input retains its complete Project Gutenberg header and
notice; a collection-level notice is not substituted for dataset provenance.

## Recorded validation

[The rebase integration record](validation/rebase-2026-10-19.md) distinguishes
current-master validation from the original import epochs.
[Validation history](validation.md) and the per-wave result bundles record
exact source epochs, commands, inputs, hosts and outcomes. Each import has
smoke and normal coverage and an independent expected result or numerical
checker. The bounded routine set is part of make check; make bench-check-all
covers every imported benchmark.

The pilots pass all four standard SML implementations and the additional
supplied hosts. Later waves retain genuine host/source limitations and
resource failures. In particular, SML/NJ32's literal-loss defect is confirmed
by a private causal Anna probe; no host workaround replaces the valid
public benchmark. A group that stopped before its summary is incomplete.
Source-loading and compile timeouts retain their actual status and phase.

The latest completed Anna wave records all 32 Rune profile combinations
passing, 12 complete semantic groups of 1963 checks, normal allocation
agreement and full repository acceptance. [Veritas](results/m4-veritas/README.md)
closes M4 with all 32 Rune combinations passing, thirteen complete groups of
218 semantic checks, agreeing normal allocation counts and full acceptance.
The [M8 closure](results/m8-closure/README.md) records the final inventory,
metadata, documentation, routine and retained-evidence checks. Full large-host sweeps are explicit broader experiments, not
implied by smoke/normal evidence.

## Measurement protocol

The [M6 reports](results/m6/README.md) retain 80 accepted fresh-process
samples and 80 repeated rounds on two normal primes variants across Rune,
MLton, SML/NJ and Poly/ML. They demonstrate reproducible metadata, snapshots,
correctness prerequisites, complete samples and median/IQR reporting.
They do not establish rankings for the whole suite.

Identical SML sources across these implementations are the standard
comparison. Haskell/OCaml originals establish correctness references.
Fresh processes and repeated in-process execution have separate labels.
First rounds remain visible; repeated runs retain global sharing and do not
prove a steady state. Compiles, execution, allocation, GC/profiling and
optional hardware counters remain distinct phases.

Runs are serial for timing and use ten fresh samples by default. The
metadata records source/input identities, compiler versions/options,
revision/dirty state, machine/runtime settings and mode. Compiler overrides
record the selected tool repository and its Basis/payload hashes separately
from the suite checkout; unknown installed/custom repository identities stay
explicitly unavailable. Wrong results,
missing configurations, compile failures, runtime failures, timeouts and
memory limits do not contribute accepted timings. Deterministic instruction
comparisons respect execution models; allocation comparisons use applicable
Rune engines. Timing thresholds stay outside make check.

## Limits and maintenance

The initial report publishes recorded evidence, not a fresh all-program
all-host timing sweep at one revision. Consult each bundle's subject hashes
and failures. Optional standalone xc1 exports and hardware-counter adapters
remain explicitly unavailable. Individual source stubs, numerical bounds,
integer-width assumptions and large checks left unrecorded remain visible
in provenance.

[Maintenance procedures](MAINTENANCE.md) cover upstream refreshes, new ports,
independent result review, deliberate count updates and evidence retention.
[Ranked candidates](CANDIDATES.md) identify overlap and conditions for further
coverage; parallel and runtime-specific candidates remain outside this
initial feature scope.

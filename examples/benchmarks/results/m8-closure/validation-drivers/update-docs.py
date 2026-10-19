from pathlib import Path
root=Path.cwd();suite=root/'examples/benchmarks'
p=root/'docs/plans/benchmarks.md';s=p.read_text()
start=s.index('Status:');end=s.index('\n\n## Goal',start)
s=s[:start]+"""Status: **complete**, 2026-10-19. M0-M8 have
[recorded validation](../../examples/benchmarks/validation.md).
The initial suite has 507 programs and 1473 profiles. All suitable pinned
inventory entries are implemented; deferred and excluded entries retain
concrete reasons. Host failures and unrecorded broader experiments remain
explicit in the [initial report](../../examples/benchmarks/REPORT.md)."""+s[end:]
s=s.replace('Sandmark collection. M3 kernels and M4 applications are complete; M8\ncoverage closure is in progress.',
 'Sandmark collection. M3 kernels, M4 applications and M8 coverage closure\nare complete with recorded evidence.')
s=s.replace('M8 closes the inventories, evidence, documentation and maintenance procedures.',
 'M8 closes the inventories, evidence, documentation and maintenance procedures.\nThe [closure evidence](../../examples/benchmarks/results/m8-closure/README.md)\nreconciles all 861 primary entries and 38 companions, indexes validation for\nevery program and records the final acceptance checks. The\n[maintenance procedures](../../examples/benchmarks/MAINTENANCE.md) and\n[ranked candidates](../../examples/benchmarks/CANDIDATES.md) define subsequent work.')
s=s.replace('| **M8 — Coverage closure and maintenance** | In progress |','| **M8 — Coverage closure and maintenance** | Complete |')
s=s.replace('M8 remains in progress. M3 closure is recorded in the','M8 completion is recorded in the [coverage closure evidence](../../examples/benchmarks/results/m8-closure/README.md).\nM3 closure is recorded in the')
s=s.replace("records this tooling change; M8's remaining audit and maintenance work stays open.",
 'records this tooling change; the final M8 audit and maintenance work is recorded\nin the [coverage closure evidence](../../examples/benchmarks/results/m8-closure/README.md).')
p.write_text(s)
p=suite/'README.md';s=p.read_text()
s=s.replace('Portable SML97 benchmark programs, being implemented from the',
 'Portable SML97 benchmark programs, implemented from the')
s=s.replace('ports, with fixed profiles and result checks. Recorded coverage is in',
 'ports, with fixed profiles and result checks. The initial roadmap is complete\nwith 507 programs and 1473 profiles. Recorded coverage is in')
s=s.replace('The larger source\n[inventory](inventory.tsv) schedules future imports; it is not a list of\npassing programs.',
 'The source\n[inventory](inventory.tsv) records every pinned disposition; it is not a list of\npassing programs.')
s=s.replace('M8 coverage closure is in progress.',
 'M8 coverage closure is [complete](results/m8-closure/README.md). See the\n[initial report](REPORT.md), [maintenance procedures](MAINTENANCE.md) and\n[additional candidate review](CANDIDATES.md).')
p.write_text(s)
p=suite/'README.md';s=p.read_text().replace('The roadmap remains\nin progress while these imported programs and tools are available for use.',
 'The initial roadmap is complete; recorded host exceptions remain explicit in\nthe report and per-wave evidence.')
p.write_text(s)
p=suite/'audit.md';s=p.read_text()
assert '## Initial roadmap coverage closure'not in s
s=s.replace('# Initial source audit\n', '# Source audit and review history\n\nCurrent closure: all 321 suitable paths are implemented in 507 programs and\n1473 profiles. The [M8 evidence](results/m8-closure/README.md) and\n[initial report](REPORT.md) record the final reconciliation. The reviews below\nretain their historical counts and status at each recorded source epoch.\n')
s+='''
## Initial roadmap coverage closure, 2026-10-19

All 861 primary entries have a disposition and reason. All 321 import paths
map to implemented profiles; 38 companions include alternate engines,
historical references and Anna's separately built Monster utility. The
closure indexes every tracked nofib runtime_files member and preserves
individual dataset credits/notices. All 163 inventory regressions and clean
five-upstream replay pass.

All 507 programs have linked overview rows, documentation sections,
provenance and recorded evidence. The portable SML coverage checker rejects
missing imports and runnable deferred/excluded entries. M4 completion is
recorded with Veritas; the final M8 evidence retains full repository
acceptance, metadata regressions, text snapshots and explicit host failures.

The [maintenance procedures](MAINTENANCE.md) define refresh and baseline
updates. [Additional candidates](CANDIDATES.md) record overlap and feature
conditions; they do not silently enlarge the initial import commitment.
'''
p.write_text(s)
p=suite/'REPORT.md';s=p.read_text()
s=s.replace('agreement and full repository acceptance. Veritas closes the remaining M4\napplication import after its final public gates are recorded in the closure\nevidence.',
 'agreement and full repository acceptance. [Veritas](results/m4-veritas/README.md)\ncloses M4 with all 32 Rune combinations passing, thirteen complete groups of\n218 semantic checks, agreeing normal allocation counts and full acceptance.\nThe [M8 closure](results/m8-closure/README.md) records the final inventory,\nmetadata, documentation, routine and retained-evidence checks.')
p.write_text(s)
p=suite/'validation.md';s=p.read_text()
assert '## M8 closure: coverage'not in s
s+="""
## M8 closure: coverage, report and maintenance, 2026-10-19

[The closure evidence](results/m8-closure/README.md) accounts for all 861
primary entries and 38 companion variants. All 321 suitable source paths
map to the 507 runnable programs and 1473 profiles. No suitable import
remains merely scheduled. The independent evidence index links each program
to its recorded per-wave checks and preserves actual host/source epochs.

The SML coverage checker and six meaningful assertions pass on four standard
SML implementations. All 163 inventory regressions pass and the inventory
replays against five pinned upstreams. The closure indexes all 43 nofib
runtime_files members, reviews dataset credits/notices, and records Monster
as Anna's separate auxiliary tool.

Selected-tool provenance distinguishes a compiler override's actual
repository, dirty state, Basis and payloads from the suite checkout.
Foreign-repository and unknown-launcher probes and the existing measurement
regressions pass. Final routine smoke, metadata and documentation checks
follow the successful full repository acceptance subject.

The audit retains 50815 previously ignored text records (158138605 bytes),
with byte-exact identities, 21 text observation aliases and 812 excluded
binary identities. Every staged added/modified blob passes the unchanged
payload policy and matches its physical bytes. Raw evidence retains its
original whitespace.

[The initial report](REPORT.md), [maintenance procedures](MAINTENANCE.md) and
[ranked additional candidates](CANDIDATES.md) complete M8. All M0-M8 milestones
are complete. This publishes recorded coverage and method evidence, not an
all-program compiler ranking or an unrecorded large-host sweep. Future
parallel/runtime-specific workloads remain deferred under the agreed policy.
"""
p.write_text(s)

# Initial source audit

The [2026-10-16 circuit-input review](validation/inventory-oct16-circuit-input.md)
adds the SCS inverter fixture whose .in suffix is added by the program. All 46
inventory regressions pass, and the full clean pinned-source replay reproduces
all 861 entries without changing dispositions or source identities.

The [2026-10-16 profile-input review](validation/inventory-oct16-profile-inputs.md)
records 22 additional input references across nine nofib entries and normalizes
related-name ordering. All 861 entries reproduce from clean pinned trees and all 45
inventory regressions pass. Dispositions and source identities are unchanged.

The [2026-10-16 allocation/stack review](validation/sandmark-allocation-probes.md)
adds four source-specific deferrals for unavailable optimization barriers.
Current Sandmark dispositions are 61 import and 82 defer. The baseline table
below records the initial audit; subsequent reviews preserve every inventory
entry and record their changes explicitly.

Recorded 2026-10-01; classic review extended 2026-10-02, on the `benchmarks` worktree branching from
`origin/master` at `b30fba275d685600da4d64cf0d9f7288bed0663e`.

M0 is **complete** as a source-audit baseline. All five trees are pinned,
entrypoints and metadata were reviewed, and each discovered source entry has
a disposition with evidence. Known missing authorship, absent upstream sources
and external/generated data remain explicitly recorded facts; they are not
claims of working ports. Compatibility and result validation are required
again at each import. No program passes merely by appearing in the inventory.

## Coverage and discovery

| Source | Entries | Scheduled imports | Deferred | Excluded | Duplicates |
|---|---:|---:|---:|---:|---:|
| MLton | 48 | 48 | 0 | 0 | 0 |
| SML/NJ | 45 | 35 | 8 | 2 | 0 |
| ML Kit | 438 | 51 | 16 | 336 | 35 |
| nofib | 187 | 128 | 48 | 11 | 0 |
| Sandmark | 143 | 66 | 77 | 0 | 0 |
| Total | 861 | 328 | 149 | 349 | 35 |

The initial M2 review classified 21 ML Kit region-control variants as deferred.
A closer audit found that five upstream host variants already define their
region-control functions as no-ops. Those are portable, distinct storage
variants and remain scheduled for import. Sixteen programs call actual
unavailable controls and remain deferred; removing those calls would change
the measured storage model.

Eighteen additional ML Kit entrypoint aliases share the complete original
kernel and hardcoded parameters with their canonical files. Byte-preserving
comparisons remove only the reviewed final invocation/export adapters (and
one driver comment), retaining strings and all algorithm/input bytes. Changed
kernels or strings prevent this duplicate classification. Existing vector
variants with different element representations and regeneration behavior
remain separate. The inventory records both source paths, identities and
notices. Five earlier project/entrypoint aliases and six support/regression
exclusions remain accounted for; the ten-repetition mergesort is distinct.
The scanner ignores prose/strings for facility detection, while duplicate
checks deliberately retain string contents.

nofib's individually inventoried Main files now include their transitive
local Haskell/literate modules and local/shared NofibUtils. The compression
and inference entrypoints previously recorded only Main.hs and therefore
omitted their algorithms and dependencies from the member digest; that
metadata gap is corrected. Individual notices beside file entrypoints are
also discovered. Explicit EXCLUDED_SRCS test programs retain exclusions with
their upstream build evidence. These refinements change source identities,
not the pinned revisions or the runnable programs.

These are source entries, not 861 distinct benchmark algorithms. ML Kit's
count includes regression and support files so exclusions are explicit.
Bytecode and native executions of one Sandmark executable share an entry;
different executable implementations remain separate.

Discovery rules are implemented in `scripts/benchmark-inventory.py`:

* **MLton:** every SML program in `benchmark/tests`.
* **SML/NJ:** every `programs` directory, plus programs advertised by the
  README even when source files are absent. `BASIS` and `common` are support
  libraries. In particular, the advertised `regex` entry has no checked-out
  program directory and remains deferred.
* **ML Kit:** every root SML/project file in `test` and `test_dev`. The
  benchmark section of `test/all.tst`, the development Makefile, and known
  benchmark families distinguish candidates from conformance tests. A second
  pass over ambiguous exclusions found the TIL-derived `weeks4` benchmark
  and the repeated reference-array workload `test_dev/many_refs.sml`; both
  are scheduled. `natset` remains a correctness suite, not a timed workload.
* **nofib:** nested Makefile directories in every workload category. Direct
  executable entrypoints are detected in both ordinary and literate Haskell;
  filenames need not be `Main`. Multiple entrypoints receive separate
  records. `real/eff` and `spectral/hartel` are aggregate directories, and
  `spectral/fft2/old` is an inactive source fragment.
* **Sandmark:** executable declarations from Dune files and included Dune
  fragments, plus all five root runplan JSON files. This includes effect
  workloads omitted from ordinary serial runplans and external application
  executables supplied by packages. Runplan names take precedence over
  generic names such as `main` or `kernel1_run`.

The scanner strips language-appropriate nested comments and strings before
looking for runtime dependencies. Haskell multiplication sections `(*)` are
not ML comments. Literate prose is separated from code; neither commented
OCaml GC suggestions nor words in documentation cause a feature deferral.

## Reading the inventory

An entry is keyed by `(source, path)`. Revisions are inherited from
`upstreams.tsv`; each record carries source members, a SHA-256 digest,
fixture/data references, attribution statements found in source headers,
notice paths, discovery evidence, a diagnostic family, a proposed name and
milestone, and a disposition with its reason.

The digest hashes sorted member paths and their exact contents, separated
by NUL bytes. It identifies the recorded source set, not a compiled binary.
`members` is an audit source set, not a promised compilation order. Ordered
sources and selected input invocations are established during imports.
Evidence and input paths are relative to the pinned upstream tree.
Generated or external datasets still need an explicit origin and recipe
when the program is imported.

`authors` records observed attribution statements rather than inferring an
author from a copyright holder. `not stated in scanned source headers`
means exactly that; context READMEs, Makefiles and source lists are included in the evidence.
Unknown attribution remains unknown rather than being inferred from a name.

`related` links naming variants and documented aliases, including
`nucleic`/`nucleic2` (Pseudoknot), `DLXSimulator`/`dlx`, and
`smith-normal-form`/`smith-nf`. Related entries are not automatically declared
identical. `test_dev/kitsimple.sml` is a confirmed byte-identical, hardcoded-workload
duplicate of `test/kitsimple.sml`. Other same-named variants remain distinct
unless their source, inputs and driving policy agree.

Classic names are reserved in the order MLton, SML/NJ, ML Kit. Distinct
classic variants receive a source qualifier; nofib and Sandmark receive
their requested suffixes on collisions. The map is the initial schedule; imports must retain
any newly discovered material variant differences. The nofib
primes entry will expand into explicitly named lazy and strict ports.

## Findings requiring care during imports

* Native SML/NJ 2026.2 probes confirm concrete blockers for the six
  advertised broken entries: Barnes-Hut's launcher signature mismatch,
  DeltaBlue's runtime cycle failure on a chain, DLX launcher syntax errors,
  kCFA's missing common/lib-base.sml, PIA's data-only directory and the
  absent regex source directory. Reconsider after the documented repair
  and independent reference-validation condition is met. These original
  variants do not inherit results from the imported monolithic versions.
  Its `cml-sieve` and `pingpong` require Concurrent ML.
* Review of nofib Makefiles excludes eight auxiliary/alternate files from
  `compress`, `infer` and `fulsom`; their `Main` module declarations alone
  do not make them benchmark invocations. Active main files retain their
  application names.
* Dune executable groups keep their common helpers and exclude sibling
  main modules. This prevents one program from inheriting another program
  as a dependency or being mistaken for its duplicate.
* Sandmark `markbench` is deferred because its workload forces full major
  collections; a portable rewrite must not silently remove that operation.
* nofib has seven `real/eff` implementations and nested Hartel workloads.
  Its `gc/hash`, `gc/spellcheck`, `real/smallpt`, and several concurrent
  workloads have entrypoint filenames other than `Main`. Treating those
  filenames as support files would lose workloads.
* nofib's `imaginary/primes` uses zero-based indexing into the prime stream,
  a finite source interval, and 100 independently invoked computations.
  A lazy/strict pair needs to preserve the result convention, while recording
  its chosen input and repetition profiles.
* ML Kit's `kittmergesort` deliberately rebuilds the remainder of a merge
  to permit local regions. Replacing that operation with a common efficient
  merge changes the memory-management workload. The file attributes the
  underlying mergesort to Paulson's book.
* Sandmark's sequential controls inside `multicore-effects` are suitable
  candidates; the adjacent effect-handler versions remain deferred. The
  directory name alone does not settle either classification.
* Sandmark's `capi` links an OCaml/C library even though its main file has
  no `external` declaration. Executable dependency declarations matter.
* Sandmark BDD and Knuth-Bendix source headers name the Q Public License
  1.0. Its top-level `LICENSE.md` is the Unlicense. Per-file notices must be
  preserved and reconciled during ports; the top-level notice does not
  replace them. ML Kit's project notice likewise describes GPL-covered
  files outside its listed exceptions.
* BDD's upstream checker uses a generator whose low bit alternates, and
  therefore checks only a narrow set of assignments. The future SML port
  needs an independent small truth-table check as well as agreement with
  the original workload. Preserve and document upstream cache choices
  rather than silently substituting a different algorithm.

The heap-layout worktree's MLton runner and shims, recorded on commit
`3a3c504`, are useful adaptation references. They are not part of this
`origin/master` baseline. Its allocation table verifies counts, not general
program results, so it cannot supply the sole oracle for imports.

## Validation recorded

* `make JOBS=4 all`: passed on the isolated worktree.
* `make JOBS=4 check`: passed on the isolated worktree, including all seven
  compiler builds' bytecode agreement. The source worktree's heap-layout
  modifications were not part of this run.
* `python3 tests/benchmarks/test-inventory.py`: 19 tests passed, covering
  alternative and multiple Haskell entrypoints, nested aggregates, literate
  code, language-specific comments, effect syntax, foreign dependencies,
  runplan aliases, source identities, name collisions, and invalid metadata.
* `python3 scripts/benchmark-inventory.py --check`: validates schema,
  pinned entry counts, identities, dispositions and name collisions.
* The same command with all five `--source` arguments reproduces discovery
  and classification against the pinned trees; no upstream scripts run.

The review corrections above, contextual provenance and explicit dispositions
close M0. The five M1 ports have separate, complete per-import provenance and
input/result records in the suite README. The remaining entries are scheduled
work, deferred facilities or documented exclusions, not completed benchmark
imports. New compatibility blockers found while porting must update the
inventory rather than being hidden by a passing similarly named variant.

## Classic source reconciliation

The M2 review maps every suitable classic entry to the runnable manifest.
Reviewed duplicate kernels include ML Kit FXP (entire normalized program),
Zern (repeat launcher only), TSP (size/repetition launcher only), checksum,
Boyer, weeks4/Tyan and the old PLClub renderer (legacy checked/unchecked
access and Byte conversion). All original source paths and parameters are
retained in the canonical provenance, with meaningful representations kept
as separate programs. The Petri-net _smlnj source differs in legacy Basis/time
adapters; deterministic elapsed-clock data is shared, not a new runtime facility.
PermuteList and pseudokit are declaration-only support/module regressions;
development life/rev/listsort are small correctness regressions rather than
benchmark computations. Their individual source reasons remain in the inventory.
SML functor `.fun` members are now included in member identities/notices;
this covers ML-Lex red-black.fun and VLIW sort.fun.

The branch was rebased onto origin/master
`f8e351ab704ee78f40d52e7ef05956578f49ac90` before the final M2 validation.
The pre-rebase branch is retained locally as `benchmarks-baseline-b30`, so
historical M6 compiler revisions remain reachable. Rebase is not new evidence
for old measurements; new correctness runs identify their actual sources/builds.

Native reference builds create source-looking cache filenames. Discovery
now excludes `.cm`, `MLB`, `_build`, `.git`, `dist-newstyle` and Python cache
directories from workload members, fixtures/notices and recursive discovery.
Tests verify that native caches cannot change the pinned source inventory.

## Opaque-call review, 2026-10-16

The [morestacks review](validation/sandmark-opaque-call.md) identifies an unavailable
optimization barrier for this call-overhead microbenchmark. Its source-guarded
entry moves from import to defer under the existing feature policy, with an
explicit reconsideration condition. All 143 pinned Sandmark entries were rebuilt
and all 861 inventory entries reconcile; alias relationships and ordering are unchanged.
All 38 discovery/classification tests pass. Other uses of opaque wrappers remain
subject to individual algorithm/observation review.

## CPP dependency review, 2026-10-16

The [quoted-include review](validation/hartel-cpp-inventory.md) adds transitive
source headers to member identities and removes include directives from runtime
input discovery. All five clean pinned trees reproduce all 861 entries; 19
records change only members, digests or inputs. The exact Hartel compatibility
shim receives a source-identity-guarded scalar-operation review. Workload names,
dispositions and scope are unchanged. All 56 inventory regressions pass.

## Circuit simulator authorship review, 2026-10-16

The gc/circsim and spectral/circsim literate headings explicitly name David J.
King and John O'Donnell, January 1998. Discovery now recognizes that exact
heading and records its source evidence. Two inventory rows change authors and
evidence only; source identities, names and dispositions remain unchanged.
All 58 inventory regressions pass and all five clean pinned trees reproduce
861 entries. The shared simulator's different consumers retain separate ports.

## Atom attribution review, 2026-10-16

The atom header attributes its kernel to Ron Legere on the line after
written by. Discovery now recognizes that exact multiline attribution.
One inventory row gains authors/evidence; source identity, name and disposition
are unchanged. All 60 regressions pass and all five clean pins reproduce 861
entries. The source's historical Hugs/GHC anecdote is recorded as history.

## Exact real arithmetic attribution review, 2026-10-17

The exact-reals source explicitly cites David Lester's 2012 paper. Discovery now
recognizes that exact title/citation and records its author and source evidence.
One inventory row changes authors/evidence only; identities, names, dispositions
and inputs are unchanged. All 62 inventory regressions pass, and all five clean
pinned trees reproduce 861 entries. Paper metadata and numerical reference scopes
are retained with the import.

## Primetest author and stdlib selector review, 2026-10-17

Primetest's exact author macro names David Lester. Its RCS Author field instead
identifies the last committer; the reviewed heading now takes precedence over
that tag. One inventory row changes authors/evidence only.

The stdlib review identifies 71 cases across ten executables, including the
already imported Stack cases and two byte operations defined but omitted from
dispatch. [The selector inventory](stdlib-cases.tsv) records source hashes,
evidence lines, reachability, implementation state and dispositions. Result-only
opaque_identity wrappers do not justify blanket deferral of portable operations.
Immediate integer equality is portable; three immutable-value physical-identity
cases have explicit missing-facility conditions.

Both pinned Bigarray modes specifically test typed C-layout storage. Managed
SML arrays would change that storage policy, so the executable and its two cases
are deferred until equivalent storage is available. No prerequisite runtime
feature is introduced. The classification is guarded by the reviewed source
hash; changed source and a portable same-named program require fresh review.

All 68 discovery/classification regressions pass. All five clean pinned trees
reproduce 861 inventory entries; only the two reviewed rows change. The additional
selector table accounts for nested cases without presenting deferred cases as
runnable programs.

## PIC authorship and historical variants, 2026-10-17

The exact Patricia Fasel/Los Alamos heading appears in nine source modules.
Discovery records the declared author and each heading's evidence. Only that
inventory row's authors/evidence change; all 70 regressions pass and all five
clean pinned trees reproduce 861 primary entries.

[Historical variants](source-variants.tsv) separately account for the retained
Culler/Lubeck Id implementations and their call graphs. Three non-built dataflow
implementations have explicit missing execution/setup facilities and conditions
for reconsideration; the two call graphs are excluded as documentation.
They are not runnable benchmarks or declared duplicates of the Haskell program.
The Haskell copying notice is retained on the derivative kernel and independent
model; no notice is inferred for a different historical component.

## Sequential Graph500 naming and variants

| Original executable | Run-plan aliases | Rune name | Disposition |
|---|---|---|---|
| graph500seq/gen.exe | graph500_gen | graph500-gen | Import efficient integer-row generation and original binary output. |
| graph500seq/kernel1_run.exe | graph500_kernel1, graph500_seq_kernel1 | graph500-kernel1 | Import list-array adjacency construction over original deterministic Marshal fixtures. |
| graph500seq/kronecker.exe | kronecker | kronecker | Import the distinct floating-array append/permutation prototype. |

The shared GraphTypes interface in graph500par contains only numeric type
aliases. Sequential ports require no parallel runtime. Their profile choices,
larger configured parameter candidates, source notices, numeric differences
and every driver/data adaptation are recorded in their provenance sections.

## Knights representations and authorship, 2026-10-17

The exact README heading declares Jonathan Hill as author. Discovery records
that heading with two positive/changed-heading regressions: all 96 inventory
tests pass, and five clean pinned trees reproduce 861 primary entries.

The [supplementary variants](source-variants.tsv) separately record the inactive
ChessSetArray representation, bringing that map to 27 entries. Its immutable
arrays, layout, metadata and source indexTile quirk differ from ChessSetList.
The original array spaces 64 1 recurses forever after reaching zero and produces
a bounded stack-overflow diagnostic. Imported array variants apply the reviewed
single formatter base-case repair logTen 0, select the array module in the
original observer, and match its complete tours. The original module remains
unchanged in provenance. This is an import with an explicit repair, not a duplicate
or an unsupported-runtime deferral.

## Expert, multiplier and regex adaptation credits, 2026-10-17

Six guarded regressions record Ian Holyer's March 1993 expert adaptation heading,
John T. O'Donnell's multiplier authorship/copyright heading and Roman Kashitsyn's
Bytes adaptation in regexredux2. Changed headings do not inherit these credits.
All 102 inventory tests and five clean pinned trees reproduce 861 primary entries.

The supplementary map now has 28 entries. The multiplier source's inactive
runMult consumer is imported separately from traceMult: it sums ready signals
and leaves the product stream undemanded. Original observations, an independent
clock model and explicit demand tests support that distinction. Generic unused
component utilities are retained as source support, not separate executables.

Regex profiles are generated by the pinned OCaml fasta3 source. Individual BSD
notices, generator/conversion credits, exact data identities and the portable
Str-fragment replacement are recorded. The published larger input remains a
separate scale reference; selected profiles explicitly state their smaller N.

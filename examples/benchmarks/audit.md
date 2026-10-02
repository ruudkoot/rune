# Initial source audit

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

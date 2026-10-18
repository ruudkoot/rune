# M0/M1 validation record

Recorded 2026-10-01 on the `benchmarks` worktree, based on `origin/master`
`b30fba275d685600da4d64cf0d9f7288bed0663e`. This is correctness evidence;
no wall-clock performance comparison is claimed.

| Check | Result |
|---|---|
| Source inventory | 861 entries accounted for; 389 scheduled imports, 133 deferrals, 338 exclusions, one confirmed duplicate. |
| Inventory discovery tests | 19 passed, including executable-group module selection. |
| SML runnable catalogue | 15 complete profiles with source/fixture checks; five metadata rejection checks passed. |
| Smoke profiles | All five pilots passed on Rune and six native SML hosts: 35 runs. |
| Normal profiles | The same 35 runs passed. |
| Large profiles | The same 35 runs passed, explicitly selected. |
| Rune `-O0 --lint` | All five smoke profiles passed. |
| Rune `-O2 --lint` | All five smoke profiles passed on register VM, tier-2 JIT and native code: 15 runs. |
| Independent semantics | 90 checks on each of seven configurations: 630 passes. Includes memoized forcing, trial-division primes at sizes 3-80, and all BDD truth assignments at sizes 1-10. |
| Negative execution | Wrong checksum, wrong name, misleading success output with a failing exit code, runtime timeout, Rune allocation limit, Poly/ML allocation limit and compile error were rejected. |
| Repository acceptance | `make JOBS=4 check` passed, including all seven compiler builds' existing bytecode agreement and normal Basis matrix behavior. |

The native hosts are MLton 20241230, SML/NJ 110.99.9 (64 and 32 bits),
SML/NJ 2026.2, Poly/ML 5.9.2 and ML Kit 4.7.23, supplied by `make hosts`.
GHC 9.4.7 and OCaml 4.14.1 supplied the original-language references.

Reproduction commands:

```sh
python3 scripts/benchmark-inventory.py --check
python3 tests/benchmarks/test-inventory.py
make JOBS=4 bench-check
make JOBS=4 bench-check BENCH_PROFILE=normal
make JOBS=4 bench-check BENCH_PROFILE=large
RUNE_BENCH_COMPILE_OPTIONS='--lint -O0' make JOBS=4 bench-check BENCH_CONFIGS=rune
RUNE_BENCH_COMPILE_OPTIONS='--lint -O2' make JOBS=4 bench-check BENCH_CONFIGS=rune:new,rune:jit,rune:opt
sh tests/benchmarks/check-pilots.sh
bin/rune --lint tests/basis/harness.sml examples/benchmarks/shared/catalog.sml \
  tests/benchmarks/catalog.sml tests/basis/finish.sml -o tests/out/benchmarks/validation/catalog.rbc
bin/runevm-stack tests/out/benchmarks/validation/catalog.rbc
make JOBS=4 check
```

Raw matrix results and source lists are kept under
`tests/out/benchmarks/PROFILE/NAME/matrix/CONFIG/program/`; failures and
independent semantic checks are under `tests/out/benchmarks/validation/`.
The expected-result files are committed inputs, never automatically updated
by the runner.

Tak expectations were independently evaluated with memoized recursion,
keeping the benchmark itself unmemoized. Sorting expectations use an
independent sort with the upstream generator, full length/sum and Word32
rolling hash. nofib's original GHC program printed the same prime in each
of 100 iterations for sizes 10, 100 and 400, matching independent trial
division; the smoke profile deliberately uses one iteration. The unmodified
OCaml BDD program, instrumented only to expose its final node ID, gave
382, 14289 and 47088 for sizes 8, 18 and 22. Original and ported BDD truth
tables were separately checked for sizes 1-10.

Resource quotas are enforced and recorded by the runner. Poly/ML uses its
allocator-compatible data/heap limits rather than treating its fixed
uncommitted virtual reservation as resident use. Correctness checks may run
on a loaded machine; these results supply no timing evidence.

Outstanding work is the scheduled corpus imports (M2-M5), timing and count
reports (M6), routine-check integration (M7) and coverage closure (M8).
Standalone `xc1` library setup and additional benchmark platforms are not
validated by this pilot record.

## M2 first collection wave (in progress)

The catalogue now contains 82 programs, including all 48 pinned MLton
workloads, fourteen ML Kit workload entries and thirteen SML/NJ entries, alongside
the nofib/Sandmark pilots. M2 remains in progress: the other suitable
SML/NJ and ML Kit entries are still scheduled, not declared complete.

[Attempt ledger](validation/m2-attempts.tsv) records configuration, profile,
actual arguments and expected result, observed status/result, compilation
identity where available, output digest and artifact directory. It includes
failed attempts and superseded profiles; it is not a blanket current-source
validation claim. Matrix PROGRAM PASS and driver correctness must both be
present before an attempt is recorded as passing. Native interactive source
identity remains a documentation limitation until M6 records full source
snapshots and configuration metadata for measurements.

The required `timeout 1800 make JOBS=4 check` passed with subprocess/socket
operations permitted. The initial sandboxed attempt failed socket checks and
stalled in rt.fork_image after a child socket error; that stalled process was
terminated and the failed attempt is retained. No compiler/runtime changes
were made to bypass it. Cross-host compiler, documentation-generator and
native-generator bytecode checks also passed.

Independent classic checks run on Rune and all six supplied hosts: checksum
nonzero/endian/modular cases, seven RFC 1321 MD5 vectors plus a split-block
update, nine finite-number/tolerance cases, six image-checker cases and six
assembly-checker cases. These include deliberately wrong results, wrong
signed zero, nonfinite values, malformed literals and pixels beyond bounds.

The first-wave source review classified 21 ML Kit region-control
variants as deferred; the later audit below corrects five upstream no-op
variants. That wave also recorded five additional duplicate entrypoint/project forms,
and six support/regression exclusions. Each reason is explicit in the
reproducible inventory; 21 discovery/classification tests pass.

Known comparison gaps remain explicit. Poly/ML 5.9.2 does not expose Int64
for peek/vector64-concat. ML Kit 4.7.23 crashes compiling Boyer,
Knuth-Bendix Tyan and FXP; these are compile failures, never measurements.
Renderer reference sets and numerical bounds are recorded with their
source-sensitive CSG-boundary evidence. FXP's original individual notice
is still an outstanding provenance lookup: the historical links are broken;
its aggregate project notice and observed authorship/source identity are
retained without claiming that the aggregate notice resolves every component.

The final 68-program wave checked 476 smoke configuration/program pairs:
470 passed, two were unavailable Int64 comparisons on Poly/ML, and four
were ML Kit compile failures (Boyer, Knuth-Bendix, Tyan, FXP). Every one of
those 68 programs passed its normal profile on Rune. The current catalogue
also has four later SML/NJ ports; their validation remains separately
recorded rather than being included in the completed 68-program run.

### Second classic wave

Minimax, iterative pi digits and maze generation were added after the first
checkpoint. Minimax smoke passed MLton, SML/NJ and Poly/ML at 1 GiB but Rune
reported out of memory; the documented 2-GiB smoke override passed Rune. Its
normal profile passed Rune at 4 GiB. A separate exhaustive board oracle
confirmed both complete-tree and transposition-table summaries. Maze smoke
and normal passed all four primary compilers, and a union-find oracle
confirmed the complete fixtures and connected, acyclic structure. Iterative
pi smoke and the selected 100-digit normal profile passed all four primary
compilers. Earlier 2000- and 500-digit normal attempts timed out after 600
seconds on Rune and passed the references; those attempts are retained. The
2000-digit original input remains an explicitly selected large profile, whose
Rune execution is not yet validated.
The full digit fixtures are independently calculated using Chudnovsky.

## M3/M5 initial search wave (in progress)

Added nofib queens in memoized lazy and eager strict forms, preserving
board-first enumeration and suffix sharing. Added Sandmark
`nqueens` (depth-first mutable sibling counter) and `rec_seq_ack`
(sequential Ackermann). The unchanged GHC 9.4.7 and OCaml 4.14.1 originals
confirmed the selected fixtures. Ackermann fixtures also follow the
independent closed form for m=3; all repetitions are consumed in SML.
Validation artifacts remain under `tests/out/benchmarks/upstream-wave`.
The nofib individual author/notice lookup remains explicit, rather than
assigning the Sandmark or GHC compiler license to the queens program.

M3 and M5 remain open; these ports do not represent collection closure.

Both queens variants, Sandmark nqueens and Ackermann passed smoke and normal
on Rune, MLton, SML/NJ and Poly/ML. Fourteen semantic checks on each primary
compiler validate lazy demand, sharing, memoized exceptions, recursive-force
rejection and queen counts for sizes 1 through 10. The test delay has an
explicit integer result type, avoiding an unresolved top-level type variable.

The current `timeout 1800 make JOBS=4 check` passed with required subprocess
and socket access. Cross-host compiler, documentation generator and native
generator checks passed. This acceptance run preceded M7 routine integration.

## M6 measurement and comparison record (complete)

The [initial reports](results/m6/README.md) preserve 80 accepted fresh-process
samples and 80 repeated rounds on two normal primes variants across Rune,
MLton, SML/NJ and Poly/ML. Separate compile phases, correctness prerequisites,
all samples, metadata, source/data snapshots, identities and raw outputs are
retained. The recorded dirty state and OS-clock resolution are explicit.

Eight O2 count configurations agree on instruction counts within execution
models and on allocation across Rune engines. Reviewed ten-percent smoke
bounds were created, then passed a separate budget-check run. Four O0 Tak
engines also agree; those counts are explicitly unbudgeted. Separate runtime
statistics runs passed. Ten statistical/counter checks on each primary
compiler test median/IQR, model boundaries, deliberate instruction/allocation
mismatches and budget failures. A wrong expected result fails before any
portable timing sample is emitted.

Standalone xc1 export support and optional hardware-counter adapters remain
unavailable; requests fail explicitly. The initial report demonstrates the
protocol without asserting compiler rankings, steady state or coverage closure.

## M7 routine verification (complete)

`timeout 1800 make JOBS=4 check` passed with required subprocess/socket
access. The new ten-program routine target also passed separately after
its integration; a cached `make JOBS=4 bench-smoke` took 8.30 seconds and
136420 KiB peak RSS on this machine. That is practical-cost evidence, not a
portable timing threshold. The recorded full acceptance invocation started
before routine-target integration, so its original top-level recipe did not
include that new step; the separate routine run supplies that evidence.

The routine manifest validates names, duplicates, reasons and smoke profiles.
`bench-check-all` explicitly covers smoke and normal for the full catalogue.
Known host failures remain failures in broad runs. No timing comparison or
timing threshold is added to `make check`.

Metadata corruption checks reject unknown/duplicate routine entries, missing
reasons, duplicate profiles and absent fixtures before any benchmark runs.
The routine set is pinned in `routine.tsv`; all imports remain covered by
the explicit smoke/normal catalogue target. New measurement statistics and
count logic remain portable SML97; adapters handle host exports and OS quotas.

The final routine run, including metadata corruption checks and a compiler
rebuild after Makefile changes, passed in 15.54 seconds with 945636 KiB peak
RSS. The earlier cached 8.30-second run excluded the new negative-metadata
step. Neither observation is enforced as a timing limit.

## Continued source audit

The ML Kit audit now distinguishes sixteen actual region-control blockers
from five portable upstream variants that already define those functions as
no-ops. Eighteen more exact entrypoint aliases are recorded as duplicates;
strings and complete kernel/input bytes are compared before sharing a
canonical implementation. Changed vector representations remain separate.

File-based nofib entrypoints now retain transitive local modules and their
individual notices in the inventory digest, including compression and type
inference dependencies. Twenty-eight inventory tests pass, including changed
string rejection, no-op versus missing runtime controls, transitive modules
and upstream-excluded test entrypoints. This audit adds no compiler features
and does not claim that the newly scheduled portable variants are imported.

## Further M2 copying variants

`klife_eq` and `kitlife35u_smlnj` passed smoke and normal on Rune, MLton,
SML/NJ and Poly/ML. They retain their distinct copying/equality/argument
policies. The latter retains upstream no-op region calls without requiring
new runtime facilities; its MLton-host entrypoint is an exact duplicate with
source and provenance retained in the same directory. Large 250-generation
profiles have independent fixtures but are not yet recorded as executed.

The final `timeout 1800 make JOBS=4 check` passed with M7 integrated: metadata
corruption rejection and all ten routine smoke programs ran in the acceptance
sequence. Compiler/runedoc/runeopt cross-host checks also passed. The source
audit refinements and additional Life imports were validated separately
after that invocation; this is not a claim that their Python checks ran in
the earlier acceptance recipe.

`kitqsort_no_basislib` additionally passed smoke and the original 25000-item
normal profile on all four primary compilers. Its copying/tuple transformations
and floating Park-Miller generator are retained; the old primitive-based
mini-Basis is replaced by equivalent SML97 operations. A separate integer
generator/Python-sort oracle confirms all three selected fixtures. Large is
still unexecuted. The inherited VM-instrumentation guard also passed the
measurement checks on all four compilers and rejects instrumented options
from headline timing before starting a measurement.

## M2 coverage and expanded validation, 2026-10-02

The catalogue contains 142 programs and 420 profiles, including 135 classic
SML programs. All 48 MLton, 35 suitable SML/NJ and 51 suitable ML Kit
inventory entries have implementations; one additional matrix-ramp diagnostic
retains the earlier adapted input separately. Thirty-five ML Kit duplicate
entries retain their original sources and individual explanations. Sixteen
region-control variants and eight SML/NJ entries retain concrete blockers;
see [the native broken-source probes](validation/broken-classic.tsv).

The four primary hosts were checked throughout the import waves. A complete
additional six-host smoke/normal attempt records missing Int64 facilities in
Poly/ML, ML Kit compiler failures, ML Kit numerical failures and an unresolved
Barnes-Hut normal result difference on SML/NJ 64 bits. These failures remain
rejected; they are not additional valid fixtures. SML/NJ 32-bit was rerun
outside the sandbox after SIGSYS exits. Its actual numeric failures are
separately documented in [the Word64 diagnostic](validation/word64-host.md).

Before the compiler correction, every catalogue smoke/normal profile passed
on stack, register interpreter, tier-2 JIT and native Rune at -O2. At -O0,
AOBench exposed a captured-record lowering bug and the pi stream normal
profile exceeded 600 seconds in the stack interpreter. The compiler bug was initially
fixed in historical commit `97de792`, with a minimal independent 3*n*n
regression and a full acceptance run: 326 language fixtures pass, and 493 programs produce identical
bytecode with all seven builds. That commit was dropped during the subsequent
rebase because master provides the broader correction in `f3cd52a`, including
function ownership and capture-use lint checks. AOBench subsequently passes smoke/normal on
all four engines at both -O0 and -O2 without changing its algorithm or fixtures.
The pi normal zero index is reduced from 30 to 10, digit position 121 checked
independently with Chudnovsky; all four engines pass at both levels. The
historical timeouts and incorrect results remain in the attempt ledger.

Full-state corruption is rejected for classic Simple, ML Kit list-reference
Simple and modern flat-array Simple. Image checks reject out-of-bound channels,
incorrect dimensions and malformed/truncated files. Smith diagonals agree with
independent Bareiss determinants, divisibility and gcd-one minor witnesses;
see [the evidence](validation/smith-determinants.tsv). An independent rewrite
interpreter validates 24 final Knuth-Bendix rules against seven open axioms and
700 deterministic ground instances, and rejects an omitted rule. VLIW outputs
agree byte for byte with the original modern upstream assembly fixtures.

`make JOBS=4 check` passed twice after rebasing to origin/master f8e351a;
the second includes the captured-record correction. Inventory regression
checks now total 32 and include source-looking native build-cache rejection.
The current per-attempt record is [m2-attempts.tsv](validation/m2-attempts.tsv).
Large inputs have reviewed source/native oracles but are not claimed to have
passed every engine/host. Full certification after the compiler correction
and the outstanding native numerical differences remain explicit checks.

## M3 recursive and exact-arithmetic wave, 2026-10-02

Seven nofib ports extend the catalogue to 149 programs and 441 profiles:
rfib, lazy/strict Takeuchi, lazy/strict unary Peano exponentiation, and two
lazy e-digit generators. The ports retain upstream sources, notices or explicit
notice gaps, fixed profiles, complete result checks, and translation decisions.
Original GHC programs agree with the reviewed fixtures. Independent Fibonacci,
machine-power and decimal-exp oracles also agree; the e2 finite-series port
preserves the upstream exhaustion behavior instead of padding a short stream.

All seven pass smoke and normal on the four Rune engines at -O0/-O2 and on
MLton, SML/NJ 64-bit and Poly/ML. The
[correctness ledger](results/m3-recursion/correctness-attempts.tsv) retains
310 passing attempts, including 112 covering all seven ports after the master
rebase and 44 additional Takeuchi reruns after sharing the strict kernel. Large profiles
are recorded but are not claimed to have run on every configuration.

The [measurement archive](results/m3-recursion/README.md) records ten serial
fresh samples per primary compiler for each Takeuchi variant, plus separate
Rune counts. Instruction totals agree within the stack/native and register/JIT
pairs; allocation agrees across all four engines. Strict uses 19968 bytes and
524 objects, while explicit lazy uses 12233024 bytes and 382186 objects on
18/12/6. OS timing resolution is 0.01 seconds, so these samples support no
precise speed ranking. The archive retains its original pre-rebase source,
revision, configuration and dirty-state metadata. M3 remains in progress.

## Master rebase and use as a validation suite, 2026-10-02

Rebased onto `origin/master` at `3d48b00`. The eight existing benchmark commits
retain their changes, confirmed by `git range-diff`; historical compiler commit
`97de792` is dropped in favor of master's broader `f3cd52a` fix. Compiler sources
and IR/language documentation now match master. Pre-rebase history is retained
in local `benchmarks-before-rebase-20261002` so historical compiler identities
in measurement archives remain available.

AOBench passes smoke and normal on all four Rune engines at both -O0 and -O2
with the replacement fix. All 112 new nofib Rune attempts also pass after the
rebase. The inventory's 32 regression tests and recorded-source audit pass.
[Reference-host notes](validation/reference-hosts.md) record the reproduced
SML/NJ GC defect and unresolved Barnes-Hut mismatch, without relaxing fixtures.
The [README](README.md) gives bounded and comprehensive Rune validation commands.
The branch can deliver the imported suite before the remaining roadmap imports
are complete; this does not claim closure of M2, M3, M4, M5 or M8.

The identical strict recurrence for classic tak, ML Kit tak and strict nofib
Takeuchi is now one implementation in `shared/tak.sml`; their drivers,
profiles and upstream provenance remain separate. All affected classic and
nofib drivers pass smoke/normal on four Rune engines at both optimization
levels and the three primary native hosts; the
[shared-kernel ledger](validation/shared-tak-attempts.tsv) records 110 passing
attempts, including reruns of the ML Kit wrapper after extraction. Pilot
failure checks and the measurement correctness guard also pass with the new
source order. [Rebased count samples](validation/shared-tak-counts.tsv) retain
the same strict/lazy allocation totals and instruction agreement across the
applicable engine pairs. The earlier measurement archive retains its earlier
source snapshots.

The full rebased `make JOBS=4 check` exits successfully. It includes 330
language fixtures on each compiler build, 139211 Basis checks on the stack,
native and register engines, JIT checks, 795 documented examples, 513
optimization checks, 24 IR checks, optimization-level agreement, bootstrap,
performance budgets, the bounded benchmark routine set, and documentation/ISA
validation. All seven builds produce identical bytecode for 497 programs;
runedoc and runeopt builds also agree. The
[acceptance transcript](validation/rebase-acceptance.log) records the complete
run. This is local acceptance evidence; GitHub CI for the rebased branch has
not run, and no push or merge is included in this checkpoint.

## M2 completed validation, 2026-10-03

All 135 imported classic programs passed smoke and normal on the stack VM,
register interpreter, JIT and native engine at -O0 and -O2. The
[certification ledger](validation/m2-certification.tsv) records all 2160
successful attempts, their input arguments, expected results, configuration,
stdout SHA256, compile identity where supplied, and artifact directory.
The four complete batches used the `d2ac5de` baseline with unchanged imported
classic sources and the suite's existing per-profile limits and matrix loaders.
They include the shared classic/ML Kit Takeuchi kernel.

Together with the pinned inventory, retained notices and adaptations, reviewed
normal fixtures and independent full-state/oracle checks, this closes M2's
import and validation criteria. Every suitable classic inventory entry has an
implementation; the remaining entries retain their documented source or runtime
blockers. The broader six-host attempts and identified native host failures
remain in their existing ledger and [reference-host notes](validation/reference-hosts.md).
Completion does not claim that defective or feature-incomplete host configurations
pass every program, nor that all large profiles have been executed.

The working branch subsequently rebases onto `4652d4a`, which adds IR/type
checks. Its full `make JOBS=4 check` run passes, including 331 language fixtures
per compiler build and bytecode agreement for 498 programs across all seven
builds. Documentation and native-code generator builds agree too. The dated
certification above describes the compiler configuration actually used for
those 2160 benchmark attempts; the subsequent acceptance run is retained in
[oct03-acceptance.log](validation/oct03-acceptance.log).

## M3 imaginary workloads, 2026-10-03

Thirteen further ports cover kahan, x2n1, integrate, bernouilli, both wheel
sieves, gen_regexps and paraffins, with separately named meaningful lazy/strict
variants. All 15 workloads in the pinned nofib `imaginary` collection now have
implementations. The suite contains 162 programs and 480 profiles; M3 remains
in progress for spectral, shootout and GC coverage, and M4/M5/M8 are not closed.

Each new port passes smoke/normal on all four Rune engines at both -O0 and -O2
on the latest `4652d4a` base. The [latest-base ledger](results/m3-imaginary/latest-base-attempts.tsv)
records those attempts. Original GHC programs and independent exact integer,
rational, prime, Cartesian-product and combinatorial references agree with
reviewed fixtures. Primary native hosts pass except legacy SML/NJ's lazy-regex
normal hash. [The full attempt ledger](results/m3-imaginary/correctness-attempts.tsv)
retains earlier port errors and rejected results, with unknown optimization
settings explicit where no surviving log identifies them.

Stream checks verify delayed heads, ignored tails, recursive sharing, memoized
exceptions and shared span projections. Numerical negatives reject altered
complete sums/corrections, complex components and final integration streams;
exact rational and 64-bit Show/hash semantics are checked too. Symbolic tests
show paraffin counts do not force unused tree values and range expansions retain
order, descending endpoints and padding. These targets are reproducible through
check-streams.sh, check-numeric-ports.sh and check-symbolic-ports.sh.

Separate [count reports](results/m3-imaginary/README.md) cover the numerical,
exact-arithmetic, wheel and symbolic variants. Allocations agree across all four
Rune engines; stack/native and register/JIT instruction counts agree within
their applicable pairs. Complete raw records, source/input snapshots, compiler
identities and tool sources are retained. Count-run times are instrumented
observations and are not headline comparisons or warmup claims.

The [lazy-regex diagnosis](validation/regex-host.md) observes three different
legacy hashes for one pure input, while all independent references and modern
SML/NJ agree. This establishes a wrong legacy execution but does not isolate
which GC/calling-convention defect causes it. No alternate fixture or workaround
is accepted. The original radical and paraffin arrays remain fully validated;
large selected fixtures are reviewed but not claimed to pass every SML engine.

The bounded routine set grows from 10 to 12 programs with kahan and the Mark II
wheel sieve. A final `make bench-smoke` validates all 480 metadata profiles and
passes the complete routine set. The preceding full acceptance run, already
recorded above, validated 474 profiles before the final paraffin registration;
its compiler/runtime checks remain successful. All final added kernels have
their explicit broader correctness checks recorded separately.

## M3 allocation, sequence and exact-arithmetic wave, 2026-10-03

Ten ports add the two mutable-store layouts, the Haskell GCBench variant,
extensible hashing, lazy/strict Hirschberg LCSS, lazy/strict shootout pi and
lazy/strict spectral extended GCD. The suite now contains 172 programs and
510 profiles. M3 remains in progress; remaining GC, shootout and spectral
workloads are still scheduled, and M4/M5/M8 are not closed.

Each final smoke/normal profile passes on all four Rune engines at -O0/-O2;
[the latest attempt record](results/m3-gc/latest-attempts.tsv) identifies those
160 successful cases and the [broader ledger](results/m3-gc/correctness-attempts.tsv)
retains earlier failures. Managed MLton, Poly/ML and both 64-bit SML/NJ versions
also validate selected profiles. Original GHC observers and independent tree,
store, bucket-placement, sequence, pi and integer-arithmetic references agree.

Mutable-store checks inspect every bucket/value. Tree checks reject incorrect
balance, individual labels and compensating bad labels while retaining both
live trees and the numerical array. Hash-table checks inspect every pair and
use independent mathematical placement, not the same potentially faulty host
hash operation. LCSS checks the full returned sequence; pi checks every digit,
partial-block space, index and newline. Extended GCD checks both Bézout identity
and common divisibility on every result. The reproducible full-state targets
are check-gc-ports.sh and check-extended-gcd.sh.

The initial 1000-digit pi normal profile exceeded 600 seconds on the unoptimized
stack VM. Its timeout and aborted remainder are retained without being accepted
as results. The selected 200-digit normal input agrees with original GHC and an
independent reviewed Chudnovsky prefix, and now passes both levels/engines.
The original larger parameters remain available in upstream provenance/large
profiles. Original GCBench's historical Java stretch phase is not added to the
Haskell variant. Added full-state observers and representation/demand changes
are recorded per benchmark rather than hidden in a uniform driver.

Separate [count archives](results/m3-gc/README.md) retain source/input snapshots,
configuration/revision/dirty-state metadata and raw observations. Allocation
agrees across all four engines; instruction comparisons agree within the
applicable stack/native and register/JIT pairs. Instrumented run times are not
headline comparisons or warmup conclusions. No universal large SML pass or
unresolved-host-failure workaround is claimed.

The full `make JOBS=4 check` run passes for the final wave, including all 510
metadata profiles, 331 language fixtures per compiler build, exact engine and
count comparisons, bootstrap, performance budgets, documentation/ISA checks,
and identical bytecode for 498 programs across all seven builds. runedoc and
runeopt builds also agree. The complete
[acceptance transcript](validation/oct03-gc-acceptance.log) records that run.

## M3 persistent structures and graph conversion, 2026-10-03

Five ports add lazy/strict treejoin, lazy/strict spellcheck, and CSE. The
catalogue contains 177 programs and 525 profiles. M3 remains in progress;
these imports do not close the remaining GC, spectral, or shootout coverage.

[Recorded attempts](results/m3-persistent/correctness-attempts.tsv) include
all 80 required final smoke/normal Rune cases, which pass on four engines at
both -O0 and -O2. Managed MLton, legacy and modern 64-bit SML/NJ, and Poly/ML
also pass both profiles. An initial CSE tuple-selector portability error is
retained as a rejected port attempt, rather than classified as a host bug.

Original GHC and independent joins, sets, and subtree-interning oracles agree
on the complete fixtures. Treejoin preserves the unbalanced persistent tree,
lookup boundaries, right-first accumulation, and delayed unused fields.
Spellcheck preserves containers 0.6.7's weight-balanced set and ascending-list
construction, checked against its exact smoke tree shape. Original Latin-1
data remain byte-identical. CSE preserves pure state functions, preorder
labels, association lists, and closure-based renaming. Each adaptation and
notice gap is documented in its benchmark provenance.

The treejoin and word-set semantic targets pass all ten configurations at both
optimization levels. Separate [count archives](results/m3-persistent/README.md)
retain source/input identities and all samples: allocations agree across all
four engines and applicable instruction comparisons agree. No headline timing
or universal large-profile pass is claimed.

The complete `make JOBS=4 check` passes, including 525 catalogue profiles,
331 language fixtures per compiler, and bytecode agreement for 498 programs
across all seven builds. Documentation and native-generator builds also agree.
The [acceptance transcript](validation/oct03-persistent-acceptance.log) and
32 passing inventory tests record the final validation.

## M3 exact series and sequential shootout wave, 2026-10-03

Five ports add GC/spectral power series, n-body, FASTA and reverse complement.
The catalogue contains 182 programs and 540 profiles. All four eligible
sequential shootout workloads are now covered, including the earlier pidigits
port. Other GC and spectral entries remain scheduled; M3 is still in progress.

Final smoke/normal profiles pass on four Rune engines at both -O0 and -O2 and
on managed MLton, both 64-bit SML/NJ versions, and Poly/ML. The
[attempt ledger and raw results](results/m3-power-shootout/README.md) preserve
244 attempts and rejected early ports. Original GHC observers and independent
analytic/Catalan identities validate every power coefficient; its GC integer
and spectral rational generating functions remain distinct. Thirteen semantics
checks cover finite boundaries, sharing, integration demand and division's
pattern demand order, on all ten configurations at both levels.

FASTA matches unchanged Haskell and independent C byte for byte, including
binary32 probability-table cutoffs. Reverse complement agrees with Haskell,
C and independent record reversal. A rejected tiny smoke candidate exposed
the upstream 82-byte reader's single-header-per-chunk assumption; selected
smoke input respects that documented limitation without changing the algorithm.
N-body checks both energies and all 35 final fields against GHC; an independent
pair-force integrator confirms the reviewed per-profile error bounds. Seventeen
shootout semantics checks reject perturbed, incomplete and nonfinite results
and test rounding and buffer boundaries, on all ten configurations at both levels.

Separate instrumented count archives retain complete samples, configurations,
tool/source/input identities and raw observations. Allocation counts agree across
all four engines; applicable instruction comparisons agree. This records no
headline timing claim or universal large SML execution.

The full `make JOBS=4 check` passes, including 540 catalogue profiles, 331
language fixtures per compiler, performance budgets and bootstrap, and bytecode
agreement for 498 programs across all seven builds. runedoc and runeopt builds
also agree. The [complete acceptance transcript](validation/oct03-power-shootout-acceptance.log)
records this run; all 32 inventory tests pass.

## M5 sequential recursive controls, 2026-10-03

Five Sandmark ports add even/odd, Fibonacci, Motzkin, Sudan and Takeuchi.
Together with the earlier Ackermann port, all six sequential recursive controls
are covered. Their effect-based siblings remain deferred. The catalogue has
187 programs and 555 profiles; M5 remains in progress for the other workloads.

[The recorded ledger](results/m5-recursive/correctness.tsv) has 144 successful
runs: 120 for the five ports and 24 for the classic Fibonacci kernel extracted
unchanged into shared/fib.sml. Smoke/normal pass on four Rune engines at both
levels and four primary managed native hosts. Complete stdout and compilation
logs are retained. Fibonacci and Takeuchi share kernels while preserving the
Sandmark source, established names and original input/repetition profiles.

Independent iterative Fibonacci, memoized Takeuchi, binomial/Catalan Motzkin
counts and a closed-form Sudan identity agree with the fixtures. Original
OCaml programs validate individual smoke/normal results and the recorded
Fibonacci/Motzkin/Takeuchi large results. Sudan's wide values use portable
IntInf within the original selected 63-bit range; its changed representation
is explicit. Each repetition contributes to the result. SML operand order,
added accumulation and optional original optimization barriers are documented.
No universal large SML execution is claimed.

Separate [count archives](results/m5-recursive/README.md) retain source/input
snapshots, metadata and all samples. All allocation and applicable instruction
comparisons agree. The pinned Sandmark rebuild preserves every source identity
and disposition while adding reviewed kernel relationships; all 32 inventory
tests pass. M2's stale introductory status is corrected in the roadmap.

The full `make JOBS=4 check` passes, including all 555 catalogue profiles,
331 language fixtures per compiler, performance budgets, bootstrap and bytecode
agreement for 498 programs across seven builds. runedoc and runeopt also agree.
The [acceptance transcript](validation/oct03-sandmark-recursive-acceptance.log)
records the complete run.

## M4 prefix-tree LZW application, 2026-10-03

Paul Sanders's compressor is the first nofib real application port, in
memoized and strict forms sharing one implementation. M4 is now in progress;
the other applications remain scheduled. The catalogue has 192 programs and
570 profiles.

[All 48 primary smoke/normal cases](results/m4-compress/correctness.tsv) pass:
four Rune engines at -O0/-O2 and four managed native hosts. Standalone ML Kit
smoke and normal programs also pass. Every compressed byte is checked before
hashing; all 31 cut fixtures per profile and all 200 normal/large hash samples
agree with original GHC and an independent executable dictionary/packing oracle.
The source's persistent prefix tree, foldr insertion order, fixed 12-bit codes,
4096-entry freeze and odd-code packing are preserved. Byte input, materialized
output, fixture validation and accumulated hashes are documented adaptations.

Seven semantic checks pass nine configurations at both levels, including full
byte range, EOF demand and dictionary freeze. ML Kit 4.7.23 crashes compiling
the combined two-functor test; its [failure and reproduction](validation/mlkit-compress.md)
are recorded separately from passing standalone benchmark runs. No workaround
or alternate expected result is introduced. Separate
[count archives](results/m4-compress/README.md) retain complete samples and
source/input/tool identities; all allocations and applicable instruction
comparisons agree. No headline timing or universal large SML pass is claimed.

The full `make JOBS=4 check` passes, including all 570 catalogue profiles,
331 language fixtures per compiler, performance budgets and bootstrap, and
bytecode agreement for 498 programs across seven builds. runedoc and runeopt
also agree. The [complete acceptance transcript](validation/oct03-compress-acceptance.log)
records this run, and all 32 inventory tests pass.

## M3/M4 shared spectral kernels and RSA, 2026-10-03

Six variants add spectral LCSS/treejoin and the RSA application, bringing the
catalogue to 198 programs and 588 profiles. M3 and M4 remain in progress.
The spectral ports share reviewed kernels while retaining 500 LCSS repetitions,
100 treejoin repetitions and the shuffled relation datasets. Their
[96 primary cases](results/m3-shared-spectral/correctness.tsv) pass on four Rune
engines at both levels and four primary native hosts. Complete sequences/joins
agree with GHC observers and independent references.

RSA's [attempt ledger](results/m4-rsa/correctness-attempts.tsv) retains a rejected
411-byte smoke timeout on the unoptimized stack VM. Its selected 64-byte prefix
keeps one full exponentiation at the original key widths. All 48 final primary
smoke/normal cases pass. Every ciphertext block and hash sum agrees with GHC
and independent modular pow. Portable input acquisition, exact wide arithmetic,
memoized versus eager encoding and added full-output validation are explicit.
Eight semantics checks pass nine configurations at both levels; the paired
ML Kit compiler failure is [recorded separately](validation/mlkit-compress.md).

The [RSA](results/m4-rsa/README.md) and
[spectral](results/m3-shared-spectral/README.md) count archives retain complete
samples and identities. All allocation and applicable instruction comparisons
agree. No headline timing or universal large SML execution is claimed.

The complete repository acceptance transcript passes all 588 catalogue profiles,
331 language fixtures per compiler, bootstrap/performance checks, and bytecode
agreement for 498 programs across seven builds. runedoc and runeopt also agree.
The [full transcript](validation/oct03-rsa-shared-spectral-acceptance.log) records
those checks; all 32 inventory tests pass.

## M5 lazy and CPS workloads, 2026-10-03

Lazy primes, lazy-list allocation and the CPS sequence pipeline bring the
catalogue to 190 programs and 564 profiles. All
[72 required smoke/normal cases](results/m5-lazy/correctness.tsv) pass on four
Rune engines at both levels and four primary managed native hosts. M5 remains
in progress for other suitable sequential workloads.

Primes preserve strict heads/memoized tails and the next-tail demand of take1.
Lazy-list heads independently reference the original zero; validation walks
the allocated spine while leaving unused heads unforced. CPS retains unfolder
records, map/filter layers and mutable callback folding, specializing used
types for SML97. Portable IntInf preserves selected 63-bit sums beyond 31 bits.
Representation, evaluation, traversal and original-observer changes are explicit.

Original OCaml agrees with independent trial division, list identities and
weighted-square sums. Eight lazy and seven CPS semantics checks pass all ten
configurations at both levels. A rejected early CPS test transcript is retained:
SML/NJ required an explicit type on its empty trace reference. This changes the
test only. Separate [count archives](results/m5-lazy/README.md) retain all samples
and source/input/tool identities; all allocations and applicable instruction
comparisons agree. No headline timing or universal large SML pass is claimed.

The full `make JOBS=4 check` passes, including 564 catalogue profiles,
331 language fixtures per compiler, bootstrap and performance budgets, and
bytecode agreement for 498 programs across all seven builds. runedoc and runeopt
builds also agree. The [acceptance transcript](validation/oct03-sandmark-lazy-acceptance.log)
records the complete run.

## M3 Life and M4 mailing-label application, 2026-10-04

Two Life variants and Paul Hudak's mailing-label application bring the catalogue
to 201 programs and 597 profiles. M3 and M4 remain in progress. All
[48 Life](results/m3-life/correctness.tsv) and
[24 maillist](results/m4-maillist/correctness.tsv) primary smoke/normal cases
pass on four Rune engines at both levels and four primary native hosts.
Complete displays/files agree with original GHC and independent references.
Life uses a nonempty smoke input and preserves adjacent-fixpoint stopping;
maillist preserves every append-file call and 100 normal repetitions.

Seven Life semantic checks pass nine configurations at both levels. The
paired ML Kit [compiler crash](validation/mlkit-life.md) is recorded separately.
Eight mailing-label boundary checks pass all ten configurations at both levels;
the initial sandboxed SML/NJ 32-bit SIGSYS and successful permitted rerun are
retained. Count comparisons agree for all allocations and applicable instruction
pairs. No headline timing or universal large SML execution is claimed.

The full `make JOBS=4 check` passes outside the syscall sandbox, including all
597 catalogue profiles, 331 language fixtures per compiler, performance budgets,
bootstrap and bytecode agreement for 498 programs across seven builds. runedoc
and runeopt also agree. The [complete acceptance transcript](validation/oct04-life-maillist-acceptance.log)
records the run. The [sandboxed attempt](validation/oct04-life-maillist-sandbox-attempt.log)
retains its socket failures and terminated blocked fork-image test; it is not
passing evidence. All 32 inventory tests pass.

## M3 SCC/awards and M5 Hamming, 2026-10-04

Five variants bring the catalogue to 206 programs and 612 profiles. All
[48 SCC](results/m3-scc/correctness.tsv),
[48 awards](results/m3-awards/correctness.tsv) and
[24 Hamming](results/m5-hamming/correctness.tsv) final primary smoke/normal cases
pass on four Rune engines at both levels and four primary native hosts.
These matrices use final canonical suite source paths and inputs.

SCC preserves lazy tuple projections and shared recursive results; its complete
partition agrees with independent mutual reachability and its order with GHC.
Awards retains stable/anti-stable quicksort, shared totals and score consumption;
all 100 source inputs agree with GHC, an independent oracle and the FAST template.
Hamming preserves signed 64-bit component overflow; its complete large window
also passes Rune and the fixed-width independent oracle. Broader large host
validation is not claimed. Semantic checks pass all ten configurations at both
levels: nine each for SCC and awards, eight for Hamming.

Complete instrumented counts agree across applicable Rune engines. A
[resolver race](results/m6-resolver-isolation/README.md) discovered by concurrent
count runs is fixed with private temporary paths and a regression that preserves
an inherited matrix worker. Initial failed attempts remain recorded separately.
No headline timing is inferred. The bounded routine smoke set adds maillist and
sequence_cps, covering file I/O applications and CPS callback translation in
14 programs. M3 and M5 remain in progress; M8 remains planned.

Full `make JOBS=4 check` passes with all 612 catalogue profiles and the expanded
14-program smoke set, 331 language fixtures per compiler, performance budgets,
bootstrap and bytecode agreement for 498 programs across seven builds.
runedoc and runeopt also agree. The [complete acceptance transcript](validation/oct04-hamming-scc-awards-acceptance.log)
records this run. All 32 inventory tests pass. The separate measurement regression
validates the final configuration-isolation change and its negative checks.

## M5 mutable Stack workloads, 2026-10-04

Two Stack modes bring the catalogue to 208 programs and 618 profiles. All
[48 primary cases](results/m5-stack/correctness.tsv) pass smoke/normal on four
Rune engines at both levels and four primary native hosts. Original normal
iteration counts, list/length invariants, library algorithm and exact source
notices are retained. Complete OCaml observers and independent arithmetic
agree. Representation and added per-iteration checks/accumulators are explicit.

Nine semantic checks pass nine configurations at both levels. The final test
crashes ML Kit with an internal type-substitution error; the
[report](validation/mlkit-stack.md) records this separately from scratch-path
successes and standalone benchmark checks. Count allocations and applicable
instruction pairs agree. No headline timing or universal large SML validation
is claimed. M5 remains in progress.

Full `make JOBS=4 check` passes with 618 catalogue profiles, the 14-program routine
set, 331 language fixtures per compiler, performance budgets, bootstrap and
bytecode agreement for 498 programs across seven builds. runedoc and runeopt
also agree. The [complete transcript](validation/oct04-stack-acceptance.log)
records the run; all 32 inventory tests pass.

Eight additional standalone smoke/normal cases pass on ML Kit and 32-bit
SML/NJ, bringing Stack correctness coverage to 56 successful cases. These
passing benchmarks are distinct from ML Kit's test-program compilation crash.

## M4 pure state encodings, 2026-10-04

Seven variants bring the catalogue to 215 programs and 639 profiles. All
[168 primary smoke/normal cases](results/m4-eff/correctness.tsv) pass on four
Rune engines at both levels and four primary native hosts. Fourteen semantic
checks pass all ten configurations at both levels. Original GHC observers
agree on selected results and S's deferred counter; strict variants additionally
validate counters already forced by their original increment/bind rules.

Handler callbacks, free constructors, class dictionaries, bind layers and
interpreter traversal remain distinct. Used ground types, explicit delays,
source State-library replacements and notices are documented. Normal uses
1,000,000 operations and large preserves the original 10,000,000; large SML
validation is not universally claimed. S's unit result permits limited output
discrimination, documented alongside demand tests and count evidence. All seven
count groups agree across applicable Rune engines; no headline timing is claimed.
Exact-name filters such as `BENCH_FILTER='=S'` select these short established names;
eight catalogue unit checks verify exact/substring selection and metadata failures.
M4 remains in progress.

Full `make JOBS=4 check` passes with all 639 catalogue profiles and the bounded
14-program routine set, 331 language fixtures per compiler, performance budgets,
bootstrap and bytecode agreement for 498 programs across seven builds. runedoc
and runeopt also agree. The [complete transcript](validation/oct04-eff-acceptance.log)
records the run; all 32 inventory tests pass.

All 28 additional smoke/normal cases on ML Kit and 32-bit SML/NJ pass,
bringing eff correctness coverage to 196 successful cases across all six
managed native hosts and four Rune engines.

## M3 shared GC/spectral CSP solvers, 2026-10-04

Two variants bring the catalogue to 217 programs and 645 profiles. Reviewed
identical GC/spectral programs share one implementation and retain all source,
fixture and runtime-setting provenance. The guarded inventory classification
has 35 passing discovery/classification tests.

[All 56 final cases](results/m3-constraints/correctness.tsv) pass smoke/normal
on four Rune engines at both levels and all six managed native hosts. The
[attempt ledger](results/m3-constraints/correctness-attempts.tsv) retains the
rejected generic driver projection and a 600-second -O0 stack timeout.
Explicit tuple typing and a recorded strict-normal 1,200-second override resolve
those cases; input size 6 and all 240 normal repetitions remain fixed. Full
ordered solution checks agree with GHC and independent permutations for every
method, including the source's backmarking zero-case behavior.

Nine semantic checks pass nine final-path configurations at both levels.
ML Kit's [test compilation crash](validation/mlkit-constraints.md) remains separate
from passing standalone benchmark runs. Final source count comparisons agree;
intermediate pre-typing driver samples are distinctly archived. No headline
timing or universal large validation is claimed. M3 remains in progress.

Full `make JOBS=4 check` passes with 645 catalogue profiles, the bounded routine
set, 331 language fixtures per compiler, performance budgets, bootstrap and
bytecode agreement for 498 programs across seven builds. runedoc and runeopt
also agree. The [complete transcript](validation/oct04-constraints-acceptance.log)
records that run. After the final timeout-only metadata update, catalogue
validation/negative checks and the recorded normal retries pass.

## M3 Fibonacci heaps, 2026-10-04

Two variants bring the catalogue to 219 programs and 651 profiles. [All 56
smoke/normal cases](results/m3-fibheaps/correctness.tsv) pass on four Rune engines
at both levels and all six managed native hosts. Nine semantic checks pass all
ten configurations at both levels. Original GHC observers and independent
histograms agree for selected inputs; separate demand observations distinguish
mutable from functional consolidation.

The [attempt ledger](results/m3-fibheaps/correctness-attempts.tsv) preserves the
strict original-size -O0 pilot's 4 GiB memory failure. Paired normal inputs use
30,000 elements; large retains the original 300,000. Both sorting algorithms,
forest orders and sharing remain explicit. Count comparisons agree. No headline
timing or universal large validation is claimed; the repeated spectral variant
remains scheduled. M3 remains in progress.

Full `make JOBS=4 check` passes with 651 catalogue profiles, the bounded routine
set, 331 language fixtures per compiler, performance budgets, bootstrap and
bytecode agreement for 498 programs across seven builds. runedoc and runeopt
also agree. The [complete transcript](validation/oct04-fibheaps-acceptance.log)
records the run; all 35 inventory tests pass.

## M3/M4/M5 imports and routine coverage, 2026-10-15

Ten imports bring the catalogue to 229 programs and 681 profiles. The repeated
spectral heap pair, ANSI pair and grep pair each pass 56 smoke/normal cases on
four Rune engines at both levels and all six managed native hosts. Sandmark's
four sequential array kernels pass 104 cases on Rune and five native hosts.
The [spectral heaps](results/m3-spectral-fibheaps/), [ANSI](results/m3-ansi/),
[grep](results/m4-grep/) and [array](results/m5-sequential-arrays/) archives
retain complete case ledgers, raw results, provenance and source/input/tool
identities. All ten count groups agree across applicable Rune engines.

ANSI preserves source stream composition and exact control-byte output. A GHC
demand observer and two new regression checks establish that EOF callbacks
remain deferred until selected. The final 14-check semantic suite passes all
ten configurations at both levels. An interrupted draft with eager callback
construction, resource failures and its failing new regression test is explicitly
intermediate. Final source retains normal400/large900 and the standard limits.

Grep retains ordered parser combinators, epsilon-compressed cyclic NFAs and
Unicode character hashing. Every matched line is checked against complete
fixtures. Forty-five semantic checks pass all ten configurations at both levels;
unchanged GHC, independent Unicode filtering and pinned fixtures agree. Strict
input acquisition and copied line buffers are documented adaptations.

The OCaml-compatible array generator retains exact modified lagged-Fibonacci
transitions, rejection sampling and reviewed fixed states. Twenty-one semantic
checks pass nine configurations at both levels. Managed 32-bit SML/NJ fails all
eight array cases with spurious Overflow in a representable integer expression;
[the independent checked probe](validation/smlnj32-random.md) records three failures,
passing variable-maximum controls and six passing comparison configurations.
Portable source and reviewed expected results remain unchanged. Those failures
cannot contribute measurements. Scratch-runner setup errors and an earlier
sandbox SIGSYS termination are separate in their attempt ledgers.

The routine set grows from 14 to 16 with seeded Floyd-Warshall and UTF-8/NFA grep.
Broader explicit targets retain every imported program. All 35 inventory tests
pass. No headline timing, steady state or universal large SML coverage is claimed.
M3, M4 and M5 remain in progress; M8 remains planned.

Final `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 after the ANSI demand
correction, grep imports and 16-program routine expansion. It validates all
681 catalogue profiles and negative metadata checks, 331 language fixtures
per compiler, existing performance budgets, bootstrap and bytecode agreement
for 498 programs across seven builds. runedoc and runeopt builds also agree;
GDB and LLDB checks run with remote debuginfo lookup disabled. The
[full final transcript](validation/oct15-benchmarks-681-acceptance.log) and
[environment record](validation/oct15-debugger-environment.md) distinguish this
run from the pre-final 675-profile baseline and interrupted debugger wait.

## M5 sequential LU, 2026-10-15

One import brings the catalogue to 230 programs and 684 profiles. [All 28
smoke/normal cases](results/m5-lu/correctness.tsv) pass on four Rune engines at
both levels and all six managed native hosts. Fourteen numerical/perturbation
checks pass all ten configurations at both levels; count comparisons agree.

Flat unpivoted elimination and separate L/U setup remain intact. A streaming
checker consumes all packed and expanded factors against finite binary64
reference fixtures, with explicit absolute/relative replay bounds. Independent
60-digit arithmetic and scaled residuals validate smoke/normal reference
accuracy separately. Normal 256 and original large 1,024 are documented; no universal
large SML validation or headline timing is claimed. M5 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 684 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and bytecode agreement for 498 programs across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct15-lu-684-acceptance.log)
records that acceptance run; all 35 inventory tests pass.

## M3 calendar pictures, 2026-10-15

Two imports bring the catalogue to 232 programs and 690 profiles. [All 56
smoke/normal cases](results/m3-calendar/correctness.tsv) pass on Rune's four
engines at both levels and all six managed native hosts. Twenty-one semantic
checks pass all ten configurations at both levels, and count comparisons agree.

The source's length-only observation is retained, including unforced glyph
payload and delayed grouping. Full rendered fixtures separately agree with GHC
and independent Gregorian formatting at 11 years. Normal 10,000/large 50,000 original
year-offset parameters remain intact. Length's limited discrimination, strict/
memoized representations and driver parsing changes are explicit. No external
dataset, universal large SML claim or headline timing is introduced. M3 remains
in progress.

The final `DEBUGINFOD_URLS= make JOBS=4 check` started on 15 October and completed
on 16 October with exit 0:690 catalogue profiles, 16 routine workloads, 331 language
fixtures per compiler, existing budgets, bootstrap and 498 matching bytecode
comparisons across seven compiler builds. runedoc and runeopt also agree.
[The full transcript](validation/oct16-calendar-690-acceptance.log) records the
run; all 35 inventory tests pass.

## M3 banner pictures, 2026-10-16

Two imports bring the catalogue to 234 programs and 696 profiles. [All 56
smoke/normal cases](results/m3-banner/correctness.tsv) pass on Rune's four engines
at both levels and all six managed native hosts. Twelve semantic checks pass all
ten configurations at both levels; count comparisons agree.

Original templates and boot counts preserve logical input/output identities.
SML stream generation inside measured execution replaces boot-file expansion;
that adaptation and per-line output checking are explicit. Both variants retain
the font/picture algorithm, while Need preserves cyclic fallback sharing and its
productive infinite prefix. Original GHC, independent rendering and exact glyph
fixtures agree. No external dataset, universal large SML claim or headline
measurement is introduced. M3 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 696 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-banner-696-acceptance.log)
records the run; all 35 inventory tests pass.

## M3 sorting and M5 barrier review, 2026-10-16

Two imports bring the catalogue to 236 programs and 702 profiles. [All 56
smoke/normal cases](results/m3-sorting/correctness.tsv) pass on Rune's four engines
at both levels and all six managed native hosts. Forty semantic checks pass all
ten configurations at both levels, and count comparisons agree. Eight algorithms,
seven reversals, guard/tie order and tree representations remain intact. Complete
sorted rows agree with GHC, independent sorting and pinned hash fixtures.

Normal600/large3000 source-file parameters and per-repetition file reads are
preserved. UTF-8 acquisition, output validation and explicit numeric-width
semantics are recorded. No universal large SML or headline timing claim is made.

The [opaque-call review](validation/sandmark-opaque-call.md) separately defers the
pinned morestacks microbenchmark for its unavailable optimization barrier.
A source digest guards that disposition and changed programs receive fresh
review. All 143 pinned Sandmark entries were rebuilt and all 861 inventory
entries reconcile; all other inventory entries and alias ordering are unchanged.
All 38 discovery tests pass. M3 and M5 remain in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 702 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-sorting-702-acceptance.log)
records that run. All 38 inventory tests pass and all 861 entries validate.

## M3 geometry and M5 numerical/grid workloads, 2026-10-16

Four imports bring the catalogue to 240 programs and 714 profiles. The
[fish pair](results/m3-fish/) passes 56 smoke/normal cases, [spectral norm](results/m5-spectralnorm/)
passes 28, and [dense-array Life](results/m5-array-life/) passes 26. The two Life
native32 attempts reproduce the independently isolated SML/NJ generator Overflow.
All remaining selected host/engine cases pass with unchanged source/expected data.
Ten geometry, seven numerical and ten Life semantic checks pass all ten
configurations at both levels. Allocation and applicable instruction counts agree.

Geometry preserves each integer division and source length observation; complete
coordinates/format independently agree at three scales. Spectral norm retains all
forty passes and per-call temporary vectors, with explicit scalar error bounds.
Dense Life retains exception-based borders and both buffers; complete current,
previous and initial-board references agree. Source-specific representation,
forcing, initialization and validation costs remain documented. No universal
large SML or headline timing claim is made. M3 and M5 remain in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 714 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-geometry-arrays-714-acceptance.log)
records the combined wave; all 38 inventory tests pass.

## M5 integer arithmetic variants, 2026-10-16

Ten imports bring the catalogue to 250 programs and 744 profiles. [All 280
canonical smoke/normal cases](results/m5-zarith/correctness.tsv) pass on Rune's
four engines at both levels and all six managed native hosts. Canonical
arguments match the current manifest. Forty normal count samples pass and
applicable instruction/allocation comparisons agree; these remain unbudgeted
instrumented results, separate from headline timing.

The ports retain four numeric modes, recursive kernels, right-first calls,
count+1 repetitions, integer-only Num dispatch and complete four-coefficient pi
composition. Thirty-seven bounded original OCaml references agree with independent
integer/Decimal algorithms. Complete pi digits/layout agree through 10,000.
Normal pi is calibrated to 128 digits; superseded 1,000/256-digit attempts remain
explicitly incomplete in the archive, with no timeout or successful timing claim.
Library source pins, individual notices, adaptations and validation costs are
recorded. No universal large SML execution is claimed. M5 remains in progress.

Twenty-one semantic checks run on all ten configurations at both requested
levels. Nine configurations pass all checks; native32 SML/NJ fails one Word64
boundary check at each level while passing all selected benchmark profiles.
The [separate runtime-input diagnostic](validation/zarith-word64.md) records
incorrect constant subtraction, distinguishes it from runtime conversion, and
keeps the remaining root-cause uncertainty explicit. No changed expected result
or benchmark workaround is used.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 744 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-zarith-744-acceptance.log)
records the run. All 38 inventory tests pass and all 861 entries validate.

## M3 column-pruned cryptarithm search, 2026-10-16

Two imports bring the catalogue to 252 programs and 750 profiles. [All 56
smoke/normal cases](results/m3-cryptarithm2/correctness.tsv) pass on Rune's four
engines at both levels and all six managed native hosts. Ten semantic checks
pass all ten configurations at both levels. Eight normal count samples pass
and applicable comparisons agree; these unbudgeted instrumented samples remain
separate from headline timings.

The shared state/list-search functor preserves digit allocation and environment
order, lookup, mapM selection, column pruning and carry propagation. Need uses
memoized value/state cells and first-answer demand; strict evaluation retains
finite alternatives. Original GHC, independent exhaustive assignment search,
full solution-state observers and every pinned stdout fixture agree. Normal
300/large 1,500 repetitions and source-dependent input construction remain intact.
Input preprocessing, suspension representation and output-checking adaptations
are documented with individual program/library notices and source identities.
No universal large SML execution or historical speed claim is introduced.
M3 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 750 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-cryptarithm2-750-acceptance.log)
records the run. All 38 inventory tests pass and all 861 entries validate.

## M3 exhaustive permutations and M5 source review, 2026-10-16

Two imports bring the catalogue to 254 programs and 756 profiles. [All 56
requested smoke/normal cases](results/m3-cryptarithm1/coverage.tsv) are accounted
for: 55 pass, and strict normal on legacy 64-bit SML/NJ 110.99.9 reaches its
1,200-second cap without a result. That full-size host check remains incomplete.
Native32 and SML/NJ 2026.2 complete it; every Rune engine passes both profiles at
both levels. Eight semantic checks pass all ten configurations at both levels.
A separate Rune/MLton counter verifies all 3,628,800 candidates. Eight complete
normal count samples pass the combined comparison, with matching source identities
and unchanged budgets. These instrumented samples are not headline timings.

Original GHC, independent exhaustive assignment search and all pinned fixtures
agree. Insertion order, full enumeration and source repetition settings remain
intact. Memoization/cursor representation, output checking and the recorded
resource overrides are documented. Earlier limited attempts and stricter-budget
successes remain explicit. A count run interrupted during a host stall retains
its complete samples; only completed guarded retries contribute the remaining
counts. No cause is assigned to the host stall, and no universal large SML
execution is claimed. M3 remains in progress.

The [allocation/stack review](validation/sandmark-allocation-probes.md) records
four exact-source deferrals for unavailable optimization barriers. All 143
Sandmark entries were rebuilt; only four dispositions/reasons changed and every
other inventory field/alias order is preserved. All 861 entries validate and
all 41 discovery tests, including twelve new subcases, pass. The retained Cmm
reproduces byte for byte. No prerequisite runtime/compiler feature is added.
M5 remains in progress.

A provenance reconciliation also adds the omitted directory Revised BSD notice
for spectralnorm2, retaining its exact CRLF bytes and refreshing source identities.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 756 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-cryptarithm1-756-acceptance.log)
records the run. Later resource-budget adjustments pass catalogue validation;
benchmark sources and expected results remain the validated implementations.

## M5 sequential trees and indexed permutations, 2026-10-16

Two imports bring the catalogue to 256 programs and 762 profiles. [All 84
smoke/normal cases](results/m5-tree-permutations/correctness.tsv) pass for the
new programs and refactored classic binary-trees on Rune's four engines at both
levels and all six managed native hosts. Twelve normal count samples pass the
combined comparison with unchanged budgets. Eight tree and ten permutation
semantic/negative checks pass all ten configurations at both levels. These
instrumented counts remain separate from headline timings.

Only the tree datatype is extracted from the classic program; its generator,
leaf shortcut and profiles are unchanged. Sandmark's variant preserves right-first
construction/traversal and Empty-child checks. The permutation port preserves
32 sequential chunks and its optimized flip/count convention, with a reviewed
terminal-counter guard replacing an invalid access hidden by upstream -unsafe.
Original/checked/repaired evidence, exact repair diff, complete fixtures,
independent references and selected numeric bounds are retained. Large original
references are available; large execution of the new SML programs is not claimed.
No prerequisite compiler/runtime feature is added. M5 remains in progress.

An initial ML Kit 4.7.23 test-adapter compilation crashes in DropRegions when
kernel and test share a basename. Distinct test filenames compile and pass;
the original failure transcript is retained and no broader cause is asserted.
Benchmark kernels were unchanged for that naming correction.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 762 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-tree-permutations-762-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M5 sequential FASTA output strategies, 2026-10-16

Two imports bring the catalogue to 258 programs and 768 profiles. [All 56
smoke/normal cases](results/m5-fasta/correctness.tsv) pass on Rune's four engines
at both levels and all six managed native hosts. Nine semantic/negative checks
pass all ten configurations at both levels. Eight normal count samples pass the
combined comparison with unchanged budgets. These instrumented samples remain
separate from headline timings.

The variants preserve division/reciprocal arithmetic, linear/midpoint lookup,
line/whole-buffer allocation, source data and cross-sequence RNG state. Reviewed
complete RNG-cycle bytes and an independent header/line state machine check every
output byte. Originals and an independent periodic reference agree through the
published 25,000,000 input. Source/dataset/notice identities, buffer initialization,
seed reset, input acquisition and validation costs are recorded. Large execution
of the new SML ports is not claimed. No prerequisite runtime/compiler feature is
added. M5 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 768 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-fasta-768-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M4 variable-width compression, 2026-10-16

Two imports bring the catalogue to 260 programs and 774 profiles. [All 112
smoke/normal cases](results/m4-compress2/correctness.tsv) pass for both new
variants and both existing users of the shared compression driver, on Rune's
four engines at both levels and all six managed native hosts. Eighteen semantic,
writer and demand checks pass all ten configurations at both levels. Sixteen
normal count samples pass the combined comparison with unchanged budgets.
These instrumented samples remain separate from headline timings.

The port preserves the five-field persistent dictionary, variable-width event
protocol and shared byte-count feedback knot. The strict variant makes finite
dictionary construction eager while retaining the causal delayed feedback streams.
Complete compressed bytes are checked before hashing. All three original
500-iteration runs match pinned stdout fixtures; all 31 cut fixtures per profile
agree with the corresponding original hashes. Source integer widths, full-result
forcing, XML attribution and missing individual program/input notices are explicit.
The common driver's maximum repetition guard changes from 200 to 500; existing
selected profiles and codecs are unchanged and included in the regression run.
No general .Z compatibility, universal large SML execution or prerequisite
compiler/runtime feature is claimed. M4 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 774 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-compress2-774-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M3 propositional rewriting, 2026-10-16

Two imports bring the catalogue to 262 programs and 780 profiles. [All 56
smoke/normal cases](results/m3-clausify/correctness.tsv) pass on Rune's four
engines at both levels and all six managed native hosts. Fifty-nine semantic
and negative checks pass all ten configurations at both levels. Eight normal
count samples pass the combined comparison with unchanged budgets. These
instrumented samples remain separate from headline timings.

Both variants preserve the parser, elimination/negation/distribution pipeline,
ordered clauses, exact spacing, FAST/NORM/SLOW sizes and all 67 repetitions.
Need retains formula/list/field sharing and short-circuit demand; Strict
materializes finite structures. Eager parser stacks, finite spacing, absent
SML97 NOINLINE pragma and full character comparison are documented. Original
GHC matches all pinned stdout bytes; an independent CNF converter and complete
truth tables agree with 48 original observer outputs. Notices, source identities,
reference reconstruction and raw correctness/count records are retained. No
prerequisite compiler/runtime feature or universal large SML execution is
claimed. M3 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 780 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-clausify-780-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M3 exhaustive histories and M5 sequential FFT, 2026-10-16

Three imports bring the catalogue to 265 programs and 789 profiles. [All 84
smoke/normal cases](results/m3-m5-puzzle-fft/correctness.tsv) pass on Rune's four
engines at both levels and all six managed native hosts. Twelve puzzle and
twelve FFT semantic/negative checks pass all ten configurations at both levels.
Twelve normal count samples pass the combined comparison with unchanged budgets.
These instrumented samples remain separate from headline timings.

Puzzle preserves exhaustive backwards enumeration, prior-state-history pruning,
source order and costs, persistent histories, delayed countdowns, stable equal
minima and full rendering. Original GHC and independent enumeration agree on
21,924 solutions, the entire time histogram, two 17-unit minima and 2,794 bytes;
a separate shortest-path traversal confirms the optimum. FFT preserves source
pi, twiddles, repeated products, array writes and the conjugated-inverse
convention. Every frequency and roundtrip component is checked with documented
length-dependent budgets. Complete original reference outputs agree with an
independent closed-form ramp DFT at all sizes; small quadratic/complex cases
also agree. Original large output is fully checked before disposal, retaining
its digest and maximum errors. Sources, notices, adaptations and all references
are retained. No prerequisite compiler/runtime feature or universal large SML
execution is claimed. M3 and M5 remain in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 789 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-puzzle-fft-789-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M5 structured numerical workloads, 2026-10-16

Four imports bring the catalogue to 269 programs and 801 profiles. [All 112
smoke/normal cases](results/m5-sequential-numerical/correctness.tsv) pass on Rune's
four engines at both levels and all six managed native hosts. Forty semantic
and negative checks pass all ten configurations at both levels. Sixteen normal
count samples pass the combined comparison with unchanged budgets. Twelve
serial native smoke samples additionally validate MLton, SML/NJ heap export,
Poly/ML compilation and deferred runtime data loading. These single-sample
adapter diagnostics and instrumented counts are separate from headline timings.

Levinson-Durbin preserves correlations, mutable accumulators, fresh arrays and
the source order offset. Every PCM conversion is exact; independent 80-digit
dense solves validate complete smoke/normal results. Durand-Kerner preserves
initialization, simultaneous updates, complex arithmetic, stopping and ten
searches. Independent refinement and full coefficient reconstruction establish
all reference root sets. QR retains dense Householder matrices, row aliasing,
slices and signed-zero behavior, with orthogonality/triangular/reconstruction
checks. Crout retains raw-column pivots, the pivot guard and dense permutation
products. Its full original result differs from input by 10452/1195; exact
rational replay reproduces every returned value to less than 1e-15. Reviewed
source-result fixtures and a counterexample preserve that explicit limitation.

Input caches, parsing/validation costs, reduced-input adapters, numerical budgets,
source/library notices and the vowel attribution gap are documented. References,
raw records and source identities are retained. No prerequisite compiler/runtime
feature or universal large SML execution is claimed. M5 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 801 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-sequential-numerical-801-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M5 sequential neural network and M6 failure categories, 2026-10-16

One import brings the catalogue to 270 programs and 804 profiles. [All 28
smoke/normal cases](results/m5-multilayer/coverage.tsv) are accounted for: 27 pass;
legacy 64-bit SML/NJ normal produces an incorrect numerical result. Every Rune engine
passes both profiles at both levels, and all other native hosts pass. Twelve
semantic/negative checks run on all ten configurations at both levels. All pass
except native32's strict decimal initialization comparison, once per level.
Four normal Rune count samples agree with unchanged budgets. Instrumented
samples and the initial native adapter diagnostics are separate from headline timings.

The port retains complete Ionosphere data, RNG/evaluation order, full Jacobian
and gradient matrices, SGD and the original large iteration count. All source
input values/labels/order match UCI data with retained CC BY 4.0 attribution.
Rune/MLton match all 417 initial parameters exactly. Independent structured
training agrees on complete smoke/normal parameters, predictions and loss;
finite differences check all parameters in a small network. Original large
outputs are retained; universal large SML execution is not claimed.

[Host findings](validation/multilayer-smlnj.md) separate GC-sensitive legacy 64-bit
NaNs from native32 decimal reading. Nursery diagnostics are consistent with the
existing GC report without reducing the exact failing entry. Exact dyadic
references verify all 417 generated parameters; native32 misreads 62 decimal
references by one ulp. Benchmark arithmetic, fixtures and standard configurations
remain unchanged. Failed results supply no accepted timing samples.

M6's shared classifier now recognizes explicit numerical-check exceptions with
the portable Fail prefix, separating incorrect results from runtime failures.
Compiled negative-result/Div probes and the existing four-host measurement
checks pass, including instrumentation rejection and worker isolation. Tool
snapshots include the classifier. M5 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 804 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-multilayer-804-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M5 mutable-body integration and exact bitmap output, 2026-10-16

Two imports bring the catalogue to 272 programs and 810 profiles. [All 56
smoke/normal cases](results/m5-game-numerical/correctness.tsv) pass on Rune's four
engines at both levels and all six managed native hosts. Twenty semantic and
negative checks pass all ten configurations at both levels. Eight normal
count samples pass the combined comparison with unchanged budgets. Six serial
native smoke samples additionally validate MLton, SML/NJ and Poly/ML adapters.
Instrumented counts and single-sample diagnostics remain separate from headline timings.

N-body retains mutable records, source constants, force-product association,
momentum/energy order and velocity-before-position passes. Every run resets
state and checks energies and all 35 body fields. Original full-size states
and independent 60-digit smoke/normal integration agree within reviewed bounds.
Mandelbrot retains refs, cached differences, source stopping, per-pixel exceptions,
carried byte state and exact P4 layout. Modulo-256 Word8 preserves observed
source bytes. BinIO compares every output byte and EOF with bounded memory.
Independent direct-complex/row packing agrees through normal; the complete
32,000,015-byte original large fixture is retained with its identity.

Source/notice identities preserve Revised BSD CRLF bytes. Representation,
input/reset and validation costs are documented. Negative tests reject state
errors and perturbed, truncated or extra bitmap data. No prerequisite
compiler/runtime feature or universal large SML execution is claimed.
M5 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 810 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-game-numerical-810-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M5 three-state arbitrary-precision pi, 2026-10-16

One import brings the catalogue to 273 programs and 813 profiles. [All 28
smoke/normal cases](results/m5-pidigits5/correctness.tsv) pass on Rune's four
engines at both levels and all six managed native hosts. Thirteen semantic
and negative checks pass all ten configurations at both levels. Four normal
count samples agree with unchanged budgets; three serial native smoke samples
validate MLton, SML/NJ and Poly/ML adapters. Instrumented counts and single-sample
diagnostics remain separate from headline timings.

The port preserves three components, both extraction divisions, separate
accumulator additions, tuple-work order and exact streamed digit/block output.
Zarith becomes IntInf with truncating quotient. Complete original outputs through
10,000 digits agree with independent high-precision Gauss-Legendre pi and block
formatting. Source/library identities, original author bytes and notices are
retained. Normal 128 follows bounded calibration; incomplete larger exploratory
sequences contribute no measurements. The general four-coefficient and optimized
nofib variants remain separately implemented. No prerequisite compiler/runtime
feature or universal large SML execution is claimed. M5 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 813 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-pidigits5-813-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M5 seeded sequential evolutionary search, 2026-10-16

One import brings the catalogue to 274 programs and 816 profiles. [All 28
smoke/normal cases](results/m5-evolutionary/coverage.tsv) are accounted for: 26 pass;
both native32 cases raise the documented bounded-random arithmetic Overflow.
Every Rune engine passes both profiles at both levels, as do the other native
hosts. Twelve semantic/negative checks run at both levels on all ten
configurations. Native32's six selection-dependent cases fail with that same
exception; its other six and all other configurations pass. Four normal count
samples agree with unchanged budgets. Three serial native smoke samples also
validate MLton, SML/NJ and Poly/ML adapters. These diagnostics and instrumented
counts remain separate from headline timings.

The port preserves boolean chromosomes, float fitness, strict tie behavior,
recursive selection, copying mutation, every draw and the source's strict
post-generation budget check. Seed 42 replaces OS entropy explicitly. Complete
original deterministic populations agree with independent packed-bit/popcount
computation for tiny/smoke/normal, including exact evaluation/draw counts.
Source/library notices and CRLF bytes, seed patch, originals, references and
all failures are retained. The unmodified nondeterministic original completes
but supplies no golden. No RNG arithmetic workaround, new runtime feature or
universal large SML execution is introduced. M5 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 816 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-evolutionary-816-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M4 sequential smallpt rendering, 2026-10-16

One import brings the catalogue to 275 programs and 819 profiles. [All 28
smoke/normal cases](results/m4-smallpt/coverage.tsv) are accounted for: 26 pass;
both native32 profiles reject different pixels. All Rune engines pass both
profiles at both levels; the other five native hosts pass. Thirteen semantic/
negative checks run on all ten configurations at both levels. Native32 fails
the complete RNG-state/value and smoke-image checks; its other eleven and all
other configurations pass. Four normal count samples agree with unchanged
budgets. Three serial native smoke samples validate MLton, SML/NJ and Poly/ML
adapters. These diagnostics and instrumented counts remain separate from
headline timings. Incorrect pixels supply no accepted measurements.

The port preserves scene geometry, strict vectors, branch/draw/row order,
roulette/splitting, subpixels, jitter, averaging and clamping. Exact dyadic
conversion replaces the bitcast; all 50 selected full RNG states/draws agree
with an independent integer recurrence on passing configurations. Complete
original smoke/normal/full upstream normal/large scenes and strict boxed-STRef
adapter evidence are retained. The adapter changes reference representation
and supplies correctness evidence only. The source hash omits terminal LF;
pinned fixtures add LF, explicitly normalized in their comparison. No RNG
arithmetic workaround or expected-image change hides the native32 finding.
Notices, authorship, input/checking costs and numerical bounds are explicit.
No prerequisite compiler/runtime feature or universal large SML execution
is introduced or claimed. M4 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 819 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-smallpt-819-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M5 reverse complement and byte-key nucleotide counts, 2026-10-16

Two imports bring the catalogue to 277 programs and 825 profiles. Each port's
[28 smoke/normal cases](results/m5-revcomp2/correctness.tsv) pass across Rune's four
engines at both levels and all six managed native hosts; [nucleotide coverage](results/m5-knucleotide/correctness.tsv)
is also complete. Fifteen reverse-complement and sixteen nucleotide semantic/
negative checks pass all ten configurations at both levels. Initial native32
launches hit sandbox SIGSYS; exact replays outside that filter pass. Original
attempts remain in separate ledgers. Eight normal count samples agree across
Rune engines. Existing budgets are unchanged; these new profiles are currently
unbudgeted. Six serial native smoke samples validate MLton, SML/NJ and Poly/ML
adapters. Instrumented counts and single-sample diagnostics remain separate
from headline timings.

Revcomp2 preserves reversed line lists, 61-byte buffering, complement mapping,
header/blank-line/CR behavior and complete byte output. Knucleotide preserves
reusable/copied byte keys, mutable counts, per-length clearing, source hash,
chain order, growth threshold and frequency ordering/formatting. Its option
lookup replaces the source Not_found boundary explicitly, with that library
cost difference documented. Both recreate state and close inputs per call.
Every output byte and EOF is checked. Bad/truncated/extra outputs are rejected;
256 independent four-mer counts exercise collisions and multiple resizes.

Original OCaml and independent complete-output references agree at all selected
input sizes. Fixed fasta3 parameters 1000/50000/500000 preserve deterministic
sequence distributions; large is explicitly reduced from the source default.
The source's 25000000 default is not claimed executed. Knucleotide3's separate
packed representation, omitted final window and cumulative tables are recorded
with original/independent outputs; it is not claimed imported by this wave.
Pinned original sources, library revisions/notices, fixture identities, raw
attempts and corrected reference/adaptor attempts are retained. No prerequisite
compiler/runtime feature or universal large SML execution is introduced or
claimed. M5 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 825 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-revcomp-knucleotide-825-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M3 machine and arbitrary-precision integer grids, 2026-10-16

Two imports bring the catalogue to 279 programs and 831 profiles. [All 56
smoke/normal cases](results/m3-integer/correctness.tsv) pass across Rune's four
engines at both levels and all six managed native hosts. Of 114 semantic/
negative checks, native32 fails only constant subtraction/multiplication wrap
at both levels; its other 112 and every other configuration's 114 pass.
A separate runtime-input probe passes its two checks on all ten configurations.
[The exact constant/dynamic results](validation/integer-smlnj32.md) preserve
the known low-half pattern without changing expressions or expected values.
These diagnostics remain distinct from the fully passing selected profiles.

Eight normal count samples agree across Rune engines. Existing budgets are
unchanged; these new profiles are currently unbudgeted. Six serial native smoke
samples validate MLton, SML/NJ and Poly/ML adapters. Instrumented counts and
single-sample diagnostics remain separate from headline timings.

The ports retain all 14 operations, separate machine64/arbitrary-precision
passes, Cartesian order and forcing. Explicit Word64 helpers avoid default-Int
width assumptions, while IntInf separately performs arbitrary-precision work.
Memoized list heads/spines preserve lazy demand and sharing; the strict variant
constructs finite result lists eagerly. Every result contributes to 28 checked
pair-count/digest lines, followed by EOF. Digest/helper costs and the bounded
positive-stride driver domain are explicit translation choices.

Unmodified GHC originals terminate with empty output. A Show-only value observer
and independent exact model agree at smoke, upstream FAST 300 (selected normal),
upstream NORM 934 and upstream SLOW 2100 (selected large). Separate original/
independent observers verify 98 arithmetic results, wrap and exceptional division.
Earlier 934-grid calibration with a one-cell-ahead enumeration is explicitly
intermediate; final demand tests and canonical results use fully delayed tails.
Source/library identities, notices, inputs, complete logs and references are
retained. No prerequisite compiler/runtime feature or universal large SML
execution is introduced or claimed. M3 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 831 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-integer-831-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M3 demand-sensitive secretary simulation, 2026-10-16

Two imports bring the catalogue to 281 programs and 837 profiles. [All 56
smoke/normal cases](results/m3-secretary/correctness.tsv) pass across Rune's four
engines at both levels and all six managed native hosts. All 145 semantic/
negative checks pass all ten configurations at both levels. Eight normal count
samples agree across Rune engines. Existing budgets remain unchanged; these
new profiles are currently unbudgeted. Six serial native smoke samples validate
MLton, SML/NJ and Poly/ML adapters. Instrumented counts and single-sample
diagnostics remain separate from headline timings.

The unmodified workload plus exact random-1.1 source reproduces its pinned
stdout. Original count-expression observers and an independent complete-
permutation/set model agree through 50000 trials. Separate observers agree on
60 full RNG states, six complete permutations, 30 lazy/strict demand cases and
five general Integer ranges through signed 10^50. Source authorship/history,
dependency revision, BSD/Haskell98 notices and every adaptation are retained.

The lazy variant preserves random streams, linear nub membership, finite
take100, shared prefix maximum/search and early stopping. The strict variant
materializes the complete finite permutation through a bounded producer.
Both retain trial map/filter/length and probability division. Word32 keeps the
source's fixed-width generator states; range accumulation remains IntInf.
Validate all five exact counts, numerical ratios and EOF before reporting.
Negative checks reject changed counts, perturbed/nonfinite probabilities,
truncation and extra data. Each invocation resets the original seed sequence.

Selected profiles use 50/500/5000 trials; the original 5000 default is selected
large, with 50000 retained as an additional reference. Current-kernel Rune O2
preflights validate both 5000 success vectors; they are not canonical large-
profile validation on all configurations. An earlier IntInf-state calibration
was deliberately stopped and remains explicitly intermediate. No compiler
failure or accepted measurement is inferred from that SIGTERM. No alternate
RNG, prerequisite compiler/runtime feature or universal large SML execution is
introduced or claimed. M3 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 837 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-secretary-837-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M3 current, historical and tree Mandelbrot variants, 2026-10-16

Six imports bring the catalogue to 287 programs and 855 profiles. All 168
selected cases are accounted for: 162 pass, five reject incorrect results and
one raises Domain. Only managed legacy 64-bit SML/NJ fails. Every Rune engine passes
both smoke/normal profiles at O0/O2; the other five native hosts pass all
profiles. [Orbit coverage](results/m3-mandel/coverage.tsv) records 110/112 passes;
[tree coverage](results/m3-mandel2/coverage.tsv) records 52/56. The historical
orbit variants pass both profiles on every host.

Twenty-six orbit and 132 tree semantic/negative checks run on all configurations
twice, with Rune O0/O2 and native defaults. Legacy64 fails two orbit and three
tree checks per pass; other configurations pass all checks. Its scalar binary32
bit/demand checks pass. Twenty-four normal count samples agree across Rune
engines. Existing budgets are unchanged; new profiles are unbudgeted. Seventeen
serial native smoke diagnostics pass; one legacy 64-bit lazy-tree correctness
precheck is rejected and contributes no fresh timing. Counts and single-sample
diagnostics remain separate from headline timings.

The current and historical orbit ports preserve generic complex/scaled-norm
versus explicit-squaring/raw-threshold behavior, boundary differences, Integer
coordinates/metadata, cyclic sharing, lazy take and historical extra-head
forcing. Strict variants materialize bounded orbits and pixel lists. Every
channel contributes to exact metadata/count/digest/EOF validation. Complete
original/independent RGB and digest references agree through 180x180, including
zero/one-limit cases. Raw historical source remains unchanged; two modern-GHC
syntax adaptations and library notices are explicit.

The tree ports retain exact binary32 rounding, inclusive geometry, source
perimeter inequalities/outward scans, memoized corners/children and right-first
forcing. Original GHC and independent models agree on every tree row through
full extent200. Scalar bit and injected-point demand tests distinguish numerical
semantics from sharing/evaluation. Complete row/EOF checks reject changed
colours/branches, truncation and extra data. Deterministic SML-generated runtime
parameter/size rows preserve repeated input dependencies. Parsing, hashing,
serialization and checking costs are documented.

[Legacy diagnostics](validation/mandel-smlnj-legacy.md) preserve canonical
categories and exact-source nursery replays. All six failing contexts pass
with a 64 MiB nursery; default replays give four incorrect results, one Domain
error and one pass. This is context-sensitive evidence, not a reduced cause
or a kernel/default-setting workaround. Large preflights/reference executions
remain explicitly distinct from canonical large validation on every host.
No prerequisite compiler/runtime feature or universal large execution is
introduced or claimed. M3 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 855 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-mandel-855-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M3 Lisp-like Boyer2 rewriting and pretty printing, 2026-10-16

Four imports bring the catalogue to 291 programs and 867 profiles. All 112
smoke/normal cases pass across Rune's four engines at both levels and all six
managed native hosts. [Boyer2 coverage](results/m3-boyer2/correctness.tsv) and
[pretty coverage](results/m3-pretty/correctness.tsv) each record 56 cases.
Twenty-five Boyer2 and 42 formatting semantic/negative checks pass all ten
configurations twice, with Rune O0/O2 and native defaults. Sixteen normal
count samples agree across Rune engines. Existing budgets are unchanged;
new profiles are unbudgeted. Twelve serial native smoke samples validate
MLton, SML/NJ and Poly/ML adapters. Instrumented counts and single-sample
diagnostics remain separate from headline timings.

Boyer2 retains binary Lisp terms, association lists, unbalanced LUTs, ordered
rule buckets, argument rewriting and Boolean short circuiting. All 106 exact
rule strings and source parser/unification quirks remain, including the accepted
missing-RHS rule. Immutable runtime-deferred caches preserve initialization
and repeated-mode behavior. Every theorem result is checked. Original full
outputs agree with fixtures through 3000; four complete normalized forms/LUTs
agree with an independent model and all 32 truth assignments. Complete-form
forcing belongs to validation, not the timed theorem workload.

The formatting ports retain higher-order document functions, metadata/child
sharing, layout alternatives, CharSeq constructors, indentation worklists and
output lists. Strict fields/nodes differ explicitly from memoized evaluation;
both retain the finite boundary on cyclic word input. Exact original and
independent layouts preserve tabs, trailing spaces, empty-document behavior
and newlines. Forty-two checks include edge layouts and demand failures;
incorrect bytes/whitespace and truncated/extra output are rejected. Original
normal width80/50 words produces 343 checked bytes; larger reference/preflight
coverage remains distinct from canonical large validation on every host.

Source notices, history, exact dependency/data origins, representation/output
adaptations, raw reference observers, complete results and all samples are
retained. No prerequisite compiler/runtime feature or universal large execution
is introduced or claimed. M3 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 867 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-boyer-pretty-867-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M3 Last Piece persistent-map board search, 2026-10-16

Two imports bring the catalogue to 293 programs and 871 profiles. [All 56
smoke/normal cases](results/m3-last-piece/correctness.tsv) pass across Rune's four
engines at both levels and all six managed native hosts. Twenty semantic/
negative checks pass all ten configurations twice, with Rune O0/O2 and native
defaults. Eight normal count samples agree across Rune engines. Existing budgets
are unchanged; new profiles are unbudgeted. Six serial native smoke samples
validate MLton, SML/NJ and Poly/ML adapters. Counts and single-sample diagnostics
remain separate from headline timings.

The port preserves containers' size-balanced persistent map and source rotations;
all 256 insertion-prefix shapes agree with the pinned original. Reversed skipped-
prefix choices, orientation order, shared remaining pieces, delayed child search,
sex transitions and unchecked-anchor fit preconditions remain. Strict evaluation
constructs the finite tree eagerly. Both variants reproduce the original three
solutions and all 300 output bytes. Used-domain rendering preserves indented
blank lines without claiming the entire external pretty library.

Original/independent prefix cases agree at 0/2/8/13 pieces. The full bitmask model
visits 103513 search states; original statistics report 59488 failures and three
solutions. Smoke is a valid reduced two-piece subproblem; normal preserves the
full fixed puzzle. No artificial larger instance is introduced. Every output
byte and EOF are checked; wrong/truncated/extra output is rejected. Exact source,
dependency revisions/notices, witness inputs, models and all results are retained.
No prerequisite compiler/runtime feature is introduced or claimed. M3 remains
in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 871 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven compiler builds.
runedoc and runeopt also agree. [The complete transcript](validation/oct16-last-piece-871-acceptance.log)
records the run. All 41 inventory tests pass and all 861 entries validate.

## M3 typed Boyer terms and recursive lemma graphs, 2026-10-16

Two imports bring the committed catalogue to 295 programs and 877 profiles.
[All 56 final smoke/normal cases](results/m3-typed-boyer/correctness.tsv) pass
across Rune's four engines at O0/O2 and all six managed native hosts. The initial
run's Rune O0 strict-smoke timeout at 30 seconds is retained in the complete
60-attempt ledger. A documented 60-second override preserves FAST2 and all 100
repetitions; all four O0 engines pass the replay. Normal preserves NORM15 and
its default 600-second limit. No incorrect result is accepted as a measurement.

Thirty semantic/negative checks pass all ten configurations twice, with Rune
O0/O2 and native defaults. Original and independent models agree on complete
input/normalized terms, all nine variable inputs and all 32 truth assignments;
only X proves the theorem. Its normalized form contains 170284 bytes. All three
original stdout fixtures match. Equality avoids forcing cyclic lemma fields,
substitution preserves their pointers, and failed unification environments remain
undemanded when their Boolean is false. This typed representation stays separate
from classic Boyer and nofib's Lisp-parsing Boyer2 variant.

Eight normal count samples agree across applicable Rune engines, including
allocation counts for all four. Existing budgets are unchanged; these new
profiles are unbudgeted. Six serial native smoke samples validate the MLton,
SML/NJ and Poly/ML adapters. Bounded preflights, counts and single-sample adapter
diagnostics remain separate from headline timings. Exact sources, Public Domain
notice/history, inputs, observers, independent models and raw results are kept.
No prerequisite compiler/runtime feature is introduced. M3 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0. It checks the 877-profile
catalogue, the 16-program routine set, 331 language fixtures per compiler,
existing budgets, bootstrap and 498 identical bytecode comparisons across seven
compiler builds. runedoc and runeopt also agree. [The complete transcript](validation/oct16-typed-boyer-877-acceptance.log)
records the run. The separately recorded inventory checks validate 861 entries
and pass all 41 tests before the subsequent profile-input audit refresh.

## M3 Eliza and M5 packed nucleotide representations, 2026-10-16

Four imports bring the catalogue to 299 programs and 889 profiles. All 112
smoke/normal cases pass across Rune's four engines at O0/O2 and all six managed
native hosts: [Eliza](results/m3-eliza/correctness.tsv) and
[packed nucleotide counting](results/m5-packed-nucleotide/correctness.tsv).
All 60 Eliza and 32 nucleotide semantic/negative checks pass all ten
configurations twice, with Rune O0/O2 and native defaults. Sixteen normal count
samples agree under the execution-model rules, including allocation across all
four engines. Existing budgets are unchanged; these new profiles are unbudgeted.
Twelve serial native smoke samples validate MLton, SML/NJ and Poly/ML adapters.
Counts, preflights and one-sample diagnostics remain separate from headline timings.

Eliza preserves ordered keywords, exact conjugations, cyclic reply rotation and
repeated-input handling. Memoized initial queues are shared; every conversation
is recomputed. Independent models match all 20 full prefix conversations and all
65000 original length rows. Separate lazy response/next-state fields preserve
unused-state demand. Strict input loading, word/string representation and fused
candidate-list layers are explicit translation choices. Source normal 13000 and
large 65000 remain; smoke covers one complete prefix cycle.

The packed counter preserves the omitted last window and cumulative tables,
including cross-length leading-zero aliases. Fixed thresholds 31/15 retain the
source's single-/pair-key representations on every SML host. The original 64-bit
OCaml program and an independent model agree on full outputs for all selected
input sizes. A separate threshold 15 observer also agrees; it does not constitute
a 32-bit OCaml compiler run. Original library observations pin 512 colliding keys,
resize/fold order and all smoke-pass statistics. Buffer reservation, option lookup,
tagged keys, sorting and output checking remain documented adaptations. The
byte-key counter stays a separate source variant.

Both families reject changed/truncated/extra output before accepting a result.
Exact source/input/library notices, originals, observers, models, raw samples,
source identities and the clean pinned inventory replay are retained. Large SML
validation is claimed only where recorded. No compiler/runtime prerequisite is
introduced. M3 and M5 remain in progress; M4 and M8 are not closed by these imports.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with the 889-profile catalogue,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 matching bytecode comparisons across seven builds. runedoc and
runeopt also agree. [The complete transcript](validation/oct16-eliza-packed-889-acceptance.log)
records the run. All 45 inventory regressions pass and all 861 entries reproduce
from the five clean pinned trees, including the separately committed profile-input
and related-name-order fixes.

## M4 polymorphic inference application, 2026-10-16

Two imports bring the catalogue to 301 programs and 895 profiles. [All 56
smoke/normal cases](results/m4-infer/correctness.tsv) pass across Rune's four
engines at O0/O2 and all six managed native hosts. All 74 semantic/negative checks
pass all ten configurations twice, with Rune O0/O2 and native defaults. Eight
normal count samples agree under the execution-model rules, including allocation
across all four engines. Existing budgets are unchanged; new profiles remain
unbudgeted. Six final serial native smoke samples validate MLton, SML/NJ and
Poly/ML adapters. The initial two SML/NJ compile errors from ambiguous tuple
selectors remain alongside the corrected explicit-pair version's results; failed
compilation contributes no accepted execution sample. Four earlier successful
adapter samples are retained too. Counts and one-sample diagnostics remain
separate from headline timings.

The unmodified original matches all three 200-line fixtures. Full rendered texts
have 643/990/1404 bytes and independently matching 64-bit hashes. A separate
parser/Algorithm W model agrees on all 48 profile expressions modulo type-variable
renaming, including rejected terms. Twenty-four original expression sessions
cover polymorphism, shadowing, parse/type failures and the source let-prefix
quirk. Exact source output, independent models and boundary observations support
different claims rather than treating one compiler as the whole specification.

Both variants memoize parser/control spines for greedy cut pruning; value fields
and term/type constructors use lazy or strict evaluation. An initial eager-spine
prototype hit its 2 GiB guard and is retained separately with its source snapshots.
The corrected bounded pilot matches all six full outputs, and both source 200-
iteration normal computations pass. Association maps retain shadowed entries,
duplicate substitution domains and a shared new binding. State wrappers are
administratively fused; source unification, occurs checks, fresh-variable order,
partial arity behavior and one-occurrence subtraction remain. Full byte/EOF and
hash checking rejects incorrect results before accepting a summary/measurement.

Every profile preserves 200 repetitions and its exact upstream input. Runtime
input reads replace the opaque NOINLINE salt dependency; input/checking costs
and character/string representation decisions are documented. Immutable initial
environment/header setup may be shared; computed terms/types are not reused as
repeated-run answers. Source/data notices, primary literature, models,
experiments, exact identities and all raw results are retained. Large SML claims
remain limited to recorded checks. No compiler/runtime prerequisite is added.
M4 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 895 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 identical bytecode comparisons across seven builds. runedoc and
runeopt also agree. [The complete transcript](validation/oct16-infer-895-acceptance.log)
records the run. All 45 inventory fixtures pass and all 861 entries validate;
the preceding full clean pinned-tree replay remains recorded separately.

## M3 Cichelli perfect-hash search, 2026-10-16

Two imports bring the catalogue to 303 programs and 901 profiles. [All 56 smoke/
normal cases](results/m3-cichelli/correctness.tsv) pass across Rune's four engines
at O0/O2 and all six managed native hosts. All 36 semantic/negative checks pass all
ten configurations twice, with Rune O0/O2 and native defaults. Eight normal count
samples agree under the execution-model rules, including allocation across all
four engines. Existing budgets are unchanged; new profiles remain unbudgeted.
Six serial native smoke samples validate MLton, SML/NJ and Poly/ML adapters.
Counts, bounded preflights and one-sample diagnostics remain separate from
headline timings.

The unmodified original matches complete FAST 6/NORM 60/SLOW 300 outputs of
507/5070/25350 bytes without added line separators. Original and independent
set-based searches agree on data/order, both parity problems and seven key-prefix
cases. Odd indices add a duplicate first keyword and fail with 324 leaves; even
indices find the first full assignment with 113994 leaves. The independent model
visits 631/116083 states respectively. The successful 17-letter witness maps 22
keywords to the interval 4..25. Source feedback counts leaves rather than all
recursive states.

Identity frequency ordering, right-fold histogram/partition order, original-left
union membership, association precedence, inclusive weights 0..17 and fixed range
bound 22 remain. Both variants short circuit on first success and memoize result
spines; count fields and finite candidate construction use lazy or strict
semantics. Finite key setup uses strict lists in both. All selected values fit
signed 31-bit Int, with positive count sums bounded by the recorded final result.
These are explicit translation choices rather than a new hashing algorithm.

SML-generated runtime index files preserve exactly 1..n with work counts 6/60/300.
Every index recomputes its search; prior parity results are not reused as repeated-
run answers. Complete bytes and EOF are checked before accepting a summary or
measurement. Large preserves repetitions of the fixed dictionary; large SML
validation is claimed only where recorded. Notices, primary bibliographic
metadata, originals, independent models, raw results and exact identities are
retained. No compiler/runtime feature prerequisite is introduced. M3 remains
in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 901 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 identical bytecode comparisons across seven builds. runedoc and
runeopt also agree. [The complete transcript](validation/oct16-cichelli-901-acceptance.log)
records the run. All 45 inventory fixtures pass and all 861 entries validate;
the preceding full clean pinned-tree replay remains separately recorded.

## M4 SET circuit simulation and host arithmetic diagnostics, 2026-10-16

Two numerical variants bring the catalogue to 305 programs and 907 profiles.
[The complete 56-case smoke/normal ledger](results/m4-scs/coverage.tsv) records 53
passes and three incorrect native legacy 64-bit SML/NJ results. All four Rune engines
pass both optimization levels/profiles/variants; all five other native hosts
pass. Default-setting failures remain recorded, with no accepted timing. Separate
64 MiB nursery replays pass all three failed profile cases, supporting a recorded
GC-corruption hypothesis without changing suite defaults or proving a reduction.

The 118-case semantic/negative set runs on all ten configurations twice, with
Rune O0/O2 and native defaults. Of 2360 assertions, 2329 pass and 31 fail. Three
SML/NJ subnormal conversion boundaries fail per host/run; six explicit Poly/ML
integral-nearest probes fail per run; one additional legacy 64-bit workload assertion
fails. Every assertion passes on Rune, MLton and MLKit. The complete outputs and
per-configuration summaries preserve the failures. The bit encoder now truncates
an exactly integral significand; separate nearest-mode probes retain the Poly/ML
native defect, with a [minimal report](../../docs/bugreport/polyml/Real.toLargeInt/nearest-integral/BUGREPORT.md).
No kernel arithmetic is changed for a host bug. [The host note](validation/scs-host-math.md)
links the existing SML/NJ reports and separates observed behavior from hypotheses.

Eight normal count samples agree under the execution-model rules, including
allocation across all Rune engines. Existing budgets remain unchanged; new
profiles are unbudgeted. Five serial native smoke samples pass adapter validation;
one legacy lazy correctness precheck rejects an incorrect result before sampling.
Counts, bounded preflights and single-sample diagnostics remain separate from
headline timings.

The unmodified original matches all Done fixtures. Export-only observers and a
separate Fraction/mutable-matrix/binary64 model agree exactly on all three full
traces: 371/2913/11315 rows and 170/912/1314 extra events. Exact prepared matrices
and binary64 conversions agree too, with 3960 Rune bit checks. Independent normal/
large minimum CDF margins exceed 8.56e-6. Validation checks exact names, dimensions,
rational times/event records, row counts and EOF, plus finite current/voltage
bounds. Deliberately perturbed values, nonfinite values and malformed/truncated/
extra data are rejected. Synthetic small circuits cover every element class,
full-rank preprocessing, zero temperature, background charge and huge seeds.

Exact IntInf rational preprocessing, source pivots/accumulation order, seeded
random mapping, constraint corrections, probability normalization, first-event
selection, last-state stepping and inclusive end times remain. Numerical cells
use lazy or eager payload evaluation; parser/RNG/conditional/trace control remains
memoized. Source parameters and literal inverter data stay fixed. GEN17 rendering
and escape-length counting replace the Haskell formatter with documented costs.
No prior trajectory serves as a repeated-run answer. Exact original/base/array
notices, references, raw traces, models, diagnostics and identities are retained.
Whole large SML validation is claimed only where recorded. No prerequisite
compiler/runtime feature is added. M4 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 907 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 identical bytecode comparisons across seven builds. runedoc and
runeopt also agree. [The complete transcript](validation/oct16-scs-907-acceptance.log)
records the run. All 46 inventory fixtures pass and all 861 entries validate;
the clean pinned-tree circuit-input replay is separately recorded.

## M0 source dependency follow-up — quoted CPP includes, 2026-10-16

The [source review](validation/hartel-cpp-inventory.md) adds transitive quoted
Haskell/C headers to source identities and removes preprocessor include paths
from runtime input metadata. The exact pinned Hartel shim receives a narrowly
scoped portable scalar-operation review. Changed shims and direct primitive
imports still require review. No compiler/runtime feature or benchmark profile
changes. [All 19 metadata differences](results/m0-cpp-includes/source-differences.json)
affect only members, SHA-256 identities or inputs; names, dispositions and
milestones remain unchanged. All five clean pinned trees reproduce 861 entries.
All 56 discovery/classification regressions pass.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 907 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 identical bytecode comparisons across seven builds. runedoc
and runeopt also agree. [The complete transcript](validation/oct16-cpp-inventory-907-acceptance.log)
records the run. [Source identities and replay logs](results/m0-cpp-includes/README.md)
make the correction reviewable. Timing and count baselines are unchanged.

## M3 Hartel comprehension compiler/copy wave — 2026-10-16

Four variants bring the catalogue to 309 programs and 919 profiles:
listcompr-lazy/strict and listcopy-lazy/strict. The [complete coverage ledger](results/m3-hartel-compr/coverage.tsv)
records all 112 canonical smoke/normal cases passing on Rune's four engines at
O0/O2 and six native hosts at compiler defaults. All 42 semantic checks pass on
each configuration in both invocations (840 assertions). Native hosts are not
claimed to have been tested with Rune optimization flags.

[Sixteen normal count samples](results/m3-hartel-compr/count-samples.tsv) agree
under execution-model rules, including allocation across all Rune engines.
Existing budgets are unchanged; new profiles remain unbudgeted. Twelve serial
single fresh-process native smoke samples validate the adapters on MLton,
legacy 64-bit SML/NJ and Poly/ML. These diagnostics remain separate from headline
comparisons, instrumented counts and bounded resource preflights.

The original GHC programs match all six upstream fixtures and the selected suite
inputs. A separate AST desugarer/renderer agrees with the full transformed AST
and every byte of its 626-character rendering. Source review identifies five
input definitions, parent-name scope during nested desugaring, the leading-newline
LET renderer quirk, unused lambda-lifting helpers and the exact copy-wrapper
variation. Both sources and their Fast2haskell compatibility include are preserved.
Lazy/eager AST evaluation is separately named; both length consumers preserve
unused character heads. Copy tests require fresh spines with shared head cells;
repetition tests require fresh transformations. Wrong, truncated and extra
rendered fixtures are rejected.

Profiles explicitly select 20/2000/20000 repetitions. Normal preserves upstream
FAST_OPTS; large preserves NORM_OPTS. The original SLOW_OPTS=100000 fixture remains
in provenance. A private 20000-repeat preflight exhausted a 4 GiB address-space
limit. Whole large SML validation under the selected 8 GiB limit is unrecorded.
An earlier prototype introduced quadratic suffix copies through concatenation;
that implementation was corrected before the canonical checks. Its stopped and
bounded preflights are retained separately and cannot supply timing samples.
[Raw evidence and source identities](results/m3-hartel-compr/README.md) accompany
the accepted results. M3 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 919 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 identical bytecode comparisons across seven builds. runedoc
and runeopt also agree. [The complete transcript](validation/oct16-hartel-compr-919-acceptance.log)
records the run. All 56 inventory regressions and all 861 inventory entries pass.

## M3 Wang numerical wave — 2026-10-16

Two variants bring the catalogue to 311 programs and 925 profiles. All [56
canonical smoke/normal cases](results/m3-wang/coverage.tsv) pass on Rune's four
engines at O0/O2 and six native hosts at their compiler defaults. All eight
normal count samples agree under execution-model rules, including allocation
across all Rune engines. Existing budgets remain unchanged. Six serial single
fresh-process native smoke samples validate the adapters separately from
instrumentation and headline comparisons.

The [37-check auxiliary program](results/m3-wang/semantic-summary.tsv) records
14 complete passing runs, four with incorrect results and two runtime failures.
Of 740 planned assertions, 714 pass, six fail and 20 remain unfinished after
32-bit SML/NJ aborts. The [host note](validation/wang-host-results.md) distinguishes
these default failures from successful profile validation and separate 64 MiB
nursery replays. All three supplied SML/NJ hosts pass the latter; the sources
and default settings remain unchanged. The exact cause is unreduced. Existing
reports and current issue-state metadata provide investigation references;
newer upstream builds have not been tested here.

The original Haskell program matches every byte of all three 500-line fixtures.
Full numerical observers and an independent mutable blocked model agree bit for
bit on 29780 uniform and 124 nonuniform values. SML checks preserve source
reconstruction divisions and block pairing, verify every scalar against explicit
bounds, validate source checksums and repeated formatting, test sharing/demand,
and reject deliberately perturbed and nonfinite values. All source notices and
literal fixtures are preserved. Smoke reduces only repetitions to one at block
size 25; normal and large retain sizes 80/150 and all 500 repetitions. Both
whole-program Rune O2 normal and large pilots pass under their recorded guards.
[Raw evidence and source identities](results/m3-wang/README.md) accompany every
scope. M3 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 925 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 identical bytecode comparisons across seven builds. runedoc
and runeopt also agree. [The complete transcript](validation/oct16-wang-925-acceptance.log)
records the run. All 56 inventory regressions and all 861 inventory entries pass.

## M3 Hartel FFT execution/generation wave — 2026-10-16

Four variants bring the catalogue to 315 programs and 937 profiles. All [112
canonical smoke/normal cases](results/m3-hartel-fft/coverage.tsv) pass on Rune's
four engines at O0/O2 and six native hosts at compiler defaults. The numerical
family's 45 checks and generator's 39 checks pass on every configuration in both
invocations (1680 assertions). Sixteen normal count samples agree under
execution-model rules, including allocation across all Rune engines. Existing
budgets are unchanged. Twelve serial single fresh-process native smoke samples
validate the adapters separately from headline timings and instrumentation.

Both original GHC programs match all six complete 360/300-line fixtures. Full
vectors agree with independent positive-sign direct DFTs and a repeated-ramp
closed form. The pinned GHC Complex module confirms strict components in both
ports. Lazy whole values/collections and eager collections remain distinct;
source root arguments, shared products, persistent array stages, explicit
butterfly association lists and recursive list reordering are retained. The
SML array adapter validates complete unique writes. Every finite scalar is
checked with documented bounds stronger than the source's 0.5 comparison.

Complete generator text agrees with a separate bit-mask/string renderer.
Eight generated dependency graphs agree with direct DFTs on nonuniform complex
inputs under documented operation meanings. Every generated character and EOF
is checked against a reviewed fixture; a transposition with unchanged source
checksum/length is rejected. Tests cover complete maxima 0..8, repeated output,
character sharing, unused separators and partial empty glue. The measured
workload generates text; the graph interpretation is an independent check.

Both normal Rune O2 pilots retain all 360/300 original iterations. Smoke reduces
only repetitions to one at the original FAST input. Large vectors/text have
recorded complete and auxiliary repeat checks; whole original-repeat large
profile validation is not claimed. Profile, library, forcing, initialization,
validation and output adaptations accompany individual source notices and pins.
[Raw evidence, resource guards and source identities](results/m3-hartel-fft/README.md)
record each scope. M3 remains in progress.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 937 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 identical bytecode comparisons across seven builds. runedoc
and runeopt also agree. [The complete transcript](validation/oct16-hartel-fft-937-acceptance.log)
records the run. All 56 inventory regressions and all 861 inventory entries pass.

## M3 circuit simulator wave — 2026-10-16

Four variants bring the catalogue to 319 programs and 949 profiles. All [112
canonical smoke/normal cases](results/m3-circsim/coverage.tsv) pass on Rune's four
engines at O0/O2 and six native hosts at compiler defaults. All 79 semantic
checks pass in every configuration in both invocations (1580 assertions).
Sixteen normal count samples agree under execution-model rules, including
allocation across all Rune engines. Existing budgets are unchanged. Twelve
serial single fresh-process native smoke samples validate the adapters
separately from instrumentation and headline comparisons.

The GC and spectral sources share their complete simulator; only their main
consumer/comment differs. Original spectral executions match all three complete
97-line fixtures. The GC program has no stored stdout fixture and returns unit
without output. Observers agree on full traces; an independent hold/load model
agrees with five varied original traces. The measured code retains processor
states, port/packet products, immutable updates and balanced-tree prefix routing.
Both policies preserve source XNOR, extent-one empties, strict routing boundaries,
depth guards, short circuiting and request restoration. Character streams remain
lazy in both, keeping GC's unused heads distinct from printed consumption.
Validation follows existing Show-spine demand points without a retained postpass.

Tests cover source profiles and repetitions, varied widths/data, malformed and
checksum-colliding traces, inactive gates, empty-input/label/root-summary demand,
packet windows/payloads and transpose. Both normal Rune O2 policies/consumers
retain all 97 repetitions. Smoke reduces only repetitions to one. Large complete
and auxiliary-repeat checks have their recorded scope; whole original-repeat
large validation is unrecorded. [Raw evidence and source identities](results/m3-circsim/README.md)
include every accepted scope and resource guard. M3 remains in progress.

The exact literate heading credits David J. King and John O'Donnell. Two inventory
rows gain authors/evidence only; identities, names and dispositions remain. All
58 inventory regressions pass and all five clean pinned trees reproduce 861
entries. Complete original files, runtime flags and individual notices remain.

Full `DEBUGINFOD_URLS= make JOBS=4 check` exits 0 with 949 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 identical bytecode comparisons across seven builds. runedoc
and runeopt also agree. [The complete transcript](validation/oct16-circsim-949-acceptance.log)
records the run.

## M3 atom stream wave — 2026-10-17

Two variants bring the catalogue to 321 programs and 955 profiles. The
[56-case canonical smoke/normal ledger](results/m3-atom/coverage.tsv) records 52
passes and four incorrect results on legacy 64-bit SML/NJ 110.99.9. All Rune
engines at O0/O2 and five other native hosts pass. Auxiliary checks record
996 passing assertions and four failures in the same legacy configuration.
All rounding, finite-domain and demand probes pass. [The host note](validation/atom-host-results.md)
records trace differences and default/64-MiB nursery replays without assigning
an unreduced cause or modifying the source to accommodate a compiler result.

Eight normal count samples agree under execution-model rules, including
allocation across all four Rune engines. Existing budgets remain unchanged.
Four serial single fresh-process MLton/PolyML smoke samples validate adapters
separately from instrumentation and headline comparisons. Both attempted legacy
samples are rejected at correctness precheck; no incorrect result contributes
a timing sample.

All three original GHC text fixtures match. Independent binary32 Euler
calculations agree on all 4000 original positions and velocities. Checked operand
domains establish that the unchanged finite-normal binary32 helper represents
the selected intermediate operations exactly before rounding. Primary lazy
validation preserves position-only demand, while auxiliary observers also check
velocities. Source stream recursion remains unshared between experiment calls;
small counted-force probes detect knotting and distinguish finite evaluation
policies. The original right-tail-square list multiplication quirk is retained.

Tests cover exact position/state bits, stream/field demand, head sharing, vector
quirks, rounding ties, signed zero, formatting roundtrips and wrong/short/extra
references. Whole normal Rune O2 pilots pass for both policies. Smoke is a
bounded 100-state prefix; normal=2500 and large=4000 retain original parameters.
Whole original large SML validation is unrecorded. [Raw evidence and identities](results/m3-atom/README.md)
distinguish original, independent, semantic, guarded and measured scopes.

The source's exact multiline heading credits Ron Legere. One inventory row gains
authorship/evidence only; names, identities and dispositions remain unchanged.
All 60 inventory regressions pass, and all five clean pinned trees reproduce
861 inventory entries. M3 remains in progress.

Full DEBUGINFOD_URLS= make JOBS=4 check exits 0 with 955 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 identical bytecode comparisons across seven builds. runedoc
and runeopt also agree. [The complete transcript](validation/oct17-atom-955-acceptance.log)
records the run.

## M3 constructive exact real arithmetic wave — 2026-10-17

Two variants bring the catalogue to 323 programs and 961 profiles. All [56
canonical smoke/normal cases](results/m3-exact-reals/coverage.tsv) pass on Rune's
four engines at O0/O2 and six native hosts at compiler defaults. All 209
arithmetic/demand checks pass in every configuration in both invocations
(4180 assertions). Eight normal count samples agree under execution-model rules,
including allocation across all Rune engines. Existing budgets remain unchanged.
Six serial single fresh-process native smoke samples validate adapters separately
from instrumentation and headline comparisons.

Unmodified original GHC programs at endpoints 60/350/800 match the complete
shared zero fixture. Observers record zero 137-bit approximants. Fourteen
nontrivial and zero scalar cases supply 84 exact integer approximants and
fourteen forty-place texts, all reproduced by both policies. Independent
120-digit mpmath calculations bound their numerical errors. [The literature
review](validation/exact-reals-literature.md) distinguishes algorithmic arguments,
the source translation and empirical port validation.

CR values remain precision-to-IntInf functions without argument-result caches.
Source ratio normalization, floor(rational+1/2) rounding, guard bits, enumeration,
left-associated summation, range reduction, shared multiplication bounds and
repeated reciprocal searches remain. Infinite coefficients and constants share
source constructions. Finite selected series remain separately lazy/strict;
tests detect unused-tail demand, premature input evaluation and reassociation.

The source's smallest endpoint 60 timed out at 600 seconds in the initial lazy
Rune stack pilot; the combined pilot never began strict mode. Suite smoke=1 and
normal=10 change only the summation endpoint, retaining forty decimal places.
Large=60 keeps original FAST; whole large SML validation is unrecorded. Source
350/800 parameters, original fixtures and the timeout remain in provenance.
Initial calibration used the earlier square-root implementation; its source is
retained. Fresh final canonical/semantic/count checks use the restored explicit
ratio-normalizing improvement. The final scalar pilot exercises that branch.

[Raw results and source identities](results/m3-exact-reals/README.md) preserve
complete attempts, samples, numerical references, semantic logs and guards.
All 62 inventory regressions pass and all five clean pinned trees reproduce
861 entries. One row gains David Lester's exact paper attribution/evidence only;
identities, names and dispositions remain. M3 remains in progress.

Full DEBUGINFOD_URLS= make JOBS=4 check exits 0 with 961 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 identical bytecode comparisons across seven builds. runedoc
and runeopt also agree. [The complete transcript](validation/oct17-exact-reals-961-acceptance.log)
records the run.

## M3 minimax and M5 sequential many-body wave — 2026-10-17

Three programs bring the catalogue to 326 programs and 970 profiles. All 84
canonical smoke/normal cases pass: [56 minimax cases](results/m3-minimax/coverage.tsv)
and [28 many-body cases](results/m5-manybody/coverage.tsv), across Rune's four
engines at O0/O2 and six native hosts at compiler defaults. Twelve normal count
samples agree under execution-model rules, including allocation across all Rune
engines. Existing budgets remain unchanged. Nine serial single fresh-process
native smoke samples validate adapters separately from instrumentation and
headline comparisons.

Minimax preserves depth-five game-tree construction/pruning/scoring/cropping,
row-major moves, first-board ties, ordered winning masks, mapped Boolean lists,
fresh position comprehensions and higher-order player functions. Lazy short
circuiting and eager finite tree construction remain distinct. GHC and a separate
position evaluator agree on the complete 194-character game and eleven varied
static/max/min analyses. Final-source Rune O2 pilots validate all 100 normal
games; the 180000/1800000/9000000 original repeat counts remain documented.
Whole large SML validation is unrecorded.

Eighteen minimax auxiliary invocations pass all 96 assertions. Both ML Kit
invocations pass 90 before an allocation error leaves six checks unreached:
1908 passed assertions, zero failed assertions, twelve unreached, and two
runtime-failure statuses. [The host note](validation/minimax-host-results.md)
records a three-node full-functor reproduction at a 256-MiB cap and passing
controls. Its cause remains unreduced; neither the source nor the valid test
is changed to hide it. All primary ML Kit benchmark cases pass.

Many-body uses the distinct random-body ordered-pair kernel, retaining the
source's solar-mass offset denominator and right-to-left initializer draws.
All 49 checks pass in every invocation (980 assertions), including perturbations
of every four-body fixture component, length/nonfinite rejection, an analytic
step, offset behavior and fresh state. Original OCaml/observers agree on nine
cases, including default 500/1024 large input. A separate generator/simulator
agrees exactly on checked initial/small/smoke/normal numbers. Bounds are
absolute 1e-9 plus relative 1e-11 for both energies and every final field.
Whole large SML integration is unrecorded.

[Minimax evidence](results/m3-minimax/README.md) and [many-body evidence](results/m5-manybody/README.md)
retain complete attempts, count samples, original/independent references,
source identities, diagnostic failures and resource guards. Individual notices,
pins, input origins, variants and every adaptation are documented. M3 and M5
remain in progress.

Full DEBUGINFOD_URLS= make JOBS=4 check exits 0 with 970 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 identical bytecode comparisons across seven builds. runedoc
and runeopt also agree. [The complete transcript](validation/oct17-minimax-manybody-970-acceptance.log)
records the run.

## M3 probable-prime and M5 stdlib primitive wave — 2026-10-17

Ten programs bring the catalogue to 336 programs and 1000 profiles. All 280
canonical smoke/normal cases pass: [56 primetest cases](results/m3-primetest/coverage.tsv)
and [224 stdlib cases](results/m5-stdlib-primitives/coverage.tsv), on Rune's four
engines at O0/O2 and six native hosts at compiler defaults. All 2720 semantic
assertions pass: 95 primetest and 41 stdlib assertions in each of twenty
invocations. Forty normal count samples agree under execution-model rules,
including allocation across all Rune engines. Existing budgets remain unchanged.
Thirty serial single fresh-process native smoke samples validate adapters
separately from instrumentation and headline comparisons.

Primetest retains 100 trials, source modular-power control flow, factorization,
base-65536 digit mapping, seeds 111/47, short circuiting and source partiality.
Infinite streams remain memoized; finite values are separately lazy/strict.
All original GHC fixtures agree. A separate Python integer/generator model
agrees on 380 original/small outcomes and small/FAST successor-state snapshots.
Eight exact power cases include two nontrivial 607-bit moduli. New profiles
have their own original/independent references; selecting candidates changes
which fixed witnesses they receive, without changing seeds or trial count.

Initial 607-bit single-candidate stack pilots time out at 600 seconds in both
policies. Smoke selects the second FAST candidate; normal selects candidates
2–4 at 74/112/63 bits. Both complete original five-candidate FAST large profiles
pass on Rune native code at O2, under the declared large limits and a 2-GiB
RSS guard. Other large configurations are unrecorded. The initial six adapter
builds exposed a missing shared-input manifest dependency; raw compile failures
are retained, the dependency is fixed before canonical/count runs, and all
final adapters pass. No incorrect timing is accepted.

The stdlib imports preserve three array selectors and five portable comparison/
immediate-integer equality selectors. Constant lists remain shared across loop
iterations and in-process calls. Typed library replacements, generator allocation,
counter/checkword consumption and final checks are documented. Original OCaml
observations agree with independent closed-form results for all profiles.
Tests also cover empty/singleton inputs, assertion failure, short circuiting,
comparison pivots, source shape errors and modular wrap.

The [71-case selector inventory](stdlib-cases.tsv) records ten implemented cases,
five concrete runtime deferrals and 56 planned cases, including two source
operations omitted from dispatch. Both typed C-layout Bigarray modes are
deferred; three immutable-value physical-identity cases have explicit missing
facilities and reconsideration conditions. Portable result-only opaque wrappers
are retained through consumption without a blanket exclusion.

All 68 inventory regressions pass; all five clean pinned trees reproduce 861
entries. Only primetest's declared-author evidence and Bigarray's disposition/
reason change. Individual notices, original run parameters, data origins,
translation decisions and scoped [primality evidence](results/m3-primetest/README.md)
and [stdlib evidence](results/m5-stdlib-primitives/README.md) accompany every
import. M3 and M5 remain in progress.

Full DEBUGINFOD_URLS= make JOBS=4 check exits 0 with 1000 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 identical bytecode comparisons across seven builds. runedoc
and runeopt also agree. [The complete transcript](validation/oct17-stdlib-primetest-1000-acceptance.log)
records the run.

## M4 particle-in-cell application wave — 2026-10-17

Two programs bring the catalogue to 338 programs and 1006 profiles. All [56
primary smoke/normal cases](results/m4-pic/coverage.tsv) pass on Rune's four
engines at O0/O2 and six native hosts at compiler defaults. Eight normal count
samples agree under execution-model rules, including allocation across all Rune
engines. Existing budgets remain unchanged. Six serial single fresh-process
native smoke samples validate adapters separately from instrumentation and
headline reports. The original normal 500/80 workload is retained and both
final-source Rune O2 calibration runs pass their guards.

Fourteen auxiliary invocations pass all 202 assertions. Each of six SML/NJ
invocations passes 115, fails 66 direct full-state checks and then terminates,
leaving 21 assertions unreached. Totals are 3518 passing assertions, 396 failed
assertions and 126 unreached. [The host note](validation/pic-host-results.md)
records the failures and a self-contained two-real constructor reduction. It
requires no arithmetic or collector stress: the internal accessor works while
external constructor matching reads garbage on all three managed SML/NJ hosts.
First-order abstract-type, mixed-field and array controls pass. Rune, MLton,
Poly/ML and ML Kit pass the reduced case. No test/kernel rewrite hides the
failure, no host fix is included and no issue is posted.

The application retains the source's active constant interpolation, reversed
potential arguments, swapped statistics, top-edge stencil and one-wrap rules.
Whole mesh/payload delays and separate position/velocity lists retain primary
timestep-only demand. Strict finite construction retains recursion guards.
The original GHC FAST/NORM/SLOW runs pass. Eleven state prefixes at six particle
counts agree exactly with an independent model using the active constant
interpolation closed form. Extra full-state observations remain auxiliary;
primary validation does not force terminal particle lists.

Every final timestep uses absolute bound 1e-12 plus relative 1e-10. Full-state
checks use absolute/relative 1e-10. GEN17 roundtrip, source-width Word64 hash
consumption and stable checked-run output are documented adaptations. Large
retains original 1000/300 parameters; whole large SML validation is unrecorded.
[Raw evidence](results/m4-pic/README.md) retains source/model notices, reference
runs, canonical attempts, samples, partial failures, reduced programs and guards.

All 70 inventory regressions pass and five clean pinned trees reproduce 861
primary entries. One row gains Patricia Fasel's declared heading/evidence only.
The [supplementary historical inventory](source-variants.tsv) records three
deferred Id implementations and two excluded non-program call graphs, with
individual hashes, author/notice review and missing-facility conditions.
M4 remains in progress.

Full DEBUGINFOD_URLS= make JOBS=4 check exits 0 with 1006 catalogue profiles,
the 16-program routine set, 331 language fixtures per compiler, existing budgets,
bootstrap and 498 identical bytecode comparisons across seven builds. runedoc
and runeopt also agree. [The complete transcript](validation/oct17-pic-1006-acceptance.log)
records the run.

## October 17: hidden-line application variants

Two programs bring the catalogue to 340 programs and 1012 profiles.
The [complete primary ledger](results/m4-hidden/coverage.tsv) records 48 passes
and eight SML/NJ failures across all 56 smoke/normal cases. Every Rune engine
passes at O0/O2. MLton, Poly/ML and ML Kit pass at defaults; the lazy variant
also passes both profiles on 32-bit legacy SML/NJ and 2026.2.

The [20-invocation auxiliary ledger](results/m4-hidden/semantic-summary.tsv)
records 1724 passing assertions, two failed assertions and 434 unreached checks.
Fourteen invocations pass all 108 checks. Each 32-bit/development SML/NJ
invocation passes 53 before strict rendering fails. Each 64-bit legacy
invocation fails its first full-edge assertion and terminates during rendering.
[The host note](validation/hidden-host-results.md) distinguishes the reduced
constructor-field defect from the legacy nursery-sensitive failure.
Canonical defaults and source checks retain both failures.

Eight full normal count samples agree under the engine comparison rules.
Four serial single fresh-process native smoke samples pass; two legacy
prechecks reject output and cannot contribute timing samples. Existing budgets
and the default ten-sample policy remain unchanged.

All three unchanged GHC source runs match their full stored prompts and empty
stdout. Complete geometry and PostScript observers, the independent binary32
model and exact command/coordinate references are archived. Both SML policies
match every one-iteration edge and vertex word across all three scenes.
Primary rendering validates every x/y word and path command without adding
unused z demand. Numerical comparison quirks, per-bottom memo construction,
finite eager payloads and lazy control are preserved. Large full-iteration SML
runs remain unrecorded.

All 72 inventory regressions and the clean five-pin 861-entry replay pass.
The hidden entry gains reviewed MAIL authorship/permission evidence; the
historical pseudo-terminal wrapper has an explicit supplementary exclusion.
[The evidence archive](results/m4-hidden/README.md) includes initial errors,
complete failures, guards, reduced probes, counts and source identities.

Full DEBUGINFOD_URLS= make JOBS=4 check exits 0 with 1012 catalogue profiles.
[The full transcript](validation/oct17-hidden-1012-acceptance.log) records the
acceptance run. M4 remains in progress.

## October 17: Mini Prolog inference engines

Four programs bring the catalogue to 344 programs and 1024 profiles.
All [112 primary cases](results/m4-prolog/coverage.tsv) pass on Rune's four
engines at O0/O2 and six native hosts at defaults. Every one of twenty
[auxiliary invocations](results/m4-prolog/semantic-summary.tsv) passes all
111 assertions, totaling 2220.

Sixteen normal count samples agree under Rune's engine comparison rules.
All twelve serial single fresh-process native smoke samples pass correctness
prechecks. These are adapter diagnostics; the default ten-sample methodology
and existing budgets remain unchanged.

The active explicit-stack engine matches all original GHC stdout fixtures.
StackEngine.hs is an exact duplicate of active Engine.hs. PureEngine.hs builds
memoized proof trees and lacks cut, so its references come from its own Haskell
loop. Both SML payload policies match every character of all three transcripts
for both engines. Additional cases cover parser ambiguity, occurs checks,
function-valued substitutions, source cut behavior, backspaces, aliases and
early quit. Higher-order difference-list printing and lazy search control
remain in both variants.

The final four-variant normal calibration validates all original 200 repetitions
on Rune O2. Every large transcript validates for one complete interpretation;
whole 200-iteration large SML runs remain unrecorded. Stable hexadecimal reports,
explicit Word64 hashing and required fixture files are documented adaptations.
Raw fixture trailing prompt spaces and backspaces are preserved.

All 74 inventory regressions and the clean five-pin 861-entry replay pass.
One row gains Mark P. Jones's reviewed author headings. The supplementary
inventory records the exact stack-module duplicate and distinct proof-tree
engine. [The complete evidence](results/m4-prolog/README.md) includes original
runs, observers, initial corrected errors, guards, samples and source identities.

Full DEBUGINFOD_URLS= make JOBS=4 check exits 0 with 1024 catalogue profiles.
[The full transcript](validation/oct17-prolog-1024-acceptance.log) records the
acceptance run. M4 remains in progress.

## October 17: photon transport and command parser generation

Four programs bring the catalogue to 348 programs and 1036 profiles.
GAMTEB records [50 passes and six SML/NJ failures](results/m4-gamteb/coverage.tsv)
across 56 primary cases; every Rune configuration passes at O0/O2.
The parser generator records [56 primary passes](results/m4-mkhprog/coverage.tsv)
across all configurations. All sixteen normal count samples agree under Rune's
engine comparison rules. Twelve serial single fresh-process native smoke
samples pass; these remain adapter diagnostics separate from headline timings.

GAMTEB's separate raw-kernel and full-checker targets total 8613 passing
assertions, 115 failures and twelve unreached checks. The [complete ledger](results/m4-gamteb/semantic-summary.tsv)
retains every invocation. Legacy 64-bit raw-stream mismatches respond to nursery
size; legacy 32-bit decimal scanning fails the exact formatter roundtrip.
Generic real tuples inside references reproduce a representation problem on all
SML/NJ hosts. Ordinary arithmetic diagnostics and MLton negative-zero formatting
failures remain separate from selected primary profile results.
[The host note](validation/gamteb-host-results.md) records the scope and controls;
no host fix or benchmark workaround is included.

Original GHC GAMTEB fixtures pass. Export-only observers and an independent eager
event queue agree on every raw result/statistic at seven particle counts;
separate ordered accumulations agree exactly. Both final-source Rune numeric
policies validate all 200 repetitions of normal and large. The source's lazy
cached prefix, control sharing, order and historical numerical quirks remain.
Derived modules/model retain the complete required Regents 1990 notice.

The command parser generator passes [2240 auxiliary assertions](results/m4-mkhprog/semantic-summary.tsv).
Both policies match nine full outputs, block hashes and channels, plus seven
original invalid-input usage cases. Literal type comparisons preserve lazy
prefix demand, and the original CPS/per-block consumer is retained. Source
allocation diagnostics confirm repeated work; the port does not cache a whole
generation across repetitions. Both policies validate all 3800 normal runs;
whole 18000-iteration large SML validation remains unrecorded. Crown Copyright
1992, N. D. North's source/manpage and historical syntax are preserved.

All 78 inventory regressions and the clean five-pin 861-entry replay pass.
Two primary rows gain reviewed author headings. Nine historical GAMTEB program
or support entries receive individual supplementary dispositions, source hashes,
notice review and reasons. [GAMTEB evidence](results/m4-gamteb/README.md) and
[generator evidence](results/m4-mkhprog/README.md) retain complete attempts,
samples, guards, references and initial-versus-final checks.

Full DEBUGINFOD_URLS= make JOBS=4 check exits 0 with 1036 catalogue profiles.
[The full transcript](validation/oct17-gamteb-mkhprog-1036-acceptance.log) records
acceptance. M4 remains in progress.

## GRIP graph utilities, 2026-10-17

Six imports bring the catalogue to 354 programs and 1054 profiles.
[Primary coverage](results/m4-gg/coverage.tsv) records 144 passes and 24 failing
64-bit SML/NJ checker cases across 168 attempts. All Rune configurations pass.
The [semantic ledger](results/m4-gg/semantic-summary.tsv) records 1976 passing
assertions, 164 failures and no unreached checks. The
[host-result note](validation/gg-host-results.md) and reduced source/control
transcripts preserve the observed discrepancy without asserting its cause.

Twenty-four normal count samples agree across the four Rune engines.
Twelve serial fresh-process native adapter samples pass; six failed SML/NJ
prechecks supply no accepted timings. GHC fixture agreement, thirty complete
PostScript comparisons, supplementary trace checks and final normal-profile
calibration are retained with [raw evidence](results/m4-gg/README.md).
Large repetition profiles remain unrecorded.

All 80 inventory tests and the five-pin 861-entry replay pass. Individual source
and data notices, the author's manual heading, graph-mode variants and report
script exclusions are recorded. Full DEBUGINFOD_URLS= make JOBS=4 check exits
zero with 1054 profiles, 498-program cross-build agreement and matching runedoc
and runeopt builds. [The complete transcript](validation/oct17-gg-1054-acceptance.log)
records the acceptance check. M4 remains in progress.

## Fourier, interpreter and paragraph workloads, 2026-10-17

Eight imports bring the catalogue to 362 programs and 1078 profiles.
[FFT2 primary coverage](results/m3-fft2/coverage.tsv) records 54 passes and two
legacy 64-bit SML/NJ normal-profile failures. All Rune cases pass. Its
[semantic ledger](results/m3-fft2/semantic-summary.tsv) records 2236 passing
assertions, two failed assertions and 402 unreached checks from incomplete
SML/NJ invocations. The [host note](validation/fft2-host-results.md) separates
the observed contexts without assigning a compiler cause.

All [112 lambda primary cases](results/m3-lambda/coverage.tsv) and 4820 semantic
assertions pass. Separate direct/state-monadic names retain each source count,
call-by-name closures and caller environment restoration. All
[56 paragraph primary cases](results/m3-para/coverage.tsv) and 2240 semantic
assertions pass. Source queue representation, pruning and text consumers remain.

Thirty-two complete normal count samples agree under Rune's engine rules.
Twenty-four serial single fresh-process native smoke adapter samples pass,
separately from count instrumentation. Default sampling policy and existing
budgets remain unchanged. All full normal Rune calibrations pass; full large
SML repetition runs remain unrecorded.

Original GHC fixtures and independent references cover mixed-factor transforms,
non-power-of-two source FFT errors, interpreted terms/environments and paragraph
layout. The independent formatter finds optimum costs for 3573 of 3574 source
paragraphs. Source linear par3 gives cost 5 for paragraph 483; both independent
dynamic programming and original quadratic par1 give cost 1. Retain par3's
exact layout and counterexample. [FFT2](results/m3-fft2/README.md),
[lambda](results/m3-lambda/README.md) and [para](results/m3-para/README.md)
retain full raw evidence and program-specific limits.

All 88 inventory regressions pass; clean five-pin replay retains 861 primary
entries. Three source author headings, the individual historical text notice,
foreign implementation/fragment dispositions and the excluded pinned i386
executable are recorded. Full original text/notices remain unchanged.
The bounded smoke input uses complete novel-body paragraphs with exact byte
origins. No executable artifacts are imported.

Full DEBUGINFOD_URLS= make JOBS=4 check exits zero with 1078 catalogue profiles,
498-program bytecode agreement and matching runedoc/runeopt builds.
[The complete transcript](validation/oct17-fft2-lambda-para-1078-acceptance.log)
records acceptance of this combined wave. M3 remains in progress.

## Sphere tracing and sequential numerical/symbolic workloads, 2026-10-17

Five imports bring the catalogue to 367 programs and 1093 profiles.
[Sphere coverage](results/m3-sphere/coverage.tsv) records 55 of 56 primary cases
passing. Only lazy normal on legacy 64-bit SML/NJ fails pixel validation.
All Rune cases pass, and all 1380 semantic assertions pass. A diagnostic
reproduces a substantial wrong color at (33,74), while the separate pixel passes
a smaller control on legacy SML/NJ. Development SML/NJ does not load that smaller
context. [The host note](validation/sphere-host-results.md) preserves all findings
without asserting a compiler cause or changing the canonical source.

[ALMABENCH coverage](results/m5-almabench/coverage.tsv) records all 28 primary
cases passing. Its semantic target records 3254 passes and six auxiliary
exact-remainder failures with no unreached checks. All original and independent
state vectors pass. [The host note](validation/almabench-host-results.md)
separates known SML/NJ Real.rem inexactness from corrected private harness errors.
Pinned ERFA Plan94 agrees exactly on all 384 sampled state coordinates.
Full source normal profiles and 27-moment numerical checks are validated.

[Knuth–Bendix coverage](results/m5-kb/coverage.tsv) records all 56 primary cases
and all 25700 semantic assertions passing. Both original programs give the same
complete 24-rule system. Checks cover all 576 ordered final critical-pair
combinations under each variant, rule orientation and normalization, input
equations, term operations and wrong-result rejection. Distinct exception/option
matching and source printer traversal remain. QPL notices, unchanged originals
and pinned canonical license text are preserved.

Twenty full normal Rune count samples agree under the execution-model rules.
Fifteen serial single fresh-process native smoke adapter samples pass, separately
from instrumentation. Default sampling and count-budget policies remain.
Every full normal Rune calibration passes; full large SML repetition runs remain
unrecorded. [Sphere](results/m3-sphere/README.md),
[ALMABENCH](results/m5-almabench/README.md) and [KB](results/m5-kb/README.md)
retain complete raw evidence, source identities and notices.

All 90 inventory tests pass, and five clean pins reproduce 861 primary entries.
The reviewed sphere attribution is recorded. There remain 21 M3, thirteen M4 and
thirteen M5 scheduled primary source entries, plus planned standard-library cases;
these are unfinished work, not passing ports.

Full DEBUGINFOD_URLS= make JOBS=4 check exits zero with 1093 profiles, 498-program
bytecode agreement and matching runedoc/runeopt builds.
[The complete transcript](validation/oct17-sphere-almabench-kb-1093-acceptance.log)
records acceptance. M3, M4 and M5 remain in progress; M8 remains planned.

## Sequential Graph500 generation and construction, 2026-10-17

Three imports bring the catalogue to 370 programs and 1102 profiles.
[Primary coverage](results/m5-graph500/coverage.tsv) records 70 passes and
fourteen failures across 84 cases. Every Rune, MLton and ML Kit primary case
passes. The [semantic ledger](results/m5-graph500/semantic-summary.tsv) records
5606 passing assertions, twelve failures and 622 unreached checks.

Original binary generation and prototype CSV outputs match selected normal and
large portable Rune pilots byte-for-byte. Original adjacency observations agree
with an independent decoder and append/reverse model. The 312-check target
covers original edge weights, binary/CSV fixtures, malformed data, sorting
stability, forced key ties, duplicate edges and source graph extents.

Twelve normal count samples agree. Seven serial single fresh-process native
adapter samples pass; two rejected prechecks supply no accepted timing.
The [host note](validation/graph500-host-results.md) distinguishes source power
rounding sensitivity, large integral conversion differences, word construction
and unresolved legacy compilation-context findings. Raw measurement statuses
remain; a reviewed table classifies the quoted incorrect-result message that
the old classifier labelled runtime failure. A tooling regression follows.

Data origins, fixed random state, three executable aliases, distinct algorithms,
individual stdlib notices and binary fixture identities are recorded with
[complete evidence](results/m5-graph500/README.md). Larger published parameters
remain explicitly separate candidates. All 90 inventory tests pass.

Full DEBUGINFOD_URLS= make JOBS=4 check exits zero with 1102 profiles and all
compiler/runedoc/runeopt cross-build comparisons.
[The complete transcript](validation/oct17-graph500-1102-acceptance.log)
records acceptance. M3, M4 and M5 remain in progress; M8 remains planned.

## Quoted correctness-exception classification, 2026-10-17

[The regression record](validation/quoted-fail-results.md) covers Poly/ML's quoted
Fail message, bare and colon-prefixed incorrect results, and an unrelated quoted
runtime failure. [Targeted measurement checks](validation/oct17-quoted-fail-targeted.log)
pass, including four-compiler statistics, numerical/runtime distinction,
instrumentation rejection and worker isolation.

[Full make JOBS=4 check](validation/oct17-quoted-fail-1114-acceptance.log) exits
zero with 1114 catalogue profiles, including registered pending linear imports,
and all compiler/runedoc/runeopt cross-build comparisons. Those imports' broader
correctness/count evidence is recorded separately. No failed precheck supplies
timing results; historical raw statuses remain unchanged.

## Sparse block linear solvers, 2026-10-17

Four imports bring the catalogue to 374 programs and 1114 profiles.
[Primary coverage](results/m3-m4-linear/coverage.tsv) records 104 passes and
eight legacy 64-bit SML/NJ failures in 112 attempts. All Rune and other native
cases pass. The [semantic ledger](results/m3-m4-linear/semantic-summary.tsv)
records 1341 passing assertions, 39 failures and no unreached checks.
[Host findings](validation/linear-host-results.md) retain context-sensitive
legacy differences without introducing compiler/nursery/tolerance workarounds.

All sixteen normal count samples agree. Serial native smoke diagnostics retain
accepted samples and rejected prechecks separately from instrumentation.
Original GHC fixtures and export-only metric/block observers agree with every
final normal Rune configuration. Exact binary32 values, higher-order callbacks,
recursive sharing, both source iteration caps and distinct text/hash consumers
remain. Full SML large repetition checks remain unrecorded.

All 94 inventory tests and five-pin 861-entry replay pass. Six contributor roles
and two concrete reservoir-data blockers are recorded; default generated-data
workloads are runnable. [Complete source/validation evidence](results/m3-m4-linear/README.md)
distinguishes private development attempts from final source identities.

[Full make JOBS=4 check](validation/oct17-quoted-fail-1114-acceptance.log) exits
zero with 1114 profiles and all compiler/runedoc/runeopt cross-build comparisons.
That run also validates the separately committed quoted-Fail classification fix.
M3, M4 and M5 remain in progress; M8 remains planned.

## Binary space partitioning modeller, 2026-10-17

Two ports bring the catalogue to 376 programs and 1120 profiles.
[Primary coverage](results/m4-bspt/coverage.tsv) records 55 passes in 56 cases:
all Rune cases pass, while ML Kit lazy smoke compilation reaches its unchanged
30-second limit. An isolated clean compiler probe confirms timeout status 124;
its normal-profile case passes. The original empty harness diagnostic remains.

All 1780 semantic assertions pass across twenty invocations. Eight normal count
samples agree, and six serial native smoke adapter samples pass separately.
Original full batch text, eleven interactive commands, signed-64 rational
operations and the GHC updatable batch thunk support exact correctness and
demand/sharing checks. Character comparison adds validation work to the original
hash consumer; globally shared geometry is computed once per fresh program.
[Complete evidence](results/m4-bspt/README.md) retains the profile limit,
consumer adaptations, source identities and unrecorded SML large checks.

[Full make JOBS=4 check](validation/oct17-bspt-1120-acceptance.log) exits zero
with 1120 profiles and all compiler/runedoc/runeopt cross-build comparisons.
M3, M4 and M5 remain in progress; M8 remains planned.

## Knight tours and mating search, 2026-10-17

Six ports bring the catalogue to 382 programs and 1138 profiles.
[Knights coverage](results/m3-knights/coverage.tsv) records 112/112 passing
primary cases; [mate coverage](results/m3-mate/coverage.tsv) records 56/56.
All Rune O0/O2 engines and all six managed native hosts pass. The semantic
ledgers record 1720 passing knight-tour assertions and 960 mating-search
assertions, with no failed or unreached checks.

All 24 normal count samples agree, and 18 serial single fresh-process native
smoke adapter samples pass separately. Complete original tour/solution text,
independent closed-tour legality, legal-move fixtures and demand/persistence
controls validate both evaluation styles. The inactive array board remains a
separate representation with its reviewed formatter repair and original bounded
failure; exact output validation adds work to the original length consumer.

All 96 inventory regressions and the five-pin 861-entry replay pass, recording
Jonathan Hill's attribution and the twenty-seventh supplementary variant.
[Knights evidence](results/m3-knights/README.md) and
[mate evidence](results/m3-mate/README.md) retain original notices, input origins,
source identities, complete attempts, development failures and unrecorded final
large-profile runs.

[Full make JOBS=4 check](validation/oct17-chess-1138-acceptance.log) exits zero
with 1138 profiles and all compiler/runedoc/runeopt cross-build comparisons.
M3, M4 and M5 remain in progress; M8 remains planned.

## Expert feedback, regex-redux and stream multiplier, 2026-10-17

Seven ports bring the catalogue to 389 programs and 1159 profiles.
[Expert coverage](results/m3-expert/coverage.tsv) records 56/56 passes,
[regex-redux coverage](results/m5-regexredux2/coverage.tsv) 28/28 and
[multiplier coverage](results/m3-multiplier/coverage.tsv) 112/112. All Rune O0/O2
engines and six managed native SML hosts pass. The semantic ledgers record
900 expert, 460 regex and 1120 multiplier passing assertions, none failed or
unreached. All 28 normal count samples agree; 21 serial single fresh-process
native smoke adapter samples pass separately from instrumentation.

Original dialogs, regex-library observations, complete reports/traces and an
independent multiplier clock model support correctness. Explicit demand tests
cover question/answer feedback, unused replies, phrase policies, gate strictness,
word arguments/tails and the count consumer's undemanded product stream. Fixed
profile reductions, consumer validation costs, portable regex library replacement,
source arithmetic widths and unrecorded final large runs are documented.

All 102 inventory regressions and five-pin 861-entry replay pass. Holyer,
O'Donnell and Kashitsyn credits are recorded, with the twenty-eighth supplementary
variant preserving multiplier's count-only consumer. Complete
[expert](results/m3-expert/README.md), [regex-redux](results/m5-regexredux2/README.md)
and [multiplier](results/m3-multiplier/README.md) evidence retains notices,
input/source identities, raw samples and development failures separately.

[Full make JOBS=4 check](validation/oct17-expert-regex-multiplier-1159-acceptance.log)
exits zero with 1159 profiles and all compiler/runedoc/runeopt cross-build
comparisons. M3/M4/M5 remain in progress; M8 remains planned.

## Hartel event simulation and functional type inference, 2026-10-17

Four ports bring the catalogue to 393 programs and 1171 profiles.
[Event coverage](results/m3-hartel-event/coverage.tsv) and
[typechecker coverage](results/m3-hartel-typecheck/coverage.tsv) each record
56/56 passing primary cases. All Rune O0/O2 engines and six managed native SML
hosts pass. The semantic ledgers record 1440 event and 560 type-inference
assertions, none failed or unreached. All sixteen normal count samples agree;
twelve serial single fresh-process native smoke adapter samples pass separately.

Original fixtures, complete changed-event traces, an independent event model,
exact inferred rows and substitution/generalization observations support
correctness. Demand controls cover exclusive cutoffs, persistent states, lazy
finite fields, functional substitutions and unused failure paths. Strong per-row
checking rejects an incorrect type with the same original checksum. Source clock/
AST sharing, no-op compatibility annotations, profile reductions and additional
validation work are explicit. Full final SML large repetition checks remain
unrecorded.

[Event evidence](results/m3-hartel-event/README.md) and
[typechecker evidence](results/m3-hartel-typecheck/README.md) retain the original
modules/shim, expected data, source identities, raw results and development scopes.
[Full make JOBS=4 check](validation/oct17-hartel-event-typecheck-1171-acceptance.log)
exits zero with 1171 profiles and all compiler/runedoc/runeopt cross-build
comparisons. M3/M4/M5 remain in progress; M8 remains planned.

The event fixtures use the suffix .state for fourteen-byte ASCII data.
[Exact fixture identities](validation/hartel-event-state-identities.tsv) record
all thirty copies, each verified against the independent event model and original
observations. This distinguishes them from compiler state/cache files: the
payload audit accepts only those exact paths, lengths, hashes and state alphabet;
binary signatures and NUL data remain rejected. The first broad suffix scan
flagged these text files, and that result was resolved after the initial local
commit. Benchmark source, inputs and recorded validation results are unchanged.

## Corrected dominators, 2026-10-18

The catalogue now has 394 programs and 1174 profiles.
[Coverage](results/m3-dom-lt/coverage.tsv) records 26/28 primary passes;
[semantic results](results/m3-dom-lt/semantic-summary.tsv) record 2220 passing
and 160 failing assertions, with none unreached. All failures are native
32-bit SML/NJ, independently reproduced by a Word64 zero-shift probe; valid
arithmetic remains unchanged and that configuration contributes no timing sample.

[The source issue](validation/dom-lt-source-issue.md) separately proves and repairs
an upstream dominator algorithm defect hidden by its length-only checksum.
Corrected original and an independent model agree on all 86 graphs. Every
measured repetition checks full ordered parents. Four normal count samples
agree; three serial single fresh-process native smoke adapter samples pass.
[Evidence](results/m3-dom-lt/README.md) retains rejected measurements and raw
original/corrected observations.
[Full make JOBS=4 check](validation/oct18-dom-lt-1174-acceptance.log) exits zero
with 1174 profiles and all cross-build comparisons. M3/M4/M5 remain in progress
and M8 remains planned; final SML large repetitions are unrecorded.

## Free-group completion and rewriting, 2026-10-18

The catalogue now contains 396 programs and 1180 profiles.
[Final wrapper coverage](results/m3-rewrite/coverage.tsv) records 54/56
passing smoke/normal cases. All Rune O0/O2 engines and five native SML hosts
pass. Both normal ML Kit attempts report allocation failure at the 4 GiB
limit; their raw failures remain in the ledger.

[Semantic results](results/m3-rewrite/semantic-summary.tsv) record all 6880
assertions passing across twenty invocations of the 344-check target, with
none failed or unreached. The original ten-rule theory, full normal forms and
an independent free-group cancellation model agree. Demand controls include
the shared completion, unused agenda costs and short-circuiting; each repeated
driver result is fully checked.

[The repository acceptance run](validation/oct18-rewrite-1180-acceptance.log)
exits zero with 1180 profiles and all compiler/runedoc/runeopt cross-build
comparisons. Its bounded routine set is separate from the new ports' explicit
final profile and semantic runs; those runs include the final agenda-cost fix.
[The evidence report](results/m3-rewrite/README.md) distinguishes final records
from provisional names, the initial fixture-path mistake and earlier cost
handling. Final SML large repetitions remain unrecorded. M3/M4/M5 remain in
progress; M8 remains planned.

Eight final normal count samples agree, with both guard processes exiting zero.
Six serial single fresh-process native smoke adapter samples pass after the
heavy jobs completed. Their complete records are retained as diagnostics.
Earlier names, fixture-path failures, eager-cost behavior and host-reserve guard
interruptions are separate development evidence and do not supply final results.

## Hartel IDA and Sandmark ordered trees, 2026-10-18

The catalogue now contains 409 programs and 1214 profiles.
[IDA coverage](results/m3-ida/coverage.tsv) records 56/56 primary passes;
[map/set coverage](results/m5-stdlib-trees/coverage.tsv) records 308/308.
All Rune O0/O2 engines and six managed native hosts pass smoke and normal.
The semantic ledgers record 2160 IDA and 7280 tree assertions passing, with
none failed or unreached. Native O0/O2 group labels repeat host-default builds.

All 52 normal Rune count samples agree, with thirteen guard processes exiting
zero and no guard interruptions. Thirty-nine serial single fresh-process native
smoke samples pass as adapter diagnostics, separately from heavy checks. These
are not ten-sample comparative performance claims.

Original configurations, ordered paths and independent breadth-first optimal
lengths support IDA correctness. Original AVL shapes, independent ordered
contents and source selector observations support the tree ports. Demand
checks preserve shared IDA partitions and cutoffs; a deliberately corrupted
map with an unchanged digest is rejected by the full-content checker.
Source profile reductions, mutable/immutable construction scopes, library
replacement costs and source quirks remain explicit.

[Full make JOBS=4 check](validation/oct18-ida-stdlib-trees-1214-acceptance.log)
exits zero with 1214 profiles and all compiler/runedoc/runeopt cross-build
comparisons. An earlier run was interrupted and has no final result; its log
is retained separately. All 108 inventory regressions and the five-pin
861-entry replay pass.

[IDA evidence](results/m3-ida/README.md) and
[map/set evidence](results/m5-stdlib-trees/README.md) retain source identities,
notices, raw outputs and development scopes. Final SML large repetitions
remain unrecorded. M3/M4/M5 remain in progress and M8 remains planned.

## Remaining Sandmark stdlib selectors, 2026-10-18

The catalogue contains 454 programs and 1316 profiles. All 45 newly imported
selectors pass their 1260 primary smoke/normal cases on Rune O0/O2 across
four engines and six managed native SML hosts. The semantic targets record
5140 passing assertions across twenty invocations per group, none failed or
unreached. Native O0/O2 group labels repeat host-default builds. Public shell
targets also pass Rune O0/O2, confirming source and data ordering.

All 180 full-normal Rune count samples agree, with 45 guard processes exiting
zero and no interruptions. All 135 serial single fresh-process native smoke
adapter samples pass before heavy validation. These remain diagnostics rather
than ten-sample comparative performance claims.

[Text/byte evidence](results/m5-stdlib-text/README.md),
[Str evidence](results/m5-stdlib-str/README.md) and
[hashtable evidence](results/m5-stdlib-hashtbl/README.md) retain complete original
observations, independent models, notices, source identities and raw records.
The imported kernel bytes match the final semantic subjects. Original source
quirks, explicit library/representation replacements and profile reductions
remain documented. Count child-output and guard-summary log filenames were
normalized without rerunning or changing the underlying samples.

[Full make JOBS=4 check](validation/oct18-stdlib-1316-acceptance.log) exits zero
with 1316 profiles and all compiler/runedoc/runeopt cross-build comparisons.
All 108 inventory regressions and the five-pin 861-entry replay pass.
The complete 71-case stdlib inventory has no suitable planned selector.
M5 still has three pending applications; M3 and M4 remain in progress,
M8 remains planned, and full final SML large repetitions remain unrecorded.

## M5 closure: sequential Sandmark applications, 2026-10-18

The catalogue contains 457 programs and 1325 profiles. Every suitable pinned
Sandmark executable and stdlib selector has a portable implementation.
Feature-dependent programs retain explicit inventory dispositions. M5 is
complete with the recorded configuration exceptions below; M3/M4 remain
in progress and M8 remains planned.

The final applications record 77 passing cases in 84 primary smoke/normal
attempts. All Rune O0/O2 stack/register/JIT/native cases pass. LexiFi G2++
records 24/28, contrast 27/28 and MiniLight 26/28. Failures are the known
native 32-bit SML/NJ random Overflow in G2++/MiniLight and default legacy
64-bit G2++ runtime/contrast normal-image errors. No expected result or
runtime default was changed to accept these failures.

The final semantic targets complete every assertion: 3584 pass, sixteen
fail, none unreached. G2++ has 1326/14, contrast 1960/0 and MiniLight 298/2.
The helper/smoke targets do not replace broader normal-profile checks.
Public source-order/data shell targets pass Rune O0/O2.

All twelve full-normal Rune count samples agree and all three guard processes
exit zero without interruption. Eight serial single fresh-process native
smoke diagnostics pass before the heavy checks. Legacy G2++ correctness fails
before its timing phase, contributing zero accepted samples. These are
adapter diagnostics, not ten-sample comparative performance claims.

[LexiFi evidence](results/m5-lexifi-g2pp/README.md),
[contrast evidence](results/m5-contrast/README.md) and
[MiniLight evidence](results/m5-minilight/README.md) retain raw failures,
full numerical/image/random-state references, independent component models,
notices, source/input identities and separate development scopes. Original
observer outputs agree with unmodified executables. Perturbation controls reject
incorrect numerical values, geometry and pixels. Nursery diagnostics remain
separate configurations and do not establish a causal reduction.

[Full make JOBS=4 check](validation/oct18-sandmark-applications-1325-acceptance.log)
exits zero with 1325 profiles and all compiler/runedoc/runeopt cross-build
comparisons. All 114 inventory tests and the five-pin 861-entry replay pass.
Profile model CRLF geometry bytes are preserved under narrow data-only
attributes; runnable SML sources retain ordinary whitespace checks.
Full final SML large-profile runs remain unrecorded.

## Hartel scheduling, 2026-10-18

The catalogue contains 459 programs and 1331 profiles. Both sched policies
pass all 56 canonical smoke/normal cases on Rune O0/O2 across four engines and
all six managed native hosts. All twenty final semantic invocations pass
54 assertions: 1080 passing assertions, none failed or unreached. Native
O0/O2 groups use host-default compiler settings.

Original complete schedule-tree observations and an independent DAG/affinity/
event oracle agree. Lazy unused-field, paired-result sharing, no-op hint,
strict finite-field and driver rejection controls pass. Normal preserves
100-by-eleven; selected large uses one fourteen-labelled supplied graph for
tree/memory scaling, with original SLOW500-by-eleven retained separately.

All eight full-normal Rune count samples agree and both guards exit zero
without interruption. Six serial single fresh-process native smoke diagnostics
pass before heavy validation. They are not ten-sample comparative performance
claims. The public semantic shell target passes Rune O0/O2; all 114 inventory
tests and the five-pin 861-entry replay pass.

[Full make JOBS=4 check](validation/oct18-hartel-sched-1331-acceptance.log)
exits zero with 1331 profiles and all compiler/runedoc/runeopt cross-build
comparisons. [Evidence](results/m3-hartel-sched/README.md) retains raw outputs,
source identities, notices/attribution limits and separate source-order setup
diagnostics. Final full SML large repetitions remain unrecorded.
M3/M4 remain in progress and M8 remains planned.

## Hartel wave4main, 2026-10-18

The catalogue contains 461 programs and 1337 profiles. Both policies pass all
56 canonical smoke/normal cases on Rune O0/O2 across four engines and all six
managed native hosts. All twenty final semantic invocations complete thirty
assertions: 600 pass, none failed or unreached. Native O0/O2 labels repeat
host-default compiler settings.

Original full six-array states and an independent unsplit-grid oracle agree
on all 1872 observed values through 400 steps. Complete numeric checks,
source formatting, boundary demand, shared cells, strict materialization,
halo indices and perturbed/NaN result controls pass. Normal preserves
500-by-eighty; full selected large 500-by-400 remains unrecorded.

All eight full-normal Rune count samples agree; both guards exit zero without
interruption. Six serial single fresh-process native smoke diagnostics pass
before heavy validation. These are adapter diagnostics, not ten-sample
comparative performance claims. Public semantic shell targets, all 114
inventory tests and the five-pin 861-entry replay pass.

[Full make JOBS=4 check](validation/oct18-wave4main-1337-acceptance.log)
exits zero with 1337 profiles and all compiler/runedoc/runeopt cross-build
comparisons. [Evidence](results/m3-wave4main/README.md) retains raw outputs,
source identities, notices/attribution limits and separate source-order setup
failures. M3/M4 remain in progress and M8 remains planned.

## Fulsom solid modelling and Symalg exact arithmetic, 2026-10-18

The catalogue contains 467 programs and 1355 profiles. All 168 canonical
smoke/normal cases pass: 112 for four Fulsom consumer/data-policy variants
and 56 for two Symalg policies. These cover Rune O0/O2 stack, register,
JIT and native engines and all six managed native hosts. Fulsom's candidate
subject bytes match the registered public sources exactly.

Fulsom's twenty semantic invocations reach every assertion: 3420 pass,
260 fail and none are unreached. All complete raster/hash observations pass.
External strict interval-pattern and 32-bit Word64-literal failures remain
visible and match the existing reduced SML/NJ reports, as explained in the
[host note](validation/fulsom-host-results.md). No expected value, access
path or tolerance was changed to accept them.

Symalg's twenty semantic invocations pass all 6640 assertions. Original
command transcripts, 161 direct real-arithmetic observations, complete
numerical values, memoization/demand and deliberate result perturbations
are checked. Independent integer square roots agree with complete original
positive sqrt values through 40000 digits. Its source zero-times-nonzero
magnitude loop remains unrepaired and has separate bounded failure evidence.

Sixteen explicitly selected Fulsom smoke count samples and eight Symalg
selected-normal count samples agree; all six guards exit zero without
interruption. No new fresh-process timing samples are recorded for this wave.
Default-profile limits remain unchanged. Calibration timeouts/guards are
separate from successful selected profiles and unrecorded full large runs.

Both public semantic shell targets pass Rune O0/O2. All 118 inventory tests
and the five-pin 861-entry replay pass. Complete source notices, input origins,
ancillary-tool exclusions, original/independent references, source identities
and distinct development failures are retained in
[Fulsom evidence](results/m3-m4-fulsom/README.md) and
[Symalg evidence](results/m4-symalg/README.md).

[Full make JOBS=4 check](validation/oct18-fulsom-symalg-1355-acceptance.log)
exits zero with 1355 profiles and all compiler/runedoc/runeopt cross-build
comparisons. M3/M4 remain in progress and M8 remains planned.

## Cacheprof text annotation, 2026-10-18

The catalogue contains 471 programs and 1367 profiles. All four variants pass
all 112 canonical smoke/normal cases across Rune O0/O2 stack/register/JIT/native
engines and six managed SML hosts. The bounded semantic target completes
822 assertions in each of twenty invocations: 16440 pass, none failed or
unreached. Native O0/O2 labels repeat host-default compiler settings.

Complete original outputs, all 206 opcode/effect entries, 67 exact nonJumpy
members, 299 original accepted/rejected cases and prefix-demand controls
support the translation. The current short GC stdin and historical full
stdout fixture are reconciled: the unmodified original with cacheprof.full
reproduces all 1671273 golden bytes exactly. Input origins and that pairing
remain explicit.

An initial mixed target has one ML Kit memory-limit failure at 1 GiB:
8232 assertions pass over ten invocations, none fail, and eight remain
incomplete. That failed subject and outcome are retained. Four separate
large checks pass on ML Kit with the declared 8 GiB large-profile limit;
the protective process-tree guard exits zero without interruption.
Neither kernel nor expected output was changed to accept the failure.

All sixteen full-normal Rune count samples agree; all four guards exit zero
without interruption. Twelve serial single fresh-process native smoke
diagnostics, including correctness preflights, pass before heavy validation.
These are adapter diagnostics rather than ten-sample comparative claims.
Broader final large-profile runs remain unrecorded beyond the explicit probe.

The public bounded semantic shell target passes Rune O0/O2. All 124 inventory
regressions and the five-pin 861-entry replay pass. [Evidence](results/m3-m4-cacheprof/README.md)
retains individual notices, source/input identities, original references,
raw outcomes and distinct development/resource failures. Repeated archived
input copies are replaced by byte-verified canonical references and group
tables; per-run outputs, logs and commands remain intact.

[Full make JOBS=4 check](validation/oct18-cacheprof-1367-acceptance.log)
exits zero with 1367 profiles and all compiler/runedoc/runeopt cross-build
comparisons. M3/M4 remain in progress and M8 remains planned.

## Hartel connected-component labelling, 2026-10-18

The catalogue contains 475 programs and 1379 profiles. All four sifting/data
variants pass all 112 canonical smoke/normal cases on Rune O0/O2 across four
engines and six managed SML hosts. Original full component images, raw ranges
and persistent trees agree across 46 states; independent BFS/run/forest checks
cover all 129950 pixels. Original FAST/NORM/SLOW fixtures match.

The final semantic target records 2034 passing assertions, none failed and
226 incomplete across twenty invocations. Both Poly/ML groups fail compilation
of a valid auxiliary strict-tree test, as documented in the
[host note](validation/comp-lab-polyml.md). Its diagnostic 98-assertion prefix
and four normal application pilots pass; neither replaces the full failed
target. Earlier tuple-arity ambiguity and allocator-probe setup failures remain
separate development records.

All sixteen full-normal Rune count samples agree with guards exiting zero
without interruption. Twelve serial single fresh-process native smoke adapter
diagnostics pass; a bounded semantic check overlapped initial samples.
These are not ten-sample comparative performance claims. Full selected large
100-repetition runs remain unrecorded.

The public Rune O0/O2 semantic target, all 124 inventory regressions and the
five-pin 861-entry replay pass. [Evidence](results/m3-comp-lab/README.md)
retains raw outcomes, notices/attribution limits, independent references and
canonical input identity/group maps.

[Full make JOBS=4 check](validation/oct18-comp-lab-1379-acceptance.log)
exits zero with 1379 profiles and all compiler/runedoc/runeopt cross-build
comparisons. M3/M4 remain in progress and M8 remains planned.

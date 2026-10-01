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
bin/runevm tests/out/benchmarks/validation/catalog.rbc
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

The catalogue now contains 79 programs, including all 48 pinned MLton
workloads, eleven ML Kit workload entries and thirteen SML/NJ entries, alongside
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

Source compatibility review now accounts for 21 ML Kit region-reset
variants as deferred, five additional duplicate entrypoint/project forms,
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

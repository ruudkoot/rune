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

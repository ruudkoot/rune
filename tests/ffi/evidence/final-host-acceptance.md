# Final Runeffi host and Basis acceptance — 2026-10-23

The final Basis matrix passes its strict judge: **3,198 PASS, 168 SKIP,
0 FAIL**, from 3,366 selected runner jobs. This is not 3,366 successful
program executions. The final native library-host gate also passes its strict
judge: **217 PASS, 0 FAIL, 0 SKIP**. Known host defects and missing optional
APIs remain explicit failed default program outcomes, as detailed below.

The machine-readable [receipt](final-host-acceptance.json),
[168 skip records](final-host-skips.json), and
[591 production source blob manifest](final-host-sources.tsv) retain the
commands, source identities, durations, classifications, and artifact hashes.

## Final Basis matrix

Source `18c353b49`, independent acceptance worktree, outside the restricted
sandbox:

```
RUNE_MATRIX_OUT=tests/out/matrix-final-18c353b49 make matrix-quick JOBS=2
```

Run `tests/out/r/20261023-122519-3013462` finished with **3,198 PASS,
168 SKIP, 0 FAIL**, in **4,216.8 s wall / 8,161.9 s CPU**. Output was fresh;
the ordinary **120 s** load limit was unchanged and no retries were used.
The former MLKit timeout cases `mono.word`, `mono.word16`, `mono.word32`,
and `mono.int16` passed on their first attempts in 43.690, 45.995, 43.485,
and 42.548 seconds respectively.

The 168 skips comprise **102 intentional Rune-extension host absences**
(17 suites on each of the six native hosts, including **12 RuneForeign
suite/signature skips**) and **66 SML/NJ32 width or dependency limitations**.
No skip represents a missing installed compiler or an unrecorded native
runtime gate. The complete per-case reasons are in the linked skip records.
RuneForeign's owning-VM primitive bridge is a Rune extension; the six
native hosts do not acquire an implementation through these portable
Basis comparisons.

Poly/ML's `Unix` load still times out after 120 s because a forked child
calling the host's `Posix.Process.exit` never terminates and reap waits.
The existing `HOST-BUG` in `tests/basis/deviations.txt` explains this
failure. It is an expected-deviation judge pass, not a successful `Unix`
execution or a skipped check.

## Native library-host gate

The native-own-Basis inventory has **34 programs on six hosts**. It does
not inject replacement Word16 or Int64 providers. SML/NJ's missing Word16
and Poly/ML's missing Int64 remain explicit `HOST-ABSENT` outcomes for the
public Win32 common/value fixtures. These are explained failed builds,
not skipped executions or successful portability claims. Other existing
host defects and missing APIs retain their individual deviations.

The first full run on `18c353b49`,
`tests/out/r/20261023-133649-3186936`, failed: **208 PASS, 4 FAIL, 4 SKIP**
of 216 runner jobs, **1,520.2 s wall / 2,374.3 s CPU**. The four skipped
`@stale` jobs depended on unexpected failures; they were not accepted host
absences. Of its 204 default program oracles, 170 passed, 30 failures had
existing explanations, and four generator failures were unexpected.
This failed receipt is retained and has not been relabeled as a clean run.

All three SML/NJ configurations missed one duplicate normalized `IntInf`
selector, with precisely **31/32 assertions passing**. Their
[context-dependent equality defect](../../../docs/bugreport/smlnj/IntInf/normalized-selector-equality/BUGREPORT.md)
is recorded without a production workaround. The native judge checks the
complete reviewed verdict sequence and status; a leading or trailing extra
failure, another assertion, a missing verdict, a crash, or a build error
remains unexpected.

MLKit's default-region generator fixture built and then exited 139 before
printing a verdict. GDB stopped in `concatStringML` at `String.c:144`.
The unchanged sources pass **32/32 assertions** with `-no_ri`; that
[region-inference comparison](../../../docs/bugreport/mlkit/region-inference/BUGREPORT.md)
is a separate, explicitly named `ffi.model.generate-no-ri` job. The
ordinary build remains enabled and its exact pre-verdict crash is explained;
it is not replaced by the collector-only configuration.

Component `7bb284dc3` added those strict reports and the positive control;
`7c7bc7006` strengthened the leading-verdict guard after review. Planted
adapter checks passed 6/6, the focused all-host generator selection passed
13/13 strict runner jobs, and a real SML/NJ run after the guard correction
passed its 7/7 strict selection. Expected host failures remain labeled as
such inside these runner passes. A 7bb full-host attempt was deliberately
interrupted at 10/217 PASS to incorporate the reviewed guard correction;
it is retained as an interrupted attempt, not a completed run.

The fresh, complete rerun uses the reviewed `7c7bc7006` test snapshot:

```
NATIVE_HOST=yes MAKE=make bin/rune-test run --strict --tier test-lib-hosts -j 2 --keep
```

Its 217 jobs comprise the 204 default program oracles, one explicit MLKit
collector-only control, one C-reference producer, six stale-deviation
checks, and five runner canaries. Run `tests/out/r/20261023-142056-3441889`
completed **217 PASS, 0 FAIL, 0 SKIP**, in **1,723.9 s wall /
2,554.6 s CPU**.

Of the 204 default program oracles, **170 passed** and **34 failed with
recorded explanations**; none failed unexpectedly. Their categories are
13 HOST-ABSENT, 19 HOST-BUG, 2 HOST-FLAKY. The separate MLKit collector-only
control passed all 32 assertions. The Poly/ML Zmtp default program still hung until its ordinary
600 s limit (the existing `HOST-BUG`); it is not counted as a successful
program. Every default program and its explanation is listed in the JSON.
These distinctions prevent the 217 outer judge passes from becoming a
blanket claim that every native-own-Basis program executed successfully.

## Source applicability

The compiler and VM used by both acceptance runs report `18c353b49`.
Their hashes are in the receipt. All **591 selected production source
blobs** are identical through `ddba4faad`, `0e7f4cbfd`, and the host-judge
repair commits and final delivery `bca128b32`. Another **558 selected
dependency/test paths** from the original native-host source lists and
Basis/matrix fixtures are unchanged.
Those sets overlap and should not be added together.

Later changes comprise documentation, installation/test helpers, new
unselected SDL generated sets, and the explicit native-host defect judges.
The unchanged library and fixture sources remain the subject of the
comparison. This receipt does not infer native-own-Basis success from an
expected host defect or from the separate Rune runtime/Windows gates.

An earlier e5 matrix attempt was interrupted after 319/3,366 jobs, with
316 PASS and three MLKit 120 s timeouts. Its failed partial receipt remains
in the JSON history. The fresh final matrix above is a separate complete
run; contention was suspected in the older run, not established as a
compiler or runtime cause.

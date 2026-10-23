# Integrated regression findings — 2026-10-23

At frozen delivery snapshot `17c188d25`, `make check JOBS=8` completed
**19,614** cases: **19,604 PASS**, **3 SKIP**, **7 FAIL**, in 2,750.0 seconds.
The failed full run is preserved in `20261023-112250-2501228`; it is not a
clean acceptance receipt.

The failures have three causes:

| Cases | Cause | Focused repair |
| --- | --- | --- |
| `intinf/hardening/runtime`, `intinf/hardening/gmp-free` | Image-14 policy offsets were applied to image-15 files | `23392e68f`: guarded, named image-prefix parsing; 63 native and 37 GMP-free subprocesses pass |
| `cross/app`, `cross/mock-main`, `cross/native-main`, `cross/sdl-main` | A source-file scan treated GUI project fragments as standalone programs | Project-aware inventory and actual `.build` host comparisons are recorded in the example acceptance evidence |
| `compiler/build-generators` | The isolated fixture copied four build files while the generator consumes five | `f1c34c8e8`: all five programs/four hosts checked, 32 concurrent writers pass, planted missing output rejected |

The three skips are the existing native-code interrupt limitations in two
execution variants and an uninstalled optional pinned GMP dependency. Existing
GMP arithmetic remains primitive-backed; these repairs do not change it.

An earlier host-matrix attempt at `e5d379022` was deliberately interrupted
after **319/3,366** cases: **316 PASS**, **3 FAIL**, 2,486.8 seconds. All three
failures were MLKit default-120-second loads (`mono.word`, `mono.word16`,
`mono.word32`); the first `mono.int16` attempt passed in 62.667 seconds.
Parallel work and two erroneously recursive temporary compiler wrappers
contributed load; contention remains an inference, not a proven cause of
each timeout. No production workaround or timeout increase was introduced.
The interrupted receipt is preserved at
`/tmp/runeffi-e5-interrupted-matrix/receipt.json` and in its original runner
output. A new two-worker matrix uses frozen production source `18c353b49`
and a fresh output root.

Final full-check, matrix and VM-profile receipts are recorded separately
when those runs finish. Focused fixes do not relabel either earlier run.

The first final-source `ddba4faad` full-check attempt was stopped after
**21/19,699** cases: **18 PASS**, **2 SKIP**, **1 FAIL**, 221.3 seconds,
run `20261023-130556-3104841`. The new example catalog used the current
directory instead of `RUNE_TEST_ROOT` during runner initialization. A law
job's isolated working directory therefore triggered `missing build
entrypoint examples/win32/mock.build` before its law ran. The runner received
SIGINT and cleaned up its children; this partial failed receipt is retained.
The correction `49d5113a6` and an isolated-directory regression are recorded
in [the focused receipt](example-cwd.md); the exact original law bytecode
subsequently reports nine passes and no failures. A new cumulative check runs
in the independent `runeffi-check-final` worktree after the SDL packaging fix.

That complete pinned-static-libffi run, source `02360e6a9`, reports
**19,699** cases: **19,021 PASS**, **3 SKIP**, **675 FAIL**, in 2,068.5 seconds
(15,292.4 seconds CPU), run `20261023-134115-3192404`. All failures share one
test-oracle cause: **337 GNU readelf** and **337 LLVM** comparisons consume
the linked libffi C/assembly compilation units after the correct Rune table;
the remaining launcher fault probe fails before reaching its planted
`addr2line` error. No unrelated failed case occurs in that run.

The [native debug repair](native-debug-static.md), delivery `9fc0c929c`,
scopes rows by sized Rune function symbols and resets LLVM tables per unit.
Both real readers pass for the compiler, hello and interrupt fixture; the
complete launcher fault suite and 13 added external-unit/negative assertions
pass. The original static library retains its debug information. A later
complete run is required; this 675-failure receipt remains failed.

The subsequent `303db25bc` run, `20261023-142919-3454924`, completes
**19,699** cases: **19,694 PASS**, **4 SKIP**, **1 FAIL**, in 2,254.3 seconds
(16,126.2 seconds CPU). All native debug checks now pass. The sole failure is
`basis/rune-jit/posix_process`, whose
`Posix.Process.W.untraced/waitpid-without-it` assertion raises an exception.
Its dependent stale-deviation check adds the fourth skip. Exact frozen
bytecode/VM repeats initially pass; the original exception identity is not
retained by that assertion harness. Investigation and a subsequent fixture
repair have separate causal probes; this full run remains failed.

At `116109b1d`, run `20261023-151806-3816580` reports **19,695 PASS**,
**3 SKIP**, **1 FAIL** of 19,699 cases, in 1,959.9 seconds (14,464.2 seconds
CPU). The repaired POSIX fixture and all other functional checks pass.
`make/check-docs-generated` alone fails because its two POSIX coverage pages
still describe the preceding fixture. Regenerating the Basis documentation
updates the recorded check count and adds the deliberate-resume test link;
delivery `7997c95a4` contains those two generated pages. The following full
snapshot includes both this correction and canonical Win32 source ownership.

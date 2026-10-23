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

# Shared Win32 planted-fault acceptance — 2026-10-23

`make test-win32-contract-mutants` compiles five isolated copies of the real
`Win32ModelFn`, instantiates each with the actual mock driver, and runs the
same `Win32ContractFn` used by native Windows and SDL. Production files are
never changed. Every changed source anchor must occur exactly once. A compile
failure, timeout, crash or different failing group does not satisfy the gate.

The baseline passed **11/11** with `--jit=off --gc-stress 7 --gc-verify`.
All four changed programs compiled, exited with test-failure status 1 and
failed their intended group:

| Planted defect | Shared group detecting it |
| --- | --- |
| Omit `endPaint` after the body raises | `paint-output-scopes-and-exception-cleanup` |
| Prepend queued messages instead of appending | `queue-filter-copy-discard-and-single-use` |
| Leave a killed timer registered | `timers-cancel-and-preserve-identity` |
| Accept a stale window in `getClientRect` | `unsupported-selection-and-stale-window` |

The queue group now posts two same-code messages and checks their dispatch
results in posting order, with an exact window/code filter. The earlier two
different-code filtered retrievals could not distinguish FIFO from LIFO.
This checks an observable application order without assuming identical OS
event streams.

The retained receipt is `win32-mutants.json`; all five per-command argument
vectors, outputs, errors, statuses and mutant sources remain under
`tests/out/final-mutants/win32-mutants/runexCYOK5/`. The current enabled VM was
copied before the run, SHA-256
`b1556ea59a929cf5faa618bdb94b228450993215e6673ff4ed34ca3d96dd47c3`.
The coordinator supports `RUNE`, `RUNEVM`, `RUNE_LIB`, `RUNE_TEST_ROOT` and
`RUNE_TEST_RUN`; this receipt used the complete `runeffi-layout/lib` production
tree and the SDL worktree's revised contract source. Native and SDL suites use
that exact contract source too; the mutations themselves deliberately target
the deterministic implementation, so no desktop availability can mask them.

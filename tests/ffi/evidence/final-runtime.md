# Final frozen-runtime acceptance — 2026-10-23

The production runtime/Basis freeze is `18c353b49`; the complete binding-source
freeze is `ddba4faad`. Subsequent example-inventory and SDL packaging repairs
change test/build/install coordination, not these runtime or library sources.
The cumulative repository run and host-library matrix have separate receipts.

## Native Windows

Strict selection `ffi/windows/runtime*`, `ffi/shims/windows*`,
`ffi/win32-native/*`, `ffi/sdl/windows*` passes **15/15** outer runner cases,
zero failures/skips, in **1,278.2 seconds** (154.7 seconds recorded CPU).
Run: `20261023-130747-3110209` in the delivery worktree. Its event stream,
JUnit, C commands and child stdout/stderr remain under `tests/out/r/`;
the command log is `/tmp/runeffi-release-final-windows-ffi.log`.

This is actual Windows execution through the repository's Windows runner,
including both widths/engines, scalar and promoted variadic calls, callback
status, generated shims, SDL behavior and native Win32 contracts. It uses
SDK 10.0.22621.0, MSVC headers 14.40.33807, pinned libffi 3.4.6 archives
and pinned SDL 3.4.18 DLLs from the final admitted dependency prefixes.

## Generator, reference hosts and sanitizers

Strict selection `tag:test-ffi-model-hosts | tag:test-ffi-generator-hosts |
tag:test-ffi-generator-asan` passes **22/22** outer cases, zero failures/skips,
in **340.6 seconds** (383.1 seconds recorded CPU). Run:
`20261023-132348-3155465`; command log:
`/tmp/runeffi-release-final-generator-hosts.log`.

The selection checks complete model/generator inspections with the configured
MLton, SML/NJ x64/x86/2026.2, Poly/ML and MLKit hosts, plus the instrumented
generated native fixture. MLKit's default-region compiler defect retains its
strict documented expected-failure judge; unchanged `-no_ri` comparisons
pass separately. This is not a claim that the default MLKit defect disappeared.

The [final generator bootstrap receipt](final-generator-bootstrap.json)
records independent MLton-built-compiler and self-hosted-compiler builds.
Both produce the delivered **868,680-byte** `runeffi.rbc`, SHA256
`9144040b994bba876d34a90c0ee905efa56a29bf6827f1b25cf6323fcb5641ba`.
All explicit generator sources and exact compiler arguments are recorded.

## Fresh REPL image

The final compiler and fresh REPL image expose both `prepareVariadic` and
`callbackStatus`. An actual existing-REPL session opens libc, prepares
`sprintf` with two fixed pointer arguments and promoted integer/double tails,
retains resources across a later datatype/value declaration and full collection,
then obtains `-42:0.25`. A rooted callback status query reports zero rejected
entries and no failure reason. Explicit release leaves zero native resources.
Log: `/tmp/runeffi-release-final-repl-apis.log`.

Frozen inputs:

| Artifact | SHA256 |
| --- | --- |
| Register VM | `eef487c7081c347cabee509ed1e71945997190dbfe6a99b2bdc0a84a96aa1531` |
| Compiler RBC | `36225003fa50774cf84419b904d5c0e74de65bb97eddd7b7525c0ab704695be0` |
| Fresh REPL image | `e7b2fbdb2ff8730307adcacda8b9bb7b66d5bc433cb1af3d8fccbd2ab954ba51` |

The public/raw scalar, SDL and native Win32 REPL sessions have their own
retained-resource, later-declaration and cleanup receipts. Historical failed
or stopped runs remain in the integrated regression record.

# Project-aware example oracle acceptance — 2026-10-23

The original full check, `tests/out/r/20261023-112250-2501228`, compiled the
Win32 application's fragments independently under `cross/app`, `cross/mock-main`,
`cross/native-main` and `cross/sdl-main`. They require their `.build` provider
selection and could not typecheck alone. The basename-only inventory also
collided between root `examples/hello.sml` and `examples/sdl/hello.sml`.

The explicit `ExampleProjects` catalog preserves the existing top-level and
one-directory-deep example scope. It identifies ten standalone programs, the
ordinary mock application entrypoint, and three generated-provider entrypoints.
The inventory rejects unknown `.build` entrypoints, unclassified project
fragments and missing application members. Its negative probes exercise all
three refusals. Example names include their directory in both runner IDs and
artifacts. Positions now require real disassembly; the mock application's
positions include its actual `app.sml` source.

`check-cross`/`check-positions` compile `examples/win32/mock.build` with its
library selection. Focused `test-sdl-hosts` and `test-win32-hosts` gates use the
existing SML generation coordinators, then compile the actual SDL/native
`.build` entrypoints with all seven existing Rune compiler builds. They do
not open SDL/Windows libraries or imply native GUI execution. Native profiles
use the pinned original SDK and MSVC headers and explicit 32/64-bit profiles.

## Actual compilation and bytecode agreement

For each row below, all **seven nonempty artifacts** have one identical
SHA-256 within that project/profile. There are **42 compared artifacts**:

| Program/project | Profile | Builds |
| --- | --- | --- |
| Root `examples/hello.sml` | Native | 7/7 |
| `examples/win32/mock.build` | Portable mock | 7/7 |
| `examples/sdl/hello.build` | Linux/x86-64 generated SDL | 7/7 |
| `examples/win32/sdl.build` | Linux/x86-64 generated SDL | 7/7 |
| `examples/win32/native.build` | Windows x86 generated binding | 7/7 |
| `examples/win32/native.build` | Windows x86-64 generated binding | 7/7 |

The builds are MLton, SML/NJ legacy 64-bit, SML/NJ 32-bit, SML/NJ current,
Poly/ML, MLKit and Rune's boot compiler. The mock RBC also executes successfully
and prints `PASS shared Win32 application: 0`.

The newly covered SDL hello project exposed a real source error: a literal
Unicode em dash failed the documented default ASCII input mode. Its title
now uses ordinary SML97 UTF-8 decimal byte escapes `\226\128\148`. A first
attempt with `\u2014` was also rejected for the byte-string type. Both failure
receipts remain recorded; the final source compiles in the default mode on
all seven builds.

## Runner integration

- Inventory, ordinary cross jobs and real position checks: **10/10 PASS**,
  including five canaries, 5.8 seconds wall. Receipt:
  `tests/out/example-projects-runner/20261023-122929-3021750/`.
- Focused SDL gate: **PASS** in 20.1 seconds; its combined selection recorded
  6 passes and one native SDK capability skip. Receipt:
  `tests/out/example-projects-focused-runner/20261023-123127-3024404/`.
- With explicit `RUNEFFI_WINDOWS_SDK` and `RUNEFFI_MSVC_INCLUDE`, the native
  gate executed both target profiles: **6/6 PASS**, including five canaries,
  56.1 seconds wall. Receipt:
  `tests/out/example-projects-native-runner/20261023-123302-3028376/`.

Initial restricted-sandbox attempts terminated the 32-bit SML/NJ compiler with
SIGSYS/status 159 and empty stderr. Their missing artifacts were not accepted
as agreement. The successful runs used the same source and actual compiler
builds outside that restriction. Earlier ordinary oracle commands print
`FAIL` without changing their own exit status; the runner's failure-line judge
and the independent seven-artifact/hash assertions both enforce the verdict.

`example-projects.json` retains classification, registered jobs, source hashes,
all 42 artifact hashes, 32 focused command vectors and prior failure receipts.
Full compiler streams and generated artifacts remain under the corresponding
`tests/out/example-projects-*` directories. Runtime GUI and generator-host
acceptance remain separately attributed in their existing receipts.

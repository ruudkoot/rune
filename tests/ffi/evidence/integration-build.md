# Integrated tool builds and optional bootstrap — 2026-10-23

Delivery snapshot `f79b70b3a` combines aggregate, registered-callback and
macro/fixed-vararg generation, the shared GUI application and guarded
dependency packaging. `make all docs check-docs check-tools JOBS=4` first
failed when the sandbox terminated SML/NJ32's `ml-build` with `Bad system
call` (exit 159). The exact unrestricted rerun passed, including all host
compiler/tool builds and **11/11** documentation checks. Its documentation
receipt is `tests/out/r/20261023-102454-2395012`. The failed sandbox run is
not counted as a clean build.

The subsequent integration snapshot with shared Boolean conversion,
callback-selector normalization and native Windows source-path handling
passes `make all docs check-docs bin/rune-ffi-generator-check JOBS=4` and
another **11/11** documentation checks:
`tests/out/r/20261023-103501-782`. Generated C-library documentation follows
the repository's central convention links.

The separate FFI-disabled release snapshot also passes
`make FFI=no bootstrap JOBS=4`: **7/7**, zero skips/failures, 3.8 seconds,
`tests/out/r/20261023-100144-426`. At that point its compiler, Basis and
runtime sources matched the enabled integration tree; the foreign-library
and generator source sets differed. This does not replace final generator
bootstrap/host agreement or later installed-native-linker acceptance.

Both CI workflow files parse as YAML. The enabled FFI and disabled-build
steps have corresponding local component receipts; the headless SDL steps
match the validated dependency/behavior sequence. Remote Actions execution
has not been requested or claimed. Cumulative release suites remain a
separate gate.

# Optional FFI-disabled build — 2026-10-23

Final frozen-source acceptance, including the current API and freshly built
artifacts, is recorded in [final-noffi.md](final-noffi.md). The older component
receipt below is retained as historical evidence.

At release worktree snapshot `5f616d0b0`, both `make FFI=no vm JOBS=4`
and `make FFI=no all JOBS=4` pass. The snapshot includes the generic ABI
query and image version 15 identity-floor protection. The recorded native
VM link contains no libffi dependency (`-DRUNE_FFI=0`).

Both stack and register VMs pass `tests/ffi/disabled.sml`, including
availability, native ABI facts and deterministic rejection of native
operations. A strict C99 `-Wall -Wextra -Werror -pedantic` build of
`tests/runtime/foreign_disabled.c` and `runtime/foreign.c` also passes,
including preserved monotone identity floors without libffi.

After the full build, the checkout's own freshly bootstrapped `bin/rune`
compiles the disabled fixture and its own VM passes it. Pure generation
also works without native FFI:

```sh
bin/runeffi generate --config tests/ffi/generator/scalars.ffi \
  --target ffi/targets/linux-x86_64.json --out build/noffi-generated
bin/runeffi check --config tests/ffi/generator/scalars.ffi \
  --target ffi/targets/linux-x86_64.json --out build/noffi-generated
```

Both commands pass with immutable generation
`49795920c9852ac9df5f915c7815ab597e31d3fc690ae15d8e375dbb9d771794`.
This is optional-build component evidence, not cumulative acceptance of
later aggregate/public-generator and packaging additions. M10 remains planned.

The final integrated runner also distinguishes native execution from pure
generation. With its FFI-enabled VM, the `check` inventory contains all 13
FFI jobs. The same runner bytecode on the FFI-disabled VM retains 10 pure or
independent-C jobs; generated native/safe calls and native shim execution are
excluded from that mandatory tier. An explicitly selected native shim job
reports `SKIP: needs ffi-runtime`, with the build instruction, rather than
failing a foreign operation. The exact selection passed five runner canaries
and recorded one expected skip in `20261023-111305-2`. Native SDL/Win32 jobs
carry the same capability requirement; strict enabled acceptance still treats
a missing required capability as an error.

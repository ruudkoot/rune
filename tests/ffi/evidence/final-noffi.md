# Final optional FFI-disabled acceptance — 2026-10-23

The exact frozen delivery source `ddba4faad9fa5f8540367f1067be35d1b561936d`
passes a fresh build and acceptance in the isolated
`/home/ruud/rune/.worktrees/runeffi-nofi-final` worktree. No enabled-build
compiler, bytecode, VM or REPL image was copied into this checkout. Existing
installed MLton was used as the bootstrap host; production sources remained
unchanged and clean throughout the checks.

The [checked JSON receipt](final-noffi.json) records all 58 focused commands,
stdout/stderr, expected negative controls, source and toolchain identities,
16 artifact hashes, witness source text, immutable generations and the three
fresh build logs. There were no unexpected failed attempts.

## Build and bootstrap

```
make -j2 FFI=no all JOBS=2
make -j2 FFI=no bootstrap JOBS=2
make -j2 FFI=no repl JOBS=2
```

All three commands pass. Bootstrap passes 7/7, including byte-for-byte
register and stack compiler reproduction and five runner canaries. Events:
`tests/out/r/20261023-130423-97/events.jsonl`.

`readelf -d` confirms that neither VM nor the generated native witness links
libffi. The register VM retains its existing `libgmp.so.10` dependency;
disabling FFI does not disable GMP. Relevant SHA256 identities are:

| Fresh artifact | SHA256 |
| --- | --- |
| Register VM | `0d88bec3011df7ad5f08b053607930f10a33feb18945fa821826b81641be7e86` |
| Stack VM | `8694a1c5cc1dbafadb5a91433ed3351db9c592b0346c659085936f65cf3d4529` |
| Compiler bytecode | `36225003fa50774cf84419b904d5c0e74de65bb97eddd7b7525c0ab704695be0` |
| Generator bytecode | `9144040b994bba876d34a90c0ee905efa56a29bf6827f1b25cf6323fcb5641ba` |

The JSON also binds the newly produced REPL image, native Rune compiler,
static runtime, strict-C99 subjects and both `SYS=none` VMs. The ordinary
VM/compiler/generator hashes are unchanged after the separate `SYS=none`
checks, which never overwrite `bin`.

## Disabled runtime and current API

Both bytecode targets compile and run the repository disabled fixture, native
ABI-fact fixture and new variadic/callback-status language fixtures using this
checkout's own `bin/rune`. Register execution passes with JIT off, baseline
and optimized tiers; those bytecode fixture runs use collection stress 7 and
heap verification.

An additional receipt-contained SML witness checks the exact public types of
`prepareVariadic` and `callbackStatus`, all four callback-fault constructors,
repeatable errors from library opening/allocation/callback creation, and zero
live resources after rejection and collection. Those errors consistently have
number 38, native code zero and message `runtime built without libffi support`
on this Linux host. The same witness passes through the freshly built
`runeopt` native execution path.

Opaque resource construction remains unavailable to SML when FFI is disabled.
The generic C disabled fixture directly invokes both new resource-taking
operations and verifies ENOSYS. Strict C99 `-Wall -Wextra -Werror -pedantic`
compilation/execution passes for `foreign_disabled.c` plus `foreign.c`, and
again with `sys_none.c` linked. Monotone identity-floor behavior is preserved.

Both full `SYS=none` interpreters also compile under C99 from the Makefile's
canonical source lists with `RUNE_FFI=0`, `RUNE_JIT=0` and the portable IntInf
backend. Silent SML witnesses verify availability, ABI facts, API types and
unsupported library behavior under collection stress. Expected nonzero
uncaught-exception controls prove that each VM actually executes its input.
This does not claim POSIX I/O or JIT support for `SYS=none`.

## Generator, mock and frozen REPL

The actual freshly built `bin/runeffi` generates, regenerates byte-identically
and checks both `scalars.ffi` and the full `safe.ffi` public projection fixture.
Neither generation path invokes native FFI. The immutable generation pointers
are retained in the JSON receipt.

The unchanged `examples/win32/app.sml` builds via
`--library ffi/win32/mock --build examples/win32/mock.build` against this
checkout's own libraries and compiler. Both VMs pass with collection stress
101 and heap verification, printing `PASS shared Win32 application: 0`.

The newly built `bin/rune-repl.img` restores with `--no-init --basic` and
accepts the same API/error witness. It exposes the current `prepareVariadic`,
`callbackStatus` and callback-fault types, reports unavailable FFI and valid
native ABI facts, and preserves deterministic rejection without resources.
The transcript and exact image hash are part of the JSON receipt. This proves
the current frozen Basis rather than reusing an older enabled image.

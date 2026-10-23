# Canonical generated SDL sources — 2026-10-23

The complete generated binding sources are committed under `lib/ffi/sdl`,
separately from the idiomatic public `sdl` facade. All targets select the same
**53 core plus 3 support functions**, **5 layouts**, **69 constants** and
**3 field adapters**. Each target contains its stable API files, immutable
source/provenance set, optional C shims and explicit `current.build` pointer.

| Canonical directory | Immutable set | Files | Bytes |
| --- | --- | --- | --- |
| `lib/ffi/sdl/generated/native` | `4fcd7b48b41e48268ed3b11311b41800dc37586a6f8b99573e7cff44dc7c753b` | 16 | 697,660 |
| `lib/ffi/sdl/generated/windows32` | `680425f7a0587a2b6554820f582276780acf425473aaa8a7f05e89e49c065070` | 16 | 2,568,113 |
| `lib/ffi/sdl/generated/windows64` | `8ea8925fd22cdc0a80383cf91167edc826ffcf1842cdddb3c1573fecbebbcf7d` | 16 | 2,595,870 |

The tracked payload is **48 files / 5,861,643 bytes**. Compiler caches,
`MANIFEST` files, object files and native shared libraries are excluded.
Windows declaration provenance is larger because its compiler-runtime
declarations differ. The set IDs are content-derived; `sdl-generated.json`
also records every individual artifact's SHA-256.

`make sdl-generated` runs the SML regeneration coordinator explicitly.
`make check-sdl-generated` recomputes and strictly checks every expected file
and pointer without publication. A single target can be selected through
`bin/runevm bin/rune-sdl-generated.rbc check native` (or `windows32`/`windows64`).
No `.build` description executes a command. The checked-in pointers are chosen
with `--path SDL_GENERATED=ABSOLUTE_TARGET_DIRECTORY`.

Inputs are the unmodified vendored SDL **3.4.18** headers, pinned source archive
SHA-256 `9c75cf16330322c217dedd2e0609f1124f1b54b8633e763467b4684d0f4334a3`,
the `.ffi` policy, core/support inventories, target profiles, explicit native
standard-include roots and the pinned original Microsoft SDK/MSVC roots.
The coordinator verifies all **87** SDL source-manifest files before either
operation. Per-set manifests retain the 95/114/113 transitive header dependency
hashes. Exact include-root/compiler queries and generator arguments are retained
in the machine receipt, alongside the production generator bytecode digest
from source revision `17c471463`.

Validation completed:

- **Three strict checks PASS**, one for each canonical target.
- An untouched private copy passed strict checking; a planted modification
  to its `raw.sml` was rejected with `changed or stale generated file`.
- The SDL hello `.build` compiles against **all three canonical source sets**.
- Generated native C shims compile with GCC; both Windows-width shims compile
  with Clang's Microsoft ABI against the original SDK/compiler headers.

The first Windows C compilation used global `-Werror` and rejected Microsoft's
unselected intrinsic declarations because Clang ignores `intrin_type`.
The successful oracle commands retain those warnings with
`-Wno-error=ignored-attributes`; other warnings remain errors. Original headers
and generated shims are unchanged. Both initial failures and successful
commands/diagnostics are preserved. These are compile checks, separate from
the real Windows SDL runtime/GUI and native C layout receipts already recorded.

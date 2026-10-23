# Expired foreign identities in images — 2026-10-23

Expired callback arguments and their views can escape into SML without a
liveness query updating their cached tombstones. No native resource remains
live, so saving is legal; restarting the process-wide numeric allocator at
one could otherwise revive those wrappers against unrelated allocations.

Image version 15 records the next unused identity and advances the restoring
process's allocator monotonically after validation succeeds. It serializes
no native address, resource registry or closure handle. Both instruction
sets, emulated fork and the Runeopt image reader use the new format. Version 14
images must be recreated; bytecode is unchanged. Zero floors reject before
read-side state restoration. A maximum floor denotes exhaustion and never
wraps. Failed/truncated image validation does not advance the allocator.

The new `stale-image.sml` retains an expired callback pointer and view without
querying them, closes every native resource, saves, then allocates sixteen
new foreign buffers before checking stale reads and liveness. The fixture
also rejects a zero floor and a truncated image with a maximum floor,
proving failed restore cannot exhaust the current allocator.

Validation passed:

- `make isa`; `make all bin/rune-ffi-check vm-asan`.
- `bin/rune-ffi-check runtime native`: stack/register save and fresh-process
  restore, the Runeopt native producer/consumer, existing GC/reentry gates.
- `bin/rune-ffi-check runtime asan`: existing FFI stress and a 25-check C
  oracle including floor validation, monotonicity and exhaustion boundaries.
- `make windows` with pinned libffi 3.4.6 archives, followed by
  `bin/rune-ffi-check runtime windows32` and `runtime windows64`: both
  instruction sets passed stale-image round trips and callback fixtures.
- `bin/rune-test run 'native/opt/images'`: 6/6 passed, including
  `runeopt --from-image` and VM/native interchange.
- `make docs check-docs`: 11/11 documentation checks passed.

The first native-image suite invocation lacked its checker executable; after
building `bin/rune-native-check`, the exact rerun passed. Initial Windows
checks found the runtime checker omitted `callback-fixture.c` from its DLL;
the source list now includes both fixture files and the exact reruns passed.
Neither initial receipt is treated as a successful full run.

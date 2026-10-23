# Runtime, public projection and SDL integration — 2026-10-23

The combined integration snapshot includes callback shutdown protection,
image version 15 identity floors, complete measured ABI guards and generic
public ownership/buffer/callback projection. Native Windows acceptance now
also exercises the x86-64 register VM's forced baseline and optimizing JIT
tiers, with collection stress 7 and heap verification, across scalar calls,
native buffers, explicit owners and suspended callbacks. x86 remains an
interpreted target. Both Windows widths/instruction sets check native ABI
facts and stale-identity image round trips.

The runtime coordinator retains a distinct numbered stdout/stderr pair and
JSON argument vector for every subprocess, including each JIT invocation.

`tests/out/r/20261023-091722-2186438` passes **41/41** cases: **37 PASS**,
four SDL capability skips, zero failures (440.8 seconds). It covers native
and sanitizer runtime gates, both Windows widths, native-image interchange,
public generator fixtures, host generation comparisons, pure libraries and
the host inventory contract. The four skips came from an incorrect SDL
prefix supplied to that invocation.

After verifying the installed prefix, the exact SDL selection passes
**9/9**, zero skips or failures, in 360.1 seconds:
`tests/out/r/20261023-091847-2194344`. This includes the core SDL fixture,
failed-start cleanup and the Win32 SDL driver in dummy and real Linux GUI
modes, including stack/register collection stress and both native JIT tiers.
The library path is
`build/deps/sdl/native/install/lib/libSDL3.so.0` in the delivery worktree;
it is not beneath the source archive directory.

The preceding combined `make all docs check-docs windows vm-asan` build and
all **11** documentation checks passed. These focused checks do not replace
the full cumulative repository/portability/release gates or the still
planned aggregate/registered callback generator work.

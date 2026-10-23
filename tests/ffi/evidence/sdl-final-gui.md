# SDL GUI collection and REPL acceptance — 2026-10-23

These checks used the production generator and sealed SDL/Win32 libraries from
`runeffi-layout`, with SDL 3.4.18's real Linux desktop backend. No dummy/headless
video override was present. The VM and compatible REPL image were copied before
execution. This is separate from the earlier M7 and GUI stress-7 receipts.

| Artifact | SHA-256 |
| --- | --- |
| Current enabled VM | `b1556ea59a929cf5faa618bdb94b228450993215e6673ff4ed34ca3d96dd47c3` |
| REPL image | `cd30bec48f70c7251c70ca0b96f0fb1ad2edff177be454bc5f6d097cc223fc3c` |
| Shared Win32 SDL application RBC | `79c87266734a8eceeef44f9700d7361bbbb91a09c677389ef7b17db38d3624fb` |
| Generated adapter library | `ebf11331130596fdfa0f925583ae8e6c6bdad67db60eec2806a263c04ba86b0d` |
| Desktop SDL shared library | `4984737ef3e9a08328dab514342fd4fe6737c0d1a35062ba23b73f0e09d958f5` |

The generator selected all 53 required SDL functions and three explicit Win32
support functions. Immutable set:
`f83b5f519861f8d76eae6b99a3f655a6aa5022fbb0632ddc56a46bd8493e6f5e`.
Generated field shims compiled with the unchanged pinned headers and
`-DSDL_MAIN_HANDLED=1`.

## Same application under collection stress

The unchanged `examples/win32/app.sml` compiled through the SDL virtual provider
and ran with:

```sh
FROZEN_VM --jit=off --gc-stress 101 --gc-verify --stats \
  win32-app.rbc ABSOLUTE_SDL_LIBRARY ABSOLUTE_ADAPTER_LIBRARY --smoke
```

**PASS**, exit 0, success marker after cleanup, 9.527 seconds wall and 7.861
seconds child user/system CPU. The 600-second harness limit was not reached.
Runtime statistics: **3,238 collections**, 6,839,704 bytes allocated, 552,280
bytes live; all collections were minor, no large objects or full collections.
The application releases window, paint, timer, class and GDI resources and
the SDL provider rejects shutdown while resources remain.

`sdl-final-app.json` retains the full command, timings, GC statistics and hashes.
Earlier stress-7 runs at a 60-second cap remain timeouts; one long run was
stopped after a CPU delay. Those receipts are preserved in `m9-sdl-driver.md`.
This passing interval establishes repeated collection while the real GUI
application runs, without relabeling the earlier failed bounded runs.

The shared Win32 GUI contract also passed **11/11** after adding the same-code
FIFO assertion used by the planted-fault gate, on this same real SDL backend
with `--jit=off --gc-stress 101 --gc-verify`. The complete command and output
are retained in `sdl-fifo-final.json`.

## Actual SDL provider in the REPL

`tests/ffi/sdl/repl-check.sml` uses existing REPL file arguments to load 24
ordinary sources, including the generated Raw/Layout modules and sealed
`SDLFn` projection. Repeated `-e` arguments then perform two distinct sessions:

1. Load SDL, initialize video, create a visible window and software renderer,
   and retain their handles across the return to the REPL.
2. Compile later value/function or datatype declarations, allocate a 5,000-
   or 7,000-element list and call `Runtime.collect ()`.
3. Require an increased collection count, unchanged window identity and native
   geometry, then draw text/present after collection.
4. Destroy renderer/window, quit/unload SDL, and require `RuneForeign.live()`
   to return to its initial zero value before the next session.

The initial exact command completed **PASS**, exit 0 in 36.768 seconds, with
both retained-session markers and the two-session success marker. The SML
coordinator repeated those assertions and passed in **45.280 seconds**, exit 0,
with empty stderr. It records every input hash and requires normal exit; it
never treats an error or timeout as a pass.
Its machine receipt is `sdl-repl-final.json`. The source-loading list and exact
repeated declarations are encoded by that coordinator; reproduction is in
[the SDL guide](../../../docs/ffi/sdl.md#existing-repl-source-loading).

Scoped repository validation: `bin/rune-test run --tier docs-consistency -j 2`
passed **11/11** (six documentation checks plus five runner canaries) in
25.5 seconds, receipt `tests/out/r/20261023-113438-8/`. Edited relative links,
JSON receipts and `git diff --check` also passed. Full integration checks belong
to the release coordinator, separately from these component receipts.

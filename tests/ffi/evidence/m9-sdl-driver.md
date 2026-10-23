# M9 SDL driver component — 2026-10-23

Milestone status: **planned**. This is the thin SDL implementation of
`WIN32_GUI_DRIVER`, not completion of the shared application/contract gate.
The shared model, native provider and all three implementations' common
acceptance remain separate artifacts.

`Win32SdlDriverFn` owns real SDL windows/renderers and drawing scopes, maps
SDL input to shared messages, and supplies monotonic clocks. Class/procedure
registration, creation callbacks, nested message sends, timer/queue policy and
GDI object ownership stay in the shared model. The driver cannot invoke a
window procedure because that capability is absent from its constructor.

Two original-header support selections, `SDL_SetWindowPosition` and
`SDL_SetHint`, supplement the required 53-function SDL inventory. The complete
selection is now 55; `ffi/sdl/support.json` records the extras and constants.
The SDL hint suppresses automatic quit when the last window closes, preserving
application-owned `PostQuitMessage` behavior. `CW_USEDEFAULT` is translated to
the generated SDL undefined position; explicit native placement is attempted,
and compositor refusal is reported instead of silently ignored.

## Executed component checks

- Generated fixed raw descriptors and layouts from the original pinned SDL
  headers, including every support constant, without editing headers.
- Focused **17/17** semantic checks with dummy video and a real Linux desktop
  window. Checks cover client geometry, default positioning, drawing scope
  lifetime, RGB channel conversion, stroke width, ASCII text/backgrounds,
  explicit unsupported text, virtual keys, mouse flags/coordinates, UTF-16
  code units, paint/resize/close events, clocks and complete native cleanup.
- Stack interpreter with GC stress 7/verification and baseline/optimizing JIT:
  **17/17** each.
- Register ASAN/UBSAN with GC stress 7/verification and LeakSanitizer outside
  the ptrace sandbox: **17/17**, exit zero.
- Complete bounded driver runner: **6/6 jobs**, 58.1 seconds, retained at
  `tests/out/r/20261023-073351-8` (one SDL driver job plus five canaries).
- Real desktop bounded driver runner outside the sandbox: **6/6 jobs**, 62.0
  seconds, retained at `tests/out/r/20261023-073355-1527576`.
- The identical shared `Win32ContractFn` source passed **11/11 groups** against
  the root agent's deterministic shared model/mock under GC stress 7 and heap
  verification. Native Windows and shared-model-over-SDL runs remain pending.

An initial prefix-filter invocation also selected the GUI tier inside the
restricted sandbox and failed that one GUI job (`No available video device`):
**six passes, one failure**. Exact native and GUI tiers were rerun separately;
GUI acceptance ran outside the display-restricted sandbox. The failed run is
retained at `tests/out/r/20261023-073311-8` and is not counted as a clean pass.

The initial shared contract run found one model mismatch (cancelled timer
reported error 87 instead of 6) and one fixture cleanup bug (converting already
closed typed GDI handles while cleaning up). The model now reports 6; fixtures
capture the generic object identities before cleanup registration. The updated
shared suite passed all 11 groups. Public stale typed-handle conversions are
also explicitly checked to reject error 6.

The independent C oracle subsequently compared all **69 selected constants**
against the SML-generated values. The expanded **18-check** source passed on
stack/register GC stress 7 and both JIT modes through the bounded runner:
**6/6 jobs**, 74.4 seconds, retained at `tests/out/r/20261023-074020-10`.
These later oracle runs do not relabel the preceding 17-check sanitizer receipt.
Generated SDL and driver library documentation was regenerated and checked
against source.

## Capability limits

SDL title display combines surrogate pairs and replaces lone surrogate glyphs;
shared model text retains its declared WTF-8 policy. Drawing uses exclusive
rectangle edges, fixed printable ASCII 8 by 8 cells and parallel-line solid
strokes, rather than GDI-identical rasterization. Unsupported characters and
unavailable placement are explicit. Mouse modifier flags follow the most
recent pumped keyboard event. Navigation/modifier keys, ASCII alphanumerics,
common OEM punctuation and F1–F24 map to Win32 virtual keys; SDL-only keys and
unmapped events are ignored. OS event ordering, decoration, DPI behavior and
pixels can differ; the shared suite compares typed behavior.

A dedicated startup-failure fixture subsequently forced an unavailable video
driver. It confirmed that the original failure is reported and all native
identities return to baseline after `SDL_Quit` and unload. The same fixture
passed ASAN/UBSAN with GC stress 7/verification and LeakSanitizer outside the
sandbox. This exercises the partial-initialization cleanup path directly.

## Persistent clipped painting follow-up

The drawing contract now requires `begin {window, rectangle}` and preservation
of pixels outside the invalid bounding rectangle. A third original support
selection, `SDL_SetRenderClipRect`, brings the total to **53 core + 3 support**
functions. Each window owns an ARGB8888 surface/software renderer independently
of the display renderer's backbuffer. Finish flushes the canvas, presents it
through a scoped texture, resets clipping and releases the scope on every
returning path. Resize allocates/clears/copies before publishing replacement
storage, and retired resources remain owned until cleanup succeeds.

The expanded pixel probe passed **30/30** checks with dummy video, real Linux
windows, the stack interpreter under GC stress 7/verification, optimizing JIT,
and register ASAN/UBSAN with GC stress 7/verification and LeakSanitizer outside
the sandbox. It proves black exterior pixels survive successive red/blue
partial presents, empty clips modify nothing, and resize preserves overlapping
old pixels while initializing the new area. Native identities return to
baseline after destroying both windows and shutting down the provider.

Receipts are `/tmp/runeffi-sdl-win32-canvas-{dummy,gui,stack,jit,asan}.log`.
The earlier 17/18-check receipts remain distinct and are not relabeled as pixel
acceptance. Shared-model-over-SDL and native Windows common-suite acceptance
are still required before the full M9 gate closes.

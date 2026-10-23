# Win32 SDL GUI driver

Area: Foreign interfaces

`Win32SdlDriverFn` implements the thin `WIN32_GUI_DRIVER` contract using the
sealed SDL3 projection. It owns SDL windows, a persistent ARGB8888 canvas and software renderer per
window, a separate display renderer, and clipped drawing scopes. Shared Win32 class registration, creation callbacks,
message dispatch, timers, paint regions and GDI object policy belong to the
separate shared model. The driver never invokes a window procedure.

`load` receives explicit SDL and generated adapter paths. It disables SDL's
automatic quit on closing the last window before initializing video, leaving
`PostQuitMessage` behavior to the application/model. `shutdown` requires all
windows and drawings to have closed, then quits and unloads SDL. Creation uses
explicit x/y coordinates; Win32 `CW_USEDEFAULT` becomes generated
`SDL_WINDOWPOS_UNDEFINED`. Platforms refusing explicit placement report that
limitation rather than silently ignoring it.

The core inventory retains its required 53 functions. Three additional original
header selections, `SDL_SetWindowPosition`, `SDL_SetHint` and
`SDL_SetRenderClipRect`, are recorded in
`ffi/sdl/support.json` for this provider. That file also lists required generated
SDL constants. Raw descriptors and layout facts are generated; the driver adds
no primitives or handwritten native call descriptors.

Each scope clips to the client-intersected invalid bounding rectangle. An empty
clip changes no pixels. Finish resets the clip, flushes the canvas, presents a
temporary texture and releases the scope on every returning path. Pixels outside
the invalid rectangle survive subsequent presentations. Resize allocates and
clears a replacement canvas, copies the overlapping old pixels, then publishes
it; failed retired-resource cleanup remains owned for retry.

Drawing uses Win32 COLORREF channel order, exclusive-edge rectangles, positive
width solid lines and printable ASCII text. SDL's fixed 8 by 8 debug font and
parallel-line stroke rasterization differ from GDI; identical pixels are not
promised. Opaque text fills its fixed-cell background. Unsupported characters
raise the shared `Unsupported` exception. Window titles accept WTF-8, combine
valid surrogate pairs and replace unpaired surrogate glyphs for SDL display;
the shared model retains the original title policy.

Input maps the documented SDL window, keyboard, text and mouse event families
to shared messages. Text becomes UTF-16 code units, including surrogate pairs.
ASCII letters, digits, common OEM punctuation, navigation/modifier keys and
F1 through F24 map to Win32 virtual keys; other SDL-only key identities are
ignored. Mouse modifier flags use the most recently pumped keyboard event.
Unmapped SDL events are ignored rather than being mislabeled Win32 messages.
The model/application owns destruction and quit semantics. Event ordering,
window decoration, DPI behavior, fonts and rasterization can differ by host.

# SDL3

Area: Foreign interfaces

`SDLFn` implements Rune's core SDL3 signature over generated declarations and
layout facts. It covers all 53 entries of `ffi/sdl/inventory.json`: startup,
windows, copied events, keyboard and mouse input, text input, surfaces, 2D
rendering, debug text, clipboard text, and clocks. The separately inventoried M9 support operations add native window
positioning, renderer clipping and SDL hints. `SDL_free` is used internally
for owned clipboard results. Audio, GPU APIs, application-entry integration,
and callbacks from foreign threads remain outside this core.

Generate the raw and layout modules from the pinned original headers and
`ffi/sdl/core.ffi`, compile the generated field adapters, then instantiate:

```sml
structure SDL = SDLFn (structure Raw = SDLGeneratedRaw
                      structure Layout = SDLGeneratedLayout)
```

`SDL.load [sdlPath, adapterPath]` names the two native libraries explicitly.
`init` calls `SDL_SetMainReady` before `SDL_Init`. Application startup, video,
event pumping and rendering run on the owning VM thread. `SDL_RunApp`, SDL's
alternative application callbacks, and SDL's rewriting of C `main` are unused.
Compile Windows field adapters with `-DSDL_MAIN_HANDLED=1` to suppress that
upstream header's C entrypoint implementation.

All public handles have explicit destruction. Renderers retain their window or
software surface; textures retain their renderer. Destroy children first.
Locks, active borrowed scopes and live children prevent destruction. `quit`
and `unload` reject live public resources before changing state. Raw sessions
retain native status/error values and original declaration names. Mixing raw
and public ownership requires the caller to maintain these same lifetime rules.

Events copy scalar data and UTF-8 strings before the next SDL operation can
invalidate borrowed payloads. Pushed text buffers remain alive until the event
is consumed, or until `quit` if raw code filters or removes it. Unknown event
kinds are preserved as their numeric identity. Push unknown event storage
through the explicit raw layer when its payload is needed. OS event ordering
and pixels are not promised to match across platforms.

Pixel scopes lock uncompressed SDL surfaces, copy their complete pitched rows,
and copy writes back even when the body raises. A retained SML byte array is a
snapshot after the scope returns. FourCC/YUV/compressed layouts require raw
access with an explicitly established extent. `renderDebugText` uses SDL's
built-in ASCII debug font; general Unicode font shaping is outside the agreed
SDL inventory. Clipboard and window titles use strict UTF-8 and reject embedded
NULs. The SML callback in a pixel scope must not leave an unmatched pixel lock.

See `docs/ffi/sdl.md` for regeneration, platform provisioning and acceptance.

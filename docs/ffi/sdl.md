# Core SDL3 delivery

The policy is [core.ffi](../../ffi/sdl/core.ffi), separate from the unchanged
[SDL3 3.4.18 originals](../../ffi/sdl/upstream/SDL3/SDL.h). Its 53 selected
functions match [the inventory](../../ffi/sdl/inventory.json). The generated raw
layer supplies native descriptors and declaration provenance; the documented
[`SDLFn`](../lib/sdl/README.md) projection supplies resource dependencies,
copied events, scoped pixels, records, options and returned outputs.

## Generate and compile

Provision the pinned sources as described by `ffi/sdl/source.json`. Provision
libffi for the target VM as described by `docs/ffi/runtime.md`. The generator
runs in Rune/SML; neither Clang nor a native C compiler parses its input.
Native compilers independently check generated adapters and ABI facts.

On Linux/x86-64, use explicit standard include roots for the installed C
headers. The following example uses GCC 13's private header directory; replace
it with the pinned toolchain's actual include directory and record that path.

```sh
bin/runeffi generate --config ffi/sdl/core.ffi \
  --target ffi/targets/linux-x86_64.json --out build/ffi-generated/sdl \
  --include ffi/sdl/upstream --include /usr/lib/gcc/x86_64-linux-gnu/13/include \
  --include /usr/include/x86_64-linux-gnu --include /usr/include \
  --layout SDL_Event --layout SDL_Surface --layout SDL_Rect --layout SDL_FRect \
  --layout SDL_TextInputEvent --field-get SDL_Surface:pixels \
  --field-set SDL_TextInputEvent:text \
  --constant SDL_INIT_VIDEO --constant SDL_INIT_EVENTS \
  --constant SDL_WINDOW_RESIZABLE --constant SDL_WINDOW_HIDDEN \
  --constant SDL_WINDOW_FULLSCREEN --constant SDL_EVENT_QUIT \
  --constant SDL_EVENT_WINDOW_RESIZED --constant SDL_EVENT_WINDOW_FIRST \
  --constant SDL_EVENT_WINDOW_LAST --constant SDL_EVENT_KEY_DOWN \
  --constant SDL_EVENT_KEY_UP --constant SDL_EVENT_TEXT_INPUT \
  --constant SDL_EVENT_MOUSE_MOTION --constant SDL_EVENT_MOUSE_BUTTON_DOWN \
  --constant SDL_EVENT_MOUSE_BUTTON_UP --constant SDL_PIXELFORMAT_RGBA8888 \
  --constant SDL_PIXELFORMAT_ARGB8888
```

The generation prints an immutable set identifier. Compile that set's `shims.c`
with `-shared -fPIC -DSDL_MAIN_HANDLED=1 -Iffi/sdl/upstream`, and record its input
set identifier beside the resulting adapter library. Include `current.build`
through the explicit path variable; it selects generated SML without running
commands:

```sh
bin/rune --library sdl --build examples/sdl/hello.build \
  --path SDL_GENERATED=build/ffi-generated/sdl -o build/sdl-hello.rbc
bin/runevm build/sdl-hello.rbc /absolute/path/libSDL3.so.0 /absolute/path/shims.so
```

Use the smoke entrypoint `tests/ffi/sdl/smoke.build` in the same way. Run it with
`SDL_VIDEODRIVER=dummy` for automated event/software-rendering checks, and
without that override for desktop GUI checks. The same smoke source runs on
native Windows. Regeneration must include the complete command above: changing
only the sidecar without replacing stale generated metadata is not acceptance.

For Windows, select `windows-x86.json` or `windows-x86_64.json`; use the pinned
SDK `um`, `shared`, `ucrt` and MSVC include roots recorded in
`ffi/win32/source.json`, plus `ffi/sdl/upstream`. Generate each width separately.
Compile adapters with the corresponding target C compiler and
`-DSDL_MAIN_HANDLED=1`; upstream's `SDL_main.h` otherwise injects a C entrypoint.
This definition leaves the original header untouched. SDL itself can be built
with a CMake cross toolchain that specifies **both** its C and C++ compilers
and resource compiler. The verified dependency build disabled `SDL_AUDIO`,
`SDL_GPU`, `SDL_TESTS` and `SDL_EXAMPLES`, and enabled shared-library installation.
The Windows64 compiler identities were GCC/G++ 13 win32 and CMake 3.28.3.

## Behavioral boundaries

The owning VM thread runs startup, video, event pumping and rendering.
`SDL_SetMainReady` precedes initialization; SDL's rewritten C `main`,
`SDL_RunApp` and foreign-thread callbacks are outside this delivery.
`SDL.load` names SDL and its generated adapter library; it prepares native
resource destructors before allocating public resources.

Window renderers retain their window, software renderers retain their surface,
and textures retain their renderer. Close children before parents. Locked or
borrowed resources reject destruction, and live resources reject shutdown.
Owned clipboard text is copied and freed before returning. Borrowed event text
is copied before subsequent SDL event operations. Text pushed through SML is
retained until consumption or shutdown; raw event filtering/removal can defer
its reclamation until shutdown.

The event datatype preserves common window, keyboard, text and mouse events;
other kinds retain their numeric identity through `Unknown` and complete data
remains available through raw access. Pixels expose copied pitched rows for
uncompressed SDL formats. FourCC, YUV and compressed extents need explicit raw
policy; the public scope rejects them. Debug text uses SDL's built-in ASCII
font. Font shaping and arbitrary Unicode glyph rendering are outside the
agreed inventory. Tests compare semantic fields, ownership and drawing effects;
they do not require identical OS event streams or pixels.

See [the dated evidence](../../tests/ffi/evidence/m7.md) for results and open gates.

## Win32 SDL provider support

The required core inventory remains 53 functions. The Win32 GUI provider adds
`SDL_SetWindowPosition`, `SDL_SetHint` and `SDL_SetRenderClipRect`; the additional selections and
constants are listed in `ffi/sdl/support.json`. Select every listed constant
with the generator's `--constant NAME` option as well as the core command above.
`make test-win32-sdl-driver` performs the complete explicit generation, compiles
an independent C constant oracle and field adapters, and runs the driver on both
interpreters under collection stress and both JIT modes. Its GUI tier is
`make test-win32-sdl-driver-gui` with desktop access.

Compile the thin driver with `--library ffi/win32/sdldriver` and
`ffi/win32/sdl-driver.build`, supplying the same `SDL_GENERATED` path variable.
That entrypoint exposes `Win32SdlDriver`, including `load` and `shutdown`
controls, for the common Win32 model. The shared model owns classes, window
procedures, timers, queue filtering and GDI object lifetime. This split keeps
those semantics identical between SDL and mocks.

# One Win32 application, three implementations

`app.sml` uses only the public `WIN32` signature. The native, SDL3 and mock
entrypoints select the implementation through the existing `.build` virtual
module mechanism. Each entrypoint owns startup and shutdown; application
window procedures, drawing and message dispatch remain identical.

Build the deterministic version from the repository root:

```sh
bin/rune --library ffi/win32/mock --build examples/win32/mock.build -o build/win32-mock.rbc
bin/runevm build/win32-mock.rbc
```

The SDL3 version needs the generated core binding and field-access shim described
in [the SDL guide](../../docs/ffi/sdl.md). `SDL_GENERATED` names the generation
output directory, containing `current.build`:

```sh
bin/rune --library ffi/win32/sdldriver --library ffi/win32/model \
  --build examples/win32/sdl.build --path SDL_GENERATED="$PWD/build/ffi-generated/sdl" \
  -o build/win32-sdl.rbc
bin/runevm build/win32-sdl.rbc /path/to/libSDL3.so.0 /path/to/shims.so
```

The native version uses the generated binding for the matching Windows ABI:

```sh
bin/rune --library ffi/win32/native --build examples/win32/native.build \
  --path WIN32_GENERATED="$PWD/build/ffi-generated/win32-64" -o build/win32-native.rbc
RUNE_WIN32_ADAPTER_LIBRARY='C:\path\to\shims.dll' bin/runevm.exe build/win32-native.rbc
```

Pass `--smoke` to either GUI version to close automatically after three timer
events. Otherwise close the window or press Escape. The mock always uses the
bounded smoke path. Cleanup runs before the success marker, including when a
window procedure or a drawing body raises an exception.

`ffi/win32/{native,sdl,mock}.build` each implement virtual structure `Win32`.
Generation and shim compilation are explicit commands, outside `.build` files.
Select the relevant libraries on the compiler command line as shown above.
The SDL provider keeps its load/shutdown controls in `Win32SdlDriver`; the native
provider closes its dynamic session with `Win32Native.close()`.

The shared behavior suite is `tests/ffi/win32/contract.sml`. Run the SDL suite
with `make test-win32-sdl-contract` and its real GUI counterpart with
`make test-win32-sdl-contract-gui`. `make test-win32-app-sdl` and
`make test-win32-app-sdl-gui` regenerate, compile and run this application in
both bytecodes with collection stress and both JIT tiers.

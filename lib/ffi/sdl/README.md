# Generated SDL target sources

`generated/native`, `generated/windows32` and `generated/windows64` contain
complete immutable Runeffi source sets for SDL 3.4.18: 53 core functions,
three Win32-provider support functions, five layouts, 69 constants and three
typed field adapters. `current.build` selects each content-addressed set.
The public facade remains the short library `sdl` under `lib/sdl`.

Regenerate explicitly with `make sdl-generated`; verify without writing with
`make check-sdl-generated`. Both require the pinned Windows SDK/MSVC roots
documented in `ffi/win32/README.md`, plus the native C standard include roots.
The SML coordinator records its compiler/include queries and every generator
argument vector and verifies all vendored SDL originals against `source.json`.
To check one target, run `bin/runevm bin/rune-sdl-generated.rbc check native`
(or `windows32`/`windows64`).

Select a target with the existing explicit `.build` variable, for example
`--path SDL_GENERATED="$PWD/lib/ffi/sdl/generated/native"`. Generation and
native compilation never execute inside `.build`. Compile the selected set's
`shims.c` separately with the original headers and `SDL_MAIN_HANDLED=1`; no
native DLL, object file, compiler cache or generated `MANIFEST` is committed.
See `docs/ffi/sdl.md` and the dated `tests/ffi/evidence/sdl-generated.md` receipt.

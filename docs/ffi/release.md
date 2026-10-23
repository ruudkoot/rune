# Provisioning and installing Runeffi

Runeffi is built by `make runeffi` and included in `make all`. The generator is
Standard ML; libffi is needed by generated calls in the VM, not by preprocessing
or generation. Builds with `FFI=no` preserve the generator and reject dynamic
calls through the existing unsupported-feature result.

## Pinned dependencies

`ffi/libffi/source.json` pins libffi 3.4.6 and `ffi/sdl/source.json` pins SDL
3.4.18. Their original release archives are verified with SHA256 before any
source is extracted. Use the existing native SML bootstrap tool:

```sh
make ffi-libffi ffi-sdl JOBS=2
make vm FFI=yes FFI_PREFIX=build/deps/libffi/native/install
make ffi-libffi-windows32 ffi-libffi-windows64 JOBS=2
make ffi-sdl-windows32 ffi-sdl-windows64 JOBS=2
make windows FFI_WIN32_PREFIX=build/deps/libffi-win32/install \
  FFI_WIN64_PREFIX=build/deps/libffi-win64/install
```

For an offline build, put the pinned archives under `build/deps/downloads`, or
supply `--archive` explicitly:

```sh
make ffi-libffi FFI_DEPS_OPTIONS=--offline
bin/rune-build build-ffi sdl --offline --archive /cache/SDL3-3.4.18.tar.gz
bin/rune-build build-ffi sdl --offline --verify-only
```

A separate headless SDL profile supports CI without desktop development
packages or a display server. Its provenance records `headless: true`; it does
not establish GUI acceptance:

```sh
make ffi-sdl FFI_DEPS_OPTIONS=--headless JOBS=2
RUNE_SDL_NATIVE_LIBRARY="$PWD/build/deps/sdl/headless/install/lib/libSDL3.so.0" \
  make test-sdl test-win32-sdl-driver test-win32-sdl-contract test-win32-app-sdl JOBS=2
```

The tool invokes existing C/C++ compilers, CMake, Make, gzip and tar. It installs
no system packages. SDL builds omit audio and GPU APIs and the optional X11
screen-saver extension, which the delivered inventory does not use. Available
video/render backends are recorded by SDL's retained CMake logs. A real GUI
still requires the platform's window system and supported video driver.

Every prefix contains `rune-ffi-dependency.json`: source and recipe digests,
toolchain identities, commands, installed-file hashes, symlinks and probe
results. Native probes execute libffi scalar calls or SDL software rendering;
cross probes are compiled and mark execution outstanding. Upstream test suites
are not implied by successful provisioning. Build, install and probe failures
leave an existing prefix intact; `--verify-only` rejects stale or modified
prefixes without replacing them.
An existing nonempty prefix needs its matching ownership record. Unrecorded
files, links or directories are preserved and cause refusal before rebuilding;
known owned outputs may be repaired. Effective compiler/linker flags are part
of cache identity, so changing `CFLAGS`, `CPPFLAGS` or `LDFLAGS` invalidates reuse.

## Installation and distribution

`make install PREFIX=...` installs `runeffi` when built, the ordinary sealed
libraries, and original headers, profiles and sidecars under
`lib/rune/ffi-assets`. `make dist` includes the same generator bytecode and
assets in Linux and Windows archives; their installers create a `runeffi`
launcher (`runeffi.cmd` on Windows). Paths are resolved relative to the launcher,
so an installation can move. Generation still takes explicit `--config`,
`--target`, `--include` and output paths; installation never runs a generator,
opens a native library or compiles an application shim automatically.

Original Win32 SDK headers remain externally acquired under their redistribution
terms. Follow the pinned acquisition/provenance instructions under
`ffi-assets/win32`; installation does not imply that the Windows SDK was vendored.
SDL/library DLLs and generated shims remain explicit application deployment
dependencies. In particular, a runtime built without FFI does not gain the
capability by receiving generator bytecode or SDL3.

Runtime relinking material records the selected libffi provider. A pinned static
prefix carries headers, archive, notices, provenance and source archive and is
validated again before relinking after relocation. System libffi is an external
development dependency with unknown source/build provenance. Existing GMP
provisioning retains its separate role.
The installed `runeopt` runtime also carries the selected static archive;
`@RUNTIME@/libffi.a` link metadata resolves relative to its new runtime directory
before quoting, preserving existing native-code dynamic calls after relocation.

## Interactive use

`RuneForeign` is part of the Basis available at the REPL. For a scalar fixture:

```sml
val library = RuneForeign.openLibrary "/absolute/path/to/fixture.so";
val symbol = RuneForeign.symbol (library, "gen_add");
val call = RuneForeign.prepare {symbol=symbol, abi=0,
  result=RuneForeign.SInt32, arguments=[RuneForeign.SInt32,RuneForeign.SInt32]};
val result = RuneForeign.invoke (call,
  [RuneForeign.Signed (Int64.fromInt 20), RuneForeign.Signed (Int64.fromInt 22)]);
val () = List.app RuneForeign.release [call,symbol,library];
```

This uses `tests/ffi/generator/scalars.c`, compiled as a shared library. The
generated scalar binding also works through existing source loading. After
generating the scalar fixture as in [generation](generation.md), pass these
files to `rune-repl --no-init` in order (or `use` each from the prompt):

1. `lib/ffi/marshal/bytes_sig.sml`, then `bytes.sml`.
2. `lib/ffi/runtime/generated_sig.sml`, then `generated.sml`.
3. The immutable generated set's `raw_sig.sml`, `raw.sml`, `public_sig.sml`,
   and `public.sml`.

Then `GeneratedScalars.openSession {libraries=[absoluteLibraryPath]}`,
`GeneratedScalars.add session {first=20,second=22}` and
`GeneratedScalars.closeSession session` produce 42 and release the native
session. The generated `current.build` describes the same source order
for compiler builds; it is not an executable command or a new REPL directive.
An interactive session must retain the owning library/session while symbols,
prepared calls, buffers or callbacks are in use. Close public resources before
unloading; reload the provider to resolve native libraries again. Native
resources cannot be persisted in portable images. See [runtime lifecycle
rules](runtime.md) for callbacks, image operations, unloading and VM-thread entry.

The shared Win32 GUI example and separate provider entrypoints are documented in
[examples/win32](../../examples/win32/README.md); SDL startup and generation
commands are in [the SDL guide](sdl.md). Capability and platform acceptance must
be read with their dated receipts; a cross build is not a native GUI test.

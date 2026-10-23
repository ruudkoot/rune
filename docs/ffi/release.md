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
results. Libffi admission executes scalar calls, an aggregate result, and a
closure invoked through a function pointer; SDL admission executes software
rendering. The Linux32, AArch64 and big-endian PowerPC64 profiles execute their
probes using native32 processes or explicit QEMU runners. Windows provisioning
without an explicit runner records execution as outstanding; the separate
Windows acceptance suites establish actual execution. See
[Linux portability](portability.md) for target provisioning and generic SML
acceptance commands. Upstream test suites
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
Complete generated source sets, typed C shims and provenance are installed
under `lib/rune/ffi/sdl/generated` and `lib/rune/ffi/win32/generated`.
Win32 sets are not duplicated under `ffi-assets`; that directory contains
the original-input manifests, policy and provider build fragments.

The Windows archive installer requires PowerShell for a read-only path
preflight, including with `--no-register`. Before creating the target prefix,
it checks the extracted archive and mapped installation paths: file paths
must be shorter than 260 UTF-16 code units and directory paths at most 248.
Enumeration errors and unavailable PowerShell also reject before installation.
Choose short extraction and installation paths; the installer does not enable
Windows long-path registry settings. These bounds follow the legacy
[Windows shell/file API limits](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation?tabs=powershell).

For the existing Windows compiler's `.build` handling, use relative paths with
forward slashes and run from the example directory. Drive-qualified absolute
project and virtual-module paths are not supported by that path resolver.
The [installed-example receipt](../../tests/ffi/evidence/installed-examples.md)
records the prior working layout. With the canonical library layout, pass
`WIN32_GENERATED` as a relative path from the selected `ffi-assets/win32`
build fragment to the installed `ffi/win32/generated/32` (or `64`) set.
The application and provider build fragments remain ordinary unchanged sources.
The [canonical-library acceptance](../../tests/ffi/evidence/win32-canonical.md)
records the current installed paths and actual native execution at both widths.
Windows launchers can run after moving an installation. Its legacy uninstall
manifest records absolute installation-time filenames: restore the original
prefix before uninstalling. Uninstall rejects a moved or out-of-prefix
manifest before changing registration or removing installed files; PowerShell
is required for that validation too.

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
generated scalar binding also works through existing source loading. Generated
public structures include ownership, scope, memory and text helpers even for
scalar-only declarations. Derive the complete non-Basis dependency order with
the compiler after [generation](generation.md):

```sh
runeffi_set="$PWD/build/ffi-generated/scalars/sets/SET_IDENTIFIER"
bin/rune --lib "$PWD/lib" --library ffi/runtime --basis-deps \
  "$runeffi_set/raw_sig.sml" "$runeffi_set/raw.sml" \
  "$runeffi_set/public_sig.sml" "$runeffi_set/public.sml"
```

With an absolute `--lib`, this prints Basis filenames followed by absolute
non-Basis source paths in dependency order. The REPL image already provides
the Basis. Pass the non-Basis paths, followed by the generated files, to
`rune-repl --no-init` in that order (or `use` each from the prompt). The current
scalar projection needs these 14 support files:

1. `lib/unicode/utf8_sig.sml`, then `utf8.sml`.
2. `lib/ffi/marshal/scope_sig.sml`, `scope.sml`, `bytes_sig.sml`, `bytes.sml`,
   `text_sig.sml`, then `text.sml`.
3. `lib/ffi/runtime/owner_sig.sml`, `owner.sml`, `memory_sig.sml`, `memory.sml`,
   `generated_sig.sml`, then `generated.sml`.
4. The immutable generated set's `raw_sig.sml`, `raw.sml`, `public_sig.sml`,
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

`make test-ffi-repl` regenerates the current scalar fixture, compiles its C
subject, obtains that dependency order through `--basis-deps`, and loads the
ordinary source files into the existing REPL. Public and raw native sessions
remain live across later declarations and full collection. Both return 42,
raw status bytes remain available, and closing both sessions must leave zero
native resources. `RUNE_REPL_IMAGE`, `RUNEVM`, `RUNE`, `RUNE_LIB` and
`RUNEFFI_BYTECODE` can select compatible frozen artifacts; exact inputs and
commands are retained with [the acceptance receipt](../../tests/ffi/evidence/scalar-repl.md).

The shared Win32 GUI example and separate provider entrypoints are documented in
[examples/win32](../../examples/win32/README.md); SDL startup and generation
commands are in [the SDL guide](sdl.md). Capability and platform acceptance must
be read with their dated receipts; a cross build is not a native GUI test.

The SDL guide also documents a [provider-specific REPL acceptance
command](sdl.md#existing-repl-source-loading). It creates real windows in two
sessions, retains each window/renderer across later declarations and full
collection, draws afterward and releases every native resource. This exercises
the generated SDL provider beyond the generic scalar REPL bridge.

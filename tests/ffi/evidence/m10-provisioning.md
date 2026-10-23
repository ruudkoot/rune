# M10 provisioning, packaging and interactive acceptance

Final current-artifact source/archive installation, runtime relocation and
actual Windows32/64 installer acceptance are recorded in
[final-packaging.md](final-packaging.md). The historical component results
and unavailable checks below describe their original runs.

Date: 2026-10-23. This is component evidence, not completion of M10. Global
regression, host/bootstrap/platform and performance gates remain separately
owned and must be read with the final capability matrix.

## Implemented artifacts

`tools/builder/ffi-deps.sml` adds `rune-build build-ffi libffi|sdl`, shared by the
native MLton bootstrap and Rune bytecode. It reads the committed original-source
manifests, verifies pinned SHA256 archives before contained-path extraction,
records toolchain/command/output identities, compiles native/cross probes and
publishes prefixes after successful build/install/probe compilation. Failed
commands preserve a previous prefix. Offline/download-only/verify-only paths
make acquisition and cache use explicit. Upstream tests remain explicitly not
run; native probes are separate independent ABI/rendering checks.

`FFI_PREFIX` selects a native static libffi archive, with header/archive metadata
prerequisites in the Make graph. The existing separate Windows prefixes remain.
Runtime records retain selected-prefix headers/archive/provenance/notices/source
archive and validate/relocate them before relinking. System libffi remains an
external development dependency with unknown source/build provenance.

Source installation and Linux/Windows archives carry `runeffi.rbc` plus original
headers, sidecars, ABI profiles and provider `.build` entrypoints under
`lib/rune/ffi-assets`. The archive installers create relative runeffi launchers;
Windows has `runeffi.cmd`. Generation and native shim compilation stay explicit.

## Commands and results

The host was Linux x86-64, GCC/G++ 13.3.0, CMake 3.28.3 and native MLton
20241230 (compiler SHA256
`b585f5ac0e96ae9da265673b796b583e4adf6870ef2d7c5c5fda9d8c158e24b3`).
Windows dependencies used MinGW GCC/G++ 13-win32 for i686 and x86-64.
Archive identities are the committed `ffi/{libffi,sdl}/source.json` SHA256 values:
libffi 3.4.6 `b0dea9df23c863a7a50e825440f3ebffabd65df1497108e5d437747843895a4e`;
SDL 3.4.18 `9c75cf16330322c217dedd2e0609f1124f1b54b8633e763467b4684d0f4334a3`.
All provisioning below used already cached archives; no packages were installed.

- Native MLton bootstrap and Rune bytecode builds of the complete builder pass.
- `bin/rune-build.bin build-ffi libffi --offline --archive CACHE/libffi-3.4.6.tar.gz
  --jobs 2` builds the static archive and executes an independently compiled
  `ffi_prep_cif`/`ffi_call` sum probe: **pass**. `--verify-only` verifies reuse.
- The equivalent SDL command builds the shared library and executes an independent
  event initialization/surface/software-renderer clear/present probe: **pass**.
  Final current-binary build log: `/tmp/runeffi-provision-sdl-final-current.log`.
  `--verify-only` verifies reuse with all installed-file hashes and symlinks.
- Both commands with `--target windows32` and `--target windows64` build pinned
  target outputs and compile their C probes. Provisioning metadata honestly marks
  execution outstanding at build time. libffi's two probes were then executed
  on actual Windows from an owned temporary staging directory: **both exit 0**.
  SDL software-render probes were also executed with each newly built matching
  DLL on actual Windows: **both exit 0**; supplemental commands, statuses and
  DLL digests are in `build/ffi-provision-windows-sdl.json`.
- `tests/ffi/provision/model.sml`: **17/17 checks**, including escaped/absolute
  archive paths and links, unsupported archive entries, offline cache checksum
  failure, no-download paths and transactional publication rollback. Collection
  stress 7/heap verification also passes.
- A pre-host Make dry run with both `GMP=yes` and `FFI=yes` pointing to absent
  prefixes reaches the explicit dependency recipe without target configuration.
  Native-prefix selection chooses the static archive/include flags and retains
  header/archive/provenance prerequisites.
- Repository `ffi/dependency-model` tier: **6/6**, including five runner canaries;
  `tests/out/ffi-deps-run/20261023-093125-8`.
- New distribution fixture checks generator bytes, original header/sidecar bytes,
  Windows launcher, relative Linux launcher, installation into a path with spaces
  and uninstall preserving an unrelated file: **7/7**, including producer and
  five canaries; `tests/out/ffi-dist-run/20261023-093237-12`.
- `tests/ffi/provision/relink.c` uses a real static libffi call. Runtime material
  built from it relinks after relocation to `build/ffi-package/relocated material`
  and returns **42**. Three planted tamper checks reject a changed prefix header
  before verification/package publication and a changed retained header before
  relinking, leaving rejected output paths absent.
- Actual source installation uses the frozen M7 VM/compiler/REPL artifacts with
  their matching runtime version header/build record. After relocation into
  `build/ffi-install/relocated tree`, the installed generator runs `--help` and
  regenerates all **56** SDL declarations from installed original headers; the
  installed REPL calls `RuneForeign.available()`; the packaged bytecode relinker
  builds an actual VM whose `--version` succeeds; uninstall removes owned files
  and preserves an unrelated marker. **All pass**; commands/statuses are retained
  in `build/ffi-install/report.json`. This is distinct from the final integrated
  VM/image release gate.
- A generated scalar public binding is loaded by the existing REPL file-argument
  mechanism (ForeignBytes, ForeignGenerated, then generated raw/public sources).
  `GeneratedScalars.add session {first=20,second=22}` returns **42**; closing the
  session leaves `RuneForeign.live()=0w0`. Frozen REPL image SHA256:
  `b3b84062d464a4906c29b5d3788c6a88220983c783c51f435f1d32d314b1f9bd`.
- Documentation consistency: **11/11**, 35.1 seconds,
  `tests/out/ffi-release-docs/20261023-093638-8`.

## Corrected failures and outstanding checks

The first SDL configure refused absent optional XScreenSaver headers. The recipe
now disables that unused extension; no system package was installed. An initial
probe omitted the separate `SDL_main.h` declaration for `SDL_SetMainReady`;
including the original header repaired the probe. Failed prefixes were never
published. One archive-link fixture initially raised an unhelpful path exception;
absolute links are now rejected before path concatenation with a source name.

Initial scoped runner attempts lacked the separate scenarios helper, or collided
when independent sandbox PID namespaces produced the same run ID in the same
second. Those failures are retained separately; final runs use explicit distinct
`--out` roots. A canary-only run caused by the unsupported `--jobs` spelling is
not counted as component acceptance; the actual runs use `-j`.

Windows-hosted generator/installer execution, the new integrated VM/image
installation, upstream dependency suites, other host provisioning environments
and global portability/bootstrap/regression/performance acceptance are not
inferred from these component checks. Windows generator checks are owned by the
generator component. The Win32 application's final GUI collection-stress timeout
is recorded separately in `m9-sdl-driver.md` and remains outstanding.

## Prefix ownership, effective flags and headless profile follow-up

Review identified that a nonempty unrelated `--prefix` could be replaced and
that inherited build flags were missing from cache identity. Follow-up checks
run before reuse/build and again on the staged and renamed old directory at
publication. Nonempty prefixes need matching project/target/recorded-prefix
ownership. Every file, link and directory must be recorded or an inventory
parent; extra entries are preserved with a clear refusal. Modified bytes in
known owned outputs remain eligible for rebuilding. Effective allowlisted
compiler/linker/tool flags distinguish unset from empty in cache identity;
inherited Make jobserver flags are cleared rather than recorded wholesale.

The model suite now passes **29/29** with collection stress 7/heap verification.
It covers unowned-prefix refusal, unrecorded file/link preservation, prefix
identity mismatch, modified owned bytes, rollback and compiler flag identity.
The repository job passes **6/6** including canaries at
`tests/out/ffi-prefix-guard/20261023-100242-9`. Five actual CLI cases verify fresh
reuse, CFLAGS invalidation, unrecorded link/file preservation and unowned-prefix
refusal; `build/ffi-prefix-guard-receipts.json` retains statuses and diagnostics.
Native MLton compiles the follow-up tool. An existing owned libffi prefix was
rebuilt successfully through the new ownership checks and native call probe.

A separate `--headless` native SDL profile records its role and uses
`build/deps/sdl/headless/install`. It excludes X11/Wayland/KMS, OpenGL/Vulkan and
optional device integrations while retaining dummy/offscreen/software rendering.
SDL's documented `SDL_UNIX_CONSOLE_BUILD=ON` explicitly admits this intentional
configuration; an initial configure without that flag was refused and did not
publish a prefix. The headless profile is intended for bounded CI smoke tests,
not GUI acceptance; its build/behavior receipts are tracked separately.

### Headless and relocated native-code receipts

The final explicit headless SDL build passes its native software-render probe.
Its library SHA256 is
`3696a490148c6f4967ec513aa5e0ca84b573e64c6e9a54be2318cb676a4ef648`.
The selected repository run covers core SDL, the Win32 SDL driver (including
failed initialization), the shared Win32 contract and the same application,
plus five runner canaries: **10/10 pass**, 356.3 seconds wall at two workers,
`tests/out/ffi-headless/20261023-101144-8`. Each helper covers stack/register
collection stress 7/heap verification and baseline/optimizing JIT. The headless
profile does not replace the separate real GUI evidence. Final current-binary
owned-libffi rebuild and fresh-versus-CFLAGS-change cache checks also pass.

Review also found that copying a static `FFI_PREFIX` path verbatim into installed
`runeopt` link metadata would retain the source location. The package now emits
`native-foreign-libs` with `@RUNTIME@/libffi.a`; installation copies the verified
archive beside `librune.a`, and `runeopt` resolves the token before shell quoting.
The package fixture confirms `@RUNTIME@/libffi.a -ldl` is emitted. A new compiler
build then translates `tests/ffi/provision/native.sml` after its runtime/archive
was moved to `build/ffi-native-relocation/relocated runtime`. The resulting
actual native executable loads the independent `gen_add` C subject, returns
**42**, releases all native resources and prints **PASS**. This proves the
existing native execution path with a relocated static libffi dependency;
future direct linking remains deferred.

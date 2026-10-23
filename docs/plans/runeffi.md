# Runeffi: an implementation roadmap

Give a Rune program an ordinary Standard ML signature for a foreign API.
Generate the signatures and native implementations from the API's original
description, keeping additional binding policy in separate `.ffi` files.
The same signature can have a native implementation, an implementation in
SML over another library, or a deterministic mock, selected by `.build`.

Written on 2026-10-22 against
`c3e713891e6ea9f32770371427fdfa5f76369255`. This document records the agreed
design and its original baseline. The implementation and executed checks
are recorded in the status table and dated evidence below. All milestones
started **planned**; the status table and dated acceptance evidence record
implementation progress separately from this original design baseline.

## Status and requirements

| Milestone | Depends on | State |
|---|---|---|
| M0: contracts, inventories and baseline | none | complete |
| M1: reusable C frontend | M0 | complete |
| M2: binding model and sidecars | M1 | complete |
| M3: generic dynamic calls | M0 | complete |
| M4: layout, marshalling and generated shims | M2, M3 | complete |
| M5: callbacks and VM lifecycle | M3, M4 | complete |
| M6: generator and build integration | M2, M3, M4, M5 | complete |
| M7: core SDL3 bindings | M6 | complete |
| M8: native Win32 GUI bindings | M6 | complete |
| M9: Win32 over SDL3 and mocks | M7, M8 | complete |
| M10: portability and release acceptance | M7, M8, M9 | complete |

M1/M2 and M3 can progress independently after M0; M7 and M8 can progress
independently after M6. Complete and commit each milestone with its evidence
before declaring it done. A failed or unavailable completion gate leaves
that part outstanding. Additions to a delivered inventory are explicit
roadmap changes, with their tests and dependencies.

Delivery acceptance on 2026-10-23 is recorded in the
[integrated release evidence](../../tests/ffi/evidence/release.md). It links
each milestone to its artifacts, commands and results, preserving earlier
failed runs and known host/platform limitations. Remote CI and production
binary-distribution checks keep their separately stated status.

The original brief is accounted for as follows:

| Requirement | Delivery |
|---|---|
| Ordinary SML97 signatures, natural to SML users and recognisable to users of the foreign API | projection rules and raw access; M0, M2, M6 |
| Several implementations of a signature through `.build` virtual modules | shared Win32 contract and native/SDL/mock builds; M0, M6, M9 |
| Minimal runtime changes and a small complete set of generic operations, independent of each bound API | runtime boundary; M3, M4, M5 |
| Keep existing GMP bindings as primitives | runtime boundary and regression checks; M3, M10 |
| Support different foreign interface families over time | extensible binding model; M2; future work below |
| Consume unmodified original descriptions and put annotations in adjacent `.ffi` files | input provenance and sidecars; M0, M1, M2 |
| Keep original sources in the repository where possible | `ffi/` source policy; M0, M10; pinned acquisition is the agreed fallback |
| Generate marked SML signatures and structures under `lib/ffi/` | output ownership; M6 |
| Deliver SDL bindings | the core SDL3 inventory; M7 |
| Deliver basic Win32 kernel/user/GDI bindings and a real Windows GUI example | the Win32 inventory; M8 |
| Run the same Win32 application on Linux using SDL | shared application and SDL implementation; M9 |
| Supply mocks for testing Win32 clients | deterministic SML implementation and shared contract tests; M9 |
| Integrate platform selection and generation with Rune's build system | existing build syntax and generation dependencies; M6 |
| Research literature and existing implementations, including local references | research below; executable design comparisons in M0 |
| Put the C parser and other reusable facilities in separate SML libraries | architecture and library boundaries; M1, M2, M4 |
| Dynamically load Win32 calls and support the REPL | dynamic calls and resource lifecycle; M3, M5, M8, M10 |
| Keep WebAssembly and future native Windows import linking in mind without delivering them here | backend separation and future work below |

## What exists at the baseline

The [architecture](../architecture.md), [runtime](../runtime.md),
[build system](../build.md), [units](../units.md), and
[native execution](../native.md) describe the current implementation.

* `.build` already has `implements`, and SML has `_virtual` and `_export`.
  A client can compile against a signature independently of the chosen
  implementation. The virtual bigint example demonstrates the mechanism.
* The runtime has GC root handles (`vm_handle_new/get/free`) and
  `vm_pin`/`vm_unpin` for stable access to byte and real arrays. A pin may
  be a copy with copy-back; it is not a general promise of shared memory.
  The [heap-layout roadmap](heap-layout.md) records their implementation.
* The register VM and stack VM share primitives, the heap and system layer.
  The register VM has interpretation and JIT tiers; `runeopt` already makes
  native executables from stack bytecode on Linux/x86-64. Future native
  register-code generation and Windows import linking are separate work.
* The [register runtime's C transition](../../runtime/register/README.md#calls-into-c-the-transition-and-the-ffis)
  synchronises VM state and reloads it after a call. It explicitly does not
  permit an ordinary helper to run bytecode. Callbacks need a new, bounded
  entry protocol; libffi closures alone do not supply it.
* Ordinary libraries cannot declare `_prim`. A trusted Basis-level bridge
  must expose the generic operations to `lib/ffi`; generated bindings must
  not work around the library boundary with per-function primitives.
* There is no general FFI, `runeffi` executable, C frontend, or SDL/Win32
  binding library in this baseline. Existing system primitives and GMP
  arithmetic are not a partial implementation of this generator.

These are source observations, not new validation results. M0 records
versions, commands and measurements for the implementation work.

## Delivery boundary and inventories

The delivered foreign language is C: declarations, data representations,
calling conventions, callbacks, and the header constructs needed by the
following inventories. The frontend is reusable, but this is not a project
to compile arbitrary C programs. C++, Java, WebAssembly, COM, and arbitrary
Windows SDK coverage are outside this delivery.

M0 turns the inventories below into checked manifests containing each
selected declaration, its transitive type dependencies, constants, source
location, projection, ownership/error policy, platform and tests. An entry
is complete only when its implementation, documentation and tests agree.
Dependencies that are parsed do not silently become exported bindings.

### Core SDL3

Pin one SDL3 release containing these APIs, with exact source hashes and
runtime compatibility requirements. The following is the minimum selected
surface, not a claim to cover every member of these SDL subsystems:

| Area | Selected native declarations and behavior |
|---|---|
| Startup and errors | `SDL_SetMainReady`, `SDL_Init`, `SDL_InitSubSystem`, `SDL_QuitSubSystem`, `SDL_Quit`, `SDL_GetError`, `SDL_ClearError`, `SDL_free` |
| Windows | `SDL_CreateWindow`, `SDL_DestroyWindow`, `SDL_GetWindowID`, `SDL_SetWindowTitle`, `SDL_GetWindowSize`, `SDL_SetWindowSize`, `SDL_ShowWindow`, `SDL_HideWindow` |
| Events | `SDL_PollEvent`, `SDL_WaitEvent`, `SDL_WaitEventTimeout`, `SDL_PushEvent`; tagged decoding of quit, window, key, mouse and text-input events, preserving unknown event identifiers |
| Input | `SDL_GetKeyboardState`, `SDL_GetMouseState`, `SDL_StartTextInput`, `SDL_StopTextInput`; copied keyboard state, key modifiers, mouse coordinates/buttons and UTF-8 text |
| Surfaces | `SDL_CreateSurface`, `SDL_DestroySurface`, `SDL_LockSurface`, `SDL_UnlockSurface`, `SDL_FillSurfaceRect`, `SDL_BlitSurface`; pitch, format, dimensions and scoped pixel-buffer access |
| 2D rendering | `SDL_CreateRenderer`, `SDL_CreateSoftwareRenderer`, `SDL_DestroyRenderer`, `SDL_SetRenderDrawColor`, `SDL_RenderClear`, `SDL_RenderPoint`, `SDL_RenderLine`, `SDL_RenderRect`, `SDL_RenderFillRect`, `SDL_RenderPresent`, `SDL_RenderReadPixels` |
| Textures | `SDL_CreateTextureFromSurface`, `SDL_DestroyTexture`, `SDL_RenderTexture`; explicit renderer/texture lifetime dependencies |
| Text | `SDL_RenderDebugText`, text-input events and window titles; the drawing contract is SDL's fixed ASCII debug font, not a general font system |
| Clipboard | `SDL_HasClipboardText`, `SDL_GetClipboardText`, `SDL_SetClipboardText`; copy and release SDL-owned returned storage |
| Time | `SDL_GetTicks`, `SDL_GetTicksNS`, `SDL_GetPerformanceCounter`, `SDL_GetPerformanceFrequency`, `SDL_Delay` |

SDL video/event operations run on the process's main thread. REPL use is
the external-module case: perform `SDL_SetMainReady` and document that the
embedding process owns platform startup. A standalone example uses that
same supported Linux/Windows path. Full `SDL_RunApp` application-entry
integration is a follow-on, not hidden startup work in a generated value.
See SDL's [nonstandard startup guidance](https://wiki.libsdl.org/SDL3/NonstandardStartup).

The debug font renders ASCII despite accepting UTF-8 input; its limitations
are part of [SDL's documented contract](https://wiki.libsdl.org/SDL3/SDL_RenderDebugText).
Audio, GPU, foreign worker-thread callbacks, timer callbacks, OpenGL/Vulkan,
SDL extensions such as SDL_ttf, and general Unicode font shaping are deferred.

### Win32 kernel/user/GDI GUI subset

Generate native bindings to the explicit wide (`W`) APIs. The shared
idiomatic signature presents SML strings and ordinary SML types; exact
UTF-16 buffers and native pointer operations remain available separately
through raw access. This is a desktop, single-UI-thread contract.

| Area | Minimum native surface |
|---|---|
| Kernel | `GetModuleHandleW`, `GetLastError`, `SetLastError`, `QueryPerformanceCounter`, `QueryPerformanceFrequency` |
| Classes and windows | `RegisterClassExW`, `UnregisterClassW`, `CreateWindowExW`, `DestroyWindow`, `ShowWindow`, `UpdateWindow`, `DefWindowProcW`, `GetClientRect`, `SetWindowTextW` |
| Message loop | `GetMessageW`, `PeekMessageW`, `TranslateMessage`, `DispatchMessageW`, `PostQuitMessage`, `PostMessageW`, `SendMessageW` |
| Painting | `InvalidateRect`, `BeginPaint`, `EndPaint`, `FillRect`; scoped paint contexts and client-coordinate rectangles |
| Timers and input | `SetTimer` with a null timer callback, `KillTimer`; window-procedure delivery of timer, key, character and mouse messages |
| GDI | `CreatePen`, `CreateSolidBrush`, `SelectObject`, `DeleteObject`, `GetStockObject`, `MoveToEx`, `LineTo`, `Rectangle`, `SetTextColor`, `SetBkMode`, `TextOutW` |
| Required data | `WNDCLASSEXW`, `WNDPROC`, `CREATESTRUCTW`, `MSG`, `POINT`, `RECT`, `PAINTSTRUCT`; distinct window, class, module, device-context, pen, brush and GDI-object types |

Include the constants and helper-macro semantics these declarations need:
window/class styles, show commands, peek flags, stock objects, pen and
background modes, message identifiers, mouse/button flags, key modifiers,
pointer-sized message parameters and signed coordinate extraction.
`GetMessageW` has error, quit and message outcomes; a Boolean projection
would lose one. `SelectObject` returns the previous object, whose lifetime
must survive until it is restored. A stock object is borrowed, not owned.

The common application contract covers top-level resizable windows, a
registered window procedure, client painting, keyboard/text/mouse input,
message posting/sending, timers and orderly closure. It includes
`WM_NCCREATE`, `WM_CREATE`, `WM_SIZE`, `WM_PAINT`, `WM_CLOSE`, `WM_DESTROY`,
`WM_NCDESTROY`, `WM_QUIT`, key/button/motion messages, `WM_CHAR`, and
`WM_TIMER`, plus one application-defined message used to test nested sends.
Other native messages reach the native default procedure; the SDL backend
does not invent a full Windows message stream.

`WM_CHAR` retains UTF-16 code-unit semantics, including surrogate pairs.
A separately decoded text convenience must not change the raw message
payload or confuse one code unit with one Unicode scalar value.

Define the creation/closure order, paint invalidation/coalescing, synchronous
`SendMessageW`, asynchronous posting, timer cancellation, selected-object
restoration and stale-handle errors in a shared contract suite. Win32
creation is already a callback boundary: Microsoft documents that
[`WM_CREATE` is sent before the creation call returns](https://learn.microsoft.com/en-us/windows/win32/winmsg/wm-create).
Both Windows widths must exercise that path.

SDL emulation covers the common subset, not pixel-identical Windows
rendering. GDI drawing is limited to solid brushes, basic solid pens,
rectangles/lines, an untransformed client coordinate system, and unrotated
ASCII text with a fixed bitmap font. Requests for other font/glyph or GDI
modes return a documented unsupported result. Unicode scalar text input
and window titles, and SDL clipboard text, remain supported independently
of glyph drawing. Native Windows may provide more; portable tests depend only on
the common behavior. Native-only flags, native pointer-valued message
payloads, child controls, menus, dialogs, printing, arbitrary GDI objects,
cross-thread messages and Windows resource files are deferred.

The example is a small event-and-paint application: resize a window, draw
shapes and an ASCII status line, change state on keyboard/mouse/timer input,
exercise a nested application message, and close without retained native
resources. The same client source runs with native, SDL and mock builds.

## Architecture and interfaces

```text
original headers + target profile       adjacent .ffi policy
                 |                              |
       SML preprocessor/parser                  |
                 |                              |
       C declaration/type model ----------------+
                 |
       binding model + target layout + projection
                 |
             runeffi
                 |
      signatures, native structures, raw structures,
      documentation, build files, manifests, optional C shims
                 |
       ordinary SML foreign-support library
                 |
       trusted generic runtime bridge
                 |
       libffi + dynamic loader + foreign memory
```

SML owns parsing, constant evaluation, layout policy, name/type projection,
ownership annotations, dependency analysis, source maps and generation.
C owns machine calls, executable callback trampolines, native allocation,
and thin VM/system adapters. A new library binding adds descriptions and
generated code, not runtime knowledge of SDL or Win32.

### Source and output ownership

* `ffi/sdl` and `ffi/win32` hold unmodified source snapshots where permitted,
  `.ffi` policy, target profiles and acquisition/provenance manifests.
  Preserve the original filenames and include relationships. Record origin,
  release/commit, exact bytes/checksums, licence, include roots, predefined
  macros and source dependencies. Do not patch upstream headers to parse.
* Microsoft's [Win32 metadata repository](https://github.com/microsoft/win32metadata#licensing)
  distinguishes MIT metadata/tooling from SDK-licensed headers/IDL. A
  metadata licence is not evidence of header redistribution rights. If
  vendoring rights cannot be established, use a pinned installed or
  explicitly acquired Microsoft SDK and commit the acquisition manifest.
  Substitution with metadata or third-party headers is not this design.
* `lib/language/c` holds reusable preprocessing, lexical/syntactic models,
  declaration analysis and constant evaluation. Keep FFI-specific ownership
  and SML naming policy out of it. Reusable target-layout and foreign-memory
  facilities get separate libraries under `lib`, rather than copies in
  each generator backend.
* `lib/ffi` holds shared support; `lib/ffi/sdl` and `lib/ffi/win32` hold
  binding libraries. Separate generated native/raw code from handwritten
  SML emulation and mocks. Every generated file is marked with its
  generator/schema and must not be edited by hand. Immutable output sets retain
  input/target identities, per-member source maps and artifact hashes;
  their documentation and generation targets give regeneration commands.
  Shared signature text remains stable across implementation-only changes.
* Check in reproducible binding SML and review its changes. Build optional
  shim binaries in target-specific build directories; do not commit them.
  Rune's ordinary library `MANIFEST` remains generated and uncommitted.
  The FFI provenance/capability manifest is a different, versioned artifact.
* Keep `ffi/webidl` as the documented future source location. This roadmap
  neither creates unused Web IDL scaffolding nor implements a Wasm backend.

No successful build depends on a developer's absolute reference-tree path.
Generator tests use repository fixtures and provisioned, hashed sources.

### The SML surface

The public surface is ordinary SML97. Each foreign library exposes a
documented signature and ascribed structures. Use lower-camel SML names
with a source mapping, labelled records for large argument sets, tuples or
records for returned output parameters, `option` for genuine nullability,
fixed-width numeric types where the foreign API fixes widths, and abstract
types for resources. Do not replace a flags set with a closed datatype
that loses unknown bits. Do not infer ownership or failure from a pointer
type alone.

The shared `WIN32` signature owns the type declarations its three
implementations must share. Client-visible types must not acquire new
identities when an implementation changes. Use a common type module and
explicit sharing/ascription, with representations hidden from clients.
The native implementation maps logical resources to native handles; SDL
and mocks map them to their own state. Pointers are not fabricated to make
an emulator look native.

The original design sketch below illustrates SML projection choices. The
delivered API uses the [WIN32 signature](../../lib/ffi/win32/common/win32_sig.sml)
and [shared types](../../lib/ffi/win32/common/types_sig.sml), documented in
[the implementation contract](../ffi/contracts.md):

```sml
type window
type message
type paint
val getClientRect : window -> {left : int, top : int,
                              right : int, bottom : int}
val setWindowText : window * string -> unit
val postMessage : window * message -> unit
val sendMessage : window * message -> Int64.int
val withPaint : window -> (paint -> 'a) -> 'a
```

Output conversion checks ranges on the target; host `int` width never
determines a C layout. Scope paint contexts dynamically so escaped or
already-ended contexts fail predictably. Preserve significant distinctions
such as borrowed stock objects versus owned created objects.

The separate `SDLGeneratedRaw` and `Win32GeneratedRaw` structures preserve foreign
names wherever legal in SML, explicit buffers/pointers, sizes, status
results and calling conventions. Use a documented, collision-checked escape
for SML keywords, leading underscores and other names SML cannot spell;
always retain the exact source spelling in the member map. Raw declarations
still have SML signatures. Raw native access
is an escape hatch outside the portable `WIN32` contract; clients using it
do not gain SDL/mock equivalence. Raw operations do not waive owner/lifetime
checks on Rune-managed resources or make arbitrary C memory type-safe.

### Binding model and `.ffi` policy

Keep three layers distinct: declarations with source identity, target
layout/ABI facts, and SML projection/ownership policy. A language-neutral
binding model carries explicit backend capabilities, not the assumption
that every future foreign system is expressible as a libffi call.

The versioned declarative `.ffi` format supplies input headers and target
profiles, selected declarations, native library/symbol names, SML names,
ownership/deallocator pairs, nullable/sentinel values, buffer lengths and
directions, encoding, error predicates, and callback lifetime/thread/failure
rules. It can request supported macro/inline adapters. It cannot execute
SML, shell commands or arbitrary code while being read. A function needing
custom adapter logic uses a separately reviewed source file named by policy.

Resolve entries against stable foreign identities and diagnose unknown,
duplicate or contradictory entries. Missing ownership, an unbounded output
buffer, or an unclassified retained callback is an error for a selected
safe binding. Preserve unresolved policy as a source-located diagnostic,
not a guessed default. The raw layer may expose an explicitly selected
unsafe operation, documented as such. Unsupported unselected declarations
appear in the coverage report; unsupported selected declarations fail
generation unless a declared adapter implements them.

The CLI delivered by M6 has three operations:

```text
runeffi generate --config FILE.ffi --target PROFILE --out DIR
runeffi check    --config FILE.ffi --target PROFILE --out DIR
runeffi inspect  --config FILE.ffi --target PROFILE
```

`generate` publishes a complete output set atomically. `check` compares
expected outputs and dependencies without rewriting them and fails on
missing, changed or stale generated files. `inspect` reports selected
declarations, layout, policy and unsupported constructs without native
loading. Input/diagnostic order and generated names are deterministic;
timestamps and absolute acquisition paths are not part of generated code.

### Build selection and caching

Generation is an explicit prerequisite driven by the repository's build
tooling. Provide `make ffi`, `make check-ffi-generated`, and focused FFI test
targets in M6. These targets now exist; their prerequisites and explicit
regeneration commands are documented in [generation](../ffi/generation.md).
Invoking `rune --build` compiles declared SML inputs; it does not launch a
header parser or arbitrary shell hook. Release/install builds ship generated
SML, optional shim sources, provenance and build entrypoints. Applications
compile and deploy target shim binaries and native libraries explicitly,
using the documented dependencies and commands.

Use the existing form, illustrated here for native selection; the delivered
[shared example](../../examples/win32/README.md) supplies the concrete files:

```text
win32_types.sml
win32_sig.sml
implements Win32 =
  use native.build
end
win32_virtual.sml
main.sml
```

`win32_virtual.sml` declares `structure Win32 = _virtual : WIN32`.
The selected implementation exports `_export structure Win32 : WIN32 = ...`.
The delivered `examples/win32/native.build`, `sdl.build` and `mock.build`
entrypoints use equivalent client inputs. The mock build needs neither DLLs nor SDL.
Selection is explicit; loading a native library must never silently choose
an emulator after failure. REPL use follows Rune's existing build/library
loading path, without restarting the VM to add a native symbol.

Generation cache keys include all transitive header bytes, sidecars,
generator/schema version, target ABI, macros/include configuration and
adapter sources/toolchain identity. Keep separate target outputs. A header
or sidecar change invalidates generation; ordinary SML signatures/usages
then govern client invalidation. Changing only the implementation should
reuse clients compiled against an unchanged virtual signature. Test cold,
warm, implementation-swapped and signature-changed builds, including
`--whole`, and ensure failures never leave a falsely current manifest.

## Runtime contracts

### Generic operations and machine support

Use libffi for call interfaces, invocation and closures. Keep C type
conversion in SML/shared support where practical. The generic primitive
families are library/symbol operations; native memory allocation/access;
call-interface preparation/invocation/release; and callback registration,
entry and release. M3 records the exact primitive inventory and argues its
coverage against the C fixture library. Adding SDL and Win32 must add zero
API-specific primitives. Do not route existing GMP arithmetic through it.

The trusted bridge lives in the Basis boundary with documented, sealed
exports; ordinary support libraries and generated bindings call it as SML.
Declare primitives in `src/isa/prims.sml`, generate their tables, and follow
the [bytecode](../bytecode.md) fingerprint/version rules. Put OS operations
behind `runtime/sys/sys.h`, with POSIX, Windows and `SYS=none` answers.

Provide an explicit FFI-enabled build and a no-libffi build. In the latter,
unrelated programs and pure mocks continue to work; foreign operations
raise an availability error. `SYS=none` reports unsupported system services
consistently. No unrequested runtime download or compiler invocation occurs
when a user first calls a binding. Use pinned, checksummed libffi sources
for provisioned builds, record dependency licences, and permit a documented
system package configuration with its detected capabilities/version.

| Target | Required evidence |
|---|---|
| Linux x86-64, System V, LP64 | full generic fixture suite, SDL3, stack/register/JIT, existing `runeopt` execution |
| Windows x86-64, Win64, LLP64 | full fixture suite, SDL3 and native Win32; correct pointer-sized arguments and callbacks |
| Windows x86, ILP32 | `cdecl` and `stdcall` calls/callbacks, symbol decoration, stack balance and native Win32 |
| Linux x86, ILP32 | generic fixture suite and existing portable VM checks |
| Linux AArch64, LP64 | generic fixture suite and register JIT modes; emulation records its limits |
| Linux PowerPC64, big endian | generic fixture/layout suite under the repository's runner, including byte order and function-pointer ABI |
| No-FFI and `SYS=none` configurations | successful builds, ordinary programs/mocks, deterministic unsupported errors |

Keep target scalar/layout profiles independent of the generator's host.
Record OS, architecture, endianness, C compiler, ABI variant and libffi
capabilities. Generic FFI portability does not imply that GUI tests ran on
that machine. Windows execution is native Windows evidence; cross-building
or running a POSIX ABI fixture is not a substitute.

### Layout, memory and errors

Support fixed C integers, target-sized integers, `float`/`double`, pointers,
enums, arrays and ordinary structs, including aggregate arguments/results.
Compute layouts from an explicit target profile and verify them using
`sizeof`, alignment and `offsetof` probes compiled for that target. Preserve
enum aliases, unknown flag bits, padding and signedness. Plain `char`,
`long`, `wchar_t`, `size_t`, and message parameters are target facts.

Unions and bitfields have checked memory views/accessors. Packed structs,
unions or other layouts that libffi cannot faithfully pass by value use
generated C shims; never substitute a guessed ordinary struct descriptor.
Object-like constant macros are evaluated in the frontend. Selected
function-like macros and inline functions use generated adapters where
needed, compiled with the matching headers and ABI. Long double, complex,
vectors and unsupported extensions fail explicitly until supported.

Variadic outgoing calls use an explicit promoted argument list and
`ffi_prep_cif_var`; apply C default promotions and cache by the complete
argument signature. Keep generic variadic calls in the raw interface;
idiomatic wrappers require a sidecar-selected fixed signature. Variadic
callbacks are rejected. This does not promise automatic interpretation of
`printf` format strings.

Foreign resources use opaque registry identities with generation/liveness
checks, owner VM and target tags. Native addresses are held outside the SML
heap, rather than cast to SML integers. GC handles root SML values;
foreign-resource identities serve a different purpose. Track dependencies
so a library cannot unload under a prepared call, live object or callback.
Resource release is explicit and scoped; a second release is diagnosed.
No finalizer or new heap object kind is a prerequisite for this roadmap.

Default string/buffer marshalling copies into a call-scoped foreign arena.
Copies avoid exposing moving heap memory. Borrow directly only on a proven
nonallocating, non-callback path with an explicit contract. Retained foreign
buffers are separately owned allocations. An annotation requesting shared
mutation during callbacks must use foreign-backed storage, not an ordinary
SML array whose copied contents would diverge. Reuse one backing allocation
for overlapping annotated views, preserving pointer identity and aliasing;
reject unsupported aliasing instead of independently copying each argument.

Reuse the existing root handles and pin/copy operations where their
semantics fit. Root arguments and partial results through every allocation,
reload heap/stack addresses after collection or stack growth, and validate
length arithmetic, bounds and alignment before native access. Copy-back
happens exactly once when foreign execution has occurred, including when a
callback left a pending exception; release the arena on every returning path.
Never copy writes into an immutable SML string/vector.

Public text defaults to each API's documented encoding. SDL uses UTF-8;
Win32 native wide calls use explicit length-aware UTF-16 conversion. Preserve
lone UTF-16 surrogates through WTF-8 at native Windows boundaries, following
the [Windows text policy](windows.md); reject other malformed input and
embedded NUL where the API uses NUL termination. Raw wide-buffer operations
preserve code units. The SDL Win32 implementation rejects lone-surrogate
text where SDL requires Unicode scalar UTF-8; document that native-only
case instead of silently replacing it. Keep byte-count/code-unit-count
annotations distinct and test supplementary characters.

Capture `errno`/`GetLastError` immediately on foreign return, before
allocation, conversion or cleanup, and only interpret it where the API's
annotated failure predicate says it is meaningful. An adapter captures it
inside C when the calling mechanism cannot guarantee that timing. Copy
SDL error text before another SDL operation can overwrite it. Idiomatic
wrappers raise documented exceptions or return explicit outcomes; the raw
interface retains the original result and captured error. C undefined
behavior and arbitrary bad native pointers are outside the safety guarantee.

### Callback entry, exceptions and the suspended caller

M5 introduces a specific foreign callback entry, not permission for all
runtime helpers to call the interpreter. Synchronise VM state before any
foreign call that may reenter; root its arguments, saved closure and partial
results. Establish a foreign activation record with a callback delimiter,
pending exception slot, owner thread, resource dependencies and saved VM
state. SML frames cannot return or unwind past the delimiter into C.

For the initial implementation, run callback SML through the owning
bytecode engine's interpreter with JIT entry/tier-up disabled for that
activation. Suspended outer JIT/native frames remain roots. Restore the
caller by frame identity/offsets, not pointers into a value stack that may
move. Freeze JIT code replacement/invalidation while suspended machine
return addresses depend on it. Existing `runeopt` needs its own bounded
callback entry that resumes its generated code; it must not assume the
register interpreter is linked. Implement and test that entry as part of
M5, rather than claiming callbacks work wherever outbound calls work.

Nested SML-to-C-to-SML calls are supported within these delimiters. Check a
finite documented foreign nesting limit before another native entry; pure
SML recursion retains its existing stack behavior. Keep existing engine
handover/no-accidental-nesting tests and add callback-specific tests. The
[JIT roadmap](jit.md), runtime README, native execution and architecture
contracts now describe the delivered bounded interpreter entry.

A callback catches an SML exception at its delimiter, stores it as a GC
root in the enclosing foreign activation, and returns the sidecar-declared
foreign failure result. It never unwinds through foreign frames. Preserve
the first exception; subsequent callbacks in that activation return their
failure values without reentering SML. After foreign control returns,
perform copy-back and cleanup, restore the caller, and raise the saved
exception. Failure results are API-specific: creation-message handling
cannot use the same return constant indiscriminately as every `WNDPROC`
message. M0's message contract supplies the required per-message policy.

Registered callbacks retain their SML closure/root and executable trampoline
until foreign registration has ended. Reject release while registered or
active; unregister/destroy the owning foreign resource first. A callback
requires an active outbound foreign activation on its owning OS thread.
Reject unsupported thread entry in the C boundary before reading VM/heap
state, returning the declared foreign failure value and recording a
thread-safe error for the owner to observe. No worker waits for SML to
service a callback. The selected APIs avoid foreign-thread callbacks;
arbitrary foreign threading is future work.

### Images, fork, loading and the REPL

Serializable specifications (library name, symbol, type and projection)
may live in SML; opened library handles, addresses, prepared native calls,
foreign allocations and callback registrations are process-local resources.
Loading generated bindings defines descriptors; acquire native state lazily.
Provide explicit library sessions whose close operation releases cached
calls/symbols after dependent resources have been released.

The first delivery rejects `Runtime.save`, `Runtime.restore` and process
fork while live foreign resources or activations exist, before any state
or output file changes. It does not serialize addresses or automatically
recreate windows. Once the session is closed and all dependent resources
are gone, portable save/restore works again; stale identities remain invalid
after a restore/new VM. Distinguish identity epochs as well as recycled
registry slots. Test both permitted descriptor-only images and rejection
with live resources, including images crossing widths/byte orders.

REPL calls use explicit sessions on the UI/main thread. Callback closure
roots survive later REPL declarations and collections. Loading/replacing
SML units while a foreign activation is suspended is rejected before
program/JIT mutation; outside it, normal loading continues. A failed
generation, missing DLL/symbol or callback exception must leave the REPL
usable and its live resources inspectable/releasable. Process exit performs
best-effort native cleanup without invoking new SML callbacks; normal
examples close explicitly and prove that their registries are empty.

## Research and design consequences

The following are design inputs, not claims that Rune reproduces another
implementation's behavior or performance. Local source trees were reviewed
under `/home/ruud/reference`; implementation evidence must record their
revisions before relying on an exact behavior. The links are independent
sources for reviewers without those checkouts.

| System or work | Relevant evidence | Adopt for Rune; boundary |
|---|---|---|
| Blume, *No-Longer-Foreign* (2001), [paper](https://www.cs.tufts.edu/comp/150FP/archive/matthias-blume/nlffi-entcs.pdf); SML/NJ NLFFI/C-Kit | C types and data access can be expressed through SML abstraction and generated glue. Local `smlnj/libraries/ckit` and `smlnj/tools/nlffi` separate a C frontend from binding support. | Reusable SML frontend, typed abstract resources, declaration-driven generation. Do not require ordinary clients to manipulate encoded C lvalues for every call, or assume the older frontend covers modern SDL/SDK extensions. |
| MLton, [FFI types](https://github.com/MLton/mlton/blob/master/doc/guide/src/ForeignFunctionInterfaceTypes.adoc) and local `mlton/mlnlffigen` | Native scalar/pointer interfaces and target-specific C aliases; generated per-declaration bindings and library linkage supplied separately. | Separate target C widths from host SML widths, and keep large libraries modular. Rune's moving heap and dynamic REPL require their own lifetime/entry protocol; MLton-specific syntax and static import machinery are not the public contract. |
| Poly/ML, [Foreign](https://github.com/polyml/polyml/blob/master/documentation/Reference/Foreign.html), local `polyml/basis/Foreign.sml` | Library/symbol objects, low-level ABI calls, conversions and explicit callback allocation/release. | Layer generic memory/calls below typed conversions. Do not copy a compiler's private value representation or expose its machinery as each application's interface. |
| Yallop, Sheets and Madhavapeddy, *A modular foreign function interface* (2017), [paper](https://www.cl.cam.ac.uk/~jdy22/papers/a-modular-foreign-function-interface.pdf) | Module abstraction separates a foreign specification from its binding mechanism, including dynamic and generated implementations. | Keep descriptions/projections independent of native, emulated and mock implementations and of future static linkage. C headers remain authoritative inputs; this is not a requirement to rewrite all declarations as a handwritten SML DSL. |
| Python, [ctypes](https://docs.python.org/3/library/ctypes.html#callback-functions) | Runtime loading/conversion is useful interactively; callback objects need retained references, and entry from foreign threads requires explicit runtime handling. | Dynamic REPL calls, strong callback roots and explicit thread policy. Reject implicit thread attachment and untyped inferred call signatures as Rune defaults. |
| [libffi manual](https://github.com/libffi/libffi/blob/master/doc/libffi.texi) | Call-interface preparation, multiple ABIs, aggregate descriptions, variadic promotions and closure allocation provide the machine-dependent layer. | Reuse its ABI engine; retain layout verification, marshalling, ownership, VM reentry and errors in Rune. A closure is not a GC root or a safe VM entry by itself. |

M0 adds small executable comparisons: scalar calls, a struct result, a
retained callback, and an ownership-bearing returned string. Their purpose
is to test the chosen Rune contract against the source/API evidence, not to
turn agreement among other implementations into the specification.

## Milestones and completion gates

### M0: contracts, inventories and baseline

**Depends on:** none. **State:** complete.

Delivered the [pinned inputs and inventories](../../ffi/README.md),
[public contracts](../ffi/contracts.md), independent native subjects and
SML test coordination. [M0 evidence](../../tests/ffi/evidence/m0.md)
records the actual implementation baseline, platform probes, regression
repairs and outstanding checks belonging to subsequent milestones.

Record the starting revision, clean/dirty context, host/compiler/VM versions,
selected SDL3/SDK/libffi sources and acquisition recipes. Turn the above
inventories into versioned, machine-readable fixtures. Write complete SML
signatures, a native-symbol-to-member map, shared type/sharing tests, and
Win32 message/resource state-machine cases. Include raw and idiomatic
examples with hand-reviewed expected behavior. Fix target ABI profiles and
the test evidence needed per platform.

**Artifacts:** manifests, contract signatures, C oracle sources, SML/mock
contract fixtures, research/revision notes and baseline measurements under
the FFI tests/docs directories. **Gate:** every brief requirement has a
delivery/test owner; every selected declaration has policy or an explicitly
tracked unresolved annotation that blocks its implementation gate. C
oracles build/run on initial Linux/Windows targets, and baseline commands,
timings and unavailable checks are recorded. Planning this document alone
does not complete M0.

### M1: reusable C frontend

**Depends on:** M0. **State:** complete.

Delivered [the reusable library](../../lib/language/c/README.md), its
[documented interfaces](../lib/language/c/README.md), development driver,
negative fixtures and original-header compiler comparisons.
[M1 evidence](../../tests/ffi/evidence/m1.md) records source profiles,
constant/declaration checks, host agreement and repository acceptance.

Implement the C translation phases needed for real headers: line splicing,
comments/literals/tokens, includes/guards, object/function/variadic macros,
rescanning, stringification/token pasting and conditional expressions.
Carry original locations and macro-expansion origins. Parse typedef-sensitive
declarations, function pointers, arrays, structs/unions/enums, qualifiers,
initializers/constant expressions, and required calling-convention,
attribute, SAL and packing constructs without discarding ABI information.
Unselected inline bodies may be retained as balanced source for adapters;
do not claim full C statement semantics from that facility.

**Artifacts:** `lib/language/c`, its `library.build`, public docs and unit/
property fixtures. **Gate:** preprocess/parse the pinned inventory headers
unchanged on every target profile; compare token/declaration results with
Clang/MSVC-compatible probes where available. Negative fixtures cover
malformed input, macro recursion, include cycles, typedef ambiguity and
unsupported ABI-affecting constructs. Parsing is bounded by explicit work/
include limits with source diagnostics. Library host tests pass; production
generation requires no Clang frontend.

### M2: binding model and sidecars

**Depends on:** M1. **State:** complete.

Acceptance evidence: [M2 binding-model record](../../tests/ffi/evidence/m2.md).

Implement the separated models, versioned declarative policy parser,
selection closure and SML projection rules. Share type identities across
files; preserve source/alias information. Track layout and ownership as
explicit data. Make a complete coverage report distinguishing selected,
generated, shimmed, unselected and unsupported declarations.

**Artifacts:** reusable binding-model library, `.ffi` specification, schema
fixtures, policy diagnostics and projected signature goldens. **Gate:**
every M0 inventory item resolves uniquely; malformed/conflicting/stale
annotations fail at their locations. Ownership/nullability/length/callback
ambiguities cannot silently produce safe wrappers. Golden interfaces
elaborate as ordinary SML and preserve intended type sharing on Rune and
the host systems. Shuffling input traversal order does not change output.

### M3: generic dynamic calls

**Depends on:** M0. **State:** complete.

Acceptance evidence: [M3 runtime record](../../tests/ffi/evidence/m3.md).
The generic trusted bridge and initial Linux/Windows calls are implemented;
callbacks and aggregate/variadic marshalling remain M4/M5 gates.

Add optional libffi provisioning/builds, system-layer loaders, the native
resource registry, foreign memory, prepared scalar/pointer calls and the
trusted bridge. Validate primitive arguments through Rune's existing
discipline. Keep shared runtime code independent of either engine's private
frame representation. Supply deterministic availability errors for disabled
features and documented host adapters where host tests need the bridge.

**Artifacts:** primitive descriptions/generated tables, Basis bridge,
runtime/system support, dependency records and C fixture library. **Gate:**
native C and SML agree on scalar ranges, pointer/null values, basic memory
and error returns on initial Linux and both Windows widths. Test missing
libraries/symbols, bad descriptors, stale/double-released resources and
allocation-failure cleanup. No-FFI/`SYS=none` builds and ordinary GMP tests
pass. The primitive inventory is generic and fixed before adding bindings.

### M4: layout, marshalling and generated shims

**Depends on:** M2, M3. **State:** complete.

Implement target layouts, structured conversions, owned/borrowed buffers,
alias tracking, text boundaries, native errors and variadic outbound calls.
Generate/compile adapters for selected non-exported macros/inlines and
unsupported by-value aggregate shapes. Verify adapters against the same
headers/profile as the SML output. No shim includes private Rune heap data.

**Artifacts:** layout profiles/oracles, marshalling support, generated
adapter fixtures and native capability reports. **Gate:** C probes verify
sizes/alignments/offsets and round trips that do not require callbacks.
Cover float rounding, signed/unsigned boundaries, padding,
unions/bitfields, endian-sensitive buffers, UTF-8/UTF-16/WTF-8, aliasing,
retention, copy-back, promotions and deallocator pairing. Error-clobber
fixtures prove capture timing. Unsupported layouts fail before native entry.

### M5: callbacks and VM lifecycle

**Depends on:** M3, M4. **State:** complete.

Implement the foreign activation/delimiter, callback registry, owner-thread
checks, pending-exception policy, bounded reentry and engine-specific return
paths. Integrate code-lifetime/loading guards and image/fork restrictions.
Update the architecture/JIT/native contracts with the specific new entry
rule. Deliberately stress a suspended JIT caller and a `runeopt` caller.

**Artifacts:** callback support across supported engines, lifecycle guards,
contract documentation and C/SML fault fixtures. **Gate:** retained callbacks
survive GC and later REPL declarations; nested callbacks collect/grow the
stack and return exactly. Exceptions never cross C, copy-back/cleanup run,
and subsequent SML remains usable. Wrong-thread entry, destruction/unload
while active, stale callbacks, depth exhaustion and forbidden lifecycle
operations give the specified result without state mutation. Existing
no-accidental-engine-nesting tests still pass. GUI binding milestones wait
for this gate, including native callback support.

### M6: generator and build integration

**Depends on:** M2, M3, M4, M5. **State:** complete.

Deliver `runeffi.build`, the self-hosted executable/wrapper, CLI above,
deterministic SML/raw/native generation, optional adapters, documentation,
versioned FFI manifests and virtual-module build files. Integrate explicit
generation/check/test targets with the SML build/test tooling. Generate
library build declarations and ordinary manifests by existing mechanisms.

**Artifacts:** generator, installed wrapper, regeneration targets, fixture
libraries, generated docs and native/SDL/mock build templates. **Gate:**
clean generation and a second generation are identical across Rune/host
generator builds. `check` detects edited/missing/stale outputs without
rewriting them. Transitive include/policy/target changes invalidate the
right generation; implementation swapping reuses unchanged clients in
warm virtual builds. Interrupted generation and parallel target builds
cannot publish partial output. Mock builds do not open native libraries.

### M7: core SDL3 bindings

**Depends on:** M6. **State:** complete.

Complete the SDL inventory, including ownership and event-union decoding,
startup/main-thread rules and explicit resource sessions. Deliver the SDL
example and REPL instructions. Keep wrappers generated from original SDL
headers plus sidecars, with handwritten adapters separately identified.

**Artifacts:** `ffi/sdl` inputs/policy, `lib/ffi/sdl`, docs, tests and an
interactive example. **Gate:** every selected declaration has a test and
projection; automated injected-event and offscreen surface/render tests
pass on Linux/Windows. Prove returned clipboard storage is freed, dependent
textures/renderers/windows close in order, and event/string/buffer data
does not outlive borrowed storage. Run real display/input/clipboard smoke
tests and repeated create/destroy REPL sessions. A dummy display result
does not stand for a real desktop result.

### M8: native Win32 GUI bindings

**Depends on:** M6. **State:** complete.

Complete the Win32 inventory, W-API text policy, native resource mappings,
window-procedure adapter and error/status projections. Resolve kernel32,
user32 and gdi32 entrypoints dynamically, including x86 decoration and
callback conventions. Deliver the shared GUI example and Windows builds.

**Artifacts:** `ffi/win32` source manifests/sidecars, native/raw generated
bindings, shared types/signatures, docs and native contract tests. **Gate:**
the example runs on 32/64-bit Windows; creation-time callbacks, creation
failure, nested sends, paint cleanup, GDI selection/restoration, timers,
supplementary text and closure all pass. Compare state/results with direct
W-API C probes. Verify dynamically loaded bindings work from the REPL and
leave no live callbacks/handles after normal closure. No new Win32-specific
runtime primitives are added.

### M9: Win32 over SDL3 and mocks

**Depends on:** M7, M8. **State:** complete.

Implement handwritten SML resource/message state machines over generated
SDL3 calls, and a deterministic SML mock with injected input/time/failures
and a drawing/resource trace. Reuse signatures, logical types and portable
contract tests, not native pointer representations. Specify translation
from SDL events to the selected Win32 message semantics and normalise only
documented platform differences in differential tests.

**Artifacts:** SDL/mock implementations, three example entrypoints, contract
suite, trace fixtures and capability/limitation table. **Gate:** the same
client source builds/runs for native Windows, Linux SDL and pure mocks.
Common results, creation/destruction, nested-send behavior and resource
lifetimes agree; native OS event ordering/pixels are not forced to match.
Planted faults in paint cleanup, message ordering, timer cancellation and
stale handles must fail the suite. Unsupported flags/glyph modes are visible
failures, never silent successful no-ops. Mock tests run without SDL/DLLs
or a display server.

### M10: portability and release acceptance

**Depends on:** M7, M8, M9. **State:** complete.

Finish the ABI/engine matrix, installation/provisioning and provenance
documentation. Package generated sources, dependency notices and target
adapters with relative paths. Record cold/warm generator costs, runtime
preparation and steady-state call/callback/marshalling overhead against
direct C. Document the public/raw distinction, cleanup recipes, errors,
REPL sessions, platform builds and capability limits in user-facing docs.

**Artifacts:** install/distribution integration, capability matrix, test and
measurement records, examples/manual and dated release evidence. **Gate:**
the acceptance sequence below passes on the delivered matrix, installed
examples work outside the checkout, generator bootstrap/host agreement
holds, and clean/no-FFI builds remain valid. CI and unavailable native GUI
checks retain their own status. No missing platform gate is converted to
a release pass by a source inspection or a cross-build.

## Acceptance and evidence

Use the existing SML test runner and `lib/test/unit`/property infrastructure.
New public library members get full doc comments, usage heads, signature
checks and tests; regenerate docs rather than editing generated pages.
Runtime/language changes update `docs/language.md`, bytecode/architecture
contracts, host primitive shims and ISA/native templates as required by
`AGENTS.md`. Ordinary library tests remain portable SML and do not hide
reference-compiler bugs behind implementation workarounds.

| Layer | Required tests and independent evidence |
|---|---|
| Frontend | positive/negative preprocessing and declaration fixtures; original-source checksums; source/macro spans; compiler token/layout comparisons; explicit resource limits |
| Policy and generation | malformed/ambiguous annotations, type identity, deterministic output, full inventory accounting, edit/staleness detection and failed-publication recovery |
| ABI | direct C oracles for scalars, aggregates, layout, by-value unions via shims, promotions, calling conventions, pointer width, error capture and cleanup |
| Memory and reentry | retained/aliased buffers, GC/stack movement, callback lifetimes/exceptions/nesting/thread rejection, suspended machine frames, allocation failures and unload guards |
| Lifecycle and REPL | missing/repeated loads, recoverable failures, late declarations, explicit session close, stale identities, allowed descriptor images and rejected live-resource images/fork/restore |
| Behavior | shared native/SDL/mock contracts, planted faults, event injection and real desktop smoke tests; explicit unsupported cases |
| Delivery | target/host/engine matrix, no-FFI builds, installed-tree runs, licences/provenance, examples, regenerated docs and baseline regressions |

Run focused suites at each gate, then `make check JOBS=8` before completing
the milestone. Run the `docs` profile for documentation changes. For runtime
work add `make windows`, `make test-windows`, `make portability`,
`make test-portability`, sanitizer/stress checks and the VM profile. Library
work adds `make matrix-quick` and `make test-lib-hosts`; native/JIT work adds
the corresponding native/JIT suites and existing instruction/count oracles.
Integrate the new FFI tests into these targets instead of assuming existing
suites exercise foreign transitions. Cross-machine images still test the
no-live-resource path. GUI/native calls are not deterministic instruction
counts; use controlled fixture inputs for engine equivalence.

Measure preprocessing/parsing, projection/generation, optional shim compile,
dynamic load, call-interface preparation, warm calls, copies and callback
entry separately. Compare paired/alternating SML runs with direct C fixtures
that verify the same result; report distributions, allocation/native-memory
cost and machine/toolchain details. Keep preparation outside warm-call
timings and report both. Establish regression budgets from M0/M3 measurements
before optimising; do not invent a universal call-overhead target or turn
noisy GUI timings into CI thresholds. Cached interfaces must have bounded,
explicitly releasable memory.

Each milestone record contains the source commit, generator/runtime and
dependency versions/hashes, target profiles, commands, exit status, test
counts, artifact locations, measurements and unresolved limitations. Record
native Windows versus emulated execution, real versus dummy displays,
unavailable packages, sandbox/interop restrictions and flaky checks
separately. A source provenance gap remains a gap. Commit the evidence and
milestone changes together, using project style and the full model name in
the agent's coauthor trailer; do not publish repository changes implicitly.

## Risks, tradeoffs and follow-on work

| Risk or cost | Response and milestone gate |
|---|---|
| A self-hosted preprocessor/parser encounters complex SDK extensions | Bound delivery by real pinned headers; preserve ABI attributes and test against independent compiler probes. M1 fails rather than sanitising originals. |
| libffi capability or executable-closure support differs by target | Probe exact pinned builds, keep capabilities explicit, generate supported adapters or report unavailability. M3/M5/M10 require actual execution evidence. |
| Reentry breaks the existing driver, rooting or JIT code-lifetime rules | Introduce the delimiter/foreign activation first, initially interpret callbacks, and stress suspended callers. M5 blocks both GUI deliveries. |
| Explicit cleanup and checked resources add API/runtime cost | Generate scoped helpers and dependency tracking; measure call, conversion and registry costs separately. Avoid a new GC/finalizer project. |
| Header descriptions omit ownership, errors or callback semantics | Require sidecars and review them against original documentation; fail selected safe bindings with missing policy. M2/M4 pin negative tests. |
| Win32 over SDL becomes a full Windows emulator | Freeze the GUI contract/inventory, return unsupported for other operations, and test portable observable behavior. M9 does not promise native widgets or identical rendering. |
| Vendored inputs, target toolchains or installed DLL versions drift | Record acquisition rights/hashes and generation/runtime compatibility; reject known mismatches. Keep acquisition distinct from execution. M0/M10 own the records. |
| Mocks agree with an incorrect implementation | Use direct C/native probes and specification-derived expected states as well as differential traces; plant faults to prove tests detect violations. |

Future C++ support needs its own frontend/adapter policy for templates,
overloads, object lifetime, name mangling and exception containment. Java
needs a VM bridge with managed references, thread attachment and exception
translation. Web IDL/Wasm needs its own value/host model and a Rune backend;
libffi is not the universal execution engine for those systems. Reuse
declaration/projection/generation interfaces where they fit, and add explicit
backend capabilities where they do not.

Future native Windows executables may replace dynamic lookup with import
linking against kernel32/user32/gdi32, while preserving SML signatures,
sidecars and ownership rules. That work needs register/native code-generation
and packaging decisions of its own. The current roadmap delivers dynamic
calls, generated shared-library adapters where required, and interactive
REPL use without depending on that future linker.

# Win32 desktop FFI: an expansion roadmap

Written on 2026-10-23 against
`338ed6b94aeb92fb3e15627887c960a90c91c1e9`. This extends the delivered
[Runeffi roadmap](../runeffi.md), particularly its M8 native Win32 and M9
SDL/mock implementations. The original brief asked for NT 4.0-era GUI APIs,
desktop OLE, examples covering Petzold and Inside OLE, and Linux execution
through complete SDL and mock implementations of the portable behavior.
The larger examples include a text editor, clock, file browser, **Paint**,
and a compound-document editor.

This document plans that expansion; it does not record its implementation.
Every W milestone below is **planned**, including the baseline/inventory
work of W0. Existing FFI acceptance remains historical evidence for the
existing delivery, not acceptance of these additions.

## Delivery contract

The target is the **NT 4.0 API baseline**, executed on supported Windows
x86 and x86-64 systems. Running Rune or these binaries on NT 4.0 itself is
not required. Modern SDK/toolchain inputs and x64 layout facts remain
necessary; their presence does not make a newer API part of the baseline.
This is a desktop binding, not an inventory of every kernel or server API.

The delivery includes native bindings and ordinary SML interfaces for the
selected desktop APIs, functional SDL implementations of portable behavior,
and deterministic mocks. It includes COM clients, Rune-owned COM objects,
local EXE servers, Automation, structured storage, clipboard/data transfer,
drag and drop, linking, embedding, in-place activation, and OLE controls.

Rune owns its process and UI/STA thread. Calling native in-process components
from Rune is included. Publishing a reusable COM DLL which loads the Rune
VM inside an arbitrary application is deferred, as are arbitrary entry into SML
from foreign threads, multithreaded SML, and distributed COM. Native local
EXE servers use Windows activation/marshalling; Linux implements the same
Rune-owned object protocols locally, without promising a Windows COM service.

### API and version boundaries

| DLL/domain | Required families | Milestones |
|---|---|---|
| user32 | Window trees, messages, input, focus/capture/caret, scrolling, menus, accelerators, resources, dialogs, standard controls, clipboard, MDI | W2-W4, W16, W19 |
| gdi32 | DCs and state, coordinates, primitives, paths/regions/clipping, fonts/text, bitmaps/DIBs/blits, palettes, metafiles, printer drawing | W5-W7, W9 |
| comctl32 | Baseline common controls, notifications, image lists, property sheets | W8 |
| comdlg32 | Open/save, color/font, find/replace, print and page-setup dialogs | W9 |
| shell32 | File operations, icons, launching, browsing, notifications, selected namespace interfaces | W12 |
| advapi32 | Registry keys/values, enumeration, access/error behavior needed by applications and registration | W10, W15 |
| kernel32 | Supporting files, memory/global-memory objects, mappings, processes, libraries, clocks, events/waits and resource loading | W3, W10, W16 |
| ole32 | COM activation/lifetime, storage, persistence, monikers, data transfer and compound documents | W11, W14-W18 |
| oleaut32 | BSTR, VARIANT, SAFEARRAY, dispatch, type information and Automation support | W13 |
| oledlg | OLE insertion, paste-special, link/object properties and related desktop dialogs | W17-W18 |
| Printing support, including winspool where needed | Printer enumeration/configuration, job lifecycle and output | W9 |

W0 freezes a declaration-level inventory with native names, SML members,
constants, messages, structures, interfaces/methods, source identity,
ownership/error policy, provider classification, milestone and tests.
The families above are mandatory scope; they are not a claim that every
declaration of those DLLs must be bound. No mandatory family can disappear
through an inventory exclusion without an explicit roadmap revision.

Distinguish stock NT 4.0 from subsequent service-pack, Internet Explorer,
shell and common-control additions. Record the earliest evidenced OS/DLL
version and required structure extent for each selected operation. Version
4.7x additions get explicit extension rows; later themes, task dialogs,
modern file dialogs and newer shell services are outside the baseline.
Test DLL capabilities individually rather than deriving them from one OS
version. Microsoft's [shell versions][shell-versions] and
[common-control versions][control-versions] explain why this distinction is
necessary. A modern documentation page's minimum *supported* Windows version
is not by itself evidence of when an API was introduced.

Keep explicit W APIs where available and record historical ANSI-only
exceptions. Pointer-sized API names which are macros or aliases must map
to the actual target declaration/export, not a presumed NT 4.0 x64 symbol.
Retain the pinned original SDK and compiler-header acquisition policy in
[the source guide](../../../ffi/win32/README.md); update hashes explicitly
when selecting additional original inputs. Headers remain unmodified and
external under their existing licence.

### Deferred work

Unrestricted SML threading, remote DCOM/security infrastructure, arbitrary
hosted Rune COM DLLs, a general C++/IDL frontend, arbitrary `.rc` parsing,
multimedia/winmm and Internet/wininet bindings are follow-on work. W0's book
coverage must name these exceptions. Ordinary native workers and DLL
fixtures can demonstrate the supported FFI boundary without executing SML
on a worker thread. Full Explorer replacement, arbitrary shell extensions,
all Windows control versions, and identical Windows pixels are not goals.

## Starting point

The inspected tree already contains the following implementation:

| Layer | Existing contract and limitation |
|---|---|
| Generator | Original-header C frontend, separate declaration/layout/policy models, generated raw/public bindings, typed field adapters, immutable output sets and staleness checks |
| Native Win32 | 38 selected kernel/user/GDI functions in [the inventory](../../../ffi/win32/inventory.json), with policy in [core.ffi](../../../ffi/win32/core.ffi); Windows32/64 generated sets |
| Shared interface | [WIN32](../../../lib/ffi/win32/common/win32_sig.sml), common logical identities, copied messages and explicit errors/unsupported operations |
| Native provider | Canonical handles, creation-time/nested callbacks, scoped painting, selected-object guards, captured errors and explicit shutdown |
| Portable model | Shared SML classes, message queues, timers, painting and object ownership over a thin window/drawing/event/clock driver |
| SDL driver | Generated SDL3 calls, persistent clipped software canvases, input translation and printable ASCII drawing; window titles/input have separate Unicode handling |
| Mock | Deterministic clock/events, logical resources and normalized traces; no SDL, DLL or desktop dependency |
| Tests/examples | One shared event-and-paint application, provider contract functors, native C oracles, driver pixel probes, REPL and host/engine checks |

The portable GUI currently accepts a narrow top-level-window/style subset.
Child controls, menus, dialogs and the expanded GDI/OLE surface are additions.
The eight existing integer helpers and generated layouts are precedents for
new helpers; target widths must never be inferred from the SML host's `int`.

The generic runtime prepares calls to exported symbols, not arbitrary COM
vtable slots. Callbacks require the owning VM thread and an active native
call. COM therefore needs generated typed method wrappers and native
interface thunks, plus explicit pumping/reentry contracts; it is not just
another list of DLL exports. See [the runtime contract](../../ffi/runtime.md)
and [callback contract](../../ffi/callbacks.md).

[The existing release record](../../../tests/ffi/evidence/release.md) links
the delivered M0-M10 acceptance. W0 records a fresh source/tool baseline
and focused reruns before implementation. This roadmap does not copy old
pass totals into a new acceptance claim.

## Architecture and public interfaces

### SML ownership and compatibility

Extend the shared interface in feature substructures for windows/controls,
resources/dialogs, drawing/text/bitmaps, printing, registry/shell, COM,
Automation, storage and OLE. Keep names recognizable from the foreign API,
large argument sets as labelled records, genuine nullability as `option`,
and exact native status/buffer access in separately documented raw bindings.

All providers use the same abstract type identities. Add distinct types for
DCs, bitmaps, fonts, regions, palettes, menus, icons/cursors, dialogs,
registry keys, storage/stream objects and interface references. Record owned,
borrowed, selected, transferred, callback-scoped and ended lifetimes. A COM
interface reference additionally records its owning apartment and release
obligation; aliases of one COM identity are not independent objects.

Preserve existing entrypoints and behavior while extending the API. Add a
new constructor when an existing record argument needs more fields rather
than breaking existing `createWindowEx` calls. Keep current paint helpers;
new general-DC operations must not turn an ended paint scope into a usable
DC. Extend typed messages/notifications with copied payloads or checked
scoped views. Never expose a native pointer as an invented SML integer or
let a retained notification refer to callback memory that has expired.

Raw native access remains outside portable equivalence. Unknown native
messages can still reach their original default procedure with the exact
payload while that callback is active. The model does not fabricate unknown
Windows messages or claim native semantics for arbitrary pointer payloads.

### Generation, resources and host adapters

Reuse the C frontend, model, `.ffi` policy, code generator and existing SML
test coordinators. Generate COM client method wrappers and interface thunk
layouts from selected original C declarations, including `this`, method
order, calling convention, output ownership and HRESULT policy. This avoids
adding a Win32-specific runtime primitive or a general C++ ABI requirement.
Extend reusable generator support where needed and test it with independent
C fixtures before relying on the Win32 binding.

Resource descriptions are ordinary typed SML data shared by all providers.
Generate native menu/dialog/accelerator templates and interpret the same
descriptions in the portable model. Support native resource loading as a
separate native facility; using an external resource compiler is an explicit
build step. `.build` selects providers and never executes a compiler or
shell recipe. A general resource-script language is not a prerequisite.

The SML model owns child controls, modal loops, focus/selection, notification
ordering, drawing state, transfer protocols and Rune-owned object behavior.
Expand the SDL driver only for actual window, event, raster, font and host
I/O operations. Use a generated, pinned [SDL3_ttf][sdl-ttf] projection for SDL font
rendering in W6; document its dependencies and distribution alongside SDL3.
Do not implement widgets or COM lifetimes independently in the SDL driver.
Mocks execute the shared semantics rather than returning canned successes.

Native handles, allocators, OS activation and printer/shell interaction stay
in thin adapters. Pair each allocation with its correct allocator/releaser:
GDI objects, global memory, COM task memory, BSTRs, VARIANT/SAFEARRAY contents,
and STGMEDIUM media have different ownership contracts.

### Text, errors and COM entry

Preserve UTF-16 code units and native WTF-8 boundaries, including lone
surrogates. BSTRs use explicit lengths and allow embedded NULs. Scalar-text
conveniences must not replace the code-unit behavior of messages/buffers.
Linux may substitute a display glyph for an unpaired surrogate while
retaining the logical contents. Font matching, shaping, metrics and glyph
rasterization have declared provider differences; ASCII-only drawing is no
longer the completed W6 contract.

Distinguish cancellation, empty/end-of-enumeration, success statuses such as
`S_FALSE`, and failure. Preserve raw HRESULTs and captured native errors;
capture `GetLastError` only where the API defines it. Out-parameters and
partly initialized owned results are cleaned up before a deferred callback
exception propagates. User exceptions never unwind through native frames.

Initialize COM/OLE on the owning UI thread with balanced teardown. Native
message pumps, modal operations and OLE calls must run inside a valid FFI
activation so inbound STA calls can safely reach SML. Cover hidden COM
window dispatch and reentrant calls made while an outgoing call waits, as
required by [the STA rules][sta]. Reject wrong-thread access and entry
without an activation. Do not weaken existing callback guards to make a
server appear to work.

Factories, interface thunks and closures stay rooted while native references
or registrations exist. Revoke registrations, disconnect advise/event sinks,
close documents/windows, release interfaces/media and then uninitialize
COM and unload adapters. Busy resources reject premature teardown; shutdown
and failed construction attempt all owned cleanup while retaining the
original failure. Live native COM resources remain process-local and do
not become restorable capabilities in images or forked processes.

## Provider behavior and explicit limits

The following is the delivery target, not a description of current support.
Each selected inventory row refines it with supported flags, notifications,
formats, error behavior and tests. An unimplemented required row remains
outstanding; putting `Unsupported` behind it does not complete a milestone.

| Feature | Native Windows | SDL/Linux | Deterministic mock |
|---|---|---|---|
| Windows, menus, dialogs, controls and MDI | Native objects | Shared SML widgets and window model over SDL; appearance may differ | Same state and injected events without a desktop |
| Drawing, fonts and images | GDI and selected native formats | Shared drawing state, SDL raster/font adapters; documented raster/metric differences | State/draw traces and software image observations |
| Resources | Generated templates and selected native resource APIs | Same logical resource descriptions | Same IDs, lookup, failure and lifetime behavior |
| Common dialogs | Native dialogs | Functional shared dialogs, not silent default answers | Scripted success, cancel, validation and error paths |
| Printing | Native printer selection/jobs/drivers | Shared preview and PostScript print-to-file output | Deterministic page/job state and injected failures |
| Registry/settings | Isolated native keys and declared registry semantics | Persistent application-scoped store implementing selected key/value semantics | In-memory store and injected access/errors |
| Files/processes/libraries | Windows operations | Existing portable host services where semantics match; declared native-only flags stay explicit | Deterministic host fixtures/state |
| Shell | Windows shell and selected namespace services | File-backed browsing/operations and explicit host-launch adapter | Virtual namespace and launch/notification records |
| COM and Automation | Native clients, objects and local EXE servers | Local Rune object/factory/dispatch model | Same identities, references and scripted failures |
| Storage/persistence | Windows storage plus shared data policy | Interoperable SML compound-file implementation | Same implementation with deterministic I/O/faults |
| Clipboard/drag and drop | Native Win32/OLE interapplication exchange | Shared format/media negotiation; host clipboard/drop bridge for supported formats | Deterministic source/target/data ownership model |
| Linking, embedding and in-place activation | Native interoperability plus Rune components | Working Rune-owned containers/components and local binding | Same activation/persistence/notification protocols |

Native-only cases include activation of installed Windows COM/OCX servers,
Windows shell extensions/non-file namespace objects, Windows association
and registration services, OS printer drivers and cross-process Windows
marshalling. Test these on Windows and expose capability failures elsewhere.
Linux local COM protocols do not claim Windows RPC interoperability, and a
portable registry store does not claim to be the host's Windows registry.
Document host clipboard/drop restrictions and backend-dependent placement,
decoration and font differences. Unsupported native-only capabilities must
be discoverable before an example chooses its integration path.

## Status and dependency order

| ID | Deliverable | Depends on | State |
|---|---|---|---|
| W0 | Baseline, scope inventories and independent oracle plan | Existing FFI | planned |
| W1 | Shared types, feature interfaces and test infrastructure | W0 | planned |
| W2 | Window hierarchy, input and subclassing | W1 | planned |
| W3 | Menus, resources, accelerators and dialogs | W2 | planned |
| W4 | Standard controls | W2, W3 | planned |
| W5 | General DCs, state, coordinates and drawing | W1, W2 | planned |
| W6 | Unicode text, fonts and layout | W5 | planned |
| W7 | Bitmaps, DIBs, blits, palettes and metafiles | W5, W6 | planned |
| W8 | Common controls, image lists and property sheets | W3, W4, W5, W6, W7 | planned |
| W9 | Common dialogs, printing and preview | W3, W6, W7, W8 | planned |
| W10 | Kernel support and registry | W1 | planned |
| W11 | COM ABI, objects, factories and STA lifetime | W1, W10 | planned |
| W12 | Shell services and namespace projection | W8, W10, W11 | planned |
| W13 | Automation, type information and events | W11 | planned |
| W14 | Streams, structured storage and persistence | W11 | planned |
| W15 | Monikers, ROT, local servers and advice | W11, W14 | planned |
| W16 | Clipboard, data transfer and drag and drop | W3, W11, W14 | planned |
| W17 | Compound documents, embedding and linking | W7, W14, W15, W16 | planned |
| W18 | In-place activation and OLE controls | W8, W13, W17 | planned |
| W19 | Complete example suite and larger applications | W2-W18 | planned |
| W20 | Integrated release acceptance | W0-W19 | planned |

W5 and W10 can follow W1/W2 without waiting for every control. After W11,
Automation and storage can proceed independently. Small examples ship with
their feature milestones; W19 integrates and completes them, rather than
deferring all application feedback until the end. Complete and commit each
milestone with its evidence before marking it done. Native, portable and
mock gates belong to the same milestone, except its named native-only rows.

## Milestones and completion gates

### W0: baseline, inventories and independent evidence

**Depends on:** existing FFI. **State:** planned.

Record source revision/dirty context, SDK/MSVC/libffi/SDL versions, host
compilers, Windows/Linux identities, engine availability and acquisition
hashes. Rerun existing shared contracts/examples and generator checks;
preserve failures/skips. Freeze the API/version/provider inventory and book
coverage, with raw/public mappings, layout/constant needs, callback/thread/
ownership policies and independent reference checks. Assign every mandatory
family an implementation milestone and test owner; unresolved annotations
block that feature's implementation gate.

**Artifacts:** inventories, source manifests, baseline receipts, oracle
fixtures and coverage maps under existing FFI directories. **Gate:** every
brief requirement and native-only/deferred exception is accounted for;
Windows32/64 and Linux reference fixtures execute or retain an outstanding
platform gate. Writing this roadmap does not pass W0.

### W1: shared interfaces, resources and contract infrastructure

**Depends on:** W0. **State:** planned.

Add feature signatures, abstract types, capability queries and typed payload/
notification support. Specify aliasing, scope, ownership transfer, status
and provider isolation. Introduce resource descriptions and reusable scoped
cleanup/partial-construction patterns. Extend existing contract functors,
deterministic input/time/error controls and normalized observations. Native
C fixtures independently measure layouts, constants and pointer-sized values.

**Artifacts:** documented signatures, model/driver contracts, type-sharing
tests and resource fixtures. **Gate:** existing applications compile and run
unchanged; type sharing, wrong-provider/stale/escaped resources, failed
construction and both ABI checks pass. Interfaces can precede feature
implementations, but those inventory rows remain visibly planned.

### W2: window hierarchies, input and subclassing

**Depends on:** W1. **State:** planned.

Extend creation/positioning, parent/owner relations, enumeration, visibility,
activation, focus, capture, caret, scroll state and input messages. Add
same-thread subclass chains and restoration. Distinguish child IDs from
menu handles and copied notification data from callback payloads. Implement
the same logical tree, hit testing, focus traversal, coordinates and cleanup
in SML. Add parent/child, input, caret and scrolling examples.

**Artifacts:** native/model extensions, input gallery and C observations.
**Gate:** creation veto, reparent/resize, signed coordinates, focus/capture
loss, input, parent destruction, subclass restoration and nested self/sibling
destruction pass without stale callbacks/windows. Host placement restrictions
remain explicit capabilities.

### W3: menus, resources, accelerators and dialogs

**Depends on:** W2. **State:** planned.

Deliver resource lookup, string tables, icons/cursors, menu trees, popup
menus, command routing, accelerators and dialog templates. Include modal
and modeless dialogs, dialog procedures, result conventions, navigation,
default/cancel buttons and loop preprocessing. Generate native templates
and interpret the same resource data in SDL/mocks. Modal execution keeps
dispatching permitted events and unwinds when its owner closes.

**Artifacts:** resource adapters, shared menu/dialog model and galleries.
**Gate:** lookup failures, invalid IDs, commands, disabled items, accelerators,
tab/default/cancel behavior, nested dialogs, exceptional exits and shutdown
pass. Cancellation differs from failure; template layouts pass both ABIs.

### W4: standard controls

**Depends on:** W2, W3. **State:** planned.

Deliver button/radio/check/group controls, static text/images, single/multi-
line edits, list/combo boxes and scrollbars. Add typed command notifications,
text/selection/range/state operations and owner-drawn/measure-item callbacks.
Implement shared editing, selection, layout and notification rules over SDL;
deliver a control gallery and first text-editor shell. Mock input exercises
the same behavior rather than bypassing controls.

**Artifacts:** control bindings/state machines and gallery contracts.
**Gate:** editing, selection, focus navigation, checked/enabled state, scroll
ranges, owner-draw cleanup, programmatic versus user notifications, reentrant
mutation and control destruction agree within the declared contract.

### W5: general DCs, coordinates and drawing

**Depends on:** W1, W2. **State:** planned.

Add general/window/memory DC lifetimes, save/restore, drawing attributes,
logical/device mapping, current points, line/polygon/ellipse/Bezier/path
operations, pens/brushes, regions and clipping. Specify selection restoration
and distinctions between releasing, deleting and ending a DC. The model owns
state/transforms; the driver renders. Add coordinate, clipping, path and
clock demonstrations with independent geometry and reviewed raster fixtures.

**Artifacts:** DC interfaces/adapters, model state and drawing gallery.
**Gate:** nested save/restore, mapping/clipping, fill/background/raster state,
empty regions, ranges, paint exceptions and selected/borrowed object guards
pass. Normalize only declared renderer differences, not geometric/state bugs.

### W6: Unicode text, fonts and layout

**Depends on:** W5. **State:** planned.

Add logical fonts, enumeration callbacks, metrics/extents, alignment,
background/spacing and formatted text. Keep UTF-16/WTF-8 policy consistent
across titles, controls, buffers and drawing. Add generated SDL3_ttf support
and font provisioning/licence records. Fonts are pinned test inputs, not
assumptions about host installation. Add font/text galleries and Unicode
editor cases; mocks use deterministic font data.

**Artifacts:** font/text bindings, SDL support inventory and text fixtures.
**Gate:** ASCII, supplementary/combining text, lone-surrogate storage/display
policy, embedded NUL where allowed, enumeration exceptions, measurement,
wrapping and font cleanup pass. Native/SDL metrics and layout invariants
are checked without promising identical font matching, shaping or pixels.

### W7: images, DIBs, raster operations, palettes and metafiles

**Depends on:** W5, W6. **State:** planned.

Add bitmap/memory-DC ownership, DIB sections/conversions, blits/stretching,
selected raster operations, palettes, and selected WMF/EMF record/playback/
enumeration operations. Freeze format/record subsets and version exclusions;
include indexed/true-color DIBs, padding, orientation and channel order.
Implement portable operations and selected metafile playback; reject records
outside that contract. Supply viewers and Paint's initial canvas/brush/BMP
workflow, with a deterministic uncompressed 24-bit BMP writer for interchange.

**Artifacts:** image/format bindings and SML support, reviewed fixtures,
viewers and initial Paint. **Gate:** independent native image observations,
load/save conversions, partial paints, offscreen selection, palette updates,
malformed/truncated/oversized input and allocation failures pass. Paint
pixels survive viewport resize and BMP save/reopen.

### W8: common controls and property sheets

**Depends on:** W3, W4, W5, W6, W7. **State:** planned.

Deliver baseline toolbar/status, list/tree, tab/header, progress, trackbar,
up-down, tooltip, hot-key and animation control families where supported by
the frozen baseline, with image lists/property sheets. Animation resources
are a versioned format dependency, not general multimedia support. Other
period controls/messages require extension rows. Implement shared item,
selection/range, notification and owner-data/draw semantics. Deliver a
gallery, settings sheet and browser shell with functional SDL controls.

**Artifacts:** versioned inventories, notifications and control suites.
**Gate:** insertion/removal/enumeration, focus/selection, notifications,
property apply/cancel/veto, shared image ownership, callback mutation and
teardown pass. Test version-specific structure extents and unavailable APIs.

### W9: common dialogs, printing and preview

**Depends on:** W3, W6, W7, W8. **State:** planned.

Add open/save, color/font, modeless find/replace, print and page-setup
dialogs. Bind printer enumeration/settings and GDI job/page operations,
including abort callbacks. Portable dialogs provide actual interaction,
validation and cancellation. Share page layout/drawing for preview and
deterministic PostScript print-to-file on Linux; OS printer drivers remain
native-only. Mocks exercise job/page transitions and injected failures.
Integrate editor/Paint printing and the common-dialog galleries.

**Artifacts:** dialog/printing interfaces, preview/export and native probes.
**Gate:** long/multiple-file buffers, filters, cancellation versus error,
hooks/reentry, printer absence, page ranges, multipage output, abort and
partial jobs pass. Native printer evidence is separate from file-output checks.

### W10: supporting kernel operations and registry

**Depends on:** W1. **State:** planned.

Deliver selected file/directory, mapping, global-memory, process/library,
event/wait and registry key/value/enumeration operations. Reuse portable
host services without a second supervisor or hidden SML threading runtime.
Native workers notify the owning UI thread. Registry tests use a private
HKCU subtree; SDL has an application-scoped persistent store and mocks
deterministic memory/I/O faults. Do not require administrator access or
modify unrelated settings. Preserve native statuses and declared translations.

**Artifacts:** support adapters, settings and worker/DLL examples.
**Gate:** Unicode names, typed/empty/binary values, buffer sizing, enumeration,
missing/access-denied cases, persistence, wait/cancel, mapped views, handle
cleanup and worker completion pass. Foreign-thread entry stays rejected
and observable.

### W11: COM ABI, object identity and STA lifetime

**Depends on:** W1, W10. **State:** planned.

Generate selected method wrappers/interface thunks with GUID, HRESULT,
inherited vtable layout, `this` and output policy. Add COM/OLE initialization,
interface references, `QueryInterface`/`AddRef`/`Release`, factories,
aggregation/delegation and activation. Rune callbacks live inside a pumped
owning-thread activation; unload guards cover native refs. Native fixtures
both consume Rune objects and expose independent C objects. SDL/mocks
share local identity/factory/refcount semantics. Deliver a component pair
before relying on higher OLE abstractions.

**Artifacts:** generator support, COM signatures/thunks and ABI fixtures.
**Gate:** Windows32 stdcall/stack balance, Windows64 ABI, method slots,
canonical `IUnknown`, aliases, failed queries, aggregation, refcounts,
HRESULTs, partial output cleanup, GC/reentry and initialization/shutdown
balance pass on both native widths.

### W12: shell services and namespace behavior

**Depends on:** W8, W10, W11. **State:** planned.

Add file operations, launching, icon extraction, browsing, change notifications
and selected namespace interfaces. Specify PIDL/shell allocation ownership,
callback extents, outcomes and cancellation. Version shell additions
explicitly. SDL provides functional file-backed browsing/operations and an
explicit host-launch adapter; mocks provide virtual namespaces and recorded
requests. Installed extensions/non-file namespaces stay native-only. Extend
the browser with tree/list synchronization, icons and operations.

**Artifacts:** shell interfaces, namespace adapters and browser scenarios.
**Gate:** traversal, Unicode paths, temporary-fixture rename/copy/move/delete,
cancellation/partial failure, notifications and PIDL/icon cleanup pass.
Native namespace/launch checks retain their own evidence; an unavailable
external application is not a successful launch test.

### W13: Automation, type information and connection points

**Depends on:** W11. **State:** planned.

Add length-aware BSTRs, VARIANT ownership/conversion, SAFEARRAY bounds/data,
`IDispatch`, invocation arguments/results/errors, type-library/type-info
access and event connection points. Deliver controller and Rune server
examples with independent native clients/servers. Shared SML metadata and
dispatch/event semantics run locally on Linux/mocks. Bind native type-library
inspection; a general IDL compiler is not required. Pin inspected libraries
and source/member mappings instead of guessing signatures.

**Artifacts:** Automation interfaces, data/metadata fixtures and examples.
**Gate:** embedded-NUL BSTRs, multidimensional/nonzero-bound arrays, by-ref
and optional/named arguments, reversed argument order, property put/get,
conversion errors, EXCEPINFO, `S_FALSE`, event reentry/unadvise and recursive
cleanup pass. See [Automation][automation].

### W14: streams, structured storage and persistence

**Depends on:** W11. **State:** planned.

Deliver stream/storage enumeration, seek/copy/clone/size, commit/revert,
locking/sharing outcomes, persistence and property sets. Implement an
interoperable NT-era version-3 compound-file reader/writer in SML for Linux,
tested over deterministic mock I/O. Version-4 files are a separate extension.
Specify direct/transacted modes and flags; never silently downgrade a
transaction. Use [MS-CFB][cfb] and [MS-OLEPS][oleps] plus independent Windows
readers/writers. Add a storage browser and persistent component.

**Artifacts:** storage/stream interfaces, format implementation and files.
**Gate:** Windows opens SML-written files and SML opens Windows-written
files; nested storages, small/large streams, seek, enumeration, commit/revert,
short writes, corruption, cycles/truncation, limits and interrupted
publication pass. Same-implementation round trips alone are insufficient.

### W15: monikers, running objects and local servers

**Depends on:** W11, W14. **State:** planned.

Add file/item/composite monikers, binding contexts, running-object tables,
class registration/revocation, local EXE activation, advice and server
lifetime/locking. Include registration/cleanup recipes without requiring
hosted Rune COM DLLs. Windows owns cross-process activation and standard
marshalling. Linux/mocks implement local Rune binding/registration and
scripted activation; Windows OS activation is a native-only capability.
Add native/Rune local-server and binding demonstrations.

**Artifacts:** binding/server interfaces, registration fixtures and native
client/server processes. **Gate:** activate/find/bind/revoke, duplicate and
missing names, disconnects, advise/unadvise, server locks, idle shutdown,
reentry during pumping, process death and failed startup pass. Tests leave
no registrations, settings or processes behind.

### W16: clipboard, data transfer and drag and drop

**Depends on:** W3, W11, W14. **State:** planned.

Deliver clipboard ownership/formats/global-memory transfer, delayed
rendering, `IDataObject`, FORMATETC enumeration, STGMEDIUM release policy,
drop registration and drag negotiation/cancellation. Include text, file
lists, bitmap/DIB and declared component/storage formats. Share negotiation
and ownership in SML; bridge supported host clipboard/drop formats through
SDL with explicit limitations. Mocks inject source/target transitions,
key states and cancellation. Integrate the editor, browser and Paint.

**Artifacts:** transfer interfaces, media fixtures and clipboard/drop apps.
**Gate:** negotiation, copied/transferred media, delayed-owner closure,
busy/lock states, cancel/drop effects, custom releasers, reentrant destruction
and exactly-once release pass. Independent native application exchange and
real Linux host clipboard/drop checks supplement deterministic protocol tests.

### W17: compound documents, embedding and linking

**Depends on:** W7, W14, W15, W16. **State:** planned.

Deliver container/server contracts: `IOleObject`, client sites, views/extents,
verbs, presentation caches, persistence, links and advice. W7 supplies the
bitmap/metafile presentation formats. Add insertion,
paste-special and object/link-property dialogs through oledlg on Windows
and shared functional dialogs for Rune components. Trace selected methods
to [the OLE reference][ole-interfaces]. Build the compound editor with
original Rune drawing/chart components; independent C counterparts verify
both roles. Linux uses those Rune protocols and CFB persistence.

**Artifacts:** document/object interfaces, editor and interchangeable files.
**Gate:** embed/link, verbs, save/reopen, cache invalidation, dirty/save
negotiation, notifications, unavailable source, moved/broken links, rejected
formats, partial insertion and unsaved closure pass. Cached display must
not imply that an unavailable linked object has been updated.

### W18: in-place activation and OLE controls

**Depends on:** W8, W13, W17. **State:** planned.

Deliver in-place site/object/frame/active-object interfaces, activation
states, clipping/extents, UI/menu merging, accelerators, focus and borders.
Add control container/server support, ambient properties, events,
persistence and property pages for selected NT-era interfaces; inventory
later ActiveX/windowless extensions separately. Rune components actually
edit inside the portable container, including SDL menus/property pages.
Installed Windows controls remain a native capability lane.

**Artifacts:** activation/control interfaces, native fixtures and extensions
to the editor/gallery. **Gate:** activate/UI-activate/deactivate, resize/clip,
accelerator/menu routing, focus, property apply/cancel, events, failed
activation and close during reentry pass with balanced UI/resource restoration.

### W19: complete examples, MDI and larger applications

**Depends on:** W2-W18. **State:** planned.

Complete chapter/topic demonstrations and the five applications below.
Add MDI frame/child behavior, menu merging, activation, document commands
and orderly child closure on native, SDL and mocks. Keep application
state/algorithms in shared SML and startup in separate `.build` entrypoints.
Every application has bounded smoke modes, deterministic mock scenarios,
real native/SDL interactive acceptance and failure/cleanup checks. Native
integration choices are explicit; the portable path keeps the application's
main functionality.

**Artifacts:** examples/build files, guides, fixtures and coverage records.
**Gate:** identical client sources run on Windows32/64, real Linux SDL and
headless mocks; every promised feature has a scenario and every book row
has evidence or a stated deferral. Paint's drawing/editing/persistence tests
pass independently of display presentation.

### W20: integrated acceptance and delivery

**Depends on:** W0-W19. **State:** planned.

Reconcile the inventory against generated/raw/public APIs, native providers,
shared model, SDL, mocks, docs and tests. Retain named native-only rows and
justified deferrals. Regenerate docs from signatures; package manifests,
adapters, fonts/dependency notices and relocated example builds. Run the
acceptance matrix below from frozen sources. Measure generation, startup,
representative drawing/control/COM/storage paths and callback overhead
against independent references, keeping phase costs separate.

**Artifacts:** coverage report, installed examples/manuals, dependency and
measurement records, dated acceptance. **Gate:** all required matrix entries
pass with commands and applicable source identities; no missing native/GUI
gate is replaced by a cross-build/mock. Existing optional/no-FFI behavior
and installed examples remain valid; practical limits are documented.

## Example suite and book coverage

### Larger applications

| Application | Required demonstration | Feature dependencies |
|---|---|---|
| Text editor | Single/multi-line editing, menus/accelerators, open/save, dirty/save prompts, find/replace, Unicode/fonts, clipboard and printing | W2-W4, W6, W9, W10, W16 |
| Clock | Timer-driven hands/digital display, coordinates, resizing, colors/fonts and persistent settings | W2, W3, W5, W6, W9, W10 |
| File browser | Synchronized tree/list views, icons, navigation, file operations, notifications and drag and drop | W8, W10, W12, W16 |
| Paint | Freehand brush, eraser, lines/rectangles/ellipses, colors/brush widths, undo/redo, BMP open/save, bitmap clipboard, preview and printing | W2-W7, W9, W10, W16 |
| Compound-document editor | Rune-owned drawing/chart components, compound-file persistence, linking, Automation, controls and in-place activation | W11, W13-W18 |

Paint starts at W7 with an editable canvas and BMP round trips; printing and
clipboard arrive at W9 and W16. Canvas pixels, tools, command history and
file state belong to shared SML application code. Present the canvas through
the selected provider. Keep document and viewport dimensions distinct:
window resizing preserves the document; explicit canvas resizing preserves
overlap and fills new pixels with the declared background. Canvas changes,
including resize, participate in undo.

Paint acceptance includes scripted pointer strokes, erasing, each shape,
color/width changes, cancelled gestures, undo/redo, document resize, partial
repaints and viewport resize. Compare independently reviewed small pixel
fixtures and BMP decode results, not screenshots of window chrome. Saving,
reopening and cross-provider loading preserve the logical canvas. A failed
save preserves the previous file and unsaved document. Check malformed BMP
input, unavailable clipboard formats, print cancel/error and closure during
a gesture. GDI/SDL presentation may differ without changing those pixels.

All five applications use original Rune sources. Record provenance/licences
for reference C programs, images and fonts; a book's availability does not
establish redistribution rights for sample code. Provide native32/native64,
SDL and mock build entrypoints, bounded smoke modes, inputs, expected state
and explicit startup/shutdown ownership. Their deterministic tests must
exercise application code, not a separate mock-only application.

### Programming Windows, fifth edition

The [publisher's contents][petzold] supply the numbering. These are coverage
obligations and planned demonstrations, not a claim that the entire C
sample corpus will be ported.

| Chapter | Subject | Planned example/check | Milestones and boundary |
|---|---|---|---|
| 1 | Getting started | Message box/window and provider selection | W0-W3 |
| 2 | Unicode | Buffer/code-unit and input gallery | W1, W2, W6 |
| 3 | Windows and messages | Existing event example, hierarchy, nested sends | W2 |
| 4 | Text output | Metrics/system-information view with scrolling | W2, W5, W6 |
| 5 | Basic drawing | Mapping, primitives, paths, clipping and clock | W5 |
| 6 | Keyboard | Key/text viewer, caret and editor input | W2, W4, W6 |
| 7 | Mouse | Capture, signed coordinates and Paint gestures | W2, W7 |
| 8 | Timer | Clock, timer replacement/cancellation | W2, W5 |
| 9 | Child controls | Standard-control gallery and editor | W4 |
| 10 | Menus/resources | Resource/menu/accelerator gallery | W3 |
| 11 | Dialog boxes | Modal/modeless settings and validation | W3, W9 |
| 12 | Clipboard | Text/bitmap transfer and delayed ownership | W16 |
| 13 | Printing | Preview, multipage output and abort | W9; OS drivers native-only |
| 14 | Bitmaps/blits | Offscreen drawing, raster operations and Paint | W7 |
| 15 | DIBs | BMP viewer/converter and interchange | W7; format subset explicit |
| 16 | Palettes | Indexed image/palette gallery | W7; physical realization is device-specific |
| 17 | Text/fonts | Font picker, measurements and Unicode editor | W6, W9 |
| 18 | Metafiles | Record/playback viewer and format checks | W7; selected records declared |
| 19 | MDI | Multiple documents, activation and menus | W19 |
| 20 | Multitasking/threads | Native worker/event and subprocess notification | W10; unrestricted SML threading deferred |
| 21 | DLLs | Generated calls, ownership and unload fixture | Existing FFI, W10-W11; arbitrary VM hosting deferred |
| 22 | Sound/music | Coverage note and future multimedia inventory | Deferred: winmm outside this delivery |
| 23 | Internet | Coverage note and future networking inventory | Deferred: wininet outside this delivery |

W0 expands included rows into selected features, source mappings and
observable checks. W19 closes the map with actual evidence. The graphics
chapters cannot be marked covered by the existing ASCII line/rectangle
example alone.

### Inside OLE, second edition

Map verified topics rather than inventing chapter numbers. Use original
book materials when available and Microsoft's interface/format references
to pin behavior. Tutorials do not replace ABI/protocol oracles.

| Topic | Planned demonstration/check | Milestones and boundary |
|---|---|---|
| Interfaces, identity, ownership and aggregation | Independent C/Rune pair, query/refcount checks | W11 |
| Factories, activation and lifetime | Native client, Rune factory and local EXE server | W11, W15; hosted Rune DLL deferred |
| Apartments/reentrancy | Pumped calls, nested callbacks and teardown | W11, W15; one owning STA |
| Automation and type information | Controller/server, type browser and events | W13 |
| Streams/structured storage | Browser, cross-written files and transactions | W14 |
| Persistence/property sets | Persistent drawing/chart component | W14, W17 |
| Monikers/running objects | Bind/find/revoke and broken-source recovery | W15 |
| Data transfer/clipboard | Formats, media ownership and delayed rendering | W16 |
| Drag and drop | Negotiation, cancel and browser/Paint transfers | W16 |
| Advice/presentation caches | Notifications and invalidated presentation | W15, W17 |
| Compound containers/servers | Embedded/linked components saved/reopened | W17 |
| In-place activation/UI | Editable component inside document frame | W18 |
| OLE controls/events/properties | Rune control/container and property pages | W13, W18; later extensions inventoried separately |
| External integration | Independent native clients/servers and selected installed components | W15-W18; Windows-only capabilities recorded |

## Validation, evidence and completion rules

Use the existing SML runner, FFI coordinators, `lib/test/unit` and property
infrastructure. Extend inventories, affected-path coverage, requirements,
pools and profiles instead of adding a scheduler or shell assertion layer.
Document new command modes when implemented; do not present invented
executable commands as if they already exist.

Keep independent native evidence alongside shared tests. Sharing SML
semantics between SDL and mocks is useful, but their agreement cannot
independently establish Windows behavior. Do not generate expectations from
the implementation or normalize away ownership, ordering, cancellation
or status failures.

| Layer | Required evidence |
|---|---|
| Sources/generation | Pinned originals, deterministic host generation, stale/missing-output and publication failures, complete inventory accounting |
| Public interfaces | Signature/ascription/sharing checks, full doc comments and usage heads, generated docs, tests for new public members |
| ABI/errors | Independent C layout/constant/method probes at both Windows widths, pointer/sign extension, x86 conventions, HRESULTs/status and output cleanup |
| Windows/controls | Shared hierarchy, focus, selection, notifications, modality, commands and teardown suites plus independent native observations |
| Drawing/text | Geometry/state, reviewed pixels/formats, declared font/raster differences, Unicode and scoped resources |
| COM/OLE | Independent clients/servers in both directions, identity/refs, activation, native marshalling, advice/events, file interchange and document activation |
| Robustness | GC/heap stress, nested callbacks/exceptions, wrong-thread/no-activation rejection, partial construction, stale aliases and unload guards |
| Fault sensitivity | Planted missing cleanup/refcount release, wrong notification order, ignored cancel, damaged image/storage output and unrevoked registrations must fail |
| Applications | Bounded smoke, deterministic interactions, real desktops, persistence/interchange, cancellation/failure and zero-live-owned-resource checks |
| Delivery | Installed/relocated examples, fonts/dependencies/adapters, no-FFI behavior, source/tool identities and measured practical limits |

### Platform and engine acceptance

* Windows x86: native ABI/oracles, shared/native-only tests, applications,
  both bytecodes/interpreters and GC stress. Report the existing unavailable
  x86 JIT as unavailable, not as an executed pass.
* Windows x86-64: the same plus available baseline/optimizing JIT paths.
* Linux: headless mocks without SDL/DLLs/display; SDL driver/shared tests;
  real desktop/clipboard/drop/print-output checks; available interpreter/JIT
  paths and stress checks.
* Hosts/portability: supported hosts build the portable model/examples and
  deterministic generator outputs consistently. Extend generic FFI/layout/
  portability coverage for shared changes.
* Full repository: `make check JOBS=8`, the docs profile and applicable
  library/VM/layout/Windows profiles required by `AGENTS.md`. Linux
  `make check` does not establish native Win32 acceptance.

Existing commands for the starting implementation include:

```sh
make win32-generated
make check-win32-generated
bin/rune-win32-check contract 32
bin/rune-win32-check contract 64
bin/rune-win32-check app 32
bin/rune-win32-check app 64
make test-win32-sdl-contract
make test-win32-sdl-contract-gui
make test-win32-app-sdl
make test-win32-app-sdl-gui
bin/rune-test run --profile docs
make check JOBS=8
```

Use pinned SDK/MSVC roots and matching libffi-enabled VMs/adapters as their
guides describe. Actual Windows/desktop execution needs an environment
that can launch the processes. Sandbox launch failures keep their receipts
and do not count as native results.

Every completion record names source/dirty context, inputs, tools,
commands/environment, executed target/engine, verdicts, timings, artifacts
and limitations. Preserve failed attempts, flaky results, unavailable checks
and skips separately from passes. A focused successful rerun does not make
a failed full run clean. Keep durable receipts outside automatically pruned
runner output and state when results apply to an earlier snapshot.

A milestone is complete only after its native, SDL/mock, docs, example and
independent-reference gates pass, respecting its named native-only cases.
W20 requires all mandatory inventory rows accounted for and W0-W19 gates
met. Missing platform access, an unimplemented required operation or a
silent successful no-op leaves work outstanding.

## Risks and implementation limits

| Risk | Required response |
|---|---|
| Scope expands into all of Windows | Freeze selected declarations/behavior; retain mandatory families and version additions/exclusions |
| Historical availability inferred from modern SDK | Separate historical evidence from ABI/layout evidence; record DLL/structure versions |
| SDL/mock support lags native work | Require all portable gates in each milestone |
| Rendering differences hide errors | Separate logical state/canvas pixels from presentation; normalize only named differences |
| COM outlives VM resources | Root thunks/closures by native lifetime; pump inside valid entry; test revocation, reentry and unload |
| Mock OLE passes without usable apps | Require independent native exchange and working SDL Rune containers/components |
| Storage round trips share a bug | Cross-read/write with Windows; validate format invariants; inject corruption/short writes |
| Capstones hide missing contracts | Ship small focused examples/tests with each feature |
| Dependencies/packaging drift | Pin inputs/fonts, retain licences and run installed examples outside checkout |

## References

The existing Runeffi [contracts](../../ffi/contracts.md),
[generation guide](../../ffi/generation.md),
[sidecar policy](../../ffi/sidecars.md),
[capabilities](../../ffi/capabilities.md) and
[testing guide](../../testing.md) remain the implementation conventions.
The [three-provider example](../../../examples/win32/README.md) and
[shared suite](../../../tests/ffi/win32/README.md) are the starting point.

* [Programming Windows, fifth edition: publisher's contents][petzold].
* [Charles Petzold's edition page and errata links][petzold-author].
* [Microsoft shell DLL versions][shell-versions].
* [Microsoft common-control versions][control-versions].
* [Microsoft single-threaded apartment contract][sta].
* [Microsoft OLE/data-transfer interfaces][ole-interfaces].
* [Microsoft Automation reference][automation].
* [SDL3_ttf documentation and dependency/licence information][sdl-ttf].
* [MS-CFB: Compound File Binary File Format][cfb].
* [MS-OLEPS: Object Linking and Embedding Property Set Data Structures][oleps].

[petzold]: https://www.microsoftpressstore.com/store/programming-windows-9781572319950
[petzold-author]: https://www.charlespetzold.com/pw5/index.html
[shell-versions]: https://learn.microsoft.com/en-us/windows/win32/shell/versions
[control-versions]: https://learn.microsoft.com/en-us/windows/win32/controls/common-control-versions
[sta]: https://learn.microsoft.com/en-us/windows/win32/com/single-threaded-apartments
[ole-interfaces]: https://learn.microsoft.com/en-us/windows/win32/com/interfaces-odt
[automation]: https://learn.microsoft.com/en-us/previous-versions/windows/desktop/automat/automation-programming-reference
[cfb]: https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-cfb/50708a61-81d9-49c8-ab9c-43c98a795242
[oleps]: https://learn.microsoft.com/en-us/openspecs/windows_protocols/ms-oleps/bf7aeae8-c47a-4939-9f45-700158dac3bc
[sdl-ttf]: https://wiki.libsdl.org/SDL3_ttf/FrontPage

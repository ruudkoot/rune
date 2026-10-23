# Runeffi capability report

This report describes the implementation boundary as of 2026-10-23.
Milestone state and dated test receipts live in
[the roadmap](../plans/runeffi.md) and [acceptance evidence](../../tests/ffi/evidence).
An implemented component and a validated target are separate claims.

## Targets and execution

| Target | Native ABI/layout oracles | Dynamic calls and callbacks | GUI providers |
| --- | --- | --- | --- |
| Linux x86-64, LP64 | Native C and original SDL headers | Stack/register interpretation, both JIT tiers and existing `runeopt` execution tested | Core SDL3, Win32 over SDL3 and deterministic mock |
| Windows x86, ILP32 | Original Microsoft SDK and SDL headers; native 32-bit probes | Stack/register interpretation and x86 stdcall tested | Core SDL3 and native Win32; common mock also available |
| Windows x86-64, LLP64 | Original Microsoft SDK and SDL headers; native 64-bit probes | Stack/register interpretation and forced baseline/optimizing JIT tested | Core SDL3 and native Win32; common mock also available |
| Linux x86, ILP32 | Native C layout, adapter and binary32 probes | Dedicated pinned-libffi VMs: both interpreters, raw variadics, callbacks/status, marshalling and generated contracts tested | No GUI acceptance claim |
| Linux AArch64, LP64 | Cross-compiled C oracles executed by explicit QEMU wrappers | Dedicated pinned-libffi VMs: both interpreters and both JIT tiers, including raw variadics, callbacks/status and generated contracts tested under explicit QEMU | No GUI acceptance claim |
| Linux big-endian PowerPC64, LP64 | Cross-compiled C oracles executed by explicit QEMU wrappers | Dedicated pinned-libffi VMs: both interpreters, raw variadics, callback descriptors/status and generated contracts tested under explicit QEMU | No GUI acceptance claim |

The three Linux portability rows refer to the explicitly provisioned acceptance
VMs described in [Linux portability](portability.md), with
[dated receipts](../../tests/ffi/evidence/m10-linux-portability.md). Ordinary
portability/distribution build configuration is independent. Physical
AArch64/PowerPC64 hardware and GUI execution are not claimed.

No native Windows `runeopt` backend is introduced. Future direct native
linking is independent of the present dynamic library/libffi path. Optional
`FFI=no` builds retain ABI queries and portable SML libraries while rejecting
dynamic native operations. Existing GMP primitives retain their role.

## C and projection boundary

| Facility | Supported behavior | Visible boundary |
| --- | --- | --- |
| Original inputs | Rune/SML preprocessing, declarations, target constant/layout analysis, source locations; pinned unmodified originals and `.ffi` policy | A selected unsupported or ambiguous declaration fails with a source diagnostic |
| Scalars | Fixed signed/unsigned widths, pointers, float/double; profile-specific C aliases and checked ranges | Prepared libffi calls use fixed scalar signatures |
| Structs and unions | Target-aware SML byte representation, layout facts and native round trips | Aggregate passing uses generated C adapters where required |
| Packed fields and bitfields | Explicit native field adapters and adjacent-byte preservation tests | They do not become portable SML field-address arithmetic |
| Macros, inline functions, variadic calls | Typed C shims; fixed variadic adapters apply C default promotions; raw `prepareVariadic` retains an exact promoted signature through `ffi_prep_cif_var` | No inferred format-string protocol, variadic callbacks or unrestricted macro-expression interface |
| Strings and buffers | Explicit encodings, bounds/element counts, input/output direction, alias-preserving copies and every-return-path cleanup | Retained native storage requires explicit lifetime/ownership policy |
| Public SML | Records, options, abstract handles, returned outputs and named error policy; checked raw access retained | Adapter selections and original declaration mappings remain in manifests |
| Callbacks | Rooted closures, owning-thread synchronous entry, nested calls, bounded VM reentry, saved exceptions and annotated foreign failure values | Foreign-thread entry returns failure without SML execution; registration must end before explicit release |
| Native resources | Opaque identities, checked dependencies, guarded destruction, retry after native destructor failure | No native pointer is serialized into an image |
| Images and process state | Active resources reject unsupported save/restore/fork before state changes; expired identities remain expired across process restores | Image version 15 records an identity high-water floor; version 14 images must be recreated |
| Other interface families | Neutral model extension points | C++, Java, Web IDL/WebAssembly and direct native linking implementations are deferred |

The generated manifest distinguishes raw calls, explicit policy adapters,
layout sources and native shim artifacts. A shim is an output to compile
with the documented native toolchain; `.build` does not execute generation
or arbitrary commands. Regeneration and stale-dependency checks are explicit.

## GUI contract

The required inventories contain [53 SDL3 operations](../../ffi/sdl/inventory.json)
and [38 Win32 operations](../../ffi/win32/inventory.json). The three additional
[SDL support operations](../../ffi/sdl/support.json) serve the Linux Win32
driver and are separately inventoried. Audio, GPU APIs and foreign-thread
callback APIs remain deferred. SDL video/events require the main thread;
the embedding process owns startup and generated adapters do not hide it.

The [shared Win32 contract](../../tests/ffi/win32/README.md) covers window
registration/creation, creation-time and nested procedures, filtered message
copies with dispatch/discard, timers, painting, drawing state, ownership and
close/quit behavior. The SDL and mock implementations share one SML model.
Partial paints preserve pixels outside the update region. OS event streams,
window decorations, exact text pixels and scheduling need not match.

Portable Win32 drawing uses RGB colours, solid pens/brushes and the agreed
fixed ASCII text behavior. Unsupported flags/messages, palette encodings,
non-ASCII drawing and synthetic pointer-bearing messages raise explicit
unsupported errors. The native provider may offer OS behavior outside the
portable subset through its explicit raw layer. Deterministic mock traces
are an application-testing tool, not evidence that an OS event occurred.

## Acceptance and performance

Native reference-host acceptance includes documented compiler defects. All
three tested SML/NJ variants can miss duplicate unsigned callback selectors
through polymorphic `IntInf` equality; their generator fixture has 31 passes
and that one explained failure. With MLKit's default region inference, the
native program crashes before the fixture's first verdict; the unchanged 32 checks pass with
`-no_ri`. The [SML/NJ report](../bugreport/smlnj/IntInf/normalized-selector-equality/BUGREPORT.md)
and [MLKit report](../bugreport/mlkit/region-inference/BUGREPORT.md) retain
reproductions and exact failure shapes. Production libraries contain no
host workaround. The shipped Rune bytecode generator uses Rune's runtime;
the separately supplied native generator wrappers are MLton and Poly/ML.
Positive reference-host inspection agreement does not erase these negative
fixture failures.

The evidence distinguishes native checks, emulator checks, known host
deviations, missing tools, sandbox restrictions, failed initial runs and
successful exact reruns. A later successful rerun does not turn an earlier
failed full run into a clean run. Cumulative repository, Windows, bootstrap,
host and portability checks remain required before milestone completion.

[Performance measurements](performance.md) separate generation, loading,
preparation, scalar calls, marshalling and callbacks. Matching execution
phases use independent direct C baselines. Timing data is descriptive and
does not replace ABI or behavioral correctness checks.

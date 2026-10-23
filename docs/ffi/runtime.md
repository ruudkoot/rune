# Generic foreign-call runtime

`RuneForeign : RUNE_FOREIGN` is a trusted Basis extension. Ordinary libraries
use this interface without declaring primitives. The `foreign` primitive
supplies operation families for ABI queries, availability, libraries,
symbols, storage, views, preparation, invocation and release. One separate
`foreign_callback` primitive roots closures and prepares callback thunks.
This fixed pair is independent of the number of bound functions. GMP's
existing primitives remain separate.

`RuneForeign.abiFacts` measures architecture, CHAR_BIT, char signedness,
and scalar C widths/alignments before loading native libraries. Together
with `target`'s pointer size, byte order and calling-convention facts, this
distinguishes LP64, LLP64 and ILP32 profiles. The version-one wire payload
contains 24 bytes: version, architecture, character bits/signedness, then
size/alignment pairs for char, short, int, long, longLong, pointer, wchar,
float, double and bool. Both ABI queries remain available without libffi
and allocate no native registry resources.

## Builds and targets

`make FFI=auto` uses the native target's `pkg-config libffi` installation
when available, or an explicit static `FFI_PREFIX`. `FFI=yes` requires a complete
prefix or the system development library; `FFI=no` selects deterministic
unavailable operations and introduces no libffi dependency. `SYS=none`
selects unavailable support. The feature selection stamp invalidates native
archives and diagnostic VM variants. `build/foreign-libs` records the
native archive's link dependencies; `runeopt` and installation carry that
metadata with the archive. VM provenance records include FFI flags.
An installed static-prefix runtime carries a verified `libffi.a` beside
`librune.a`; its `@RUNTIME@/libffi.a` metadata follows the runtime directory when
it moves. `runeopt` resolves that token before quoting linker arguments.

Windows cross builds use separate target prefixes:

```
make windows FFI_WIN64_PREFIX=build/deps/libffi-win64/install \
             FFI_WIN32_PREFIX=build/deps/libffi-win32/install
```

Each prefix contains that target's `include/ffi.h` and `lib/libffi.a`.
The pinned libffi source and checksum are in `ffi/libffi/source.json`.
A missing cross prefix builds the unavailable bridge; native include and
link flags never enter another target's build. Provisioning those prefixes
is an explicit development step; no build description executes commands.
Linux x86, AArch64 and big-endian PowerPC64 use separately provisioned target
prefixes and explicit FFI acceptance VMs. Ordinary portability builds retain
their existing optional-feature configuration. The capability report names
the tested binaries and distinguishes native execution from QEMU execution.

The scalar call interface covers fixed signed/unsigned 8/16/32/64-bit
integers, float, double, void results and pointers. ABI 0 is the target
default; ABI 1 is x86 Windows stdcall. `RuneForeign.target ()` reports native
pointer bytes, byte order and stdcall support, independently of the SML
word representation. For example, 32-bit Windows C `size_t` is 32 bits even
when the portable SML word representation is wider. Invalid argument types, ranges,
argument counts and unsupported conventions fail before native entry.
Aggregates use typed C adapters; same-thread closures use the explicit
[callback protocol](callbacks.md). No direct-link backend exists.

`prepareVariadic` prepares an outgoing C variadic interface with a nonempty
fixed prefix and the complete argument types. The caller applies C default
promotions to tail types and values: `float` becomes `double`, and integers
narrower than C `int` become `int` or `unsigned int` as required by the target.
The runtime rejects unpromoted types, invalid counts and nondefault ABIs
before native entry. It uses `ffi_prep_cif_var` even when the tail is empty,
as required by the [libffi manual](https://github.com/libffi/libffi/blob/master/doc/libffi.texi).
Each prepared resource retains its exact complete signature for reuse; a
different tail requires a different prepared resource. Release cached calls
explicitly before their symbols/libraries. Generated idiomatic bindings use
sidecar-selected fixed typed adapters; no format-string inference or variadic
callback entry is provided.

## Resources and memory

The native registry belongs to one VM. A process-wide atomic identity
allocator never reuses identities, including across different VMs. SML
contains identities and liveness tombstones, never native addresses.
Libraries retain symbols; symbols retain prepared calls; native pointer
results retain their library. Views retain their source allocation or view.
Release rejects stale resources, active prepared calls, leased arguments
and live dependents. Native calls lease pointer arguments until native
execution returns. Reserved result identities survive registry growth
during native reentry without retaining a movable registry address.
The VM releases remaining registry resources on shutdown.

Foreign allocations contain zeroed bytes outside the moving heap. Reads
copy bytes to immutable SML strings; writes copy bytes from SML strings.
A view shares native storage, so mutations are visible to all its aliases.
Reads, writes and views of allocations are checked with subtraction-based
bounds tests, including empty and one-past-end runs. Pointer results inside
known allocations inherit their remaining range and retain their backing
allocation. Other native pointer results have caller-established extents:
the raw bridge cannot infer the native allocation's size or ownership.
The higher layer must apply sidecar bounds and the proper deallocator.
Releasing a pointer identity alone never frees native-owned storage.

No borrowed SML heap address survives the primitive. Call arenas hold native
scalar copies and resource addresses. Result construction roots each SML
partial value on the VM stack before allocating another. Existing GC
handles and pin/copy operations remain the facilities for subsequent
retained SML values and callbacks; resource identities do not replace GC
roots. Asynchronous access to copied storage needs explicit retained
resources, not temporary call arenas.

Native error state is captured immediately after `ffi_call`, through the
system layer, before arena cleanup or SML conversion. The result preserves
raw status bits and both `errno` and the Windows native error number.
Bindings interpret success and failure using their sidecars. Calling a
native deallocator can change current native error state without changing
the previously returned capture.

## Images, processes and interactive use

Saving, restoring into a VM, or forking with live foreign resources fails
with `EBUSY` before opening/truncating an image or flushing/changing process
state. Closed SML tombstones can enter portable images and remain stale
after restore in another process. The restored VM starts with an empty
native registry. Native `runeopt` programs use the same primitive and rules.
REPL code can use the Basis bridge, but must explicitly release resources
before requesting an image or unloading their owner library.

Callbacks use an explicit VM entry delimiter, rooted closures, owning-thread
guards and saved-exception propagation. The existing no-nested-driver rule
remains enforced: the bounded interpreter callback loop does not call
`vm_loop`, compile JIT code or invoke another engine driver. See the
[callback lifecycle contract](callbacks.md) for suspended frames and shutdown.

## Reproduction

```
make test-ffi-runtime JOBS=8
make test-ffi-runtime-asan JOBS=8
make test-ffi-runtime-windows JOBS=8
make vm FFI=no
bin/rune tests/ffi/disabled.sml -o build/foreign-disabled.rbc
bin/runevm build/foreign-disabled.rbc
make vm FFI=auto
```

The runtime suite compares native scalar and pointer behavior, aliasing,
missing libraries/symbols, both x86 Windows conventions, native ownership,
error capture, bounds, stale handles and dependency release. C tests inject
registry/preparation/call-arena allocation failures. Image tests preserve a
sentinel destination on rejected saves, then save and restore closed
handles. Sanitizer and GC-stress executions complement these contracts.
Acceptance commands, toolchains and outstanding checks belong in the dated
milestone evidence rather than inferred platform claims.

## Guarded native ownership

`RuneForeign.dispose` combines an annotated native destructor with registry
retirement. It checks active uses and live views before any native entry,
marks the target as being destroyed, and rejects nested reads, views, reuse
or release during destruction. Its destructor alone may receive that
retiring pointer. The native return/error capture precedes cleanup. A
zero/nonzero/negative failure predicate preserves ownership for retry;
success closes the identity even if later SML result construction fails.
Void destructors require the unconditional-success policy. Floating and
pointer-valued destructor results require a separately specified adapter.

This operation accepts external pointers, not Rune allocations or returned
pointers retaining Rune-owned storage. Dropping a raw pointer identity still
does not invoke a native deallocator. `sameAddress` compares pointer values
without exposing an address, and `isLive` refreshes SML tombstones after
retirement. Old identities are never reused for a new allocation.

These guards are the strict memory-ownership contract. Opaque GUI handles
whose native APIs explicitly permit destruction during a synchronous
message require a separately specified callback/lifecycle protocol; they
are not silently exempted from memory leases.

Sanitizer fixtures keep native allocation/deallocation in one coherent
symbol namespace. A direct per-library lookup of libc allocation functions
can bypass sanitizer interposition for one member of a pair; the retained
independent C reproducer is `tests/ffi/research/libc-asan.c`. The runtime does
not silently substitute symbol names. Its fixture library calls its
allocator and deallocator normally, allowing sanitizer instrumentation to
observe both ends of the ownership contract.

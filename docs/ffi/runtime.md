# Generic foreign-call runtime

`RuneForeign : RUNE_FOREIGN` is a trusted Basis extension. Ordinary libraries
use this interface without declaring primitives. One `foreign` primitive
supplies operation families for availability, libraries, symbols, storage,
views, preparation, invocation and release. Adding functions to a binding
adds no primitive. GMP's existing primitives remain separate.

## Builds and targets

`make FFI=auto` uses the native target's `pkg-config libffi` installation
when available. `FFI=yes` requires it; `FFI=no` selects deterministic
unavailable operations and introduces no libffi dependency. `SYS=none`
selects unavailable support. The feature selection stamp invalidates native
archives and diagnostic VM variants. `build/foreign-libs` records the
native archive's link dependencies; `runeopt` and installation carry that
metadata with the archive. VM provenance records include FFI flags.

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
Other cross targets currently retain unavailable support. Extending their
provisioning and executing their ABI fixtures remain portability gates.

The initial call interface covers fixed signed/unsigned 8/16/32/64-bit
integers, float, double, void results and pointers. ABI 0 is the target
default; ABI 1 is x86 Windows stdcall. `RuneForeign.target ()` reports native
pointer bytes, byte order and stdcall support, independently of the SML
word representation. For example, 32-bit Windows C `size_t` is 32 bits even
when the portable SML word representation is wider. Invalid argument types, ranges,
argument counts and unsupported conventions fail before native entry.
Aggregates, outbound varargs, closures and foreign-thread entry require the
later marshalling and callback milestones. No direct-link backend exists.

## Resources and memory

The native registry belongs to one VM. A process-wide atomic identity
allocator never reuses identities, including across different VMs. SML
contains identities and liveness tombstones, never native addresses.
Libraries retain symbols; symbols retain prepared calls; native pointer
results retain their library. Views retain their source allocation or view.
Release rejects stale resources, active prepared calls and live dependents.
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

Callbacks are not enabled by this milestone. The existing driver nesting
constraint is still enforced. Later callbacks must use an explicit VM
entry delimiter, rooted closures, owning-thread guards and saved-exception
propagation; libffi closures alone do not supply those requirements.

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

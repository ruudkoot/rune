# Foreign callbacks and VM lifecycle

`RuneForeign.callback` makes a generic scalar libffi closure. Its resource
retains a GC handle to a trusted SML wrapper, including the user closure and
its environment. The caller unregisters retained native callbacks before
explicitly releasing the resource. An active callback or a callback passed
to a suspended native call cannot be released.

The context belongs to its creating OS thread. Closure entry compares a
thread-local identity before reading the VM or mutable resource registry.
Another thread, or entry outside a native call belonging to the context,
returns the annotated native failure value without executing SML. Failure
selection supports an integral argument index and a table of raw values:
Win32 `WM_NCCREATE` can return zero, `WM_CREATE` minus one, and all other
messages the annotated default. Failed thread entry does not raise an SML
exception on a different thread.

## A bounded callback delimiter

The register driver remains nonrecursive: no engine calls `vm_loop`, another
driver, the JIT compiler, or native entry. A foreign callback is an explicit
bounded interpreter scope. It pushes a frame above the parked caller,
runs the ordinary interpreter with no JIT program, and stops at that frame's
`RET` before it touches the parked caller's return word. A maximum of 64
nested callback scopes bounds growth of the C stack. Interpreted calls and
tail calls inside the scope retain their ordinary semantics. Nested foreign
calls may synchronously open another callback scope.

This is the narrowly defined exception to the former prohibition on any
bytecode execution from a native helper. It does not permit unrestricted
driver reentry. The register callback interpreter cannot tier up, perform
OSR, invalidate code, rebuild a JIT program, or change executable pages.
`runeopt` retains a stack-bytecode callback interpreter; it never reenters
`rune_enter`. Unit loading and changes to debugger mode are rejected before
state changes while a callback scope is active. Save, restore and fork
already reject live foreign resources before changing state. User interrupts
are deferred until native control returns.

The parked frames remain on the VM value stack. Each callback scope saves
the suspended native frame's precise live mask by stable frame identity.
Full and minor collection consult those masks while scanning waiting frames.
Callback execution clears the running-frame native mask and restores native
frame addresses from indices after any value-stack or frame-array relocation.
No unrooted SML pointer remains in C across collection.

## Exceptions and resources

The trusted SML wrapper catches an escaping user exception and returns the
selected native failure value. Each native call has its own activation and pending exception, rooted in
SML. Once a callback fails, subsequent callbacks in that activation return
their message-specific native failure value without entering SML. Nested
activations retain independent pending exceptions.
`invoke`, `dispose` and `consumeHandle` re-raise it only after native control
has returned, native errors have been captured, and native lease cleanup has
finished. Nested invocations move that same exception through enclosing
callback wrappers without unwinding a C frame. `invokeDeferred` exposes the
raw result and an optional `callbackException` before propagation. Generated
ownership adapters use it to destroy an owned result even when native code
returns a non-null pointer after a callback failed. Ordinary `invoke` can
release an unexposed registry identity but cannot infer its native
deallocator. Later invocations do not inherit a consumed saved exception.

Native callback pointer arguments have temporary registry identities. They
may be used during the callback and expire on return. A native closure's
result is converted before temporary argument identities are retired.

`aliasHandle` adopts an opaque pointer into a canonical handle identity that
retains its native library. Creation-time window callbacks may therefore
adopt a window before its creation call returns; adopting the returned
pointer finds the same public identity. Handles cannot be read, written or
viewed as memory.

`consumeHandle` permits destruction of an opaque handle while an outer
native caller is suspended using it. Native uses remain available to nested
destruction callbacks; recursive destruction rejects. Native success retires
every native pointer alias at that address. Suspended leases keep internal
bookkeeping alive until they return, without making the identity publicly
live. Native failure preserves the handle. Rune-owned memory and ordinary
native memory keep the stricter `dispose` guards for active uses and views.

Callback unregistration is a foreign API obligation: calling executable
closure storage after it has been released is invalid native behavior.
Foreign-thread callbacks, audio callbacks, and arbitrary asynchronous SML
entry remain outside the delivery contract.

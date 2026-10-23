# Runeffi implementation contracts

The delivered public surface is [WIN32](../../lib/ffi/win32/common/win32_sig.sml)
with [shared types](../../lib/ffi/win32/common/types_sig.sml). Native and
portable implementations share one sealed logical type module and the same
behavioral contract suite. The earlier [M0 SML contracts](../../ffi/contracts/)
remain design/type-sharing fixtures; their `Win32SharedContract` checks the
original type equations during elaboration.
Raw pointers never serve as portable window or paint identities.

## Win32 observations

A class must be registered before creation. `WM_NCCREATE` and `WM_CREATE`
run synchronously before `createWindowEx` returns. The logical window and
its callback registration must already exist when either message arrives.
A failing `WM_NCCREATE` callback returns zero; a failing `WM_CREATE` returns
minus one. Other callback exceptions return zero, preserve the first
exception as a GC root, and rethrow it only after C returns and cleanup
finishes. Subsequent callbacks in the same failed activation return the
message-specific failure value without executing SML. `Default` invokes
the platform default procedure; it is distinct from an explicit zero.

`sendMessage` dispatches synchronously and permits nested sends on the
owning UI thread. Posting enqueues a message; it does not invoke the
procedure immediately. Paint invalidations may coalesce. `withPaint`
brackets `BeginPaint`/`EndPaint` on normal and exceptional returns. A paint
identity cannot be used after its lease ends. An owned pen/brush cannot be
deleted while selected; restore the object returned by `selectObject`
first. Stock objects and module handles are borrowed and cannot be freed.

`WM_CLOSE` defaults to destruction. Destruction delivers `WM_DESTROY`
followed by `WM_NCDESTROY`, unregisters retained callback state after native
destruction, cancels timers, and invalidates the logical handle. Repeated
destruction and all stale resource uses raise a deterministic error.
`getMessage` distinguishes error, quit status and a message. Timers use a
null native timer callback and deliver `Timer` through the window procedure.
`Char` preserves individual UTF-16 units. Drawing tests compare operations
and observable results; OS scheduling and rasterization may differ.

Queued messages are explicit copied resources. Dispatch consumes a copy on
every returning path; `discardMessage` releases a copy that will not be
dispatched, including lookahead snapshots from PeekMessage. Translating,
dispatching or discarding a consumed copy raises a stale-resource error.
Provider shutdown also releases undispatched copies. Native MSG storage
stays outside portable images. The discard operation extends the original
prototype signature so long-lived lookahead loops can release every copy.

The SDL and mock subsets support resizable top-level windows, solid pens
and brushes, basic lines/rectangles and fixed ASCII text. They reject
unsupported native flags and drawing modes explicitly. No backend invents
foreign pointer payloads. Native titles preserve WTF-8/lone surrogates;
SDL titles accept Unicode scalar UTF-8 and reject lone surrogates.

## Runtime ownership and delivery gates

The roadmap's [runtime contracts](../plans/runeffi.md#runtime-contracts)
remain authoritative. Descriptors are serializable; native sessions,
allocations, prepared calls and closures are process-local registry
resources with ownership, liveness and dependency checks. Process-wide
monotonic identities and the saved image floor prevent stale identity reuse. Explicit
release diagnoses double release. Images/fork/restore and REPL mutation
reject live-resource/activation conflicts before changing state.

Ordinary buffers copy through call arenas. Retained storage is separately
owned. Annotated overlapping views share one allocation; shared mutation
during callbacks requires foreign-backed memory. Capture native errors
before conversion/cleanup. No SML exception unwinds through C. Callback
entry requires an active foreign delimiter on the owning VM thread;
foreign-thread attachment is outside this delivery. Suspended engine
frames remain rooted and JIT code replacement is frozen until return.

These are required behaviors, not claims that the runtime implements them
at M0. The inventory's unresolved entries, milestone states and dated
evidence distinguish contracts from completed work.

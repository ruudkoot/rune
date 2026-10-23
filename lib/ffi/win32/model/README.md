# Win32 GUI semantics

Area: Foreign interfaces

`Win32ModelFn` implements the agreed Win32 GUI subset over a thin drawing,
window, event and clock driver. SDL3 and deterministic mocks use the same
class registry, creation-time and nested procedure calls, message queue,
filtering, message timers, invalidation, paint scopes and GDI ownership.
All public identities come from `Win32Common.Types`.

Each synchronous dispatch has its own exception boundary. A failing
procedure returns its message-specific failure result while the activation
finishes cleanup; subsequent calls in that activation skip user code. The
original exception is raised on return to the caller. Nested calls have
independent boundaries, so an application can handle an inner exception.

The portable subset accepts top-level windows, zero extended style, solid
pens and brushes, supported stock objects, and printable ASCII drawing.
Titles use scalar UTF-8. Unsupported flags and drawing modes raise
`Types.Unsupported`. The driver owns rendering and external event input;
normalized contract tests compare operations rather than exact pixels or
OS event streams. A deterministic mock without queued events or active
timers reports an explicit unsupported blocking wait.

Paint invalidations intersect the current client rectangle and may coalesce
into their bounding rectangle. The driver receives that clip at BeginPaint
and retains backing pixels outside later partial repaints. Copied messages
must be dispatched or explicitly discarded; both consume their identity.
Normalized traces include paint rectangles and fill colours.

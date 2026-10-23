# Runeffi sidecars, version 1

A `.ffi` file is UTF-8 JSON policy stored beside original headers. It never
modifies a header, executes a command or inserts SML source. The reusable
`ffi/model` library decodes and validates it separately from target layout
and executable generation. All diagnostics identify the sidecar's physical
file, line and column; foreign declarations retain their own source mapping.
Duplicate keys point at the second key, and unknown fields are errors.

## Root and selection

Required root fields are `version` (currently `1`), `family` (currently
`"c"`), `structure` (one legal SML structure identifier), `headers` and
`libraries` (ordered string arrays), `functions` and `callbacks` (arrays).
Optional `resources` is an array of distinct abstract SML type names.
It defaults to an empty array; referring to an undeclared resource fails.
Libraries and header paths are data for later acquisition/loading consumers.
Original-source manifests pin their provenance independently of policy.

Each function requires `foreign`, `name`, `parameters`, `result`, `errors`,
`variadic` and `unsafeRaw`. `foreign` names an exact declaration identity;
`name` is a legal SML member path such as `User.createWindowEx`. Optional
`namespace` selects `function` (the default) or `macro`. Selected macros
require explicit typed shim lowering before they can become calls. Optional
`raw` supplies an unqualified raw SML name; otherwise a deterministic escape
maps foreign identifiers to legal names. Complete selections are checked
for duplicate foreign identities and public/raw name collisions. Optional
`adapter` names an adapter capability, as data; the generator must resolve
that capability rather than treating it as source or a shell command.

Selection is explicit. Unrelated, unselected header declarations can remain
unsupported. Selecting a missing, incompatible or ambiguous declaration
fails. Repeated compatible declarations coalesce using canonical original
source positions. Selection closures retain referenced aliases and shared
type identities. Physical traversal order does not determine output order.

## Values and memory

`parameters` contains value objects with a required foreign `name`.
`result` is a value object without a parameter name. The following keys are
available; declaration-aware validation requires enough information for the
selected interface and does not infer ownership from a pointer type.

| Key | Meaning |
|---|---|
| `direction` | `"in"`, `"out"` or `"inout"`; pointer parameters require it |
| `ownership` | Exactly one of `{"borrowed": SCOPE}` or `{"owned": DEALLOCATOR}` |
| `nullable` | Whether native null is a valid value; non-null projections can still raise on a declared null failure |
| `encoding` | `"bytes"`, `"utf8"`, `"wtf8"` or `"utf16"` |
| `terminator` | Explicit Boolean: whether a string uses a native NUL terminator |
| `length` | A nonnegative integer element count or the name of an integral count parameter |
| `callback` | A callback policy name, separate from pointer ownership |
| `type` | A structured SML projection type |
| `output` | The public label of a returned output value |
| `consumes` | Explicit release/ownership consumption of an input resource; defaults to false |

Borrowed scopes are `call`, `static`, `library`, `parameter:NAME`, or an
explicit callback registration owner. Unknown scopes fail. A returned
resource cannot borrow a call arena that has already ended. Owned results
name a real fixed-arity deallocator with a resource argument. A resource
identity's release and the native deallocation policy remain distinct.
Output policies cannot write through const pointers. Output buffers need
bounds; input buffers need an extent or explicit terminated-string policy.
Native pointer results projected as abstract resources retain their native
identity; subsequent marshalling must establish accessible byte extents.

Scalar output parameters with an `output` label can become returned SML
values. Nullable projections require `option`; contradictory non-null
options fail. Strings need an explicit terminator or length, including
optional strings. Length names must resolve to integral parameters (including
integral output counts). Runtime conversion still checks negative counts,
overflow and byte-size multiplication using the selected target layout.

Projection types use fixed names: `unit`, `bool`, `int`, `int8`, `word8`,
`int16`, `word16`, `int32`, `word32`, `int64`, `word64`, `real`, `string`,
and `bytes`. Structured forms each contain exactly one constructor:

```json
{"option": "string"}
{"resource": "window"}
{"array": "word8"}
{"vector": "bool"}
{"tuple": ["int", "int"]}
{"record": {"width": "int", "height": "int"}}
```

The fixed renderer maps these to ordinary SML types. It copies no arbitrary
SML text from a sidecar. Resource names and record labels are checked SML
identifiers; resource definitions must be declared at the root. Type
compatibility, target widths, layouts and any required adapters are separate
lowering checks before executable generation.

## Public arguments, outputs and errors

Optional `input` and `returns` group existing native values. A string names
one foreign parameter; `$result` names the native result in `returns`.
Structured grouping uses `{"unit": true}`, `{"tuple": [...]}` or
`{"record": {"label": ...}}`. Every leaf resolves uniquely. An input cannot
refer to an output-only parameter, duplicate a leaf, or omit a required
native argument without an explicit adapter/derived length relationship.
These forms are data, not SML expressions.

Without explicit grouping, no inputs become `unit`, one input retains its
type, and multiple inputs form a tuple. Output parameters become a returned
record, using their public labels. A non-unit native result occupies the
`result` field alongside outputs. An explicit result projection of `unit`
can consume a foreign success status after the binding checks its errors.
`ForeignProjection.callType` combines these rules with separately established
native value types, keeping target inference outside projection policy.

`errors` contains `predicate` and `capture`, and optionally `getter`.
Predicates are `none`, `null`, `false`, `negative`, `zero`, `nonzero` and
`minus-one`. Capture is `none`, `errno`, `win32` or `text`. Text capture
requires a declared zero-argument character-string getter; a getter with
another capture mode fails. Native error state must be captured before
conversion or cleanup changes it. The raw layer preserves native statuses
regardless of the public exception/result projection.

## Callbacks and variadic functions

Each callback requires `foreign` (a function-pointer typedef), `lifetime`
(`call` or `registered`), `thread` (`owner-vm-thread` only), and `failure`.
Registered lifetimes also require an `owner`. Variadic callbacks fail.
A callback failure is a native integer or a message-specific table:

```json
{"parameter": "arg1", "cases": {"WM_CREATE": -1, "WM_NCCREATE": 0}, "otherwise": 0}
```

The selector must name an actual callback parameter; unnamed parameters
use `arg0`, `arg1`, and so on. The target/layout consumer checks values and
constant names against the native result type. The runtime must retain the
closure, contain exceptions, return the annotated failure and re-raise the
saved exception after native control safely returns to SML. Decoding a
policy does not claim runtime callback support.

`variadic` is `reject` or `raw`. A variadic selection requires explicit
`raw` plus `unsafeRaw: true`, or a resolved fixed adapter. A raw declaration
still needs a supported ABI lowering; an annotation does not make a runtime
feature exist. `unsafeRaw` permits explicit low-level pointer access while
preserving selection, syntax and unsupported-type diagnostics. Long double,
complex, vector ABI types and unprototyped calls fail in the current backend.

## Coverage and examples

`ForeignCoverage` reports each foreign identity and original source as
`selected`, `generated`, `shimmed`, `unselected` or `unsupported` with a
reason. Selection alone never means code was generated. Stale, duplicate
or conflicting implementation claims fail. Later generation supplies
artifact evidence for `generated`/`shimmed` entries.

[The fixture policy](../../tests/ffi/fixture.ffi) covers scalars, records,
owned strings, a matching deallocator, aliasing buffers, a registered
callback, error capture and explicit raw variadics. The pure library suite
contains positive and negative schema/declaration fixtures and projection
goldens. The [SDL policy sample](../../tests/ffi/model/sdl.ffi) and
[Win32 policy sample](../../tests/ffi/model/win32.ffi) exercise original
header declarations, owned and borrowed values, output grouping, native
errors and the window-procedure failure table. They are policy examples,
not completed library implementations. The SDL/Win32 inventory check must resolve every selected identity
on each pinned target; unreviewed ownership remains a visible blocker until
its binding policy and runtime capability are available.

# Libraries

The libraries that come with Rune, grouped by what they are for. Each is a
directory of `lib/` with a MANIFEST, documented from the signatures it is
built from. A program asks for one by name, `rune --library NAME`; the Basis
Library is what every program starts with.

## The Basis Library

| Library |  |
| --- | --- |
| [The Standard ML Basis Library](basis/README.md) `basis` | The library every Standard ML program starts with: lists and options, sequences, text, numbers, input and output, and the operating system. |

## Testing

| Library |  |
| --- | --- |
| [Random numbers](random/README.md) `random` | Pseudo-random numbers: SplitMix64, a generator that can be split into two independent ones and read as a hash of a counter. |
| [Property testing](test/property/README.md) `test/property` | Property testing in the style of QuickCheck. Generators draw values, observers say what a generated function sees of its argument, printers show a counterexample, and an arbitrary holds those with the equality of a type. A property is what must hold for every value a generator draws, and it is run over many cases, each from its own seed. |
| [Property testing: the Basis Library's arbitraries](test/property-basis/README.md) `test/property/basis` | Arbitraries for the types of the Basis Library. There is one for each structure, and functors make an arbitrary from a structure of `INTEGER`, `WORD`, `REAL`, `CHAR`, `STRING` and the monomorphic sequences. |
| [Unit testing](test/unit/README.md) `test/unit` | Unit tests as values. A test is the unit of a verdict and the checks inside it are soft. Golden files hold what a test must produce. A suite names its tests, so a program can list them, filter them and run them as `main`. |
| [Running tests](test/runner/README.md) `test/runner` | Running tests that are commands. A scheduler decides which jobs to start and a supervisor runs them as children, ending one that ran too long or wrote too much. The history records what earlier runs found, and the command line says which tests to run. |

## Text and terminals

| Library |  |
| --- | --- |
| [Unicode](unicode/README.md) `unicode` | UTF-8, read and written strictly, the display width of a code point, grapheme clusters as Unicode Standard Annex \#29 defines them, the normalisation forms NFC and NFD of Annex \#15, the identifiers of Annex \#31 with the profile that Rune takes for Standard ML, and the security mechanisms of Unicode Technical Standard \#39. |
| [Pretty printing](pretty/README.md) `pretty` | Documents laid out at a width: Wadler's prettier printer, as Lindig wrote it, with annotations a renderer turns into styles and budgets that cut a deep or long value short. |
| [Markdown](markdown/README.md) `markdown` | Markdown: CommonMark's blocks and inlines, with GitHub's tables, parsed into a tree and written back as HTML or as a document of `Pretty`. |
| [Terminal](terminal/README.md) `terminal` | A terminal as a line editor uses it. Colours and attributes, the keys a terminal sends, the device in raw mode, and an emulator for tests. The history of a prompt is kept in a file several sessions share, and the editor draws one line or many. |

## Protocols

| Library |  |
| --- | --- |
| [JSON](json/README.md) `json` | JSON (RFC 8259): values read from text and written back. |
| [JSON-RPC](jsonrpc/README.md) `jsonrpc` | JSON-RPC 2.0. Requests, notifications and responses are values, read from JSON and written to it, and a framing cuts them out of a byte stream: a line each, or a `Content-Length` header, as the Language Server Protocol and the Debug Adapter Protocol frame theirs. |
| [Debug Adapter Protocol](dap/README.md) `dap` | The Debug Adapter Protocol's messages. Requests, responses and events are values, read from JSON and written to it, framed as the protocol frames them. |
| [ZMTP](zmtp/README.md) `zmtp` | ZeroMQ's sockets over ZMTP 3.1 with the NULL mechanism, on the Basis's TCP sockets, and the bytes of that protocol: the greeting, the frames and the commands. |
| [Jupyter](jupyter/README.md) `jupyter` | Jupyter's messaging protocol for a kernel: the connection file, the signed messages of the wire, and a kernel's loop on its five channels, the language's part given as handlers. |

## Digests

| Library |  |
| --- | --- |
| [Digests](digest/README.md) `digest` | Hash functions read in pieces, bytes written as hexadecimal, and HMAC over a hash. MurmurHash2 is here too: a fast hash that is no digest, which is what a notebook's cell is named by. |

## Languages

| Library |  |
| --- | --- |
| [C declaration frontend](language/c/README.md) `language/c` | This library preprocesses and parses C interface descriptions in Standard ML. It has no dependency on a C compiler or an FFI runtime. Include loading is an explicit resolver, and target predefinitions and expression widths are caller-supplied. It does not infer SML names, ownership or errors. |

## Foreign interfaces

| Library |  |
| --- | --- |
| [Foreign binding model](ffi/model/README.md) `ffi/model` | This library separates original foreign declarations, target layout facts, and SML projection policy. It contains no native loader or compiler primitive. `ForeignModel` adapts C declarations, preserves source identities and aliases, and computes deterministic selection closures. Other source families require explicit backends; they never silently become C pointers. |
| [Foreign byte marshalling](ffi/marshal/README.md) `ffi/marshal` | Portable SML support for target integer, binary32 and binary64 representations, explicit byte/text encodings and deterministic cleanup scopes. Native addresses and VM operations belong to the runtime support library. |
| [Foreign runtime support](ffi/runtime/README.md) `ffi/runtime` | Ordinary SML support over the trusted `RuneForeign` bridge. No primitives are declared here. `ForeignMemory` owns or bounds native storage and supplies scoped copies of borrowed SML byte arrays. Overlapping arguments referring to the same array share backing storage and preserve native aliasing. |
| [Shared Win32 GUI contracts](ffi/win32/common/README.md) `ffi/win32/common` | The native Windows, SDL3 and deterministic mock implementations share `Win32Common.Types`. Their registries validate every identity and reject values belonging to another implementation or an ended lifetime. Provider support factories create unregistered tokens; they carry no native pointer or permission to use a native resource. |
| [Win32 GUI semantics](ffi/win32/model/README.md) `ffi/win32/model` | `Win32ModelFn` implements the agreed Win32 GUI subset over a thin drawing, window, event and clock driver. SDL3 and deterministic mocks use the same class registry, creation-time and nested procedure calls, message queue, filtering, message timers, invalidation, paint scopes and GDI ownership. All public identities come from `Win32Common.Types`. |
| [Deterministic Win32 GUI mock](ffi/win32/mock/README.md) `ffi/win32/mock` | `Win32Mock` implements `WIN32` through the same semantics as the SDL3 provider. Its in-memory driver advances a deterministic clock, creates no native resources, and records normalized API operations. Injection, time advancement and trace controls support reproducible contract tests. A blocked GetMessage with no queued event or active timer raises an explicit unsupported operation instead of waiting for an external source. |
| [SDL3](sdl/README.md) `sdl` | `SDLFn` implements Rune's core SDL3 signature over generated declarations and layout facts. It covers all 53 entries of `ffi/sdl/inventory.json`: startup, windows, copied events, keyboard and mouse input, text input, surfaces, 2D rendering, debug text, clipboard text, and clocks. The separately inventoried M9 support operations add native window positioning, renderer clipping and SDL hints. `SDL_free` is used internally for owned clipboard results. Audio, GPU APIs, application-entry integration, and callbacks from foreign threads remain outside this core. |
| [Win32 SDL GUI driver](ffi/win32/sdldriver/README.md) `ffi/win32/sdldriver` | `Win32SdlDriverFn` implements the thin `WIN32_GUI_DRIVER` contract using the sealed SDL3 projection. It owns SDL windows, a persistent ARGB8888 canvas and software renderer per window, a separate display renderer, and clipped drawing scopes. Shared Win32 class registration, creation callbacks, message dispatch, timers, paint regions and GDI object policy belong to the separate shared model. The driver never invokes a window procedure. |
| [Native Win32 GUI bindings](ffi/win32/native/README.md) `ffi/win32/native` | `Win32NativeFn` implements the shared `WIN32` GUI contract over generated original-header descriptors and typed C field adapters. Native pointers remain in `RuneForeign`; public tokens share `Win32Common.Types` identities. Use the Windows-width build entrypoint after regenerating the binding set and compiling its field adapter DLL. Close windows, classes and owned GDI objects before the provider's explicit `close` operation. |

---

<sub>Generated by runedoc; do not edit.</sub>

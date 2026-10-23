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
| [Foreign byte marshalling](ffi/marshal/README.md) `ffi/marshal` | Portable SML support for target integer and binary64 representations, explicit byte/text encodings and deterministic cleanup scopes. Native addresses and VM operations belong to the runtime support library. |

---

<sub>Generated by runedoc; do not edit.</sub>

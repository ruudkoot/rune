# Measuring foreign interfaces

`make ffi-performance` writes `tests/out/ffi-performance/results.json` and
retains every subprocess argument vector, stdout and stderr alongside it.
Use a fresh `FFI_PERF_OUT` for each measurement. `FFI_PERF_ITERATIONS`
defaults to 10,000 and `FFI_PERF_SAMPLES` to five. `FFI_PERF_MODE` selects
`off`, `baseline`, `opt` or `all`; the default measures register
interpretation. Correctness tests and timing thresholds are separate.

The SML coordinator builds an independent shared C subject and a direct C
executable, checks their checksums and alternates execution order between
samples. Each result records CPU time, iteration count and checksum; Rune
also records elapsed wall time. The summary gives median CPU nanoseconds
per operation and a ratio where a matching direct C phase exists. Source
and subject hashes, compiler/VM identities, options, revision and OS facts
make the measurement attributable. Repeat on an otherwise idle machine
for performance decisions; a small direct C interval has clock-resolution
noise even when Rune's interval is longer.

The phases have distinct meanings:

| Phase | Measured work | Direct C comparison |
| --- | --- | --- |
| generation | Read the small fixture's original headers, sidecar and target; preprocess, parse, analyze, generate, hash dependencies and package an immutable set, ten repetitions | None: this fixture has no comparable C generator |
| load-symbol | Open library, resolve one symbol, release symbol and library | None: reported as Rune loader startup work |
| prepare | Prepare and release one fixed scalar call, using an already resolved symbol | None: a direct C call needs no libffi preparation |
| scalar | Invoke an already prepared `uint64_t -> uint64_t` function and decode its result | Same function in a separate DSO, linked by C; no cross-unit inlining |
| marshal-256 | Copy a 256-byte input/output array, call C to increment every byte, copy back, release temporary memory | C allocation/copy/call/copy/free with the same byte mutation |
| callback | Invoke prepared C which synchronously calls a rooted SML increment closure, then decode the result | Same native call through a C function pointer |

Worker startup and compilation occur outside the phase timers. Preparation
and loading are excluded from steady-state calls. Marshalling includes
temporary allocation and cleanup. Callback time includes the outward call,
VM reentry and result decoding. No aggregate score combines these phases;
none of these small fixtures predicts GUI event/render throughput.

The generic runtime is being measured directly. Generated policy wrappers
can add conversions and ownership work; measure those application paths
separately when selecting an interface. Future direct native linking is a
separate implementation choice, not a claim made by these dynamic-call
measurements.

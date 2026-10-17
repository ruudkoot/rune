# Rune

Rune is a compiler and runtime for Standard ML '97, written in Standard ML
and C. The compiler is portable Standard ML: it builds unchanged with
**MLton**, **SML/NJ**, **Poly/ML** and **MLKit**, all of which produce
byte-identical bytecode, and it compiles itself. The bytecode runs on a C
virtual machine with a copying garbage collector, which compiles the code
that gets hot to machine code as the program runs.

## The language and the Basis Library

* **The language.** The full Core and Modules languages of *The Definition
  of Standard ML (Revised)*, including equality types, the exhaustiveness
  and redundancy reports of Section 4.11 and `abstype`. What differs from
  the Definition are implementation-defined choices, listed in
  [docs/language.md](docs/language.md). Every feature row there names a test
  in `tests/lang/`, and `make check-docs` fails when the two drift apart.
* **The Basis Library.** The required structures, and of the optional ones
  everything that makes sense on Linux: `IntInf`, `Array2`, the monomorphic
  vectors and arrays, `Posix`, `Unix`, sockets, the fixed-width `IntN` and
  `WordN`, `Real32`, wide characters. Rune adds `Runtime` (counters,
  profiling, stack traces, and `save`, which writes a running program to a
  file) and `INet6Sock`. The Basis suite also runs against MLton, SML/NJ,
  Poly/ML and MLKit, and where each of them differs from the specification,
  Rune included, is documented per member in
  [docs/lib/basis](docs/lib/basis/README.md).

## Hello world

```
make hosts    # once: MLton and the other SML systems, under ~/.local/rune-hosts
make          # the compiler, bin/rune, and the VM, bin/runevm
bin/rune examples/hello.sml -o hello.rbc
bin/runevm hello.rbc
Hello, world!
```

`make repl` builds the REPL, `bin/rune-repl`: entries edited and coloured as
they are typed, completion, history, commands such as `:type`, `:doc` and
`:search`, reload, and a debugger ([docs/repl.md](docs/repl.md)). `make
kernel` builds a Jupyter kernel ([docs/kernel.md](docs/kernel.md)), and
`bin/rune-repl --dap` debugs SML from an editor ([docs/dap.md](docs/dap.md)).

`make doctor` reports what the machine lacks, and the command that installs
it. `make check` runs every test. Prerequisites, every `make` target and
installing are in [docs/building.md](docs/building.md).

## Performance

Against MLton on the programs of `tests/perf`, compiled Rune is as fast on a
floating-point loop and 3.6 to 4.7 times slower on calls, arithmetic and
arrays, 1.4 to 3.7 times on library-heavy code, and orders of magnitude
slower on `IntInf`. The compiler compiles itself in 3.0 s, MLton's build in
1.1 s. The figures are in [docs/performance.md](docs/performance.md).

## Repository layout

| Path | Contents |
|---|---|
| `src/` | the compiler: frontend, elaboration, intermediate representations, backend, driver; `src/isa/` describes the instruction set and the primitives |
| `runtime/` | the runtime in C, shared by both VMs; `runtime/register/` is the register VM and its JIT, `runtime/stack/` the stack VM |
| `lib/` | the Basis Library in `lib/basis/`, and libraries beside it |
| `tests/` | `lang/` run tests, `errors/` compile-error tests, `basis/` the Basis Library suite, `perf/` benchmarks with budgets |
| `docs/` | the documentation; `docs/lib/` is generated from the libraries in `lib/` |
| `examples/` | small programs and benchmarks |
| `scripts/` | generators, consistency checks, `doctor.sh`, `install.sh` |
| `share/` | man pages and shell completions |

## Documentation

* [language.md](docs/language.md): what Rune accepts, feature by feature.
* [lib](docs/lib/README.md): the libraries.
* [lib/basis](docs/lib/basis/README.md): the Basis Library, a page per signature.
* [building.md](docs/building.md): prerequisites, every `make` target, installing.
* [architecture.md](docs/architecture.md): how the compiler is organised.
* [ir.md](docs/ir.md): the intermediate representations.
* [bytecode.md](docs/bytecode.md): the instruction sets and the file format.
* [runtime.md](docs/runtime.md): what a running program can count on.
* [repl.md](docs/repl.md): the REPL's manual.
* [diagnostics.md](docs/diagnostics.md): how errors are shown, colours and `RUNE_COLORS`.
* [repl-protocol.md](docs/repl-protocol.md): the REPL's engine, for editors and other fronts.
* [kernel.md](docs/kernel.md): the Jupyter kernel.
* [dap.md](docs/dap.md): the debug adapter for editors.
* [native.md](docs/native.md): translating bytecode to machine code.
* [performance.md](docs/performance.md): timings against the SML systems, and why.
* [basis-compat.md](docs/basis-compat.md): running Rune's Basis Library on the other SML systems.
* [unicode.md](docs/unicode.md): Unicode, wide characters, and the Basis Library's wide text specification.
* [doc-comments.md](docs/doc-comments.md): the language of the comments that generate the library's documentation.

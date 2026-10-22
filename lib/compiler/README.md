# Compiler

<!-- Area: Compiler tools -->

The reusable Rune compiler implementation: source positions and
diagnostics, lexical/syntactic analysis, elaboration, intermediate passes,
bytecode generation, units, caches and build/dependency parsing.

`internal.build` is the shared implementation graph used by the compiler
driver. `frontend.build` provides the subset shared with runedoc, and
`util.build` the small utility prefix. Unicode and JSON are dependencies;
the command-line parser and executable entrypoints remain under `src`.
`CompilerSettings` owns settings used by library passes; the CLI aliases
those refs instead of being a library dependency.

The current extraction retains the compiler's existing mutable state.
The public export boundary, isolated sessions and `RuneCompiler` facade
are the following compiler-library milestones. Internal module names are
implementation interfaces and should not be used as a stable application
API. `config.sml` is a generated copy of the build's version/identity,
installed with the library sources and never committed.

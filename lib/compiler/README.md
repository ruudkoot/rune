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

`CompilerState` registers persistent compiler roots and switches them
between owners for serialized operations. Duplicate-name validation is
deferred to sealing, keeping batch startup linear. Its baseline is sealed after
module initialization, preserving initialized builtin identities. Mutable
container cells, arrays and integer-table buckets are copied for each
owner; persistent maps and that owner's type and AST graphs retain their
identities. Nested calls restore the caller's roots on return or exception.
Publication of immutable semantic results is a separate analysis contract.

`make test-compiler-state` checks registrations with the compiler's SML
parser, tests planted audit faults, interleaves compiler owners, and checks
unit-byte agreement under the interpreter and JIT. The audit covers known
allocation forms and explicit mutable root types, including nested modules,
local declarations and eager collection callbacks. New allocation helpers
must extend the audit and its fault cases.

The public export boundary and `RuneCompiler` facade remain upcoming
compiler-library milestones. Internal module names are implementation
interfaces and should not be used as a stable application API. `config.sml`
is a generated copy of the build's version/identity, installed with the
library sources and never committed.

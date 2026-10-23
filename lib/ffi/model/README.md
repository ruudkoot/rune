# Foreign binding model

Area: Foreign interfaces

This library separates original foreign declarations, target layout facts,
and SML projection policy. It contains no native loader or compiler
primitive. `ForeignModel` adapts C declarations, preserves source identities
and aliases, and computes deterministic selection closures. Other source
families require explicit backends; they never silently become C pointers.

`ForeignPolicy` reads versioned JSON `.ffi` sidecars with physical source
diagnostics from `ForeignJson`. Sidecars contain data, including structured
types and argument/result grouping; they cannot insert SML source or run
commands. `ForeignValidate` checks selected declarations against ownership,
nullability, extents, directions, errors and callback lifecycle rules.
`ForeignProjection` assembles public types from established value types.
`ForeignCoverage` reports selection and supplied implementation evidence
separately, preserving mappings to original declarations.

The specification in `docs/ffi/sidecars.md` describes the schema and its
capability boundaries. Target layout and executable generation are
separate consumers; a selected declaration is not a generated binding.

`ForeignShim` emits typed C adapters over original functions, inline
functions, macros and fields. Aggregate values can cross the dynamic ABI
through pointers while C performs their copies. C handles bitfields and
compiler packing. This source-generation component does not execute
commands; the generator/build integration supplies provenance and rebuilds.

`ForeignTarget` validates version-one target profiles before generation. Widths,
alignments, size type, byte order, enum policy and preprocessing macros are data;
the generator does not infer them from the host running Rune.

`ForeignPublic` lowers selected scalar, text, byte-buffer, output, owned and
borrowed resource, native-error and call-scoped callback policies into checked
SML wrappers. Cleanup surrounds native entry and result conversion; a deferred
callback exception escapes only after a newly owned result is protected.
Struct values use checked target layouts for complete records and fixed
vectors, crossing the dynamic call boundary through generated typed C shims.
Registered callbacks transfer roots and retained resource leases to their
owned result handle, whose destructor must unregister before returning.
Other registration protocols, union active members and pointer fields require
explicit adapters.

`ForeignGenerate` produces documented, sealed raw and public bindings,
selected object measurements, typed field/call adapters and an implementation
manifest. Static/inline selections record a required shim during validation;
the generator emits that shim over the original definition. Explicit public adapters remain named in that
manifest. An unsupported selected projection fails generation; it never
quietly exports an unsafe public wrapper. `runeffi` supplies filesystem
inputs and atomic publication around this reusable pure emitter.

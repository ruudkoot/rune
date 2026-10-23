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

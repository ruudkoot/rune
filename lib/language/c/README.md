# C declaration frontend

Area: Languages

This library preprocesses and parses C interface descriptions in Standard
ML. It has no dependency on a C compiler or an FFI runtime. Include loading
is an explicit resolver, and target predefinitions and expression widths
are caller-supplied. It does not infer SML names, ownership or errors.

`CLex` preserves original physical positions through line splicing and
comment replacement. `CPreprocess` implements macro expansion and records
invocation origins, includes, compiler pragmas and final macro definitions.
`CConst` evaluates intmax/uintmax preprocessing expressions with lazy
logical/conditional operators and explicit signed-overflow diagnostics.
`CEnumConst` folds retained enumerator expressions and implicit successors,
checking referenced declarations and preserving target-independent values.
`CParse` produces typedef-sensitive declaration trees, retaining aggregate
fields, bounds, bit widths, attributes, conventions, packing and inline
bodies. `CFiles` supplies a portable file resolver using original bytes.

Inline bodies are balanced syntax, not compiled C statements. Target
layout, declaration-expression typing and FFI projection are separate
consumers. Unknown active directives or unsupported declaration syntax
produce source diagnostics. Original headers are never repaired in place.

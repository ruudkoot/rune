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

`CInteger` implements target integer ranks, promotions, checked arithmetic
and two's-complement conversions. `CType` normalizes equivalent scalar
spellings and parses abstract type names through the declaration parser.
`CExpression` adds typed casts, `sizeof`, alignment and lazy operators;
unevaluated operands are typechecked without executing their arithmetic.
`CLayout` computes target structs, unions, nested arrays, anonymous members,
flexible tails and pragma packing. Alias/tag lookup, constant values and
all scalar facts come from the caller. Bitfields and explicit alignment
attributes request a verified native adapter rather than guessing.

Inline bodies are balanced syntax, not compiled C statements. Target
layout and declaration-expression typing are explicit consumers of the
syntax tree; FFI projection remains separate. Unknown active directives or unsupported declaration syntax
produce source diagnostics. Original headers are never repaired in place.

# Regression cases preserved from gpt-6-astra

Imported from commit `46028819d141f5f212a4f5041d60984d34cc4643`.
Output expectations come from its reviewed fixture manifest. Warning wording and
positions use origin's diagnostics; counts and kinds were checked against the
original expectations. Runtime cases assert the exception name separately from
stack traces. Tests tied to old 32-bit integers, deferred features, or arbitrary
old syntax limits are excluded. Old 16 KiB GC ceilings use 64 KiB here to allow
for origin's different representations and Basis library.

| Original | Current |
|---|---|
| `examples/hello.sml` | `tests/lang/exp.let_astra-hello.sml` |
| `tests/accept/arithmetic.sml` | `tests/lang/exp.infix_astra-arithmetic.sml` |
| `tests/accept/int32.sml` | `tests/lang/exp.infix_astra-int32.sml` |
| `tests/accept/comments.sml` | `tests/lang/dec.val_astra-comments.sml` |
| `tests/accept/shadowing.sml` | `tests/lang/exp.let_astra-shadowing.sml` |
| `tests/accept/short-circuit.sml` | `tests/lang/exp.if_astra-short-circuit.sml` |
| `tests/accept/boolean-precedence.sml` | `tests/lang/exp.if_astra-boolean-precedence.sml` |
| `tests/accept/comparison.sml` | `tests/lang/exp.infix_astra-comparison.sml` |
| `tests/accept/sequence.sml` | `tests/lang/exp.let_astra-sequence.sml` |
| `tests/accept/empty-let.sml` | `tests/lang/exp.let_astra-empty-let.sml` |
| `tests/accept/alias.sml` | `tests/lang/dec.val_astra-alias.sml` |
| `tests/accept/escapes.sml` | `tests/lang/exp.literal_astra-escapes.sml` |
| `tests/accept/nul-string.sml` | `tests/lang/exp.infix_astra-nul-string.sml` |
| `tests/accept/unit.sml` | `tests/lang/exp.seq_astra-unit.sml` |
| `tests/accept/datatype.sml` | `tests/lang/dec.datatype.poly_astra-datatype.sml` |
| `tests/accept/case.sml` | `tests/lang/dec.datatype.poly_astra-case.sml` |
| `tests/runtime/zero-div.sml` | `tests/lang/rt.exn.uncaught_astra-zero-div.sml` |
| `tests/runtime/zero-mod.sml` | `tests/lang/rt.exn.uncaught_astra-zero-mod.sml` |
| `examples/closures.sml` | `tests/lang/dec.fun.clauses_astra-closures.sml` |
| `tests/accept/polymorphic-id.sml` | `tests/lang/dec.fun.clauses_astra-polymorphic-id.sml` |
| `tests/accept/closure-shadow.sml` | `tests/lang/exp.fn_astra-closure-shadow.sml` |
| `tests/accept/closure-transitive.sml` | `tests/lang/dec.fun.clauses_astra-closure-transitive.sml` |
| `tests/accept/higher-order.sml` | `tests/lang/dec.fun.clauses_astra-higher-order.sml` |
| `tests/accept/factorial.sml` | `tests/lang/dec.fun.clauses_astra-factorial.sml` |
| `tests/accept/recursive-curry.sml` | `tests/lang/dec.fun.clauses_astra-recursive-curry.sml` |
| `tests/accept/recursive-nested.sml` | `tests/lang/dec.fun.clauses_astra-recursive-nested.sml` |
| `tests/accept/recursive-shadow.sml` | `tests/lang/dec.fun.clauses_astra-recursive-shadow.sml` |
| `tests/accept/tail-loop.sml` | `tests/lang/dec.fun.clauses_astra-tail-loop.sml` |
| `tests/accept/tail-tuple.sml` | `tests/lang/dec.fun.clauses_astra-tail-tuple.sml` |
| `tests/accept/tail-builtin.sml` | `tests/lang/dec.fun.clauses_astra-tail-builtin.sml` |
| `tests/accept/tuple-patterns.sml` | `tests/lang/dec.fun.clauses_astra-tuple-patterns.sml` |
| `tests/accept/tuple-equality.sml` | `tests/lang/ty.eqtype_astra-tuple-equality.sml` |
| `tests/accept/tuple-poly-bind.sml` | `tests/lang/exp.fn_astra-tuple-poly-bind.sml` |
| `tests/accept/function-order.sml` | `tests/lang/exp.fn_astra-function-order.sml` |
| `tests/accept/value-restriction-later-use.sml` | `tests/lang/exp.fn_astra-value-restriction-later-use.sml` |
| `tests/accept/poly-local.sml` | `tests/lang/exp.fn_astra-poly-local.sml` |
| `tests/accept/fn-literal-pattern.sml` | `tests/lang/exp.fn_astra-fn-literal-pattern.sml` |
| `tests/accept/fun-literal-pattern.sml` | `tests/lang/dec.fun.clauses_astra-fun-literal-pattern.sml` |
| `tests/accept/fun-parameter-limit.sml` | `tests/lang/dec.fun.clauses_astra-fun-parameter-limit.sml` |
| `examples/collection.sml` | `tests/lang/rt.gc_astra-collection.sml` |
| `tests/accept/gc-closures.sml` | `tests/lang/rt.gc_astra-gc-closures.sml` |
| `tests/accept/gc-tuples.sml` | `tests/lang/rt.gc_astra-gc-tuples.sml` |
| `tests/accept/gc-roots.sml` | `tests/lang/rt.gc_astra-gc-roots.sml` |
| `examples/datatypes.sml` | `tests/lang/dec.fun.clauses_astra-datatypes.sml` |
| `tests/accept/datatype-types.sml` | `tests/lang/dec.datatype.poly_astra-datatype-types.sml` |
| `tests/accept/constructor-scope.sml` | `tests/lang/exp.fn_astra-constructor-scope.sml` |
| `tests/accept/constructor-functions.sml` | `tests/lang/dec.fun.clauses_astra-constructor-functions.sml` |
| `tests/accept/datatype-equality.sml` | `tests/lang/dec.datatype.poly_astra-datatype-equality.sml` |
| `tests/accept/case-order.sml` | `tests/lang/dec.datatype.poly_astra-case-order.sml` |
| `tests/accept/case-nesting.sml` | `tests/lang/dec.datatype.poly_astra-case-nesting.sml` |
| `tests/accept/case-warnings.sml` | `tests/lang/dec.datatype.poly_astra-case-warnings.sml` |
| `tests/accept/refutable-functions.sml` | `tests/lang/dec.fun.clauses_astra-refutable-functions.sml` |
| `tests/accept/case-coverage.sml` | `tests/lang/dec.datatype.poly_astra-case-coverage.sml` |
| `tests/accept/gc-datatypes.sml` | `tests/lang/rt.gc_astra-gc-datatypes.sml` |
| `tests/runtime/match-case.sml` | `tests/lang/rt.exn.uncaught_astra-match-case.sml` |
| `tests/runtime/match-fn.sml` | `tests/lang/rt.exn.uncaught_astra-match-fn.sml` |
| `tests/runtime/match-curried.sml` | `tests/lang/rt.exn.uncaught_astra-match-curried.sml` |
| `tests/runtime/bind-constructor.sml` | `tests/lang/rt.exn.uncaught_astra-bind-constructor.sml` |
| `tests/runtime/bind-literal.sml` | `tests/lang/rt.exn.uncaught_astra-bind-literal.sml` |
| `tests/accept/int32-pattern.sml` | `tests/lang/dec.datatype.poly_astra-int32-pattern.sml` |
| `examples/lists.sml` | `tests/lang/dec.fun.clauses_astra-lists.sml` |
| `tests/accept/lists.sml` | `tests/lang/dec.datatype.poly_astra-lists.sml` |
| `tests/accept/list-polymorphism.sml` | `tests/lang/dec.datatype.poly_astra-list-polymorphism.sml` |
| `tests/accept/list-precedence.sml` | `tests/lang/dec.datatype.poly_astra-list-precedence.sml` |
| `tests/accept/list-types.sml` | `tests/lang/dec.datatype.poly_astra-list-types.sml` |
| `tests/accept/list-equality.sml` | `tests/lang/dec.datatype.poly_astra-list-equality.sml` |
| `tests/accept/list-evaluation.sml` | `tests/lang/dec.datatype.poly_astra-list-evaluation.sml` |
| `tests/accept/list-coverage.sml` | `tests/lang/dec.datatype.poly_astra-list-coverage.sml` |
| `tests/accept/list-warnings.sml` | `tests/lang/dec.datatype.poly_astra-list-warnings.sml` |
| `tests/accept/list-literal-limit.sml` | `tests/lang/dec.datatype.poly_astra-list-literal-limit.sml` |
| `tests/accept/list-cons-limit.sml` | `tests/lang/dec.datatype.poly_astra-list-cons-limit.sml` |
| `tests/accept/gc-lists.sml` | `tests/lang/rt.gc_astra-gc-lists.sml` |
| `tests/accept/list-deep-equality.sml` | `tests/lang/rt.gc_astra-list-deep-equality.sml` |
| `tests/runtime/bind-list.sml` | `tests/lang/rt.exn.uncaught_astra-bind-list.sml` |
| `tests/runtime/bind-nil.sml` | `tests/lang/rt.exn.uncaught_astra-bind-nil.sml` |
| `tests/runtime/match-list.sml` | `tests/lang/rt.exn.uncaught_astra-match-list.sml` |
| `tests/runtime/match-list-fn.sml` | `tests/lang/rt.exn.uncaught_astra-match-list-fn.sml` |
| `tests/runtime/list-evaluation.sml` | `tests/lang/rt.exn.uncaught_astra-list-evaluation.sml` |
| `tests/accept/fn-multiple-clauses.sml` | `tests/lang/dec.fun.clauses_astra-fn-multiple-clauses.sml` |
| `tests/accept/fun-multiple-clauses.sml` | `tests/lang/dec.fun.clauses_astra-fun-multiple-clauses.sml` |
| `tests/accept/function-clause-order.sml` | `tests/lang/dec.fun.clauses_astra-function-clause-order.sml` |
| `tests/accept/function-clause-patterns.sml` | `tests/lang/dec.fun.clauses_astra-function-clause-patterns.sml` |
| `tests/accept/function-clause-scope.sml` | `tests/lang/dec.fun.clauses_astra-function-clause-scope.sml` |
| `tests/accept/function-clause-capture.sml` | `tests/lang/dec.fun.clauses_astra-function-clause-capture.sml` |
| `tests/accept/function-clause-poly-equality.sml` | `tests/lang/dec.fun.clauses_astra-function-clause-poly-equality.sml` |
| `tests/accept/function-clause-partial.sml` | `tests/lang/dec.fun.clauses_astra-function-clause-partial.sml` |
| `tests/accept/function-clause-nesting.sml` | `tests/lang/dec.fun.clauses_astra-function-clause-nesting.sml` |
| `tests/accept/function-clause-matrix.sml` | `tests/lang/dec.fun.clauses_astra-function-clause-matrix.sml` |
| `tests/accept/function-clause-warnings.sml` | `tests/lang/dec.fun.clauses_astra-function-clause-warnings.sml` |
| `tests/accept/function-clause-value-restriction.sml` | `tests/lang/dec.fun.clauses_astra-function-clause-value-restriction.sml` |
| `tests/accept/function-clause-constructor-shadow.sml` | `tests/lang/dec.fun.clauses_astra-function-clause-constructor-shadow.sml` |
| `tests/accept/function-clause-tail.sml` | `tests/lang/rt.gc_astra-function-clause-tail.sml` |
| `tests/accept/function-clause-gc-captures.sml` | `tests/lang/rt.gc_astra-function-clause-gc-captures.sml` |
| `tests/runtime/match-multiple-fn.sml` | `tests/lang/rt.exn.uncaught_astra-match-multiple-fn.sml` |
| `tests/runtime/match-multiple-fun.sml` | `tests/lang/rt.exn.uncaught_astra-match-multiple-fun.sml` |
| `tests/runtime/match-multiple-curried.sml` | `tests/lang/rt.exn.uncaught_astra-match-multiple-curried.sml` |
| `tests/runtime/match-multiple-nested-fn.sml` | `tests/lang/rt.exn.uncaught_astra-match-multiple-nested-fn.sml` |
| `tests/runtime/match-multiple-correlated.sml` | `tests/lang/rt.exn.uncaught_astra-match-multiple-correlated.sml` |
| `tests/runtime/match-multiple-no-retry.sml` | `tests/lang/rt.exn.uncaught_astra-match-multiple-no-retry.sml` |
| `tests/runtime/function-clause-argument-failure.sml` | `tests/lang/rt.exn.uncaught_astra-function-clause-argument-failure.sml` |
| `examples/multi-clause.sml` | `tests/lang/dec.fun.clauses_astra-multi-clause.sml` |
| `tests/accept/function-clause-list-depth.sml` | `tests/lang/dec.fun.clauses_astra-function-clause-list-depth.sml` |
| `tests/accept/function-clause-many.sml` | `tests/lang/dec.fun.clauses_astra-function-clause-many.sml` |

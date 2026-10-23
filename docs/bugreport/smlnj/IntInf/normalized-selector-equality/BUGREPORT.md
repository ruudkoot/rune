# SML/NJ: polymorphic equality misses equal normalized IntInf selectors

Observed 2026-10-23 on the pinned SML/NJ 110.99.9 (both 64-bit and 32-bit)
and SML/NJ 2026.2 (64-bit), with Rune source `18c353b49`. Not reported
upstream. The example has not been reduced below the generator context.

The unmodified `tests/lib/ffi/model/generate.sml` passes 31 of its 32
checks. Its sole failure is `duplicate narrowed selectors rejected`.
MLton 20241230, Poly/ML 5.9.2 and Rune pass all 32 checks. MLKit's
collector-only comparison also passes; its default region-inference crash
is a separate defect.

## Reproduction

From a Rune checkout with the pinned hosts and manifests prepared:

```
NATIVE_HOST=yes bin/rune-test run 'lib-hosts/smlnj*/ffi.model.generate' --keep
```

The harness retains the complete original source list and session output
under `tests/out/r/RUN/lib-hosts/HOST/ffi.model.generate`. This is a
standard SML program using the host's own Basis; no Rune extensions or
replacement numeric structures are supplied. The source fixture and the
library sources are unchanged. The program exits 1 with:

```
FAIL ffi/model/generate/duplicate narrowed selectors rejected
  - duplicate narrowed selectors rejected
SUMMARY 32 tests, 31 passed, 1 failed, 0 skipped
```

`tests/lib/ffi/model/generate.smlnj.expected` lists the full, reviewed
verdict sequence. The strict native-host judge accepts only this sequence
and exit status, after a successful build. Another failed assertion, a
missing verdict, a build error, a crash or a timeout remains an unexpected
failure. A successful program makes the deviation stale.

## Equal values in the failing context

`selectorCases false ["-1", "4294967295U"]` declares a callback with an
`unsigned int` selector. The target has a 32-bit unsigned int, so both
expressions convert to 4294967295. `ForeignPublic` checks for duplicate
converted selectors using its polymorphic local `distinct` helper:

```sml
fun distinct [] = ()
  | distinct ((key, _) :: rest) =
      if List.exists (fn (other, _) => key = other) rest
      then raise Fail "duplicate"
      else distinct rest
```

On SML/NJ this helper misses the duplicate and the generated callback
policy contains two `Word64.fromLargeInt 4294967295` cases. The Boolean
selector duplicate check in the same fixture succeeds.

For diagnosis only, a temporary copy of `ForeignPublic` added an equality
helper with the same polymorphic type, alongside the specialized
comparison in its `IntInf` context:

```sml
fun polymorphicEqual (left, right) = left = right
(* In the existing converted-selector traversal: *)
val generic = polymorphicEqual (key, other)
val specialized = key = other
val order = IntInf.compare (key, other)
```

For the unequal source expressions after conversion, the recorded values
were `generic = false`, `specialized = true`, and `order = EQUAL`; both
printed as 4294967295. Each value compared equal to itself. Additional
SML/NJ 110.99.9 64-bit-specific inspection showed the same nonnegative, one-digit
`FFFFFFFF` representation for both values. No such instrumentation or
representation-dependent code is included in the production library.

Simple stand-alone `IntInf.mod (~1, 2^32)` comparisons, signed-to-unsigned
round trips, and the isolated C integer/expression evaluator did **not**
reproduce the mismatch. The failure therefore remains context-dependent;
we do not claim a reduced arithmetic cause, a collector cause, or a repair
to SML/NJ. The original uninstrumented full fixture independently preserves
the observable failure. Rune's production generator retains its ordinary
polymorphic equality, following the owner rule against external-host
workarounds.

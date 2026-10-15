# 32-bit SML/NJ bounded-random arithmetic failure

Recorded 2026-10-15 with managed SML/NJ 110.99.9, 32-bit. The new Sandmark array
ports raise `Overflow` in their shared bounded random generator. Their raw
30-bit bit streams match the pinned OCaml reference; integer rejection draws
fail. This is separate from sandbox SIGSYS termination and earlier Word64 bugs.

The [minimal checked probe](../results/m5-sequential-arrays/reference-observers/threshold-checked.sml)
is independent of the random generator:

```sml
fun literal bound = 1073741823 - bound + 1
fun variable maximum bound = maximum - bound + 1
```

For bounds 1, 100 and 1,000,000,000, `literal` raises `Overflow` on the managed
32-bit SML/NJ. The expected results are 1,073,741,823; 1,073,741,724; and
73,741,824. Every subtraction result and final addition fits the signed 31-bit
range. The [Basis INTEGER contract](https://smlfamily.github.io/Basis/integer.html)
specifies the sum/difference and overflow for unrepresentable results; these
operations have representable results. Supplying the same maximum through input
and calling `variable` passes all three checks on that host.

Six comparison configurations (Rune, MLton, both managed 64-bit SML/NJ releases,
Poly/ML and ML Kit) pass all six checks. The [complete checked transcript](../results/m5-sequential-arrays/reference-observers/threshold-checked.log)
records the 32-bit three-failure result separately. The compiler transformation
responsible is not isolated by this probe; no optimizer cause or upstream issue
identity is asserted.

Both selected profiles of quicksort, mergesort, matrix_multiplication and
floyd_warshall fail on that host with the same runtime exception. Other recorded
configurations use unchanged portable sources and expected results. The suite
does not substitute a different arithmetic expression or accept an alternate
expected result for this host. These failures cannot contribute measurements.
Recheck after a managed host update and retain the failing baseline.

# Integer-grid native32 constant diagnostics

The selected integer smoke/normal profiles pass on managed SML/NJ 110.99.9
32-bit. Two auxiliary wrap checks fail at both levels; the other 112 checks
pass. All other configurations pass all 114 checks. The expressions and
expected values remain unchanged.

| Expression | Expected | Native32 constant expression | Runtime-input result |
|---|---|---|---|
| Word64 minimum minus one | 7FFFFFFFFFFFFFFF | 7FFFFFFF3FFFFFFF | 7FFFFFFFFFFFFFFF |
| Word64 signed maximum times two | FFFFFFFFFFFFFFFE | FFFFFFFF3FFFFFFE | FFFFFFFFFFFFFFFE |

[The complete probe](../results/m3-integer/word64-probe.log) records constant
and runtime results across all ten configurations. Both runtime checks pass
everywhere. Its [source](../results/m3-integer/word64-probe.sml) and
[input](../results/m3-integer/word64-probe.input) are retained, as are both
levels' [complete semantic logs](../results/m3-integer/semantics/O0.log).
The observed constant paths lose bits 30 and 31, consistent with the existing
[Word64 low-half reports](../../../docs/bugreport/smlnj/README.md).
No current upstream issue status is inferred from this local run.

These diagnostics remain distinct from the full selected-profile digests.
The selected operands/products fit signed 64 bits, and those profiles agree
with original GHC and independent exact arithmetic. Their passing measurements
must not be described as evidence that every Word64 corner case is correct
on this host. No alternate arithmetic stream or expectation is substituted.

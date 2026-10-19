# Multilayer reference-host findings

Recorded 2026-10-16 with the managed SML/NJ 110.99.9 64/32-bit and 2026.2
hosts. Expected networks, arithmetic and ordinary suite configurations remain
unchanged. Raw probes and original/independent references accompany the
multilayer result archive.

## Legacy 64-bit: GC-sensitive NaNs

An initial native smoke measurement rejects a NaN model result before accepting
any timing sample. The canonical matrix later passes smoke but fails normal
on the same legacy host. Both Rune levels/all engines, MLton, SML/NJ32,
SML/NJ2026.2, Poly/ML and ML Kit pass the selected profiles.

A zero-training diagnostic starts with all 417 parameters exactly matching
the original network. A complete forward scan has maximum prediction difference
about 3.5e-11 from OCaml, and total loss differs by about 1.1e-9, within the
previously chosen budgets. Re-evaluating the same pure model through the
validator subsequently produces NaN for a prediction whose reference is
0.31845545356307325. A control that repeats one forward input 10,000 times
passes, so the failure is sensitive to caller/allocation context.

Running the same complete 0/1/20-epoch diagnostic with `@SMLalloc=128k` passes
two profiles and then fails; with `@SMLalloc=64m` all three pass. These are
reference diagnostics, not suite overrides or a new standard measurement
configuration. The behavior is consistent with the documented
[64-bit GC root defect](../../../docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/BUGREPORT.md)
and its upstream #299 context. The exact failing entry in this workload has
not been reduced, so that causal identification remains an inference.

## Native32: decimal reference reading

The strict initialization test differs by one ulp even though the full model
profiles pass their numerical budgets. A separate probe reconstructs all 417
expected values from small-integer dyadic components, bypassing decimal real
reading. Every generated parameter matches those exact references on Rune,
MLton, native32 and SML/NJ2026.2. Native32's decimal reader differs on 62 of
417 values; the other tested readers match all of them.

For example, the actual/exact value 0.42989864717140014 is read from the decimal
fixture as 0.4298986471714002. This reproduces the already documented
[Word64 shifts/negation and Real.fromString defect](../../../docs/bugreport/smlnj/Word64/shifts-and-negation/BUGREPORT.md),
which includes the upstream #373 context. The standard strict test and its
reviewed decimal fixture remain intact, with this host failure recorded at
both levels. No RNG or expected-value adjustment masks it.

## Measurement classification

An internal numerical checker uses the explicit `incorrect result` exception
marker. The shared shell classifier accepts its portable `Fail:` prefix and
keeps this category separate from ordinary runtime exceptions. Integration
checks compile and execute both failing programs; neither can produce timing
samples. The classifier is retained in tool-source snapshots for reproduction.

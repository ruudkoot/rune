# nofib imaginary import wave

Recorded 2026-10-03. This wave adds compensated summation, complex arithmetic,
numerical feedback streams, exact Bernoulli arithmetic, both wheel algorithms,
range expansion and paraffin generation. Together with the earlier recursive,
prime, queen and e-digit ports, all 15 pinned `imaginary` workloads now have
implementations. M3 remains in progress for `spectral`, `gc` and `shootout`.

[The attempt ledger](correctness-attempts.tsv) preserves successful and rejected
correctness runs. Final smoke/normal inputs pass on all four Rune engines at
-O0/-O2, MLton, Poly/ML and modern SML/NJ; legacy SML/NJ rejects lazy regex normal.
Its diagnosis is retained separately. Initial port build errors remain in the
ledger; they are not described as compiler failures or silently turned into
valid expected results. Large fixtures agree with upstream or independent
oracles, but no universal large SML execution is claimed.

The counts under `counts/` run separately from headline timings, on the normal
profiles. Each report retains source/input snapshots, compiler and configuration
identities, original revision/dirty state, raw observations and tool sources.
All four engines agree on allocation; stack/native and register/JIT instruction
counts agree within their applicable pairs. Reports are instrumented observations,
not headline timings or evidence of steady state. No speed ranking is claimed.
Compiled programs/heap images and work directories are excluded from the archive.

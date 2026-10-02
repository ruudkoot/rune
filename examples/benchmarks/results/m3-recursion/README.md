# nofib recursive-kernel measurement checkpoint

Recorded 2026-10-02. The two separately named Takeuchi ports use normal
input 18/12/6 and return 7. Original Haskell references also agree. All
samples are serial fresh processes, ten per primary compiler: 80 accepted
samples total. [The report](fresh/report.md) retains compiler/source/input
identities, compile phases, dirty state and every sample. OS time output has
0.01-second resolution; these small timings support no precise speed ranking.
No warmup/steady-state conclusion is claimed.

[Counts](counts/report.md) are separate from headline samples. Stack/native
instruction totals agree and register/JIT totals agree; all four engines'
allocation counts agree. Strict uses 19968 bytes/524 objects; explicit lazy
uses 12233024 bytes/382186 objects on this input. This is observed allocation
for these ports, not an attribution to any particular compiler optimization
or a prediction about the original GHC program's optimized thunks.

The archive keeps metadata, raw observations, ordered source/input snapshots
and tool sources. Compiled executables/heap images and work directories are
excluded. M3 is still in progress; this package is a measured import wave.

[The correctness ledger](correctness-attempts.tsv) records 310 passing smoke
and normal attempts for rfib, the lazy/strict Takeuchi and Peano variants,
and the two lazy e-digit generators. The import-wave checks cover Rune's four
engines at -O0/-O2, plus MLton, SML/NJ 64-bit and Poly/ML. Of these attempts,
112 repeat all seven programs on the four Rune engines at both levels after
rebasing onto master `3d48b00`. Another 44 attempts rerun the Takeuchi pair
after sharing the strict kernel with the classic drivers. Native optimization
entries are `host-default`, since Rune levels do not set host compiler options.
This does not claim large-profile execution.
The measurement archives precede that rebase and retain their original
revision and dirty-state metadata; they are not timings of the new base.

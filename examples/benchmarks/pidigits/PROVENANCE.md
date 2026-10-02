# pidigits provenance

mlton `b15e2d289c3d701131733665a74e2dd8438410b6`, `benchmark/tests/pidigits.sml`. Original, patch and notice retained.

Jeremy Gibbons linear fractional transformation spigot, in the MLton source.
Keeps IntInf arithmetic and the original function-stream implementation.
The benchmark stops on a zero occurrence, not at a fixed digit count; its
zero index and returned digit position are zero based. Chudnovsky expansion
provides an independent oracle. Stream functions are nonmemoized as in this
SML source; no Haskell demand equivalence is claimed.

The initial normal zero index 100 timed out on Rune under the 600-second
limit. The subsequent zero index 30 also timed out at -O0 in the stack interpreter.
Normal is now fixed at zero index 10 (digit position 121),
with an independently computed Chudnovsky fixture. This input revision
changes the workload identity; the unsuccessful larger run is recorded.

See [Gibbons, Unbounded Spigot Algorithms for the Digits of Pi](https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/spigot.pdf)
for the linear-fractional streaming formulation. The zero-occurrence driver
is specific to this upstream SML workload, rather than the paper's usual
fixed digit-count presentation.

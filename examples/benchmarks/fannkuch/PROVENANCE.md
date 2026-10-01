# fannkuch provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/fannkuch`.
Copyright/notice and original ordered sources retained.

2026 Fellowship of SML/NJ fannkuch-redux implementation. Keeps mutable
permutation arrays, rotation order, flip counting and alternating checksum.
Normal retains upstream testit size 7; large retains three size-11 calls.
Return the observed maximum and IntInf sum of checksums. Benchmark Game
reference values are max/checksum (7,11), (16,228), and (51,556355) before
repetition; independent small permutation checks are required.

The unchanged upstream Main.doit on MLton independently prints checksum
556355 and maximum 51 three times; reference-large.txt retains that fixture.
The source README links [Performing Lisp analysis of the FANNKUCH benchmark](https://doi.org/10.1145/382109.382124)
and the Benchmark Game. The alternating checksum depends on the preserved
permutation order, not an arbitrary lexicographic enumeration.

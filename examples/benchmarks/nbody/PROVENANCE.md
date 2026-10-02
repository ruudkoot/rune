# nbody provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/nbody`.
Copyright/notice and original ordered sources retained.

2025 Fellowship of SML/NJ solar-system benchmark. Keeps five planets,
immutable planet records/lists, pairwise velocity updates, momentum offset,
dt=.01 and the original numerical operation order. The original driver
offsets momentum before calling run, which offsets it again; this is
preserved. Normal uses one million steps; large preserves fifty million.
Energy references come from the original C implementation in other/main.c
with an explicit second momentum offset to match the SML driver, and
17-digit output; reference.patch records these reference-only changes. Bounds are absolute 1e-9 plus
relative 1e-9; they are not an energy-conservation claim.

The reference offset uses subtraction from the sun velocity before its
second call, matching the immutable SML operation. The original C operation
assigns a velocity assuming an initially resting sun; calling that assignment
twice would reset the sun velocity and produce the wrong reference problem.

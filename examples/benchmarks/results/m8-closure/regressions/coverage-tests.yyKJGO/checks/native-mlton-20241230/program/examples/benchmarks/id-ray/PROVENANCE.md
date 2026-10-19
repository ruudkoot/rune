# id-ray provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/id-ray`.
SML/NJ Fellowship; original headers, modules and aggregate notice retained.

Render the original fixed Id/Manticore scene with reflections, transparency,
shadows, lighting and recursive ray intersections. Preserve the original
custom image representation, including its source indexing `width*row+col`
for RGB writes (rather than `3*(width*row+col)`). This overlaps channel writes
and leaves the trailing two-thirds zero; it is a known upstream defect,
kept visible in the fixture rather than silently changing the workload.
The source also ignores its output filename and uses out.ppm. Large preserves
1024 square; smoke/normal are bounded 8/128-square renders. Sampling is not
used by this deterministic renderer; the adapter passes a documented 1.
Source comments identify a negative-vector limitation retained in the kernel.
Every header, dimension, data length and actual quantized RGB channel is
validated against reviewed native source renders. Permit at most one level
per 8-bit channel for floating-point rounding at quantization boundaries;
this is a benchmark-specific output tolerance, not permission to change
geometry. Allocation/traversal/real-operation concerns are source hypotheses;
no measured attribution is claimed. See [rendering literature](../literature.md).

The full original `DATA/spheres.txt` supplements the embedded test spheres;
no per-dataset notice or origin is given in the data, so its notice/origin
remains an explicit provenance gap. Scene loading at structure initialization
is included in fresh-process runs; repeated in-process calls reuse it.

SML/NJ 110.99.9 for 32 bits fails the normal image check; the cause has not
been isolated. Its documented [numeric host defects](../../../docs/bugreport/smlnj/README.md)
are relevant diagnostic candidates. Do not count this as a pass or widen
tolerances to accept an unreviewed output.

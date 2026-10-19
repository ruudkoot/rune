# ray-smlnj provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/ray`.
Individual module/data notices and aggregate notice are retained with the
ordered originals and patch.

Interpret the original fixed sphere scenes and shade every pixel. This
modern modular SML/NJ variant emits P6 RGB rather than the old Dump format.
Preserve scene parsing, sphere order, ray/camera distributions, lighting and
quantization. Add a dimension ref to the picture adapter and replace 512
coordinate/loop/header constants uniformly; smoke is the upstream three-
sphere test at 16 square, normal the nine-sphere benchmark at 128 square,
large the original 512-square scene and 500 repetitions. Only output paths
are changed in DATA copies; original data notices are retained.
Validate P6 headers, dimensions and every RGB channel against reviewed
native original renders, with at most one 8-bit level of rounding tolerance.
Result consumption and file output/validation are measured work. Algorithm,
real-operation, closure and allocation sensitivity are source hypotheses,
not established performance causes. See [literature](../literature.md).

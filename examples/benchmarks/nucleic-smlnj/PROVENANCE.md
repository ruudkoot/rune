# nucleic-smlnj provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/nucleic`.
Pristine ordered sources, individual headers, project notice and adaptation
patch are retained.

Marc Feeley's Scheme-origin Pseudoknot, ported by the May 1994 Dagstuhl
workshop group. Retain the modern SML/NJ anticodon search, molecular
coordinates, constraints, queue and Math.atan2. This variant counts
anticodon solutions; old MLton nucleic reports a maximum atom distance.
Every returned count is consumed. Large preserves 5000 searches. Golden
count comes from the unmodified upstream Nucleic implementation on MLton
and SML/NJ, reviewed before committing. See the Hartel et al. Pseudoknot
paper in the literature survey.

All selected profiles retain meaningful source parameters; diagnostics numerical,search,geometry
are source-based hypotheses, not measured causal findings. See the
[classic SML and benchmark-specific literature](../literature.md).

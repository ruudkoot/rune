# safe-for-space provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/safe-for-space`.
Pristine ordered sources, individual headers, project notice and adaptation
patch are retained.

John Reppy 2020; based on Zhong Shao and Andrew Appel,
[Efficient and Safe-for-Space Closure Conversion](https://doi.org/10.1145/345099.345125),
TOPLAS 22(1), 2000. Keep strict big-list creation and all nested g/h/i
functions, retaining every h before observing it. Parameterize the big-list
length and outer count; large preserves 10000/100000. Invoke each h/i to
validate (3,list-size), whose sum is independently derived. Additional
observation work is measured. Closure capture/lifetime is a diagnostic
question; successful output alone does not prove space safety.

All selected profiles retain meaningful source parameters; diagnostics closures,retention,allocation
are source-based hypotheses, not measured causal findings. See the
[classic SML and benchmark-specific literature](../literature.md).

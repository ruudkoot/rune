# f-arith provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/f-arith`.
Copyright/notice and original ordered sources retained.

2026 Fellowship of SML/NJ floating arithmetic loop: two alternating
Leibniz terms per iteration. Preserve acc+1/n-1/(n+2) and denominator
increment 4, including their operation order. Check against mathematical
pi with the next-term bound 4/(4*steps+1), plus 8*steps*2^-53 for rounding
accumulation. Large retains the original five billion steps and requires
a default int precision of at least 34; narrower configurations are
unavailable for that profile. Removes logging, consumes the computed value.

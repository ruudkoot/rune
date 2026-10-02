# black-scholes provenance

smlnj `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/black-scholes`.
Pristine sources, observed source notices and adaptation patch are retained.

Damon Wang's Manticore-origin SML port; Fellowship of SML/NJ 2025.
Preserve the original normal-CDF polynomial, option record/list distribution,
pricing operations and residual-returning price function. Large preserves
65536 records replicated 32 times with ten passes. Normal uses all 4096
upstream small records; smoke selects its first sixteen. Data loading and
replication move inside the measured driver and are explicit additional
work relative to upstream preload. Every result is checked against the
embedded DerivaGem reference using 1e-6 + 7.5e-8*(spot+discounted strike),
derived from the source's Abramowitz-Stegun CDF approximation bound.
The original dataset bytes and embedded reference values are retained.
No separate dataset license/origin is stated in its headers; this remains
an explicit provenance lookup, not an assertion that the program notice
covers the dataset.

Diagnostic questions are hypotheses until measured. See the
[classic SML literature](../literature.md).

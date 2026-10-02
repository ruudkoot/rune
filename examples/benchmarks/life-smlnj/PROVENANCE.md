# life-smlnj provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, programs/life.
Ordered original sources, notice and adaptation patch retained.

Modern list-based Game of Life variant. Retains the sorted generations,
neighborhood merge and glider-gun seed. Observe every live coordinate and
return count/hash for every invocation. Normal performs 100 fifty-generation
calls; large preserves the original 1000 calls. Independent Python set-based
neighbor counting supplies the exact generation summaries. The repetition
policy differs materially from the long single evolution in MLton life.

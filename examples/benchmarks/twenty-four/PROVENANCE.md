# twenty-four provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/twenty-four`.
Copyright/notice and original ordered sources retained.

2026 Fellowship of SML/NJ arithmetic-expression solver. Retains its
expression tree and continuation/resume enumeration, including repeated
solutions. Smoke retains the [4,7,8,8] fixture with count 44. Normal
enumerates four distinct cards selected from 1..10, and large retains
250 full deck enumerations. Actual callback counts are accumulated in
IntInf rather than dropped. Reference counts come from the unchanged
upstream solver on MLton; no claim of unique expression deduplication.

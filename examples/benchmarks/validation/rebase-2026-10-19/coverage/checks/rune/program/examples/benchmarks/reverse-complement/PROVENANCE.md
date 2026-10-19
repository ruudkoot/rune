# reverse-complement provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `shootout/reverse-complement`.

### Algorithm and history

Louis Wasserman contributed the Haskell Benchmarks Game implementation.
The retained boot.sh generates input with Mr Ledrug's fasta-c.c and expected
output with the separately retained revcomp-c.c. Original sources/build scripts
and notices have SHA256 identities. Individual licence terms are unspecified
in these pinned program files; this gap remains explicit.

### Variants and translation

Preserve the82-byte reader, first-header search,1024-byte initial buffer,
doubling capacity, reset/reuse on record boundaries,200-entry identity/complement
table, and in-place inward swap loop. Keep lowercase/uppercase ambiguity mappings,
headers and newline positions. SML checked character arrays replace malloc,
realloc, pointer access and memchr; the input file is materialized earlier as
one byte string. Rendering collects completed records instead of hPutBuf output,
changing retention/copying costs. No alternative record parser or sequence list
replaces the buffering and swap algorithm; no foreign runtime feature is needed.

The original reader handles only the first '>' in each82-byte chunk. Tiny input
n=13 packs multiple headers into a chunk and original GHC output disagrees with
independent FASTA reversal. That unsuitable smoke candidate was rejected;
selected n=100 has sufficiently spaced headers. This source limitation is
preserved and documented rather than silently repairing the benchmark.

### Inputs, validation and references

Profiles are generated with original fasta-c.c at n=100/75000/750000. The same
size parameter/input distribution is retained; source FAST 5000000 and
NORM/SLOW 50000000 remain recorded, including the C parser-overflow warning in
Makefile. Inputs/expected outputs are fixed files rather than generated during
measurement. All selected fixtures agree with unchanged GHC, original C, and an
independent per-record complement/reversal oracle that preserves line positions.
Every output byte is checked. Boundary tests cover all mappings, odd centers,
line positions, growth beyond1024 and headers crossing reader chunks. Added full
output collection/validation is included; large SML execution is not universally
claimed. Buffer growth, copying, mutation and byte representation are hypotheses
until measured. References: retained source/boot scripts and
[the literature survey](../literature.md).

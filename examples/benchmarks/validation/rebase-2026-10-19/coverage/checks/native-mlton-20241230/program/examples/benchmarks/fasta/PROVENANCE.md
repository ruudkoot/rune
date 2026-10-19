# fasta provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `shootout/fasta`.

### Algorithm and history

Bryan O'Sullivan contributed the Haskell Benchmarks Game implementation. Mr
Ledrug contributed the independent C generator used by nofib's boot.sh. Both
sources, build scripts, parameters and notices are retained with SHA256 identities.
Their individual licence terms are unspecified in the pinned files; this remains
an explicit provenance gap rather than a GHC compiler-licence assignment.

### Variants and translation

Preserve the cyclic ALU sequence, lengths2n/3n/5n,60-column lines, seed 42,
modulus 139968, multiplier 3877, increment 29573, and seed carried between the two
random sequences. Preserve cumulative Float probabilities, inclusive lookup
cutoffs floor(modulus*p+1), and table clamping. Every literal/add/multiply/add
is explicitly rounded to binary32 using24 significand bits and ties to even.
Only positive normal finite values in the original table builder occur; the
helper is not a general substitute for all IEEE special/subnormal behavior.
All table cutoffs match an independent binary32 reference. The generator's
integer product fits31-bit signed Int for every permitted seed.

Portable SML strings replace strict/lazy ByteStrings and the cyclic byte chunks;
a checked60-character mutable array replaces the CString line buffer. Table
construction and array mutation remain; no direct probabilistic scan replaces
lookup. The complete generated output is collected in SML strings instead of
streamed through stdout, changing retention and copy costs. No foreign runtime
or computation is needed. These representation/evaluation changes are explicit.

### Inputs, validation and references

Profiles select n=13/75000/750000; large preserves original FAST 750000.
Original NORM 7500000/SLOW 25000000 remain recorded. The partial smoke lines
exercise remainder handling. Complete outputs agree with unchanged GHC and
nofib's independent C reference for every selected profile. Every header, base,
newline and seed-dependent character is checked. Semantic tests cover the
reviewed distribution cutoffs and halfway rounding. Added collection/validation
is included; large SML execution is not universally claimed.

Binary32 table construction, byte representation, buffer mutation, slicing/copying
and input/output retention are source-derived hypotheses until measured.
References: the retained O'Sullivan/Ledrug implementations and
[the literature survey](../literature.md).

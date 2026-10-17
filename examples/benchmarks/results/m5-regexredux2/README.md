# Regex-redux validation

The port passes all 28 primary smoke/normal cases across Rune O0/O2 engines and
six managed native SML hosts. Twenty semantic invocations pass all 23 assertions:
460 passing assertions, none failed or unreached. Four full normal count samples
agree. Three serial single fresh-process native smoke adapter samples pass,
separately from instrumentation and comparative performance claims.

Pinned OCaml fasta3 generates deterministic inputs at N=100, 50000 and 500000.
These explicit smaller profiles retain source RNG state, probabilities and line
widths; the published N=5000000 input is not claimed. Original OCaml 4.14.1 yields
all expected reports. A development Rune O2 pilot validates all three, including
large; final registered-source canonical checks cover smoke and normal. The
public program's added notice is recorded separately from that earlier source.

Twelve original Str observations and five complete original program edge cases
cover greedy matching, ordered alternatives, anchors, overlap, case and ordered
substitutions. The portable matching adapter implements only the fixed source
fragment; it is explicitly a library replacement rather than OCaml Str's internal
engine. Pattern-at-a-time searches and replacement order remain unchanged. Full
stdout is validated and replaced by a checked-length report. Data identities,
original programs, generator credits and Revised BSD notices are retained.

All 102 inventory regressions and the five-pin 861-entry replay pass. Roman
Kashitsyn's Bytes adaptation credit is recorded. The shared full repository
acceptance transcript exits zero with 1159 profiles and all cross-build tool
comparisons. This does not close remaining Sandmark or standard-library work.

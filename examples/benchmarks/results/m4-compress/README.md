# nofib compressor application pilot

Recorded 2026-10-03. Memoized and strict ports of Paul Sanders's fixed-12-bit
prefix-tree LZW share one implementation. M4 is in progress; the other real
applications remain scheduled. The catalogue contains 192 programs and
570 profiles.

[The ledger](correctness.tsv) records 48 final smoke/normal runs, all passing:
four Rune engines at -O0/-O2 and four primary native hosts. Standalone ML Kit
smoke and normal programs also pass. Complete primary stdout/logs, original
GHC hash samples, the read-only byte observer and an executable independent
dictionary/packing/hash oracle are retained.

All 31 cut outputs per profile agree byte for byte with GHC and the independent
oracle. All 200 normal/large original GHC hash samples agree. Dictionary size,
fixed-width packing, final unshifted nibble, original foldr table order and EOF
demand are preserved. Separate seven-check semantics runs pass nine configurations
at both levels. ML Kit 4.7.23 crashes compiling the combined two-functor semantics
test, despite compiling the standalone programs. The failure and
[reproduction](../../validation/mlkit-compress.md) remain explicit; no alternate
expected result or compiler workaround is introduced.

Fixed datasets retain their byte identities and upstream origin. Input strings,
output materialization, full-byte validation, preloaded fixture I/O and accumulated
hashes are documented adaptations. Lazy and strict forcing/retention remain
distinct. Large SML execution is not universally claimed.

The separate count archive preserves every instrumented sample, source/input/tool
snapshot and configuration identity. Allocation counts agree across all four
Rune engines; applicable instruction comparisons agree. Instrumented times are
not headline performance comparisons. Compiled payloads and disposable work
directories are excluded.

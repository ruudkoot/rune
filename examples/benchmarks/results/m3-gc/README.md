# Allocation, sequence and exact-arithmetic import wave

Recorded 2026-10-03. Ten ports cover the two mutable-store layouts, GCBench,
the original extensible hash table, lazy/strict Hirschberg LCSS, shootout pi
extraction and spectral extended GCD. M3 remains in progress for the other
GC/spectral/shootout workloads. No broader roadmap closure is claimed.

[The ledger](correctness-attempts.tsv) retains successful, timed-out, incomplete
and erroneous port attempts. Final selected smoke/normal profiles pass on Rune's
four engines at -O0/-O2 and primary managed reference hosts. The initial
1000-digit shootout pi normal input timed out on Rune's unoptimized stack engine;
the reviewed 200-digit normal profile now passes. Its original larger parameters
are retained for scaling. Aborted old runs remain incomplete, not interpreted as
correctness passes. Initial tree-checker and assignment-syntax errors were port
errors and are preserved. No large execution is universally claimed.

Separate count archives under `counts/` retain complete samples, configurations,
compiler/source/input identities and raw observations. Instruction counts agree
within stack/native and register/JIT pairs; allocation agrees across all four
engines. Timings in these instrumented runs are not headline comparisons or
steady-state evidence. Compiled payloads and work directories are excluded.

The complete-state corruption target verifies balanced tree shapes and every
label, detects compensating bad labels, and rejects wrong hash-table entries.
Extended-GCD checks independently reject wrong coefficients and divisors. The
pi fixtures agree with original GHC and an independent Chudnovsky calculation;
LCSS agrees with GHC and a separate dynamic-programming/intersection oracle.
All programs retain their individual provenance, adaptations and notices.

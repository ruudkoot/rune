# Allocation and stack microprobe audit

The original four Cmm transcripts retain opaque values and indirect calls.
metadata.json records compiler version/options, pinned revision, per-source
SHA256 and the compilation-only resource limits. Exact source fixtures and the
aggregate notice are under tests/benchmarks/data/sandmark-opaque/.

Reproduce with `python3 examples/benchmarks/results/m5-allocation-audit/compile.py
tests/out/benchmarks/recheck-opaque` using OCaml 4.14.1 and ocamlfind. Compiled
payloads remain in that explicit scratch directory.

rebuild.py rebuilds the pinned Sandmark inventory, checks all alias relationships,
preserves their order and requires exactly the four reviewed disposition/reason
changes. rebuild.log records the successful 143-entry rebuild and 861-entry
reconciliation. tests.log records all 41 passing discovery tests.

The [review](../../validation/sandmark-allocation-probes.md) explains each missing
capability and reconsideration condition. These are source-audit findings;
no runnable port, runtime feature, timing sample or milestone completion is claimed.

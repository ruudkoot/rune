# ML Kit paired Life semantics test

Recorded with managed ML Kit 4.7.23 on 2026-10-03. Compiling
tests/benchmarks/nofib-life.sml terminates with:

```text
Impossible: CompileDec.TypeFcn not simple
[[ERR in sub process:
  CRASH]]
```

The same seven checks pass on Rune's four engines, MLton, both 64-bit SML/NJ
versions, 32-bit SML/NJ and Poly/ML, at both Rune optimization levels.
The valid source uses memoized/strict instances of the same sequence and
list-grid functors. The crash's cause has not been isolated. It has different
error text from the paired compressor/RSA failures; no common cause is asserted.
No source workaround or alternate expected result is introduced.

```sh
BENCH_CONFIGS=native:mlkit sh tests/benchmarks/check-nofib-life.sh
```

Benchmark smoke/normal validation remains separate from this additional test.

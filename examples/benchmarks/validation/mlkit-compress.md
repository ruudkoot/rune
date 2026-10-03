# ML Kit paired compressor semantics test

Recorded 2026-10-03 with managed ML Kit 4.7.23. Compiling
tests/benchmarks/compress.sml, which instantiates the same prefix-tree functor
with memoized and strict suspension adapters, terminates with:

```text
Impossible: StatObject.instance_with_types.wrong number of types
[[ERR in sub process:
  CRASH]]
```

The identical source passes seven checks on Rune's four engines, MLton,
both 64-bit SML/NJ versions, 32-bit SML/NJ and Poly/ML. Both standalone
compressor benchmark smoke programs compile and pass on ML Kit. The internal
crash is a compile failure of this combined test; its cause has not been
isolated. No benchmark/library workaround or alternate expected result is added.

Reproduce the compiler failure with:

```sh
BENCH_CONFIGS=native:mlkit sh tests/benchmarks/check-compress.sh
```

The nine other configurations can validate both levels explicitly:

```sh
BENCH_CONFIGS=rune,rune:new,rune:jit,rune:opt,native:mlton,native:smlnj-legacy,native:smlnj32,native:smlnj-dev,native:polyml \
  sh tests/benchmarks/check-compress.sh
```

The failed O0 build and completed nine-configuration O2 run are retained with
the application's correctness/count evidence. Primary smoke/normal benchmark
validation remains separate from this additional semantics target.

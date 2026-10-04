# ML Kit constraint semantics compilation

Recorded with managed ML Kit 4.7.23 on 2026-10-04. Compiling the final constraint
semantics test fails with:

```text
Impossible: CompileDec.TypeFcn not simple
[[ERR in sub process:
  CRASH]]
```

The same nine obligations pass on the other nine configurations at both
optimization levels. Scratch files containing the same operations/checks
previously passed ML Kit. The final helper/test share basename
nofib-constraints.sml in separate directories; the role of source names or
positions has not been isolated. The crash text matches the earlier paired
Life report, but no common cause is asserted. Standalone benchmark validation
remains separate from this additional test. No source workaround is applied.

```sh
BENCH_CONFIGS=native:mlkit sh tests/benchmarks/check-nofib-constraints.sh
```

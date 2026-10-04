# ML Kit Stack semantics compilation

Recorded with managed ML Kit 4.7.23 on 2026-10-04. The final Stack semantics
program repeatedly fails compilation with:

```text
Impossible: LambdaBasics.mk_subst: 0 tyvars, 1 types; reduce2
[[ERR in sub process:
  CRASH]]
```

Nine other configurations pass its nine checks at both optimization levels.
The same operations and checks previously passed ML Kit in scratch files with
different filenames and comments. The final helper and test both have basename
ocaml-stack.sml in separate directories. The role of filenames/source positions
has not yet been isolated; no general cause is claimed. The source remains
unchanged to preserve this reproduction. Standalone benchmark validation is
recorded separately from this additional test.

```sh
BENCH_CONFIGS=native:mlkit sh tests/benchmarks/check-ocaml-stack.sh
```

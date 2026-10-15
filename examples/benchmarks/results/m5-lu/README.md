# Sequential LU factorization

Recorded 2026-10-15. [All 28 smoke/normal cases](correctness.tsv) pass on four
Rune engines at both levels and all six managed SML hosts. Fourteen numerical
checks pass all ten configurations at both levels, including rejected absolute/
relative perturbations and nonfinite values. All four normal count samples pass;
allocation and applicable instruction comparisons agree.

The kernel preserves flat row-major unpivoted elimination, cached multipliers,
input copying and separate L/U constructions. Normal256 balances computation
and validation; large1024 preserves the published run configuration. The driver
streams original-OCaml packed factors and checks packed/L/U values within
absolute1e-9 plus relative1e-10 of finite references. This replay bound is distinct
from true forward accuracy. Checking work and generic-array boxing are explicit
adaptations, with fixed generator/state provenance retained.

Bounded original OCaml observers produce all three selected fixtures. Independent
60-digit elimination and residual reconstruction validate smoke/normal. Normal
scaled residual is about1.50e-16, while the maximum packed discrepancy against
high precision is about7.52e-10. Those reference accuracy findings do not change
the runtime replay criterion. Large SML execution is not universally claimed.
Raw samples retain source/input/tool identities; instrumented times are not
headline timing results. M5 remains in progress.

To repeat reference acquisition, use OCaml4.14.1 and copy `reference-observers/`
to a scratch directory. Restore the retained original LU source at the repository
path named by acquire-final.py, then run that helper from the repository root,
followed by independent-final.py. They create an acquired/ directory containing
new factors and original inputs; compare its identities with metadata.json.
The existing smoke/normal original input arrays are also retained here for
independent examination. Benchmark execution uses the committed SML sources
and expected-factor fixtures through the suite manifest.

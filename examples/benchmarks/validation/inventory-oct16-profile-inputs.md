# Profile input and inventory reproducibility review

Recorded 2026-10-16. Clean checkouts at all five locked upstream revisions
reproduce all 861 inventory entries after this review. No program disposition,
source member, source digest or pinned revision changes. Four new regressions
bring the inventory test set to 45 passing tests.

The scanner previously missed literal file arguments supplied through nofib
FAST_OPTS/NORM_OPTS/SLOW_OPTS. It now reads those assignments, quoted paths,
line continuations and --option=file forms without evaluating Make or shell
expressions. Existing relative-path containment and tracked-file filters apply.
Nine entries gain 22 file references, including the dom-lt graph dataset.
Source files used as runtime sorting inputs are retained as input identities.

| Workload | Additional input paths |
|---|---|
| `gc/happy` | `gc/happy/TestInput.y` |
| `gc/spellcheck` | `gc/spellcheck/input`; `gc/spellcheck/words` |
| `real/hidden` | `real/hidden/runtime_files/four.plate`; `real/hidden/runtime_files/houses.plate`; `real/hidden/runtime_files/rad.plate` |
| `real/maillist` | `real/maillist/runtime_files/fast`; `real/maillist/runtime_files/norm`; `real/maillist/runtime_files/slow` |
| `spectral/dom-lt` | `spectral/dom-lt/ghc-examples.in` |
| `spectral/mate` | `spectral/mate/runtime_files/heathcote3.prob`; `spectral/mate/runtime_files/holzhausen.prob`; `spectral/mate/runtime_files/kohtz.prob` |
| `spectral/para` | `spectral/para/runtime_files/input-data` |
| `spectral/sorting` | `spectral/sorting/Main.hs`; `spectral/sorting/Sort.hs` |
| `spectral/treejoin` | `spectral/treejoin/runtime_files/1500.1`; `spectral/treejoin/runtime_files/1500.2`; `spectral/treejoin/runtime_files/27000.1`; `spectral/treejoin/runtime_files/27000.2`; `spectral/treejoin/runtime_files/8000.1`; `spectral/treejoin/runtime_files/8000.2` |

The initial clean replay also exposed nine manually appended related-name
lists whose order differed from regenerated discovery. Their membership was
already correct. Sorting related names makes that metadata independent of
discovery order; the checked inventory is regenerated accordingly.

Regression fixtures cover the omitted graph dataset, quoted/continued/flagged
file arguments, references outside the pinned tree, and related-name order.
All 45 tests pass and the complete five-source --check exits 0. The raw log and
field-by-field changes are retained beside this note. This is an inventory
refresh, not completion of M3/M4/M5 or closure of M8.

[Validation log](inventory-oct16-profile-inputs.log);
[input changes](inventory-oct16-profile-inputs.json);
[locked upstreams](../upstreams.tsv).

Full `DEBUGINFOD_URLS= make JOBS=4 check` also exits 0. The
[import-wave transcript](oct16-eliza-packed-889-acceptance.log) records the
889-profile catalogue, bounded routine checks and all compiler comparisons.

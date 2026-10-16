# Current and historical Mandelbrot orbits

Recorded 2026-10-16. Four imports, together with the tree pair, bring the
catalogue to 287 programs and 855 profiles. All 112 requested orbit cases are
accounted for: 110 pass and two legacy64 normal cases reject incorrect digests.
Every Rune engine passes both profiles at both levels; all other native hosts
pass, as do both profiles of the historical variants on legacy64. Twenty-six
semantic/negative checks run on every configuration twice. Only legacy64 fails
two checks per pass; the other nine configurations pass all 26.

Sixteen normal count samples agree with unchanged existing budgets; these new
profiles are currently unbudgeted. Twelve serial native smoke samples validate
MLton, SML/NJ and Poly/ML adapters. Instrumented counts and single-sample
adapter diagnostics remain separate from headline timings. A successful smoke
sample is not evidence that a normal profile is correct on that configuration.

Original GHC pixmaps and independent binary64 models agree on every component
through 180x180, rectangular and zero/one-limit cases. Separate GHC Word64
observers agree with independently derived full-image digests. Main executes
its 100 NFData repetitions on all three upstream sizes; the historical module
uses the two recorded syntax-only reference adaptations. Current SML pixmap
preflights check all 24 variant/input combinations once, including 180x180;
this is not canonical 100-repetition large validation on every host.

The ports retain Integer coordinate enumeration/metadata, complex operation
association, scaled-norm versus raw-threshold differences, shared RGB values,
cyclic/take memoization and historical extra-head forcing. Strict finite
orbits/grid/pixel lists preserve their explicit eager behavior, including
unused post-escape arithmetic. Full-result digests/counts/metadata/EOF consume
every channel. Deterministic SML-generated parameter rows retain repeated
runtime input and prevent whole-render invariant hoisting. Parsing, file I/O,
hashing and checking costs are explicit. Negative checks reject altered RGB,
metadata, count, digest, missing/truncated/extra reference data.

Canonical failures and default/64 MiB nursery replays remain separate in
coverage/host-diagnostics. Both failed normal contexts pass with the larger
nursery. The first corrupt operation is not reduced; no kernel, reference or
default-setting workaround is introduced. Original/library notices, historical
syntax patches, source/input identities and all raw outcomes are retained.
No prerequisite compiler/runtime feature or universal large execution is
introduced or claimed. M3 remains in progress.

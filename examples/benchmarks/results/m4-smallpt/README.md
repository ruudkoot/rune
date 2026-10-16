# Sequential smallpt rendering

Recorded 2026-10-16. One import brings the catalogue to 275 programs and
819 profiles. All 28 requested smoke/normal cases are accounted for: 26 pass;
both native32 profiles reject different rendered pixels. Every Rune engine
passes both levels/profiles, and all other native hosts pass. Thirteen
semantic/negative checks run on all ten configurations at both levels.
Native32 fails the complete RNG-state/value and smoke-image checks; its other
eleven and every other configuration pass. These Word64-path findings are
retained without an alternate stream or expected image.

Four normal count samples agree across Rune engines with unchanged budgets.
Three serial native smoke samples also validate MLton, SML/NJ and Poly/ML
adapters. Instrumented counts and these single-sample diagnostics remain
separate from headline timings. Incorrect native32 pixels supply no measurements.

The port retains the nine spheres, strict vectors, ray/intersection order,
diffuse/specular/refractive branches, roulette and splitting, jitter, 2x2
subpixels, averaging/clamping, descending rows and full 64-bit recurrence.
Exact 48-bit dyadic conversion replaces the source bitcast. Row lists are
consumed incrementally and every RGB component plus sequential channel sum
is checked. Original full normal/large scenes and reduced smoke/normal scenes
are retained with all component values. Rune/MLton smoke and normal agree
exactly with the reference in the prototype comparisons.

A correctness-only boxed STRef adapter supplies the absent unboxed-ref API,
with strict initialization/writes. It is not an original-runtime performance
measurement. Its source hashes match both pinned nofib fixture values; the
fixtures add one terminal newline absent from the source hPutStr output.
That exact normalization and the initial failed formatting comparison are
recorded. Complete strict-adapter RGB outputs remain unchanged, and independent
integer recurrence checks verify 50 full RNG states/draws.

Raw results, complete semantic logs, helper/source identities, adapted reference
sources, scene fixtures and geometry/negative tests are retained. Authorship,
unstated individual notice, input/representation/validation costs and numerical
budgets are explicit. No prerequisite compiler/runtime feature or universal
large SML execution is introduced or claimed. M4 remains in progress.

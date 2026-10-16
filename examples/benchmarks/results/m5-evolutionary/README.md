# Seeded sequential evolutionary computation

Recorded 2026-10-16. One import brings the catalogue to 274 programs and
816 profiles. All 28 smoke/normal cases are accounted for: 26 pass, while both
native32 cases raise the documented bounded-random arithmetic Overflow. Every
Rune engine and the other five native hosts pass both profiles. Twelve semantic
and negative checks run on all ten configurations at both levels; native32's
six checks that invoke bounded selection fail with that same exception. The
other six native32 checks and every other configuration pass.

Four normal count samples agree across Rune engines with unchanged budgets.
Three serial native smoke samples validate MLton, SML/NJ and Poly/ML adapters.
These instrumented samples and single-sample diagnostics are separate from
headline timings. Failed native32 results supply no measurements.

The port retains boolean arrays, float fitness, strict tie behavior, recursive
tournaments, full copying mutation and every RNG draw. The source's post-generation
strict budget test remains: initial population plus floor(budget/lambda)+2 new
generations. Seed 42 replaces OS entropy explicitly for reproducibility; all
other generation/update behavior is retained. Every final bit and fitness is
checked against complete original deterministic populations. Independent packed-bit/
integer-popcount computation verifies tiny/smoke/normal exactly, including
6/176/10,368 evaluations and random draw counts.

The unmodified nondeterministic original also completes; its output is not a
reproducible golden. Seed patch, CLI/observation adaptations, original source,
independent references, raw results, notices and identities are retained. The
selected file is sequential despite its multicore collection/title. No runtime
feature or universal large SML execution is introduced or claimed.
M5 remains in progress.

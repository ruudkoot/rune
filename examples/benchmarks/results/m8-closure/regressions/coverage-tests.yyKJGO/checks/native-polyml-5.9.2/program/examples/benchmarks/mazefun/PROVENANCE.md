# mazefun provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`, `programs/mazefun/main.sml`.
Copyright 2024 The Fellowship of SML/NJ; notice and pristine source retained.
Marc Feeley's Larceny Scheme maze generator was ported by Kavon Farvardin
for Manticore. Upstream calls the benchmark `mazefn`; the directory and
established Scheme name are `mazefun`. Record `mazefn` as an alias.

Preserve persistent list matrices, recursive cavity relabeling, hole order,
and the integer generator `(seed*3581+12751) mod 131072`, seeded at zero for
each shuffle. Rename the module to expose `makeMaze` to a portable driver.
Flatten the complete rendered matrix into one line with slash row separators
and compare every character; suppress direct logging. Repetitions check
each regenerated maze against the first. Smoke is the 11-by-11 maze printed
in the upstream comment; normal uses 100 repetitions of its 15-by-15 maze;
large retains the original 10000 repetitions. Each consumes its result.

Independent fixtures come from the union-find Python oracle, whose different
representation also verifies a connected, acyclic maze. The 11-by-11 fixture
was reviewed against the source comment. No external dataset is required.
Persistent updates, flood-fill recursion and intermediate lists are
diagnostic hypotheses from source inspection. No performance finding is
claimed. The Larceny/R6RS family remains a coverage candidate in the
[literature review](../literature.md); this port records that overlap.

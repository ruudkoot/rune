# bernouilli-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/bernouilli/Main.hs`. Complete original source,
Makefile and available upstream fixtures are retained with SHA256SUMS.

See ../bernouilli-lazy/PROVENANCE.md for history, alias, source notice gap,
profiles, exact references, ratio arithmetic and Show/hash semantics.
The strict variant uses ordinary finite power and Pascal lists and recomputes
them per repetition, omitting the lazy port's shared global caches. It keeps
the same multiply-by-base recurrence and signed power-sum formula, with
identical normalized IntInf ratio operations in ../shared/rational.sml.
Demand, recomputation, allocation and retained data therefore differ; this
is a separately named strict workload, not a claim about GHC's optimized
execution. Full rational values and original 64-bit hashes are checked.

See [the literature survey](../literature.md).

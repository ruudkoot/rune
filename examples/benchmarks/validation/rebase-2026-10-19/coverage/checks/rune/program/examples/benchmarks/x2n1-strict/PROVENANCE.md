# x2n1-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/x2n1/Main.hs`. Complete original source,
Makefile and available upstream fixtures are retained with SHA256SUMS.

See ../x2n1-lazy/PROVENANCE.md for authorship, history, numerical checks,
profiles and references. This separately named strict variant preserves the
same complex arithmetic and power order via ../shared/x2n1.sml. All root
powers are computed into an ordinary finite list before summation. This
changes allocation/retention and evaluation order relative to demanded list
nodes, while retaining the same element and accumulation order. Both components
are consumed and checked. Strict/lazy results agree on smoke and normal.
The original letter, source, Makefile and fixtures are retained here too.

See [the literature survey](../literature.md).

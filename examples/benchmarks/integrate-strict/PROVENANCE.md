# integrate-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `imaginary/integrate/Main.hs`. Complete original source,
Makefile and available upstream fixtures are retained with SHA256SUMS.

See ../integrate-lazy/PROVENANCE.md for the algorithm, authorship gap,
profiles, exact polynomial oracle, numerical bounds and references.
This strict finite projection uses the same ../shared/integrate.sml kernel,
then builds ordinary input, integral, fourth-power, cumulative-total and
squared-error lists before summation. It omits infinite memoized CAFs and
changes retention/evaluation; the selected values and arithmetic order are
unchanged. Both final cumulative streams and scalar error are consumed and
validated. Preserve the original source, Makefile and fixture here too.

See [the literature survey](../literature.md).

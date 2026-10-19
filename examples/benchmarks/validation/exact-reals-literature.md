# Exact real arithmetic literature review

David R. Lester, *The world's shortest correct exact real arithmetic program?*,
Information and Computation 216 (2012), 39–46,
[DOI](https://doi.org/10.1016/j.ic.2011.09.004);
[full text hosted by Manchester](https://www.cs.man.ac.uk/~bparsia/2017/introexercise/lester1_unblanked.pdf).
Reviewed 2026-10-17, sections 3–6 and Appendix A.

The paper defines fast binary Cauchy approximants and derives guard precision
and trigonometric range reduction. It reports PVS validation, while explicitly
allowing errors in the later Haskell translation. Its choice of wider reduction
intervals favors proof simplicity. These arguments motivate preserving precision,
rounding and reduction rules; they do not verify this SML port.

The import's source comparisons, scalar numerical cross-checks, demand probes
and compiler matrices are separate empirical evidence. No proof or performance
claim is transferred to the port.

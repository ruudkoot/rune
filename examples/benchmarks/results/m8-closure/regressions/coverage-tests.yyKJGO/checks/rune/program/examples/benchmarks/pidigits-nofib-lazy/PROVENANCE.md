# pidigits-nofib-lazy provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `shootout/pidigits/Main.hs`.
Bryan O'Sullivan contributed the Benchmarks Game program; Eugene Kirpichov changed
its output construction according to the retained header. No individual licence
is supplied; retain the notice gap, complete source, fixtures and build manifest.
This is a distinct variant of the classic pidigits programs, preserving its
step-before-extraction recurrence and formatting; collision names use -nofib.

Preserve all exact Integer arithmetic as IntInf, quotient/remainder conditions,
index advancement and digit extraction. In particular n>a short-circuits before
expensive division. The lazy port memoizes each coefficient and digit/spine;
the strict variant evaluates coefficient triples eagerly. It avoids computing
an unused final scaled state. Arithmetic values and output agree, while delayed
work, retained coefficients and allocation differ materially. The bounded term
index fits all supported machine Int widths. No arbitrary-precision operations
are replaced with floating point or host-width wrapping arithmetic.

The shared formatter preserves ten-character blocks, final space padding,
TAB-colon indices and newlines, using linear block splitting. Every output byte
is checked against original GHC output and independently computed high-precision
Chudnovsky digits, including the partial 27-digit smoke block. SML materializes
the selected prefix and final string instead of printing the Haskell lazy String;
record this representation/retention change. The actual byte count is consumed.
Profiles select 27/200/3500 digits; large preserves original FAST, while original
normal 11000 and slow 22000 remain recorded and unexecuted on all SML engines.
References: original author/header, exact upstream fixtures and the nofib/Benchmarks
Game literature. Arithmetic, demand, sharing and formatting costs are source
hypotheses until separately measured. Large SML execution is not universally claimed.

The initial 1000-digit normal input timed out after 600 seconds on Rune -O0
stack execution. Keep that rejected attempt. The selected 200-digit normal
fixture is independently reviewed and retains the same extraction algorithm.

# iter-pidigits provenance

SML/NJ `75ee8bee6fbd38af68a549bc6ca091f15fb8d3f0`,
`programs/iter-pidigits/pi-digits.sml` and `main.sml`.
Copyright 2026 The Fellowship of SML/NJ; notice and pristine sources retained.
The upstream README identifies the Benchmarks Game C version (retained in
the pinned tree at `other/pidigits.c`) and Jeremy Gibbons's
[Unbounded Spigot Algorithms for the Digits of Pi](https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/spigot.pdf), section 5.

This is an iterative IntInf spigot, distinct from the lazy stream and
zero-count stopping condition of `pidigits`. Keep its arithmetic, column
counter and termination. Capture each emitted digit, omit the human-readable
column labels, then validate every digit against an independently calculated
Chudnovsky fixture (`oracle.py`). Smoke retains upstream's 30-digit check;
normal selects 100 digits; large preserves upstream's 2000. The original
2000- and 500-digit normal runs passed the reference hosts but timed out after 600
seconds on Rune. Moving that input to the 3600-second large profile preserves
the algorithm and stopping condition without changing its arithmetic. There are no external
datasets or random seeds. Arbitrary-precision division and multiplication
and iterative control flow are source-based diagnostic hypotheses.

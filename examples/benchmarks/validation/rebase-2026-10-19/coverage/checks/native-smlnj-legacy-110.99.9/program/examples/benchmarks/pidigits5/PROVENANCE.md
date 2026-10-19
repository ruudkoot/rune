# pidigits5 provenance

Sandmark 5605805954a00497ed197c930641cddd580e1507,
benchmarks/benchmarksgame/pidigits5.ml. The header credits Christophe Troestler,
Matías Giovannini and Tony Tavener's C-inspired changes. Preserve the original
Latin-1 author byte and Revised BSD notice/CRLF bytes. Zarith 1.14 library source
identities and GNU Library GPL/linking-exception notice remain retained with
the suite's Zarith reference material. No input dataset is acquired.

## Algorithm and variants

Generate pi by a three-component integer transformation (num,den,acc). Extract
at 3 and 4, compare the candidate for safety, multiply the numerator/adjusted
accumulator by 10 to emit a digit, or refine with k and 2*k+1. Preserve both
extract divisions, separate acc+num+num additions, operation order and the
source's right-to-left tuple-construction work order. Measured arithmetic uses
SML97 IntInf, including truncating quot to match Zarith division.

The four-coefficient Sandmark zarith_pi keeps general LFT composition and zero
coefficients. nofib's optimized pidigits uses different quotient/remainder
safety/refinement work. Keep these materially different representations and
library operations separately named. Do not replace this program by the
independent AGM calculation or reuse another kernel merely because digits agree.

## Profiles, formatting and checks

Smoke 27 preserves the no-argument source default. Normal 128 is a bounded
comparative input; large preserves the selected 10,000-digit source run.
A standalone Rune -O2 resource calibration takes about 23 seconds for 128 digits;
larger exploratory sequences remain incomplete/time-limited. This is profile
calibration, not a comparative timing claim. Source transformation counters
for selected profiles fit 31 bits; coefficients have arbitrary precision.

Preserve ten-column blocks, row counts, tabs, final spaces/newlines and the
special zero-count output. A thin emit callback replaces print_int/Printf and
checks every generated character against reviewed complete output. It retains
streaming observation without materializing the digit sequence first. File
loading and checks are measured work; the final result reports count:checked.
Every invocation starts with the same initial transformation.

All original outputs at 0/1/10/11/27/128/256/1,000/10,000 agree exactly with an
independent high-precision Gauss-Legendre pi calculation and separately built
block layout. Source/independent fixtures and identities are retained.
Large execution of the SML port is claimed only where explicitly recorded.
Semantic/negative tests cover extraction, refinement, negative accumulators,
truncating division, block boundaries and perturbed/missing/extra output.

## References and diagnostic questions

Gibbons's [Unbounded Spigot Algorithms for the Digits of Pi](https://www.cs.ox.ac.uk/people/jeremy.gibbons/publications/spigot.pdf)
supplies algorithm-family context. The retained source defines this particular
three-state implementation and output adapter. Integer division, coefficient
growth, repeated additions, intermediate allocation, specialization, tuple
representation and bigint-library behavior are source-based hypotheses until
supported by inspection or measurements. Standard reports compare identical
SML; OCaml/Zarith and the independent AGM computation supply references.

# cryptarithm2-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, spectral/cryptarithm2,
Main.hs/Makefile and all three upstream stdout fixtures. Andy Gill's October 1999
header identifies the author and explains the column-pruning guard. Retain the
full header; an individual license grant for the program is unstated. Puzzle
words are embedded program data, with no external dataset. Original source
imports transformers; the reference uses GHC 9.4.7 / transformers 0.5.6.2. Retained
State/State.Lazy/Class sources are pinned to transformers commit
0fe761c9287111373ae64ab39b67fbcde212b3f7 (release 0.5.6.2), with complete BSD notices
and authorship headers. The State re-export selects the lazy module.

## Algorithm, variants and translation

Preserve the ordered list-of-successes state search, remaining-digit deletion,
reverse-chronological association list, lookup-before-allocation, mapM selection,
column summation, units-digit guard and carry propagation. The main puzzle is
THIRTY + five TWELVEs = NINETY. Leading zero assignments remain legal; no extra
pruning rule or mutable in-place permutation algorithm is substituted.
`cryptarithm1` exhaustively filters a different permutation enumeration and is
separately scheduled, rather than identified as a duplicate by puzzle name.

SML97 translates the used StateT operations into functions from state to
memoized sequences of delayed value/state pairs. Record fields, remaining-digit
lists and environment cells stay delayed/shared in Need. Branch dispatch
inspects a result-pair constructor; values and state remain independently delayed.
This is the program's state/list search, not a general-purpose Haskell typeclass
library port. Shared initial digits are built once per functor instance.
The strict policy uses the same code and fully materializes finite branches;
it can evaluate alternatives past the first solution. Need retains the original
first-answer demand. Explicit suspension cells, closures and generic SML types
change representation/allocation and are documented translation costs.

Input word strings, reversing and ragged transpose use ordinary finite SML
lists prepared once per puzzle call. Search-result and state sequences remain
explicitly lazy in Need. These small input spines are acquired eagerly rather
than using Haskell character-list demand; every selected complete solution needs
all columns. Symbol counting, dictionary ordering, final arithmetic verification
and map formatting remain intact. Integer arithmetic uses default int: digit,
carry, six-place expanded values and six-word sums all fit signed 31 bits for the
fixed profiles, preserving GHC Int arithmetic without overflow.

## Profiles and correctness

Smoke 1 is bounded for routine correctness; normal 300 and large 1500 preserve
published NORM/SLOW repetitions, and original FAST 30 is also checked as a
reference. Each iteration constructs the original word list with its i>999999
conditional; no selected iteration takes the extra-symbol branch. Each puzzle
call performs fresh search with the shared initial digit list. It validates the
sum, renders the complete mapping in original environment order, and compares
all bytes to a reviewed 70-byte original fixture. The driver consumes output
lengths and returns repetition/byte counts rather than printing repeated maps.
The fixture read and byte comparisons replace original stdout IO; their cost
is part of suite execution and is explicit.

An independent exhaustive 10! assignment search establishes a unique mapping.
GHC observers compare the full solution state and first-answer text. Original
smoke/FAST/normal/large runs match the independent mapping and all available
pinned stdout fixtures byte for byte. Semantic checks cover both full searches,
rendering, ragged transpose, deletion of only the first occurrence, variant
agreement on smaller puzzles, carry rejection, leading-zero acceptance and
non-demand of unused digits/choice tails. Large SML execution is claimed only
for recorded cases.

## References and runtime questions

The source cites [Jones, Functional Programming with Overloading and Higher-Order
Polymorphism](https://web.cecs.pdx.edu/~mpj/pubs/springschool.html), Advanced
Functional Programming, LNCS 925, 1995, as its monad-library background. The
[retained program](https://github.com/ghc/nofib/blob/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/cryptarithm2/Main.hs)
and pinned library definitions establish this implementation's actual search.
Jones's paper supplies background, not performance measurements of this port.

Branch ordering, state lookup/extension, backtracking allocation, pruning,
closure specialization and suspension sharing are source-based hypotheses
until investigated with measurements or compiler inspection. Standard compiler
comparisons use identical SML; Haskell is a correctness reference. No historical
speed claim in a source comment is transferred to Rune.

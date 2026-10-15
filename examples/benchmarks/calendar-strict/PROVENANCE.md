# calendar-strict provenance

The pin is nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`,
`spectral/calendar/Main.hs` and `Makefile`. The source identifies a modification
of section4.5 of Bird and Wadler's Introduction to Functional Programming, with
two picture formats. Main selects the Unix-cal-style cal. The unused alternate
calendar formatter remains in retained source, outside the selected invocation.
Partain's appended helpers and SDM's length-only output change remain attributed
in the comments. Original modifier and individual license grant are unstated;
all original source, fixtures, build settings and identities are retained.

## Algorithm, variants and portable representation

Preserve nested character/row/picture lists, append/zipWith composition, right
folds, grouping, weekday scans, Gregorian leap rules,42 date positions, exact
centering and padding. Both variants share one SML97 functor. Memoized sequences
keep character payload separate from spine demand; eager sequences materialize
those finite structures. Source length observation does not force date glyphs.
Decimal conversion therefore delays character heads, while exposing the digit
spines needed for justification. Group tail/drop work is delayed until selected.
Constant month/day text remains shared. Explicit cells, portable list helpers
and custom decimal conversion are representation/library adaptations.

The GHC type audit identifies calFor as String -> Int -> IO(), despite cal's
Integral-polymorphic helper type. atoi uses fromEnum, hence the actual main
uses machine Int. All selected values fit signed31bits, including the largest
sum144,400,000. The port retains exact arithmetic over that domain. Selected
text is ASCII, so SML97 chars preserve the original character values.

## Inputs, validation and forcing

Arguments retain base-year and repetition count. Base1993 plus i in1..count
gives firstyear1994, normal's lastyear11993 and large's lastyear51993.
Smoke2 is deliberately small; normal10000 and large50000 retain original NORM/
SLOW parameters. Original FAST1000 remains in provenance. No external dataset
is used; layouts are generated from arithmetic and fixed English names.

The source prints length(cal year) each iteration. The driver preserves that
observation, checks each length2888 (38rows of75characters plus LF), and consumes
it in a checked count/sum. It validates base/count once, replacing the source's
per-calFor span/atoi at source level. Compilers may hoist invariant parsing.
There is no added full-character forcing inside measured work. Length has limited
discrimination for wrong glyphs; full layout correctness is checked separately.

Twenty-one semantic checks cover complete rendered fixtures at11 years, leap/
weekday rules, grouping demand, negative padding/drop and unforced character
payload through justification/unlines. Original GHC and an independent Python
Gregorian renderer agree byte for byte on those layouts. The renderer uses the
source's floor-left centering, rather than Python str.center's different odd-gap
rule. GHC demand observers independently confirm the unforced-payload properties.
Original length fixtures/runs agree for selected profiles. Large SML execution
is claimed only for recorded cases.

## Runtime questions and references

Memo-cell retention, shared picture fragments, digit conversion, grouping and
constant-length optimization are source-based diagnostic hypotheses until
measured or established by IR inspection. Every selected calendar has the same
length, which permits benchmark-specific optimization. Comparisons use identical
SML sources; original Haskell is a correctness reference. Source comments provide
the Bird/Wadler ancestry; see also the [pinned implementation](https://github.com/ghc/nofib/blob/b7391df4540ac8b11b35e1b2e2c15819b5171798/spectral/calendar/Main.hs)
and the shared nofib/measurement literature survey. No historical timing claim
is transferred to this port.

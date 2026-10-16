# fish-strict provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`,
`spectral/fish/Main.hs` and `Makefile`. The functional-geometry pseudocorner and
pseudolimit construction matches Henderson's published method; the particular
Haskell port's author is unstated. The source credits SLPJ's November 1999
formatter change and discusses earlier GHC behavior. Original program, embedded
tile constants, notices, build settings and identities remain retained. An
individual program/data grant is unstated. No external tile dataset is acquired.

## Algorithm and known variants

A picture maps an origin and two bounding-box vectors to ordered line segments.
Preserve the four integer tile tables, rotations, weighted above/beside,
quartets, cycles, side/corner hierarchy and Main's pseudolimit. The unused nonet
and full squarelimit definitions remain source provenance, outside Main's
selected workload. The source comment says floats, but its explicit Vec type
is a pair of machine Int values. Every intermediate multiply/divide and negative
floor division is preserved; collapsing transforms or substituting real affine
arithmetic would change coordinates.

Both ports share an SML97 functor. Need memoizes vector headers/components,
segment fields and sequence spines/heads. Strict materializes finite structures.
Picture closures remain functions; explicit cells and tuples replace Haskell's
lazy representation. Second picture branches stay delayed in Need, and formatter
segments are demanded after their prefix. scale_vec2 remains a distinct function.
Its inlining/CPR comment is source history, not a measured Rune result.

## Inputs, observation and result validation

Smoke 1 is deliberately small; normal 300 and large 1,500 retain upstream NORM/SLOW
repetitions. Original FAST 30 remains provenance. Main's i in1..count and
min(0,i) offset remain explicit, producing the original 640 bounding box. Tile
coordinates, intermediate operations, loop counts and largest summed length
254,044,500 fit 31 bits on selected profiles. No modular/precision substitution
is needed over that domain.

Original Main forces length(fmt(pseudolimit ...)) and returns unit. The portable
driver checks 169,363 each iteration and consumes it in a count/sum, preserving
that length observation without forcing character payload. Decimal character
heads are delayed separately from numeric/digit-spine work. Formatting retains
tuple commas, newline separators, brackets and the explicit second showl argument.
Empty pictures format as []. Driver argument parsing/validation happens once.
Length has limited discrimination for wrong coordinates or glyphs; full data
validation belongs to the separate semantic target.

GHC and an independent integer-affine model agree on all 9,344 segments and exact
formatted strings at sides 255,640,641, covering intermediate rounding differences.
Ten semantic checks cover complete coordinates/format, variants, negative floor
scaling, identity grid, segment count, empty output, deferred prefix and decimal
spine length. Original bounded smoke/normal/large invocations also complete.
Large SML execution is claimed only for recorded cases.

## Runtime questions and references

Higher-order picture composition, tuple/header sharing, field forcing, scale
inlining, constructor representation and length-based optimization are diagnostic
hypotheses until established by measurements or IR inspection. Every selected
iteration describes the same scene; the source's min expression and observation
may permit compiler specialization or hoisting. Comparison reports use identical
SML sources; Haskell supplies correctness references.

Algorithm background: Henderson, [Functional Geometry (1982)](https://worrydream.com/refs/Henderson_1982_-_Functional_Geometry.pdf),
which describes compositional line pictures. Program-specific integer rounding
and formatter behavior are established by the retained nofib source and observers,
not assumed from the abstract geometric method. See the shared nofib/measurement
survey; no historical timing result is transferred to this port.

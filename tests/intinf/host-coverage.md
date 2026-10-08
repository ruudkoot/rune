# Host coverage enabled by M2

The SML/NJ32 `xc1` configuration has a 31-bit machine `int`. The original
IntInf file could not load there: its base 2^30 is itself outside that
signed range. The replacement uses 15-bit scratch digits and loads, so tests
that previously could not typecheck through `LargeInt` now execute.

The comparison used the exact M1 sources at `bf5ac2c5`, extracted into the
ignored `tests/out/intinf/baseline-tree`, with the same installed SML/NJ
110.99.9 (32-bit). Filtered matrix runs used `date`, `time`, `real32`,
`intn_int8`, and `intn_int16`. Their logs are
`tests/out/intinf/baseline-FILTER.log`. The actual `date`, `time`, `real32`,
`intn_int8`, and `intn_int16` programs did not run at M1 (some related
signature, formatting, and monomorphic-array programs did).

At M2, these five programs execute. They expose 162 previously unexercised
limitations, rather than 162 wrong results from the new IntInf arithmetic:

| Program | Pass | Explained failures | Cause |
|---|---:|---:|---|
| date | 6 | 126 | Fixed-offset construction computes 86400 * 1000000 in a 31-bit int, even for offset zero. Date construction raises before the accessor or other check can obtain its input; epoch-sized Time values also exceed that representation. |
| time | 152 | 28 | The implementation stores microseconds in a machine int; the tested large durations and current epoch do not fit in 31 bits. |
| real32 | 182 | 6 | One conversion uses Real.toLargeInt's wide intermediate; one formatter truncates to 17 digits; four math cases inherit the host's signed-zero/infinity defects. |
| intn_int8 | 2625 | 1 | The host's closed overloading uses its native integer operator rather than the smaller checked operator. |
| intn_int16 | 2625 | 1 | The same closed-overloading limitation. |

The Date and Time entries name individual failing checks. They do not excuse
all future failures of those structures. Width limitations remain failures
in the matrix's explained column. Fixing Date/Time's representation on narrow
hosts is separate work; no workaround is added to Rune's arithmetic kernel.

A native SML/NJ32 probe independently confirmed `Int.precision = SOME 31`,
overflow of the day-in-microseconds product, positive zero from `Math.tan`,
`Math.sinh`, and `Math.tanh` on negative zero, NaN from `Math.tanh` on positive
infinity, and only 17 significant digits for the Real32 0.1 value at GEN 20.
These math defects already have entries for the other SML/NJ configurations;
the ledger now includes this configuration too. The local probe and output
are `tests/out/intinf/host-probe.sml` and `host-probe.log`.

The complete M2 matrix also found ten stale expectations concerning Int64 /
Word64 precision and PackReal on wide hosts. Those checks now pass; their
old deviation entries are removed. All 5,418 direct IntInf checks pass on
each of the six hosts, and all Rune Basis checks pass.

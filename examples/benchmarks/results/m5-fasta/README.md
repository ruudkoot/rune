# Sequential FASTA generation variants

Recorded 2026-10-16. Two imports bring the catalogue to 258 programs and
768 profiles. All 56 smoke/normal cases pass on four Rune engines at both levels
and all six managed native hosts. Nine semantic/negative checks pass all ten
configurations at both levels. Eight normal count samples pass the combined
SML comparison. Budgets remain unchanged; instrumented samples are separate
from headline timings.

The ports retain distinct line-buffer/whole-buffer strategies, linear/midpoint
probability lookup, division/reciprocal multiplication, source data and seed
continuity. Portable mutable buffers and callbacks preserve slice access without
creating a full immutable copy of large outputs. The defined initialization
required by SML97 CharArray adds a documented pass in fasta6. Fasta3 resets at
the suite call boundary to reproduce fresh-program behavior in repeated runs.

Both original programs and an independent periodic reference agree on complete
smoke/normal/large outputs, including SHA256 identities. Original cycle observers
and an independent probability builder agree for all 139,968 RNG states in both
distributions. The exact SML checker uses reviewed cycle bytes and a line/header
state machine, not the generator's RNG/CDF logic. Every output byte is checked.
Smoke includes wrapping/partial lines and normal covers the complete RNG cycle;
large preserves the published 25,000,000 input. Large execution of the new SML
ports is not claimed.

Full source/header/dataset origins, directory Revised BSD notice, aggregate
Unlicense, oracle acquisition and identities are retained. Oracle loading and
comparison costs replace original stdout IO and remain included in execution.
The nofib generator's binary32 arithmetic is a separate variant. M5 remains
in progress.

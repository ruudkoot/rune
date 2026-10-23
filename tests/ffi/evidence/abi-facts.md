# Native ABI facts

2026-10-23. `RuneForeign.abiFacts` exposes the runtime C compiler's measured
architecture, character representation and ten scalar sizes/alignments.
The query creates no registry or native resources and also works without
libffi. Generated loaders can reject LP64/LLP64/ILP32 mismatches before
opening libraries.

The new language fixture passes in stack and register interpretation and
JIT tiers 1 and 2 with collection stress and heap verification. A standalone
`-std=c99 -Wall -Wextra -Werror -pedantic -DRUNE_FFI=0` C probe passes;
native Linux reports long=8, pointer=8 and wchar=4. Basis implementation and
signature witnesses include the query. `make docs check-docs JOBS=4` passes
all 11 documentation checks.

Two overbroad local runner selections also selected portability binaries
that had not been built in this checkout: the first records 39 passes,
10 missing-host skips and 12 missing-VM failures; the second records
41 passes, 15 skips, seven missing-VM failures and four LeakSanitizer
environment failures. These are failed runs, not portability acceptance.
Portability, Windows and unrestricted sanitizer reruns remain outstanding
for this addition.

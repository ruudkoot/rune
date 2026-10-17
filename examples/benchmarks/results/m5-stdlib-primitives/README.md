# Portable stdlib arrays and comparisons

All 224 canonical smoke/normal cases pass on Rune's four engines at O0/O2 and six
native hosts at their defaults. All 41 auxiliary assertions pass in twenty
invocations (820 assertions), including the selected large parameter calls.
Thirty-two normal count samples agree under execution-model rules, including
allocation across every Rune engine. Existing budgets remain unchanged.
Twenty-four serial single fresh-process native smoke samples validate adapters
separately from headline comparisons and instrumentation.

Three array selectors retain zero-filled array allocation followed by index mapping into
a distinct array, source bound assertions, iteration and left reduction. Five
pervasives selectors retain source list/integer/finite-float/string ordering
and immediate-integer equality. The two original constant lists are shared
across loop iterations and repeated in-process runs. Typed library adapters,
unsigned Word32 result consumption and final checks are documented additions.

Unmodified OCaml originals and reference-only immediate-result observations
agree with independent closed-form result totals at all three profiles. Raw
signed totals and modular reports are retained separately. Tests also check
empty/singleton arrays, zero iterations, malformed initialization, source
assertions, short circuiting, comparator pivots, signed modular wrap and bounds.
No immutable heap-identity comparison is replaced by structural comparison.

The selector inventory covers 71 cases, including two already imported Stack
cases and two defined-but-undispatched byte workloads. Ten are implemented,
five have concrete runtime deferrals, and 56 remain planned. The Bigarray
family is deferred for its typed C-layout storage policy; three immutable-value
physical-identity cases have their own missing-facility conditions. Result-only
opaque wrappers do not justify blanket exclusion. This wave closes only the
portable array and pervasives cases, not the remaining stdlib families.

All 68 inventory regressions and all five clean pinned trees pass with 861
source entries. Only the reviewed primetest attribution and Bigarray disposition
rows change. Source hashes, per-case evidence/reachability, original run-plan
arguments, notices, generation, adapters and measurement scopes are retained.
Compiled artifacts are excluded.

Full make check exits 0 with 1000 catalogue profiles; validation.md links the
complete acceptance transcript.
M5 remains in progress.

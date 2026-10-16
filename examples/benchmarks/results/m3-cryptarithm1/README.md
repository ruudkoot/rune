# Exhaustive cryptarithm permutations

Recorded 2026-10-16. Two imports bring the catalogue to 254 programs and
756 profiles. [All 56 requested cases](coverage.tsv) are accounted for:
[55 pass](correctness.tsv), while the strict normal case on SML/NJ 110.99.9
legacy64 reaches its 1,200-second limit without a result. Its full-size normal
validation remains incomplete. Native32 and SML/NJ 2026.2 pass that profile;
every Rune engine passes both profiles at both levels. No incorrect output is
accepted. Eight semantic checks pass all ten configurations at both requested
levels, and a separate predicate counter verifies all 3,628,800 candidates on
Rune and MLton.

The port preserves insertion order, every permutation test, the original
equation and all FAST/NORM/SLOW repetition values. Both variants use one functor.
Need streams through a memoized filter; Strict materializes intermediate lists.
A private cursor prevents the filter thunk from retaining its skipped prefix.
The previous translation is retained and its source keys match the original
bounded attempts. Full four-element order fixtures, all 720 six-element
permutations, shared demand and deliberate output perturbations are checked.

The fixed ten-digit problem makes one full search the smallest nonempty input.
Final maximum budgets are 16 GiB for both variants, Need smoke/normal 120/600
seconds, and Strict smoke/normal 600/1,200 seconds. Original successes at tighter
bounds and fresh retries are distinguished in [validation-limits.tsv](validation-limits.tsv).
The [attempts](correctness-attempts.tsv) retain earlier memory limits/timeouts;
the [resource probes](resource-probes.tsv) record the translation and budget
calibration. Inputs, source and expected values were preserved while budgets
were calibrated. Large SML execution is claimed only where recorded.

[Eight complete normal count samples](count-samples.tsv) pass a single combined
SML comparison. Source identities agree across the contributing runs. Allocation
counts and applicable instruction counts agree; budgets remain unchanged and
the new entries are explicitly unbudgeted. Raw phases, identities, options,
inputs and machine metadata are retained under count-attempts/.

An initial count run was stopped after shell commands stalled. Its two completed
count samples remain valid and its incomplete register sample is excluded.
Read-only host diagnostics are retained without assigning a cause to the stall.
The missing samples were collected serially with an additional process-tree RSS
and available-host-memory guard. A controlled negative probe verifies termination.
Accepted guarded runs did not trigger it; the strict run needed the recorded
12 GiB RSS ceiling after an 8 GiB guard interrupted its predecessor. These are
instrumented diagnostics, not headline timings. No stopped attempt is presented
as a successful sample or benchmark timeout.

Original bounded GHC runs, an independent exhaustive assignment search and all
three pinned stdout fixtures agree. Original sources, complete correspondence,
input origins and individual notice status remain recorded. Historical speed
claims are not transferred. M3 remains in progress.

# Happy host observations, 2026-10-18

Final evidence records 78 of 80 tagged profile passes: all 40 normal runs
and 38 of 40 smoke runs. The two lazy ML Kit smoke compiles have empty logs
and remain unclassified. The same host passes normal and complete semantics.
All 2514 semantic assertions pass in each of 20 configuration/level groups
(50280 total). See the [raw matrix](../results/m3-happy/correctness.tsv).
Native requested levels repeat host-default compiler options.

The [small arithmetic reproducer](happy-smlnj32-arithmetic.sml) reads the
divisor from stdin (10), obtains the digit from Int.fromString, and tests
subtraction, a combined quotient, a let-bound quotient and a constant
expression. The six-host observation is:

| Host | Subtraction | Combined / separate quotient | Constant quotient |
|---|---:|---:|---:|
| MLton 20241230 | 1073741822 | 107374182 | 107374182 |
| SML/NJ 110.99.9, 64-bit | 1073741822 | 107374182 | 107374182 |
| SML/NJ 110.99.9, 32-bit | Overflow | Overflow | 107374182 |
| SML/NJ 2026.2 | 1073741822 | 107374182 | 107374182 |
| Poly/ML 5.9.2 | 1073741822 | 107374182 | 107374182 |
| ML Kit 4.7.23 | 1073741822 | 107374182 | 107374182 |

The larger Happy-based probe prints Int.maxInt = 1073741823 on SML/NJ32.
Both mathematical results fit that host's int range. This is a reproduced
host arithmetic failure; no upstream issue number is asserted without a
matching verified report. No compiler/runtime workaround is added.

The literal translation helper uses exact quotient/remainder limits for
bases 10/16/8. Six new boundary cases accept 1073741823 and reject the next
integer in each spelling, alongside all 555 semantic-action fixtures.
The selected grammar and generated parser remain unchanged.

An empty ML Kit compiler log is recorded as an unclassified compile error;
it does not establish a memory failure. A compile timeout remains a
separate category. Preliminary and final source epochs remain distinct.


Inspection of tests/basis/run-matrix.sh identifies a reporting limitation:
the ML Kit/MLton native compile failure branches return before assigning
load_status. Their reported exit 0 is the initialized runner value, not
evidence that the compiler itself returned zero. The empty-log failures
therefore remain unclassified compile failures. Later successful normal
compiles establish that the workload builds on that host. Capturing native
compile status and testing native compile-timeout classification is an M8
tooling follow-up; the existing raw records are retained unchanged.

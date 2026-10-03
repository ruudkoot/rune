# Sandmark sequential recursion

Recorded 2026-10-03. Five ports add even/odd, Fibonacci, Motzkin, Sudan and
Takeuchi sequential controls. Together with Ackermann, the six sequential
recursive controls have runnable ports. Effect-based siblings remain deferred
with their required runtime capability. M5 remains in progress for other
sequential workloads; no collection closure is claimed.

[The ledger](correctness.tsv) records 144 successful configuration/profile runs:
120 for the five new programs and 24 for the unchanged classic Fibonacci
recurrence extracted into a shared source. All four Rune engines pass both
optimization levels, and all four primary managed native hosts pass. Complete
stdout/logs and available compilation identities are retained.

Fibonacci and Takeuchi share existing kernels while retaining Sandmark's names,
source notices, argument order and input/repetition profiles. Independent
iterative Fibonacci and memoized Takeuchi establish their values; the benchmark
recurrences remain unmemoized. Motzkin fixtures use binomial/Catalan counts.
Sudan fixtures use an independently derived order-one identity and iterative
order-two substitution. OCaml originals agree with smoke/normal individual
values; recorded Motzkin, Fibonacci and Takeuchi large original results also
agree. No universal large SML execution is claimed.

The Sudan result exceeds 31 bits. Portable IntInf preserves all selected values
within the original OCaml 63-bit range while changing representation/allocation;
the port documents this difference. All drivers consume every repetition rather
than discarding the original accumulator and printing only the last value.
Pure operand evaluation follows SML order; this translation decision is recorded.

Separate count archives retain complete samples and compiler/configuration,
source/input and tool identities. Applicable instruction comparisons and all
four engines' allocation counts agree. Instrumented times are not headline
performance comparisons. Compiled payloads and disposable work directories
are excluded.

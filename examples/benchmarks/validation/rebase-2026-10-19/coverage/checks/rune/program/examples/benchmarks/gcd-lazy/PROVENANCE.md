# gcd-lazy provenance

nofib `b7391df4540ac8b11b35e1b2e2c15819b5171798`, `spectral/gcd/Main.hs`. Sergey Mechveliani contributed
this Integer-performance test. The retained header explains replacing a sum
with a maximum to avoid distorted large numbers. The individual licence is
unspecified; source, Makefile and fixtures retain their notices and SHA256 IDs.

Preserve the inclusive grid 5000..5000+d by 10000..10000+d, extended-Euclidean
quotRem recurrence, arbitrary-precision Integer arithmetic, coefficient update
order and maximum abs(g+u+v). IntInf is used throughout; this is not a machine
integer benchmark. The lazy variant shares finite input streams, memoizes
coefficient expressions and demands pairs/triples/results through explicit
streams. The strict variant uses eager coefficient triples and materializes
ordinary pair/triple/result lists. The selected mathematical work and maximum
agree; evaluation, intermediate retention and allocation differ materially.

Every computed result is consumed and checked: g is positive, divides both
inputs, and equals u*x+v*y. Together these identities independently establish
the greatest common divisor. The additional checks are part of the SML workload.
Original GHC maxima agree with a separate Python reference also checked by
math.gcd. Profiles select d=2/100/400; large preserves original FAST, while
original normal1200 and slow2700 remain recorded. Large SML execution is not
universally claimed. Output is the actual reviewed maximum; no success constant
or floating-point approximation replaces the kernel.

References: original Mechveliani explanation and nofib survey. Big-integer
costs, coefficient demand/sharing, lazy traversal and retained intermediate
lists are source-derived diagnostic questions until measured. No compiler or
runtime features are prerequisites of this port.

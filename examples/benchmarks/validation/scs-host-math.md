# SCS host arithmetic observations

Recorded 2026-10-16 using the managed native hosts. SCS keeps default runtime
settings and reviewed numerical/reference results. Auxiliary support probes and
actual application correctness are recorded separately.

## SML/NJ: subnormal scaling

110.99.9 on both 64-bit and 32-bit builds, and 2026.2 on 64-bit, return zero from
`Real.fromManExp {man=1.0,exp= ~1074}`. The expected value is the minimum positive
binary64 subnormal. Three auxiliary rational-conversion boundary cases fail on
each host. These values lie outside the SCS profile's normal/zero conversion
domain; workload validations still apply independently.

This reproduces the repository's [existing report](../../../docs/bugreport/smlnj/Real.fromManExp/subnormal-is-zero/BUGREPORT.md)
and [legacy issue 254](https://github.com/smlnj/legacy/issues/254). The upstream
issue is closed in the recorded API snapshot. That status does not establish
behavior of a different compiler build or current upstream source.

## Poly/ML: nearest conversion changes integers

Poly/ML 5.9.2 changes exactly integral reals under
`Real.toLargeInt IEEEReal.TO_NEAREST`. For 4503599627370497.0 it returns
4503599627370498, while TO_ZERO returns 4503599627370497. Six explicit integral
nearest probes fail, covering positive/negative odd significands at or above 2^52.
Rune and the other managed hosts pass these probes.

The initial bit encoder used nearest mode on an integral significand and thereby
misclassified four correct Poly/ML rational conversions. The encoder now uses
exact truncation; separate nearest-mode regressions preserve the native defect.
The kernel has no call to Real.toLargeInt. [Local minimal report/reproducer](../../../docs/bugreport/polyml/Real.toLargeInt/nearest-integral/BUGREPORT.md)
and the raw observational probes distinguish the oracle defect from the program.
No upstream issue was submitted through this roadmap task.

## Legacy 64-bit: intermittent numerical failures

A repeated seven-case workload probe produced four failures in 56 checks under
default allocation, including changed values and a shorter event trace. A
separate replay of the same program with `@SMLalloc=64m` passed all 56 checks.
The full default-setting native adapter also rejected one incorrect scs-lazy
smoke result before accepting a timing. The other native diagnostics remain
recorded with their source/runtime identities.

The pattern is consistent with the [existing 64-bit real/GC report](../../../docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/BUGREPORT.md).
It is not a reduction proving that cause for this application. Nursery settings
are diagnostic configurations, with no change to suite defaults or expectations.
Incorrect results have no accepted timing sample.

The [Basis REAL specification](https://smlfamily.github.io/Basis/real.html)
defines power-of-radix reconstruction and conversion under the requested rounding
mode. Exact representable integers require no rounding, and representable
subnormals are nonzero values. Original/independent reference results and all
observed passes/failures remain in the SCS result archive.

Separate 64 MiB nursery runs also validate the three failed canonical profile
cases (lazy smoke/normal and strict normal). Their default-setting incorrect
results remain unchanged in coverage.tsv.

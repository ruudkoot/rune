# Word64 host diagnostic

Recorded 2026-10-02 using the `make hosts` SML/NJ 110.99.9 builds on Linux.
The reproduction is [word64-host.sml](word64-host.sml), with no Rune library.
Its stdout on 32 bits prints the mask as `3FFFFFFF / 1073741823`; on 64
bits it prints `7FFFFFFF / 2147483647`. A constant multiplication prints
`AA020DE9FA / 730178906618` versus `AA420DE9FA / 731252648442`.
Constant folding and precompiled library defects must be distinguished from
runtime arithmetic; these probes alone do not isolate every generator error.
The [existing report](../../../docs/bugreport/smlnj/Word64-low-half/BUGREPORT.md)
explains the low-half and boot-file defect. A direct six-word seeded MINSTD
comparison against compiled expected literals diverges from the third draw
on 32 bits. Earlier agreement is weak evidence because expected literals
are also miscompiled; the 64-bit host matches all six. The expected words are
`E74766 599FCB4E 69905C98 7BA3F469 781358C9 4802E529`.

Smoke/normal TSP, AOBench and Monte Carlo ray results are therefore rejected
on this host. Id-ray also fails its normal numerical checker with a cause
still unisolated. The regular four-system comparisons use SML/NJ 64 bits.
No benchmark workaround, compiler fix or changed RNG distribution is included.
The initial sandboxed 32-bit attempts exited with SIGSYS (159); unsandboxed
reruns supplied the actual correctness results described here.

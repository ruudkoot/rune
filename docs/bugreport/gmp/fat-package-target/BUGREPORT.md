# A fat GMP package also needs a generic host target

The first native package used `--enable-fat` while allowing GMP's
`config.guess` to identify the build machine as `haswell-pc-linux-gnu`.
This was a packaging configuration error. Fat assembly dispatch did not
remove processor-specific inline helpers selected in `longlong.h` by
`HAVE_HOST_CPU_haswell`.

Under QEMU 8.2.2's `qemu64` CPU model, Rune's GMP path printed `~2147483648`
for `IntInf.<< (IntInf.fromInt (~9), 0w31)`; the correct answer is
`~19327352832`. Forced SML and QEMU's `max` model gave the correct answer.
A standalone `mpz_mul_2exp`/`gmp_printf` reproducer encountered an illegal
MULX instruction in `mpz_get_str`. The recorded instruction trace also shows
the processor-specific leading-zero instruction: older CPUs interpret its
encoding as a different operation. Neither behavior belongs in a generic
x86-64 package. This does not establish a bug in Rune's mpz binding.

The recipe now passes a generic compiler target for native fat builds and
an explicit build-machine triple. Cross x86 packages already named generic
targets. The source pin remains GMP 6.3.0; no upstream source patch is applied.
The final regression is [cpu-family.py](../../../../tests/intinf/cpu-family.py),
which runs the independent corpus on baseline, Conroe, Opteron G1 and maximum
CPU models across the interpreter and both JIT tiers. Final pass evidence is
recorded with M5 acceptance; the failed observations remain in
[evidence.json](evidence.json).

This follows both parts of GMP's
[package-build guidance](https://gmplib.org/manual/Notes-for-Package-Builds):
choose an appropriate minimum target and use fat selection for x86 packages.
No report has been sent externally.

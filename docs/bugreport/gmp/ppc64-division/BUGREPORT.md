# PowerPC64 division mismatch in the pinned GMP build

Observed during Rune M5 on 2026-10-12: GMP 6.3.0, clang 18.1.3,
big-endian `powerpc64-linux-gnu`, ABI `mode64`, `-O2`, under qemu-ppc64.
The exact compiler/emulator identities and transcript hashes are retained in
[evidence.json](evidence.json). This is a local report; nothing has been sent
upstream. The cause has not been attributed to GMP, clang or the emulator.

The optimized build fails upstream `tests/mpn/t-div` at test -299:
`mpn_div_qr_1` returns a quotient too small. The original numerator was
73,915 bits. Removing limbs against Python's integer arithmetic reduces it
to `n = 2^256 - 1`, `d = 2^63 + 3`, in 181 probes.

The correct quotient is `2^193 - 3*2^130 + 9*2^67 - 432`, with remainder
1295. Multiplication by the divisor and addition of that remainder gives
`2^256 - 1`; the remainder is smaller than the divisor. The optimized
internal kernel instead returns a quotient smaller by `2^64`, with the same
remainder. The public `mpz_fdiv_qr` path passes this particular case, so this
report does not claim that Rune's public binding returned the wrong answer.

The self-contained reproducer is
[tests/intinf/gmp-division.c](../../../../tests/intinf/gmp-division.c).
It checks the public operation and, on 64-bit limbs, the failing internal
kernel. That internal call is restricted to the pinned 6.3.0 dependency test;
Rune's runtime uses only documented `mpz` calls. Compile it with the tested
prefix's include directory and static `libgmp.a`, using the PowerPC compiler
and sysroot flags in the Makefile, then run with
`qemu-ppc64 -L /usr/powerpc64-linux-gnu`.

Rebuilding the same pinned source with `--disable-assembly` passes this
reproducer and the entire upstream suite. Rune's PowerPC package therefore
uses that configuration. The failing optimized build was never installed;
its source, build and logs remain in the recorded build directory. No
extra upstream test filters were added to accept the replacement; ordinary
feature-dependent skips remain in the suite reports. The default can be
revisited only with a passing configuration and retained regression evidence.

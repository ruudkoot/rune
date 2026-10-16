# Fat x86-64 GMP still compiles Haswell `lzcnt` and `mulx` into C

GMP 6.3.0 with `--enable-fat`, configured on a machine `config.guess`
reports as `haswell`, compiles `longlong.h` helpers that use `lzcnt` and
`mulx`. Fat dispatch covers the mpn assembly files. It does not cover those
helpers. On a CPU without LZCNT, `rep; bsr` executes as `bsr` and
`mpz_sizeinbase` in base 2 is silently short. On a CPU without BMI2,
`mulx` raises SIGILL. QEMU's `qemu64` model does both, and its `max` model
does neither. The limb GMP computed for the original shift is the right
limb on both.

Nothing in this directory has been sent upstream. The pinned source is
still GMP 6.3.0, unmodified. Rune's package no longer configures that
build: a fat build with no explicit `--host` now passes the compiler's
generic triple. The original observations are in
[evidence.json](evidence.json).

## The issue

`configure` defines `HAVE_HOST_CPU_<config.guess CPU>` unconditionally
(`configure.ac`, `AC_DEFINE_UNQUOTED(HAVE_HOST_CPU_$tmp_host)`). On this
machine that macro is `HAVE_HOST_CPU_haswell`. It also defines
`X86_ASM_MULX` when the assembler accepts `mulx`. `--enable-fat` clears
the `-march` / `-mcpu` flags and selects mpn routines at run time. The
`longlong.h` x86-64 block then still does two things:

* `count_leading_zeros` is `rep; bsr`. GMP's comment says this is `lzcnt`,
  spelled for older assemblers. The same encoding is `bsr` on a CPU
  without LZCNT. `bsr` writes the index of the top set bit. `lzcnt` writes
  the number of leading zeros.
* `umul_ppmm` is `mulx` when `X86_ASM_MULX` is also set and the model is
  haswell, broadwell, skylake, bd4 or zen. `mulx` is a `#UD` without BMI2.

`mpz_sizeinbase(z, 2)` is `GMP_LIMB_BITS * limbs - count_leading_zeros(top)`.
For the magnitude of `-(9 << 31)`, that top limb is `0x480000000`. Its
leading-zero count is 29, so the width is 35 bits and the little-endian
export is 5 bytes. `bsr` of the same limb is 34. Used as a leading-zero
count, the width becomes 30 and the export length becomes 4. The low 4
bytes are `00 00 00 80`, which is 2147483648. The sign is untouched, so
the printed value is `~2147483648`. The correct value is `~19327352832`.

Rune's current `export` allocates `(bits + 7) / 8` bytes from that width
and then requires `mpz_export` to have written the same count
(`runtime/intinf.c`). `mpz_export` is given no buffer length. A short
`sizeinbase` makes it write one byte past the string, and the mismatch
check runs after that write. The 2026-10-13 probe printed the truncated
value and exited 0; that probe predates this check.

The same library's `mpz_mul_2exp(-9, 31)` produces limb `0x480000000` on
the host and under `qemu-x86_64 -cpu qemu64`. `mpz_sizeinbase` then returns
35 on the host and 30 under `qemu64`. Calling `mpz_get_str` on that
library raises SIGILL inside `mulx` before it can print.

## Reported or fixed upstream

Reported, and not fixed.

[gmp-bugs 005562](https://gmplib.org/list-archives/gmp-bugs/2025-February/005562.html)
(February 2025, Emmanuel Lonca, messages 005562–005567) is a fat GMP 6.3.0
built on a BMI2 machine and run without BMI2. It dies with SIGILL in
`__gmpz_sizeinbase`, on `mulx`. Marc Glisse traced it to `HAVE_HOST_CPU_*`
plus the `longlong.h` guard. Torbjörn Granlund's statement of the fat
contract is that the binary runs on any 64-bit x86. Niels Möller suggested
leaving `X86_ASM_MULX` undefined for a fat build. Marc's objection was that
the macro describes the assembler, and that the model macros should be
left undefined instead. No change landed.

The development `configure.ac` and `longlong.h` fetched on 2026-10-16 still
define `HAVE_HOST_CPU_$tmp_host` unconditionally, still define
`X86_ASM_MULX` from the assembler test, and still contain the `rep; bsr`
and `mulx` guards. A fix that only stops emitting `mulx` leaves the silent
`sizeinbase` result. The model macro has to go as well: `count_leading_zeros`
is gated on `HAVE_HOST_CPU_haswell` and the rest of that list, not on
`X86_ASM_MULX`.

GMP's
[Notes for Package Builds](https://gmplib.org/manual/Notes-for-Package-Builds)
already says to choose the least common CPU as `--host` and, separately,
that `--enable-fat` is appropriate for an x86 package. Doing only the
second half, and letting `config.guess` answer `haswell`, is what selects
the helpers. Rune's first native recipe did that.

## How it was found

During M5 acceptance on 2026-10-13, the native fat package was run under
QEMU 8.2.2. `IntInf.<< (IntInf.fromInt (~9), 0w31)` printed `~2147483648`
with `--intinf=gmp` on `-cpu qemu64`, and `~19327352832` with `--intinf=sml`
and on `-cpu max`. The twelfth value of
`tests/out/intinf/m5/cpu-probe/operations.rbc` is that shift. The record is
[evidence.json](evidence.json).

On 2026-10-16 the same GMP 6.3.0 tarball
(`a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898`) was
configured with only `--enable-fat` on this machine. `config.log` has
`host_cpu='haswell'`. The generated `config.h` has
`#define HAVE_HOST_CPU_haswell 1` and `#define X86_ASM_MULX 1`. The C flags
are `-O2 -pedantic -fomit-frame-pointer -m64`, with no `-march=haswell`.
[repro.c](repro.c) copies the two inline helpers and needs no libgmp. The
library program below, compiled with `gcc -O2 -march=x86-64` and linked to
that static library, separates the limb from the width.

## Reproducer

[repro.c](repro.c). No libgmp.

```
cc -O2 -o repro repro.c
./repro
qemu-x86_64 -cpu qemu64 ./repro
qemu-x86_64 -cpu max ./repro
```

On the build machine, and under `-cpu max`:

```
rep;bsr -> 29 (generic bsr^63 -> 29)
sizeinbase bits 35, export bytes 5, value 19327352832
mulx: 3*5 -> hi 0 lo 15
```

Under `-cpu qemu64` the process exits 1:

```
rep;bsr -> 34 (generic bsr^63 -> 29)
sizeinbase bits 30, export bytes 4, value 2147483648
mulx: SIGILL
```

The library confirmation, against a default `--enable-fat` build on
Haswell:

```c
#include <gmp.h>
#include <stdio.h>
int main(void) {
    mpz_t x, z;
    mpz_init_set_si(x, -9);
    mpz_init(z);
    mpz_mul_2exp(z, x, 31);
    printf("limb0 0x%llx size %zu\n",
           (unsigned long long)mpz_getlimbn(z, 0), mpz_sizeinbase(z, 2));
    return mpz_getlimbn(z, 0) != 0x480000000ull || mpz_sizeinbase(z, 2) != 35;
}
```

```
gcc -O2 -march=x86-64 -I<gmp-build> library.c <gmp-build>/.libs/libgmp.a -o library
qemu-x86_64 -cpu qemu64 ./library
```

Under `-cpu qemu64` that prints `limb0 0x480000000 size 30` and exits 1.
On the host the same binary prints `size 35` and exits 0. Do not call
`mpz_get_str` here: that function contains `mulx` and dies with SIGILL
before the widths can be compared.

## Fix

Two changes. The package change is in Rune and is what the VM uses. The
`configure.ac` change is for GMP. It is not applied to the pin.

Rune, already in [scripts/build-gmp.py](../../../../scripts/build-gmp.py):
a fat build with no `--host` passes `--host` from `cc -dumpmachine`. Here
that is `x86_64-linux-gnu`, so `HAVE_HOST_CPU_haswell` is never defined.
[tests/intinf/cpu-family.py](../../../../tests/intinf/cpu-family.py) runs
the independent corpus on the baseline, Conroe, Opteron G1 and maximum CPU
models, on the interpreter and both JIT tiers.

GMP: [fix.diff](fix.diff) skips `HAVE_HOST_CPU_$tmp_host` when `--enable-fat`
is combined with an x86 or x86-64 host. `X86_ASM_MULX` stays defined, which
matches the February 2025 objection that it describes the assembler. The
inline `mulx` and `rep; bsr` both also require the model macro, so they
fall through to `mulq` and to `bsr` followed by `xor 63`.

The same condition, applied to the generated `configure` of the 6.3.0
tarball and re-run on this machine with `--enable-fat`, still records
`host_cpu='haswell'` and still defines `X86_ASM_MULX` and
`HAVE_HOST_CPU_FAMILY_x86_64`. It leaves `HAVE_HOST_CPU_haswell` undefined.
The library itself was not rebuilt from that `config.h`; the helpers are
selected entirely by the macro.

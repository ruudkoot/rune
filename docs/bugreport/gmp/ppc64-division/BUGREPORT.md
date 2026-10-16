# Clang 18 miscompiles GMP's PowerPC64 single-limb division

GMP 6.3.0, compiled with Clang 18.1.3 for big-endian `powerpc64-linux-gnu`
at `-O1` or `-O2`, returns a wrong quotient from `mpn_div_qr_1` /
`mpn_div_qr_1n_pi1`. The PowerPC `addc` / `adde` / `subfe` helpers in
`longlong.h` and `mpn/generic/div_qr_1n_pi1.c` write `XER[CA]` and name only
`"cc"` as a clobber. `"cc"` is the condition register. Clang keeps a
`subc` / `subfe` pair live across that asm, so `subfe` consumes the carry
the asm just wrote. Adding `"xer"` to the clobber makes this input match
the true quotient. QEMU's own `addc`, `adde` and `mulhdu` produce the right
results when they are not split around the asm. `mpz_fdiv_qr` does not call
this kernel and passes the same input.

Nothing in this directory has been sent upstream. The pinned source is
still GMP 6.3.0, unmodified. Rune's PowerPC package builds with
`--disable-assembly` (`GMP_PPC64_FLAGS` in the Makefile). That build passes
GMP's suite and this case. The optimized library was never installed.
The original transcript hashes are in [evidence.json](evidence.json).

## The issue

Upstream `tests/mpn/t-div`, test -299, calls `mpn_div_qr_1`. The failure
minimizes to a 4-limb numerator and a one-limb divisor:

* `n = 2^256 - 1`
* `d = 2^63 + 3`
* true quotient `2^193 - 3*2^130 + 9*2^67 - 432`, which is
  `0x1fffffffffffffff40000000000000047fffffffffffffe50`
* remainder `1295` (`0x50f`)

`q*d + r = n` and `r < d`. The optimized kernel returns that quotient minus
`2^64` (the limb that should be `0x47` is `0x46`) and the same remainder.
The pair is not a division of `n`.

`mpn_div_qr_1` peels the top limb and calls `mpn_div_qr_1n_pi1`. The
default `DIV_QR_1N_METHOD` is 2. For this normalized divisor the inverse
comes from `mpn_invert_limb` (`0xfffffffffffffff4` for this `d`) and the
rest is C: `umul_ppmm`, `add_ssaaaa`, `add_mssaaaa`, and
`udiv_qrnnd_preinv`. Clang 18 defines `__GNUC__` as 4.2, so the PowerPC
`umul_ppmm` is the `mulhdu` asm rather than the GCC `>= 4.8` 128-bit
multiply. Those `mulhdu` results were checked on their own, including
`(2^63+3)*(2^64-1)`, and they match.

Replacing only `mpn/div_qr_1n_pi1.o` in the optimized archive changes the
answer. The rest of the assembly kernels, including `invert_limb.asm`, stay
in the passing and the failing libraries.

| Build of `div_qr_1n_pi1.c` only | This input |
|---|---|
| `-O2`, stock `"cc"` clobber | quotient limb `0x46` |
| `-O1` | `0x46` |
| `-O0` | `0x47` |
| `-O2 -DNO_ASM` | `0x47` |
| `-O2 -DDIV_QR_1N_METHOD=1` | `0x47` |
| `-O2 -DDIV_QR_1N_METHOD=3` | `0x47` |
| `-O2` with `__CLOBBER_CC` defined as `: "cc", "xer"` | `0x47` |

Method 3 also calls `add_mssaaaa`, and method 1 calls `add_ssaaaa` through
`udiv_qrnnd_preinv`. The bad schedule is method 2's C together with the
missing clobber, at `-O1` and `-O2`.

The `-O2` assembly of the stock file splits a compiler `subc` / `subfe`
around the inline add:

```
subc 3, 3, 7
#APP
addc 10, 8, 0
adde 4, 5, 4
#NO_APP
subfe 3, 7, 7
```

`subfe 3, 7, 7` is `r3 = ~r7 + r7 + CA`, so the mask it produces is the
carry the `addc` just stored. With the `"xer"` clobber those two
instructions stay adjacent, and the `addc` / `adde` come afterwards.

There is no `powerpc64-linux-gnu-gcc` on this machine. GCC has, since the
2014 rs6000 carry rewrite, treated every asm as clobbering `XER[CA]` so
that older code which forgot to say so would keep working. Clang does not.
Clang 18 rejects the GCC register name `"ca"` (`unknown register name
'ca'`) and accepts `"xer"`.

## Reported or fixed upstream

Not reported to GMP from here, and not fixed in GMP.

The same function was reported in
[gmp-bugs 004691](https://gmplib.org/list-archives/gmp-bugs/2019-November/004691.html)
(November 2019). Clang had scheduled a `subfe` across an inline `addc` that
did not name the carry. The proposed fix was to append `: "cc"`. GMP's
`__CLOBBER_CC` is that string. On PowerPC it names the condition register,
which is not `XER[CA]`.

Libgcrypt's copy of `longlong.h` grew the same bug. The patch of 13 May
2026 adds `"xer"` on the PowerPC add and subtract helpers, with the
explanation that GCC's `"cc"` clobber covers `XER` and Clang's does not:
[gcrypt-devel 006101](https://lists.gnupg.org/pipermail/gcrypt-devel/2026-May/006101.html).
That patch is Libgcrypt's, not GMP's.

GMP 6.3.0 and the development `longlong.h` fetched on 2026-10-16 still
define `__CLOBBER_CC` as `: "cc"`. The PowerPC `add_ssaaaa`, `sub_ddmmss`
and `add_mssaaaa` use it unchanged.

## How it was found

During M5 on 2026-10-12 the optimized PowerPC dependency failed
`tests/mpn/t-div` at test -299. The numerator in that test was 73,915 bits.
Dropping limbs while checking the division in Python reached
`2^256 - 1` over `2^63 + 3` in 181 probes.
[tests/intinf/gmp-division.c](../../../../tests/intinf/gmp-division.c)
recorded the public `mpz_fdiv_qr` path as a pass and the internal kernel as
a failure. `--disable-assembly` passed that program and the upstream suite.
Compiler and emulator identities are in [evidence.json](evidence.json):
Ubuntu Clang 18.1.3, `qemu-ppc64` 8.2.2, ABI `mode64`, `-O2`.

On 2026-10-16 the same tarball was configured with
`--host=powerpc64-linux-gnu` and the Makefile's Clang sysroot flags, with
assembly left on. The object-for-object swap, the `-O0` / `-DNO_ASM` /
method switches, and the `"xer"` rebuild were all of
`mpn/div_qr_1n_pi1.c` inside that library. Isolated `addc` / `adde` (carry
out of bit 31 and bit 63) and both the 128-bit and `mulhdu` multiplies
passed under the same `qemu-ppc64`. A smaller function that only did
`addc` / `adde` between two C arithmetic operations did not get the bad
schedule; [repro.c](repro.c) is the reduction that does.

## Reproducer

[repro.c](repro.c) is the method-2 kernel and its PowerPC helpers, with no
libgmp. Clang's schedule of this reduction corrupts the same limb by one
in the other direction (`0x48` rather than GMP's `0x46`). `-DXER` and
`-O0` produce `0x47`. The exact `t-div` residue is the stock GMP object,
linked with [tests/intinf/gmp-division.c](../../../../tests/intinf/gmp-division.c).

```
clang -O2 --target=powerpc64-linux-gnu \
  -B/usr/powerpc64-linux-gnu/bin \
  -L/usr/powerpc64-linux-gnu/lib -I/usr/powerpc64-linux-gnu/include \
  -Wl,-dynamic-linker,/usr/powerpc64-linux-gnu/lib/ld64.so.1 \
  repro.c -o repro
qemu-ppc64 -L /usr/powerpc64-linux-gnu ./repro
```

`-O2` and `-O1` print this and exit 1:

```
r=0x50f qp=1 fffffffffffffff4 48 fffffffffffffe50
FAIL
```

`-O0`, and the same `-O2` command with `-DXER`, print `47` in that limb
and `pass`.

The stock GMP object, called as `mpn_div_qr_1` does (top limb peeled, so
`mpn_div_qr_1n_pi1` sees three limbs and `u1 = ~0 - d`), prints:

```
r=0x50f qp=1 fffffffffffffff4 46 fffffffffffffe50
```

The same call after recompiling that one file with the `"xer"` clobber
prints `47`. `mpz_fdiv_qr` on `2^256-1` and `2^63+3` prints the `0x47`
quotient in both libraries.

## Fix

Rune's package fix is the one in the tree: `GMP_PPC64_FLAGS ?= --disable-assembly`.
It is a workaround. The optimized sources are a faithful Clang `-O2` of
GMP, and they fail GMP's own test.

The GMP change is [fix.diff](fix.diff). Under Clang, on PowerPC, it
redefines `__CLOBBER_CC` to `: "cc", "xer"`. That macro is what the
PowerPC `add_ssaaaa`, `sub_ddmmss` and `add_mssaaaa` expand. GCC is left
alone: it already clobbers `XER[CA]` on every asm, and this tree has no
PowerPC GCC with which to try the `"ca"` name.

What was run with that clobber is the one translation unit and `repro.c`.
Both then return the true quotient and remainder for this input. The rest
of `make check` was not re-run on the patched header. Other PowerPC inline
asm that writes `XER[CA]` and lists only `"cc"` has the same shape; the
diff covers every use of `__CLOBBER_CC` in a Clang PowerPC compile of this
header, which includes those helpers.

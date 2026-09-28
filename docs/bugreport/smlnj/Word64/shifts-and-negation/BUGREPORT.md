# SML/NJ 110.99.9 for 32 bits: `Word64` shifts by 0, `~>>`, and `Word64.~` of 2^63 are wrong

## Status: not reported as such; the cause of open #373

* **Not in the trackers:** smlnj/legacy and smlnj/smlnj have no issue on
  these shifts or on `Word64.~` (searched 2026-09-28).
* **The cause of [smlnj/legacy#373](https://github.com/smlnj/legacy/issues/373)**
  (open, 2025-11-19, 32-bit): `Real.fromString` reads some decimal
  strings 1 ulp too high, e.g. `"4194303"`. `Real.fromString` shifts
  `Word64` values by amounts that can be 0 (below).
  - On a native fixed point of 110.99.9 (Linux), #373's examples still fail:
    all 18 reals it lists, and 1,799 of 20,000 random reals, do not round-trip
    through `Real.fmt StringCvt.EXACT` and `Real.fromString`.
  - With only this report's `fix.diff`, built the same way, every one of them
    round-trips.
  - The issue's last comment says the problem "seems to go away" with a
    fixed point on a 32-bit machine. That fixes the literal bug the issue
    also shows ([Word64-low-half](../../Word64-low-half/BUGREPORT.md)), not
    this one.

**What is worth sending SML/NJ:** a comment on #373 with this cause, or a
new issue that names it, with `bug.sml` and `fix.diff`.

## Summary

* **The trigger:** `Word64.<<`, `Word64.>>` or `Word64.~>>` (also those of
  `LargeWord`), and `Word64.~`, in the 32-bit build.
* **What goes wrong:**
  - **A shift by 0** ORs the two halves: `0wx1 << 0w0` is `0wx100000001`,
    and `0wx100000000 >> 0w0` is `0wx100000001`.
  - **`~>>` by 1 to 31** shifts the low half arithmetically, so bit 31 of
    the low half is copied down: `0wx80000000 ~>> 0w1` is
    `0wxC0000000`.
  - **`~>>` by 32 to 63** fills the low half from a logical shift of the
    high half: `0wx8000000000000000 ~>> 0w33` is `0wxFFFFFFFF40000000`, not
    `0wxFFFFFFFFC0000000`.
  - **`~>>` by 64 or more** shifts by 31: `0wx8000000000000000 ~>> 0w64` is
    `0wxFFFFFFFF00000000`, not all ones.
  - **`Word64.~ 0wx8000000000000000`** raises `Overflow`.
* **Required behaviour:** the
  [Basis `WORD` specification](https://smlfamily.github.io/Basis/word.html):
  `<<` and `>>` fill with zeros, `~>>` with the sign bit, and a shift of
  `wordSize` or more gives 0 or all sign bits. `~` is negation modulo 2^64
  and raises nothing.

## Where it happens

`bug.sml` reads its operands from strings, so that nothing is folded:

| Build (110.99.9) | wrong of 8 |
|---|---|
| 32-bit: Linux and Windows releases, Windows source build (MSVC), native fixed point on Linux, cross-compiled on amd64 | 8 |
| 64-bit release, Ubuntu's 110.79 (32-bit) | 0 |
| 32-bit and 64-bit with `fix.diff` | 0 |

```
$ sml bug.sml                           # 110.99.9, 32-bit
0wx1 << 0w0 = 100000001, expected 1: WRONG
0wx100000000 >> 0w0 = 100000001, expected 100000000: WRONG
0wx100000000 ~>> 0w0 = 100000001, expected 100000000: WRONG
0wx80000000 ~>> 0w1 = C0000000, expected 40000000: WRONG
0wx8000000000000000 ~>> 0w33 = FFFFFFFF40000000, expected FFFFFFFFC0000000: WRONG
0wx80000000 ~>> 0w64 = FFFFFFFF, expected 0: WRONG
0wx8000000000000000 ~>> 0w64 = FFFFFFFF00000000, expected FFFFFFFFFFFFFFFF: WRONG
Word64.~ 0wx8000000000000000 = Overflow, expected 8000000000000000: WRONG
```

## The cause

On 32-bit targets `Num64Cnv` (`base/compiler/CPS/opt/num64cnv.sml`) expands
64-bit shifts into 32-bit ones.

* **Shift by 0.** For an amount below 32, `w64LShift` computes the new high
  half as `(hi << amt) | (lo >> (32 - amt))`, and the right shifts
  likewise. For `amt = 0` that shifts by 32. The comment above these
  functions notes that x86 takes shift amounts mod 32, so `lo >> 32` is
  `lo`, not 0.
* **`w64RShift` (`~>>`) against its own comment.** The comment has
  `lo' = (lo >> amt) | …` and, for 32 or more, `hi ~>> (amt - 0w32)`. The
  code has `P.RSHIFT` (arithmetic) for the first and `P.RSHIFTL` (logical)
  for the second, the other way round.
* **`~>>` by 64 or more.** `inlineArithmeticShiftRight`
  (`base/compiler/FLINT/trans/transprim.sml`) replaces an amount of `sz` or
  more by `Tgt.defaultIntSz`, which is 31 on 32-bit targets. That is
  enough for words up to 32 bits, and for 64 bits only on a 64-bit target,
  where it is 63.
* **`Word64.~`.** The dispatch for `PURE_ARITH{oper=NEG, kind=UINT 64}`
  calls `i64Neg`, whose checked `INEG` of the high half raises `Overflow`
  for 2^63. `w64Neg`, a few lines up, is the right expansion and is never
  used.

`Real.fromString` rounds its result in `frep-to-real64.sml` with shifts
whose amounts come from the exponents. One is
`multipleOfPowerOf2 (m10, W.fromInt (e2 - e10))`, which is
`W64.andb (value, W64.lshift (0w1, p) - 0w1) = 0w0`; for `p = 0` the mask
should be 0, and with this bug it is `0wx100000000`. A wrong mask or a wrong
last removed bit changes the rounding, hence #373's one ulp. Which of these
shifts #373's examples go through was not traced; the fix of the shifts
alone makes them right.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9):

* returns the number unchanged for a shift by 0 in `w64LShift`,
  `w64RShiftL` and `w64RShift`;
* uses `RSHIFTL` for the low half and `RSHIFT` for the high half in
  `w64RShift`, as its comment has them;
* shifts by `sz - 1` when `sz > Tgt.defaultIntSz` in
  `inlineArithmeticShiftRight` (for 32-bit words on 32-bit targets and
  64-bit words on 64-bit targets that is what it was);
* dispatches `UINT 64` `NEG` to `w64Neg`.

It also brings the comments up to date.

**How it was tested:**
* with the other fixes of this directory, built to a fixed point for 32
  and 64 bits and cross-compiled for x86-unix and x86-win32;
* `bug.sml` is right on all of them;
* `<<`, `>>` and `~>>` by 0, 1, 29-33, 63 and 64 of 24 `Word64` operands,
  and `+`, `-`, `*`, `div`, `mod`, the bitwise operations, the comparisons
  and `~`, agree with the 64-bit build;
* a native fixed point with this `fix.diff` alone makes #373's examples
  round-trip, and `Real.fromString "1.5e~2"` is 0.015.

## How Rune met it

Not directly: Rune's Basis suite could not load its `Word64` tests on this
build, because the compiler stopped with "Compiler bug: Num64Cnv: test64To"
([Int.fromLarge/fused-conversions](../../Int.fromLarge/fused-conversions/BUGREPORT.md)).
A test of `Word64` against the 64-bit build, written while checking the
other reports, found these. `tests/basis/deviations.txt` line 780
(`Real.fromString/minus-exponent`, "`1.5e~2` is not the real nearest
0.015") is this bug.

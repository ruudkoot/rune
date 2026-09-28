# SML/NJ 110.99.9: fused integer conversions: `Int.fromLarge (Word.toLargeInt w)` does not raise `Overflow`, and for 32 bits, conversions through 64 bits crash the compiler or give garbage

## Status: not reported

The issue trackers of smlnj/legacy and smlnj/smlnj have nothing on it
(searched 2026-09-28 for `test64To`, `Num64Cnv`, `fromLarge`, `toLargeInt`).
The optimizer rule of the first part is the same in smlnj/smlnj at
`a5f3fa7` (`compiler/CPS/opt/contract-prim.sml`), so the 2026 series has it
too (by reading the code; no 2026 build was run).

**What is worth sending SML/NJ:**
* the first part as an issue on smlnj/smlnj and smlnj/legacy, with
  `bug.sml`;
* the second part as an issue on smlnj/legacy, with `bug-64.sml` and
  `bug-32.sml`;
* `fix.diff` for both.

## Summary

The CPS optimizer fuses two integer conversions into one
(`base/compiler/CPS/opt/contract-prim.sml`). Some of its rules are wrong.

**On every build, 32 and 64 bits:** converting a word to a signed integer
through `IntInf`, as the Basis prescribes, keeps a number that does not fit
instead of raising `Overflow`. It is read as a signed number of the word's
width.
* `Int.fromLarge (Word.toLargeInt (Word.notb 0w0))` is `~1`.
* `Int32.fromLarge (Word32.toLargeInt 0wxFFFFFFFF)` is `~1`.
* 64-bit: `Int.fromLarge (Word64.toLargeInt 0wxFFFFFFFFFFFFFFFF)` and
  `Int64.fromLarge (Word64.toLargeInt 0wxFFFFFFFFFFFFFFFF)` are `~1`.
* 32-bit: `Word64.toIntX (Word32.toLarge 0wxFFFFFFFF)` is `~1`.

The same conversion in two steps, where nothing can be fused, raises
`Overflow`. 110.79 has the first two as well.

**On 32-bit builds only:**
* **The compiler stops** with "Error: Compiler bug: Num64Cnv: test64To" on
  `fn w => Int.fromLarge (Word64.toLargeInt w)`, on
  `fn i => Int.fromLarge (Int64.toLarge i)`, and on any program that has
  them. Rune's Basis suite cannot load its `Word8`, `Word32`, `Word64` and
  `LargeWord` tests for this.
* **A fused conversion between 64 bits and 32 or fewer gives garbage:**
  - `Int64.toInt (Int64.fromLarge 5)` is 0.
  - `Word32.fromLarge (Word64.fromLargeInt 0x200000005)` is 2.
  - `Word64.toLargeInt (Word32.toLarge 0wx1)` is `4294967297`: the word
    times 2^32, plus whatever a register held.
  - `Int64.toLarge (Int64.fromLarge (Int32.toLarge ~7))` varies similarly.

**Required behaviour:** the
[Basis `INTEGER`](https://smlfamily.github.io/Basis/integer.html) and
[`WORD`](https://smlfamily.github.io/Basis/word.html) specifications:
`fromLarge` raises `Overflow` when the number does not fit; `toLargeInt` is
the unsigned value; conversions through `LargeInt` and `LargeWord` keep the
value.

## Where it happens

Each program reads its arguments at run time (or applies a function of its
own to them), so that the conversions are fused but not folded:

| Build (110.99.9) | `bug.sml` (2 lines) | `bug-64.sml` (2 lines) | `bug-32.sml` (4 lines) |
|---|---|---|---|
| 32-bit: Linux and Windows releases, Windows source build (MSVC), native fixed point on Linux, cross-compiled on amd64 | 2 wrong | compiler bug | 4 wrong |
| 64-bit release | 2 wrong | 2 wrong | 0 |
| Ubuntu's 110.79 (32-bit) | 2 wrong | 0 | does not compile (no `Word32.toLarge`) |
| 32-bit and 64-bit with `fix.diff` | 0 | 0 | 0 |

```
$ sml bug.sml                           # 110.99.9, 32 or 64 bits
Int.fromLarge (Word.toLargeInt (Word.notb 0w0)) = ~1, expected Overflow: WRONG
Int32.fromLarge (Word32.toLargeInt 0wxFFFFFFFF) = ~1, expected Overflow: WRONG
Int32.fromLarge 4294967295 = Overflow, expected Overflow: ok
$ sml bug-32.sml                        # 110.99.9, 32-bit
Int64.toInt (Int64.fromLarge 5) = 0, expected 5: WRONG
Word32.fromLarge (Word64.fromLargeInt 0x200000005) = 2, expected 5: WRONG
Word64.toLargeInt (Word32.toLarge 0wx1) = 4294967297, expected 1: WRONG
Int64.toLarge (Int64.fromLarge (Int32.toLarge ~7)) = ~30064771065, expected ~7: WRONG
```

`convs.sml` checks every conversion the Basis gives between `int`, `Int32`,
`Int64`, `word`, `Word8`, `Word32` and `Word64` on 31 numbers, against
results computed with `IntInf`:

| Build | wrong |
|---|---|
| 64-bit release | 78 of 3,184 |
| 32-bit builds | none: the compiler stops |
| 32-bit with `fix.diff` and the other fixes of this directory | 0 of 2,989 |
| 64-bit with the same fixes | 19 of 3,184 |
| 32-bit and 64-bit with these and the fix of [Word32.fromLarge/fused-sign-extension](../../Word32.fromLarge/fused-sign-extension/BUGREPORT.md) | 0 |

Of the release's 78, 59 are this bug. The remaining 19 are a different
64-bit bug in the same file:
[Word32.fromLarge/fused-sign-extension](../../Word32.fromLarge/fused-sign-extension/BUGREPORT.md).
`Word32.fromLargeInt (Int32.toLarge ~1)` and
`Word32.fromLarge (Word8.toLargeX 0wxFF)` give a `Word32.word` whose
`toString` is `7FFFFFFFFFFFFFFF`.

## The cause

**Unsigned taken for signed.** `COPY(m, n)` and `COPY_INF m` are zero
extensions. Two rules replace a signed test of such a copy:

```
TEST(∞,p) o COPY(m,∞) ==> COPY(m,p) when (p >= m)
TEST(∞,p) o COPY(m,∞) ==> TEST(m,p) when (p < m)
TEST(n,p) o COPY(m,n) ==> COPY(m,p) if (p >= m)
TEST(n,p) o COPY(m,n) ==> TEST(m,p) if (p < m)
```

An `m`-bit word with its top bit set does not fit `p = m` signed bits, so
`COPY(m, p)` is only right for `p > m`. For `p <= m` the test must be
unsigned: `TESTU(m, p)`, as the `TESTU` rules just above already have it
(`TESTU(n,p) o COPY(m,n) ==> TESTU(m,p) if (p <= m)`).

**32-bit: a `TEST` from 64 bits without its function.** On 32-bit targets a
`TEST` or `TESTU` from 64 bits takes an extra argument, the function of
`Core` that does the work (the comment above the `TESTU` rules says so).
The `TEST_INF` rules make `TEST{from=64, ...}` with one argument, and
`Num64Cnv.test64To` stops at its `bug "test64To"` case. This happens both
for `COPY_INF 64` (`Word64.toLargeInt`) and for `EXTEND_INF 64`
(`Int64.toLarge`).

**32-bit: an `_INF` conversion given the function of another size.**
`TEST_INF`, `TRUNC_INF`, `COPY_INF` and `EXTEND_INF` also take a `Core`
function as an extra argument, chosen by size (`pickName` in
`base/compiler/FLINT/trans/transprim.sml`). On 32-bit targets the function
for 64 bits (`testInf64`, `copy64Inf`, …) works on a pair of 32-bit words,
and the one for 32 bits or fewer on a single word. Four rules change the
size of an `_INF` conversion and keep the old function:

```
TEST(n,p)  o TEST(∞,n)  ==> TEST(∞,p)
TRUNC(n,p) o TRUNC(∞,n) ==> TRUNC(∞,p)
COPY(n,∞)  o COPY(m,n)  ==> COPY(m,∞)
EXTEND(n,∞) o EXTEND(m,n), COPY(m,n) ==> EXTEND(m,∞), COPY(m,∞)
```

With `n = 64` and `p` or `m` at most 32, a 64-bit function is called as a
32-bit one. For example, `Int64.toInt (Int64.fromLarge x)` gets the high
word of `x`, and `Word64.toLargeInt (Word32.toLarge w)` gets `w` as its high
word and a register's contents as its low word.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9)
changes `contract-prim.sml`:

* the two rules of a signed test of a copy fuse into `COPY(m,p)` only when
  `p > m`, and into `TESTU(m,p)` otherwise;
* on 32-bit targets the `TEST_INF` rules leave a conversion from 64 bits
  alone, since the result would need the extra argument;
* a new `sameInfFn (n, m)` (always true on 64-bit targets; on 32-bit
  targets, true when both sizes are above 32 or both at most 32) guards the
  four rules that change the size of an `_INF` conversion.

**How it was tested:**
* with the other fixes of this directory, built to a fixed point for 32
  and 64 bits and cross-compiled for x86-unix and x86-win32;
* the three programs are right on all of them;
* `convs.sml` as in the table above;
* Rune's Basis suite now loads the `Word8`, `Word32`, `Word64` and
  `LargeWord` tests on the 32-bit build (10,433 more checks) with no
  unexplained failure ([README](../../README.md)).

## How Rune met it

`tests/basis/deviations.txt` records the compiler bug as the `@load` lines
774-777 (`intn_word32`, `intn_word64`, `word_large`, `word8`), which kept
Rune's word tests off this build. The other cases turned up while checking
the `Int64` and `Word64` reports of this directory.

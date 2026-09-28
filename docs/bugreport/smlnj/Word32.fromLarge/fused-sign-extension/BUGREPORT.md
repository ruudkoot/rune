# SML/NJ 110.99.9: a fused sign extension makes a malformed `Word32` on 64 bits, and misses `Overflow` in `Word64.toInt (Word8.toLargeX w)`

## Status: not reported

The issue trackers have nothing on it (searched 2026-09-28). The closest
report is [#370](https://github.com/smlnj/legacy/issues/370) (`Int32`
operations not raising `Overflow`, fixed in 110.99.9). Its discussion notes
that `EXTEND` serves both `WordN.toIntX` and `IntN.toInt`, and that 32-bit
values on 64-bit targets must keep a consistent representation. The rules
below are the same in smlnj/smlnj at `a5f3fa7`
(`compiler/CPS/opt/contract-prim.sml`), so the 2026 series has them too (by
reading the code; no 2026 build was run).

**What is worth sending SML/NJ:** a new issue with `bug.sml` and `fix.diff`
(`upstream.md` is the text). It is the same family as
[Int.fromLarge/fused-conversions](../../Int.fromLarge/fused-conversions/BUGREPORT.md),
in the same file, and could go with it.

## Summary

* **The trigger:** a word conversion whose argument is a sign extension,
  e.g. `Word32.fromLargeInt (Int32.toLarge i)`,
  `Word32.fromLarge (Word8.toLargeX w)` or `Word64.toInt (Word8.toLargeX w)`,
  when the compiler fuses the two conversions.
* **What goes wrong:**
  - **64-bit:** a `Word32.word` made from a negative number keeps the sign
    in the bits above 32:
    - `Word32.fromLargeInt (Int32.toLarge ~1)` prints as
      `7FFFFFFFFFFFFFFF`;
    - it is not equal to `0wxFFFFFFFF`;
    - `Word32.toLargeInt` of it is 2^63 - 1;
    - `Word32.toInt` of `Word32.fromLarge (Word8.toLargeX 0wxFF)` is `~1`.
  - **Both widths:** `Word64.toInt (Word8.toLargeX 0wxFF)` is `~1`: the
    word 2^64 - 1 is converted to an `int` without `Overflow`. So is
    `Word32.toInt (Word32.fromLarge (Word8.toLargeX 0wxFF))` on 32 bits,
    where 2^32 - 1 does not fit.
* **Required behaviour:** the
  [Basis `WORD` specification](https://smlfamily.github.io/Basis/word.html):
  `fromLargeInt` and `fromLarge` take the low `wordSize` bits, and `toInt`
  raises `Overflow` when the unsigned value does not fit. MLton and Poly/ML
  get every line of `bug.sml` right.

## Where it happens

| Build (110.99.9) | wrong of 5 |
|---|---|
| 64-bit release | 5 |
| 32-bit: Linux and Windows releases, native fixed point on Linux | 2 |
| 32-bit and 64-bit with `fix.diff` | 0 |

```
$ sml bug.sml                           # 110.99.9, 64-bit
Word32.fromLargeInt (Int32.toLarge ~1) = 7FFFFFFFFFFFFFFF, expected FFFFFFFF: WRONG
Word32.toLargeInt (Word32.fromLargeInt (Int32.toLarge ~1)) = 9223372036854775807, expected 4294967295: WRONG
Word32.fromLarge (Word8.toLargeX 0wxFF) = 7FFFFFFFFFFFFFFF, expected FFFFFFFF: WRONG
Word64.toInt (Word8.toLargeX 0wxFF) = ~1, expected Overflow: WRONG
Word32.toInt (Word32.fromLarge (Word8.toLargeX 0wxFF)) = ~1, expected 4294967295: WRONG
```

`convs.sml` of
[Int.fromLarge/fused-conversions](../../Int.fromLarge/fused-conversions/BUGREPORT.md)
found the first of these: 19 of its checks fail on 64 bits after that
report's fix, and none after this one.

## The cause

Three rules of `ContractPrim` (`CPS/opt/contract-prim.sml`) fuse a sign
extension:

```
TRUNC(n,p) o EXTEND(m,n) ==> EXTEND(m,p)  if p >= m
TRUNC(∞,p) o EXTEND(m,∞) ==> EXTEND(m,p)  when p >= m
TESTU(n,p) o EXTEND(m,n) ==> EXTEND(m,p)  if p >= m
```

* **The `TRUNC` rules** produce a word, whose representation must be 0
  above its p bits. `EXTEND(m,p)` fills those bits with the sign, which is
  harmless only when p bits are the whole representation. That holds for 32
  bits on a 32-bit target, and for 63 and 64 bits on a 64-bit one. It fails
  for `Word32` on a 64-bit target, where a 32-bit value is held as a
  tagged 63-bit integer (the CPS gives it type `I`). With m = p = 32 the "extension" is the identity, and an
  `Int32` -1 becomes a `Word32` -1.
* **The `TESTU` rule** reads the extended n-bit value as unsigned. A
  negative number becomes 2^n more than itself, which does not fit p bits
  when p < n and is not the number itself when p >= n. One `EXTEND(m,p)` is
  not either of those. The rule's other case, `TESTU(m,p)` when p < m, is
  right.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9,
before or after the fix of
[Int.fromLarge/fused-conversions](../../Int.fromLarge/fused-conversions/BUGREPORT.md)):

* **The two `TRUNC` rules** fuse only when `p >= Target.defaultIntSz`, and
  leave the conversions alone otherwise.
* **The `TESTU` rule** leaves them alone when p >= m.

**How it was tested:**
* with the other fixes of this directory, built to a fixed point for 32
  and 64 bits;
* `bug.sml` is right on both;
* `convs.sml` has no wrong result on either;
* Rune's Basis suite has no new failure ([README](../../README.md)).

## How Rune met it

`Int.fromLarge/fused-conversions/convs.sml`, written for the reports of
this directory, had 19 failures left on 64 bits. Looking at them found the
`TESTU` rule too.

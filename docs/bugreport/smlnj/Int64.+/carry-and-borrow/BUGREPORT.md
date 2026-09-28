# SML/NJ 110.99.9 for 32 bits: `Int64.+` and `Int64.-` get the carry and the borrow wrong

## Status: not reported

The issue trackers of smlnj/legacy and smlnj/smlnj have nothing on it
(searched 2026-09-28). [#238](https://github.com/smlnj/legacy/issues/238)
(`Position.int` division, 32-bit) and #114/#120 (`Int64` comparisons) are
other bugs. The 2026 series has no 32-bit target, so only 110.x has this.

**What is worth sending SML/NJ:** a new issue on smlnj/legacy with
`bug.sml` and `fix.diff`.

## Summary

* **The trigger:** in the 32-bit build, `Int64.+` (or `Position.+`) whose
  low halves carry into the high half, and `Int64.-` whose second operand
  has a high half other than 0 (it is negative, or 2^32 or more).
* **What goes wrong:**
  - An addition that carries gets a high half 2 too small: `~2 + ~3` is
    `~8589934597`, `~1 + 1` is `~8589934592`, `4294967295 + 1` is
    `~4294967296`.
  - Overflow is missed: `9223372036854775807 + 1` is `9223372028264841216`.
  - A subtraction adds the second high half where it should subtract it:
    `5 - ~3` is `~8589934584`, `0 - 4294967296` is `4294967296`.
* **Required behaviour:** the
  [Basis `INTEGER` specification](https://smlfamily.github.io/Basis/integer.html):
  the sum or difference, or `Overflow`.

## Where it happens

`bug.sml` reads its operands from strings, so that nothing is folded at
compile time:

| Build (110.99.9) | wrong of 7 |
|---|---|
| 32-bit: Linux and Windows releases, Windows source build (MSVC), native fixed point on Linux, cross-compiled on amd64 | 6 |
| 64-bit release | 0 |
| 32-bit and 64-bit with `fix.diff` | 0 |

```
$ sml bug.sml                           # 110.99.9, 32-bit
~2 + ~3 = ~8589934597, expected ~5: WRONG
~1 + 1 = ~8589934592, expected 0: WRONG
4294967295 + 1 = ~4294967296, expected 4294967296: WRONG
9223372036854775807 + 1 = 9223372028264841216, expected Overflow: WRONG
5 - ~3 = ~8589934584, expected 8: WRONG
0 - 4294967296 = 4294967296, expected ~4294967296: WRONG
~9223372036854775808 - 1 = Overflow, expected Overflow: ok
```

(Ubuntu's 110.79 implements `Int64` in library code and fails two other
lines of `bug.sml`, `4294967295 + 1` and `0 - 4294967296`, with a spurious
`Overflow`.)

## The cause

On 32-bit targets `Num64Cnv` (`base/compiler/CPS/opt/num64cnv.sml`) expands
64-bit arithmetic into 32-bit operations. For `Int64.+`, the comment gives
the algorithm from *Hacker's Delight* with a logical shift:

```
val carry = ((lo1 & lo2) ++ ((lo1 ++ lo2) & not lo)) >> 0w31
```

`i64Add` computes it with `P.RSHIFT`, the arithmetic shift, so the carry is
0 or -1. The high half is then `hi1 + hi2 - 1` where it should be
`hi1 + hi2 + 1`. The unsigned `w64Add` uses `P.RSHIFTL` and is right.

`i64Sub` has the same arithmetic shift for the borrow, and adds where the
comment subtracts. With the borrow at 0 or -1 it computes
`hi1 + hi2 - b`, where the algorithm is `hi1 - hi2 - b`, which is right
only when `hi2` is 0:

```sml
sIf(P.LTE, hi1, hi2,
  iarith32(P.IADD, [hi1, hi2], fn tmp1 =>
  iarith32(P.IADD, [tmp1, borrow], k')),
  iarith32(P.IADD, [hi1, borrow], fn tmp2 =>
  iarith32(P.IADD, [tmp2, hi2], k')))
```

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9)
shifts logically, so that the carry and the borrow are 0 or 1. It uses
`P.ISUB` in `i64Sub`, keeping the order of the comment's algorithm, which
avoids a spurious `Overflow` on the intermediate result:

```diff
-	      pure_arith32(P.RSHIFT, [tmp3, tagNum 31], fn borrow =>
+	      pure_arith32(P.RSHIFTL, [tmp3, tagNum 31], fn borrow =>
 ...
-		    iarith32(P.IADD, [hi1, hi2], fn tmp1 =>
-		    iarith32(P.IADD, [tmp1, borrow], k')),
+		    iarith32(P.ISUB, [hi1, hi2], fn tmp1 =>
+		    iarith32(P.ISUB, [tmp1, borrow], k')),
```

**How it was tested:**
* with the other fixes of this directory, built to a fixed point for 32
  bits and cross-compiled for x86-unix and x86-win32;
* `bug.sml` is right on all of them;
* `Int64` `+`, `-`, `*`, `div`, `mod`, `quot`, `rem` and the comparisons
  agree with the 64-bit build on all 576 pairs of 24 operands, apart from
  `mod`/`rem (minInt, ~1)`, where the 64-bit build is the wrong one
  (`tests/basis/deviations.txt` line 696).

## How Rune met it

`tests/basis/deviations.txt` has one line for the whole of `Int64` on this
build ("`Int64.*` … comes out wrong throughout"). Its example,
`Int64.+ (~2, ~3)` = 1073741819, is a folded constant, which is
[Word64-low-half](../../Word64-low-half/BUGREPORT.md). With the fixes of
this directory the line no longer matches any failure.

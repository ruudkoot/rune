# SML/NJ 110.99.9 for 32 bits: `Int64.toInt` and `Word64.toIntX` ignore the high word instead of raising `Overflow`

## Status: not reported

The issue trackers of smlnj/legacy and smlnj/smlnj have nothing on it
(searched 2026-09-28). The 2026 series has no 32-bit target.

**What is worth sending SML/NJ:** a new issue on smlnj/legacy with
`bug.sml` and `fix.diff`.

## Summary

* **The trigger:** `Int64.toInt`, `Position.toInt` or `Word64.toIntX` (any
  signed conversion from 64 bits to `int`) of a number outside the 31 bits
  of `int`, in the 32-bit build.
* **What goes wrong:** the result is the low 32 bits taken as a 32-bit
  integer and then checked against 31 bits; the high word is never looked at.
  - `Int64.toInt 4294967296` is 0.
  - `Int64.toInt 3221225472` is `~1073741824`.
  - `Int64.toInt ~4294967297` is `~1`.
  - `Word64.toIntX 0wxFFFFFFFF` is `~1`.
  - `Position.toInt 4294967296` is 0.

  A file position of 4 GiB becomes 0 without an exception.
* **Required behaviour:** the
  [Basis `INTEGER` specification](https://smlfamily.github.io/Basis/integer.html)
  for `toInt` and the [`WORD` specification](https://smlfamily.github.io/Basis/word.html)
  for `toIntX`: "raise Overflow if the target integer value is not
  representable".

## Where it happens

`bug.sml` reads its numbers from strings; what it expects depends on the
width of `int`, so it runs everywhere:

| Build (110.99.9) | wrong of 8 |
|---|---|
| 32-bit: Linux and Windows releases, Windows source build (MSVC), native fixed point on Linux, cross-compiled on amd64 | 6 |
| 64-bit release | 0 |
| 32-bit and 64-bit with `fix.diff` | 0 |

```
$ sml bug.sml                           # 110.99.9, 32-bit
Int64.toInt 4294967296 = 0, expected Overflow: WRONG
Int64.toInt 3221225472 = ~1073741824, expected Overflow: WRONG
Int64.toInt ~4294967297 = ~1, expected Overflow: WRONG
Int64.toInt ~5 = ~5, expected ~5: ok
Word64.toIntX 0wx100000000 = 0, expected Overflow: WRONG
Word64.toIntX 0wxFFFFFFFF = ~1, expected Overflow: WRONG
Word64.toIntX 0wxFFFFFFFFFFFFFFFB = ~5, expected ~5: ok
Position.toInt 4294967296 = 0, expected Overflow: WRONG
```

(Ubuntu's 110.79 gets `Int64.toInt` right and the two `Word64.toIntX` lines
wrong.)

## The cause

On 32-bit targets, a signed conversion from 64 bits, `TEST(64, n)`, takes
an extra argument: a function of `Core` that converts a pair of 32-bit words
to a 32-bit integer, after which `TEST(32, n)` narrows further. `transprim.sml`
(`base/compiler/FLINT/trans/transprim.sml`, in `chkPrim`) passes
`w64ToInt32X`:

```sml
| chkPrim (po as PO.TEST(64, to), lt, ts) = ...
      L.RECORD[arg, coreAcc "w64ToInt32X"]))
```

`w64ToInt32X` is `CoreWord64.toInt32X` (`system/smlnj/init/core-word64.sml`),
which takes the low word and does not check:

```sml
fun toInt32X w = copy_word32_to_int32 (#2 (extern w))
```

The checked conversion is there as well, `i64ToInt32` =
`CoreInt64.toInt32`, which raises `Overflow` unless the high word is the
sign extension of the low word. Nothing uses it.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9)
passes `i64ToInt32` for `TEST(64, n)`:

```diff
-			      L.RECORD[arg, coreAcc "w64ToInt32X"]))
+			      L.RECORD[arg, coreAcc "i64ToInt32"]))
```

**How it was tested:**
* with the other fixes of this directory, built to a fixed point for 32
  and 64 bits and cross-compiled for x86-unix and x86-win32;
* `bug.sml` is right on all of them;
* `convs.sml` of
  [Int.fromLarge/fused-conversions](../../Int.fromLarge/fused-conversions/BUGREPORT.md)
  checks every conversion between `int`, `Int32`, `Int64`, `word`, `Word8`,
  `Word32` and `Word64`, `Int64.toInt` and `Word64.toIntX` among them, on 31
  numbers against `IntInf`. It has no wrong result on the patched 32-bit
  build.

`Position.toInt (Position.fromLarge x)` was also wrong, for another reason
(a fusion of the two conversions,
[Int.fromLarge/fused-conversions](../../Int.fromLarge/fused-conversions/BUGREPORT.md)).
`bug.sml` reads its `Position.int` with `Position.fromString` to keep the
two apart.

## How Rune met it

It was hidden under the one line that `tests/basis/deviations.txt` has for
all of `Int64` on this build ("`Int64.*` … comes out wrong throughout").
A test of `Word64` and `Int64` against the 64-bit build, written while
checking the other reports, found it.

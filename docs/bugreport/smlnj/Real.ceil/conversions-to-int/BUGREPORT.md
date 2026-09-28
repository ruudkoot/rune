# SML/NJ 110.99.9: `Real.ceil`, `trunc` and `round` are off by one, and for 64 bits `floor`, `ceil`, `trunc` and `round` wrap around instead of raising `Overflow`

## Status: not reported

The issue trackers of smlnj/legacy and smlnj/smlnj have nothing on
`Real.floor`, `ceil`, `trunc` or `round` (searched 2026-09-28). The code is
the same in smlnj/smlnj at `a5f3fa7` (`system/smlnj/init/pervasive.sml`,
`target64-inline.sml`), so the 2026 series has these bugs too (by reading
the code; no 2026 build was run).

**What is worth sending SML/NJ:** a new issue with `bug.sml` and
`fix.diff` (`upstream.md` is the text).

## Summary

* **The trigger:** converting a real to an `int` with `Real.ceil`,
  `Real.trunc` or `Real.round` (and so `Real.toInt` in every rounding mode),
  and, on 64-bit builds, with `Real.floor` too.
* **What goes wrong:**
  - **All builds, `ceil` just above an integer:** it is one too small:
    `ceil (nextAfter (3.0, 4.0))` is 3, and `ceil 1.0E~20` and
    `ceil minPos` are 0.
  - **The same, `trunc` of a negative number** (which is `ceil`):
    `trunc (~(2^62) + 512.0)` is one too far from 0.
  - **64-bit, `floor` from 2^62 to 2^62 + 2048 and from -2^62 - 2048 up:**
    the number wraps around the 63 bits of `int` instead of raising
    `Overflow`. `floor (2^62)` and `round (2^62)` are `minInt`,
    `floor (~(2^62) - 2048.0)` is a positive number, and `trunc (~(2^62))` is
    `maxInt` where it should be `minInt`.
  - **64-bit, `round` above 2^52:** `round (2^52 + 1.0)` is 2^52 + 2.
  - **32-bit, `round` just below `minInt`:** `round (real minInt - 0.5)`
    raises `Overflow`, although the tie goes to the even `minInt`.
* **Required behaviour:** the
  [Basis `REAL` specification](https://smlfamily.github.io/Basis/real.html):
  `ceil r` is the smallest integer not less than `r`, and `round` rounds to
  the nearest integer, ties to the even one. Each "raises Overflow if the
  resulting value cannot be represented as an int". MLton and Poly/ML get
  every line of `bug.sml` right.

## Where it happens

`bug.sml` expects the exact integer, or `Overflow` when that does not fit
`int`, so it runs on both widths:

| Build (110.99.9) | wrong of 12 |
|---|---|
| 64-bit release | 9 |
| 32-bit: Linux and Windows releases, native fixed point on Linux | 4 (the three `ceil`s and `round (real minInt - 0.5)`) |
| 32-bit and 64-bit with `fix.diff` | 0 |

```
$ sml bug.sml                           # 110.99.9, 64-bit
ceil minPos = 0, expected 1: WRONG
ceil (nextAfter (3.0, 4.0)) = 3, expected 4: WRONG
ceil 1.0E~20 = 0, expected 1: WRONG
trunc (~(2^62) + 512.0) = ~4611686018427387393, expected ~4611686018427387392: WRONG
floor (2^62) = ~4611686018427387904, expected Overflow: WRONG
floor (~(2^62) - 2048.0) = 4611686018427385856, expected Overflow: WRONG
trunc (~(2^62)) = 4611686018427387903, expected ~4611686018427387904: WRONG
round (2^62) = ~4611686018427387904, expected Overflow: WRONG
round (real minInt - 0.5) = ~4611686018427387904, expected ~4611686018427387904: ok
round (2^52 + 1.0) = 4503599627370498, expected 4503599627370497: WRONG
round 2.5 = 2, expected 2: ok
round ~2.5 = ~2, expected ~2: ok
```

## The cause

**`floor` on 64-bit.** It is range-checked in
`system/smlnj/init/target64-inline.sml`:

```sml
val rminInt = ~4611686018427390000.0
val rmaxInt = 4611686018427390000.0
fun floor (x : real) =
      if InLine.real64_le(rminInt, x) andalso InLine.real64_le(x, rmaxInt)
        then Assembly.A.floor x
```

The comment calls the bounds `minInt` and `maxInt` "with loss of
precision". As reals they are ±(2^62 + 2048), and the upper test is `<=`.
Every real from 2^62 to 2^62 + 2048 passes, and from -(2^62 + 2048) to just
below -2^62. `Assembly.A.floor` converts it to a 64-bit integer and tags it
with a shift that drops the top bit. The 32-bit version tests exactly:
`-2^30 <= x < 2^30`.

**`ceil` and `round`** are in `system/smlnj/init/pervasive.sml`:

```sml
fun ceil x = Int.- (~1, floor (R64.~ (x + 1.0)))
fun trunc x = if R64.< (x, 0.0) then ceil x else floor x
fun round x = let
      val fl = floor(x+0.5)
      val cl = ceil(x-0.5)
      in
        if fl=cl then fl
        else if Word.andb(Word.fromInt fl, 0w1) = 0w1 then cl
        else fl
      end
```

* **`ceil`** is right only when `x + 1.0` is exact. For `x = n + e`, just
  above an integer n, the sum rounds down to n + 1 whenever `e` is less than
  half an ulp of n + 1, and `ceil` gives n. That is every positive `x` below
  2^-53, and the real just above n for most n. Above 2^53 the sum can round
  the other way.
* **`round`** has the same problem with `x + 0.5` and `x - 0.5`, which
  are not exact above 2^52: `round (2^52 + 1.0)` becomes
  `floor (2^52 + 2)`. It also calls `ceil (x - 0.5)`, which is out of
  range for `x = real minInt - 0.5` although the result, `minInt`, is not.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9)
makes three changes.

* **64-bit `floor`:** test `-2^62 <= x < 2^62` exactly, as the 32-bit
  version does.
* **`ceil` and `round`:** start from `floor x`, which checks the range,
  and from `x - real (floor x)`, which is exact. `ceil` adds 1 unless `x` is
  an integer; `round` adds 1 when the fraction is above one half, or equal
  to it and `floor x` is odd.
* **The one case where `floor x` is out of range but the result is not:**
  the answer is `minInt`, for an `x` less than 1 (`ceil`) or one half
  (`round`) below it. There the handler tries `floor` of `x + 1.0` or
  `x + 0.5`, which are exact for such an `x`.

```sml
fun ceil x = let
      val f = floor x
      in
        if R64.== (real f, x) then f else Int.+ (f, 1)
      end
        handle Overflow => Int.- (~1, floor (R64.~ (x + 1.0)))

fun round x = let
      val f = floor x
      val d = R64.- (x, real f)
      in
        if R64.< (d, 0.5) then f
        else if R64.> (d, 0.5) orelse Word.andb(Word.fromInt f, 0w1) = 0w1
          then Int.+ (f, 1)
          else f
      end
        handle Overflow => floor (x + 0.5)
```

**How it was tested:**
* with the other fixes of this directory, built to a fixed point for 32
  and 64 bits;
* `bug.sml` is right on both;
* Rune's Basis suite on both has no new failure, and its
  `Real.ceil/small-positive` and `Real.round/minInt-minus-half-tie-to-even`
  checks pass ([README](../../README.md)).

## How Rune met it

`tests/basis/deviations.txt` lines 157 (`Real.ceil/small-positive`) and 158
(`Real.round/minInt-minus-half-tie-to-even`, 32-bit). The 64-bit
wrap-around turned up while checking them.

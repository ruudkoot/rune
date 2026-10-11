# SML/NJ 110.99.9 and 2026.2, 64-bit: `Int32.abs minInt` does not raise `Overflow`, and makes a malformed `Int32.int`

## Status: fixed upstream in the new series, not in 110.x

* **The report:** [smlnj/smlnj#444](https://github.com/smlnj/smlnj/issues/444),
  "`Int32.abs` of `Int32.minInt` should raise `Overflow`" (2026-08-30).
* **The fix:** commit `a9218d2` of smlnj/smlnj (2026-08-31); the first tag
  with it is `v2026.3-beta`. 2026.2 does not have it.
* **110.x:** smlnj/legacy at `6ed5a0a` (2026-09-13) has the same
  `target64-inline.sml` as 110.99.9, so the bug is still there; nothing on
  the legacy tracker (searched 2026-10-11). The `Overflow` checks of the
  other `Int32` operations came from
  [smlnj/legacy#370](https://github.com/smlnj/legacy/issues/370), whose fix
  left `abs` out.

**What is worth sending SML/NJ:** a request to port `a9218d2` to legacy, a
new issue on smlnj/legacy with `bug.sml` and `fix.diff` (`upstream.md` is
the text).

## Summary

* **The trigger:** `Int32.abs` of `valOf Int32.minInt`
  (`~2147483648`), on a 64-bit build.
* **What goes wrong:** no `Overflow`; the result prints as `~2147483648`
  but is 2^31 inside: it compares greater than 0, `Int32.toLarge` gives
  `~2147483648`, and adding 0 to it raises `Overflow`.
* **Required behaviour:** the
  [Basis `INTEGER` specification](https://smlfamily.github.io/Basis/integer.html#SIG:INTEGER.abs:VAL):
  "`abs i` returns the absolute value (magnitude) of `i`. It raises
  `Overflow` when the result is not representable." SML/NJ's own 32-bit build
  raises it, and so do MLton, Poly/ML, MLKit and Rune.

## Where it happens

| Build | wrong of 5 |
|---|---|
| 110.99.9, 64-bit | 3 |
| 110.99.9, 32-bit | 0 |
| 2026.2 (64-bit) | 3 |
| smlnj/smlnj `17362d2` (by reading the code) | 0 |
| smlnj/legacy `6ed5a0a` (by reading the code) | 3 on 64 bits |

```
$ sml bug.sml                           # 110.99.9, 64-bit, or 2026.2
Int32.~ minInt = Overflow: ok
Int32.abs minInt = ~2147483648: WRONG
Int32.abs minInt > 0 = true: WRONG
Int32.toLarge (Int32.abs minInt) = ~2147483648: WRONG
Int32.abs minInt + 0 = Overflow: ok
```

The last line is `ok` by accident: `+` sees the malformed 2^31 and raises
`Overflow` although it adds 0.

## The cause

On 64-bit targets an `Int32.int` is held in a 63-bit tagged integer, so the
hardware does not overflow at 32 bits. `base/system/smlnj/init/target64-inline.sml`
wraps the `Int32` operations that can leave the range in `i32chk`, which
checks the result against -2^31 and 2^31 - 1 (smlnj/legacy#370). `abs` is
outside the wrapped group:

```sml
        val ~       : int32 -> int32          = i32chk InLine.int32_neg
        ...
	end (* local *)

        val min     : int32 * int32 -> int32  = InLine.int32_min
        val max     : int32 * int32 -> int32  = InLine.int32_max
        val abs     : int32 -> int32          = InLine.int32_abs
```

`InLine.int32_abs` is expanded to `if x > 0 then x else ~x` with the
63-bit negation (`FLINT/trans/transprim.sml`, `inlabs`), which gives 2^31
for `minInt`. The 32-bit target has no wrapper and needs none: there the
negation traps at 32 bits.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9)
is upstream's `a9218d2`: it moves `abs` into the `local` and wraps it in
`i32chk`, like `~`.

**How it was tested:** SML/NJ was not rebuilt. `fix-check.sml` defines
`i32chk` as `target64-inline.sml` does (with `Unsafe.cast` for
`InLine.cast`) and wraps `Int32.abs` in it: on 110.99.9 (64-bit) and
2026.2 the wrapped `abs` raises `Overflow` for `minInt` and agrees with
`Int32.abs` on 100,005 other values. (It does not compile on the 32-bit
build, whose `int` cannot hold the bounds; `target64-inline.sml` is not
used there.)

## How Rune met it

By the laws of Rune's Basis Library documentation: each `Law:` is tested
on generated values, and `tests/basis/run-laws-hosts.py` runs them against
the Basis Library of the other compilers (`docs/plans/quickcheck-hunt.md`,
the sections on the other compilers, "D10 on the split library"). The law
of `abs` (`lib/basis/int_sig.sml`), `abs i = (if i < 0 then ~i else i)`,
fails at `Int32` on the 64-bit builds once `Int32`'s arbitrary was in a
file of its own; it is the line `native:smlnj-* | INTEGER.abs/law-1@Int32`
of `tests/basis/law-deviations.txt`.

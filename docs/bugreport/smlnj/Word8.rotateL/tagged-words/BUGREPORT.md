# SML/NJ 2026.2: `rotateL` and `rotateR` of `Word8`, `Word32` and `Word` fill with the top bit

## Status: fixed upstream after 2026.2, nothing to send

smlnj/smlnj fixed it in
[`d6f6888`](https://github.com/smlnj/smlnj/commit/d6f6888) (2026-09-23,
"Fixed issue with synthesized rotations for smaller integer types"), after
the `v2026.2` tag (2026-08-14) and before `v2026.3-rc1` (checked
2026-10-09). 110.99.9 has no rotations. Found while porting 2026.2's
library to Rune (`xc2:smlnj-dev`, `tests/basis/xc2`), whose stand-ins for
the new primitives were checked against native 2026.2.

## Summary

* **The trigger:** `rotateL` or `rotateR` of a `Word8.word`, a
  `Word32.word` or a `Word.word` (63 bits) whose top bit is set, by any
  amount, known to the compiler or not. These are operations of 2026.2's
  `WORD` (`WORD_2026` in `word.sig`), outside the Basis specification.
* **What goes wrong:** the bits rotated in are copies of the top bit
  instead of the bits rotated out. `Word8.rotateL (0wx81, 0w1)` is `0wxFF`
  instead of `0wx3`; `Word32.rotateR (0wx80000000, 0w4)` is `0wxF8000000`
  instead of `0wx8000000`.
* **Required behaviour:** a rotation, as `Word64.rotateL` does it.

## Where it happens

| Build | wrong of 7 |
|---|---|
| 2026.2, 64-bit (amd64 Linux) | 6 (all but `Word64`) |

```
$ sml bug.sml
Word8.rotateL (0wx81, 0w1) = FF   (should be 3)
Word8.rotateL (0wx81, ident 0w1) = FF   (should be 3)
Word8.rotateR (0wx80, 0w1) = C0   (should be 40)
Word32.rotateL (0wx80000001, 0w4) = FFFFFFF8   (should be 18)
Word32.rotateR (0wx80000000, 0w4) = F8000000   (should be 8000000)
Word.rotateL (0wx4000000000000001, 0w1) = 7FFFFFFFFFFFFFFF   (should be 3)
Word64.rotateL (0wx8000000000000001, 0w1) = 3
```

## Cause

`compiler/CPS/opt/lower.sml` expands a rotation of a word narrower than a
machine word, which is tagged, into shifts: `(v1 >> k) | ((v1 & m) << n)`
for `rotateL`, and the like for `rotateR`. The `>>` is `P.RSHIFT`, the
arithmetic shift, where it has to be `P.RSHIFTL`, the logical one. A
`Word64` is rotated by the machine's instruction and is right. `d6f6888`
changes the two `P.RSHIFT` to `P.RSHIFTL`.

# SML/NJ 110.99.9 for 32 bits: a 64-bit literal loses bits 30 and 31 of its low half, because the boot files are cross-compiled

## Status: reported and closed as fixed, but still there

* **The report:** [smlnj/legacy#260](https://github.com/smlnj/legacy/issues/260),
  "64-bit word literals are parsed incorrectly on 32-bit systems"
  (2022-10-26, against 110.99.3): `0wxFFFFFFFFFFFFFFFF : Word64.word` is
  `0wxFFFFFFFF3FFFFFFF`.
* **Closed as fixed** in 110.99.4 by commits `ca65b54` and `29585b3`.
  They change only `CPS/opt/streqlcnv.sml`, the 32-bit
  string-matching bug that a comment on the issue found. The literal bug
  itself was not touched, and 110.99.9 still has it.
* **Seen again:** in [#373](https://github.com/smlnj/legacy/issues/373)
  (open), John Reppy traced a lost bit to the lowering of
  `0wxffffffff : Word64.word` to `{RK_RAWBLOCK 2,(I32)0,(I32)1073741823}`
  (2025-12-23). He also noted that the problem "seems to go away if I compile
  to a fixed point on a 32-bit machine" (2026-03-13). That is this bug, and
  the explanation is below. #373's own failures have another cause
  ([Word64/shifts-and-negation](../Word64/shifts-and-negation/BUGREPORT.md)).

**What is worth sending SML/NJ:** a comment on #260 or #373, or a new
issue, with the cause and `fix.diff`.

## Summary

* **The trigger:** a `Word64.word`, `Int64.int` or `Position.int` literal
  whose low 32 bits have bit 30 or 31 set, or an expression the optimizer
  folds into one (`Word64.fromInt 1073741823 + 0w1`, `Int64.+ (~2, ~3)`),
  compiled by the 32-bit build.
* **What goes wrong:** the low half of the constant keeps only its low 30
  bits, and a negative constant also gets a high half of 0.
  - `0wx40000000 : Word64.word` is `0w0`.
  - `0wxFFFFFFFFFFFFFFFF` is `0wxFFFFFFFF3FFFFFFF`.
  - `~5 : Int64.int` is `1073741819`.

  Values made at run time are not affected. An earlier version of this
  report said that arithmetic loses the same bits; that was constant
  folding.
* **Required behaviour:** the
  [Basis `WORD`](https://smlfamily.github.io/Basis/word.html) and
  [`INTEGER`](https://smlfamily.github.io/Basis/integer.html) specifications:
  a literal denotes its value.

## Where it happens

`bug.sml` prints seven constants beside the same numbers read from strings
at run time:

| Build (110.99.9, 32-bit unless noted) | wrong of 7 |
|---|---|
| Linux, the release (`config/install.sh -32`) | 7 |
| Windows, the release (`smlnj-110.99.9.msi`) | 7 |
| Windows, built from the release's sources with `config\install.bat` (Visual Studio 2022, cl 19.40, x86) | 7 |
| Linux, from x86-unix boot files cross-compiled on amd64 from the release's sources (`cmb-cross -64 x86-unix`) | 7 |
| Linux, the release's sources compiled to a fixed point by the 32-bit compiler (`fixpt -32`, `makeml -32`, `installml -32`) | 0 |
| Linux, 64-bit release | 0 |
| Ubuntu 24.04's `smlnj 110.79-8build1` (32-bit) | 0 |
| the 32-bit releases 110.98.1 to 110.99.7.1 | 7 |
| the 32-bit release 110.99.8 | 0 |
| cross-compiled on amd64 with `fix.diff`, on Linux (x86-unix) and on Windows (x86-win32) | 0 |

```
$ sml bug.sml                           # 110.99.9, 32-bit release
0wx40000000 : Word64.word = 0, expected 40000000: WRONG
0wx80000000 : Word64.word = 0, expected 80000000: WRONG
0wxFFFFFFFFFFFFFFFF : Word64.word = FFFFFFFF3FFFFFFF, expected FFFFFFFFFFFFFFFF: WRONG
Word64.fromInt 1073741823 + 0w1 = 0, expected 40000000: WRONG
~5 : Int64.int = 1073741819, expected ~5: WRONG
1073741824 : Int64.int = 0, expected 1073741824: WRONG
Int64.+ (~2, ~3) = 1073741819, expected ~5: WRONG
```

## The cause

The 32-bit compiler splits a 64-bit constant into two 32-bit words in
`Num64Cnv.split` (`base/compiler/CPS/opt/num64cnv.sml`):

```sml
val lo = C.NUM{ival = IntInf.andb(n, 0xffffffff), ty = {sz = 32, tag = false}}
```

The source is right, but the released compiler's `0xffffffff` is not. An
`IntInf.int` literal is compiled by `transIntInf`
(`base/compiler/FLINT/trans/translate.sml`) into a call that builds the
number from its digits. The digits come from `LiteralToNum.repDigits`, which
is `CoreIntInf.concrete` of the compiler that runs, the *host*:

```sml
val repDigits = #digits o unBI o CoreIntInf.concrete
```

A 64-bit host's `CoreIntInf` has 62-bit digits
(`system/smlnj/init/target64-core-intinf.sml`); a 32-bit target's has 30-bit
digits (`target32-core-intinf.sml`). The 32-bit boot files of a release are
cross-compiled on amd64 (`admin/prepare-release.sh` runs `allcross` with a
64-bit `sml`). So every `IntInf` literal of 2^30 or more in them is built
from digits of the wrong size:
* `0xffffffff` becomes a single digit that no 30-bit digit can be, and
  `andb` with it keeps only the lowest 30-bit digit of `n`: `n mod 2^30`.
* For a negative constant, `split` first adds `0x10000000000000000`. That is
  2^64 = 4 * 2^62, the digits `[0, 4]`, which the target reads as 2^32. So
  `~5` becomes 2^32 - 5, whose halves are 0 and `1073741819`.

The two builds that are right confirm this:
* a native fixed point, where host and target have the same digits;
* the cross-compiled build with `fix.diff`.

Cross-compiling the unpatched sources on amd64 reproduces the release's
wrong values.

The same host dependence is in `LiteralToNum.lowVal`, which decides which
`IntInf` constants of a `case` are compiled into a switch on
`CoreIntInf.lowValue`. A cross-compiled constant between 2^30 and 2^62 is
taken for a one-digit number there. No wrong result of that was looked for.

Every `IntInf` literal of 2^30 or more in the compiler and Basis of the
32-bit releases is affected, not only `Num64Cnv.split`'s. Among Rune's
Basis checks, one more thing is wrong in the release and right after a
native fixed point: the positions `Posix.IO.lseek` gives for a negative
offset from the current position or the end.

## The fix

`fix.diff` computes the digits for the target, with 30 or 62 bits after
`Target.is64`, and returns them as `IntInf.int` so that a 32-bit host can
cross-compile for a 64-bit target too. `translate.sml` and
`translate-new.sml` take the digits as they are:

```sml
val baseBits : word = if Target.is64 then 0w62 else 0w30
val base = IntInf.<< (1, baseBits)
val maxDigit = base - 1

fun repDigits i = let
      fun digits 0 = []
        | digits n = IntInf.andb (n, maxDigit) :: digits (IntInf.~>> (n, baseBits))
      in
        digits (IntInf.abs i)
      end

fun lowVal i = if IntInf.abs i < base then SOME i else NONE
```

`fix.diff` applies to smlnj/legacy at `6ed5a0a` and to 110.99.9's sources.

**How it was tested:**
* built natively (fixed point) for 32 and 64 bits;
* cross-compiled on amd64 into x86-unix and x86-win32 boot files, the
  release's way, with the other six fixes of this directory;
* all seven reports' programs are right on every one of these builds;
* Rune's Basis suite has no new failure on the 32-bit build
  ([README](../README.md)).

**Until a release has the fix:** compiling the 32-bit system to a fixed
point with itself (`base/system/fixpt -32`, `makeml -32`, `installml -32`,
then `config/install.sh -32`) gives a compiler without this bug.

## How Rune met it

Rune's random-number library, `lib/random` (SplitMix64, whose constants are
64-bit literals with those bits set), gives the published known answers on
Rune, MLton, Poly/ML, MLKit and SML/NJ for 64 bits, and wrong ones on this
build. It is a `HOST-BUG` line of `tests/lib/deviations.txt`; Rune does not
change the library for it. On a native fixed point of 110.99.9,
`random.kat` and `random.props` pass.

# SML/NJ bug reports

One directory per bug, each with a `BUGREPORT.md`, a program that shows the
bug with SML/NJ's own Basis Library (`sml bug.sml`, nothing of Rune
involved) and, where there is one, a `fix.diff` against
[smlnj/legacy](https://github.com/smlnj/legacy) at `6ed5a0a` (2026-09-13),
which also applies to the sources of 110.99.9.

## 64-bit integers and reals in 110.99.9 (checked 2026-09-28)

The reports below come from the `HOST-BUG` lines that Rune's suites record
for SML/NJ's 32-bit build (`native:smlnj32`), and from what turned up while
checking them. Each report's programs were run on eleven builds, grouped
into the table's columns:

* **32-bit releases:** Linux (`config/install.sh -32`, the release's
  `boot.x86-unix.tgz`) and Windows (`smlnj-110.99.9.msi`).
* **32-bit source builds:** the release's sources built on Windows with
  `config\install.bat` (Visual Studio 2022, cl 19.40 for x86), as
  `win-dist/build-msi.bat` does; the release's sources compiled to a fixed
  point by the 32-bit compiler itself on Linux (`base/system/fixpt -32`,
  `makeml`, `installml`); and boot files I cross-compiled on amd64
  (`base/system/cmb-cross -64 x86-unix`), which is how the release makes its
  32-bit boot files (`admin/prepare-release.sh`, step 9).
* **Others:** the 64-bit release on Linux (`config/install.sh -64`) and
  Ubuntu 24.04's package of 110.79 (`smlnj 110.79-8build1`, 32-bit).
* **With the fixes:** all seven `fix.diff`s applied, built natively on Linux
  for 32 and 64 bits, and cross-compiled on amd64 into x86-unix and
  x86-win32 boot files installed on Linux and on Windows.

Linux is Ubuntu 24.04 on WSL2 (gcc 13.3); Windows is Windows 11 (10.0.22000).

Each cell is the number of wrong lines the report's program prints;
"crash" is `Compiler bug: Num64Cnv: test64To`.

| Report | 32-bit releases, Win/Linux source builds | 32-bit, native fixed point | 64-bit release | 110.79 | all builds with the fixes | Upstream |
|---|---|---|---|---|---|---|
| [Word64-low-half](Word64-low-half/BUGREPORT.md): 64-bit literals lose bits 30 and 31 | 7 of 7 | 0 | 0 | 0 | 0 | [#260](https://github.com/smlnj/legacy/issues/260), closed as fixed but not fixed |
| [Int64.+/carry-and-borrow](Int64.+/carry-and-borrow/BUGREPORT.md) | 6 of 7 | 6 | 0 | (2) | 0 | not reported |
| [Word64/shifts-and-negation](Word64/shifts-and-negation/BUGREPORT.md) | 8 of 8 | 8 | 0 | 0 | 0 | not reported; the cause of [#373](https://github.com/smlnj/legacy/issues/373) |
| [Int64.toInt/high-word-ignored](Int64.toInt/high-word-ignored/BUGREPORT.md) | 6 of 8 | 6 | 0 | (2) | 0 | not reported |
| [Int.fromLarge/fused-conversions](Int.fromLarge/fused-conversions/BUGREPORT.md) | 2 + crash + 4 | the same | 4 | 2 | 0 | not reported |
| [Real.fromManExp/subnormal-is-zero](Real.fromManExp/subnormal-is-zero/BUGREPORT.md) | 6 of 6 | 6 | 6 | 6 | 0 | [#254](https://github.com/smlnj/legacy/issues/254), closed as fixed but not fixed |
| [Real.nextAfter/subnormal-and-zero](Real.nextAfter/subnormal-and-zero/BUGREPORT.md) | 5 of 5 | 5 | 5 | absent | 0 | not reported |

(110.79 implements `Int64` differently; its failures there are other bugs.)

The first bug is in how the release is made: a native 32-bit fixed point does
not have it. The others are in the sources, so every build has them;
`fromManExp`, `nextAfter` and the fused conversions are the same code in
[smlnj/smlnj](https://github.com/smlnj/smlnj) at `a5f3fa7`, so the 2026
series has them too (by reading the code; no 2026 build was run).

## Drafts for upstream

Each report's `upstream.md` is the text to post, with the fields of the
issue form, the program, a transcript and the patch filled in:

* comments on [#260](https://github.com/smlnj/legacy/issues/260)
  ([Word64-low-half](Word64-low-half/upstream.md)),
  [#373](https://github.com/smlnj/legacy/issues/373)
  ([Word64/shifts-and-negation](Word64/shifts-and-negation/upstream.md)) and
  [#254](https://github.com/smlnj/legacy/issues/254)
  ([Real.fromManExp](Real.fromManExp/subnormal-is-zero/upstream.md));
* four new issues on smlnj/legacy:
  - [Int64.+](Int64.+/carry-and-borrow/upstream.md)
  - [Int64.toInt](Int64.toInt/high-word-ignored/upstream.md)
  - [fused conversions](Int.fromLarge/fused-conversions/upstream.md)
  - [Real.nextAfter](Real.nextAfter/subnormal-and-zero/upstream.md)

The legacy form asks for one report when the development version has the
bug too; for the last two it says so.

## Which release is good for 32 bits

None of the 110 releases gets 64-bit integers right on 32 bits. Each
release from 110.79 to 110.99.8 was installed for 32 bits
(`config/install.sh`) and given the programs of these reports (checked
2026-09-28). The counts are wrong lines of each report's program:

| Releases (32-bit) | literals | `Int64` `+` `-` | `Word64` shifts | `toInt`, `toIntX` | fused conversions | `fromManExp` | `nextAfter` |
|---|---|---|---|---|---|---|---|
| 110.79 - 110.87 | right | 2: `Int64.fromString` raises `Overflow` above 2^31 | right | 2: `Word64.toIntX` | 2 (`Word`, `Word32`) | 6 | absent |
| 110.88 | hangs | 5 | hangs | 3 | 2; the compiler raises `Match` | 6 | absent |
| 110.89 - 110.92 | right, but `Word64.scan` of more than 32 bits raises `Overflow` ([#240](https://github.com/smlnj/legacy/issues/240)) | 6 | 8 | 6 | 2 + 3; the compiler raises `Match` | 6 | absent |
| 110.93 - 110.98 | as above | 6 | 8 | 6 | 1-4 | 6 | absent |
| 110.98.1 - 110.99.4 | 7 ([#260](https://github.com/smlnj/legacy/issues/260)) | 6 | 8 | 6 | 1 | 6 | absent |
| 110.99.5 - 110.99.7.1 | 7 | 6 | 8 | 6 | 1-3 | 6 | 5 |
| 110.99.8 | right | 6 | 8 | 6 | 2 + 4; `Compiler bug: Num64Cnv: test64To` | 6 | 5 |
| 110.99.9 | 7 | 6 | 8 | 6 | 2 + 4; `Compiler bug` | 6 | 5 |
| 110.99.9 with the fixes | right | right | right | right | right | right | right |

What the table shows:

* **The break:** between 110.87 (May 3, 2019) and 110.89 (June 1, 2019),
  the 64-bit arithmetic of 32-bit targets changed to today's lowering in
  the compiler (`CPS/opt/num64cnv.sml`, dated 2019); 110.88 is in between
  and hangs. Since then `Int64` `+` and `-`, the `Word64` shifts and `toInt`
  have been wrong.
* **110.99.8:** it is the one release since 110.98.1 without the literal
  bug, so its boot files were evidently not cross-compiled. It is also the
  first with the `test64To` compiler bug.
* **110.87 and Ubuntu's 110.79** predate the rewrite, and their `Int64`
  arithmetic is right. They are not good either:
  - their `Word64` is incomplete: `LargeWord` is `Word32`, and
    `Word64.toLarge` and `Word64.fromLarge` raise `Fail "unimplemented"`;
  - `Word64.min` gives the larger operand;
  - `Int64.fromString`, `Int64.scan` and `Int64.mod` raise at large
    magnitudes;
  - `Word64.toIntX` and the fused `Word` conversions miss `Overflow`;
  - `Real.toManExp` is wrong at 0, `maxFinite` and the subnormals, and
    `fromManExp` is wrong below 2^-1021.

Rune's Basis suite (`native:smlnj32`) puts numbers on it. The failures
counted are the checks explained by `deviations.txt` and the unexplained
ones together:

| SML/NJ, 32-bit | checks | failing | where most of them are |
|---|---|---|---|
| Ubuntu 24.04's 110.79 | 61,234 | 1,770 | `Word64` 647, `Int64` 223, `Real` 142 |
| 110.87 | 61,558 | 1,963 | `Word64` 647, `Int64` 223, `Real` 140 |
| 110.99.9 | 48,968 | 1,466 | `Int64` 832; the `Word8`, `Word32`, `Word64` and `LargeWord` tests do not compile |
| 110.99.9 with the fixes | 59,401 | 649 | `Bool` 114, `IntInf` 56, `Array2` 37, `Real` 32: none in `Int64` or `Word64` |

So the last release before the break is 110.87, and 110.79 behaves the
same. Both have 64-bit integers and reals that are broken in smaller ways.
The only 32-bit SML/NJ that gets these right is 110.99.9 with the fixes of
this directory.

## What the fixes do to Rune's suites

With all seven fixes, SML/NJ's 32-bit build:

* **Basis suite** (`tests/basis/run-matrix.sh --configs native:smlnj32`):
  - The release runs 48,968 checks with 1,466 explained by
    `tests/basis/deviations.txt`.
  - The patched build runs 59,401 checks, because the `Word8`, `Word32`,
    `Word64` and `LargeWord` tests now compile, and 649 are explained.
  - Neither has an unexplained failure.
  - Thirteen `native:smlnj32` lines no longer match a failure: lines 149,
    162, 693, 698-700, 774-778, 780 and 781. Of these, only line 781
    (`Posix.IO.SEEK_[CE]*/negative`) also goes away with a native fixed
    point alone.
* **Library tests** (`tests/lib/run-hosts.sh smlnj32`): all four tests
  pass, where the release fails `random.*` and `property.*`.

## Seen on the way, not reported here

* **64-bit, nondeterministic:** the 64-bit build, release and patched alike,
  now and then corrupts a real (a round trip through
  `Real.toManExp`/`fromManExp` gives a number whose bits are a heap address)
  or stops with "bogus fault" / "bogus overflow fault" (3 runs of 5 of
  `tests/lib/property/core.sml`). Open
  [#299](https://github.com/smlnj/legacy/issues/299) describes the same kind
  of corruption of 64-bit values across a garbage collection. Not
  investigated.
* **64-bit, `Word32` from a signed value:** `Word32.fromLargeInt
  (Int32.toLarge ~1)` and `Word32.fromLarge (Word8.toLargeX 0wxFF)` give a
  `Word32.word` of 63 one-bits (`Word32.toString` prints
  `7FFFFFFFFFFFFFFF`). Found by `Int.fromLarge/fused-conversions/convs.sml`,
  not reported, not fixed.
* **32-bit reals that the fixes leave:** `Real.round (real minInt - 0.5)`
  raises `Overflow` and `Real.fromLargeInt (2^100 + 2^47 + 1)` rounds twice
  (`tests/basis/deviations.txt` lines 158 and 159).
* **All builds:** `Real.ceil Real.minPos` is 0 (line 157).

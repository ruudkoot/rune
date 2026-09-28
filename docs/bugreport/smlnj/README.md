# SML/NJ bug reports

One directory per bug, each with:
* a `BUGREPORT.md`;
* a program that shows the bug with SML/NJ's own Basis Library
  (`sml bug.sml`, nothing of Rune involved);
* where there is one, a `fix.diff` against
  [smlnj/legacy](https://github.com/smlnj/legacy/tree/6ed5a0a9b3f42df06c8dd999373521c70d44d04b) at `6ed5a0a` (2026-09-13),
  which also applies to the sources of 110.99.9;
* an `upstream.md` with the text to post.

## Integers and reals in 110.99.9 (checked 2026-09-28)

These reports come from the `HOST-BUG` lines that Rune's suites record for
SML/NJ, and from what turned up while checking them. Their programs were
run on these builds:

* **32-bit releases:** Linux (`config/install.sh -32`, the release's
  `boot.x86-unix.tgz`) and Windows (`smlnj-110.99.9.msi`).
* **32-bit source builds:**
  - the release's sources built on Windows with `config\install.bat`
    (Visual Studio 2022, cl 19.40 for x86), as `win-dist/build-msi.bat` does;
  - the release's sources compiled to a fixed point by the 32-bit compiler
    itself on Linux (`base/system/fixpt -32`, `makeml`, `installml`);
  - boot files I cross-compiled on amd64
    (`base/system/cmb-cross -64 x86-unix`), which is how the release makes its
    32-bit boot files (`admin/prepare-release.sh`, step 9).
* **Others:** the 64-bit release on Linux (`config/install.sh -64`), Ubuntu
  24.04's package of 110.79 (`smlnj 110.79-8build1`, 32-bit), every
  32-bit release from 110.79 to 110.99.8 and some 64-bit ones, and the
  Windows installers of ten releases from 110.79 to 110.99.3.
* **With the fixes:**
  - the twelve `fix.diff`s of the compiler and Basis applied and built
    natively on Linux for 32 and 64 bits;
  - the fixes of the literals, `Int64.+`, the shifts, `Int64.toInt`, the
    fused conversions, `Real.fromManExp` and `Real.nextAfter` also
    cross-compiled on amd64 into x86-unix and x86-win32 boot files,
    installed on Linux and on Windows;
  - the runtime `fix.diff` of `IEEEReal.setRoundingMode` built into the
    Windows source build.

Linux is Ubuntu 24.04 on WSL2 (gcc 13.3); Windows is Windows 11 (10.0.22000).

Each cell is the number of wrong lines the report's program prints:
* "crash" is `Compiler bug: Num64Cnv: test64To`;
* "n/a" means the program does not compile there (110.79 lacks some of the
  functions it uses).

The table is in the order of the ranking below.

| # | Report | 32-bit, 110.99.9 (Linux and Windows; release and source builds) | 64-bit release | 110.79 (32-bit) | with the fixes | Upstream |
|---|---|---|---|---|---|---|
| 1 | [GC/real-corrupted-on-64-bit](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/BUGREPORT.md) | 0 | 83 in 300,000 (590 with `@SMLalloc=128k`) | n/a | 0 | the cause of [#299](https://github.com/smlnj/legacy/issues/299) (open) |
| 2 | [GC/spilled-word64-argument](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/GC/spilled-word64-argument/BUGREPORT.md): an `Int64`/`Word64` argument in the spill record | 0 | constant call wrong, then "bogus fault" | 0 | 0 | the legacy side of [#381](https://github.com/smlnj/legacy/issues/381) (open) |
| 3 | [Int64.+/carry-and-borrow](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Int64.+/carry-and-borrow/BUGREPORT.md) | 6 of 7 | 0 | other bugs | 0 | not reported |
| 4 | [Word64-low-half](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Word64-low-half/BUGREPORT.md): 64-bit literals lose bits 30 and 31 | 7 of 7 (0 in a native fixed point) | 0 | 0 | 0 | [#260](https://github.com/smlnj/legacy/issues/260), closed as fixed but not fixed |
| 5 | [Word64/shifts-and-negation](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Word64/shifts-and-negation/BUGREPORT.md) | 8 of 8 | 0 | 0 | 0 | not reported; the cause of [#373](https://github.com/smlnj/legacy/issues/373) |
| 6 | [IEEEReal.setRoundingMode/windows-no-op](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/IEEEReal.setRoundingMode/windows-no-op/BUGREPORT.md) | 7 of 7 on Windows, 0 on Linux | 0 (Linux) | 0 (Windows and Linux) | 0 | [#70](https://github.com/smlnj/legacy/issues/70) fixed it for Linux only; Windows not reported |
| 7 | [Real.ceil/conversions-to-int](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Real.ceil/conversions-to-int/BUGREPORT.md) | 4 of 12 | 9 of 12 | `ceil minPos` is 0 | 0 | not reported |
| 8 | [Int.fromLarge/fused-conversions](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Int.fromLarge/fused-conversions/BUGREPORT.md) | 2 + crash + 4 | 4 | 2 | 0 | not reported |
| 9 | [Word32.fromLarge/fused-sign-extension](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Word32.fromLarge/fused-sign-extension/BUGREPORT.md) | 2 of 5 | 5 of 5 | n/a | 0 | not reported |
| 10 | [Int64.toInt/high-word-ignored](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Int64.toInt/high-word-ignored/BUGREPORT.md) | 6 of 8 | 0 | other bugs | 0 | not reported |
| 11 | [Real.fromManExp/subnormal-is-zero](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Real.fromManExp/subnormal-is-zero/BUGREPORT.md) | 6 of 6 | 6 | 6 | 0 | [#254](https://github.com/smlnj/legacy/issues/254), closed as fixed but not fixed |
| 12 | [Real.fromLargeInt/rounds-twice](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Real.fromLargeInt/rounds-twice/BUGREPORT.md) | 31 of 148 (Linux) | 34 of 148 | n/a | 0 | not reported |
| 13 | [Real.nextAfter/subnormal-and-zero](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Real.nextAfter/subnormal-and-zero/BUGREPORT.md) | 5 of 5 | 5 | absent | 0 | not reported |

Only the literals come from how the release is made; the rest are in the
sources. The code behind 6, 7, the first part of 8, 9, 11, 12 and 13 is
the same in [smlnj/smlnj](https://github.com/smlnj/smlnj/tree/a5f3fa766c04eac403b4012414f2845006854f84) at `a5f3fa7`, so
the 2026 series has those too (6 only where it builds for Windows). The
2026 series has no `invokegc.sml`, the code behind 1. According to smlnj/smlnj
#394, 2026.3 fixes 2 with a new `CPSTransFn`. That was established by
reading the code and the issue, and no 2026 build was run.

## Ranking

Ranked by how likely a program is to meet the bug, how much harm it does,
and whether it is silent. Crashes rank below wrong answers.

1. **GC/real-corrupted-on-64-bit.** A garbage collection loses a real or
   an untagged `Word64`/`Int64` argument of a function. It happens on the
   default 64-bit platform, in every 64-bit release since the first
   (110.94). Silent and nondeterministic; a one-line fix.
2. **GC/spilled-word64-argument** (64-bit). A function of five or more
   arguments, one of them an `Int64` or `Word64` that does not fit the
   registers, reads the address of a box when the arguments are constants
   (as `Posix.IO.FLock.flock` does), and otherwise can crash the collector.
3. **Int64.+/carry-and-borrow** (32-bit). Everyday `Int64` and
   `Position.int` arithmetic is off by 2^33 whenever a carry happens, and
   `Overflow` is missed.
4. **Word64-low-half** (32-bit releases). Every negative `Int64` literal
   and many `Word64` constants are wrong, and so are the `IntInf` constants
   of the release's own compiler and Basis.
5. **Word64/shifts-and-negation** (32-bit). Silent wrong shifts, which
   also make `Real.fromString` read about 9% of reals one ulp high (#373).
6. **IEEEReal.setRoundingMode/windows-no-op** (Windows, since 110.91).
   `Real.realFloor`, `realCeil` and `realTrunc` round to nearest, which is
   wrong for about half of all non-integers, and `setRoundingMode` does
   nothing. Silent, but only on Windows, and `Real.floor` and the other
   conversions to `int` do not use the mode.
7. **Real.ceil/conversions-to-int** (all platforms).
   - `ceil` and `trunc` are one off just above an integer.
   - On 64 bits `floor`, `ceil`, `trunc` and `round` wrap around near 2^62
     instead of raising `Overflow`.
8. **Int.fromLarge/fused-conversions** (all platforms, and the 2026
   series). The Basis's own `Int.fromLarge (Word.toLargeInt w)` misses
   `Overflow`. On 32 bits there is also garbage and a compiler crash.
9. **Word32.fromLarge/fused-sign-extension** (64-bit mostly).
   `Word32.fromLargeInt (Int32.toLarge i)` makes a malformed word for a
   negative `i`.
10. **Int64.toInt/high-word-ignored** (32-bit). Silent truncation, but only
    for numbers that should raise `Overflow`.
11. **Real.fromManExp/subnormal-is-zero** (all platforms). Wrong below
    2^-1021.
12. **Real.fromLargeInt/rounds-twice** (all platforms). One ulp off for
    numbers of more than 60 or 62 bits, and in the directed rounding modes.
13. **Real.nextAfter/subnormal-and-zero** (all platforms). Edge cases of a
    rarely used function.

## Drafts for upstream

Each report's `upstream.md` is the text to post, with the fields of the
issue form, the program, a transcript and the patch filled in:

* **Comments** on [#260](https://github.com/smlnj/legacy/issues/260)
  ([Word64-low-half](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Word64-low-half/upstream.md)),
  [#373](https://github.com/smlnj/legacy/issues/373)
  ([Word64/shifts-and-negation](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Word64/shifts-and-negation/upstream.md)),
  [#254](https://github.com/smlnj/legacy/issues/254)
  ([Real.fromManExp](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Real.fromManExp/subnormal-is-zero/upstream.md)),
  [#299](https://github.com/smlnj/legacy/issues/299)
  ([the GC corruption](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/GC/real-corrupted-on-64-bit/upstream.md), with its
  cause and fix) and [#381](https://github.com/smlnj/legacy/issues/381)
  ([the spilled argument](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/GC/spilled-word64-argument/upstream.md), with a
  fix for legacy).
* **Eight new issues** on smlnj/legacy:
  - [Int64.+](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Int64.+/carry-and-borrow/upstream.md);
  - [IEEEReal.setRoundingMode on Windows](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/IEEEReal.setRoundingMode/windows-no-op/upstream.md),
    which names #70;
  - [Real.ceil](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Real.ceil/conversions-to-int/upstream.md);
  - [fused conversions](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Int.fromLarge/fused-conversions/upstream.md);
  - [fused sign extension](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Word32.fromLarge/fused-sign-extension/upstream.md);
  - [Int64.toInt](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Int64.toInt/high-word-ignored/upstream.md);
  - [Real.fromLargeInt](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Real.fromLargeInt/rounds-twice/upstream.md);
  - [Real.nextAfter](https://github.com/ruudkoot/rune/blob/8e4a5cb4a633e2ba8e7e1d26d294c53a36128259/docs/bugreport/smlnj/Real.nextAfter/subnormal-and-zero/upstream.md).

The legacy form asks for one report when the development version has the
bug too; the drafts of the all-platform bugs say so.

## Which release is good for 32 bits

None of the 110 releases gets 64-bit integers right on 32 bits. Each
release from 110.79 to 110.99.8 was installed for 32 bits
(`config/install.sh`) and given the programs of the 64-bit integer and real
reports (checked 2026-09-28). The counts are wrong lines of each report's
program:

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
    `fromManExp` is wrong below 2^-1021;
  - `Real.ceil minPos` is 0.

Rune's Basis suite (`native:smlnj32`) puts numbers on it. The failures
counted are the checks explained by `deviations.txt` and the unexplained
ones together:

| SML/NJ, 32-bit | checks | failing | where most of them are |
|---|---|---|---|
| Ubuntu 24.04's 110.79 | 61,234 | 1,770 | `Word64` 647, `Int64` 223, `Real` 142 |
| 110.87 | 61,558 | 1,963 | `Word64` 647, `Int64` 223, `Real` 140 |
| 110.99.9 | 48,968 | 1,466 | `Int64` 832; the `Word8`, `Word32`, `Word64` and `LargeWord` tests do not compile |
| 110.99.9 with the fixes | 59,401 | 645 | `Bool` 114, `IntInf` 56, `Array2` 37, `Real` 28: none in `Int64` or `Word64` |

So the last release before the break is 110.87, and 110.79 behaves the
same. Both have 64-bit integers and reals that are broken in smaller ways.
The only 32-bit SML/NJ that gets these right is 110.99.9 with the fixes of
this directory.

## What the fixes do to Rune's suites

**Basis suite** (`tests/basis/run-matrix.sh`), all twelve fixes:

| Configuration | release: checks, explained | with the fixes: checks, explained | lines that match no failure with the fixes |
|---|---|---|---|
| `native:smlnj32` | 48,968, 1,466 | 59,401, 645 | 149, 157-159, 162, 583, 693, 698-700, 774-778, 780, 781 |
| `native:smlnj` (64-bit) | 61,677, 669 | 61,677, 648 | 149, 157, 181, 182, 526, 583, 702 |

* Neither build has an unexplained failure, with or without the fixes.
  The first full run with all twelve fixes had some for each: eleven
  `Posix.Process` checks on 64 bits and `OS.FileSys.hash/spread` on 32
  bits. They passed when run alone and in a second full run.
* Line 526 (`Posix.IO.FLock.*`) goes with the fix of
  GC/spilled-word64-argument.
* The 32-bit build runs more checks because the `Word8`, `Word32`,
  `Word64` and `LargeWord` tests now compile.
* Of the lines above, only 781 (`Posix.IO.SEEK_[CE]*/negative`) also goes
  away with a native fixed point alone. The Real32.Math lines 173-175 match
  no failure in either configuration, with or without the fixes.

**Library tests** (`tests/lib/run-hosts.sh`): all four tests pass, where
the release fails `random.*` and `property.*` on 32 bits and
`property.core` on 64 bits. On 64 bits `property.core` passed 20 runs of
20. With the fixes before GC/real-corrupted-on-64-bit it passed none of
20, and with that fix but not GC/spilled-word64-argument, 10 of 20.

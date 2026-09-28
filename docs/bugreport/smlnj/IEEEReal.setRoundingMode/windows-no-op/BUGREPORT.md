# SML/NJ 110.99.9 on Windows: `IEEEReal.setRoundingMode` does nothing, so `Real.realFloor`, `realCeil` and `realTrunc` round to nearest

## Status: reported for Linux and fixed there; Windows never reported

* **The Linux report:** [smlnj/legacy#70](https://github.com/smlnj/legacy/issues/70),
  "`IEEEReal.setRoundingMode` is a no-op on Linux". It was fixed in 110.99.3
  by commit `434ec4f`, which moved Linux to `<fenv.h>`.
* **Windows:** it has had the same bug since 110.91 and was never reported
  (searched 2026-09-28).
* **The 2026 series:** smlnj/smlnj at `a5f3fa7` has the same
  `ml-osdep.h` and `fp-dep.h`, so a Windows or Cygwin build of it would
  have the bug too (by reading the code; no 2026 build was run).

**What is worth sending SML/NJ:** a new issue that names #70, with
`bug.sml` and `fix.diff` (`upstream.md` is the text).

## Summary

* **The trigger:** `IEEEReal.setRoundingMode` with a mode other than
  `TO_NEAREST`, on Windows. That includes `Real.realFloor`, `realCeil` and
  `realTrunc`, which call it.
* **What goes wrong:** the mode does not change.
  - `getRoundingMode ()` still says `TO_NEAREST`.
  - Arithmetic still rounds to nearest: `1.0 / 3.0` is the same under
    `TO_POSINF` and `TO_NEGINF`.
  - `Real.realFloor 2.7` is 3.0, `Real.realCeil 2.2` is 2.0, and
    `Real.realTrunc ~2.7` is ~3.0.
* **Required behaviour:** the
  [Basis `IEEE_REAL`](https://smlfamily.github.io/Basis/ieee-float.html) and
  [`REAL`](https://smlfamily.github.io/Basis/real.html) specifications:
  `setRoundingMode` sets the mode that arithmetic uses, and `realFloor`,
  `realCeil` and `realTrunc` round toward minus infinity, plus infinity and
  zero.

## Where it happens

| Build | wrong of 7 |
|---|---|
| Windows, the 110.99.9 release (`smlnj-110.99.9.msi`) and the source build with `config\install.bat` (Visual Studio 2022, cl 19.40, x86) | 7 |
| Windows, releases 110.91, 110.98 and 110.99.3 | 7 |
| Windows, releases 110.92, 110.93, 110.94 and 110.96 | wrong (`getRoundingMode` checked) |
| Windows, releases 110.79, 110.84 and 110.90 | 0 |
| Windows, the 110.99.9 source build with `fix.diff` | 0 |
| Linux, 110.99.9 for 32 and 64 bits | 0 |

```
C:\> sml bug.sml                        :: 110.99.9, Windows
getRoundingMode () after setRoundingMode TO_NEGINF = TO_NEAREST, expected TO_NEGINF: WRONG
getRoundingMode () after setRoundingMode TO_POSINF = TO_NEAREST, expected TO_POSINF: WRONG
getRoundingMode () after setRoundingMode TO_ZERO = TO_NEAREST, expected TO_ZERO: WRONG
1.0 / 3.0 under TO_POSINF > 1.0 / 3.0 under TO_NEGINF = false, expected true: WRONG
Real.realFloor 2.7 = 3.0, expected 2.0: WRONG
Real.realCeil 2.2 = 2.0, expected 3.0: WRONG
Real.realTrunc ~2.7 = ~3.0, expected ~2.0: WRONG
```

## The cause

`_ml_Math_ctlrndmode` (`base/runtime/c-libs/smlnj-math/ctlrndmode.c`)
calls `fegetround` and `fesetround` with the constants of
`c-libs/smlnj-math/fp-dep.h`. Which ones depends on the system:

* **Linux and macOS** (`HAS_ANSI_C_FP_EXT`, set in
  `include/ml-osdep.h`): `<fenv.h>` and its constants.
* **Win32 and Cygwin**: constants and declarations of its own:

  ```c
  #elif (defined(OPSYS_WIN32) || defined(OPSYS_CYGWIN))
  #  define FE_TONEAREST		0
  #  define FE_TOWARDZERO		3
  #  define FE_UPWARD		2
  #  define FE_DOWNWARD		1
  extern int fegetround (void);
  extern int fesetround (int);
  ```

  These are the values of the x87 control word's rounding field. They
  belonged to `fegetround` and `fesetround` routines of the x86 assembly
  code, which 110.91 removed: "Because we now assume C99 support, we can use
  the C Library functions fegetround and fesetround … Therefore, we have
  removed these from the assembly code" (its release notes).

Since then the declarations bind to the C library's C99 functions.
Microsoft's UCRT uses other values, 0x100, 0x200 and 0x300. Its
`fesetround` rejects 1, 2 and 3 (it returns 1 and changes nothing), and
`fegetround` then returns 0, which maps back to `TO_NEAREST`.
`ucrt-fesetround.c` shows it:

```
UCRT: FE_TONEAREST 0 FE_DOWNWARD 0x100 FE_UPWARD 0x200 FE_TOWARDZERO 0x300
fesetround(2), fp-dep.h's FE_UPWARD: returns 1, then fegetround() is 0 and 1/3 is 0.33333333333333331
fesetround(FE_UPWARD): returns 0, then fegetround() is 0x200 and 1/3 is 0.33333333333333338
```

Linux had the same fault, with glibc's values, until #70 was fixed by
defining `HAS_ANSI_C_FP_EXT` for Linux; Windows was left out.

`Real.realFloor`, `realCeil` and `realTrunc` (`Real/real64.sml`) set the
mode, compute `x + 2^52 - 2^52`, and set it back, so they round to nearest
on Windows.

## The fix

`fix.diff` (against smlnj/legacy `6ed5a0a`; it also applies to 110.99.9)
defines `HAS_ANSI_C_FP_EXT` for Win32 with Microsoft's compiler, which has
had `<fenv.h>` since Visual Studio 2013. `fp-dep.h` then uses `<fenv.h>`
and its constants, with `#pragma fenv_access (on)`, Microsoft's spelling of
`#pragma STDC FENV_ACCESS ON`.

With it, the arithmetic of compiled SML code follows the mode. The rebuilt
runtime, with the 110.99.9 heap, gives `bug.sml` all right, and the same
answers as Linux in every mode of `Real.fromLargeInt/rounds-twice/bug.sml`.

Cygwin keeps the old branch. Its C library, newlib, has `<fenv.h>` too, and
if its constants are not 0-3 either, Cygwin has the same fault; there was
no Cygwin build to try.

**How it was tested:** the runtime of the Windows source build was rebuilt
with `fix.diff` (`nmake -f mk.x86-win32` in `base\runtime\objs`) and run
with the heap of the same build.

## How Rune met it

`Real.fromLargeInt/rounds-twice/bug.sml`, run on the Windows release, got
twice as many directed-mode answers wrong as on Linux. Rune's Basis suite
runs SML/NJ only on Linux, so no deviation records it.

# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `IEEEReal.setRoundingMode` is a no-op on Windows (as #70 was on Linux), so `Real.realFloor`, `realCeil` and `realTrunc` round to nearest

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Windows |
| OS Version | Windows 11 (10.0.22000) |
| Processor | x86 (32-bit) |
| System Component | Basis Library |
| Severity | Major |
| Also present in the "development" version? | Yes, where it builds for Windows: `runtime/include/ml-osdep.h` and `runtime/c-libs/smlnj-math/fp-dep.h` of smlnj/smlnj `a5f3fa7` have the same code (read, not run) |

### Description

On Windows, `IEEEReal.setRoundingMode` does not change the rounding mode:
* `getRoundingMode ()` still says `TO_NEAREST`;
* arithmetic still rounds to nearest;
* `Real.realFloor 2.7` is 3.0, `Real.realCeil 2.2` is 2.0, and
  `Real.realTrunc ~2.7` is ~3.0.

This happens in the 110.99.9 MSI, in a source build with
`config\install.bat` (Visual Studio 2022), and in every Windows release I
tried from 110.91 on. 110.90 and earlier are right, and so is Linux.

### Transcript

```
C:\> sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 32-bit; November 4, 2025]
getRoundingMode () after setRoundingMode TO_NEGINF = TO_NEAREST, expected TO_NEGINF: WRONG
getRoundingMode () after setRoundingMode TO_POSINF = TO_NEAREST, expected TO_POSINF: WRONG
getRoundingMode () after setRoundingMode TO_ZERO = TO_NEAREST, expected TO_ZERO: WRONG
1.0 / 3.0 under TO_POSINF > 1.0 / 3.0 under TO_NEGINF = false, expected true: WRONG
Real.realFloor 2.7 = 3.0, expected 2.0: WRONG
Real.realCeil 2.2 = 2.0, expected 3.0: WRONG
Real.realTrunc ~2.7 = ~3.0, expected ~2.0: WRONG
```

### Expected Behavior

`ok` on every line, as on Linux.

### Steps to Reproduce

```sml
(* IEEEReal.setRoundingMode, and the functions of Real that use it. The
   divisor is in a ref, so that the division is done at run time.
   Run: sml bug.sml *)
fun modeName IEEEReal.TO_NEAREST = "TO_NEAREST" | modeName IEEEReal.TO_NEGINF = "TO_NEGINF"
  | modeName IEEEReal.TO_POSINF = "TO_POSINF" | modeName IEEEReal.TO_ZERO = "TO_ZERO"
fun show (name, got, expected) =
      print (concat [name, " = ", got, ", expected ", expected, ": ",
                     if got = expected then "ok" else "WRONG", "\n"])
fun under (mode, f) = let
      val () = IEEEReal.setRoundingMode mode
      val r = f ()
      in
        IEEEReal.setRoundingMode IEEEReal.TO_NEAREST; r
      end
val three = ref 3.0
fun third () = 1.0 / !three
val () = List.app (fn m =>
      show ("getRoundingMode () after setRoundingMode " ^ modeName m,
            under (m, fn () => modeName (IEEEReal.getRoundingMode ())), modeName m))
    [IEEEReal.TO_NEGINF, IEEEReal.TO_POSINF, IEEEReal.TO_ZERO]
val () = show ("1.0 / 3.0 under TO_POSINF > 1.0 / 3.0 under TO_NEGINF",
               Bool.toString (under (IEEEReal.TO_POSINF, third) > under (IEEEReal.TO_NEGINF, third)), "true")
fun r x = Real.fmt (StringCvt.FIX (SOME 1)) x
val () = show ("Real.realFloor 2.7", r (Real.realFloor 2.7), "2.0")
val () = show ("Real.realCeil 2.2", r (Real.realCeil 2.2), "3.0")
val () = show ("Real.realTrunc ~2.7", r (Real.realTrunc ~2.7), "~2.0")
val () = OS.Process.exit OS.Process.success
```

### Additional Information

It is #70 again, for Windows.
* **What 110.91 changed.** It removed `fegetround` and `fesetround` from the
  x86 assembly code, to use the C library's C99 functions ("Because we now
  assume C99 support…").
* **What it left.** `fp-dep.h` still gives Win32 its own
  `FE_TONEAREST`/`FE_TOWARDZERO`/`FE_UPWARD`/`FE_DOWNWARD` of 0, 3, 2 and 1,
  the values of the x87 control word, with `extern` declarations. Those
  now bind to Microsoft's UCRT, whose modes are 0, 0x100, 0x200 and 0x300.
* **What UCRT does with them.** It rejects 1-3: `fesetround(2)` returns 1
  and changes nothing.
* **Linux** was fixed for #70 (`434ec4f`) by defining `HAS_ANSI_C_FP_EXT`,
  so that `fp-dep.h` includes `<fenv.h>`.

The patch does the same for Win32 with Microsoft's compiler, which has
`<fenv.h>` since Visual Studio 2013, and uses `#pragma fenv_access (on)`
there. It is against legacy `main` (`6ed5a0a`) and also applies to
110.99.9:

```diff
diff --git a/base/runtime/c-libs/smlnj-math/fp-dep.h b/base/runtime/c-libs/smlnj-math/fp-dep.h
index 60267f0..6707b41 100644
--- a/base/runtime/c-libs/smlnj-math/fp-dep.h
+++ b/base/runtime/c-libs/smlnj-math/fp-dep.h
@@ -35,7 +35,11 @@
 #if defined(HAS_ANSI_C_FP_EXT)
 #  include <fenv.h>
 /* some compilers may ignore the fesetround() function if this is not ON */
-#pragma STDC FENV_ACCESS ON
+#  if defined(_MSC_VER)
+#    pragma fenv_access (on)
+#  else
+#    pragma STDC FENV_ACCESS ON
+#  endif
 
 typedef int fe_rnd_mode_t;
 
@@ -82,6 +86,9 @@ typedef int fe_rnd_mode_t;
 /**
  ** Win32 can set (some) alternate math paramters, but then only by re-linking
  ** with different objects.  Best to do it by hand here as well.
+ ** (Microsoft's C takes the <fenv.h> path above: its C library has the C99
+ ** fegetround and fesetround, whose modes are not the x87 values below, so
+ ** that these declarations would call them with modes they reject.)
  **/
 #  define FE_TONEAREST		0
 #  define FE_TOWARDZERO		3
diff --git a/base/runtime/include/ml-osdep.h b/base/runtime/include/ml-osdep.h
index a21199f..eaf6962 100644
--- a/base/runtime/include/ml-osdep.h
+++ b/base/runtime/include/ml-osdep.h
@@ -51,8 +51,11 @@ extern int GetPageSize (void);
 
 #endif
 
-/* support for ANSI C Floating-point extensions */
-#if defined(OPSYS_DARWIN) || defined(OPSYS_LINUX)
+/* support for ANSI C Floating-point extensions (Microsoft's C has <fenv.h>
+ * since Visual Studio 2013)
+ */
+#if defined(OPSYS_DARWIN) || defined(OPSYS_LINUX) \
+    || (defined(OPSYS_WIN32) && defined(_MSC_VER))
 #  define HAS_ANSI_C_FP_EXT
 #endif
 
```

With the runtime rebuilt this way (`nmake -f mk.x86-win32`) and the 110.99.9
heap, every line is `ok`. A known-answer test of `Real.fromLargeInt` in all
four modes then fails the same cases on Windows as on Linux, where before
it failed twice as many. Cygwin still takes the old branch and may have the
same problem; I could not try it.

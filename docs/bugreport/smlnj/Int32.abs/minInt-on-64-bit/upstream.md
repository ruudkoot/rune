# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `Int32.abs` of `Int32.minInt` does not raise `Overflow` on 64-bit systems (smlnj/smlnj#444, not fixed in legacy)

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Any |
| OS Version | Ubuntu 24.04 (WSL2) |
| Processor | x86-64 (64-bit) |
| System Component | Basis Library |
| Severity | Minor |
| Also present in the "development" version? | No: fixed by smlnj/smlnj `a9218d2` (#444), in 2026.3 |

### Description

On 64-bit systems `Int32.abs (valOf Int32.minInt)` does not raise
`Overflow`. The result prints as `~2147483648` but is 2^31 inside: it
compares greater than 0, and adding 0 to it raises `Overflow`. The 32-bit
build raises `Overflow`, as the specification asks ("It raises `Overflow`
when the result is not representable").

This is smlnj/smlnj#444, fixed in the development version by `a9218d2`.
`target64-inline.sml` of legacy `main` (`6ed5a0a`) is still as in 110.99.9:
the fix of #370 wraps the `Int32` operations in `i32chk`, but `abs` is
outside the wrapped group.

### Transcript

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
Int32.~ minInt = Overflow: ok
Int32.abs minInt = ~2147483648: WRONG
Int32.abs minInt > 0 = true: WRONG
Int32.toLarge (Int32.abs minInt) = ~2147483648: WRONG
Int32.abs minInt + 0 = Overflow: ok
```

### Expected Behavior

`Overflow` on every line, as on the 32-bit build.

### Steps to Reproduce

```sml
(* Int32.abs of Int32.minInt. The specification of INTEGER: abs i raises
   Overflow "when the result is not representable", and Int32.~
   of minInt does raise it. Every line should be Overflow. Run: sml bug.sml *)
fun show (name, f) =
      let val got = (f ()) handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ": ", if got = "Overflow" then "ok" else "WRONG", "\n"])
      end
val r = ref (valOf Int32.minInt)        (* so that nothing is folded at compile time *)
val () = show ("Int32.~ minInt", fn () => Int32.toString (Int32.~ (!r)))
val () = show ("Int32.abs minInt", fn () => Int32.toString (Int32.abs (!r)))
val () = show ("Int32.abs minInt > 0", fn () => Bool.toString (Int32.abs (!r) > 0))
val () = show ("Int32.toLarge (Int32.abs minInt)", fn () => LargeInt.toString (Int32.toLarge (Int32.abs (!r))))
val () = show ("Int32.abs minInt + 0", fn () => Int32.toString (Int32.abs (!r) + 0))
val () = OS.Process.exit OS.Process.success
```

### Additional Information

The patch is `a9218d2` of smlnj/smlnj applied to legacy: `abs` moves into
the `local` and is wrapped in `i32chk`, like `~`. It is against legacy
`main` (`6ed5a0a`) and also applies to 110.99.9:

```diff
diff --git a/base/system/smlnj/init/target64-inline.sml b/base/system/smlnj/init/target64-inline.sml
index 809777a..e33eb3b 100644
--- a/base/system/smlnj/init/target64-inline.sml
+++ b/base/system/smlnj/init/target64-inline.sml
@@ -197,11 +197,11 @@ structure InlineT =
         val op >=   : int32 * int32 -> bool   = InLine.int32_ge
         val op =    : int32 * int32 -> bool   = InLine.int32_eql
         val op <>   : int32 * int32 -> bool   = InLine.int32_neq
-	end (* local *)
 
         val min     : int32 * int32 -> int32  = InLine.int32_min
         val max     : int32 * int32 -> int32  = InLine.int32_max
-        val abs     : int32 -> int32          = InLine.int32_abs
+        val abs     : int32 -> int32          = i32chk InLine.int32_abs
+	end (* local *)
       end
 
     structure Int64 =
```

Not built: `i32chk` defined as in `target64-inline.sml` (with
`Unsafe.cast`) around `Int32.abs`, in a standalone program on 110.99.9
(64-bit), raises `Overflow` for `minInt` and agrees with `Int32.abs` on
100,005 other values.

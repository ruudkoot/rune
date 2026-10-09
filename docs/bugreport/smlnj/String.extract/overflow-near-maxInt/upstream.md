# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `String.extract (s, i, SOME j)` near `Int.maxInt` crashes the system instead of raising `Subscript`

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Any |
| OS Version | Ubuntu 24.04 (WSL2) |
| Processor | Any |
| System Component | Basis Library |
| Severity | Minor |
| Also present in the "development" version? | Yes: 2026.2 dies the same way, and `system/Basis/Implementation/string.sml` of smlnj/smlnj `033dd76` has the same code |

### Description

`String.extract (s, i, SOME j)` checks its region with an addition that
does not test for `Overflow` (`++`, `InlineT.Int.fast_add`). When `i + j`
passes `Int.maxInt` the sum wraps round, the region passes, and `extract`
either reads the character at index `i` or allocates `j` characters. The
system dies instead of raising `Subscript`.

### Transcript

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
String.substring ("abcde", 1, big) (for contrast): Subscript (expected)
/home/.../bin/sml: Fatal error -- bogus overflow fault: pc = 0x784d65cc29b9, sig = 11
```

`String.extract ("abcde", 1, SOME big)` alone ends with `Fatal error --
unable to allocate minimum size`.

### Expected Behavior

`Subscript`, as the specification says ("It raises Subscript if i < 0 or
j < 0 or |s| < i + j") and as `String.substring` does for the same
arguments.

### Steps to Reproduce

```sml
fun check name f =
  (ignore (f ()); print (name ^ ": UNEXPECTED no exception\n"))
  handle Subscript => print (name ^ ": Subscript (expected)\n")
       | e => print (name ^ ": " ^ General.exnName e ^ " (WRONG: expected Subscript)\n")

val big = valOf Int.maxInt
val () = check "String.substring (\"abcde\", 1, big) (for contrast)" (fn () => String.substring ("abcde", 1, big))
val () = check "String.extract (\"abcde\", big, SOME 1)" (fn () => String.extract ("abcde", big, SOME 1))
val () = check "String.extract (\"abcde\", big, SOME big)" (fn () => String.extract ("abcde", big, SOME big))
val () = check "String.extract (\"abcde\", 1, SOME big)" (fn () => String.extract ("abcde", 1, SOME big))
```

### Additional Information

The patch tests without adding (`len <= base` for one character,
`len < base orelse len -- base < n` otherwise). It is against legacy `main`
(`12f1dfe`), whose file is that of 110.99.9; with `system/` for
`base/system/` it applies to smlnj/smlnj `main` too:

```diff
--- a/base/system/Basis/Implementation/string.sml
+++ b/base/system/Basis/Implementation/string.sml
@@ -93,11 +93,11 @@
 		      then ""
 		      else newVec (len - base)
 	      | (_, SOME 1) =>
-		  if ((base < 0) orelse (len < (base ++ 1)))
+		  if ((base < 0) orelse (len <= base))
 		    then raise General.Subscript
 		    else str(unsafeSub(v, base))
 	      | (_, SOME n) =>
-		  if ((base < 0) orelse (n < 0) orelse (len < (base ++ n)))
+		  if ((base < 0) orelse (n < 0) orelse (len < base) orelse ((len -- base) < n))
 		    then raise General.Subscript
 		    else newVec n
 	    (* end case *)
```

Tested by compiling `extract` with the patch as a program on 110.99.9 (with
stand-ins for the compiler's primitives), not by rebuilding the Basis.

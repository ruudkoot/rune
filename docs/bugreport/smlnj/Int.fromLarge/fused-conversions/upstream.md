# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** Fused integer conversions: `Int.fromLarge (Word.toLargeInt w)` does not raise `Overflow`; on 32-bit systems conversions through 64 bits crash the compiler or give wrong results

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Any |
| OS Version | Ubuntu 24.04 (WSL2); Windows 11 (10.0.22000) |
| Processor | x86 (32-bit), x86-64 (64-bit) |
| System Component | Core system |
| Severity | Major |
| Also present in the "development" version? | Yes: the rule of the first part is the same in smlnj/smlnj `a5f3fa7` `compiler/CPS/opt/contract-prim.sml` (read, not run) |

### Description

`ContractPrim` fuses two conversions into one, and some of its rules are
wrong.

1. **All targets.** A word converted to a signed integer through
   `IntInf`, as the Basis prescribes, keeps a number that does not fit
   instead of raising `Overflow`: the fused conversion reads it as signed.
   - `Int.fromLarge (Word.toLargeInt (Word.notb 0w0))` is `~1`.
   - `Int32.fromLarge (Word32.toLargeInt 0wxFFFFFFFF)` is `~1`.
   - 64-bit: `Int.fromLarge (Word64.toLargeInt 0wxFFFFFFFFFFFFFFFF)` is `~1`.

   In two steps, with nothing to fuse, the result is `Overflow`.
2. **32-bit targets.** `fn w => Int.fromLarge (Word64.toLargeInt w)` and
   `fn i => Int.fromLarge (Int64.toLarge i)` do not compile: "Error:
   Compiler bug: Num64Cnv: test64To".
3. **32-bit targets.** A fused conversion between 64 bits and 32 or
   fewer gives garbage:
   - `Int64.toInt (Int64.fromLarge 5)` is `0`.
   - `Word32.fromLarge (Word64.fromLargeInt 0x200000005)` is `2`.
   - `Word64.toLargeInt (Word32.toLarge 0wx1)` is `4294967297`.

### Transcript

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 32-bit; November 4, 2025]
Int.fromLarge (Word.toLargeInt (Word.notb 0w0)) = ~1, expected Overflow: WRONG
Int32.fromLarge (Word32.toLargeInt 0wxFFFFFFFF) = ~1, expected Overflow: WRONG
Int32.fromLarge 4294967295 = Overflow, expected Overflow: ok
$ sml bug-64.sml
Standard ML of New Jersey [Version 110.99.9; 32-bit; November 4, 2025]
Error: Compiler bug: Num64Cnv: test64To
$ sml bug-32.sml
Standard ML of New Jersey [Version 110.99.9; 32-bit; November 4, 2025]
Int64.toInt (Int64.fromLarge 5) = 0, expected 5: WRONG
Word32.fromLarge (Word64.fromLargeInt 0x200000005) = 2, expected 5: WRONG
Word64.toLargeInt (Word32.toLarge 0wx1) = 4294967297, expected 1: WRONG
Int64.toLarge (Int64.fromLarge (Int32.toLarge ~7)) = ~30064771065, expected ~7: WRONG
$ sml bug-64.sml     # 64-bit build
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
Int.fromLarge (Word64.toLargeInt 0wxFFFFFFFFFFFFFFFF) = ~1, expected Overflow: WRONG
Int64.fromLarge (Word64.toLargeInt 0wxFFFFFFFFFFFFFFFF) = ~1, expected Overflow: WRONG
Int.fromLarge (Int64.toLarge 5) = 5, expected 5
```

### Expected Behavior

`Overflow` for the first two lines of the first program and all of the
second; `5`, `5`, `1` and `~7` in the third.

### Steps to Reproduce

The arguments are read at run time or passed to a function, so that the
conversions are fused but not folded.

All targets:

```sml
(* Int.fromLarge (Word.toLargeInt w) and the like, for a w whose value does
   not fit the integer type: the Basis has Overflow. Run: sml bug.sml *)
fun show (name, f) =
      let val got = f () handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected Overflow: ",
                        if got = "Overflow" then "ok" else "WRONG", "\n"])
      end
fun fromWord (w : word) = Int.fromLarge (Word.toLargeInt w)
val () = show ("Int.fromLarge (Word.toLargeInt (Word.notb 0w0))",
               fn () => Int.toString (fromWord (Word.notb 0w0)))
fun fromWord32 (w : Word32.word) = Int32.fromLarge (Word32.toLargeInt w)
val () = show ("Int32.fromLarge (Word32.toLargeInt 0wxFFFFFFFF)",
               fn () => Int32.toString (fromWord32 0wxFFFFFFFF))
(* the same conversion in two steps, which the optimizer does not fuse *)
val big = Word32.toLargeInt 0wxFFFFFFFF;
val () = show ("Int32.fromLarge 4294967295",
               fn () => Int32.toString (Int32.fromLarge big))
val () = OS.Process.exit OS.Process.success
```

64-bit values (the compiler bug on 32-bit targets):

```sml
(* The same with Word64 and Int64. For 64 bits, the first two lines print ~1;
   for 32 bits, the compiler stops with "Compiler bug: Num64Cnv: test64To".
   Run: sml bug-64.sml *)
fun show (name, f) =
      let val got = f () handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected ", "Overflow: ",
                        if got = "Overflow" then "ok" else "WRONG", "\n"])
      end
fun toInt (w : Word64.word) = Int.fromLarge (Word64.toLargeInt w)
val () = show ("Int.fromLarge (Word64.toLargeInt 0wxFFFFFFFFFFFFFFFF)",
               fn () => Int.toString (toInt 0wxFFFFFFFFFFFFFFFF))
fun toInt64 (w : Word64.word) = Int64.fromLarge (Word64.toLargeInt w)
val () = show ("Int64.fromLarge (Word64.toLargeInt 0wxFFFFFFFFFFFFFFFF)",
               fn () => Int64.toString (toInt64 0wxFFFFFFFFFFFFFFFF))
fun narrow (i : Int64.int) = Int.fromLarge (Int64.toLarge i)
val () = print ("Int.fromLarge (Int64.toLarge 5) = " ^ Int.toString (narrow 5) ^ ", expected 5\n")
val () = OS.Process.exit OS.Process.success
```

32-bit targets:

```sml
(* Two conversions that the optimizer fuses into one, where one side is 64
   bits and the other at most 32; each argument is read from a string at run
   time. For 32 bits, the fused conversion is given the "_Core" function of the
   other size. Run: sml bug-32.sml *)
fun int s = valOf (IntInf.fromString s)
fun show (name, f, expected) =
      let val got = f () handle Overflow => "Overflow"
      in print (concat [name, " = ", got, ", expected ", expected, ": ",
                        if got = expected then "ok" else "WRONG", "\n"])
      end
fun a (x : IntInf.int) = Int64.toInt (Int64.fromLarge x)
val () = show ("Int64.toInt (Int64.fromLarge 5)", fn () => Int.toString (a (int "5")), "5")
fun b (x : IntInf.int) = Word32.fromLarge (Word64.fromLargeInt x)
val () = show ("Word32.fromLarge (Word64.fromLargeInt 0x200000005)", fn () => Word32.toString (b (int "8589934597")), "5")
fun c (w : Word32.word) = Word64.toLargeInt (Word32.toLarge w)
val () = show ("Word64.toLargeInt (Word32.toLarge 0wx1)", fn () => IntInf.toString (c (Word32.fromLargeInt (int "1"))), "1")
fun d (i : Int32.int) = Int64.toLarge (Int64.fromLarge (Int32.toLarge i))
val () = show ("Int64.toLarge (Int64.fromLarge (Int32.toLarge ~7))", fn () => IntInf.toString (d (Int32.fromLarge (int "~7"))), "~7")
val () = OS.Process.exit OS.Process.success
```

### Additional Information

In `CPS/opt/contract-prim.sml`:

1. **Signed tests of an unsigned copy.** `COPY` and `COPY_INF` are zero
   extensions, but two rules replace a signed test of one with a copy:
   ```
   TEST(∞,p) o COPY(m,∞) ==> COPY(m,p) when (p >= m), TEST(m,p) when (p < m)
   TEST(n,p) o COPY(m,n) ==> COPY(m,p) if (p >= m), TEST(m,p) if (p < m)
   ```
   An m-bit word with its top bit set does not fit m signed bits. The
   results should be `COPY(m,p)` only for `p > m`, and `TESTU(m,p)`
   otherwise, as the `TESTU` rules already have it. On 64-bit, the second
   rule also makes `Word64.toIntX (Word32.toLarge 0wxFFFFFFFF)` `~1`.
2. **`TEST` from 64 bits without its argument.** On 32-bit targets a `TEST`
   or `TESTU` from 64 bits needs the extra conversion argument, and the
   `TEST_INF` rules create `TEST{from=64, ...}` without it, so
   `Num64Cnv.test64To` fails.
3. **The wrong conversion function.** The `_INF` conversions carry the
   conversion function for their size (`pickName` in
   FLINT/trans/transprim.sml). On 32-bit targets the 64-bit one works on
   pairs of words. `TEST o TEST_INF`, `TRUNC o TRUNC_INF`, `COPY_INF o COPY`
   and `EXTEND_INF o EXTEND/COPY` change the size and keep the function.

The patch fixes the signedness, leaves a 64-bit `TEST_INF` fusion alone on
32-bit targets, and guards the four size-changing rules with a
`sameInfFn (n, m)` that is always true on 64-bit targets. It is against
legacy `main` (`6ed5a0a`) and also applies to 110.99.9:

```diff
diff --git a/base/compiler/CPS/opt/contract-prim.sml b/base/compiler/CPS/opt/contract-prim.sml
index 1d35189..284b927 100644
--- a/base/compiler/CPS/opt/contract-prim.sml
+++ b/base/compiler/CPS/opt/contract-prim.sml
@@ -148,6 +148,14 @@ structure ContractPrim : sig
           then Val arg
           else Pure(P.COPY{from=from, to=to}, [arg])
 
+  (* The `_INF` conversions have an extra argument: the "_Core" conversion function
+   * for their size (see `pickName` in FLINT/trans/transprim.sml).  On 32-bit targets,
+   * the function for 64 bits works on pairs of 32-bit words and the one for the other
+   * sizes on single words, so a contraction may give the function of a conversion of
+   * size n to a conversion of size m only when `sameInfFn(n, m)`.
+   *)
+    fun sameInfFn (n, m) = Target.is64 orelse ((n > 32) = (m > 32))
+
   (* contraction for impure arithmetic operations; note that 64-bit IMUL, IDIV,
    * IMOD, IQUOT, and IREM have three arguments on 32-bit targets, so we need
    * to allow for the extra argument in the patterns.
@@ -230,15 +238,18 @@ structure ContractPrim : sig
                          of ARITHinfo(P.TEST{from=m, ...}, args) =>
                               (* TEST(n,p) o TEST(m,n) ==> TEST(m, p) *)
                               Arith(P.TEST{from=m, to=p}, args)
-                          | ARITHinfo(P.TEST_INF _, [u, f]) =>
+                          | ARITHinfo(P.TEST_INF _, [u, f]) => if sameInfFn(n, p)
                               (* TEST(n,p) o TEST(∞,n) ==> TEST(∞, p) *)
-                              Arith(P.TEST_INF p, [u, f])
+                              then Arith(P.TEST_INF p, [u, f])
+                              else None
                           | PUREinfo(P.COPY{from=m, ...}, [u]) =>
-                              if (p >= m)
-                                (* TEST(n,p) o COPY(m,n) ==> COPY(m, p) if (p >= m) *)
+                              if (p > m)
+                                (* TEST(n,p) o COPY(m,n) ==> COPY(m, p) if (p > m) *)
                                 then mkCOPY(m, p, u)
-                                (* TEST(n,p) o COPY(m,n) ==> TEST(m, p) if (p < m) *)
-                                else Arith(P.TEST{from=m, to=p}, [u])
+                                (* COPY is unsigned, so
+                                 * TEST(n,p) o COPY(m,n) ==> TESTU(m, p) if (p <= m)
+                                 *)
+                                else Arith(P.TESTU{from=m, to=p}, [u])
                           | PUREinfo(P.EXTEND{from=m, ...}, [u]) =>
                               if (p >= m)
                                 (* TEST(n,p) o EXTEND(m,n) ==> EXTEND(m, p) if (p >= m) *)
@@ -278,19 +289,26 @@ structure ContractPrim : sig
             (***** TEST_INF *****
              *
              * Note that `TEST_INF` will have an extra argument (the
-             * `Core.testInf` function).
+             * `Core.testInf` function).  `COPY_INF` is unsigned, so the
+             * test that replaces a `TEST_INF` of it is a `TESTU`.  On 32-bit
+             * targets, a `TEST` or `TESTU` from 64 bits needs an extra argument
+             * that we do not have here, so we leave those cases alone.
              *)
             | (P.TEST_INF p, VAR v::_) => (case #info(get v)
-                 of PUREinfo(P.COPY_INF m, u::_) => if (p >= m)
-                      (* TEST(∞,p) o COPY(m,∞) ==> COPY(m,p) when (p >= m) *)
+                 of PUREinfo(P.COPY_INF m, u::_) => if (p > m)
+                      (* TEST(∞,p) o COPY(m,∞) ==> COPY(m,p) when (p > m) *)
                       then mkCOPY(m, p, u)
-                      (* TEST(∞,p) o COPY(m,∞) ==> TEST(m,p) when (p < m) *)
-                      else Arith(P.TEST{from=m, to=p}, [u])
+                      else if (m > 32) andalso not Target.is64
+                        then None
+                      (* TEST(∞,p) o COPY(m,∞) ==> TESTU(m,p) when (p <= m) *)
+                        else Arith(P.TESTU{from=m, to=p}, [u])
                   | PUREinfo(P.EXTEND_INF m, u::_) => if (p >= m)
                       (* TEST(∞,p) o EXTEND(m,∞) ==> EXTEND(m,p) when (p >= m) *)
                       then Pure(P.EXTEND{from=m, to=p}, [u])
+                      else if (m > 32) andalso not Target.is64
+                        then None
                       (* TEST(∞,p) o EXTEND(m,∞) ==> TEST(m,p) when (p < m) *)
-                      else Arith(P.TEST{from=m, to=p}, [u])
+                        else Arith(P.TEST{from=m, to=p}, [u])
                   | _ => None
                 (* end case *))
             | _ => None
@@ -455,9 +473,10 @@ structure ContractPrim : sig
                          of PUREinfo(P.TRUNC{from=m, ...}, arg) =>
                               (* TRUNC(n,p) o TRUNC(m,n) ==> TRUNC(m,p) *)
                               Pure(P.TRUNC{from=m, to=p}, arg)
-                          | PUREinfo(P.TRUNC_INF _, arg) =>
+                          | PUREinfo(P.TRUNC_INF _, arg) => if sameInfFn(n, p)
                               (* TRUNC(n,p) o TRUNC(∞,n) ==> TRUNC(∞,p) *)
-                              Pure(P.TRUNC_INF p, arg)
+                              then Pure(P.TRUNC_INF p, arg)
+                              else None
                           | PUREinfo(P.COPY{from=m, ...}, [u]) =>
                               if (p >= m)
                                 (* TRUNC(n,p) o COPY(m,n) ==> COPY(m,p) if (p >= m) *)
@@ -475,18 +494,22 @@ structure ContractPrim : sig
                     | _ => bug "bogus argument to TRUNC"
                   (* end case *))
             (***** COPY_INF *****)
-            | (P.COPY_INF _, [VAR v, f]) => (case #info(get v)
-                 of PUREinfo(P.COPY{from=m, ...}, [u]) =>
+            | (P.COPY_INF n, [VAR v, f]) => (case #info(get v)
+                 of PUREinfo(P.COPY{from=m, ...}, [u]) => if sameInfFn(n, m)
                       (* COPY(n,∞) o COPY(m,n) ==> COPY(m,∞) *)
-                      Pure(P.COPY_INF m, [u, f])
+                      then Pure(P.COPY_INF m, [u, f])
+                      else None
                   | _ => None
                 (* end case *))
             (***** EXTEND_INF *****)
             | (P.EXTEND_INF n, [VAR v, f]) => (case #info(get v)
-                 of PUREinfo(P.EXTEND{from=m, ...}, [u]) =>
+                 of PUREinfo(P.EXTEND{from=m, ...}, [u]) => if sameInfFn(n, m)
                       (* EXTEND(n,∞) o EXTEND(m,n) ==> EXTEND(m,∞) *)
-                      Pure(P.EXTEND_INF m, [u, f])
-                  | PUREinfo(P.COPY{from=m, ...}, [u]) => if (m < n)
+                      then Pure(P.EXTEND_INF m, [u, f])
+                      else None
+                  | PUREinfo(P.COPY{from=m, ...}, [u]) => if not (sameInfFn(n, m))
+                      then None
+                    else if (m < n)
                       (* EXTEND(n,∞) o COPY(m,n) ==> COPY(m,∞) when (m < n) *)
                       then Pure(P.COPY_INF m, [u, f])
                       (* EXTEND(n,∞) o COPY(m,n) ==> EXTEND(m,∞) when (m = n) *)
```

Tested with a fixed point for 32 and 64 bits and with cross-compiled x86-unix
and x86-win32 boot files. A check of every conversion between `int`,
`Int32`, `Int64`, `word`, `Word8`, `Word32` and `Word64` on 31 numbers,
against results computed with `IntInf`, went as follows:
* the 64-bit release gets 78 of 3,184 wrong, and the 32-bit build does not
  compile it;
* with this patch and those filed alongside (the `Int64.toInt` check and the
  64-bit literals), the 32-bit build gets none of 2,989 wrong;
* the 64-bit build gets 19 wrong, from a separate 64-bit bug that I have not
  looked into: `Word32.fromLargeInt (Int32.toLarge ~1)` and
  `Word32.fromLarge (Word8.toLargeX 0wxFF)` give a `Word32.word` that prints
  as `7FFFFFFFFFFFFFFF`.

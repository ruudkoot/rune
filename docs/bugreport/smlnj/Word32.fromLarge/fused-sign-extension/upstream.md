# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** A fused sign extension makes a malformed `Word32` on 64-bit systems, and `Word64.toInt (Word8.toLargeX w)` misses `Overflow`

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Any |
| OS Version | Ubuntu 24.04 (WSL2); Windows 11 (10.0.22000) |
| Processor | x86 (32-bit), x86-64 (64-bit) |
| System Component | Core system |
| Severity | Major |
| Also present in the "development" version? | Yes: the rules are the same in `compiler/CPS/opt/contract-prim.sml` of smlnj/smlnj `a5f3fa7` (read, not run) |

### Description

`ContractPrim` fuses a conversion of a sign-extended value into one
`EXTEND`, which is wrong in two ways:

* **64-bit:** a `Word32.word` made from a negative number keeps the sign in
  its upper bits. `Word32.fromLargeInt (Int32.toLarge ~1)` prints as
  `7FFFFFFFFFFFFFFF`, is not equal to `0wxFFFFFFFF`, and its `toLargeInt`
  is 2^63 - 1.
* **Both widths:** `Word64.toInt (Word8.toLargeX 0wxFF)` is `~1`; the word
  2^64 - 1 does not fit `int`.

### Transcript

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
Word32.fromLargeInt (Int32.toLarge ~1) = 7FFFFFFFFFFFFFFF, expected FFFFFFFF: WRONG
Word32.toLargeInt (Word32.fromLargeInt (Int32.toLarge ~1)) = 9223372036854775807, expected 4294967295: WRONG
Word32.fromLarge (Word8.toLargeX 0wxFF) = 7FFFFFFFFFFFFFFF, expected FFFFFFFF: WRONG
Word64.toInt (Word8.toLargeX 0wxFF) = ~1, expected Overflow: WRONG
Word32.toInt (Word32.fromLarge (Word8.toLargeX 0wxFF)) = ~1, expected 4294967295: WRONG
```

On 32 bits the last two lines are wrong.

### Expected Behavior

The expected value of each line. MLton and Poly/ML print `ok` throughout.

### Steps to Reproduce

```sml
(* Conversions through a sign extension that the optimizer fuses: a word made
   from a signed value, and an unsigned test of a sign-extended word. The
   arguments are read at run time. Run: sml bug.sml *)
fun show (name, got, expected) =
      print (concat [name, " = ", got, ", expected ", expected, ": ",
                     if got = expected then "ok" else "WRONG", "\n"])
fun r f = f () handle Overflow => "Overflow"
val m1 = valOf (Int32.fromString "~1")
val ff = valOf (Word8.fromString "FF")
fun a (i : Int32.int) = Word32.fromLargeInt (Int32.toLarge i)
val () = show ("Word32.fromLargeInt (Int32.toLarge ~1)", Word32.toString (a m1), "FFFFFFFF")
val () = show ("Word32.toLargeInt (Word32.fromLargeInt (Int32.toLarge ~1))",
               IntInf.toString (Word32.toLargeInt (a m1)), "4294967295")
fun b (w : Word8.word) = Word32.fromLarge (Word8.toLargeX w)
val () = show ("Word32.fromLarge (Word8.toLargeX 0wxFF)", Word32.toString (b ff), "FFFFFFFF")
fun c (w : Word8.word) = Word64.toInt (Word8.toLargeX w)
val () = show ("Word64.toInt (Word8.toLargeX 0wxFF)", r (fn () => Int.toString (c ff)), "Overflow")
fun d (w : Word8.word) = Word32.toInt (Word32.fromLarge (Word8.toLargeX w))
val () = show ("Word32.toInt (Word32.fromLarge (Word8.toLargeX 0wxFF))", r (fn () => Int.toString (d ff)),
               if Word.wordSize > 32 then "4294967295" else "Overflow")
val () = OS.Process.exit OS.Process.success
```

### Additional Information

In `CPS/opt/contract-prim.sml`:

* **`TRUNC(n,p) o EXTEND(m,n) ==> EXTEND(m,p)` if p >= m**, and the same
  for `TRUNC_INF o EXTEND_INF`. `TRUNC` makes a word, which must be 0 above
  its p bits. `EXTEND` fills them with the sign, which does no harm only when
  p is the whole representation. On a 64-bit target a `Word32` is a tagged
  63-bit value, and with m = p = 32 the extension is the identity, so an
  `Int32` -1 becomes a `Word32` -1.
* **`TESTU(n,p) o EXTEND(m,n) ==> EXTEND(m,p)` if p >= m.** Read as
  unsigned, a negative extended value is 2^n more than itself, which no
  single `EXTEND` gives.

The patch lets the `TRUNC` rules fuse only when
`p >= Target.defaultIntSz`, and the `TESTU` rule not for p >= m. It is
against legacy `main` (`6ed5a0a`) and also applies to 110.99.9:

```diff
diff --git a/base/compiler/CPS/opt/contract-prim.sml b/base/compiler/CPS/opt/contract-prim.sml
index 1d35189..3b0fb3d 100644
--- a/base/compiler/CPS/opt/contract-prim.sml
+++ b/base/compiler/CPS/opt/contract-prim.sml
@@ -269,8 +269,10 @@ structure ContractPrim : sig
                         else Arith(P.TESTU{from=m, to=p}, [u])
                   | PUREinfo(P.EXTEND{from=m, ...}, [u]) =>
                       if (p >= m)
-                        (* TESTU(n,p) o EXTEND(m,n) ==> EXTEND(m, p) if (p >= m) *)
-                        then Pure(P.EXTEND{from=m, to=p}, [u])
+                        (* a negative number, extended to n bits and read as unsigned,
+                         * is 2^n more than itself, which one conversion cannot say
+                         *)
+                        then None
                         (* TESTU(n,p) o EXTEND(m,n) ==> TESTU(m, p) if (p < m) *)
                         else Arith(P.TESTU{from=m, to=p}, [u])
                   | _ => None
@@ -466,8 +468,14 @@ structure ContractPrim : sig
                                 else Pure(P.TRUNC{from=m, to=p}, [u])
                           | PUREinfo(P.EXTEND{from=m, to=n}, arg) =>
                               if (p >= m)
-                                (* TRUNC(n,p) o EXTEND(m,n) ==> EXTEND(m,p) if (p >= m) *)
-                                then Pure(P.EXTEND{from=m, to=p}, arg)
+                                (* TRUNC(n,p) o EXTEND(m,n) ==> EXTEND(m,p) if (p >= m),
+                                 * when p bits are the whole of the representation; a
+                                 * word of fewer bits must be 0 above them, and EXTEND
+                                 * fills them with the sign
+                                 *)
+                                then if (p >= Target.defaultIntSz)
+                                  then Pure(P.EXTEND{from=m, to=p}, arg)
+                                  else None
                                 (* TRUNC(n,p) o EXTEND(m,n) ==> TRUNC(m,p) if (p < m) *)
                                 else Pure(P.TRUNC{from=m, to=p}, arg)
                           | _ => None
@@ -501,8 +509,12 @@ structure ContractPrim : sig
                       (* TRUNC(∞,p) o COPY(m,∞) ==> TRUNC(m,p) when (m > p) *)
                       else Pure(P.TRUNC{from=m, to=p}, [u])
                   | PUREinfo(P.EXTEND_INF m, [u, _]) => if (p >= m)
-                      (* TRUNC(∞,p) o EXTEND(m,∞) ==> EXTEND(m,p) when (p >= m) *)
-                      then Pure(P.EXTEND{from=m, to=p}, [u])
+                      (* TRUNC(∞,p) o EXTEND(m,∞) ==> EXTEND(m,p) when (p >= m), and
+                       * p bits are the whole of the representation (see TRUNC)
+                       *)
+                      then if (p >= Target.defaultIntSz)
+                        then Pure(P.EXTEND{from=m, to=p}, [u])
+                        else None
                       (* TRUNC(∞,p) o EXTEND(m,∞) ==> TRUNC(m,p) when (m > p) *)
                       else Pure(P.TRUNC{from=m, to=p}, [u])
                   | _ => None
```

Tested with a fixed point for 32 and 64 bits. A check of every conversion
between `int`, `Int32`, `Int64`, `word`, `Word8`, `Word32` and `Word64` on 31
numbers against `IntInf` then has no wrong result on either (together with
the fix for the fused-conversions issue filed alongside).

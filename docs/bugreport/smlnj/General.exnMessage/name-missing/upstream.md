# Draft: new issue on smlnj/legacy

Where: https://github.com/smlnj/legacy/issues/new?template=00_bug_report.yaml

**Title:** `exnMessage` of `Div`, `Overflow`, `Subscript` and four other Basis exceptions does not contain `exnName`

| Field | Value |
|---|---|
| Version | 110.99.9 (Latest) |
| Operating System | Any |
| OS Version | Ubuntu 24.04 (WSL2) |
| Processor | Any |
| System Component | Basis Library |
| Severity | Minor |
| Also present in the "development" version? | Yes: 2026.2 prints the same, and `exn-name.sml` of smlnj/smlnj `17362d2` is the same file |

### Description

The Basis specification of `General.exnMessage` says the message "will at
least contain the string `exnName ex`", and gives `exnMessage Div = "Div"`
as its example. SML/NJ's `exnMessage` of `Bind`, `Match`, `Div`, `Domain`,
`Overflow`, `Size` and `Subscript` is a phrase without the name:
`"divide by zero"`, `"overflow"`, `"size"`, ... The same on 32 and 64
bits, and in 2026.2.

### Transcript

```
$ sml bug.sml
Standard ML of New Jersey [Version 110.99.9; 64-bit; November 4, 2025]
exnMessage Bind = "nonexhaustive binding failure": WRONG (no "Bind")
exnMessage Match = "nonexhaustive match failure": WRONG (no "Match")
exnMessage Div = "divide by zero": WRONG (no "Div")
exnMessage Domain = "domain error": WRONG (no "Domain")
exnMessage Overflow = "overflow": WRONG (no "Overflow")
exnMessage Size = "size": WRONG (no "Size")
exnMessage Subscript = "subscript out of bounds": WRONG (no "Subscript")
exnMessage Chr = "Chr": ok
exnMessage Empty = "Empty": ok
exnMessage Option = "Option": ok
exnMessage Span = "Span": ok
exnMessage Fail = "Fail: why": ok
exnMessage SysErr = "SysErr: No such file": ok
```

### Expected Behavior

A message that contains `exnName ex`, e.g. `"Div"` or
`"Div: divide by zero"`. MLton, Poly/ML and MLKit give `"Div"`,
`"Overflow"` and so on.

### Steps to Reproduce

```sml
(* General.exnMessage of the Basis's own exceptions. The specification: the
   message "will at least contain the string exnName ex", with the example
   exnMessage Div = "Div". Run: sml bug.sml *)
fun show ex =
      let val name = exnName ex
          val msg = exnMessage ex
      in print (concat ["exnMessage ", name, " = \"", String.toString msg, "\": ",
                        if String.isSubstring name msg then "ok" else "WRONG (no \"" ^ name ^ "\")", "\n"])
      end
val () = List.app show [Bind, Match, Div, Domain, Overflow, Size, Subscript,
                        Chr, Empty, Option, Span, Fail "why", OS.SysErr ("No such file", NONE)]
val () = OS.Process.exit OS.Process.success
```

### Additional Information

`exn-name.sml` gives these seven a phrase of their own. The patch puts the
name in front of the five phrases that say more than the name, as the
clause for `Fail` does (`"Div: divide by zero"`), and lets `Size` and
`Overflow`, whose phrases are only the name in lower case, fall through to
`exnName e`. The REPL would then print `uncaught exception Div [Div: divide
by zero]`, as it prints `uncaught exception Fail [Fail: why]`. It is against
legacy `main` (`6ed5a0a`) and also applies to 110.99.9 and, with `-p2`, to
smlnj/smlnj:

```diff
diff --git a/base/system/Basis/Implementation/exn-name.sml b/base/system/Basis/Implementation/exn-name.sml
index 0ad599a..aadcd94 100644
--- a/base/system/Basis/Implementation/exn-name.sml
+++ b/base/system/Basis/Implementation/exn-name.sml
@@ -39,13 +39,12 @@ structure ExnName : sig
 	  end
       | exnMessage (Fail s) = "Fail: " ^ s
 (** NOTE: we should probably include line/file info for Match and Bind *)
-      | exnMessage Bind = "nonexhaustive binding failure"
-      | exnMessage Match = "nonexhaustive match failure"
-      | exnMessage Subscript = "subscript out of bounds"
-      | exnMessage Size = "size"
-      | exnMessage Overflow = "overflow"
-      | exnMessage Div = "divide by zero"
-      | exnMessage Domain = "domain error"
+    (* the Basis requires the message to contain `exnName ex` *)
+      | exnMessage Bind = "Bind: nonexhaustive binding failure"
+      | exnMessage Match = "Match: nonexhaustive match failure"
+      | exnMessage Subscript = "Subscript: subscript out of bounds"
+      | exnMessage Div = "Div: divide by zero"
+      | exnMessage Domain = "Domain: domain error"
       | exnMessage e = exnName e
 
     val _ = ExnInfoHook.exnMessageHook := exnMessage
```

Not built: the patched `exnMessage`, copied into a standalone program, gives
a message containing `exnName ex` for all 18 exceptions tried, on 110.99.9
(32 and 64 bits) and 2026.2.

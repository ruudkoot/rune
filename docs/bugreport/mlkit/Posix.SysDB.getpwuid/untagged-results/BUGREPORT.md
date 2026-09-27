# MLKit 4.7.23: `Posix.SysDB.getpwuid`, `getpwnam`, `getgrgid` and `getgrnam` raise `Overflow` for an entry that exists

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Runtime/Posix.c` and `basis/Posix.sml` as
the tag `v4.7.23`, byte for byte, so the code below is unchanged there;
`master` was not built.

## Summary

* **The trigger:** any call of `Posix.SysDB.getpwuid`, `getpwnam`,
  `getgrgid` or `getgrnam`, in a program built with garbage collection
  (the default, where values are tagged).
* **What goes wrong:** the C functions of the runtime store the result of
  `getpwuid_r` (and of the three others) in the record they return
  untagged, and `getpwnam` and `getpwuid` do the same with the user and
  group IDs. The ML code then sees an error where there is none: the
  result `0` is not the ML integer 0, so the function builds an
  `OS.SysErr` for "error" 0 and raises `Overflow` doing so. An untagged
  field can also crash the garbage collector, which takes an even word
  for a pointer.
* **Required behaviour:** the
  [`POSIX_SYS_DB` specification](https://smlfamily.github.io/Basis/posix-sys-db.html):
  "These return the group or user database entry associated with the
  given group ID or name, or user ID or name. It raises OS.SysErr if there
  is no group or user with the given ID or name."

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04 in a Firecracker microVM (kernel
  6.18.44), glibc 2.39, running as root (user and group 0, `root`).
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* The entries of the user and the group of the process, and those of root.
   getpwuid comes first: getpwnam and getgrnam as the first look-up of the
   program crash for another reason (their C functions are called with the
   stack misaligned). *)
structure D = Posix.SysDB
structure E = Posix.ProcEnv
fun show f = f () handle e => "raised " ^ exnName e
val () = print ("getpwuid (getuid ()): name " ^ show (fn () => D.Passwd.name (D.getpwuid (E.getuid ()))) ^ "\n")
val () = print ("getgrgid (getgid ()): name " ^ show (fn () => D.Group.name (D.getgrgid (E.getgid ()))) ^ "\n")
val () = print ("getpwnam \"root\": home " ^ show (fn () => D.Passwd.home (D.getpwnam "root")) ^ "\n")
val () = print ("getgrnam \"root\": name " ^ show (fn () => D.Group.name (D.getgrnam "root")) ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
getpwuid (getuid ()): name raised Overflow
getgrgid (getgid ()): name raised Overflow
getpwnam "root": home raised Overflow
getgrnam "root": name raised Overflow
```

With `-no_gc`, where integers are not tagged, all four return the entry
(`root`, `root`, `/root`, `root`). (The crash of a first `getpwnam` or
`getgrnam` is the subject of the report `X64/c-call-alignment`.)

## The cause

In `src/Runtime/Posix.c`, `sml_getpwuid` (line 1019) returns the record
`(name, gid, home, shell, res)` that `basis/Posix.sml` reads (line 1065 on):

```c
  res = getpwuid_r(uid, &pbuf, b, s-1, &pbuf2);
  elemRecordML(tuple,4) = res;
  ...
  elemRecordML(tuple,0) = (long) REG_POLY_CALL(convertStringToML, nameR, pbuf2->pw_name);
  elemRecordML(tuple,1) = (long) pbuf2->pw_gid;
```

```sml
          val (n,g,h,s,res) = prim("sml_getpwuid", (getCtx(), u : int, s : int, e : exn))
                              : (string * int * string * string * int)
          val res' = Error.fromWord(SysWord.fromInt res)
        in
          if res = 0 then {n = n, u = u, g = g, s = s, h = h}
          else raise OS.SysErr (Error.errorName res' ^ ": "^ (Error.errorMsg res'),SOME res)
```

`res` and the group ID are stored as C values; with tagging the ML integer
`k` is represented as `2k+1` (`convertIntToML`), so the stored 0 is not
the ML 0 and `res = 0` is false. Building the message of the `SysErr` for
this non-error then raises `Overflow` (in `Error.errorName`). The same
holds for `res` in `sml_getpwnam` (line 1056), which also stores `pw_uid`
and `pw_gid` untagged, and in `sml_getgrgid` (line 927) and `sml_getgrnam`
(line 973), both through `third(triple) = res`. `sml_getgrnam` converts its
group ID (`convertIntToML(gbuf2->gr_gid)`); the others do not.

## The fix

Tag every integer that goes into the result (`fix.patch`):

```diff
--- a/src/Runtime/Posix.c
+++ b/src/Runtime/Posix.c
@@ -938,11 +938,11 @@
   if (!b)
   {
     res = errno;
-    third(triple) = res;
+    third(triple) = convertIntToML(res);
     return triple;
   }
   res = getgrgid_r(gid, &gbuf, b, s-1, &gbuf2);
-  third(triple) = res;
+  third(triple) = convertIntToML(res);
   if (res)
   {
     free(b);
@@ -984,11 +984,11 @@
   if (!b)
   {
     res = errno;
-    third(triple) = res;
+    third(triple) = convertIntToML(res);
     return triple;
   }
   res = getgrnam_r(name, &gbuf, b, s-1, &gbuf2);
-  third(triple) = res;
+  third(triple) = convertIntToML(res);
   if (res)
   {
     free(b);
@@ -1029,11 +1029,11 @@
   if (!b)
   {
     res = errno;
-    elemRecordML(tuple,4) = res;
+    elemRecordML(tuple,4) = convertIntToML(res);
     return tuple;
   }
   res = getpwuid_r(uid, &pbuf, b, s-1, &pbuf2);
-  elemRecordML(tuple,4) = res;
+  elemRecordML(tuple,4) = convertIntToML(res);
   if (res)
   {
     free(b);
@@ -1045,7 +1045,7 @@
     raise_exn(ctx,exn);
   }
   elemRecordML(tuple,0) = (long) REG_POLY_CALL(convertStringToML, nameR, pbuf2->pw_name);
-  elemRecordML(tuple,1) = (long) pbuf2->pw_gid;
+  elemRecordML(tuple,1) = convertIntToML((long) pbuf2->pw_gid);
   elemRecordML(tuple,2) = (long) REG_POLY_CALL(convertStringToML, homeR, pbuf2->pw_dir);
   elemRecordML(tuple,3) = (long) REG_POLY_CALL(convertStringToML, shellR, pbuf2->pw_shell);
   free(b);
@@ -1065,11 +1065,11 @@
   if (!b)
   {
     res = errno;
-    elemRecordML(tuple,4) = res;
+    elemRecordML(tuple,4) = convertIntToML(res);
     return tuple;
   }
   res = getpwnam_r(name, &pbuf, b, s-1, &pbuf2);
-  elemRecordML(tuple,4) = res;
+  elemRecordML(tuple,4) = convertIntToML(res);
   if (res)
   {
     free(b);
@@ -1080,8 +1080,8 @@
     free(b);
     raise_exn(ctx,exn);
   }
-  elemRecordML(tuple,0) = (long) pbuf2->pw_uid;
-  elemRecordML(tuple,1) = (long) pbuf2->pw_gid;
+  elemRecordML(tuple,0) = convertIntToML((long) pbuf2->pw_uid);
+  elemRecordML(tuple,1) = convertIntToML((long) pbuf2->pw_gid);
   elemRecordML(tuple,2) = (long) REG_POLY_CALL(convertStringToML, homeR, pbuf2->pw_dir);
   elemRecordML(tuple,3) = (long) REG_POLY_CALL(convertStringToML, shellR, pbuf2->pw_shell);
   free(b);
```

`convertIntToML` is the identity without tagging, so `-no_gc` programs are
unaffected. Tested: the runtime archive `runtimeSystemGC.a` rebuilt from
the 4.7.23 sources of `src/Runtime` with this change (`make
build/linux-x86_64/runtimeSystemGC.a`) and put in a copy of the installed
`lib/mlkit`; `bug.sml` then prints `root`, `root`, `/root` and `root`,
`Passwd.uid`, `Passwd.gid` and `Group.gid` of these entries are the IDs
of `Posix.ProcEnv`, and `getpwnam "no-such-user"` and `getgrgid` of an
unused ID raise `OS.SysErr`. Rune's `tests/basis/posix_sysdb_sig.sml`
passes with it (3 checks, 0 failed). `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks that `Passwd.uid (getpwuid (getuid ()))`
is `getuid ()` and `Group.gid (getgrgid (getgid ()))` is `getgid ()`
(`tests/basis/posix_sysdb_sig.sml`,
`Posix.SysDB:POSIX_SYS_DB/uid-is-ProcEnv.uid` and
`gid-is-ProcEnv.gid`); on MLKit both raise `Overflow`. Its
`tests/basis/posix_sysdb.sml` does not get that far: it crashes in its
first check (report `X64/c-call-alignment`). The line of
`tests/basis/deviations.txt`:

```
native:mlkit@* | Posix.SysDB:POSIX_SYS_DB/[ug]id-is-ProcEnv.[ug]id | HOST-BUG | getpwuid, getpwnam, getgrgid and getgrnam raise Overflow for an entry that exists: the runtime returns the result of getpwuid_r (and the IDs of getpw*) untagged, so the result 0 is not the ML 0 and the library builds a SysErr for it
```

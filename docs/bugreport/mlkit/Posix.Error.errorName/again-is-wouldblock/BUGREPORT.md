# MLKit 4.7.23: `Posix.Error.errorName again` is `"wouldblock"` and `errorName notsup` is `"opnotsupp"`

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** The `Posix.Error.errorName` of MLton, SML/NJ and Poly/ML gives `"again"` and `"notsup"`.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Runtime/gen_syserror.c`,
`src/Runtime/Posix.c` and `basis/FileSys.sml` as the tag `v4.7.23`, byte
for byte, so the code below is unchanged there; `master` was not built.

## Summary

* **The trigger:** `Posix.Error.errorName` (or `OS.errorName`) of
  `Posix.Error.again` or `Posix.Error.notsup`, on a system where
  `EWOULDBLOCK` is `EAGAIN` and `EOPNOTSUPP` is `ENOTSUP` (Linux).
* **What goes wrong:** the names are `"wouldblock"` and `"opnotsupp"`,
  names that `POSIX_ERROR` does not have, instead of `"again"` and
  `"notsup"`. Which of two names that share a number comes out depends on
  where a binary search over a table sorted by an unstable `qsort` lands.
* **Required behaviour:** the
  [`POSIX_ERROR` specification](https://smlfamily.github.io/Basis/posix-error.html)
  lists `again` and `notsup` among the errors, and says "The string
  representation of a syserror value, as returned by errorName, is the name
  of the error. Thus, errorName badmsg = "badmsg"."

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04 in a Firecracker microVM (kernel
  6.18.44), glibc 2.39 (`EWOULDBLOCK` is `EAGAIN`, 11; `ENOTSUP` is
  `EOPNOTSUPP`, 95), running as root.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* errorName of the syserror values of POSIX_ERROR that Linux shares with
   another name: EAGAIN = EWOULDBLOCK, ENOTSUP = EOPNOTSUPP. *)
structure E = Posix.Error
fun show (name, e) =
  print ("errorName " ^ name ^ " = \"" ^ E.errorName e ^ "\"; syserror \"" ^ name ^ "\" = "
         ^ (case E.syserror name of SOME e' => if e' = e then "SOME " ^ name else "SOME other" | NONE => "NONE")
         ^ "; OS.errorName = \"" ^ OS.errorName e ^ "\"\n")
val () = List.app show [("again", E.again), ("notsup", E.notsup), ("badmsg", E.badmsg)]
```

```
$ mlkit -o bug bug.mlb && ./bug
errorName again = "wouldblock"; syserror "again" = SOME again; OS.errorName = "wouldblock"
errorName notsup = "opnotsupp"; syserror "notsup" = SOME notsup; OS.errorName = "opnotsupp"
errorName badmsg = "badmsg"; syserror "badmsg" = SOME badmsg; OS.errorName = "badmsg"
```

Expected: `"again"` and `"notsup"` in the first two lines.

## The cause

`errorName` (`basis/FileSys.sml`, lines 16-25) looks the number up with the
runtime's `sml_errorName`, which searches `syserrTableNumber` by binary
search (`sml_PosixName`, `src/Runtime/Posix.c` line 891). The table is
made at build time by `src/Runtime/gen_syserror.c` from a list that has
both `EAGAIN` and `EWOULDBLOCK`, and both `ENOTSUP` and `EOPNOTSUPP`,
sorted by number with `qsort` (lines 169-177):

```c
  qsort(srcErr,j,sizeof(struct syserr_entry),
	(int(*)(const void*,const void*))cmpInt);
  printf ("\nstatic struct syserr_entry syserrTableNumber[] = {\n");
  i = 0;
  while (i < j)
  {
    printf("  {\"%s\", %s},\n", srcErr[i].name, srcErr[i].name);
    i++;
  }
```

On Linux the two names of each pair have the same number, and the search
returns whichever entry it meets; here the ones that are not POSIX_ERROR's.

## The fix

Give both entries of such a number the name of `POSIX_ERROR`, so that the
search finds it whichever entry it meets; the name table, which
`syserror` uses, keeps both names:

```diff
--- a/src/Runtime/gen_syserror.c
+++ b/src/Runtime/gen_syserror.c
@@ -172,7 +172,13 @@
   i = 0;
   while (i < j)
   {
-    printf("  {\"%s\", %s},\n", srcErr[i].name, srcErr[i].name);
+    /* Where EWOULDBLOCK is EAGAIN and EOPNOTSUPP is ENOTSUP, the number
+       has two entries; both get the name of POSIX_ERROR (again, notsup),
+       whichever the search finds. */
+    const char *name = srcErr[i].name;
+    if (strcmp(name, "EWOULDBLOCK") == 0 && EWOULDBLOCK == EAGAIN) name = "EAGAIN";
+    if (strcmp(name, "EOPNOTSUPP") == 0 && EOPNOTSUPP == ENOTSUP) name = "ENOTSUP";
+    printf("  {\"%s\", %s},\n", name, srcErr[i].name);
     i++;
   }
   printf("  {NULL, -1}\n};\n");
```

Tested: the runtime archive `runtimeSystemGC.a` rebuilt from the 4.7.23
sources of `src/Runtime` with this change, in a copy of the installed
`lib/mlkit` (together with the changes proposed in the other reports of
this series): `bug.sml` then prints `"again"` and `"notsup"`, and
`syserror "wouldblock"` and `syserror "opnotsupp"` still give the values.
Rune's `tests/basis/posix_error.sml` then fails only the check of the
report `X64/is-null`. `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks the name of each error of
`POSIX_ERROR` (`tests/basis/posix_error.sml`,
`Posix.Error.again/errorName`: `got "wouldblock", expected "again"`, and
`Posix.Error.notsup/errorName`: `got "opnotsupp", expected "notsup"`). The
line of `tests/basis/deviations.txt`:

```
native:mlkit@* | Posix.Error.[an][go][at][is][nu]*/errorName | HOST-BUG | errorName again is "wouldblock" and errorName notsup is "opnotsupp" ("errorName badmsg = "badmsg""): the runtime's table from numbers to names has both names of EAGAIN = EWOULDBLOCK and ENOTSUP = EOPNOTSUPP, and its binary search finds the other one
```

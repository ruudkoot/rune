# MLKit 4.7.23: `Posix.FileSys.S` codes modes its own way: `S.irwxu` is not `irusr`+`iwusr`+`ixusr`, and `umask` returns the previous mask in another code

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `basis/Initial.sml`, `basis/Posix.sml` and
`src/Runtime/Posix.c` as the tag `v4.7.23`, byte for byte, so the code
below is unchanged there; `master` was not built.

## Summary

* **The trigger:** the modes of `Posix.FileSys.S`, and the mode that
  `Posix.FileSys.ST.mode` and `Posix.FileSys.umask` return.
* **What goes wrong:** MLKit gives each of the 14 modes of `S` a bit of
  its own (`irwxu = 0wx1`, `irusr = 0wx2`, ..., `isgid = 0wx2000`) and
  translates between that code and C's in the runtime. So:
  * `S.irwxu` is not the set of `irusr`, `iwusr` and `ixusr` (nor
    `irwxg`, `irwxo` those of the group and others), and `S.toWord` gives
    none of the values of the C binding;
  * `ST.mode` of a file whose mode is `rw-r-----` is not `S.flags
    [irusr, iwusr, irgrp]`: the runtime adds the bit of `irwxu` whenever
    any of the owner's three is set, and that of `irwxg` for the group;
    and `S.intersect [ST.mode st, S.irwxu]` is `S.irwxu`'s bit, not the
    owner's permissions;
  * `umask` returns the previous mask as C gives it, without translating
    it back, so the value is wrong, and putting it back with `umask`
    sets another mask (`0470` for a mask that was `0022`).
* **Required behaviour:** the
  [`POSIX_FILE_SYS` specification](https://smlfamily.github.io/Basis/posix-file-sys.html):
  "A file mode is a set of (read, write, execute) permissions for the
  owner of the file, members of the file's group, and others", with
  `irwxu` "Read, write, and execute permission for "user" (the file's
  owner)"; `S.mode` is a `BIT_FLAGS` type, whose
  [specification](https://smlfamily.github.io/Basis/bit-flags.html) says of
  `toWord` and `fromWord`: "The interpretation of the bits is
  system-dependent, but follows the C language binding for the host
  operating system", where `S_IRWXU` is `S_IRUSR | S_IWUSR | S_IXUSR` (0700);
  and "`umask cmask` sets the file mode creation mask of the process to
  cmask and returns the previous value of the mask".

## Environment

* **MLKit:** v4.7.23, the official binary release
  `mlkit-bin-dist-linux.tgz` ("MLKit v4.7.23 (v4.7.23 -
  2026-09-24T12:26:51+02:00) [X64 Backend]").
* **System:** Linux x86-64, Ubuntu 24.04 in a Firecracker microVM (kernel
  6.18.44), glibc 2.39, running as root.
* **Basis Library: MLKit's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlkit -o bug bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
structure FS = Posix.FileSys
structure S = FS.S
fun hex m = "0wx" ^ SysWord.toString (S.toWord m)
fun b x = Bool.toString x

(* 1. The values of the modes, which the C binding gives as S_IRWXU 0700,
      S_IRUSR 0400, ..., S_ISGID 02000 (0wx1C0, 0wx100, ..., 0wx400). *)
val () = print ("S.toWord of irwxu, irusr, iwusr, ixusr, isuid: "
                ^ String.concatWith ", " (map hex [S.irwxu, S.irusr, S.iwusr, S.ixusr, S.isuid]) ^ "\n")
(* 2. irwxu is read, write and execute permission for the owner. *)
val () = print ("S.irwxu = S.flags [S.irusr, S.iwusr, S.ixusr]: "
                ^ b (S.irwxu = S.flags [S.irusr, S.iwusr, S.ixusr]) ^ "\n")
(* 3. The mode of a file made with rw-r----- *)
val () = ignore (FS.umask (S.flags []))
val rw_r_____ = S.flags [S.irusr, S.iwusr, S.irgrp]
val () = Posix.IO.close (FS.createf ("f.txt", FS.O_WRONLY, FS.O.flags [], rw_r_____))
val m = FS.ST.mode (FS.stat "f.txt")
val () = print ("ST.mode of a file made rw-r-----: " ^ hex m ^ ", = rw-r-----: " ^ b (m = rw_r_____)
                ^ ", owner's part (intersect with S.irwxu): " ^ hex (S.intersect [m, S.irwxu]) ^ "\n")
val () = FS.unlink "f.txt"
(* 4. umask returns the previous mask. *)
val () = ignore (FS.umask (S.flags [S.iwgrp, S.iwoth]))
val old = FS.umask (S.flags [S.irwxg])
val now = FS.umask old
val () = print ("umask returned " ^ hex old ^ " for the mask S.flags [S.iwgrp, S.iwoth] = "
                ^ hex (S.flags [S.iwgrp, S.iwoth]) ^ ", and " ^ hex now ^ " for S.irwxg = " ^ hex S.irwxg ^ "\n")
val () = print "the mask of the process after putting the old one back, as the shell's umask shows it: "
val _ = OS.Process.system "umask"
```

```
$ mlkit -o bug bug.mlb && ./bug
S.toWord of irwxu, irusr, iwusr, ixusr, isuid: 0wx1, 0wx2, 0wx4, 0wx8, 0wx1000
S.irwxu = S.flags [S.irusr, S.iwusr, S.ixusr]: false
ST.mode of a file made rw-r-----: 0wx37, = rw-r-----: false, owner's part (intersect with S.irwxu): 0wx1
umask returned 0wx12 for the mask S.flags [S.iwgrp, S.iwoth] = 0wx440, and 0wx38 for S.irwxg = 0wx10
the mask of the process after putting the old one back, as the shell's umask shows it: 0470
```

The file itself is made with the right mode (`ls` shows `-rw-r-----`):
the translation into C is right, the code is the problem. `0wx37` is
`irwxu`, `irusr`, `iwusr`, `irwxg` and `irgrp` in MLKit's code. `umask`
returns `0wx12`, which is the C value of the mask (`022`); read in
MLKit's code it is `irusr` and `irwxg`, and set again it becomes the mask
`0470`.

## The cause

`basis/Initial.sml` (lines 307-324) gives the modes bits of their own:

```sml
        structure S =
          struct
            val irwxu =    0wx1
            val irusr =    0wx2
            val iwusr =    0wx4
            val ixusr =    0wx8
            val irwxg =   0wx10
            ...
            val isuid = 0wx1000
            val isgid = 0wx2000
            val all   = 0wx3FFF
          end
```

`Posix.FileSys` (`basis/Posix.sml`) builds `S` on them with `BitFlags`,
and passes a mode to `sml_lower` in `src/Runtime/Posix.c`, which
translates it into C's (lines 191-204):

```c
  if (perm & 0x1) mode |= S_IRWXU;
  if (perm & 0x2) mode |= S_IRUSR;
  ...
  if (perm & 0x2000) mode |= S_ISGID;
```

The way back is `sml_statA` (lines 451-478), which sets each bit of the ML
code when any bit of the corresponding C mask is set, so that the bit of
`irwxu` is set when any of the owner's permissions is:

```c
  res |= (S_ISGID & b->st_mode ? 1 : 0);
  res <<= 1;
  ...
  res |= (S_IRWXU & b->st_mode ? 1 : 0);
```

`umask` (`basis/Posix.sml` line 729) is the kind 3 of `sml_lower`, which
returns what C's `umask` returns, the previous mask in C's code
(`res = umask(mode);`, line 216), and the ML code takes it as a mode of its
own code without translating it:

```sml
    fun umask m = S.fromWord(SysWord.fromInt(lower "umask" ("", O_WRONLY, O.trunc, m, 0, 3)))
```

## The fix

Use the values of the C binding, which POSIX fixes (`S_IRWXU` 0700 ...
`S_ISGID` 02000), and pass them through unchanged. In `basis/Initial.sml`:

```sml
            (* the values of the C binding, <sys/stat.h> *)
            val irwxu = 0wx1C0  (* 0700 *)
            val irusr = 0wx100  (* 0400 *)
            val iwusr =  0wx80  (* 0200 *)
            val ixusr =  0wx40  (* 0100 *)
            val irwxg =  0wx38  (* 0070 *)
            val irgrp =  0wx20  (* 0040 *)
            val iwgrp =  0wx10  (* 0020 *)
            val ixgrp =   0wx8  (* 0010 *)
            val irwxo =   0wx7  (* 0007 *)
            val iroth =   0wx4  (* 0004 *)
            val iwoth =   0wx2  (* 0002 *)
            val ixoth =   0wx1  (* 0001 *)
            val isuid = 0wx800  (* 04000 *)
            val isgid = 0wx400  (* 02000 *)
            val all   = 0wxDFF
```

and in `src/Runtime/Posix.c`, in `sml_lower`:

```diff
-  if (perm & 0x1) mode |= S_IRWXU;
-  if (perm & 0x2) mode |= S_IRUSR;
-  ... (the 14 lines)
-  if (perm & 0x2000) mode |= S_ISGID;
+  /* perm is a Posix.FileSys.S.mode, whose bits are those of C */
+  mode = perm & (S_IRWXU | S_IRWXG | S_IRWXO | S_ISUID | S_ISGID);
```

and in `sml_statA`:

```diff
-  res = 0;
-  res |= (S_ISGID & b->st_mode ? 1 : 0);
-  res <<= 1;
-  ... (and so on for the other 13 bits)
-  res |= (S_IRWXU & b->st_mode ? 1 : 0);
+  res = b->st_mode & (S_IRWXU | S_IRWXG | S_IRWXO | S_ISUID | S_ISGID);
   elemRecordML(pair,1) = convertIntToML(res);
```

`umask` is then right as it is, since what C returns is a mode of the ML
code too. Tested: the runtime archive `runtimeSystemGC.a` rebuilt from
the 4.7.23 sources of `src/Runtime` with this change, and a copy of the
installed `lib/mlkit` with the new `basis/Initial.sml` (together with the
changes proposed in the other reports of this series, among them the fix
of `chmod`, report `Posix.FileSys.chmod/open-flags-as-mode`): `bug.sml`
then prints

```
S.toWord of irwxu, irusr, iwusr, ixusr, isuid: 0wx1C0, 0wx100, 0wx80, 0wx40, 0wx800
S.irwxu = S.flags [S.irusr, S.iwusr, S.ixusr]: true
ST.mode of a file made rw-r-----: 0wx1A0, = rw-r-----: true, owner's part (intersect with S.irwxu): 0wx180
umask returned 0wx12 for the mask S.flags [S.iwgrp, S.iwoth] = 0wx12, and 0wx38 for S.irwxg = 0wx38
the mask of the process after putting the old one back, as the shell's umask shows it: 0022
```

and Rune's Basis Library tests of `Posix.FileSys` (`posix_filesys`,
`posix_filesys_dir`) pass. `master` was not built.

## Relation to Rune

Rune's Basis Library suite checks the modes in
`tests/basis/posix_filesys.sml` and `tests/basis/posix_filesys_dir.sml`.
It reads the permissions of a file as `S.intersect [ST.mode (stat f),
S.flags [S.irwxu, S.irwxg, S.irwxo, S.isuid, S.isgid]]`, which on MLKit
keeps only the bits of `irwxu`, `irwxg` and `irwxo`; so besides
`Posix.FileSys.S.irwx[ugo]/is-*`, `S.toWord/values-of-the-C-binding`,
`umask/returns-previous`, `umask/set-then-read` and `mkdir/mask-unchanged`,
the checks of the modes that `createf`, `creat`, `mkdir` and `mkfifo`
give under a mask fail (`createf/mode-less-umask`: `got 0wx111, expected
0wx226`, and so on), although the files are made with the right modes.
The lines of `tests/basis/deviations.txt`:

```
native:mlkit@* | Posix.FileSys.S.*/[iv]* | HOST-BUG | S codes the modes its own way (irwxu = 0wx1, irusr = 0wx2, ..., isgid = 0wx2000, translated by the runtime): irwxu is not irusr + iwusr + ixusr, and toWord gives none of the values of the C binding
native:mlkit@* | Posix.FileSys.umask/* | HOST-BUG | S codes the modes its own way (irwxu = 0wx1, ..., translated by the runtime): umask returns the previous mask in C's code, untranslated, and the checks read the permissions of a file through S.irwxu, S.irwxg and S.irwxo, which stand for bits of their own, not for their three permissions
native:mlkit@* | Posix.FileSys.*/m[ao]* | HOST-BUG | S codes the modes its own way (irwxu = 0wx1, ..., translated by the runtime): the checks read the permissions of a file through S.irwxu, S.irwxg and S.irwxo, which stand for bits of their own, not for their three permissions, and umask returns the previous mask in C's code, untranslated
```

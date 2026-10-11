# MLton 20241230: `Posix.TTY.getlflag` returns the output flags, not the local flags

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (SML/NJ 110.99.9 and 2026.2, Poly/ML 5.9.2 and MLKit 4.7.23) does this.** In SML/NJ, Poly/ML and MLKit `getlflag` gives the `lflag` of the termios.

## Status

Not reported upstream from here. MLton's tracker has no matching issue or
pull request: searching the issues and the pull requests of MLton/mlton
for `getlflag`, `Posix.TTY`, `termios`, `lflag`, `oflag` and `TTY` (on
2026-10-11) found nothing about it. MLton's `master` at `5fe943391`
(2026-10-03) has the same line in `basis-library/posix/tty.sml`. The line
has been this way since the file's first revision (`a56204b36`, 2001).

## Summary

* **The trigger:** `Posix.TTY.getlflag t` for any `termios` value `t`,
  whether it is built with `Posix.TTY.termios` or returned by
  `Posix.TTY.TC.getattr`.
* **What goes wrong:** the result is the termios's output flags (`oflag`),
  the same as `getoflag t`, and not its local flags (`lflag`).
* **Required behaviour:** the
  [Basis `POSIX_TTY` specification](https://smlfamily.github.io/Basis/posix-tty.html#SIG:POSIX_TTY.getiflag:VAL)
  says of `getiflag`, `getoflag`, `getcflag`, `getlflag` and `getcc`:
  "These are the obvious projection functions from a termios value to its
  constituent fields." So `getlflag t` is `#lflag (fieldsOf t)`.

## Environment

* **MLton:** 20241230, the official binary release (`mlton` prints
  "MLton 20241230").
* **System:** Linux x86-64, Ubuntu 24.04 on WSL2 (kernel
  6.18.33.2-microsoft-standard-WSL2), glibc 2.39.
* **Basis Library: MLton's own.** The program is built from `bug.mlb`,
  which lists `$(SML_LIB)/basis/basis.mlb` and `bug.sml`, with
  `mlton bug.mlb`. Nothing of Rune is involved.

## The program

`bug.sml`:

```sml
(* Each getter of Posix.TTY should give its own field of a termios. *)
structure T = Posix.TTY
val t = T.termios {iflag = T.I.icrnl, oflag = T.O.opost, cflag = T.C.cs8,
                   lflag = T.L.echo, cc = T.V.cc [], ispeed = T.b0, ospeed = T.b0}
fun show (name, got, expected) =
    print (name ^ " = 0wx" ^ SysWord.toString got
           ^ "   (expected 0wx" ^ SysWord.toString expected ^ ")\n")
val () = show ("getiflag t", T.I.toWord (T.getiflag t), T.I.toWord T.I.icrnl)
val () = show ("getoflag t", T.O.toWord (T.getoflag t), T.O.toWord T.O.opost)
val () = show ("getcflag t", T.C.toWord (T.getcflag t), T.C.toWord T.C.cs8)
val () = show ("getlflag t", T.L.toWord (T.getlflag t), T.L.toWord T.L.echo)
val () = show ("#lflag (fieldsOf t)", T.L.toWord (#lflag (T.fieldsOf t)), T.L.toWord T.L.echo)
```

```
$ mlton bug.mlb && ./bug
getiflag t = 0wx100   (expected 0wx100)
getoflag t = 0wx1   (expected 0wx1)
getcflag t = 0wx30   (expected 0wx30)
getlflag t = 0wx1   (expected 0wx8)
#lflag (fieldsOf t) = 0wx8   (expected 0wx8)
```

`getlflag t` is `0wx1`, which is `O.opost`, the output flag. `fieldsOf`
still holds `L.echo` (`0wx8`) as the local flags.

## The other implementations

The same `bug.sml`, run on each of them:

* **SML/NJ 110.99.9 (64 bits) and SML/NJ 2026.2** (`use "bug.sml";`): every
  line gives the value expected, and `getlflag t = 0wx8`.
* **Poly/ML 5.9.2** (`use "bug.sml";`): every line gives the value expected.
* **MLKit 4.7.23** (`mlkit -o bug bug.mlb`): every line gives the value
  expected.
* **Rune** (`bin/rune bug.sml -o bug.rbc && bin/runevm bug.rbc`): every
  line gives the value expected.

## The cause

`basis-library/posix/tty.sml`, lines 168 to 184. A `termios` is a record, and
the getters select its fields:

```sml
      type termios = {iflag: I.flags,
                      oflag: O.flags,
                      cflag: C.flags,
                      lflag: L.flags,
                      cc: V.cc,
                      ispeed: speed,
                      ospeed: speed}

      val id = fn x => x
      val termios = id
      val fieldsOf = id

      val getiflag: termios -> I.flags = #iflag
      val getoflag: termios -> O.flags = #oflag
      val getcflag: termios -> C.flags = #cflag
      val getlflag: termios -> L.flags = #oflag
      val getcc: termios -> V.cc = #cc
```

`getlflag` selects `#oflag`. `I`, `O`, `C` and `L` all open one structure,
`Flags = BitFlags (structure S = C_TCFlag)` (line 64), so `L.flags` and
`O.flags` are the same type here, and the type checker accepts the copying
slip. `TC.getattr` and `TC.setattr` read and write `lflag` correctly. Only
the projection is wrong.

## The fix

Select the right field (`fix.patch`):

```diff
--- a/basis-library/posix/tty.sml
+++ b/basis-library/posix/tty.sml
@@ -180,7 +180,7 @@
       val getiflag: termios -> I.flags = #iflag
       val getoflag: termios -> O.flags = #oflag
       val getcflag: termios -> C.flags = #cflag
-      val getlflag: termios -> L.flags = #oflag
+      val getlflag: termios -> L.flags = #lflag
       val getcc: termios -> V.cc = #cc
 
       structure CF =
```

How it was tested: MLton compiles its Basis Library from source into every
program, so the fix was built without rebuilding MLton. The
installed library (`lib/mlton/sml/basis`, identical to `basis-library` of
the 20241230 sources) was copied with this patch applied and used with
`mlton -mlb-path-var 'SML_LIB <copy>' bug.mlb`. `bug.sml` then gives the
values expected on every line. Rune's `tests/basis/posix_tty.sml`, built the
same way with the patches of all four MLton reports of this directory, goes
from 110 checks with 1 failed (`Posix.TTY.getlflag/sample`) to 110 checks
with none failed. The patch applies to `master` unchanged.

## How it was found

By the laws of Rune's Basis Library documentation: each `Law:` in
`lib/basis` is tested on generated values. The laws were run against MLton's
own Basis Library with `tests/basis/run-laws-hosts.py` (see the sections on
the other compilers in `docs/plans/quickcheck-hunt.md`). The law of `getiflag` in
`lib/basis/sig_posix_tty.sml`:

```
Law: `getiflag t = #iflag (fieldsOf t)`, and `getoflag t = #oflag
(fieldsOf t)`, and `getcflag t = #cflag (fieldsOf t)`, and `getlflag t =
#lflag (fieldsOf t)`, and `getcc t = #cc (fieldsOf t)`
```

Its fourth part, `POSIX_TTY.getiflag/law-4` at `Posix.TTY`, failed on MLton
for a termios with `lflag` `0w0` and `oflag` `0w1`: `getlflag` gave `0w1`.
That difference from Rune is the line of `tests/basis/law-deviations.txt`:

```
native:mlton | POSIX_TTY.getiflag/law-4@Posix.TTY | HOST-BUG | Posix.TTY.getlflag returns the termios's oflag: of a termios with lflag 0w0 and oflag 0w1 it is 0w1
```

Rune's Basis Library suite had already met it, in the check
`Posix.TTY.getlflag/sample` of `tests/basis/posix_tty.sml`. That check is
recorded as a known `HOST-BUG` for `mlton@*` in `tests/basis/deviations.txt`
("getlflag returns the output flags (those of getoflag)").

# MLKit 4.7.23: `OS.IO.poll` of a closed descriptor returns a `poll_info` instead of raising `OS.SysErr`

**Class 3 of 4: the specification is explicit, but at least one of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does the same.** MLton also returns a `poll_info`; SML/NJ and Poly/ML raise `OS.SysErr`.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Runtime/IO.c` and `basis/OS.sml` as the tag
`v4.7.23`, byte for byte, so the code below is unchanged there; `master`
was not built.

## Summary

* **The trigger:** `OS.IO.poll` of a list that holds the poll descriptor
  of an I/O descriptor that has been closed.
* **What goes wrong:** `poll` returns a list with a `poll_info` for it in
  which no condition is set (`isIn`, `isOut` and `isPri` are false). The
  C `poll` reports such a descriptor with `POLLNVAL` in `revents`, which
  the runtime does not look at: every non-zero `revents` becomes a
  `poll_info`.
* **Required behaviour:** the
  [`OS_IO` specification](https://smlfamily.github.io/Basis/os-io.html):
  "The poll function will raise OS.SysErr if, for example, one of the file
  descriptors refers to a closed file." (A `poll_info` in the result is
  also to "reflect a (nonempty) subset of the conditions specified in the
  corresponding argument descriptor", which one with no condition does
  not.)

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
(* poll of a descriptor that has been closed must raise OS.SysErr. *)
val {infd, outfd} = Posix.IO.pipe ()
val () = (Posix.IO.close infd; Posix.IO.close outfd)
val pd = valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD infd))
val r = (let val l = OS.IO.poll ([OS.IO.pollIn pd], SOME Time.zeroTime)
         in "returned " ^ Int.toString (length l) ^ " poll_info, isIn "
            ^ String.concatWith ", " (map (Bool.toString o OS.IO.isIn) l) end)
        handle OS.SysErr (m, _) => "raised SysErr \"" ^ m ^ "\""
val () = print ("OS.IO.poll of a closed descriptor: " ^ r ^ "\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
OS.IO.poll of a closed descriptor: returned 1 poll_info, isIn false
```

Expected: `raised SysErr ...`.

## The cause

`OS.IO.poll` (`basis/OS.sml`, lines 122-128) calls the runtime's
`sml_poll` and turns its exception `Poll` into `SysErr`. `sml_poll`
(`src/Runtime/IO.c`, from line 599) raises it only when `poll` itself
returns a negative number, and makes a `poll_info` of every descriptor
with a non-zero `revents` (lines 629-651):

```c
  int res = poll(pollfds, n, tm);

  if (res < 0) {
    free(pollfds);
    raise_exn(ctx,exn);
  }

  // build poll-info list
  makeNIL(list);
  for ( i = 0 ; i < n ; i++ ) {
    if ( (pollfds[i].revents) != 0 ) {
```

For a descriptor that is not open, `poll` succeeds and sets `POLLNVAL` in
its `revents`.

## The fix

Treat `POLLNVAL` as an error:

```diff
--- a/src/Runtime/IO.c
+++ b/src/Runtime/IO.c
@@ -628,6 +628,13 @@
 
   int res = poll(pollfds, n, tm);
 
+  for ( i = 0 ; res > 0 && i < n ; i++ ) {
+    if ( pollfds[i].revents & POLLNVAL ) {
+      errno = EBADF;
+      res = -1;
+    }
+  }
+
   if (res < 0) {
     free(pollfds);
     raise_exn(ctx,exn);
```

(`OS.IO.poll` raises `SysErr ("poll error", NONE)` for it, as for every
failure of `poll`; passing the `syserror` along would be better still.)

Tested: the runtime archive `runtimeSystemGC.a` rebuilt from the 4.7.23
sources of `src/Runtime` with this change, in a copy of the installed
`lib/mlkit` (together with the changes proposed in the other reports of
this series, which touch other functions): `bug.sml` then prints `raised
SysErr "poll error"`, and Rune's `tests/basis/os.io.sml` passes. `master`
was not built.

## Relation to Rune

Rune's Basis Library suite checks this (`tests/basis/os.io.sml`,
`OS.IO.poll/closed-SysErr`: "no exception raised" on MLKit). The line of
`tests/basis/deviations.txt`, worded as the one for MLton:

```
native:mlkit@* | OS.IO.poll/closed-SysErr | HOST-BUG | poll of a descriptor that has been closed returns a poll_info with no condition instead of raising OS.SysErr: the runtime ignores POLLNVAL
```

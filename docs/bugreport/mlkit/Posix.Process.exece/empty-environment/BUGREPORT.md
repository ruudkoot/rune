# MLKit 4.7.23: `Posix.Process.exece` and `Unix.executeInEnv` with the environment `[]` pass on the whole environment

**Class 2 of 4: the specification is explicit, and none of the other implementations tested (MLton 20241230, SML/NJ 110.99.9 and Poly/ML 5.9.2) does this.** MLton, SML/NJ and Poly/ML pass an empty environment.

## Status: not reported upstream

This has not been sent to MLKit from here. MLKit's `master` at `c49fbea`
(2026-09-25) has the same `src/Runtime/Posix.c` and `basis/Posix.sml` as
the tag `v4.7.23`, byte for byte, so the code below is unchanged there;
`master` was not built.

Related upstream: [#79](https://github.com/melsman/mlkit/issues/79), closed
in 2021, fixed a segmentation fault of `exece`. This report is about a
different matter, the empty environment.

## Summary

* **The trigger:** `Posix.Process.exece (path, args, [])`, and so also
  `Unix.executeInEnv (cmd, args, [])`, which ends in it.
* **What goes wrong:** the new program gets the environment of the
  calling process instead of an empty one. The runtime installs the list
  as the environment only when it is not empty.
* **Required behaviour:** the
  [`POSIX_PROCESS` specification](https://smlfamily.github.io/Basis/posix-process.html):
  "Normally, the new image is given the same environment as the calling
  program. The env argument in exece allows the program to specify a new
  environment"; the
  [`UNIX` specification](https://smlfamily.github.io/Basis/unix.html):
  "`executeInEnv (cmd, args, env)` asks the operating system to execute the
  program named by the string cmd with the argument list args and the
  environment env."

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

`bug.sml` (it prints only the number of variables, not the variables):

```sml
(* A program run with the environment [] sees no variables. *)
structure P = Posix.Process
fun status () =
  case #2 (P.waitpid (P.W_ANY_CHILD, [])) of
    P.W_EXITED => "exit 0"
  | P.W_EXITSTATUS w => "exit " ^ Word8.toString w
  | _ => "other"
(* sh exits with 4 if HOME is unset, 5 if it is set *)
val () =
  case P.fork () of
    NONE => P.exece ("/bin/sh", ["sh", "-c", "test -z \"${HOME+set}\" && exit 4; exit 5"], [])
  | SOME _ => print ("Posix.Process.exece with []: " ^ status () ^ " (4: HOME unset, 5: HOME set)\n")
(* the number of variables env prints *)
val p : (TextIO.instream, TextIO.outstream) Unix.proc = Unix.executeInEnv ("/usr/bin/env", [], [])
val n = length (String.tokens (fn c => c = #"\n") (TextIO.inputAll (Unix.textInstreamOf p)))
val _ = Unix.reap p
val () = print ("Unix.executeInEnv (\"/usr/bin/env\", [], []): env printed " ^ Int.toString n ^ " variables\n")
```

```
$ mlkit -o bug bug.mlb && ./bug
Posix.Process.exece with []: exit 5 (4: HOME unset, 5: HOME set)
Unix.executeInEnv ("/usr/bin/env", [], []): env printed 146 variables
```

Expected: `exit 4` and `0 variables`. (A non-empty list is installed as
it should be.)

## The cause

`exec`, `exece` and `execp` (`basis/Posix.sml`, lines 347-356) share the
runtime's `sml_exec`; `exec` passes the empty list for "no new
environment", and `exece` passes its `env`, so the runtime cannot tell an
empty `env` from none:

```sml
    fun exec (s : string, sl : string list) = exec'(s,sl,[],true)
    fun exece (s : string, sl : string list, env : string list) = exec'(s,sl,env,true)
    fun execp (s : string, sl : string list) = exec'(s,sl,[],false)
```

`sml_exec` (`src/Runtime/Posix.c`, line 239) replaces `environ` only for a
non-empty list:

```c
  list = envl;
  if (isCONS(list))
  {
    ...
    env[i] = NULL;
    environ = env;
  }
  if (kind)
  {
    n = execv(path->data, args);
  }
```

## The fix

Tell the runtime which of the three it is, and install the list, even an
empty one, for `exece`:

```diff
--- a/basis/Posix.sml
+++ b/basis/Posix.sml
@@ -344,17 +344,18 @@
-    fun exec' (s, sl, env, path) =
+    (* kind 0: execvp; 1: execv; 2: execv with the environment env *)
+    fun exec' (s, sl, env, kind) =
         let
-          val a = prim("sml_exec", (s : string, sl : string list, env : string list, if path then 1 else 0)) : int
+          val a = prim("sml_exec", (s : string, sl : string list, env : string list, kind : int)) : int
         in
           raiseSys "exec" NONE ""
         end
 
-    fun exec (s : string, sl : string list) = exec'(s,sl,[],true)
-    fun exece (s : string, sl : string list, env : string list) = exec'(s,sl,env,true)
-    fun execp (s : string, sl : string list) = exec'(s,sl,[],false)
+    fun exec (s : string, sl : string list) = exec'(s,sl,[],1)
+    fun exece (s : string, sl : string list, env : string list) = exec'(s,sl,env,2)
+    fun execp (s : string, sl : string list) = exec'(s,sl,[],0)
--- a/src/Runtime/Posix.c
+++ b/src/Runtime/Posix.c
@@ -260,7 +260,7 @@
   args[i] = NULL;
 
   list = envl;
-  if (isCONS(list))
+  if (kind == 2)
   {
     for (n = 0; isCONS(list); list = tl(list))
     {
```

Tested: the runtime archive `runtimeSystemGC.a` rebuilt from the 4.7.23
sources of `src/Runtime` with this change, and a copy of the installed
`lib/mlkit` with the new `basis/Posix.sml` (together with the changes
proposed in the other reports of this series, which touch other
functions): `bug.sml` then prints `exit 4` and `0 variables`, and Rune's
`tests/basis/posix_process.sml` and `tests/basis/unix.sml` pass.
`master` was not built.

## Relation to Rune

Rune's Basis Library suite checks the empty environment with both
functions (`tests/basis/posix_process.sml`,
`Posix.Process.exece/empty-environment`: `got W_EXITSTATUS 5, expected
W_EXITSTATUS 4`; `tests/basis/unix.sml`,
`Unix.executeInEnv/empty-environment`, which gets the whole environment
back from `/usr/bin/env` where it expects `""`). The line of
`tests/basis/deviations.txt`:

```
native:mlkit@* | *exec*/empty-environment | HOST-BUG | exece (and so Unix.executeInEnv) with the environment [] passes on the environment of the process: the runtime installs the list only when it is not empty
```

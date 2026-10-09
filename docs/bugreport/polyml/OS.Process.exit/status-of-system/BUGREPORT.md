# Poly/ML 5.9.2: `OS.Process.exit` of the status of `OS.Process.system` loses the command's exit code on Unix

## Status: not reported

No issue on polyml/polyml matches (searched 2026-10-09 for `exit code`,
`WEXITSTATUS`, `system exit status`, `Process.exit`).
[#253](https://github.com/polyml/polyml/issues/253) (closed) was about
`system` on Windows, where it always returned failure; its fix does not
touch the Unix path. `master` at `45283b5` (2026-10-07) has the same code
in `libpolyml/process_env.cpp` and `basis/OS.sml` (read, not built).

## Summary

* **The trigger:** `OS.Process.exit st` where `st` comes from
  `OS.Process.system`, on Unix.
* **What goes wrong:** the program ends with the low byte of the status
  that `waitpid` gave, not with the command's exit code:
  - after `system "exit 3"`, `exit` ends the program with 0 (success), not
    3;
  - after a command that `SIGTERM` ends, with 15, not failure (1).
* **Required behaviour:** the
  [Basis `OS.Process` specification](https://smlfamily.github.io/Basis/os-process.html)
  of `exit`: "if the argument to exit comes from system or some other
  function returning a status value, then the implementation should attempt
  to preserve the meaning of the exit code from the subprocess. ... if
  Posix.Process.fromStatus st yields Posix.Process.W_EXITSTATUS v, then v
  should be passed to Posix.Process.exit after all necessary cleanup is
  done. If st does not connote an exit value, exit should act as though
  called with failure." SML/NJ 110.99.9 ends these programs with 3 and 1.

## Where it happens

Poly/ML 5.9.2, the release built from source, on Linux x86-64 (Ubuntu
24.04 on WSL2):

```
$ poly --script bug.sml; echo $?
Posix.Process.fromStatus of the status: W_EXITSTATUS 3
0
$ poly --script bug-signal.sml; echo $?
15
```

Poly/ML's own `Posix.Process.fromStatus` reads the status as
`W_EXITSTATUS 3`, so the information is there; `exit` does not use it.

## The cause

On Unix, `PolyProcessEnvSystem` (`libpolyml/process_env.cpp`) returns the
status that `waitpid` fills in, as it is:

```c++
                int wRes = waitpid(pid, &res, WNOHANG);
                if (wRes > 0)
                    break;
...
        result = Make_fixed_precision(taskData, res);
```

That is by design: `OS.Process.status` is that word, and
`Posix.Process.fromStatus` decodes it through the runtime (call 15 of
`PolyOSSpecificGeneral`). But `OS.Process.exit` (`basis/OS.sml`) passes its
argument to `PolyFinish`, and so to C's `exit`, as it is:

```sml
            fun exit (n: int) =
            ...
                fun runExit () =
                    case !atExitList of
                        [] => reallyExit n
```

C's `exit` keeps the low 8 bits: 768, the status of `exit 3`, gives 0, and
15, the status of a process that `SIGTERM` ended, gives 15.

## The fix

Not made here. On Unix `exit` should decode its argument as
`Posix.Process.fromStatus` does before it calls `PolyFinish`: the exit
value where the status has one, and `failure` otherwise. `success` (0) and
`failure` (1) decode to themselves (1 reads as "terminated by signal 1",
which maps to `failure`). On Windows, where `system` returns the exit code
itself, nothing changes. A patch was not written because testing it needs a
rebuild of Poly/ML.

## How Rune met it

Natively, the suite's check `OS.Process.exit/keeps-the-exit-code-of-a-command`
times out, because a child that Poly/ML forks and that calls `exit` never
ends (`deviations.txt`: `native:polyml@* | OS.Process.exit/keeps-...`;
perhaps related to [#176](https://github.com/polyml/polyml/issues/176),
"Forked child process blocks all signals", which is open). In
`xc2:polyml`, which compiles Poly/ML's own
library with Rune and gives it a runtime that does what `libpolyml` does
(`tests/basis/xc2`), the child ends and its status showed what `exit` does.
The programs here show it in the main process, natively.

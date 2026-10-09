# MLton 20241230: `OS.Process.exit` of the status of `OS.Process.system` raises `Fail`, and `Unix.fromStatus` misreads `Unix.reap` and `failure`

## Status: not reported

No issue on MLton/mlton matches (searched 2026-10-09 for
`OS.Process.exit`, `fromStatus`, `reap status`, `exit status 256`;
[#373](https://github.com/MLton/mlton/issues/373), "OS.Process.status as
integral value", is about the type being abstract). `master` at `5fe9433`
(2026-10-03) has the same `basis-library/system/process.sml`,
`mlton/exit.sml`, `system/unix.sml` and `posix/process.sml` (read, not
built).

## Summary

One cause: MLton keeps an `OS.Process.status` in two representations, and
each function reads it in one of them.

* **The trigger:**
  - `OS.Process.exit st` with `st` from `OS.Process.system`;
  - `Unix.fromStatus` (which is `Posix.Process.fromStatus`) of a status
    from `Unix.reap`, or of `OS.Process.failure`.
* **What goes wrong:**
  - after `system "exit 3"`, `exit` raises `Fail "MLton.Exit.exit(768):
    exit must have 0 <= status < 256"`, and the program ends with 1 from
    the top-level handler, not 3;
  - after a command that `SIGTERM` ended, `exit` ends the program with 15,
    not with failure;
  - `Unix.fromStatus` of the `reap` of a process that exited with 3 is
    `W_SIGNALED 3`, of one that `SIGTERM` ended `W_SIGNALED 1`, and of
    `OS.Process.failure` `W_SIGNALED 1`.
* **Required behaviour:** the
  [Basis `OS.Process` specification](https://smlfamily.github.io/Basis/os-process.html)
  of `exit`: "if the argument to exit comes from system or some other
  function returning a status value, then the implementation should attempt
  to preserve the meaning of the exit code from the subprocess. ... if
  Posix.Process.fromStatus st yields Posix.Process.W_EXITSTATUS v, then v
  should be passed to Posix.Process.exit after all necessary cleanup is
  done. If st does not connote an exit value, exit should act as though
  called with failure." `Unix.fromStatus` "returns a concrete view of the
  given status", which for a process that exited with 3 is `W_EXITSTATUS
  0w3`, and for one that a signal ended `W_SIGNALED` of that signal.

## Environment

* **MLton:** 20241230, the official binary release for amd64-linux.
* **System:** Linux x86-64 (Ubuntu 24.04 on WSL2).
* **Basis Library: MLton's own.** `mlton bug.sml`, nothing of Rune
  involved.

## Where it happens

```
$ mlton bug.sml && ./bug; echo $?
Posix.Process.fromStatus of the status: W_EXITSTATUS 3
unhandled exception: Fail: MLton.Exit.exit(768): exit must have 0 <= status < 256
Top-level handler raised exception.
1
$ mlton bug-signal.sml && ./bug-signal; echo $?
15
$ mlton bug-statuses.sml && ./bug-statuses
fromStatus (system "exit 3") = W_EXITSTATUS 3, expected W_EXITSTATUS 3: ok
fromStatus (reap of sh -c "exit 3") = W_SIGNALED 3, expected W_EXITSTATUS 3: WRONG
fromStatus (reap of sh killed by SIGTERM) = W_SIGNALED 1, expected W_SIGNALED 15: WRONG
fromStatus OS.Process.failure = W_SIGNALED 1, expected W_EXITSTATUS of a non-zero code: WRONG
```

SML/NJ 110.99.9 ends `bug.sml` with 3 and `bug-signal.sml` with 1. Of
`bug-statuses.sml` it gets all but the `SIGTERM` line right (it says
`W_EXITSTATUS 1`); Poly/ML 5.9.2 gets all but the last right. Those are
faults of their own, which Rune's suite records for them.

## The cause

`OS.Process.status` is `PreOS.Status.t`, a `C_Status.t` (a C `int`) behind
an abstract type, and it holds two kinds of number:

* **The status of `waitpid`.** `OS.Process.system` (`system/process.sml`)
  returns what C's `system` returns, as it is: 768 for `exit 3`, 15 for a
  process that `SIGTERM` ended. `Posix.Process.fromStatus`
  (`posix/process.sml`), and so `Unix.fromStatus`, decodes its argument
  this way, with `WIFEXITED`, `WEXITSTATUS` and `WTERMSIG`.
* **An exit code.** `OS.Process.success` and `failure` are 0 and 1
  (`MLton.Exit.Status`); `Unix.reap` (`system/unix.sml`) returns
  `Status.fromPosix` of the decoded status, which is the exit code for a
  process that exited and `failure` for one that a signal ended;
  `MLton.Exit.exit`, which is `OS.Process.exit`, passes its argument to C's
  `exit` and rejects one outside 0 to 255:

```sml
      fun exit (status: Status.t): 'a =
         ...
               val i = Status.toInt status
            in
               if 0 <= i andalso i < 256
                  then (let open Cleaner in clean atExit end
                        ; halt status
                        ; raise Fail "MLton.Exit.exit")
               else raise Fail (concat ["MLton.Exit.exit(", Int.toString i, "): ",
                                        "exit must have 0 <= status < 256"])
```

So `exit` reads a status of `system` as an exit code (768 is out of range;
15, the signal, is taken for the code 15), and `fromStatus` reads an exit
code as a status of `waitpid` (3 is "killed by signal 3", 1, which is
`failure`, "killed by signal 1").

## The fix

Not made here: it means choosing one representation for every function of
`OS.Process` and `Unix`. Two ways:

* **Every status the status of `waitpid`**, as `system` and
  `Posix.Process.fromStatus` already have it: `Unix.reap` returns the
  status undecoded; `failure` is the status of a process that exited with 1;
  `OS.Process.exit` decodes its argument with `fromStatus'` before it calls
  `MLton.Exit.exit` (`W_EXITED` to 0, `W_EXITSTATUS v` to `v`, anything
  else to 1). Nothing is lost, and `Unix.fromStatus` of a process that a
  signal ended says which signal. The cost is that `failure` needs the
  platform's encoding of an exit status (256 on Linux and the BSDs) and
  that `MLton.Exit`'s own `failure`, an exit code, becomes a type apart.
* **Every status an exit code**, as `reap` and `exit` have it: `system`
  returns `Status.fromPosix (fromStatus' r)`, and `Unix.fromStatus` maps 0
  to `W_EXITED` and `n` to `W_EXITSTATUS n`. That is a smaller change, but
  `Unix.fromStatus` can then no longer say that a signal ended a process.

## How Rune met it

Rune's Basis suite checks `OS.Process.exit` of the status of a command in
a child (`OS.Process.exit/keeps-the-exit-code-of-a-command` and
`signal-status-is-failure`) and `Unix.fromStatus` of what `reap` returns.
The lines of `deviations.txt` for `native:mlton`
(`OS.Process.exit/[ks]*`, `Unix.reap/*`, `Unix.W_*/reap*`, `Unix.kill/*`,
`Unix.fromStatus/failure`, `Posix.Process.fromStatus/failure`) all come
from this.

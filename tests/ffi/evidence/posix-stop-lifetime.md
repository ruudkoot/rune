# Stopped-child fixture lifetime — 2026-10-23

This is a test-only repair. No compiler, runtime, Basis implementation,
ordinary library, deviation, or timeout changes.

The full check on `303db25bc` failed
`Posix.Process.W.untraced/waitpid-without-it` with an exception. Its
original stdout records **76 checks, 1 failed**; the portable harness did
not retain the exception identity. Eight independent repetitions of the
exact frozen VM/bytecode passed all 76 checks, including two syscall-traced
runs. These repetitions do not turn the failed full run into a clean run.

The old fixture stopped a shell that executed `exit 7` after continuation.
A nonblocking wait could then reap its terminal status before the
unconditional cleanup kill, which raises `ESRCH`. Independent native C and
SML probes deliberately plant `SIGCONT` and reproduce that precise
failure. The SML probe captures `SysErr srch: No such process`, rather than
allowing the test harness to discard the exception detail. We have not
proved that a continuation signal caused the original full-run failure.
The runner requests a process group per job, and native child creation
sets it in both parent and child; cross-job signal interference has not
been observed.

The repaired negative fixture keeps the child in a pause loop until the
parent kills and reaps it. It cannot exit just because it was continued.
A new regression confirms the stopped status, deliberately continues the
child, waits for the child's marker proving it resumed, and checks that
nonblocking wait without `untraced` still returns `NONE`; cleanup must
reap `SIGKILL`. The existing positive `W_STOPPED/stop` check independently
checks stop reporting with `untraced`. Observation exceptions remain the
primary exception even if cleanup also raises.

The updated default suite passes **77/77** checks on the frozen stack
interpreter, register interpretation, baseline JIT, optimized JIT
(`--jit=all --jit-tier=2`), and existing `runeopt` native execution. The
manual causal probe passes **79/79** in each register execution mode,
including its intentional old-fixture ESRCH check and repaired resumed
child check. Actual probe child PGIDs equal their job PIDs. Commands,
artifact hashes and per-mode results are in the [JSON receipt](posix-stop-lifetime.json).

Reproduce in a private working directory, with the pinned compiler/runtime:

```
cc -std=c17 -Wall -Wextra -Werror tests/basis/fixtures/posix_stop_resume.c -o stop-oracle
./stop-oracle
bin/rune tests/basis/harness.sml tests/basis/fn/posix_child.sml tests/basis/posix_process.sml tests/basis/fixtures/posix_stop_resume.sml tests/basis/finish.sml -o probe.rbc
bin/runevm --jit=all --jit-tier=2 probe.rbc
```

The new fixture changes one of the 558 previously compared test/dependency
inputs. The 591 production source blobs remain unchanged. Targeted host
matrix and portability validation follow separately; prior full receipts
remain dated evidence for their original snapshots.

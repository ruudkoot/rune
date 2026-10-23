# Basis Library suite

| Configuration | Test | Checks | Pass | Explained | Unexplained | Skipped | Not run |
|---|---|---|---|---|---|---|---|
| rune | posix_process | 77 | 77 | 0 | 0 | 0 |  |
| rune | posix_process_sig | 5 | 5 | 0 | 0 | 0 |  |
| xc1:mlton@20241230 | posix_process | 77 | 76 | 1 | 0 | 0 |  |
| xc1:mlton@20241230 | posix_process_sig | 5 | 5 | 0 | 0 | 0 |  |
| xc1:smlnj-legacy@110.99.9 | posix_process | 77 | 75 | 2 | 0 | 0 |  |
| xc1:smlnj-legacy@110.99.9 | posix_process_sig | 5 | 5 | 0 | 0 | 0 |  |
| xc1:smlnj32@110.99.9 | posix_process | 0 | 0 | 0 | 0 | 0 | NA Posix |
| xc1:smlnj32@110.99.9 | posix_process_sig | 0 | 0 | 0 | 0 | 0 | NA Posix |
| xc1:smlnj-dev@2026.2 | posix_process | 77 | 75 | 2 | 0 | 0 |  |
| xc1:smlnj-dev@2026.2 | posix_process_sig | 5 | 5 | 0 | 0 | 0 |  |
| xc1:polyml@5.9.2 | posix_process | 77 | 71 | 6 | 0 | 0 |  |
| xc1:polyml@5.9.2 | posix_process_sig | 5 | 5 | 0 | 0 | 0 |  |
| xc1:mlkit@4.7.25 | posix_process | 77 | 71 | 6 | 0 | 0 |  |
| xc1:mlkit@4.7.25 | posix_process_sig | 5 | 5 | 0 | 0 | 0 |  |

## Explained deviations

| Configuration | Check | Category | Reason |
|---|---|---|---|
| xc1:mlkit@4.7.25 | Posix.Process.exece/empty-environment | HOST-BUG | exece (and so Unix.executeInEnv) with the environment [] passes on the environment of the process: the runtime installs the list only when it is not empty |
| xc1:mlkit@4.7.25 | Posix.Process.execp/with-slash | HOST-FLAKY | the check makes its script executable with chmod, which on MLKit sets every mode to 1001, so its owner may not run it and the child's exec fails; root, for whom one execute bit is enough, passes the check (docs/bugreport/mlkit/Posix.FileSys.chmod/open-flags-as-mode) |
| xc1:mlkit@4.7.25 | Posix.Process.exit/no-flush | XC1-NA | the file handles of tests/basis/host/rune-prim.sml write through (file_write), where the VM's keep the block that TextIO leaves them to buffer: what the child wrote before Posix.Process.exit is in the file already (and on SML/NJ 110.79 the check raises Overflow first, at the Time.now of C.waitBounded: microseconds since 1970 in a 31-bit int; on Poly/ML the child's exit fails too, as in Posix.Process.exit/status) |
| xc1:mlkit@4.7.25 | Posix.Process.fromStatus/system-exit-200 | HOST-BUG | the status of a process that did not succeed is W_EXITSTATUS 0w255 whatever its exit status or signal: OS.Process.system and Unix.reap reduce every failure to OS.Process.failure (an int, ~1), which fromStatus maps to W_EXITSTATUS 0wxFF |
| xc1:mlkit@4.7.25 | Posix.Process.fromStatus/system-exit-3 | HOST-BUG | the status of a process that did not succeed is W_EXITSTATUS 0w255 whatever its exit status or signal: OS.Process.system and Unix.reap reduce every failure to OS.Process.failure (an int, ~1), which fromStatus maps to W_EXITSTATUS 0wxFF |
| xc1:mlkit@4.7.25 | Posix.Process.fromStatus/system-killed | HOST-BUG | the status of a process that did not succeed is W_EXITSTATUS 0w255 whatever its exit status or signal: OS.Process.system and Unix.reap reduce every failure to OS.Process.failure (an int, ~1), which fromStatus maps to W_EXITSTATUS 0wxFF |
| xc1:mlton@20241230 | Posix.Process.exit/no-flush | XC1-NA | the file handles of tests/basis/host/rune-prim.sml write through (file_write), where the VM's keep the block that TextIO leaves them to buffer: what the child wrote before Posix.Process.exit is in the file already (and on SML/NJ 110.79 the check raises Overflow first, at the Time.now of C.waitBounded: microseconds since 1970 in a 31-bit int; on Poly/ML the child's exit fails too, as in Posix.Process.exit/status) |
| xc1:polyml@5.9.2 | Posix.Process.exit/no-atExit | HOST-BUG | a forked child that calls Posix.Process.exit (or OS.Process.exit) never ends |
| xc1:polyml@5.9.2 | Posix.Process.exit/no-flush | XC1-NA | the file handles of tests/basis/host/rune-prim.sml write through (file_write), where the VM's keep the block that TextIO leaves them to buffer: what the child wrote before Posix.Process.exit is in the file already (and on SML/NJ 110.79 the check raises Overflow first, at the Time.now of C.waitBounded: microseconds since 1970 in a 31-bit int; on Poly/ML the child's exit fails too, as in Posix.Process.exit/status) |
| xc1:polyml@5.9.2 | Posix.Process.exit/status | HOST-BUG | a forked child that calls Posix.Process.exit (or OS.Process.exit) never ends |
| xc1:polyml@5.9.2 | Posix.Process.exit/zero | HOST-BUG | a forked child that calls Posix.Process.exit (or OS.Process.exit) never ends |
| xc1:polyml@5.9.2 | Posix.Process.pause/until-alarm | HOST-BUG | a forked child that pauses is not ended by the signal (alrm, usr1) that ends the same pause in the main process |
| xc1:polyml@5.9.2 | Posix.Process.pause/until-signal | HOST-BUG | a forked child that pauses is not ended by the signal (alrm, usr1) that ends the same pause in the main process |
| xc1:smlnj-dev@2026.2 | Posix.Process.exit/no-flush | XC1-NA | the file handles of tests/basis/host/rune-prim.sml write through (file_write), where the VM's keep the block that TextIO leaves them to buffer: what the child wrote before Posix.Process.exit is in the file already (and on SML/NJ 110.79 the check raises Overflow first, at the Time.now of C.waitBounded: microseconds since 1970 in a 31-bit int; on Poly/ML the child's exit fails too, as in Posix.Process.exit/status) |
| xc1:smlnj-dev@2026.2 | Posix.Process.fromStatus/system-killed | HOST-BUG | OS.Process.system returns failure (W_EXITSTATUS 1) for a command that a signal ended |
| xc1:smlnj-legacy@110.99.9 | Posix.Process.exit/no-flush | XC1-NA | the file handles of tests/basis/host/rune-prim.sml write through (file_write), where the VM's keep the block that TextIO leaves them to buffer: what the child wrote before Posix.Process.exit is in the file already (and on SML/NJ 110.79 the check raises Overflow first, at the Time.now of C.waitBounded: microseconds since 1970 in a 31-bit int; on Poly/ML the child's exit fails too, as in Posix.Process.exit/status) |
| xc1:smlnj-legacy@110.99.9 | Posix.Process.fromStatus/system-killed | HOST-BUG | OS.Process.system returns failure (W_EXITSTATUS 1) for a command that a signal ended |

## Unexplained failures


## Stale deviations


## Files of lib/basis that a host does not load (xc1)

| Configuration | File | First error |
|---|---|---|
| xc1:smlnj32@110.99.9 | word64.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/word64.sml:45.32-45.42 Error: literal '4294967296' is too large for type |
| xc1:smlnj32@110.99.9 | sysword.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/sysword.sml:14.1-14.34 Error: value type in structure does not match signature spec |
| xc1:smlnj32@110.99.9 | int32.sml | ExnDuringExecution |
| xc1:smlnj32@110.99.9 | int64.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/int64.sml:24.32-24.42 Error: literal '4294967296' is too large for type |
| xc1:smlnj32@110.99.9 | position.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/position.sml:10.1-10.37 Error: value type in structure does not match signature spec |
| xc1:smlnj32@110.99.9 | timer.sml | ExnDuringExecution |
| xc1:smlnj32@110.99.9 | posix_process.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/posix_process.sml:60.32-60.52 Error: unbound structure: RuneSysWord in path RuneSysWord.fromWord |
| xc1:smlnj32@110.99.9 | posix_procenv.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/posix_procenv.sml:4.14-4.34 Error: unbound structure: RunePosixProcess in path RunePosixProcess.pid |
| xc1:smlnj32@110.99.9 | posix_filesys.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/posix_filesys.sml:4.14-4.34 Error: unbound structure: RunePosixProcEnv in path RunePosixProcEnv.uid |
| xc1:smlnj32@110.99.9 | posix_io.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/posix_io.sml:4.20-4.46 Error: unbound structure: RunePosixFileSys in path RunePosixFileSys.file_desc |
| xc1:smlnj32@110.99.9 | posix_sysdb.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/posix_sysdb.sml:4.14-4.34 Error: unbound structure: RunePosixProcEnv in path RunePosixProcEnv.uid |
| xc1:smlnj32@110.99.9 | posix_tty.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/posix_tty.sml:13.28-13.48 Error: unbound structure: RuneSysWord in path RuneSysWord.fromWord |
| xc1:smlnj32@110.99.9 | posix.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/posix.sml:22.23-22.39 Error: unbound structure: RunePosixProcess |
| xc1:smlnj32@110.99.9 | unix.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/unix.sml:67.41-68.103 Error: operator and operand do not agree [tycon mismatch] |
| xc1:smlnj32@110.99.9 | windows.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/windows.sml:231.26-232.88 Error: operator and operand do not agree [tycon mismatch] |
| xc1:smlnj32@110.99.9 | pack_real32.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/pack_real32.sml:27.43-27.54 Error: literal '0wx80000000' is too large for type |
| xc1:smlnj32@110.99.9 | seal_sysword.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/seal_sysword.sml:4.1-4.35 Error: value type in structure does not match signature spec |
| xc1:smlnj32@110.99.9 | seal_int32.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/seal_int32.sml:4.1-4.34 Error: value type in structure does not match signature spec |
| xc1:smlnj32@110.99.9 | seal_int64.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/seal_int64.sml:4.1-4.34 Error: value type in structure does not match signature spec |
| xc1:smlnj32@110.99.9 | seal_word64.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/seal_word64.sml:4.1-4.33 Error: value type in structure does not match signature spec |
| xc1:smlnj32@110.99.9 | seal_position.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/seal_position.sml:4.1-4.40 Error: value type in structure does not match signature spec |
| xc1:smlnj32@110.99.9 | seal_timer.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/seal_timer.sml:5.1-5.33 Error: value type in structure does not match signature spec |
| xc1:smlnj32@110.99.9 | seal_posix.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/seal_posix.sml:4.1-4.247 Error: type syserror does not match definitional specification |
| xc1:smlnj32@110.99.9 | seal_unix.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/seal_unix.sml:4.1-4.120 Error: value type in structure does not match signature spec |
| xc1:smlnj32@110.99.9 | seal_windows.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/seal_windows.sml:5.32-5.39 Error: unbound structure: Windows |
| xc1:smlnj32@110.99.9 | seal_pack_real32.sml | /home/ruud/rune/.worktrees/runeffi-acceptance/tests/out/matrix-final-18c353b49/xc1-smlnj32-110.99.9/basis/basis/seal_pack_real32.sml:4.69-4.82 Error: unbound structure: PackReal32Big |

## Timing

| Configuration | Work s | Fallback s | Preparation |
|---|---:|---:|---|
| rune | 6.7 | 0.0 | probed 1 loads, 1.948 s |
| xc1:mlton@20241230 | 36.6 | 0.0 | cached 0 loads, 0.657 s |
| xc1:smlnj-legacy@110.99.9 | 6.4 | 0.0 | cached 0 loads, 0.648 s |
| xc1:smlnj32@110.99.9 | 0.0 | 0.0 | cached 0 loads, 0.653 s |
| xc1:smlnj-dev@2026.2 | 9.8 | 0.0 | cached 0 loads, 0.674 s |
| xc1:polyml@5.9.2 | 35.0 | 0.0 | cached 0 loads, 3.644 s |
| xc1:mlkit@4.7.25 | 34.5 | 0.0 | cached 0 loads, 8.697 s |

The runner receipt records wall time, CPU use, job-slot utilization and slowest cases. Producer dependencies replace probe waiting.

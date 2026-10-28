# Investigation, 2026-10-28

The original abort remains **unreproduced and its cause unconfirmed**.
The investigation found and reproduced an allocation-failure defect in
the x86-64 encoder. Its repair is not evidence that it caused the original
abort: no core or allocation-failure record survives from that process.

## Preserved original program

The snapshot `/home/ruud/rune/.worktrees/lint-mut` still holds the original
artifacts. Every file under its `runtime/` was compared with `d551f19dd`
and matched. Its sources and binaries were not edited. Ten additional
reruns used the harness's exact absolute VM, compiler, and output paths;
the output was initially absent and each newly created output was removed
after its hash was recorded.

| Artifact | SHA-256 |
|---|---|
| `bin/runevm` | `269f2edfb6ff3c659f390e79390244144ce1bc71a42819f9fce41045129763ba` |
| `e3work/r2b/good.rbc` | `b729c76147016df3d10f91bed86046ef9ba1cbd7f4782f06480fc7815bd5f8df` |

The reported compile produced MD5 `7bd4d9b899158b180d9a397dbb3dafff`
and SHA-256 `2fe471063920ecafca475d424170babdcd3efb53f67db632e177708e20bb1711`
in successful reruns, agreeing with the report's saved output hash.

## Confirmed encoder defect

`ref_room` in `runtime/register/jit/x64.c` grew two arrays with consecutive
`realloc` calls and only then updated the owner's pointers. If the first
call moved the references array and the second call failed, the label
retained the freed old address. Cleanup freed that address again. The
opposite partial-success case also left ownership inconsistent.

A small driver filled a label's first four references, forced the next
references allocation to move, and failed the following tables allocation.
AddressSanitizer reported a double free at `x64_label_free`, with the old
allocation freed during the first reallocation. The same driver completes
with the repair, which commits each successful reallocation immediately.

Failure handling also allowed label references and patches after byte
emission had failed. A reference could then describe bytes that were never
allocated. Failed encoders now stop recording and applying patches, and
patch offsets are checked against the emitted buffer.

`tests/register/x64_fail_test.c` exercises the production encoder with an
allocator that always moves successful reallocations. It fails each of
the workload's ten allocation calls in turn, finishes the workload, and
checks cleanup. This passes with ASan and UBSan; leak detection was disabled
because LeakSanitizer cannot inspect processes in this sandbox. The test's
own allocation table independently checks for retained or invalid frees.
The final fixtures for both encoders also pass outside the sandbox with
LeakSanitizer enabled.

### AArch64 failure handling

The AArch64 encoder uses a single `A64Fix` array and does not have the
paired-reallocation double free. It did continue emission, reference
recording and patching after failure. If a table word needed a larger
buffer and that allocation failed, binding its label wrote beyond the old
buffer. `tests/register/a64_fail_test.c` reproduced a heap-buffer-overflow
under ASan at `put32`, called by `patch` and `a64_bind`, immediately beyond
the allocated 1024 bytes. The original diagnostic is retained locally in
`/tmp/rune-heap-investigation/a64-fail-before.log`.

The repair stops those operations once the encoder has failed and checks
patch offsets before forming a pointer. The fixture fails each of eight
allocation calls, checks failed table writes with forward and bound
labels, and rejects incomplete or out-of-buffer patch locations. Both
architectures use a shared moving allocator that checks ownership and
rejects further allocation attempts after failure. This ARM defect cannot
explain the original x86-64 incident.

### Trampoline padding after failure

The final review also found padding loops in both portable assembler
implementations that waited for the buffer position to advance after the
encoder had failed. The Windows x86-64 trampoline has a second such loop
for trailing padding. Both extended allocation fixtures timed out after
two seconds before repair (`trampoline-before.log`); they now return and
pass ASan, UBSan and LeakSanitizer. Their shared `trampoline_probe.h`
fails every allocation of a 300-trampoline workload in both calling
conventions, and checks an already failed, unaligned buffer. Each padding
loop now stops when `failed` is set. Successful encodings are unchanged.

## Attempts to reproduce the original incident

All of these use the preserved original VM and compiler, not the repair:

| Check | Result |
|---|---|
| Valgrind Memcheck, original default-JIT compile | Completed, 0 errors |
| Memcheck with address space starting above 4 GiB and allocated/freed-memory fill patterns | Completed, 0 errors |
| Memcheck with all functions at tier 2 and a fixed 256 KiB nursery | Completed, 0 errors |
| Memcheck with all functions at tier 2, 64 KiB nursery, and heap verification | Timed out after 240 seconds during heap verification; no errors reported before timeout; not a passing completed check |
| Seeded sweep, 256 compiles, two processes at most | All completed with matching bytecode |
| Exact harness command, including absolute paths, timezone, address-space and CPU limits, ten times | All completed with matching bytecode |
| Extended exact-command campaign, 2048 sequential trials alternating ordinary allocation and glibc allocation checks | All completed with matching bytecode (1024 trials in each mode) |

The sweep used seed `20261028`, nursery sizes around the original 1 MiB,
different JIT thresholds, allocator perturbation, and disabled glibc
tcache. Every sixteenth case enabled heap verification. The raw commands,
per-case results, sanitizer output and Memcheck logs are retained locally
under `/tmp/rune-heap-investigation/`; that temporary directory is not a
permanent archive.

These successful runs do not rule out a rare error. In particular they
do not establish that an allocation failed in the October 25 incident.

The kernel journal does retain the abort at **2026-10-25 22:57:05 UTC**,
on CPU 14. WSL's capture message names process 44604 and the original
`lint-mut/bin/runevm` executable, confirming that the abort occurred after
the harness had executed the VM. The recorded registers are at libc's
signal-raising syscall, not at the corrupting write. No OOM or failed
allocation record was found in the ten-minute journal window around it.
The Windows `AppData/Local/Temp/wsl-crashes` directory currently contains
ten much newer dumps, including intentional test-runner crashes; it no
longer contains this incident. The relevant journal window is saved as
`/tmp/rune-heap-investigation/incident-kernel.log`.

## Compiler determinism

An early comparison of VM counts mixed two initial filesystem states:
the output did not exist on the first run and existed thereafter. The
compiler's protection against overwriting an input performs additional
file-identity checks when the output exists. Repeated runs with that state
held fixed had equal counts. Attributing that first-run difference to
clock readings was incorrect.

There was separate avoidable dependence on clocks and process ids in
cache publication: `UnitCache.unique` formatted both to construct temporary
names. A cold-cache probe with controlled clocks and process ids produced
different allocation counts but identical bytecode. With OS-reserved
temporary names instead, the probe produced identical bytecode and counts
for all four tested inputs. Normal pass and unit execution also no longer
samples clocks or accumulates unused timing data; `--pass-stats` still
requests real measurements.

The regression tests cover untimed and measured stages (including nesting
and exceptions), plus repeated whole, uncached-unit, cold-cache, and
warm-cache compiles. Input/output alias protection is preserved. Different
cache states, filesystem errors, and explicit timing requests remain
different executions.

For replayable testing variation, use:

```
bin/rune-test compiler-stress --seed 1 --runs 16
```

This varies nursery sizes and JIT thresholds in a fixed sequence, verifies
the heap every eighth case, compares bytecode and VM counts with the
ordinary run, and retains each command for replay. It does not randomize
normal compilation. The first sixteen-case run completed successfully.

## Validation

The isolated worktree is `compiler-determinism`, based on refreshed
`origin/master` at `9d256dcf8`. Results on October 28:

| Check | Result |
|---|---|
| Full `make check JOBS=6` | 21253 PASS, 3 SKIP (two unsupported native interrupt cases and the uninstalled pinned GMP dependency) |
| Encoder failure fixtures, ASan/UBSan/LeakSanitizer outside the sandbox | Passed: all 10 x86-64 and 8 AArch64 allocation points, failed table words, and AArch64 patch bounds |
| AArch64 instruction encodings, C99 build | Passed |
| Final focused runner selection (both allocation-failure fixtures and reproducible counts, with canaries) | 8 PASS |
| `make test-register-asan JOBS=4` | 1975 PASS |
| Stack VM language/error suite with ASan/UBSan | 915 PASS |
| `make test-stress JOBS=4` | 3238 PASS |
| `make test-portability JOBS=3`, including the Basis matrix and AArch64 JIT bootstrap modes | 4285 PASS |
| `make test-lib-hosts JOBS=3` | 259 PASS |
| Windows main runner selection | 2547 PASS, 4 SKIP (Win32 FFI tests require configured Windows SDK paths) |
| Windows DAP and kernel protocols | Passed |
| Final encoder/trampoline fault fixtures built as C99 for Windows 32/64-bit and AArch64 | Passed on both Windows widths and under AArch64 emulation |
| Normal trampoline bytes before/after padding guards | Identical on both targets, both calling conventions, four initial alignments, 300 trampolines each |
| Rebuilt register VM sanitizer selection after the padding guards | 1975 PASS |
| Final focused encoder/JIT, cross-platform count and image checks | 38 PASS |
| Final native bootstrap, reproducible counts and low-level JIT selection | 22 PASS; native VM binary and modified source hashes match its build record |
| Seeded compiler stress, seed 20261028, 16 cases | All bytecode and counts matched the reference |
| Saved stress commands, seed 1 | Direct shell replay of reference and stressed commands matched bytecode and recorded counts |

The replay command now restores the working directory, the pre-existing
output file, and the runner's lint and arithmetic-backend settings. This
manual-command adjustment was built and checked separately while the full
suite ran; it does not change any scheduled check.

The full check, stress and broad platform runs began before the three final
trampoline-padding guards; they are not a full rerun of those final guards.
Those guards were then checked with
the extended fault fixtures, byte-for-byte comparisons of successful
encodings, rebuilt sanitizer/platform VMs and the focused checks above.

The first full build was blocked by the sandbox's SML/NJ 32-bit execution
restriction. Its unrestricted replacement was interrupted to include the
AArch64 repair; it had reported no failures, but was not a completed check.
The Windows Basis matrix recorded 1929 PASS, 2 FAIL and 3 dependent SKIP.
The `io_functors` collection failed before running its test, and `io_sig`
failed during process startup. Both reported
`UtilAcceptVsock:273: accept4 failed 110`; the first arose during the
`%TEMP%` lookup.
Repeating both collections and comparisons with `RUNE_WINDOWS_DIR` set
to the verified existing worktree directory passed, as did the deferred
stale-deviation check and full matrix report. The original failed receipt
is retained; those retries do not make the original run clean.

The first separate Windows protocol invocation failed because its custom
log directory had not been
created; creating it and rerunning both protocols passed. This setup
failure and its successful retry have separate logs.
Complete command logs are retained locally under
`/tmp/rune-heap-investigation/`. The runner pruned earlier per-test receipt
directories through its normal retention; the Windows failure receipts
and later completed receipts were copied to that directory's `receipts/`
folder before further checks.
The encoder defect and the determinism changes are separate from the
unresolved attribution of the original incident.

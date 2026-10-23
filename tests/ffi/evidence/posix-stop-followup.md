# Stopped-child fixture follow-up — 2026-10-23

Component `de587836f` changes only the test fixture and its causal probes.
The strict focused matrix passes **46 PASS, 2 SKIP, 0 FAIL** from 48 runner
jobs, in **75.0 s wall / 91.6 s CPU**. It selects `posix_process` and its
signature on Rune and the six native hosts with Rune's Basis. Both the
original negative wait check and the new deliberate-resume regression pass
on every available configuration. SML/NJ32's two Posix suites remain the
existing explicit `NA Posix` skips.

This does not mean that every native-host assertion passes: the programs
retain 17 existing explained host/shim failures elsewhere in the suite.
The [matrix report](posix-stop-matrix-report.md) gives every configuration's
77-check outcome, its five signature checks, and those explanations.
No deviation or 120-second load limit changed.

Eight focused portability runs pass **77/77 assertions each**: Linux32
stack/register interpretation; AArch64 stack/register interpretation and
both JIT tiers; PPC64 stack/register interpretation. The binaries are the
frozen FFI-enabled cross VMs used by the prior release gates; their hashes,
commands and actual results are in the [JSON receipt](posix-stop-followup.json).
Linux32 executes natively, and AArch64/PPC64 use QEMU 8.2.2. No unsupported
Linux32 or PPC64 JIT execution is claimed.

The first focused matrix setup failed **43 PASS, 2 SKIP, 3 FAIL**. The
copied producer metadata still named its old absolute directory, so MLKit
recopied 255 shared Basis files into each test's private source tree and
hit the 120-second compile bound. The unchanged signature-only program
failed too. This was an acceptance setup error, not a compiler defect or a
fixture failure. A repair attempt was interrupted after an unreadable
compiler lock file prevented the metadata correction. Those attempts are
retained separately from the successful run.

The successful setup relocates only producer metadata and verifies all
1,536 copied generated Basis SML source files remain identical. MLKit then
loads the changed fixture in 20.4 s and its signature in 14.2 s, with the
same 120-second bound. Original full-matrix outputs were preserved.

All 591 production source blobs remain unchanged. Of the 558 original
selected library/test/matrix inputs, only `tests/basis/posix_process.sml`
changes. These targeted runs bridge that fixture change to the prior full
matrix and library-host receipts. The original `303db25bc` full run remains
a failed receipt (**19,694 PASS, 4 SKIP, 1 FAIL**); its exception's actual
cause remains unknown. The independent planted-signal proof establishes
the old fixture's lifetime vulnerability without claiming that the same
signal occurred in that full run. The parent release gate owns the new
complete repository run.

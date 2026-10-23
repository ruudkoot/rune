# Windows: Unicode in paths, arguments and the environment

Option B is implemented on the `windows-unicode` branch (2026-10-21).
Windows text crosses the system layer through wide APIs. Rune strings stay
bytes: ordinary Unicode is UTF-8, and isolated UTF-16 surrogates use
[WTF-8](https://wtf-8.codeberg.page/) so that every native filename can
round-trip. Other malformed byte sequences fail with `OS.SysErr` (`ilseq`).
The Unicode library and source-text decoder still require strict UTF-8.

## The implementation

* `sys_init_args` recovers the wide command line with `GetCommandLineW` and
  `CommandLineToArgvW` before option parsing; other system layers leave the
  arguments alone. The layer owns the replacement arguments until exit.
* Length-aware Windows-local converters preserve lone surrogates and
  embedded NULs, reject malformed and noncanonical WTF-8, and use growing
  storage. No ANSI code page, best-fit mapping or Unicode normalization is
  involved. Registry string types are converted with their lengths and NULs;
  binary and numeric payloads remain exact bytes.
* Files, directories, links, temporary files, executable discovery, process
  creation and environment blocks use wide APIs. So do the registry,
  configuration and account names, volume information, Shell and DDE text.
  Explicit child environments are sorted by Windows' case-insensitive
  ordinal UTF-16 name order. The remaining A APIs take only Rune's own
  ASCII names or no name.
* Ordinary long filesystem paths are made absolute and their separators and
  dot components normalized before adding `\\?\` or `\\?\UNC\`. Returned
  paths now use native Windows drive/UNC syntax and backslashes, with matching
  host syntax in `OS.Path` (the language-server filesystem follow-up). Short paths
  retain DOS-device semantics, and relative symbolic-link targets stay
  relative. Directory patterns in the transient Windows fork transport are
  length-prefixed; the persistent image and bytecode formats are unchanged.
* `OS.Process.getEnv` and `Posix.ProcEnv.getenv` distinguish an absent variable
  from a conversion/allocation failure. No public API or setter was added.

## Native limits

The choice is wide APIs with native Windows limits, without working-directory
emulation. Filesystem paths are no longer limited to 260 characters by Rune;
component and extended-path limits are Windows' UTF-16 limits, and
`pathconf`/`fpathconf` report `PATH_MAX` as indeterminate. Process command
lines are checked in UTF-16 units, including the terminating NUL.

A deep current directory can still prevent a child from starting. Shell
operations have their own path restrictions, DDE peers may have their own
encoding limits, and Unix-domain sockets retain Winsock's UTF-8 pathname
and address-size limits. See Microsoft's [path limits](https://learn.microsoft.com/en-us/windows/win32/fileio/maximum-file-path-limitation)
and [SetCurrentDirectory](https://learn.microsoft.com/en-us/windows/win32/api/winbase/nf-winbase-setcurrentdirectory).
No manifest or machine-wide code-page/long-path setting is required.

## Tests

`make test-windows-text`, also part of `make test-windows`, runs native
32/64-bit W-API oracles and all four VMs. Direct wide calls create and inspect
fixtures independently of Rune's conversions. They cover scalar Unicode,
lone surrogates, malformed WTF-8, Unicode executable names and PATH search,
inherited and explicit environments, an environment over 64 KiB, command-line
limits, registry strings and binary data, extended UNC spelling without a
network share, and filesystem paths beyond 1,040 bytes with links and renames.

The SML integration probes verify arguments and environment errors, stream
reopening and directory positions after fork under a long path, and compile
and execute `λ.sml` using each Windows VM's native compiler bytecode.
A native probe records a skip when Windows itself refuses a deep current
directory; this is the selected native limit, not an emulated capability.
Portable language fixtures pin UTF-8 filenames, directory listings and
arguments with hand-reviewed expected output. The full Windows, native,
documentation, host-matrix and sanitizer/stress checks form final acceptance.

## Acceptance (2026-10-21)

* `make windows` and `make test-windows JOBS=8` passed on the final Windows
  implementation. The focused text suite reported 224 passes, with two
  native deep-current-directory limit skips. Every language/runtime run
  (both widths and bytecodes, plus register tier 2) passed 328 and 30 cases;
  layout counts and cross-platform images agreed. Each Windows Basis
  configuration ran 139,593 checks with zero unexplained failures: 194
  explained deviations (195 on the 32-bit register VM) and six skips.
  Terminal tests passed 13 cases; DAP and kernel passed.
* `make check JOBS=8` passed 17,332 tests: 17,330 passes and the two documented
  native-interrupt skips. This includes documentation and ISA consistency.
  `make matrix-quick JOBS=8` passed Rune and all six host configurations with
  zero unexplained failures; existing host deviations and absent features
  remain recorded by the matrix.
* `make vm-asan test-register-asan test-stress JOBS=8` passed, including the
  register sanitizer/deoptimization and Basis runs and the interpreter/JIT
  GC-stress modes. The stack ASan/UBSan suite separately passed 518 cases.
  A C99 stack VM linked with `SYS=none` and answered `--version` successfully.
* The existing getenv equivalence law passed 100 generated cases on Windows;
  its equality runner already compares exceptions. An independent native
  environment-order probe failed on the unsorted implementation and passed
  after the UTF-16 ordering fix, on both widths. The final Windows suite
  includes that regression. The Windows-only follow-up changes no native
  Linux source.

Validation ran outside the restricted sandbox for Windows interop, native
socket tests and 32-bit SML/NJ execution. No machine-wide settings were changed.

## Native filesystem paths (2026-10-23)

Filesystem results now use native Windows drive and UNC syntax with backslash
separators. The `/C:/...` adaptation has been removed. `OS.Path` understands
drives, drive-relative paths and UNC share roots; Unix/host conversion and
incompatible-volume errors follow the host model in the
[Basis specification](https://smlfamily.github.io/Basis/os-path.html).
`getDir` and `fullPath` include their volume and return canonical paths as
[OS.FileSys requires](https://smlfamily.github.io/Basis/os-file-sys.html).
Canonical Windows paths preserve native case and bytes, including WTF-8.
This intentionally differs from the Basis lowercase-only Windows system note,
because [case-sensitive NTFS directories and WSL shares](https://learn.microsoft.com/en-us/windows/wsl/case-sensitivity)
must remain usable.
The empty-volume/root-relative reading and UNC extension are documented once
in the `OS_PATH` signature.

Rebuild bytecode and saved images that embed the earlier Unix-only `OS.Path`
before using them with the updated Windows VM.

Restoring a saved image refreshes the host path syntax. Compiler projects
select their path grammar independently of the operating system running the
compiler, so Windows can inspect POSIX overlays and vice versa.

Focused acceptance passed the independent Windows text/oracle cohort (12
runner jobs), native path and filesystem matrices (38 and 30 jobs on all four
VMs), six compiler API cases on Linux and Windows, and all 12 directed saved
image transfers between Linux and both Windows widths across both bytecode
formats. The image fixture checks the restoring host's path syntax. The
complete host-library matrix at `aace898fc` passed 3,196 runner jobs with 156
skips (`20261023-094630-2323736`,
`/tmp/rune-native-path-frozen-matrix.log`). The frozen full repository check
also passed 19,445 jobs with three skips (`20261023-102438-2394411`,
`/tmp/rune-native-path-frozen-full-check.log`). These receipts cover
`aace898fc`; interrupted and earlier failed runs remain separate results.

The mixed-case follow-up caught a gap in those earlier receipts: `fullPath
"Makefile"` produced a nonexistent `makefile` on the WSL share. The canonical
text model now preserves path-component case; volume comparison still ignores
ASCII case and separators. Three specification checks retain their normative
lowercase expectations and have explicit RUNE-DEV entries. Native path-case
fixtures separately verify case preservation, identity and relative paths.
The corrected library passed the Windows text/oracle cohort (12 runner jobs),
the path and filesystem matrices on all four VMs (38 and 30 jobs), and the
mixed-case language fixture on both widths and bytecode formats. The path
matrix has exactly the three documented casing deviations per configuration,
with no unexplained failures or stale deviations.

The full native suite also exposed a Unix-only assertion in
`tests/lang/basis.posix_files.sml`: a home directory was considered absolute
only when it began with `/`. The fixture now uses `OS.Path.isAbsolute`.
Both native widths return the existing home directory in drive syntax, and
the corrected fixture passes on all four Windows VMs. The fixture now checks
the native-path contract with the portable predicate.

Native absolute library paths now use the host path predicate in the shared
compiler/documentation library resolver. The previous slash-prefix test
prepended the installed library root to a drive path returned by `fullPath`.
Seven public API cases pass on Linux interpreter/JIT, all six SML hosts and
both Windows widths. An independent native before/after probe reproduces the
bad manifest path and verifies the corrected library loads.

Documentation source paths also retain Windows volumes during normalization
and use percent-encoded `file:` URLs for drive/UNC sources. The versioned
absolute-library fixture verifies its source link against the original file.
Both native widths additionally passed drive, UNC, space and Unicode path
probes against an independent URI oracle. The documentation consistency and
31-case generator cohort passed.

The full run at `92cadd504` exposed a staging race in the shared count oracle:
parallel cases could overwrite the same `prog.rbc`. Count and image invocations
now atomically reserve separate endpoint directories. A deterministic nested
invocation reproduces the failure with the shared-directory control and passes
with private staging. All Windows count/image jobs pass (34 and 13 runner jobs);
the earlier full receipt remains a failed result.

The case-preserving filesystem checkpoint `ff1bfd7ac` passed the full Linux
check: 19,490 passes and three skips (`20261023-141152-3350968`,
`/tmp/rune-native-case-frozen-full-check.log`). Its complete host-library
matrix passed 3,196 jobs with 156 skips (`20261023-140244-3279385`,
`/tmp/rune-native-case-frozen-matrix.log`). These receipts cover the corrected
case policy; the later native library/source-URL and oracle fixes have their
separate focused and native receipts above.

Retained native failures are `ff1bfd7ac` with five Unix-prefix home-fixture
failures and one WSL launch error (2,382 passes, six failures), followed by
`92cadd504` with the shared count-staging failure (2,387 passes, one failure).
The exact WSL launch case passed with explicit native storage and separate
history (`20261023-153851-3928348`, eight runner jobs). Neither failed full
run is reclassified as clean by those focused reruns.

At `767dc8d9a`, all 2,388 Windows language/runtime jobs passed
(`20261023-163455-303320`). Its Basis matrix then exposed two remaining test
assumptions on each VM: the opaque OS signature check hardcoded `a/b`, and
the volume-information fixture still constructed `/C:/`. The signature check
now verifies parsed arcs, and the volume check uses `OS.FileSys.fullPath` for
the root. Both corrected fixtures pass all four configurations (22 and 38
runner jobs). The failed full matrix remains recorded as 1,909 passes and
nine failed jobs, including its aggregate report (`20261023-165916-411560`).

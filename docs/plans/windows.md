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
  The remaining A APIs take only Rune's own ASCII names or no name.
* Ordinary long filesystem paths are made absolute and their separators and
  dot components normalized before adding `\\?\` or `\\?\UNC\`. Returned
  paths keep Rune's `/C:/...` and forward-slash conventions. Short paths
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

# Windows: the build (done) and the `Windows` structure (scoped)

## The build

`make windows` builds the VM for Windows with mingw-w64 and `make
test-windows` runs the language suite on it. Both are apart from every other
target: `make check` never compiles `vm/sys_win.c`, and nothing else in the
tree depends on it. Only the VM differs -- the compiler, the library and the
bytecode are the ones everything else uses -- so the suite runs with the
ordinary `bin/rune` and `bin/runevm.exe`. Running an `.exe` needs Windows, or
WSL, which starts one for you.

`vm/sys_win.c` implements the system layer with the CRT of mingw and Win32:
the clock (`GetSystemTimeAsFileTime`, `GetProcessTimes`), the calendar,
files, directories (`FindFirstFile`), descriptors, the environment
(`GetEnvironmentStrings`) and `system`. It answers `ENOSYS` for what belongs
to POSIX and has no counterpart worth faking. Two things it does that are
not obvious:

* every path it hands back is written with `/`, because Rune's `OS.Path` is
  the one of POSIX and the CRT of Windows takes either separator;
* the standard streams are put in binary mode before `main` runs, since a
  Rune string is bytes and a `\n` must stay one byte.

**127 of the 136 programs of `tests/lang` pass.** The nine that do not are in
`tests/windows-skip.txt`: four want sockets, three want POSIX processes and
file modes, one wants `poll`, and one prints a year before 1970, which
Microsoft's `strftime` refuses where POSIX formats it.

## The `Windows` structure

Not implemented, and this is what it would take. `WINDOWS` is optional in the
specification and is the one structure that only `make test-windows` could
ever exercise.

| Part | What it needs from the system layer |
| --- | --- |
| `Key` | nothing: the access flags of the registry are constants (`KEY_ALL_ACCESS` and the rest) |
| `Status` | nothing: the exit codes a process may give are constants |
| `Config` | `GetVersionEx` or the version helpers, `GetSystemDirectory`, `GetWindowsDirectory`, `GetComputerName`, `GetUserName` |
| `Reg` | the registry: `RegOpenKeyEx`, `RegCreateKeyEx`, `RegCloseKey`, `RegDeleteKey`, `RegDeleteValue`, `RegEnumKeyEx`, `RegEnumValue`, `RegQueryValueEx`, `RegSetValueEx`, and the value types (`REG_SZ`, `REG_DWORD`, `REG_BINARY`, `REG_MULTI_SZ`, `REG_EXPAND_SZ`), which `Reg.value` is a datatype of |
| `DDE` | `DdeInitialize`, `DdeConnect`, `DdeClientTransaction`, `DdeDisconnect`, `DdeUninitialize`, and the string handles around them |
| `execute`, `simpleExecute`, `reap`, the stream accessors | `CreateProcess` with `STARTUPINFO` redirecting the three handles to pipes made with `CreatePipe`, and `WaitForSingleObject` with `GetExitCodeProcess`; the streams then have to reach `TextIO` and `BinIO` through the descriptor layer, as `Unix.execute` does on POSIX |
| `getVolumeInformation` | `GetVolumeInformation` |
| `findExecutable`, `launchApplication`, `openDocument` | `FindExecutable` and `ShellExecute`, which are of the shell library and not of the C runtime |

The work is about the size of the `Posix` structure: a new group of calls in
`vm/sys_win.c` behind new entries of `vm/sys.h`, which every other system
layer then has to answer `ENOSYS` for, plus the SML and a suite that can only
run under `make test-windows`. `DDE` is the odd one: it is an interface
Microsoft has not recommended since the 1990s, and a conforming `Windows`
needs it all the same.

**Recommendation.** Do `Key`, `Status`, `Config` and `Reg` first -- they are
self-contained, and the registry is what a program actually wants from this
structure -- then the process group, which shares its shape with
`Unix.execute` and can borrow its tests. Leave `DDE` last and let it raise
`SysErr` with `ENOSYS` until something wants it; the structure will not match
`WINDOWS` until it is there, so it stays out of the claims and out of
`structures.md` until then.

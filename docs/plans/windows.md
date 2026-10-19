# Windows: Unicode in paths, arguments and the environment

Claude, 2026-10-19, at the close of the utf8 roadmap
([utf8.md](utf8.md): found in M0, *What is wrong today*; left to *Later*).
Nothing here is started. It records the problem and the two ways out, for
the owner to decide.

## The problem

Rune's strings are bytes, and the compiler and the Basis Library treat a
path, an argument or an environment variable as UTF-8 (`OS.FileSys`,
`OS.Path`, `CommandLine`, `OS.Process.getEnv`). On Windows the VM hands
those bytes to the "A" functions of the Windows API, which read them in the
ANSI code page of the system (Windows-1252 in western Europe), and takes
the narrow `argv` that the C runtime makes in the same code page. So,
beyond ASCII:

* **`rune λ.sml` does not find the file.** `CreateFileA` reads the two
  bytes of `λ` as two Windows-1252 characters, `Î»`. A file that a
  program creates under a non-ASCII name gets such a name too.
* **Non-ASCII arguments are lost before the program sees them.** The C
  runtime turns the UTF-16 command line into the ANSI code page: a
  character the code page lacks becomes `?`, or a "best fit" lookalike,
  so that `CommandLine.arguments ()` holds neither the character nor its
  UTF-8.
* **The environment, the current directory, directory listings, symbolic
  links and the names of users and machines** go the same way, in both
  directions.

What works already: the console. Output is switched to code page UTF-8 at
start-up (`runtime/sys/sys_win.c:88`), and typed input is read as UTF-16
and handed on as UTF-8 (`runtime/sys/sys_win.c:3499`), so the REPL and
diagnostics can show Unicode on Windows' console.

## Where it is

* `runtime/main.c:95`: `int main(int argc, char **argv)`, the narrow
  `argv`.
* `runtime/sys/sys_win.c`: 75 calls of 43 "A" functions:
  - **files and directories:** `CreateFileA` (`:487`, `:849`, `:1380`, the
    last the one every open goes through: `open_fd`, `sys_openf`,
    `sys_fopen`), `GetFileAttributesA` (12 calls), `SetFileAttributesA`,
    `DeleteFileA`, `CreateDirectoryA`, `RemoveDirectoryA`, `MoveFileExA`,
    `FindFirstFileA` and `FindNextFileA`, `GetFullPathNameA`,
    `GetFinalPathNameByHandleA`, `CreateSymbolicLinkA`, `CreateHardLinkA`,
    `GetTempPathA`, `GetCurrentDirectoryA`, `SetCurrentDirectoryA`, and
    `WideCharToMultiByte(CP_ACP, ...)` for a link's target (`:757`);
  - **processes:** `CreateProcessA`, `ShellExecuteA`, `FindExecutableA`,
    `GetModuleFileNameA`;
  - **the environment:** `GetEnvironmentStringsA`,
    `SetEnvironmentVariableA`, and the C runtime's `getenv` and `_putenv`
    (here and in `runtime/main.c`, `runtime/runtime.c`);
  - **the registry, names and the rest:** the `Reg...A` functions of the
    `Windows` structure, `GetUserNameA`, `GetComputerNameA`,
    `GetComputerNameExA`, `LookupAccountSidA`, `GetWindowsDirectoryA`,
    `GetSystemDirectoryA`, `GetVolumeInformationA`, the DDE functions, and
    `WideCharToMultiByte(CP_ACP, ...)` for the version string (`:3125`).
    `CreateEventA`, `CreateJobObjectA` and `GetModuleHandleA` take names of
    Rune's own, in ASCII, and need nothing.
* Paths are held in buffers of `MAX_PATH` (`path_buffer`, `MAX_PATH * 4`),
  so a path is also limited to 260 characters: a separate problem that the
  second way below would solve as well.

## Two ways out

**A. A manifest that makes UTF-8 the process's code page.** An
application manifest with `<activeCodePage>UTF-8</activeCodePage>`,
linked into `runevm.exe` as a resource (`windres`, beside the mingw-w64
build of `make windows`), makes every "A" function, `GetCommandLineA` and
so the C runtime's `argv`, and `getenv` speak UTF-8, with no change to
the code. Windows takes it from Windows 10 version 1903 (May 2019) on;
before that it is ignored, and the VM behaves as it does today.
- Cost: a manifest, a resource script and two lines of the `Makefile`.
- Risk: `GetACP` then answers 65001 for the whole process, and a library
  that assumes a single-byte code page would break; the VM has none.
  `WideCharToMultiByte(CP_ACP, ...)` turns into UTF-8 by itself.
- What it leaves: older Windows, and the 260-character limit.

**B. The "W" functions.** Every path, argument and variable converted
between UTF-8 and UTF-16 where it meets Windows (`MultiByteToWideChar` and
`WideCharToMultiByte` with `CP_UTF8`), `wmain` or `GetCommandLineW` with
`CommandLineToArgvW`, `GetEnvironmentStringsW`, and paths given the `\\?\`
prefix where they are long.
- Cost: the 75 calls, one helper for each direction, and buffers that grow.
- Works on every Windows that Rune runs on, and lifts the 260-character
  limit.
- Two questions it must answer: a path in a Rune `string` that is not
  UTF-8 (refuse it with `OS.SysErr`, as the strict `Utf8` of `lib/unicode`
  would, rather than replace a byte), and a name on disk that is not
  well-formed UTF-16 (a lone surrogate, which NTFS allows and UTF-8
  cannot hold: refuse it, or carry it as WTF-8).

**Recommended: A now, B if older Windows or long paths come to matter.**
A is a small change with no risk to what works. B is the complete answer,
and A does not stand in its way.

## How to test it

`make test-windows` runs the Windows VMs through WSL's interop
([testing.md](../testing.md)). It would gain a program that:

* is started with an argument `λ`, and prints `CommandLine.arguments ()`'s
  bytes;
* creates `λ.txt`, writes to it, reads it back, finds it in
  `OS.FileSys.readDir`'s listing and removes it;
* sets and reads back an environment variable whose value is `é`;
* and is compiled from a source file named `λ.sml` (`rune λ.sml`).

Each prints the UTF-8 it saw, and the expected output is the same as on
Linux.

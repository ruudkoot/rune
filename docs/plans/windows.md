# Roadmap: Rune on Windows

Written 2026-09-22 on commit `667eef6` (branch `docgen`). The VM builds for
64-bit Windows, and 127 of the 136 programs of `tests/lang` pass on it. This
roadmap does four things:

* builds and tests a 32-bit VM beside the 64-bit one;
* runs the Basis Library suite on both;
* cuts `tests/windows-skip.txt` from nine programs to the one or two that
  print what only Linux prints;
* then adds the `Windows` structure.

Every number below was measured on that commit unless it is marked as an
estimate.

## Status

| Milestone | State |
|---|---|
| M0, the 64-bit VM (`make windows`, `make test-windows`) | done (`667eef6`): 127 of 136 programs of `tests/lang` pass; 9 in `tests/windows-skip.txt` |
| M1a, the core fixes a 32-bit VM needs | done: growing the heap stops with "out of memory" where it wrapped, the loader's bound cannot wrap and the loader reads to the end of the file, `bytes_allocated` is 64 bits, `--heap-size` and `--gc-stress` refuse what is not a size; `sys_ftell`/`sys_fseek` give `BinIO` 64-bit positions everywhere; `tests/vm` (9 cases, part of `make test`) |
| M1b, two widths | done: `bin/runevm.exe` and `bin/runevm32.exe` (SSE2, large-address-aware), both importing only `KERNEL32.dll` and `msvcrt.dll`; 127 of 136 on both, `tests/vm` 9 of 9, and `--count` agrees with `bin/runevm` on four programs; the runner compiles once, runs in parallel on NTFS with `TZ` (1 m 29 s for both VMs, where one took 9.5 minutes), which showed that msvcrt's `_stat64` shifts file times by `TZ`: they are now read and set in UTC |
| M2, the Basis suite on both Windows VMs | done: `rune:windows` and `rune:windows32` in `run-matrix.sh`, run by `make test-windows`, each program in its own directory on NTFS; the category `WINDOWS` of `deviations.txt`, which `gen-annotations.sh` leaves out like the lines of `rune`. **Baseline** (M1b, 7 minutes): 963 of 137,016 checks fail on the 64-bit VM, 1,004 of 137,084 on the 32-bit one; `timeout` ends the Windows process too |
| M3, constants, errors and two quick wins | done: a table of the named constants (the numbers of Linux for what the layer decodes itself, Winsock's for what goes to Winsock), every error of POSIX with glibc's text, the error cleared where POSIX clears it, `getpid` and the ids checked by the library, the addresses of sockets without a socket, a file on disk ready for `poll`; `basis.inet6sock` and `basis.os.io_poll` leave the skip list and `basis.posix_seek` joins `tests/lang`; the Basis suite: 667 of 137,054 checks fail on either VM (963 and 1,004 before), each explained by a `WINDOWS` line that names its milestone |
| M4, a C-locale `strftime`, reals in the rounding mode, local time in any year | done: `Date.fmt` is formatted in the core as glibc formats it in the C locale (780 lines of edge years and every directive agree with glibc), only `%Z` of a local date asks the system; `Real.fromString` reads in the rounding mode on every C library (132 numerals in four modes agree with glibc, subnormals and overflow included); the layer of Windows reaches local time outside 1970 to 3000 by 400-year cycles. `basis.date_year_of_c` leaves the skip list and `basis.date_local_before_1970` joins `tests/lang`; Basis suite: 661 failures on either VM, all explained. Found on the way: glibc keeps no summer time before 1970 under a POSIX `TZ` rule, where the layer of Windows follows the rule in every year |
| M5, sockets over Winsock | done: sockets in a table beside the descriptors of msvcrt, `WSAPoll`, the databases of ws2_32, AF_UNIX streams and their pairs, and five differences of Winsock found by the tests and made good (below); `basis.inetsock_addresses`, `basis.netdb_lookup` and `basis.socket_loopback` leave the skip list. In the Basis suite what stays is Windows' own: no datagrams in the Unix domain, `SIOCATMARK`, and a resolver that names `localhost` after the machine |
| M6, POSIX counterparts short of processes | done: ids from the token, the user and groups of the process, `uname`, `times`, `sysconf`, `pathconf`; the console as a terminal; paths of a drive as `/C:/...`, `/dev/null` and `/dev/tty`; `stat` from handles (inode, device, links), owner modes, executables by `PATHEXT`; hard and symbolic links and `readlink`; files that can be removed while open; `fcntl` of files (close-on-exec, append, non-blocking pipes, synchronous), `F_DUPFD`, locks by `LockFileEx`. `basis.posix_files` leaves the skip list as it is. Basis suite: 236 checks fail on either VM (398 before), and what stays is Windows' own -- no bits for a group or others, a file its owner cannot fail to read, no FIFOs, no user `root`, the root of a drive -- or asks `sh` |
| M7, a spawn primitive | done: `posix_spawn` starts a program with three descriptors, `Unix.execute` uses it everywhere (fork, dup2 and exec in C on POSIX, so 126 stays; `CreateProcess` handing on only the three handles on Windows); `exec` without a fork, `waitpid`, `kill`, `alarm`, `pause` and `OS.Process.system` on Windows. `basis.unix_pipes` runs `cmd.exe` on Windows and `basis.posix_process` keeps what every system has; `basis.posix_fork` (FORK) and `basis.posix_linux` (LINUX) are the skip list. Basis suite: 232 checks fail on either VM, the rest of them fork or start the programs of POSIX |
| M8, `poll` beyond sockets and files | done: the reading end of a pipe by `PeekNamedPipe` (its writer gone is the end, ready to be read), the writing end always, the console by a key waiting in its input, `NUL` always; a set of more than sockets is looked at every 10 milliseconds until something is ready or the time is up. Basis suite: 225 checks fail on either VM (232 before), the `poll` of a pipe no longer among them |
| M9 to M11, the `Windows` structure | done, in one commit, since a signature of the library that nothing implements fails `check-claims`: `WINDOWS` transcribed, documented in full and on the ratchet list; `Windows` with the registry, `Config`, DDE, the volume, the shell, programs started with one command line and reaped with their whole code, and `Status`; sixteen primitives `win_*`, which every other system answers with `ENOSYS`. The suite has 93 checks, which pass on Linux (as `ENOSYS`), under the three hosts that compile the library (`xc1`), and on both VMs of Windows but `exit`, which forks: 226 checks of the Basis suite fail on either VM |
| M12, `fork` by carrying the VM across (optional) | not started |

## Where it stands

`make windows` builds `bin/runevm.exe` with `x86_64-w64-mingw32-gcc`, and
`make test-windows` runs `tests/lang` on it (`tests/run-windows.sh`). Neither
belongs to any other target. `make check` never compiles `vm/sys_win.c`.

Only the VM differs from other builds. The compiler, the library and the
bytecode are the ones everything else uses, so the suite compiles with the
ordinary `bin/rune`. Running an `.exe` needs Windows, or WSL, which starts
one for you.

`vm/sys_win.c` implements `vm/sys.h` with msvcrt and Win32:
* the clock (`GetSystemTimeAsFileTime`, `GetProcessTimes`) and the calendar;
* files and directories (`FindFirstFile`), descriptors, the environment and
  `system`.

It answers `ENOSYS` for the rest. Two things it does are not obvious:
* every path it hands back is written with `/`, because Rune's `OS.Path` is
  the POSIX one;
* the standard streams are put in binary mode before `main` runs.

### The toolchains

Both mingw-w64 toolchains are installed here: `gcc-mingw-w64-i686` and
`gcc-mingw-w64-x86-64`, gcc 13.
* Both link msvcrt.dll and build for `_WIN32_WINNT` 0xA00, so `WSAPoll`,
  `inet_pton` and AF_UNIX sockets are there.
* The VM passes `-fsyntax-only -Wall -Wextra` with both.
* Windows 11 (build 22000) runs 32-bit programs under WoW64.
* Developer Mode is on, so a symbolic link needs no privilege.

Nothing more has to be installed for any milestone below.

### What the 127 passing programs do not show

**Every POSIX constant is 0.**
* `sys_const` returns -1 for every name (`vm/sys_win.c:303`). The library
  reads -1 as "not known" and uses 0, so every `O_*`, `SEEK_*`, `AF_*`,
  signal and `Posix.Error` value is 0 on Windows.
* `Posix.FileSys.openf` therefore opens read-only and never creates, and
  `Posix.IO.lseek` with `SEEK_END` seeks from the start. Neither says so.
* `wnohang` (`lib/basis/posix_process.sml:69`) and the `addrType` of
  `NetHostDB` (`lib/basis/netdb.sml:119`) have no guard, so they become all
  ones.
* `sys_openf` decodes the flags as Linux's octal numbers
  (`vm/sys_win.c:354-365`). A constant table has to give those numbers, or
  `sys_openf` has to change with it.
* None of the 127 programs touches any of this: `OS`, `TextIO` and `BinIO`
  never ask for a constant.

**Errors are never cleared.**
* `sys_win.c` sets its error only on failure (`:29`, `:50-52`).
* The POSIX layer sets `errno` to 0 before `read`, `recv`, `readdir`,
  `sysconf` and `pathconf` (`vm/sys_posix.c:327,566,581,668,787,793`).
* The library takes an empty result with error 0 as the end of a stream
  (`lib/basis/socket.sml:110`). A stale error from an earlier call turns an
  end of stream into `SysErr`.
* msvcrt's `strerror` has no text for error numbers from 100 up, which is
  where `EWOULDBLOCK`, `ECONNREFUSED` and the other socket errors are.

**`getpid` is not checked.**
* `Posix.ProcEnv.getpid` (`lib/basis/posix_procenv.sml:39`) takes the
  primitive's result as it is. On Windows that is -1, and the first line of
  `basis.posix_process` raises `Overflow`.

**Four of the nine skip reasons name the wrong cause:**
* `basis.inet6sock` needs no socket: `INet6Sock.fromString` is SML, and only
  the address family and `toAddr`/`fromAddr` reach the system.
* `basis.posix_files` fails at `O_RDWR` being 0.
* `basis.unix_pipes` fails at `Posix.IO.setfd` (`lib/basis/unix.sml:34`),
  before it forks.
* `basis.date_year_of_c` fails because msvcrt's `strftime` takes only the
  years 0 to 9999. `basis.date_calendar` formats 1900 and passes, so the limit
  is not 1970.

**A 32-bit VM needs work, and so does LLP64 on both widths.**
* `Int` and `Word` stay 64 bits on a 32-bit VM. A `Value` holds an
  `int64_t`, a `uint64_t` or a `double` whatever the pointer size, and the
  library measures the precision itself (`int.sml`, `word.sml`). So results
  should not change; that is to be measured, not assumed. What does change:
  * `time_t` is 32 bits in i686's msvcrt, so local dates after 2038 are
    wrong (`sys_date_parts`, `sys_date_seconds`, `sys_date_offset`).
  * Arithmetic is x87 unless the VM is built with `-msse2 -mfpmath=sse`, and
    even then a `double` comes back from a function in an x87 register.
  * The executable is not large-address-aware unless it is linked so.
  * `vm/heap.c:128` doubles `want` until it wraps to 0 and hangs, once live
    data passes 1 GiB.
  * The bounds check of the loader (`vm/loader.c:10-13`) adds `pos + n`,
    which can wrap.
  * `bytes_allocated` (`vm/vm.h:123`) wraps at 4 GiB, and `--count` is meant
    to print the same everywhere.
* On both Windows widths `long` is 32 bits. `ftell` and `fseek` with `long`
  (`vm/loader.c:34`, `vm/prims.c:1442-1466`) truncate positions past 2 GiB.

**The runner.**
* `tests/run-windows.sh` parses `-j` and ignores it; a full run takes about
  9.5 minutes, one program at a time.
* It sets no `TZ`, unlike `tests/run-tests.sh:19`.
* It writes to a fixed `tests/out/windows`, so two VMs would overwrite each
  other.
* Its header says it runs `tests/run-tests.sh`, which it does not.
* It starts each `.exe` in a directory on the Linux file system. Windows sees
  that directory as a `\\wsl.localhost` UNC path served over 9P, not as NTFS.
  `cmd.exe` will not work in it: it warns and falls back to `C:\Windows`.
* Nothing of `tests/basis` runs on Windows at all.

**What makes emulation possible.**
* Rune's Basis has no signal handlers. `Posix.Signal` is only the numbers,
  and the primitives are `kill`, `alarm` and `pause`. So the default action
  of a signal is all a program can ever observe, and emulating that is
  honest, not a fake.
* The whole state of the VM can be listed. The collector's roots
  (`vm/heap.c:89-97`) and a heap that can be walked object by object are all
  there is, which makes M12 possible.

## The skip list: what is realistic

Every program in the skip list wants something Windows has in some form, and
six pass as they stand once the system layer gives it. The other three also
print what only Linux prints:
* `uname` giving `Linux`;
* `/bin/sh` and its syntax;
* a home directory under `/`.

No emulation can give those honestly. Those programs are split: what is
portable stays in the test, and the lines only Linux can print move to a
small Linux-only test. That test would fail on a Mac too, so the split is
worth having for its own sake.

| Program | Passes after | How |
| --- | --- | --- |
| `basis.inet6sock` | M3 | the constants, and `inet_pton`/`inet_ntop` without a socket |
| `basis.os.io_poll` | M3 | a file on disk is always ready, as `poll` says on POSIX |
| `basis.date_year_of_c` | M4 | Rune's own C-locale `strftime` |
| `basis.inetsock_addresses` | M5 | Winsock; AF_UNIX from `afunix.h`; `socketpair` emulated |
| `basis.netdb_lookup` | M5 | Winsock; Windows' `etc\protocol` and `etc\services` have tcp 6, udp 17, http 80 and ssh 22 |
| `basis.socket_loopback` | M5 | Winsock, with `WSAPoll` for `Socket.select` |
| `basis.posix_files` | M6 | once the home directory under `/` moves to the Linux-only test |
| `basis.unix_pipes` | M7 | rewritten with the child chosen by the platform: `/bin/sh`, or `cmd.exe` |
| `basis.posix_process` | M7 | ids, environment and signal numbers stay; `fork` moves to `basis.posix_fork`, `uname` giving `Linux` to the Linux-only test |

The skip list ends with two lines:
* the Linux-only test, category `LINUX`;
* `basis.posix_fork`, category `FORK`, which goes too if M12 is done.

## Constraints for all items

* Each milestone is one or more commits, and each commit leaves `make check`
  green. A change to the VM also passes `make vm-asan && sh
  tests/run-tests.sh --vm bin/runevm-asan` and `make test-stress`.
* `make check` never compiles `vm/sys_win.c`, so a green `make check` says
  nothing about Windows. A milestone is done only when `make windows` builds
  both VMs and `make test-windows` passes on both. From M2 on that includes
  the Basis suite.
* A new primitive goes through `vm/prims.def` and `docs/bytecode.md`, and is
  written on the hosts in `tests/basis/host/rune-prim.sml` for the `xc1`
  configurations.
* The VM core stays C99 with no platform code: what needs the system goes
  behind `vm/sys.h`, and every system layer answers each new call. When
  `sys_posix.c` and `sys_none.c` have nothing to do, they answer `ENOSYS`.
* A change of behaviour updates `docs/language.md` and `tests/lang`
  (`make check-docs`). An `.expected` file is written by hand or reviewed
  line by line.

## Milestones

### M1a. The core fixes a 32-bit VM needs -- S

These need no Windows. They are portable C in the core, so `make check`
covers them, and they come first so that M1b only adds the Windows side.

* Growing the heap stops with "runevm: out of memory" when the doubling
  would overflow, and no longer wraps (`vm/heap.c:128`).
* The loader tests `n > len - pos` in place of `pos + n > len`
  (`vm/loader.c:10-13`). It reads the file to its end, which removes its
  `ftell` (`:34`).
* `bytes_allocated` becomes `uint64_t`.
* `--heap-size` and `--gc-stress` refuse a value that does not fit a
  `size_t` (`vm/main.c:54,61`), where they now truncate it.
* `sys_ftell` and `sys_fseek` join `vm/sys.h`, for `BinIO`'s positions
  (`vm/prims.c:1442-1466`):
  * `ftello`/`fseeko` in `sys_posix.c`;
  * `_ftelli64`/`_fseeki64` in `sys_win.c`;
  * `ftell`/`fseek` in `sys_none.c`.

*Leaves verifiable:* a `.rbc` crafted to wrap the old bounds check is refused
with a message.

### M1b. Two widths -- M

`make windows` builds `bin/runevm.exe` for x86_64 and `bin/runevm32.exe` for
i686. The name follows `bin/rune-smlnj32`: no suffix is 64 bits.
`make test-windows` compiles each program once and runs it on both VMs, and
prints one summary line per VM.

* **The 32-bit build.**
  * `sys_win.c` calls the 64-bit time functions by name: `_localtime64_s`,
    `_gmtime64_s`, `_mktime64`, `_mkgmtime64`, `__time64_t`. That is right on
    both widths. `-D__MINGW_USE_VC2005_COMPAT` does the same in one flag but
    hides it.
  * i686 is built with `-msse2 -mfpmath=sse -Wl,--large-address-aware`.
  * Both widths get `-D__USE_MINGW_ANSI_STDIO=1` spelled out. Every `%zu` and
    `%lld` of the VM depends on it, and `-std=c99` gives it only by accident.
* **What each `.exe` imports** is checked after the link (`objdump -p`): only
  `KERNEL32.dll` and `msvcrt.dll`, later `WS2_32.dll`. The posix-threads
  flavour of mingw would bring `libwinpthread-1.dll`, and the VM would not
  start.
* **The runner.**
  * The results go to `tests/out/windows` and `tests/out/windows32`.
  * `-j` works, with the `xargs -P` scheme of `tests/run-tests.sh`.
  * `TZ` reaches the `.exe` through `WSLENV`.
  * The `.cwarn` files are checked.
  * Each program runs in a scratch directory on NTFS under `/mnt/c`, not on
    the `\\wsl.localhost` path. Without that, M6 would test the 9P redirector
    rather than NTFS, and M7 could not start `cmd.exe`.
  * The header says what the script does.
* **The doctor.**
  * A `windows` scope in `scripts/doctor.sh` compiles a probe with each
    compiler, and the `.exe` rules depend on its stamp.
  * The scope stays out of `all`, so `make doctor` is still green on a
    machine without mingw.
  * The packages for the two compilers are `gcc-mingw-w64-i686` and
    `gcc-mingw-w64-x86-64`.
* **A layout check.**
  * A program of `tests/lang` with `--count` in its `.vmargs` prints its
    counts of bytes and objects.
  * `Value` is 16 bytes and `Obj` 8 on Linux and on both Windows targets, so
    the numbers must be the same on all three.
* **Width markers.** If the two VMs ever differ on a program, its line in
  `tests/windows-skip.txt` names the width. The syntax is added only then.

*Leaves verifiable:* the same result on both VMs, expected to be 127 of 136
each. A difference is either fixed or explained in the skip list.

### M2. The Basis suite on both Windows VMs -- M

The owner's own list asks for a "full check on lang and basis" on Windows,
and the Basis suite exercises far more of the system layer than
`tests/lang`. It comes before the fixes so that each fix is measured.

* **Configurations.** `tests/basis/run-matrix.sh` gets two, say
  `rune-windows` and `rune-windows32`. It already takes `RUNEVM` and runs
  `prog.rbc` by a relative path, which is what an `.exe` needs. But it
  writes `id=rune` whatever the VM (`run-matrix.sh:797-801`), so the Windows
  results need ids of their own.
* **Known failures.**
  * `tests/basis/deviations.txt` gets a `WINDOWS` category.
  * A `RUNE-DEV` or `SPEC-AMBIGUOUS` line for `rune` holds for the Windows
    configurations as it does for `xc1`.
  * Whether the Windows lines reach `gen-annotations`, and so the generated
    pages, is decided here.
* **Checks.**
  * `timeout` in `run-matrix.sh` kills the WSL proxy of an `.exe`. Check that
    the Windows process dies with it.
  * `make test-windows` runs the suite on both VMs after `tests/lang`.

**Expected deviations:**
* Local time: msvcrt reads `NST3:30NDT` from `TZ` and ignores the rule
  `,M3.2.0,M11.1.0`. It applies the rules of the United States, which happen
  to be the same.
* msvcrt refuses a time before 1970 in `localtime` and `mktime`.
* Everything M3 fixes.

*Leaves verifiable:* the number of Windows deviations per VM, written into
the Status table. Every milestone after this one gives its effect as a drop
in that number, as well as a shorter skip list.

### M3. Constants, errors and two quick wins -- S

* **A constant table in `sys_win.c`.**
  * Linux's numbers for what the Windows layer decodes or emulates itself:
    `O_*`, `SEEK_*`, `F_*`, `FD_CLOEXEC`, the signals and `W*`. `sys_openf`
    already decodes those.
  * Winsock's own numbers for what goes to Winsock unchanged: `AF_*`,
    `SOCK_*`, `SOL_SOCKET`, `SO_*`, `IPPROTO_*`, `MSG_*`, `SHUT_*`.
  * Every `E*` name the library asks for, the socket ones included.
* **Errors.**
  * `sys_win.c` names and describes the error numbers itself, where msvcrt
    stops at 99.
  * It clears the error wherever `sys_posix.c` does.
* **The library** checks the results of `getpid`, `wnohang` and `addrType`,
  so a system that lacks one raises `SysErr` and does not give a wrong
  number.
* **Quick wins.**
  * `sys_inet_addr`, `sys_inet6_addr` and their `_parts` use `inet_pton` and
    `inet_ntop`, which need no socket and no `WSAStartup`.
  * `sys_poll` reports a file on disk ready, as POSIX's `poll` does.
  * `poll` of no descriptors sleeps for its timeout, where it now returns at
    once.

*Removes* `basis.inet6sock` and `basis.os.io_poll`. *Leaves verifiable:* a
program that does `Posix.FileSys.createf` and `Posix.IO.lseek` with
`SEEK_END`, which failed without a word before, and a drop in M2's count.

### M4. A C-locale `strftime`, reals in the rounding mode, local time in any year -- S

* **Portable C in the core** formats the directives `lib/basis/date.sml:173`
  lets through, `aAbBcdHIjmMpSUwWxXyYZ%`, the way glibc does in the C
  locale:
  * `%Y` with no padding and a `-` sign;
  * `%c` as `%a %b %e %H:%M:%S %Y`, where msvcrt writes `%m/%d/%y
    %H:%M:%S`;
  * glibc's rule for `%y` of a negative year.
* **The system layer** answers only `%Z`, which reaches C only for a local
  date.
* **`Date.fmt` then prints the same on every platform.** Rune never calls
  `setlocale`, so that is what the specification's `strftime` means here.
  The SML check that a year fits a C `int` stays, because `date_year_of_c`
  expects `Date` beyond it.

* **Reals are read in the rounding mode.** msvcrt's `strtod` and `strtof`
  round to the nearest whatever the mode, where glibc's round in it. The
  core reads a numeral to the nearest and steps it to the other neighbour
  when the mode asks, comparing the numeral with the exact decimal
  expansion of the nearest, so that `Real.fromString` gives the same
  everywhere.
* **Local time in any year.** msvcrt's 64-bit time functions know only the
  years 1970 to 3000. Its rules for summer time are the same every year and
  the calendar repeats every 400 years, so the layer moves a time into
  2370 to 2770 by whole cycles and the year back after.

*Removes* `basis.date_year_of_c`.

### M5. Sockets over Winsock -- M, several commits

* **A socket is a descriptor.** The library holds a socket as the same `int`
  as a file (`lib/basis/socket.sml:41`). So `sys_win.c` keeps a table from
  descriptors to `SOCKET`, in a non-negative range that never meets a CRT
  descriptor.
  * read, write, close, dup, `fstat`, `fcntl`, `sys_desc_kind` (5) and
    `sys_poll` look a descriptor up there first.
  * `O_NONBLOCK` goes through `F_GETFL`/`F_SETFL` to `FIONBIO`. The bit is
    remembered, because Winsock cannot report it.
* **Starting and errors.** `WSAStartup` runs on first use, since `vm/sys.h`
  has no start-up call. `WSAGetLastError` codes become errors of the names M3
  gave them.
* **Polling.** `sys_poll` uses `WSAPoll` when every descriptor in the set is
  a socket, which is what `Socket.select` needs (`socket.sml:281`).
* **Addresses.**
  * AF_UNIX comes from `afunix.h` (Windows 10 1803 and later).
  * `socketpair` is emulated with a listening AF_UNIX socket.
  * The text of `INet6Sock.fromAddr` goes through the SML `fromString`, so
    it is the same on every platform, not whatever `inet_ntop` writes.
* **Databases.** The protocol, service and host databases are ws2_32's.
* **Windows' own behaviours.**
  * `SIO_UDP_CONNRESET` is turned off: otherwise `recvfrom` reports an
    earlier ICMP "port unreachable" as a failure, which POSIX does not.
  * Sockets are made with `WSA_FLAG_NO_HANDLE_INHERIT`, for M7.
* **The link** takes `-lws2_32`.
* **What Winsock does differently, found by the tests.**
  * `SO_REUSEADDR` of Winsock lets a socket bind an address another socket
    is using, where POSIX's only lets it take one a closed connection still
    holds, which Winsock allows anyway: the option is remembered and not
    given to Winsock.
  * Windows gives the port a socket binds when it asks for any, and the
    port of a connection, as the lowest free one. On the loopback interface
    two programs that each listen and connect then swap ports, and the
    second one's connection has the ends of the first one's, which waits
    out TIME_WAIT: `connect` fails with `WSAEADDRINUSE`, half the time in a
    loop of 200. A stream socket that binds port 0 gets a random ephemeral
    port, as on Linux, and a socket the program did not bind is made again
    (with its options) and connected from the next port when it meets one.
  * On the machine this was developed on, a closed port of the loopback
    interface is never refused -- not even to Windows' own .NET client,
    which waits for more than 90 seconds -- where Windows normally refuses
    it in two. A blocking connect on the loopback interface is given four
    seconds and then taken to be refused, and its socket made again.
  * Winsock reports a port unreachable to an unconnected UDP socket, which
    POSIX does not, and not to a connected one, which POSIX does; `connect`
    turns the report on. Winsock fails `getsockname` of a socket not yet
    bound, where POSIX gives an address of no name; so does the layer, and
    for either end of a `socketpair`, which on POSIX is unnamed.

*Removes* `basis.inetsock_addresses`, `basis.netdb_lookup` and
`basis.socket_loopback`.

### M6. POSIX counterparts short of processes -- M, three or four commits

Each commit takes one group and leaves both suites green.

**Ids, users, `uname`.**
* `getpid`, and `getppid` from a Toolhelp snapshot.
* The user and group ids are the RIDs of the token's user and primary group.
  `stat` gives the current user as the owner of every file, as Cygwin does
  with `noacl`.
* `getpwuid` and `getpwnam` answer for the current user only:
  `GetUserName`, `USERPROFILE` written with `/`, and `COMSPEC`.
* `getgroups`, `getlogin`, and `uname` with the system name `Windows`.
* `times`: the children's times come from M7.
* The names of `sysconf` and `pathconf` that Windows can answer: the page
  size, `_getmaxstdio`, `MAX_PATH`.

**Modes and links.**
* A mode is its owner bits: `w` is the inverse of the read-only attribute,
  and the group and other bits are 0.
* `fchmod`, and `umask` through `_umask`.
* `link` is `CreateHardLink`.
* `symlink` passes the flag for no privilege, and gives `EPERM` without
  Developer Mode.
* `readlink` reads the reparse data.
* `unlink` of a read-only file clears the attribute first, since POSIX
  ignores the mode there.

**`fcntl` and locks.**
* `F_GETFL`/`F_SETFL`.
* Locks are `LockFileEx`, and `F_GETLK` is approximated by trying the lock.
* The terminal calls give `ENOTTY` on a descriptor that is not a console,
  where they now give `ENOSYS`.

**Paths**, which the tests showed to be needed.
* A path of a drive is handed to the library as `/C:/Users/...`, and taken
  back as `C:/...`: absolute to the `OS.Path` of POSIX, and no name of
  Windows has a colon in it. `realPath`, `fullPath` and `mkRelative` then
  work as on POSIX. `/dev/null` is `NUL` and `/dev/tty` is `CON`.
* TextIO, BinIO and the loader open their files through `sys_fopen`, a new
  call of `vm/sys.h`, so that their paths are translated too.
* Every file is opened with `FILE_SHARE_DELETE`, so that it can be removed
  or renamed while open, as on POSIX.
* `stat` reads a handle's file information: the index of the file is its
  inode, the serial of the volume its device, and the links are counted.
* Windows says a path is not found where POSIX says why; the layer names
  `ENOTDIR` and `ENAMETOOLONG` itself.

**The test.** `basis.posix_files` passes as it is: the home directory is
`/C:/Users/...`, which starts with `/`.

*Removes* `basis.posix_files`.

### M7. A spawn primitive -- M

`Unix.execute` today is SML over `fork`, `dup2` and `exec`
(`lib/basis/unix.sml:28-59`). A primitive that starts a program directly
gives Windows the process group of the Basis without `fork`. It is also
most of what M10 and M12 need.

* **The primitive.** One new primitive takes:
  * the program, its arguments and its environment;
  * whether to search `PATH`;
  * the three descriptors the child gets as its standard streams.
* **On POSIX** it is `fork`, `dup2` and `execve` in C, and `_exit(126)` when
  `execve` fails. A failed exec therefore still looks as it does today:
  the child exits with 126, as the specification asks
  (`lib/basis/unix.sml:44-48`). `posix_spawn` would report it as an error
  of the call instead.
* **On Windows** it is `CreateProcess`:
  * started suspended, with `STARTF_USESTDHANDLES` and a
    `PROC_THREAD_ATTRIBUTE_HANDLE_LIST` so that the child inherits only its
    three handles;
  * the arguments quoted by msvcrt's rules, and `PATH` searched with
    `PATHEXT`;
  * the process handles kept in a table for `waitpid`, which waits on more
    than 64 of them in turns;
  * `kill` as `TerminateProcess`, with an exit code no program gives
    (`0xE0520000` with the signal in its low bits), which `waitpid` reports
    as "signalled";
  * NTSTATUS codes mapped to signals: `0xC0000005` to `SIGSEGV`,
    `0xC000013A` to `SIGINT`. msvcrt's `abort` exits with 3 and stays
    "exited 3".
* **In the library**, one code path on every platform:
  * `Unix.execute`, `executeInEnv`, `reap` and `kill` go through the
    primitive;
  * `Posix.Process.exec` alone, with no `fork` before it, spawns, waits and
    exits with the child's status;
  * `OS.Process.system` spawns too, where msvcrt's `system` would hand the
    child every inheritable handle.
* **Handles.**
  * Every CRT descriptor is opened with `_O_NOINHERIT`.
  * `FD_CLOEXEC` is a bit the system layer keeps, which the spawn reads.
  * The inherit flag of a handle is left alone, which M12 needs.
* **The tests.**
  * `basis.unix_pipes` is written with the child chosen by the platform:
    `/bin/sh` on POSIX, or `cmd.exe` in the NTFS directory of M1b.
  * `basis.posix_process` is split three ways:
    * a portable test: ids, environment case-insensitively, `isatty`,
      error names, signal numbers;
    * `basis.posix_fork`, category `FORK`: `fork` with `exec` and
      `waitpid`, and `fork` with `pause` and `kill`;
    * the Linux-only test, category `LINUX`: `uname` giving `Linux`, and
      the home directory from M6.

*Removes* `basis.unix_pipes` and `basis.posix_process`, and adds
`basis.posix_fork` and the Linux-only test.

### M8. `poll` beyond sockets and files -- S

* Pipes are asked with `PeekNamedPipe`.
* The console is asked with `WaitForSingleObject` and `PeekConsoleInput`.
* A set that mixes kinds is asked in a short loop until something is ready
  or the time is up.

Under WSL the standard handles of an `.exe` are pipes, so the console branch
can only be tested by hand.

### M9 to M11. The `Windows` structure

`WINDOWS` is optional in the specification. It is the one structure only
`make test-windows` can exercise.

| Part | What it needs from the system layer |
| --- | --- |
| `Key` | nothing: the access flags of the registry are constants (`KEY_ALL_ACCESS` and the rest) |
| `Status` | nothing: the exit codes a process may give are constants |
| `Config` | `GetVersionEx` or the version helpers, `GetSystemDirectory`, `GetWindowsDirectory`, `GetComputerName`, `GetUserName` |
| `Reg` | the registry: `RegOpenKeyEx`, `RegCreateKeyEx`, `RegCloseKey`, `RegDeleteKey`, `RegDeleteValue`, `RegEnumKeyEx`, `RegEnumValue`, `RegQueryValueEx`, `RegSetValueEx`, and the value types (`REG_SZ`, `REG_DWORD`, `REG_BINARY`, `REG_MULTI_SZ`, `REG_EXPAND_SZ`), which `Reg.value` is a datatype of |
| `DDE` | `DdeInitialize`, `DdeConnect`, `DdeClientTransaction`, `DdeDisconnect`, `DdeUninitialize`, and the string handles around them |
| `execute`, `simpleExecute`, `reap`, the stream accessors | M7's spawn, with the three handles redirected to pipes; the streams reach `TextIO` and `BinIO` through the descriptor layer, as `Unix.execute`'s do |
| `getVolumeInformation` | `GetVolumeInformation` |
| `findExecutable`, `launchApplication`, `openDocument` | `FindExecutable` and `ShellExecute`, which are of the shell library and not of the C runtime |

Each part is a group of calls in `vm/sys_win.c` behind new entries of
`vm/sys.h`, which the other system layers answer with `ENOSYS`. Each also
needs its SML and a suite only `make test-windows` runs.

* **M9 (M):** `Key`, `Status`, `Config` and `Reg`. They are self-contained,
  and the registry is what a program actually wants from this structure.
* **M10 (M):** the process group on M7, then `getVolumeInformation`,
  `findExecutable`, `launchApplication` and `openDocument`.
* **M11 (M):** `DDE`. Microsoft has not recommended it since the 1990s, and
  a conforming `Windows` needs it all the same.

The structure does not match `WINDOWS` without M11, and a signature of the
library that no structure implements fails `check-claims`, so the three
went in together. The suite checks DDE only in what it refuses: a machine
has no server of DDE that a test may count on.

### M12. `fork` by carrying the VM across -- L, optional

Windows has no `fork`, but a Rune program is its VM. `fork` can start a
second VM and hand it the first one's state, and the child carries on as if
the process had been copied. Cygwin copies the address space of a native
program to do the same. Here the state is only what the collector already
knows how to list.

**The estimate:** about 2,000 lines and three to five weeks, in four
commits or more:

| Part | Lines |
| --- | ---: |
| The image in the core | 500 to 700 |
| The POSIX side | about 150 |
| The Windows side | 900 to 1,200 |
| Tests and documents | about 300 |

It comes last because M7 already gives every program that only starts
other programs. M12 adds `Posix.Process.fork` itself, which
`basis.posix_fork` and a few programs want.

* **The image.** `p_posix_fork` (`vm/prims.c:1515`) writes the VM before it
  returns. `vm/interp.c:205` has already moved `pc` past the instruction.
  * The heap goes as it stands: the from-space `[0, heap_used)` can always be
    walked between allocations, and pointers become offsets. The child's
    heap is the same, so `--count`, `--gc-stress` and the collector's count
    carry on as after a real `fork`.
  * With it go the stack, the frames and handlers, the globals and
    `global_set`, and the built-in exceptions. An exception constructor's
    identity is its address, which offsets keep.
  * Also the counters, the flags, `io_errno`, `argv` and `progname`, and the
    rounding mode.
  * The program goes whole: its functions, names, code and constants. The
    child does not load the `.rbc` again, which would allocate the constants
    anew and could fail after a `chdir`.
  * The file table goes with each file's mode, closed slots included,
    because handles are never reused. `p_file_open` has to start keeping the
    mode.
* **Before writing the image,** `fflush(NULL)`, and every input that can seek
  is synchronised with `fseek(f, 0, SEEK_CUR)`, so the child reads on from
  where the program stopped. What a pipe has buffered cannot follow. That is
  documented.
* **The system layer's own state** goes through a new pair,
  `sys_image_save`/`sys_image_restore`: open directory streams, M5's
  sockets, the `FD_CLOEXEC` bits, the `umask`.
* **The child** is started as `runevm --resume`, and `vm_run` is split so it
  does not make the built-in exceptions again or push a second top-level
  frame. It rebuilds its state and returns 0 from `fork`.
* **On Windows**:
  * the child is made with `CreateProcess`, suspended, and inherits nothing;
  * each descriptor's handle is given to it with `DuplicateHandle`, and each
    socket with `WSADuplicateSocket`, cloexec ones included, since cloexec
    matters only at `exec`;
  * the image goes through a pipe handle given the same way;
  * the child rebuilds the exact descriptor numbers with `_open_osfhandle`
    and `_dup2`, because SML values hold them.
  * msvcrt's own passing of descriptors (`lpReserved2`) is not used: it
    names handles the kernel only copies if they are inheritable.
* **`exec` in a child made this way** is M7's spawn, and then the child
  waits and exits with the program's status.
  * Before it waits, it closes every descriptor and socket and frees its
    heap. Otherwise it holds, for example, the write end of a sibling's
    input, and two `Unix.execute`s deadlock.
  * The program runs in a job object with `KILL_ON_JOB_CLOSE`, so a `kill`
    of the child reaches it.
* **The other signal calls.**
  * `alarm` is a timer that ends the process as `SIGALRM` would.
  * `pause` waits for ever, since no handler can end it.
  * The stop and continue signals stay `ENOSYS`.
* **Tested on Linux too.** A VM option `--emulate-fork` makes the POSIX layer
  take the same path. Before starting `/proc/self/exe` it clears
  `FD_CLOEXEC` on every descriptor, and the child restores the bits from the
  image.
  * A program of `tests/lang` runs with it in its `.vmargs`, so it also runs
    under ASan and `make test-stress`.
  * The program forks with a cycle in the heap, an exception compared by
    identity across the `fork`, and a handler pushed before the `fork` and
    raised to in the child. It also forks with a file half read and after a
    `chdir`.
  * This tests the image and the resumption. The handles, the job and the
    exec emulation are tested only under `make test-windows`.

*Removes* `basis.posix_fork`. The skip list is then the Linux-only test
alone.

## Risks

1. **WSL interop.**
   * Environment variables reach an `.exe` only through `WSLENV`.
   * A working directory on the Linux side is a UNC path.
   * `timeout` kills the proxy, not necessarily the program.
   * *Mitigation:* M1b runs from NTFS and passes `TZ` explicitly; M2 checks
     the timeout.
2. **msvcrt's calendar.**
   * No local time before 1970.
   * A `TZ` rule it partly ignores.
   * `strftime` limited to the years 0 to 9999.
   * *Mitigation:* M4 formats in Rune's own code. The rest is recorded in
     M2's deviations rather than rebuilt, unless the Basis suite shows a
     program that needs it.
3. **x87 on i686.**
   * `-mfpmath=sse` moves the arithmetic, but a `double` still comes back in
     an x87 register, which can quieten a signalling NaN.
   * The 32-bit maths library can differ from the 64-bit one in the last
     bit.
   * *Mitigation:* expect deviations only the 32-bit VM has, and record them
     under `WIDTH` with the reason.
4. **The 32-bit address space.**
   * A collection holds the old space and the new one at once. With
     `--large-address-aware` under WoW64, live data tops out around 512 MiB;
     without it, around 256 MiB (an estimate).
   * No program of `tests/lang` comes near that.
   * *Mitigation:* M1a makes running out a clean error, not a hang.
5. **Symbolic links need Developer Mode.** On a machine without it M6's test
   of `symlink` expects `EPERM`. The expected output must not depend on which
   machine runs it.
6. **The cost of `fork` in M12.** Each `fork` copies the live heap and
   starts a process.
   * *Mitigation:* measure it when M12 is built. M7 already keeps
     `Unix.execute` off `fork` entirely.

## Out of scope

* **`OS.Path` with volumes and `\`.** Rune's `OS.Path` is POSIX's. M6
  hands it the paths of Windows as `/C:/...`, which it reads as absolute;
  the rules of Windows that the specification describes, chosen at run
  time, would be a project of its own.
* **Rune itself on Windows:** running `bin/rune.rbc` on the Windows VMs, and
  `make install` there.
* **A 32-bit Linux VM under `make check`.** The i386 headers are installed,
  and `gcc -m32` compiles the VM. It would catch 32-bit mistakes without
  Windows, but it is a target of its own and not asked for here.
* **Continuous integration.**

## Verification

* Each milestone's *Leaves verifiable* line holds.
* The skip list and M2's count go down by what the milestone says.
* The whole of `make check` stays green, together with ASan and
  `test-stress` for the VM.
* At the end, `make test-windows` reports both VMs over `tests/lang` and
  `tests/basis`.
* `tests/windows-skip.txt` holds the Linux-only test, and `basis.posix_fork`
  too if M12 is not done. Every category in its header still has a program.

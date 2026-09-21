# signature POSIX

[The Standard ML Basis Library](../README.md) &rsaquo; The operating system &rsaquo; **POSIX**

|  |  |
| --- | --- |
| Status | optional |
| Implementations | 1 |
| Documentation | 8 of 8 entries documented |
| Tests | 0 checks of 0 entries |
| Source | [lib/basis/sig\_posix.sml](../../../../lib/basis/sig_posix.sml) |

## Synopsis

```sml
signature POSIX
structure Posix : POSIX where type FileSys.dirstream = OS.FileSys.dirstream where type FileSys.access_mode = OS.FileSys.access_mode  (* optional *)
```

| Implementation |  | Source |
| --- | --- | --- |
| `Posix` | Posix: the interface of the operating system itself. | [lib/basis/posix.sml](../../../../lib/basis/posix.sml) |

The POSIX interface: the system calls of a Unix-like system, gathered into
eight substructures.

Where [`OS`](../sig/OS.md) offers what any system can do, this offers what POSIX
prescribes, and offers it plainly: `fork`, `exec`, `dup`, `stat`, the
signals, the password and group files, the terminal settings. Failure is
always [`OS.SysErr`](../sig/OS.md#exn-syserr), carrying the `errno` the call set, which
[`Posix.Error`](#str-error) names.

The `where type` clauses tie the substructures together: a `file_desc`
from [`FileSys`](#str-filesys) is the one [`IO`](#str-io) reads from, a `pid` from [`Process`](#str-process) is the
one [`ProcEnv`](#str-procenv) reports, and so on. Each part can therefore be used with the
others without conversion.

> **Erratum** `POSIX/opaque-in-the-page`. The page declares
> `structure Posix :> POSIX`, so the types that no `where` clause fixes are
> abstract; the suite matches [`Posix`](POSIX.md) against this signature both
> transparently and opaquely.

## Interface

<pre>
signature POSIX =
sig
  structure <a href="#str-error">Error</a> : POSIX_ERROR

  structure <a href="#str-signal">Signal</a> : POSIX_SIGNAL

  structure <a href="#str-process">Process</a> : POSIX_PROCESS
    where type signal = Signal.signal

  structure <a href="#str-procenv">ProcEnv</a> : POSIX_PROC_ENV
    where type pid = Process.pid

  structure <a href="#str-filesys">FileSys</a> : POSIX_FILE_SYS
    where type file_desc = ProcEnv.file_desc
    where type uid = ProcEnv.uid
    where type gid = ProcEnv.gid

  structure <a href="#str-io">IO</a> : POSIX_IO
    where type pid = Process.pid
    where type file_desc = ProcEnv.file_desc
    where type open_mode = FileSys.open_mode

  structure <a href="#str-sysdb">SysDB</a> : POSIX_SYS_DB
    where type uid = ProcEnv.uid
    where type gid = ProcEnv.gid

  structure <a href="#str-tty">TTY</a> : POSIX_TTY
    where type pid = Process.pid
    where type file_desc = ProcEnv.file_desc
end
</pre>

### <a name="str-error"></a>`Error`

```sml
structure Error : POSIX_ERROR
```

A substructure: its members are described on the page of [`POSIX_ERROR`](../sig/POSIX_ERROR.md).

The conditions the system reports, and their names.

### <a name="str-signal"></a>`Signal`

```sml
structure Signal : POSIX_SIGNAL
```

A substructure: its members are described on the page of [`POSIX_SIGNAL`](../sig/POSIX_SIGNAL.md).

The signals, by name and by number.

### <a name="str-process"></a>`Process`

```sml
structure Process : POSIX_PROCESS
  where type signal = Signal.signal
```

A substructure: its members are described on the page of [`POSIX_PROCESS`](../sig/POSIX_PROCESS.md).

Processes: making them, replacing them, waiting for them, ending them.

### <a name="str-procenv"></a>`ProcEnv`

```sml
structure ProcEnv : POSIX_PROC_ENV
  where type pid = Process.pid
```

A substructure: its members are described on the page of [`POSIX_PROC_ENV`](../sig/POSIX_PROC_ENV.md).

The process's own identity and its environment.

### <a name="str-filesys"></a>`FileSys`

```sml
structure FileSys : POSIX_FILE_SYS
  where type file_desc = ProcEnv.file_desc
  where type uid = ProcEnv.uid
  where type gid = ProcEnv.gid
```

A substructure: its members are described on the page of [`POSIX_FILE_SYS`](../sig/POSIX_FILE_SYS.md).

Files and directories as POSIX has them, with modes and file status.

### <a name="str-io"></a>`IO`

```sml
structure IO : POSIX_IO
  where type pid = Process.pid
  where type file_desc = ProcEnv.file_desc
  where type open_mode = FileSys.open_mode
```

A substructure: its members are described on the page of [`POSIX_IO`](../sig/POSIX_IO.md).

Reading, writing, duplicating and locking file descriptors.

### <a name="str-sysdb"></a>`SysDB`

```sml
structure SysDB : POSIX_SYS_DB
  where type uid = ProcEnv.uid
  where type gid = ProcEnv.gid
```

A substructure: its members are described on the page of [`POSIX_SYS_DB`](../sig/POSIX_SYS_DB.md).

The password and group databases of the system.

### <a name="str-tty"></a>`TTY`

```sml
structure TTY : POSIX_TTY
  where type pid = Process.pid
  where type file_desc = ProcEnv.file_desc
```

A substructure: its members are described on the page of [`POSIX_TTY`](../sig/POSIX_TTY.md).

Terminals: their modes, their speeds and their control characters.

## See also

[`OS`](../sig/OS.md), [`UNIX`](../sig/UNIX.md), [`BIT_FLAGS`](../sig/BIT_FLAGS.md), [`PRIM_IO`](../sig/PRIM_IO.md)

---

<sub>Generated by runedoc from lib/basis/sig\_posix.sml; do not edit.</sub>

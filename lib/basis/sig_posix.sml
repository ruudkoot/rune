(* The POSIX interface: the system calls of a Unix-like system, gathered into
   eight substructures.

   Where `OS` offers what any system can do, this offers what POSIX
   prescribes, and offers it plainly: `fork`, `exec`, `dup`, `stat`, the
   signals, the password and group files, the terminal settings. Failure is
   always `OS.SysErr`, carrying the `errno` the call set, which
   `Posix.Error` names.

   The `where type` clauses tie the substructures together: a `file_desc`
   from `FileSys` is the one `IO` reads from, a `pid` from `Process` is the
   one `ProcEnv` reports, and so on. Each part can therefore be used with the
   others without conversion.

   Area: The operating system

   Status: optional

   See also: `OS`, `UNIX`, `BIT_FLAGS`, `PRIM_IO`

   Erratum: `POSIX/opaque-in-the-page`. The page declares
   `structure Posix :> POSIX`, so the types that no `where` clause fixes are
   abstract; the suite matches `Posix` against this signature both
   transparently and opaquely.

   Deviation: `POSIX/not-sealed`. The structure is not sealed, so the
   representations show: `uid`, `gid`, `pid`, `file_desc`, `signal` and
   `speed` are `int`, and a set of flags is a word. A program should not rely
   on that.

   Pinned by: `Posix:POSIX/*` *)
signature POSIX =
sig
  (* The conditions the system reports, and their names. *)
  structure Error : POSIX_ERROR

  (* The signals, by name and by number. *)
  structure Signal : POSIX_SIGNAL

  (* Processes: making them, replacing them, waiting for them, ending them. *)
  structure Process : POSIX_PROCESS
    where type signal = Signal.signal

  (* The process's own identity and its environment. *)
  structure ProcEnv : POSIX_PROC_ENV
    where type pid = Process.pid

  (* Files and directories as POSIX has them, with modes and file status. *)
  structure FileSys : POSIX_FILE_SYS
    where type file_desc = ProcEnv.file_desc
    where type uid = ProcEnv.uid
    where type gid = ProcEnv.gid

  (* Reading, writing, duplicating and locking file descriptors. *)
  structure IO : POSIX_IO
    where type pid = Process.pid
    where type file_desc = ProcEnv.file_desc
    where type open_mode = FileSys.open_mode

  (* The password and group databases of the system. *)
  structure SysDB : POSIX_SYS_DB
    where type uid = ProcEnv.uid
    where type gid = ProcEnv.gid

  (* Terminals: their modes, their speeds and their control characters. *)
  structure TTY : POSIX_TTY
    where type pid = Process.pid
    where type file_desc = ProcEnv.file_desc
end

(* Posix: the interface of the operating system itself.

   Implements: POSIX where type FileSys.dirstream = OS.FileSys.dirstream where
   type FileSys.access_mode = OS.FileSys.access_mode

   Status: optional *)
structure Posix =
struct
  (* Posix.Error: the conditions a failing call reports, with their names
     and numbers.

     Implements: POSIX_ERROR *)
  structure Error = RunePosixError
  (* Posix.Signal: the signals of POSIX and their numbers.

     Implements: POSIX_SIGNAL *)
  structure Signal = RunePosixSignal
  (* Posix.Process: making, running, waiting for, signalling and ending
     processes.

     Implements: POSIX_PROCESS *)
  structure Process = RunePosixProcess
  (* Posix.ProcEnv: the identities, groups, environment, terminal and limits
     of this process.

     Implements: POSIX_PROC_ENV *)
  structure ProcEnv = RunePosixProcEnv
  (* Posix.FileSys: files and directories as POSIX has them: descriptors,
     opening, permissions, links and what `stat` reports.

     Implements: POSIX_FILE_SYS *)
  structure FileSys = RunePosixFileSys
  (* Posix.IO: reading, writing and controlling open descriptors: pipes,
     duplicates, positions, flags and locks.

     Implements: POSIX_IO *)
  structure IO = RunePosixIO
  (* Posix.SysDB: the user and group databases of the system.

     Implements: POSIX_SYS_DB *)
  structure SysDB = RunePosixSysDB
  (* Posix.TTY: the settings of a terminal, and the operations on it.

     Implements: POSIX_TTY *)
  structure TTY = RunePosixTTY
end

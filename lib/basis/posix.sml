(* Posix: the interface of the operating system itself.

   Implements: POSIX where type FileSys.dirstream = OS.FileSys.dirstream where
   type FileSys.access_mode = OS.FileSys.access_mode

   Status: optional *)
structure Posix =
struct
  (* Implements: POSIX_ERROR *)
  structure Error = RunePosixError
  (* Implements: POSIX_SIGNAL *)
  structure Signal = RunePosixSignal
  (* Implements: POSIX_PROCESS *)
  structure Process = RunePosixProcess
  (* Implements: POSIX_PROC_ENV *)
  structure ProcEnv = RunePosixProcEnv
  (* Implements: POSIX_FILE_SYS *)
  structure FileSys = RunePosixFileSys
  (* Implements: POSIX_IO *)
  structure IO = RunePosixIO
  (* Implements: POSIX_SYS_DB *)
  structure SysDB = RunePosixSysDB
  (* Implements: POSIX_TTY *)
  structure TTY = RunePosixTTY
end

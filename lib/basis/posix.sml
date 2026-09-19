(* Posix: the interface of the operating system itself. *)
structure Posix =
struct
  structure Error = RunePosixError
  structure Signal = RunePosixSignal
  structure Process = RunePosixProcess
  structure ProcEnv = RunePosixProcEnv
  structure FileSys = RunePosixFileSys
  structure IO = RunePosixIO
  structure SysDB = RunePosixSysDB
end

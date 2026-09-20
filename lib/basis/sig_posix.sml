(* signature POSIX, transcribed from
   https://smlfamily.github.io/Basis/posix.html

   Uses the signatures of the eight substructures, which have to be loaded
   first, with BIT_FLAGS before them: spec-sigs/BIT_FLAGS.sml,
   POSIX_ERROR.sml, POSIX_SIGNAL.sml, POSIX_PROCESS.sml, POSIX_PROC_ENV.sml,
   POSIX_FILE_SYS.sml, POSIX_IO.sml, POSIX_SYS_DB.sml and POSIX_TTY.sml. The
   page declares `structure Posix :> POSIX`: the types that the `where type`
   clauses do not fix are abstract. *)
signature POSIX =
sig
  structure Error : POSIX_ERROR
  structure Signal : POSIX_SIGNAL
  structure Process : POSIX_PROCESS
    where type signal = Signal.signal
  structure ProcEnv : POSIX_PROC_ENV
    where type pid = Process.pid
  structure FileSys : POSIX_FILE_SYS
    where type file_desc = ProcEnv.file_desc
    where type uid = ProcEnv.uid
    where type gid = ProcEnv.gid
  structure IO : POSIX_IO
    where type pid = Process.pid
    where type file_desc = ProcEnv.file_desc
    where type open_mode = FileSys.open_mode
  structure SysDB : POSIX_SYS_DB
    where type uid = ProcEnv.uid
    where type gid = ProcEnv.gid
  structure TTY : POSIX_TTY
    where type pid = Process.pid
    where type file_desc = ProcEnv.file_desc
end

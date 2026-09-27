(* OS: the errors of the system, the file system, paths, the process and the
   I/O descriptors.

   Implements: OS *)
structure OS =
struct
  type syserror = RuneError.syserror
  exception SysErr = RuneError.SysErr
  val errorMsg = RuneError.errorMsg
  val errorName = RuneError.errorName
  val syserror = RuneError.syserror

  (* OS.FileSys: directories and the files in them: reading a directory, the
     attributes of a file, and changing them.

     Implements: OS_FILE_SYS *)
  structure FileSys = RuneFileSys
  (* OS.Path: paths as text, taken apart into arcs and put together, in the
     syntax of Unix.

     Implements: OS_PATH *)
  structure Path = RunePath

  (* OS.Process: the status a program ends with, running a command, the
     environment, and ending the program.

     Implements: OS_PROCESS *)
  structure Process =
  struct
    type status = RuneStatus.status
    val success = RuneStatus.fromInt 0
    val failure = RuneStatus.fromInt 1
    fun isSuccess s = s = success

    local
      val system' = _prim "os_system" : string -> int
      val getenv' = _prim "os_getenv" : string -> string option
      val sleep' = _prim "time_sleep" : int -> unit
      val exit' = _prim "exit" : int -> 'a
      (* "If the argument to exit comes from system ... the implementation
         should attempt to preserve the meaning of the exit code from the
         subprocess ... If st does not connote an exit value, exit should act
         as though called with failure": the status of a command that a signal
         ended is 256 and more, which no exit code can be *)
      fun code status =
        let val n = RuneStatus.toInt status
        in if n >= 0 andalso n < 256 then n else RuneStatus.toInt failure end
    in
      (* "returns the termination status of the command" *)
      fun system command =
        case system' command of
          ~1 => raise RuneError.lastError ()
        | status => RuneStatus.fromInt status

      fun getEnv name = getenv' name

      (* "If t is zero or negative, then the calling process does not sleep,
         but returns immediately. No exception is raised." *)
      fun sleep t = sleep' (Time.micros t)

      val atExit = RuneExit.atExit

      (* exit runs the actions registered with atExit; terminate does not. *)
      fun exit status = (RuneExit.run (); exit' (code status))
      fun terminate status = exit' (code status)
    end
  end

  (* OS.IO: the descriptors of what the system has opened for the program,
     and waiting until they are ready. A descriptor is the system's own file
     descriptor, wrapped in a constructor that the signature does not name.

     Implements: OS_IO *)
  structure IO = RuneIODesc
end

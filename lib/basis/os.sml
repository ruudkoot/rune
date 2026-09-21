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

  (* Implements: OS_FILE_SYS *)
  structure FileSys = RuneFileSys
  (* Implements: OS_PATH *)
  structure Path = RunePath

  (* Implements: OS_PROCESS *)
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
      fun exit status = (RuneExit.run (); exit' (RuneStatus.toInt status))
      fun terminate status = exit' (RuneStatus.toInt status)
    end
  end

  (* A descriptor is the system's own file descriptor, wrapped (`RuneIODesc.FD`).

     Implements: OS_IO *)
  structure IO = RuneIODesc
end

(* OS: the errors of the system, the file system, paths, the process and the
   I/O descriptors. *)
structure OS =
struct
  type syserror = RuneError.syserror
  exception SysErr = RuneError.SysErr
  val errorMsg = RuneError.errorMsg
  val errorName = RuneError.errorName
  val syserror = RuneError.syserror

  structure FileSys = RuneFileSys
  structure Path = RunePath

  structure Process =
  struct
    type status = int
    val success = 0
    val failure = 1
    fun isSuccess s = s = 0

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
        | status => status

      fun getEnv name = getenv' name

      (* "If t is zero or negative, then the calling process does not sleep,
         but returns immediately. No exception is raised." *)
      fun sleep t = sleep' (Time.micros t)

      val atExit = RuneExit.atExit

      (* exit runs the actions registered with atExit; terminate does not. *)
      fun exit status = (RuneExit.run (); exit' status)
      fun terminate status = exit' status
    end
  end

  (* A descriptor is the handle of the VM's file table. *)
  structure IO = RuneIODesc
end

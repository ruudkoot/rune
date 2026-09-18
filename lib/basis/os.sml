(* OS: the errors of the system, the process, and the I/O descriptors. *)
structure OS =
struct
  (* A syserror is an errno value. *)
  type syserror = int
  exception SysErr of string * syserror option

  local
    val errno = _prim "sys_errno" : unit -> int
    val message = _prim "sys_error_msg" : int -> string
    val name = _prim "sys_error_name" : int -> string
    val ofName = _prim "sys_error_of_name" : string -> int
  in
    fun errorMsg e = message e
    fun errorName e = let val n = name e in if n = "" then "error" ^ Int.toString e else n end
    fun syserror s =
      case ofName s of
        ~1 => NONE
      | e => SOME e
    (* The last failure of the system, as an exception. *)
    fun lastError () = let val e = errno () in SysErr (message e, SOME e) end
    fun fail function = raise lastError ()
  end

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
      (* "returns the termination status of the command"; the shell reports a
         command that could not be run as 127, and a failure of the call
         itself raises SysErr. *)
      fun system command =
        case system' command of
          ~1 => fail "system"
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

  (* The rest of OS.IO (poll and its kin) comes with the system layer; the
     type is here because PRIM_IO names it. A descriptor is the handle of the
     VM's file table. *)
  structure IO =
  struct
    datatype iodesc = FD of int
    fun hash (FD fd) = Word.fromInt fd
    fun compare (FD a, FD b) = Int.compare (a, b)
  end
end

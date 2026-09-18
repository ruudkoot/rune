(* The errors of the system, shared by OS and by what is built on it. A
   syserror is an errno value. *)
structure RuneError =
struct
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
    fun syserror s = case ofName s of ~1 => NONE | e => SOME e
    (* The last failure of the system, as an exception. *)
    fun lastError () = let val e = errno () in SysErr (message e, SOME e) end
  end
end

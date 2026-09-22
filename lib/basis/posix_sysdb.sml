(* Posix.SysDB: the users and the groups of the system. *)
structure RunePosixSysDB =
struct
  type uid = RunePosixProcEnv.uid
  type gid = RunePosixProcEnv.gid

  local
    val getpw' = _prim "posix_getpw" : string * int -> string list
    val getgr' = _prim "posix_getgr" : string * int -> string list
    fun number s = case Int.fromString s of SOME n => n | NONE => 0
    (* "It raises OS.SysErr if there is no group or user with the given ID
       or name": the C library reports that without an errno. *)
    fun failure what =
      case RuneError.lastError () of
        (e as RuneError.SysErr (_, SOME n)) =>
          if RuneError.toInt n = 0 then RuneError.SysErr ("no such " ^ what, NONE) else e
      | e => e
  in
    structure Passwd =
    struct
      type passwd = {name : string, uid : uid, gid : gid, home : string, shell : string}
      fun name (p : passwd) = #name p
      fun uid (p : passwd) = #uid p
      fun gid (p : passwd) = #gid p
      fun home (p : passwd) = #home p
      fun shell (p : passwd) = #shell p
    end

    structure Group =
    struct
      type group = {name : string, gid : gid, members : string list}
      fun name (g : group) = #name g
      fun gid (g : group) = #gid g
      fun members (g : group) = #members g
    end

    fun passwdOf l =
      case l of
        [name, home, shell, uid, gid] =>
          ({name = name, uid = number uid, gid = number gid, home = home, shell = shell} : Passwd.passwd)
      | _ => raise failure "user"

    fun groupOf l =
      case l of
        name :: gid :: members => ({name = name, gid = number gid, members = members} : Group.group)
      | _ => raise failure "group"

    (* The primitives look up the number when the name is empty, so no
       name is looked up that is empty. *)
    fun getpwnam name =
      if name = "" then raise RuneError.SysErr ("no such user", NONE) else passwdOf (getpw' (name, 0))
    fun getpwuid uid = passwdOf (getpw' ("", uid))
    fun getgrnam name =
      if name = "" then raise RuneError.SysErr ("no such group", NONE) else groupOf (getgr' (name, 0))
    fun getgrgid gid = groupOf (getgr' ("", gid))
  end
end

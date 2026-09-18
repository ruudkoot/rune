(* OS.FileSys: the files themselves. Every failure raises OS.SysErr with the
   reason the system gave. *)
structure RuneFileSys =
struct
  local
    val mkdir = _prim "os_mkdir" : string -> int
    val rmdir = _prim "os_rmdir" : string -> int
    val chdir = _prim "os_chdir" : string -> int
    val getcwd = _prim "os_getcwd" : unit -> string
    val remove' = _prim "os_remove" : string -> int
    val rename' = _prim "os_rename" : string * string -> int
    val access' = _prim "os_access" : string * int * int -> int
    val fileKind = _prim "os_file_kind" : string -> int
    val linkKind = _prim "os_link_kind" : string -> int
    val fileSize' = _prim "os_file_size" : string -> int
    val modTime' = _prim "os_mod_time" : string -> int
    val setTime' = _prim "os_set_time" : string * int * int -> int
    val readLink' = _prim "os_read_link" : string -> string
    val realPath' = _prim "os_real_path" : string -> string
    val tmpName' = _prim "os_tmp_name" : unit -> string
    val fileId' = _prim "os_file_id" : string -> int list
    val openDir' = _prim "os_open_dir" : string -> int
    val readDir' = _prim "os_read_dir" : int -> string option
    val rewindDir' = _prim "os_rewind_dir" : int -> int
    val closeDir' = _prim "os_close_dir" : int -> int

    fun check r = if r < 0 then raise RuneError.lastError () else r
    fun checkUnit r = ignore (check r)
    fun checkString s = if s = "" then raise RuneError.lastError () else s
  in
    datatype dirstream = Dir of {stream : int, closed : bool ref}

    fun openDir path = Dir {stream = check (openDir' path), closed = ref false}
    fun readDir (Dir {stream, closed}) =
      if !closed then raise RuneError.SysErr ("closed directory stream", NONE) else readDir' stream
    fun rewindDir (Dir {stream, closed}) =
      if !closed then raise RuneError.SysErr ("closed directory stream", NONE) else checkUnit (rewindDir' stream)
    fun closeDir (Dir {stream, closed}) =
      if !closed then () else (closed := true; checkUnit (closeDir' stream))

    fun chDir path = checkUnit (chdir path)
    fun getDir () = checkString (getcwd ())
    fun mkDir path = checkUnit (mkdir path)
    fun rmDir path = checkUnit (rmdir path)

    fun isDir path = check (fileKind path) = 1
    fun isLink path = check (linkKind path) = 2
    fun readLink path = checkString (readLink' path)

    (* "the canonical path, with no symbolic links"; fullPath needs the file
       to exist, realPath does not need the last arc to. *)
    fun realPath path =
      if RunePath.isAbsolute path then checkString (realPath' path)
      else RunePath.mkRelative {path = checkString (realPath' path), relativeTo = getDir ()}
    fun fullPath path = checkString (realPath' path)

    fun modTime path = Time.fromSeconds (IntInf.fromInt (check (modTime' path)))
    fun fileSize path = check (fileSize' path)
    fun setTime (path, NONE) = checkUnit (setTime' (path, 0, 1))
      | setTime (path, SOME t) = checkUnit (setTime' (path, IntInf.toInt (Time.toSeconds t), 0))

    fun remove path = checkUnit (remove' path)
    fun rename {old, new} = checkUnit (rename' (old, new))

    datatype access_mode = A_READ | A_WRITE | A_EXEC
    fun access (path, modes) =
      let
        fun bit A_READ = 1 | bit A_WRITE = 2 | bit A_EXEC = 4
        val flags = List.foldl (fn (m, acc) => acc + (if acc div bit m mod 2 = 1 then 0 else bit m)) 0 modes
      in check (access' (path, flags, 0)) = 1 end

    fun tmpName () = checkString (tmpName' ())

    (* A file is known by its device and inode. *)
    type file_id = int * int
    fun fileId path =
      case fileId' path of
        [device, inode] => (device, inode)
      | _ => raise RuneError.lastError ()
    fun hash ((device, inode) : file_id) = Word.fromInt (device * 65599 + inode)
    fun compare ((d1, i1) : file_id, (d2, i2) : file_id) =
      case Int.compare (d1, d2) of EQUAL => Int.compare (i1, i2) | other => other
  end
end

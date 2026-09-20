(* Posix.FileSys: files by their descriptors, and what stat reports. *)
structure RunePosixFileSys =
struct
  type uid = RunePosixProcEnv.uid
  type gid = RunePosixProcEnv.gid
  type file_desc = int

  local
    val const = _prim "posix_const" : string -> int
    val openf' = _prim "posix_openf" : string * int * int -> int
    val stat' = _prim "posix_stat" : string * int * int -> int list
    val chmod' = _prim "posix_chmod" : string * int * int -> int
    val chown' = _prim "posix_chown" : string * int * int * int -> int
    val link' = _prim "posix_link" : string * string -> int
    val symlink' = _prim "posix_symlink" : string * string -> int
    val mkfifo' = _prim "posix_mkfifo" : string * int -> int
    val umask' = _prim "posix_umask" : int -> int
    val ftruncate' = _prim "posix_ftruncate" : int * int -> int
    fun check r = if r < 0 then raise RuneError.lastError () else r
    fun named name = case const name of ~1 => 0 | v => v
    (* The primitives take the path "" for "the descriptor"; a path that is
       empty is refused as the system refuses it ("an empty string causes an
       exception"). *)
    fun nonEmpty "" = let val e = named "ENOENT" in raise RuneError.SysErr (RuneError.errorMsg e, SOME e) end
      | nonEmpty p = p
  in
    fun fdToWord (fd : file_desc) = Word.fromInt fd
    fun wordToFD w = Word.toInt w
    fun fdToIOD (fd : file_desc) = RuneIODesc.FD fd
    fun iodToFD (RuneIODesc.FD fd) = SOME fd

    val stdin : file_desc = 0
    val stdout : file_desc = 1
    val stderr : file_desc = 2

    (* The flags of open and the bits of a mode, as words. "all represents
       the union of all flags", also those of the system that O does not
       name (O_CLOEXEC, and O_LARGEFILE, which getfl reports): the bits of a
       C int. fromWord keeps the bits of all, so that "toWord o fromWord" is
       "fn w => SysWord.andb (w, toWord all)". *)
    structure O =
    struct
      type flags = word
      val append = Word.fromInt (named "O_APPEND")
      val excl = Word.fromInt (named "O_EXCL")
      val noctty = Word.fromInt (named "O_NOCTTY")
      val nonblock = Word.fromInt (named "O_NONBLOCK")
      val sync = Word.fromInt (named "O_SYNC")
      val trunc = Word.fromInt (named "O_TRUNC")
      val all = if Word.wordSize > 32 then Word.<< (0w1, 0w32) - 0w1 else Word.notb 0w0
      fun toWord (f : flags) = f
      fun fromWord w = Word.andb (w, all)
      fun flags l = List.foldl Word.orb 0w0 l
      fun intersect l = List.foldl Word.andb all l
      fun allSet (a, b) = Word.andb (a, b) = a
      fun anySet (a, b) = Word.andb (a, b) <> 0w0
      fun clear (a, b) = Word.andb (Word.notb a, b)
    end

    structure S =
    struct
      type mode = word
      type flags = mode
      val irwxu = Word.fromInt (named "S_IRWXU")
      val irusr = Word.fromInt (named "S_IRUSR")
      val iwusr = Word.fromInt (named "S_IWUSR")
      val ixusr = Word.fromInt (named "S_IXUSR")
      val irwxg = Word.fromInt (named "S_IRWXG")
      val irgrp = Word.fromInt (named "S_IRGRP")
      val iwgrp = Word.fromInt (named "S_IWGRP")
      val ixgrp = Word.fromInt (named "S_IXGRP")
      val irwxo = Word.fromInt (named "S_IRWXO")
      val iroth = Word.fromInt (named "S_IROTH")
      val iwoth = Word.fromInt (named "S_IWOTH")
      val ixoth = Word.fromInt (named "S_IXOTH")
      val isuid = Word.fromInt (named "S_ISUID")
      val isgid = Word.fromInt (named "S_ISGID")
      (* every bit that chmod sets: those above and S_ISVTX, 07777 *)
      val all = 0w4095
      fun toWord (m : mode) = m
      fun fromWord w = Word.andb (w, all)
      fun flags l = List.foldl Word.orb 0w0 l
      fun intersect l = List.foldl Word.andb all l
      fun allSet (a, b) = Word.andb (a, b) = a
      fun anySet (a, b) = Word.andb (a, b) <> 0w0
      fun clear (a, b) = Word.andb (Word.notb a, b)
    end

    datatype open_mode = O_RDONLY | O_WRONLY | O_RDWR
    fun modeBits O_RDONLY = named "O_RDONLY"
      | modeBits O_WRONLY = named "O_WRONLY"
      | modeBits O_RDWR = named "O_RDWR"

    val defaultMode = Word.orb (S.irusr, Word.orb (S.iwusr, Word.orb (S.irgrp, S.iroth)))

    fun openf (path, mode, flags) =
      check (openf' (path, Word.toInt (Word.orb (Word.fromInt (modeBits mode), flags)), 0))
    fun createf (path, mode, flags, perms) =
      check (openf' (path,
                     Word.toInt (Word.orb (Word.fromInt (named "O_CREAT"),
                                           Word.orb (Word.fromInt (modeBits mode), flags))),
                     Word.toInt perms))
    fun creat (path, perms) =
      check (openf' (path,
                     Word.toInt (Word.orb (Word.fromInt (named "O_CREAT"),
                                 Word.orb (Word.fromInt (named "O_WRONLY"), Word.fromInt (named "O_TRUNC")))),
                     Word.toInt perms))

    fun link {old, new} = ignore (check (link' (old, new)))
    fun symlink {old, new} = ignore (check (symlink' (old, new)))
    fun mkfifo (path, perms) = ignore (check (mkfifo' (path, Word.toInt perms)))
    fun umask mask = Word.fromInt (check (umask' (Word.toInt mask)))
    fun ftruncate (fd, length) = ignore (check (ftruncate' (fd, length)))

    (* "creates a new directory named s with protection mode m (as modified
       by the umask)". The directory of OS.FileSys gets every permission the
       mask leaves; the mask is widened by those that m does not give while
       it is made. *)
    fun mkdir (path, perms) =
      let
        val mask = umask' 0
        fun restore () = ignore (umask' mask)
      in
        ignore (umask' (Word.toInt (Word.orb (Word.fromInt mask, Word.andb (Word.notb perms, 0w511)))));
        (RuneFileSys.mkDir path; restore ()) handle e => (restore (); raise e)
      end

    type dev = int
    type ino = int
    fun wordToDev w : dev = Word.toInt w
    fun devToWord (d : dev) = Word.fromInt d
    fun wordToIno w : ino = Word.toInt w
    fun inoToWord (i : ino) = Word.fromInt i

    (* What stat reports. The kind is posix_stat's: 0 regular file, 1
       directory, 2 symbolic link, 3 anything else; 4 FIFO, 5 socket, 6
       character device and 7 block device where the primitive tells them
       apart (the VM does not yet: it reports them as 3). *)
    structure ST =
    struct
      type stat = {kind : int, mode : word, ino : ino, dev : dev, nlink : int,
                   uid : uid, gid : gid, size : int,
                   atime : Time.time, mtime : Time.time, ctime : Time.time}
      fun isDir (s : stat) = #kind s = 1
      fun isLink (s : stat) = #kind s = 2
      fun isReg (s : stat) = #kind s = 0
      fun isChr (s : stat) = #kind s = 6
      fun isBlk (s : stat) = #kind s = 7
      fun isFIFO (s : stat) = #kind s = 4
      fun isSock (s : stat) = #kind s = 5
      fun mode (s : stat) = #mode s
      fun ino (s : stat) = #ino s
      fun dev (s : stat) = #dev s
      fun nlink (s : stat) = #nlink s
      fun uid (s : stat) = #uid s
      fun gid (s : stat) = #gid s
      fun size (s : stat) = #size s
      fun atime (s : stat) = #atime s
      fun mtime (s : stat) = #mtime s
      fun ctime (s : stat) = #ctime s
    end

    fun statOf (path, follow, fd) =
      case stat' (path, follow, fd) of
        [kind, mode, ino, dev, nlink, uid, gid, size, atime, mtime, ctime] =>
          ({kind = kind, mode = S.fromWord (Word.fromInt mode), ino = ino, dev = dev, nlink = nlink,
            uid = uid, gid = gid, size = size,
            atime = Time.ofMicros (atime * 1000000), mtime = Time.ofMicros (mtime * 1000000),
            ctime = Time.ofMicros (ctime * 1000000)} : ST.stat)
      | _ => raise RuneError.lastError ()

    fun stat path = statOf (nonEmpty path, 0, 0)
    fun lstat path = statOf (nonEmpty path, 1, 0)
    fun fstat fd = statOf ("", 0, fd)

    fun chmod (path, perms) = ignore (check (chmod' (nonEmpty path, 0, Word.toInt perms)))
    fun fchmod (fd, perms) = ignore (check (chmod' ("", fd, Word.toInt perms)))
    fun chown (path, uid, gid) = ignore (check (chown' (nonEmpty path, 0, uid, gid)))
    fun fchown (fd, uid, gid) = ignore (check (chown' ("", fd, uid, gid)))

    (* The rest of the file system is the same as OS.FileSys's. *)
    val rmdir = RuneFileSys.rmDir
    val chdir = RuneFileSys.chDir
    val getcwd = RuneFileSys.getDir
    val unlink = RuneFileSys.remove
    val rename = RuneFileSys.rename
    val readlink = RuneFileSys.readLink
    val opendir = RuneFileSys.openDir
    val readdir = RuneFileSys.readDir
    val rewinddir = RuneFileSys.rewindDir
    val closedir = RuneFileSys.closeDir
    type dirstream = RuneFileSys.dirstream
    datatype access_mode = datatype RuneFileSys.access_mode
    val access = RuneFileSys.access
    local
      val utime' = _prim "posix_utime" : string * int * int -> int
      val pathconf' = _prim "posix_pathconf" : string * int * string -> int list
      fun seconds t = Time.micros t div 1000000
      fun limit [~1] = NONE
        | limit [v] = SOME (Word.fromInt v)
        | limit _ = raise RuneError.lastError ()
    in
      fun utime (path, NONE) = RuneFileSys.setTime (path, NONE)
        | utime (path, SOME {actime, modtime}) =
            if utime' (nonEmpty path, seconds actime, seconds modtime) < 0 then raise RuneError.lastError () else ()
      (* the limits are named without their prefix: "LINK_MAX", "NAME_MAX", ... *)
      fun pathconf (path, name) = limit (pathconf' (nonEmpty path, 0, name))
      fun fpathconf (fd : file_desc, name) = limit (pathconf' ("", fd, name))
    end
  end
end

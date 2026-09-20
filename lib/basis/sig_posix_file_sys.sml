(* Files and directories as POSIX has them: opening them, linking and
   removing them, and reading and setting what the system records about them.

   Where `OS_FILE_SYS` offers what any system can do, this offers the system
   calls: `open`, `creat`, `link`, `mkfifo`, `stat`, `chmod`, `chown`,
   `umask`. What it gives back for an open file is a `file_desc`, which
   `POSIX_IO` reads and writes.

   Permissions are a set of flags, the substructure `S`, and so are the
   options of `openf`, the substructure `O`; both are `BIT_FLAGS`. What
   `stat` reports is an `ST.stat`, which the functions of `ST` take apart.

   Every failure raises `OS.SysErr` with the `errno` the call left; the
   conditions are the ones `POSIX_ERROR` names.

   Area: The operating system

   See also: `OS_FILE_SYS`, `POSIX_IO`, `POSIX`, `BIT_FLAGS`, `TIME`

   Erratum: `POSIX_FILE_SYS/flexible-types`. The types are kept as the page
   writes them. What the text says about them is checked in the suite rather
   than written here: `uid`, `gid` and `file_desc` are those of
   `Posix.ProcEnv`, `dirstream` is `OS.FileSys.dirstream`, and `access_mode`
   is `OS.FileSys.access_mode`.

   Reading: `Posix.FileSys/empty-path-raises`. An empty path raises
   `OS.SysErr` with `noent`, as the system would, although inside the library
   the empty string means "use the descriptor instead". *)
signature POSIX_FILE_SYS =
sig
  (* The type of the number that names a user, the one of `Posix.ProcEnv`. *)
  eqtype uid

  (* The type of the number that names a group. *)
  eqtype gid

  (* The type of an open file descriptor. *)
  eqtype file_desc

  (* `fdToWord fd` is the number the system knows `fd` by. *)
  val fdToWord : file_desc -> SysWord.word

  (* `wordToFD w` is the descriptor numbered `w`, whether or not it is open. *)
  val wordToFD : SysWord.word -> file_desc

  (* `fdToIOD fd` is `fd` as the `OS.IO.iodesc` that `OS.IO.poll` takes. *)
  val fdToIOD : file_desc -> OS.IO.iodesc

  (* `iodToFD iod` is `SOME` of the descriptor that `iod` is, or `NONE` when it is not one. *)
  val iodToFD : OS.IO.iodesc -> file_desc option

  (* The type of an open directory being read, the `dirstream` of `OS.FileSys`. *)
  type dirstream

  (* `opendir p` opens the directory `p` for reading.

     Raises: `OS.SysErr` if `p` is no directory, or may not be read. *)
  val opendir : string -> dirstream

  (* `readdir d` is `SOME` of the next name in `d`, or `NONE` when there are no more.

     The names are arcs, and `"."` and `".."` are not among them.

     Raises: `OS.SysErr` if the directory cannot be read. *)
  val readdir : dirstream -> string option

  (* `rewinddir d` puts `d` back at its first name. *)
  val rewinddir : dirstream -> unit

  (* `closedir d` closes `d`. *)
  val closedir : dirstream -> unit

  (* `chdir p` makes `p` the current directory of the process.

     Raises: `OS.SysErr` if `p` is no directory, or may not be entered. *)
  val chdir : string -> unit

  (* `getcwd ()` is the current directory, as an absolute path.

     Raises: `OS.SysErr` if it cannot be found. *)
  val getcwd : unit -> string

  (* The descriptor the program reads its input from.

     Implementation: `Posix.FileSys.stdin/is-0`. The three standard
     descriptors are the words 0, 1 and 2, which POSIX fixes and the page
     does not state.

     Pinned by: `Posix.FileSys.stdin/is-0`, `Posix.FileSys.stdout/is-1`,
     `Posix.FileSys.stderr/is-2` *)
  val stdin : file_desc

  (* The descriptor the program writes its output to. *)
  val stdout : file_desc

  (* The descriptor the program writes its errors to. *)
  val stderr : file_desc

  (* The permission bits of a file, as a set of flags. *)
  structure S :
  sig
    (* The type of a set of permission bits. *)
    eqtype mode

    include BIT_FLAGS
      where type flags = mode

    (* Read, write and run, for the owner: `irusr`, `iwusr` and `ixusr` together.

       Implementation: `Posix.FileSys.S/values-of-the-C-binding`. The bits
       are the ones of the system's `<sys/stat.h>`: `irwxu` is 0700 through
       `isuid` 04000 and `isgid` 02000, and `all` is 07777, every bit that
       `chmod` sets, the sticky bit included.

       Pinned by: `Posix.FileSys.S.toWord/values-of-the-C-binding` *)
    val irwxu : mode

    (* The owner may read. *)
    val irusr : mode

    (* The owner may write. *)
    val iwusr : mode

    (* The owner may run it, or enter it when it is a directory. *)
    val ixusr : mode

    (* Read, write and run, for the group. *)
    val irwxg : mode

    (* The group may read. *)
    val irgrp : mode

    (* The group may write. *)
    val iwgrp : mode

    (* The group may run it. *)
    val ixgrp : mode

    (* Read, write and run, for everyone else. *)
    val irwxo : mode

    (* Everyone may read. *)
    val iroth : mode

    (* Everyone may write. *)
    val iwoth : mode

    (* Everyone may run it. *)
    val ixoth : mode

    (* Run the program as its owner rather than as whoever started it. *)
    val isuid : mode

    (* Run the program with the file's group.

       Implementation: `Posix.FileSys.S.isgid/may-not-stick`. The owner may
       always set `isuid`; `isgid` is only bound to stay set when the file's
       group is one of the process's own groups.

       Pinned by: `Posix.FileSys.S.isgid/chmod` *)
    val isgid : mode
  end

  (* The options of `openf` and `createf`. *)
  structure O :
  sig
    include BIT_FLAGS

    (* Every write goes to the end of the file. *)
    val append : flags

    (* Fail rather than open a file that is there already; for `createf`. *)
    val excl : flags

    (* Do not let this file become the process's controlling terminal.

       Reading: `Posix.FileSys.O.noctty/only-for-terminals`. A regular file
       never becomes a controlling terminal, so on one this flag is only
       checked to leave reading as it was. *)
    val noctty : flags

    (* A read or a write that would wait fails instead. *)
    val nonblock : flags

    (* A write returns only once the data have reached the device. *)
    val sync : flags

    (* Empty the file when opening it. *)
    val trunc : flags
  end

  (* What a file is opened for. *)
  datatype open_mode
    = O_RDONLY   (* reading only *)
    | O_WRONLY   (* writing only *)
    | O_RDWR     (* both *)

  (* `openf (p, mode, flags)` opens the file `p`, which must exist, and is a descriptor on it.

     Raises: `OS.SysErr` if `p` names nothing, or may not be opened that
     way. *)
  val openf : string * open_mode * O.flags -> file_desc

  (* `createf (p, mode, flags, perms)` opens `p`, making it with the permissions `perms` when it is not there.

     Raises: `OS.SysErr` if `p` cannot be opened or made.

     Reading: `Posix.FileSys.createf/existing-file-is-opened`. The page
     speaks of the permissions only for a file that has to be made, so a file
     that is there already is opened as it stands: neither its contents nor
     its permissions are touched, unless `O.trunc` is given.

     Pinned by: `Posix.FileSys.createf/*` *)
  val createf : string * open_mode * O.flags * S.mode
                -> file_desc

  (* `creat (p, perms)` is `createf (p, O_WRONLY, O.flags [O.trunc], perms)`.

     Raises: `OS.SysErr` if `p` cannot be opened or made. *)
  val creat : string * S.mode -> file_desc

  (* `umask m` makes `m` the set of permission bits withheld from files this process creates, and is the old one.

     Reading: `Posix.FileSys.umask/not-for-chmod`. The mask applies to files
     that are created; `chmod` sets what it is given, mask or no mask.

     Pinned by: `Posix.FileSys.chmod/not-masked` *)
  val umask : S.mode -> S.mode

  (* `link {old, new}` makes `new` another name for the file `old`.

     Raises: `OS.SysErr` if `old` names nothing, `new` is there already, or
     the two are on different file systems. *)
  val link : {old : string, new : string} -> unit

  (* `mkdir (p, perms)` makes a directory `p` with the permissions `perms`, less the mask.

     Raises: `OS.SysErr` if `p` is there already, or cannot be made. *)
  val mkdir : string * S.mode -> unit

  (* `mkfifo (p, perms)` makes a named pipe `p` with the permissions `perms`, less the mask.

     Raises: `OS.SysErr` if `p` is there already, or cannot be made. *)
  val mkfifo : string * S.mode -> unit

  (* `unlink p` removes the name `p`; the file goes when its last name does.

     Raises: `OS.SysErr` if `p` names nothing, or may not be removed. *)
  val unlink : string -> unit

  (* `rmdir p` removes the directory `p`, which must be empty.

     Raises: `OS.SysErr` if `p` is not an empty directory, or may not be
     removed. *)
  val rmdir : string -> unit

  (* `rename {old, new}` renames `old` to `new`, replacing what `new` named.

     Raises: `OS.SysErr` if `old` names nothing, or the rename is refused. *)
  val rename : {old : string, new : string} -> unit

  (* `symlink {old, new}` makes `new` a symbolic link holding the text `old`.

     `old` need not name anything.

     Raises: `OS.SysErr` if `new` is there already, or cannot be made. *)
  val symlink : {old : string, new : string} -> unit

  (* `readlink p` is the text that the symbolic link `p` holds.

     Raises: `OS.SysErr` if `p` is no symbolic link. *)
  val readlink : string -> string

  (* The type of the number that names a device. *)
  eqtype dev

  (* `wordToDev w` is the device numbered `w`. *)
  val wordToDev : SysWord.word -> dev

  (* `devToWord d` is the number of the device `d`. *)
  val devToWord : dev -> SysWord.word

  (* The type of the number that names a file within its device. *)
  eqtype ino

  (* `wordToIno w` is the file numbered `w`. *)
  val wordToIno : SysWord.word -> ino

  (* `inoToWord i` is the number of the file `i`. *)
  val inoToWord : ino -> SysWord.word

  (* What the system records about a file, and the functions that read it. *)
  structure ST :
  sig
    (* The type of what `stat` reports about one file. *)
    type stat

    (* `isDir st` is `true` when the file is a directory. *)
    val isDir : stat -> bool

    (* `isChr st` is `true` when the file is a character device, as `/dev/null` is. *)
    val isChr : stat -> bool

    (* `isBlk st` is `true` when the file is a block device. *)
    val isBlk : stat -> bool

    (* `isReg st` is `true` when the file is an ordinary file. *)
    val isReg : stat -> bool

    (* `isFIFO st` is `true` when the file is a pipe, named or not. *)
    val isFIFO : stat -> bool

    (* `isLink st` is `true` when the file is a symbolic link; only `lstat` reports one. *)
    val isLink : stat -> bool

    (* `isSock st` is `true` when the file is a socket. *)
    val isSock : stat -> bool

    (* `mode st` is the permission bits of the file. *)
    val mode : stat -> S.mode

    (* `ino st` is the number that names the file within its device. *)
    val ino : stat -> ino

    (* `dev st` is the number of the device the file is on. *)
    val dev : stat -> dev

    (* `nlink st` is how many names the file has. *)
    val nlink : stat -> int

    (* `uid st` is the user that owns the file. *)
    val uid : stat -> uid

    (* `gid st` is the group of the file. *)
    val gid : stat -> gid

    (* `size st` is the size of the file in bytes. *)
    val size : stat -> Position.int

    (* `atime st` is when the file was last read.

       Implementation: `Posix.FileSys.ST.atime/whole-seconds`. The three
       times are kept in whole seconds, so they have no fraction. *)
    val atime : stat -> Time.time

    (* `mtime st` is when the contents of the file were last changed. *)
    val mtime : stat -> Time.time

    (* `ctime st` is when what the system records about the file last changed.

       Reading: `Posix.FileSys.ST.ctime/utime-sets-it-to-now`. `utime`
       changes this time to now, not to either of the times it is given: it
       is the record that changed, not the contents.

       Pinned by: `Posix.FileSys.ST.ctime/after-utime` *)
    val ctime : stat -> Time.time
  end

  (* `stat p` is what the system records about the file `p`, following symbolic links.

     Raises: `OS.SysErr` if `p` names nothing. *)
  val stat : string -> ST.stat

  (* `lstat p` is what the system records about `p` itself, without following a symbolic link.

     Raises: `OS.SysErr` if `p` names nothing. *)
  val lstat : string -> ST.stat

  (* `fstat fd` is what the system records about the file that `fd` is open on.

     Raises: `OS.SysErr` if `fd` is not open. *)
  val fstat : file_desc -> ST.stat

  (* What one may want to do with a file, for `access` to ask about. *)
  datatype access_mode
    = A_READ    (* read it *)
    | A_WRITE   (* write it *)
    | A_EXEC    (* run it, or enter it when it is a directory *)

  (* `access (p, modes)` is `true` when the process may do all of `modes` to `p`, by its real user and group.

     An empty list asks only whether `p` names something.

     Raises: `OS.SysErr` if the question cannot be answered. *)
  val access : string * access_mode list -> bool

  (* `chmod (p, perms)` sets the permission bits of `p` to `perms`.

     Raises: `OS.SysErr` if `p` names nothing, or the process does not own
     it. *)
  val chmod : string * S.mode -> unit

  (* `fchmod (fd, perms)` sets the permission bits of the file that `fd` is open on.

     Raises: `OS.SysErr` if `fd` is not open, or the process does not own the
     file. *)
  val fchmod : file_desc * S.mode -> unit

  (* `chown (p, u, g)` makes `u` the owner and `g` the group of `p`.

     Raises: `OS.SysErr` if the change is refused.

     Implementation: `Posix.FileSys.chown/only-what-is-allowed`. An
     unprivileged process may not give a file away, so the suite only checks
     setting the owner and group a file already has.

     Pinned by: `Posix.FileSys.chown/*` *)
  val chown : string * uid * gid -> unit

  (* `fchown (fd, u, g)` is `chown` on the file that `fd` is open on.

     Raises: `OS.SysErr` if the change is refused. *)
  val fchown : file_desc * uid * gid -> unit

  (* `utime (p, times)` sets when `p` was read and changed, or both to now when `times` is `NONE`.

     Raises: `OS.SysErr` if `p` names nothing, or its times may not be
     set. *)
  val utime : string
              * {actime : Time.time, modtime : Time.time} option
              -> unit

  (* `ftruncate (fd, n)` makes the file that `fd` is open on `n` bytes long, cutting or extending it.

     Raises: `OS.SysErr` if `fd` is not open for writing, or cannot be
     resized. *)
  val ftruncate : file_desc * Position.int -> unit

  (* `pathconf (p, name)` is `SOME` of the limit `name` for `p`, or `NONE` when it is unbounded.

     The names are written without a prefix: `"NAME_MAX"`, `"PATH_MAX"`,
     `"LINK_MAX"`.

     Raises: `OS.SysErr` if `p` names nothing, or `name` is not a limit the
     system knows.

     Implementation: `Posix.FileSys.pathconf/what-a-check-can-assume`. The
     suite asks that `NAME_MAX` be bounded and lie between 13 and 255, and
     allows `PATH_MAX` and `LINK_MAX` to be unbounded, `PATH_MAX` being at
     most 65535 when it is not.

     Pinned by: `Posix.FileSys.pathconf/*` *)
  val pathconf : string * string -> SysWord.word option

  (* `fpathconf (fd, name)` is `pathconf` for the file that `fd` is open on.

     Raises: `OS.SysErr` if `fd` is not open, or `name` is not a limit the
     system knows. *)
  val fpathconf : file_desc * string -> SysWord.word option
end

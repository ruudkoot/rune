(* The file system: reading directories, moving about in them, and asking
   what a file is and when it changed.

   Where `OS_PATH` works on the text of a path alone, everything here touches
   the file system, and everything here reports a refusal the same way:
   `OS.SysErr` with the message and the condition the system gave. A path
   that names nothing, a directory that may not be read, a file that may not
   be removed -- all of them arrive as that one exception.

   A directory is read as a stream: `openDir`, then `readDir` until it gives
   `NONE`, then `closeDir`. The names it gives are arcs, not paths, and
   `"."` and `".."` are not among them.

   Area: The operating system

   See also: `OS_PATH`, `OS`, `OS_IO`, `POSIX_FILE_SYS`, `TIME`

   Implementation: `OS.FileSys/errors-are-SysErr`. Every failure raises
   `OS.SysErr` carrying the reason the system gave; no operation here has an
   exception of its own. *)
signature OS_FILE_SYS =
sig
  (* The type of an open directory being read. *)
  type dirstream

  (* `openDir p` opens the directory `p` for reading.

     Raises: `OS.SysErr` if `p` is no directory, or may not be read. *)
  val openDir : string -> dirstream

  (* `readDir d` is `SOME` of the next name in `d`, or `NONE` when there are no more.

     The names are arcs of the directory, in no particular order, and
     `OS.Path.currentArc` and `OS.Path.parentArc` are not among them.

     Raises: `OS.SysErr` if the directory cannot be read.

     Reading: `OS.FileSys.readDir/empty-stays-empty`. Once the stream is
     spent it stays spent: `readDir` keeps giving `NONE` however often it is
     called, until `rewindDir`.

     Pinned by: `OS.FileSys.readDir/NONE-at-the-end` *)
  val readDir : dirstream -> string option

  (* `rewindDir d` puts `d` back at its first name.

     Raises: `OS.SysErr` if the directory cannot be read again. *)
  val rewindDir : dirstream -> unit

  (* `closeDir d` closes `d`; closing twice is allowed. *)
  val closeDir : dirstream -> unit

  (* `chDir p` makes `p` the current directory of the process.

     Raises: `OS.SysErr` if `p` is no directory, or may not be entered. *)
  val chDir : string -> unit

  (* `getDir ()` is the current directory, as an absolute canonical path.

     Raises: `OS.SysErr` if it cannot be found. *)
  val getDir : unit -> string

  (* `mkDir p` makes a directory `p`.

     Raises: `OS.SysErr` if `p` is there already, or cannot be made. *)
  val mkDir : string -> unit

  (* `rmDir p` removes the directory `p`, which must be empty.

     Raises: `OS.SysErr` if `p` is not an empty directory, or may not be
     removed. *)
  val rmDir : string -> unit

  (* `isDir p` is `true` when `p` names a directory, following symbolic links.

     Raises: `OS.SysErr` if `p` names nothing.

     Example: `isDir "." = true` *)
  val isDir : string -> bool

  (* `isLink p` is `true` when `p` itself is a symbolic link, without following it.

     Raises: `OS.SysErr` if `p` names nothing. *)
  val isLink : string -> bool

  (* `readLink p` is the path that the symbolic link `p` holds, as it is written there.

     Raises: `OS.SysErr` if `p` is no symbolic link. *)
  val readLink : string -> string

  (* `fullPath p` is `p` as an absolute canonical path, with every symbolic link followed.

     Raises: `OS.SysErr` if `p` names nothing, or a link leads nowhere or in a
     circle.

     Example: `fullPath "." = getDir ()` *)
  val fullPath : string -> string

  (* `realPath p` is `fullPath p` when `p` is absolute, and the same made relative to the current directory when it is not.

     Raises: `OS.SysErr` as `fullPath` does. *)
  val realPath : string -> string

  (* `modTime p` is when what `p` names was last changed.

     Raises: `OS.SysErr` if `p` names nothing.

     Implementation: `OS.FileSys.modTime/whole-seconds`. The file system
     keeps whole seconds only, so the time has no fraction. *)
  val modTime : string -> Time.time

  (* `fileSize p` is the size in bytes of what `p` names.

     Raises: `OS.SysErr` if `p` names nothing. *)
  val fileSize : string -> Position.int

  (* `setTime (p, t)` sets the time of what `p` names to `t`, or to now when `t` is `NONE`.

     Raises: `OS.SysErr` if `p` names nothing, or its time may not be set.

     Implementation: `OS.FileSys.setTime/what-a-check-can-assume`. The range
     of a `Time.time` is the implementation's, so the suite builds the times
     it sets inside the checks; and because the file system may keep whole
     seconds only, "now" is checked with a second of slack either way.

     Pinned by: `OS.FileSys.setTime/*` *)
  val setTime : string * Time.time option -> unit

  (* `remove p` removes the file `p`, which must not be a directory.

     Raises: `OS.SysErr` if `p` names nothing, is a directory, or may not be
     removed. *)
  val remove : string -> unit

  (* `rename {old, new}` renames `old` to `new`, replacing what `new` named.

     Raises: `OS.SysErr` if `old` names nothing, or the rename is refused. *)
  val rename : {old : string, new : string} -> unit

  (* What one may want to do with a file, for `access` to ask about. *)
  datatype access_mode
    = A_READ    (* read it *)
    | A_WRITE   (* write it *)
    | A_EXEC    (* run it, or enter it when it is a directory *)

  (* `access (p, modes)` is `true` when the process may do all of `modes` to what `p` names.

     An empty list asks only whether `p` names something.

     Raises: `OS.SysErr` if the question cannot be answered -- not when the
     answer is no.

     Implementation: `OS.FileSys.access/depends-on-the-process`. Whether a
     file counts as executable is the system's affair, and a privileged
     process may read and write whatever the permission bits say, so the
     suite's checks of the bits hold only for an ordinary process.

     Pinned by: `OS.FileSys.A_EXEC/*`, `OS.FileSys.A_WRITE/read-only` *)
  val access : string * access_mode list -> bool

  (* `tmpName ()` is the path of a file that does not exist yet, for temporary use.

     The file is not created, so two processes can still race for the
     name. *)
  val tmpName : unit -> string

  (* The type that tells one file from another, whatever path leads to it.

     Deviation: `OS.FileSys.file_id/is-a-pair`. The specification leaves the
     type abstract; in Rune it is the pair of the device number and the inode
     number of the file, and the structure is not sealed. *)
  eqtype file_id

  (* `fileId p` is the identity of what `p` names: two paths to one file give the same `file_id`.

     Raises: `OS.SysErr` if `p` names nothing. *)
  val fileId : string -> file_id

  (* `hash id` is a word for `id`, spread well enough to index a table with.

     Implementation: `OS.FileSys.hash/device-and-inode`. It is the device
     number times 65599 plus the inode number, in wrapping word arithmetic.
     "Well distributed modulo 2^n" is checked only as far as a test can: the
     same file hashes the same, and sixteen files do not all agree in the
     lowest bit.

     Pinned by: `OS.FileSys.hash/same-object`, `OS.FileSys.hash/spread` *)
  val hash : file_id -> word

  (* `compare (a, b)` orders two file identities, so that they can be kept in a map. *)
  val compare : file_id * file_id -> order
end

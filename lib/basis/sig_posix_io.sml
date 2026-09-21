(* File descriptors: reading and writing them, duplicating them, positioning
   them, locking them, and turning them into readers and writers.

   A `file_desc` is the small number the system knows an open file by.
   `Posix.FileSys` opens files and gives descriptors; this signature is what
   a program does with one afterwards.

   `mkBinReader` and the three like it bridge to the rest of the library:
   they wrap a descriptor as a `PRIM_IO` reader or writer, which
   `STREAM_IO` and then `TEXT_IO` or `BIN_IO` build streams on.

   Area: The operating system

   Status: optional

   See also: `POSIX_FILE_SYS`, `PRIM_IO`, `POSIX`, `TEXT_IO`, `BIN_IO`

   Erratum: `POSIX_IO/flexible-types`. The types are kept as the page writes
   them; the identities that `POSIX` states in its `where type` clauses --
   `pid` is `Posix.Process.pid`, `file_desc` is `Posix.ProcEnv.file_desc`, and
   `open_mode` is
   `Posix.FileSys.open_mode` -- are checked in the suite rather than written
   here.

   Reading: `Posix.IO/what-comes-from-posix`. Two things the page does not
   state come from POSIX itself: a descriptor that has just been made has
   `FD.cloexec` clear, and a process's own lock never blocks it, so `getlk`
   reports `F_UNLCK` for it. *)
signature POSIX_IO =
sig
  (* The type of an open file descriptor.

     Deviation: `Posix.IO.file_desc/is-an-int`. The specification leaves the
     type abstract; in Rune it is `int`, the number the system uses, and the type is not made abstract. *)
  eqtype file_desc

  (* The type of the number that names a process, the one of `Posix.Process`. *)
  eqtype pid

  (* `pipe ()` is a pair of descriptors: what is written to `outfd` can be read from `infd`.

     Raises: `OS.SysErr` if no pipe can be made. *)
  val pipe : unit -> {infd : file_desc, outfd : file_desc}

  (* `dup fd` is a new descriptor on the same open file as `fd`.

     The two share their position, so reading through one moves the other.

     Raises: `OS.SysErr` if `fd` is not open, or no descriptor is free.

     Reading: `Posix.IO.dup/lowest-available`. "The lowest one available" is
     read strictly: closing a descriptor that was just opened and then
     calling `dup` gives that same number back.

     Pinned by: `Posix.IO.dup/lowest-available` *)
  val dup : file_desc -> file_desc

  (* `dup2 {old, new}` makes `new` a descriptor on the same open file as `old`, closing what `new` was on.

     Raises: `OS.SysErr` if `old` is not open. *)
  val dup2 : {old : file_desc, new : file_desc} -> unit

  (* `close fd` closes `fd`.

     Raises: `OS.SysErr` if `fd` was not open. *)
  val close : file_desc -> unit

  (* `readVec (fd, n)` reads at most `n` bytes from `fd` and is what it read.

     A shorter vector than `n` means only that less was there; the empty
     vector means the end of the file.

     Raises: `Size` if `n < 0`; `OS.SysErr` if the read fails. *)
  val readVec : file_desc * int -> Word8Vector.vector

  (* `readArr (fd, sl)` reads into the stretch `sl` and is the number of bytes read, 0 at the end of the file.

     Raises: `OS.SysErr` if the read fails. *)
  val readArr : file_desc * Word8ArraySlice.slice -> int

  (* `writeVec (fd, sl)` writes the bytes of `sl` and is the number it wrote, which may be fewer.

     Raises: `OS.SysErr` if the write fails. *)
  val writeVec : file_desc * Word8VectorSlice.slice -> int

  (* `writeArr (fd, sl)` writes the bytes of the array stretch `sl` and is the number it wrote.

     Raises: `OS.SysErr` if the write fails. *)
  val writeArr : file_desc * Word8ArraySlice.slice -> int

  (* What a position given to `lseek` or a lock is counted from. *)
  datatype whence
    = SEEK_SET   (* the start of the file *)
    | SEEK_CUR   (* where the descriptor is now *)
    | SEEK_END   (* the end of the file *)

  (* The flags of a descriptor itself, which `dup` does not carry over. *)
  structure FD :
  sig
    include BIT_FLAGS

    (* Close this descriptor when the process runs another program.

       A descriptor that has just been made does not have it. *)
    val cloexec : flags
  end

  (* The flags of the open file that a descriptor is on, which `dup` shares. *)
  structure O :
  sig
    include BIT_FLAGS

    (* Every write goes to the end of the file. *)
    val append : flags

    (* A read or a write that would wait fails instead. *)
    val nonblock : flags

    (* A write returns only once the data have reached the device. *)
    val sync : flags
  end

  (* What a file was opened for. *)
  datatype open_mode
    = O_RDONLY   (* reading only *)
    | O_WRONLY   (* writing only *)
    | O_RDWR     (* both *)

  (* `dupfd {old, base}` is `dup old`, but the number it gives is at least `base`.

     Raises: `OS.SysErr` if `old` is not open, or no such descriptor is
     free. *)
  val dupfd : {old : file_desc, base : file_desc}
              -> file_desc

  (* `getfd fd` is the flags of the descriptor `fd` itself.

     Raises: `OS.SysErr` if `fd` is not open. *)
  val getfd : file_desc -> FD.flags

  (* `setfd (fd, fl)` sets the flags of the descriptor `fd` to `fl`.

     Raises: `OS.SysErr` if `fd` is not open. *)
  val setfd : file_desc * FD.flags -> unit

  (* `getfl fd` is the flags of the open file that `fd` is on, and what it was opened for.

     Raises: `OS.SysErr` if `fd` is not open. *)
  val getfl : file_desc -> O.flags * open_mode

  (* `setfl (fd, fl)` sets the flags of the open file that `fd` is on.

     What a file was opened for cannot be changed this way.

     Raises: `OS.SysErr` if `fd` is not open. *)
  val setfl : file_desc * O.flags -> unit

  (* `lseek (fd, n, whence)` moves `fd` to `n` bytes from the place `whence` names, and is where it now is.

     Raises: `OS.SysErr` if `fd` cannot be positioned -- a pipe, a socket or
     a terminal. *)
  val lseek : file_desc * Position.int * whence
              -> Position.int

  (* `fsync fd` waits until what was written to `fd` has reached the device.

     Raises: `OS.SysErr` if `fd` is not open, or the write fails. *)
  val fsync : file_desc -> unit

  (* What a lock is for, and what `F_UNLCK` says when a lock is asked about. *)
  datatype lock_type
    = F_RDLCK   (* a read lock: others may read, none may write *)
    | F_WRLCK   (* a write lock: none may read or write *)
    | F_UNLCK   (* no lock; as an answer, that nothing blocks *)

  (* A description of a stretch of a file and what is to be done with it.

     Implementation: `Posix.IO.FLock/is-a-flock`. The lock operations are
     `fcntl` with a `struct flock`, and a `flock` here is that record. *)
  structure FLock :
  sig
    (* The type of a lock description. *)
    type flock

    (* `flock {ltype, whence, start, len, pid}` describes a lock of kind `ltype` on the stretch that the rest names.

       `len` of zero reaches to the end of the file, however far it grows.
       `pid` is meaningful only in what `getlk` gives back. *)
    val flock : {
                  ltype : lock_type,
                  whence : whence,
                  start : Position.int,
                  len : Position.int,
                  pid : pid option
                } -> flock

    (* `ltype fl` is the kind of lock `fl` describes. *)
    val ltype : flock -> lock_type

    (* `whence fl` is what `start fl` is counted from. *)
    val whence : flock -> whence

    (* `start fl` is where the locked stretch begins. *)
    val start : flock -> Position.int

    (* `len fl` is how long the locked stretch is, 0 meaning to the end of the file. *)
    val len : flock -> Position.int

    (* `pid fl` is the process holding the lock, when `getlk` found one. *)
    val pid : flock -> pid option
  end

  (* `getlk (fd, fl)` asks what would block the lock `fl`, without taking it.

     Raises: `OS.SysErr` if the question is refused.

     Reading: `Posix.IO.getlk/F_UNLCK-means-free`. When nothing blocks the
     described lock, POSIX reports that as an answer of kind `F_UNLCK`; and
     since a process's own locks never block it, its own lock is reported
     that way too.

     Pinned by: `Posix.IO.getlk/*` *)
  val getlk : file_desc * FLock.flock -> FLock.flock

  (* `setlk (fd, fl)` takes or releases the lock `fl` without waiting.

     Raises: `OS.SysErr` if another process holds a lock in the way. *)
  val setlk : file_desc * FLock.flock -> FLock.flock

  (* `setlkw (fd, fl)` takes or releases the lock `fl`, waiting until it can.

     Raises: `OS.SysErr` if the wait is interrupted or the lock is
     refused. *)
  val setlkw : file_desc * FLock.flock -> FLock.flock

  (* `mkBinReader {fd, name, initBlkMode}` is a `PRIM_IO` reader of bytes over `fd`.

     `name` is what an `IO.Io` from it will carry; `initBlkMode` says whether
     the descriptor starts in blocking mode.

     Implementation: `Posix.IO.mkBinReader/positions`. Only a regular file
     has positions, so `getPos`, `setPos`, `endPos` and `verifyPos` are
     `NONE` for a pipe, a socket or a terminal.

     Pinned by: `Posix.IO.mkBinReader/*` *)
  val mkBinReader : {
                      fd : file_desc,
                      name : string,
                      initBlkMode : bool
                    } -> BinPrimIO.reader

  (* `mkTextReader {fd, name, initBlkMode}` is a `PRIM_IO` reader of characters over `fd`. *)
  val mkTextReader : {
                       fd : file_desc,
                       name : string,
                       initBlkMode : bool
                     } -> TextPrimIO.reader

  (* `mkBinWriter {fd, name, appendMode, initBlkMode, chunkSize}` is a `PRIM_IO` writer of bytes over `fd`.

     `appendMode` says whether every write goes to the end of the file, and
     `chunkSize` how much the writer likes to be given at a time. *)
  val mkBinWriter : {
                      fd : file_desc,
                      name : string,
                      appendMode : bool,
                      initBlkMode : bool,
                      chunkSize : int
                    } -> BinPrimIO.writer

  (* `mkTextWriter {fd, name, appendMode, initBlkMode, chunkSize}` is a `PRIM_IO` writer of characters over `fd`. *)
  val mkTextWriter : {
                       fd : file_desc,
                       name : string,
                       appendMode : bool,
                       initBlkMode : bool,
                       chunkSize : int
                     } -> TextPrimIO.writer
end

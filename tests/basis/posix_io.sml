(* requires: Posix OS TextIO BinIO Byte SysWord Word8Vector Word8VectorSlice Word8Array Word8ArraySlice *)
(* Posix.IO (signature POSIX_IO). Expected values follow the text of
   https://smlfamily.github.io/Basis/posix-io.html. Files are made in the
   current directory and removed again; pipes are closed. Nothing reads from
   a descriptor that has no data yet and a writer that could still write:
   that would wait for ever (or, on a descriptor that does not block, fail
   in a way the page does not describe).

   Two things come from POSIX rather than the page: a new descriptor has
   FD.cloexec clear (open and dup clear FD_CLOEXEC), and a process's own
   locks never block it, so that getlk reports F_UNLCK for a lock the process
   holds. File locking is a section of its own. *)
structure TestPosixIO =
struct
  structure FS = Posix.FileSys
  structure PIO = Posix.IO

  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqI = T.eq T.int
  val eqPos = T.eq Position.toString
  fun isSysErr e = case e of OS.SysErr _ => true | _ => false
  fun isSize e = case e of Size => true | _ => false

  fun write (name, s) =
    let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
  fun slurp name =
    let val ins = TextIO.openIn name val s = TextIO.inputAll ins in TextIO.closeIn ins; s end
  fun remove name = FS.unlink name handle OS.SysErr _ => ()
  fun bytes s = Byte.stringToBytes s
  fun str v = Byte.bytesToString v
  fun readS (fd, n) = str (PIO.readVec (fd, n))
  fun writeS (fd, s) = PIO.writeVec (fd, Word8VectorSlice.full (bytes s))
  fun pos n = Position.fromInt n
  (* withFd (name, contents, mode, flags, f): f fd on a new file that holds
     contents, opened with openf; closed and removed afterwards *)
  fun withFd (name, contents, mode, flags, f) =
    let
      val () = write (name, contents)
      val fd = FS.openf (name, mode, flags)
      fun tidy () = (PIO.close fd; remove name)
    in (f fd before tidy ()) handle e => (tidy (); raise e) end
  fun withFile (name, contents, f) = withFd (name, contents, FS.O_RDONLY, FS.O.flags [], fn _ => f name)
  (* withPipe f: f {infd, outfd}; both ends closed afterwards unless f closed them *)
  fun withPipe f =
    let
      val p as {infd, outfd} = PIO.pipe ()
      fun tidy () = ((PIO.close infd handle OS.SysErr _ => ()); (PIO.close outfd handle OS.SysErr _ => ()))
    in (f p before tidy ()) handle e => (tidy (); raise e) end

  (* ---- pipe ---- *)
  (* "returns two file descriptors that refer to the read (infd) and write
     (outfd) ends of the pipe" *)
  val () = eqS ("Posix.IO.pipe/write-then-read", "through the pipe",
                fn () => withPipe (fn {infd, outfd} => (ignore (writeS (outfd, "through the pipe")); readS (infd, 100))))
  val () = eqB ("Posix.IO.pipe/distinct-ends", true,
                fn () => withPipe (fn {infd, outfd} => infd <> outfd andalso FS.fdToWord infd <> FS.fdToWord outfd))
  val () = eqS ("Posix.IO.pipe/end-of-stream-when-writer-closed", "abc|",
                fn () => withPipe (fn {infd, outfd} =>
                           (ignore (writeS (outfd, "abc")); PIO.close outfd;
                            readS (infd, 100) ^ "|" ^ readS (infd, 100))))
  val () = T.raises ("Posix.IO.pipe/read-end-cannot-write", isSysErr,
                     fn () => withPipe (fn {infd, ...} => writeS (infd, "x")))
  val () = eqB ("Posix.IO.pipe/kind", true,
                fn () => withPipe (fn {infd, outfd} => OS.IO.kind (FS.fdToIOD infd) = OS.IO.Kind.pipe
                                                       andalso OS.IO.kind (FS.fdToIOD outfd) = OS.IO.Kind.pipe))

  (* ---- close ---- *)
  val () = T.raises ("Posix.IO.close/then-read", isSysErr,
                     fn () => withPipe (fn {infd, outfd} => (ignore (writeS (outfd, "x")); PIO.close infd; readS (infd, 1))))
  val () = T.raises ("Posix.IO.close/then-write", isSysErr,
                     fn () => withPipe (fn {outfd, ...} => (PIO.close outfd; writeS (outfd, "x"))))
  val () = eqS ("Posix.IO.close/other-end-sees-end-of-stream", "",
                fn () => withPipe (fn {infd, outfd} => (PIO.close outfd; readS (infd, 10))))

  (* ---- readVec ---- *)
  (* "reads at most n bytes ... The size of the resulting vector is the
     number of bytes that were successfully read, which may be less than n.
     This function returns the empty vector if end-of-stream is detected (or
     if n is 0). It raises the Size exception if n < 0." *)
  val () = eqS ("Posix.IO.readVec/at-most-n", "hel",
                fn () => withFd ("pio-read", "hello", FS.O_RDONLY, FS.O.flags [], fn fd => readS (fd, 3)))
  val () = eqS ("Posix.IO.readVec/continues", "hel|lo|",
                fn () => withFd ("pio-read", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           readS (fd, 3) ^ "|" ^ readS (fd, 3) ^ "|" ^ readS (fd, 3)))
  val () = eqS ("Posix.IO.readVec/zero", "|hello",
                fn () => withFd ("pio-read", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           readS (fd, 0) ^ "|" ^ readS (fd, 10)))
  val () = eqS ("Posix.IO.readVec/empty-file", "", fn () => withFd ("pio-read", "", FS.O_RDONLY, FS.O.flags [], fn fd => readS (fd, 10)))
  val () = eqS ("Posix.IO.readVec/binary", "\000\255\n\r\001",
                fn () => withFd ("pio-read", "\000\255\n\r\001", FS.O_RDONLY, FS.O.flags [], fn fd => readS (fd, 10)))
  val () = T.raises ("Posix.IO.readVec/negative", isSize,
                     fn () => withFd ("pio-read", "hello", FS.O_RDONLY, FS.O.flags [], fn fd => PIO.readVec (fd, ~1)))
  val () = T.raises ("Posix.IO.readVec/write-only", isSysErr,
                     fn () => withFd ("pio-read", "hello", FS.O_WRONLY, FS.O.flags [], fn fd => PIO.readVec (fd, 1)))

  (* ---- readArr ---- *)
  (* "reads bytes from the file specified by fd into the array slice slice
     and returns the number of bytes actually read. The end-of-file condition
     is marked by returning 0, although 0 is also returned if the slice is
     empty. This function will raise OS.SysErr if there is some problem with
     the underlying system call (e.g., the file is closed)." *)
  fun arrString a = str (Word8Array.vector a)
  val () = eqS ("Posix.IO.readArr/into-slice", "3:..hel.",
                fn () => withFd ("pio-read", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           let
                             val a = Word8Array.array (6, Byte.charToByte #".")
                             val n = PIO.readArr (fd, Word8ArraySlice.slice (a, 2, SOME 3))
                           in Int.toString n ^ ":" ^ arrString a end))
  val () = eqS ("Posix.IO.readArr/short", "5:hello...",
                fn () => withFd ("pio-read", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           let
                             val a = Word8Array.array (8, Byte.charToByte #".")
                             val n = PIO.readArr (fd, Word8ArraySlice.full a)
                           in Int.toString n ^ ":" ^ arrString a end))
  val () = eqI ("Posix.IO.readArr/end-of-file", 0,
                fn () => withFd ("pio-read", "hi", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           let val a = Word8Array.array (4, Word8.fromInt 0)
                           in ignore (PIO.readArr (fd, Word8ArraySlice.full a)); PIO.readArr (fd, Word8ArraySlice.full a) end))
  val () = eqS ("Posix.IO.readArr/empty-slice", "0:hello",
                fn () => withFd ("pio-read", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           let val a = Word8Array.array (4, Word8.fromInt 0)
                           in Int.toString (PIO.readArr (fd, Word8ArraySlice.slice (a, 2, SOME 0))) ^ ":" ^ readS (fd, 10) end))
  val () = T.raises ("Posix.IO.readArr/closed", isSysErr,
                     fn () => withPipe (fn {infd, outfd} =>
                                (ignore (writeS (outfd, "x")); PIO.close infd;
                                 PIO.readArr (infd, Word8ArraySlice.full (Word8Array.array (4, Word8.fromInt 0))))))

  (* ---- writeVec, writeArr ---- *)
  (* "These functions write the bytes the vector or array slice slice to the
     open file fd. Both functions return the number bytes actually written
     and will raise OS.SysErr if there is some problem with the underlying
     system call (e.g., the file is closed ...)." *)
  val () = eqS ("Posix.IO.writeVec/slice", "3:ell",
                fn () => withFd ("pio-write", "", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           let val n = PIO.writeVec (fd, Word8VectorSlice.slice (bytes "hello", 1, SOME 3))
                           in Int.toString n ^ ":" ^ slurp "pio-write" end))
  val () = eqS ("Posix.IO.writeVec/empty-slice", "0:",
                fn () => withFd ("pio-write", "", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           Int.toString (PIO.writeVec (fd, Word8VectorSlice.slice (bytes "hello", 5, NONE))) ^ ":" ^ slurp "pio-write"))
  val () = eqS ("Posix.IO.writeVec/twice", "abcdef",
                fn () => withFd ("pio-write", "", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           (ignore (writeS (fd, "abc")); ignore (writeS (fd, "def")); slurp "pio-write")))
  val () = T.raises ("Posix.IO.writeVec/closed", isSysErr,
                     fn () => withPipe (fn {outfd, ...} => (PIO.close outfd; writeS (outfd, "x"))))
  val () = T.raises ("Posix.IO.writeVec/read-only", isSysErr,
                     fn () => withFd ("pio-write", "", FS.O_RDONLY, FS.O.flags [], fn fd => writeS (fd, "x")))
  val () = eqS ("Posix.IO.writeArr/slice", "2:cd",
                fn () => withFd ("pio-write", "", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           let
                             val a = Word8Array.fromList (List.map Byte.charToByte (String.explode "abcdef"))
                             val n = PIO.writeArr (fd, Word8ArraySlice.slice (a, 2, SOME 2))
                           in Int.toString n ^ ":" ^ slurp "pio-write" end))
  val () = eqS ("Posix.IO.writeArr/binary", "\000\255\n",
                fn () => withFd ("pio-write", "", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           (ignore (PIO.writeArr (fd, Word8ArraySlice.full (Word8Array.fromList (List.map Word8.fromInt [0, 255, 10]))));
                            slurp "pio-write")))
  val () = T.raises ("Posix.IO.writeArr/closed", isSysErr,
                     fn () => withPipe (fn {outfd, ...} =>
                                (PIO.close outfd; PIO.writeArr (outfd, Word8ArraySlice.full (Word8Array.array (1, Word8.fromInt 0))))))

  (* ---- lseek, whence ---- *)
  (* "sets the file offset for the open file descriptor fd to off if wh is
     SEEK_SET; to its current value plus off bytes if wh is SEEK_CUR; or, to
     the size of the file plus off bytes if wh is SEEK_END. Note that off may
     be negative." *)
  val () = eqS ("Posix.IO.SEEK_SET/offset", "3:lo",
                fn () => withFd ("pio-seek", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           Position.toString (PIO.lseek (fd, pos 3, PIO.SEEK_SET)) ^ ":" ^ readS (fd, 10)))
  val () = eqS ("Posix.IO.SEEK_CUR/offset", "4:o",
                fn () => withFd ("pio-seek", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           (ignore (readS (fd, 2)); Position.toString (PIO.lseek (fd, pos 2, PIO.SEEK_CUR)) ^ ":" ^ readS (fd, 10))))
  val () = eqS ("Posix.IO.SEEK_CUR/negative", "1:ell",
                fn () => withFd ("pio-seek", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           (ignore (readS (fd, 4)); Position.toString (PIO.lseek (fd, pos ~3, PIO.SEEK_CUR)) ^ ":" ^ readS (fd, 3))))
  val () = eqS ("Posix.IO.SEEK_END/negative", "3:lo",
                fn () => withFd ("pio-seek", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           Position.toString (PIO.lseek (fd, pos ~2, PIO.SEEK_END)) ^ ":" ^ readS (fd, 10)))
  val () = eqPos ("Posix.IO.SEEK_END/size", pos 5,
                  fn () => withFd ("pio-seek", "hello", FS.O_RDONLY, FS.O.flags [], fn fd => PIO.lseek (fd, pos 0, PIO.SEEK_END)))
  val () = eqPos ("Posix.IO.lseek/current-position", pos 2,
                  fn () => withFd ("pio-seek", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                             (ignore (readS (fd, 2)); PIO.lseek (fd, pos 0, PIO.SEEK_CUR))))
  val () = eqS ("Posix.IO.lseek/then-write", "heLLo",
                fn () => withFd ("pio-seek", "hello", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           (ignore (PIO.lseek (fd, pos 2, PIO.SEEK_SET)); ignore (writeS (fd, "LL")); slurp "pio-seek")))
  val () = eqS ("Posix.IO.lseek/beyond-the-end", "hello\000\000!",
                fn () => withFd ("pio-seek", "hello", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           (ignore (PIO.lseek (fd, pos 2, PIO.SEEK_END)); ignore (writeS (fd, "!")); slurp "pio-seek")))

  (* ---- fsync ---- *)
  (* "all data for the open file descriptor fd is to be transferred to the
     device associated with the descriptor" *)
  val () = eqS ("Posix.IO.fsync/written-file", "synced",
                fn () => withFd ("pio-sync", "", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           (ignore (writeS (fd, "synced")); PIO.fsync fd; slurp "pio-sync")))

  (* ---- dup, dup2, dupfd ---- *)
  (* dup: "returns a new file descriptor that refers to the same open file,
     with the same file pointer and access mode, as fd. The underlying word
     ... of the returned file descriptor is the lowest one available." *)
  val () = eqS ("Posix.IO.dup/same-file-pointer", "he|ll|o",
                fn () => withFd ("pio-dup", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           let val d = PIO.dup fd
                           in (readS (fd, 2) ^ "|" ^ readS (d, 2) ^ "|" ^ readS (fd, 2)) before PIO.close d end))
  val () = eqB ("Posix.IO.dup/new-descriptor", true,
                fn () => withFd ("pio-dup", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           let val d = PIO.dup fd in (d <> fd andalso FS.fdToWord d <> FS.fdToWord fd) before PIO.close d end))
  val () = T.raises ("Posix.IO.dup/same-access-mode", isSysErr,
                     fn () => withFd ("pio-dup", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                                let val d = PIO.dup fd
                                in (writeS (d, "x") before PIO.close d) handle e => (PIO.close d; raise e) end))
  (* The lowest descriptor available is the one that was just closed: open
     returns the lowest one too. *)
  val () = eqB ("Posix.IO.dup/lowest-available", true,
                fn () => withFd ("pio-dup", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           let
                             val a = FS.openf ("pio-dup", FS.O_RDONLY, FS.O.flags [])
                             val w = FS.fdToWord a
                             val () = PIO.close a
                             val d = PIO.dup fd
                           in (FS.fdToWord d = w) before PIO.close d end))
  (* "It is equivalent to dupfd {old=fd, base=Posix.FileSys.wordToFD 0w0}." *)
  val () = eqB ("Posix.IO.dupfd/base-0-is-dup", true,
                fn () => withFd ("pio-dup", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           let
                             val a = FS.openf ("pio-dup", FS.O_RDONLY, FS.O.flags [])
                             val w = FS.fdToWord a
                             val () = PIO.close a
                             val d = PIO.dupfd {old = fd, base = FS.wordToFD 0w0}
                           in (FS.fdToWord d = w) before PIO.close d end))
  (* "The returned descriptor is greater than or equal to the file descriptor
     base" *)
  val () = eqB ("Posix.IO.dupfd/at-least-base", true,
                fn () => withFd ("pio-dup", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           let val d = PIO.dupfd {old = fd, base = FS.wordToFD 0w20}
                           in (FS.fdToWord d >= 0w20) before PIO.close d end))
  val () = eqS ("Posix.IO.dupfd/same-file", "he|llo",
                fn () => withFd ("pio-dup", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           let val d = PIO.dupfd {old = fd, base = FS.wordToFD 0w20}
                           in (readS (fd, 2) ^ "|" ^ readS (d, 10)) before PIO.close d end))
  (* "duplicates the open file descriptor old as file descriptor new" *)
  val () = eqS ("Posix.IO.dup2/redirects", "into a|",
                fn () => withFd ("pio-dup-a", "", FS.O_WRONLY, FS.O.flags [], fn a =>
                           withFd ("pio-dup-b", "", FS.O_WRONLY, FS.O.flags [], fn b =>
                             (PIO.dup2 {old = a, new = b}; ignore (writeS (b, "into a"));
                              slurp "pio-dup-a" ^ "|" ^ slurp "pio-dup-b"))))
  val () = eqS ("Posix.IO.dup2/same-descriptor", "hello",
                fn () => withFd ("pio-dup", "hello", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           (PIO.dup2 {old = fd, new = fd}; readS (fd, 10))))

  (* ---- getfd, setfd, FD ---- *)
  (* cloexec: "File descriptor flag that, if set, will cause the file
     descriptor to be closed should the opening process replace itself" *)
  val () = eqB ("Posix.IO.getfd/new-descriptor", false,
                fn () => withFd ("pio-fd", "", FS.O_RDONLY, FS.O.flags [], fn fd => PIO.FD.anySet (PIO.FD.cloexec, PIO.getfd fd)))
  val () = eqB ("Posix.IO.setfd/cloexec", true,
                fn () => withFd ("pio-fd", "", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           (PIO.setfd (fd, PIO.FD.cloexec); PIO.FD.anySet (PIO.FD.cloexec, PIO.getfd fd))))
  val () = eqB ("Posix.IO.setfd/clear", false,
                fn () => withFd ("pio-fd", "", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           (PIO.setfd (fd, PIO.FD.cloexec); PIO.setfd (fd, PIO.FD.flags []); PIO.FD.anySet (PIO.FD.cloexec, PIO.getfd fd))))
  val () = eqB ("Posix.IO.FD.cloexec/not-inherited-by-dup", false,
                fn () => withFd ("pio-fd", "", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           (PIO.setfd (fd, PIO.FD.cloexec);
                            let val d = PIO.dup fd in PIO.FD.anySet (PIO.FD.cloexec, PIO.getfd d) before PIO.close d end)))
  val () = eqB ("Posix.IO.FD.cloexec/per-descriptor", true,
                fn () => withFd ("pio-fd", "", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           let val d = PIO.dup fd
                           in
                             PIO.setfd (d, PIO.FD.cloexec);
                             (PIO.FD.anySet (PIO.FD.cloexec, PIO.getfd d) andalso not (PIO.FD.anySet (PIO.FD.cloexec, PIO.getfd fd)))
                             before PIO.close d
                           end))

  (* ---- getfl, setfl, O, open_mode ---- *)
  (* getfl: "gets the file status flags for the open file descriptor fd and
     the access mode in which the file was opened" *)
  fun modeOf fd = #2 (PIO.getfl fd)
  val () = eqB ("Posix.IO.O_RDONLY/getfl", true,
                fn () => withFd ("pio-fl", "", FS.O_RDONLY, FS.O.flags [], fn fd => modeOf fd = PIO.O_RDONLY))
  val () = eqB ("Posix.IO.O_WRONLY/getfl", true,
                fn () => withFd ("pio-fl", "", FS.O_WRONLY, FS.O.flags [], fn fd => modeOf fd = PIO.O_WRONLY))
  val () = eqB ("Posix.IO.O_RDWR/getfl", true,
                fn () => withFd ("pio-fl", "", FS.O_RDWR, FS.O.flags [], fn fd => modeOf fd = PIO.O_RDWR))
  val () = eqB ("Posix.IO.getfl/pipe-ends", true,
                fn () => withPipe (fn {infd, outfd} => modeOf infd = PIO.O_RDONLY andalso modeOf outfd = PIO.O_WRONLY))
  val () = eqB ("Posix.IO.getfl/no-append", false,
                fn () => withFd ("pio-fl", "", FS.O_WRONLY, FS.O.flags [], fn fd => PIO.O.anySet (PIO.O.append, #1 (PIO.getfl fd))))
  (* append: "File status flag which forces the file offset to be set to the
     end of the file prior to each write" *)
  val () = eqB ("Posix.IO.O.append/getfl-after-openf", true,
                fn () => withFd ("pio-fl", "", FS.O_WRONLY, FS.O.append, fn fd => PIO.O.anySet (PIO.O.append, #1 (PIO.getfl fd))))
  (* setfl: "sets the file status flags for the open file descriptor fd to fl" *)
  val () = eqB ("Posix.IO.setfl/append", true,
                fn () => withFd ("pio-fl", "", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           (PIO.setfl (fd, PIO.O.append); PIO.O.anySet (PIO.O.append, #1 (PIO.getfl fd)))))
  val () = eqS ("Posix.IO.setfl/append-writes-at-end", "hello!",
                fn () => withFd ("pio-fl", "hello", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           (PIO.setfl (fd, PIO.O.append); ignore (writeS (fd, "!")); slurp "pio-fl")))
  val () = eqB ("Posix.IO.setfl/clear", false,
                fn () => withFd ("pio-fl", "", FS.O_WRONLY, FS.O.append, fn fd =>
                           (PIO.setfl (fd, PIO.O.flags []); PIO.O.anySet (PIO.O.append, #1 (PIO.getfl fd)))))
  val () = eqS ("Posix.IO.setfl/cleared-append-writes-at-offset", "Jello",
                fn () => withFd ("pio-fl", "hello", FS.O_WRONLY, FS.O.append, fn fd =>
                           (PIO.setfl (fd, PIO.O.flags []); ignore (writeS (fd, "J")); slurp "pio-fl")))
  val () = eqB ("Posix.IO.setfl/keeps-access-mode", true,
                fn () => withFd ("pio-fl", "", FS.O_RDWR, FS.O.flags [], fn fd =>
                           (PIO.setfl (fd, PIO.O.append); modeOf fd = PIO.O_RDWR)))
  (* nonblock: "File status flag used to enable non-blocking I/O." *)
  val () = eqB ("Posix.IO.O.nonblock/setfl", true,
                fn () => withPipe (fn {infd, ...} =>
                           (PIO.setfl (infd, PIO.O.nonblock); PIO.O.anySet (PIO.O.nonblock, #1 (PIO.getfl infd)))))
  val () = eqB ("Posix.IO.O.nonblock/new-pipe", false,
                fn () => withPipe (fn {infd, ...} => PIO.O.anySet (PIO.O.nonblock, #1 (PIO.getfl infd))))
  (* sync: "File status flag enabling writes using synchronized I/O file
     integrity completion." *)
  val () = eqB ("Posix.IO.O.sync/getfl-after-openf", true,
                fn () => withFd ("pio-fl", "", FS.O_WRONLY, FS.O.sync, fn fd =>
                           let val w = PIO.O.toWord PIO.O.sync
                           in SysWord.andb (PIO.O.toWord (#1 (PIO.getfl fd)), w) = w end))
  val () = eqB ("Posix.IO.O.sync/not-set", false,
                fn () => withFd ("pio-fl", "", FS.O_WRONLY, FS.O.flags [], fn fd => PIO.O.anySet (PIO.O.sync, #1 (PIO.getfl fd))))

  (* ---- mkBinReader, mkTextReader, mkBinWriter, mkTextWriter ---- *)
  (* "These functions convert an open POSIX file descriptor into a reader.
     From this, one can then construct an input stream." *)
  val () = eqS ("Posix.IO.mkBinReader/readVec", "bin",
                fn () => withFd ("pio-rd", "binary", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           case PIO.mkBinReader {fd = fd, name = "pio-rd", initBlkMode = true} of
                             BinPrimIO.RD {readVec = SOME readVec, ...} => str (readVec 3)
                           | BinPrimIO.RD {readVec = NONE, ...} => "no readVec"))
  val () = eqS ("Posix.IO.mkBinReader/name", "the name",
                fn () => withFd ("pio-rd", "", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           case PIO.mkBinReader {fd = fd, name = "the name", initBlkMode = true} of
                             BinPrimIO.RD {name, ...} => name))
  val () = eqS ("Posix.IO.mkBinReader/stream", "\000binary\255",
                fn () => withFd ("pio-rd", "\000binary\255", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           let
                             val d = PIO.dup fd
                             val ins = BinIO.mkInstream (BinIO.StreamIO.mkInstream
                                                           (PIO.mkBinReader {fd = d, name = "pio-rd", initBlkMode = true},
                                                            Word8Vector.fromList []))
                           in str (BinIO.inputAll ins) before BinIO.closeIn ins end))
  (* A pipe has no positions: the stream must not need them. *)
  val () = eqS ("Posix.IO.mkBinReader/from-a-pipe", "piped",
                fn () => withPipe (fn {infd, outfd} =>
                           let
                             val () = ignore (writeS (outfd, "piped"))
                             val () = PIO.close outfd
                             val ins = BinIO.mkInstream (BinIO.StreamIO.mkInstream
                                                           (PIO.mkBinReader {fd = PIO.dup infd, name = "pipe", initBlkMode = true},
                                                            Word8Vector.fromList []))
                           in str (BinIO.inputAll ins) before BinIO.closeIn ins end))
  val () = eqS ("Posix.IO.mkTextReader/readVec", "tex",
                fn () => withFd ("pio-rd", "text", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           case PIO.mkTextReader {fd = fd, name = "pio-rd", initBlkMode = true} of
                             TextPrimIO.RD {readVec = SOME readVec, ...} => readVec 3
                           | TextPrimIO.RD {readVec = NONE, ...} => "no readVec"))
  val () = eqS ("Posix.IO.mkTextReader/name", "the name",
                fn () => withFd ("pio-rd", "", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           case PIO.mkTextReader {fd = fd, name = "the name", initBlkMode = true} of
                             TextPrimIO.RD {name, ...} => name))
  val () = eqS ("Posix.IO.mkTextReader/stream-lines", "one\n|two|",
                fn () => withFd ("pio-rd", "one\ntwo", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           let
                             val d = PIO.dup fd
                             val ins = TextIO.mkInstream (TextIO.StreamIO.mkInstream
                                                            (PIO.mkTextReader {fd = d, name = "pio-rd", initBlkMode = true}, ""))
                             fun line () = getOpt (TextIO.inputLine ins, "")
                             val l1 = line ()
                             val l2 = TextIO.inputAll ins
                           in (l1 ^ "|" ^ l2 ^ "|") before TextIO.closeIn ins end))
  val () = eqS ("Posix.IO.mkTextReader/from-a-pipe", "piped",
                fn () => withPipe (fn {infd, outfd} =>
                           let
                             val () = ignore (writeS (outfd, "piped"))
                             val () = PIO.close outfd
                             val ins = TextIO.mkInstream (TextIO.StreamIO.mkInstream
                                                            (PIO.mkTextReader {fd = PIO.dup infd, name = "pipe", initBlkMode = true}, ""))
                           in TextIO.inputAll ins before TextIO.closeIn ins end))
  (* "These functions convert an open POSIX file descriptor into a writer." *)
  val () = eqS ("Posix.IO.mkBinWriter/writeVec", "3:bin",
                fn () => withFd ("pio-wr", "", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           case PIO.mkBinWriter {fd = fd, name = "pio-wr", appendMode = false, initBlkMode = true, chunkSize = 64} of
                             BinPrimIO.WR {writeVec = SOME writeVec, ...} =>
                               Int.toString (writeVec (Word8VectorSlice.full (bytes "bin"))) ^ ":" ^ slurp "pio-wr"
                           | BinPrimIO.WR {writeVec = NONE, ...} => "no writeVec"))
  (* chunkSize: "The recommended size of write operations for efficient
     writing." *)
  val () = eqS ("Posix.IO.mkBinWriter/name-and-chunkSize", "the name/77",
                fn () => withFd ("pio-wr", "", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           case PIO.mkBinWriter {fd = fd, name = "the name", appendMode = false, initBlkMode = true, chunkSize = 77} of
                             BinPrimIO.WR {name, chunkSize, ...} => name ^ "/" ^ Int.toString chunkSize))
  val () = eqS ("Posix.IO.mkBinWriter/stream", "\000out\255",
                fn () => withFd ("pio-wr", "", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           let
                             val out = BinIO.mkOutstream (BinIO.StreamIO.mkOutstream
                                                            (PIO.mkBinWriter {fd = PIO.dup fd, name = "pio-wr", appendMode = false,
                                                                             initBlkMode = true, chunkSize = 16},
                                                             IO.NO_BUF))
                           in BinIO.output (out, bytes "\000out\255"); BinIO.closeOut out; slurp "pio-wr" end))
  (* appendMode: "True if the file is in append mode, i.e., if the flag
     O.append is set in #1(getfl fd)." *)
  val () = eqS ("Posix.IO.mkBinWriter/append-mode", "old+new",
                fn () => withFd ("pio-wr", "old", FS.O_WRONLY, FS.O.append, fn fd =>
                           let
                             val out = BinIO.mkOutstream (BinIO.StreamIO.mkOutstream
                                                            (PIO.mkBinWriter {fd = PIO.dup fd, name = "pio-wr", appendMode = true,
                                                                             initBlkMode = true, chunkSize = 16},
                                                             IO.BLOCK_BUF))
                           in BinIO.output (out, bytes "+new"); BinIO.closeOut out; slurp "pio-wr" end))
  val () = eqS ("Posix.IO.mkBinWriter/into-a-pipe", "piped",
                fn () => withPipe (fn {infd, outfd} =>
                           let
                             val out = BinIO.mkOutstream (BinIO.StreamIO.mkOutstream
                                                            (PIO.mkBinWriter {fd = PIO.dup outfd, name = "pipe", appendMode = false,
                                                                              initBlkMode = true, chunkSize = 64},
                                                             IO.BLOCK_BUF))
                           in BinIO.output (out, bytes "piped"); BinIO.closeOut out; readS (infd, 100) end))
  val () = eqS ("Posix.IO.mkTextWriter/writeVec", "4:text",
                fn () => withFd ("pio-wr", "", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           case PIO.mkTextWriter {fd = fd, name = "pio-wr", appendMode = false, initBlkMode = true, chunkSize = 64} of
                             TextPrimIO.WR {writeVec = SOME writeVec, ...} =>
                               Int.toString (writeVec (CharVectorSlice.full "text")) ^ ":" ^ slurp "pio-wr"
                           | TextPrimIO.WR {writeVec = NONE, ...} => "no writeVec"))
  val () = eqS ("Posix.IO.mkTextWriter/name-and-chunkSize", "the name/77",
                fn () => withFd ("pio-wr", "", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           case PIO.mkTextWriter {fd = fd, name = "the name", appendMode = false, initBlkMode = true, chunkSize = 77} of
                             TextPrimIO.WR {name, chunkSize, ...} => name ^ "/" ^ Int.toString chunkSize))
  val () = eqS ("Posix.IO.mkTextWriter/stream", "line one\nline two\n",
                fn () => withFd ("pio-wr", "", FS.O_WRONLY, FS.O.flags [], fn fd =>
                           let
                             val out = TextIO.mkOutstream (TextIO.StreamIO.mkOutstream
                                                             (PIO.mkTextWriter {fd = PIO.dup fd, name = "pio-wr", appendMode = false,
                                                                               initBlkMode = true, chunkSize = 4},
                                                              IO.LINE_BUF))
                           in
                             TextIO.output (out, "line one\n"); TextIO.output (out, "line two\n"); TextIO.closeOut out;
                             slurp "pio-wr"
                           end))
  val () = eqS ("Posix.IO.mkTextWriter/into-a-pipe", "piped",
                fn () => withPipe (fn {infd, outfd} =>
                           let
                             val out = TextIO.mkOutstream (TextIO.StreamIO.mkOutstream
                                                             (PIO.mkTextWriter {fd = PIO.dup outfd, name = "pipe", appendMode = false,
                                                                               initBlkMode = true, chunkSize = 64},
                                                              IO.NO_BUF))
                           in TextIO.output (out, "piped"); TextIO.closeOut out; readS (infd, 100) end))

  (*<< flock *)
  (* "flock {ltype, whence, start, len, pid} creates a flock value described
     by the parameters"; ltype, whence, start, len and pid are "projection
     functions for the fields composing a flock value" *)
  val lock = PIO.FLock.flock {ltype = PIO.F_WRLCK, whence = PIO.SEEK_CUR, start = pos 3, len = pos 7, pid = NONE}
  val () = eqB ("Posix.IO.FLock.flock/fields", true,
                fn () => PIO.FLock.ltype lock = PIO.F_WRLCK andalso PIO.FLock.whence lock = PIO.SEEK_CUR
                         andalso PIO.FLock.start lock = pos 3 andalso PIO.FLock.len lock = pos 7
                         andalso PIO.FLock.pid lock = NONE)
  val () = eqB ("Posix.IO.FLock.ltype/read-lock", true,
                fn () => PIO.FLock.ltype (PIO.FLock.flock {ltype = PIO.F_RDLCK, whence = PIO.SEEK_SET, start = pos 0,
                                                         len = pos 0, pid = NONE}) = PIO.F_RDLCK)
  val () = eqB ("Posix.IO.FLock.whence/SEEK_END", true,
                fn () => PIO.FLock.whence (PIO.FLock.flock {ltype = PIO.F_UNLCK, whence = PIO.SEEK_END, start = pos ~1,
                                                          len = pos 1, pid = NONE}) = PIO.SEEK_END)
  val () = eqPos ("Posix.IO.FLock.start/negative", pos ~1,
                  fn () => PIO.FLock.start (PIO.FLock.flock {ltype = PIO.F_UNLCK, whence = PIO.SEEK_END, start = pos ~1,
                                                           len = pos 1, pid = NONE}))
  val () = eqPos ("Posix.IO.FLock.len/zero", pos 0,
                  fn () => PIO.FLock.len (PIO.FLock.flock {ltype = PIO.F_WRLCK, whence = PIO.SEEK_SET, start = pos 0,
                                                         len = pos 0, pid = NONE}))
  val () = eqB ("Posix.IO.FLock.pid/SOME", true,
                fn () => let val p = Posix.ProcEnv.getpid ()
                         in PIO.FLock.pid (PIO.FLock.flock {ltype = PIO.F_WRLCK, whence = PIO.SEEK_SET, start = pos 0,
                                                          len = pos 0, pid = SOME p}) = SOME p end)
  val () = eqB ("Posix.IO.F_UNLCK/distinct", true,
                fn () => PIO.F_UNLCK <> PIO.F_RDLCK andalso PIO.F_UNLCK <> PIO.F_WRLCK andalso PIO.F_RDLCK <> PIO.F_WRLCK)
  (* "If the section starts at the beginning of the file and len = 0, then the
     entire file is locked." *)
  fun whole ltype = PIO.FLock.flock {ltype = ltype, whence = PIO.SEEK_SET, start = pos 0, len = pos 0, pid = NONE}
  (* setlk: "sets or clears a file segment lock according to the lock
     description fl" *)
  val () = eqB ("Posix.IO.setlk/write-lock", true,
                fn () => withFd ("pio-lock", "locked", FS.O_RDWR, FS.O.flags [], fn fd =>
                           (ignore (PIO.setlk (fd, whole PIO.F_WRLCK)); ignore (PIO.setlk (fd, whole PIO.F_UNLCK)); true)))
  val () = eqB ("Posix.IO.F_RDLCK/setlk", true,
                fn () => withFd ("pio-lock", "locked", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           (ignore (PIO.setlk (fd, whole PIO.F_RDLCK)); ignore (PIO.setlk (fd, whole PIO.F_UNLCK)); true)))
  val () = eqB ("Posix.IO.F_WRLCK/setlk-needs-write-access", true,
                fn () => withFd ("pio-lock", "locked", FS.O_RDONLY, FS.O.flags [], fn fd =>
                           (ignore (PIO.setlk (fd, whole PIO.F_WRLCK)); false) handle OS.SysErr _ => true))
  val () = eqB ("Posix.IO.setlkw/write-lock", true,
                fn () => withFd ("pio-lock", "locked", FS.O_RDWR, FS.O.flags [], fn fd =>
                           (ignore (PIO.setlkw (fd, whole PIO.F_WRLCK)); ignore (PIO.setlkw (fd, whole PIO.F_UNLCK)); true)))
  (* getlk: "gets the first lock that blocks the lock description fl"; none
     does, and POSIX reports that as F_UNLCK *)
  val () = eqB ("Posix.IO.getlk/own-lock-does-not-block", true,
                fn () => withFd ("pio-lock", "locked", FS.O_RDWR, FS.O.flags [], fn fd =>
                           (ignore (PIO.setlk (fd, whole PIO.F_WRLCK));
                            PIO.FLock.ltype (PIO.getlk (fd, whole PIO.F_WRLCK)) = PIO.F_UNLCK)))
  val () = eqB ("Posix.IO.getlk/no-lock", true,
                fn () => withFd ("pio-lock", "locked", FS.O_RDWR, FS.O.flags [], fn fd =>
                           PIO.FLock.ltype (PIO.getlk (fd, whole PIO.F_RDLCK)) = PIO.F_UNLCK))
  (*>> flock *)
end

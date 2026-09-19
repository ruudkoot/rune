(* requires: Posix OS TextIO Byte SysWord Word8VectorSlice *)
(* Posix.FileSys (signature POSIX_FILE_SYS): descriptors, openf, createf,
   creat, umask, the flags of O and the modes of S, chmod, chown, access and
   ftruncate. Names and directories are in posix_filesys_dir.sml, stat and
   the times in posix_filesys_stat.sml. Expected values follow the text of
   https://smlfamily.github.io/Basis/posix-file-sys.html; "the interpretation
   of the bits is system-dependent, but follows the C language binding"
   (bit-flags.html), which gives the numbers of the standard descriptors and
   of the modes (section values).

   The files are made in the current directory, with the mask of the process
   set for the check that needs it and put back after it. A privileged
   process (real user 0) may read and write any file ("if the process has
   appropriate privileges, access will return true"), which the checks of
   access allow for. *)
structure TestPosixFileSys =
struct
  structure FS = Posix.FileSys
  structure S = Posix.FileSys.S
  structure O = Posix.FileSys.O

  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqW = T.eq (fn w => "0wx" ^ SysWord.toString w)
  fun showMode m = "0wx" ^ SysWord.toString (S.toWord m)
  val eqMode = T.eq showMode
  fun isSysErr e = case e of OS.SysErr _ => true | _ => false

  fun write (name, s) =
    let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
  fun slurp name =
    let val ins = TextIO.openIn name val s = TextIO.inputAll ins in TextIO.closeIn ins; s end
  fun remove name = FS.unlink name handle OS.SysErr _ => ()
  fun readFd (fd, n) = Byte.bytesToString (Posix.IO.readVec (fd, n))
  fun writeFd (fd, s) = Posix.IO.writeVec (fd, Word8VectorSlice.full (Byte.stringToBytes s))
  (* withMask (m, f): f () with the mask of the process set to m *)
  fun withMask (m, f) =
    let val old = FS.umask m
    in (f () before ignore (FS.umask old)) handle e => (ignore (FS.umask old); raise e) end
  (* withFile (name, contents, f): f name on a new file that holds contents,
     removed afterwards *)
  fun withFile (name, contents, f) =
    (remove name; write (name, contents); (f name before remove name) handle e => (remove name; raise e))
  (* withFd (name, mode, f): f fd on the file opened by openf, closed afterwards *)
  fun withFd (name, mode, flags, f) =
    let val fd = FS.openf (name, mode, flags)
    in (f fd before Posix.IO.close fd) handle e => (Posix.IO.close fd; raise e) end
  (* the bits of a mode that S names *)
  val perms = S.flags [S.irwxu, S.irwxg, S.irwxo, S.isuid, S.isgid]
  fun permsOf name = S.intersect [FS.ST.mode (FS.stat name), perms]
  fun privileged () = Posix.ProcEnv.getuid () = Posix.ProcEnv.wordToUid 0w0
  val rw_r__r__ = S.flags [S.irusr, S.iwusr, S.irgrp, S.iroth]
  val rw_rw_rw_ = S.flags [S.irusr, S.iwusr, S.irgrp, S.iwgrp, S.iroth, S.iwoth]

  (* ---- the standard descriptors, fdToWord, wordToFD ---- *)
  (* "The standard input, output, and error file descriptors": 0, 1 and 2
     (STDIN_FILENO, STDOUT_FILENO, STDERR_FILENO) *)
  val () = eqW ("Posix.FileSys.stdin/is-0", 0w0, fn () => FS.fdToWord FS.stdin)
  val () = eqW ("Posix.FileSys.stdout/is-1", 0w1, fn () => FS.fdToWord FS.stdout)
  val () = eqW ("Posix.FileSys.stderr/is-2", 0w2, fn () => FS.fdToWord FS.stderr)
  val () = eqB ("Posix.FileSys.stdout/is-open", true, fn () => (ignore (FS.fstat FS.stdout); true))
  val () = eqB ("Posix.FileSys.stderr/dup", true,
                fn () => let val fd = Posix.IO.dup FS.stderr
                         in (fd <> FS.stderr) before Posix.IO.close fd end)
  val () = eqB ("Posix.FileSys.stdin/wordToFD-0", true, fn () => FS.wordToFD 0w0 = FS.stdin)
  val () = eqB ("Posix.FileSys.wordToFD/inverts-fdToWord", true,
                fn () => withFile ("pfs-fd.txt", "x", fn f =>
                           withFd (f, FS.O_RDONLY, O.flags [], fn fd => FS.wordToFD (FS.fdToWord fd) = fd)))
  (* "there is no validation that the file descriptor created by wordToFD
     corresponds to an actually open file" *)
  val () = eqW ("Posix.FileSys.fdToWord/inverts-wordToFD", 0w57, fn () => FS.fdToWord (FS.wordToFD 0w57))
  val () = eqB ("Posix.FileSys.fdToWord/distinct-descriptors", true,
                fn () => withFile ("pfs-fd.txt", "x", fn f =>
                           withFd (f, FS.O_RDONLY, O.flags [], fn a =>
                             withFd (f, FS.O_RDONLY, O.flags [], fn b =>
                               FS.fdToWord a <> FS.fdToWord b andalso a <> b))))

  (* ---- fdToIOD, iodToFD ---- *)
  val () = eqB ("Posix.FileSys.iodToFD/inverts-fdToIOD", true,
                fn () => withFile ("pfs-iod.txt", "x", fn f =>
                           withFd (f, FS.O_RDONLY, O.flags [], fn fd => FS.iodToFD (FS.fdToIOD fd) = SOME fd)))
  val () = eqB ("Posix.FileSys.iodToFD/stdout", true, fn () => FS.iodToFD (FS.fdToIOD FS.stdout) = SOME FS.stdout)
  val () = eqB ("Posix.FileSys.fdToIOD/same-descriptor", true,
                fn () => withFile ("pfs-iod.txt", "x", fn f =>
                           withFd (f, FS.O_RDONLY, O.flags [], fn a =>
                             withFd (f, FS.O_RDONLY, O.flags [], fn b =>
                               OS.IO.compare (FS.fdToIOD a, FS.fdToIOD a) = EQUAL
                               andalso OS.IO.compare (FS.fdToIOD a, FS.fdToIOD b) <> EQUAL))))
  val () = eqB ("Posix.FileSys.fdToIOD/kind-of-a-file", true,
                fn () => withFile ("pfs-iod.txt", "x", fn f =>
                           withFd (f, FS.O_RDONLY, O.flags [], fn fd => OS.IO.kind (FS.fdToIOD fd) = OS.IO.Kind.file)))

  (*<< iodesc-of-stream *)
  (* The descriptor under a stream of BinIO is the file's. *)
  val () = eqB ("Posix.FileSys.iodToFD/descriptor-of-a-stream", true,
                fn () => withFile ("pfs-iod.txt", "x", fn f =>
                           let
                             val ins = BinIO.openIn f
                             val (reader, _) = BinIO.StreamIO.getReader (BinIO.getInstream ins)
                             val BinPrimIO.RD {ioDesc, close, ...} = reader
                             val result =
                               case ioDesc of
                                 SOME iod =>
                                   (case FS.iodToFD iod of
                                      SOME fd => FS.ST.ino (FS.fstat fd) = FS.ST.ino (FS.stat f)
                                                 andalso FS.ST.dev (FS.fstat fd) = FS.ST.dev (FS.stat f)
                                    | NONE => false)
                               | NONE => false
                           in close (); result end))
  (*>> iodesc-of-stream *)

  (* ---- openf and the open modes ---- *)
  (* "If the file does not exist, openf raises the OS.SysErr exception" *)
  val () = T.raises ("Posix.FileSys.openf/missing-file", isSysErr,
                     fn () => FS.openf ("pfs-no-such-file", FS.O_RDONLY, O.flags []))
  val () = eqS ("Posix.FileSys.openf/reads-the-file", "hello",
                fn () => withFile ("pfs-open.txt", "hello", fn f =>
                           withFd (f, FS.O_RDONLY, O.flags [], fn fd => readFd (fd, 100))))
  val () = eqS ("Posix.FileSys.openf/keeps-contents", "Jello",
                fn () => withFile ("pfs-open.txt", "hello", fn f =>
                           (withFd (f, FS.O_WRONLY, O.flags [], fn fd => writeFd (fd, "J")); slurp f)))
  val () = eqS ("Posix.FileSys.O_RDONLY/reads", "hel",
                fn () => withFile ("pfs-open.txt", "hello", fn f =>
                           withFd (f, FS.O_RDONLY, O.flags [], fn fd => readFd (fd, 3))))
  val () = T.raises ("Posix.FileSys.O_RDONLY/cannot-write", isSysErr,
                     fn () => withFile ("pfs-open.txt", "hello", fn f =>
                                withFd (f, FS.O_RDONLY, O.flags [], fn fd => writeFd (fd, "x"))))
  val () = eqS ("Posix.FileSys.O_WRONLY/writes", "HEllo",
                fn () => withFile ("pfs-open.txt", "hello", fn f =>
                           (withFd (f, FS.O_WRONLY, O.flags [], fn fd => writeFd (fd, "HE")); slurp f)))
  val () = T.raises ("Posix.FileSys.O_WRONLY/cannot-read", isSysErr,
                     fn () => withFile ("pfs-open.txt", "hello", fn f =>
                                withFd (f, FS.O_WRONLY, O.flags [], fn fd => readFd (fd, 3))))
  val () = eqS ("Posix.FileSys.O_RDWR/reads-and-writes", "he/heLLo",
                fn () => withFile ("pfs-open.txt", "hello", fn f =>
                           let val got = withFd (f, FS.O_RDWR, O.flags [], fn fd =>
                                                   let val s = readFd (fd, 2) in ignore (writeFd (fd, "LL")); s end)
                           in got ^ "/" ^ slurp f end))

  (* ---- the flags of O ---- *)
  (* "This causes the file to be truncated (to zero length) upon opening." *)
  val () = eqS ("Posix.FileSys.O.trunc/truncates", "",
                fn () => withFile ("pfs-flags.txt", "hello", fn f =>
                           (withFd (f, FS.O_WRONLY, O.trunc, fn _ => ()); slurp f)))
  val () = eqS ("Posix.FileSys.O.trunc/then-writes", "ab",
                fn () => withFile ("pfs-flags.txt", "hello", fn f =>
                           (withFd (f, FS.O_RDWR, O.trunc, fn fd => writeFd (fd, "ab")); slurp f)))
  (* "the file pointer is set to the end of the file prior to each write" *)
  val () = eqS ("Posix.FileSys.O.append/writes-at-end", "hello!?",
                fn () => withFile ("pfs-flags.txt", "hello", fn f =>
                           (withFd (f, FS.O_WRONLY, O.append, fn fd =>
                              (ignore (writeFd (fd, "!"));
                               ignore (Posix.IO.lseek (fd, Position.fromInt 0, Posix.IO.SEEK_SET));
                               writeFd (fd, "?")));
                            slurp f)))
  (* "This flag causes the open to fail if the file already exists." *)
  val () = T.raises ("Posix.FileSys.O.excl/existing-file", isSysErr,
                     fn () => withFile ("pfs-flags.txt", "hello", fn f =>
                                FS.createf (f, FS.O_WRONLY, O.excl, rw_r__r__)))
  val () = eqS ("Posix.FileSys.O.excl/new-file", "new",
                fn () => (remove "pfs-excl.txt";
                          let val fd = FS.createf ("pfs-excl.txt", FS.O_WRONLY, O.excl, rw_r__r__)
                          in ignore (writeFd (fd, "new")); Posix.IO.close fd; slurp "pfs-excl.txt" before remove "pfs-excl.txt" end))
  (* A regular file never becomes a controlling terminal. *)
  val () = eqS ("Posix.FileSys.O.noctty/regular-file", "hello",
                fn () => withFile ("pfs-flags.txt", "hello", fn f =>
                           withFd (f, FS.O_RDONLY, O.noctty, fn fd => readFd (fd, 10))))
  (* "On return from a function that performs a synchronous update
     (writeVec, ...), the calling process is assured that all data for the
     file has been written" *)
  val () = eqS ("Posix.FileSys.O.sync/writes", "Yello",
                fn () => withFile ("pfs-flags.txt", "hello", fn f =>
                           (withFd (f, FS.O_WRONLY, O.sync, fn fd => writeFd (fd, "Y")); slurp f)))
  val () = eqS ("Posix.FileSys.O.nonblock/regular-file", "hello",
                fn () => withFile ("pfs-flags.txt", "hello", fn f =>
                           withFd (f, FS.O_RDONLY, O.nonblock, fn fd => readFd (fd, 10))))
  val () = eqS ("Posix.FileSys.O.flags/append-and-sync", "hello!",
                fn () => withFile ("pfs-flags.txt", "hello", fn f =>
                           (withFd (f, FS.O_WRONLY, O.flags [O.append, O.sync], fn fd => writeFd (fd, "!")); slurp f)))

  (*<< fifo *)
  (* "Open, read, and write operations on the file will be nonblocking": a
     FIFO that no process writes to opens for reading at once, and one that
     no process reads from cannot be opened for writing without waiting. *)
  fun withFifo (name, f) =
    (remove name; FS.mkfifo (name, S.flags [S.irusr, S.iwusr]);
     (f name before remove name) handle e => (remove name; raise e))
  val () = eqB ("Posix.FileSys.O.nonblock/fifo-opens-at-once", true,
                fn () => withFifo ("pfs-fifo", fn f => withFd (f, FS.O_RDONLY, O.nonblock, fn _ => true)))
  val () = T.raises ("Posix.FileSys.O.nonblock/fifo-without-reader", isSysErr,
                     fn () => withFifo ("pfs-fifo", fn f => withFd (f, FS.O_WRONLY, O.nonblock, fn _ => ())))
  (*>> fifo *)

  (* ---- createf, creat, umask ---- *)
  (* "createf creates the file, setting its protection mode to m (as modified
     by the umask)" *)
  val () = eqMode ("Posix.FileSys.createf/mode-less-umask", rw_r__r__,
                   fn () => (remove "pfs-create.txt";
                             withMask (S.flags [S.iwgrp, S.iwoth], fn () =>
                               Posix.IO.close (FS.createf ("pfs-create.txt", FS.O_WRONLY, O.flags [], rw_rw_rw_)));
                             permsOf "pfs-create.txt" before remove "pfs-create.txt"))
  val () = eqMode ("Posix.FileSys.createf/mode-with-empty-umask", S.flags [S.irusr, S.iwusr, S.ixusr, S.irgrp],
                   fn () => (remove "pfs-create.txt";
                             withMask (S.flags [], fn () =>
                               Posix.IO.close (FS.createf ("pfs-create.txt", FS.O_WRONLY, O.flags [],
                                                           S.flags [S.irusr, S.iwusr, S.ixusr, S.irgrp])));
                             permsOf "pfs-create.txt" before remove "pfs-create.txt"))
  (* The descriptor is open for reading and writing: the read at the end of
     the file returns the empty vector and does not fail. *)
  val () = eqS ("Posix.FileSys.createf/open-mode", "2:|ab",
                fn () => (remove "pfs-create.txt";
                          let
                            val fd = FS.createf ("pfs-create.txt", FS.O_RDWR, O.flags [], rw_r__r__)
                            val result = (Int.toString (writeFd (fd, "ab")) ^ ":" ^ readFd (fd, 10))
                                         handle e => (Posix.IO.close fd; raise e)
                          in
                            Posix.IO.close fd;
                            (result ^ "|" ^ slurp "pfs-create.txt") before remove "pfs-create.txt"
                          end))
  (* An existing file is opened as it is: "If the file does not exist, ...
     createf creates the file". *)
  val () = eqS ("Posix.FileSys.createf/existing-file", "hello",
                fn () => withFile ("pfs-create.txt", "hello", fn f =>
                           let val fd = FS.createf (f, FS.O_RDONLY, O.flags [], rw_rw_rw_)
                           in readFd (fd, 10) before Posix.IO.close fd end))
  val () = eqMode ("Posix.FileSys.createf/existing-mode-kept", S.flags [S.irusr, S.iwusr],
                   fn () => withFile ("pfs-create.txt", "hello", fn f =>
                              (FS.chmod (f, S.flags [S.irusr, S.iwusr]);
                               Posix.IO.close (FS.createf (f, FS.O_WRONLY, O.flags [], rw_rw_rw_));
                               permsOf f)))
  val () = eqS ("Posix.FileSys.createf/with-trunc", "",
                fn () => withFile ("pfs-create.txt", "hello", fn f =>
                           (Posix.IO.close (FS.createf (f, FS.O_WRONLY, O.trunc, rw_rw_rw_)); slurp f)))
  (* "opens a file s for writing. If the file exists, this call truncates the
     file to zero length. If the file does not exist, it creates the file,
     setting its protection mode to m (as modified by the umask)." *)
  val () = eqS ("Posix.FileSys.creat/truncates", "",
                fn () => withFile ("pfs-creat.txt", "hello", fn f =>
                           (Posix.IO.close (FS.creat (f, rw_rw_rw_)); slurp f)))
  val () = eqMode ("Posix.FileSys.creat/mode-less-umask", rw_r__r__,
                   fn () => (remove "pfs-creat.txt";
                             withMask (S.flags [S.iwgrp, S.iwoth], fn () =>
                               Posix.IO.close (FS.creat ("pfs-creat.txt", rw_rw_rw_)));
                             permsOf "pfs-creat.txt" before remove "pfs-creat.txt"))
  val () = eqS ("Posix.FileSys.creat/writes", "new",
                fn () => (remove "pfs-creat.txt";
                          let val fd = FS.creat ("pfs-creat.txt", rw_r__r__)
                          in ignore (writeFd (fd, "new")); Posix.IO.close fd; slurp "pfs-creat.txt" before remove "pfs-creat.txt" end))
  val () = T.raises ("Posix.FileSys.creat/write-only", isSysErr,
                     fn () => withFile ("pfs-creat.txt", "hello", fn f =>
                                let val fd = FS.creat (f, rw_r__r__)
                                in (readFd (fd, 1) before Posix.IO.close fd) handle e => (Posix.IO.close fd; raise e) end))
  (* "sets the file mode creation mask of the process to cmask and returns the
     previous value of the mask" *)
  val () = eqMode ("Posix.FileSys.umask/returns-previous", S.flags [S.iwgrp, S.irwxo],
                   fn () => withMask (S.flags [S.iwgrp, S.irwxo], fn () => FS.umask (S.flags [S.irwxg])))
  val () = eqMode ("Posix.FileSys.umask/set-then-read", S.flags [S.irwxg],
                   fn () => let
                              val old = FS.umask (S.flags [S.irwxg])
                              val now = FS.umask old
                            in now end)
  val () = eqMode ("Posix.FileSys.umask/removes-permissions", S.flags [S.irusr],
                   fn () => (remove "pfs-mask.txt";
                             withMask (S.flags [S.iwusr, S.irwxg, S.irwxo], fn () =>
                               Posix.IO.close (FS.creat ("pfs-mask.txt", rw_rw_rw_)));
                             permsOf "pfs-mask.txt" before remove "pfs-mask.txt"))

  (* ---- the modes of S ---- *)
  val () = eqMode ("Posix.FileSys.S.irwxu/is-irusr-iwusr-ixusr", S.flags [S.irusr, S.iwusr, S.ixusr], fn () => S.irwxu)
  val () = eqMode ("Posix.FileSys.S.irwxg/is-irgrp-iwgrp-ixgrp", S.flags [S.irgrp, S.iwgrp, S.ixgrp], fn () => S.irwxg)
  val () = eqMode ("Posix.FileSys.S.irwxo/is-iroth-iwoth-ixoth", S.flags [S.iroth, S.iwoth, S.ixoth], fn () => S.irwxo)
  (* The permissions are distinct bits. *)
  val single = [("irusr", S.irusr), ("iwusr", S.iwusr), ("ixusr", S.ixusr),
                ("irgrp", S.irgrp), ("iwgrp", S.iwgrp), ("ixgrp", S.ixgrp),
                ("iroth", S.iroth), ("iwoth", S.iwoth), ("ixoth", S.ixoth),
                ("isuid", S.isuid), ("isgid", S.isgid)]
  val () = T.eq (T.list T.string) ("Posix.FileSys.S.isuid/distinct-from-the-others", [],
                fn () => List.concat (List.map (fn (n1, a) =>
                           List.mapPartial (fn (n2, b) =>
                                              if n1 <> n2 andalso S.anySet (a, b) orelse S.toWord a = 0w0
                                              then SOME (n1 ^ "," ^ n2) else NONE) single) single))
  (* chmod sets each permission alone, and stat reports it. *)
  fun chmodStat c =
    withFile ("pfs-mode.txt", "", fn f => (FS.chmod (f, c); permsOf f before FS.chmod (f, S.irwxu)))
  val () = eqMode ("Posix.FileSys.S.irusr/chmod", S.irusr, fn () => chmodStat S.irusr)
  val () = eqMode ("Posix.FileSys.S.iwusr/chmod", S.iwusr, fn () => chmodStat S.iwusr)
  val () = eqMode ("Posix.FileSys.S.ixusr/chmod", S.ixusr, fn () => chmodStat S.ixusr)
  val () = eqMode ("Posix.FileSys.S.irgrp/chmod", S.irgrp, fn () => chmodStat S.irgrp)
  val () = eqMode ("Posix.FileSys.S.iwgrp/chmod", S.iwgrp, fn () => chmodStat S.iwgrp)
  val () = eqMode ("Posix.FileSys.S.ixgrp/chmod", S.ixgrp, fn () => chmodStat S.ixgrp)
  val () = eqMode ("Posix.FileSys.S.iroth/chmod", S.iroth, fn () => chmodStat S.iroth)
  val () = eqMode ("Posix.FileSys.S.iwoth/chmod", S.iwoth, fn () => chmodStat S.iwoth)
  val () = eqMode ("Posix.FileSys.S.ixoth/chmod", S.ixoth, fn () => chmodStat S.ixoth)
  val () = eqMode ("Posix.FileSys.S.irwxu/chmod", S.irwxu, fn () => chmodStat S.irwxu)
  val () = eqMode ("Posix.FileSys.S.irwxg/chmod", S.irwxg, fn () => chmodStat S.irwxg)
  val () = eqMode ("Posix.FileSys.S.irwxo/chmod", S.irwxo, fn () => chmodStat S.irwxo)
  (* The owner may set the set-user-id bit of a file; the set-group-id bit
     only when the file's group is one of the process's. *)
  val () = eqMode ("Posix.FileSys.S.isuid/chmod", S.flags [S.isuid, S.irusr], fn () => chmodStat (S.flags [S.isuid, S.irusr]))
  val () = eqB ("Posix.FileSys.S.isgid/chmod", true,
                fn () => withFile ("pfs-mode.txt", "", fn f =>
                           let
                             val g = FS.ST.gid (FS.stat f)
                             val mine = g = Posix.ProcEnv.getegid () orelse List.exists (fn g' => g' = g) (Posix.ProcEnv.getgroups ())
                           in
                             FS.chmod (f, S.flags [S.isgid, S.irusr]);
                             (not mine orelse permsOf f = S.flags [S.isgid, S.irusr]) before FS.chmod (f, S.irwxu)
                           end))

  (*<< values *)
  (* The values of the C binding (<sys/stat.h>): S_IRWXU 0700, S_IRUSR 0400,
     S_IWUSR 0200, S_IXUSR 0100, S_IRWXG 070, ..., S_ISUID 04000, S_ISGID
     02000. *)
  val () = T.eq (T.list (fn w => "0wx" ^ SysWord.toString w)) ("Posix.FileSys.S.toWord/values-of-the-C-binding",
                [0wx1C0, 0wx100, 0wx80, 0wx40, 0wx38, 0wx20, 0wx10, 0wx8, 0wx7, 0wx4, 0wx2, 0wx1, 0wx800, 0wx400],
                fn () => List.map S.toWord [S.irwxu, S.irusr, S.iwusr, S.ixusr, S.irwxg, S.irgrp, S.iwgrp, S.ixgrp,
                                            S.irwxo, S.iroth, S.iwoth, S.ixoth, S.isuid, S.isgid])
  (*>> values *)

  (* ---- chmod, fchmod ---- *)
  (* "changes the permissions of s to mode"; the mask applies to files that
     are made, not to chmod *)
  val () = eqMode ("Posix.FileSys.chmod/sets-mode", S.flags [S.irusr, S.iwusr, S.irgrp],
                   fn () => withFile ("pfs-chmod.txt", "", fn f => (FS.chmod (f, S.flags [S.irusr, S.iwusr, S.irgrp]); permsOf f)))
  val () = eqMode ("Posix.FileSys.chmod/not-masked", rw_rw_rw_,
                   fn () => withFile ("pfs-chmod.txt", "", fn f =>
                              withMask (S.flags [S.irwxg, S.irwxo], fn () => (FS.chmod (f, rw_rw_rw_); permsOf f))))
  val () = eqMode ("Posix.FileSys.chmod/no-permissions", S.flags [],
                   fn () => withFile ("pfs-chmod.txt", "", fn f =>
                              (FS.chmod (f, S.flags []); permsOf f before FS.chmod (f, S.irwxu))))
  val () = T.raises ("Posix.FileSys.chmod/missing-file", isSysErr, fn () => FS.chmod ("pfs-no-such-file", S.irwxu))
  val () = T.raises ("Posix.FileSys.chmod/empty-path", isSysErr, fn () => FS.chmod ("", S.irwxu))
  (* "changes the permissions of the file opened as fd to mode" *)
  val () = eqMode ("Posix.FileSys.fchmod/sets-mode", S.flags [S.irusr, S.ixusr, S.iroth],
                   fn () => withFile ("pfs-chmod.txt", "", fn f =>
                              (withFd (f, FS.O_RDONLY, O.flags [], fn fd => FS.fchmod (fd, S.flags [S.irusr, S.ixusr, S.iroth]));
                               permsOf f)))
  val () = eqMode ("Posix.FileSys.fchmod/fstat-agrees", S.flags [S.irusr, S.iwusr, S.iwgrp],
                   fn () => withFile ("pfs-chmod.txt", "", fn f =>
                              withFd (f, FS.O_RDONLY, O.flags [], fn fd =>
                                (FS.fchmod (fd, S.flags [S.irusr, S.iwusr, S.iwgrp]);
                                 S.intersect [FS.ST.mode (FS.fstat fd), perms]))))

  (* ---- chown, fchown: to the owner and group the file has ---- *)
  val () = eqB ("Posix.FileSys.chown/to-current-owner", true,
                fn () => withFile ("pfs-chown.txt", "", fn f =>
                           let val st = FS.stat f
                           in
                             FS.chown (f, FS.ST.uid st, FS.ST.gid st);
                             FS.ST.uid (FS.stat f) = FS.ST.uid st andalso FS.ST.gid (FS.stat f) = FS.ST.gid st
                           end))
  val () = eqB ("Posix.FileSys.chown/owner-is-process", true,
                fn () => withFile ("pfs-chown.txt", "", fn f =>
                           (FS.chown (f, Posix.ProcEnv.geteuid (), FS.ST.gid (FS.stat f));
                            FS.ST.uid (FS.stat f) = Posix.ProcEnv.geteuid ())))
  val () = T.raises ("Posix.FileSys.chown/missing-file", isSysErr,
                     fn () => FS.chown ("pfs-no-such-file", Posix.ProcEnv.geteuid (), Posix.ProcEnv.getegid ()))
  val () = eqB ("Posix.FileSys.fchown/to-current-owner", true,
                fn () => withFile ("pfs-chown.txt", "", fn f =>
                           let val st = FS.stat f
                           in
                             withFd (f, FS.O_RDONLY, O.flags [], fn fd => FS.fchown (fd, FS.ST.uid st, FS.ST.gid st));
                             FS.ST.uid (FS.stat f) = FS.ST.uid st andalso FS.ST.gid (FS.stat f) = FS.ST.gid st
                           end))

  (* ---- access ---- *)
  (* "If l is the empty list, it checks for the existence of the file" *)
  val () = eqB ("Posix.FileSys.access/exists", true, fn () => withFile ("pfs-access.txt", "", fn f => FS.access (f, [])))
  val () = eqB ("Posix.FileSys.access/missing", false, fn () => FS.access ("pfs-no-such-file", []))
  val () = eqB ("Posix.FileSys.access/missing-read", false, fn () => FS.access ("pfs-no-such-file", [FS.A_READ]))
  fun accessWith (mode, l) =
    withFile ("pfs-access.txt", "", fn f => (FS.chmod (f, mode); FS.access (f, l) before FS.chmod (f, S.irwxu)))
  val () = eqB ("Posix.FileSys.A_READ/readable", true, fn () => accessWith (S.flags [S.irusr, S.iwusr], [FS.A_READ]))
  val () = eqB ("Posix.FileSys.A_READ/not-readable", true,
                fn () => accessWith (S.iwusr, [FS.A_READ]) = privileged ())
  val () = eqB ("Posix.FileSys.A_WRITE/writable", true, fn () => accessWith (S.flags [S.irusr, S.iwusr], [FS.A_WRITE]))
  val () = eqB ("Posix.FileSys.A_WRITE/not-writable", true,
                fn () => accessWith (S.irusr, [FS.A_WRITE]) = privileged ())
  val () = eqB ("Posix.FileSys.A_EXEC/searchable-directory", true, fn () => FS.access (".", [FS.A_EXEC]))
  val () = eqB ("Posix.FileSys.A_EXEC/not-executable", true,
                fn () => privileged () orelse not (accessWith (S.flags [S.irusr, S.iwusr], [FS.A_EXEC])))
  val () = eqB ("Posix.FileSys.access/every-mode-of-the-list", true,
                fn () => accessWith (S.flags [S.irusr, S.iwusr], [FS.A_READ, FS.A_WRITE])
                         andalso (privileged () orelse not (accessWith (S.irusr, [FS.A_READ, FS.A_WRITE]))))
  (* "A directory may be indicated as writable by access" *)
  val () = eqB ("Posix.FileSys.access/directory", true, fn () => FS.access (".", [FS.A_READ, FS.A_WRITE, FS.A_EXEC]))

  (* ---- ftruncate ---- *)
  (* "If the new length is less than the previous length, all data beyond n
     bytes is discarded. If the new length is greater than the previous
     length, the file is extended to its new length by the necessary number
     of zero bytes." *)
  fun truncated (n, contents) =
    withFile ("pfs-trunc.txt", contents, fn f =>
      (withFd (f, FS.O_WRONLY, O.flags [], fn fd => FS.ftruncate (fd, Position.fromInt n)); slurp f))
  val () = eqS ("Posix.FileSys.ftruncate/shorter", "he", fn () => truncated (2, "hello"))
  val () = eqS ("Posix.FileSys.ftruncate/longer", "hello\000\000\000", fn () => truncated (8, "hello"))
  val () = eqS ("Posix.FileSys.ftruncate/zero", "", fn () => truncated (0, "hello"))
  val () = eqS ("Posix.FileSys.ftruncate/same", "hello", fn () => truncated (5, "hello"))
  val () = eqS ("Posix.FileSys.ftruncate/size", "8",
                fn () => withFile ("pfs-trunc.txt", "hello", fn f =>
                           withFd (f, FS.O_RDWR, O.flags [], fn fd =>
                             (FS.ftruncate (fd, Position.fromInt 8); Position.toString (FS.ST.size (FS.fstat fd))))))
end

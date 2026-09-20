(* requires: Posix OS TextIO Time *)
(* Posix.FileSys (signature POSIX_FILE_SYS): stat, lstat, fstat and what ST
   reports, dev and ino, utime, pathconf and fpathconf. Expected values follow
   the text of https://smlfamily.github.io/Basis/posix-file-sys.html.

   The kinds of file are a regular file, a directory, a symbolic link and a
   FIFO made here, the read end of a pipe (a FIFO too), /dev/null (a
   character device on every POSIX system) and, in a section of its own, a
   socket. No block device can be counted on: isBlk is checked to be false
   for all of them. A new file belongs to the effective user of the process
   and to its effective group or to the group of the directory. Times are
   compared in whole seconds. *)
structure TestPosixFileSysStat =
struct
  structure FS = Posix.FileSys
  structure S = Posix.FileSys.S
  structure ST = Posix.FileSys.ST

  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqL = T.eq (T.list T.string)
  fun showMode m = "0wx" ^ SysWord.toString (S.toWord m)
  val eqMode = T.eq showMode
  val eqPos = T.eq Position.toString
  fun isSysErr e = case e of OS.SysErr _ => true | _ => false

  fun write (name, s) =
    let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
  fun remove name = FS.unlink name handle OS.SysErr _ => ()
  fun removeDir name = FS.rmdir name handle OS.SysErr _ => ()
  fun clean (files, dirs, f) =
    let fun tidy () = (List.app remove files; List.app removeDir dirs)
    in tidy (); (f () before tidy ()) handle e => (tidy (); raise e) end
  fun withFile (name, contents, f) = clean ([name], [], fn () => (write (name, contents); f name))
  fun withFd (name, f) =
    let val fd = FS.openf (name, FS.O_RDONLY, FS.O.flags [])
    in (f fd before Posix.IO.close fd) handle e => (Posix.IO.close fd; raise e) end
  fun withMask (m, f) =
    let val old = FS.umask m
    in (f () before ignore (FS.umask old)) handle e => (ignore (FS.umask old); raise e) end
  fun seconds t = Time.toSeconds t

  (* kinds st: the names of the predicates of ST that hold for st *)
  fun kinds st =
    List.map #1 (List.filter (fn (_, p) => p st)
                             [("isDir", ST.isDir), ("isChr", ST.isChr), ("isBlk", ST.isBlk), ("isReg", ST.isReg),
                              ("isFIFO", ST.isFIFO), ("isLink", ST.isLink), ("isSock", ST.isSock)])

  (* ---- the kinds of file: "These functions return true if the file
     described by the parameter is, respectively, a directory, a character
     special device, a block special device, a regular file, a FIFO, a
     symbolic link, or a socket." ---- *)
  val () = eqL ("Posix.FileSys.ST.isReg/regular-file", ["isReg"],
                fn () => withFile ("pst-file", "x", fn f => kinds (FS.stat f)))
  val () = eqL ("Posix.FileSys.ST.isDir/directory", ["isDir"],
                fn () => clean ([], ["pst-dir"], fn () => (FS.mkdir ("pst-dir", S.irwxu); kinds (FS.stat "pst-dir"))))
  val () = eqL ("Posix.FileSys.ST.isDir/current-directory", ["isDir"], fn () => kinds (FS.stat "."))
  val () = eqL ("Posix.FileSys.ST.isLink/lstat-of-a-link", ["isLink"],
                fn () => clean (["pst-file", "pst-link"], [], fn () =>
                           (write ("pst-file", "x"); FS.symlink {old = "pst-file", new = "pst-link"};
                            kinds (FS.lstat "pst-link"))))
  val () = eqL ("Posix.FileSys.ST.isLink/dangling-link", ["isLink"],
                fn () => clean (["pst-link"], [], fn () =>
                           (FS.symlink {old = "pst-no-such-file", new = "pst-link"}; kinds (FS.lstat "pst-link"))))
  val () = eqL ("Posix.FileSys.ST.isFIFO/mkfifo", ["isFIFO"],
                fn () => clean (["pst-fifo"], [], fn () =>
                           (FS.mkfifo ("pst-fifo", S.flags [S.irusr, S.iwusr]); kinds (FS.stat "pst-fifo"))))
  val () = eqL ("Posix.FileSys.ST.isFIFO/pipe", ["isFIFO"],
                fn () => let val {infd, outfd} = Posix.IO.pipe ()
                         in (kinds (FS.fstat infd) before (Posix.IO.close infd; Posix.IO.close outfd))
                            handle e => (Posix.IO.close infd; Posix.IO.close outfd; raise e)
                         end)
  val () = eqL ("Posix.FileSys.ST.isChr/dev-null", ["isChr"], fn () => kinds (FS.stat "/dev/null"))
  val () = eqL ("Posix.FileSys.ST.isBlk/none-of-the-others", [],
                fn () => clean (["pst-file", "pst-fifo"], ["pst-dir"], fn () =>
                           (write ("pst-file", ""); FS.mkdir ("pst-dir", S.irwxu);
                            FS.mkfifo ("pst-fifo", S.irwxu);
                            List.map #1 (List.filter (fn (_, st) => ST.isBlk st)
                                                     [("file", FS.stat "pst-file"), ("dir", FS.stat "pst-dir"),
                                                      ("fifo", FS.stat "pst-fifo"), ("null", FS.stat "/dev/null"),
                                                      ("dot", FS.lstat ".")]))))
  val () = eqL ("Posix.FileSys.ST.isSock/none-of-the-others", [],
                fn () => clean (["pst-file", "pst-fifo"], ["pst-dir"], fn () =>
                           (write ("pst-file", ""); FS.mkdir ("pst-dir", S.irwxu);
                            FS.mkfifo ("pst-fifo", S.irwxu);
                            List.map #1 (List.filter (fn (_, st) => ST.isSock st)
                                                     [("file", FS.stat "pst-file"), ("dir", FS.stat "pst-dir"),
                                                      ("fifo", FS.stat "pst-fifo"), ("null", FS.stat "/dev/null")]))))

  (*<< socket *)
  (* A socket of the Unix domain, by its descriptor. *)
  val () = eqL ("Posix.FileSys.ST.isSock/socket", ["isSock"],
                fn () => let
                           val sock : Socket.passive UnixSock.stream_sock = UnixSock.Strm.socket ()
                         in
                           (case FS.iodToFD (Socket.ioDesc sock) of
                              SOME fd => kinds (FS.fstat fd)
                            | NONE => ["no descriptor"]) before Socket.close sock
                         end)
  (*>> socket *)

  (* ---- stat, lstat, fstat ---- *)
  (* "Note that an empty string causes an exception." *)
  val () = T.raises ("Posix.FileSys.stat/empty-string", isSysErr, fn () => FS.stat "")
  val () = T.raises ("Posix.FileSys.lstat/empty-string", isSysErr, fn () => FS.lstat "")
  val () = T.raises ("Posix.FileSys.stat/missing", isSysErr, fn () => FS.stat "pst-no-such-file")
  val () = T.raises ("Posix.FileSys.lstat/missing", isSysErr, fn () => FS.lstat "pst-no-such-file")
  (* "lstat differs from stat in that, if the pathname argument is a symbolic
     link, the information concerns the link itself, not the file to which the
     link points" *)
  val () = eqL ("Posix.FileSys.stat/follows-a-link", ["isReg"],
                fn () => clean (["pst-file", "pst-link"], [], fn () =>
                           (write ("pst-file", "x"); FS.symlink {old = "pst-file", new = "pst-link"};
                            kinds (FS.stat "pst-link"))))
  val () = T.raises ("Posix.FileSys.stat/dangling-link", isSysErr,
                     fn () => clean (["pst-link"], [], fn () =>
                                (FS.symlink {old = "pst-no-such-file", new = "pst-link"}; FS.stat "pst-link")))
  val () = eqL ("Posix.FileSys.lstat/regular-file", ["isReg"],
                fn () => withFile ("pst-file", "x", fn f => kinds (FS.lstat f)))
  val () = eqB ("Posix.FileSys.lstat/the-link-itself", true,
                fn () => clean (["pst-file", "pst-link"], [], fn () =>
                           (write ("pst-file", "some contents"); FS.symlink {old = "pst-file", new = "pst-link"};
                            FS.ST.ino (FS.lstat "pst-link") <> FS.ST.ino (FS.stat "pst-link")
                            andalso FS.ST.ino (FS.stat "pst-link") = FS.ST.ino (FS.stat "pst-file"))))
  (* "For fstat, an open file descriptor is supplied." *)
  val () = eqB ("Posix.FileSys.fstat/same-file", true,
                fn () => withFile ("pst-file", "hello", fn f =>
                           withFd (f, fn fd => FS.ST.ino (FS.fstat fd) = FS.ST.ino (FS.stat f)
                                               andalso FS.ST.dev (FS.fstat fd) = FS.ST.dev (FS.stat f)
                                               andalso FS.ST.size (FS.fstat fd) = FS.ST.size (FS.stat f))))
  val () = eqL ("Posix.FileSys.fstat/kind", ["isReg"], fn () => withFile ("pst-file", "hello", fn f => withFd (f, kinds o FS.fstat)))
  val () = eqL ("Posix.FileSys.fstat/directory", ["isDir"], fn () => withFd (".", kinds o FS.fstat))

  (* ---- the fields of ST ---- *)
  (* "returns the protection mode of the file" *)
  val () = eqMode ("Posix.FileSys.ST.mode/regular-file", S.flags [S.irusr, S.iwusr, S.irgrp],
                   fn () => withFile ("pst-file", "", fn f => (FS.chmod (f, S.flags [S.irusr, S.iwusr, S.irgrp]);
                                                               ST.mode (FS.stat f))))
  val () = eqMode ("Posix.FileSys.ST.mode/directory", S.flags [S.irwxu, S.irgrp, S.ixgrp],
                   fn () => clean ([], ["pst-dir"], fn () =>
                              (FS.mkdir ("pst-dir", S.irwxu); FS.chmod ("pst-dir", S.flags [S.irwxu, S.irgrp, S.ixgrp]);
                               ST.mode (FS.stat "pst-dir"))))
  val () = eqMode ("Posix.FileSys.ST.mode/fifo", S.flags [S.irusr, S.iwusr],
                   fn () => clean (["pst-fifo"], [], fn () =>
                              (FS.mkfifo ("pst-fifo", S.flags [S.irusr, S.iwusr]); FS.chmod ("pst-fifo", S.flags [S.irusr, S.iwusr]);
                               ST.mode (FS.stat "pst-fifo"))))
  (* "The device identifier and the file serial number (inode or ino)
     uniquely identify a file." *)
  val () = eqB ("Posix.FileSys.ST.ino/distinct-files", true,
                fn () => clean (["pst-a", "pst-b"], [], fn () =>
                           (write ("pst-a", ""); write ("pst-b", "");
                            FS.ST.ino (FS.stat "pst-a") <> FS.ST.ino (FS.stat "pst-b"))))
  val () = eqB ("Posix.FileSys.ST.ino/same-file", true,
                fn () => withFile ("pst-file", "", fn f => FS.ST.ino (FS.stat f) = FS.ST.ino (FS.stat ("./" ^ f))))
  val () = eqB ("Posix.FileSys.ST.dev/same-directory", true,
                fn () => clean (["pst-a"], [], fn () => (write ("pst-a", ""); FS.ST.dev (FS.stat "pst-a") = FS.ST.dev (FS.stat "."))))
  (* "returns the number of hard links to the file" *)
  val () = T.eq T.int ("Posix.FileSys.ST.nlink/new-file", 1, fn () => withFile ("pst-file", "", fn f => ST.nlink (FS.stat f)))
  val () = T.eq T.int ("Posix.FileSys.ST.nlink/three-links", 3,
                       fn () => clean (["pst-a", "pst-b", "pst-c"], [], fn () =>
                                  (write ("pst-a", ""); FS.link {old = "pst-a", new = "pst-b"};
                                   FS.link {old = "pst-b", new = "pst-c"}; ST.nlink (FS.stat "pst-c"))))
  (* "These return the owner and group ID of the file." *)
  val () = eqB ("Posix.FileSys.ST.uid/new-file", true,
                fn () => withFile ("pst-file", "", fn f => ST.uid (FS.stat f) = Posix.ProcEnv.geteuid ()))
  val () = eqB ("Posix.FileSys.ST.gid/new-file", true,
                fn () => withFile ("pst-file", "", fn f =>
                           let val g = ST.gid (FS.stat f)
                           in g = Posix.ProcEnv.getegid () orelse g = ST.gid (FS.stat ".") end))
  (* "returns the size (number of bytes) of the file" *)
  val () = eqPos ("Posix.FileSys.ST.size/bytes", Position.fromInt 11,
                  fn () => withFile ("pst-file", "hello\nworld", fn f => ST.size (FS.stat f)))
  val () = eqPos ("Posix.FileSys.ST.size/empty", Position.fromInt 0, fn () => withFile ("pst-file", "", fn f => ST.size (FS.stat f)))
  val () = eqPos ("Posix.FileSys.ST.size/lstat-of-a-link-is-its-text", Position.fromInt 8,
                  fn () => clean (["pst-link"], [], fn () =>
                             (FS.symlink {old = "12345678", new = "pst-link"}; ST.size (FS.lstat "pst-link"))))

  (* ---- the times, utime ---- *)
  (* "sets the access and modification times of the file f to actime and
     modtime, respectively" *)
  (* The seconds as LargeInt.int values: a host that compiles lib/basis (xc1)
     cannot type an int constant at the LargeInt of lib/basis, and
     1100000000 does not fit a 31-bit int. *)
  val actimeSeconds = LargeInt.fromInt 1000000000
  val modtimeSeconds = valOf (LargeInt.fromString "1100000000")
  fun setTimes f =
    FS.utime (f, SOME {actime = Time.fromSeconds actimeSeconds, modtime = Time.fromSeconds modtimeSeconds})
  val () = T.eq LargeInt.toString ("Posix.FileSys.ST.atime/utime", actimeSeconds,
                                   fn () => withFile ("pst-file", "x", fn f => (setTimes f; seconds (ST.atime (FS.stat f)))))
  val () = T.eq LargeInt.toString ("Posix.FileSys.ST.mtime/utime", modtimeSeconds,
                                   fn () => withFile ("pst-file", "x", fn f => (setTimes f; seconds (ST.mtime (FS.stat f)))))
  val () = T.eq LargeInt.toString ("Posix.FileSys.utime/actime", actimeSeconds,
                                   fn () => withFile ("pst-file", "x", fn f => (setTimes f; seconds (ST.atime (FS.stat f)))))
  val () = T.eq LargeInt.toString ("Posix.FileSys.utime/modtime", modtimeSeconds,
                                   fn () => withFile ("pst-file", "x", fn f => (setTimes f; seconds (ST.mtime (FS.stat f)))))
  val () = eqB ("Posix.FileSys.utime/fstat-agrees", true,
                fn () => withFile ("pst-file", "x", fn f =>
                           (setTimes f;
                            withFd (f, fn fd => seconds (ST.mtime (FS.fstat fd)) = modtimeSeconds
                                                andalso seconds (ST.atime (FS.fstat fd)) = actimeSeconds))))
  (* The status of the file changes now, after the times it is given. *)
  val () = eqB ("Posix.FileSys.ST.ctime/after-utime", true,
                fn () => withFile ("pst-file", "x", fn f =>
                           let val start = seconds (Time.now ())
                           in setTimes f; LargeInt.>= (seconds (ST.ctime (FS.stat f)), LargeInt.- (start, LargeInt.fromInt 2)) end))
  (* "sets the access and modification times of a file to the current time" *)
  fun nowAround f =
    let
      val start = seconds (Time.now ())
      val t = f ()
      val stop = seconds (Time.now ())
      val two = LargeInt.fromInt 2
    in LargeInt.<= (LargeInt.- (start, two), t) andalso LargeInt.<= (t, LargeInt.+ (stop, two)) end
  val () = eqB ("Posix.FileSys.utime/NONE-sets-mtime-to-now", true,
                fn () => withFile ("pst-file", "x", fn f =>
                           (setTimes f; nowAround (fn () => (FS.utime (f, NONE); seconds (ST.mtime (FS.stat f)))))))
  val () = eqB ("Posix.FileSys.utime/NONE-sets-atime-to-now", true,
                fn () => withFile ("pst-file", "x", fn f =>
                           (setTimes f; nowAround (fn () => (FS.utime (f, NONE); seconds (ST.atime (FS.stat f)))))))
  val () = eqB ("Posix.FileSys.ST.mtime/new-file", true,
                fn () => nowAround (fn () => withFile ("pst-file", "x", fn f => seconds (ST.mtime (FS.stat f)))))
  val () = T.raises ("Posix.FileSys.utime/missing", isSysErr, fn () => FS.utime ("pst-no-such-file", NONE))

  (* ---- dev, ino ---- *)
  (* "These functions convert between dev values and words by which the
     operating system identifies a device." *)
  val () = eqB ("Posix.FileSys.devToWord/inverts-wordToDev", true,
                fn () => FS.devToWord (FS.wordToDev 0w12345) = 0w12345)
  val () = eqB ("Posix.FileSys.wordToDev/inverts-devToWord", true,
                fn () => let val d = ST.dev (FS.stat ".") in FS.wordToDev (FS.devToWord d) = d end)
  val () = eqB ("Posix.FileSys.inoToWord/inverts-wordToIno", true,
                fn () => FS.inoToWord (FS.wordToIno 0w67890) = 0w67890)
  val () = eqB ("Posix.FileSys.wordToIno/inverts-inoToWord", true,
                fn () => let val i = ST.ino (FS.stat ".") in FS.wordToIno (FS.inoToWord i) = i end)
  val () = eqB ("Posix.FileSys.inoToWord/distinct-files", true,
                fn () => clean (["pst-a", "pst-b"], [], fn () =>
                           (write ("pst-a", ""); write ("pst-b", "");
                            FS.inoToWord (ST.ino (FS.stat "pst-a")) <> FS.inoToWord (ST.ino (FS.stat "pst-b")))))
  val () = eqB ("Posix.FileSys.devToWord/same-device", true,
                fn () => clean (["pst-a"], [], fn () =>
                           (write ("pst-a", ""); FS.devToWord (ST.dev (FS.stat "pst-a")) = FS.devToWord (ST.dev (FS.stat ".")))))

  (*<< pathconf *)
  (* "For integer-valued properties, if the value is unbounded, NONE is
     returned. If the value is bounded, SOME(v) is returned ... For
     boolean-value properties, if the value is true, SOME(1) is returned;
     otherwise, SOME(0) or NONE is returned. The OS.SysErr exception is raised
     if something goes wrong, including when p is not a valid property" *)
  fun isBool (r : SysWord.word option) = r = NONE orelse r = SOME 0w0 orelse r = SOME 0w1
  (* NAME_MAX "may be as small as 13, but is never larger than 255" *)
  val () = eqB ("Posix.FileSys.pathconf/NAME_MAX", true,
                fn () => case FS.pathconf (".", "NAME_MAX") of
                           SOME v => 0w13 <= v andalso v <= 0w255
                         | NONE => false)
  (* PATH_MAX "is never larger than 65,535" *)
  val () = eqB ("Posix.FileSys.pathconf/PATH_MAX", true,
                fn () => case FS.pathconf (".", "PATH_MAX") of
                           SOME v => 0w1 <= v andalso v <= 0w65535
                         | NONE => true)
  val () = eqB ("Posix.FileSys.pathconf/LINK_MAX", true,
                fn () => case FS.pathconf (".", "LINK_MAX") of
                           SOME v => 0w1 <= v
                         | NONE => true)
  val () = eqB ("Posix.FileSys.pathconf/boolean-properties", true,
                fn () => List.all (fn p => isBool (FS.pathconf (".", p)))
                                  ["CHOWN_RESTRICTED", "NO_TRUNC"])
  val () = T.raises ("Posix.FileSys.pathconf/not-a-property", isSysErr,
                     fn () => FS.pathconf (".", "RUNE_NO_SUCH_PROPERTY"))
  val () = T.raises ("Posix.FileSys.pathconf/missing-file", isSysErr,
                     fn () => FS.pathconf ("pst-no-such-file", "NAME_MAX"))
  val () = eqB ("Posix.FileSys.fpathconf/NAME_MAX-of-the-directory", true,
                fn () => withFd (".", fn fd => FS.fpathconf (fd, "NAME_MAX") = FS.pathconf (".", "NAME_MAX")))
  (* PIPE_BUF "Maximum number of bytes guaranteed to be written atomically.
     This is applicable only to a FIFO." *)
  val () = eqB ("Posix.FileSys.fpathconf/PIPE_BUF-of-a-pipe", true,
                fn () => let val {infd, outfd} = Posix.IO.pipe ()
                         in (case FS.fpathconf (outfd, "PIPE_BUF") of
                               SOME v => v >= 0w1
                             | NONE => true) before (Posix.IO.close infd; Posix.IO.close outfd)
                         end)
  val () = eqB ("Posix.FileSys.fpathconf/boolean-property", true,
                fn () => withFd (".", fn fd => isBool (FS.fpathconf (fd, "NO_TRUNC"))))
  val () = T.raises ("Posix.FileSys.fpathconf/not-a-property", isSysErr,
                     fn () => withFd (".", fn fd => FS.fpathconf (fd, "RUNE_NO_SUCH_PROPERTY")))
  (*>> pathconf *)
end

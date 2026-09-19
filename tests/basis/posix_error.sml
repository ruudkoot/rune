(* requires: Posix OS TextIO *)
(* uses: fn/posix_child.sml *)
(* Posix.Error (signature POSIX_ERROR). Expected values follow the text of
   https://smlfamily.github.io/Basis/posix-error.html: "The string
   representation of a syserror value, as returned by errorName, is the name
   of the error. Thus, errorName badmsg = "badmsg"", and "SOME(e) =
   syserror(errorName e)". Which error a failing call reports is POSIX's
   (the page: "The name of a corresponding POSIX error can be derived by
   capitalizing all letters and adding the character E as a prefix");
   the failures provoked here have one cause that POSIX names. *)
structure TestPosixError =
struct
  structure E = Posix.Error
  structure C = PosixChild
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val showW = fn w => "0wx" ^ SysWord.toString w

  (* named (label, name, e): the checks that hold for every named error:
     errorName gives its name, syserror its value, and toWord a non-zero
     word that fromWord turns back into it. *)
  fun named (label, name, e) =
    (eqS (label ^ "errorName", name, fn () => E.errorName e);
     eqB (label ^ "syserror", true, fn () => E.syserror name = SOME e);
     eqB (label ^ "toWord-fromWord", true, fn () => E.toWord e <> 0w0 andalso E.fromWord (E.toWord e) = e))

  val () = named ("Posix.Error.acces/", "acces", E.acces)
  val () = named ("Posix.Error.again/", "again", E.again)
  val () = named ("Posix.Error.badf/", "badf", E.badf)
  val () = named ("Posix.Error.badmsg/", "badmsg", E.badmsg)
  val () = named ("Posix.Error.busy/", "busy", E.busy)
  val () = named ("Posix.Error.canceled/", "canceled", E.canceled)
  val () = named ("Posix.Error.child/", "child", E.child)
  val () = named ("Posix.Error.deadlk/", "deadlk", E.deadlk)
  val () = named ("Posix.Error.dom/", "dom", E.dom)
  val () = named ("Posix.Error.exist/", "exist", E.exist)
  val () = named ("Posix.Error.fault/", "fault", E.fault)
  val () = named ("Posix.Error.fbig/", "fbig", E.fbig)
  val () = named ("Posix.Error.inprogress/", "inprogress", E.inprogress)
  val () = named ("Posix.Error.intr/", "intr", E.intr)
  val () = named ("Posix.Error.inval/", "inval", E.inval)
  val () = named ("Posix.Error.io/", "io", E.io)
  val () = named ("Posix.Error.isdir/", "isdir", E.isdir)
  val () = named ("Posix.Error.loop/", "loop", E.loop)
  val () = named ("Posix.Error.mfile/", "mfile", E.mfile)
  val () = named ("Posix.Error.mlink/", "mlink", E.mlink)
  val () = named ("Posix.Error.msgsize/", "msgsize", E.msgsize)
  val () = named ("Posix.Error.nametoolong/", "nametoolong", E.nametoolong)
  val () = named ("Posix.Error.nfile/", "nfile", E.nfile)
  val () = named ("Posix.Error.nodev/", "nodev", E.nodev)
  val () = named ("Posix.Error.noent/", "noent", E.noent)
  val () = named ("Posix.Error.noexec/", "noexec", E.noexec)
  val () = named ("Posix.Error.nolck/", "nolck", E.nolck)
  val () = named ("Posix.Error.nomem/", "nomem", E.nomem)
  val () = named ("Posix.Error.nospc/", "nospc", E.nospc)
  val () = named ("Posix.Error.nosys/", "nosys", E.nosys)
  val () = named ("Posix.Error.notdir/", "notdir", E.notdir)
  val () = named ("Posix.Error.notempty/", "notempty", E.notempty)
  val () = named ("Posix.Error.notsup/", "notsup", E.notsup)
  val () = named ("Posix.Error.notty/", "notty", E.notty)
  val () = named ("Posix.Error.nxio/", "nxio", E.nxio)
  val () = named ("Posix.Error.perm/", "perm", E.perm)
  val () = named ("Posix.Error.pipe/", "pipe", E.pipe)
  val () = named ("Posix.Error.range/", "range", E.range)
  val () = named ("Posix.Error.rofs/", "rofs", E.rofs)
  val () = named ("Posix.Error.spipe/", "spipe", E.spipe)
  val () = named ("Posix.Error.srch/", "srch", E.srch)
  val () = named ("Posix.Error.toobig/", "toobig", E.toobig)
  val () = named ("Posix.Error.xdev/", "xdev", E.xdev)

  val all =
    [E.acces, E.again, E.badf, E.badmsg, E.busy, E.canceled, E.child, E.deadlk, E.dom, E.exist,
     E.fault, E.fbig, E.inprogress, E.intr, E.inval, E.io, E.isdir, E.loop, E.mfile, E.mlink,
     E.msgsize, E.nametoolong, E.nfile, E.nodev, E.noent, E.noexec, E.nolck, E.nomem, E.nospc,
     E.nosys, E.notdir, E.notempty, E.notsup, E.notty, E.nxio, E.perm, E.pipe, E.range, E.rofs,
     E.spipe, E.srch, E.toobig, E.xdev]
  fun distinct [] = true
    | distinct (x :: r) = not (List.exists (fn y => y = x) r) andalso distinct r

  (* errorName "returns a unique name used for the syserror value", and the
     names of the 43 errors differ: so do the errors. *)
  val () = eqB ("Posix.Error.errorName/distinct-errors", true, fn () => distinct all)
  val () = eqB ("Posix.Error.errorName/distinct-names", true, fn () => distinct (List.map E.errorName all))
  val () = eqB ("Posix.Error.toWord/distinct-words", true, fn () => distinct (List.map E.toWord all))
  val () = eqB ("Posix.Error.syserror/inverts-errorName-all", true,
                fn () => List.all (fn e => E.syserror (E.errorName e) = SOME e) all)
  val () = T.eq (T.option T.string) ("Posix.Error.syserror/unknown-name", NONE,
                                     fn () => Option.map E.errorName (E.syserror "no such error name"))
  val () = T.eq (T.option T.string) ("Posix.Error.syserror/empty-name", NONE,
                                     fn () => Option.map E.errorName (E.syserror ""))
  (* The name is the lower case one: "Thus, errorName badmsg = "badmsg"". *)
  val () = eqS ("Posix.Error.errorName/badmsg", "badmsg", fn () => E.errorName E.badmsg)
  val () = eqS ("Posix.Error.errorName/toobig-not-2big", "toobig", fn () => E.errorName E.toobig)

  (* "there is no validation that a syserror value generated using fromWord
     corresponds to an error value supported by the underlying system" *)
  val () = T.eq showW ("Posix.Error.fromWord/no-validation", 0w4000,
                       fn () => E.toWord (E.fromWord 0w4000))
  val () = eqB ("Posix.Error.fromWord/of-toWord", true,
                fn () => List.all (fn e => E.fromWord (E.toWord e) = e) all)
  val () = eqB ("Posix.Error.toWord/nonzero", true, fn () => List.all (fn e => E.toWord e <> 0w0) all)

  (* "This is identical to the type OS.syserror": the same values, names and
     messages. *)
  val () = eqB ("Posix.Error.errorMsg/is-OS.errorMsg", true,
                fn () => List.all (fn e => E.errorMsg e = OS.errorMsg e) all)
  val () = eqB ("Posix.Error.errorMsg/nonempty", true,
                fn () => List.all (fn e => size (E.errorMsg e) > 0) all)
  val () = eqB ("Posix.Error.errorMsg/differ", true,
                fn () => E.errorMsg E.noent <> E.errorMsg E.acces)
  val () = eqB ("Posix.Error.syserror/is-OS.syserror", true,
                fn () => OS.syserror (OS.errorName E.noent) = SOME E.noent)

  (* ---- errors that failing calls report ---- *)
  (* The syserror of the SysErr that f raises, directly or as the cause of
     an Io. *)
  fun errorOf (f : unit -> unit) : E.syserror option =
    (f (); NONE)
    handle OS.SysErr (_, e) => e
         | IO.Io {cause = OS.SysErr (_, e), ...} => e
  fun reports (label, expected, f) =
    T.eq (T.option E.errorName) (label, SOME expected, fn () => errorOf f)

  (* A SysErr (s, SOME e) carries errorMsg e. *)
  val () = eqB ("Posix.Error.errorMsg/of-SysErr", true,
                fn () => (TextIO.closeIn (TextIO.openIn "no-such-file.txt"); false)
                         handle IO.Io {cause = OS.SysErr (s, SOME e), ...} => E.errorMsg e = s)

  val () = reports ("Posix.Error.noent/open-missing-file", E.noent,
                    fn () => TextIO.closeIn (TextIO.openIn "no-such-file.txt"))
  val () = reports ("Posix.Error.notdir/path-through-file", E.notdir,
                    fn () => (C.write ("plain.txt", "x"); TextIO.closeIn (TextIO.openIn "plain.txt/x")))
  val () = reports ("Posix.Error.exist/mkDir-twice", E.exist,
                    fn () => (OS.FileSys.mkDir "err-dir"; OS.FileSys.mkDir "err-dir"))
  val () = reports ("Posix.Error.isdir/open-directory-for-writing", E.isdir,
                    fn () => TextIO.closeOut (TextIO.openOut "err-dir"))
  (* rmdir of a directory with entries: POSIX allows EEXIST or ENOTEMPTY. *)
  val () = eqB ("Posix.Error.notempty/rmDir-nonempty", true,
                fn () => (C.write ("err-dir/f.txt", "x");
                          case errorOf (fn () => OS.FileSys.rmDir "err-dir") of
                            SOME e => e = E.notempty orelse e = E.exist
                          | NONE => false))
  (* rename of a directory into itself is EINVAL. *)
  val () = reports ("Posix.Error.inval/rename-into-itself", E.inval,
                    fn () => OS.FileSys.rename {old = "err-dir", new = "err-dir/sub"})
  val () = reports ("Posix.Error.nametoolong/long-file-name", E.nametoolong,
                    fn () => TextIO.closeIn (TextIO.openIn (CharVector.tabulate (1000, fn _ => #"n"))))
  val () = reports ("Posix.Error.child/wait-without-children", E.child,
                    fn () => ignore (Posix.Process.wait ()))
  val () = reports ("Posix.Error.notty/ttyname-of-dev-null", E.notty,
                    fn () => ignore (Posix.ProcEnv.ttyname (Posix.FileSys.wordToFD 0w0)))

  (*<< io *)
  (* Closing a descriptor twice; seeking on a pipe. *)
  val () = reports ("Posix.Error.badf/close-twice", E.badf,
                    fn () => let val {infd, outfd} = Posix.IO.pipe ()
                             in Posix.IO.close outfd; Posix.IO.close infd; Posix.IO.close infd end)
  val () = reports ("Posix.Error.spipe/lseek-on-pipe", E.spipe,
                    fn () => let val {infd, outfd} = Posix.IO.pipe ()
                             in
                               (ignore (Posix.IO.lseek (infd, 0, Posix.IO.SEEK_SET)))
                               handle e => (Posix.IO.close infd; Posix.IO.close outfd; raise e)
                             end)
  (*>> io *)

  (*<< loop *)
  val () = reports ("Posix.Error.loop/symbolic-link-loop", E.loop,
                    fn () => (Posix.FileSys.symlink {old = "loop-a", new = "loop-b"};
                              Posix.FileSys.symlink {old = "loop-b", new = "loop-a"};
                              TextIO.closeIn (TextIO.openIn "loop-a")))
  (*>> loop *)

  (*<< privileges *)
  (* Permissions do not stop the superuser: these hold for other users. *)
  val root = Posix.ProcEnv.getuid () = Posix.ProcEnv.wordToUid 0w0
  val () = eqB ("Posix.Error.acces/open-unreadable-file", true,
                fn () => root orelse
                         (TextIO.closeOut (TextIO.openOut "unreadable.txt");
                          Posix.FileSys.chmod ("unreadable.txt", Posix.FileSys.S.flags []);
                          errorOf (fn () => TextIO.closeIn (TextIO.openIn "unreadable.txt")) = SOME E.acces))
  val () = eqB ("Posix.Error.perm/setuid-root", true,
                fn () => root orelse
                         errorOf (fn () => Posix.ProcEnv.setuid (Posix.ProcEnv.wordToUid 0w0)) = SOME E.perm)
  (*>> privileges *)

  (*<< process *)
  (* Signalling a child that has ended and been waited for. *)
  val () = reports ("Posix.Error.srch/kill-reaped-child", E.srch,
                    fn () => let val pid = C.spawn (fn () => C.w8 0)
                             in ignore (C.status pid);
                                Posix.Process.kill (Posix.Process.K_PROC pid, Posix.Signal.term)
                             end)
  (* A child that executes something that is not a program, and one with an
     argument longer than the system takes, report the error with their
     status. *)
  fun execError (expected, run) =
    C.run (fn () => (run (); C.w8 1) handle OS.SysErr (_, SOME e) => if e = expected then C.w8 3 else C.w8 4)
  val () = T.eq C.showStatus ("Posix.Error.noexec/exec-of-data", Posix.Process.W_EXITSTATUS (C.w8 3),
                              fn () => (C.write ("not-a-program", "\000\001\002 not a program\n");
                                        Posix.FileSys.chmod ("not-a-program", Posix.FileSys.S.irwxu);
                                        execError (E.noexec, fn () => Posix.Process.exec ("./not-a-program", ["not-a-program"]))))
  val () = T.eq C.showStatus ("Posix.Error.toobig/exec-huge-argument", Posix.Process.W_EXITSTATUS (C.w8 3),
                              fn () => let val huge = CharVector.tabulate (4194304, fn _ => #"x")
                                       in execError (E.toobig, fn () => Posix.Process.exec ("/bin/sh", ["sh", huge])) end)
  (* A write on a pipe that nobody reads ends the writer with Signal.pipe
     or, if that signal is ignored or caught, fails with pipe. *)
  val () = eqB ("Posix.Error.pipe/write-without-reader", true,
                fn () => case C.run (fn () =>
                                       let val {infd, outfd} = Posix.IO.pipe ()
                                       in
                                         Posix.IO.close infd;
                                         (ignore (Posix.IO.writeVec (outfd, Word8VectorSlice.full (Byte.stringToBytes "x"))); C.w8 1)
                                         handle OS.SysErr (_, SOME e) => if e = E.pipe then C.w8 3 else C.w8 4
                                       end) of
                           Posix.Process.W_EXITSTATUS w => w = C.w8 3
                         | Posix.Process.W_SIGNALED s => s = Posix.Signal.pipe
                         | _ => false)
  (*>> process *)

  val () = (List.app (fn f => OS.FileSys.remove f handle _ => ())
                     ["plain.txt", "err-dir/f.txt", "loop-a", "loop-b", "unreadable.txt", "not-a-program",
                      "posix-shell-out.txt"];
            OS.FileSys.rmDir "err-dir" handle _ => ())
end

(* requires: Posix OS TextIO *)
(* Posix.FileSys (signature POSIX_FILE_SYS): names and directories: link,
   symlink, readlink, unlink, rename, mkdir, rmdir, mkfifo, opendir, readdir,
   rewinddir, closedir, chdir and getcwd. Expected values follow the text of
   https://smlfamily.github.io/Basis/posix-file-sys.html. Everything is made
   in the current directory and removed again; a check that changes the
   working directory changes it back. *)
structure TestPosixFileSysDir =
struct
  structure FS = Posix.FileSys
  structure S = Posix.FileSys.S

  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqL = T.eq (T.list T.string)
  fun showMode m = "0wx" ^ SysWord.toString (S.toWord m)
  val eqMode = T.eq showMode
  fun isSysErr e = case e of OS.SysErr _ => true | _ => false

  fun write (name, s) =
    let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
  fun slurp name =
    let val ins = TextIO.openIn name val s = TextIO.inputAll ins in TextIO.closeIn ins; s end
  fun exists name = (ignore (FS.lstat name); true) handle OS.SysErr _ => false
  fun remove name = FS.unlink name handle OS.SysErr _ => ()
  fun removeDir name = FS.rmdir name handle OS.SysErr _ => ()
  (* clean (files, dirs, f): f (), and the files and then the directories
     removed afterwards *)
  fun clean (files, dirs, f) =
    let fun tidy () = (List.app remove files; List.app removeDir dirs)
    in tidy (); (f () before tidy ()) handle e => (tidy (); raise e) end
  fun withMask (m, f) =
    let val old = FS.umask m
    in (f () before ignore (FS.umask old)) handle e => (ignore (FS.umask old); raise e) end
  val perms = S.flags [S.irwxu, S.irwxg, S.irwxo, S.isuid, S.isgid]
  fun permsOf name = S.intersect [FS.ST.mode (FS.stat name), perms]
  (* the names of a directory stream until readdir returns NONE, sorted *)
  fun insert (x : string, []) = [x]
    | insert (x, y :: ys) = if x <= y then x :: y :: ys else y :: insert (x, ys)
  fun names d = case FS.readdir d of NONE => [] | SOME n => n :: names d
  fun sorted d = List.foldl insert [] (names d)

  (* ---- link ---- *)
  (* "creates an additional hard link (directory entry) for an existing file.
     Both the old and the new link share equal access rights to the
     underlying object." *)
  val () = eqS ("Posix.FileSys.link/same-contents", "hello",
                fn () => clean (["pfd-link-a", "pfd-link-b"], [], fn () =>
                           (write ("pfd-link-a", "hello"); FS.link {old = "pfd-link-a", new = "pfd-link-b"};
                            slurp "pfd-link-b")))
  val () = eqS ("Posix.FileSys.link/shared-file", "changed",
                fn () => clean (["pfd-link-a", "pfd-link-b"], [], fn () =>
                           (write ("pfd-link-a", "hello"); FS.link {old = "pfd-link-a", new = "pfd-link-b"};
                            write ("pfd-link-b", "changed"); slurp "pfd-link-a")))
  val () = eqB ("Posix.FileSys.link/same-inode", true,
                fn () => clean (["pfd-link-a", "pfd-link-b"], [], fn () =>
                           (write ("pfd-link-a", "hello"); FS.link {old = "pfd-link-a", new = "pfd-link-b"};
                            FS.ST.ino (FS.stat "pfd-link-a") = FS.ST.ino (FS.stat "pfd-link-b")
                            andalso FS.ST.dev (FS.stat "pfd-link-a") = FS.ST.dev (FS.stat "pfd-link-b"))))
  val () = T.eq T.int ("Posix.FileSys.link/link-count", 2,
                       fn () => clean (["pfd-link-a", "pfd-link-b"], [], fn () =>
                                  (write ("pfd-link-a", "hello"); FS.link {old = "pfd-link-a", new = "pfd-link-b"};
                                   FS.ST.nlink (FS.stat "pfd-link-a"))))
  (* "A hard link to a directory cannot be created." *)
  val () = T.raises ("Posix.FileSys.link/directory", isSysErr,
                     fn () => clean (["pfd-link-dir"], ["pfd-dir"], fn () =>
                                (FS.mkdir ("pfd-dir", S.irwxu); FS.link {old = "pfd-dir", new = "pfd-link-dir"})))
  val () = T.raises ("Posix.FileSys.link/missing-file", isSysErr,
                     fn () => clean (["pfd-link-b"], [], fn () => FS.link {old = "pfd-no-such-file", new = "pfd-link-b"}))

  (* ---- symlink, readlink ---- *)
  (* "creates a symbolic link new. Any component of a pathname resolving to
     new will be replaced by the text old. Note that old may be a relative or
     absolute pathname, and might not be the pathname of any existing file." *)
  val () = eqS ("Posix.FileSys.symlink/follows", "hello",
                fn () => clean (["pfd-sym-a", "pfd-sym-b"], [], fn () =>
                           (write ("pfd-sym-a", "hello"); FS.symlink {old = "pfd-sym-a", new = "pfd-sym-b"};
                            slurp "pfd-sym-b")))
  val () = eqB ("Posix.FileSys.symlink/dangling", true,
                fn () => clean (["pfd-sym-b"], [], fn () =>
                           (FS.symlink {old = "pfd-no-such-target", new = "pfd-sym-b"};
                            exists "pfd-sym-b" andalso not (FS.access ("pfd-sym-b", [])))))
  val () = eqS ("Posix.FileSys.symlink/through-a-directory", "inside",
                fn () => clean (["pfd-dir/f", "pfd-sym-d"], ["pfd-dir"], fn () =>
                           (FS.mkdir ("pfd-dir", S.irwxu); write ("pfd-dir/f", "inside");
                            FS.symlink {old = "pfd-dir", new = "pfd-sym-d"}; slurp "pfd-sym-d/f")))
  val () = T.raises ("Posix.FileSys.symlink/existing-name", isSysErr,
                     fn () => clean (["pfd-sym-a"], [], fn () =>
                                (write ("pfd-sym-a", ""); FS.symlink {old = "x", new = "pfd-sym-a"})))
  (* "reads the value of a symbolic link s": the text old, as it was given *)
  val () = eqS ("Posix.FileSys.readlink/text-of-the-link", "pfd-no-such-target",
                fn () => clean (["pfd-sym-b"], [], fn () =>
                           (FS.symlink {old = "pfd-no-such-target", new = "pfd-sym-b"}; FS.readlink "pfd-sym-b")))
  val () = eqS ("Posix.FileSys.readlink/relative-path-kept", "../x/./y",
                fn () => clean (["pfd-sym-b"], [], fn () =>
                           (FS.symlink {old = "../x/./y", new = "pfd-sym-b"}; FS.readlink "pfd-sym-b")))
  val () = eqS ("Posix.FileSys.readlink/absolute-path", "/no/such/absolute/path",
                fn () => clean (["pfd-sym-b"], [], fn () =>
                           (FS.symlink {old = "/no/such/absolute/path", new = "pfd-sym-b"}; FS.readlink "pfd-sym-b")))
  val () = T.raises ("Posix.FileSys.readlink/not-a-link", isSysErr,
                     fn () => clean (["pfd-sym-a"], [], fn () => (write ("pfd-sym-a", ""); FS.readlink "pfd-sym-a")))
  val () = T.raises ("Posix.FileSys.readlink/missing", isSysErr, fn () => FS.readlink "pfd-no-such-file")

  (* ---- unlink ---- *)
  (* "removes the directory entry specified by path and, if the entry is a
     hard link, decrements the link count of the file referenced by the
     link" *)
  val () = eqB ("Posix.FileSys.unlink/removes", false,
                fn () => clean (["pfd-unlink"], [], fn () => (write ("pfd-unlink", "x"); FS.unlink "pfd-unlink"; exists "pfd-unlink")))
  val () = T.eq T.int ("Posix.FileSys.unlink/decrements-link-count", 1,
                       fn () => clean (["pfd-link-a", "pfd-link-b"], [], fn () =>
                                  (write ("pfd-link-a", "hello"); FS.link {old = "pfd-link-a", new = "pfd-link-b"};
                                   FS.unlink "pfd-link-a"; FS.ST.nlink (FS.stat "pfd-link-b"))))
  (* "If the path parameter names a symbolic link, the symbolic link itself
     is removed." *)
  val () = eqB ("Posix.FileSys.unlink/symbolic-link", true,
                fn () => clean (["pfd-sym-a", "pfd-sym-b"], [], fn () =>
                           (write ("pfd-sym-a", "hello"); FS.symlink {old = "pfd-sym-a", new = "pfd-sym-b"};
                            FS.unlink "pfd-sym-b"; not (exists "pfd-sym-b") andalso slurp "pfd-sym-a" = "hello")))
  (* "If one or more processes have the file open ..., the link is removed
     before unlink returns, but the removal of the file contents is postponed
     until all open ... references to the file are removed." *)
  val () = eqS ("Posix.FileSys.unlink/open-file", "gone:still here",
                fn () => clean (["pfd-unlink"], [], fn () =>
                           let
                             val () = write ("pfd-unlink", "still here")
                             val ins = TextIO.openIn "pfd-unlink"
                             val () = FS.unlink "pfd-unlink"
                             val gone = not (exists "pfd-unlink")
                             val rest = TextIO.inputAll ins
                           in TextIO.closeIn ins; (if gone then "gone:" else "there:") ^ rest end))
  val () = T.raises ("Posix.FileSys.unlink/missing", isSysErr, fn () => FS.unlink "pfd-no-such-file")

  (* ---- rename ---- *)
  (* "changes the name of a file system object from old to new" *)
  val () = eqS ("Posix.FileSys.rename/file", "false:moved",
                fn () => clean (["pfd-ren-a", "pfd-ren-b"], [], fn () =>
                           (write ("pfd-ren-a", "moved"); FS.rename {old = "pfd-ren-a", new = "pfd-ren-b"};
                            Bool.toString (exists "pfd-ren-a") ^ ":" ^ slurp "pfd-ren-b")))
  val () = eqS ("Posix.FileSys.rename/directory", "inside",
                fn () => clean (["pfd-dir2/f"], ["pfd-dir", "pfd-dir2"], fn () =>
                           (FS.mkdir ("pfd-dir", S.irwxu); write ("pfd-dir/f", "inside");
                            FS.rename {old = "pfd-dir", new = "pfd-dir2"}; slurp "pfd-dir2/f")))
  val () = eqB ("Posix.FileSys.rename/into-directory", true,
                fn () => clean (["pfd-ren-a", "pfd-dir/g"], ["pfd-dir"], fn () =>
                           (FS.mkdir ("pfd-dir", S.irwxu); write ("pfd-ren-a", "x");
                            FS.rename {old = "pfd-ren-a", new = "pfd-dir/g"};
                            exists "pfd-dir/g" andalso not (exists "pfd-ren-a"))))
  val () = T.raises ("Posix.FileSys.rename/missing", isSysErr,
                     fn () => FS.rename {old = "pfd-no-such-file", new = "pfd-ren-b"})

  (* ---- mkdir, rmdir ---- *)
  (* "creates a new directory named s with protection mode m (as modified by
     the umask)" *)
  val () = eqB ("Posix.FileSys.mkdir/makes-a-directory", true,
                fn () => clean ([], ["pfd-dir"], fn () => (FS.mkdir ("pfd-dir", S.irwxu); FS.ST.isDir (FS.stat "pfd-dir"))))
  val () = eqMode ("Posix.FileSys.mkdir/mode", S.flags [S.irwxu, S.irgrp, S.ixgrp],
                   fn () => clean ([], ["pfd-dir"], fn () =>
                              withMask (S.flags [], fn () =>
                                (FS.mkdir ("pfd-dir", S.flags [S.irwxu, S.irgrp, S.ixgrp]); permsOf "pfd-dir"))))
  val () = eqMode ("Posix.FileSys.mkdir/mode-less-umask", S.flags [S.irwxu, S.irgrp, S.ixgrp, S.iroth, S.ixoth],
                   fn () => clean ([], ["pfd-dir"], fn () =>
                              withMask (S.flags [S.iwgrp, S.iwoth], fn () =>
                                (FS.mkdir ("pfd-dir", S.flags [S.irwxu, S.irwxg, S.irwxo]); permsOf "pfd-dir"))))
  val () = eqMode ("Posix.FileSys.mkdir/owner-only", S.irwxu,
                   fn () => clean ([], ["pfd-dir"], fn () =>
                              withMask (S.flags [S.iwgrp, S.iwoth], fn () =>
                                (FS.mkdir ("pfd-dir", S.irwxu); permsOf "pfd-dir"))))
  val () = eqB ("Posix.FileSys.mkdir/mask-unchanged", true,
                fn () => clean ([], ["pfd-dir"], fn () =>
                           withMask (S.flags [S.iwgrp, S.iwoth], fn () =>
                             (FS.mkdir ("pfd-dir", S.irwxu); FS.umask (S.flags [S.iwgrp, S.iwoth]) = S.flags [S.iwgrp, S.iwoth]))))
  val () = T.raises ("Posix.FileSys.mkdir/existing", isSysErr,
                     fn () => clean ([], ["pfd-dir"], fn () => (FS.mkdir ("pfd-dir", S.irwxu); FS.mkdir ("pfd-dir", S.irwxu))))
  val () = T.raises ("Posix.FileSys.mkdir/missing-parent", isSysErr, fn () => FS.mkdir ("pfd-no-such-dir/d", S.irwxu))
  (* "removes a directory s, which must be empty" *)
  val () = eqB ("Posix.FileSys.rmdir/removes", false,
                fn () => clean ([], ["pfd-dir"], fn () => (FS.mkdir ("pfd-dir", S.irwxu); FS.rmdir "pfd-dir"; exists "pfd-dir")))
  val () = T.raises ("Posix.FileSys.rmdir/not-empty", isSysErr,
                     fn () => clean (["pfd-dir/f"], ["pfd-dir"], fn () =>
                                (FS.mkdir ("pfd-dir", S.irwxu); write ("pfd-dir/f", ""); FS.rmdir "pfd-dir")))
  val () = T.raises ("Posix.FileSys.rmdir/a-file", isSysErr,
                     fn () => clean (["pfd-file"], [], fn () => (write ("pfd-file", ""); FS.rmdir "pfd-file")))
  val () = T.raises ("Posix.FileSys.rmdir/missing", isSysErr, fn () => FS.rmdir "pfd-no-such-dir")

  (* ---- mkfifo ---- *)
  (* "makes a FIFO special file (or named pipe) s, with protection mode m (as
     modified by the umask)" *)
  val () = eqB ("Posix.FileSys.mkfifo/makes-a-fifo", true,
                fn () => clean (["pfd-fifo"], [], fn () =>
                           (FS.mkfifo ("pfd-fifo", S.flags [S.irusr, S.iwusr]);
                            exists "pfd-fifo" andalso not (FS.ST.isReg (FS.stat "pfd-fifo")))))
  val () = eqMode ("Posix.FileSys.mkfifo/mode-less-umask", S.flags [S.irusr, S.iwusr, S.irgrp, S.iroth],
                   fn () => clean (["pfd-fifo"], [], fn () =>
                              withMask (S.flags [S.iwgrp, S.iwoth], fn () =>
                                (FS.mkfifo ("pfd-fifo", S.flags [S.irusr, S.iwusr, S.irgrp, S.iwgrp, S.iroth, S.iwoth]);
                                 permsOf "pfd-fifo"))))
  val () = T.raises ("Posix.FileSys.mkfifo/existing", isSysErr,
                     fn () => clean (["pfd-file"], [], fn () => (write ("pfd-file", ""); FS.mkfifo ("pfd-file", S.irwxu))))

  (* ---- opendir, readdir, rewinddir, closedir ---- *)
  fun withDir (files, f) =
    clean (List.map (fn n => "pfd-ls/" ^ n) files, ["pfd-ls"], fn () =>
      (FS.mkdir ("pfd-ls", S.irwxu);
       List.app (fn n => write ("pfd-ls/" ^ n, n)) files;
       let val d = FS.opendir "pfd-ls"
       in (f d before FS.closedir d) handle e => (FS.closedir d; raise e) end))
  (* "Entries for "." (current directory) and ".." (parent directory) are never
     returned." *)
  val () = eqL ("Posix.FileSys.readdir/entries", ["a", "b", "c.txt"], fn () => withDir (["b", "c.txt", "a"], sorted))
  val () = eqL ("Posix.FileSys.readdir/empty-directory", [], fn () => withDir ([], sorted))
  (* "When the directory stream is empty ..., NONE is returned." *)
  val () = eqB ("Posix.FileSys.readdir/NONE-at-end", true,
                fn () => withDir (["a"], fn d => (ignore (names d); FS.readdir d = NONE andalso FS.readdir d = NONE)))
  val () = T.eq (T.option T.string) ("Posix.FileSys.opendir/positioned-at-first-entry", SOME "only",
                                     fn () => withDir (["only"], FS.readdir))
  (* "repositions the directory stream d for reading at the beginning" *)
  val () = eqL ("Posix.FileSys.rewinddir/reads-again", ["a", "b"],
                fn () => withDir (["a", "b"], fn d => (ignore (names d); FS.rewinddir d; sorted d)))
  val () = eqL ("Posix.FileSys.rewinddir/after-one-entry", ["a", "b"],
                fn () => withDir (["a", "b"], fn d => (ignore (FS.readdir d); FS.rewinddir d; sorted d)))
  (* "Closing a previously closed dirstream does not raise an exception." *)
  val () = eqB ("Posix.FileSys.closedir/twice", true,
                fn () => withDir (["a"], fn d => (FS.closedir d; FS.closedir d; true)))
  val () = eqB ("Posix.FileSys.closedir/then-opendir-again", true,
                fn () => withDir (["a"], fn d => (FS.closedir d;
                                                  let val d' = FS.opendir "pfd-ls"
                                                  in sorted d' = ["a"] before FS.closedir d' end)))
  val () = T.raises ("Posix.FileSys.opendir/missing", isSysErr, fn () => FS.opendir "pfd-no-such-dir")
  val () = T.raises ("Posix.FileSys.opendir/a-file", isSysErr,
                     fn () => clean (["pfd-file"], [], fn () => (write ("pfd-file", ""); FS.opendir "pfd-file")))

  (* ---- chdir, getcwd ---- *)
  (* withCwd f: f () with the working directory put back afterwards *)
  fun withCwd f =
    let val here = FS.getcwd ()
    in (f here before FS.chdir here) handle e => (FS.chdir here; raise e) end
  (* "The absolute pathname of the current working directory." *)
  val () = eqB ("Posix.FileSys.getcwd/absolute", true,
                fn () => let val d = FS.getcwd () in String.size d > 0 andalso String.sub (d, 0) = #"/" end)
  val () = eqB ("Posix.FileSys.getcwd/is-the-directory", true,
                fn () => FS.ST.ino (FS.stat (FS.getcwd ())) = FS.ST.ino (FS.stat ".")
                         andalso FS.ST.dev (FS.stat (FS.getcwd ())) = FS.ST.dev (FS.stat "."))
  (* "changes the current working directory to s" *)
  val () = eqB ("Posix.FileSys.chdir/into-subdirectory", true,
                fn () => clean ([], ["pfd-cd"], fn () =>
                           (FS.mkdir ("pfd-cd", S.irwxu);
                            withCwd (fn here => (FS.chdir "pfd-cd"; FS.getcwd () = here ^ "/pfd-cd")))))
  val () = eqS ("Posix.FileSys.chdir/relative-names", "made inside",
                fn () => clean (["pfd-cd/f"], ["pfd-cd"], fn () =>
                           (FS.mkdir ("pfd-cd", S.irwxu);
                            withCwd (fn _ => (FS.chdir "pfd-cd"; write ("f", "made inside")));
                            slurp "pfd-cd/f")))
  val () = eqB ("Posix.FileSys.chdir/back-up", true,
                fn () => clean ([], ["pfd-cd"], fn () =>
                           (FS.mkdir ("pfd-cd", S.irwxu);
                            withCwd (fn here => (FS.chdir "pfd-cd"; FS.chdir ".."; FS.getcwd () = here)))))
  val () = eqB ("Posix.FileSys.chdir/absolute", true,
                fn () => withCwd (fn here => (FS.chdir "/"; FS.getcwd () = "/" andalso (FS.chdir here; FS.getcwd () = here))))
  val () = T.raises ("Posix.FileSys.chdir/missing", isSysErr, fn () => withCwd (fn _ => FS.chdir "pfd-no-such-dir"))
  val () = eqB ("Posix.FileSys.chdir/failure-keeps-directory", true,
                fn () => withCwd (fn here => ((FS.chdir "pfd-no-such-dir" handle OS.SysErr _ => ()); FS.getcwd () = here)))
end

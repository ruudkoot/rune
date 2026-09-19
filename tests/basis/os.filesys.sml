(* requires: OS TextIO Time Position *)
(* OS.FileSys (signature OS_FILE_SYS). Expected values follow the text of
   https://smlfamily.github.io/Basis/os-file-sys.html.

   Everything the test creates is in one directory of the current directory,
   the first of osfs0, osfs1, ... that does not exist yet, and in the files
   that tmpName makes; the last checks remove them. The current directory is
   changed only inside a check, which changes it back. Symbolic and hard
   links, permission bits and access times are made and read with
   Posix.FileSys, in the sections at the end. *)
structure TestOSFileSys =
struct
  val eqB = T.eq T.bool
  val eqS = T.eq T.string
  val eqSL = T.eq (T.list T.string)
  val eqPos = T.eq Position.toString
  val eqTime = T.eq Time.toString
  val isSysErr = fn OS.SysErr _ => true | _ => false

  fun write (name, s) = let val out = TextIO.openOut name in TextIO.output (out, s); TextIO.closeOut out end
  fun append (name, s) = let val out = TextIO.openAppend name in TextIO.output (out, s); TextIO.closeOut out end
  fun slurp name = let val ins = TextIO.openIn name val s = TextIO.inputAll ins in TextIO.closeIn ins; s end
  fun exists name = OS.FileSys.access (name, [])

  (* top (): the directory of the test, chosen when it is first asked for. *)
  val topName : string option ref = ref NONE
  fun top () =
    case !topName of
      SOME n => n
    | NONE =>
        let
          fun try i = let val n = "osfs" ^ Int.toString i in if exists n then try (i + 1) else n end
          val n = try 0
        in
          topName := SOME n; n
        end
  fun p name = top () ^ "/" ^ name

  fun insert (x : string, []) = [x]
    | insert (x, y :: r) = if x <= y then x :: y :: r else y :: insert (x, r)
  fun sort l = List.foldl insert [] l

  (* readAll s: the names that s has left, in the order readDir gives them. *)
  fun readAll s = case OS.FileSys.readDir s of NONE => [] | SOME n => n :: readAll s
  (* entries d: the names in the directory d, sorted. *)
  fun entries d =
    let val s = OS.FileSys.openDir d val names = readAll s in OS.FileSys.closeDir s; sort names end

  (* inDir (d, f): f () with d as the current directory, which is restored
     after, also when f raises an exception. *)
  fun inDir (d, f) =
    let
      val here = OS.FileSys.getDir ()
      val () = OS.FileSys.chDir d
      val r = f () handle e => (OS.FileSys.chDir here; raise e)
    in
      OS.FileSys.chDir here; r
    end

  (* The names tmpName returned, removed at the end. *)
  val tmpNames : string list ref = ref []
  fun newTmp () = let val n = OS.FileSys.tmpName () in tmpNames := n :: !tmpNames; n end

  (* ---- mkDir, and the files of the test:
       top/a.txt "hello\n", top/b.txt "", top/sub/c.txt "c" ---- *)
  val () = eqB ("OS.FileSys.mkDir/creates", true,
                fn () => (OS.FileSys.mkDir (top ()); OS.FileSys.isDir (top ())))
  val () = eqSL ("OS.FileSys.mkDir/nested", ["a.txt", "b.txt", "sub"],
                 fn () => (write (p "a.txt", "hello\n"); write (p "b.txt", "");
                           OS.FileSys.mkDir (p "sub"); write (p "sub/c.txt", "c");
                           entries (top ())))
  (* "mkDir raises SysErr if, for example, the directory in which s is to be
     created does not exist"; "each of the ancestor directories will need to
     be created first" *)
  val () = T.raises ("OS.FileSys.mkDir/missing-parent-SysErr", isSysErr, fn () => OS.FileSys.mkDir (p "none/deeper"))
  val () = T.raises ("OS.FileSys.mkDir/exists-SysErr", isSysErr, fn () => OS.FileSys.mkDir (p "sub"))
  val () = T.raises ("OS.FileSys.mkDir/over-a-file-SysErr", isSysErr, fn () => OS.FileSys.mkDir (p "a.txt"))
  (* "functions taking a string argument will raise the OS.SysErr exception
     if the argument string is empty" *)
  val () = T.raises ("OS.FileSys.mkDir/empty-SysErr", isSysErr, fn () => OS.FileSys.mkDir "")

  (* ---- openDir, readDir, rewindDir, closeDir ---- *)
  (* "readDir filters out the names corresponding to the current and parent
     arcs" *)
  val () = eqB ("OS.FileSys.readDir/no-current-or-parent-arc", true,
                fn () => not (List.exists (fn n => n = "." orelse n = "..") (entries (top ()))))
  val () = eqSL ("OS.FileSys.readDir/subdirectory", ["c.txt"], fn () => entries (p "sub"))
  (* "When the directory stream is empty ... NONE is returned", and it stays
     empty. *)
  val () = T.eq (T.list (T.option T.string)) ("OS.FileSys.readDir/NONE-at-the-end", [NONE, NONE],
                fn () => let val s = OS.FileSys.openDir (top ())
                             val _ = readAll s
                             val r = [OS.FileSys.readDir s, OS.FileSys.readDir s]
                         in OS.FileSys.closeDir s; r end)
  val () = T.eq (T.option T.string) ("OS.FileSys.readDir/empty-directory", NONE,
                fn () => (OS.FileSys.mkDir (p "empty");
                          let val s = OS.FileSys.openDir (p "empty") val r = OS.FileSys.readDir s
                          in OS.FileSys.closeDir s; OS.FileSys.rmDir (p "empty"); r end))
  (* "returns and removes one filename": each name once *)
  val () = T.eq T.int ("OS.FileSys.readDir/each-name-once", 3,
                       fn () => let val s = OS.FileSys.openDir (top ()) val n = List.length (readAll s)
                                in OS.FileSys.closeDir s; n end)
  val () = eqSL ("OS.FileSys.openDir/relative-dot", ["a.txt", "b.txt", "sub"],
                 fn () => inDir (top (), fn () => entries "."))
  val () = eqSL ("OS.FileSys.openDir/two-streams", ["a.txt", "b.txt", "sub"],
                 fn () => let val s1 = OS.FileSys.openDir (top ())
                              val s2 = OS.FileSys.openDir (top ())
                              val _ = readAll s1
                              val names = readAll s2
                          in OS.FileSys.closeDir s1; OS.FileSys.closeDir s2; sort names end)
  (* "It raises SysErr if, for example, the directory does not exist" *)
  val () = T.raises ("OS.FileSys.openDir/missing-SysErr", isSysErr, fn () => OS.FileSys.openDir (p "none"))
  val () = T.raises ("OS.FileSys.openDir/file-SysErr", isSysErr, fn () => OS.FileSys.openDir (p "a.txt"))
  val () = T.raises ("OS.FileSys.openDir/empty-SysErr", isSysErr, fn () => OS.FileSys.openDir "")
  (* "resets the directory stream dir, as if it had just been opened" *)
  val () = eqSL ("OS.FileSys.rewindDir/after-some", ["a.txt", "b.txt", "sub"],
                 fn () => let val s = OS.FileSys.openDir (top ())
                              val _ = OS.FileSys.readDir s
                              val _ = OS.FileSys.readDir s
                              val () = OS.FileSys.rewindDir s
                              val names = readAll s
                          in OS.FileSys.closeDir s; sort names end)
  val () = eqSL ("OS.FileSys.rewindDir/after-the-end", ["a.txt", "b.txt", "sub"],
                 fn () => let val s = OS.FileSys.openDir (top ())
                              val _ = readAll s
                              val () = OS.FileSys.rewindDir s
                              val names = readAll s
                          in OS.FileSys.closeDir s; sort names end)
  (* "Any subsequent read or rewind on the stream will raise exception
     SysErr. Closing a closed directory stream, however, has no effect." *)
  val () = T.raises ("OS.FileSys.closeDir/then-readDir-SysErr", isSysErr,
                     fn () => let val s = OS.FileSys.openDir (top ()) in OS.FileSys.closeDir s; OS.FileSys.readDir s end)
  val () = T.raises ("OS.FileSys.closeDir/then-rewindDir-SysErr", isSysErr,
                     fn () => let val s = OS.FileSys.openDir (top ()) in OS.FileSys.closeDir s; OS.FileSys.rewindDir s end)
  val () = T.raises ("OS.FileSys.closeDir/at-the-end-then-readDir-SysErr", isSysErr,
                     fn () => let val s = OS.FileSys.openDir (top ())
                              in ignore (readAll s); OS.FileSys.closeDir s; OS.FileSys.readDir s end)
  val () = eqB ("OS.FileSys.closeDir/twice", true,
                fn () => let val s = OS.FileSys.openDir (top ()) in OS.FileSys.closeDir s; OS.FileSys.closeDir s; true end)

  (* ---- getDir: "An absolute canonical pathname of the current working
     directory"; chDir ---- *)
  val () = eqB ("OS.FileSys.getDir/absolute", true, fn () => OS.Path.isAbsolute (OS.FileSys.getDir ()))
  val () = eqB ("OS.FileSys.getDir/canonical", true, fn () => OS.Path.isCanonical (OS.FileSys.getDir ()))
  val () = eqB ("OS.FileSys.getDir/same-twice", true, fn () => OS.FileSys.getDir () = OS.FileSys.getDir ())
  val () = eqB ("OS.FileSys.getDir/is-a-directory", true, fn () => OS.FileSys.isDir (OS.FileSys.getDir ()))
  val () = eqS ("OS.FileSys.chDir/relative", "/" ^ top () ^ "/sub",
                fn () => let val here = OS.FileSys.getDir ()
                             val there = inDir (p "sub", OS.FileSys.getDir)
                         in if String.isPrefix here there then String.extract (there, size here, NONE) else there end)
  val () = eqB ("OS.FileSys.chDir/back-to-absolute", true,
                fn () => let val here = OS.FileSys.getDir ()
                         in inDir (top (), fn () => (OS.FileSys.chDir here; OS.FileSys.getDir () = here)) end)
  val () = eqB ("OS.FileSys.chDir/parent-arc", true,
                fn () => inDir (p "sub", fn () => (OS.FileSys.chDir OS.Path.parentArc; OS.FileSys.getDir ()))
                         = inDir (top (), OS.FileSys.getDir))
  (* "This affects future calls to all functions that access the file system.
     These include the input/output functions such as TextIO.openIn and
     TextIO.openOut, and functions defined in this structure." *)
  val () = eqS ("OS.FileSys.chDir/affects-TextIO.openIn", "hello\n", fn () => inDir (top (), fn () => slurp "a.txt"))
  val () = eqS ("OS.FileSys.chDir/affects-TextIO.openOut", "made in sub",
                fn () => (inDir (p "sub", fn () => write ("made.txt", "made in sub"));
                          let val s = slurp (p "sub/made.txt") in OS.FileSys.remove (p "sub/made.txt"); s end))
  val () = eqB ("OS.FileSys.chDir/affects-FileSys", true, fn () => inDir (top (), fn () => OS.FileSys.isDir "sub"))
  (* "It raises SysErr if, for example, the directory does not exist" *)
  val () = T.raises ("OS.FileSys.chDir/missing-SysErr", isSysErr, fn () => OS.FileSys.chDir (p "none"))
  val () = eqB ("OS.FileSys.chDir/failure-keeps-the-directory", true,
                fn () => let val here = OS.FileSys.getDir ()
                         in (OS.FileSys.chDir (p "none") handle OS.SysErr _ => ()); OS.FileSys.getDir () = here end)
  val () = T.raises ("OS.FileSys.chDir/file-SysErr", isSysErr, fn () => OS.FileSys.chDir (p "a.txt"))
  val () = T.raises ("OS.FileSys.chDir/empty-SysErr", isSysErr, fn () => OS.FileSys.chDir "")

  (* ---- isDir ---- *)
  val () = eqB ("OS.FileSys.isDir/directory", true, fn () => OS.FileSys.isDir (p "sub"))
  val () = eqB ("OS.FileSys.isDir/current-arc", true, fn () => OS.FileSys.isDir ".")
  val () = eqB ("OS.FileSys.isDir/root", true, fn () => OS.FileSys.isDir "/")
  val () = eqB ("OS.FileSys.isDir/trailing-separator", true, fn () => OS.FileSys.isDir (p "sub/"))
  val () = eqB ("OS.FileSys.isDir/file", false, fn () => OS.FileSys.isDir (p "a.txt"))
  (* "It raises SysErr if, for example, s does not exist" *)
  val () = T.raises ("OS.FileSys.isDir/missing-SysErr", isSysErr, fn () => OS.FileSys.isDir (p "none"))
  val () = T.raises ("OS.FileSys.isDir/empty-SysErr", isSysErr, fn () => OS.FileSys.isDir "")

  (* ---- isLink, readLink, on what is not a link ---- *)
  val () = eqB ("OS.FileSys.isLink/file", false, fn () => OS.FileSys.isLink (p "a.txt"))
  val () = eqB ("OS.FileSys.isLink/directory", false, fn () => OS.FileSys.isLink (p "sub"))
  (* "It raises SysErr if, for example, s does not exist" *)
  val () = T.raises ("OS.FileSys.isLink/missing-SysErr", isSysErr, fn () => OS.FileSys.isLink (p "none"))
  val () = T.raises ("OS.FileSys.isLink/empty-SysErr", isSysErr, fn () => OS.FileSys.isLink "")
  (* "It raises SysErr if, for example, s does not exist or is not a symbolic
     link" *)
  val () = T.raises ("OS.FileSys.readLink/file-SysErr", isSysErr, fn () => OS.FileSys.readLink (p "a.txt"))
  val () = T.raises ("OS.FileSys.readLink/missing-SysErr", isSysErr, fn () => OS.FileSys.readLink (p "none"))
  val () = T.raises ("OS.FileSys.readLink/empty-SysErr", isSysErr, fn () => OS.FileSys.readLink "")

  (* ---- fullPath: "an absolute canonical path that names the same file
     system object"; "An empty path is treated as "."." ---- *)
  fun here () = OS.FileSys.getDir ()
  val () = eqB ("OS.FileSys.fullPath/current-arc", true, fn () => OS.FileSys.fullPath "." = here ())
  val () = eqB ("OS.FileSys.fullPath/empty-is-current-arc", true, fn () => OS.FileSys.fullPath "" = here ())
  val () = eqB ("OS.FileSys.fullPath/relative-file", true,
                fn () => OS.FileSys.fullPath (p "a.txt") = OS.Path.concat (here (), p "a.txt"))
  val () = eqB ("OS.FileSys.fullPath/arcs-removed", true,
                fn () => OS.FileSys.fullPath (top () ^ "/./sub//../a.txt") = OS.Path.concat (here (), p "a.txt"))
  val () = eqB ("OS.FileSys.fullPath/trailing-separator", true,
                fn () => OS.FileSys.fullPath (p "sub/") = OS.Path.concat (here (), p "sub"))
  val () = eqB ("OS.FileSys.fullPath/absolute-canonical", true,
                fn () => let val f = OS.FileSys.fullPath (top () ^ "/sub/../b.txt")
                         in OS.Path.isAbsolute f andalso OS.Path.isCanonical f end)
  val () = eqB ("OS.FileSys.fullPath/of-fullPath", true,
                fn () => let val f = OS.FileSys.fullPath (p "a.txt") in OS.FileSys.fullPath f = f end)
  val () = eqS ("OS.FileSys.fullPath/root", "/", fn () => OS.FileSys.fullPath "/")
  val () = eqB ("OS.FileSys.fullPath/parent-arc", true,
                fn () => OS.FileSys.fullPath (p "sub/..") = OS.Path.concat (here (), top ()))
  (* "It raises SysErr if, for example, a directory on the path, or the file
     or directory named, does not exist" *)
  val () = T.raises ("OS.FileSys.fullPath/missing-SysErr", isSysErr, fn () => OS.FileSys.fullPath (p "none"))
  val () = T.raises ("OS.FileSys.fullPath/missing-directory-SysErr", isSysErr,
                     fn () => OS.FileSys.fullPath (p "none/a.txt"))

  (* ---- realPath: "If path is relative ..., then it returns a path that is
     relative to the current working directory"; "If path is an absolute
     path, then realPath acts like fullPath" ---- *)
  val () = eqS ("OS.FileSys.realPath/relative-file", top () ^ "/a.txt", fn () => OS.FileSys.realPath (p "a.txt"))
  val () = eqS ("OS.FileSys.realPath/arcs-removed", top () ^ "/a.txt",
                fn () => OS.FileSys.realPath (top () ^ "/./sub//../a.txt"))
  val () = eqS ("OS.FileSys.realPath/current-arc", ".", fn () => OS.FileSys.realPath ".")
  val () = eqS ("OS.FileSys.realPath/empty", ".", fn () => OS.FileSys.realPath "")
  val () = eqS ("OS.FileSys.realPath/parent-arc", "..", fn () => OS.FileSys.realPath "..")
  val () = eqS ("OS.FileSys.realPath/from-a-subdirectory", "../a.txt",
                fn () => inDir (p "sub", fn () => OS.FileSys.realPath "../a.txt"))
  val () = eqB ("OS.FileSys.realPath/absolute-is-fullPath", true,
                fn () => let val f = OS.Path.concat (here (), top () ^ "/sub/../a.txt")
                         in OS.FileSys.realPath f = OS.FileSys.fullPath f end)
  val () = T.raises ("OS.FileSys.realPath/missing-SysErr", isSysErr, fn () => OS.FileSys.realPath (p "none"))

  (* ---- fileSize: "the size of file path in bytes" ---- *)
  val () = eqPos ("OS.FileSys.fileSize/bytes", Position.fromInt 6, fn () => OS.FileSys.fileSize (p "a.txt"))
  val () = eqPos ("OS.FileSys.fileSize/empty", Position.fromInt 0, fn () => OS.FileSys.fileSize (p "b.txt"))
  val () = eqPos ("OS.FileSys.fileSize/grows", Position.fromInt 9,
                  fn () => (write (p "grow.txt", "hello\n"); append (p "grow.txt", "abc");
                            OS.FileSys.fileSize (p "grow.txt")))
  val () = eqPos ("OS.FileSys.fileSize/large", Position.fromInt 100000,
                  fn () => (write (p "large.txt", CharVector.tabulate (100000, fn i => Char.chr (97 + i mod 26)));
                            OS.FileSys.fileSize (p "large.txt")))
  (* "the arguments can be directories as well as ordinary files" *)
  val () = eqB ("OS.FileSys.fileSize/directory", true,
                fn () => OS.FileSys.fileSize (p "sub") >= Position.fromInt 0)
  (* "It raises SysErr if, for example, path does not exist" *)
  val () = T.raises ("OS.FileSys.fileSize/missing-SysErr", isSysErr, fn () => OS.FileSys.fileSize (p "none"))
  val () = T.raises ("OS.FileSys.fileSize/empty-SysErr", isSysErr, fn () => OS.FileSys.fileSize "")

  (* ---- setTime, modTime: "If opt is SOME(t), then the time t is used;
     otherwise the current time (i.e., Time.now()) is used." ---- *)
  (* made inside the checks, like everything else: a Time.time need not
     hold them (Time) *)
  fun t2001 () = Time.fromSeconds (LargeInt.fromInt 1000000000)
  fun t2009 () = Time.fromSeconds (valOf (LargeInt.fromString "1234567890"))
  fun eqTimeOf (label, expected : unit -> Time.time, f) =
    case (SOME (expected ()) handle _ => NONE) of
      SOME e => eqTime (label, e, f)
    | NONE => T.fail (label, "the expected value raised an exception")
  val () = eqTimeOf ("OS.FileSys.setTime/SOME", t2001,
                     fn () => (OS.FileSys.setTime (p "a.txt", SOME (t2001 ())); OS.FileSys.modTime (p "a.txt")))
  val () = eqTimeOf ("OS.FileSys.setTime/SOME-again", t2009,
                     fn () => (OS.FileSys.setTime (p "a.txt", SOME (t2009 ())); OS.FileSys.modTime (p "a.txt")))
  val () = eqTimeOf ("OS.FileSys.setTime/directory", t2001,
                     fn () => (OS.FileSys.setTime (p "sub", SOME (t2001 ())); OS.FileSys.modTime (p "sub")))
  (* The file system may keep whole seconds only: a second of slack. *)
  fun within (lo, t, hi) =
    Time.<= (Time.- (lo, Time.fromSeconds (LargeInt.fromInt 1)), t)
    andalso Time.<= (t, Time.+ (hi, Time.fromSeconds (LargeInt.fromInt 1)))
  val () = eqB ("OS.FileSys.setTime/NONE-is-now", true,
                fn () => let
                           val () = OS.FileSys.setTime (p "a.txt", SOME (t2001 ()))
                           val start = Time.now ()
                           val () = OS.FileSys.setTime (p "a.txt", NONE)
                           val stop = Time.now ()
                         in within (start, OS.FileSys.modTime (p "a.txt"), stop) end)
  (* "It raises SysErr if path does not exist" *)
  val () = T.raises ("OS.FileSys.setTime/missing-SysErr", isSysErr,
                     fn () => OS.FileSys.setTime (p "none", SOME (t2001 ())))
  val () = T.raises ("OS.FileSys.setTime/missing-NONE-SysErr", isSysErr, fn () => OS.FileSys.setTime (p "none", NONE))
  val () = T.raises ("OS.FileSys.setTime/empty-SysErr", isSysErr, fn () => OS.FileSys.setTime ("", NONE))
  val () = eqB ("OS.FileSys.modTime/new-file-is-now", true,
                fn () => let
                           val start = Time.now ()
                           val () = write (p "new.txt", "new")
                           val stop = Time.now ()
                         in within (start, OS.FileSys.modTime (p "new.txt"), stop) end)
  val () = eqB ("OS.FileSys.modTime/writing-updates", true,
                fn () => (OS.FileSys.setTime (p "new.txt", SOME (t2001 ())); append (p "new.txt", "er");
                          Time.> (OS.FileSys.modTime (p "new.txt"), t2001 ())))
  val () = eqB ("OS.FileSys.modTime/other-file-unchanged", true,
                fn () => (OS.FileSys.setTime (p "b.txt", SOME (t2009 ())); OS.FileSys.setTime (p "new.txt", SOME (t2001 ()));
                          OS.FileSys.modTime (p "b.txt") = t2009 ()))
  (* "It raises SysErr if, for example, path does not exist" *)
  val () = T.raises ("OS.FileSys.modTime/missing-SysErr", isSysErr, fn () => OS.FileSys.modTime (p "none"))
  val () = T.raises ("OS.FileSys.modTime/empty-SysErr", isSysErr, fn () => OS.FileSys.modTime "")

  (* ---- remove: "deletes the file path from the file system" ---- *)
  val () = eqB ("OS.FileSys.remove/file", false,
                fn () => (write (p "r.txt", "r"); OS.FileSys.remove (p "r.txt"); exists (p "r.txt")))
  val () = eqSL ("OS.FileSys.remove/others-kept", ["a.txt", "b.txt", "grow.txt", "large.txt", "new.txt", "sub"],
                 fn () => (write (p "r.txt", "r"); OS.FileSys.remove (p "r.txt"); entries (top ())))
  (* "It raises SysErr if, path does not exist ..., or file is a directory." *)
  val () = T.raises ("OS.FileSys.remove/missing-SysErr", isSysErr, fn () => OS.FileSys.remove (p "r.txt"))
  val () = T.raises ("OS.FileSys.remove/directory-SysErr", isSysErr, fn () => OS.FileSys.remove (p "sub"))
  val () = T.raises ("OS.FileSys.remove/empty-SysErr", isSysErr, fn () => OS.FileSys.remove "")
  val () = eqB ("OS.FileSys.remove/directory-kept", true,
                fn () => ((OS.FileSys.remove (p "sub") handle OS.SysErr _ => ()); OS.FileSys.isDir (p "sub")))

  (* ---- rename: "changes the name of file old to new" ---- *)
  val () = eqS ("OS.FileSys.rename/moves", "moved",
                fn () => (write (p "m1.txt", "moved"); OS.FileSys.rename {old = p "m1.txt", new = p "m2.txt"};
                          if exists (p "m1.txt") then "old name still there" else slurp (p "m2.txt")))
  (* "If a file called new exists, it is removed." *)
  val () = eqS ("OS.FileSys.rename/replaces", "first",
                fn () => (write (p "m1.txt", "first"); write (p "m3.txt", "second");
                          OS.FileSys.rename {old = p "m1.txt", new = p "m3.txt"};
                          if exists (p "m1.txt") then "old name still there" else slurp (p "m3.txt")))
  (* "If new and old refer to the same file, rename does nothing." *)
  val () = eqS ("OS.FileSys.rename/same-name", "second",
                fn () => (write (p "m4.txt", "second"); OS.FileSys.rename {old = p "m4.txt", new = p "m4.txt"};
                          slurp (p "m4.txt")))
  val () = eqS ("OS.FileSys.rename/other-name-of-same-file", "second",
                fn () => (OS.FileSys.rename {old = p "m4.txt", new = top () ^ "/sub/../m4.txt"}; slurp (p "m4.txt")))
  val () = eqS ("OS.FileSys.rename/into-a-subdirectory", "moved",
                fn () => (OS.FileSys.rename {old = p "m2.txt", new = p "sub/m2.txt"}; slurp (p "sub/m2.txt")))
  (* "the arguments can be directories as well as ordinary files" *)
  val () = eqSL ("OS.FileSys.rename/directory", ["c.txt", "m2.txt"],
                 fn () => (OS.FileSys.rename {old = p "sub", new = p "sub2"};
                           if exists (p "sub") then ["old name still there"]
                           else (let val l = entries (p "sub2") in OS.FileSys.rename {old = p "sub2", new = p "sub"}; l end)))
  (* "It raises SysErr if, for example, old does not exist" *)
  val () = T.raises ("OS.FileSys.rename/missing-SysErr", isSysErr,
                     fn () => OS.FileSys.rename {old = p "none", new = p "none2"})
  val () = T.raises ("OS.FileSys.rename/missing-directory-SysErr", isSysErr,
                     fn () => OS.FileSys.rename {old = p "m3.txt", new = p "none/m3.txt"})
  val () = T.raises ("OS.FileSys.rename/empty-SysErr", isSysErr, fn () => OS.FileSys.rename {old = "", new = p "x"})
  val () = eqB ("OS.FileSys.rename/failure-keeps-old", true,
                fn () => ((OS.FileSys.rename {old = p "m3.txt", new = p "none/m3.txt"} handle OS.SysErr _ => ());
                          exists (p "m3.txt")))

  (* ---- access: "If the list accs of required access modes is empty, it
     tests whether path exists." "The function will only raise OS.SysErr for
     errors unrelated to resolving the pathname and the related
     permissions" ---- *)
  val () = eqB ("OS.FileSys.access/exists", true, fn () => OS.FileSys.access (p "a.txt", []))
  val () = eqB ("OS.FileSys.access/directory-exists", true, fn () => OS.FileSys.access (p "sub", []))
  val () = eqB ("OS.FileSys.access/missing", false, fn () => OS.FileSys.access (p "none", []))
  val () = eqB ("OS.FileSys.access/missing-read", false, fn () => OS.FileSys.access (p "none", [OS.FileSys.A_READ]))
  val () = eqB ("OS.FileSys.access/missing-directory", false, fn () => OS.FileSys.access (p "none/a.txt", []))
  val () = eqB ("OS.FileSys.access/through-a-file", false, fn () => OS.FileSys.access (p "a.txt/x", []))
  (* A file the process made itself can be read and written. *)
  val () = eqB ("OS.FileSys.A_READ/own-file", true, fn () => OS.FileSys.access (p "a.txt", [OS.FileSys.A_READ]))
  val () = eqB ("OS.FileSys.A_WRITE/own-file", true, fn () => OS.FileSys.access (p "a.txt", [OS.FileSys.A_WRITE]))
  val () = eqB ("OS.FileSys.A_READ/own-directory", true, fn () => OS.FileSys.access (p "sub", [OS.FileSys.A_READ]))
  (* A_EXEC is accepted ("On systems that do not support a notion of
     execution permissions, the access should accept but ignore the A_EXEC
     value"); whether the file is executable is up to the system. *)
  val () = eqB ("OS.FileSys.A_EXEC/accepted", true,
                fn () => (ignore (OS.FileSys.access (p "a.txt", [OS.FileSys.A_EXEC])); true))
  (* "testing their conjunction if more than one are present", for every
     non-empty list of modes (the empty one tests existence) *)
  val modes = [OS.FileSys.A_READ, OS.FileSys.A_WRITE, OS.FileSys.A_EXEC]
  fun subsets [] = [[]]
    | subsets (x :: r) = let val s = subsets r in s @ List.map (fn l => x :: l) s end
  fun conjunction path =
    List.all (fn l => List.null l orelse OS.FileSys.access (path, l) = List.all (fn m => OS.FileSys.access (path, [m])) l)
             (subsets modes @ List.map List.rev (subsets modes))
  val () = eqB ("OS.FileSys.access/conjunction-file", true, fn () => conjunction (p "a.txt"))
  val () = eqB ("OS.FileSys.access/conjunction-directory", true, fn () => conjunction (p "sub"))
  val () = eqB ("OS.FileSys.access/conjunction-missing", true, fn () => conjunction (p "none"))
  val () = eqB ("OS.FileSys.access/repeated-mode", true,
                fn () => OS.FileSys.access (p "a.txt", [OS.FileSys.A_READ, OS.FileSys.A_READ, OS.FileSys.A_WRITE]))

  (* ---- tmpName: "This creates a new empty file with a unique name and
     returns the full pathname of the file. The named file will be readable
     and writable by the creating process" ---- *)
  val () = eqB ("OS.FileSys.tmpName/creates-a-file", true, fn () => exists (newTmp ()))
  val () = eqB ("OS.FileSys.tmpName/empty", true,
                fn () => OS.FileSys.fileSize (newTmp ()) = Position.fromInt 0)
  val () = eqB ("OS.FileSys.tmpName/not-a-directory", false, fn () => OS.FileSys.isDir (newTmp ()))
  val () = eqB ("OS.FileSys.tmpName/full-pathname", true, fn () => OS.Path.isAbsolute (newTmp ()))
  val () = eqB ("OS.FileSys.tmpName/readable-and-writable", true,
                fn () => OS.FileSys.access (newTmp (), [OS.FileSys.A_READ, OS.FileSys.A_WRITE]))
  val () = eqS ("OS.FileSys.tmpName/usable", "temporary",
                fn () => let val n = newTmp () in write (n, "temporary"); slurp n end)
  val () = eqB ("OS.FileSys.tmpName/unique", true,
                fn () => let val a = newTmp () val b = newTmp () val c = newTmp ()
                         in a <> b andalso b <> c andalso a <> c andalso exists a andalso exists b end)

  (* ---- fileId, hash, compare ---- *)
  fun id name = OS.FileSys.fileId name
  val () = eqB ("OS.FileSys.fileId/same-path", true, fn () => id (p "a.txt") = id (p "a.txt"))
  (* "if fileId p = fileId p', then the paths p and p' refer to the same file
     system object"; and a file_id is "better than pathnames for uniquely
     identifying files" *)
  val () = eqB ("OS.FileSys.fileId/other-path", true,
                fn () => id (p "a.txt") = id ("./" ^ top () ^ "/sub/../a.txt")
                         andalso id (p "a.txt") = id (OS.FileSys.fullPath (p "a.txt")))
  val () = eqB ("OS.FileSys.fileId/different-files", false, fn () => id (p "a.txt") = id (p "b.txt"))
  val () = eqB ("OS.FileSys.fileId/directory", true,
                fn () => id (top ()) = id (p "sub/..") andalso id (top ()) <> id (p "sub")
                         andalso id "." = id (OS.FileSys.getDir ()))
  val () = eqB ("OS.FileSys.fileId/same-file-after-rename", true,
                fn () => let val old = id (p "m3.txt")
                         in OS.FileSys.rename {old = p "m3.txt", new = p "m5.txt"}; id (p "m5.txt") = old end)
  val () = eqB ("OS.FileSys.fileId/new-content-same-file", true,
                fn () => let val old = id (p "m5.txt") in append (p "m5.txt", "more"); id (p "m5.txt") = old end)
  val () = T.raises ("OS.FileSys.fileId/missing-SysErr", isSysErr, fn () => id (p "none"))
  val () = T.raises ("OS.FileSys.fileId/empty-SysErr", isSysErr, fn () => id "")
  fun ids () = List.map (fn n => id (p n)) ["a.txt", "b.txt", "sub", "sub/c.txt", "large.txt", "."]
  (* "returns LESS, EQUAL, or GREATER when fid is less than, equal to, or
     greater than fid', respectively, in some underlying linear ordering" *)
  val () = eqB ("OS.FileSys.compare/EQUAL-iff-equal", true,
                fn () => let val l = ids ()
                         in List.all (fn a => List.all (fn b => (OS.FileSys.compare (a, b) = EQUAL) = (a = b)) l) l end)
  val () = eqB ("OS.FileSys.compare/antisymmetric", true,
                fn () => let val l = ids ()
                             fun flip LESS = GREATER | flip GREATER = LESS | flip EQUAL = EQUAL
                         in List.all (fn a => List.all (fn b => OS.FileSys.compare (b, a) = flip (OS.FileSys.compare (a, b))) l) l end)
  val () = eqB ("OS.FileSys.compare/transitive", true,
                fn () => let val l = ids ()
                             fun lt (a, b) = OS.FileSys.compare (a, b) = LESS
                         in List.all (fn a => List.all (fn b => List.all (fn c => not (lt (a, b) andalso lt (b, c)) orelse lt (a, c)) l) l) l end)
  val () = eqB ("OS.FileSys.compare/same-object", true,
                fn () => OS.FileSys.compare (id (p "a.txt"), id (top () ^ "/./a.txt")) = EQUAL)
  (* "returns a hash value associated with fid": the same for the same
     object; and, "well distributed when taken modulo 2(n)", not the same bit
     0 for sixteen files. *)
  val () = eqB ("OS.FileSys.hash/same-object", true,
                fn () => OS.FileSys.hash (id (p "a.txt")) = OS.FileSys.hash (id (top () ^ "/sub/../a.txt")))
  val () = eqB ("OS.FileSys.hash/spread", true,
                fn () => let
                           val () = OS.FileSys.mkDir (p "h")
                           val names = List.tabulate (16, fn i => p ("h/" ^ Int.toString i))
                           val () = List.app (fn n => write (n, "")) names
                           val bits = List.map (fn n => Word.andb (OS.FileSys.hash (id n), 0w1)) names
                         in List.exists (fn b => b = 0w0) bits andalso List.exists (fn b => b = 0w1) bits end)

  (*<< links *)
  (* Symbolic links, made with Posix.FileSys.symlink: top/link -> a.txt,
     top/sublink -> sub, top/dangling -> none, top/loop1 <-> top/loop2. *)
  fun symlink (target, name) = Posix.FileSys.symlink {old = target, new = p name}
  val () = eqB ("OS.FileSys.isLink/symbolic-link", true,
                fn () => (symlink ("a.txt", "link"); OS.FileSys.isLink (p "link")))
  (* "returns the contents of the symbolic link s" *)
  val () = eqS ("OS.FileSys.readLink/contents", "a.txt", fn () => OS.FileSys.readLink (p "link"))
  val () = eqB ("OS.FileSys.isLink/to-a-directory", true,
                fn () => (symlink ("sub", "sublink"); OS.FileSys.isLink (p "sublink")))
  val () = eqB ("OS.FileSys.isLink/dangling", true,
                fn () => (symlink ("none", "dangling"); OS.FileSys.isLink (p "dangling")))
  val () = eqS ("OS.FileSys.readLink/dangling", "none", fn () => OS.FileSys.readLink (p "dangling"))
  (* "only symbolic links appearing as directory components of the pathname
     are resolved" *)
  val () = eqB ("OS.FileSys.isLink/link-as-directory-component", false,
                fn () => OS.FileSys.isLink (p "sublink/c.txt"))
  val () = eqS ("OS.FileSys.readLink/link-as-directory-component", "a.txt",
                fn () => (symlink ("a.txt", "sub/uplink"); OS.FileSys.readLink (p "sublink/uplink")))
  (* "all functions taking a pathname as an argument ... will resolve any
     components corresponding to symbolic links" *)
  val () = eqB ("OS.FileSys.isDir/through-a-link", true, fn () => OS.FileSys.isDir (p "sublink"))
  val () = eqB ("OS.FileSys.isDir/link-to-a-file", false, fn () => OS.FileSys.isDir (p "link"))
  val () = eqB ("OS.FileSys.fileSize/through-a-link", true,
                fn () => OS.FileSys.fileSize (p "link") = OS.FileSys.fileSize (p "a.txt"))
  val () = eqTimeOf ("OS.FileSys.setTime/through-a-link", t2009,
                     fn () => (OS.FileSys.setTime (p "link", SOME (t2009 ())); OS.FileSys.modTime (p "a.txt")))
  val () = eqSL ("OS.FileSys.openDir/through-a-link", ["c.txt", "m2.txt", "uplink"], fn () => entries (p "sublink"))
  val () = eqB ("OS.FileSys.access/through-a-link", true, fn () => OS.FileSys.access (p "link", [OS.FileSys.A_READ]))
  (* "tests the access permissions of file path, expanding symbolic links" *)
  val () = eqB ("OS.FileSys.access/dangling-link", false, fn () => OS.FileSys.access (p "dangling", []))
  val () = eqB ("OS.FileSys.chDir/through-a-link", true,
                fn () => inDir (p "sublink", OS.FileSys.getDir) = inDir (p "sub", OS.FileSys.getDir))
  (* "Note that if p is a symbolic link, then fileId p = fileId(readLink p)." *)
  val () = eqB ("OS.FileSys.fileId/symbolic-link", true,
                fn () => inDir (top (), fn () => id "link" = id (OS.FileSys.readLink "link")))
  (* "any symbolic links will have been fully expanded" *)
  val () = eqB ("OS.FileSys.fullPath/link", true,
                fn () => OS.FileSys.fullPath (p "link") = OS.FileSys.fullPath (p "a.txt"))
  val () = eqB ("OS.FileSys.fullPath/link-as-directory-component", true,
                fn () => OS.FileSys.fullPath (p "sublink/c.txt") = OS.FileSys.fullPath (p "sub/c.txt"))
  val () = eqS ("OS.FileSys.realPath/link", top () ^ "/a.txt", fn () => OS.FileSys.realPath (p "link"))
  val () = eqS ("OS.FileSys.realPath/link-then-parent-arc", top (),
                fn () => OS.FileSys.realPath (p "sublink/.."))
  val () = eqB ("OS.FileSys.isLink/loop", true,
                fn () => (symlink ("loop2", "loop1"); symlink ("loop1", "loop2"); OS.FileSys.isLink (p "loop1")))
  (* "It raises SysErr if, for example, ... there is a link loop." *)
  val () = T.raises ("OS.FileSys.fullPath/link-loop-SysErr", isSysErr, fn () => OS.FileSys.fullPath (p "loop1"))
  val () = T.raises ("OS.FileSys.fullPath/dangling-SysErr", isSysErr, fn () => OS.FileSys.fullPath (p "dangling"))
  val () = T.raises ("OS.FileSys.isDir/dangling-SysErr", isSysErr, fn () => OS.FileSys.isDir (p "dangling"))
  (*>> links *)

  (*<< hard-links *)
  (* A second name of top/b.txt, made with Posix.FileSys.link. *)
  val () = eqB ("OS.FileSys.fileId/hard-link", true,
                fn () => (Posix.FileSys.link {old = p "b.txt", new = p "hard.txt"}; id (p "hard.txt") = id (p "b.txt")))
  (* "If new and old refer to the same file, rename does nothing." *)
  val () = eqB ("OS.FileSys.rename/two-names-of-one-file", true,
                fn () => (OS.FileSys.rename {old = p "hard.txt", new = p "b.txt"};
                          exists (p "hard.txt") andalso exists (p "b.txt")))
  val () = eqB ("OS.FileSys.hash/hard-link", true,
                fn () => OS.FileSys.hash (id (p "hard.txt")) = OS.FileSys.hash (id (p "b.txt")))
  (*>> hard-links *)

  (*<< permissions *)
  (* The permission bits set with Posix.FileSys.chmod, for a process that is
     not the super-user (who may read and write whatever the bits say). *)
  fun super () = Posix.ProcEnv.getuid () = Posix.ProcEnv.wordToUid 0w0
  fun chmod (name, bits) = Posix.FileSys.chmod (p name, Posix.FileSys.S.flags bits)
  val () = eqB ("OS.FileSys.A_EXEC/without-execute-bit", false,
                fn () => (write (p "perm.txt", "#!/bin/sh\n"); chmod ("perm.txt", [Posix.FileSys.S.irusr, Posix.FileSys.S.iwusr]);
                          OS.FileSys.access (p "perm.txt", [OS.FileSys.A_EXEC])))
  val () = eqB ("OS.FileSys.A_EXEC/with-execute-bit", true,
                fn () => (chmod ("perm.txt", [Posix.FileSys.S.irwxu]); OS.FileSys.access (p "perm.txt", [OS.FileSys.A_EXEC])))
  val () = eqB ("OS.FileSys.A_EXEC/directory-search-bit", true,
                fn () => (chmod ("sub", [Posix.FileSys.S.irwxu]); OS.FileSys.access (p "sub", [OS.FileSys.A_EXEC])))
  val () = eqB ("OS.FileSys.A_WRITE/read-only", false,
                fn () => (chmod ("perm.txt", [Posix.FileSys.S.irusr]);
                          not (super ()) andalso OS.FileSys.access (p "perm.txt", [OS.FileSys.A_WRITE])))
  val () = eqB ("OS.FileSys.A_READ/read-only", true, fn () => OS.FileSys.access (p "perm.txt", [OS.FileSys.A_READ]))
  val () = eqB ("OS.FileSys.access/conjunction-read-only", false,
                fn () => not (super ()) andalso OS.FileSys.access (p "perm.txt", [OS.FileSys.A_READ, OS.FileSys.A_WRITE]))
  val () = eqB ("OS.FileSys.A_READ/write-only", false,
                fn () => (chmod ("perm.txt", [Posix.FileSys.S.iwusr]);
                          not (super ()) andalso OS.FileSys.access (p "perm.txt", [OS.FileSys.A_READ])))
  val () = eqB ("OS.FileSys.A_WRITE/write-only", true, fn () => OS.FileSys.access (p "perm.txt", [OS.FileSys.A_WRITE]))
  val () = eqB ("OS.FileSys.access/exists-without-permissions", true,
                fn () => (chmod ("perm.txt", []); OS.FileSys.access (p "perm.txt", [])))
  val () = eqB ("OS.FileSys.access/conjunction-without-permissions", true, fn () => conjunction (p "perm.txt"))
  (* "sets the modification and access time of file path" *)
  val () = eqTimeOf ("OS.FileSys.setTime/access-time", t2001,
                     fn () => (OS.FileSys.setTime (p "b.txt", SOME (t2001 ())); Posix.FileSys.ST.atime (Posix.FileSys.stat (p "b.txt"))))
  (* "The named file will be readable and writable by the creating process,
     but, if the host operating systems supports it, not accessible by other
     users." *)
  val () = eqB ("OS.FileSys.tmpName/not-for-other-users", false,
                fn () => Posix.FileSys.S.anySet (Posix.FileSys.S.flags [Posix.FileSys.S.irwxg, Posix.FileSys.S.irwxo],
                                                 Posix.FileSys.ST.mode (Posix.FileSys.stat (newTmp ()))))
  (*>> permissions *)

  (* ---- rmDir: "It raises SysErr if, for example, s does not exist ... or if
     the directory is not empty." ---- *)
  val () = T.raises ("OS.FileSys.rmDir/not-empty-SysErr", isSysErr, fn () => OS.FileSys.rmDir (p "sub"))
  val () = eqB ("OS.FileSys.rmDir/not-empty-kept", true,
                fn () => ((OS.FileSys.rmDir (p "sub") handle OS.SysErr _ => ()); OS.FileSys.isDir (p "sub")))
  val () = T.raises ("OS.FileSys.rmDir/missing-SysErr", isSysErr, fn () => OS.FileSys.rmDir (p "none"))
  val () = T.raises ("OS.FileSys.rmDir/file-SysErr", isSysErr, fn () => OS.FileSys.rmDir (p "a.txt"))
  val () = T.raises ("OS.FileSys.rmDir/empty-SysErr", isSysErr, fn () => OS.FileSys.rmDir "")
  val () = eqB ("OS.FileSys.rmDir/empty-directory", false,
                fn () => (OS.FileSys.mkDir (p "gone"); OS.FileSys.rmDir (p "gone"); exists (p "gone")))

  (* ---- cleaning up: what the test made is removed with remove and rmDir ---- *)
  fun removeTree d =
    (List.app (fn n => let val q = d ^ "/" ^ n
                       in if OS.FileSys.isLink q then OS.FileSys.remove q
                          else if OS.FileSys.isDir q then removeTree q
                          else OS.FileSys.remove q
                       end)
              (entries d);
     OS.FileSys.rmDir d)
  val () = eqB ("OS.FileSys.remove/tmpName-files", false,
                fn () => (List.app OS.FileSys.remove (!tmpNames); List.exists exists (!tmpNames)))
  val () = eqB ("OS.FileSys.rmDir/everything", false, fn () => (removeTree (top ()); exists (top ())))
end

(* Entry point of rhc, the haskell98 roadmap's compiler: compiled by rune
   after the sources of rhc.build. Rune alone builds it (D42). A status
   other than 0 and 1 is a program's own, from `exit`, given as it is. *)
val () = Pass.instructions := (fn () => #instructions (Runtime.stats ()))
(* a file's stat, for the memos of a compile in units (UnitStore.stat), and
   what trim asks of a file of a store (UnitStore.lstat), as rune's are *)
val () = UnitStore.stat := (fn p =>
  (let val st = Posix.FileSys.stat p
   in SOME (UnitStore.stampOf {dev = Posix.FileSys.devToWord (Posix.FileSys.ST.dev st),
                               ino = Posix.FileSys.inoToWord (Posix.FileSys.ST.ino st), size = Posix.FileSys.ST.size st,
                               mtime = Posix.FileSys.ST.mtime st, ctime = Posix.FileSys.ST.ctime st})
   end)
  handle OS.SysErr _ => NONE | Overflow => NONE)
val () = UnitStore.lstat := SOME (fn p =>
  let val st = Posix.FileSys.lstat p
  in
    (if Posix.FileSys.ST.isLink st then UnitStore.Link else if Posix.FileSys.ST.isDir st then UnitStore.Directory else UnitStore.File,
     Posix.FileSys.ST.size st, Posix.FileSys.ST.mtime st)
  end)
val status = RhcMain.main (CommandLine.name (), CommandLine.arguments ())
val _ =
  if status = 0 then OS.Process.exit OS.Process.success
  else if status = 1 then OS.Process.exit OS.Process.failure
  else (TextIO.flushOut TextIO.stdOut; TextIO.flushOut TextIO.stdErr; Posix.Process.exit (Word8.fromInt status))

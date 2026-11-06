(* Entry point for the self-hosted build: compiled by rune after the sources of rune.build. *)
val () = Pass.liveBytes := (fn () => (Runtime.collect (); #live (Runtime.stats ())))
val () = Pass.instructions := (fn () => #instructions (Runtime.stats ()))
(* a file's stat, for the memos of a warm build (UnitStore.stat) *)
val () = UnitStore.stat := (fn p =>
  (let val st = Posix.FileSys.stat p
   in SOME (UnitStore.stampOf {dev = Posix.FileSys.devToWord (Posix.FileSys.ST.dev st),
                               ino = Posix.FileSys.inoToWord (Posix.FileSys.ST.ino st), size = Posix.FileSys.ST.size st,
                               mtime = Posix.FileSys.ST.mtime st, ctime = Posix.FileSys.ST.ctime st})
   end)
  handle OS.SysErr _ => NONE | Overflow => NONE)
(* what trim asks of a file of a store, in one lstat (UnitStore.lstat) *)
val () = UnitStore.lstat := SOME (fn p =>
  let val st = Posix.FileSys.lstat p
  in
    (if Posix.FileSys.ST.isLink st then UnitStore.Link else if Posix.FileSys.ST.isDir st then UnitStore.Directory else UnitStore.File,
     Posix.FileSys.ST.size st, Posix.FileSys.ST.mtime st)
  end)
val _ = OS.Process.exit (Serve.main (CommandLine.name (), CommandLine.arguments ()))

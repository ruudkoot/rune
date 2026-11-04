(* Entry point of runedoc for the self-hosted build: compiled by rune after the sources of runedoc.build. *)
(* a file's stat, by which a library's index in the store is believed (UnitStore.stat; LibraryIndex) *)
val () = UnitStore.stat := (fn p =>
  (let val st = Posix.FileSys.stat p
   in SOME (UnitStore.stampOf {dev = Posix.FileSys.devToWord (Posix.FileSys.ST.dev st),
                               ino = Posix.FileSys.inoToWord (Posix.FileSys.ST.ino st), size = Posix.FileSys.ST.size st,
                               mtime = Posix.FileSys.ST.mtime st, ctime = Posix.FileSys.ST.ctime st})
   end)
  handle OS.SysErr _ => NONE | Overflow => NONE)
val _ = OS.Process.exit (DocMain.main (CommandLine.name (), CommandLine.arguments ()))

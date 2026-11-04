(* The Rune host adapter contains execution, not compiler semantics. *)
structure CompilerApiPlatform =
struct
  (* Captured before client code can link more units. Ordinary unit builds
     initialize the compiler's library dependencies before this adapter.
     Runtime's inventory itself makes no initialization guarantee. *)
  val inherited =
    let val sources=RuneRuntime.linkedUnitSources ()
    in List.map (fn identity => (identity,Option.map #2 (List.find (fn (id,_) => id=identity) sources)))
         (Runtime.linkedUnits ()) end
  (* a file's stat, by which a library's index is believed where its files
     are as they were (UnitStore.stat; LibraryIndex), as rune's own main has it *)
  val () = UnitStore.stat := (fn p =>
    (let val st = Posix.FileSys.stat p
     in SOME (UnitStore.stampOf {dev = Posix.FileSys.devToWord (Posix.FileSys.ST.dev st),
                                 ino = Posix.FileSys.inoToWord (Posix.FileSys.ST.ino st), size = Posix.FileSys.ST.size st,
                                 mtime = Posix.FileSys.ST.mtime st, ctime = Posix.FileSys.ST.ctime st})
     end)
    handle OS.SysErr _ => NONE | Overflow => NONE)
  fun link bytes = Runtime.link (Byte.stringToBytes bytes)
  val current = RuneRuntime.linkedUnitSources
  fun prepare usesLibraries =
    if usesLibraries andalso null inherited then
      raise Fail "compiler-library execution with libraries requires a host built with --units"
    else ()
end

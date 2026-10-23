val [libraryPath, image] = CommandLine.arguments ()
fun check(label,b)=if b then () else raise Fail label
val library = RuneForeign.openLibrary libraryPath
val out = TextIO.openOut image
val () = (TextIO.output(out,"preserve\n");TextIO.closeOut out)
val blocked = ((ignore(Runtime.save image);false) handle OS.SysErr _ => true)
val input = TextIO.openIn image
val contents = TextIO.inputAll input before TextIO.closeIn input
val () = check("save rejects before truncation",blocked andalso contents="preserve\n")
val () = check("restore rejects with live resources",((Runtime.restore image;false) handle OS.SysErr _ => true))
val () = check("fork rejects with live resources",((case Posix.Process.fork() of
  NONE => OS.Process.exit OS.Process.failure | SOME pid => (ignore(Posix.Process.waitpid(Posix.Process.W_CHILD pid,[]));false))
  handle OS.SysErr _ => true))
val () = RuneForeign.release library
val phase = Runtime.save image
val stale = ((ignore(RuneForeign.symbol(library,"rf_i64"));false) handle RuneForeign.Error _ => true)
val () = check("closed tombstone remains stale",stale)
val () = print (case phase of Runtime.Saved => "PASS foreign lifecycle: rejected live state, saved closed state\n"
                            | Runtime.Restored => "PASS foreign lifecycle: restored closed state, stale resource rejected\n")

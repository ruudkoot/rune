(* Started by the independent wide-API helper, including a lone surrogate.
   Fail with an exit status as well as a message, for the outer runner. *)
fun check (name, yes) =
  if yes then print ("PASS windows.text/" ^ name ^ "\n") else raise Fail name
val odd = "\237\160\128-x-\237\191\191"
val () = check ("vm-wide-arguments", CommandLine.arguments () = [odd, "", "a b", "quote\"x", "tail\\"])
val () = check ("vm-wide-environment", OS.Process.getEnv "RuneTextInherited" = SOME odd
                                         andalso Posix.ProcEnv.getenv "RuneTextInherited" = SOME odd)
fun ill f = (ignore (f "\255"); false) handle OS.SysErr (_, SOME e) => OS.errorName e = "ilseq" | _ => false
val () = check ("vm-environment-errors", ill OS.Process.getEnv andalso ill Posix.ProcEnv.getenv)
val () = check ("vm-missing-clears-error", OS.Process.getEnv "RuneTextNeverSet" = NONE)
val () = check ("vm-malformed-file-access",
  (ignore (OS.FileSys.access ("\255", [])); false) handle OS.SysErr (_, SOME e) => OS.errorName e = "ilseq" | _ => false)
val here = OS.FileSys.getDir ()
val base = OS.FileSys.tmpName ()
val () = check ("vm-native-filesystem-paths", OS.Path.getVolume here <> "" andalso
  OS.Path.isCanonical here andalso OS.Path.isAbsolute base andalso
  OS.Path.getVolume base <> "" andalso String.isSubstring "\\" here andalso
  String.isSubstring "\\" base andalso not (String.isPrefix "/" base))
val () = (OS.FileSys.remove base; OS.FileSys.mkDir base)
val piece = "abcdefghijabcdefghijabcdefghijabcdefghij\206\187"
fun deep (path, 0) = path
  | deep (path, n) = let val next = OS.Path.concat (path, piece) in OS.FileSys.mkDir next; deep (next, n - 1) end
val deepest = deep (base, 29)
val file = OS.Path.concat (deepest, odd)
val out = TextIO.openOut file
val () = (TextIO.output (out, "prefix"); TextIO.closeOut out)
val input = TextIO.openIn file
val () = check ("vm-long-open", TextIO.inputN (input, 2) = "pr")
val stream = OS.FileSys.openDir deepest
val first = OS.FileSys.readDir stream
val child = Posix.Process.fork ()
val () =
  case child of
    NONE =>
      (check ("vm-fork-directory", first = SOME odd andalso OS.FileSys.readDir stream = NONE);
       check ("vm-fork-reopen", TextIO.inputAll input = "efix");
       OS.Process.exit OS.Process.success)
  | SOME pid =>
      let val (_, status) = Posix.Process.waitpid (Posix.Process.W_CHILD pid, [])
      in check ("vm-fork-status", status = Posix.Process.W_EXITED) end
val () = (OS.FileSys.closeDir stream; TextIO.closeIn input)
val () = OS.FileSys.remove file
fun clean (path, 0) = OS.FileSys.rmDir path
  | clean (path, n) = (OS.FileSys.rmDir path; clean (OS.Path.dir path, n - 1))
val () = clean (deepest, 29)
val () = check ("vm-current-directory", OS.FileSys.getDir () = here)

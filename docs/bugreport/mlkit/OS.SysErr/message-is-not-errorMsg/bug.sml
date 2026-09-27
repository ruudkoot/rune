(* "if a SysErr exception has the form SysErr(s,SOME e), then we have
   errorMsg e = s" *)
fun check name f =
  (f (); print (name ^ ": no exception\n"))
  handle OS.SysErr (s, SOME e) =>
           print (name ^ ": SysErr (\"" ^ s ^ "\", SOME e), errorMsg e = \"" ^ OS.errorMsg e ^ "\": "
                  ^ (if OS.errorMsg e = s then "equal" else "DIFFERENT") ^ "\n")
       | IO.Io {cause = OS.SysErr (s, SOME e), ...} =>
           print (name ^ ": Io with SysErr (\"" ^ s ^ "\", SOME e), errorMsg e = \"" ^ OS.errorMsg e ^ "\": "
                  ^ (if OS.errorMsg e = s then "equal" else "DIFFERENT") ^ "\n")
val () = check "OS.FileSys.remove" (fn () => OS.FileSys.remove "no-such-file")
val () = check "OS.FileSys.chDir" (fn () => OS.FileSys.chDir "no-such-dir")
val () = check "TextIO.openIn" (fn () => TextIO.closeIn (TextIO.openIn "no-such-file"))
val () = check "Posix.FileSys.opendir" (fn () => ignore (Posix.FileSys.opendir "no-such-dir"))

(* Native host path syntax, as required by OS.Path in the Basis specification. *)
fun check yes = if yes then () else raise Fail "host path syntax"
val windows = OS.Path.validVolume {isAbs=true,vol="C:"}
val () = if windows then
  (check (OS.Path.fromString "C:\\a\\b" = {isAbs=true,vol="C:",arcs=["a","b"]});
   check (OS.Path.isRelative "C:a");
   check (OS.Path.mkCanonical "C:/A/../B" = "c:\\b");
   check (OS.Path.mkRelative {path="C:\\a\\b",relativeTo="c:\\a"} = "b");
   check ((OS.Path.concat ("C:a","D:b"); false) handle OS.Path.Path => true);
   check (OS.Path.getVolume (OS.FileSys.getDir ()) <> "");
   check (OS.Path.isAbsolute (OS.FileSys.getDir ())))
  else
  (check (OS.Path.fromString "C:\\a\\b" = {isAbs=false,vol="",arcs=["C:\\a\\b"]});
   check (OS.Path.fromUnixPath "/a/b" = "/a/b"))
val () = print "host paths: ok\n"

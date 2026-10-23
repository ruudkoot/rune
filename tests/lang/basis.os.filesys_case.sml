(* Native path spelling must keep mixed-case objects usable on Windows,
   including case-sensitive directories and WSL shares. *)
fun check yes = if yes then () else raise Fail "native path case"
val root=OS.FileSys.tmpName ()
val ()=(OS.FileSys.remove root;OS.FileSys.mkDir root)
val directory=OS.Path.concat (root,"MiXeD-Dir")
val ()=OS.FileSys.mkDir directory
val file=OS.Path.concat (directory,"MiXeD-Case.txt")
val output=TextIO.openOut file
val ()=(TextIO.output (output,"case\n");TextIO.closeOut output)
val here=OS.FileSys.getDir ()
fun clean ()=(OS.FileSys.chDir here;OS.FileSys.remove file;OS.FileSys.rmDir directory;OS.FileSys.rmDir root)
fun work ()=
  let val full=OS.FileSys.fullPath file
      val ()=check (String.isSuffix "MiXeD-Case.txt" full andalso OS.Path.isCanonical full)
      val ()=check (OS.FileSys.fileId full=OS.FileSys.fileId file)
      val ()=OS.FileSys.chDir directory
      val current=OS.FileSys.getDir ()
      val ()=check (String.isSuffix "MiXeD-Dir" current andalso OS.Path.isCanonical current)
      val ()=check (OS.FileSys.realPath "MiXeD-Case.txt"="MiXeD-Case.txt")
      val ()=if OS.Path.validVolume {isAbs=true,vol="C:"} then
          check (OS.Path.mkRelative {path="C:\\Upper\\File",relativeTo="c:\\upper"}="..\\Upper\\File") else ()
  in print "native path case: ok\n" end
val ()=(work () before clean ()) handle error => (clean () handle _ => ();raise error)

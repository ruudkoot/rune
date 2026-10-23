structure RuneLspWorkspaceTests =
struct
  structure W=RuneLspWorkspace
  structure D=RuneLspDocuments
  structure U=LspUri
  val check=Expect.that
  fun remove path=OS.FileSys.remove path handle _ => ()
  fun write (path,text)=let val out=TextIO.openOut path in TextIO.output (out,text);TextIO.closeOut out end
  fun uri path=U.original (U.fromPath (U.Posix,path))
  fun fixture action =
    let val dir=OS.FileSys.tmpName ()
        val ()=(remove dir;OS.FileSys.mkDir dir)
        fun clean path=if OS.FileSys.isDir path then
          let val stream=OS.FileSys.openDir path
              fun all ()=case OS.FileSys.readDir stream of NONE => () | SOME name => (clean (OS.Path.concat (path,name));all ())
          in all ();OS.FileSys.closeDir stream;OS.FileSys.rmDir path end else remove path
    in (action dir before clean dir) handle e => (clean dir handle _ => ();raise e) end
  fun contexts () = fixture (fn root =>
    let val ()=List.app OS.FileSys.mkDir [root ^ "/one",root ^ "/two",root ^ "/one/included",root ^ "/one/sub"]
        val first=root ^ "/one/first.build"
        val second=root ^ "/one/second.build"
        val a=root ^ "/one/a.sml"
        val b=root ^ "/one/sub/b.sml"
        val c=root ^ "/two/c.sml"
        val ()=List.app write
          [(first,"files a.sml end\nuse included/part.build\n"),(second,"files sub/b.sml end\n"),
           (root ^ "/one/included/part.build","files ../sub/b.sml end\n"),
           (root ^ "/two/third.build","files c.sml end\n"),(a,"val a=1\n"),(b,"val b=2\n"),(c,"val c=3\n"),
           (root ^ "/one/sub/deep.build","files unrelated.sml end\n")]
        val workspace=W.new {platform=U.Posix,lib="lib"}
        val documents=D.new (LspProtocol.Utf16,{maxDocuments=3,maxDocumentBytes=10000,maxTotalBytes=20000,maxDocumentLines=1000,maxTotalLines=2000})
        val ()=W.setRoots (workspace,[uri (root ^ "/one"),uri (root ^ "/two")])
        val _=D.openDocument (documents,{uri=uri a,languageId="sml",version=1,text="val a=4\n"})
        val ()=check ("one context selected",case W.select (workspace,documents,uri a) of W.Selected _ => true | _ => false)
        val alternatives=case W.select (workspace,documents,uri b) of W.Ambiguous values => values | _ => []
        val ()=check ("multiple build contexts stay ambiguous",length alternatives=2)
        val chosen=hd alternatives
        val ()=W.choose (workspace,uri b,#id chosen)
        val ()=check ("explicit context choice",case W.select (workspace,documents,uri b) of
          W.Selected context => #id context= #id chosen | _ => false)
        val ()=W.dirty workspace
        val ()=check ("edits retain context choice",case W.select (workspace,documents,uri b) of W.Selected _ => true | _ => false)
        val ()=W.configureAt (workspace,uri c,Json.Object [])
        val ()=check ("unrelated scoped settings retain context choice",case W.select (workspace,documents,uri b) of
          W.Selected context => #id context= #id chosen | _ => false)
        val ()=check ("independent workspace root",case W.select (workspace,documents,uri c) of W.Selected _ => true | _ => false)
        val ()=check ("discovery does not scan descendants",not (List.exists (fn file => file=root ^ "/one/sub/deep.build") (W.discover (workspace,a))))
        val settings=Json.Object [("activeContext",Json.String "first"),("targets",Json.Array
          [Json.Object [("name",Json.String "first"),("build",Json.String (uri first))],
           Json.Object [("name",Json.String "second"),("build",Json.String (uri second))]])]
        val ()=W.configure (workspace,settings)
        val ()=check ("configured target selection",case W.select (workspace,documents,uri b) of
          W.Selected context => #target context="first" | _ => false)
        val generation=W.generation workspace
        val rejected=((W.configure (workspace,Json.Object [("sourceMode",Json.String "invalid")]);false) handle W.Invalid _ => true)
    in check ("configuration is atomic",rejected andalso W.generation workspace=generation) end)
end
structure RuneLspWorkspaceTestMain = Main (struct
  val name="lsp-workspace"
  val tests=Test.describe "lsp-workspace" [Test.it "contexts" RuneLspWorkspaceTests.contexts]
end)
val ()=RuneLspWorkspaceTestMain.main ()

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
  (* D28: the files a client's watcher names, by the generation each event
     made; a plan older than the last kept looks at the disk instead *)
  fun changes () =
    let val workspace=W.new {platform=U.Posix,lib="lib"}
        val start=W.inputGeneration workspace
        val ()=W.changed (workspace,[(uri "/w/a.sml",false),(uri "/w/b.build",true)])
        val middle=W.inputGeneration workspace
        val ()=W.changed (workspace,[(uri "/w/c.sml",false)])
        val ()=check ("each event moves the input generation",IntInf.> (middle,start))
        val ()=check ("a plan sees what changed since it, and what came or went",
          W.changedSince (workspace,start)=SOME [("/w/c.sml",false),("/w/a.sml",false),("/w/b.build",true)]
          andalso W.changedSince (workspace,middle)=SOME [("/w/c.sml",false)])
        val ()=W.changed (workspace,List.tabulate (W.changeLimit,fn i => (uri ("/w/many" ^ Int.toString i ^ ".sml"),false)))
        val ()=check ("past the last kept, a plan is told nothing, and looks",W.changedSince (workspace,start)=NONE)
        val ()=check ("one made since the last is told",isSome (W.changedSince (workspace,W.inputGeneration workspace)))
        val ()=W.changed (workspace,[("untitled:scratch",false)])
        val ()=check ("an event of no file tells every plan to look",W.changedSince (workspace,W.inputGeneration workspace-1)=NONE)
    in check ("a key without ..",W.lexical "/w/x/../y/./z.sml"=SOME "/w/y/z.sml" andalso W.lexical "/../z"=NONE) end
  (* An event names a file by its path; a key with .. names it so only where
     no symbolic link to a directory comes before the .. *)
  fun eventKeys () = fixture (fn root =>
    let val ()=List.app OS.FileSys.mkDir [root ^ "/real",root ^ "/real/deep",root ^ "/sub"]
        val ()=List.app write [(root ^ "/x.build","files end\n"),(root ^ "/real/x.build","files end\n")]
        val ()=Posix.FileSys.symlink {old=root ^ "/real/deep",new=root ^ "/link"}
        val direct=W.eventKey U.Posix (root ^ "/sub/../x.build")
        val linked=W.eventKey U.Posix (root ^ "/link/../x.build")
        val ()=OS.FileSys.remove (root ^ "/link")
    in check ("a path through a directory and back names its file",direct=SOME (W.pathKey U.Posix (root ^ "/x.build")));
       check ("one back out of a symbolic link names none",linked=NONE);
       check ("a path without .. is its key",W.eventKey U.Posix (root ^ "/x.build")=SOME (W.pathKey U.Posix (root ^ "/x.build"))) end)
  (* A root file's targets come first, named, and what discovery finds beside
     them stays, whether the client's folder holds the root file or is
     inside the workspace (M3's root above a folder). *)
  fun namedTargets () = fixture (fn root =>
    let val ()=List.app OS.FileSys.mkDir [root ^ "/src",root ^ "/src/inner"]
        val a=root ^ "/src/a.sml"
        val ()=List.app write
          [(root ^ "/rune.workspace","roots lib end\ntarget main = src/main.build \"--target=stack\" end\n"),
           (root ^ "/src/main.build","files a.sml end\n"),(root ^ "/src/other.build","files a.sml end\n"),
           (root ^ "/src/inner/b.sml","val b=1\n"),(root ^ "/src/inner/b.build","files b.sml end\n"),(a,"val a=1\n")]
        val workspace=W.new {platform=U.Posix,lib="lib"}
        val documents=D.new (LspProtocol.Utf16,{maxDocuments=3,maxDocumentBytes=10000,maxTotalBytes=20000,maxDocumentLines=1000,maxTotalLines=2000})
        val ()=W.setRoots (workspace,[uri root])
        val found=W.contexts (workspace,documents,uri a)
        val ()=check ("a root file's target, then the build it does not name",
          List.map #target found=["main",uri (root ^ "/src/other.build")])
        val ()=check ("a target's options",case found of first :: _ => #build first=uri (root ^ "/src/main.build") | [] => false)
        val inner=W.new {platform=U.Posix,lib="lib"}
        val ()=W.setRoots (inner,[uri (root ^ "/src/inner")])
        val ()=check ("a folder inside a workspace still has its own builds",
          List.map #target (W.contexts (inner,documents,uri (root ^ "/src/inner/b.sml")))=[uri (root ^ "/src/inner/b.build")])
        val below=W.new {platform=U.Posix,lib="lib"}
        val ()=W.setRoots (below,[uri (root ^ "/src")])
        val ()=check ("a root file above the client's folder gives its targets",
          List.map #target (W.contexts (below,documents,uri a))=["main",uri (root ^ "/src/other.build")])
        val _=D.openDocument (documents,{uri=uri (root ^ "/rune.workspace"),languageId="rune-build",version=1,
          text="roots lib end\ntarget alternative = src/other.build end\n"})
    in check ("a root file open in the editor is read as it stands, unsaved",
         List.map #target (W.contexts (workspace,documents,uri a))=["alternative",uri (root ^ "/src/main.build")]) end)
  fun shortNames ()=List.app (fn (name,short) => check (name ^ " shows as " ^ short,W.shortName (U.Posix,name)=short))
    [("file:///project/one.build","one.build"),("file:///a%20b/two%20words.build","two words.build"),
     ("rune","rune"),("loose source","loose source"),("untitled:note","untitled:note")]
  val plain=W.defaults
  fun named name:W.settings={targets=[],flags=[],variables=[],activeContext=SOME name,libraryRoot=NONE}
  fun active (workspace,address)= #activeContext (W.configurationFor (workspace,address))
  fun scopes () =
    let val workspace=W.new {platform=U.Posix,lib="lib"}
        val ()=W.assign (workspace,[("file:///a",named "a"),("file:///a/b/",named "b"),("file:///a/b/c",named "c"),
          ("untitled:note",named "note")])
        val ()=check ("a scope's own URI",active (workspace,"file:///a/b/c")=SOME "c")
        val ()=check ("a scope with no native key, by URI",active (workspace,"untitled:note")=SOME "note")
        val ()=check ("the nearest directory wins",active (workspace,"file:///a/b/d.sml")=SOME "b")
        val ()=check ("a directory with no slash",active (workspace,"file:///a/z.sml")=SOME "a")
        val ()=check ("a longer name is not below a directory",active (workspace,"file:///ab/z.sml")=NONE
          andalso active (workspace,"file:///a/bb")=SOME "a")
        val ()=check ("outside every scope",active (workspace,"file:///other.sml")=NONE
          andalso active (workspace,"untitled:other")=NONE)
        val ()=W.assign (workspace,[("file:///a/./b/",named "older"),("file:///a/b/./",named "newest")])
        val ()=check ("of two spellings of a directory, the newest",active (workspace,"file:///a/b/d.sml")=SOME "newest")
        val ()=W.forget (workspace,"file:///a/b/./")
        val ()=check ("forgetting a spelling leaves the one before it",active (workspace,"file:///a/b/d.sml")=SOME "older")
        val ()=W.forget (workspace,"file:///a/./b/")
        val ()=W.forget (workspace,"file:///a/b/")
        val ()=check ("forgetting a scope goes to the one above it",active (workspace,"file:///a/b/d.sml")=SOME "a")
        val ()=W.configureAt (workspace,"file:///a/b/d.sml",Json.Object [("activeContext",Json.String "set")])
        val ()=check ("a scope set alone is found",active (workspace,"file:///a/b/d.sml")=SOME "set")
        val ()=W.configureAt (workspace,"file:///a/b/d.sml",Json.Null)
    in check ("a scope cleared alone is gone",active (workspace,"file:///a/b/d.sml")=SOME "a") end
  (* E20: at 1,001 scopes a call parsed 1,001 URIs and allocated 27 MB. *)
  fun scopeCost () =
    let fun cost count =
          let val workspace=W.new {platform=U.Posix,lib="lib"}
              val ()=W.assign (workspace,List.tabulate (count,fn i => (uri ("/project/src/file" ^ Int.toString i ^ ".sml"),plain)))
              val ()=check ("the index is made before it is measured",active (workspace,uri "/project/src/file0.sml")=NONE)
              val files=List.tabulate (200,fn i => uri ("/project/lib/deep/file" ^ Int.toString i ^ ".sml"))
              val (_,{bytes,...})=Runtime.profile (fn () => List.app (fn file => ignore (active (workspace,file))) files)
          in bytes end
    in check ("a file's configuration does not cost the number of scopes",cost 8000<2*cost 500) end
end
structure RuneLspWorkspaceTestMain = Main (struct
  val name="lsp-workspace"
  val tests=Test.describe "lsp-workspace" [Test.it "contexts" RuneLspWorkspaceTests.contexts,
    Test.it "scopes" RuneLspWorkspaceTests.scopes,Test.it "scope-cost" RuneLspWorkspaceTests.scopeCost,
    Test.it "named-targets" RuneLspWorkspaceTests.namedTargets,
    Test.it "short-names" RuneLspWorkspaceTests.shortNames,
    Test.it "file-events" RuneLspWorkspaceTests.changes,Test.it "event-keys" RuneLspWorkspaceTests.eventKeys]
end)
val ()=RuneLspWorkspaceTestMain.main ()

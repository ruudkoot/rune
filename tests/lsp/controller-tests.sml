structure RuneLspControllerTests =
struct
  structure C=RuneLspController
  structure W=RuneLspWorkspace
  structure D=RuneLspDocuments
  structure R=JsonRpc
  val check=Expect.that
  fun object fields=Json.Object fields
  fun caps value=valOf (LspProtocol.capabilities value)
  fun identifier (R.Request {id,...})=id | identifier _=raise Fail "expected server request"
  fun method (R.Request {method,...})=method | method _=""
  fun params (R.Request {params=SOME value,...})=value | params _=raise Fail "missing request params"
  fun field name value=RuneLspSync.required (value,name)
  fun requests sent name=List.filter (fn request => method request=name) (List.rev (!sent))
  fun answer (controller,request,outcome)=C.response (controller,R.Response {id=SOME (identifier request),outcome=outcome})
  fun fixture action =
    let val dir=OS.FileSys.tmpName ()
        val ()=(OS.FileSys.remove dir handle _ => ();OS.FileSys.mkDir dir)
        fun write (file,text)=let val out=TextIO.openOut file in TextIO.output (out,text);TextIO.closeOut out end
        val ()=write (dir ^ "/one.build","files a.sml end\n")
        val ()=write (dir ^ "/two.build","files a.sml end\n")
        val ()=write (dir ^ "/a.sml","val a=1\n")
        fun uri path=LspUri.original (LspUri.fromPath (LspUri.Posix,path))
        fun clean ()=(List.app (fn file => OS.FileSys.remove (dir ^ "/" ^ file)) ["one.build","two.build","a.sml"];OS.FileSys.rmDir dir)
    in (action (dir,uri) before clean ()) handle e => (clean () handle _ => ();raise e) end
  fun configuration () = fixture (fn (dir,uri) =>
    let val documents=D.new (LspProtocol.Utf16,{maxDocuments=3,maxDocumentBytes=1000,maxTotalBytes=3000,maxDocumentLines=100,maxTotalLines=300})
        val document=uri (dir ^ "/a.sml")
        val _=D.openDocument (documents,{uri=document,languageId="sml",version=1,text="val a=1\n"})
        val sent=ref [] : R.message list ref
        val errors=ref [] : string list ref
        val capabilities=caps (object [("workspace",object [("configuration",Json.Bool true)])])
        val initialize=object [("workspaceFolders",Json.Array [object [("uri",Json.String (uri dir)),("name",Json.String "fixture")]])]
        val controller=C.new {platform=LspUri.Posix,lib="lib",documents=documents,caps=capabilities,
          send=fn message => sent:=message :: !sent,log=fn _ => (),error=fn text => errors:=text :: !errors,initialize=initialize}
        val ()=C.initialized controller
        val query=hd (requests sent "workspace/configuration")
        val targets=object [("targets",Json.Array [object [("name",Json.String "one"),("build",Json.String (uri (dir ^ "/one.build")))],
          object [("name",Json.String "two"),("build",Json.String (uri (dir ^ "/two.build")))]])]
        val ()=check ("configuration response owned",answer (controller,query,R.Result (Json.Array [object [],targets])))
        val choice=hd (requests sent "window/showMessageRequest")
        val actions=case field "actions" (params choice) of Json.Array actions => actions | _ => []
        val action=List.nth (actions,1)
        val ()=check ("context response owned",answer (controller,choice,R.Result action))
        val ()=check ("client chooses context explicitly",case W.select (C.workspace controller,documents,document) of
          W.Selected context => #target context="two" | _ => false)
        val ()=check ("late resolve consumed once",not (answer (controller,choice,R.Result action)))
        val ()=check ("no controller errors",null (!errors))
    in C.clear controller end)
  fun watchers () = fixture (fn (dir,uri) =>
    let val documents=D.new (LspProtocol.Utf16,{maxDocuments=1,maxDocumentBytes=1000,maxTotalBytes=1000,maxDocumentLines=100,maxTotalLines=100})
        val sent=ref [] : R.message list ref
        val capabilities=caps (object [("workspace",object [("didChangeWatchedFiles",object
          [("dynamicRegistration",Json.Bool true),("relativePatternSupport",Json.Bool true)])])])
        val initialize=object [("rootUri",Json.String (uri dir))]
        val controller=C.new {platform=LspUri.Posix,lib="lib",documents=documents,caps=capabilities,
          send=fn message => sent:=message :: !sent,log=fn _ => (),error=fn text => raise Fail text,initialize=initialize}
        val ()=C.initialized controller
        val registration=hd (requests sent "client/registerCapability")
        val ()=check ("watch registration reply",answer (controller,registration,R.Result Json.Null))
        val _=C.notification (controller,{method="workspace/didChangeWorkspaceFolders",params=SOME (object
          [("event",object [("added",Json.Array []),("removed",Json.Array [object [("uri",Json.String (uri dir)),("name",Json.String "fixture")]])])])})
        val unregister=hd (requests sent "client/unregisterCapability")
        val ()=check ("watch removal balanced",answer (controller,unregister,R.Result Json.Null))
    in C.clear controller end)
  fun staleConfiguration () =
    let val documents=D.new (LspProtocol.Utf16,{maxDocuments=1,maxDocumentBytes=1000,maxTotalBytes=1000,maxDocumentLines=100,maxTotalLines=100})
        val uri="untitled:scoped"
        val _=D.openDocument (documents,{uri=uri,languageId="sml",version=1,text="val x=1\n"})
        val sent=ref [] : R.message list ref
        val capabilities=caps (object [("workspace",object [("configuration",Json.Bool true)])])
        val controller=C.new {platform=LspUri.Posix,lib="lib",documents=documents,caps=capabilities,
          send=fn message => sent:=message :: !sent,log=fn _ => (),error=fn text => raise Fail text,initialize=object []}
        val ()=C.initialized controller
        val old=hd (requests sent "workspace/configuration")
        val _=C.notification (controller,{method="workspace/didChangeConfiguration",params=SOME (object [])})
        val current=List.last (requests sent "workspace/configuration")
        fun settings name=R.Result (Json.Array [object [("activeContext",Json.String name)]])
        val _=answer (controller,old,settings "stale")
        val ()=check ("old configuration response ignored",#activeContext (W.configurationFor (C.workspace controller,uri))=NONE)
        val _=answer (controller,current,settings "current")
        val ()=check ("current scoped configuration applied",#activeContext (W.configurationFor (C.workspace controller,uri))=SOME "current")
        val _=C.configuration (controller,[uri])
        val late=List.last (requests sent "workspace/configuration")
        val ()=D.closeDocument (documents,uri)
        val _=answer (controller,late,settings "late")
    in check ("closed scope not replaced by late response",#activeContext (W.configurationFor (C.workspace controller,uri))=SOME "current");
       C.clear controller end
end
structure RuneLspControllerTestMain = Main (struct
  val name="lsp-controller"
  val tests=Test.describe "lsp-controller"
    [Test.it "configuration-and-context" RuneLspControllerTests.configuration,
     Test.it "watchers" RuneLspControllerTests.watchers,
     Test.it "stale-configuration" RuneLspControllerTests.staleConfiguration]
end)
val ()=RuneLspControllerTestMain.main ()

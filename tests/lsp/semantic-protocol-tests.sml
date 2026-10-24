structure RuneLspSemanticProtocolTests =
struct
  structure C=RuneLspTestClient
  val check=Expect.that
  fun object fields=Json.Object fields
  fun document uri=object [("uri",Json.String uri)]
  fun textValue (Json.String value)=value | textValue _=raise Fail "expected string"
  fun launchArguments ("--filter"::_::rest)=launchArguments rest
    | launchArguments (arg::rest)=arg::launchArguments rest | launchArguments []=[]
  fun fixtureInitializedResult initialization action =
    let val (program,args)=case launchArguments(CommandLine.arguments ()) of [vm,server,worker] => (vm,[server,vm,worker])
          | [vm,server] => (vm,[server]) | [program] => (program,[])
          | _ => raise Fail "semantic protocol tests require server launch arguments"
        val client=C.start (program,args)
        fun work () =
          let val ()=C.request (client,1,"initialize",initialization)
              val initializationResult=C.result (C.response (client,1))
              val ()=C.notify (client,"initialized",object [])
              val ()=action (client,initializationResult)
              val ()=C.request (client,9000,"shutdown",Json.Null)
              val ()=check ("shutdown response",C.result (C.response (client,9000))=Json.Null)
              val ()=C.notify (client,"exit",Json.Null)
          in () end
    in (work () before C.close client) handle error => (C.close client;raise error) end
  fun fixtureInitialized initialization action=fixtureInitializedResult initialization (fn (client,_) => action client)
  fun fixtureWith capabilities action=fixtureInitialized (object [("capabilities",capabilities)]) action
  fun fixture action=fixtureWith (object []) action
  fun openDocument (client,uri,text)=C.notify (client,"textDocument/didOpen",object [("textDocument",object
    [("uri",Json.String uri),("languageId",Json.String "sml"),("version",Json.int 1),("text",Json.String text)])])
  fun diagnostics client = fixture (fn client =>
    let val uri="untitled:semantic-protocol"
        val ()=openDocument (client,uri,"val bad:int=true\n")
        val pushed=C.receive (client,fn value => Json.member ("method",value)=SOME (Json.String "textDocument/publishDiagnostics"))
        val params=C.field (pushed,"params")
        val ()=check ("push diagnostics without EOF",case C.field (params,"diagnostics") of Json.Array (_::_) => true | _ => false)
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "val answer=42\n")]])])
        val ()=C.request (client,2,"textDocument/diagnostic",object [("textDocument",document uri)])
        val report=C.result (C.response (client,2))
        val ()=check ("pull diagnostics clear errors",C.field (report,"items")=Json.Array [])
        val ()=C.request (client,3,"textDocument/diagnostic",object [("textDocument",document uri),("previousResultId",C.field (report,"resultId"))])
        val unchanged=C.result (C.response (client,3))
        val ()=check ("unchanged report",C.field (unchanged,"kind")=Json.String "unchanged")
        val ()=C.request (client,4,"textDocument/hover",object [("textDocument",document uri),
          ("position",object [("line",Json.int 0),("character",Json.int 4)])])
        val hover=C.result (C.response (client,4))
    in check ("hover uses checked snapshot",C.field (C.field (hover,"contents"),"value")=Json.String "int") end)
  fun cancellation () = fixture (fn client =>
    let val uri="untitled:cancel-protocol"
        val text=String.concat (List.tabulate (10000,fn i => "val x" ^ Int.toString i ^ "=" ^ Int.toString i ^ "\n"))
        val ()=openDocument (client,uri,text)
        val ()=C.request (client,10,"textDocument/hover",object [("textDocument",document uri),
          ("position",object [("line",Json.int 0),("character",Json.int 4)])])
        val ()=C.notify (client,"$/cancelRequest",object [("id",Json.int 10)])
        val cancelled=C.response (client,10)
    in check ("cancellation answered while checking",C.field (C.field (cancelled,"error"),"code")=Json.int (~32800)) end)
  fun pullRefresh () = fixtureWith (object [("textDocument",object [("diagnostic",object [])]),
    ("workspace",object [("diagnostics",object [("refreshSupport",Json.Bool true)])])]) (fn client =>
    let val uri="untitled:pull-refresh"
        val ()=openDocument (client,uri,"val bad:int=true\n")
        val refresh=C.receive (client,fn value => Json.member ("method",value)=SOME (Json.String "workspace/diagnostic/refresh"))
        val ()=C.send (client,object [("jsonrpc",Json.String "2.0"),("id",C.field (refresh,"id")),("result",Json.Null)])
        val ()=C.request (client,30,"textDocument/diagnostic",object [("textDocument",document uri)])
        val report=C.result (C.response (client,30))
        val C.Client {messages,...}=client
        val pushed=List.exists (fn value => Json.member ("method",value)=SOME (Json.String "textDocument/publishDiagnostics")) (!messages)
    in check ("pull client receives refresh without duplicate pushes",not pushed andalso
      (case C.field (report,"items") of Json.Array (_::_) => true | _ => false)) end)
  fun progressCancellation () = fixture (fn client =>
    let val uri="untitled:progress-cancellation"
        val text=String.concat (List.tabulate (10000,fn i => "val x" ^ Int.toString i ^ "=" ^ Int.toString i ^ "\n"))
        val ()=openDocument (client,uri,text)
        val ()=C.request (client,31,"textDocument/diagnostic",object [("textDocument",document uri),
          ("workDoneToken",Json.String "cancel-this-check")])
        val ()=C.notify (client,"window/workDoneProgress/cancel",object [("token",Json.String "cancel-this-check")])
        val response=C.response (client,31)
    in check ("work progress cancellation owns its matching request",
      C.field (C.field (response,"error"),"code")=Json.int (~32800)) end)
  fun staleDiagnostics () = fixture (fn client =>
    let val uri="untitled:stale-diagnostics"
        val text=String.concat (List.tabulate (5000,fn i => "val x" ^ Int.toString i ^ "=" ^ Int.toString i ^ "\n"))
        val ()=openDocument (client,uri,text)
        val ()=C.request (client,40,"textDocument/diagnostic",object [("textDocument",document uri)])
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "val fixed=1\n")]])])
        val answer=C.response (client,40)
        val error=C.field (answer,"error")
    in check ("stale diagnostic request can be retriggered",C.field (error,"code")=Json.int (~32802)
      andalso C.field (C.field (error,"data"),"retriggerRequest")=Json.Bool true) end)
  fun markup () = fixtureWith (object [("textDocument",object
    [("diagnostic",object [("markupMessageSupport",Json.Bool true)]),
     ("hover",object [("contentFormat",Json.Array [Json.String "markdown"])])])]) (fn client =>
    let val uri="untitled:markup"
        val ()=openDocument (client,uri,"val bad:int=true\n")
        val ()=C.request (client,50,"textDocument/diagnostic",object [("textDocument",document uri)])
        val report=C.result (C.response (client,50))
        val message=case C.field (report,"items") of Json.Array (item::_) => C.field (item,"message") | _ => raise Fail "missing markup diagnostic"
        val ()=check ("diagnostic markup negotiated",C.field (message,"kind")=Json.String "plaintext")
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "val value=42\n")]])])
        val ()=C.request (client,51,"textDocument/hover",object [("textDocument",document uri),
          ("position",object [("line",Json.int 0),("character",Json.int 4)])])
        val hover=C.result (C.response (client,51))
    in check ("hover markup negotiated",C.field (C.field (hover,"contents"),"kind")=Json.String "markdown") end)
  fun fileProject () =
    let val dir=OS.FileSys.tmpName ()
        val ()=(OS.FileSys.remove dir handle _ => ();OS.FileSys.mkDir dir)
        fun write (name,text)=let val output=TextIO.openOut (dir ^ "/" ^ name)
          in TextIO.output (output,text);TextIO.closeOut output end
        val ()=write ("main.build","files main.sml end\n")
        val ()=write ("main.sml","val answer=42\n")
        val platform=if List.exists (fn (key,value) => key="sysname" andalso value="Windows") (Posix.ProcEnv.uname ())
          then LspUri.Windows else LspUri.Posix
        val uri=LspUri.original (LspUri.fromPath (platform,OS.FileSys.fullPath (dir ^ "/main.sml")))
        fun clean ()=(OS.FileSys.remove (dir ^ "/main.build");OS.FileSys.remove (dir ^ "/main.sml");OS.FileSys.rmDir dir)
        fun work ()=fixture (fn client =>
          let val ()=openDocument (client,uri,"val answer=43\n")
              val ()=C.request (client,60,"textDocument/hover",object [("textDocument",document uri),
                ("position",object [("line",Json.int 0),("character",Json.int 4)])])
              val hover=C.result (C.response (client,60))
          in check ("native build context resolves without path rewriting",C.field (C.field (hover,"contents"),"value")=Json.String "int") end)
    in (work () before clean ()) handle error => (clean () handle _ => ();raise error) end
  fun workspaceDiagnostics () =
    let val dir=OS.FileSys.tmpName ()
        val ()=(OS.FileSys.remove dir handle _ => ();OS.FileSys.mkDir dir)
        fun write (name,text)=let val output=TextIO.openOut (dir ^ "/" ^ name)
          in TextIO.output (output,text);TextIO.closeOut output end
        val ()=write ("project.build","files main.sml end\n")
        val ()=write ("main.sml","val bad:int=true\n")
        val platform=if List.exists (fn (key,value) => key="sysname" andalso value="Windows") (Posix.ProcEnv.uname ())
          then LspUri.Windows else LspUri.Posix
        val root=LspUri.original (LspUri.fromPath (platform,OS.FileSys.fullPath dir))
        val uri=LspUri.original (LspUri.fromPath (platform,OS.FileSys.fullPath (dir ^ "/main.sml")))
        fun clean ()=(OS.FileSys.remove (dir ^ "/project.build");OS.FileSys.remove (dir ^ "/main.sml");OS.FileSys.rmDir dir)
        fun work ()=fixtureInitialized (object [("capabilities",object [("textDocument",object [("diagnostic",object [])])]),
          ("workspaceFolders",Json.Array [object [("uri",Json.String root),("name",Json.String "fixture")]])]) (fn client =>
          let val ()=C.request (client,70,"workspace/diagnostic",object [("previousResultIds",Json.Array [])])
              val report=C.result (C.response (client,70))
              val first=case C.field (report,"items") of Json.Array [item] => item | _ => raise Fail "workspace report missing closed source"
              val ()=check ("closed source checked through build model",C.field (first,"uri")=Json.String uri andalso
                (case C.field (first,"items") of Json.Array (_::_) => true | _ => false))
              val ()=C.request (client,72,"workspace/diagnostic",object [("previousResultIds",Json.Array []),
                ("partialResultToken",Json.String "workspace-partial"),("workDoneToken",Json.String "workspace-work")])
              val partial=C.receive (client,fn value => Json.member ("method",value)=SOME (Json.String "$/progress") andalso
                (case Json.member ("params",value) of SOME params => Json.member ("token",params)=SOME (Json.String "workspace-partial") | _ => false))
              val ()=check ("workspace partial results carry reports",case C.field (C.field (C.field (partial,"params"),"value"),"items") of
                Json.Array (_::_) => true | _ => false)
              val ()=check ("partial final result contains no duplicates",C.field (C.result (C.response (client,72)),"items")=Json.Array [])
              val ()=write ("main.sml","val fixed=42\n")
              val ()=C.request (client,71,"workspace/diagnostic",object [("previousResultIds",Json.Array
                [object [("uri",Json.String uri),("value",C.field (first,"resultId"))]])])
              val fixed=C.result (C.response (client,71))
              val item=case C.field (fixed,"items") of Json.Array [item] => item | _ => raise Fail "workspace refresh missing source"
          in check ("disk-only changes invalidate workspace diagnostics",C.field (item,"items")=Json.Array []) end)
    in (work () before clean ()) handle error => (clean () handle _ => ();raise error) end
  fun navigation ()=fixture (fn client =>
    let val uri="untitled:navigation"
        val text="val first=1\nval second=first\nfun identity x=x\nval third=identity second\n"
        val ()=openDocument (client,uri,text)
        fun query (id,method,line,character)=
          (C.request (client,id,method,object [("textDocument",document uri),
            ("position",object [("line",Json.int line),("character",Json.int character)])]);C.result (C.response (client,id)))
        val definition=query (80,"textDocument/definition",1,12)
        val target=case definition of Json.Array [target] => target | _ => raise Fail "definition not resolved"
        val start=C.field (C.field (target,"range"),"start")
        val ()=check ("value definition uses compiler binding",C.field (target,"uri")=Json.String uri andalso
          C.field (start,"line")=Json.int 0 andalso C.field (start,"character")=Json.int 4)
        val function=query (81,"textDocument/definition",3,12)
        val functionStart=case function of Json.Array [target] => C.field (C.field (target,"range"),"start")
          | _ => raise Fail "function definition not resolved"
        val ()=check ("function selection is its head identifier",C.field (functionStart,"line")=Json.int 2
          andalso C.field (functionStart,"character")=Json.int 4)
        val ()=C.request (client,82,"textDocument/documentSymbol",object [("textDocument",document uri)])
        val symbols=C.result (C.response (client,82))
    in check ("document symbols reflect checked declarations",case symbols of Json.Array values =>
      List.exists (fn value => Json.member ("name",value)=SOME (Json.String "identity")) values | _ => false) end)
  fun temporaryTree action =
    let val root=OS.FileSys.tmpName()
        val ()=(OS.FileSys.remove root;OS.FileSys.mkDir root)
        fun remove path=if OS.FileSys.isDir path then
              let val stream=OS.FileSys.openDir path
                  fun loop()=case OS.FileSys.readDir stream of NONE=>() | SOME name=>(remove(OS.Path.concat(path,name));loop())
              in loop();OS.FileSys.closeDir stream;OS.FileSys.rmDir path end
            else OS.FileSys.remove path
        val platform=if List.exists(fn (key,value)=>key="sysname" andalso value="Windows")(Posix.ProcEnv.uname())
          then LspUri.Windows else LspUri.Posix
        fun uri path=LspUri.original(LspUri.fromPath(platform,OS.FileSys.fullPath path))
        fun write(path,text)=let val out=TextIO.openOut path in TextIO.output(out,text);TextIO.closeOut out end
        fun work()=action{root=root,uri=uri,write=write}
    in (work() before remove root) handle error=>(remove root handle _=>();raise error) end
  fun minimalLibrary (root,write)=
    let val lib=OS.Path.concat(root,"lib") val basis=OS.Path.concat(lib,"basis")
        val ()=(OS.FileSys.mkDir lib;OS.FileSys.mkDir basis)
        val ()=write(OS.Path.concat(basis,"initial.sml"),"val preludeValue=0\n")
        val ()=write(OS.Path.concat(basis,"MANIFEST"),"initial.sml | always | yes | | \n")
    in lib end
  fun watchedWorkspaceCache ()=temporaryTree(fn {root,uri,write}=>
    let val lib=minimalLibrary(root,write)
        fun path name=OS.Path.concat(root,name)
        val ()=write(path "main.build","main.sml\n")
        val ()=write(path "main.sml","val answer=1\n")
        val options=object[("libraryRoot",Json.String(uri lib))]
        val caps=object[("textDocument",object[("diagnostic",object[])]),("workspace",object
          [("didChangeWatchedFiles",object[("dynamicRegistration",Json.Bool true),("relativePatternSupport",Json.Bool true)])])]
    in fixtureInitialized(object[("capabilities",caps),("initializationOptions",options),
        ("workspaceFolders",Json.Array[object[("uri",Json.String(uri root)),("name",Json.String "watched")]])]) (fn client=>
      let fun registration()=C.receive(client,fn value=>Json.member("method",value)=SOME(Json.String "client/registerCapability"))
          val request=registration()
          val ()=C.send(client,object[("jsonrpc",Json.String "2.0"),("id",C.field(request,"id")),("result",Json.Null)])
          fun pull id=(C.request(client,id,"workspace/diagnostic",object[("previousResultIds",Json.Array[])]);C.result(C.response(client,id)))
          val first=pull 700
          val ()=check("acknowledged watcher cache preserves results",pull 701=first)
          val ()=write(path "main.sml","val answer:int=true\n")
          val ()=C.notify(client,"workspace/didChangeWatchedFiles",object[("changes",Json.Array
            [object[("uri",Json.String(uri(path "main.sml"))),("type",Json.int 2)]])])
          val changed=pull 702
          val ()=check("watch notifications invalidate trusted cached reports",case C.field(changed,"items") of
            Json.Array [report]=>C.field(report,"items")<>Json.Array[] | _=>false)
          val ()=C.notify(client,"workspace/didChangeConfiguration",object[("settings",options)])
          val refused=registration()
          val ()=C.send(client,object[("jsonrpc",Json.String "2.0"),("id",C.field(refused,"id")),
            ("error",object[("code",Json.int(~32601)),("message",Json.String "unsupported")])])
          val ()=write(path "main.sml","val answer=2\n")
          val repaired=pull 703
      in check("refused watcher registration falls back to content checks without notifications",case C.field(repaired,"items") of
        Json.Array [report]=>C.field(report,"items")=Json.Array[] | _=>false) end)
    end)
  fun evictionRefreshLoop ()=temporaryTree(fn {root,uri,write}=>
    let val lib=minimalLibrary(root,write)
        val capabilities=object[("textDocument",object[("diagnostic",object[])]),
          ("workspace",object[("diagnostics",object[("refreshSupport",Json.Bool true)])])]
        val names=List.tabulate(6,fn n=>"untitled:refresh-eviction-" ^ Int.toString n)
    in fixtureInitialized(object[("capabilities",capabilities),
        ("initializationOptions",object[("libraryRoot",Json.String(uri lib))])]) (fn client=>
      let val refreshes=ref 0
          fun refresh value=Json.member("method",value)=SOME(Json.String "workspace/diagnostic/refresh")
          fun response id=
            let val value=C.receive(client,fn value=>refresh value orelse Json.member("id",value)=SOME(Json.int id))
            in if refresh value then (refreshes:= !refreshes+1;C.send(client,object[("jsonrpc",Json.String "2.0"),
                ("id",C.field(value,"id")),("result",Json.Null)]);response id) else C.result value end
          fun pull(id,name)=(C.request(client,id,"textDocument/diagnostic",object[("textDocument",document name)]);response id)
          val ()=List.app(fn name=>openDocument(client,name,"val stable=42\n"))names
          val ()=List.app(fn (name,id)=>ignore(pull(id,name)))(ListPair.zip(names,List.tabulate(6,fn n=>10+n)))
          val _=pull(20,List.last names)
          val initial= !refreshes
          val ()=List.app(fn n=>List.app(fn (name,index)=>
            let val id=100+n*20+index*2
                val ()=C.request(client,id,"textDocument/hover",object[("textDocument",document name),
                  ("position",object[("line",Json.int 0),("character",Json.int 5)])])
                val _=response id
            in ignore(pull(id+1,name)) end)(ListPair.zip(names,List.tabulate(6,fn n=>n))))[0,1]
          val ()=check("rechecking evicted views does not generate another global diagnostic refresh",!refreshes=initial)
          val last=List.last names
          val ()=C.notify(client,"textDocument/didChange",object[("textDocument",object[("uri",Json.String last),("version",Json.int 2)]),
            ("contentChanges",Json.Array[object[("text",Json.String "val stable=true\n")]])])
          val report=pull(200,last)
      in check("real input changes still refresh even when active diagnostics stay empty",
        C.field(report,"items")=Json.Array[] andalso !refreshes>initial) end)
    end)
  fun queryBeforeEviction ()=temporaryTree(fn {root,uri,write}=>
    let val lib=minimalLibrary(root,write)
        val names=List.tabulate(12,fn n=>"untitled:query-eviction-" ^ Int.toString n)
    in fixtureInitialized(object[("capabilities",object[]),
        ("initializationOptions",object[("libraryRoot",Json.String(uri lib))])]) (fn client=>
      let fun query(id,name)=C.request(client,id,"textDocument/hover",object[("textDocument",document name),
            ("position",object[("line",Json.int 0),("character",Json.int 5)])])
          val ()=List.app(fn name=>openDocument(client,name,"val stable=42\n"))names
          val ()=List.app(fn (name,id)=>(query(id,name);ignore(C.result(C.response(client,id)))))
            (ListPair.zip(names,List.tabulate(12,fn n=>20+n)))
          val batch=ListPair.zip(List.take(names,6),List.tabulate(6,fn n=>100+n))
          val ()=List.app(fn (name,id)=>query(id,name))batch
          val ()=List.app(fn (_,id)=>
            let val answer=C.response(client,id)
            in check("dependent queries finish before another check evicts their view: " ^ Json.encode answer,
              case Json.member("result",answer) of SOME hover=>
                Json.member("value",C.field(hover,"contents"))=SOME(Json.String "int") | NONE=>false) end)batch
      in () end)
    end)
  fun contextSelectionRecovery ()=temporaryTree(fn {root,uri,write}=>
    let val lib=minimalLibrary(root,write)
        fun path name=OS.Path.concat(root,name)
        val ()=List.app write[(path "one.build","files one.sml shared.sml end\n"),
          (path "two.build","files two.sml shared.sml end\n"),(path "one.sml","val input=1\n"),
          (path "two.sml","val input=true\n"),(path "shared.sml","val result=input\n")]
        val targets=Json.Array(List.map(fn name=>object[("name",Json.String name),
          ("build",Json.String(uri(path(name ^ ".build"))))])["one","two"])
        val options=object[("libraryRoot",Json.String(uri lib)),("targets",targets)]
        val source=uri(path "shared.sml")
    in fixtureInitialized(object[("capabilities",object[("textDocument",object[("diagnostic",object[])])]),
        ("initializationOptions",options)]) (fn client=>
      let val ()=openDocument(client,source,"val result=input\n")
          fun pull id=(C.request(client,id,"textDocument/diagnostic",object[("textDocument",document source)]);C.response(client,id))
          val pending=pull 600
          val ()=check("a pending build-context choice cancels quietly until selection",
            C.field(C.field(pending,"error"),"code")=Json.int(~32802) andalso
            C.field(C.field(C.field(pending,"error"),"data"),"retriggerRequest")=Json.Bool false)
          val again=pull 601
          val ()=check("repeated providers remain cancelled while the choice is pending",C.field(C.field(again,"error"),"code")=Json.int(~32802))
          val prompt=C.receive(client,fn value=>Json.member("method",value)=SOME(Json.String "window/showMessageRequest"))
          val actions=case C.field(C.field(prompt,"params"),"actions") of Json.Array values=>values | _=>raise Fail "missing context actions"
          val first=case List.find(fn action=>String.isSubstring "one" (textValue(C.field(action,"title"))))actions of
            SOME action=>action | NONE=>raise Fail "missing named context action"
          val ()=C.request(client,650,"workspace/diagnostic",object[("previousResultIds",Json.Array[])])
          val _=C.result(C.response(client,650))
          val C.Client{messages,...}=client
          fun plans()=length(List.filter(fn value=>Json.member("method",value)=SOME(Json.String "window/logMessage") andalso
            (case Json.member("params",value) of SOME params=>(case Json.member("message",params) of
              SOME(Json.String text)=>String.isSubstring "Workspace analysis:" text | _=>false) | _=>false))(!messages))
          val planned=plans()
          val ()=C.send(client,object[("jsonrpc",Json.String "2.0"),("id",C.field(prompt,"id")),("result",first)])
          val ()=check("choosing a context recovers without an edit or restart",C.field(C.result(pull 602),"items")=Json.Array[])
          val ()=C.request(client,603,"textDocument/hover",object[("textDocument",document source),
            ("position",object[("line",Json.int 0),("character",Json.int 5)])])
          val hover=C.result(C.response(client,603))
          val ()=check("the selected context supplies the actual incoming type",C.field(C.field(hover,"contents"),"value")=Json.String "int")
          val ()=C.request(client,651,"workspace/diagnostic",object[("previousResultIds",Json.Array[])])
          val _=C.result(C.response(client,651))
      in check("a document context choice does not rescan unchanged workspace projects",plans()=planned) end)
    end)
  fun idleWorkspacePolls ()=temporaryTree(fn {root,uri,write}=>
    let fun path name=OS.Path.concat(root,name)
        val lib=path "lib" val basis=OS.Path.concat(lib,"basis")
        val ()=(OS.FileSys.mkDir lib;OS.FileSys.mkDir basis)
        val initial=OS.Path.concat(basis,"initial.sml")
        val manifest=OS.Path.concat(basis,"MANIFEST")
        val manifestText="initial.sml | always | yes | | \n"
        val ()=write(initial,"val libraryValue=1\n")
        val ()=write(manifest,manifestText)
        val ()=write(path "main.build","main.sml\n")
        val ()=write(path "main.sml","val answer=libraryValue\n")
        val ()=write(path "extra.sml","val extra=2\n")
        val options=object[("libraryRoot",Json.String(uri lib))]
    in fixtureInitialized(object[("capabilities",object[("textDocument",object[("diagnostic",object[])])]),
        ("workspaceFolders",Json.Array[object[("uri",Json.String(uri root)),("name",Json.String "idle")]]),
        ("initializationOptions",options)]) (fn client=>
      let val C.Client {messages,...}=client
          fun plans()=length(List.filter(fn message=>Json.member("method",message)=SOME(Json.String "window/logMessage") andalso
            (case Json.member("params",message) of SOME params=>
              (case Json.member("message",params) of SOME(Json.String text)=>String.isSubstring "Workspace analysis:" text | _=>false)
            | _=>false))(!messages))
          fun pull(id,previous)=(C.request(client,id,"workspace/diagnostic",object[("previousResultIds",Json.Array previous)]);
            C.field(C.result(C.response(client,id)),"items"))
          val first=pull(290,[])
          val count=plans()
          val ()=check("the initial poll performs one workspace sweep",count=1)
          val ()=check("unchanged polls reuse reports without another analysis sweep",pull(291,[])=first andalso plans()=count)
          val previous=case first of Json.Array [report]=>[object[("uri",C.field(report,"uri")),("value",C.field(report,"resultId"))]]
            | _=>raise Fail "missing initial idle report"
          val ()=check("cached reports honor previous result IDs",case pull(292,previous) of Json.Array [report]=>
            C.field(report,"kind")=Json.String "unchanged" andalso plans()=count | _=>false)
          val mainUri=uri(path "main.sml")
          val ()=openDocument(client,mainUri,"val answer=libraryValue\n")
          val ()=check("opening an unchanged project file does not restart the workspace sweep",case pull(298,[]) of
            Json.Array [report]=>C.field(report,"version")=Json.int 1 andalso plans()=count | _=>false)
          val ()=C.notify(client,"textDocument/didClose",object[("textDocument",document mainUri)])
          val ()=check("closing a clean project file preserves reports and clears its version",case pull(299,[]) of
            Json.Array [report]=>C.field(report,"version")=Json.Null andalso plans()=count | _=>false)
          val ()=write(initial,"val libraryValue=true\n")
          val _=pull(293,[])
          val ()=check("saved library source edits invalidate the cache without watched-file notifications",plans()=count+1)
          val ()=write(manifest,manifestText ^ "# regenerated\n")
          val _=pull(294,[])
          val ()=check("regenerated manifests invalidate the cache",plans()=count+2)
          val ()=write(path "main.build","files main.sml extra.sml end\n")
          val ()=check("build changes invalidate membership",case pull(295,[]) of Json.Array reports=>length reports=2 andalso plans()=count+3 | _=>false)
          val ()=write(path "other.build","other.sml\n")
          val ()=write(path "other.sml","val other=3\n")
          val ()=check("new root build files invalidate discovery",case pull(296,[]) of Json.Array reports=>length reports=3 andalso plans()=count+4 | _=>false)
          val ()=openDocument(client,uri(path "main.sml"),"val overlay:int=true\n")
          val ()=check("unsaved overlays invalidate diagnostic results",case pull(297,[]) of Json.Array reports=>
            List.exists(fn report=>C.field(report,"uri")=Json.String(uri(path "main.sml")) andalso
              C.field(report,"items")<>Json.Array[])reports | _=>false)
      in () end)
    end)
  fun analysisProgress ()=temporaryTree(fn {root,uri,write}=>
    let fun path name=OS.Path.concat(root,name)
        val ()=write(path "left.build","left.sml\n")
        val ()=write(path "right.build","right.sml\n")
        val ()=write(path "left.sml","val left=1\n")
        val ()=write(path "right.sml","val right=true\n")
    in fixtureInitialized(object[("capabilities",object[("textDocument",object[("diagnostic",object[])])]),
        ("workspaceFolders",Json.Array[object[("uri",Json.String(uri root)),("name",Json.String "progress")]])]) (fn client=>
      let val ()=C.request(client,280,"workspace/diagnostic",object[("previousResultIds",Json.Array[]),
            ("workDoneToken",Json.String "live-analysis")])
          fun final value=Json.member("id",value)=SOME(Json.int 280)
          fun plan value=Json.member("method",value)=SOME(Json.String "window/logMessage") andalso
            (case Json.member("params",value) of SOME params=>
              Json.member("type",params)=SOME(Json.int 3) andalso
              (case Json.member("message",params) of SOME(Json.String text)=>String.isSubstring "Workspace analysis: 2 contexts" text | _=>false)
            | _=>false)
          val first=C.receive(client,fn value=>final value orelse plan value)
          val ()=check("the Output channel receives the workspace plan before completion",plan first)
          fun tokenReport value=Json.member("method",value)=SOME(Json.String "$/progress") andalso
            (case Json.member("params",value) of SOME params=>Json.member("token",params)=SOME(Json.String "live-analysis") andalso
              (case Json.member("value",params) of SOME report=>Json.member("kind",report)=SOME(Json.String "report") andalso
                (case Json.member("message",report) of SOME(Json.String text)=>String.isSubstring "context 1/2" text | _=>false)
              | _=>false) | _=>false)
          val next=C.receive(client,fn value=>final value orelse tokenReport value)
          val ()=check("work-done tokens receive intermediate context reports",tokenReport next)
          val result=C.result(C.response(client,280))
      in check("progress does not replace the final diagnostic result",case C.field(result,"items") of
        Json.Array items=>length items=2 andalso List.all(fn item=>C.field(item,"items")=Json.Array[])items | _=>false) end)
    end)
  fun workspaceContexts ()=temporaryTree(fn {root,uri,write}=>
    let fun path name=OS.Path.concat(root,name)
        val ()=write(path "left.build","files left.sml left-tail.sml end\n")
        val ()=write(path "right.build","files right.sml right-tail.sml end\n")
        val ()=write(path "left.sml","val contextLeft=1\n")
        val ()=write(path "right.sml","val contextRight=true\n")
        val ()=write(path "left-tail.sml","val leftTail:int=true\n")
        val ()=write(path "right-tail.sml","val rightTail:bool=1\n")
        fun array (Json.Array values)=values | array _=raise Fail "expected array"
        fun report (items,name)=case List.find(fn item=>C.field(item,"uri")=Json.String(uri(path name)))items of
          SOME item=>item | NONE=>raise Fail("missing workspace source " ^ name)
    in fixtureInitialized(object[("capabilities",object[("textDocument",object[("diagnostic",object[])])]),
        ("workspaceFolders",Json.Array[object[("uri",Json.String(uri root)),("name",Json.String "contexts")]])]) (fn client=>
      let fun pull(id,previous)=(C.request(client,id,"workspace/diagnostic",object[("previousResultIds",Json.Array previous)]);
            array(C.field(C.result(C.response(client,id)),"items")))
          val first=pull(270,[])
          val ()=check("all sources survive context-at-a-time reporting",length first=4 andalso
            List.all(fn name=>C.field(report(first,name),"items")=Json.Array[])["left.sml","right.sml"] andalso
            List.all(fn name=>not(null(array(C.field(report(first,name),"items")))))["left-tail.sml","right-tail.sml"])
          val ()=write(path "left-tail.sml","val leftTail:int=contextLeft\n")
          val ()=write(path "right-tail.sml","val rightTail:bool=contextRight\n")
          val previous=List.map(fn item=>object[("uri",C.field(item,"uri")),("value",C.field(item,"resultId"))]) first
          val fixed=pull(271,previous)
          val ()=check("each context uses its own ordinal and previous result",length fixed=4 andalso
            List.all(fn name=>C.field(report(fixed,name),"kind")=Json.String "unchanged")["left.sml","right.sml"] andalso
            List.all(fn name=>C.field(report(fixed,name),"items")=Json.Array[])["left-tail.sml","right-tail.sml"])
          val ()=C.request(client,272,"workspace/symbol",object[("query",Json.String "context")])
          val symbols=array(C.result(C.response(client,272)))
      in check("workspace symbols include both contexts",List.all(fn name=>
        List.exists(fn symbol=>C.field(symbol,"name")=Json.String name)symbols)["contextLeft","contextRight"]) end)
    end)
  fun basisDevelopment ()=temporaryTree(fn {root,uri,write}=>
    let val lib=root ^ "/lib" val basis=lib ^ "/basis"
        val ()=List.app OS.FileSys.mkDir [lib,basis]
        val text="structure Runtime=struct val add=primitive end\n"
        val ()=List.app write [(basis ^ "/library.build","files initial.sml runtime.sml end\n"),
          (basis ^ "/initial.sml","val primitive = _prim \"int_add\" : int * int -> int\n"),
          (basis ^ "/runtime.sml",text),(basis ^ "/MANIFEST","initial.sml | always | yes | | \nruntime.sml | demand | yes | Runtime | \n"),
          (root ^ "/program.build","main.sml\n"),(root ^ "/main.sml","val userPrimitive = _prim \"int_add\" : int * int -> int\n")]
        val runtime=uri(basis ^ "/runtime.sml")
        val options=object[("libraryRoot",Json.String(uri lib)),("targets",Json.Array
          [object[("name",Json.String "program"),("build",Json.String(uri(root ^ "/program.build")))]]),
          ("activeContext",Json.String "program")]
    in fixtureInitialized(object[("capabilities",object[("textDocument",object[("diagnostic",object[])])]),
         ("workspaceFolders",Json.Array[object[("uri",Json.String(uri root)),("name",Json.String "basis")]]),
         ("initializationOptions",options)]) (fn client=>
      let fun pull id=(C.request(client,id,"textDocument/diagnostic",object[("textDocument",document runtime)]);C.result(C.response(client,id)))
          fun change(version,text)=C.notify(client,"textDocument/didChange",object[("textDocument",object
            [("uri",Json.String runtime),("version",Json.int version)]),("contentChanges",Json.Array[object[("text",Json.String text)]])])
          val ordinary=uri(root ^ "/main.sml")
          val ()=openDocument(client,ordinary,"val userPrimitive = _prim \"int_add\" : int * int -> int\n")
          val ()=openDocument(client,runtime,text)
          val ()=C.request(client,715,"textDocument/diagnostic",object[("textDocument",document ordinary)])
          val ()=C.request(client,710,"textDocument/diagnostic",object[("textDocument",document runtime)])
          val ordinaryReport=C.result(C.response(client,715))
          val ()=check("concurrent worker jobs keep their document waiters separate",C.field(ordinaryReport,"items")<>Json.Array[])
          val ()=check("Basis bootstrap does not preload or reject its own primitives",C.field(C.result(C.response(client,710)),"items")=Json.Array[])
          val ()=C.request(client,711,"textDocument/hover",object[("textDocument",document runtime),
            ("position",object[("line",Json.int 0),("character",Json.int 30)])])
          val ()=check("Basis declarations have semantic hover",C.result(C.response(client,711))<>Json.Null)
          val ()=change(2,"structure Runtime=struct val add:int=primitive end\n")
          val ()=check("Basis edits are checked",case C.field(pull 712,"items") of Json.Array(_::_)=>true | _=>false)
          val ()=change(3,text)
          val ()=check("Basis repairs clear diagnostics",C.field(pull 713,"items")=Json.Array[])
          val ()=C.request(client,714,"textDocument/diagnostic",object[("textDocument",document ordinary)])
          val report=C.result(C.response(client,714))
      in check("Basis privilege does not leak into ordinary programs",case C.field(report,"items") of Json.Array items=>
        List.exists(fn item=>String.isSubstring "_prim" (textValue(C.field(item,"message"))))items | _=>false) end) end)
  fun highlightPositions values = case values of Json.Array values => List.map (fn value =>
      let val start=C.field (C.field (value,"range"),"start")
      in (C.field (start,"line"),C.field (start,"character")) end) values
    | _ => raise Fail "highlight result must be an array"
  fun documentHighlights ()=fixture (fn client =>
    let val uri="untitled:highlights"
        val text="val x=1\nval result=x\nlocal val x=true in val inside=x end\nval after=x\nval text=\"x\" (* x *)\nstructure S=struct val x=2 end\nval member=S.x\nfun multi 0=0 | multi n=multi (n-1)\nval called=multi 2\ninfix 6 ++\nfun 0 ++ b=b | a ++ b=a+b\nval summed=1 ++ 2\n"
        val ()=openDocument (client,uri,text)
        val ()=C.request (client,199,"textDocument/diagnostic",object [("textDocument",document uri)])
        val ()=check ("highlight fixture typechecks",C.field (C.result (C.response (client,199)),"items")=Json.Array [])
        fun query (id,line,column)=
          (C.request (client,id,"textDocument/documentHighlight",object [("textDocument",document uri),
            ("position",object [("line",Json.int line),("character",Json.int column)])]);C.result (C.response (client,id)))
        fun positions values=List.map (fn (line,column) => (Json.int line,Json.int column)) values
        val outer=query (200,1,11)
        val ()=check ("highlights follow the outer binding and exclude shadowing, comments and strings",
          highlightPositions outer=positions [(0,4),(1,11),(3,10)])
        val ()=check ("value uses are reads while a declaration is not a mutable write",case outer of Json.Array values =>
          List.map (fn value => C.field (value,"kind")) values=[Json.int 1,Json.int 2,Json.int 2] | _ => false)
        val ()=check ("local shadowed binding is distinct",highlightPositions (query (201,2,31))=positions [(2,10),(2,31)])
        val ()=check ("qualified member selects only the member token",highlightPositions (query (202,6,13))=positions [(5,23),(6,13)])
        val ()=check ("qualified prefix selects the structure binding",highlightPositions (query (203,6,11))=positions [(5,10),(6,11)])
        val ()=check ("a caret directly after an identifier still highlights its binding",query (205,1,12)=outer)
        val ()=check ("all function clause heads and recursive uses share the actual binding",
          highlightPositions (query (206,8,12))=positions [(7,4),(7,16),(7,24),(8,11)])
        val ()=check ("infix clause heads use their operator token ranges",
          highlightPositions (query (207,11,13))=positions [(10,6),(10,17),(11,13)])
    in check ("whitespace has no binding highlight",query (204,0,3)=Json.Array []) end)
  fun highlightEncodings () =
    let fun one (encoding,binder,use) = fixtureInitialized (object
          [("capabilities",object [("general",object [("positionEncodings",Json.Array [Json.String encoding])])]),
           ("initializationOptions",object [("sourceMode",Json.String "unicode")])]) (fn client =>
          let val uri="untitled:unicode-highlights"
              val ()=openDocument (client,uri,"(* \240\159\154\128 *) val x=1; val y=x\n")
              val ()=C.request (client,209,"textDocument/diagnostic",object [("textDocument",document uri)])
              val ()=check ("Unicode highlight fixture typechecks",C.field (C.result (C.response (client,209)),"items")=Json.Array [])
              val ()=C.request (client,210,"textDocument/documentHighlight",object [("textDocument",document uri),
                ("position",object [("line",Json.int 0),("character",Json.int use)])])
              val values=C.result (C.response (client,210))
          in check ("highlight offsets use negotiated " ^ encoding,
               highlightPositions values=[(Json.int 0,Json.int binder),(Json.int 0,Json.int use)]) end)
    in List.app one [("utf-8",15,26),("utf-16",13,24),("utf-32",12,23)] end
  fun highlightBudget ()=fixture (fn client =>
    let val uri="untitled:highlight-budget"
        val text="val x=1\nval xs=[" ^ String.concatWith "," (List.tabulate (10000,fn _ => "x")) ^ "]\n"
        val ()=openDocument (client,uri,text)
        val ()=C.request (client,220,"textDocument/diagnostic",object [("textDocument",document uri)])
        val ()=check ("large highlight fixture typechecks",C.field (C.result (C.response (client,220)),"items")=Json.Array [])
        val params=object [("textDocument",document uri),("position",object [("line",Json.int 0),("character",Json.int 4)])]
        val ()=C.request (client,221,"textDocument/documentHighlight",params)
        val error=C.field (C.response (client,221),"error")
        val ()=check ("oversized highlights fail explicitly rather than return a partial set",C.field (error,"code")=Json.int (~32803))
        val ()=C.request (client,222,"textDocument/hover",params)
        val hover=C.result (C.response (client,222))
    in check ("the semantic worker remains usable after an oversized query",C.field (C.field (hover,"contents"),"value")=Json.String "int") end)
  fun highlightOccurrence () =
    let val dir=OS.FileSys.tmpName ()
        val ()=(OS.FileSys.remove dir;OS.FileSys.mkDir dir)
        fun write (name,text)=let val output=TextIO.openOut (dir ^ "/" ^ name)
          in TextIO.output (output,text);TextIO.closeOut output end
        val text="val x=Outer.value\nval y=x\n"
        val ()=(write ("project.build","files a.sml shared.sml b.sml ./shared.sml end\n");write ("shared.sml",text);
          write ("a.sml","structure Outer=struct datatype t=A val value=A end\n");
          write ("b.sml","structure Outer=struct datatype t=B val value=B end\n"))
        val platform=if OS.Path.validVolume {isAbs=true,vol="C:"} then LspUri.Windows else LspUri.Posix
        fun uri path=LspUri.original (LspUri.fromPath (platform,OS.FileSys.fullPath path))
        val root=uri dir
        val source=uri (dir ^ "/shared.sml")
        fun clean ()=(List.app (fn name => OS.FileSys.remove (dir ^ "/" ^ name))
          ["project.build","shared.sml","a.sml","b.sml"];OS.FileSys.rmDir dir)
        fun work spelling=(write ("project.build","files a.sml shared.sml b.sml " ^ spelling ^ " end\n");
          fixtureInitialized (object [("capabilities",object []),
          ("workspaceFolders",Json.Array [object [("uri",Json.String root),("name",Json.String "occurrences")]])]) (fn client =>
          let val ()=openDocument (client,source,text)
              val choice=C.receive (client,fn value => Json.member ("method",value)=SOME (Json.String "window/showMessageRequest"))
              val action=case C.field (C.field (choice,"params"),"actions") of Json.Array [_,action] => action
                | _ => raise Fail "expected two source occurrences"
              val ()=C.send (client,object [("jsonrpc",Json.String "2.0"),("id",C.field (choice,"id")),("result",action)])
              val ()=C.request (client,230,"textDocument/documentHighlight",object [("textDocument",document source),
                ("position",object [("line",Json.int 1),("character",Json.int 6)])])
              val result=C.result (C.response (client,230))
              val ()=check ("the selected occurrence uses its own file alias and bindings",
                highlightPositions result=[(Json.int 0,Json.int 4),(Json.int 1,Json.int 6)])
              val ()=C.request (client,231,"textDocument/typeDefinition",object [("textDocument",document source),
                ("position",object [("line",Json.int 1),("character",Json.int 6)])])
              val definition=C.result (C.response (client,231))
          in check ("type definition uses the selected occurrence's inferred type",case definition of
            Json.Array [target] => C.field (target,"uri")=Json.String (uri (dir ^ "/b.sml")) | _ => false) end))
    in (List.app work ["shared.sml","./shared.sml"] before clean ()) handle error => (clean () handle _ => ();raise error) end
  val structuralText="(* first\n   second *)\nstructure S =\nstruct\n  fun f x =\n    let\n      val y = x + 1\n    in\n      y\n    end\nend\nval result=S.f 1\n"
  fun structuralRanges ()=fixture (fn client =>
    let val uri="untitled:structure"
        val ()=openDocument (client,uri,structuralText)
        val ()=C.request (client,240,"textDocument/foldingRange",object [("textDocument",document uri)])
        val folds=C.result (C.response (client,240))
        val lines=case folds of Json.Array values => List.map (fn value => (C.field (value,"startLine"),C.field (value,"endLine"))) values
          | _ => raise Fail "folds are not an array"
        val ()=check ("folds follow comments and real nested compiler syntax",lines=
          List.map (fn (a,b) => (Json.int a,Json.int b)) [(0,1),(2,10),(3,10),(4,9),(5,9)])
        val ()=check ("comment folds retain their kind",case folds of Json.Array (first::_) => C.field (first,"kind")=Json.String "comment" | _ => false)
        val ()=C.request (client,241,"textDocument/selectionRange",object [("textDocument",document uri),
          ("positions",Json.Array [object [("line",Json.int 6),("character",Json.int 14)],object [("line",Json.int 11),("character",Json.int 13)]])])
        val selections=C.result (C.response (client,241))
        fun parsed node=valOf (LspProtocol.rangeFromJson (C.field (node,"range")))
        fun leq (a:LspProtocol.position,b:LspProtocol.position)= #line a< #line b orelse #line a= #line b andalso #character a<= #character b
        fun nested node=case Json.member ("parent",node) of NONE => true | SOME parent =>
          let val small=parsed node val large=parsed parent
          in small<>large andalso leq (#start large,#start small) andalso leq (#stop small,#stop large) andalso nested parent end
        val (first,second)=case selections of Json.Array [first,second] => (first,second) | _ => raise Fail "selection cardinality differs"
        val ()=check ("selection starts with the identifier and qualified member components",
          parsed first={start={line=6,character=14},stop={line=6,character=15}} andalso
          parsed second={start={line=11,character=13},stop={line=11,character=14}})
        val ()=check ("selection parents are strict containing ranges",nested first andalso nested second)
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "(* first\n second *)\nval bad:int=true\nstructure S=\nstruct\nend\n")]])])
        val ()=C.request (client,242,"textDocument/foldingRange",object [("textDocument",document uri)])
        val typedError=C.result (C.response (client,242))
        val ()=check ("type errors retain current structural syntax",case typedError of Json.Array values =>
          List.exists (fn value => C.field (value,"startLine")=Json.int 3 andalso C.field (value,"endLine")=Json.int 5) values | _ => false)
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 3)]),
          ("contentChanges",Json.Array [object [("text",Json.String "(* first\n second *)\nval bad=(\n")]])])
        val ()=C.request (client,243,"textDocument/foldingRange",object [("textDocument",document uri)])
        val recovered=C.result (C.response (client,243))
    in check ("parse errors keep comments without reusing stale structure folds",case recovered of
      Json.Array [value] => C.field (value,"startLine")=Json.int 0 andalso C.field (value,"endLine")=Json.int 1 | _ => false) end)
  fun foldingLimits ()=fixtureWith (object [("textDocument",object [("foldingRange",object
    [("rangeLimit",Json.int 1),("lineFoldingOnly",Json.Bool true)])])]) (fn client =>
    let val uri="untitled:fold-limit"
        val ()=openDocument (client,uri,structuralText)
        val ()=C.request (client,250,"textDocument/foldingRange",object [("textDocument",document uri)])
        val result=C.result (C.response (client,250))
    in check ("fold count and complete-line capability are respected",case result of Json.Array [value] =>
      Json.member ("startCharacter",value)=NONE andalso Json.member ("endCharacter",value)=NONE | _ => false) end)
  fun selectionValidation ()=fixtureInitialized (object [("capabilities",object []),
    ("initializationOptions",object [("sourceMode",Json.String "unicode")])]) (fn client =>
    let val uri="untitled:selection-validation"
        val ()=openDocument (client,uri,"(* \240\159\154\128 *)\n")
        fun query (id,positions)=(C.request (client,id,"textDocument/selectionRange",object [("textDocument",document uri),("positions",positions)]);C.response (client,id))
        val split=query (260,Json.Array [object [("line",Json.int 0),("character",Json.int 4)]])
        val ()=check ("selection rejects a split UTF16 scalar",C.field (C.field (split,"error"),"code")=Json.int (~32602))
        val huge=query (261,Json.Array (List.tabulate (129,fn _ => object [("line",Json.int 0),("character",Json.int 0)])))
        val ()=check ("selection position budget is explicit",C.field (C.field (huge,"error"),"code")=Json.int (~32803))
    in check ("empty position arrays have an empty result",C.result (query (262,Json.Array []))=Json.Array []) end)
  fun foldingRefresh () =
    let val capabilities=object [("workspace",object [("foldingRange",object [("refreshSupport",Json.Bool true)])])]
        fun isRefresh value=Json.member ("method",value)=SOME (Json.String "workspace/foldingRange/refresh")
        fun configure (client,mode)=C.notify (client,"workspace/didChangeConfiguration",object
          [("settings",object [("sourceMode",Json.String mode)])])
        fun acknowledge (client,message,result)=C.send (client,object
          [("jsonrpc",Json.String "2.0"),("id",C.field (message,"id")),("result",result)])
        fun barrier (client,id,uri)=
          (C.request (client,id,"textDocument/foldingRange",object [("textDocument",document uri)]);ignore (C.result (C.response (client,id))))
        fun pending (C.Client {messages,...})=List.exists isRefresh (!messages)
        val ()=fixtureWith capabilities (fn client =>
          let val uri="untitled:fold-refresh"
              val ()=openDocument (client,uri,"val x=1\n")
              val ()=configure (client,"unicode")
              val first=C.receive (client,isRefresh)
              val ()=configure (client,"ascii")
              val ()=barrier (client,270,uri)
              val ()=check ("folding refreshes coalesce while a request is pending",not (pending client))
              val ()=acknowledge (client,first,Json.Null)
              val next=C.receive (client,isRefresh)
              val ()=check ("a newer workspace generation gets a fresh refresh id",C.field (first,"id")<>C.field (next,"id"))
              val ()=acknowledge (client,next,Json.Null)
              val ()=barrier (client,271,uri)
              val ()=check ("refresh acknowledgements do not create a loop",not (pending client))
              val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
                ("contentChanges",Json.Array [object [("text",Json.String "val x=2\n")]])])
              val ()=barrier (client,272,uri)
          in check ("ordinary typing does not trigger a global folding refresh",not (pending client)) end)
    in fixtureWith capabilities (fn client =>
      let val uri="untitled:fold-refresh-refusal"
          val ()=openDocument (client,uri,"val x=1\n")
          val ()=configure (client,"unicode")
          val message=C.receive (client,isRefresh)
          val ()=C.send (client,object [("jsonrpc",Json.String "2.0"),("id",C.field (message,"id")),
            ("error",object [("code",Json.int (~32601)),("message",Json.String "not implemented")])])
          val ()=configure (client,"ascii")
          val ()=barrier (client,280,uri)
      in check ("an unsupported client refresh method is not requested again",not (pending client)) end) end
  val tokenTypes=["string","namespace","number","type","variable","comment","keyword","interface","typeParameter"]
  fun tokenCapabilities (encoding,requests,types,modifiers,formats) = object
    [("general",object [("positionEncodings",Json.Array [Json.String encoding])]),
     ("textDocument",object [("semanticTokens",object [("requests",requests),
       ("tokenTypes",Json.Array (List.map Json.String types)),("tokenModifiers",Json.Array (List.map Json.String modifiers)),
       ("formats",Json.Array (List.map Json.String formats)),("multilineTokenSupport",Json.Bool false),
       ("overlappingTokenSupport",Json.Bool false)])])]
  val tokenRequests=object [("full",object [("delta",Json.Bool true)]),("range",Json.Bool true)]
  fun tokenFixture capabilities action=fixtureInitializedResult (object [("capabilities",capabilities),
    ("initializationOptions",object [("sourceMode",Json.String "unicode")])]) action
  fun tokenQuery (client,id,method,uri,extra)=
    (C.request (client,id,method,object (("textDocument",document uri)::extra));C.response (client,id))
  fun jsonStrings (Json.Array values)=List.map (fn Json.String value => value | _ => raise Fail "nonstring legend") values
    | jsonStrings _=raise Fail "missing token legend array"
  fun tokenData (Json.Array values)=Vector.fromList (List.map (fn value => case Json.toIntInf value of
      SOME n => if n>=0 andalso n<=2147483647 then n else raise Fail "token integer outside LSP bounds"
    | NONE => raise Fail "noninteger token") values)
    | tokenData _=raise Fail "token data is not an array"
  type tokenRow={line:IntInf.int,column:IntInf.int,length:IntInf.int,kind:string,bits:IntInf.int}
  fun decodeTokens (response,legend) =
    let val types=jsonStrings (C.field (legend,"tokenTypes"))
        val modifiers=jsonStrings (C.field (legend,"tokenModifiers"))
        val data=tokenData (C.field (response,"data"))
        val ()=if Vector.length data mod 5=0 then () else raise Fail "token data lacks complete tuples"
        fun power (0,n)=n | power (i,n)=power (i-1,n*2)
        val bitLimit=power (length modifiers,1:IntInf.int)
        fun loop (i,line,column,finish,rows)=if i=Vector.length data then List.rev rows else
          let val dl=Vector.sub (data,i) val dc=Vector.sub (data,i+1)
              val size=Vector.sub (data,i+2) val kind=Vector.sub (data,i+3) val bits=Vector.sub (data,i+4)
              val nextLine=line+dl
              val nextColumn=if dl=0 then column+dc else dc
              val ()=if size>0 andalso kind<IntInf.fromInt (length types) andalso bits<bitLimit andalso
                (dl<>0 orelse nextColumn>=finish) then () else raise Fail "invalid or overlapping semantic token"
              val row={line=nextLine,column=nextColumn,length=size,kind=List.nth (types,IntInf.toInt kind),bits=bits}:tokenRow
          in loop (i+5,nextLine,nextColumn,nextColumn+size,row::rows) end
    in loop (0,0,0,0,[]) end
  fun applyTokenDelta (original,delta) =
    let val data=Vector.foldr (op ::) [] (tokenData (C.field (original,"data")))
        val edits=case C.field (delta,"edits") of Json.Array edits => edits | _ => raise Fail "missing token edits"
        fun start edit=valOf (Json.toInt (C.field (edit,"start")))
        fun insert (edit,[])= [edit]
          | insert (edit,first::rest)=if start edit>start first then edit::first::rest else first::insert (edit,rest)
        val edits=List.foldl insert [] edits
        fun apply (edit,data)=
          let val at=start edit val count=valOf (Json.toInt (C.field (edit,"deleteCount")))
              val added=case Json.member ("data",edit) of NONE => [] | SOME data => Vector.foldr (op ::) [] (tokenData data)
          in List.take (data,at) @ added @ List.drop (data,at+count) end
    in Json.Array (List.map Json.intInf (List.foldl apply data edits)) end
  val semanticText="(* one\r\n   \240\159\154\128 two *)\r\nstructure S = struct\r\n  type t = int\r\n  val value : t = 42\r\n  val text=\"ok\"\r\nend\r\nval result = S.value\r\nsignature SIG = sig val v:int end\r\nval polymorphic : 'a list -> 'a list = fn x => x\r\n"
  fun semanticTokens ()=tokenFixture (tokenCapabilities ("utf-16",tokenRequests,tokenTypes,["readonly","declaration"],["relative"]))
    (fn (client,initialized) =>
      let val provider=C.field (C.field (initialized,"capabilities"),"semanticTokensProvider")
          val legend=C.field (provider,"legend")
          val ()=check ("full/delta/range are negotiated",C.field (provider,"full")=object [("delta",Json.Bool true)] andalso C.field (provider,"range")=Json.Bool true)
          val uri="untitled:semantic-tokens"
          val ()=openDocument (client,uri,semanticText)
          val original=C.result (tokenQuery (client,300,"textDocument/semanticTokens/full",uri,[]))
          val rows=decodeTokens (original,legend)
          fun has (line,column,size,kind)=List.exists (fn row:tokenRow => #line row=line andalso #column row=column andalso #length row=size andalso #kind row=kind) rows
          val ()=check ("multiline CRLF comments are split into encoded line tokens",has (0,0,6,"comment") andalso has (1,0,12,"comment"))
          val ()=check ("checked namespaces and literal classes are distinct",has (2,10,1,"namespace") andalso
            has (3,7,1,"type") andalso has (8,10,3,"interface") andalso has (9,18,2,"typeParameter") andalso has (4,6,5,"variable") andalso has (4,18,2,"number") andalso has (5,11,4,"string"))
          val ()=check ("modifier bits use the server legend rather than client ordering",
            C.field (legend,"tokenModifiers")=Json.Array [Json.String "declaration",Json.String "readonly"] andalso
            List.exists (fn row:tokenRow => #line row=4 andalso #column row=6 andalso #bits row=3) rows andalso
            List.exists (fn row:tokenRow => #line row=7 andalso #column row=15 andalso #bits row=2) rows)
          val unchanged=C.result (tokenQuery (client,301,"textDocument/semanticTokens/full/delta",uri,[("previousResultId",C.field (original,"resultId"))]))
          val ()=check ("unchanged token arrays have no edits",C.field (unchanged,"edits")=Json.Array [])
          val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
            ("contentChanges",Json.Array [object [("text",Json.String ("\r\n" ^ semanticText))]])])
          val changed=C.result (tokenQuery (client,302,"textDocument/semanticTokens/full/delta",uri,[("previousResultId",C.field (original,"resultId"))]))
          val full=C.result (tokenQuery (client,303,"textDocument/semanticTokens/full",uri,[]))
          val ()=check ("independent delta splicing equals a fresh full result",applyTokenDelta (original,changed)=C.field (full,"data"))
          val ()=check ("the newline delta edits a uint rather than replacing a whole token",case C.field (changed,"edits") of
            Json.Array [edit] => C.field (edit,"start")=Json.int 0 andalso C.field (edit,"deleteCount")=Json.int 1 andalso C.field (edit,"data")=Json.Array [Json.int 1] | _ => false)
          val range=object [("start",object [("line",Json.int 8),("character",Json.int 16)]),("end",object [("line",Json.int 8),("character",Json.int 17)])]
          val partial=C.result (tokenQuery (client,304,"textDocument/semanticTokens/range",uri,[("range",range)]))
          val ()=check ("range replies retain whole intersecting tokens and document-relative positions",case decodeTokens (partial,legend) of
            [row] => #line row=8 andalso #column row=15 andalso #length row=5 andalso #kind row="variable" | _ => false)
          val missing=C.result (tokenQuery (client,305,"textDocument/semanticTokens/full/delta",uri,[("previousResultId",Json.String "missing")]))
      in check ("unknown delta state returns a complete result",Json.member ("edits",missing)=NONE andalso C.field (missing,"data")=C.field (full,"data")) end)
  fun semanticTokenEncodings () =
    let fun one (encoding,commentLength)=tokenFixture (tokenCapabilities (encoding,tokenRequests,tokenTypes,[],["relative"]))
          (fn (client,initialized) =>
            let val uri="untitled:token-encoding"
                val legend=C.field (C.field (C.field (initialized,"capabilities"),"semanticTokensProvider"),"legend")
                val ()=openDocument (client,uri,semanticText)
                val full=C.result (tokenQuery (client,310,"textDocument/semanticTokens/full",uri,[]))
                val rows=decodeTokens (full,legend)
            in check ("semantic token lengths use " ^ encoding,List.exists (fn row:tokenRow =>
              #line row=1 andalso #column row=0 andalso #length row=commentLength andalso #kind row="comment") rows) end)
    in List.app one [("utf-8",14),("utf-16",12),("utf-32",11)] end
  fun semanticTokenNegotiation () =
    let val ()=fixture (fn client =>
          let val uri="untitled:legacy-tokens" val ()=openDocument (client,uri,"val x=1\n")
              val response=tokenQuery (client,320,"textDocument/semanticTokens/full",uri,[])
          in check ("legacy clients do not activate token requests",C.field (C.field (response,"error"),"code")=Json.int (~32601)) end)
    in tokenFixture (tokenCapabilities ("utf-16",object [("full",Json.Bool true)], ["variable"],[],["relative"]))
      (fn (client,initialized) =>
        let val uri="untitled:restricted-tokens"
            val provider=C.field (C.field (initialized,"capabilities"),"semanticTokensProvider")
            val legend=C.field (provider,"legend")
            val ()=check ("server legends contain only supported classes",C.field (legend,"tokenTypes")=Json.Array [Json.String "variable"] andalso C.field (legend,"tokenModifiers")=Json.Array [])
            val ()=openDocument (client,uri,"val x=1\nval y=x\n")
            val full=C.result (tokenQuery (client,321,"textDocument/semanticTokens/full",uri,[]))
            val rows=decodeTokens (full,legend)
            val ()=check ("unsupported classes and modifiers are omitted",length rows=3 andalso List.all (fn row:tokenRow => #kind row="variable" andalso #bits row=0) rows)
            val unsupported=tokenQuery (client,322,"textDocument/semanticTokens/full/delta",uri,[("previousResultId",C.field (full,"resultId"))])
        in check ("unnegotiated deltas stay unsupported",C.field (C.field (unsupported,"error"),"code")=Json.int (~32601)) end) end
  fun semanticTokenHistory () =
    let val capabilities=tokenCapabilities ("utf-16",tokenRequests,tokenTypes,[],["relative"])
        val saved=ref NONE : Json.value option ref
        val uri="untitled:token-history"
        fun text count="val start=0\n" ^ String.concat (List.tabulate (count,fn i => "val x" ^ Int.toString i ^ "=" ^ Int.toString i ^ "\n"))
        val ()=tokenFixture capabilities (fn (client,_) =>
          let val ()=openDocument (client,uri,text 0)
              val first=C.result (tokenQuery (client,330,"textDocument/semanticTokens/full",uri,[]))
              fun change count=
                (C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int (count+1))]),
                   ("contentChanges",Json.Array [object [("text",Json.String (text count))]])]);
                 ignore (C.result (tokenQuery (client,330+count,"textDocument/semanticTokens/full",uri,[]))))
              val ()=List.app change (List.tabulate (10,fn i => i+1))
              val evicted=C.result (tokenQuery (client,350,"textDocument/semanticTokens/full/delta",uri,[("previousResultId",C.field (first,"resultId"))]))
              val ()=check ("evicted token arrays fall back to full responses",isSome (Json.member ("data",evicted)) andalso Json.member ("edits",evicted)=NONE)
          in saved:=SOME evicted end)
    in tokenFixture capabilities (fn (client,_) =>
      let val ()=openDocument (client,uri,text 10)
          val previous=valOf (!saved)
          val restarted=C.result (tokenQuery (client,351,"textDocument/semanticTokens/full/delta",uri,[("previousResultId",C.field (previous,"resultId"))]))
      in check ("a restarted server has no previous token cache",Json.member ("edits",restarted)=NONE andalso C.field (restarted,"data")=C.field (previous,"data")) end) end
  fun semanticTokenRecovery ()=tokenFixture (tokenCapabilities ("utf-16",tokenRequests,tokenTypes,[],["relative"]))
    (fn (client,initialized) =>
      let val uri="untitled:token-recovery"
          val legend=C.field (C.field (C.field (initialized,"capabilities"),"semanticTokensProvider"),"legend")
          val ()=openDocument (client,uri,"val x=1\nval y=x\n")
          val first=C.result (tokenQuery (client,360,"textDocument/semanticTokens/full",uri,[]))
          val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
            ("contentChanges",Json.Array [object [("text",Json.String "val broken=(\n")]])])
          val change=C.result (tokenQuery (client,361,"textDocument/semanticTokens/full/delta",uri,[("previousResultId",C.field (first,"resultId"))]))
          val full=C.result (tokenQuery (client,362,"textDocument/semanticTokens/full",uri,[]))
          val rows=decodeTokens (full,legend)
      in check ("recovery colors current lexical pieces without stale checked bindings",applyTokenDelta (first,change)=C.field (full,"data") andalso
        not (null rows) andalso List.all (fn row:tokenRow => #kind row="keyword") rows) end)
  fun semanticTokenRefresh () =
    let val base=tokenCapabilities ("utf-16",tokenRequests,tokenTypes,[],["relative"])
        val capabilities=case base of Json.Object fields => object (("workspace",object [("semanticTokens",object [("refreshSupport",Json.Bool true)])])::fields)
          | _ => raise Fail "token capabilities must be an object"
    in tokenFixture capabilities (fn (client,_) =>
      let val uri="untitled:token-refresh"
          val ()=openDocument (client,uri,"val x=1\n")
          val ()=C.notify (client,"workspace/didChangeConfiguration",object [("settings",object [("sourceMode",Json.String "ascii")])])
          val refresh=C.receive (client,fn value => Json.member ("method",value)=SOME (Json.String "workspace/semanticTokens/refresh"))
          val ()=C.send (client,object [("jsonrpc",Json.String "2.0"),("id",C.field (refresh,"id")),("result",Json.Null)])
          val full=C.result (tokenQuery (client,370,"textDocument/semanticTokens/full",uri,[]))
      in check ("negotiated token refresh leaves the provider usable",isSome (Json.member ("data",full))) end) end
  fun semanticTokenValidation () =
    let val ()=tokenFixture (tokenCapabilities ("utf-16",tokenRequests,tokenTypes,[],["relative"]))
          (fn (client,_) =>
            let val uri="untitled:token-validation"
                val ()=openDocument (client,uri,"(* \240\159\154\128 *)\n")
                fun range (a,b)=object [("start",object [("line",Json.int 0),("character",Json.int a)]),
                  ("end",object [("line",Json.int 0),("character",Json.int b)])]
                val split=tokenQuery (client,380,"textDocument/semanticTokens/range",uri,[("range",range (4,5))])
                val reversed=tokenQuery (client,381,"textDocument/semanticTokens/range",uri,[("range",range (5,1))])
                val missing=tokenQuery (client,382,"textDocument/semanticTokens/full/delta",uri,[])
            in check ("token ranges and delta state reject malformed parameters",List.all (fn response =>
              C.field (C.field (response,"error"),"code")=Json.int (~32602)) [split,reversed,missing]) end)
    in tokenFixture (tokenCapabilities ("utf-16",tokenRequests,tokenTypes,[],["absolute"]))
      (fn (client,initialized) =>
        let val uri="untitled:unsupported-token-format"
            val ()=check ("unsupported token formats do not advertise a provider",Json.member ("semanticTokensProvider",C.field (initialized,"capabilities"))=NONE)
            val ()=openDocument (client,uri,"val x=1\n")
            val response=tokenQuery (client,383,"textDocument/semanticTokens/full",uri,[])
        in check ("unsupported token formats do not activate requests",C.field (C.field (response,"error"),"code")=Json.int (~32601)) end) end
  fun semanticTokenBudget ()=tokenFixture (tokenCapabilities ("utf-16",tokenRequests,tokenTypes,[],["relative"]))
    (fn (client,initialized) =>
      let val uri="untitled:token-budget"
          val legend=C.field (C.field (C.field (initialized,"capabilities"),"semanticTokensProvider"),"legend")
          val text="(*\n" ^ String.concat (List.tabulate (20001,fn _ => "x\n")) ^ "*)\n"
          val ()=openDocument (client,uri,text)
          val huge=tokenQuery (client,390,"textDocument/semanticTokens/full",uri,[])
          val ()=check ("oversized token replies fail instead of truncating",C.field (C.field (huge,"error"),"code")=Json.int (~32803))
          val range=object [("start",object [("line",Json.int 0),("character",Json.int 0)]),
            ("end",object [("line",Json.int 2),("character",Json.int 1)])]
          val visible=C.result (tokenQuery (client,391,"textDocument/semanticTokens/range",uri,[("range",range)]))
          val rows=decodeTokens (visible,legend)
      in check ("a bounded visible range remains available after full reply refusal",length rows=3 andalso List.all (fn row:tokenRow => #kind row="comment") rows) end)
  fun workspaceSymbols ()=fixtureWith (object [("workspace",object [("symbol",object
    [("resolveSupport",object [("properties",Json.Array [Json.String "location.range"])])])])]) (fn client =>
    let val uri="untitled:workspace-symbols"
        val ()=openDocument (client,uri,"fun namedFunction x=x\nval value=1\n")
        val ()=C.request (client,90,"workspace/symbol",object [("query",Json.String "namedFunction")])
        val symbols=C.result (C.response (client,90))
        val symbol=case symbols of Json.Array [symbol] => symbol | _ => raise Fail "workspace symbol missing"
        val ()=check ("workspace symbol can defer its range",Json.member ("range",C.field (symbol,"location"))=NONE)
        val ()=C.request (client,91,"workspaceSymbol/resolve",symbol)
        val resolved=C.result (C.response (client,91))
        val ()=check ("workspace resolve returns validated location",isSome (Json.member ("range",C.field (resolved,"location"))))
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "val replacement=1\n")]])])
        val ()=C.request (client,92,"workspaceSymbol/resolve",symbol)
        val stale=C.response (client,92)
    in check ("stale symbol resolve refused",isSome (Json.member ("error",stale))) end)
  fun completion ()=fixture (fn client =>
    let val uri="untitled:completion"
        val text="structure S : sig val visible:int end = struct val visible=1 val hidden=2 end\nval result=S."
        val ()=openDocument (client,uri,text)
        fun query (id,line,column)=
          (C.request (client,id,"textDocument/completion",object [("textDocument",document uri),
            ("position",object [("line",Json.int line),("character",Json.int column)])]);
           C.result (C.response (client,id)))
        val result=query (100,1,13)
        val items=case C.field (result,"items") of Json.Array items => items | _ => raise Fail "completion items missing"
        val item=case List.find (fn item => C.field (item,"label")=Json.String "visible") items of
          SOME item => item | NONE => raise Fail "visible completion missing"
        val ()=check ("signature hides private completion names",
          not (List.exists (fn item => C.field (item,"label")=Json.String "hidden") items))
        val ()=check ("completion replacement follows the qualification",
          C.field (C.field (C.field (item,"textEdit"),"range"),"start")=object [("line",Json.int 1),("character",Json.int 13)])
        val ()=C.request (client,101,"completionItem/resolve",item)
        val resolved=C.result (C.response (client,101))
        val ()=check ("completion resolves against its frozen scope",C.field (resolved,"detail")=Json.String "int")
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "fun f parameter = let val localName=1 in loc")]])])
        val localResult=query (102,0,44)
        val ()=check ("unfinished local completion uses lexical scope",case C.field (localResult,"items") of Json.Array items =>
          List.exists (fn item => C.field (item,"label")=Json.String "localName") items | _ => false)
        val ()=C.request (client,103,"completionItem/resolve",item)
        val stale=C.response (client,103)
    in check ("old completion resolve rejected after an edit",isSome (Json.member ("error",stale))) end)
  fun signatureHelp ()=fixtureInitialized (object [("capabilities",object [("textDocument",object
    [("signatureHelp",object [("signatureInformation",object [("parameterInformation",object [("labelOffsetSupport",Json.Bool true)])])])])]),
    ("initializationOptions",object [("sourceMode",Json.String "unicode")])]) (fn client =>
    let val uri="untitled:signature-help"
        val text="datatype \240\144\144\128 = V\nfun f (x:\240\144\144\128,y:bool)=x\nval result=f(V, "
        val ()=openDocument (client,uri,text)
        val ()=C.request (client,110,"textDocument/signatureHelp",object [("textDocument",document uri),
          ("position",object [("line",Json.int 2),("character",Json.int 16)])])
        val result=C.result (C.response (client,110))
        val ()=check ("signature identifies the active tuple argument",C.field (result,"activeParameter")=Json.int 1)
        val information=case C.field (result,"signatures") of Json.Array [value] => value | _ => raise Fail "signature missing"
        val parameters=case C.field (information,"parameters") of Json.Array values => values | _ => raise Fail "signature parameters missing"
        val ()=check ("signature parameter offsets count UTF-16 units",case parameters of [_,second] =>
          C.field (second,"label")=Json.Array [Json.int 7,Json.int 11] | _ => false)
    in check ("signature retains the compiler type",String.isSubstring "bool" (case C.field (information,"label") of
      Json.String label => label | _ => "")) end)
  fun completionSnippets ()=fixtureWith (object [("textDocument",object [("completion",object
    [("completionItem",object [("snippetSupport",Json.Bool true)])])])]) (fn client =>
    let val uri="untitled:completion-snippets"
        val ()=openDocument (client,uri,"fun identity (x:int)=x\nval result=ide\n")
        val ()=C.request (client,120,"textDocument/completion",object [("textDocument",document uri),
          ("position",object [("line",Json.int 1),("character",Json.int 14)])])
        val response=C.result (C.response (client,120))
        val items=case C.field (response,"items") of Json.Array items => items | _ => raise Fail "completion items missing"
        val item=case List.find (fn item => C.field (item,"insertTextFormat")=Json.int 2) items of
          SOME item => item | NONE => raise Fail "typed invocation snippet missing"
        val ()=check ("snippet arguments follow the checked callable type",C.field (C.field (item,"textEdit"),"newText")=
          Json.String "identity (${1:(raise op Match)})$0")
        val ()=C.request (client,121,"completionItem/resolve",item)
        val resolved=C.result (C.response (client,121))
        val ()=check ("snippet item resolves without becoming a plain item",C.field (resolved,"insertTextFormat")=Json.int 2)
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "fun identity (x:int)=x\nval result=identity ((raise op Match))\n")]])])
        val ()=C.request (client,122,"textDocument/diagnostic",object [("textDocument",document uri)])
        val checked=C.result (C.response (client,122))
        val ()=check ("expanded invocation template parses and typechecks without execution",C.field (checked,"items")=Json.Array [])
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 3)]),
          ("contentChanges",Json.Array [object [("text",Json.String "fun Match (x:int)=x\nfun identity (x:int)=x\nval result=ide\n")]])])
        val ()=C.request (client,123,"textDocument/completion",object [("textDocument",document uri),
          ("position",object [("line",Json.int 2),("character",Json.int 14)])])
        val shadowed=C.result (C.response (client,123))
    in check ("shadowed placeholder exceptions suppress invalid snippets",case C.field (shadowed,"items") of Json.Array items =>
      not (List.exists (fn item => C.field (item,"insertTextFormat")=Json.int 2) items) | _ => false) end)
  fun inlineCompletion ()=fixtureWith (object [("textDocument",object [("inlineCompletion",object [])])]) (fn client =>
    let val uri="untitled:inline-pattern"
        val ()=openDocument (client,uri,"datatype t=Some of int | None\nfun f (So)=1\n")
        fun query (id,extra)=
          (C.request (client,id,"textDocument/inlineCompletion",object [("textDocument",document uri),
             ("position",object [("line",Json.int 1),("character",Json.int 9)]),
             ("context",object (("triggerKind",Json.int 1)::extra))]);C.result (C.response (client,id)))
        val response=query (130,[])
        val items=case C.field (response,"items") of Json.Array items => items | _ => raise Fail "inline items missing"
        val item=case items of [item] => item | _ => raise Fail "constructor pattern completion missing"
        val ()=check ("inline completion uses a real constructor and a parenthesized pattern",
          C.field (item,"insertText")=Json.String "(Some _)")
        val incompatible=query (131,[("selectedCompletionInfo",object [("range",object
          [("start",object [("line",Json.int 1),("character",Json.int 0)]),
           ("end",object [("line",Json.int 1),("character",Json.int 9)])]),("text",Json.String "different")])])
    in check ("incompatible selected completion receives no inline edit",C.field (incompatible,"items")=Json.Array []) end)
  fun completionContextAndDocumentation ()=fixture (fn client =>
    let val uri="untitled:completion-context"
        val ()=openDocument (client,uri,"(* Preserves its integer argument. *)\nfun identity (x:int)=x\nval copied=identity 1\n")
        fun position (line,column)=object [("line",Json.int line),("character",Json.int column)]
        fun request (id,method,line,column)=
          (C.request (client,id,method,object [("textDocument",document uri),("position",position (line,column))]);
           C.result (C.response (client,id)))
        fun change (version,text)=C.notify (client,"textDocument/didChange",object
          [("textDocument",object [("uri",Json.String uri),("version",Json.int version)]),
           ("contentChanges",Json.Array [object [("text",Json.String text)]])])
        val hover=request (140,"textDocument/hover",2,13)
        val ()=check ("hover attaches the actual declaration's captured documentation",case C.field (C.field (hover,"contents"),"value") of
          Json.String value => String.isSubstring "Preserves its integer argument." value | _ => false)
        val ()=change (2,"(* Preserves its integer argument. *)\nfun identity (x:int)=x\nval result=ide\n")
        val completion=request (141,"textDocument/completion",2,14)
        val item=case C.field (completion,"items") of Json.Array [item] => item | _ => raise Fail "documented completion missing"
        val ()=C.request (client,142,"completionItem/resolve",item)
        val resolved=C.result (C.response (client,142))
        val ()=check ("completion resolves captured source documentation",C.field (resolved,"documentation")=Json.String "Preserves its integer argument.")
        val ()=change (3,"val record={name=1,other=true}\nval selected= #na record\n")
        val fields=request (143,"textDocument/completion",1,17)
        val field=case C.field (fields,"items") of Json.Array [field] => field | _ => raise Fail "concrete record field missing"
        val ()=check ("record selector completion is typed and replaces only the label",
          C.field (field,"label")=Json.String "name" andalso C.field (field,"kind")=Json.int 5 andalso
          C.field (field,"detail")=Json.String "int" andalso
          C.field (C.field (C.field (field,"textEdit"),"range"),"start")=position (1,15))
        val ()=change (4,"type existingType=int\nval existingValue=1\nval result:exis=1\n")
        val types=request (144,"textDocument/completion",2,15)
    in check ("type positions exclude same-prefix values",case C.field (types,"items") of Json.Array [item] =>
      C.field (item,"label")=Json.String "existingType" | _ => false) end)
  fun legacyCompletionFallback ()=fixture (fn client =>
    let val uri="untitled:legacy-completion"
        val ()=openDocument (client,uri,"datatype t=Some of int | None\nval Someone=1\nfun f (So)=1\n")
        val params=[("textDocument",document uri),("position",object [("line",Json.int 2),("character",Json.int 9)])]
        val ()=C.request (client,150,"textDocument/completion",object params)
        val completion=C.result (C.response (client,150))
        val ()=check ("older clients receive ordinary constructor completion without snippets",case C.field (completion,"items") of
          Json.Array [item] => C.field (item,"label")=Json.String "Some" andalso C.field (item,"insertTextFormat")=Json.int 1 | _ => false)
        val ()=C.request (client,151,"textDocument/inlineCompletion",object (("context",object [("triggerKind",Json.int 1)])::params))
        val unsupported=C.response (client,151)
    in check ("inline completion requires negotiated client support",C.field (C.field (unsupported,"error"),"code")=Json.int (~32601)) end)
  fun semanticErrorsAndEviction ()=fixture (fn client =>
    let val uris=List.tabulate (6,fn index => "untitled:eviction-" ^ Int.toString index)
        val ()=List.app (fn uri => openDocument (client,uri,"val answer=42\n")) uris
        fun pull ([],_)=() | pull (uri::rest,id)=
          (C.request (client,id,"textDocument/diagnostic",object [("textDocument",document uri)]);
           ignore (C.result (C.response (client,id)));pull (rest,id+1))
        val ()=pull (uris,160)
        val uri=hd uris
        val ()=C.request (client,166,"textDocument/hover",object [("textDocument",document uri),
          ("position",object [("line",Json.int 0),("character",Json.int 4)])])
        val hover=C.result (C.response (client,166))
        val ()=check ("an evicted semantic view is recomputed once",C.field (C.field (hover,"contents"),"value")=Json.String "int")
        val ()=C.request (client,167,"textDocument/hover",object [("textDocument",document uri),
          ("position",object [("line",Json.int (~1)),("character",Json.int 0)])])
        val invalid=C.response (client,167)
        val ()=check ("malformed semantic positions return InvalidParams",C.field (C.field (invalid,"error"),"code")=Json.int (~32602))
        val ()=C.request (client,168,"textDocument/diagnostic",object [("textDocument",document uri),("previousResultId",Json.int 7)])
        val malformed=C.response (client,168)
    in check ("malformed diagnostic parameters retain their error code",C.field (C.field (malformed,"error"),"code")=Json.int (~32602)) end)
  fun hintCapabilities lazy=object [("textDocument",object [("inlayHint",if lazy then
    object [("resolveSupport",object [("properties",Json.Array [Json.String "tooltip"])])] else object [])])]
  fun hintRange (line,column,lastLine,lastColumn)=object
    [("start",object [("line",Json.int line),("character",Json.int column)]),
     ("end",object [("line",Json.int lastLine),("character",Json.int lastColumn)])]
  fun hintQuery (client,id,uri,range)=
    (C.request (client,id,"textDocument/inlayHint",object [("textDocument",document uri),("range",range)]);C.response (client,id))
  fun hintItems response=case C.result response of Json.Array items => items | _ => raise Fail "inlay hint array missing"
  fun hintOne response=case hintItems response of [item] => item | _ => raise Fail "expected one inlay hint"
  fun inlayHints ()=fixtureWith (hintCapabilities true) (fn client =>
    let val uri="untitled:inferred-hints"
        val text="datatype choice=C | D of int\nval a=1\nval typed:int=2\nval (b,c)=(true,3)\nfun id x=x\nval y=fn z=>z\n"
        val ()=openDocument (client,uri,text)
        val hints=hintItems (hintQuery (client,500,uri,hintRange (0,0,6,0)))
        fun line item=C.field (C.field (item,"position"),"line")
        val first=hd hints
        val ()=check ("hints come from inferred variable patterns",length hints=6 andalso
          C.field (first,"position")=object [("line",Json.int 1),("character",Json.int 5)] andalso
          C.field (first,"label")=Json.String ": int" andalso
          List.all (fn item => C.field (item,"kind")=Json.int 1 andalso Json.member ("textEdits",item)=NONE andalso
            Json.member ("tooltip",item)=NONE andalso line item<>Json.int 0 andalso line item<>Json.int 2) hints)
        val ()=check ("visible hint ranges use insertion positions",
          hintItems (hintQuery (client,501,uri,hintRange (1,0,1,5)))=[first] andalso
          null (hintItems (hintQuery (client,502,uri,hintRange (1,0,1,4)))))
        val reordered=case first of Json.Object fields =>
              object (List.map (fn (name,Json.Object values) => (name,object (List.rev values)) | field => field) (List.rev fields))
          | _ => raise Fail "inlay hint object missing"
        val ()=C.request (client,503,"inlayHint/resolve",reordered)
        val resolved=C.result (C.response (client,503))
    in check ("lazy hint resolution preserves presentation and adds the checked tooltip",
      C.field (resolved,"position")=C.field (first,"position") andalso C.field (resolved,"label")=C.field (first,"label")
      andalso C.field (resolved,"data")=C.field (first,"data") andalso C.field (resolved,"tooltip")=Json.String "a : int"
      andalso Json.member ("textEdits",resolved)=NONE) end)
  fun inlayNegotiation () =
    let val ()=fixtureInitializedResult (object [("capabilities",object [])]) (fn (client,initialized) =>
          let val uri="untitled:unnegotiated-hints" val ()=openDocument (client,uri,"val x=1\n")
              val response=hintQuery (client,510,uri,hintRange (0,0,1,0))
          in check ("hints require client support",Json.member ("inlayHintProvider",C.field (initialized,"capabilities"))=NONE
            andalso C.field (C.field (response,"error"),"code")=Json.int (~32601)) end)
    in fixtureInitializedResult (object [("capabilities",hintCapabilities false)]) (fn (client,initialized) =>
      let val uri="untitled:eager-hints" val ()=openDocument (client,uri,"val x=1\n")
          val item=hintOne (hintQuery (client,511,uri,hintRange (0,0,1,0)))
          val ()=check ("clients without lazy tooltip support receive complete hints",
            C.field (C.field (C.field (initialized,"capabilities"),"inlayHintProvider"),"resolveProvider")=Json.Bool false
            andalso C.field (item,"tooltip")=Json.String "x : int" andalso Json.member ("data",item)=NONE)
          val ()=C.request (client,512,"inlayHint/resolve",item)
      in check ("unnegotiated hint resolution stays unsupported",C.field (C.field (C.response (client,512),"error"),"code")=Json.int (~32601)) end) end
  fun inlayEncodings () =
    let fun one (encoding,column)=fixtureInitialized (object [("capabilities",object
          [("general",object [("positionEncodings",Json.Array [Json.String encoding])]),
           ("textDocument",object [("inlayHint",object [])])]),
          ("initializationOptions",object [("sourceMode",Json.String "unicode")])]) (fn client =>
          let val uri="untitled:unicode-hints" val ()=openDocument (client,uri,"(* \240\159\154\128 *) val \206\187=1\n")
              val item=hintOne (hintQuery (client,520,uri,hintRange (0,0,1,0)))
          in check ("hint positions use negotiated " ^ encoding,
            C.field (item,"position")=object [("line",Json.int 0),("character",Json.int column)]
            andalso C.field (item,"tooltip")=Json.String "\206\187 : int") end)
    in List.app one [("utf-8",17),("utf-16",14),("utf-32",13)] end
  fun inlayValidation ()=fixtureInitialized (object [("capabilities",hintCapabilities true),
      ("initializationOptions",object [("sourceMode",Json.String "unicode")])]) (fn client =>
    let val uri="untitled:invalid-hints" val ()=openDocument (client,uri,"(* \240\159\154\128 *) val x=1\n")
        val ranges=[hintRange (1,0,0,0),hintRange (0,~1,1,0),hintRange (0,4,0,5)]
        val ()=List.app (fn range => check ("malformed hint ranges retain InvalidParams",
          C.field (C.field (hintQuery (client,530,uri,range),"error"),"code")=Json.int (~32602))) ranges
        val item=hintOne (hintQuery (client,531,uri,hintRange (0,0,1,0)))
        val ()=check ("hint ranges beyond EOF are clamped",length (hintItems (hintQuery (client,533,uri,hintRange (0,0,2,0))))=1)
        val forged=case item of Json.Object fields => object (("label",Json.String ": bool")::List.filter (fn (key,_) => key<>"label") fields)
          | _ => raise Fail "inlay hint object missing"
        val ()=C.request (client,532,"inlayHint/resolve",forged)
    in check ("modified hint labels cannot change the inferred type",C.field (C.field (C.response (client,532),"error"),"code")=Json.int (~32602)) end)
  fun inlayStale ()=fixtureWith (hintCapabilities true) (fn client =>
    let val uri="untitled:stale-hints" val ()=openDocument (client,uri,"val x=1\n")
        val old=hintOne (hintQuery (client,540,uri,hintRange (0,0,1,0)))
        val others=List.tabulate (6,fn i => "untitled:evict-hint-" ^ Int.toString i)
        val ()=List.app (fn uri => openDocument (client,uri,"val y=2\n")) others
        val ()=List.app (fn uri => ignore (hintItems (hintQuery (client,541,uri,hintRange (0,0,1,0))))) others
        val ()=C.request (client,542,"inlayHint/resolve",old)
        val ()=check ("evicted hint resolution is rejected without retrying old metadata",
          C.field (C.field (C.response (client,542),"error"),"code")=Json.int (~32801))
        val current=hintOne (hintQuery (client,543,uri,hintRange (0,0,1,0)))
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "val x=true\n")]])])
        val updated=hintOne (hintQuery (client,544,uri,hintRange (0,0,1,0)))
        val ()=check ("fresh hint queries recover views and use current types",C.field (updated,"label")=Json.String ": bool")
        val ()=C.request (client,545,"inlayHint/resolve",current)
        val ()=check ("source edits invalidate previously returned hints",C.field (C.field (C.response (client,545),"error"),"code")=Json.int (~32801))
        val forged=case (current,C.field (current,"data"),C.field (updated,"data")) of
          (Json.Object fields,Json.Object data,updatedData) =>
            object (("data",object (("revision",C.field (updatedData,"revision"))::List.filter (fn (key,_) => key<>"revision") data))::
              List.filter (fn (key,_) => key<>"data") fields)
          | _ => raise Fail "inlay hint metadata missing"
        val ()=C.request (client,546,"inlayHint/resolve",forged)
        val ()=check ("client metadata cannot relabel an older captured revision",
          C.field (C.field (C.response (client,546),"error"),"code")=Json.int (~32801))
        val ()=C.notify (client,"workspace/didChangeConfiguration",object [("settings",object [("sourceMode",Json.String "unicode")])])
        val ()=C.request (client,547,"inlayHint/resolve",updated)
    in check ("workspace changes invalidate hints without text edits",C.field (C.field (C.response (client,547),"error"),"code")=Json.int (~32801)) end)
  fun inlayRefresh () =
    let val capabilities=object [("textDocument",object [("inlayHint",object [])]),
          ("workspace",object [("inlayHint",object [("refreshSupport",Json.Bool true)])])]
        fun isRefresh value=Json.member ("method",value)=SOME (Json.String "workspace/inlayHint/refresh")
    in fixtureWith capabilities (fn client =>
      let val uri="untitled:refresh-hints" val ()=openDocument (client,uri,"val x=1\n")
          val ()=C.notify (client,"workspace/didChangeConfiguration",object [("settings",object [("sourceMode",Json.String "unicode")])])
          val refresh=C.receive (client,isRefresh)
          val ()=C.send (client,object [("jsonrpc",Json.String "2.0"),("id",C.field (refresh,"id")),("result",Json.Null)])
          val ()=ignore (hintItems (hintQuery (client,550,uri,hintRange (0,0,1,0))))
          val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
            ("contentChanges",Json.Array [object [("text",Json.String "val x=2\n")]])])
          val ()=ignore (hintItems (hintQuery (client,551,uri,hintRange (0,0,1,0))))
          val C.Client {messages,...}=client
      in check ("ordinary typing does not trigger a global inlay refresh",not (List.exists isRefresh (!messages))) end) end
  fun inlayBudget ()=fixtureWith (hintCapabilities false) (fn client =>
    let val uri="untitled:hint-budget"
        val text="val [" ^ String.concatWith "," (List.tabulate (2050,fn i => "a" ^ Int.toString i)) ^ "]=[]\n"
        val ()=openDocument (client,uri,text)
        val ()=C.request (client,559,"textDocument/diagnostic",object [("textDocument",document uri)])
        val ()=check ("hint budget fixture typechecks",C.field (C.result (C.response (client,559)),"items")=Json.Array [])
        val response=hintQuery (client,560,uri,hintRange (0,0,1,0))
        val error=C.field (response,"error")
        val ()=check ("oversized hints fail at their count limit",C.field (error,"code")=Json.int (~32803) andalso
          (case C.field (error,"message") of Json.String message => String.isSubstring "inlay hint count budget exceeded" message | _ => false))
        val subset=hintItems (hintQuery (client,561,uri,hintRange (0,0,0,12)))
        val ()=check ("a smaller hint range remains usable after refusal",not (null subset) andalso length subset<4)
        val longName="long" ^ String.implode (List.tabulate (1200,fn _ => #"a"))
        val text="datatype " ^ longName ^ "=C\nval [" ^
          String.concatWith "," (List.tabulate (1000,fn i => "b" ^ Int.toString i)) ^ "]=[C]\n"
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String text)]])])
        val ()=C.request (client,562,"textDocument/diagnostic",object [("textDocument",document uri)])
        val ()=check ("hint byte-budget fixture typechecks",C.field (C.result (C.response (client,562)),"items")=Json.Array [])
        val error=C.field (hintQuery (client,563,uri,hintRange (0,0,2,0)),"error")
    in check ("fewer long hints fail at their byte limit",C.field (error,"code")=Json.int (~32803) andalso
      (case C.field (error,"message") of Json.String message => String.isSubstring "inlay hint response budget exceeded" message | _ => false)) end)
  fun linkCapabilities tooltip=object [("textDocument",object [("documentLink",object [("tooltipSupport",Json.Bool tooltip)])])]
  fun linkFixture action =
    let val dir=OS.FileSys.tmpName ()
        val ()=(OS.FileSys.remove dir;OS.FileSys.mkDir dir)
        fun write (name,text)=let val out=TextIO.openOut (OS.Path.concat (dir,name)) in TextIO.output (out,text);TextIO.closeOut out end
        val source="MiXeD Path \206\187.sml"
        val ()=(write (source,"intentionally not Standard ML\n");write ("child.build","files end\n");write ("main.build",""))
        val platform=if OS.Path.validVolume {isAbs=true,vol="C:"} then LspUri.Windows else LspUri.Posix
        fun uri file=LspUri.original (LspUri.fromPath (platform,OS.FileSys.fullPath (OS.Path.concat (dir,file))))
        fun clean ()=(List.app (fn name => OS.FileSys.remove (OS.Path.concat (dir,name))) [source,"child.build","main.build"];OS.FileSys.rmDir dir)
    in (action {dir=dir,platform=platform,uri=uri "main.build",source=source} before clean ())
       handle error => (clean () handle _ => ();raise error) end
  fun linkQuery (client,id,uri)=
    (C.request (client,id,"textDocument/documentLink",object [("textDocument",document uri)]);C.response (client,id))
  fun linkItems response=case C.result response of Json.Array items => items | _ => raise Fail "document link array missing"
  fun documentLinks ()=linkFixture (fn {dir,platform,uri,source} =>
    fixtureInitializedResult (object [("capabilities",linkCapabilities true)]) (fn (client,initialized) =>
      let val ()=check ("document link resolution is advertised only when supported",
            C.field (C.field (C.field (initialized,"capabilities"),"documentLinkProvider"),"resolveProvider")=Json.Bool true)
          val text="files \"" ^ source ^ "\" $(MISSING)/x end\nuse child.build\nlibraries json end\ncache .\n"
          val ()=openDocument (client,uri,text)
          val items=linkItems (linkQuery (client,600,uri))
          val ()=check ("compiler path roles produce deferred links and omit unresolved variables",length items=4 andalso
            List.all (fn item => Json.member ("target",item)=NONE andalso Json.member ("tooltip",item)=NONE) items)
          val targets=[OS.Path.concat (dir,source),OS.Path.concat (dir,"child.build"),"lib/json/library.build",dir]
          fun resolve (item,expected)=
            let val reordered=case item of Json.Object fields => object (List.map
                  (fn (name,Json.Object fields) => (name,object (List.rev fields)) | field => field) (List.rev fields))
                  | _ => raise Fail "document link object missing"
                val ()=C.request (client,601,"documentLink/resolve",reordered)
                val resolved=C.result (C.response (client,601))
                val parsed=LspUri.parse (case C.field (resolved,"target") of Json.String uri => uri | _ => raise Fail "link URI missing")
                val path=case LspUri.native (platform,parsed) of SOME {path,...} => path | _ => raise Fail "link target is not a file URI"
            in check ("resolved links identify the actual native object",OS.FileSys.fileId path=OS.FileSys.fileId expected andalso
              isSome (Json.member ("tooltip",resolved)) andalso C.field (resolved,"data")=C.field (item,"data")) end
          val ()=ListPair.app resolve (items,targets)
          val first=hd items
          val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
            ("contentChanges",Json.Array [object [("text",Json.String "files child.build end\n")]])])
          val ()=C.request (client,602,"documentLink/resolve",first)
          val ()=check ("source edits invalidate old build links",C.field (C.field (C.response (client,602),"error"),"code")=Json.int (~32801))
          val current=hd (linkItems (linkQuery (client,603,uri)))
          val ()=C.notify (client,"workspace/didChangeConfiguration",object [("settings",object [("sourceMode",Json.String "unicode")])])
          val ()=C.request (client,604,"documentLink/resolve",current)
      in check ("workspace changes invalidate build links without text edits",C.field (C.field (C.response (client,604),"error"),"code")=Json.int (~32801)) end))
  fun linkNegotiation () =
    let val ()=fixtureInitializedResult (object [("capabilities",object [])]) (fn (client,initialized) =>
          let val uri="untitled:unnegotiated-links" val ()=openDocument (client,uri,"val x=1\n")
              val response=linkQuery (client,610,uri)
          in check ("document links require client support",Json.member ("documentLinkProvider",C.field (initialized,"capabilities"))=NONE
            andalso C.field (C.field (response,"error"),"code")=Json.int (~32601)) end)
    in linkFixture (fn {uri,source,...} => fixtureWith (linkCapabilities false) (fn client =>
      let val ()=openDocument (client,uri,"files \"" ^ source ^ "\" end\n")
          val item=hd (linkItems (linkQuery (client,611,uri)))
          val ()=C.request (client,612,"documentLink/resolve",item)
          val resolved=C.result (C.response (client,612))
          val ()=check ("link tooltips respect client support",Json.member ("tooltip",resolved)=NONE)
          val sml="untitled:sml-links" val ()=openDocument (client,sml,"val path=\"child.build\"\n")
      in check ("ordinary SML strings do not become guessed links",C.result (linkQuery (client,613,sml))=Json.Null) end)) end
  fun linkValidation ()=linkFixture (fn {uri,source,...} => fixtureWith (linkCapabilities true) (fn client =>
    let val ()=openDocument (client,uri,"files \"" ^ source ^ "\" missing.sml end\n")
        val items=linkItems (linkQuery (client,620,uri))
        val first=hd items
        val forged=case first of Json.Object fields => object (("range",hintRange (0,0,0,1))::List.filter (fn (name,_) => name<>"range") fields)
          | _ => raise Fail "document link object missing"
        val ()=C.request (client,621,"documentLink/resolve",forged)
        val ()=check ("modified document link ranges are rejected",C.field (C.field (C.response (client,621),"error"),"code")=Json.int (~32602))
        val ()=C.request (client,622,"documentLink/resolve",List.nth (items,1))
    in check ("missing file targets fail explicitly on resolve",C.field (C.field (C.response (client,622),"error"),"code")=Json.int (~32803)) end))
  fun linkBudget ()=linkFixture (fn {dir,platform,uri,...} => fixtureWith (linkCapabilities false) (fn client =>
    let val text="files " ^ String.concat (List.tabulate (2050,fn _ => "missing.sml ")) ^ "end\n"
        val ()=openDocument (client,uri,text)
        val error=C.field (linkQuery (client,630,uri),"error")
        val ()=check ("link count budget refuses rather than truncates",C.field (error,"code")=Json.int (~32803) andalso
          (case C.field (error,"message") of Json.String text => String.isSubstring "document link count budget exceeded" text | _ => false))
        val leaf="L" ^ String.implode (List.tabulate (200,fn _ => #" ")) ^ "main.build"
        val longUri=LspUri.original (LspUri.fromPath (platform,OS.Path.concat (dir,leaf)))
        val ()=openDocument (client,longUri,"files " ^ String.concat (List.tabulate (1500,fn _ => "missing.sml ")) ^ "end\n")
        val error=C.field (linkQuery (client,631,longUri),"error")
    in check ("link byte budget is independent of its count budget",C.field (error,"code")=Json.int (~32803) andalso
      (case C.field (error,"message") of Json.String text => String.isSubstring "document link response budget exceeded" text | _ => false)) end))
  fun buildDocuments () =
    let val dir=OS.FileSys.tmpName ()
        val ()=(OS.FileSys.remove dir handle _ => ();OS.FileSys.mkDir dir)
        fun write (name,text)=let val output=TextIO.openOut (dir ^ "/" ^ name)
          in TextIO.output (output,text);TextIO.closeOut output end
        val ()=write ("main.build","")
        val ()=write ("alpha space.sml","val ()=print \"build requests must not execute this\\n\"\n")
        val platform=if List.exists (fn (key,value) => key="sysname" andalso value="Windows") (Posix.ProcEnv.uname ()) then LspUri.Windows else LspUri.Posix
        val uri=LspUri.original (LspUri.fromPath (platform,OS.FileSys.fullPath (dir ^ "/main.build")))
        fun clean ()=(OS.FileSys.remove (dir ^ "/main.build");OS.FileSys.remove (dir ^ "/alpha space.sml");OS.FileSys.rmDir dir)
        fun work ()=fixtureWith (hintCapabilities true) (fn client =>
          let val ()=openDocument (client,uri,"files \"alpha sp")
              val ()=C.request (client,180,"textDocument/diagnostic",object [("textDocument",document uri)])
              val diagnostic=C.result (C.response (client,180))
              val ()=check ("build documents receive build grammar diagnostics",case C.field (diagnostic,"items") of Json.Array [item] =>
                C.field (item,"source")=Json.String "rune-build" andalso
                C.field (C.field (C.field (item,"range"),"start"),"character")=Json.int 6 | _ => false)
              val ()=C.request (client,181,"textDocument/completion",object [("textDocument",document uri),
                ("position",object [("line",Json.int 0),("character",Json.int 15)])])
              val result=C.result (C.response (client,181))
              val item=case C.field (result,"items") of Json.Array [item] => item | _ => raise Fail "quoted build path completion missing"
              val ()=check ("build completion supplies valid quoting and the complete token range",
                C.field (C.field (item,"textEdit"),"newText")=Json.String "\"alpha space.sml\"" andalso
                C.field (C.field (C.field (item,"textEdit"),"range"),"start")=object [("line",Json.int 0),("character",Json.int 6)])
              val ()=C.request (client,182,"completionItem/resolve",item)
              val resolved=C.result (C.response (client,182))
              val ()=check ("build completion resolves against its original revision",C.field (resolved,"label")=Json.String "alpha space.sml")
              val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
                ("contentChanges",Json.Array [object [("text",Json.String "files \"alpha space.sml\" end\n")]])])
              val ()=C.request (client,183,"textDocument/diagnostic",object [("textDocument",document uri)])
              val corrected=C.result (C.response (client,183))
              val ()=check ("valid build overlays clear errors without SML parsing or execution",C.field (corrected,"items")=Json.Array [])
              val ()=C.request (client,185,"textDocument/selectionRange",object [("textDocument",document uri),
                ("positions",Json.Array [object [("line",Json.int 0),("character",Json.int 8)]])])
              val selection=C.result (C.response (client,185))
              val ()=check ("build selections use actual grammar path spans",case selection of Json.Array [node] =>
                (case LspProtocol.rangeFromJson (C.field (node,"range")) of SOME range =>
                  range={start={line=0,character=6},stop={line=0,character=23}} | _ => false) | _ => false)
              val ()=check ("build paths do not fabricate SML type hints",
                C.result (hintQuery (client,187,uri,hintRange (0,0,1,0)))=Json.Null)
              val ()=C.request (client,184,"completionItem/resolve",item)
              val stale=C.response (client,184)
          in check ("build path resolution rejects stale source revisions",C.field (C.field (stale,"error"),"code")=Json.int (~32801)) end)
    in (work () before clean ()) handle error => (clean () handle _ => ();raise error) end
end
structure RuneLspSemanticProtocolTestMain=Main (struct
  val name="lsp-semantic-protocol"
  val tests=Test.describe "lsp-semantic-protocol" [Test.it "diagnostics-and-hover" (fn () => RuneLspSemanticProtocolTests.diagnostics ()),
    Test.it "cancellation" RuneLspSemanticProtocolTests.cancellation,
    Test.it "pull-refresh" RuneLspSemanticProtocolTests.pullRefresh,
    Test.it "progress-cancellation" RuneLspSemanticProtocolTests.progressCancellation,
    Test.it "stale-diagnostics" RuneLspSemanticProtocolTests.staleDiagnostics,
    Test.it "markup-negotiation" RuneLspSemanticProtocolTests.markup,
    Test.it "file-project-mapping" RuneLspSemanticProtocolTests.fileProject,
    Test.it "workspace-diagnostics" RuneLspSemanticProtocolTests.workspaceDiagnostics,
    Test.it "workspace-context-reporting" RuneLspSemanticProtocolTests.workspaceContexts,
    Test.it "live-analysis-progress" RuneLspSemanticProtocolTests.analysisProgress,
    Test.it "idle-workspace-polls" RuneLspSemanticProtocolTests.idleWorkspacePolls,
    Test.it "eviction-refresh-loop" RuneLspSemanticProtocolTests.evictionRefreshLoop,
    Test.it "watched-workspace-cache" RuneLspSemanticProtocolTests.watchedWorkspaceCache,
    Test.it "query-before-eviction" RuneLspSemanticProtocolTests.queryBeforeEviction,
    Test.it "context-selection-recovery" RuneLspSemanticProtocolTests.contextSelectionRecovery,
    Test.it "basis-development-context" RuneLspSemanticProtocolTests.basisDevelopment,
    Test.it "navigation-and-symbols" RuneLspSemanticProtocolTests.navigation,
    Test.it "workspace-symbols-resolve" RuneLspSemanticProtocolTests.workspaceSymbols,
    Test.it "document-highlights" RuneLspSemanticProtocolTests.documentHighlights,
    Test.it "highlight-position-encodings" RuneLspSemanticProtocolTests.highlightEncodings,
    Test.it "highlight-response-budget" RuneLspSemanticProtocolTests.highlightBudget,
    Test.it "highlight-source-occurrence" RuneLspSemanticProtocolTests.highlightOccurrence,
    Test.it "structural-ranges" RuneLspSemanticProtocolTests.structuralRanges,
    Test.it "folding-client-limits" RuneLspSemanticProtocolTests.foldingLimits,
    Test.it "selection-validation" RuneLspSemanticProtocolTests.selectionValidation,
    Test.it "folding-refresh" RuneLspSemanticProtocolTests.foldingRefresh,
    Test.it "semantic-tokens" RuneLspSemanticProtocolTests.semanticTokens,
    Test.it "semantic-token-encodings" RuneLspSemanticProtocolTests.semanticTokenEncodings,
    Test.it "semantic-token-negotiation" RuneLspSemanticProtocolTests.semanticTokenNegotiation,
    Test.it "semantic-token-history" RuneLspSemanticProtocolTests.semanticTokenHistory,
    Test.it "semantic-token-recovery" RuneLspSemanticProtocolTests.semanticTokenRecovery,
    Test.it "semantic-token-refresh" RuneLspSemanticProtocolTests.semanticTokenRefresh,
    Test.it "semantic-token-validation" RuneLspSemanticProtocolTests.semanticTokenValidation,
    Test.it "semantic-token-response-budget" RuneLspSemanticProtocolTests.semanticTokenBudget,
    Test.it "inferred-type-hints" RuneLspSemanticProtocolTests.inlayHints,
    Test.it "inlay-negotiation" RuneLspSemanticProtocolTests.inlayNegotiation,
    Test.it "inlay-encodings" RuneLspSemanticProtocolTests.inlayEncodings,
    Test.it "inlay-validation" RuneLspSemanticProtocolTests.inlayValidation,
    Test.it "inlay-stale-and-eviction" RuneLspSemanticProtocolTests.inlayStale,
    Test.it "inlay-refresh" RuneLspSemanticProtocolTests.inlayRefresh,
    Test.it "inlay-response-budget" RuneLspSemanticProtocolTests.inlayBudget,
    Test.it "build-document-links" RuneLspSemanticProtocolTests.documentLinks,
    Test.it "document-link-negotiation" RuneLspSemanticProtocolTests.linkNegotiation,
    Test.it "document-link-validation" RuneLspSemanticProtocolTests.linkValidation,
    Test.it "document-link-response-budgets" RuneLspSemanticProtocolTests.linkBudget,
    Test.it "completion" RuneLspSemanticProtocolTests.completion,
    Test.it "signature-help" RuneLspSemanticProtocolTests.signatureHelp,
    Test.it "completion-snippets" RuneLspSemanticProtocolTests.completionSnippets,
    Test.it "inline-completion" RuneLspSemanticProtocolTests.inlineCompletion,
    Test.it "completion-context-and-documentation" RuneLspSemanticProtocolTests.completionContextAndDocumentation,
    Test.it "legacy-completion-fallback" RuneLspSemanticProtocolTests.legacyCompletionFallback,
    Test.it "semantic-errors-and-eviction" RuneLspSemanticProtocolTests.semanticErrorsAndEviction,
    Test.it "build-documents" RuneLspSemanticProtocolTests.buildDocuments]
end)
val ()=RuneLspSemanticProtocolTestMain.main ()

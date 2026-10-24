(* Deterministic completion races: real document revisions and service events,
   without timing a worker process against a document change. *)
structure RuneLspServiceTests =
struct
  structure S=RuneLspService
  structure D=RuneLspDocuments
  structure W=RuneLspWorkspace
  structure J=RuneLspJobs
  structure V=RuneLspWorkerWire
  structure R=JsonRpc
  val check=Expect.that
  fun fixture action =
    let val documents=D.new (LspProtocol.Utf16,{maxDocuments=1,maxDocumentBytes=1000,maxTotalBytes=1000,
          maxDocumentLines=100,maxTotalLines=100})
        val initial=D.openDocument (documents,{uri="untitled:race",languageId="sml",version=1,text="val x=1\n"})
        val workspace=W.new {platform=LspUri.Posix,lib="lib"}
        val output=ref [] : R.message list ref
        val service=S.new {workspace=workspace,documents=documents,caps=valOf (LspProtocol.capabilities (Json.Object
          [("textDocument",Json.Object [("inlayHint",Json.Object [("resolveSupport",Json.Object [("properties",Json.Array [Json.String "tooltip"])])])])])),
          command="unused-worker",args=[],send=fn value => output:= !output @ [value],log=fn _ => (),discovered=fn _ => (),
          watchedRoots=fn () => []}
        fun request method : S.request={id=R.Number 1,method=method,params=Json.Object [],uri= #uri initial,
          revision= #revision initial,generation=W.generation workspace,done=ref false,job=ref NONE,retried=ref false}
        fun change ()=ignore (D.changeDocument (documents,{uri= #uri initial,version=2,changes=[D.Replace "val x=2\n"]}))
        fun work ()=action {service=service,request=request,change=change,dirty=fn () => W.dirty workspace,output=output}
    in (work () before S.close service) handle error => (S.close service;raise error) end
  fun changed () = List.app (fn method => fixture (fn {service,request,change,output,...} =>
    let val request=request method
        val ()=change ()
        val result=if String.isPrefix "textDocument/semanticTokens/" method then Json.Object [("data",Json.Array [])]
          else if method="textDocument/hover" then Json.Null else Json.Array []
        val ()=S.handleEvent (service,J.Done (S.Query request,V.json result))
    in check ("changed sources reject " ^ method,case !output of
      [R.Response {outcome=R.Error {code,...},...}] => code=LspProtocol.contentModified | _ => false) end))
    ["textDocument/semanticTokens/full","textDocument/semanticTokens/full/delta","textDocument/semanticTokens/range",
     "textDocument/foldingRange","textDocument/selectionRange","textDocument/hover","textDocument/documentHighlight",
     "textDocument/inlayHint","inlayHint/resolve"]
  fun checked ()=fixture (fn {service,request,change,output,...} =>
    let val request=request "textDocument/semanticTokens/full"
        val ()=change ()
        val ticket={uri= #uri request,revision= #revision request,generation= #generation request,request=SOME request}
        val ()=S.handleEvent (service,J.Done (S.Check ticket,V.Object [("snapshot",V.Bytes "old"),("reports",V.Array [])]))
    in check ("obsolete checks do not enqueue a stale query",case !output of
      [R.Response {outcome=R.Error {code,...},...}] => code=LspProtocol.contentModified | _ => false) end)
  fun unchanged ()=fixture (fn {service,request,output,...} =>
    let val request=request "textDocument/semanticTokens/full"
        val result=Json.Object [("data",Json.Array [])]
        val ()=S.handleEvent (service,J.Done (S.Query request,V.json result))
        val ()=S.handleEvent (service,J.Done (S.Query request,V.json result))
    in check ("a current worker completion is returned exactly once",case !output of
      [R.Response {outcome=R.Result value,...}] => value=result | _ => false) end)
  fun generation ()=fixture (fn {service,request,dirty,output,...} =>
    let val request=request "textDocument/semanticTokens/full"
        val ()=dirty ()
        val ()=S.handleEvent (service,J.Done (S.Query request,V.json (Json.Object [("data",Json.Array [])])))
    in check ("workspace changes invalidate replies even without text edits",case !output of
      [R.Response {outcome=R.Error {code,...},...}] => code=LspProtocol.contentModified | _ => false) end)
  fun invalidResolution ()=fixture (fn {service,request,output,...} =>
    let val original=request "inlayHint/resolve"
        fun send generation=ignore (S.request (service,{id=R.Number 77,method="inlayHint/resolve",params=SOME (Json.Object
          [("data",Json.Object [("uri",Json.String (#uri original)),("snapshot",Json.String "unused"),
            ("revision",Json.intInf (#revision original+1)),("generation",generation)])])}))
        val ()=send (Json.String "invalid")
        val ()=send (Json.intInf (#generation original))
    in check ("invalid metadata does not retain a completed request id",case !output of
      [R.Response {outcome=R.Error {code=first,...},...},R.Response {outcome=R.Error {code=second,...},...}] =>
        first=R.invalidParams andalso second=LspProtocol.contentModified | _ => false) end)
  fun sharedChecks ()=fixture(fn {service,output,change,...}=>
    let val S.Service{jobs=J.Jobs{queue,...},requests,...}=service
        fun send id=ignore(S.request(service,{id=R.Number id,method="textDocument/hover",params=SOME(Json.Object
          [("textDocument",Json.Object[("uri",Json.String "untitled:race")]),
           ("position",Json.Object[("line",Json.int 0),("character",Json.int 4)])])}))
        val ()=(send 1;send 2)
        val ()=check("provider burst shares one check",length(!queue)=1 andalso length(!requests)=2)
        val task= #data(hd(!queue))
        val ()=S.cancel(service,R.Number 1)
        val J.Jobs{events,...}=case service of S.Service{jobs,...}=>jobs
        val ()=check("cancelling one waiter preserves the shared check",null(!events))
        val ()=queue:=[]
        val ()=S.handleEvent(service,J.Done(task,V.Object[("snapshot",V.Bytes "shared"),("reports",V.Array [])]))
        val ()=check("only the remaining waiter is queried",case !queue of [job]=>
          (case #data job of S.Query request=> #id request=R.Number 2 | _=>false) | _=>false)
    in () end)
  fun failedChecks ()=fixture(fn {service,output,change,...}=>
    let val S.Service{jobs=J.Jobs{queue,...},...}=service
        fun send id=ignore(S.request(service,{id=R.Number id,method="textDocument/hover",params=SOME(Json.Object
          [("textDocument",Json.Object[("uri",Json.String "untitled:race")])])}))
        val ()=(send 1;send 2)
        val task= #data(hd(!queue)) val ()=queue:=[]
        val ()=S.handleEvent(service,J.Failed(task,"analysis worker exhausted its heap budget"))
        val ()=send 3
        fun failed(R.Response{outcome=R.Error{message,...},...})=message="analysis worker exhausted its heap budget" | failed _=false
        val ()=check("failure fans out once and unchanged source does not retry",length(!output)=3
          andalso List.all failed(!output) andalso null(!queue))
        val ()=change() val ()=send 4
    in check("a new revision permits recovery",length(!queue)=1) end)
  fun workspacePriority ()=fixture(fn {service,...}=>
    let val S.Service{jobs=J.Jobs{queue,...},workspaceJobs=J.Jobs{queue=background,...},...}=service
        val _=S.request(service,{id=R.Number 1,method="workspace/diagnostic",params=SOME(Json.Object[])})
        val ()=check("workspace pulls use their own queue",null(!queue) andalso case !background of
          [job]=> (case #data job of S.Workspace _=>true | _=>false) | _=>false)
        val _=S.request(service,{id=R.Number 2,method="textDocument/hover",params=SOME(Json.Object
          [("textDocument",Json.Object[("uri",Json.String "untitled:race")])])})
        val task= #data(hd(!queue))
        val ()=check("document checks use the foreground queue",case task of S.Check _=>true | _=>false)
        val ()=queue:=tl(!queue)
        val ()=S.handleEvent(service,J.Done(task,V.Object[("snapshot",V.Bytes "shared"),("reports",V.Array [])]))
    in check("queries stay separate from pending workspace pulls",case (!queue,!background) of
      ([first],[second])=> (case (#data first,#data second) of (S.Query _,S.Workspace _)=>true | _=>false) | _=>false) end)
end
structure RuneLspServiceTestMain=Main (struct
  val name="lsp-service"
  val tests=Test.describe "lsp-service" [Test.it "stale-query-completions" RuneLspServiceTests.changed,
    Test.it "stale-check-completions" RuneLspServiceTests.checked,Test.it "current-completion-once" RuneLspServiceTests.unchanged,
    Test.it "workspace-generation-completions" RuneLspServiceTests.generation,
    Test.it "invalid-hint-resolution" RuneLspServiceTests.invalidResolution,
    Test.it "shared-check-cancellation" RuneLspServiceTests.sharedChecks,
    Test.it "failed-check-backoff" RuneLspServiceTests.failedChecks,
    Test.it "foreground-isolated-from-workspace-pull" RuneLspServiceTests.workspacePriority]
end)
val ()=RuneLspServiceTestMain.main ()

(* Request/version policy around the generic worker scheduler. *)
structure RuneLspService =
struct
  structure V=RuneLspWorkerWire
  structure J=RuneLspJobs
  structure D=RuneLspDocuments
  structure W=RuneLspWorkspace
  structure P=LspProtocol
  structure R=JsonRpc
  structure S=RuneLspSync
  structure Q=LspRequests
  type request={id:R.id,method:string,params:Json.value,uri:string,revision:IntInf.int,generation:IntInf.int,
    done:bool ref,job:IntInf.int option ref,retried:bool ref}
  datatype task=Discover of {uri:string,revision:IntInf.int,generation:IntInf.int}
    | Check of {uri:string,revision:IntInf.int,generation:IntInf.int,request:request option}
    | Build of {uri:string,revision:IntInf.int,generation:IntInf.int,request:request option}
    | Query of request | Workspace of request
  type result={uri:string,revision:IntInf.int,generation:IntInf.int,snapshot:string}
  type flight={uri:string,revision:IntInf.int,generation:IntInf.int,job:IntInf.int}
  type failed={uri:string,revision:IntInf.int,generation:IntInf.int,message:string}
  exception Duplicate
  datatype t=Service of {workspace:W.t,documents:D.t,caps:P.capabilities,jobs:task J.t,
    results:result list ref,requests:request list ref,flights:flight list ref,failures:failed list ref,
    refresh:unit Q.t,refreshPending:bool ref,send:R.message->unit,log:string->unit,
    discovered:string*V.value->unit}
  fun new {workspace,documents,caps,command,args,send,log,discovered} =
    Service {workspace=workspace,documents=documents,caps=caps,jobs=J.new {command=command,args=args,
      timeout=Time.fromSeconds 30,cancelGrace=Time.fromMilliseconds 250,maxPending=128},results=ref [],requests=ref [],
      flights=ref [],failures=ref [],refresh=Q.new {prefix="runelsp-diagnostics-",maxPending=1},refreshPending=ref false,
      send=send,log=log,discovered=discovered}
  fun current (Service {workspace,documents,...},{uri,revision,generation}) =
    W.generation workspace=generation andalso (uri="" orelse (D.healthy (documents,uri) andalso
      (case D.snapshot (documents,uri) of SOME snapshot => #revision snapshot=revision | NONE => false)))
  fun finish (Service {send,requests,...},request:request,outcome) =
    if !(#done request) then () else
      let val outcome=case (outcome,#method request,Json.member ("partialResultToken",#params request)) of
            (R.Result result,"workspace/diagnostic",SOME token) =>
              (send (R.Notification {method="$/progress",params=SOME (Json.Object [("token",token),("value",result)])});
               R.Result (Json.Object [("items",Json.Array [])]))
          | _ => outcome
          val ()=case Json.member ("workDoneToken",#params request) of NONE => () | SOME token =>
            send (R.Notification {method="$/progress",params=SOME (Json.Object [("token",token),
              ("value",Json.Object [("kind",Json.String "end")])])})
      in #done request:=true;requests:=List.filter (fn pending:request => #id pending<> #id request) (!requests);
         send (R.Response {id=SOME (#id request),outcome=outcome}) end
  fun failure (service,request,code,message,data)=finish (service,request,R.Error {code=code,message=message,data=data})
  fun submit (Service {jobs,...},parameters)=J.submit (jobs,parameters)
  fun capture (Service {workspace,documents,...})=RuneLspWorkerModel.capture (workspace,documents)
  fun buildDocument (Service {workspace=W.Workspace {platform,...},documents,...},uri)=
    case D.snapshot (documents,uri) of NONE => false | SOME snapshot => RuneLspBuild.isDocument (platform,snapshot)
  fun buildJob (service as Service {workspace,documents,caps,log,...},uri,request) =
    case D.snapshot (documents,uri) of NONE => () | SOME snapshot =>
      let val method=case request of NONE => "textDocument/diagnostic" | SOME request => #method (request:request)
          val params=case request of NONE => Json.Object [("textDocument",Json.Object [("uri",Json.String uri)])]
            | SOME request => #params request
          val id=submit (service,{key=case request of NONE => SOME ("check:" ^ uri) | SOME _ => NONE,
            priority=if isSome request then 0 else 100,
            data=Build {uri=uri,revision= #revision snapshot,generation=W.generation workspace,request=request},
            payload=V.Object [("op",V.Bytes "build"),("uri",V.Bytes uri),("method",V.Bytes method),("params",V.json params),
              ("capabilities",V.json (P.rawCapabilities caps)),
              ("encoding",V.Bytes (P.encodingName (P.positionEncoding caps))),("state",capture service)]})
      in Option.app (fn request:request => #job request:=SOME id) request end
      handle J.Full => (case request of NONE => log "analysis queue is full"
        | SOME request => failure (service,request,P.requestFailed,"analysis queue is full",NONE))
  fun discover (service as Service {workspace,documents,log,...},uri) =
    if buildDocument (service,uri) then buildJob (service,uri,NONE) else
    case D.snapshot (documents,uri) of NONE => () | SOME snapshot =>
      (ignore (submit (service,{key=SOME ("discover:" ^ uri),priority=50,
        data=Discover {uri=uri,revision= #revision snapshot,generation=W.generation workspace},
        payload=V.Object [("op",V.Bytes "discover"),("uri",V.Bytes uri),("state",capture service)]}))
       handle J.Full => log "analysis queue is full")
  fun check (service as Service {workspace,documents,caps,log,flights,failures,results,...},uri,request) =
    if buildDocument (service,uri) then buildJob (service,uri,request) else
    case D.snapshot (documents,uri) of NONE => () | SOME snapshot =>
      let val revision= #revision snapshot val generation=W.generation workspace
          val blocked=List.find(fn item:failed=> #uri item=uri andalso #revision item=revision andalso #generation item=generation)(!failures)
          val running=List.find(fn item:flight=> #uri item=uri andalso #revision item=revision andalso #generation item=generation)(!flights)
          val ready=List.exists(fn item:result=> #uri item=uri andalso #revision item=revision andalso #generation item=generation)(!results)
      in if not(isSome request) andalso ready then () else
       case blocked of SOME item=>Option.app(fn request=>failure(service,request,P.requestFailed,#message item,NONE))request
       | NONE=>let val id=case running of SOME item=> #job item | NONE=>
          let val id=submit (service,{key=SOME ("check:" ^ uri),
            priority=if isSome request then 0 else 100,
            data=Check {uri=uri,revision= #revision snapshot,generation=W.generation workspace,request=request},
            payload=V.Object [("op",V.Bytes "check"),("uri",V.Bytes uri),
              ("encoding",V.Bytes (P.encodingName (P.positionEncoding caps))),
              ("capabilities",V.json (P.rawCapabilities caps)),("state",capture service)]})
          in flights:={uri=uri,revision=revision,generation=generation,job=id}:: !flights;id end
        in Option.app (fn request:request => #job request:=SOME id) request end end
      handle J.Full => (case request of NONE => log "analysis queue is full"
        | SOME request => failure (service,request,P.requestFailed,"analysis queue is full",NONE))
  fun query (service as Service {jobs,...},request:request,snapshot) =
    let val id=J.submit (jobs,{key=NONE,priority=0,data=Query request,payload=V.Object
          [("op",V.Bytes "query"),("snapshot",V.Bytes snapshot),("uri",V.Bytes(#uri request)),
           ("method",V.Bytes (#method request)),("params",V.json (#params request))]})
    in #job request:=SOME id end
    handle J.Full => failure (service,request,P.requestFailed,"analysis queue is full",NONE)
  fun accepts method=List.exists (fn candidate => candidate=method) ["textDocument/diagnostic","workspace/diagnostic","textDocument/hover",
    "textDocument/definition","textDocument/declaration","textDocument/typeDefinition","textDocument/implementation","textDocument/documentSymbol","textDocument/documentHighlight",
    "workspace/symbol","workspaceSymbol/resolve","textDocument/completion","completionItem/resolve","textDocument/signatureHelp",
    "textDocument/inlineCompletion","textDocument/foldingRange","textDocument/selectionRange",
    "textDocument/semanticTokens/full","textDocument/semanticTokens/full/delta","textDocument/semanticTokens/range",
    "textDocument/inlayHint","inlayHint/resolve","textDocument/documentLink","documentLink/resolve"]
  fun resolving method=method="completionItem/resolve" orelse method="inlayHint/resolve" orelse method="documentLink/resolve"
  fun inlineClient caps=case Json.member ("textDocument",P.rawCapabilities caps) of NONE => false | SOME value =>
    (case Json.member ("inlineCompletion",value) of SOME (Json.Object _) => true | _ => false)
  fun request (service as Service {workspace,documents,caps,jobs,requests,results,...},{id,method,params}) =
    if not (accepts method) orelse method="textDocument/inlineCompletion" andalso not (inlineClient caps) orelse
       RuneLspTokens.method method andalso not (RuneLspTokens.enabled (P.rawCapabilities caps,method)) orelse
       RuneLspHints.method method andalso not (RuneLspHints.supported (P.rawCapabilities caps,method)) orelse
       RuneLspBuild.linkMethod method andalso not (RuneLspBuild.linkClient (P.rawCapabilities caps)) then false else
    let val params=case params of SOME params => S.object params | NONE => raise S.Invalid "missing semantic parameters"
        val workspaceRequest=List.exists (fn candidate => candidate=method) ["workspace/diagnostic","workspace/symbol","workspaceSymbol/resolve"]
        val uri=if workspaceRequest then "" else S.string (S.required (S.object (S.required
          (params,if resolving method then "data" else "textDocument")),"uri"))
        val revision=if workspaceRequest then 0 else case D.snapshot (documents,uri) of SOME snapshot => #revision snapshot
          | NONE => raise S.Invalid "document is not open"
        val ()=if workspaceRequest orelse D.healthy (documents,uri) then () else raise S.Invalid "document synchronization requires a replacement"
        val ()=if List.exists (fn pending:request => #id pending=id) (!requests) then raise Duplicate else ()
        fun token name=case Json.member (name,params) of NONE => () | SOME (Json.String _) => ()
          | SOME value => if isSome (P.integer value) then () else raise S.Invalid "invalid progress token"
        val ()=(token "workDoneToken";token "partialResultToken")
        val hintResolution=if method<>"inlayHint/resolve" then NONE else
          let val data=S.object (S.required (params,"data"))
              fun number name=case Json.toIntInf (S.required (data,name)) of SOME value => value
                | NONE => raise S.Invalid ("invalid inlay hint " ^ name)
          in SOME {snapshot=S.string (S.required (data,"snapshot")),revision=number "revision",generation=number "generation"} end
        val request={id=id,method=method,params=params,uri=uri,revision=revision,generation=W.generation workspace,
          done=ref false,job=ref NONE,retried=ref false}:request
        val ()=requests:=request :: !requests
        val ()=case Json.member ("workDoneToken",params) of NONE => () | SOME token =>
          let val Service {send,...}=service
          in send (R.Notification {method="$/progress",params=SOME (Json.Object [("token",token),
            ("value",Json.Object [("kind",Json.String "begin"),("title",Json.String "Analyze Rune sources"),("cancellable",Json.Bool true)])])}) end
        val prior=List.find (fn result:result => #uri result=uri andalso #revision result=revision
          andalso #generation result=W.generation workspace) (!results)
    in ((if workspaceRequest then
          #job request:=SOME (J.submit (jobs,{key=NONE,priority=if method="workspace/diagnostic" then 25 else 0,
            data=Workspace request,payload=V.Object
            [("op",V.Bytes "workspace"),("state",capture service),("params",V.json params),
             ("method",V.Bytes method),
             ("encoding",V.Bytes (P.encodingName (P.positionEncoding caps))),("capabilities",V.json (P.rawCapabilities caps))]}))
        else if buildDocument (service,uri) then buildJob (service,uri,SOME request)
        else case hintResolution of SOME item =>
          if #revision item<>revision orelse #generation item<> #generation request then
            failure (service,request,P.contentModified,"inlay hint context changed",NONE)
          else query (service,request,#snapshot item)
        | NONE => (case prior of SOME result => query (service,request,#snapshot result) | NONE => check (service,uri,SOME request)));true)
        handle J.Full => (failure (service,request,P.requestFailed,"analysis queue is full",NONE);true) end
    handle Duplicate =>
      let val Service {send,...}=service
      in send (R.Response {id=NONE,outcome=R.Error {code=R.invalidRequest,message="duplicate pending request id",data=NONE}});true end
    | S.Invalid message =>
      let val Service {send,...}=service
      in send (R.Response {id=SOME id,outcome=R.Error {code=R.invalidParams,message=message,data=NONE}});true end
  fun cancel (service as Service {jobs,requests,...},id) =
    case List.find (fn request:request => #id request=id) (!requests) of NONE => () | SOME request =>
      (failure (service,request,R.requestCancelled,"request cancelled",NONE);Option.app (fn id =>
        if List.exists(fn other:request=> !(#job other)=SOME id andalso not(!(#done other)))(!requests)
        then () else J.cancel (jobs,id)) (!(#job request)))
  fun cancelProgress (service as Service {requests,...},token) =
    List.app (fn request:request => if Json.member ("workDoneToken",#params request)=SOME (P.idToJson token)
      then cancel (service,#id request) else ()) (!requests)
  fun changed (service as Service {jobs,requests,...}) =
    List.app (fn request:request => if not (List.exists (fn method => method= #method request)
      ["textDocument/diagnostic","workspace/diagnostic"]) orelse
      current (service,{uri= #uri request,revision= #revision request,generation= #generation request}) then () else
      (failure (service,request,P.serverCancelled,"diagnostic source changed",SOME (Json.Object [("retriggerRequest",Json.Bool true)]));
       Option.app (fn id => J.cancel (jobs,id)) (!(#job request)))) (!requests)
  fun pullClient (Service {caps,...}) = case Json.member ("textDocument",P.rawCapabilities caps) of
    SOME value => (case Json.member ("diagnostic",value) of SOME (Json.Object _) => true | _ => false) | _ => false
  fun refresh (service as Service {caps,send,refresh,refreshPending,...}) =
    if not (pullClient service) orelse !refreshPending orelse not (P.supports (caps,["workspace","diagnostics","refreshSupport"])) then () else
      (refreshPending:=true;send (Q.issue (refresh,{method="workspace/diagnostic/refresh",params=NONE,data=()})))
  fun response (Service {refresh,refreshPending,...},message) =
    case Q.resolve (refresh,message) of NONE => false | SOME _ => (refreshPending:=false;true)
  fun closeDocument (service as Service {results,failures,send,...},uri) =
    (results:=List.filter (fn result:result => #uri result<>uri) (!results);
     failures:=List.filter(fn item:failed=> #uri item<>uri)(!failures);
     if pullClient service then refresh service else send (R.Notification {method="textDocument/publishDiagnostics",params=SOME (Json.Object
       [("uri",Json.String uri),("diagnostics",Json.Array [])])}))
  fun publish (service as Service {documents,caps,send,...},reports) =
    if pullClient service then refresh service else List.app (fn report =>
      let val uri=V.bytes (V.field (report,"uri"))
          val version=case V.field (report,"version") of V.Null => NONE | value => SOME (V.integer value)
          val json=V.unjson (V.field (report,"report"))
          val items=case Json.member ("items",json) of SOME items => items | NONE => Json.Array []
          val fields=[("uri",Json.String uri),("diagnostics",items)] @
            (case version of NONE => [] | SOME version => if P.supports (caps,["textDocument","publishDiagnostics","versionSupport"])
              then [("version",Json.intInf version)] else [])
          val valid=case D.snapshot (documents,uri) of NONE => not (isSome version)
            | SOME snapshot => version=SOME (#version snapshot) andalso D.healthy (documents,uri)
      in if valid then send (R.Notification {method="textDocument/publishDiagnostics",params=SOME (Json.Object fields)}) else () end) reports
  fun finishQuery (service,request:request,value) =
    if not (current (service,
      {uri= #uri request,revision= #revision request,generation= #generation request})) then
      if #method request="textDocument/diagnostic" then
        failure (service,request,P.serverCancelled,"diagnostic source changed",SOME (Json.Object [("retriggerRequest",Json.Bool true)]))
      else failure (service,request,P.contentModified,"query source changed",NONE)
    else finish (service,request,R.Result (V.unjson value))
  (* A check belongs to captured source, not to its first requesting provider.
     Detach all waiters atomically before dispatching their independent queries. *)
  fun waiters (Service {flights,requests,...},{uri,revision,generation,request}) =
    let val matching=List.find(fn item:flight=> #uri item=uri andalso #revision item=revision andalso #generation item=generation)(!flights)
        val ()=flights:=List.filter(fn item:flight=>not(#uri item=uri andalso #revision item=revision andalso #generation item=generation))(!flights)
    in case matching of NONE=>(case request of NONE=>[] | SOME request=>[request])
     | SOME item=>List.filter(fn request:request=> !(#job request)=SOME(#job item) andalso not(!(#done request)))(!requests) end
  fun failedCheck (service as Service {failures,log,...},ticket,message) =
    let val pending=waiters(service,ticket)
        val item={uri= #uri ticket,revision= #revision ticket,generation= #generation ticket,message=message}:failed
        val all=item::List.filter(fn prior:failed=> #uri prior<> #uri item)(!failures)
        val ()=if current(service,{uri= #uri ticket,revision= #revision ticket,generation= #generation ticket})
          then failures:=List.take(all,Int.min(64,length all)) else ()
    in if null pending then log message else List.app(fn request=>failure(service,request,P.requestFailed,message,NONE))pending end
  fun handleEvent (service as Service {results,discovered,log,...},event) =
    case event of J.Restarted => results:=[]
    | J.Done (Discover ticket,value) => if current (service,ticket) then discovered (#uri ticket,value) else ()
    | J.Done (Check ticket,value) =>
        let val snapshot=V.bytes (V.field (value,"snapshot"))
            val valid=current (service,{uri= #uri ticket,revision= #revision ticket,generation= #generation ticket})
            val ()=if not valid then () else
              (results:={uri= #uri ticket,revision= #revision ticket,generation= #generation ticket,snapshot=snapshot} ::
                List.filter (fn result:result => #uri result<> #uri ticket) (!results);
               publish (service,V.array (V.field (value,"reports"))))
            val pending=waiters(service,ticket)
        in List.app(fn request=>
          if !(#done request) then () else if not valid then
            if #method request="textDocument/diagnostic" then
              failure (service,request,P.serverCancelled,"diagnostic source changed",SOME (Json.Object [("retriggerRequest",Json.Bool true)]))
            else failure (service,request,P.contentModified,"query source changed",NONE)
          else query (service,request,snapshot))pending end
    | J.Done (Query request,value) => finishQuery (service,request,value)
    | J.Done (Build ticket,value) =>
        (case #request ticket of SOME request => finishQuery (service,request,value) | NONE =>
          if not (current (service,{uri= #uri ticket,revision= #revision ticket,generation= #generation ticket})) then () else
            let val Service {documents,...}=service
                val version=case D.snapshot (documents,#uri ticket) of NONE => V.Null | SOME snapshot => V.Integer (#version snapshot)
            in publish (service,[V.Object [("uri",V.Bytes (#uri ticket)),("version",version),("report",value)]]) end)
    | J.Done (Workspace request,value) =>
        if #method request<>"workspace/diagnostic" orelse current (service,{uri="",revision=0,generation= #generation request}) then finish (service,request,R.Result (V.unjson value))
        else failure (service,request,P.serverCancelled,"workspace source changed",SOME (Json.Object [("retriggerRequest",Json.Bool true)]))
    | J.Failed (Workspace request,message) => failure (service,request,P.requestFailed,message,NONE)
    | J.Rejected (task,error) =>
        let fun reject request=failure (service,request,#code error,#message error,Option.map V.unjson (#data error))
        in case task of Query request =>
             if #code error=P.contentModified andalso not (!(#done request)) andalso not (!(#retried request))
               andalso not (resolving (#method request))
               andalso current (service,{uri= #uri request,revision= #revision request,generation= #generation request}) then
               (#retried request:=true;results:=List.filter (fn result:result => #uri result<> #uri request) (!results);
                check (service,#uri request,SOME request)) else reject request
           | Workspace request => reject request
           | Check ticket => List.app reject (waiters(service,ticket))
           | Build {request=SOME request,...} => reject request
           | _ => log (#message error) end
    | J.Failed (Query request,message) => failure (service,request,P.requestFailed,message,NONE)
    | J.Failed (Check ticket,message) => failedCheck(service,ticket,message)
    | J.Failed (Build {request=SOME request,...},message) => failure (service,request,P.requestFailed,message,NONE)
    | J.Failed (_,message) => log message
    | J.Cancelled (Query request) => if !(#done request) then () else failure (service,request,R.requestCancelled,"request cancelled",NONE)
    | J.Cancelled (Workspace request) => if !(#done request) then () else failure (service,request,R.requestCancelled,"request cancelled",NONE)
    | J.Cancelled (Check ticket) => List.app(fn request=>if !(#done request) then () else
        failure (service,request,R.requestCancelled,"request cancelled",NONE))(waiters(service,ticket))
    | J.Cancelled (Build {request=SOME request,...}) => if !(#done request) then () else failure (service,request,R.requestCancelled,"request cancelled",NONE)
    | J.Cancelled _ => ()
  fun descriptors (Service {jobs,...})=J.descriptors jobs
  fun pump (service as Service {jobs,log,...},ready) =
    List.app (fn event => handleEvent (service,event) handle V.Invalid message => log message) (J.pump (jobs,ready))
  fun close (service as Service {jobs,requests,refresh,...}) =
    (List.app (fn request => failure (service,request,R.requestCancelled,"server shutting down",NONE)) (!requests);
     ignore (Q.clear refresh);J.close jobs)
end

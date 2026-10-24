(* Connection-owned workspace requests and explicit build-context choices. *)
structure RuneLspController =
struct
  structure R=JsonRpc
  structure P=LspProtocol
  structure Q=LspRequests
  structure W=RuneLspWorkspace
  structure D=RuneLspDocuments
  structure J=RuneLspSync
  structure V=RuneLspWorkerWire
  datatype request = Configuration of {epoch:IntInf.int,scopes:string list}
    | Folders of IntInf.int
    | Choice of {uri:string,revision:IntInf.int,generation:IntInf.int,actions:(string*string) list}
    | Register of {id:string,epoch:IntInf.int}
    | Refresh of {method:string,capability:string list,generation:IntInf.int}
    | Unregister
  datatype t=Controller of {workspace:W.t,documents:D.t,caps:P.capabilities,pending:request Q.t,
    epoch:IntInf.int ref,asked:string list ref,waiting:string list ref,registration:string option ref,
    refreshing:string list ref,refreshDenied:string list ref,
    presentations:(string*string list) list ref,
    serial:IntInf.int ref,discover:string->unit,selected:string->unit,send:R.message->unit,log:string->unit,error:string->unit}
  fun workspace (Controller {workspace,...})=workspace
  fun issue (Controller {pending,send,error,...},method,params,data) =
    (send (Q.issue (pending,{method=method,params=params,data=data}));true)
    handle Q.Full => (error "workspace request limit reached";false)
  fun refresh (controller as Controller {workspace,documents,caps,waiting,refreshing,refreshDenied,...},method,capability) =
    if null (D.all documents) orelse not (null (!waiting)) orelse not (P.supports (caps,capability)) orelse
       List.exists (fn pending => pending=method) (!refreshing @ !refreshDenied) then () else
    if issue (controller,method,NONE,Refresh {method=method,capability=capability,generation=W.generation workspace})
    then refreshing:=method:: !refreshing else ()
  fun presentations (Controller {presentations,...},providers)=presentations:=providers
  fun refreshPresentations (controller as Controller {presentations,...}) =
    (refresh (controller,"workspace/foldingRange/refresh",["workspace","foldingRange","refreshSupport"]);
     List.app (fn (method,capability) => refresh (controller,method,capability)) (!presentations))
  fun scopes (Controller {workspace,documents,...}) =
    List.foldl (fn (uri,all) => if List.exists (fn prior => prior=uri) all then all else all @ [uri])
      (W.roots workspace) (List.map #uri (D.all documents))
  fun configuration (controller as Controller {caps,epoch,waiting,...},uris) =
    if not (P.supports (caps,["workspace","configuration"])) orelse null uris then false else
      let val items=List.map (fn uri => Json.Object [("scopeUri",Json.String uri),("section",Json.String "runelsp")]) uris
          val sent=issue (controller,"workspace/configuration",SOME (Json.Object [("items",Json.Array items)]),
            Configuration {epoch= !epoch,scopes=uris})
      in if sent then waiting:= !waiting @ uris else ();sent end
  fun context (Controller {documents,asked,waiting,discover,...},uri) =
    if List.exists (fn pending => pending=uri) (!waiting) orelse List.exists (fn pending => pending=uri) (!asked)
      orelse not (D.healthy (documents,uri)) then () else discover uri
  fun contexts (controller as Controller {workspace,documents,asked,selected,...},uri,value) =
    let val kind=V.bytes (V.field (value,"kind"))
    in if kind<>"ambiguous" then selected uri else
      case D.snapshot (documents,uri) of NONE => () | SOME snapshot =>
      let val alternatives=V.array (V.field (value,"contexts"))
          val actions=ListPair.map (fn (value,index) =>
            (Int.toString (index+1) ^ ". " ^ V.bytes (V.field (value,"label")),V.bytes (V.field (value,"id"))))
            (alternatives,List.tabulate (length alternatives,fn i => i))
          val params=Json.Object [("type",Json.int 3),("message",Json.String ("Select a Rune build context for " ^ uri)),
            ("actions",Json.Array (List.map (fn (title,_) => Json.Object [("title",Json.String title)]) actions))]
          val sent=issue (controller,"window/showMessageRequest",SOME params,
            Choice {uri=uri,revision= #revision snapshot,generation=W.generation workspace,actions=actions})
      in if sent then asked:=uri :: !asked else () end
    end
  fun allContexts (controller as Controller {documents,...}) =
    (List.app (fn snapshot:D.snapshot => context (controller,#uri snapshot)) (D.all documents);refreshPresentations controller)
  fun unregister (controller as Controller {registration,...},id) =
    (if !registration=SOME id then registration:=NONE else ();
     ignore (issue (controller,"client/unregisterCapability",SOME (Json.Object
      [("unregisterations",Json.Array [Json.Object [("id",Json.String id),("method",Json.String "workspace/didChangeWatchedFiles")]])]),Unregister)))
  fun watch (controller as Controller {workspace,caps,epoch,registration,serial,...}) =
    if not (P.supports (caps,["workspace","didChangeWatchedFiles","dynamicRegistration"])) then () else
      let val ()=Option.app (fn id => unregister (controller,id)) (!registration)
          val relative=P.supports (caps,["workspace","didChangeWatchedFiles","relativePatternSupport"])
          val roots=W.roots workspace
          fun patterns root=List.map (fn pattern => Json.Object [("globPattern",
            if relative then Json.Object [("baseUri",Json.String root),("pattern",Json.String pattern)] else Json.String pattern),
            ("kind",Json.int 7)]) ["**/*.{sml,sig,build}","**/MANIFEST"]
          val watchers=if relative then List.concat (List.map patterns roots) else patterns ""
          val id="runelsp-watch-" ^ IntInf.toString (!serial)
          val ()=serial:=IntInf.+ (!serial,1)
          val params=Json.Object [("registrations",Json.Array [Json.Object [("id",Json.String id),
            ("method",Json.String "workspace/didChangeWatchedFiles"),("registerOptions",Json.Object [("watchers",Json.Array watchers)])]])]
          val sent=if null watchers then false else issue (controller,"client/registerCapability",SOME params,Register {id=id,epoch= !epoch})
      in if sent then registration:=SOME id else () end
  fun new {platform,lib,documents,caps,send,log,error,initialize,discover,selected} =
    let val workspace=W.new {platform=platform,lib=lib}
        val ()=W.initialize (workspace,initialize)
    in Controller {workspace=workspace,documents=documents,caps=caps,pending=Q.new {prefix="runelsp-ws-",maxPending=2048},
      epoch=ref 0,asked=ref [],waiting=ref [],registration=ref NONE,refreshing=ref [],refreshDenied=ref [],presentations=ref [],
      serial=ref 0,discover=discover,selected=selected,send=send,log=log,error=error} end
  fun initialized (controller as Controller {workspace,caps,epoch,...}) =
    (if null (W.roots workspace) andalso P.supports (caps,["workspace","workspaceFolders"])
     then ignore (issue (controller,"workspace/workspaceFolders",NONE,Folders (!epoch))) else ();
     ignore (configuration (controller,scopes controller));watch controller)
  fun savedText (W.Workspace {platform,...},snapshot:D.snapshot) =
    (case LspUri.native(platform,LspUri.parse(#uri snapshot)) of NONE=>false | SOME {path,...}=>
      let val input=BinIO.openIn path
          val text=(Byte.bytesToString(BinIO.inputAll input) before BinIO.closeIn input)
            handle error=>(BinIO.closeIn input handle _=>();raise error)
      in text=LspPosition.text(#content snapshot) end)
    handle IO.Io _=>false | OS.SysErr _=>false
  fun event (controller as Controller {workspace,asked,...},event) =
    (case event of RuneLspSync.Opened snapshot =>
       (if savedText(workspace,snapshot) then () else W.dirty workspace;
        if configuration (controller,[#uri snapshot]) then () else context (controller,#uri snapshot))
     | RuneLspSync.Changed snapshot => (W.dirty workspace;context (controller,#uri snapshot))
     | RuneLspSync.Closed snapshot =>
         (if savedText(workspace,snapshot) then () else W.dirty workspace;
          W.forget (workspace,#uri snapshot);asked:=List.filter (fn uri => uri<> #uri snapshot) (!asked))
     | _ => ())
  fun notification (controller as Controller {workspace,caps,epoch,asked,waiting,error,...},{method,params}) =
    let fun value ()=case params of SOME value => J.object value | NONE => raise W.Invalid "missing workspace parameters"
        fun renew ()=(epoch:=IntInf.+ (!epoch,1);asked:=[];waiting:=[];ignore (configuration (controller,scopes controller));watch controller)
    in case method of
      "workspace/didChangeConfiguration" =>
        (if P.supports (caps,["workspace","configuration"]) then ()
         else W.configure (workspace,J.required (value (),"settings"));renew ();allContexts controller;true)
    | "workspace/didChangeWorkspaceFolders" => (W.foldersChanged (workspace,value ());renew ();allContexts controller;true)
    | "workspace/didChangeWatchedFiles" =>
        (case J.required (value (),"changes") of Json.Array changes =>
           List.app (fn change =>
             let val change=J.object change
                 val uri=J.string (J.required (change,"uri"))
                 val _=LspUri.parse uri
                 val kind=J.required (change,"type")
             in if List.exists (fn expected => kind=Json.int expected) [1,2,3] then ()
                else raise W.Invalid "invalid watched-file change type" end) changes
         | _ => raise W.Invalid "watched-file changes must be an array";
         W.dirty workspace;allContexts controller;true)
    | _ => false
    end handle W.Invalid message => (error message;true) | J.Invalid message => (error message;true)
      | LspUri.Invalid => (error "invalid watched-file URI";true)
  fun response (controller as Controller {workspace,documents,pending,epoch,waiting,asked,registration,
                                        refreshing,refreshDenied,error,log,selected,...},message) =
    case Q.resolve (pending,message) of NONE => false | SOME (request,outcome) =>
      ((case request of
         Configuration {epoch=issued,scopes=uris} =>
           let val generation=W.generation workspace
               val ()=if issued<> !epoch then () else
                 waiting:=List.filter (fn uri => not (List.exists (fn scope => uri=scope) uris)) (!waiting)
           in if issued<> !epoch then () else
             (case outcome of R.Result (Json.Array values) =>
                if length values<>length uris then error "workspace configuration response has the wrong length" else
                  ListPair.app (fn (uri,value) => if isSome (D.snapshot (documents,uri)) orelse List.exists (fn root => uri=root) (W.roots workspace)
                    then (W.configureAt (workspace,uri,value) handle W.Invalid message => error message) else ()) (uris,values)
              | R.Error _ => log "client refused workspace configuration; keeping startup settings"
              | _ => error "invalid workspace configuration response");
             if W.generation workspace<>generation then allContexts controller
             else List.app(fn uri=>context(controller,uri))uris end
       | Folders issued => if issued<> !epoch then () else
           (case outcome of R.Result (Json.Array values) =>
              (W.setRoots (workspace,List.map W.folder values);
               ignore (configuration (controller,scopes controller));watch controller;allContexts controller)
            | R.Result Json.Null => () | _ => log "client supplied no workspace folders")
       | Choice {uri,revision,generation,actions} =>
           let val ()=asked:=List.filter (fn document => document<>uri) (!asked)
           in case D.snapshot (documents,uri) of NONE => () | SOME snapshot =>
             if #revision snapshot<>revision orelse W.generation workspace<>generation then context (controller,uri) else
             (case outcome of R.Result Json.Null => asked:=uri :: !asked
              | R.Result value =>
                  (case J.member (J.object value,"title") of SOME (Json.String title) =>
                    (case List.find (fn (action,_) => action=title) actions of SOME (_,id) =>
                       (W.choose (workspace,uri,id);selected uri;refreshPresentations controller)
                     | NONE => error "unknown build-context action") | _ => error "invalid build-context action")
              | R.Error _ => (asked:=uri :: !asked;log "client declined build-context selection")) end
       | Register {id,epoch=issued} =>
           (case outcome of R.Result _ => if issued= !epoch then () else unregister (controller,id)
            | R.Error _ => (if !registration=SOME id then registration:=NONE else ();log "client refused file watchers; contexts revalidate on queries"))
       | Refresh {method,capability,generation} =>
           (refreshing:=List.filter (fn pending => pending<>method) (!refreshing);
            case outcome of R.Result _ => if W.generation workspace=generation then () else refresh (controller,method,capability)
              | R.Error {code,...} =>
                  (if code=R.methodNotFound then refreshDenied:=method:: !refreshDenied else ();
                   log ("client refused " ^ method)))
       | Unregister => ());true)
      handle W.Invalid message => (error message;true) | J.Invalid message => (error message;true)
           | LspUri.Invalid => (error "invalid workspace URI";true)
  fun clear (Controller {pending,refreshing,refreshDenied,presentations,...})=
    (ignore (Q.clear pending);refreshing:=[];refreshDenied:=[];presentations:=[])
end

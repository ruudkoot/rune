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
  val inlayClient=Json.Object [("textDocument",Json.Object [("inlayHint",Json.Object [("resolveSupport",Json.Object [("properties",Json.Array [Json.String "tooltip"])])])])]
  val statusClient=Json.Object [("experimental",Json.Object [("rune",Json.Object [("status",Json.Bool true)])])]
  fun fixtureWith capabilities action =
    let val documents=D.new (LspProtocol.Utf16,{maxDocuments=1,maxDocumentBytes=1000,maxTotalBytes=1000,
          maxDocumentLines=100,maxTotalLines=100})
        val initial=D.openDocument (documents,{uri="untitled:race",languageId="sml",version=1,text="val x=1\n"})
        val workspace=W.new {platform=LspUri.Posix,lib="lib"}
        val output=ref [] : R.message list ref
        val service=S.new {workspace=workspace,documents=documents,caps=valOf (LspProtocol.capabilities capabilities),
          command="unused-worker",args=[],send=fn value => output:= !output @ [value],log=fn _ => (),discovered=fn _ => (),
          watchedRoots=fn () => []}
        fun request method : S.request={id=R.Number 1,method=method,params=Json.Object [],uri= #uri initial,
          revision= #revision initial,generation=W.generation workspace,done=ref false,job=ref NONE,retried=ref false}
        fun change ()=ignore (D.changeDocument (documents,{uri= #uri initial,version=2,changes=[D.Replace "val x=2\n"]}))
        fun work ()=action {service=service,request=request,change=change,dirty=fn () => W.dirty workspace,output=output}
    in (work () before S.close service) handle error => (S.close service;raise error) end
  fun fixture action=fixtureWith inlayClient action
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
  fun statuses output=List.mapPartial (fn R.Notification {method="rune/status",params=SOME value} => SOME value | _ => NONE) (!output)
  fun field (value,name)=valOf (Json.member (name,value))
  fun failedStatus ()=fixtureWith statusClient (fn {service,request,output,...}=>
    let val S.Service {statusAt,...}=service
        fun report ()=(statusAt:=Time.zeroTime;S.reportStatus service)
        val ()=report ()
        val pending=request "textDocument/hover"
        val task=S.Check {uri= #uri pending,revision= #revision pending,generation= #generation pending,request=NONE}
        val ()=S.handleEvent (service,J.Failed (task,"analysis worker exceeded its deadline\n  worker PID 1"))
        val ()=report ()
        val failed=List.last (statuses output)
        val ()=check ("a worker's failure is an error, with its reason",field (failed,"severity")=Json.String "error"
          andalso field (failed,"detail")=Json.String "analysis worker exceeded its deadline")
        val ()=S.handleEvent (service,J.Done (S.Query (request "textDocument/hover"),V.json Json.Null))
        val ()=report ()
        val ()=check ("a query does not clear it",field (List.last (statuses output),"severity")=Json.String "error")
        val ()=S.handleEvent (service,J.Failed (task,"a second failure\n  worker PID 2"))
        val ()=report ()
        val ()=check ("the latest failure shows",field (List.last (statuses output),"detail")=Json.String "a second failure")
        val ()=S.handleEvent (service,J.Done (task,V.Object [("snapshot",V.Bytes "s"),("reports",V.Array [])]))
        val ()=report ()
    in check ("a check that succeeds clears it",field (List.last (statuses output),"severity")=Json.String "information") end)
  fun lostWorker ()=fixtureWith statusClient (fn {service,output,...}=>
    let val S.Service {statusAt,jobs=J.Jobs {queue,...},...}=service
        fun hover id=ignore (S.request (service,{id=R.Number id,method="textDocument/hover",params=SOME (Json.Object
          [("textDocument",Json.Object [("uri",Json.String "untitled:race")])])}))
        val ()=hover 1
        val task= #data (hd (!queue))
        val ()=queue:=[]
        val ()=S.handleEvent (service,J.Done (task,V.Object [("snapshot",V.Bytes "s"),("reports",V.Array [])]))
        val ()=check ("a query is waiting",case !queue of [job] => (case #data job of S.Query _ => true | _ => false) | _ => false)
        fun failed ()=List.exists (fn status => field (status,"severity")=Json.String "error") (statuses output)
        fun settle n=if n=0 orelse failed () then () else
          (statusAt:=Time.zeroTime;S.pump (service,OS.IO.poll (S.descriptors service,SOME (Time.fromMilliseconds 20)));settle (n-1))
        val ()=settle 500
    in check ("a worker lost during a query is an error",failed ()
         andalso field (List.last (statuses output),"text")=Json.String "Analysis failed") end)
  fun queryFailure ()=fixtureWith statusClient (fn {service,request,output,...}=>
    let val S.Service {statusAt,...}=service
        val ()=S.handleEvent (service,J.Failed (S.Query (request "textDocument/semanticTokens/full"),"semantic token response budget exceeded"))
        val ()=statusAt:=Time.zeroTime
        val ()=S.reportStatus service
    in check ("a query's own failure is not the server's",field (List.last (statuses output),"severity")=Json.String "information") end)
  fun throttledStatus ()=fixtureWith statusClient (fn {service,output,...}=>
    let val S.Service {statusAt,...}=service
        fun count ()=length (statuses output)
        fun hover id=ignore (S.request (service,{id=R.Number id,method="textDocument/hover",params=SOME (Json.Object
          [("textDocument",Json.Object [("uri",Json.String "untitled:race")])])}))
        val ()=S.reportStatus service
        val ()=check ("the first status goes at once",count ()=1 andalso field (hd (statuses output),"busy")=Json.Bool false)
        val ()=hover 1
        val ()=S.reportStatus service
        val ()=check ("a change inside the interval waits",count ()=1)
        val ()=statusAt:=Time.zeroTime
        val ()=S.reportStatus service
        val ()=check ("it goes when the interval is over",count ()=2 andalso field (List.last (statuses output),"busy")=Json.Bool true)
        val ()=statusAt:=Time.zeroTime
        val ()=S.reportStatus service
    in check ("no change, no message",count ()=2) end)
  fun quietStatus ()=fixture (fn {service,output,...}=>
    let val ()=ignore (S.request (service,{id=R.Number 1,method="textDocument/hover",params=SOME (Json.Object
          [("textDocument",Json.Object [("uri",Json.String "untitled:race")])])}))
        val S.Service {statusAt,...}=service
        val ()=statusAt:=Time.zeroTime
        val ()=S.reportStatus service
    in check ("a client that did not ask gets no status",null (statuses output)) end)
  fun sweepStatus ()=fixtureWith statusClient (fn {service,output,...}=>
    let val ()=ignore (S.request (service,{id=R.Number 1,method="workspace/diagnostic",params=SOME (Json.Object [])}))
        val ()=S.reportStatus service
    in check ("a workspace poll is not busy before it plans a sweep",field (hd (statuses output),"busy")=Json.Bool false) end)
  (* the outline as it was, a scan of everything for each symbol: what the
     indexes must give *)
  structure Reference=
  struct
    structure C=RuneCompiler
    structure RuneLspStructure=RuneLspStructure
    type entry=RuneLspOutline.entry
    type symbol=RuneLspOutline.symbol
    fun prepare {entries:entry list,events:C.Syntax.event list,pieces:C.Syntax.piece list,facts:C.Analysis.fact list} =
      let fun same (a:entry,b:entry)= #identity a= #identity b andalso #name a= #name b andalso #category a= #category b
          fun group (entry,kept)=case List.find(fn prior=>same(entry,prior))kept of NONE=>entry::kept
            | SOME prior=>if #start prior<= #start entry then kept else entry::List.filter(fn prior=>not(same(entry,prior)))kept
          val entries=RuneLspStructure.sort (fn (a:entry,b:entry)=> #start a< #start b)(List.foldl group [] entries)
          fun contains (event:C.Syntax.event,start,stop)= #start event<=start andalso stop<= #stop event
          fun smallest ([],best)=best
            | smallest (event::rest,NONE)=smallest(rest,SOME event)
            | smallest (event::rest,SOME prior)=smallest(rest,SOME(if #stop event- #start event< #stop prior- #start prior then event else prior))
          fun firstName (event:C.Syntax.event,name)=Option.map #start(List.find(fn piece:C.Syntax.piece=>
            #start event<= #start piece andalso #stop piece<= #stop event andalso #text piece=name andalso
            List.exists(fn kind=>kind= #kind piece)["identifier","operator","typeVariable"])pieces)
          fun named (entry:entry)=smallest(List.filter(fn event:C.Syntax.event=>
            List.exists(fn kind=>kind= #kind event)["fundef","strbind","sigbind","funbind","typbind","datbind",
              "typespec","valspec","strspec","exnspec","ExnDecl","ExnRepl","constructor"] andalso
            (case #values event of name::_=>name= #name entry | _=>false) andalso
            contains(event,#start entry,#stop entry) andalso firstName(event,#name entry)=SOME(#start entry))events,NONE)
          fun valueDeclaration (entry:entry)=
            case smallest(List.filter(fn event:C.Syntax.event=>contains(event,#start entry,#stop entry) andalso
              List.exists(fn kind=>kind= #kind event)["DVal","DValRec"])events,NONE) of NONE=>NONE
            | SOME event=>
                (case List.find(fn expression:C.Syntax.event=>String.isPrefix "E" (#kind expression) andalso
                  contains(event,#start expression,#stop expression))events of NONE=>NONE | SOME expression=>
                  if #stop entry> #start expression orelse length(List.filter(fn other:entry=> #category other="value" andalso
                    contains(event,#start other,#stop other) andalso #stop other<= #start expression)entries)<>1 then NONE
                  else SOME(event,expression))
          fun make (entry:entry):symbol =
            let val declaration=named entry
                val value=if #category entry="value" andalso not(isSome declaration) then valueDeclaration entry else NONE
                val functionValue=case value of NONE=>false | SOME(_,expression)=> #kind expression="EFn" orelse
                  List.exists(fn fact:C.Analysis.fact=> #start fact= #start expression andalso #stop fact= #stop expression
                    andalso not(null(#arguments fact)))facts
                val functionSpec=case declaration of SOME event=> #kind event="valspec" andalso
                  (case List.find(fn item:C.Syntax.event=>String.isPrefix "Ty" (#kind item) andalso
                    contains(event,#start item,#stop item))events of SOME ty=> #kind ty="TyArrow" | _=>false) | NONE=>false
                val tag=case declaration of NONE=>"" | SOME event=> #kind event
                val kind=case #category entry of "structure"=>2 | "signature"=>11 | "functor"=>12 | "type"=>23
                  | _=>if tag="constructor" then 22 else if tag="ExnDecl" orelse tag="ExnRepl" orelse tag="exnspec" then 14
                    else if tag="fundef" orelse functionValue orelse functionSpec then 12 else 13
                val span=case declaration of SOME event=>
                      (case smallest(List.filter(fn outer:C.Syntax.event=>contains(outer,#start event,#stop event) andalso
                        (case #values outer of "1"::_=>true | _=>false) andalso
                        List.exists(fn pair=>pair=(tag,#kind outer))[("fundef","DFun"),("strbind","DStructure"),
                          ("sigbind","DSignature"),("funbind","DFunctor")])events,NONE) of SOME outer=>(#start outer,#stop outer)
                       | NONE=>(#start event,#stop event))
                  | NONE=>(case value of SOME(event,_)=>(#start event,#stop event) | NONE=>(#start entry,#stop entry))
            in {name= #name entry,kind=kind,start= #1 span,stop= #2 span,selectionStart= #start entry,selectionStop= #stop entry} end
      in List.map make entries end
    fun flat (symbols:symbol list,uri,range)=List.map(fn item=>Json.Object
      [("name",Json.String(#name item)),("kind",Json.int(#kind item)),("location",Json.Object
        [("uri",Json.String uri),("range",range(#selectionStart item,#selectionStop item))])])symbols
    fun nested (symbols:symbol list,range) =
      let val table=Vector.fromList symbols
          val count=Vector.length table
          fun owner i=
            let val child=Vector.sub(table,i)
                fun pick(j,best)=if i=j then best else
                  let val parent=Vector.sub(table,j)
                      val encloses= #start parent<= #start child andalso #stop child<= #stop parent andalso
                        (#start parent<> #start child orelse #stop parent<> #stop child)
                  in if not encloses then best else case best of NONE=>SOME j | SOME old=>
                    let val prior=Vector.sub(table,old)
                    in if #stop parent- #start parent< #stop prior- #start prior then SOME j else best end end
            in List.foldl pick NONE (List.tabulate(count,fn n=>n)) end
          val parents=Vector.tabulate(count,owner)
          fun children parent=List.filter(fn i=>Vector.sub(parents,i)=parent)(List.tabulate(count,fn n=>n))
          fun emit i=
            let val item=Vector.sub(table,i)
            in Json.Object[("name",Json.String(#name item)),("kind",Json.int(#kind item)),
              ("range",range(#start item,#stop item)),("selectionRange",range(#selectionStart item,#selectionStop item)),
              ("children",Json.Array(List.map emit(children(SOME i))))] end
      in List.map emit (children NONE) end
  end
  structure C=RuneCompiler
  fun outlineOf (compiler,name,text)=
    let val analysis=C.Analysis.create (compiler,{context=name})
        val snapshot=C.Analysis.check (analysis,{project=NONE,cancelled=fn () => false,
          inputs=[{file=name,text=text,revision="1",mode="ascii",annotations=[]}]})
        val ()=check ("the outline's source checks: " ^ name ^ " " ^ String.concatWith "; " (List.map #message (C.Analysis.diagnostics snapshot)),
          null (C.Analysis.diagnostics snapshot))
        val unit=valOf (C.Analysis.unitAt (snapshot,{ordinal=0}))
        val syntax=valOf (C.Analysis.syntaxAt (snapshot,{ordinal=0}))
        val entries=List.mapPartial (fn occurrence:C.Analysis.occurrence =>
          if #isDefinition occurrence andalso not (#derived occurrence) then
            SOME {identity=getOpt (#binding occurrence,"span:" ^ Int.toString (#start occurrence)),name= #name occurrence,
                  category= #kind occurrence,start= #start occurrence,stop= #stop occurrence}:RuneLspOutline.entry option
          else NONE) (C.Analysis.occurrencesIn (snapshot,unit))
    in C.Analysis.close analysis;
       {entries=entries,events=C.Syntax.events syntax,pieces=C.Syntax.pieces syntax,facts=C.Analysis.factsIn (snapshot,unit)} end
  fun outlineSame () =
    let val compiler=C.session {lib=NONE,flags=[]}
        fun lines items=String.concatWith "\n" items ^ "\n"
        val sources=[("declarations",lines
            ["signature S=sig type t val f:t->int val g:int exception E structure N:sig val h:int end end",
             "structure A:S=struct type t=int fun f x=x val g=1 exception E structure N=struct val h=2 end end",
             "functor F(X:S)=struct val y=X.g fun z x=x end",
             "structure B=F(A) and D=F(A)",
             "datatype d=C of int|K and e=M of d",
             "exception X of int exception Y=X",
             "type p=int and q=bool",
             "val (a,b)=(1,2) and c=3",
             "val h=fn x=>x val i=let val j=1 in j end val k=(fn y=>y) 1",
             "fun m 0=1 | m n=n*m (n-1) and u x=m x",
             "fun nest x=let fun inner y=let val deep=y in deep end val other=inner x in other end",
             "local val hidden=1 in val shown=hidden end",
             "val rec r=fn x=>r x"]),
           ("same names",lines
            ["val x=1 val x=2 val x=x+1",
             "fun f x=x fun f y=y+1",
             "structure A=struct val x=1 structure A=struct val x=2 fun x2 x=x end end",
             "val y=let val y=1 val y=y in y end"])]
        fun compare (name,text)=
          let val input=outlineOf (compiler,name,text)
              val fresh=RuneLspOutline.prepare input
              val old=Reference.prepare input
              fun range (start,stop)=Json.Array [Json.int start,Json.int stop]
          in check ("the same symbols as the scan: " ^ name,fresh=old);
             check ("the same tree as the scan: " ^ name,RuneLspOutline.nested (fresh,range)=Reference.nested (old,range)) end
    in List.app compare sources;C.close compiler end
  (* E20's reproducer: 1.4 s at 1,000 declarations, past the deadline at 6,000 *)
  fun outlineLinear () =
    let fun cost count =
          let val entries=List.tabulate (count,fn i => {identity=Int.toString i,name="f" ^ Int.toString i,category="value",
                start=10*i+4,stop=10*i+6}:RuneLspOutline.entry)
              val events=List.concat (List.tabulate (count,fn i =>
                [{kind="DFun",start=10*i,stop=10*i+9,values=["1"]},{kind="fundef",start=10*i,stop=10*i+9,values=["f" ^ Int.toString i]}]:C.Syntax.event list))
              val pieces=List.tabulate (count,fn i => {kind="identifier",start=10*i+4,stop=10*i+6,text="f" ^ Int.toString i}:C.Syntax.piece)
              val (symbols,{bytes,...})=Runtime.profile (fn () =>
                let val symbols=RuneLspOutline.prepare {entries=entries,events=events,pieces=pieces,facts=[]}
                in RuneLspOutline.nested (symbols,fn (start,stop) => Json.Array [Json.int start,Json.int stop]) end)
          in check ("every declaration is a symbol",length symbols=count);bytes end
        val small=cost 2000
        val large=cost 8000
    in check ("document symbols are linear in declarations: 4 times the declarations, " ^
        Int.toString small ^ " to " ^ Int.toString large ^ " bytes",large<6*small) end
end
structure RuneLspServiceTestMain=Main (struct
  val name="lsp-service"
  val tests=Test.describe "lsp-service" [Test.it "stale-query-completions" RuneLspServiceTests.changed,
    Test.it "stale-check-completions" RuneLspServiceTests.checked,Test.it "current-completion-once" RuneLspServiceTests.unchanged,
    Test.it "workspace-generation-completions" RuneLspServiceTests.generation,
    Test.it "invalid-hint-resolution" RuneLspServiceTests.invalidResolution,
    Test.it "shared-check-cancellation" RuneLspServiceTests.sharedChecks,
    Test.it "failed-check-backoff" RuneLspServiceTests.failedChecks,
    Test.it "foreground-isolated-from-workspace-pull" RuneLspServiceTests.workspacePriority,
    Test.it "status-failure" RuneLspServiceTests.failedStatus,
    Test.it "status-lost-worker" RuneLspServiceTests.lostWorker,
    Test.it "status-query-failure" RuneLspServiceTests.queryFailure,
    Test.it "status-throttled" RuneLspServiceTests.throttledStatus,
    Test.it "status-unasked" RuneLspServiceTests.quietStatus,
    Test.it "status-workspace-poll" RuneLspServiceTests.sweepStatus,
    Test.it "outline-same-as-the-scan" RuneLspServiceTests.outlineSame,
    Test.it "outline-linear-in-declarations" RuneLspServiceTests.outlineLinear]
end)
val ()=RuneLspServiceTestMain.main ()

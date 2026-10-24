structure RuneLspWorkerAnalysisTests =
struct
  structure P=RuneLspWorkerProcess
  structure V=RuneLspWorkerWire
  structure W=RuneLspWorkspace
  structure D=RuneLspDocuments
  structure M=RuneLspWorkerModel
  val check=Expect.that
  fun run () =
    let val (vm,worker)=case CommandLine.arguments () of [vm,worker] => (vm,worker) | _ => raise Fail "worker paths required"
        val process=ref (P.start {command=vm,args=[worker],limits=Subprocess.unlimited})
        fun stop process =
          let val ()=P.terminate process
              val until=Time.+ (Time.now (),Time.fromSeconds 3)
              fun reap ()=case P.reap process of SOME _ => () | NONE =>
                if Time.> (Time.now (),until) then raise Fail "worker not reaped"
                else (ignore (OS.IO.poll ([],SOME (Time.fromMilliseconds 10)));reap ())
          in reap () end
        val inbox=ref [] : V.value list ref
        val observations=ref [] : V.value list ref
        fun progress value=(V.bytes(V.field(value,"op"))="progress") handle V.Invalid _=>false
        fun receive predicate =
          let val until=Time.+ (Time.now (),Time.fromSeconds 20)
              fun find ()=case List.find predicate (!inbox) of SOME value =>
                    (inbox:=List.filter (fn other => other<>value) (!inbox);value)
                | NONE => if Time.> (Time.now (),until) then raise Fail "analysis worker timeout" else
                    let val events=P.pump (!process,OS.IO.poll (P.descriptors (!process),SOME (Time.fromMilliseconds 20)))
                        val ()=List.app (fn P.Message value => if progress value then observations:=value:: !observations else inbox:= !inbox @ [value]
                          | P.Ended => raise Fail "analysis worker exited" | P.Failed message => raise Fail message) events
                    in find () end
          in find () end
        fun ready ()=ignore (receive (fn value =>
          (V.bytes (V.field (value,"op"))="ready") handle V.Invalid _ => false))
        fun response id=receive (fn value => (V.integer (V.field (value,"id"))=id) handle V.Invalid _ => false)
        fun result value=V.field (value,"result") handle V.Invalid _ =>
          let val error=V.field (value,"error")
          in raise Fail (case error of V.Bytes message => message | _ => V.bytes (V.field (error,"message"))) end
        val platform=if List.exists (fn (key,value) => key="sysname" andalso value="Windows") (Posix.ProcEnv.uname ())
          then LspUri.Windows else LspUri.Posix
        val workspace=W.new {platform=platform,lib="lib"}
        val documents=D.new (LspProtocol.Utf16,{maxDocuments=3,maxDocumentBytes=4*1024*1024,maxTotalBytes=8*1024*1024,
          maxDocumentLines=200000,maxTotalLines=300000})
        val uri="untitled:worker-analysis"
        val _=D.openDocument (documents,{uri=uri,languageId="sml",version=1,text="val bad:int=true\n"})
        fun request id=V.Object [("op",V.Bytes "check"),("id",V.Integer id),("uri",V.Bytes uri),
          ("encoding",V.Bytes "utf-16"),("state",M.capture (workspace,documents))]
        fun query (id,snapshot,method,params)=
          (ready ();P.enqueue (!process,V.Object [("op",V.Bytes "query"),("id",V.Integer id),("snapshot",V.Bytes snapshot),
            ("method",V.Bytes method),("params",V.json params)]);V.unjson (result (response id)))
        fun report response=V.unjson (V.field (hd (V.array (V.field (response,"reports"))),"report"))
        fun items report=case Json.member ("items",report) of SOME (Json.Array values) => values | _ => []
        fun work () =
          let val ()=ready ()
              val ()=P.enqueue (!process,request 1)
              val bad=result (response 1)
              val ()=check ("compiler diagnostics cross worker boundary",not (null (items (report bad))))
              val ()=check("worker reports the analyzed source and phase",List.exists(fn value=>
                (V.bytes(V.field(value,"phase"))="unit-start" andalso V.bytes(V.field(value,"file"))=uri
                 andalso V.integer(V.field(value,"id"))=1)handle V.Invalid _=>false)(!observations))
              val _=D.changeDocument (documents,{uri=uri,version=2,changes=[D.Replace "val answer=42\n"]})
              val ()=ready ()
              val ()=P.enqueue (!process,request 2)
              val good=result (response 2)
              val goodId=V.bytes (V.field (good,"snapshot"))
              val ()=check ("fixed errors clear",null (items (report good)))
              val params=Json.Object [("textDocument",Json.Object [("uri",Json.String uri)]),
                ("position",Json.Object [("line",Json.int 0),("character",Json.int 4)])]
              val hover=query (3,goodId,"textDocument/hover",params)
              val contents=valOf (Json.member ("contents",hover))
              val ()=check ("frozen hover query",Json.member ("value",contents)=SOME (Json.String "int"))
              val old=query (4,V.bytes (V.field (bad,"snapshot")),"textDocument/diagnostic",
                Json.Object [("textDocument",Json.Object [("uri",Json.String uri)])])
              val ()=check ("older snapshot remains isolated",not (null (items old)))
              val large=String.concat (List.tabulate (10000,fn n => "val x" ^ Int.toString n ^ "=" ^ Int.toString n ^ "\n"))
              val _=D.changeDocument (documents,{uri=uri,version=3,changes=[D.Replace large]})
              val ()=ready ()
              val ()=P.enqueue (!process,request 5)
              val ()=P.enqueue (!process,V.Object [("op",V.Bytes "cancel"),("id",V.Integer 5)])
              val cancelled=response 5
              val ()=check ("cooperative cancellation acknowledged",V.field (cancelled,"cancelled")=V.Bool true)
              val after=query (6,goodId,"textDocument/hover",params)
              val ()=check ("cancellation preserves prior views",Json.member ("contents",after)=SOME contents)
              val ()=stop (!process)
              val ()=inbox:=[]
              val ()=process:=P.start {command=vm,args=[worker],limits=Subprocess.unlimited}
              val _=D.changeDocument (documents,{uri=uri,version=4,changes=[D.Replace "val answer=42\n"]})
              val ()=ready ()
              val ()=P.enqueue (!process,request 7)
              val restarted=result (response 7)
              val ()=check ("snapshot IDs do not repeat after worker restart",
                V.field (restarted,"snapshot")<>V.field (bad,"snapshot"))
              val ()=ready ()
              val ()=P.enqueue (!process,V.Object [("op",V.Bytes "query"),("id",V.Integer 8),
                ("snapshot",V.field (bad,"snapshot")),("method",V.Bytes "textDocument/hover"),("params",V.json params)])
              val stale=response 8
          in check ("old snapshot IDs cannot resolve to a new process's view",
            (V.field (V.field (stale,"error"),"code")=V.Integer LspProtocol.contentModified)
              handle V.Invalid _ => false) end
        val result=(work () handle error => (stop (!process);raise error))
    in stop (!process);result end
end
structure RuneLspWorkerAnalysisTestMain=Main (struct
  val name="lsp-worker-analysis"
  val tests=Test.describe "lsp-worker-analysis" [Test.it "snapshots-diagnostics-cancellation" RuneLspWorkerAnalysisTests.run]
end)
val ()=RuneLspWorkerAnalysisTestMain.main ()

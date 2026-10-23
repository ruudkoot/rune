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
        val process=P.start {command=vm,args=[worker],limits=Subprocess.unlimited}
        val inbox=ref [] : V.value list ref
        fun receive predicate =
          let val until=Time.+ (Time.now (),Time.fromSeconds 20)
              fun find ()=case List.find predicate (!inbox) of SOME value =>
                    (inbox:=List.filter (fn other => other<>value) (!inbox);value)
                | NONE => if Time.> (Time.now (),until) then raise Fail "analysis worker timeout" else
                    let val events=P.pump (process,OS.IO.poll (P.descriptors process,SOME (Time.fromMilliseconds 20)))
                        val ()=List.app (fn P.Message value => inbox:= !inbox @ [value]
                          | P.Ended => raise Fail "analysis worker exited" | P.Failed message => raise Fail message) events
                    in find () end
          in find () end
        fun ready ()=ignore (receive (fn value =>
          (V.bytes (V.field (value,"op"))="ready") handle V.Invalid _ => false))
        fun response id=receive (fn value => (V.integer (V.field (value,"id"))=id) handle V.Invalid _ => false)
        fun result value=V.field (value,"result") handle V.Invalid _ => raise Fail (V.bytes (V.field (value,"error")))
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
          (ready ();P.enqueue (process,V.Object [("op",V.Bytes "query"),("id",V.Integer id),("snapshot",V.Bytes snapshot),
            ("method",V.Bytes method),("params",V.json params)]);V.unjson (result (response id)))
        fun report response=V.unjson (V.field (hd (V.array (V.field (response,"reports"))),"report"))
        fun items report=case Json.member ("items",report) of SOME (Json.Array values) => values | _ => []
        fun work () =
          let val ()=ready ()
              val ()=P.enqueue (process,request 1)
              val bad=result (response 1)
              val ()=check ("compiler diagnostics cross worker boundary",not (null (items (report bad))))
              val _=D.changeDocument (documents,{uri=uri,version=2,changes=[D.Replace "val answer=42\n"]})
              val ()=ready ()
              val ()=P.enqueue (process,request 2)
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
              val ()=P.enqueue (process,request 5)
              val ()=P.enqueue (process,V.Object [("op",V.Bytes "cancel"),("id",V.Integer 5)])
              val cancelled=response 5
              val ()=check ("cooperative cancellation acknowledged",V.field (cancelled,"cancelled")=V.Bool true)
              val after=query (6,goodId,"textDocument/hover",params)
          in check ("cancellation preserves prior views",Json.member ("contents",after)=SOME contents) end
        val result=(work () handle error => (P.terminate process;raise error))
        val ()=P.terminate process
        val until=Time.+ (Time.now (),Time.fromSeconds 3)
        fun reap ()=case P.reap process of SOME _ => () | NONE => if Time.> (Time.now (),until) then raise Fail "worker not reaped"
          else (ignore (OS.IO.poll ([],SOME (Time.fromMilliseconds 10)));reap ())
    in reap ();result end
end
structure RuneLspWorkerAnalysisTestMain=Main (struct
  val name="lsp-worker-analysis"
  val tests=Test.describe "lsp-worker-analysis" [Test.it "snapshots-diagnostics-cancellation" RuneLspWorkerAnalysisTests.run]
end)
val ()=RuneLspWorkerAnalysisTestMain.main ()

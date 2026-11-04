structure RuneLspWorkerAnalysisTests =
struct
  structure P=RuneLspWorkerProcess
  structure V=RuneLspWorkerWire
  structure W=RuneLspWorkspace
  structure D=RuneLspDocuments
  structure M=RuneLspWorkerModel
  structure C=CompilerApi
  structure A=C.Analysis
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
              val completionParams=Json.Object[("textDocument",Json.Object[("uri",Json.String uri)]),
                ("position",Json.Object[("line",Json.int 1),("character",Json.int 0)])]
              fun answerType value=case Json.member("items",value) of SOME(Json.Array items)=>
                  (case List.find(fn item=>Json.member("label",item)=SOME(Json.String "answer"))items of
                     NONE=>NONE | SOME item=>Json.member("detail",item)) | _=>NONE
              val firstCompletion=query(30,goodId,"textDocument/completion",completionParams)
              val ()=check("repeated frozen completion keeps its semantic result",
                firstCompletion=query(31,goodId,"textDocument/completion",completionParams) andalso
                answerType firstCompletion=SOME(Json.String "int"))
              val _=D.changeDocument(documents,{uri=uri,version=3,changes=[D.Replace "val answer=true\n"]})
              val ()=ready() val ()=P.enqueue(!process,request 32)
              val changed=result(response 32)
              val changedId=V.bytes(V.field(changed,"snapshot"))
              val ()=check("new text refreshes indexes and completion while old snapshots stay frozen",
                answerType(query(33,changedId,"textDocument/completion",completionParams))=SOME(Json.String "bool") andalso
                query(34,goodId,"textDocument/completion",completionParams)=firstCompletion)
              val old=query (4,V.bytes (V.field (bad,"snapshot")),"textDocument/diagnostic",
                Json.Object [("textDocument",Json.Object [("uri",Json.String uri)])])
              val ()=check ("older snapshot remains isolated",not (null (items old)))
              val large=String.concat (List.tabulate (10000,fn n => "val x" ^ Int.toString n ^ "=" ^ Int.toString n ^ "\n"))
              val _=D.changeDocument (documents,{uri=uri,version=4,changes=[D.Replace large]})
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
              val _=D.changeDocument (documents,{uri=uri,version=5,changes=[D.Replace "val answer=42\n"]})
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
  (* E20: Env.plus filtered every origin on every declaration, so that twice the
     declarations in a unit allocated and took four times as much. *)
  fun linear () =
    let fun cost count =
          let val text="structure Big=struct\n" ^ String.concat (List.tabulate (count,fn i =>
                "  fun f" ^ Int.toString i ^ " (x:int):int=x+" ^ Int.toString i ^ "\n")) ^ "end\n"
              val compiler=C.session {lib=NONE,flags=[]}
              val analysis=A.create (compiler,{context="linear"})
              val input={file="big.sml",text=text,revision="1",mode="ascii",annotations=[]}:A.input
              val (snapshot,{bytes,...})=Runtime.profile (fn () =>
                A.check (analysis,{project=NONE,inputs=[input],cancelled=fn () => false}))
              val ()=check ("the unit checks",null (A.diagnostics snapshot))
          in A.close analysis;C.close compiler;bytes end
        val small=cost 2000
        val large=cost 8000
    in check ("analysis is linear in a unit's declarations: 4 times the declarations, " ^
        Int.toString small ^ " to " ^ Int.toString large ^ " bytes",large<6*small) end
  (* a worker of its own, and the phases it reports *)
  fun harness () =
    let val (vm,worker)=case CommandLine.arguments () of [vm,worker] => (vm,worker) | _ => raise Fail "worker paths required"
        val process=P.start {command=vm,args=[worker],limits=Subprocess.unlimited}
        val inbox=ref [] : V.value list ref
        val phases=ref [] : string list ref
        fun progress value=(V.bytes(V.field(value,"op"))="progress") handle V.Invalid _=>false
        fun receive predicate =
          let val until=Time.+ (Time.now (),Time.fromSeconds 30)
              fun find ()=case List.find predicate (!inbox) of SOME value =>
                    (inbox:=List.filter (fn other => other<>value) (!inbox);value)
                | NONE => if Time.> (Time.now (),until) then raise Fail "analysis worker timeout" else
                    let val events=P.pump (process,OS.IO.poll (P.descriptors process,SOME (Time.fromMilliseconds 20)))
                        val ()=List.app (fn P.Message value =>
                            if progress value then phases:=V.bytes (V.field (value,"phase")):: !phases else inbox:= !inbox @ [value]
                          | P.Ended => raise Fail "analysis worker exited" | P.Failed message => raise Fail message) events
                    in find () end
          in find () end
        val serial=ref (0:IntInf.int)
        fun ready ()=ignore (receive (fn value => (V.bytes (V.field (value,"op"))="ready") handle V.Invalid _ => false))
        fun call fields=
          let val ()=serial:=IntInf.+ (!serial,1)
              val id= !serial
              val ()=ready ()
              val ()=P.enqueue (process,V.Object (("id",V.Integer id)::fields))
              val answer=receive (fn value => (V.integer (V.field (value,"id"))=id) handle V.Invalid _ => false)
          in V.field (answer,"result") handle V.Invalid _ =>
               let val error=V.field (answer,"error")
               in raise Fail (case error of V.Bytes message => message | _ => V.bytes (V.field (error,"message"))) end end
        fun stop ()=
          let val ()=P.terminate process
              val until=Time.+ (Time.now (),Time.fromSeconds 3)
              fun reap ()=case P.reap process of SOME _ => () | NONE =>
                if Time.> (Time.now (),until) then raise Fail "worker not reaped"
                else (ignore (OS.IO.poll ([],SOME (Time.fromMilliseconds 10)));reap ())
          in reap () end
    in {call=call,phases=phases,stop=stop} end
  fun writeFile (file,text)=let val output=TextIO.openOut file in TextIO.output (output,text);TextIO.closeOut output end
  (* A project on disk, every file older than a stamp's doubt, and a file of it open. *)
  fun project action =
    let val root=OS.FileSys.tmpName ()
        val ()=OS.FileSys.remove root handle OS.SysErr _ => ()
        val ()=OS.FileSys.mkDir root
        val root=OS.FileSys.fullPath root
        fun path name=OS.Path.concat (root,name)
        val old=Time.- (Time.now (),Time.fromSeconds 100)
        fun age name=OS.FileSys.setTime (path name,SOME old)
        val ()=writeFile (path "a.sml","val a=1\n")
        val ()=writeFile (path "b.sml","val b=a+1\n")
        val ()=writeFile (path "p.build","files a.sml b.sml end\n")
        val ()=List.app age ["a.sml","b.sml","p.build"]
        val ()=OS.FileSys.setTime (root,SOME old)
        val platform=LspUri.Posix
        fun uri name=LspUri.original (LspUri.fromPath (platform,path name))
        val workspace=W.new {platform=platform,lib="lib"}
        val ()=W.setRoots (workspace,[LspUri.original (LspUri.fromPath (platform,root))])
        val documents=D.new (LspProtocol.Utf16,{maxDocuments=3,maxDocumentBytes=4*1024*1024,maxTotalBytes=8*1024*1024,
          maxDocumentLines=200000,maxTotalLines=300000})
        val _=D.openDocument (documents,{uri=uri "b.sml",languageId="sml",version=1,text="val b=a+1\n"})
        val {call,phases,stop}=harness ()
        fun state ()=M.capture (workspace,documents)
        fun check ()=call [("op",V.Bytes "check"),("uri",V.Bytes (uri "b.sml")),("encoding",V.Bytes "utf-16"),("state",state ())]
        fun discover ()=call [("op",V.Bytes "discover"),("uri",V.Bytes (uri "b.sml")),("state",state ())]
        fun planned ()=length (List.filter (fn phase => phase="planning") (!phases))
        fun edit (version,text)=ignore (D.changeDocument (documents,{uri=uri "b.sml",version=version,changes=[D.Replace text]}))
        fun errors reply=case V.array (V.field (reply,"reports")) of [] => [] | report::_ =>
          (case Json.member ("items",V.unjson (V.field (report,"report"))) of SOME (Json.Array items) => items | _ => [])
        fun cleanup ()=(List.app (fn name => OS.FileSys.remove (path name) handle OS.SysErr _ => ()) ["a.sml","b.sml","p.build","q.build"];
          OS.FileSys.rmDir root handle OS.SysErr _ => ())
        val result=(action {path=path,age=age,root=root,old=old,check=check,discover=discover,planned=planned,edit=edit,errors=errors,workspace=workspace}
          handle error => (stop ();cleanup ();raise error))
    in stop ();cleanup ();result end
  (* E23: a discover job read every target before every check: 19.1 s against 0.6 s *)
  fun planHolds ()=project (fn {discover,check,planned,edit,errors,...} =>
    let val _=discover ()
        val first=planned ()
        val ()=Expect.that ("the first discovery plans",first=1)
        val reply=check ()
        val ()=Expect.that ("the check takes the discovery's plan",planned ()=first andalso null (errors reply))
        val ()=edit (2,"val b=a+2\n")
        val _=discover ()
        val _=check ()
    in Expect.that ("an edit of a source plans nothing",planned ()=first) end)
  fun planMoves ()=project (fn {path,age,root,old,discover,check,planned,edit,errors,...} =>
    let val _=check ()
        val first=planned ()
        (* the same size, and older than the file's doubt: a time that moved *)
        val ()=writeFile (path "p.build","files b.sml a.sml end\n")
        val ()=OS.FileSys.setTime (path "p.build",SOME (Time.+ (old,Time.fromSeconds 10)))
        val reply=check ()
        val ()=Expect.that ("a build file that changed plans again",planned ()=first+1)
        val ()=Expect.that ("and its order holds",not (null (errors reply)))
        val ()=writeFile (path "p.build","files a.sml b.sml end\n")
        val ()=age "p.build"
        val reply=check ()
        val ()=Expect.that ("back again",null (errors reply))
        val count=planned ()
        val _=discover ()
        val ()=Expect.that ("that plan holds",planned ()=count)
        val ()=writeFile (path "q.build","files b.sml end\n")
        val ()=OS.FileSys.setTime (path "q.build",SOME old)
        val _=discover ()
    in Expect.that ("a new build beside it plans again",planned ()=count+1) end)
  (* a file written this second, of the same size: a stamp cannot tell *)
  fun planRacy ()=project (fn {path,check,planned,errors,...} =>
    let val ()=writeFile (path "p.build","files b.sml a.sml end\n")
        val first=check ()
        val ()=Expect.that ("a build written now is read",not (null (errors first)))
        val ()=writeFile (path "p.build","files a.sml b.sml end\n")
        val second=check ()
        val ()=Expect.that ("and so is one rewritten in the same second at the same size",null (errors second))
        val ()=writeFile (path "a.sml","val c=1\n")
        val third=check ()
    in Expect.that ("as is a closed source",not (null (errors third))) end)
  fun unitsOf count=List.tabulate (count,fn i => {file="unit" ^ Int.toString i ^ ".sml",text="val v" ^ Int.toString i ^ "=" ^
    (if i=0 then "1" else "v" ^ Int.toString (i-1)) ^ "\nstructure S" ^ Int.toString i ^ "=struct datatype t=C end\n",
    revision="1",mode="ascii",annotations=[]}:A.input)
  fun checkOf (context,inputs)=A.check (context,{project=NONE,inputs=inputs,cancelled=fn () => false})
  (* E23: a query of an early file elaborated every unit after it, 2.35 s against 0.012 s *)
  fun queryStops () =
    let fun cost count =
          let val compiler=C.session {lib=NONE,flags=[]}
              val analysis=A.create (compiler,{context="query"})
              val snapshot=checkOf (analysis,unitsOf count)
              val (candidates,{bytes,...})=Runtime.profile (fn () => A.visibleAt (snapshot,{ordinal=1,offset=0,path=[]}))
              val ()=check ("the query sees the unit before it",List.exists (fn candidate:A.candidate => #name candidate="v0") candidates)
          in A.close analysis;C.close compiler;bytes end
        val small=cost 10
        val large=cost 160
    in check ("a query costs nothing of the units after it: " ^ Int.toString small ^ " to " ^ Int.toString large ^ " bytes",
        large<3*small) end
  (* E23: register and stableName, and syntaxAt per input, were quadratic in units *)
  fun linearUnits () =
    let fun cost count =
          let val compiler=C.session {lib=NONE,flags=[]}
              val analysis=A.create (compiler,{context="units"})
              val (_,{bytes,...})=Runtime.profile (fn () =>
                let val snapshot=checkOf (analysis,unitsOf count)
                    val ()=check ("the units check",null (A.diagnostics snapshot))
                in List.app (fn ordinal => ignore (A.syntaxAt (snapshot,{ordinal=ordinal}))) (List.tabulate (count,fn i => i)) end)
          in A.close analysis;C.close compiler;bytes end
        val small=cost 300
        val large=cost 1200
    in check ("analysis is linear in units: 4 times the units, " ^ Int.toString small ^ " to " ^ Int.toString large ^ " bytes",
        large<6*small) end
  (* E23: every hover filtered the occurrences of every unit *)
  fun hoverPerUnit () =
    let fun cost count =
          let val compiler=C.session {lib=NONE,flags=[]}
              val analysis=A.create (compiler,{context="hover"})
              val snapshot=checkOf (analysis,unitsOf count)
              val unit=valOf (A.unitAt (snapshot,{ordinal=0}))
              val (found,{bytes,...})=Runtime.profile (fn () => A.occurrencesIn (snapshot,unit))
              val ()=check ("a unit's occurrences are its own",not (null found) andalso
                List.all (fn occurrence:A.occurrence => #unit occurrence=unit) found andalso
                found=List.filter (fn occurrence:A.occurrence => #unit occurrence=unit) (A.occurrences snapshot))
          in A.close analysis;C.close compiler;bytes end
        val small=cost 10
        val large=cost 160
    in check ("one unit's occurrences cost nothing of the others: " ^ Int.toString small ^ " to " ^ Int.toString large ^ " bytes",
        large<3*small) end
  (* A tree of files on disk, a minute old, a worker, and a way to open one of
     them, check it and discover its contexts; the client's folder is the
     tree's root. *)
  fun tree (files,action) =
    let val root=OS.FileSys.tmpName ()
        val ()=OS.FileSys.remove root handle OS.SysErr _ => ()
        val ()=OS.FileSys.mkDir root
        val root=OS.FileSys.fullPath root
        fun path name=OS.Path.concat (root,name)
        val made=ref [root]
        fun mkdirs dir=if dir=root orelse List.exists (fn other => other=dir) (!made) then () else
          (mkdirs (OS.Path.dir dir);OS.FileSys.mkDir dir;made:=dir:: !made)
        val old=Time.- (Time.now (),Time.fromSeconds 100)
        val ()=List.app (fn (name,text) => (mkdirs (OS.Path.dir (path name));writeFile (path name,text);
          OS.FileSys.setTime (path name,SOME old))) files
        val ()=List.app (fn dir => OS.FileSys.setTime (dir,SOME old)) (!made)
        val platform=LspUri.Posix
        fun uri name=LspUri.original (LspUri.fromPath (platform,path name))
        val workspace=W.new {platform=platform,lib="lib"}
        val ()=W.setRoots (workspace,[LspUri.original (LspUri.fromPath (platform,root))])
        val documents=D.new (LspProtocol.Utf16,{maxDocuments=8,maxDocumentBytes=4*1024*1024,maxTotalBytes=8*1024*1024,
          maxDocumentLines=200000,maxTotalLines=300000})
        fun open' name=if isSome (D.snapshot (documents,uri name)) then () else ignore (D.openDocument (documents,{uri=uri name,languageId="sml",version=1,text=
          List.foldl (fn ((other,text),found) => if other=name then text else found) "" files}))
        val {call,phases,stop}=harness ()
        (* as the service captures it, with the folder the client watches once
           watch () says so; changed names files an event says changed *)
        val watching=ref false
        fun state ()=V.Object (("watchedRoots",M.strings (if !watching then [LspUri.original (LspUri.fromPath (platform,root))] else []))::
          V.object (M.capture (workspace,documents)))
        fun watch ()=watching:=true
        fun changed names=W.changed (workspace,List.map (fn name => (uri name,false)) names)
        fun check name=(open' name;call [("op",V.Bytes "check"),("uri",V.Bytes (uri name)),("encoding",V.Bytes "utf-16"),("state",state ())])
        fun discover name=(open' name;call [("op",V.Bytes "discover"),("uri",V.Bytes (uri name)),("state",state ())])
        fun workspaceDiagnostics ()=V.unjson (call [("op",V.Bytes "workspace"),("method",V.Bytes "workspace/diagnostic"),
          ("encoding",V.Bytes "utf-16"),("params",V.json (Json.Object [("previousResultIds",Json.Array [])])),
          ("capabilities",V.json (Json.Object [])),("state",state ())])
        fun errors reply=case V.array (V.field (reply,"reports")) of [] => [] | report::_ =>
          (case Json.member ("items",V.unjson (V.field (report,"report"))) of SOME (Json.Array items) => items | _ => [])
        fun messages reply=List.map (fn item => case Json.member ("message",item) of SOME (Json.String text) => text | _ => "") (errors reply)
        fun clean dir=(List.app (fn entry => let val full=OS.Path.concat (dir,entry)
            in if OS.FileSys.isDir full then clean full else OS.FileSys.remove full end)
            (let val stream=OS.FileSys.openDir dir
                 fun all found=case OS.FileSys.readDir stream of NONE => found | SOME entry => all (entry::found)
             in all [] before OS.FileSys.closeDir stream end);OS.FileSys.rmDir dir) handle OS.SysErr _ => ()
        val result=(action {uri=uri,path=path,check=check,discover=discover,errors=errors,messages=messages,phases=phases,
          workspaceDiagnostics=workspaceDiagnostics,watch=watch,changed=changed,old=old} handle error => (stop ();clean root;raise error))
    in stop ();clean root;result end
  fun kind reply=V.bytes (V.field (reply,"kind"))
  fun contextNames reply=List.map (fn context => V.bytes (V.field (context,"build"))) (V.array (V.field (reply,"contexts")))
  fun shown reply=kind reply ^ " " ^ String.concatWith " " (List.map (fn name => OS.Path.file name) (contextNames reply))
  (* D26: a file of a library is checked in the library, whatever else names it *)
  fun owner ()=tree ([("lib1/library.build","files x.sml y.sml end\n"),("lib1/x.sml","structure X=struct val x=1 end\n"),
      ("lib1/y.sml","structure Y=struct val y=X.x end\n"),
      ("program.build","files lib1/x.sml lib1/y.sml main.sml end\n"),("main.sml","val main=Y.y\n"),
      ("lib1/tests.build","files x.sml y.sml check.sml end\n"),("lib1/check.sml","val checked=Y.y\n")],
    fn {uri,discover,check,errors,...} =>
    let val found=discover "lib1/y.sml"
        val ()=Expect.that ("a file of a library has one context, the library's, and no prompt: " ^ shown found,
          kind found="selected" andalso contextNames found=[uri "lib1/library.build"])
        val ()=Expect.that ("and checks in it",null (errors (check "lib1/y.sml")))
        val outside=discover "main.sml"
    in Expect.that ("a file of no library keeps its build",kind outside="selected" andalso contextNames outside=[uri "program.build"]) end)
  (* D26: contexts compared by what the file's names resolve to, never by a
     printed type; one that never reaches the file is no candidate *)
  fun compared ()=tree ([("one.build","files base.sml shared.sml end\n"),("two.build","files base.sml other.sml shared.sml end\n"),
      ("three.build","files broken.sml shared.sml end\n"),("four.build","files input.sml shared.sml end\n"),
      ("base.sml","structure Base=struct val input=1 end\n"),("other.sml","structure Other=struct val unused=true end\n"),
      ("broken.sml","val broken:int=true\n"),("input.sml","structure Base=struct val input=2 end\n"),
      ("shared.sml","val result=Base.input+1\n"),
      ("same.build","files base.sml twin.sml end\n"),("again.build","files base.sml other.sml twin.sml end\n"),
      ("twin.sml","val twin=Base.input\n")],
    fn {uri,discover,check,errors,phases,...} =>
    let val twin=discover "twin.sml"
        val ()=Expect.that ("contexts whose names resolve alike ask nothing: " ^ shown twin,kind twin="selected" andalso
          contextNames twin=[uri "again.build",uri "same.build"])
        val ()=Expect.that ("and the file checks in the first",null (errors (check "twin.sml")))
        val shared=discover "shared.sml"
        val ()=Expect.that ("where they resolve apart a choice is asked, of those that reach the file: " ^ shown shared,kind shared="ambiguous" andalso
          contextNames shared=[uri "four.build",uri "one.build",uri "two.build"])
    in Expect.that ("each comparison is reported",List.exists (fn phase => phase="contexts-compared") (!phases)) end)
  (* D28: where the client watches, its file events say what changed, and a
     plan takes them over the stamps: a build rewritten at its size and time,
     which no stamp can tell, is read again when an event names it, and an
     event that names another file plans nothing. *)
  fun planByEvents ()=tree ([("lib1/library.build","files x.sml y.sml end\n"),("lib1/x.sml","structure X=struct val x=1 end\n"),
      ("lib1/y.sml","structure Y=struct val y=X.x end\n"),("main.sml","val main=Y.y\n"),
      ("program.build","use lib1/library.build\nfiles main.sml end\n")],
    fn {path,check,errors,phases,watch,changed,old,...} =>
    let fun planned ()=length (List.filter (fn phase => phase="planning") (!phases))
        val ()=watch ()
        val ()=Expect.that ("a file of a library checks in it",null (errors (check "lib1/y.sml")))
        val first=planned ()
        val ()=changed ["main.sml"]
        val ()=Expect.that ("an event of a file the plan did not read plans nothing",
          null (errors (check "lib1/y.sml")) andalso planned ()=first)
        val ()=writeFile (path "lib1/library.build","files y.sml x.sml end\n")
        val ()=OS.FileSys.setTime (path "lib1/library.build",SOME old)
        val ()=Expect.that ("with no event, a build rewritten at its size and time is not seen",
          null (errors (check "lib1/y.sml")) andalso planned ()=first)
        val ()=changed ["lib1/library.build"]
        val reply=check "lib1/y.sml"
    in Expect.that ("its event has it read again, and its new order holds",planned ()=first+1 andalso not (null (errors reply))) end)
  (* D28: where the events since a closed input was read are not whole, its
     stamp says, not the events: a change no event named is seen *)
  fun textsPastEvents ()=tree ([("lib1/library.build","files x.sml y.sml end\n"),("lib1/x.sml","structure X=struct val x=1 end\n"),
      ("lib1/y.sml","structure Y=struct val y=X.x+1 end\n")],
    fn {path,check,errors,watch,changed,...} =>
    let val ()=watch ()
        val ()=Expect.that ("the library checks",null (errors (check "lib1/y.sml")))
        val ()=writeFile (path "lib1/x.sml","structure X=struct val x=true end\n")
        val ()=changed (List.tabulate (W.changeLimit+1,fn i => "lib1/elsewhere" ^ Int.toString i ^ ".sml"))
    in Expect.that ("a closed input changed with no event is read again when the events are not whole",
        not (null (errors (check "lib1/y.sml")))) end)
  (* D26: a file in no build, its names found in its directory, in a library
     and anywhere in its workspace, the nearest first *)
  fun implicit ()=tree ([("rune.workspace","roots lib end\n"),
      ("tools/a/script.sml","val total=Helper.twice 2 + Far.value\nval document=Json.decode \"[]\"\n"),
      ("tools/a/helper.sml","structure Helper=struct fun twice x=Inner.base*x end\n"),
      ("tools/a/inner.sml","structure Inner=struct val base=2 end\n"),
      ("tools/b/helper.sml","structure Helper=struct fun twice x=x end\n"),
      ("deep/far/far.sml","structure Far=struct val value=3 end\n"),
      ("tools/a/unbound.sml","val missing=Nowhere.value\n"),
      ("tools/a/broken.sml","val sum=Helper.twice true\nval later:string=Far.value\n")],
    fn {check,messages,discover,...} =>
    let val found=discover "tools/a/script.sml"
        val ()=Expect.that ("a file in no build has its implicit library, and no prompt",kind found="selected" andalso
          V.bytes (V.field (V.field (found,"context"),"name"))="implicit")
        val found=messages (check "tools/a/script.sml")
        val ()=Expect.that ("its names are found beside it, in a library and anywhere in its workspace: " ^ String.concatWith "; " found,
          null found)
        val ()=Expect.that ("a name nowhere is unbound",List.exists (fn text => String.isSubstring "Nowhere" text)
          (messages (check "tools/a/unbound.sml")))
        val broken=messages (check "tools/a/broken.sml")
    in Expect.that ("the nearest of two is taken, and analysis goes past an error",length broken=2) end)
end
structure RuneLspWorkerAnalysisTestMain=Main (struct
  val name="lsp-worker-analysis"
  val tests=Test.describe "lsp-worker-analysis" [Test.it "snapshots-diagnostics-cancellation" RuneLspWorkerAnalysisTests.run,
    Test.it "linear-in-declarations" RuneLspWorkerAnalysisTests.linear,
    Test.it "plan-holds-through-edits" RuneLspWorkerAnalysisTests.planHolds,
    Test.it "plan-moves-with-its-files" RuneLspWorkerAnalysisTests.planMoves,
    Test.it "plan-trusts-no-new-stamp" RuneLspWorkerAnalysisTests.planRacy,
    Test.it "query-stops-at-its-unit" RuneLspWorkerAnalysisTests.queryStops,
    Test.it "linear-in-units" RuneLspWorkerAnalysisTests.linearUnits,
    Test.it "hover-reads-its-unit" RuneLspWorkerAnalysisTests.hoverPerUnit,
    Test.it "one-owning-library" RuneLspWorkerAnalysisTests.owner,
    Test.it "contexts-compared-by-binder" RuneLspWorkerAnalysisTests.compared,
    Test.it "implicit-library" RuneLspWorkerAnalysisTests.implicit,
    Test.it "plan-by-file-events" RuneLspWorkerAnalysisTests.planByEvents,
    Test.it "texts-past-file-events" RuneLspWorkerAnalysisTests.textsPastEvents]
end)
val ()=RuneLspWorkerAnalysisTestMain.main ()

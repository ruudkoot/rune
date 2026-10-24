structure RuneLspJobsTests =
struct
  structure J=RuneLspJobs
  structure V=RuneLspWorkerWire
  val check=Expect.that
  fun fixture action =
    let val (vm,worker)=case CommandLine.arguments () of [vm,worker] => (vm,worker) | _ => raise Fail "worker paths required"
        val jobs=J.new {command=vm,args=[worker],timeout=Time.fromSeconds 10,cancelGrace=Time.fromMilliseconds 50,maxPending=8}:string J.t
    in (action jobs before J.close jobs) handle error => (J.close jobs;raise error) end
  fun payload () =
    let val documents=RuneLspDocuments.new (LspProtocol.Utf8,{maxDocuments=1,maxDocumentBytes=1000,maxTotalBytes=1000,
          maxDocumentLines=100,maxTotalLines=100})
        val _=RuneLspDocuments.openDocument (documents,{uri="untitled:queue",languageId="sml",version=1,text="val x=1\n"})
        val platform=if List.exists (fn (name,value) => name="sysname" andalso value="Windows") (Posix.ProcEnv.uname ())
          then LspUri.Windows else LspUri.Posix
        val workspace=RuneLspWorkspace.new {platform=platform,lib="lib"}
    in V.Object [("op",V.Bytes "discover"),("uri",V.Bytes "untitled:queue"),
      ("state",RuneLspWorkerModel.capture (workspace,documents))] end
  fun collect (jobs,count) =
    let val until=Time.+ (Time.now (),Time.fromSeconds 20)
        fun loop all=if length all>=count then List.rev all else
          if Time.> (Time.now (),until) then raise Fail "job completion timeout" else
          let val events=J.pump (jobs,OS.IO.poll (J.descriptors jobs,SOME (Time.fromMilliseconds 20)))
              val events=List.filter (fn J.Restarted => false | _ => true) events
          in loop (List.rev events @ all) end
    in J.tick jobs;loop [] end
  fun priorities ()=fixture (fn jobs =>
    let val body=payload ()
        val _=J.submit (jobs,{key=SOME "background",priority=100,data="superseded",payload=body})
        val _=J.submit (jobs,{key=SOME "background",priority=100,data="background",payload=body})
        val _=J.submit (jobs,{key=NONE,priority=0,data="foreground",payload=body})
        val events=collect (jobs,3)
        fun label (J.Cancelled name)="cancel:" ^ name | label (J.Done (name,_))="done:" ^ name
          | label (J.Failed (name,message))=raise Fail (name ^ ": " ^ message)
          | label (J.Rejected (name,error))=raise Fail (name ^ ": " ^ #message error) | label J.Restarted="restart"
    in check ("foreground precedes coalesced background",List.map label events=["cancel:superseded","done:foreground","done:background"]) end)
  fun queuedCancellation ()=fixture (fn jobs =>
    let val id=J.submit (jobs,{key=NONE,priority=0,data="cancelled",payload=payload ()})
        val ()=J.cancel (jobs,id)
    in check ("queued cancellation finishes once",case collect (jobs,1) of [J.Cancelled "cancelled"] => true | _ => false) end)
  fun failedStartup () =
    let val jobs=J.new {command="/no/runelsp/worker",args=[],timeout=Time.fromSeconds 1,cancelGrace=Time.zeroTime,maxPending=2}:string J.t
        val _=J.submit (jobs,{key=NONE,priority=0,data="missing",payload=payload ()})
        val events=collect (jobs,1)
        val ()=J.close jobs
        val message=case events of [J.Failed("missing",message)]=>message | _=>"unexpected startup events"
    in check ("startup failure completes with the launch path and job: " ^ message,
      String.isSubstring "/no/runelsp/worker" message andalso String.isSubstring "job 0" message) end
  fun typedRejection ()=fixture (fn jobs =>
    let val _=J.submit (jobs,{key=NONE,priority=0,data="expired",payload=V.Object [("op",V.Bytes "query"),
          ("snapshot",V.Bytes "not-retained"),("method",V.Bytes "textDocument/hover"),("params",V.Object [])]})
        val events=collect (jobs,1)
    in check ("worker rejection retains its code separately from infrastructure failure",case events of
      [J.Rejected ("expired",error)] => #code error=LspProtocol.contentModified | _ => false) end)
  fun informativeTimeout ()=fixture(fn jobs=>
    let val J.Jobs{command,args,worker,active,queue,phase,started,events,...}=jobs
        val process=RuneLspWorkerProcess.start{command=command,args=args,limits=Subprocess.unlimited}
        val RuneLspWorkerProcess.Process{pid,...}=process
        val uri="file:///project%20with%20spaces/%CE%BB/rune-main.sml"
        val id=J.submit(jobs,{key=NONE,priority=0,data="deadline",payload=V.Object[("op",V.Bytes "query"),
          ("uri",V.Bytes uri),("snapshot",V.Bytes "snapshot-55"),("method",V.Bytes "textDocument/completion"),
          ("state",V.Bytes "captured-source-sentinel")]})
        val ()=(worker:=SOME process;active:=SOME(hd(!queue));queue:=[];
          started:=SOME(Time.-(Time.now(),Time.fromSeconds 11));phase:=J.Working(Time.-(Time.now(),Time.fromSeconds 1)))
        val ()=J.message(jobs,V.Object[("op",V.Bytes "progress"),("id",V.Integer id),
          ("phase",V.Bytes "project-selected"),("file",V.Bytes "file:///project/rune.build"),("context",V.Bytes "rune")])
        val ()=J.message(jobs,V.Object[("op",V.Bytes "progress"),("id",V.Integer id),
          ("phase",V.Bytes "unit-elaborated"),("file",V.Bytes "/project with spaces \206\187/elaborate.sml"),
          ("checked",V.Integer 187),("reused",V.Integer 2)])
        val ()=check("progress is metadata, not a completed job",null(!events))
        val ()=J.tick jobs
        val message=case List.find(fn J.Failed("deadline",_)=>true | _=>false)(!events) of
          SOME(J.Failed(_,message))=>message | _=>raise Fail "deadline did not fail despite progress"
    in check("deadline identifies worker, job, request, source, project and last phase",
      List.all(fn text=>String.isSubstring text message)["analysis worker exceeded its deadline",
        "worker PID " ^ Int.toString pid,"job " ^ IntInf.toString id,"textDocument/completion",uri,
        "snapshot-55","context: rune","rune.build","unit-elaborated","elaborate.sml","checked 187","reused 2","limit 10.000 s"]);
      check("failure metadata excludes captured source/state",not(String.isSubstring "captured-source-sentinel" message))
    end)
  fun metadataBounds ()=
    let val path=String.implode(List.tabulate(10000,fn _=> #"x")) ^ "/tail\n\255\206\187.sml"
        val shown=J.preview path
    in check("metadata stays bounded and escapes controls and invalid native bytes",size shown<1100 andalso
      String.isSubstring "tail\\x0A\\xFF" shown andalso not(String.isSubstring "\n" shown)) end
end
structure RuneLspJobsTestMain=Main (struct
  val name="lsp-jobs"
  val tests=Test.describe "lsp-jobs" [Test.it "priority-and-coalescing" RuneLspJobsTests.priorities,
    Test.it "queued-cancellation" RuneLspJobsTests.queuedCancellation,Test.it "failed-startup" RuneLspJobsTests.failedStartup,
    Test.it "typed-rejection" RuneLspJobsTests.typedRejection,
    Test.it "informative-timeout" RuneLspJobsTests.informativeTimeout,
    Test.it "bounded-error-metadata" RuneLspJobsTests.metadataBounds]
end)
val ()=RuneLspJobsTestMain.main ()

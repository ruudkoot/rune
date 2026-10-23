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
          | label (J.Failed (name,message))=raise Fail (name ^ ": " ^ message) | label J.Restarted="restart"
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
    in check ("startup failure completes without retrying forever",case events of [J.Failed ("missing",_)] => true | _ => false) end
end
structure RuneLspJobsTestMain=Main (struct
  val name="lsp-jobs"
  val tests=Test.describe "lsp-jobs" [Test.it "priority-and-coalescing" RuneLspJobsTests.priorities,
    Test.it "queued-cancellation" RuneLspJobsTests.queuedCancellation,Test.it "failed-startup" RuneLspJobsTests.failedStartup]
end)
val ()=RuneLspJobsTestMain.main ()

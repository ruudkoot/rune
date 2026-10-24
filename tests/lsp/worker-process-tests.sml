structure RuneLspWorkerProcessTests =
struct
  structure P=RuneLspWorkerProcess
  structure W=RuneLspWorkerWire
  val check=Expect.that
  fun arguments ()=case CommandLine.arguments () of [vm,worker] => (vm,worker)
    | _ => raise Fail "worker tests require VM and worker bytecode paths"
  fun fixture action =
    let val (vm,worker)=arguments ()
        val process=P.start {command=vm,args=[worker],limits=Subprocess.unlimited}
        fun reap ()=let val until=Time.+ (Time.now (),Time.fromSeconds 3)
              fun loop ()=case P.reap process of SOME _ => () | NONE =>
                if Time.> (Time.now (),until) then raise Fail "worker was not reaped" else
                  (ignore (OS.IO.poll ([],SOME (Time.fromMilliseconds 10)));loop ())
            in loop () end
        fun clean ()=(P.terminate process;reap ())
    in (action process before clean ()) handle error => (clean () handle _ => ();raise error) end
  fun receive process =
    let val until=Time.+ (Time.now (),Time.fromSeconds 10)
        fun loop ()=if Time.> (Time.now (),until) then raise Fail "worker response timeout" else
          case P.pump (process,OS.IO.poll (P.descriptors process,SOME (Time.fromMilliseconds 20))) of
            [] => loop () | events => events
    in loop () end
  fun roundtrip ()=fixture (fn process =>
    let val ()=check ("worker ready",case receive process of [P.Message (W.Bytes "ready")] => true | _ => false)
        val payload=W.Bytes (CharVector.tabulate (1048576,fn i => Char.chr (i mod 256)))
        val ()=P.enqueue (process,payload)
        val {infd,outfd}=Posix.IO.pipe ()
        val _=Posix.IO.writeVec (outfd,Word8VectorSlice.full (Byte.stringToBytes "x"))
        val input=OS.IO.pollIn (valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD infd)))
        val ready=OS.IO.poll (input :: P.descriptors process,SOME Time.zeroTime)
        val ()=check ("other protocol input remains pollable",List.exists (fn info => OS.IO.compare
          (OS.IO.pollToIODesc (OS.IO.infoToPollDesc info),Posix.FileSys.fdToIOD infd)=EQUAL) ready)
        val ()=(Posix.IO.close infd;Posix.IO.close outfd)
        val ()=ignore (P.pump (process,ready))
    in check ("large binary round trip under backpressure",case receive process of [P.Message returned] => returned=payload | _ => false) end)
  fun cancellation ()=fixture (fn process =>
    let val _=receive process
        val ()=P.enqueue (process,W.Bytes "hold")
        val ()=check ("worker entered slow phase",case receive process of [P.Message (W.Bytes "holding")] => true | _ => false)
        val ()=P.terminate process
    in check ("termination closes protocol descriptors",P.closed process andalso null (P.descriptors process)) end)
  fun truncated ()=fixture (fn process =>
    let val _=receive process
        val ()=P.enqueue (process,W.Bytes "truncate")
    in check ("truncated worker frames fail",case receive process of [P.Failed _] => true | _ => false) end)
  fun stderrLimits ()=List.app(fn (command,expected)=>fixture(fn process=>
    let val _=receive process
        val ()=P.enqueue(process,W.Bytes command)
        val timer=Timer.startRealTimer()
        val events=receive process
    in check("bounded classified stderr: " ^ command,case events of [P.Failed message]=>message=expected
        andalso P.closed process andalso Time.<(Timer.checkRealTimer timer,Time.fromSeconds 3) | _=>false) end))
    [("heap","analysis worker exhausted its heap budget"),("stderr-flood","analysis worker exceeded its stderr budget")]
  fun awaited ()=fixture(fn process=>
    let val _=receive process val ended=P.await process
    in check("shutdown waits for the terminated child",P.closed process andalso P.reap process=SOME ended) end)
end
structure RuneLspWorkerProcessTestMain=Main (struct
  val name="lsp-worker-process"
  val tests=Test.describe "lsp-worker-process"
    [Test.it "roundtrip-and-input" RuneLspWorkerProcessTests.roundtrip,
     Test.it "cancellation" RuneLspWorkerProcessTests.cancellation,
     Test.it "truncated-output" RuneLspWorkerProcessTests.truncated,
     Test.it "bounded-stderr" RuneLspWorkerProcessTests.stderrLimits,
     Test.it "reaped-shutdown" RuneLspWorkerProcessTests.awaited]
end)
val ()=RuneLspWorkerProcessTestMain.main ()

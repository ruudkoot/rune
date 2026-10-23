(* Compile isolated defects into the unchanged shared behavioral suite. A
   compile error, crash or timeout never counts as detecting a mutation. *)
structure Win32ContractMutants =
struct
  open Sh
  fun need(ok,message)=if ok then () else raise Fail message
  val lib=OS.FileSys.fullPath(env("RUNE_LIB","lib"))
  val sourceRoot=OS.Path.dir lib
  val rune=env("RUNE","bin/rune")
  val vm=env("RUNEVM","bin/runevm")
  val directory=let val reservation=OS.FileSys.tmpName()
      val path=run ^ "/win32-mutants/" ^ OS.Path.file reservation
      val ()=mkdirs path val ()=OS.FileSys.remove reservation
    in path end
  val model=lib ^ "/ffi/win32/model/model.sml"
  val mock=lib ^ "/ffi/win32/mock/mock.sml"
  val contract=fromRoot "tests/ffi/win32/contract.sml"
  val original=read model
  fun hash path=Hex.fromBytes(Sha256.digest(read path))
  fun replaceOnce(old,replacement)=
    let val n=size old val limit=size original-n
        fun positions i values=if i>limit then List.rev values else
          positions(i+1)(if String.substring(original,i,n)=old then i::values else values)
    in case positions 0 [] of [i]=>String.substring(original,0,i) ^ replacement ^ String.extract(original,i+n,NONE)
       | matches=>raise Fail("mutation anchor occurs " ^ Int.toString(length matches) ^ " times: " ^ old) end
  val variants=[("baseline",NONE,NONE),
    ("paint-cleanup",SOME("val result=body value handle e=>(endPaint(token,#1 value)handle _=>();raise e)",
      "val result=body value handle e=>raise e"),SOME "paint-output-scopes-and-exception-cleanup"),
    ("message-order",SOME("queue:= !queue @ [(window,message)]","queue:=(window,message):: !queue"),
      SOME "queue-filter-copy-discard-and-single-use"),
    ("timer-cancellation",SOME("timers:=List.filter(fn(t:timerState)=>not(#window t=token andalso #id t=id))(!timers);note \"kill-timer\"",
      "timers:= !timers;note \"kill-timer\""),SOME "timers-cancel-and-preserve-identity"),
    ("stale-window",SOME("fun getClientRect token=rect(findWindow \"getClientRect\" token)",
      "fun getClientRect token=rect(findWindow \"getClientRect\" token) handle Types.Error _=>{left=Int32.fromInt 0,top=Int32.fromInt 0,right=Int32.fromInt 1,bottom=Int32.fromInt 1}"),
      SOME "unsupported-selection-and-stale-window")]
  val main=directory ^ "/main.sml"
  val ()=write(main,"structure MockContract=Win32ContractFn(struct structure Win32=Win32Mock val name=\"mock\" end)\n" ^
    "structure MockContractMain=Main(struct val name=\"win32/mock/contract\" val tests=MockContract.tests end)\nval ()=MockContractMain.main()\n")
  fun command name args=
    let val prefix=directory ^ "/" ^ name
        val ()=write(prefix ^ ".argv.json",Json.encode(Json.Array(List.map Json.String args)) ^ "\n")
        val status=Children.exec Subprocess.unlimited(fn e=>e){cmd=args,dir=SOME root,stdin="",
          stdout=prefix ^ ".out",stderr=prefix ^ ".err",timeout=300}
        val ()=write(prefix ^ ".status",Int.toString status ^ "\n")
    in (status,read(prefix ^ ".out"),read(prefix ^ ".err")) end
  fun one(name,change,expected)=
    let val source=directory ^ "/" ^ name ^ ".sml" val code=directory ^ "/" ^ name ^ ".rbc"
        val ()=write(source,case change of NONE=>original | SOME pair=>replaceOnce pair)
        val (compiled,_,errors)=command(name ^ "-compile")[rune,"--lib",lib,"--library","ffi/win32/mock",
          "--library","test/unit",source,mock,contract,main,"-o",code]
        val ()=need(compiled=0,name ^ " must compile before execution: " ^ errors)
        val (status,output,errors)=command(name ^ "-run")[vm,"--jit=off","--gc-stress","7","--gc-verify",code]
        val ()=case expected of NONE=>need(status=0 andalso String.isSubstring "SUMMARY 11 tests, 11 passed" output,"baseline suite failed")
          | SOME group=>need(status=1 andalso List.exists(fn line=>String.isPrefix "FAIL " line andalso
                String.isSubstring("/" ^ group)line)(lines output) andalso
              String.isSubstring "SUMMARY 11 tests," output andalso errors="",
              name ^ " must fail its intended contract group, without a crash or timeout: " ^ output ^ errors)
        val ()=say("PASS Win32 contract mutation: " ^ name ^ "\n")
    in Json.Object[("variant",Json.String name),("sourceSha256",Json.String(hash source)),
      ("bytecodeSha256",Json.String(hash code)),("status",Json.int status),
      ("expectedFailure",case expected of NONE=>Json.Null | SOME value=>Json.String value)] end
  val results=List.map one variants
  val ()=write(directory ^ "/results.json",Json.encodeIndented 2(Json.Object[
    ("schema",Json.int 1),("libraryRoot",Json.String lib),("modelSha256",Json.String(hash model)),
    ("mockSha256",Json.String(hash mock)),("contractSha256",Json.String(hash contract)),
    ("vmSha256",Json.String(hash vm)),("variants",Json.Array results)]) ^ "\n")
  val ()=need(read model=original,"production model changed during mutation checks")
  val ()=say("PASS all four planted Win32 faults rejected: " ^ directory ^ "/results.json\n")
end

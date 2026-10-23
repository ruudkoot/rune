(* Timed phases exclude fixture validation, warmup and final cleanup. *)
structure FfiPerformance =
struct
  fun need(condition,message)=if condition then () else raise Fail message
  val (libraryPath,iterations)=case CommandLine.arguments() of [path,count]=>
      (path,case Int.fromString count of SOME n=>if n>0 andalso n<=10000000 then n else raise Fail "iteration range"
        | NONE=>raise Fail "iteration count")
    | _=>raise Fail "usage: performance.rbc SUBJECT ITERATIONS"
  val warmup=Int.min(1000,Int.max(10,iterations div 10))
  fun number value=Json.Number(String.translate(fn #"~"=>"-" | c=>str c)(Real.toString value))
  fun bufferPhase phase=String.isPrefix "marshal-256" phase
  fun measure phase count body=
    let val first=Runtime.stats() val resources=RuneForeign.live()
        val timer=Timer.startCPUTimer() val wall=Runtime.clock()
        val checksum=body()
        val elapsed=Time.toReal(Time.-(Runtime.clock(),wall))
        val {usr,sys}=Timer.checkCPUTimer timer
        val cpu=Time.toReal(Time.+(usr,sys))
        val last=Runtime.stats() val afterResources=RuneForeign.live()
        val ()=need(resources=afterResources,"phase leaked native resources")
        val ()=print(Json.encode(Json.Object[("implementation",Json.String "rune"),("phase",Json.String phase),
          ("iterations",Json.int count),("cpuSeconds",number cpu),("wallSeconds",number elapsed),
          ("warmupIterations",Json.int(if String.isSuffix "-first" phase then 0 else warmup)),
          ("smlAllocatedBytes",Json.int(#bytes last- #bytes first)),
          ("smlAllocatedObjects",Json.int(#objects last- #objects first)),
          ("collections",Json.int(#collections last- #collections first)),
          ("foreignResourcesBefore",Json.String(IntInf.toString(Word64.toLargeInt resources))),
          ("foreignResourcesAfter",Json.String(IntInf.toString(Word64.toLargeInt afterResources))),
          ("bufferPayloadAllocatedBytes",Json.int(if bufferPhase phase then count*256 else 0)),
          ("peakBufferPayloadBytes",Json.int(if bufferPhase phase then 256 else 0)),
          ("nativeMetadataBytes",Json.Null),
          ("checksum",Json.String(IntInf.toString(Word64.toLargeInt checksum)))]) ^ "\n")
    in checksum end
  fun repeat count body=let fun loop 0 value=value | loop n value=loop(n-1)(body value)
    in loop count 0w0 end
  fun warm body=ignore(repeat warmup body)
  val preparations=Int.max(10,iterations div 100)
  fun increment value=Word64.+(value,0w1)
  val ()=warm increment
  val ()=need(measure "loop" iterations(fn()=>repeat iterations increment)=Word64.fromInt iterations,"loop checksum")
  fun load _=let val library=RuneForeign.openLibrary libraryPath
    val symbol=RuneForeign.symbol(library,"rfp_scalar")
    val ()=RuneForeign.release symbol val ()=RuneForeign.release library in 0w0 end
  val ()=ignore(measure "load-symbol-first" 1(fn()=>load 0w0))
  val ()=warm load
  val ()=ignore(measure "load-symbol" preparations(fn()=>repeat preparations load))
  val library=RuneForeign.openLibrary libraryPath
  val owned=ref([]:RuneForeign.resource list)
  fun symbol name=let val value=RuneForeign.symbol(library,name) in owned:=value:: !owned;value end
  val scalarSymbol=symbol "rfp_scalar"
  fun prepare symbol result arguments=RuneForeign.prepare{symbol=symbol,abi=0,result=result,arguments=arguments}
  fun preparation _=let val call=prepare scalarSymbol RuneForeign.UInt64 [RuneForeign.UInt64]
    in RuneForeign.release call;0w0 end
  val ()=ignore(measure "prepare-first" 1(fn()=>preparation 0w0))
  val ()=warm preparation
  val ()=ignore(measure "prepare" preparations(fn()=>repeat preparations preparation))
  fun call symbol result arguments=let val value=prepare symbol result arguments in owned:=value:: !owned;value end
  val scalar=call scalarSymbol RuneForeign.UInt64 [RuneForeign.UInt64]
  fun word(result:RuneForeign.result)=PackWord64Little.subVec(Byte.stringToBytes(#bytes result),0)
  fun scalarStep value=word(RuneForeign.invoke(scalar,[RuneForeign.Unsigned value]))
  val ()=need(measure "scalar-first" 1(fn()=>scalarStep 0w0)=0w1,"first scalar checksum")
  val ()=warm scalarStep
  val result=measure "scalar" iterations(fn()=>repeat iterations scalarStep)
  val ()=need(result=Word64.fromInt iterations,"scalar checksum")
  val sizeType=if #pointerBytes(RuneForeign.target())=4 then RuneForeign.UInt32 else RuneForeign.UInt64
  val buffer=call(symbol "rfp_buffer") RuneForeign.UInt64 [RuneForeign.Pointer,sizeType]
  val array=Word8Array.array(256,0w0)
  fun marshalStep _=ForeignMemory.withArrays
    [{array=array,offset=0,length=256,direction=ForeignMemory.InputOutput}]
    (fn buffers=>word(RuneForeign.invoke(buffer,[RuneForeign.Address(SOME(ForeignMemory.raw(hd buffers))),RuneForeign.Unsigned 0w256])))
  val ()=need(measure "marshal-256-first" 1(fn()=>marshalStep 0w0)=0w1,"first buffer checksum")
  val ()=warm marshalStep
  val ()=Word8Array.modify(fn _=>0w0)array
  val result=measure "marshal-256" iterations(fn()=>repeat iterations marshalStep)
  val ()=need(result=Word64.fromInt(iterations mod 256) andalso
    Word8Array.all(fn byte=>byte=Word8.fromInt(iterations mod 256))array,"buffer checksum")
  val callback=RuneForeign.callback{abi=0,result=RuneForeign.UInt64,arguments=[RuneForeign.UInt64],
    failure=RuneForeign.Default(RuneForeign.Unsigned 0w0),function=fn [RuneForeign.Unsigned value]=>RuneForeign.Unsigned(Word64.+(value,0w1))
      | _=>raise Fail "callback shape"}
  val callbackCall=call(symbol "rfp_callback") RuneForeign.UInt64 [RuneForeign.Pointer,RuneForeign.UInt64]
  fun callbackStep value=word(RuneForeign.invoke(callbackCall,[RuneForeign.Address(SOME callback),RuneForeign.Unsigned value]))
  val ()=need(measure "callback-first" 1(fn()=>callbackStep 0w0)=0w1,"first callback checksum")
  val ()=warm callbackStep
  val result=measure "callback" iterations(fn()=>repeat iterations callbackStep)
  val ()=need(result=Word64.fromInt iterations,"callback checksum")
  val ()=RuneForeign.release callback
  val ()=List.app RuneForeign.release(!owned)
  val ()=RuneForeign.release library
  val ()=need(RuneForeign.live()=0w0,"performance resource leak")
  val ()=print(Json.encode(Json.Object[("implementation",Json.String "rune"),("phase",Json.String "cleanup"),
    ("foreignResourcesAfter",Json.String "0")]) ^ "\n")
end

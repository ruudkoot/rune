(* Phase-separated timings; correctness checks run outside each timed phase.
   Timing thresholds deliberately do not participate in make check. *)
structure FfiPerformance =
struct
  fun need(condition,message)=if condition then () else raise Fail message
  val (libraryPath,iterations)=case CommandLine.arguments() of [path,count]=>
      (path,case Int.fromString count of SOME n=>if n>0 andalso n<=10000000 then n else raise Fail "iteration range"
        | NONE=>raise Fail "iteration count")
    | _=>raise Fail "usage: performance.rbc SUBJECT ITERATIONS"
  fun number value=Json.Number(String.translate(fn #"~"=>"-" | c=>str c)(Real.toString value))
  fun measure phase count body=
    let val timer=Timer.startCPUTimer() val wall=Runtime.clock()
        val checksum=body()
        val elapsed=Time.toReal(Time.-(Runtime.clock(),wall))
        val {usr,sys}=Timer.checkCPUTimer timer
        val cpu=Time.toReal(Time.+(usr,sys))
        val ()=print(Json.encode(Json.Object[("implementation",Json.String "rune"),("phase",Json.String phase),
          ("iterations",Json.int count),("cpuSeconds",number cpu),("wallSeconds",number elapsed),
          ("checksum",Json.String(IntInf.toString(Word64.toLargeInt checksum)))]) ^ "\n")
    in checksum end
  fun repeat count body=let fun loop 0 value=value | loop n value=loop(n-1)(body value)
    in loop count 0w0 end
  val preparations=Int.max(10,iterations div 100)
  val ()=ignore(measure "load-symbol" preparations (fn()=>
    repeat preparations(fn _=>let val library=RuneForeign.openLibrary libraryPath
      val symbol=RuneForeign.symbol(library,"rfp_scalar")
      val ()=RuneForeign.release symbol val ()=RuneForeign.release library in 0w0 end)))
  val library=RuneForeign.openLibrary libraryPath
  val owned=ref([]:RuneForeign.resource list)
  fun symbol name=let val value=RuneForeign.symbol(library,name) in owned:=value:: !owned;value end
  val scalarSymbol=symbol "rfp_scalar"
  fun prepare symbol result arguments=RuneForeign.prepare{symbol=symbol,abi=0,result=result,arguments=arguments}
  val ()=ignore(measure "prepare" preparations(fn()=>repeat preparations(fn _=>
    let val call=prepare scalarSymbol RuneForeign.UInt64 [RuneForeign.UInt64]
    in RuneForeign.release call;0w0 end)))
  fun call symbol result arguments=let val value=prepare symbol result arguments in owned:=value:: !owned;value end
  val scalar=call scalarSymbol RuneForeign.UInt64 [RuneForeign.UInt64]
  fun word(result:RuneForeign.result)=PackWord64Little.subVec(Byte.stringToBytes(#bytes result),0)
  val result=measure "scalar" iterations(fn()=>repeat iterations(fn value=>word(RuneForeign.invoke(scalar,[RuneForeign.Unsigned value]))))
  val ()=need(result=Word64.fromInt iterations,"scalar checksum")
  val sizeType=if #pointerBytes(RuneForeign.target())=4 then RuneForeign.UInt32 else RuneForeign.UInt64
  val buffer=call(symbol "rfp_buffer") RuneForeign.UInt64 [RuneForeign.Pointer,sizeType]
  val array=Word8Array.array(256,0w0)
  val result=measure "marshal-256" iterations(fn()=>repeat iterations(fn _=>ForeignMemory.withArrays
    [{array=array,offset=0,length=256,direction=ForeignMemory.InputOutput}]
    (fn buffers=>word(RuneForeign.invoke(buffer,[RuneForeign.Address(SOME(ForeignMemory.raw(hd buffers))),RuneForeign.Unsigned 0w256])))))
  val ()=need(result=Word64.fromInt(iterations mod 256) andalso
    Word8Array.all(fn byte=>byte=Word8.fromInt(iterations mod 256))array,"buffer checksum")
  val callback=RuneForeign.callback{abi=0,result=RuneForeign.UInt64,arguments=[RuneForeign.UInt64],
    failure=RuneForeign.Default(RuneForeign.Unsigned 0w0),function=fn [RuneForeign.Unsigned value]=>RuneForeign.Unsigned(Word64.+(value,0w1))
      | _=>raise Fail "callback shape"}
  val callbackCall=call(symbol "rfp_callback") RuneForeign.UInt64 [RuneForeign.Pointer,RuneForeign.UInt64]
  val result=measure "callback" iterations(fn()=>repeat iterations(fn value=>word(RuneForeign.invoke(callbackCall,
    [RuneForeign.Address(SOME callback),RuneForeign.Unsigned value]))))
  val ()=need(result=Word64.fromInt iterations,"callback checksum")
  val ()=RuneForeign.release callback
  val ()=List.app RuneForeign.release(!owned)
  val ()=RuneForeign.release library
  val ()=need(RuneForeign.live()=0w0,"performance resource leak")
end

structure ForeignMemoryTests =
struct
  val checks=ref 0
  fun check(name,condition)=(checks:= !checks+1;if condition then () else raise Fail name)
  fun bounds action=((action();false)handle ForeignMemory.Bounds=>true)
  val library=RuneForeign.openLibrary(hd(CommandLine.arguments()))
  fun withCall name result types body=ForeignScope.withScope(fn scope=>
    let val symbol=RuneForeign.symbol(library,name)
        val ()=ignore(ForeignScope.defer(scope,fn()=>RuneForeign.release symbol))
        val call=RuneForeign.prepare{symbol=symbol,abi=0,result=result,arguments=types}
        val ()=ignore(ForeignScope.defer(scope,fn()=>RuneForeign.release call))
    in body call end)
  fun value(result:RuneForeign.result)=ForeignBytes.value{signed=true,littleEndian=true,bytes= #bytes result}
  fun array()=Word8Array.fromList[0w1,0w2,0w3,0w4]
  fun bytes a=Byte.bytesToString(Word8Array.vector a)
  fun argument a direction offset length={array=a,direction=direction,offset=offset,length=length}
  val baseline=RuneForeign.live()
  val buffer=ForeignMemory.fromBytes "abcd"
  val view=ForeignMemory.slice(buffer,1,2)
  val ()=ForeignMemory.write(view,0,"XY")
  val ()=check("view mutations visible",ForeignMemory.read(buffer,0,4)="aXYd")
  val ()=check("negative allocation",bounds(fn()=>ignore(ForeignMemory.allocate ~1)))
  val ()=check("negative read",bounds(fn()=>ignore(ForeignMemory.read(buffer,~1,1))))
  val ()=check("read extent",bounds(fn()=>ignore(ForeignMemory.read(buffer,3,2))))
  val ()=check("view extent",bounds(fn()=>ignore(ForeignMemory.slice(buffer,2,3))))
  val ()=check("write extent",bounds(fn()=>ForeignMemory.write(buffer,4,"!")))
  val ()=check("live view retains allocation",((ForeignMemory.release buffer;false)handle RuneForeign.Error _=>true))
  val ()=(ForeignMemory.release view;ForeignMemory.release buffer)
  val ()=check("closed read rejected",((ignore(ForeignMemory.read(buffer,0,1));false)handle RuneForeign.Error _=>true))
  val ()=ForeignMemory.withBytes "a\000garbage"(fn buffer=>check("terminated bytes",ForeignMemory.terminated{buffer=buffer,unitBytes=1}="a\000"))
  val ()=ForeignMemory.withBytes "a\000\000\000z\000"(fn buffer=>check("terminated code units",ForeignMemory.terminated{buffer=buffer,unitBytes=2}="a\000\000\000"))
  val ()=ForeignMemory.withBytes "abc"(fn buffer=>check("terminator bounded",bounds(fn()=>ignore(ForeignMemory.terminated{buffer=buffer,unitBytes=1}))))
  val ()=ForeignMemory.withBytes "a"(fn buffer=>check("incomplete code unit bounded",bounds(fn()=>ignore(ForeignMemory.terminated{buffer=buffer,unitBytes=2}))))
  val ()=withCall "rf_alias" RuneForeign.SInt32 [RuneForeign.Pointer,RuneForeign.Pointer](fn call=>
    let val a=array()
        val result=ForeignMemory.withArrays [argument a ForeignMemory.InputOutput 0 4,argument a ForeignMemory.InputOutput 1 3]
          (fn buffers=>case buffers of [first,second]=>value(RuneForeign.invoke(call,
            [RuneForeign.Address(SOME(ForeignMemory.raw first)),RuneForeign.Address(SOME(ForeignMemory.raw second))])) | _=>raise Fail "views")
    in check("overlapping native pointers alias",result=18 andalso bytes a="\017\018\003\004") end)
  val ()=withCall "rf_alias" RuneForeign.SInt32 [RuneForeign.Pointer,RuneForeign.Pointer](fn call=>
    let val a=array() val b=array()
        val result=ForeignMemory.withArrays [argument a ForeignMemory.InputOutput 0 4,argument b ForeignMemory.InputOutput 0 4]
          (fn buffers=>case buffers of [first,second]=>value(RuneForeign.invoke(call,
            [RuneForeign.Address(SOME(ForeignMemory.raw first)),RuneForeign.Address(SOME(ForeignMemory.raw second))])) | _=>raise Fail "views")
    in check("distinct arrays retain independence",result=2 andalso bytes a="\017\002\003\004" andalso bytes b="\018\002\003\004") end)
  val a=array()
  val ()=ForeignMemory.withArrays[argument a ForeignMemory.Output 1 2](fn buffers=>
    (check("output storage initially zero",ForeignMemory.read(hd buffers,0,2)="\000\000");ForeignMemory.write(hd buffers,0,"XY")))
  val ()=check("output copies only selected range",bytes a="\001XY\004")
  val a=array()
  val caught=((ForeignMemory.withArrays[argument a ForeignMemory.InputOutput 0 4](fn buffers=>
      (ForeignMemory.write(hd buffers,0,"WXYZ");raise Fail "body"));false)handle Fail message=>message="body")
  val ()=check("output copy-back on exception",caught andalso bytes a="WXYZ")
  val a=array()
  val ()=ForeignMemory.withArrays[argument a ForeignMemory.Input 0 4](fn buffers=>ForeignMemory.write(hd buffers,0,"WXYZ"))
  val ()=check("input-only has snapshot semantics",bytes a="\001\002\003\004")
  val a=array()
  val ()=ForeignMemory.withArrays[argument a ForeignMemory.InputOutput 0 4](fn buffers=>
    (Word8Array.update(a,0,0w99);ForeignMemory.write(hd buffers,0,"WXYZ")))
  val ()=check("native output supersedes SML mutation",bytes a="WXYZ")
  val ()=check("argument extent checked before allocation",bounds(fn()=>ForeignMemory.withArrays[argument a ForeignMemory.Input 3 2](fn _=>())))
  val ()=ForeignMemory.withArrays[argument a ForeignMemory.Input 4 0](fn buffers=>check("one-past empty view",ForeignMemory.length(hd buffers)=0))
  val ()=check("temporary native resources cleaned",RuneForeign.live()=baseline)
  val ()=RuneForeign.release library
  val ()=check("all native resources released",RuneForeign.live()=0w0)
  val ()=print("PASS native memory marshalling: " ^ Int.toString(!checks) ^ " checks\n")
end

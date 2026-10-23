val () = if not(RuneForeign.available()) then () else
  let val windows=List.exists(fn(name,value)=>name="sysname" andalso value="Windows")(Posix.ProcEnv.uname())
      val library=RuneForeign.openLibrary(if windows then "msvcrt.dll" else "libc.so.6")
      val symbol=RuneForeign.symbol(library,"sprintf")
      val output=RuneForeign.allocate 0w64
      val format=RuneForeign.allocate 0w9
      val ()=RuneForeign.write(format,0w0,"%d:%.2f\000")
      val call=RuneForeign.prepareVariadic{symbol=symbol,abi=0,result=RuneForeign.SInt32,
        arguments=[RuneForeign.Pointer,RuneForeign.Pointer,RuneForeign.SInt32,RuneForeign.Float64],fixedCount=2}
      fun rejected body=(body();false)handle RuneForeign.Error _=>true
      val result=RuneForeign.invoke(call,[RuneForeign.Address(SOME output),RuneForeign.Address(SOME format),
        RuneForeign.Signed ~42,RuneForeign.Real 0.25])
      val ()=if RuneForeign.read(output,0w0,9)="-42:0.25\000" andalso
        PackWord64Little.subVec(Byte.stringToBytes(#bytes result),0)=0w8 then () else raise Fail "mixed variadic call"
      val ()=if rejected(fn()=>ignore(RuneForeign.prepareVariadic{symbol=symbol,abi=0,result=RuneForeign.SInt32,
        arguments=[RuneForeign.Pointer,RuneForeign.Float32],fixedCount=1})) then () else raise Fail "unpromoted float accepted"
      val ()=if rejected(fn()=>ignore(RuneForeign.invoke(call,[]))) then () else raise Fail "variadic arity accepted"
      val ()=List.app RuneForeign.release[call,output,format,symbol,library]
      val ()=if RuneForeign.live()=0w0 then () else raise Fail "variadic resource cleanup"
  in () end
val ()=print "promoted variadic signatures retain exact types and clean up\n"

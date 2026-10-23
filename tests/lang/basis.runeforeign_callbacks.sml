val ()=if not(RuneForeign.available()) then () else
  let val windows=List.exists(fn(name,value)=>name="sysname" andalso value="Windows")(Posix.ProcEnv.uname())
      val library=RuneForeign.openLibrary(if windows then "msvcrt.dll" else "libc.so.6")
      val symbol=RuneForeign.symbol(library,"qsort")
      val sizeType=if #pointerBytes(RuneForeign.target())=4 then RuneForeign.UInt32 else RuneForeign.UInt64
      val call=RuneForeign.prepare{symbol=symbol,abi=0,result=RuneForeign.Void,
        arguments=[RuneForeign.Pointer,sizeType,sizeType,RuneForeign.Pointer]}
      val callback=RuneForeign.callback{abi=0,result=RuneForeign.SInt32,
        arguments=[RuneForeign.Pointer,RuneForeign.Pointer],failure=RuneForeign.Default(RuneForeign.Signed 0),
        function=fn [RuneForeign.Address(SOME a),RuneForeign.Address(SOME b)]=>
          RuneForeign.Signed(Int64.fromInt(Char.ord(String.sub(RuneForeign.read(a,0w0,1),0))-
            Char.ord(String.sub(RuneForeign.read(b,0w0,1),0)))) | _=>raise Fail "comparator arguments"}
      val memory=RuneForeign.allocate 0w4
      val ()=RuneForeign.write(memory,0w0,"dbca")
      val _=RuneForeign.invoke(call,[RuneForeign.Address(SOME memory),RuneForeign.Unsigned 0w4,
        RuneForeign.Unsigned 0w1,RuneForeign.Address(SOME callback)])
      val ()=if RuneForeign.read(memory,0w0,4)="abcd" then () else raise Fail "callback sort"
      val ()=List.app RuneForeign.release[memory,callback,call,symbol,library]
  in () end
val ()=print "callbacks return through a bounded VM delimiter\n"

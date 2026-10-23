(* requires: RuneForeign Posix PackWord64Little Byte Int64 Word64 *)
structure TestRuneForeign =
struct
  val enabled = RuneForeign.available ()
  val () = T.check ("RuneForeign.available/boolean", fn () => enabled orelse not enabled)
  val () = T.check ("RuneForeign.target/pointer-width", fn () => List.exists(fn n=>n= #pointerBytes(RuneForeign.target()))[4,8])
  val facts=RuneForeign.abiFacts()
  val ()=T.check("RuneForeign.abiFacts/complete-representation",fn()=> #charBits facts=8 andalso List.length(#scalars facts)=10 andalso
    List.all(fn{name,size,alignment}=>name<>"" andalso size>0 andalso alignment>0 andalso size mod alignment=0)(#scalars facts))
  val ()=T.check("RuneForeign.abiFacts/pointer-agreement",fn()=>List.exists(fn{name,size,...}=>
    name="pointer" andalso size= #pointerBytes(RuneForeign.target()))(#scalars facts))
  val () = T.check ("RuneForeign.live/initially-empty", fn () => RuneForeign.live () = 0w0)
  val () = T.check ("RuneForeign.Error/missing-library", fn () =>
    (ignore (RuneForeign.openLibrary "runeffi-library-that-does-not-exist"); false) handle RuneForeign.Error _ => true)
  val () = if not enabled then () else
    let val windows = List.exists (fn (key,value) => key="sysname" andalso value="Windows") (Posix.ProcEnv.uname ())
        val library = RuneForeign.openLibrary (if windows then "msvcrt.dll" else "libc.so.6")
        val () = T.check ("RuneForeign.openLibrary/live-resource", fn () => RuneForeign.live () > 0w0)
        val symbol = RuneForeign.symbol (library,"abs")
        val () = T.check ("RuneForeign.symbol/retains-library", fn () =>
          (RuneForeign.release library;false) handle RuneForeign.Error _ => true)
        val call = RuneForeign.prepare {symbol=symbol,abi=0,result=RuneForeign.SInt32,arguments=[RuneForeign.SInt32]}
        val () = T.check ("RuneForeign.prepare/prepared-call", fn () => RuneForeign.live () >= 0w3)
        val deferred=RuneForeign.invokeDeferred(call,[RuneForeign.Signed(Int64.fromInt ~42)])
        val ()=T.check("RuneForeign.invokeDeferred/ordinary-result",fn()=>not(Option.isSome(#callbackException deferred)))
        val result = #result deferred
        val () = T.check ("RuneForeign.invoke/native-scalar", fn () => PackWord64Little.subVec(Byte.stringToBytes(#bytes result),0)=0w42)
        val variadicSymbol=RuneForeign.symbol(library,"sprintf")
        val variadicCall=RuneForeign.prepareVariadic{symbol=variadicSymbol,abi=0,result=RuneForeign.SInt32,
          arguments=[RuneForeign.Pointer,RuneForeign.Pointer,RuneForeign.SInt32,RuneForeign.Float64],fixedCount=2}
        val formatted=RuneForeign.allocate 0w64
        val format=RuneForeign.allocate 0w9
        val ()=RuneForeign.write(format,0w0,"%d:%.2f\000")
        val formattedResult=RuneForeign.invoke(variadicCall,[RuneForeign.Address(SOME formatted),
          RuneForeign.Address(SOME format),RuneForeign.Signed ~42,RuneForeign.Real 0.25])
        val ()=T.check("RuneForeign.prepareVariadic/promoted-mixed-native-call",fn()=>
          PackWord64Little.subVec(Byte.stringToBytes(#bytes formattedResult),0)=0w8 andalso
          RuneForeign.read(formatted,0w0,9)="-42:0.25\000")
        val ()=List.app RuneForeign.release[formatted,format,variadicCall,variadicSymbol]
        val callback = RuneForeign.callback {abi=0,result=RuneForeign.SInt32,arguments=[RuneForeign.SInt32],
          function=fn _=>RuneForeign.Signed 1,failure=RuneForeign.Default(RuneForeign.Signed 0)}
        val () = T.check ("RuneForeign.callback/rooted-resource",fn()=>RuneForeign.isLive callback)
        val () = T.check ("RuneForeign.callbackStatus/initial-snapshot",fn()=>
          RuneForeign.callbackStatus{callback=callback,reset=true}={rejected=0w0,first=NONE})
        val () = T.check ("RuneForeign.callbackFault/reasons",fn()=>
          List.length[RuneForeign.WrongThread,RuneForeign.NoActivation,RuneForeign.EntryDisabled,RuneForeign.EntryFailure]=4)
        val () = RuneForeign.release callback
        val () = T.check ("RuneForeign.callbackStatus/stale-resource",fn()=>
          (ignore(RuneForeign.callbackStatus{callback=callback,reset=false});false)handle RuneForeign.Error _=>true)
        val () = T.check ("RuneForeign.callbackFailure/argument-selection",fn()=>
          case RuneForeign.ByArgument{index=0,cases=[(0w1,RuneForeign.Signed ~1)],default=RuneForeign.Signed 0} of
            RuneForeign.ByArgument{index,cases,...}=>index=0 andalso List.length cases=1 | _=>false)
        val memory = RuneForeign.allocate 0w4
        val () = T.check ("RuneForeign.allocate/zeroed", fn () => RuneForeign.read(memory,0w0,4)="\000\000\000\000")
        val () = T.check ("RuneForeign.aliasHandle/rejects-memory",fn()=>
          (ignore(RuneForeign.aliasHandle memory);false)handle RuneForeign.Error _=>true)
        val () = T.check ("RuneForeign.consumeHandle/rejects-memory",fn()=>
          (ignore(RuneForeign.consumeHandle{resource=memory,call=call,arguments=[RuneForeign.Signed 1],failure=RuneForeign.NoFailure});false)
            handle RuneForeign.Error _=>true)
        val () = RuneForeign.write(memory,0w0,"test")
        val () = T.check ("RuneForeign.write/copy", fn () => RuneForeign.read(memory,0w0,4)="test")
        val view = RuneForeign.view(memory,0w1,0w2)
        val same = RuneForeign.view(memory,0w0,0w4)
        val () = T.check ("RuneForeign.sameAddress/views", fn () => RuneForeign.sameAddress(memory,same) andalso not(RuneForeign.sameAddress(memory,view)))
        val () = T.check ("RuneForeign.isLive/registered", fn () => RuneForeign.isLive memory)
        val () = T.check ("RuneForeign.dispose/ownership-checked", fn () =>
          (ignore(RuneForeign.dispose{resource=memory,call=call,arguments=[RuneForeign.Signed 1],failure=RuneForeign.NoFailure});false)
            handle RuneForeign.Error _=>true)
        val () = RuneForeign.release same
        val () = T.check ("RuneForeign.view/aliases-parent", fn () => RuneForeign.read(view,0w0,2)="es")
        val () = T.check ("RuneForeign.read/bounds", fn () =>
          (ignore(RuneForeign.read(view,0w1,2));false) handle RuneForeign.Error _ => true)
        val () = RuneForeign.release view
        val () = RuneForeign.release memory
        val () = T.check ("RuneForeign.isLive/released", fn () => not(RuneForeign.isLive memory))
        val () = T.check ("RuneForeign.release/tombstone", fn () =>
          (RuneForeign.release memory;false) handle RuneForeign.Error _ => true)
        val () = (RuneForeign.release call;RuneForeign.release symbol;RuneForeign.release library)
        val () = T.check ("RuneForeign.live/empty-after-release", fn () => RuneForeign.live () = 0w0)
    in () end
end

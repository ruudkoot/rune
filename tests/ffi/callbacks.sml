val callbackLibrary = RuneForeign.openLibrary(hd(CommandLine.arguments()))
val callbackOwned : RuneForeign.resource list ref = ref []
fun callbackCall name result arguments =
  let val symbol=RuneForeign.symbol(callbackLibrary,name)
      val call=RuneForeign.prepare{symbol=symbol,abi=0,result=result,arguments=arguments}
  in callbackOwned:=call::symbol:: !callbackOwned;call end
fun callbackCheck(name,condition)=if condition then () else raise Fail name
fun callbackWord(result:RuneForeign.result)=PackWord64Little.subVec(Byte.stringToBytes(#bytes result),0)
fun callbackSigned result=Word64.toLargeIntX(callbackWord result)
fun callbackRejected f=(f();false) handle RuneForeign.Error _=>true
val applyCallback=callbackCall "rf_cb_apply" RuneForeign.SInt32 [RuneForeign.Pointer,RuneForeign.Pointer,RuneForeign.SInt32]
val threadCallback=callbackCall "rf_cb_thread" RuneForeign.SInt32 [RuneForeign.Pointer,RuneForeign.Pointer,RuneForeign.SInt32]
val nestedDepth=ref 0
val capturedCallback=ref(NONE:RuneForeign.resource option)
val borrowedCallback=ref(NONE:RuneForeign.resource option)
val borrowedView=ref(NONE:RuneForeign.resource option)
val marker=RuneForeign.allocate 0w4
val ()=RuneForeign.write(marker,0w0,"root")
val callbackSelf=ref(NONE:RuneForeign.resource option)
fun callbackArguments cb context n=[RuneForeign.Address(SOME cb),RuneForeign.Address context,RuneForeign.Signed(Int64.fromInt n)]
fun growCallback 0=let val ()=Runtime.collect() in ["retained"] end
  | growCallback n=Int.toString n::growCallback(n-1)
val callback=RuneForeign.callback{abi=0,result=RuneForeign.SInt32,arguments=[RuneForeign.Pointer,RuneForeign.SInt32],
  failure=RuneForeign.Default(RuneForeign.Signed ~99),function=fn values=>case values of
    [RuneForeign.Address context,RuneForeign.Signed n]=>
      let val i=Int64.toInt n
          val ()=callbackCheck("callback root survives",RuneForeign.read(marker,0w0,4)="root")
          val ()=borrowedCallback:=context
          val ()=case context of NONE=>() | SOME p=>borrowedView:=SOME(RuneForeign.view(p,0w0,0w4))
          val ()=callbackCheck("cannot release active callback",callbackRejected(fn()=>RuneForeign.release(valOf(!callbackSelf))))
          val ()=List.app(fn _=>let val r=RuneForeign.allocate 0w1 in RuneForeign.release r end)(List.tabulate(40,fn i=>i))
          val ()=if i=7 then callbackCheck("moving callback stack",List.length(growCallback 6000)=6001) else ()
          val result=if i>0 andalso i<4 then
              (nestedDepth:= !nestedDepth+1;
               IntInf.toInt(callbackSigned(RuneForeign.invoke(applyCallback,callbackArguments(valOf(!callbackSelf))context(i-1))))+1)
            else i+10
      in RuneForeign.Signed(Int64.fromInt result) end
  | _=>raise Fail "callback argument shape"}
val ()=callbackSelf:=SOME callback
val ()=callbackCheck("scalar callback",callbackSigned(RuneForeign.invoke(applyCallback,callbackArguments callback(SOME marker)7))=17)
val borrowed=valOf(!borrowedCallback)
val ()=callbackCheck("borrowed pointer expires",not(RuneForeign.isLive borrowed))
val ()=callbackCheck("borrowed view expires",not(RuneForeign.isLive(valOf(!borrowedView))))
val ()=callbackCheck("nested foreign callbacks",callbackSigned(RuneForeign.invoke(applyCallback,callbackArguments callback NONE 3))=13 andalso !nestedDepth=3)
val ()=callbackCheck("foreign thread rejected",callbackSigned(RuneForeign.invoke(threadCallback,callbackArguments callback NONE 5))= ~99)
exception CallbackFailure
val failingCallback=RuneForeign.callback{abi=0,result=RuneForeign.SInt32,arguments=[RuneForeign.Pointer,RuneForeign.SInt32],
  failure=RuneForeign.ByArgument{index=1,cases=[(0w129,RuneForeign.Signed 0),(0w1,RuneForeign.Signed ~1)],default=RuneForeign.Signed ~77},
  function=fn _=>raise CallbackFailure}
val ()=callbackCheck("exception after native return",(ignore(RuneForeign.invoke(applyCallback,callbackArguments failingCallback NONE 1));false)handle CallbackFailure=>true)
val ()=callbackCheck("foreign thread selected failure zero",callbackSigned(RuneForeign.invoke(threadCallback,callbackArguments failingCallback NONE 129))=0)
val ()=callbackCheck("foreign thread selected failure minus one",callbackSigned(RuneForeign.invoke(threadCallback,callbackArguments failingCallback NONE 1))= ~1)
val ()=callbackCheck("saved exception cleared",callbackSigned(RuneForeign.invoke(applyCallback,callbackArguments callback NONE 6))=16)
val depthEntries=ref 0
val depthSelf=ref(NONE:RuneForeign.resource option)
val depthCallback=RuneForeign.callback{abi=0,result=RuneForeign.SInt32,arguments=[RuneForeign.Pointer,RuneForeign.SInt32],
  failure=RuneForeign.Default(RuneForeign.Signed ~999),function=fn [_,RuneForeign.Signed n]=>
    (depthEntries:= !depthEntries+1;
     RuneForeign.Signed(Int64.fromLarge(callbackSigned(RuneForeign.invoke(applyCallback,
       callbackArguments(valOf(!depthSelf))NONE(Int64.toInt n-1)))))) | _=>raise Fail "depth argument"}
val ()=depthSelf:=SOME depthCallback
val ()=callbackCheck("bounded callback nesting",callbackSigned(RuneForeign.invoke(applyCallback,callbackArguments depthCallback NONE 200))= ~999 andalso !depthEntries=64)
val realCall=callbackCall "rf_cb_real" RuneForeign.Float64 [RuneForeign.Pointer,RuneForeign.Float64]
val realCallback=RuneForeign.callback{abi=0,result=RuneForeign.Float64,arguments=[RuneForeign.Float64],
  failure=RuneForeign.Default(RuneForeign.Real 0.0),function=fn [RuneForeign.Real n]=>RuneForeign.Real(n+0.25) | _=>raise Fail "real argument"}
val ()=callbackCheck("real callback",Real.==(PackReal64Little.fromBytes(Byte.stringToBytes(#bytes(RuneForeign.invoke(realCall,[RuneForeign.Address(SOME realCallback),RuneForeign.Real 0.5])))),0.75))
val narrowCall=callbackCall "rf_cb_narrow" RuneForeign.SInt8 [RuneForeign.Pointer,RuneForeign.SInt8]
val narrowCallback=RuneForeign.callback{abi=0,result=RuneForeign.SInt8,arguments=[RuneForeign.SInt8],
  failure=RuneForeign.Default(RuneForeign.Signed 0),function=fn [RuneForeign.Signed n]=>RuneForeign.Signed(Int64.+(n,1)) | _=>raise Fail "narrow argument"}
val ()=callbackCheck("narrow signed callback",callbackSigned(RuneForeign.invoke(narrowCall,[RuneForeign.Address(SOME narrowCallback),RuneForeign.Signed ~128]))= ~127)
val callbackTarget=RuneForeign.target()
val callbackIntPtr=if #pointerBytes callbackTarget=4 then RuneForeign.SInt32 else RuneForeign.SInt64
val callbackUIntPtr=if #pointerBytes callbackTarget=4 then RuneForeign.UInt32 else RuneForeign.UInt64
val messageCall=callbackCall "rf_cb_message" callbackIntPtr [RuneForeign.Pointer,RuneForeign.Pointer,RuneForeign.UInt32]
val messageCallback=RuneForeign.callback{abi=if #stdcall callbackTarget then 1 else 0,result=callbackIntPtr,
  arguments=[RuneForeign.Pointer,RuneForeign.UInt32,callbackUIntPtr,callbackIntPtr],failure=RuneForeign.Default(RuneForeign.Signed 0),
  function=fn [_,RuneForeign.Unsigned message,_,_]=>RuneForeign.Signed(Int64.fromLarge(Word64.toLargeInt message)) | _=>raise Fail "message callback"}
val ()=callbackCheck("stdcall message callback",callbackSigned(RuneForeign.invoke(messageCall,[RuneForeign.Address(SOME messageCallback),RuneForeign.Address NONE,RuneForeign.Unsigned 0w129]))=129)
val createHandle=callbackCall "rf_cb_create" RuneForeign.Pointer [RuneForeign.Pointer]
val destroyHandle=callbackCall "rf_cb_destroy" RuneForeign.Void [RuneForeign.Pointer]
val adopted=ref(NONE:RuneForeign.resource option)
val createCallback=RuneForeign.callback{abi=0,result=RuneForeign.SInt32,arguments=[RuneForeign.Pointer,RuneForeign.SInt32],
  failure=RuneForeign.Default(RuneForeign.Signed 0),function=fn [RuneForeign.Address(SOME pointer),_]=>
    (adopted:=SOME(RuneForeign.aliasHandle pointer);RuneForeign.Signed 1) | _=>RuneForeign.Signed 0}
val created=valOf(#pointer(RuneForeign.invoke(createHandle,[RuneForeign.Address(SOME createCallback)])))
val opaque=valOf(!adopted)
val alias=RuneForeign.aliasHandle created
val ()=callbackCheck("creation-time stable identity",opaque=alias andalso RuneForeign.sameAddress(opaque,created))
val ()=callbackCheck("opaque memory access rejected",callbackRejected(fn()=>ignore(RuneForeign.read(opaque,0w0,1))))
val notifiedDestroy=callbackCall "rf_cb_destroy_notify" RuneForeign.Void [RuneForeign.Pointer,RuneForeign.Pointer]
val handleUse=callbackCall "rf_cb_handle_use" RuneForeign.SInt32 [RuneForeign.Pointer]
val destroyNotification=RuneForeign.callback{abi=0,result=RuneForeign.SInt32,arguments=[RuneForeign.Pointer,RuneForeign.SInt32],
  failure=RuneForeign.Default(RuneForeign.Signed ~1),function=fn _=>
    (callbackCheck("nested use during destruction",callbackSigned(RuneForeign.invoke(handleUse,[RuneForeign.Address(SOME opaque)]))=1);
     callbackCheck("recursive destruction rejected",callbackRejected(fn()=>ignore(RuneForeign.consumeHandle{resource=opaque,call=destroyHandle,
       arguments=[RuneForeign.Address(SOME opaque)],failure=RuneForeign.NoFailure})));RuneForeign.Signed 1)}
val destroying=RuneForeign.callback{abi=0,result=RuneForeign.SInt32,arguments=[RuneForeign.Pointer,RuneForeign.SInt32],
  failure=RuneForeign.Default(RuneForeign.Signed ~1),function=fn _=>
    let val result=RuneForeign.consumeHandle{resource=opaque,call=notifiedDestroy,arguments=[RuneForeign.Address(SOME opaque),RuneForeign.Address(SOME destroyNotification)],failure=RuneForeign.NoFailure}
    in callbackCheck("destruction while native caller is suspended",#disposed result);RuneForeign.Signed 42 end}
val ()=callbackCheck("nested opaque destruction",callbackSigned(RuneForeign.invoke(applyCallback,callbackArguments destroying(SOME opaque)2))=42)
val ()=callbackCheck("all aliases retired",not(RuneForeign.isLive opaque) andalso not(RuneForeign.isLive alias) andalso not(RuneForeign.isLive created))
val ()=List.app RuneForeign.release [callback,failingCallback,depthCallback,realCallback,narrowCallback,messageCallback,createCallback,destroyNotification,destroying,marker]
val ()=List.app RuneForeign.release(!callbackOwned)
val ()=RuneForeign.release callbackLibrary
val ()=callbackCheck("all callback resources released",RuneForeign.live()=0w0)
val ()=print "PASS foreign callbacks: reentry, collection, stack growth, failures, threads, opaque destruction\n"

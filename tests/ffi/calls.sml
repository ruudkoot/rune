val libraryPath = hd (CommandLine.arguments ())
fun check (label, condition) = if condition then () else raise Fail label
val () = check ("available", RuneForeign.available ())
val target = RuneForeign.target()
val sizeType = if #pointerBytes target=4 then RuneForeign.UInt32 else RuneForeign.UInt64
val library = RuneForeign.openLibrary libraryPath
fun rejected action = (action (); false) handle RuneForeign.Error _ => true
val () = check("missing library",rejected(fn()=>ignore(RuneForeign.openLibrary(libraryPath ^ ".missing"))))
val () = check("missing symbol",rejected(fn()=>ignore(RuneForeign.symbol(library,"rf_missing"))))
val () = check("embedded NUL",rejected(fn()=>ignore(RuneForeign.symbol(library,"rf_i8\000missing"))))
fun withCall name result types action =
  let val symbol = RuneForeign.symbol(library,name)
      val call = RuneForeign.prepare{symbol=symbol,abi=0,result=result,arguments=types}
      fun cleanup()=(RuneForeign.release call;RuneForeign.release symbol)
      val answer = action call handle e => (cleanup();raise e)
  in cleanup();answer end
fun word result = PackWord64Little.subVec(Byte.stringToBytes(#bytes (result:RuneForeign.result)),0)
fun withVariadic name result fixedCount types action =
  let val symbol = RuneForeign.symbol(library,name)
      val call = RuneForeign.prepareVariadic{symbol=symbol,abi=0,result=result,arguments=types,fixedCount=fixedCount}
      fun cleanup()=(RuneForeign.release call;RuneForeign.release symbol)
      val answer=action call handle e=>(cleanup();raise e)
  in cleanup();answer end
val () = List.app (fn values =>
  withVariadic "rf_variadic" RuneForeign.SInt32 1
    (RuneForeign.UInt32 :: List.map (fn _ => RuneForeign.SInt32) values) (fn call =>
      let val arguments=RuneForeign.Unsigned(Word64.fromInt(List.length values)) ::
            List.map (RuneForeign.Signed o Int64.fromInt) values
          fun invoke ()=Word64.toLargeIntX(word(RuneForeign.invoke(call,arguments)))
          val expected=IntInf.fromInt(List.foldl op+ 0 values)
      in check("variadic integer register/stack arguments",invoke()=expected);
         check("variadic prepared signature reused",invoke()=expected);
         check("variadic argument count checked",rejected(fn()=>ignore(RuneForeign.invoke(call,[])))) end))
  [[],[3,14,25],[1,2,3,4,5,6,7,8,9,10,11,12]]
val () = withVariadic "rf_variadic_real" RuneForeign.Float64 1
  (RuneForeign.UInt32 :: List.tabulate(12,fn _=>RuneForeign.Float64)) (fn call =>
    let val result=RuneForeign.invoke(call,RuneForeign.Unsigned 0w12 ::
          List.tabulate(12,fn _=>RuneForeign.Real 0.25))
    in check("variadic promoted real register/stack arguments",
      Real.==(PackReal64Little.fromBytes(Byte.stringToBytes(#bytes result)),3.0)) end)
val () =
  let val symbol=RuneForeign.symbol(library,"rf_variadic")
      val initial=RuneForeign.live()
      fun prepare abi fixedCount tail=ignore(RuneForeign.prepareVariadic{symbol=symbol,abi=abi,
        result=RuneForeign.SInt32,arguments=RuneForeign.UInt32 :: tail,fixedCount=fixedCount})
      val ()=List.app(fn ty=>check("unpromoted variadic tail rejected",rejected(fn()=>prepare 0 1 [ty])))
        [RuneForeign.SInt8,RuneForeign.UInt8,RuneForeign.SInt16,RuneForeign.UInt16,RuneForeign.Float32,RuneForeign.Void]
      val ()=List.app(fn n=>check("invalid variadic fixed count",rejected(fn()=>prepare 0 n []))) [~1,0,2]
      val ()=check("variadic nondefault ABI rejected",rejected(fn()=>prepare 1 1 []))
      val ()=check("rejected variadic interfaces leave no resources",RuneForeign.live()=initial)
  in RuneForeign.release symbol end
val () =
  let val memory=RuneForeign.allocate 0w4
      val ()=RuneForeign.write(memory,0w0,if #littleEndian target then "\037\000\000\000" else "\000\000\000\037")
      val visits=ref 0
      val callback=RuneForeign.callback{abi=0,result=RuneForeign.SInt32,
        arguments=[RuneForeign.Pointer,RuneForeign.SInt32],failure=RuneForeign.Default(RuneForeign.Signed ~999),
        function=fn [RuneForeign.Address(SOME context),RuneForeign.Signed n]=>
          (check("variadic callback context identity",RuneForeign.sameAddress(context,memory));
           check("variadic callback payload",n=1);visits:= !visits+1;Runtime.collect();RuneForeign.Signed 42)
          | _=>raise Fail "variadic callback arguments"}
      val types=[RuneForeign.SInt32,RuneForeign.Float64,RuneForeign.SInt64,RuneForeign.UInt64,
        RuneForeign.Pointer,RuneForeign.Pointer,RuneForeign.Pointer]
      val values=[RuneForeign.Signed 1,RuneForeign.Real 0.25,RuneForeign.Signed ~81985529216486895,
        RuneForeign.Unsigned 0wxFEDCBA9876543210,RuneForeign.Address(SOME memory),
        RuneForeign.Address(SOME callback),RuneForeign.Address(SOME memory)]
      val symbol=RuneForeign.symbol(library,"rf_variadic_mixed")
      val call=RuneForeign.prepareVariadic{symbol=symbol,abi=0,result=RuneForeign.Float64,fixedCount=3,
        arguments=[RuneForeign.Float32,RuneForeign.SInt8,RuneForeign.UInt32] @ List.concat(List.tabulate(12,fn _=>types))}
      val ()=check("variadic call retains its symbol",rejected(fn()=>RuneForeign.release symbol))
      val ()=check("variadic call retains its library",rejected(fn()=>RuneForeign.release library))
      val result=RuneForeign.invoke(call,[RuneForeign.Real 0.5,RuneForeign.Signed ~5,RuneForeign.Unsigned 0w12] @
        List.concat(List.tabulate(12,fn _=>values)))
      val ()=check("mixed variadic register/stack tail and unpromoted fixed prefix",
        Real.==(PackReal64Little.fromBytes(Byte.stringToBytes(#bytes result)),958.5) andalso !visits=12)
      val ()=RuneForeign.release call
      val ()=check("stale variadic call rejected",rejected(fn()=>ignore(RuneForeign.invoke(call,[]))))
  in List.app RuneForeign.release[symbol,callback,memory] end
fun signed(name,ty,n) = withCall name ty [ty] (fn call =>
  check(name,Word64.toLargeIntX(word(RuneForeign.invoke(call,[RuneForeign.Signed(Int64.fromLarge n)])))=n))
fun unsigned(name,ty,n) = withCall name ty [ty] (fn call =>
  check(name,word(RuneForeign.invoke(call,[RuneForeign.Unsigned n]))=n))
val () = List.app signed [("rf_i8",RuneForeign.SInt8,~128),("rf_i16",RuneForeign.SInt16,~32768),
  ("rf_i32",RuneForeign.SInt32,~2147483648)]
val () = List.app unsigned [("rf_u8",RuneForeign.UInt8,0w255),("rf_u16",RuneForeign.UInt16,0w65535),
  ("rf_u32",RuneForeign.UInt32,0wxFFFFFFFF),("rf_u64",RuneForeign.UInt64,0wxFFFFFFFFFFFFFFFF)]
val () = List.app(fn(name,ty)=>withCall name ty [ty] (fn call =>
  check(name,Real.==(PackReal64Little.fromBytes(Byte.stringToBytes(#bytes(RuneForeign.invoke(call,[RuneForeign.Real 0.25])))),0.25))))
  [("rf_float",RuneForeign.Float32),("rf_double",RuneForeign.Float64)]
val () = withCall "rf_i8" RuneForeign.SInt8 [RuneForeign.SInt8] (fn call=>
  (check("signed range",rejected(fn()=>ignore(RuneForeign.invoke(call,[RuneForeign.Signed(Int64.fromInt 128)]))));
   check("argument arity",rejected(fn()=>ignore(RuneForeign.invoke(call,[]))));
   check("argument type",rejected(fn()=>ignore(RuneForeign.invoke(call,[RuneForeign.Unsigned 0w1]))))))
val () = withCall "rf_u8" RuneForeign.UInt8 [RuneForeign.UInt8] (fn call=>
  check("unsigned range",rejected(fn()=>ignore(RuneForeign.invoke(call,[RuneForeign.Unsigned 0w256])))))
val symbol = RuneForeign.symbol (library, "rf_i64")
val () = check("void argument rejected",rejected(fn()=>ignore(RuneForeign.prepare{symbol=symbol,abi=0,result=RuneForeign.Void,arguments=[RuneForeign.Void]})))
val () = check("unknown convention rejected",rejected(fn()=>ignore(RuneForeign.prepare{symbol=symbol,abi=255,result=RuneForeign.SInt64,arguments=[]})))
val call = RuneForeign.prepare {symbol=symbol,abi=0,result=RuneForeign.SInt64,arguments=[RuneForeign.SInt64]}
val minimum = valOf Int64.minInt
val result = RuneForeign.invoke (call,[RuneForeign.Signed minimum])
val bits = PackWord64Little.subVec (Byte.stringToBytes (#bytes result),0)
val () = check ("i64 minimum", Word64.toLargeIntX bits = Int64.toLarge minimum)
val windows = List.exists(fn(key,value)=>key="sysname" andalso value="Windows")(Posix.ProcEnv.uname())
val stdcallSymbol = RuneForeign.symbol(library,"rf_stdcall_add")
val stdcall = RuneForeign.prepare {symbol=stdcallSymbol,abi=if #stdcall target then 1 else 0,
  result=RuneForeign.SInt32,arguments=[RuneForeign.SInt32,RuneForeign.SInt32]}
val stdcallResult = RuneForeign.invoke(stdcall,[RuneForeign.Signed(Int64.fromInt 19),RuneForeign.Signed(Int64.fromInt 23)])
val () = check("target calling convention",PackWord64Little.subVec(Byte.stringToBytes(#bytes stdcallResult),0)=0w42)
val () = (RuneForeign.release stdcall;RuneForeign.release stdcallSymbol)
val memory = RuneForeign.allocate 0w6
val () = RuneForeign.write (memory,0w0,"owned\000")
val () = check ("memory", RuneForeign.read(memory,0w0,6)="owned\000")
val view = RuneForeign.view(memory,0w1,0w3)
val () = check ("view", RuneForeign.read(view,0w0,3)="wne")
val offsetSymbol = RuneForeign.symbol (library,"rf_offset")
val offsetCall = RuneForeign.prepare {symbol=offsetSymbol,abi=0,result=RuneForeign.Pointer,arguments=[RuneForeign.Pointer,sizeType]}
val offsetResult = RuneForeign.invoke (offsetCall,[RuneForeign.Address(SOME memory),RuneForeign.Unsigned 0w2])
val pointer = valOf (#pointer offsetResult)
val () = check ("returned pointer range",RuneForeign.read(pointer,0w0,4)="ned\000")
val () = check ("returned pointer is bounded",((ignore(RuneForeign.read(pointer,0w3,2));false) handle RuneForeign.Error _ => true))
val () = RuneForeign.release pointer
val endResult = RuneForeign.invoke(offsetCall,[RuneForeign.Address(SOME memory),RuneForeign.Unsigned 0w6])
val endPointer = valOf(#pointer endResult)
val () = check("one-past empty read",RuneForeign.read(endPointer,0w0,0)="")
val () = check("one-past bounds",rejected(fn()=>ignore(RuneForeign.read(endPointer,0w0,1))))
val () = RuneForeign.release endPointer
val () = RuneForeign.release offsetCall
val () = RuneForeign.release offsetSymbol
val () = withCall "rf_alias" RuneForeign.SInt32 [RuneForeign.Pointer,RuneForeign.Pointer] (fn aliasCall=>
  (check("alias result",word(RuneForeign.invoke(aliasCall,[RuneForeign.Address(SOME memory),RuneForeign.Address(SOME view)]))=0w18);
   check("mutation visibility",RuneForeign.read(memory,0w0,2)="\017\018")))
val () = RuneForeign.write(memory,0w0,"owned\000")
val savedError = withCall "rf_error" RuneForeign.SInt32 [RuneForeign.SInt32] (fn call=>
  let val result=RuneForeign.invoke(call,[RuneForeign.Signed(Int64.fromInt 12345)])
  in check("native status",Word64.toLargeIntX(word result)= ~1);
     check("captured errno",#number(#error result)=12345);
     check("captured Windows error",not windows orelse #native(#error result)=0w12345);
     #error result end)
val () = withCall "rf_copy" RuneForeign.Pointer [RuneForeign.Pointer] (fn copyCall=>
  withCall "rf_free" RuneForeign.Void [RuneForeign.Pointer] (fn freeCall=>
  withCall "rf_allocations" (sizeType) [] (fn countCall=>
  let val copy=valOf(#pointer(RuneForeign.invoke(copyCall,[RuneForeign.Address(SOME memory)])))
      val ()=check("owned native bytes",RuneForeign.read(copy,0w0,6)="owned\000")
      val ()=check("native allocation count",word(RuneForeign.invoke(countCall,[]))=0w1)
      val alias=RuneForeign.view(copy,0w0,0w6)
      val ()=check("native address identity",RuneForeign.sameAddress(copy,alias) andalso not(RuneForeign.sameAddress(copy,memory)))
      val ()=check("owned resource live",RuneForeign.isLive copy)
      fun dispose failure=RuneForeign.dispose{resource=copy,call=freeCall,arguments=[RuneForeign.Address(SOME copy)],failure=failure}
      val ()=check("destructor waits for views",rejected(fn()=>ignore(dispose RuneForeign.NoFailure)))
      val ()=check("busy destructor did not run",word(RuneForeign.invoke(countCall,[]))=0w1)
      val ()=RuneForeign.release alias
      val ()=check("invalid failure predicate rejected before entry",rejected(fn()=>ignore(dispose RuneForeign.Zero)))
      val ()=withCall "rf_i32" RuneForeign.SInt32 [RuneForeign.SInt32](fn failing=>
        List.app(fn(predicate,n)=>let val outcome=RuneForeign.dispose{resource=copy,call=failing,
            arguments=[RuneForeign.Signed(Int64.fromInt n)],failure=predicate}
          in check("native destructor failure retains ownership",not(#disposed outcome) andalso RuneForeign.isLive copy andalso
              Word64.toLargeIntX(word(#result outcome))=IntInf.fromInt n) end)
          [(RuneForeign.Zero,0),(RuneForeign.Nonzero,1),(RuneForeign.Negative,~1)])
      val outcome=dispose RuneForeign.NoFailure
      val cleanup= #result outcome
      val ()=check("native destructor commits identity",#disposed outcome andalso not(RuneForeign.isLive copy))
      val ()=check("native destructor cannot run twice",rejected(fn()=>ignore(dispose RuneForeign.NoFailure)))
      val ()=check("cleanup clobbers error",#number(#error cleanup)<> #number savedError)
      val ()=check("captured error survives cleanup",#number savedError=12345)
      val ()=check("native allocation released",word(RuneForeign.invoke(countCall,[]))=0w0)
  in withCall "rf_fail_allocation" RuneForeign.Void [RuneForeign.SInt32] (fn failCall=>
       (ignore(RuneForeign.invoke(failCall,[RuneForeign.Signed(Int64.fromInt 1)]));
        check("native allocation failure",not(Option.isSome(#pointer(RuneForeign.invoke(copyCall,[RuneForeign.Address(SOME memory)])))));
        ignore(RuneForeign.invoke(failCall,[RuneForeign.Signed(Int64.fromInt 0)]))))
  end)))
val () = check ("parent retained", ((RuneForeign.release memory;false) handle RuneForeign.Error _ => true))
val () = RuneForeign.release view
val () = RuneForeign.release memory
val () = check ("stale resource", ((ignore(RuneForeign.read(memory,0w0,1));false) handle RuneForeign.Error _ => true))
val () = check ("library retained", ((RuneForeign.release library;false) handle RuneForeign.Error _ => true))
val () = RuneForeign.release call
val () = RuneForeign.release symbol
val () = RuneForeign.release library
val () = check ("empty registry", RuneForeign.live()=0w0)
val () = print "PASS foreign calls: scalars, conventions, bounds, aliasing, errors, ownership, failures, lifetimes\n"

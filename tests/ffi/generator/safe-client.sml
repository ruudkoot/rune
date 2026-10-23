structure GeneratedSafeClient =
struct
  exception CallbackStop
  fun check (name,ok)=if ok then print("PASS generated safe " ^ name ^ "\n") else raise Fail name
  fun run path=
    let val session=GeneratedSafe.openSession{libraries=[path]}
        val ()=check("optional UTF-8 input",GeneratedSafe.length session(SOME "A\195\169")=3 andalso GeneratedSafe.length session NONE=0)
        val ()=check("owned UTF-8 output cleanup",GeneratedSafe.copy session "copied\195\169"="copied\195\169" andalso GeneratedSafe.allocations session()=0)
        val ()=check("failed output conversion still releases owned text",((ignore(GeneratedSafe.badUtf8 session());false)handle ForeignText.Error _=>GeneratedSafe.allocations session()=0))
        val ()=check("nullable borrowed output",GeneratedSafe.optional session true=NONE andalso GeneratedSafe.optional session false=SOME "borrowed")
        val text="A\240\159\152\128"
        val ()=check("UTF-16 extents count code units",GeneratedSafe.utf16 session()=text andalso GeneratedSafe.utf16Input session text=65)
        val ()=check("input text extent prevents native overread",((ignore(GeneratedSafe.utf16Input session "ABCDE");false)handle ForeignMemory.Bounds=>true))
        val {integer,bits,fraction}=GeneratedSafe.numbers session()
        val ()=check("returned scalar outputs",integer= ~17 andalso bits=0wxF0000000 andalso Real.abs(fraction-1.25)<0.00001)
        val ()=check("inout scalar copy",#value(GeneratedSafe.accumulate session 12)=21)
        val array=Word8Array.fromList[0w0,0w22]
        val {result,first,second}=GeneratedSafe.alias session(array,array)
        val ()=check("aliased array copy-back",result=22 andalso Word8Array.sub(array,0)=0w18 andalso first=second)
        val {buffer}=GeneratedSafe.fill session 3
        val ()=check("returned byte output",Word8Array.length buffer=3 andalso Word8Array.sub(buffer,2)=0w3)
        val {buffer=integers}=GeneratedSafe.fillInts session()
        val ()=check("buffer extents count native elements",Word8Array.length integers=12 andalso GeneratedSafe.sumInts session integers=6)
        val ()=check("derived count rejects incomplete native elements",((ignore(GeneratedSafe.sumInts session(Word8Array.array(3,0w0)));false)handle ForeignMemory.Bounds=>true))
        val handleValue=GeneratedSafe.allocate session 4
        val ()=check("owned resource count",GeneratedSafe.allocations session()=1)
        val borrowed=GeneratedSafe.borrow session handleValue
        val ()=check("borrowed result retains its annotated parent",((GeneratedSafe.free session(SOME handleValue);false)handle ForeignOwner.Busy=>true))
        val ()=GeneratedSafe.release_memory borrowed
        val ()=check("negative unsigned input rejected",((ignore(GeneratedSafe.allocate session ~1);false)handle ForeignBytes.Error _=>true))
        val ()=check("live owned resource blocks session close",((GeneratedSafe.closeSession session;false)handle ForeignOwner.Busy=>true))
        val ()=check("explicit raw handle mapping",RuneForeign.read(GeneratedSafe.raw_memory handleValue,0w0,4)="\000\000\000\000")
        val ()=GeneratedSafe.free session(SOME handleValue)
        val ()=check("consumed resource shares closed state",((ignore(GeneratedSafe.raw_memory handleValue);false)handle ForeignOwner.Closed=>true))
        val ()=check("native error capture",((GeneratedSafe.fail session 13;false)handle GeneratedSafe.ForeignFailure{result,text,...}=>
          #number(#error result)=13 andalso text=SOME "fixture error" andalso ForeignBytes.value{signed=true,littleEndian=true,bytes= #bytes result}= ~1))
        val ()=check("floating native failure compares the numeric result",((GeneratedSafe.floatFail session();false)handle GeneratedSafe.ForeignFailure{result,...}=>
          #number(#error result)=13 andalso Real.abs(ForeignBytes.real64Value{littleEndian=true,bytes= #bytes result}+1.25)<0.00001))
        val ()=check("native bool callback arguments and results",not(GeneratedSafe.callBool session not))
        val ()=check("same-thread callback with nested native call",GeneratedSafe.callbackOwned session(fn value=>
          Int32.fromInt(GeneratedSafe.length session(SOME "nested"))+value)="callback")
        val ()=check("callback cannot partially close its active session",GeneratedSafe.callbackOwned session(fn value=>
          if ((GeneratedSafe.closeSession session;false)handle ForeignOwner.Busy=>true) then value else raise Fail "active close")="callback")
        val ()=check("owned result cleaned before callback exception propagation",((ignore(GeneratedSafe.callbackOwned session(fn _=>raise CallbackStop));false)
          handle CallbackStop=>GeneratedSafe.allocations session()=0))
        val callbackBuffer=Word8Array.array(2,0w0)
        val ()=check("callback exception copies native output on returning path",((ignore(GeneratedSafe.callbackBuffer session(fn _=>raise CallbackStop,callbackBuffer));false)
          handle CallbackStop=>Word8Array.sub(callbackBuffer,0)=0w91 andalso Word8Array.sub(callbackBuffer,1)=0w92))
        val ()=check("missing deallocator rejects before native ownership transfer",((ignore(GeneratedSafe.preflight session());false)handle RuneForeign.Error _=>
          GeneratedSafe.preflightCalls session()=0 andalso GeneratedSafe.allocations session()=0))
        val packet={origin={x=3,y=1.25},codes=Vector.fromList[0w1,0w2,0w3]:Word32.word vector,scale=2.5}
        val transformed=GeneratedSafe.transform session(packet,4)
        val ()=check("by-value nested struct and fixed vector roundtrip",#x(#origin transformed)=7 andalso
          Real.abs(#y(#origin transformed)-1.75)<0.00001 andalso Vector.sub(#codes transformed,1)=0w6 andalso Real.==(#scale transformed,5.0))
        val {value=outputPacket}=GeneratedSafe.packetOut session()
        val ()=check("returned struct output",#x(#origin outputPacket)=8 andalso Vector.sub(#codes outputPacket,2)=0w9)
        val {value=inoutPacket}=GeneratedSafe.packetInout session packet
        val ()=check("struct inout roundtrip",#x(#origin inoutPacket)=6 andalso Real.abs(#y(#origin inoutPacket)-1.75)<0.00001)
        val ()=check("fixed native array member length checked",((ignore(GeneratedSafe.transform session({origin={x=0,y=0.0},codes=Vector.fromList[0w1],scale=0.0},1));false)handle ForeignMemory.Bounds=>true))
        val ()=check("original inline definition called through typed shim",GeneratedSafe.inline session 7=21)
        val ()=check("nonstandard native convention called through typed shim",GeneratedSafe.otherAbi session 7=26)
        val ()=check("selected macro keeps explicit fixed native types",GeneratedSafe.macroAdd session(0wxF0000000,0w17)=0wxF0000011)
        val macroPacket=GeneratedSafe.macroPacket session packet
        val ()=check("selected aggregate macro uses typed indirect shim",#x(#origin macroPacket)=5 andalso Vector.sub(#codes macroPacket,1)=0w4)
        val ()=check("fixed variadic shim applies integer promotions",GeneratedSafe.variadicSum session(2,~7,0w250)=243)
        val ()=check("fixed variadic shim applies floating promotions",Real.abs(GeneratedSafe.variadicReal session(2,1.25,2.5)-3.75)<0.00001)
        val context=GeneratedSafe.allocate session 4
        val ()=RuneForeign.write(GeneratedSafe.raw_memory context,0w0,"\037\000\000\000")
        val destroyed=ref 0
        fun registered(value,pointer)=if value=7 then raise CallbackStop else
          let val ()=if value=91 then destroyed:= !destroyed+1 else ()
              val byte=case pointer of SOME pointer=>Char.ord(String.sub(RuneForeign.read(pointer,0w0,1),0)) | NONE=>0
          in value+Int32.fromInt byte end
        val subscription=GeneratedSafe.register session(registered,context)
        val ()=check("registered callback retains native context",((GeneratedSafe.release_memory context;false)handle ForeignOwner.Busy=>true))
        val ()=check("registered callback remains rooted between native calls",GeneratedSafe.dispatch session(subscription,4)=41)
        val ()=check("registered callback exception preserves live owner",((ignore(GeneratedSafe.dispatch session(subscription,7));false)handle CallbackStop=>
          GeneratedSafe.dispatch session(subscription,4)=41))
        val ()=GeneratedSafe.unregister session subscription
        val ()=check("callback survives native unregistration until destructor returns",!destroyed=1)
        val ()=check("failed registration releases closure and context lease",((ignore(GeneratedSafe.register session(fn _=>raise CallbackStop,context));false)
          handle CallbackStop=>GeneratedSafe.allocations session()=1))
        val ()=check("nullable failed registration releases retained contexts",not(isSome(GeneratedSafe.registerNone session(registered,context))))
        val throwing=GeneratedSafe.register session((fn(value,_)=>if value=91 then raise CallbackStop else value),context)
        val ()=check("unregister callback exception still releases roots and context",((GeneratedSafe.release_subscription throwing;false)handle CallbackStop=>
          ((ignore(GeneratedSafe.raw_subscription throwing);false)handle ForeignOwner.Closed=>true)))
        val ()=GeneratedSafe.release_memory context
        val ()=check("registered callback native allocations released",GeneratedSafe.allocations session()=0)
        fun retire 0=() | retire n=
          let val parent=GeneratedSafe.allocate session 4 val child=GeneratedSafe.borrow session parent
          in GeneratedSafe.release_memory child;GeneratedSafe.release_memory parent;retire(n-1) end
        val ()=retire 16
        val ()=check("repeated resource registration and retirement",GeneratedSafe.allocations session()=0)
        val ()=GeneratedSafe.closeSession session
        val facts=RuneForeign.abiFacts()
        val mismatch={architecture= #architecture facts,charBits= #charBits facts,charSigned= #charSigned facts,
          scalars=List.map(fn {name,size,alignment}=>{name=name,size=if name="long" then size+1 else size,alignment=alignment})(#scalars facts)}
        val invalid=ForeignGenerated.createChecked{libraries=["missing-library-must-not-open"],
          descriptors=[{name="probe",symbol="probe",abi=0,result=RuneForeign.Void,arguments=[]}],target=RuneForeign.target(),abiFacts=mismatch}
        val ()=check("complete ABI mismatch rejects before library load",((ignore(ForeignGenerated.prepare invalid "probe");false)
          handle Fail message=>String.isSubstring "C ABI facts" message))
        val ()=ForeignGenerated.close invalid
    in check("registry cleanup",RuneForeign.live()=0w0) end
end
val ()=GeneratedSafeClient.run(hd(CommandLine.arguments()))

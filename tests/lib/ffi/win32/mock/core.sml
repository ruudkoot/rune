(* libraries: test/unit *)
structure Win32MockTests =
struct
  structure W=Win32Mock
  val serial=ref 0
  fun test name body=Test.it name body
  fun check name condition=Expect.that(name,condition)
  fun finally body cleanup=
    let val result=body()handle e=>(cleanup()handle _=>();raise e) in cleanup();result end
  fun error body=((body();false)handle W.Types.Error _=>true)
  fun unsupported body=((body();false)handle W.Types.Unsupported _=>true)
  fun withClass procedure body=
    let val ()=W.reset() val ()=serial:= !serial+1
        val instance=W.Kernel.getModuleHandle NONE
        val created=ref([]:W.Types.window list)
        fun wrapped(window,message)=
          (case message of W.Types.NcCreate=>created:=window:: !created | _=>();procedure(window,message))
        val class=W.User.registerClassEx{name="mock-test-" ^ Int.toString(!serial),instance=instance,style=0w3,procedure=wrapped}
        fun make()=W.User.createWindowEx{class=class,instance=instance,title="model",style=0wxCF0000,extendedStyle=0w0,
          x=0,y=0,width=320,height=200,parent=NONE}
        fun cleanup()=
          (List.app(fn window=>if error(fn()=>ignore(W.User.getClientRect window)) then () else
             (W.User.destroyWindow window handle _=>()))(!created);W.User.unregisterClass(class,instance))
    in finally(fn()=>body{create=make,class=class,instance=instance})cleanup end
  fun using procedure body=withClass procedure(fn{create,...}=>body(create()))
  fun default _=W.Types.Default
  fun app code=W.Types.Application{code=code,w=0w19,l=Int64.fromInt 23}
  fun filtered remove=W.User.peekMessage{window=NONE,minimum=0wx8000,maximum=0wx800F,remove=remove}
  fun some(SOME x)=x | some NONE=raise Fail "missing queued message"
  val tests=Test.describe "ffi/win32/mock"
    [test "creation before return and canonical identity"(fn()=>
      let val seen=ref([]:W.Types.window list)
      in using(fn(window,message)=>(case message of W.Types.NcCreate=>seen:=window:: !seen | W.Types.Create=>seen:=window:: !seen | _=>();W.Types.Default))
        (fn window=>check "creation callbacks"(length(!seen)=2 andalso List.all(fn token=>token=window)(!seen))) end),
     test "independent nested exception activations"(fn()=>
       using(fn(window,W.Types.Application{code,...})=>
         if code=0wx8001 then
           (ignore(W.User.sendMessage(window,app 0wx8002))handle Fail "inner"=>();W.Types.Result(Int64.fromInt 7))
         else raise Fail "inner" | _=>W.Types.Default)
         (fn window=>check "inner handled"(W.User.sendMessage(window,app 0wx8001)=Int64.fromInt 7))),
     test "nested sends preserve depth and arguments"(fn()=>
       let val depth=ref 0 val deepest=ref 0
           fun procedure(window,W.Types.Application{code,w,l})=
             (depth:= !depth+1;deepest:=Int.max(!deepest,!depth);
              let val result=if code=0wx8001 then W.User.sendMessage(window,app 0wx8002)
                else Int64.+(Int64.fromLarge(Word64.toLargeInt w),l)
              in depth:= !depth-1;W.Types.Result result end)
             | procedure _=W.Types.Default
       in using procedure(fn window=>check "nested result"(W.User.sendMessage(window,app 0wx8001)=Int64.fromInt 42 andalso !deepest=2 andalso !depth=0)) end),
     test "post is deferred and copies have single-use lifetimes"(fn()=>
       let val count=ref 0
       in using(fn(_,W.Types.Application _)=>(count:= !count+1;W.Types.Result(Int64.fromInt 42)) | _=>W.Types.Default)
         (fn window=>let val ()=W.User.postMessage(window,app 0wx8001)
                        val lookahead=some(filtered false)
                        val ()=check "post deferred"(!count=0)
                        val ()=W.User.discardMessage lookahead
                        val copy=some(filtered true)
                        val ()=check "dispatch result"(W.User.dispatchMessage copy=Int64.fromInt 42 andalso !count=1)
                    in check "copies stale"(error(fn()=>ignore(W.User.dispatchMessage copy)) andalso error(fn()=>W.User.discardMessage lookahead)) end) end),
     test "message filters and quit status"(fn()=>using default(fn window=>
       let val ()=W.User.postMessage(window,app 0wx8002)
           val none=W.User.peekMessage{window=SOME window,minimum=0wx8001,maximum=0wx8001,remove=true}
           val copy=some(filtered true) val ()=ignore(W.User.dispatchMessage copy)
           val ()=W.User.postQuitMessage(Int32.fromInt 17)
       in check "filtered quit"(not(isSome none) andalso(case W.User.getMessage{window=NONE,minimum=0w0,maximum=0w0} of
          W.Types.Quit status=>status=Int32.fromInt 17 | _=>false)) end)),
     test "paint scopes clean after exceptions"(fn()=>using default(fn window=>
       let val saved=ref(NONE:W.Types.paint option)
           val failed=((W.User.withPaint window(fn(p,_) =>(saved:=SOME p;raise Fail "body"));false)handle Fail "body"=>true)
       in check "paint stale"(failed andalso error(fn()=>ignore(W.Gdi.moveToEx(valOf(!saved),1,2)))) end)),
     test "active paint prevents destruction"(fn()=>using default(fn window=>
       W.User.withPaint window(fn _=>check "paint borrow"(error(fn()=>W.User.destroyWindow window))))),
     test "paint invalidation clips to the current client rectangle"(fn()=>using default(fn window=>
       (W.User.invalidateRect(window,SOME{left=Int32.fromInt ~5,top=Int32.fromInt ~6,right=Int32.fromInt 1000,bottom=Int32.fromInt 1000},false);
        W.User.withPaint window(fn(_,area)=>check "client clip"(#left area=Int32.fromInt 0 andalso #top area=Int32.fromInt 0 andalso
          #right area=Int32.fromInt 320 andalso #bottom area=Int32.fromInt 200))))),
     test "selected objects are guarded and share closed state"(fn()=>using default(fn window=>
       let val pen=W.Gdi.createPen{style=0,width=2,colour=0wx112233}
           val object=W.Gdi.penObject pen
       in finally(fn()=>W.User.withPaint window(fn(p,_)=>
           let val old=W.Gdi.selectObject(p,object)
               val ()=check "selection guard"(error(fn()=>W.Gdi.deleteObject object))
               val ()=ignore(W.Gdi.moveToEx(p,2,3)) val ()=W.Gdi.lineTo(p,10,11)
           in ignore(W.Gdi.selectObject(p,old)) end)) (fn()=>W.Gdi.deleteObject object);
          check "stale pen view"(error(fn()=>ignore(W.Gdi.penObject pen))) end)),
     test "stock objects are borrowed and kind checked"(fn()=>using default(fn window=>
       let val brush=W.Gdi.getStockObject 0 val pen=W.Gdi.getStockObject 7
       in check "stock guards"(error(fn()=>W.Gdi.deleteObject brush) andalso error(fn()=>ignore(W.Gdi.objectBrush pen)));
          W.User.withPaint window(fn(p,area)=>W.User.fillRect(p,area,W.Gdi.objectBrush brush)) end)),
     test "owned brush lifetime and drawing state"(fn()=>using default(fn window=>
       let val brush=W.Gdi.createSolidBrush 0wxA0B0C0 val object=W.Gdi.brushObject brush
       in finally(fn()=>W.User.withPaint window(fn(p,_)=>
         let val old=W.Gdi.selectObject(p,object)
             val point=W.Gdi.moveToEx(p,4,5)
             val previous=W.Gdi.setTextColor(p,0wx102030)
             val mode=W.Gdi.setBkMode(p,1)
             val ()=W.Gdi.rectangle(p,{left=Int32.fromInt 1,top=Int32.fromInt 2,right=Int32.fromInt 20,bottom=Int32.fromInt 30})
             val ()=W.Gdi.textOut(p,1,2,"Rune")
         in check "initial state"(#x point=0 andalso #y point=0 andalso previous=0w0 andalso mode=2);
            ignore(W.Gdi.selectObject(p,old)) end))(fn()=>W.Gdi.deleteObject object) end)),
     test "invalidations coalesce before synchronous update"(fn()=>
       let val count=ref 0
       in using(fn(window,W.Types.Paint)=>(count:= !count+1;W.User.withPaint window(fn _=>());W.Types.Result(Int64.fromInt 0)) | _=>W.Types.Default)
         (fn window=>(W.User.invalidateRect(window,NONE,false);W.User.invalidateRect(window,NONE,true);W.User.updateWindow window;
           W.User.updateWindow window;check "one paint"(!count=1))) end),
     test "deterministic message timers and cancellation"(fn()=>using default(fn window=>
       let val earlier=W.Kernel.queryPerformanceCounter()
           val timer=W.User.setTimer(window,0w7,0w20)
           val next=W.User.getMessage{window=SOME window,minimum=0wx113,maximum=0wx113}
           val ()=case next of W.Types.Message copy=>ignore(W.User.dispatchMessage copy) | _=>raise Fail "expected timer"
           val ()=W.User.killTimer(window,timer)
       in check "time advanced"(W.Kernel.queryPerformanceCounter()>earlier andalso error(fn()=>W.User.killTimer(window,timer))) end)),
     test "close defaults to destruction and repeated uses reject"(fn()=>using default(fn window=>
       (ignore(W.User.sendMessage(window,W.Types.Close));check "closed"(error(fn()=>ignore(W.User.getClientRect window)) andalso error(fn()=>W.User.destroyWindow window))))),
     test "creation exception suppresses later procedure calls and cleans"(fn()=>
       let val calls=ref([]:string list)
       in withClass(fn(_,message)=>case message of W.Types.NcCreate=>(calls:="nc":: !calls;W.Types.Default)
            | W.Types.Create=>(calls:="create":: !calls;raise Fail "creation")
            | W.Types.Destroy=>(calls:="destroy":: !calls;W.Types.Default)
            | W.Types.NcDestroy=>(calls:="nc-destroy":: !calls;W.Types.Default) | _=>W.Types.Default)
          (fn{create,...}=>check "suppression"(((ignore(create());false)handle Fail "creation"=>true) andalso !calls=["create","nc"])) end),
     test "explicit nonclient creation rejection has no Destroy"(fn()=>
       let val destroyed=ref false
       in withClass(fn(_,W.Types.NcCreate)=>W.Types.Result(Int64.fromInt 0)
            | (_,W.Types.Destroy)=>(destroyed:=true;W.Types.Default) | _=>W.Types.Default)
          (fn{create,...}=>check "rejected creation"(error(fn()=>ignore(create())) andalso not(!destroyed))) end),
     test "destroy exception still invalidates window"(fn()=>using(fn(_,W.Types.Destroy)=>raise Fail "destroy" | _=>W.Types.Default)
       (fn window=>let val failed=((W.User.destroyWindow window;false)handle Fail "destroy"=>true)
        in check "destroy cleanup"(failed andalso error(fn()=>ignore(W.User.getClientRect window))) end)),
     test "class cannot unregister during active callback"(fn()=>
       let val registration=ref(NONE:(W.Types.atom*W.Types.module)option) val blocked=ref false
       in withClass(fn(_,W.Types.Destroy)=>(blocked:=error(fn()=>W.User.unregisterClass(valOf(!registration)));W.Types.Default) | _=>W.Types.Default)
         (fn{create,class,instance}=>(registration:=SOME(class,instance);let val window=create() in W.User.destroyWindow window;check "callback registration guard"(!blocked) end)) end),
     test "synthetic pointer-bearing messages are rejected"(fn()=>using default(fn window=>
       check "synthetic guards"(unsupported(fn()=>W.User.postMessage(window,W.Types.Unknown 0wxC)) andalso
         unsupported(fn()=>ignore(W.User.sendMessage(window,W.Types.Create))) andalso
         unsupported(fn()=>ignore(W.User.sendMessage(window,W.Types.Application{code=0wx100,w=0w0,l=Int64.fromInt 0})))))),
     test "unsupported portable text and flags are explicit"(fn()=>using default(fn window=>
       W.User.withPaint window(fn(p,_)=>check "text guard"(unsupported(fn()=>W.Gdi.textOut(p,0,0,"\206\187")))))),
     test "palette encodings reject before allocating an owner"(fn()=>
       check "palette"(unsupported(fn()=>ignore(W.Gdi.createSolidBrush 0wx01000000)) andalso
         unsupported(fn()=>ignore(W.Gdi.createPen{style=0,width=1,colour=0wx02000000})))),
     test "traces are normalized and reset clears observations"(fn()=>
       let val ()=using default(fn window=>ignore(W.User.showWindow(window,1)))
           val observations=W.trace() val ()=W.reset()
       in check "trace"(List.exists(String.isPrefix "create 1 ")observations andalso null(W.trace())) end)]
end
structure Win32MockMain=Main(struct val name="ffi/win32/mock" val tests=Win32MockTests.tests end)
val ()=Win32MockMain.main()

(* Shared observable Win32 GUI behavior. Instantiate this exact source against
   native Windows, SDL and deterministic mocks. It depends only on WIN32 and
   test/unit; platform entrypoints supply provider startup and shutdown. *)
functor Win32ContractFn (structure Win32 : WIN32 val name : string) =
struct
  structure W=Win32
  structure T=W.Types
  exception CallbackFailure
  exception BodyFailure
  val serial=ref 0
  fun assert label ok=Expect.that(label,ok)
  fun errorCode code body=(body();false) handle T.Error{code=actual,...}=>actual=code
  fun anyError body=(body();false) handle T.Error _=>true
  fun unsupported body=(body();false) handle T.Unsupported _=>true
  fun finally body cleanup=
    let val result=body() handle e=>((cleanup() handle _=>());raise e)
    in cleanup();result end
  fun closedObject object=(W.Gdi.deleteObject object handle T.Error{code=0w6,...}=>())
  fun app code value=T.Application{code=code,w=0w0,l=Int64.fromInt value}
  fun filter window minimum maximum={window=window,minimum=minimum,maximum=maximum}
  fun fixture label procedure body=
    let val ()=serial:= !serial+1
        val instance=W.Kernel.getModuleHandle NONE
        val className="Runeffi.Contract." ^ String.substring(name,0,Int.min(size name,32)) ^ "." ^ label ^ "." ^ Int.toString(!serial)
        val windows=ref([]:T.window list)
        val actions=ref([]:(unit->unit)list)
        fun onCleanup action=actions:=action:: !actions
        fun remember window=if List.exists(fn old=>old=window)(!windows) then () else windows:=window:: !windows
        fun callback(window,message)=
          (case message of T.NcCreate=>remember window | _=>();
           procedure(window,message))
        val class=W.User.registerClassEx{name=className,instance=instance,style=0w0,procedure=callback}
        fun create title=
          let val window=W.User.createWindowEx{class=class,instance=instance,title=title,style=0wx00CF0000,extendedStyle=0w0,
            x= ~2147483648,y= ~2147483648,width=160,height=120,parent=NONE}
          in remember window;window end
        fun cleanup ()=
          let val first=ref(NONE:exn option)
              fun attempt action=action() handle e=>if isSome(!first) then () else first:=SOME e
              fun destroy window=(W.User.destroyWindow window handle T.Error{code=0w1400,...}=>())
              val ()=List.app attempt (!actions)
              val ()=List.app(fn window=>attempt(fn()=>destroy window))(!windows)
              val ()=attempt(fn()=>W.User.unregisterClass(class,instance))
          in case !first of NONE=>() | SOME e=>raise e end
        val result=body{create=create,class=class,instance=instance,onCleanup=onCleanup}
          handle e=>((cleanup() handle _=>());raise e)
        val ()=cleanup()
    in result end
  fun test label body=Test.it label(fn()=>body() handle T.Error{function,code}=>
    raise Fail(function ^ ": Win32 error " ^ Word32.toString code))
  val tests=Test.describe("win32/contract/" ^ name)
    [test "kernel-errors-and-clock"(fn()=>
       let val instance=W.Kernel.getModuleHandle NONE
           val ()=assert "module identity"(instance=W.Kernel.getModuleHandle NONE)
           val ()=W.Kernel.setLastError 0wx1234
           val ()=assert "last error round trip"(W.Kernel.getLastError()=0wx1234)
           val frequency=W.Kernel.queryPerformanceFrequency()
           val started=W.Kernel.queryPerformanceCounter()
           val stopped=W.Kernel.queryPerformanceCounter()
       in assert "positive frequency and monotonic counter"(frequency>Int64.fromInt 0 andalso stopped>=started) end),
     test "creation-and-nested-dispatch"(fn()=>
       let val returned=ref false val observed=ref(NONE:T.window option)
           val phases=ref([]:string list)
           fun procedure(window,message)=case message of
               T.NcCreate=>(assert "NcCreate before return"(not(!returned));observed:=SOME window;phases:="nc":: !phases;T.Default)
             | T.Create=>(assert "Create before return"(not(!returned));phases:="create":: !phases;
                 assert "send during creation"(W.User.sendMessage(window,app 0wx8001 7)=Int64.fromInt 7);T.Default)
             | T.Application{code=0wx8000,...}=>T.Result(Int64.+(W.User.sendMessage(window,app 0wx8001 7),Int64.fromInt 5))
             | T.Application{l,...}=>T.Result l
             | _=>T.Default
       in fixture "creation" procedure(fn{create,...}=>
         let val window=create "creation" val ()=returned:=true
             val ()=assert "creation identity is stable"(!observed=SOME window)
             val ()=assert "ordered required creation messages"(rev(!phases)=["nc","create"])
             val ()=assert "nested synchronous send"(W.User.sendMessage(window,app 0wx8000 0)=Int64.fromInt 12)
             val rect=W.User.getClientRect window
         in assert "positive client size"(#right rect> #left rect andalso #bottom rect> #top rect) end) end),
     test "queue-filter-copy-discard-and-single-use"(fn()=>
       fixture "queue" (fn(_,message)=>case message of T.Application{l,...}=>T.Result l | _=>T.Default)(fn{create,onCleanup,...}=>
         let val window=create "queue"
             val ()=W.User.postMessage(window,app 0wx8004 4)
             val ()=W.User.postMessage(window,app 0wx8005 5)
             val peek=valOf(W.User.peekMessage{window=SOME window,minimum=0wx8005,maximum=0wx8005,remove=false})
             val ()=onCleanup(fn()=>W.User.discardMessage peek handle T.Error{code=0w6,...}=>())
             val ()=W.User.discardMessage peek
             val ()=assert "discard closes copied message"(errorCode 0w6(fn()=>W.User.discardMessage peek))
             val removed=valOf(W.User.peekMessage{window=SOME window,minimum=0wx8005,maximum=0wx8005,remove=true})
             val ()=onCleanup(fn()=>W.User.discardMessage removed handle T.Error{code=0w6,...}=>())
             val ()=assert "application message has no keyboard translation"(not(W.User.translateMessage removed))
             val ()=assert "filtered dispatch"(W.User.dispatchMessage removed=Int64.fromInt 5)
             val ()=assert "dispatch consumes once"(errorCode 0w6(fn()=>ignore(W.User.dispatchMessage removed)))
             val ()=assert "filter retained earlier message"(case W.User.getMessage(filter(SOME window)0wx8004 0wx8004) of
                 T.Message queued=>finally(fn()=>W.User.dispatchMessage queued=Int64.fromInt 4)
                   (fn()=>W.User.discardMessage queued handle T.Error{code=0w6,...}=>()) | T.Quit _=>false)
             val remaining=W.User.peekMessage{window=SOME window,minimum=0wx8004,maximum=0wx8005,remove=true}
             val ()=Option.app(fn queued=>onCleanup(fn()=>W.User.discardMessage queued handle T.Error{code=0w6,...}=>()))remaining
         in assert "no matching queue residue"(not(isSome remaining)) end)),
     test "paint-output-scopes-and-exception-cleanup"(fn()=>
       fixture "paint" (fn _=>T.Default)(fn{create,...}=>
         let val window=create "paint"
             val _=W.User.showWindow(window,8)
             val ()=W.User.invalidateRect(window,NONE,true)
             val saved=ref(NONE:T.paint option)
             val ()=(W.User.withPaint window(fn(paint,rectangle)=>
               (saved:=SOME paint;assert "paint output rectangle"(#right rectangle> #left rectangle andalso #bottom rectangle> #top rectangle);raise BodyFailure));
               raise Fail "paint body exception was swallowed") handle BodyFailure=>()
             val ()=assert "exception ended paint scope"(errorCode 0w6(fn()=>ignore(W.Gdi.moveToEx(valOf(!saved),1,1))))
             val ()=W.User.invalidateRect(window,NONE,false)
             val (paint,_)=W.User.beginPaint window
             val ()=finally(fn()=>assert "active paint protects window"(errorCode 0w170(fn()=>W.User.destroyWindow window)))
               (fn()=>W.User.endPaint(window,paint))
         in assert "EndPaint consumes once"(errorCode 0w6(fn()=>W.User.endPaint(window,paint))) end)),
     test "gdi-owned-selection-stock-and-drawing-state"(fn()=>
       fixture "gdi" (fn _=>T.Default)(fn{create,onCleanup,...}=>
         let val window=create "drawing"
             val pen=W.Gdi.createPen{style=0,width=1,colour=0wx00332211}
             val penObject=W.Gdi.penObject pen
             val ()=onCleanup(fn()=>closedObject penObject)
             val brush=W.Gdi.createSolidBrush 0wx00665544
             val brushObject=W.Gdi.brushObject brush
             val ()=onCleanup(fn()=>closedObject brushObject)
             fun cleanup ()=((W.Gdi.deleteObject penObject handle _=>());(W.Gdi.deleteObject brushObject handle _=>()))
             val ()=(W.User.invalidateRect(window,NONE,false);
               W.User.withPaint window(fn(paint,rectangle)=>
                 let val _=W.Gdi.selectObject(paint,penObject)
                     val _=W.Gdi.selectObject(paint,brushObject)
                     val ()=assert "selected pen cannot be deleted"(errorCode 0w170(fn()=>W.Gdi.deleteObject penObject))
                     val ()=assert "selected brush cannot be deleted"(errorCode 0w170(fn()=>W.Gdi.deleteObject brushObject))
                     val ()=assert "pen cannot become brush"(errorCode 0w6(fn()=>ignore(W.Gdi.objectBrush penObject)))
                     val old=W.Gdi.moveToEx(paint,4,5)
                     val ()=assert "initial drawing point"(#x old=0 andalso #y old=0)
                     val ()=W.Gdi.lineTo(paint,9,10)
                     val previous=W.Gdi.moveToEx(paint,0,0)
                     val ()=assert "LineTo updates drawing point"(#x previous=9 andalso #y previous=10)
                     val ()=W.Gdi.rectangle(paint,{left=Int32.fromInt 1,top=Int32.fromInt 2,right=Int32.fromInt 16,bottom=Int32.fromInt 17})
                     val ()=W.User.fillRect(paint,rectangle,W.Gdi.objectBrush brushObject)
                     val _=W.Gdi.setTextColor(paint,0wx00332211)
                     val ()=assert "text colour output"(W.Gdi.setTextColor(paint,0wx00665544)=0wx00332211)
                     val _=W.Gdi.setBkMode(paint,1)
                     val ()=assert "background mode output"(W.Gdi.setBkMode(paint,2)=1)
                 in W.Gdi.textOut(paint,2,2,"Rune") end)) handle e=>(cleanup();raise e)
             val ()=W.Gdi.deleteObject penObject
             val ()=W.Gdi.deleteObject brushObject
             val ()=assert "stale pen conversion rejected"(errorCode 0w6(fn()=>ignore(W.Gdi.penObject pen)))
             val ()=assert "stale brush conversion rejected"(errorCode 0w6(fn()=>ignore(W.Gdi.brushObject brush)))
             val ()=assert "ended paint released selections"(errorCode 0w6(fn()=>W.Gdi.deleteObject penObject))
             val stock=W.Gdi.getStockObject 0
         in assert "borrowed stock cannot be deleted"(errorCode 0w6(fn()=>W.Gdi.deleteObject stock)) end)),
     test "timers-cancel-and-preserve-identity"(fn()=>
       let val delivered=ref([]:Word64.word list)
       in fixture "timer" (fn(_,message)=>case message of T.Timer id=>(delivered:=id:: !delivered;T.Default) | _=>T.Default)(fn{create,...}=>
         let val window=create "timer"
             val timer=W.User.setTimer(window,0wx1234,0w1)
             val ()=assert "requested timer identity"(timer=0wx1234)
             val ()=(case W.User.getMessage(filter(SOME window)0wx113 0wx113) of
                 T.Message queued=>ignore(W.User.dispatchMessage queued) | T.Quit _=>raise Fail "unexpected quit while waiting for timer")
               handle e=>((W.User.killTimer(window,timer) handle _=>());raise e)
             val ()=W.User.killTimer(window,timer)
             val ()=assert "timer message identity"(List.exists(fn id=>id=timer)(!delivered))
         in assert "cancelled timer cannot be killed twice"(errorCode 0w6(fn()=>W.User.killTimer(window,timer))) end) end),
     test "callback-exception-containment"(fn()=>
       fixture "callback-exception" (fn(_,message)=>case message of T.Application{code=0wx8002,...}=>raise CallbackFailure | _=>T.Default)(fn{create,...}=>
         let val window=create "callback exception"
             val raised=(ignore(W.User.sendMessage(window,app 0wx8002 0));false) handle CallbackFailure=>true
             val ()=assert "same exception safely returns to SML" raised
             val ()=W.User.setWindowText(window,"still live")
             val rectangle=W.User.getClientRect window
         in assert "VM and window remain usable"(#right rectangle> #left rectangle) end)),
     test "creation-veto-and-exception-cleanup"(fn()=>
       let fun run phase result=
             fixture ("failed-create-" ^ phase) (fn(_,message)=>case (phase,message) of
                 ("nc",T.NcCreate)=>T.Result(Int64.fromInt 0)
               | ("create",T.Create)=>T.Result(Int64.fromInt ~1)
               | ("exception",T.Create)=>raise CallbackFailure | _=>T.Default)
               (fn{create,...}=>assert "failed creation reports its cause"
                 (if result then ((ignore(create "failed");false) handle CallbackFailure=>true)
                  else anyError(fn()=>ignore(create "failed"))))
       in run "nc" false;run "create" false;run "exception" true end),
     test "unsupported-selection-and-stale-window"(fn()=>
       fixture "unsupported" (fn _=>T.Default)(fn{create,class,instance,...}=>
         let val window=create "unsupported"
             val ()=assert "synthetic lifecycle message rejected"(unsupported(fn()=>W.User.postMessage(window,T.NcCreate)))
             val ()=assert "unsupported window style rejected"(unsupported(fn()=>ignore(W.User.createWindowEx{class=class,instance=instance,
               title="child",style=0wx40000000,extendedStyle=0w0,x=0,y=0,width=16,height=16,parent=NONE})))
             val ()=W.User.destroyWindow window
         in assert "stale window rejected"(errorCode 0w1400(fn()=>ignore(W.User.getClientRect window))) end)),
     test "default-close-destroys-before-return"(fn()=>
       let val destroyed=ref false val ended=ref false
       in fixture "close" (fn(_,message)=>case message of T.Destroy=>(destroyed:=true;T.Default) | T.NcDestroy=>(ended:=true;T.Default) | _=>T.Default)(fn{create,...}=>
         let val window=create "close"
             val _=W.User.sendMessage(window,T.Close)
             val ()=assert "destruction callbacks completed"(!destroyed andalso !ended)
         in assert "default close ended identity"(errorCode 0w1400(fn()=>ignore(W.User.getClientRect window))) end) end),
     test "quit-status-is-signed-and-consumed"(fn()=>
       let val ()=W.User.postQuitMessage(Int32.fromInt ~13)
           fun next 0=raise Fail "posted quit status missing"
             | next n=case W.User.getMessage(filter NONE 0w0 0w0) of
                 T.Quit code=>code=Int32.fromInt ~13
               | T.Message queued=>(W.User.discardMessage queued;next(n-1))
       in assert "quit status"(next 2048) end)]
end

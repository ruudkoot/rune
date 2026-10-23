structure NativeWin32Suite =
struct
  structure W=Win32Native
  structure T=W.Types
  val checks=ref 0
  fun check(name,condition)=(checks:= !checks+1;if condition then () else raise Fail name)
  fun rejected action=(action();false)handle T.Error _=>true
  val instance=W.Kernel.getModuleHandle NONE
  val ()=W.Kernel.setLastError 0w12345
  val ()=check("last error",W.Kernel.getLastError()=0w12345)
  val ()=check("performance frequency",W.Kernel.queryPerformanceFrequency()>0)
  val firstCounter=W.Kernel.queryPerformanceCounter()
  val ()=check("monotonic counter",W.Kernel.queryPerformanceCounter()>=firstCounter)
  val events=ref([]:string list)
  val windowValue=ref(NONE:T.window option)
  val atom=W.User.registerClassEx{name="RuneffiNativeGuiContract",instance=instance,style=0w3,
    procedure=fn(window,message)=>case message of
      T.NcCreate=>(windowValue:=SOME window;events:="nc-create":: !events;T.Default)
    | T.Create=>(events:="create":: !events;T.Default)
    | T.Application{code=0wx8001,...}=>(check("nested send",W.User.sendMessage(window,T.Application{code=0wx8002,w=0w0,l=0})=22);T.Result 11)
    | T.Application{code=0wx8002,...}=>T.Result 22
    | T.Paint=>(W.User.withPaint window(fn(paint,rect)=>
        let val brush=W.Gdi.objectBrush(W.Gdi.getStockObject 0)
            val ()=W.User.fillRect(paint,rect,brush)
            val pen=W.Gdi.createPen{style=0,width=1,colour=0wx332211}
            val old=W.Gdi.selectObject(paint,W.Gdi.penObject pen)
            val ()=check("selected pen busy",rejected(fn()=>W.Gdi.deleteObject(W.Gdi.penObject pen)))
            val _=W.Gdi.moveToEx(paint,1,1)
            val ()=W.Gdi.lineTo(paint,20,20)
            val ()=W.Gdi.rectangle(paint,{left=2,top=2,right=30,bottom=30})
            val _=W.Gdi.setTextColor(paint,0w0)
            val _=W.Gdi.setBkMode(paint,1)
            val ()=W.Gdi.textOut(paint,3,3,"Runeffi")
            val _=W.Gdi.selectObject(paint,old)
            val ()=W.Gdi.deleteObject(W.Gdi.penObject pen)
        in () end);events:="paint":: !events;T.Result 0)
    | T.Destroy=>(events:="destroy":: !events;T.Default)
    | T.NcDestroy=>(events:="nc-destroy":: !events;T.Default)
    | _=>T.Default}
  val window=W.User.createWindowEx{class=atom,instance=instance,title="Runeffi native GUI",style=0wx00CF0000,
    extendedStyle=0w0,x=40,y=40,width=240,height=160,parent=NONE}
  val ()=check("creation-time identity",!windowValue=SOME window)
  val ()=check("creation callbacks",List.exists(fn s=>s="nc-create")(!events) andalso List.exists(fn s=>s="create")(!events))
  val ()=check("nested synchronous sends",W.User.sendMessage(window,T.Application{code=0wx8001,w=0w0,l=0})=11)
  val _=W.User.showWindow(window,8)
  val ()=W.User.setWindowText(window,"Runeffi \237\160\128")
  val rect=W.User.getClientRect window
  val ()=check("client rectangle",#right rect>= #left rect andalso #bottom rect>= #top rect)
  val ()=W.User.invalidateRect(window,NONE,true)
  val ()=W.User.updateWindow window
  val ()=check("native paint callback",List.exists(fn s=>s="paint")(!events))
  val timer=W.User.setTimer(window,0w1,0w1000)
  val ()=W.User.killTimer(window,timer)
  val ()=check("timer released",rejected(fn()=>W.User.killTimer(window,timer)))
  val ()=W.User.postMessage(window,T.Application{code=0wx8002,w=0w0,l=0})
  val snapshot=valOf(W.User.peekMessage{window=SOME window,minimum=0wx8002,maximum=0wx8002,remove=false})
  val ()=W.User.discardMessage snapshot
  val ()=check("discarded message stale",rejected(fn()=>ignore(W.User.dispatchMessage snapshot)))
  val message=case W.User.getMessage{window=SOME window,minimum=0wx8002,maximum=0wx8002} of T.Message q=>q | _=>raise Fail "message result"
  val _=W.User.translateMessage message
  val ()=check("dispatch status",W.User.dispatchMessage message=22)
  val ()=check("dispatched message stale",rejected(fn()=>ignore(W.User.translateMessage message)))
  val _=W.User.sendMessage(window,T.Close)
  val ()=check("destroy sequence",List.exists(fn s=>s="destroy")(!events) andalso List.exists(fn s=>s="nc-destroy")(!events))
  val ()=check("closed window stale",rejected(fn()=>W.User.destroyWindow window))
  val ()=W.User.unregisterClass(atom,instance)
  exception CreationFailed
  fun creationFailure which =
    let val token=ref(NONE:T.window option)
        val flag=ref true
        val class=W.User.registerClassEx{name="RuneffiCreationFailure" ^ Int.toString which,instance=instance,style=0w0,
          procedure=fn(window,message)=>(case message of T.NcCreate=>token:=SOME window | _=>();
            if (case message of T.NcCreate=>which=0 | T.Create=>which=1 | T.Size _=>which=2 | _=>false) andalso !flag
            then (flag:=false;raise CreationFailed) else T.Default)}
        val failed=(ignore(W.User.createWindowEx{class=class,instance=instance,title="creation failure",style=0wx10CF0000,
          extendedStyle=0w0,x=40,y=40,width=160,height=100,parent=NONE});false)handle CreationFailed=>true
        val ()=check("creation exception propagated",failed)
        val ()=check("creation failure token retired",case !token of NONE=>true | SOME window=>rejected(fn()=>ignore(W.User.getClientRect window)))
    in W.User.unregisterClass(class,instance) end
  val ()=List.app creationFailure [0,1,2]
  exception DestructionFailed
  val destructionClass=W.User.registerClassEx{name="RuneffiDestroyFailure",instance=instance,style=0w0,
    procedure=fn(_,message)=>case message of T.Destroy=>raise DestructionFailed | _=>T.Default}
  val destructionWindow=W.User.createWindowEx{class=destructionClass,instance=instance,title="destroy failure",style=0wx00CF0000,
    extendedStyle=0w0,x=40,y=40,width=160,height=100,parent=NONE}
  val ()=check("destruction exception propagated",(W.User.destroyWindow destructionWindow;false)handle DestructionFailed=>true)
  val ()=check("destruction exception token retired",rejected(fn()=>ignore(W.User.getClientRect destructionWindow)))
  val ()=W.User.unregisterClass(destructionClass,instance)
  exception PaintFailed
  val paintClass=W.User.registerClassEx{name="RuneffiPaintFailure",instance=instance,style=0w0,
    procedure=fn(_,message)=>case message of T.NcCreate=>T.Default | T.Create=>T.Default | _=>T.Result 0}
  val paintWindow=W.User.createWindowEx{class=paintClass,instance=instance,title="paint failure",style=0wx00CF0000,
    extendedStyle=0w0,x=40,y=40,width=160,height=100,parent=NONE}
  val savedPaint=ref(NONE:T.paint option)
  val ()=check("paint exception cleanup",(W.User.withPaint paintWindow(fn(paint,_)=>
    (savedPaint:=SOME paint;raise PaintFailed));false)handle PaintFailed=>true)
  val ()=check("paint lease stale",rejected(fn()=>W.Gdi.lineTo(valOf(!savedPaint),1,1)))
  val ()=W.User.withPaint paintWindow(fn _=>())
  val ()=NativeWin32Faults.arm("EndPaint",1)
  val ()=check("paint body exception survives failed cleanup",(W.User.withPaint paintWindow(fn(paint,_)=>
    (savedPaint:=SOME paint;raise PaintFailed));false)handle PaintFailed=>true)
  val _=W.User.getClientRect paintWindow
  val ()=check("failed cleanup retries and retires paint",rejected(fn()=>W.Gdi.lineTo(valOf(!savedPaint),1,1)))
  val ()=NativeWin32Faults.arm("EndPaint",1)
  val ()=check("successful body reports cleanup failure",(W.User.withPaint paintWindow(fn(paint,_)=>
    savedPaint:=SOME paint);false)handle NativeWin32Faults.Injected=>true)
  val ()=W.User.withPaint paintWindow(fn _=>())
  val ()=check("normal cleanup failure is retryable",rejected(fn()=>W.Gdi.lineTo(valOf(!savedPaint),1,1)))
  val ()=W.User.destroyWindow paintWindow
  val ()=W.User.unregisterClass(paintClass,instance)
  val otherClass=W.User.registerClassEx{name="RuneffiInactiveClass",instance=instance,style=0w0,procedure=fn _=>T.Default}
  val activeClass=ref(NONE:T.atom option)
  val unrelatedReleased=ref false
  val activeAtom=W.User.registerClassEx{name="RuneffiActiveClass",instance=instance,style=0w0,
    procedure=fn(window,message)=>case message of T.Timer _=>
      (W.User.unregisterClass(otherClass,instance);unrelatedReleased:=true;ignore(W.User.sendMessage(window,T.Close));
       check("active callback class survives destruction",(W.User.unregisterClass(valOf(!activeClass),instance);false)
         handle T.Error{code,...}=>code=0w170);T.Default)
      | _=>T.Default}
  val ()=activeClass:=SOME activeAtom
  val activeWindow=W.User.createWindowEx{class=activeAtom,instance=instance,title="class callbacks",style=0wx00CF0000,
    extendedStyle=0w0,x=40,y=40,width=160,height=100,parent=NONE}
  val closedResult=W.User.sendMessage(activeWindow,T.Timer 0w1)
  val ()=check("default after nested destruction completes",closedResult=Int64.fromInt 0)
  val ()=check("unrelated callback class can unregister",!unrelatedReleased)
  val ()=W.User.unregisterClass(activeAtom,instance)
  val _=NativeWin32Config.prepare "GetMessageW"
  val _=NativeWin32Config.prepare "rf_field_MSG_wParam_get"
  val ()=W.User.postQuitMessage ~8
  val beforeQuit=RuneForeign.live()
  val ()=NativeWin32Faults.arm("rf_field_MSG_wParam_get",0)
  val ()=check("quit conversion failure propagated",(ignore(W.User.getMessage{window=NONE,minimum=0w0,maximum=0w0});false)
    handle NativeWin32Faults.Injected=>true)
  val ()=check("quit conversion failure frees MSG",RuneForeign.live()=beforeQuit)
  val ()=W.User.postQuitMessage ~3
  val ()=check("quit status",case W.User.getMessage{window=NONE,minimum=0w0,maximum=0w0}of T.Quit status=>status= ~3 | _=>false)
  val ()=W.close()
  val ()=check("native resources closed",RuneForeign.live()=0w0)
  val ()=print("PASS native Win32 GUI: " ^ Int.toString(!checks) ^ " checks\n")
end

structure MockTrace =
struct
  structure W=Win32Mock
  val module=W.Kernel.getModuleHandle NONE
  val brush=W.Gdi.createSolidBrush 0wx112233
  val brushObject=W.Gdi.brushObject brush
  fun procedure(window,W.Types.Paint)=
        (W.User.withPaint window(fn(p,area)=>W.User.fillRect(p,area,brush));W.Types.Result(Int64.fromInt 0))
    | procedure(_,W.Types.Application _)=W.Types.Result(Int64.fromInt 42)
    | procedure _=W.Types.Default
  val class=W.User.registerClassEx{name="trace",instance=module,style=0w0,procedure=procedure}
  val window=W.User.createWindowEx{class=class,instance=module,title="trace",style=0wx10CF0000,
    extendedStyle=0w0,x=0,y=0,width=64,height=48,parent=NONE}
  val ()=W.User.invalidateRect(window,NONE,false)
  val ()=W.User.updateWindow window
  val message=W.Types.Application{code=0wx8001,w=0w0,l=Int64.fromInt 0}
  val ()=W.User.postMessage(window,message)
  val copy=valOf(W.User.peekMessage{window=SOME window,minimum=0wx8000,maximum=0wxBFFF,remove=true})
  val _=W.User.dispatchMessage copy
  val _=W.User.sendMessage(window,W.Types.Application{code=0wx8002,w=0w0,l=Int64.fromInt 0})
  val timer=W.User.setTimer(window,0w7,0w20)
  val ()=W.User.killTimer(window,timer)
  val ()=W.User.setWindowText(window,"next")
  val _=W.User.showWindow(window,1)
  val _=W.User.sendMessage(window,W.Types.Close)
  val ()=W.Gdi.deleteObject brushObject
  val ()=W.User.unregisterClass(class,module)
  val ()=List.app(fn row=>print(row ^ "\n"))(W.trace())
end

(* Identical application source for native Windows, SDL and deterministic mocks.
   Provider entrypoints own only startup/shutdown, never window behavior. *)
structure Win32Example =
struct
  structure W=Win32
  structure T=W.Types
  fun withCleanup body=
    let val actions=ref([]:(unit->unit)list)
        fun defer action=actions:=action:: !actions
        fun cleanup ()=
          let val first=ref(NONE:exn option)
              fun attempt action=action() handle e=>if isSome(!first) then () else first:=SOME e
              val ()=List.app attempt (!actions)
          in case !first of NONE=>() | SOME e=>raise e end
        val result=body defer handle e=>((cleanup() handle _=>());raise e)
    in cleanup();result end
  fun run smoke=withCleanup(fn defer=>
    let val instance=W.Kernel.getModuleHandle NONE
        val background=W.Gdi.createSolidBrush 0wx00241C18
        val backgroundObject=W.Gdi.brushObject background
        val ()=defer(fn()=>W.Gdi.deleteObject backgroundObject)
        val accent=W.Gdi.createSolidBrush 0wx00E6B45A
        val accentObject=W.Gdi.brushObject accent
        val ()=defer(fn()=>W.Gdi.deleteObject accentObject)
        val pen=W.Gdi.createPen{style=0,width=1,colour=0wx00F5F0F0}
        val penObject=W.Gdi.penObject pen
        val ()=defer(fn()=>W.Gdi.deleteObject penObject)
        val class=ref(NONE:T.atom option)
        val window=ref(NONE:T.window option)
        val timer=ref(NONE:Word64.word option)
        val frames=ref 0
        fun draw handleWindow=W.User.withPaint handleWindow(fn(paint,area)=>
          let val _=W.Gdi.selectObject(paint,penObject)
              val _=W.Gdi.selectObject(paint,accentObject)
              val ()=W.User.fillRect(paint,area,background)
              val ()=W.Gdi.rectangle(paint,{left=Int32.fromInt 24,top=Int32.fromInt 56,right=Int32.fromInt 184,bottom=Int32.fromInt 120})
              val _=W.Gdi.setTextColor(paint,0wx00F5F0F0)
              val _=W.Gdi.setBkMode(paint,1)
              val ()=W.Gdi.textOut(paint,24,24,"Runeffi: one Win32 program")
              val ()=W.Gdi.textOut(paint,24,144,"native Windows / SDL3 / mock")
              val _=W.Gdi.moveToEx(paint,24,176)
          in W.Gdi.lineTo(paint,184,176) end)
        fun procedure(handleWindow,message)=case message of
            T.Paint=>(draw handleWindow;T.Result(Int64.fromInt 0))
          | T.Size _=>(W.User.invalidateRect(handleWindow,NONE,false);T.Default)
          | T.Timer _=>(frames:= !frames+1;
              W.User.invalidateRect(handleWindow,SOME{left=Int32.fromInt 24,top=Int32.fromInt 56,right=Int32.fromInt 184,bottom=Int32.fromInt 120},false);
              if smoke andalso !frames>=3 then ignore(W.User.sendMessage(handleWindow,T.Close)) else ();T.Default)
          | T.KeyDown{key=0wx1B,...}=>(ignore(W.User.sendMessage(handleWindow,T.Close));T.Result(Int64.fromInt 0))
          | T.NcCreate=>(window:=SOME handleWindow;T.Default)
          | T.Destroy=>(W.User.postQuitMessage(Int32.fromInt 0);T.Default)
          | T.NcDestroy=>(window:=NONE;timer:=NONE;T.Default)
          | _=>T.Default
        fun run ()=
          let val atom=W.User.registerClassEx{name="Runeffi.Shared.Example",instance=instance,style=0w3,procedure=procedure}
              val ()=class:=SOME atom
              val ()=defer(fn()=>case !class of SOME c=>(W.User.unregisterClass(c,instance);class:=NONE) | NONE=>())
              val ()=defer(fn()=>case !window of SOME w=>(W.User.destroyWindow w handle T.Error{code=0w1400,...}=>()) | NONE=>())
              val handleWindow=W.User.createWindowEx{class=atom,instance=instance,title="Runeffi Win32 GUI",style=0wx00CF0000,
                extendedStyle=0w0,x= ~2147483648,y= ~2147483648,width=480,height=280,parent=NONE}
              val ()=window:=SOME handleWindow
              val _=W.User.showWindow(handleWindow,1)
              val ()=W.User.invalidateRect(handleWindow,NONE,true)
              val ()=W.User.updateWindow handleWindow
              val ()=timer:=SOME(W.User.setTimer(handleWindow,0wx1234,0w50))
              val ()=defer(fn()=>case (!window,!timer) of (SOME w,SOME t)=>(W.User.killTimer(w,t);timer:=NONE) | _=>())
              fun loop ()=case W.User.getMessage{window=NONE,minimum=0w0,maximum=0w0} of
                  T.Quit status=>status
                | T.Message message=>(ignore(W.User.translateMessage message);ignore(W.User.dispatchMessage message);loop())
          in loop() end
    in run() end)
  fun main smoke=
    let val status=run smoke
    in print("PASS shared Win32 application: " ^ Int32.toString status ^ "\n");status end
end

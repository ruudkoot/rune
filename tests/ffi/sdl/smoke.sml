(* The same semantic assertions run with a dummy video driver and real Linux
   and Windows windows. OS-generated event streams are deliberately ignored. *)
structure SDLChecks =
struct
  val checks=ref 0
  fun check(ok,message)=if ok then checks:= !checks+1 else raise Fail message
  fun busy body=(body();false) handle SDL.Busy=>true
  fun closed body=(body();false) handle SDL.Closed=>true
  fun c name=SDL.constant name
  fun w32 name=Word32.fromLargeInt(c name)
  fun main paths=
    let val baseline=RuneForeign.live()
        val ()=SDL.load paths
        val ()=SDL.init(w32 "SDL_INIT_VIDEO")
        val ()=SDL.initSubSystem(w32 "SDL_INIT_EVENTS")
        val surface=SDL.createSurface{width=32,height=24,format=w32 "SDL_PIXELFORMAT_RGBA8888"}
        val ()=SDL.withSurfacePixels surface(fn{bytes,pitch,width,height,...}=>
          check(width=32 andalso height=24 andalso pitch>=128 andalso Word8Array.length bytes=pitch*height,"surface geometry"))
        val ()=SDL.fillSurfaceRect(surface,NONE,0wx11223344)
        val ()=SDL.withSurfacePixels surface(fn{bytes,...}=>
          check(Word8Array.sub(bytes,0)=(if #littleEndian(RuneForeign.target()) then 0wx44 else 0wx11),"native surface color"))
        val ()=SDL.withSurfacePixels surface(fn _=>check(busy(fn()=>SDL.destroySurface surface),"pixel borrower prevents destruction"))
        val ()=check((ignore(SDL.createSurface{width= ~1,height=1,format=w32 "SDL_PIXELFORMAT_RGBA8888"});false)
          handle SDL.Error{function,message}=>function="SDL_CreateSurface" andalso size message>0,"captured SDL error")
        val renderer=SDL.createSoftwareRenderer surface
        val ()=check(busy(fn()=>SDL.destroySurface surface),"software renderer retains surface")
        val ()=SDL.setRenderDrawColor(renderer,{red=17,green=34,blue=51,alpha=255})
        val ()=SDL.renderClear renderer
        val snapshot=SDL.renderReadPixels(renderer,NONE)
        val ()=SDL.withSurfacePixels snapshot(fn{width,height,...}=>check(width=32 andalso height=24,"renderer readback"))
        val ()=SDL.destroySurface snapshot
        val ()=SDL.withSurfacePixels surface(fn{bytes,...}=>
          check(ForeignBytes.value{signed=false,littleEndian= #littleEndian(RuneForeign.target()),
            bytes=Byte.bytesToString(Word8ArraySlice.vector(Word8ArraySlice.slice(bytes,0,SOME 4)))}=0x112233FF,"software renderer clear pixels"))
        val ()=SDL.renderPoint(renderer,1.0,1.0)
        val ()=SDL.renderLine(renderer,0.0,0.0,12.0,8.0)
        val ()=SDL.renderRect(renderer,SOME{x=2.0,y=3.0,width=8.0,height=7.0})
        val ()=SDL.renderFillRect(renderer,SOME{x=5.0,y=4.0,width=4.0,height=3.0})
        val ()=SDL.renderDebugText(renderer,0.0,8.0,"Rune")
        val texture=SDL.createTextureFromSurface(renderer,surface)
        val ()=check(busy(fn()=>SDL.destroyRenderer renderer),"texture retains renderer")
        val ()=SDL.renderTexture(renderer,texture,NONE,NONE)
        val ()=SDL.renderPresent renderer
        val ()=SDL.destroyTexture texture
        val ()=SDL.destroyRenderer renderer
        val ()=check(closed(fn()=>SDL.renderClear renderer),"closed renderer")
        val destination=SDL.createSurface{width=32,height=24,format=w32 "SDL_PIXELFORMAT_RGBA8888"}
        val ()=SDL.blitSurface{source=surface,sourceRect=SOME{x=0,y=0,width=8,height=8},destination=destination,destinationRect=SOME{x=1,y=1,width=8,height=8}}
        val ()=SDL.destroySurface destination
        val ()=check((SDL.withSurfacePixels surface(fn{bytes,...}=>(Word8Array.update(bytes,0,0wx5A);raise Fail "body"));false)
          handle Fail "body"=>true | e=>raise e,"pixel callback exception")
        val ()=SDL.withSurfacePixels surface(fn{bytes,...}=>check(Word8Array.sub(bytes,0)=0wx5A,"pixel writes copied after exception"))
        val ()=SDL.lockSurface surface
        val ()=check(busy(fn()=>SDL.destroySurface surface),"locked surface cannot close")
        val ()=SDL.unlockSurface surface
        val ()=SDL.destroySurface surface
        val window=SDL.createWindow{title="Runeffi UTF-8 \206\187",width=160,height=120,flags=Word64.fromLargeInt(c "SDL_WINDOW_HIDDEN")}
        val id=SDL.getWindowID window
        val ()=check(id<>0w0,"window identity")
        val size=SDL.getWindowSize window
        val ()=check(#width size>0 andalso #height size>0,"window dimensions")
        val ()=SDL.setWindowTitle(window,"Runeffi SDL smoke")
        val ()=SDL.setWindowSize(window,180,130)
        val ()=SDL.showWindow window
        val ()=SDL.hideWindow window
        val ()=SDL.startTextInput window
        val ()=SDL.stopTextInput window
        val windowRenderer=SDL.createRenderer(window,SOME "software")
        val ()=check(busy(fn()=>SDL.destroyWindow window),"window renderer retains window")
        val ()=SDL.setRenderDrawColor(windowRenderer,{red=17,green=34,blue=51,alpha=255})
        val ()=SDL.renderClear windowRenderer
        val ()=SDL.renderDebugText(windowRenderer,8.0,8.0,"Runeffi smoke")
        val ()=SDL.renderPresent windowRenderer
        val ()=SDL.destroyRenderer windowRenderer
        fun drain 0=() | drain n=case SDL.pollEvent() of NONE=>() | SOME _=>drain(n-1)
        val ()=drain 1024
        val _=SDL.waitEventTimeout 0
        val ()=SDL.pushEvent(SDL.Text{window=id,text="queued \206\187"})
        fun findText 0=raise Fail "text event missing" | findText n=case SDL.pollEvent() of
          SOME(SDL.Text{window,text})=>(check(window=id andalso text="queued \206\187","owned event text");text)
        | _=>findText(n-1)
        val text=findText 1024
        val ()=SDL.pushEvent(SDL.Key{window=id,down=true,repeated=true,key=0wx61,scan=4,modifiers=0wx3})
        fun findKey 0=raise Fail "key event missing" | findKey n=case SDL.pollEvent() of
          SOME(SDL.Key{window,down,repeated,key,scan,modifiers})=>check(window=id andalso down andalso repeated andalso key=0wx61 andalso scan=4 andalso modifiers=0wx3,"key projection")
        | _=>findKey(n-1)
        val ()=findKey 1024
        val ()=check(text="queued \206\187","event text survives polling")
        val ()=SDL.pushEvent(SDL.MouseMotion{window=id,x=12.5,y=7.25,buttons=0wx5})
        fun findMotion 0=raise Fail "motion event missing" | findMotion n=case SDL.pollEvent() of
          SOME(SDL.MouseMotion{window,x,y,buttons})=>check(window=id andalso Real.==(x,12.5) andalso Real.==(y,7.25) andalso buttons=0wx5,"mouse coordinates")
        | _=>findMotion(n-1)
        val ()=findMotion 1024
        val ()=SDL.pushEvent(SDL.MouseButton{window=id,down=true,button=1,clicks=2,x=3.5,y=6.25})
        fun findButton 0=raise Fail "button event missing" | findButton n=case SDL.pollEvent() of
          SOME(SDL.MouseButton{window,down,button,clicks,x,y})=>check(window=id andalso down andalso button=1 andalso clicks=2 andalso Real.==(x,3.5) andalso Real.==(y,6.25),"mouse button projection")
        | _=>findButton(n-1)
        val ()=findButton 1024
        val ()=SDL.pushEvent(SDL.Window{window=id,kind=w32 "SDL_EVENT_WINDOW_RESIZED",data1=123,data2=234})
        fun findWindow 0=raise Fail "window event missing" | findWindow n=case SDL.pollEvent() of
          SOME(SDL.Window{window,kind,data1,data2})=>if data1=123 andalso data2=234 then check(window=id andalso kind=w32 "SDL_EVENT_WINDOW_RESIZED","window projection") else findWindow(n-1)
        | _=>findWindow(n-1)
        val ()=findWindow 1024
        val ()=SDL.pushEvent SDL.Quit
        fun findQuit 0=raise Fail "quit event missing" | findQuit n=case SDL.waitEvent() of SDL.Quit=>check(true,"wait event") | _=>findQuit(n-1)
        val ()=findQuit 1024
        val ()=check(Vector.length(SDL.getKeyboardState())>0,"keyboard snapshot")
        val _=SDL.getMouseState()
        val clipboard=SDL.getClipboardText()
        val ()=(SDL.setClipboardText "Runeffi clipboard \206\187";
          check(SDL.hasClipboardText() andalso SDL.getClipboardText()="Runeffi clipboard \206\187","clipboard ownership and UTF-8"))
          handle e=>(SDL.setClipboardText clipboard;raise e)
        val ()=SDL.setClipboardText clipboard
        val started=SDL.getTicksNS()
        val ()=SDL.delay 0w1
        val ()=check(SDL.getTicksNS()>=started andalso SDL.getPerformanceFrequency()>0w0 andalso SDL.getPerformanceCounter()>0w0,"timing")
        val _=SDL.getTicks()
        val ()=check(busy SDL.quit andalso busy SDL.unload,"live resource shutdown")
        val ()=SDL.destroyWindow window
        val ()=SDL.clearError()
        val ()=SDL.quitSubSystem(w32 "SDL_INIT_EVENTS")
        val ()=SDL.quit()
        val ()=SDL.unload()
        val ()=check(RuneForeign.live()=baseline,"all native identities closed")
    in print("PASS SDL core: " ^ Int.toString(!checks) ^ " checks\n") end
end
val ()=(case CommandLine.arguments() of paths as _::_=>SDLChecks.main paths | _=>raise Fail "expected SDL library path")
  handle e=>(TextIO.output(TextIO.stdErr,"FAIL SDL core: " ^ (case e of SDL.Error{function,message}=>function ^ ": " ^ message | RuneForeign.Error{message,...}=>"foreign: " ^ message | _=>General.exnMessage e) ^ "\n");OS.Process.exit OS.Process.failure)

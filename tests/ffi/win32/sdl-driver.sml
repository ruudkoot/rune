(* Real SDL calls with SML observation hooks; no handwritten native descriptors. *)
structure ObservedSDL =
struct
  open SDL
  val created=ref(NONE:SDL.window option)
  val positions=ref([]:(int*int)list)
  val surfaces=ref([]:SDL.surface list)
  val canvasRenderer=ref(NONE:SDL.renderer option)
  fun createSurface options=let val surface=SDL.createSurface options in surfaces:=surface:: !surfaces;surface end
  fun createSoftwareRenderer surface=let val renderer=SDL.createSoftwareRenderer surface in canvasRenderer:=SOME renderer;renderer end
  val lines=ref 0
  val fills=ref 0
  val texts=ref([]:string list)
  val colours=ref([]:{red:int,green:int,blue:int,alpha:int}list)
  fun createWindow options=let val window=SDL.createWindow options in created:=SOME window;window end
  fun setWindowPosition(window,x,y)=(positions:=(x,y):: !positions;SDL.setWindowPosition(window,x,y))
  fun renderLine args=(lines:= !lines+1;SDL.renderLine args)
  fun renderFillRect args=(fills:= !fills+1;SDL.renderFillRect args)
  fun renderDebugText args=let val (_,_,_,text)=args in texts:=text:: !texts;SDL.renderDebugText args end
  fun setRenderDrawColor(renderer,colour)=(colours:=colour:: !colours;SDL.setRenderDrawColor(renderer,colour))
end
structure Driver = Win32SdlDriverFn(structure Sdl = ObservedSDL)
structure Win32SDLDriverChecks =
struct
  structure T=Win32Common.Types
  val count=ref 0
  fun check(ok,message)=if ok then count:= !count+1 else raise Fail message
  fun rejected body=(body();false) handle T.Error _=>true
  fun unsupported body=(body();false) handle T.Unsupported _=>true
  fun c name=Word32.fromLargeInt(SDL.constant name)
  fun message wanted =
    let fun loop 0=raise Fail "normalized SDL message missing"
          | loop n=case Driver.poll() of SOME(Driver.Message(_,message))=>if wanted message then message else loop(n-1)
            | _=>loop(n-1)
    in loop 2048 end
  fun drain 0=() | drain n=case Driver.poll() of NONE=>() | _=>drain(n-1)
  fun main arguments=
    let fun split([],paths)=(rev paths,[]) | split("--runeffi-constants"::facts,paths)=(rev paths,facts)
          | split(path::rest,paths)=split(rest,path::paths)
        val (paths,facts)=split(arguments,[])
        val ()=if null facts then () else check(List.all(fn fact=>case String.fields(fn c=>c= #"=")fact of
          [name,value]=>SDL.constant name=valOf(IntInf.fromString value) | _=>false)facts,"all selected SDL constants agree with native C")
        val baseline=RuneForeign.live()
        val ()=Driver.load paths
        val window=Driver.create{title="Win32 SDL driver",x= ~2147483648,y= ~2147483648,width=160,height=120,visible=false,resizable=true}
        val id=SDL.getWindowID(valOf(!ObservedSDL.created))
        val ()=check(Driver.externalEvents,"external event capability")
        val undefined=IntInf.toInt(SDL.constant "SDL_WINDOWPOS_UNDEFINED")
        val ()=check(!ObservedSDL.positions=[(undefined,undefined)],"CW_USEDEFAULT position translation")
        val size=Driver.client window
        val ()=check(#width size>0 andalso #height size>0,"client rectangle")
        val ()=Driver.title(window,"WTF-8 display \237\160\128")
        val ()=Driver.show(window,5)
        val ()=Driver.show(window,0)
        val ()=Driver.show(window,10)
        val ()=Driver.show(window,0)
        val drawing=Driver.begin{window=window,rectangle={left=Int32.fromInt 0,top=Int32.fromInt 0,
          right=Int32.fromInt(#width size),bottom=Int32.fromInt(#height size)}}
        val ()=check(rejected(fn()=>Driver.destroy window),"active drawing prevents window destruction")
        val rectangle={left=Int32.fromInt 1,top=Int32.fromInt 2,right=Int32.fromInt 20,bottom=Int32.fromInt 30}
        val ()=Driver.fill{drawing=drawing,rectangle=rectangle,colour=0wx00332211}
        val ()=Driver.line{drawing=drawing,x1=0,y1=0,x2=10,y2=4,width=3,colour=0wx00332211}
        val ()=Driver.text{drawing=drawing,x=1,y=1,text="Rune",colour=0wx00332211,opaque=true,background=0wx00FFFFFF}
        val ()=check(!ObservedSDL.lines=3 andalso !ObservedSDL.fills=2 andalso !ObservedSDL.texts=["Rune"],"drawing projection")
        val ()=check(List.exists(fn{red,green,blue,alpha}=>red=17 andalso green=34 andalso blue=51 andalso alpha=255)(!ObservedSDL.colours),"Win32 COLORREF channels")
        val ()=check(unsupported(fn()=>Driver.text{drawing=drawing,x=0,y=0,text="\206\187",colour=0w0,opaque=false,background=0w0}),"explicit ASCII text limit")
        val ()=Driver.finish drawing
        val ()=check(rejected(fn()=>Driver.finish drawing),"drawing scope closes once")
        val ()=drain 2048
        val ()=SDL.pushEvent(SDL.Key{window=id,down=true,repeated=true,key=0wx61,scan=4,modifiers=Word16.fromLargeInt(SDL.constant "SDL_KMOD_SHIFT")})
        val _=message(fn T.KeyDown{key,repeated}=>key=0wx41 andalso repeated | _=>false)
        val ()=check(true,"virtual key normalization")
        val ()=SDL.pushEvent(SDL.MouseMotion{window=id,x=5.75,y= ~2.5,buttons=0wx3})
        val _=message(fn T.MouseMove{x,y,buttons}=>x=5 andalso y= ~3 andalso buttons=0wx15 | _=>false)
        val ()=check(true,"mouse buttons, modifier flags and coordinates")
        val ()=SDL.pushEvent(SDL.Text{window=id,text="\206\187\240\159\152\128"})
        val a=message(fn T.Char _=>true | _=>false)
        val b=message(fn T.Char _=>true | _=>false)
        val d=message(fn T.Char _=>true | _=>false)
        val ()=check(a=T.Char 0wx03BB andalso b=T.Char 0wxD83D andalso d=T.Char 0wxDE00,"UTF-16 character units")
        val ()=SDL.pushEvent(SDL.Window{window=id,kind=c "SDL_EVENT_WINDOW_EXPOSED",data1=0,data2=0})
        val _=message(fn T.Paint=>true | _=>false)
        val ()=check(true,"paint event normalization")
        val ()=SDL.pushEvent(SDL.Window{window=id,kind=c "SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED",data1=90,data2=70})
        val _=message(fn T.Size{width,height}=>width=90 andalso height=70 | _=>false)
        val ()=check(true,"resize event normalization")
        val ()=SDL.pushEvent(SDL.Window{window=id,kind=c "SDL_EVENT_WINDOW_CLOSE_REQUESTED",data1=0,data2=0})
        val _=message(fn T.Close=>true | _=>false)
        val ()=check(true,"close remains a model message")
        val started=Driver.ticks()
        val ()=Driver.delay 0w1
        val ()=check(Driver.ticks()>=started andalso Driver.frequency()>Int64.fromInt 0 andalso Driver.counter()>Int64.fromInt 0,"monotonic clocks")
        val ()=Driver.destroy window
        val ()=check(rejected(fn()=>ignore(Driver.client window)),"closed window")
        val pixelWindow=Driver.create{title="paint pixels",x= ~2147483648,y= ~2147483648,width=8,height=8,visible=false,resizable=true}
        val pixelNative=valOf(!ObservedSDL.created)
        val pixelSize=Driver.client pixelWindow
        fun rect(x,y,right,bottom)={left=Int32.fromInt x,top=Int32.fromInt y,right=Int32.fromInt right,bottom=Int32.fromInt bottom}
        val whole=rect(0,0,#width pixelSize,#height pixelSize)
        fun paint rectangle colour=
          let val scope=Driver.begin{window=pixelWindow,rectangle=rectangle}
              val ()=(Driver.fill{drawing=scope,rectangle=whole,colour=colour}
                handle e=>(Driver.finish scope;raise e))
          in Driver.finish scope end
        fun pixels expected=SDL.withSurfacePixels(hd(!ObservedSDL.surfaces))(fn{bytes,pitch,...}=>
          List.app(fn(x,y,wanted)=>
            let val offset=y*pitch+x*4
                val actual=ForeignBytes.value{signed=false,littleEndian= #littleEndian(RuneForeign.target()),
                  bytes=Byte.bytesToString(Word8ArraySlice.vector(Word8ArraySlice.slice(bytes,offset,SOME 4)))}
            in check(actual=wanted,"persistent clipped canvas pixel") end)expected)
        val ()=paint whole 0w0
        val ()=paint(rect(2,2,4,4))0wx000000FF
        val ()=pixels[(0,0,0xFF000000),(2,2,0xFFFF0000),(4,2,0xFF000000),(6,6,0xFF000000)]
        val ()=paint(rect(5,5,7,7))0wx00FF0000
        val ()=pixels[(0,0,0xFF000000),(2,2,0xFFFF0000),(5,5,0xFF0000FF)]
        val ()=paint(rect(1,1,1,3))0wx0000FF00
        val ()=pixels[(0,0,0xFF000000),(2,2,0xFFFF0000),(5,5,0xFF0000FF)]
        val requestedWidth= #width pixelSize+4 val requestedHeight= #height pixelSize+4
        val ()=SDL.setWindowSize(pixelNative,requestedWidth,requestedHeight)
        fun resized 0=raise Fail "SDL window resize did not settle" | resized n=
          let val size=Driver.client pixelWindow
          in if #width size>=requestedWidth andalso #height size>=requestedHeight then size
             else (ignore(Driver.poll());Driver.delay 0w1;resized(n-1)) end
        val enlarged=resized 1000
        val empty=rect(#width enlarged,#height enlarged,#width enlarged,#height enlarged)
        val scope=Driver.begin{window=pixelWindow,rectangle=empty}
        val ()=Driver.finish scope
        val ()=pixels[(2,2,0xFFFF0000),(5,5,0xFF0000FF),(#width pixelSize+1,#height pixelSize+1,0xFF000000)]
        val ()=Driver.destroy pixelWindow
        val ()=Driver.shutdown()
        val ()=check(RuneForeign.live()=baseline,"driver shutdown releases native resources")
    in print("PASS SDL Win32 driver: " ^ Int.toString(!count) ^ " checks\n") end
end
val ()=Win32SDLDriverChecks.main(CommandLine.arguments()) handle e=>
  (TextIO.output(TextIO.stdErr,"FAIL SDL Win32 driver: " ^ (case e of
    Win32Common.Types.Error{function,code}=>function ^ ": " ^ Word32.toString code
  | Win32Common.Types.Unsupported text=>text | SDL.Error{function,message}=>function ^ ": " ^ message
  | RuneForeign.Error{message,...}=>message | _=>General.exnMessage e) ^ "\n");OS.Process.exit OS.Process.failure)

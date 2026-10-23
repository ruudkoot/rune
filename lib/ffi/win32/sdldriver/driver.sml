(* Implements: WIN32_SDL_DRIVER *)
functor Win32SdlDriverFn (structure Sdl : SDL) :> WIN32_SDL_DRIVER =
struct
  structure T = Win32Common.Types
  type canvas = {surface:Sdl.surface,renderer:Sdl.renderer,width:int,height:int}
  datatype window = Window of {native:Sdl.window,renderer:Sdl.renderer option ref,
    canvas:canvas option ref,retired:canvas list ref,id:Word32.word,closed:bool ref,drawings:int ref}
  datatype drawing = Drawing of {window:window,canvas:canvas,rectangle:T.rect,active:bool ref}
  datatype event = Quit | Message of window * T.message
  val externalEvents=true
  val windows=ref([]:window list)
  val pending=ref([]:event list)
  val modifiers=ref(0w0:Word16.word)
  val loaded=ref false
  fun error name code=raise T.Error{function=name,code=Word32.fromInt code}
  fun protect name body=body() handle
      Sdl.Error{message,...}=>raise T.Unsupported(name ^ ": " ^ message)
    | Sdl.Unsupported message=>raise T.Unsupported message
    | Sdl.Closed=>error name 6
    | Sdl.Busy=>error name 170
    | ForeignText.Error _=>error name 1113
    | Domain=>error name 87
    | Size=>error name 87
    | Overflow=>error name 87
    | RuneForeign.Error{native,...}=>raise T.Error{function=name,code=if native=0w0 then 0w31 else native}
  fun constant name=Sdl.constant name
  fun live(Window{closed,...})=not(!closed)
  fun native(window as Window{native,...})=if live window then native else error "SDL window" 1400
  fun displayRenderer(window as Window{renderer,...})=
    if not(live window) then error "SDL renderer" 1400 else
    case !renderer of SOME r=>r | NONE=>error "SDL renderer" 6
  fun find id=List.find(fn window as Window{id=other,...}=>live window andalso id=other)(!windows)
  fun displayText text=
    let val units=ForeignText.encode{encoding=ForeignText.Utf16,littleEndian=true,terminated=false,text=text}
        val normalized=ForeignText.decode{encoding=ForeignText.Utf16,littleEndian=true,terminated=false,bytes=units}
        fun loop(index,parts)=if index=size normalized then String.concat(rev parts) else
          if Char.ord(String.sub(normalized,index))=237 andalso index+2<size normalized andalso
             Char.ord(String.sub(normalized,index+1))>=160 andalso Char.ord(String.sub(normalized,index+1))<=191
          then loop(index+3,"\239\191\189"::parts)
          else loop(index+1,str(String.sub(normalized,index))::parts)
    in loop(0,[]) end
  fun load paths=protect "SDL load" (fn()=>
    if !loaded then error "SDL load" 170 else
    (Sdl.load paths;
     ((Sdl.setHint("SDL_QUIT_ON_LAST_WINDOW_CLOSE","0");
       Sdl.init(Word32.fromLargeInt(constant "SDL_INIT_VIDEO"));loaded:=true)
      handle e=>((Sdl.quit() handle _=>());(Sdl.unload() handle _=>());raise e))))
  fun shutdown ()=protect "SDL shutdown"(fn()=>
    if not(null(!windows)) then error "SDL shutdown" 170 else
    (Sdl.quit();Sdl.unload();loaded:=false;pending:=[];modifiers:=0w0))
  fun position value=if IntInf.fromInt value= ~2147483648 then IntInf.toInt(constant "SDL_WINDOWPOS_UNDEFINED") else value
  fun onFailure action cleanup=action() handle e=>
    (List.app(fn release=>(release() handle _=>()))cleanup;raise e)
  fun complete actions=
    let val first=ref(NONE:exn option)
        fun attempt action=action() handle e=>if isSome(!first) then () else first:=SOME e
        val ()=List.app attempt actions
    in case !first of NONE=>() | SOME e=>raise e end
  fun closeCanvas({surface,renderer,...}:canvas)=complete
    [fn()=>Sdl.destroyRenderer renderer handle Sdl.Closed=>(),fn()=>Sdl.destroySurface surface handle Sdl.Closed=>()]
  fun makeCanvas{width,height}=
    let val width=Int.max(1,width) val height=Int.max(1,height)
        val surface=Sdl.createSurface{width=width,height=height,format=Word32.fromLargeInt(constant "SDL_PIXELFORMAT_ARGB8888")}
        val render=onFailure(fn()=>Sdl.createSoftwareRenderer surface)[fn()=>Sdl.destroySurface surface]
        val ()=onFailure(fn()=>(Sdl.setRenderDrawColor(render,{red=0,green=0,blue=0,alpha=255});
          Sdl.renderClear render;Sdl.renderPresent render))[fn()=>Sdl.destroyRenderer render,fn()=>Sdl.destroySurface surface]
    in {surface=surface,renderer=render,width=width,height=height}:canvas end
  fun cleanupRetired(Window{retired,...})=
    let fun loop()=case !retired of []=>() | old::rest=>(closeCanvas old;retired:=rest;loop())
    in loop() end
  fun ensureCanvas(window as Window{canvas,retired,drawings,...})=
    let val ()=cleanupRetired window
        val dimensions=Sdl.getWindowSize(native window)
        val width=Int.max(1,#width dimensions) val height=Int.max(1,#height dimensions)
    in case !canvas of SOME old=>
      if #width old=width andalso #height old=height then old
      else if !drawings<>0 then error "SDL resize canvas" 170 else
        let val replacement=makeCanvas{width=width,height=height}
            val rectangle=SOME{x=0,y=0,width=Int.min(#width old,width),height=Int.min(#height old,height)}
            val ()=onFailure(fn()=>(Sdl.renderPresent(#renderer old);
              Sdl.blitSurface{source= #surface old,sourceRect=rectangle,destination= #surface replacement,destinationRect=rectangle}))
              [fn()=>closeCanvas replacement]
            val ()=canvas:=SOME replacement
            val ()=retired:=old:: !retired
            val ()=cleanupRetired window
        in replacement end
    | NONE=>let val replacement=makeCanvas{width=width,height=height}
      in canvas:=SOME replacement;replacement end end
  fun create{title,width,height,x,y,visible,resizable}=protect "SDL createWindow"(fn()=>
    let val flags=Word64.orb(if visible then 0w0 else Word64.fromLargeInt(constant "SDL_WINDOW_HIDDEN"),
          if resizable then Word64.fromLargeInt(constant "SDL_WINDOW_RESIZABLE") else 0w0)
        val handleWindow=Sdl.createWindow{title=displayText title,width=width,height=height,flags=flags}
        val id=onFailure(fn()=>Sdl.getWindowID handleWindow)[fn()=>Sdl.destroyWindow handleWindow]
        val ()=onFailure(fn()=>Sdl.setWindowPosition(handleWindow,position x,position y))[fn()=>Sdl.destroyWindow handleWindow]
        val handleRenderer=onFailure(fn()=>Sdl.createRenderer(handleWindow,SOME "software"))[fn()=>Sdl.destroyWindow handleWindow]
        val backing=onFailure(fn()=>makeCanvas(Sdl.getWindowSize handleWindow))
          [fn()=>Sdl.destroyRenderer handleRenderer,fn()=>Sdl.destroyWindow handleWindow]
        val ()=onFailure(fn()=>Sdl.startTextInput handleWindow)
          [fn()=>closeCanvas backing,fn()=>Sdl.destroyRenderer handleRenderer,fn()=>Sdl.destroyWindow handleWindow]
        val window=Window{native=handleWindow,renderer=ref(SOME handleRenderer),canvas=ref(SOME backing),retired=ref[],
          id=id,closed=ref false,drawings=ref 0}
    in windows:=window:: !windows;window end)
  fun destroy(window as Window{renderer=render,canvas,retired,closed,drawings,...})=protect "SDL destroyWindow"(fn()=>
    if not(live window) then error "SDL destroyWindow" 1400 else if !drawings<>0 then error "SDL destroyWindow" 170 else
    (case !canvas of NONE=>() | SOME old=>(retired:=old:: !retired;canvas:=NONE);
     cleanupRetired window;
     (case !render of NONE=>() | SOME r=>(Sdl.destroyRenderer r;render:=NONE));
     Sdl.destroyWindow(native window);closed:=true;windows:=List.filter(fn w=>w<>window)(!windows);
     pending:=List.filter(fn Message(w,_)=>w<>window | Quit=>true)(!pending)))
  fun show(window,command)=protect "SDL showWindow"(fn()=>
    if command=0 then Sdl.hideWindow(native window)
    else if command=1 orelse command=5 orelse command=8 orelse command=9 orelse command=10 then Sdl.showWindow(native window)
    else raise T.Unsupported "SDL visibility command is outside the shared GUI subset")
  fun title(window,text)=protect "SDL setWindowText"(fn()=>Sdl.setWindowTitle(native window,displayText text))
  fun client window=protect "SDL getClientRect"(fn()=>Sdl.getWindowSize(native window))
  fun clip({left,top,right,bottom}:T.rect)=
    {x=Int32.toInt left,y=Int32.toInt top,width=Int.max(0,Int32.toInt right-Int32.toInt left),
     height=Int.max(0,Int32.toInt bottom-Int32.toInt top)}
  fun begin{window=window as Window{drawings,...},rectangle}=protect "SDL beginPaint"(fn()=>
    let val backing=ensureCanvas window
        val ()=Sdl.setRenderClipRect(#renderer backing,SOME(clip rectangle))
    in drawings:= !drawings+1;Drawing{window=window,canvas=backing,rectangle=rectangle,active=ref true} end)
  fun drawing(Drawing{window,canvas,rectangle,active})=
    if not(!active) then error "SDL drawing" 6 else
      (ignore(native window);Sdl.setRenderClipRect(#renderer canvas,SOME(clip rectangle));#renderer canvas)
  fun present window (backing:canvas)=
    let val display=displayRenderer window
        val texture=Sdl.createTextureFromSurface(display,#surface backing)
    in ForeignScope.withScope(fn scope=>
      (ignore(ForeignScope.defer(scope,fn()=>Sdl.destroyTexture texture));
       Sdl.setRenderClipRect(display,NONE);Sdl.renderTexture(display,texture,NONE,NONE);Sdl.renderPresent display)) end
  fun finish(Drawing{window=window as Window{drawings,...},canvas,active,...})=protect "SDL endPaint"(fn()=>
    if not(!active) then error "SDL endPaint" 6 else
    ForeignScope.withScope(fn scope=>
      (ignore(ForeignScope.defer(scope,fn()=>(active:=false;drawings:= !drawings-1)));
       complete[fn()=>Sdl.setRenderClipRect(#renderer canvas,NONE),fn()=>Sdl.renderPresent(#renderer canvas),fn()=>present window canvas])))
  fun colour value={red=Word32.toInt(Word32.andb(value,0wxFF)),
    green=Word32.toInt(Word32.andb(Word32.>>(value,0w8),0wxFF)),
    blue=Word32.toInt(Word32.andb(Word32.>>(value,0w16),0wxFF)),alpha=255}
  fun fill{drawing=value,rectangle={left,top,right,bottom}:T.rect,colour=rgb}=protect "SDL fillRect"(fn()=>
    let val render=drawing value val x=Int32.toInt left val y=Int32.toInt top
        val width=Int32.toInt right-x val height=Int32.toInt bottom-y
    in if width<=0 orelse height<=0 then () else
      (Sdl.setRenderDrawColor(render,colour rgb);Sdl.renderFillRect(render,SOME{x=Real.fromInt x,y=Real.fromInt y,
        width=Real.fromInt width,height=Real.fromInt height})) end)
  fun line{drawing=value,x1,y1,x2,y2,width,colour=rgb}=protect "SDL lineTo"(fn()=>
    if width<=0 then error "SDL lineTo" 87 else
    let val render=drawing value
        val horizontal=IntInf.abs(IntInf.-(IntInf.fromInt x2,IntInf.fromInt x1))>=IntInf.abs(IntInf.-(IntInf.fromInt y2,IntInf.fromInt y1))
        fun draw n=if n=width then () else
          let val delta=Real.fromInt n-Real.fromInt(width div 2)
              val dx=if horizontal then 0.0 else delta val dy=if horizontal then delta else 0.0
          in Sdl.renderLine(render,Real.fromInt x1+dx,Real.fromInt y1+dy,Real.fromInt x2+dx,Real.fromInt y2+dy);draw(n+1) end
    in Sdl.setRenderDrawColor(render,colour rgb);draw 0 end)
  fun text{drawing=value,x,y,text=content,colour=rgb,opaque,background}=protect "SDL textOut"(fn()=>
    let val ()=if CharVector.all(fn c=>c>= #" " andalso c<= #"~")content then ()
          else raise T.Unsupported "SDL Win32 text rendering accepts printable ASCII with its fixed 8 by 8 font"
        val render=drawing value
        val ()=if not opaque then () else
          (Sdl.setRenderDrawColor(render,colour background);Sdl.renderFillRect(render,SOME{x=Real.fromInt x,y=Real.fromInt y,
            width=Real.fromInt(size content)*8.0,height=8.0}))
    in Sdl.setRenderDrawColor(render,colour rgb);Sdl.renderDebugText(render,Real.fromInt x,Real.fromInt y,content) end)
  val scanNames=[("RIGHT",39),("LEFT",37),("DOWN",40),("UP",38),("INSERT",45),("HOME",36),("PAGEUP",33),("DELETE",46),("END",35),("PAGEDOWN",34),
    ("NUMLOCKCLEAR",144),("CAPSLOCK",20),("SCROLLLOCK",145),("PAUSE",19),("LCTRL",17),("RCTRL",17),("LSHIFT",16),("RSHIFT",16),
    ("LALT",18),("RALT",18),("LGUI",91),("RGUI",92)] @ List.tabulate(24,fn n=>("F" ^ Int.toString(n+1),112+n))
  fun keyCode(key,scan)=
    let val n=Word32.toLargeInt key
        val punctuation=[(59,186),(61,187),(44,188),(45,189),(46,190),(47,191),(96,192),(91,219),(92,220),(93,221),(39,222)]
    in if n>=97 andalso n<=122 then SOME(Word32.fromLargeInt(IntInf.-(n,32)))
       else if n>=48 andalso n<=57 orelse n>=65 andalso n<=90 orelse n=8 orelse n=9 orelse n=13 orelse n=27 orelse n=32 then SOME key
       else case List.find(fn(code,_)=>IntInf.fromInt code=n)punctuation of SOME(_,code)=>SOME(Word32.fromInt code)
       | NONE=>(case List.find(fn(name,_)=>constant("SDL_SCANCODE_" ^ name)=IntInf.fromInt scan)scanNames of
           SOME(_,code)=>SOME(Word32.fromInt code) | NONE=>NONE) end
  fun mouseButtons state=
    let val pairs=[(0wx1,0wx1),(0wx2,0wx10),(0wx4,0wx2),(0wx8,0wx20),(0wx10,0wx40)]
        val buttons=List.foldl(fn((from,to),result)=>if Word32.andb(state,from)<>0w0 then Word32.orb(result,to) else result)0w0 pairs
        fun modifier(name,bit)=if Word16.andb(!modifiers,Word16.fromLargeInt(constant name))<>0w0 then bit else 0w0
    in Word32.orb(buttons,Word32.orb(modifier("SDL_KMOD_SHIFT",0wx4),modifier("SDL_KMOD_CTRL",0wx8))) end
  fun characters(window,content)=
    let val bytes=ForeignText.encode{encoding=ForeignText.Utf16,littleEndian=true,terminated=false,text=content}
    in List.tabulate(size bytes div 2,fn i=>Message(window,T.Char(Word16.fromLargeInt
      (ForeignBytes.value{signed=false,littleEndian=true,bytes=String.substring(bytes,i*2,2)})))) end
  fun poll ()=protect "SDL event"(fn()=>
    let fun message id body=case find id of NONE=>NONE | SOME window=>SOME(Message(window,body))
        fun event(Sdl.Quit)=SOME Quit
          | event(Sdl.Window{window,kind,data1,data2})=
              if Word32.toLargeInt kind=constant "SDL_EVENT_WINDOW_RESIZED" orelse Word32.toLargeInt kind=constant "SDL_EVENT_WINDOW_PIXEL_SIZE_CHANGED"
                then message window(T.Size{width=data1,height=data2})
              else if Word32.toLargeInt kind=constant "SDL_EVENT_WINDOW_EXPOSED" then message window T.Paint
              else if Word32.toLargeInt kind=constant "SDL_EVENT_WINDOW_CLOSE_REQUESTED" then message window T.Close else NONE
          | event(Sdl.Key{window,down,repeated,key,scan,modifiers=mods})=
              (modifiers:=mods;case keyCode(key,scan) of NONE=>NONE
                | SOME key=>message window(if down then T.KeyDown{key=key,repeated=repeated} else T.KeyUp key))
          | event(Sdl.Text{window, text})=(case find window of NONE=>NONE | SOME handleWindow=>
              (case characters(handleWindow,text) of []=>NONE | first::rest=>(pending:=rest;SOME first)))
          | event(Sdl.MouseMotion{window,x,y,buttons})=message window(T.MouseMove{x=Real.floor x,y=Real.floor y,buttons=mouseButtons buttons})
          | event(Sdl.MouseButton{window,down,button,x,y,...})=message window
              (if down then T.ButtonDown{button=button,x=Real.floor x,y=Real.floor y} else T.ButtonUp{button=button,x=Real.floor x,y=Real.floor y})
          | event(Sdl.Unknown _)=NONE
        fun next remaining=case !pending of first::rest=>(pending:=rest;SOME first) | []=>
          if remaining=0 then NONE else case Sdl.pollEvent() of NONE=>NONE | SOME source=>case event source of NONE=>next(remaining-1) | some=>some
    in next 1024 end)
  fun ticks ()=protect "SDL clock"(fn()=>Word64.toLargeInt(Sdl.getTicks()))
  fun counter ()=protect "SDL counter"(fn()=>Int64.fromLarge(Word64.toLargeInt(Sdl.getPerformanceCounter())))
  fun frequency ()=protect "SDL frequency"(fn()=>Int64.fromLarge(Word64.toLargeInt(Sdl.getPerformanceFrequency())))
  fun delay milliseconds=protect "SDL delay"(fn()=>Sdl.delay milliseconds)
end

(* Implements: SDL *)
functor SDLFn (structure Raw : SDL_NATIVE_RAW
               structure Layout : SDL_NATIVE_LAYOUT) :> SDL =
struct
  type rect = {x : int, y : int, width : int, height : int}
  type frect = {x : real, y : real, width : real, height : real}
  datatype event = Quit
    | Window of {window : Word32.word, kind : Word32.word, data1 : int, data2 : int}
    | Key of {window : Word32.word, down : bool, repeated : bool, key : Word32.word,
              scan : int, modifiers : Word16.word}
    | Text of {window : Word32.word, text : string}
    | MouseMotion of {window : Word32.word, x : real, y : real, buttons : Word32.word}
    | MouseButton of {window : Word32.word, down : bool, button : int, clicks : int, x : real, y : real}
    | Unknown of Word32.word
  exception Error of {function : string, message : string}
  exception Unsupported of string
  exception Closed
  exception Busy
  datatype handleValue = Handle of {owner : ForeignOwner.owner ref, children : int ref,
    parent : int ref option, locks : int ref}
  type window = handleValue
  type surface = handleValue
  type renderer = handleValue
  type texture = handleValue
  val loaded = ref (NONE : Raw.session option)
  val initialized = ref false
  val ready = ref false
  val resources = ref 0
  val queuedText = ref ([] : ForeignMemory.buffer list)
  fun session () = case !loaded of SOME s => s | NONE => raise Closed
  fun constant name = Layout.constant name
  fun call name arguments = Raw.call (session ()) name arguments
  fun signed n = RuneForeign.Signed (Int64.fromInt n)
  fun unsigned n = RuneForeign.Unsigned (Word64.fromLargeInt n)
  fun address p = RuneForeign.Address (SOME p)
  val null = RuneForeign.Address NONE
  fun integer signed bytes = ForeignBytes.value {signed=signed,littleEndian=true,bytes=bytes}
  fun status (r : RuneForeign.result) = integer false (#bytes r) <> 0
  fun word32 (r : RuneForeign.result) = Word32.fromLargeInt (integer false (#bytes r))
  fun word64 (r : RuneForeign.result) = Word64.fromLargeInt (integer false (#bytes r))
  fun release p = RuneForeign.release p
  fun withPointer r body = case #pointer (r : RuneForeign.result) of NONE => body NONE
    | SOME p => ForeignScope.withScope (fn scope =>
        (ignore(ForeignScope.defer(scope,fn()=>release p));body(SOME p)))
  fun cString pointer =
    let fun read (offset, chunks) =
          if offset=1048576 then raise Size else
          let val byte=RuneForeign.read(pointer,Word64.fromInt offset,1)
          in if byte="\000" then ForeignText.decode{encoding=ForeignText.Utf8,
               littleEndian=Layout.littleEndian,terminated=false,bytes=String.concat(rev chunks)}
             else read(offset+1,byte::chunks) end
    in read(0,[]) end
  fun getError () = withPointer (call "SDL_GetError" [])
    (fn NONE=>"SDL returned a null error string" | SOME p=>cString p)
  fun failed name = raise Error {function=name,message=getError ()}
  fun checked name arguments =
    let val result=call name arguments in if status result then () else failed name end
  fun unitCall name arguments = ignore(call name arguments)
  fun withString text body =
    let val bytes=ForeignText.encode{encoding=ForeignText.Utf8,littleEndian=Layout.littleEndian,terminated=false,text=text}
        val ()=if String.isSubstring "\000" bytes then raise Domain else ()
    in ForeignMemory.withBytes(bytes ^ "\000")(fn buffer=>body(address(ForeignMemory.raw buffer))) end
  fun withOptionalString NONE body=body null
    | withOptionalString(SOME text)body=withString text body
  fun withHandle(Handle{owner,...}) body=ForeignOwner.withBorrow(!owner) body
    handle ForeignOwner.Closed=>raise Closed | ForeignOwner.Busy=>raise Busy
  fun depend (Handle{children,...})=children
  fun adopt name parent result = case #pointer (result : RuneForeign.result) of NONE=>failed name
    | SOME pointer=>
      let val destructor=case name of "SDL_CreateWindow"=>"SDL_DestroyWindow"
            | "SDL_CreateRenderer"=>"SDL_DestroyRenderer" | "SDL_CreateSoftwareRenderer"=>"SDL_DestroyRenderer"
            | "SDL_CreateTextureFromSurface"=>"SDL_DestroyTexture" | _=>"SDL_DestroySurface"
          val call=Raw.prepare(session())destructor
          val owner=(ForeignOwner.adopt{pointer=pointer,destructor={call=call,
            arguments=fn p=>[address p],failure=RuneForeign.NoFailure}}
            handle ForeignOwner.AlreadyOwned=>(RuneForeign.release pointer;raise ForeignOwner.AlreadyOwned)
              | e=>(ignore(RuneForeign.dispose{resource=pointer,call=call,
              arguments=[address pointer],failure=RuneForeign.NoFailure});raise e))
          val ()=Option.app(fn n=>n:= !n+1)parent
          val ()=resources:= !resources+1
      in Handle{owner=ref owner,children=ref 0,parent=parent,locks=ref 0} end
  fun destroy(Handle{owner,children,parent,locks})=
    if !children<>0 orelse !locks<>0 then raise Busy else
    (ForeignOwner.close(!owner);resources:= !resources-1;Option.app(fn n=>n:= !n-1)parent)
    handle ForeignOwner.Closed=>raise Closed | ForeignOwner.Busy=>raise Busy
  fun load libraries =
    let val ()=case !loaded of NONE=>() | SOME _=>raise Busy
        val target=RuneForeign.target()
        val ()=if #pointerBytes target=Layout.pointerBytes andalso #littleEndian target=Layout.littleEndian
          then () else raise Unsupported "generated SDL target differs from this runtime"
        val native=Raw.openSession{libraries=libraries}
        val ()=(List.app(fn name=>ignore(Raw.prepare native name))
          ["SDL_DestroyWindow","SDL_DestroySurface","SDL_DestroyRenderer","SDL_DestroyTexture","SDL_free"]
          handle e=>((Raw.closeSession native handle _=>());raise e))
    in loaded:=SOME native end
  fun unload () = if !resources<>0 orelse !initialized then raise Busy else
    let val s=session() in Raw.closeSession s;loaded:=NONE;ready:=false end
  fun setMainReady () = if !ready then () else (unitCall "SDL_SetMainReady" [];ready:=true)
  fun init flags=(setMainReady();checked "SDL_Init" [unsigned(Word32.toLargeInt flags)];initialized:=true)
  fun initSubSystem flags=(setMainReady();checked "SDL_InitSubSystem" [unsigned(Word32.toLargeInt flags)];initialized:=true)
  fun quitSubSystem flags=if !resources<>0 then raise Busy
    else unitCall "SDL_QuitSubSystem" [unsigned(Word32.toLargeInt flags)]
  fun quit ()=if !resources<>0 then raise Busy else
    (unitCall "SDL_Quit" [];List.app ForeignMemory.release (!queuedText);queuedText:=[];initialized:=false)
  fun clearError ()=checked "SDL_ClearError" []
  fun createWindow{title,width,height,flags}=withString title(fn title=>
    adopt "SDL_CreateWindow" NONE(call "SDL_CreateWindow" [title,signed width,signed height,RuneForeign.Unsigned flags]))
  val destroyWindow=destroy
  fun getWindowID window=withHandle window(fn p=>
    let val result=call "SDL_GetWindowID" [address p] val value=word32 result
    in if value=0w0 then failed "SDL_GetWindowID" else value end)
  fun setWindowTitle(window,title)=withHandle window(fn p=>withString title(fn text=>checked "SDL_SetWindowTitle" [address p,text]))
  fun objectRead (buffer,offset,length)=ForeignMemory.read(buffer,offset,length)
  fun intAt(buffer,offset,width)=IntInf.toInt(ForeignBytes.value{signed=true,littleEndian=Layout.littleEndian,bytes=objectRead(buffer,offset,width)})
  fun wordAt(buffer,offset,width)=ForeignBytes.value{signed=false,littleEndian=Layout.littleEndian,bytes=objectRead(buffer,offset,width)}
  fun realAt(buffer,offset)=ForeignBytes.real32Value{littleEndian=Layout.littleEndian,bytes=objectRead(buffer,offset,4)}
  fun putInt(buffer,offset,width,n)=ForeignMemory.write(buffer,offset,ForeignBytes.integer{width=width,signed=true,littleEndian=Layout.littleEndian,value=IntInf.fromInt n})
  fun putWord(buffer,offset,width,n)=ForeignMemory.write(buffer,offset,ForeignBytes.integer{width=width,signed=false,littleEndian=Layout.littleEndian,value=n})
  fun putReal(buffer,offset,n)=ForeignMemory.write(buffer,offset,ForeignBytes.real32{littleEndian=Layout.littleEndian,value=n})
  fun withAllocation size body=ForeignScope.withScope(fn scope=>
    let val buffer=ForeignMemory.allocate size val _=ForeignScope.defer(scope,fn()=>ForeignMemory.release buffer)
    in body buffer end)
  fun getWindowSize window=withHandle window(fn p=>withAllocation 8(fn b=>
    let val w=ForeignMemory.slice(b,0,4) val h=ForeignMemory.slice(b,4,4)
    in ForeignScope.withScope(fn scope=>
      (ignore(ForeignScope.defer(scope,fn()=>ForeignMemory.release h));
       ignore(ForeignScope.defer(scope,fn()=>ForeignMemory.release w));
       checked "SDL_GetWindowSize" [address p,address(ForeignMemory.raw w),address(ForeignMemory.raw h)];
       {width=intAt(b,0,4),height=intAt(b,4,4)})) end))
  fun setWindowSize(window,w,h)=withHandle window(fn p=>checked "SDL_SetWindowSize" [address p,signed w,signed h])
  fun windowOperation name window=withHandle window(fn p=>checked name[address p])
  val showWindow=windowOperation "SDL_ShowWindow"
  val hideWindow=windowOperation "SDL_HideWindow"
  val startTextInput=windowOperation "SDL_StartTextInput"
  val stopTextInput=windowOperation "SDL_StopTextInput"
  fun eventOffset path=Layout.offset("SDL_Event",path)
  fun decodeEvent buffer=
    let fun w path width=wordAt(buffer,eventOffset path,width)
        fun i path=intAt(buffer,eventOffset path,4)
        fun f path=realAt(buffer,eventOffset path)
        fun id variant=Word32.fromLargeInt(w[variant,"windowID"]4)
        val kind=Word32.fromLargeInt(w["type"]4)
        fun is name=Word32.toLargeInt kind=constant name
    in if is "SDL_EVENT_QUIT" then Quit
      else if Word32.toLargeInt kind>=constant "SDL_EVENT_WINDOW_FIRST" andalso Word32.toLargeInt kind<=constant "SDL_EVENT_WINDOW_LAST"
        then Window{window=id "window",kind=kind,data1=i["window","data1"],data2=i["window","data2"]}
      else if is "SDL_EVENT_KEY_DOWN" orelse is "SDL_EVENT_KEY_UP" then
        Key{window=id "key",down=w["key","down"]1<>0,repeated=w["key","repeat"]1<>0,
          key=Word32.fromLargeInt(w["key","key"]4),scan=i["key","scancode"],modifiers=Word16.fromLargeInt(w["key","mod"]2)}
      else if is "SDL_EVENT_TEXT_INPUT" then
        let val pointer=call "rf_field_SDL_TextInputEvent_text_get" [address(ForeignMemory.raw buffer)]
            val (consumed,pending)=case #pointer pointer of NONE=>([],!queuedText)
              | SOME p=>List.partition(fn b=>RuneForeign.sameAddress(ForeignMemory.raw b,p))(!queuedText)
            val text=withPointer pointer(fn NONE=>"" | SOME p=>cString p)
            val ()=queuedText:=pending
            val ()=List.app ForeignMemory.release consumed
        in Text{window=id "text",text=text} end
      else if is "SDL_EVENT_MOUSE_MOTION" then MouseMotion{window=id "motion",x=f["motion","x"],y=f["motion","y"],buttons=Word32.fromLargeInt(w["motion","state"]4)}
      else if is "SDL_EVENT_MOUSE_BUTTON_DOWN" orelse is "SDL_EVENT_MOUSE_BUTTON_UP" then
        MouseButton{window=id "button",down=w["button","down"]1<>0,button=IntInf.toInt(w["button","button"]1),
          clicks=IntInf.toInt(w["button","clicks"]1),x=f["button","x"],y=f["button","y"]}
      else Unknown kind end
  fun eventCall name arguments = withAllocation(Layout.sizeOf "SDL_Event")(fn buffer=>
    let val result=call name(address(ForeignMemory.raw buffer)::arguments)
    in if status result then SOME(decodeEvent buffer) else NONE end)
  fun pollEvent ()=eventCall "SDL_PollEvent" []
  fun waitEvent ()=case eventCall "SDL_WaitEvent" [] of SOME e=>e | NONE=>failed "SDL_WaitEvent"
  fun waitEventTimeout milliseconds=eventCall "SDL_WaitEventTimeout" [signed milliseconds]
  fun pushEvent value=withAllocation(Layout.sizeOf "SDL_Event")(fn buffer=>
    let fun w path width value=putWord(buffer,eventOffset path,width,value)
        fun i path value=putInt(buffer,eventOffset path,4,value)
        fun f path value=putReal(buffer,eventOffset path,value)
        fun kind name=w["type"]4(constant name)
        fun id variant value=w[variant,"windowID"]4(Word32.toLargeInt value)
        fun push ()=checked "SDL_PushEvent" [address(ForeignMemory.raw buffer)]
    in case value of Quit=>(kind "SDL_EVENT_QUIT";push())
      | Window{window,kind=eventKind,data1,data2}=>(w["type"]4(Word32.toLargeInt eventKind);id "window" window;i["window","data1"]data1;i["window","data2"]data2;push())
      | Key{window,down,repeated,key,scan,modifiers}=>
          (kind(if down then "SDL_EVENT_KEY_DOWN" else "SDL_EVENT_KEY_UP");id "key" window;
           w["key","down"]1(if down then 1 else 0);w["key","repeat"]1(if repeated then 1 else 0);
           w["key","key"]4(Word32.toLargeInt key);i["key","scancode"]scan;w["key","mod"]2(Word16.toLargeInt modifiers);push())
      | Text{window,text}=>ForeignScope.withScope(fn scope=>
          let val bytes=ForeignText.encode{encoding=ForeignText.Utf8,littleEndian=Layout.littleEndian,terminated=false,text=text}
              val ()=if String.isSubstring "\000" bytes then raise Domain else ()
              val native=ForeignMemory.fromBytes(bytes ^ "\000")
              val ticket=ForeignScope.defer(scope,fn()=>ForeignMemory.release native)
              val ()=kind "SDL_EVENT_TEXT_INPUT" val ()=id "text" window
              val ()=unitCall "rf_field_SDL_TextInputEvent_text_set" [address(ForeignMemory.raw buffer),address(ForeignMemory.raw native)]
              val ()=push()
              val ()=queuedText:=native:: !queuedText
          in ForeignScope.cancel ticket end)
      | MouseMotion{window,x,y,buttons}=>(kind "SDL_EVENT_MOUSE_MOTION";id "motion" window;
          f["motion","x"]x;f["motion","y"]y;w["motion","state"]4(Word32.toLargeInt buttons);push())
      | MouseButton{window,down,button,clicks,x,y}=>(kind(if down then "SDL_EVENT_MOUSE_BUTTON_DOWN" else "SDL_EVENT_MOUSE_BUTTON_UP");id "button" window;
          w["button","button"]1(IntInf.fromInt button);w["button","down"]1(if down then 1 else 0);
          w["button","clicks"]1(IntInf.fromInt clicks);f["button","x"]x;f["button","y"]y;push())
      | Unknown _=>raise Unsupported "pushing an unknown event needs explicit raw SDL_Event storage" end)
  fun getKeyboardState ()=withAllocation 4(fn count=>
    let val result=call "SDL_GetKeyboardState" [address(ForeignMemory.raw count)]
        val n=intAt(count,0,4)
    in if n<0 then raise Size else withPointer result(fn NONE=>failed "SDL_GetKeyboardState" | SOME p=>
      ForeignScope.withScope(fn scope=>let val b=ForeignMemory.pointer{pointer=p,length=n}
        val _=ForeignScope.defer(scope,fn()=>ForeignMemory.release b)
        val bytes=ForeignMemory.read(b,0,n)
      in Vector.tabulate(n,fn i=>String.sub(bytes,i)<> #"\000") end)) end)
  fun getMouseState ()=withAllocation 8(fn b=>
    let val x=ForeignMemory.slice(b,0,4) val y=ForeignMemory.slice(b,4,4)
    in ForeignScope.withScope(fn scope=>
      (ignore(ForeignScope.defer(scope,fn()=>ForeignMemory.release y));ignore(ForeignScope.defer(scope,fn()=>ForeignMemory.release x));
       let val buttons=word32(call "SDL_GetMouseState" [address(ForeignMemory.raw x),address(ForeignMemory.raw y)])
       in {buttons=buttons,x=realAt(b,0),y=realAt(b,4)} end)) end)
  fun createSurface{width,height,format}=adopt "SDL_CreateSurface" NONE
    (call "SDL_CreateSurface" [signed width,signed height,(if Layout.enumSigned then RuneForeign.Signed(Int64.fromLarge(Word32.toLargeInt format)) else unsigned(Word32.toLargeInt format))])
  val destroySurface=destroy
  fun lockSurface(surface as Handle{locks,...})=withHandle surface(fn p=>(checked "SDL_LockSurface" [address p];locks:= !locks+1))
  fun unlockSurface(surface as Handle{locks,...})=if !locks=0 then raise Busy else
    withHandle surface(fn p=>(unitCall "SDL_UnlockSurface" [address p];locks:= !locks-1))
  fun withSurfacePixels surface body=
    let val ()=lockSurface surface
    in ForeignScope.withScope(fn scope=>
      (ignore(ForeignScope.defer(scope,fn()=>unlockSurface surface));withHandle surface(fn pointer=>
       let val object=ForeignMemory.pointer{pointer=pointer,length=Layout.sizeOf "SDL_Surface"}
           val _=ForeignScope.defer(scope,fn()=>ForeignMemory.release object)
           fun offset name=Layout.offset("SDL_Surface",[name])
           val width=intAt(object,offset "w",4) val height=intAt(object,offset "h",4) val pitch=intAt(object,offset "pitch",4)
           val format=Word32.fromLargeInt(wordAt(object,offset "format",4))
           val ()=if Word32.>>(format,0w28)=0w1 then ()
             else raise Unsupported "pixel scopes require an uncompressed SDL pixel format"
           val ()=if width>=0 andalso height>=0 andalso pitch>=0 then () else raise Size
           val length=pitch*height
           val result=call "rf_field_SDL_Surface_pixels_get" [address pointer]
       in withPointer result(fn NONE=>raise Unsupported "surface has no accessible pixels" | SOME p=>
         ForeignScope.withScope(fn pixelScope=>
         let val pixels=ForeignMemory.pointer{pointer=p,length=length}
             val _=ForeignScope.defer(pixelScope,fn()=>ForeignMemory.release pixels)
             val array=Word8Array.fromList(List.map(Byte.charToByte)(String.explode(ForeignMemory.read(pixels,0,length))))
             val _=ForeignScope.defer(pixelScope,fn()=>ForeignMemory.write(pixels,0,Byte.bytesToString(Word8Array.vector array)))
         in body{bytes=array,pitch=pitch,width=width,height=height,format=format} end)) end))) end
  fun withRect kind NONE body=body null
    | withRect kind (SOME{x,y,width,height}:rect option) body=withAllocation(Layout.sizeOf kind)(fn b=>
        (List.app(fn(name,n)=>putInt(b,Layout.offset(kind,[name]),4,n))[("x",x),("y",y),("w",width),("h",height)];body(address(ForeignMemory.raw b))))
  fun withFRect NONE body=body null
    | withFRect(SOME{x,y,width,height}:frect option)body=withAllocation(Layout.sizeOf "SDL_FRect")(fn b=>
        (List.app(fn(name,n)=>putReal(b,Layout.offset("SDL_FRect",[name]),n))[("x",x),("y",y),("w",width),("h",height)];body(address(ForeignMemory.raw b))))
  fun fillSurfaceRect(surface,rect,color)=withHandle surface(fn p=>withRect "SDL_Rect" rect(fn rect=>checked "SDL_FillSurfaceRect" [address p,rect,unsigned(Word32.toLargeInt color)]))
  fun blitSurface{source,sourceRect,destination,destinationRect}=withHandle source(fn src=>withHandle destination(fn dst=>
    withRect "SDL_Rect" sourceRect(fn sr=>withRect "SDL_Rect" destinationRect(fn dr=>checked "SDL_BlitSurface" [address src,sr,address dst,dr]))))
  fun createRenderer(window,name)=withHandle window(fn p=>withOptionalString name(fn name=>
    adopt "SDL_CreateRenderer" (SOME(depend window))(call "SDL_CreateRenderer" [address p,name])))
  fun createSoftwareRenderer surface=withHandle surface(fn p=>
    adopt "SDL_CreateSoftwareRenderer" (SOME(depend surface))(call "SDL_CreateSoftwareRenderer" [address p]))
  val destroyRenderer=destroy
  fun rendererOperation name renderer=withHandle renderer(fn p=>checked name[address p])
  fun setRenderDrawColor(renderer,{red,green,blue,alpha})=withHandle renderer(fn p=>
    let fun channel n=if n<0 orelse n>255 then raise Domain else RuneForeign.Unsigned(Word64.fromInt n)
    in checked "SDL_SetRenderDrawColor" (address p::List.map channel[red,green,blue,alpha]) end)
  val renderClear=rendererOperation "SDL_RenderClear"
  fun renderPoint(renderer,x,y)=withHandle renderer(fn p=>checked "SDL_RenderPoint" [address p,RuneForeign.Real x,RuneForeign.Real y])
  fun renderLine(renderer,x1,y1,x2,y2)=withHandle renderer(fn p=>checked "SDL_RenderLine" (address p::List.map RuneForeign.Real[x1,y1,x2,y2]))
  fun renderRect(renderer,rect)=withHandle renderer(fn p=>withFRect rect(fn rect=>checked "SDL_RenderRect" [address p,rect]))
  fun renderFillRect(renderer,rect)=withHandle renderer(fn p=>withFRect rect(fn rect=>checked "SDL_RenderFillRect" [address p,rect]))
  val renderPresent=rendererOperation "SDL_RenderPresent"
  fun renderReadPixels(renderer,rect)=withHandle renderer(fn p=>withRect "SDL_Rect" rect(fn rect=>
    adopt "SDL_RenderReadPixels" NONE(call "SDL_RenderReadPixels" [address p,rect])))
  fun createTextureFromSurface(renderer,surface)=withHandle renderer(fn r=>withHandle surface(fn s=>
    adopt "SDL_CreateTextureFromSurface" (SOME(depend renderer))(call "SDL_CreateTextureFromSurface" [address r,address s])))
  val destroyTexture=destroy
  fun renderTexture(renderer,texture,sourceRect,destinationRect)=withHandle renderer(fn r=>withHandle texture(fn t=>
    withFRect sourceRect(fn sr=>withFRect destinationRect(fn dr=>checked "SDL_RenderTexture" [address r,address t,sr,dr]))))
  fun renderDebugText(renderer,x,y,text)=withHandle renderer(fn r=>withString text(fn text=>checked "SDL_RenderDebugText" [address r,RuneForeign.Real x,RuneForeign.Real y,text]))
  fun hasClipboardText ()=status(call "SDL_HasClipboardText" [])
  fun getClipboardText ()=case #pointer(call "SDL_GetClipboardText" []) of NONE=>failed "SDL_GetClipboardText"
    | SOME p=>
      let val owner=ForeignOwner.adopt{pointer=p,destructor={call=Raw.prepare(session())"SDL_free",arguments=fn p=>[address p],failure=RuneForeign.NoFailure}}
      in ForeignScope.withScope(fn scope=>(ignore(ForeignOwner.inScope(scope,owner));ForeignOwner.withBorrow owner cString)) end
  fun setClipboardText text=withString text(fn text=>checked "SDL_SetClipboardText" [text])
  fun getTicks ()=word64(call "SDL_GetTicks" [])
  fun getTicksNS ()=word64(call "SDL_GetTicksNS" [])
  fun getPerformanceCounter ()=word64(call "SDL_GetPerformanceCounter" [])
  fun getPerformanceFrequency ()=word64(call "SDL_GetPerformanceFrequency" [])
  fun delay ms=unitCall "SDL_Delay" [unsigned(Word32.toLargeInt ms)]
end

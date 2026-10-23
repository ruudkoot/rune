(* Implements: WIN32_NATIVE where type Types.window = Win32Common.Types.window and type Types.module = Win32Common.Types.module and type Types.atom = Win32Common.Types.atom and type Types.paint = Win32Common.Types.paint and type Types.object = Win32Common.Types.object and type Types.pen = Win32Common.Types.pen and type Types.brush = Win32Common.Types.brush and type Types.message = Win32Common.Types.message and type Types.reply = Win32Common.Types.reply and type Types.queued = Win32Common.Types.queued and type Types.next = Win32Common.Types.next *)
functor Win32NativeFn (Config : WIN32_NATIVE_CONFIG) :> WIN32_NATIVE
  where type Types.window = Win32Common.Types.window
  and type Types.module = Win32Common.Types.module
  and type Types.atom = Win32Common.Types.atom
  and type Types.paint = Win32Common.Types.paint
  and type Types.object = Win32Common.Types.object
  and type Types.pen = Win32Common.Types.pen
  and type Types.brush = Win32Common.Types.brush
  and type Types.message = Win32Common.Types.message
  and type Types.reply = Win32Common.Types.reply
  and type Types.queued = Win32Common.Types.queued
  and type Types.next = Win32Common.Types.next =
struct
  structure Types = Win32Common.Types
  structure R = RuneForeign
  structure B = ForeignBytes
  structure M = ForeignMemory
  datatype objectKind = Pen | Brush
  type classEntry = {token:Types.atom, instance:Types.module, name:M.buffer,
    callback:R.resource, procedure:Types.window * Types.message -> Types.reply, windows:int ref}
  type windowEntry = {token:Types.window, raw:R.resource, class:Types.atom,
    live:bool ref, painting:bool ref, timers:Word64.word list ref}
  type objectEntry = {token:Types.object, raw:R.resource, kind:objectKind,
    owned:bool, live:bool ref, selected:int ref, active:int ref}
  type paintEntry = {token:Types.paint, window:Types.window, dc:R.resource,
    buffer:M.buffer, pen:Types.object option ref, brush:Types.object option ref, active:int ref}
  type queuedEntry = {token:Types.queued, buffer:M.buffer}
  type context = {window:Types.window, class:Types.atom, message:Types.message, arguments:R.argument list}
  val classes=ref([]:classEntry list)
  val windows=ref([]:windowEntry list)
  val modules=ref([]:(Types.module * R.resource) list)
  val objects=ref([]:objectEntry list)
  val paints=ref([]:paintEntry list)
  val queued=ref([]:queuedEntry list)
  val contexts=ref([]:context list)
  val creating=ref([]:Types.window list)
  val retiring=ref([]:R.resource list)
  val recoveries=ref([]:(unit -> unit) list)
  val recovering=ref false
  val closed=ref false
  val lastError=ref(0w0:Word32.word)
  val platform=List.exists(fn(name,value)=>name="sysname" andalso value="Windows")(Posix.ProcEnv.uname())
  val target=R.target()
  val available=R.available()
  fun error function code=(lastError:=code;raise Types.Error{function=function,code=code})
  fun unsupported detail=raise Types.Unsupported detail
  fun drainRecoveries()=if !recovering then () else
    let fun loop()=case !recoveries of []=>() | action::rest=>(action();recoveries:=rest;loop())
        val ()=recovering:=true
    in (loop()handle exn=>(recovering:=false;raise exn));recovering:=false end
  fun recover action=(action()handle _=>recoveries:=action:: !recoveries)
  fun guard function=(if !closed then error function 0w6 else
    if not platform then unsupported "native Win32 requires Windows" else
    if available then () else unsupported "native Win32 requires libffi";drainRecoveries())
  fun word(result:R.result)=if size(#bytes result)=0 then 0w0 else PackWord64Little.subVec(Byte.stringToBytes(#bytes result),0)
  fun integer result=Word64.toLargeIntX(word result)
  fun signed n=if IntInf.fromInt n< ~2147483648 orelse IntInf.fromInt n>2147483647
    then unsupported "native C int argument exceeds 32 bits" else R.Signed(Int64.fromInt n)
  fun unsigned n=R.Unsigned(Word64.fromInt n)
  fun w32 n=R.Unsigned(Word64.fromLargeInt(Word32.toLargeInt n))
  fun address p=R.Address(SOME p)
  val null=R.Address NONE
  fun nativeError name result=error name (#native(#error(result:R.result)))
  fun drain()=
    let fun one(resource,kept)=if not(R.isLive resource) then kept else
          ((R.release resource;kept) handle R.Error _=>resource::kept)
    in retiring:=List.foldl one [] (!retiring) end
  fun deferred name arguments=
    let val ()=guard name
        val answer=R.invokeDeferred(Config.prepare name,arguments)
          handle R.Error{native,...}=>error name native
        val ()=lastError:= #native(#error(#result answer))
        val ()=drain()
    in answer end
  fun call name arguments=
    let val {result,callbackException}=deferred name arguments
    in case callbackException of NONE=>result | SOME exn=>raise exn end
  fun checked name arguments=let val result=call name arguments
    in if word result=0w0 then nativeError name result else result end
  fun pointer name result=case #pointer(result:R.result) of NONE=>nativeError name result | SOME value=>value
  fun adopt value=
    let val handleValue=R.aliasHandle value
        handle exn=>(R.release value;raise exn)
        val ()=R.release value
    in handleValue end
  fun adoptOwned value cleanup=
    let val handleValue=R.aliasHandle value
          handle exn=>(recover cleanup;raise exn)
        val ()=R.release value
    in handleValue end
  fun withBuffer length body=
    let val buffer=M.allocate length
        val result=body buffer handle exn=>(M.release buffer;raise exn)
    in M.release buffer;result end
  fun text function value=ForeignText.encode{encoding=ForeignText.Utf16,littleEndian=true,terminated=true,text=value}
    handle ForeignText.Error _=>error function 0w1113
  fun withText function value body=M.withBytes(text function value)(fn buffer=>body(M.raw buffer))
  fun withOptionalText function NONE body=body NONE
    | withOptionalText function(SOME value)body=withText function value(fn p=>body(SOME p))
  fun member ty path buffer=B.value{signed=true,littleEndian=true,
    bytes=M.read(buffer,Config.offset(ty,path),4)}
  fun rectangle buffer={left=Int32.fromLarge(member "RECT" ["left"] buffer),
    top=Int32.fromLarge(member "RECT" ["top"] buffer),right=Int32.fromLarge(member "RECT" ["right"] buffer),
    bottom=Int32.fromLarge(member "RECT" ["bottom"] buffer)}
  fun writeRectangle buffer({left,top,right,bottom}:Types.rect)=List.app(fn(name,value)=>
    M.write(buffer,Config.offset("RECT",[name]),B.integer{width=4,signed=true,littleEndian=true,value=Int32.toLarge value}))
    [("left",left),("top",top),("right",right),("bottom",bottom)]
  fun field ty path buffer=call ("rf_field_" ^ ty ^ "_" ^ String.concatWith "_" path ^ "_get") [address(M.raw buffer)]
  fun setField ty name buffer value=ignore(call("rf_field_" ^ ty ^ "_" ^ name ^ "_set")[address(M.raw buffer),value])
  fun class function token=(guard function;case List.find(fn entry:classEntry=> #token entry=token)(!classes) of
      SOME entry=>entry | NONE=>error function 0w6)
  fun module function token=(guard function;case List.find(fn(key,_)=>key=token)(!modules) of SOME(_,value)=>value | NONE=>error function 0w6)
  fun window function token=(guard function;case List.find(fn entry:windowEntry=> #token entry=token)(!windows) of
      SOME entry=>if !(#live entry) andalso R.isLive(#raw entry) then entry else error function 0w1400
    | NONE=>error function 0w1400)
  fun paint function token=(guard function;case List.find(fn entry:paintEntry=> #token entry=token)(!paints) of SOME entry=>entry | NONE=>error function 0w6)
  fun object function token=(guard function;case List.find(fn entry:objectEntry=> #token entry=token)(!objects) of
      SOME entry=>if !(#live entry) andalso R.isLive(#raw entry) then entry else error function 0w6
    | NONE=>error function 0w6)
  fun queuedMessage function token=(guard function;case List.find(fn entry:queuedEntry=>Win32Common.queuedKey(#token entry)=Win32Common.queuedKey token)(!queued) of
      SOME entry=>entry | NONE=>error function 0w6)
  fun retire entry=if not(!(#live(entry:windowEntry))) then () else
    let val owner=class "retireWindow" (#class entry)
    in #live entry:=false;#timers entry:=[];#windows owner:= !(#windows owner)-1;
       windows:=List.filter(fn other:windowEntry=> #token other<> #token entry)(!windows);
       retiring:= #raw entry:: !retiring end
  fun findWindow raw=List.find(fn entry:windowEntry=> !(#live entry) andalso #raw entry=raw)(!windows)
  fun low n=Word16.toInt(Win32Values.lowWord n)
  fun high n=Word16.toInt(Win32Values.highWord n)
  fun decode(code,w,l)=
    let val n=if code<=0wxFFFF then Word32.toInt code else ~1 val bits=Word64.fromLargeInt(Int64.toLarge l)
        val point={x=Win32Values.xFromLParam l,y=Win32Values.yFromLParam l}
    in case n of 129=>Types.NcCreate | 1=>Types.Create | 5=>Types.Size{width=low bits,height=high bits}
      | 15=>Types.Paint | 16=>Types.Close | 2=>Types.Destroy | 130=>Types.NcDestroy
      | 256=>Types.KeyDown{key=Word32.fromLargeWord(Word64.toLargeWord w),repeated=Word64.andb(bits,0wx40000000)<>0w0}
      | 257=>Types.KeyUp(Word32.fromLargeWord(Word64.toLargeWord w))
      | 258=>Types.Char(Word16.fromInt(low w))
      | 512=>Types.MouseMove{x= #x point,y= #y point,buttons=Word32.fromLargeWord(Word64.toLargeWord w)}
      | 513=>Types.ButtonDown{button=1,x= #x point,y= #y point} | 514=>Types.ButtonUp{button=1,x= #x point,y= #y point}
      | 519=>Types.ButtonDown{button=2,x= #x point,y= #y point} | 520=>Types.ButtonUp{button=2,x= #x point,y= #y point}
      | 516=>Types.ButtonDown{button=3,x= #x point,y= #y point} | 517=>Types.ButtonUp{button=3,x= #x point,y= #y point}
      | 275=>Types.Timer w
      | _=>if n>=32768 andalso n<49152 then Types.Application{code=code,w=w,l=l} else Types.Unknown code
    end
  fun packed(x,y)=
    if x< ~32768 orelse x>32767 orelse y< ~32768 orelse y>32767 then unsupported "mouse coordinates exceed signed 16 bits"
    else Word64.orb(Word64.andb(Word64.fromInt x,0wxFFFF),Word64.<<(Word64.andb(Word64.fromInt y,0wxFFFF),0w16))
  fun encode message=
    let fun value(code,w,l)=(Word32.fromInt code,w,Int64.fromLarge(if #pointerBytes target=4 then
          Word32.toLargeIntX(Word32.fromLargeWord(Word64.toLargeWord l)) else Word64.toLargeIntX l))
        fun button down{button,x,y}=value((case button of 1=>if down then 513 else 514 | 2=>if down then 519 else 520
            | 3=>if down then 516 else 517 | _=>unsupported "unsupported mouse button"),0w0,packed(x,y))
    in case message of Types.Size{width,height}=>if width<0 orelse width>65535 orelse height<0 orelse height>65535
          then unsupported "window size message exceeds unsigned 16 bits" else value(5,0w0,Word64.orb(Word64.fromInt width,Word64.<<(Word64.fromInt height,0w16)))
      | Types.Paint=>value(15,0w0,0w0) | Types.Close=>value(16,0w0,0w0)
      | Types.KeyDown{key,repeated}=>value(256,Word64.fromLargeInt(Word32.toLargeInt key),if repeated then 0wx40000000 else 0w0)
      | Types.KeyUp key=>value(257,Word64.fromLargeInt(Word32.toLargeInt key),0w0)
      | Types.Char c=>value(258,Word64.fromLargeInt(Word16.toLargeInt c),0w0)
      | Types.MouseMove{x,y,buttons}=>value(512,Word64.fromLargeInt(Word32.toLargeInt buttons),packed(x,y))
      | Types.ButtonDown p=>button true p | Types.ButtonUp p=>button false p
      | Types.Timer id=>value(275,id,0w0)
      | Types.Application payload=>if #code payload>=0wx8000 andalso #code payload<0wxC000 then
          (#code payload,#w payload,#l payload) else unsupported "application message code must be in WM_APP range"
      | _=>unsupported "synthetic lifecycle and unknown messages are unsupported"
    end
  fun messageArguments raw(code,w,l)=
    if #pointerBytes target=4 andalso (w>0wxFFFFFFFF orelse Int64.toLarge l< ~2147483648 orelse Int64.toLarge l>2147483647)
    then unsupported "message payload exceeds the native pointer width"
    else [address raw,w32 code,R.Unsigned w,R.Signed l]
  fun default windowValue message=
    let val entry=window "DefWindowProcW" windowValue
        val ()=case message of Types.Close=>if !(#painting entry) then error "DefWindowProcW" 0w170 else () | _=>()
        val arguments=case List.find(fn(c:context)=> #window c=windowValue andalso #message c=message)(!contexts) of
            SOME c=> #arguments c | NONE=>messageArguments(#raw entry)(encode message)
        val result=call "DefWindowProcW" arguments
          handle exn=>(case message of Types.Close=>retire entry | _=>();raise exn)
        val ()=case message of Types.Close=>retire entry | _=>()
    in Int64.fromLarge(integer result) end
  fun procedure atom client arguments=
    case arguments of [R.Address(SOME pointerValue),R.Unsigned message,R.Unsigned w,R.Signed l]=>
      let val raw=R.aliasHandle pointerValue
          val entry=case findWindow raw of SOME entry=>entry | NONE=>
            let val token=case !creating of token::_=>token | []=>Win32Common.freshWindow()
                val entry={token=token,raw=raw,class=atom,live=ref true,painting=ref false,timers=ref []}
                val owner=class "WindowProc" atom
            in windows:=entry:: !windows;#windows owner:= !(#windows owner)+1;entry end
          val decoded=decode(Word32.fromLargeWord(Word64.toLargeWord message),w,l)
          val previous= !contexts
          val ()=contexts:={window= #token entry,class=atom,message=decoded,arguments=arguments}::previous
          fun finish()=(contexts:=previous;case decoded of Types.NcDestroy=>retire entry | _=>())
          val answer=(case client(#token entry,decoded) of Types.Default=>
              if !(#live entry) then default(#token entry)decoded
              else (case decoded of Types.Create=>Int64.fromInt ~1 | _=>Int64.fromInt 0)
            | Types.Result value=>value)
            handle exn=>(finish();raise exn)
      in finish();R.Signed answer end
    | _=>raise Fail "invalid native window procedure arguments"
  fun decrement NONE=() | decrement(SOME token)=let val entry=object "EndPaint" token in #selected entry:= !(#selected entry)-1 end
  fun endPaint(windowValue,paintValue)=
    let val entry=paint "EndPaint" paintValue
        val ()=if !(#active entry)=0 then () else error "EndPaint" 0w170
        val ()=if #window entry=windowValue then () else error "EndPaint" 0w6
        val owner=window "EndPaint" windowValue
        fun finish()=(decrement(!(#pen entry));decrement(!(#brush entry));M.release(#buffer entry);
          paints:=List.filter(fn p:paintEntry=> #token p<>paintValue)(!paints);#painting owner:=false;drain())
        val answer=R.consumeHandle{resource= #dc entry,call=Config.prepare "EndPaint",
          arguments=[address(#raw owner),address(M.raw(#buffer entry))],failure=R.Zero}
          handle exn=>(if R.isLive(#dc entry) then () else finish();raise exn)
        val ()=lastError:= #native(#error(#result answer))
    in if #disposed answer then finish() else nativeError "EndPaint" (#result answer) end
  structure Kernel =
  struct
    fun getModuleHandle name=withOptionalText "GetModuleHandleW" name(fn p=>
      let val raw=adopt(pointer "GetModuleHandleW" (call "GetModuleHandleW" [R.Address p]))
      in case List.find(fn(_,value)=>value=raw)(!modules) of SOME(token,_)=>token | NONE=>
        let val token=Win32Common.freshModule() in modules:=(token,raw):: !modules;token end end)
    fun getLastError()=(guard "GetLastError";!lastError)
    fun setLastError code=(ignore(call "SetLastError" [w32 code]);lastError:=code)
    fun counter name=withBuffer 8(fn buffer=>
      (ignore(checked name [address(M.raw buffer)]);Int64.fromLarge(B.value{signed=true,littleEndian=true,bytes=M.read(buffer,0,8)})))
    fun queryPerformanceCounter()=counter "QueryPerformanceCounter"
    fun queryPerformanceFrequency()=counter "QueryPerformanceFrequency"
  end
  structure User =
  struct
    fun registerClassEx{name,instance,style,procedure=client}=
      let val ()=guard "RegisterClassExW"
          val ()=if Word32.andb(style,Word32.notb 0w3)=0w0 then () else unsupported "unsupported window class style"
          val instanceHandle=module "RegisterClassExW" instance
          val atom=Win32Common.freshAtom()
          val nameBuffer=M.fromBytes(text "RegisterClassExW" name)
          val callback=R.callback{abi=if #stdcall target then 1 else 0,
            result=if #pointerBytes target=4 then R.SInt32 else R.SInt64,
            arguments=[R.Pointer,R.UInt32,if #pointerBytes target=4 then R.UInt32 else R.UInt64,
              if #pointerBytes target=4 then R.SInt32 else R.SInt64],function=procedure atom client,
            failure=R.ByArgument{index=1,cases=[(0w129,R.Signed 0),(0w1,R.Signed ~1)],default=R.Signed 0}}
            handle exn=>(M.release nameBuffer;raise exn)
          fun cleanup()=(R.release callback;M.release nameBuffer)
          val _=(withBuffer(Config.sizeOf "WNDCLASSEXW")(fn record=>
            (setField "WNDCLASSEXW" "cbSize" record(unsigned(Config.sizeOf "WNDCLASSEXW"));
             setField "WNDCLASSEXW" "style" record(w32 style);
             setField "WNDCLASSEXW" "hInstance" record(address instanceHandle);
             setField "WNDCLASSEXW" "lpfnWndProc" record(address callback);
             setField "WNDCLASSEXW" "lpszClassName" record(address(M.raw nameBuffer));
             checked "RegisterClassExW" [address(M.raw record)]))) handle exn=>(cleanup();raise exn)
      in classes:={token=atom,instance=instance,name=nameBuffer,callback=callback,procedure=client,windows=ref 0}:: !classes;atom end
    fun unregisterClass(atom,instance)=
      let val entry=class "UnregisterClassW" atom
          val ()=if #instance entry=instance then () else error "UnregisterClassW" 0w6
          val ()=if !(#windows entry)=0 andalso not(List.exists(fn(c:context)=> #class c=atom)(!contexts))
            then () else error "UnregisterClassW" 0w170
          val _=checked "UnregisterClassW" [address(M.raw(#name entry)),address(module "UnregisterClassW" instance)]
      in R.release(#callback entry);M.release(#name entry);classes:=List.filter(fn entry:classEntry=> #token entry<>atom)(!classes) end
    fun destroyWindow token=
      let val entry=window "DestroyWindow" token
          val ()=if !(#painting entry) then error "DestroyWindow" 0w170 else ()
          fun finish()=(retire entry;drain())
          val answer=R.consumeHandle{resource= #raw entry,call=Config.prepare "DestroyWindow",
            arguments=[address(#raw entry)],failure=R.Zero}
            handle exn=>(if R.isLive(#raw entry) then () else finish();raise exn)
          val ()=lastError:= #native(#error(#result answer))
      in if #disposed answer then finish() else nativeError "DestroyWindow" (#result answer) end
    fun createWindowEx{class=atom,instance,title,style,extendedStyle,x,y,width,height,parent}=
      let val owner=class "CreateWindowExW" atom
          val ()=if #instance owner=instance then () else error "CreateWindowExW" 0w6
          val ()=if extendedStyle=0w0 andalso parent=NONE andalso
            Word32.andb(style,Word32.notb 0wx10CF0000)=0w0 andalso width>0 andalso height>0 then ()
            else unsupported "unsupported top-level window flags, parent or dimensions"
          val token=Win32Common.freshWindow()
          val previous= !creating
          fun forget()=(creating:=previous;case List.find(fn entry:windowEntry=> #token entry=token)(!windows) of NONE=>() | SOME entry=>retire entry;drain())
          val answer=(creating:=token::previous;
            withText "CreateWindowExW" title(fn titlePointer=>deferred "CreateWindowExW"
              [w32 extendedStyle,address(M.raw(#name owner)),address titlePointer,w32 style,signed x,signed y,
               signed width,signed height,null,null,address(module "CreateWindowExW" instance),null]))
            handle exn=>(forget();raise exn)
          val ()=creating:=previous
          val raw=case #pointer(#result answer) of NONE=>(forget();case #callbackException answer of SOME exn=>raise exn
                | NONE=>nativeError "CreateWindowExW" (#result answer)) | SOME value=>adopt value
          val entry=case findWindow raw of SOME entry=>entry | NONE=>
            let val entry={token=token,raw=raw,class=atom,live=ref true,painting=ref false,timers=ref []}
            in windows:=entry:: !windows;#windows owner:= !(#windows owner)+1;entry end
      in case #callbackException answer of NONE=> #token entry | SOME exn=>
        ((destroyWindow(#token entry)handle _=>());forget();raise exn) end
    fun showWindow(token,command)=
      if List.exists(fn n=>n=command)[0,1,5,8,9,10] then
        word(call "ShowWindow" [address(#raw(window "ShowWindow" token)),signed command])<>0w0
      else unsupported "unsupported show-window command"
    fun updateWindow token=ignore(checked "UpdateWindow" [address(#raw(window "UpdateWindow" token))])
    val defWindowProc=fn(token,message)=>default token message
    fun getClientRect token=withBuffer(Config.sizeOf "RECT")(fn record=>
      (ignore(checked "GetClientRect" [address(#raw(window "GetClientRect" token)),address(M.raw record)]);rectangle record))
    fun setWindowText(token,value)=withText "SetWindowTextW" value(fn p=>
      ignore(checked "SetWindowTextW" [address(#raw(window "SetWindowTextW" token)),address p]))
    fun filterWindow function NONE=null | filterWindow function(SOME token)=address(#raw(window function token))
    fun copied buffer=let val token=Win32Common.freshQueued()
      in queued:={token=token,buffer=buffer}:: !queued;token end
    fun getMessage{window=token,minimum,maximum}=
      let val buffer=M.allocate(Config.sizeOf "MSG")
          val result=call "GetMessageW" [address(M.raw buffer),filterWindow "GetMessageW" token,w32 minimum,w32 maximum]
            handle exn=>(M.release buffer;raise exn)
          val status=integer result
      in if status<0 then (M.release buffer;nativeError "GetMessageW" result)
        else if status=0 then let val quit=Int32.fromLarge(Word32.toLargeIntX(Word32.fromLargeWord(Word64.toLargeWord(word(field "MSG" ["wParam"] buffer)))))
              handle exn=>(M.release buffer;raise exn)
          in M.release buffer;Types.Quit quit end
        else Types.Message(copied buffer) end
    fun peekMessage{window=token,minimum,maximum,remove}=
      let val buffer=M.allocate(Config.sizeOf "MSG")
          val result=call "PeekMessageW" [address(M.raw buffer),filterWindow "PeekMessageW" token,w32 minimum,w32 maximum,
            unsigned(if remove then 1 else 0)] handle exn=>(M.release buffer;raise exn)
      in if word result=0w0 then (M.release buffer;NONE) else SOME(copied buffer) end
    fun discardMessage token=
      let val entry=queuedMessage "discardMessage" token
      in M.release(#buffer entry);queued:=List.filter(fn entry:queuedEntry=>Win32Common.queuedKey(#token entry)<>Win32Common.queuedKey token)(!queued) end
    fun translateMessage token=word(call "TranslateMessage" [address(M.raw(#buffer(queuedMessage "TranslateMessage" token)))])<>0w0
    fun dispatchMessage token=
      let val entry=queuedMessage "DispatchMessageW" token
          val result=call "DispatchMessageW" [address(M.raw(#buffer entry))]
            handle exn=>(discardMessage token;raise exn)
      in discardMessage token;Int64.fromLarge(integer result) end
    fun postQuitMessage code=ignore(call "PostQuitMessage" [R.Signed(Int64.fromLarge(Int32.toLarge code))])
    fun postMessage(token,message)=ignore(checked "PostMessageW" (messageArguments(#raw(window "PostMessageW" token))(encode message)))
    fun sendMessage(token,message)=Int64.fromLarge(integer(call "SendMessageW" (messageArguments(#raw(window "SendMessageW" token))(encode message))))
    fun invalidateRect(token,rect,erase)=
      let val args=[address(#raw(window "InvalidateRect" token))]
          fun invoke pointerValue=ignore(checked "InvalidateRect" (args @ [pointerValue,signed(if erase then 1 else 0)]))
      in case rect of NONE=>invoke null | SOME rect=>withBuffer(Config.sizeOf "RECT")(fn buffer=>(writeRectangle buffer rect;invoke(address(M.raw buffer)))) end
    fun beginPaint token=
      let val owner=window "BeginPaint" token
          val ()=if !(#painting owner) then error "BeginPaint" 0w170 else ()
          val endCall=Config.prepare "EndPaint"
          val buffer=M.allocate(Config.sizeOf "PAINTSTRUCT")
          val ()= #painting owner:=true
          val answer=deferred "BeginPaint" [address(#raw owner),address(M.raw buffer)]
            handle exn=>(#painting owner:=false;M.release buffer;raise exn)
          val pointerValue=case #pointer(#result answer) of NONE=>(#painting owner:=false;M.release buffer;
              case #callbackException answer of SOME exn=>raise exn | NONE=>nativeError "BeginPaint" (#result answer))
            | SOME pointerValue=>pointerValue
          fun cleanup()=
            let val ()=if not(R.isLive pointerValue) then () else
                  let val outcome=R.dispose{resource=pointerValue,call=endCall,
                    arguments=[address(#raw owner),address(M.raw buffer)],failure=R.Zero}
                  in if #disposed outcome then () else nativeError "EndPaint" (#result outcome) end
            in M.release buffer;#painting owner:=false end
          val ()=case #callbackException answer of NONE=>() | SOME exn=>(recover cleanup;raise exn)
          val raw=adoptOwned pointerValue cleanup
          val paintToken=Win32Common.freshPaint()
          val entry={token=paintToken,window=token,dc=raw,buffer=buffer,pen=ref NONE,brush=ref NONE,active=ref 0}
          val ()=paints:=entry:: !paints
          val rect=({left=Int32.fromLarge(integer(field "PAINTSTRUCT" ["rcPaint","left"] buffer)),
            top=Int32.fromLarge(integer(field "PAINTSTRUCT" ["rcPaint","top"] buffer)),
            right=Int32.fromLarge(integer(field "PAINTSTRUCT" ["rcPaint","right"] buffer)),
            bottom=Int32.fromLarge(integer(field "PAINTSTRUCT" ["rcPaint","bottom"] buffer))}
            handle exn=>((endPaint(token,paintToken)handle _=>());raise exn))
      in (paintToken,rect) end
    val endPaint=endPaint
    fun withPaint token body=
      let val lease=beginPaint token
          fun cleanup()=if List.exists(fn(entry:paintEntry)=> #token entry= #1 lease)(!paints)
            then endPaint(token,#1 lease) else ()
          val value=body lease handle exn=>(recover cleanup;raise exn)
          val ()=cleanup()handle exn=>(recoveries:=cleanup:: !recoveries;raise exn)
      in value end
    fun fillRect(token,rect,brush)=
      let val context=paint "FillRect" token val object=object "FillRect" (Win32Common.brushObject brush)
          val ()=if #kind object=Brush then () else error "FillRect" 0w6
          val ()= #active context:= !(#active context)+1
          val ()= #active object:= !(#active object)+1
          fun finish()=(#active context:= !(#active context)-1;#active object:= !(#active object)-1)
          val ()=(withBuffer(Config.sizeOf "RECT")(fn buffer=>
            (writeRectangle buffer rect;ignore(checked "FillRect" [address(#dc context),address(M.raw buffer),address(#raw object)]))))
            handle exn=>(finish();raise exn)
      in finish() end
    fun setTimer(token,id,milliseconds)=
      let val owner=window "SetTimer" token
          val ()=if #pointerBytes target=4 andalso id>0wxFFFFFFFF then unsupported "timer identity exceeds native pointer width" else ()
          val result=word(checked "SetTimer" [address(#raw owner),R.Unsigned id,w32 milliseconds,null])
      in #timers owner:=result::List.filter(fn n=>n<>result)(!(#timers owner));result end
    fun killTimer(token,id)=
      let val owner=window "KillTimer" token
          val ()=if List.exists(fn n=>n=id)(!(#timers owner)) then () else error "KillTimer" 0w6
          val _=checked "KillTimer" [address(#raw owner),R.Unsigned id]
      in #timers owner:=List.filter(fn n=>n<>id)(!(#timers owner)) end
  end
  fun withDc function token body=
    let val entry=paint function token
        val ()= #active entry:= !(#active entry)+1
        val value=body entry handle exn=>(#active entry:= !(#active entry)-1;raise exn)
    in #active entry:= !(#active entry)-1;value end
  fun registerObject raw kind owned token=
    let fun cleanup()=if not(R.isLive raw) then () else
          let val answer=R.dispose{resource=raw,call=Config.prepare "DeleteObject",arguments=[address raw],failure=R.Zero}
          in if #disposed answer then () else nativeError "DeleteObject" (#result answer) end
        val handleValue=if owned then adoptOwned raw cleanup else adopt raw
    in case List.find(fn entry:objectEntry=> #raw entry=handleValue andalso !(#live entry))(!objects) of
        SOME entry=> #token entry
      | NONE=>(objects:={token=token,raw=handleValue,kind=kind,owned=owned,live=ref true,selected=ref 0,active=ref 0}:: !objects;token) end
  structure Gdi =
  struct
    fun rgb colour=if Word32.andb(colour,0wxFF000000)=0w0 then ()
      else unsupported "palette and reserved colour bits are unsupported"
    fun createPen{style,width,colour}=
      if style<>0 orelse width<0 then unsupported "only solid nonnegative-width pens are supported" else
      let val ()=rgb colour
          val _=Config.prepare "DeleteObject"
          val pen=Win32Common.freshPen()
          val raw=pointer "CreatePen" (call "CreatePen" [signed style,signed width,w32 colour])
          val _=registerObject raw Pen true (Win32Common.penObject pen)
      in pen end
    fun createSolidBrush colour=
      let val ()=rgb colour
          val _=Config.prepare "DeleteObject"
          val brush=Win32Common.freshBrush()
          val _=registerObject(pointer "CreateSolidBrush" (call "CreateSolidBrush" [w32 colour]))Brush true(Win32Common.brushObject brush)
      in brush end
    fun penObject value=
      let val token=Win32Common.penObject value val entry=object "penObject" token
      in if #kind entry=Pen then token else error "penObject" 0w6 end
    fun brushObject value=
      let val token=Win32Common.brushObject value val entry=object "brushObject" token
      in if #kind entry=Brush then token else error "brushObject" 0w6 end
    fun objectBrush token=if #kind(object "objectBrush" token)=Brush then Win32Common.objectBrush token else error "objectBrush" 0w6
    fun selectObject(paintToken,objectToken)=withDc "SelectObject" paintToken(fn context=>
      let val entry=object "SelectObject" objectToken
          val ()= #active entry:= !(#active entry)+1
          val result=call "SelectObject" [address(#dc context),address(#raw entry)]
            handle exn=>(#active entry:= !(#active entry)-1;raise exn)
          val ()= #active entry:= !(#active entry)-1
          val old=registerObject(pointer "SelectObject" result)(#kind entry)false(Win32Common.freshObject())
          val slot=case #kind entry of Pen=> #pen context | Brush=> #brush context
          val ()=decrement(!slot)
      in #selected entry:= !(#selected entry)+1;slot:=SOME objectToken;old end)
    fun deleteObject token=
      let val entry=object "DeleteObject" token
          val ()=if #owned entry then () else error "DeleteObject" 0w6
          val ()=if !(#selected entry)=0 andalso !(#active entry)=0 then () else error "DeleteObject" 0w170
          val answer=R.consumeHandle{resource= #raw entry,call=Config.prepare "DeleteObject",
            arguments=[address(#raw entry)],failure=R.Zero}
          val ()=lastError:= #native(#error(#result answer))
      in if #disposed answer then (#live entry:=false;objects:=List.filter(fn other:objectEntry=> #token other<>token)(!objects))
        else nativeError "DeleteObject" (#result answer) end
    fun getStockObject index=
      if index<0 orelse index>8 then unsupported "only stock pens and brushes are supported" else
        registerObject(pointer "GetStockObject" (call "GetStockObject" [signed index]))
          (if index<=5 then Brush else Pen)false(Win32Common.freshObject())
    fun moveToEx(token,x,y)=withDc "MoveToEx" token(fn context=>withBuffer(Config.sizeOf "POINT")(fn buffer=>
      (ignore(checked "MoveToEx" [address(#dc context),signed x,signed y,address(M.raw buffer)]);
       {x=IntInf.toInt(member "POINT" ["x"] buffer),y=IntInf.toInt(member "POINT" ["y"] buffer)})))
    fun lineTo(token,x,y)=withDc "LineTo" token(fn context=>ignore(checked "LineTo" [address(#dc context),signed x,signed y]))
    fun rectangle(token,{left,top,right,bottom})=withDc "Rectangle" token(fn context=>
      ignore(checked "Rectangle" (address(#dc context)::List.map(fn n=>R.Signed(Int64.fromLarge(Int32.toLarge n)))[left,top,right,bottom])))
    fun setTextColor(token,colour)=withDc "SetTextColor" token(fn context=>
      let val ()=rgb colour
          val result=call "SetTextColor" [address(#dc context),w32 colour]
      in if word result=0wxFFFFFFFF then nativeError "SetTextColor" result else Word32.fromLargeWord(Word64.toLargeWord(word result)) end)
    fun setBkMode(token,mode)=if mode<>1 andalso mode<>2 then unsupported "unsupported text background mode" else
      withDc "SetBkMode" token(fn context=>IntInf.toInt(integer(checked "SetBkMode" [address(#dc context),signed mode])))
    fun textOut(token,x,y,value)=withDc "TextOutW" token(fn context=>
      let val bytes=ForeignText.encode{encoding=ForeignText.Utf16,littleEndian=true,terminated=false,text=value}
          handle ForeignText.Error _=>error "TextOutW" 0w1113
      in M.withBytes bytes(fn buffer=>ignore(checked "TextOutW" [address(#dc context),signed x,signed y,address(M.raw buffer),signed(size bytes div 2)])) end)
  end
  fun close()=
    let val ()=guard "close"
        val ()=if List.null(!contexts) andalso List.null(!creating) andalso List.null(!classes) andalso List.null(!windows) andalso
          List.null(!paints) andalso not(List.exists(fn entry:objectEntry=> #owned entry andalso !(#live entry))(!objects)) then () else error "close" 0w170
        val ()=List.app(fn entry:queuedEntry=>M.release(#buffer entry))(!queued)
        val ()=queued:=[]
        val ()=drain()
        val ()=if List.null(!retiring) then () else error "close" 0w170
        val ()=List.app(fn entry:objectEntry=>if R.isLive(#raw entry) then R.release(#raw entry) else())(!objects)
        val ()=objects:=[]
        val ()=List.app(fn(_,resource)=>if R.isLive resource then R.release resource else())(!modules)
        val ()=modules:=[]
    in Config.close();closed:=true end
end

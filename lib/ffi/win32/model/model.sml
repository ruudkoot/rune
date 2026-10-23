(* Implements: WIN32_MODEL *)
functor Win32ModelFn (Driver : WIN32_GUI_DRIVER) : WIN32_MODEL
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
  structure Types=Win32Common.Types
  val observations=ref([]:string list)
  fun note text=observations:=text:: !observations
  fun trace()=List.rev(!observations)
  val lastError=ref(0w0:Word32.word)
  fun fail function code=(lastError:=code;raise Types.Error{function=function,code=code})
  fun unsupported text=raise Types.Unsupported text
  fun rgb colour=if Word32.andb(colour,0wxFF000000)=0w0 then () else unsupported "palette and system colour encodings"
  fun native function body=body()handle Types.Error{code,...}=>fail function code
  fun text function value=if Utf8.isValid value andalso not(String.isSubstring "\000" value) then ()
    else unsupported(function ^ " requires scalar UTF-8 without NUL")
  val activationCells=ref([]:exn option ref list)
  fun pending()=case !activationCells of cell::_=> !cell | []=>NONE
  fun activation body=
    let val cell=ref(NONE:exn option) val previous= !activationCells
        val ()=activationCells:=cell::previous
        fun finish()=(activationCells:=previous;case !cell of NONE=>() | SOME e=>raise e)
        val result=body()handle e=>(activationCells:=previous;case !cell of NONE=>raise e | SOME first=>raise first)
    in finish();result end
  fun remember e=case !activationCells of []=>raise e | cell::_=>(case !cell of NONE=>cell:=SOME e | SOME _=>())
  datatype phase=Creating | Live | Destroying | Closed
  type classState={token:Types.atom,name:string,instance:Types.module,style:Word32.word,
    procedure:Types.window*Types.message->Types.reply,windows:int ref,active:int ref}
  type windowState={token:Types.window,driver:Driver.window,class:classState,phase:phase ref,
    visible:bool ref,invalid:Types.rect option ref,number:int}
  datatype objectKind=Pen of {width:int,colour:Word32.word} | Brush of Word32.word | NullPen | NullBrush
  type objectState={token:Types.object,kind:objectKind,owned:bool,live:bool ref}
  type paintState={token:Types.paint,window:windowState,drawing:Driver.drawing,live:bool ref,
    pen:Types.object ref,brush:Types.object ref,point:(int*int)ref,colour:Word32.word ref,mode:int ref}
  type timerState={window:Types.window,id:Word64.word,interval:IntInf.int,due:IntInf.int ref}
  val classes=ref([]:classState list) val windows=ref([]:windowState list)
  val objects=ref([]:objectState list) val paints=ref([]:paintState list)
  val timers=ref([]:timerState list)
  val queue=ref([]:(Types.window option*Types.message)list)
  val quit=ref(NONE:Int32.int option)
  val copies=ref([]:(Types.queued*(Types.window option*Types.message))list)
  val serial=ref 0 val nextTimer=ref(0w1:Word64.word)
  val instance=Win32Common.freshModule()
  fun findWindow function token=case List.find(fn(w:windowState)=> #token w=token)(!windows) of
    SOME w=>if !(#phase w)=Closed then fail function 0w1400 else w | NONE=>fail function 0w1400
  fun findClass function token=case List.find(fn(c:classState)=> #token c=token)(!classes) of SOME c=>c | NONE=>fail function 0w1411
  fun findObject function token=case List.find(fn(o':objectState)=> #token o'=token andalso !(#live o'))(!objects) of SOME o'=>o' | NONE=>fail function 0w6
  fun findPaint function token=case List.find(fn(p:paintState)=> #token p=token andalso !(#live p))(!paints) of
    SOME p=>(ignore(findWindow function(#token(#window p)));p) | NONE=>fail function 0w6
  fun messageCode message=case message of Types.NcCreate=>0wx81 | Types.Create=>0wx1 | Types.Size _=>0wx5
    | Types.Paint=>0wxF | Types.Close=>0wx10 | Types.Destroy=>0wx2 | Types.NcDestroy=>0wx82
    | Types.KeyDown _=>0wx100 | Types.KeyUp _=>0wx101 | Types.Char _=>0wx102 | Types.MouseMove _=>0wx200
    | Types.ButtonDown{button=1,...}=>0wx201 | Types.ButtonUp{button=1,...}=>0wx202
    | Types.ButtonDown{button=2,...}=>0wx207 | Types.ButtonUp{button=2,...}=>0wx208
    | Types.ButtonDown{button=3,...}=>0wx204 | Types.ButtonUp{button=3,...}=>0wx205
    | Types.ButtonDown _=>unsupported "mouse button" | Types.ButtonUp _=>unsupported "mouse button"
    | Types.Timer _=>0wx113 | Types.Application{code,...}=>code | Types.Unknown code=>code
  fun failure Types.NcCreate=Int64.fromInt 0 | failure Types.Create=Int64.fromInt ~1 | failure _=Int64.fromInt 0
  fun rect window=
    let val {width,height}=native "getClientRect"(fn()=>Driver.client(#driver(window:windowState)))
    in {left=Int32.fromInt 0,top=Int32.fromInt 0,right=Int32.fromInt width,bottom=Int32.fromInt height}:Types.rect end
  fun empty({left,top,right,bottom}:Types.rect)=left>=right orelse top>=bottom
  fun union(a:Types.rect,b:Types.rect):Types.rect={left=Int32.min(#left a,#left b),top=Int32.min(#top a,#top b),
    right=Int32.max(#right a,#right b),bottom=Int32.max(#bottom a,#bottom b)}
  fun intersect(a:Types.rect,b:Types.rect):Types.rect={left=Int32.max(#left a,#left b),top=Int32.max(#top a,#top b),
    right=Int32.min(#right a,#right b),bottom=Int32.min(#bottom a,#bottom b)}
  fun rectangleText({left,top,right,bottom}:Types.rect)=String.concatWith ","(List.map Int32.toString[left,top,right,bottom])
  fun enqueue window message=(ignore(messageCode message);queue:= !queue @ [(window,message)])
  fun markPaint(window:windowState,area)=
    let val client=rect window val area=case area of NONE=>client | SOME r=>intersect(r,client)
    in if empty area then () else
      (#invalid window:=SOME(case !(#invalid window) of NONE=>area | SOME old=>union(old,area));
       if !(#visible window) andalso not(List.exists(fn(w,m)=>w=SOME(#token window) andalso messageCode m=0wxF)(!queue))
       then enqueue(SOME(#token window))Types.Paint else ()) end
  fun activeWindow token=List.exists(fn(w:windowState)=> #token w=token andalso !(#phase w)<>Closed)(!windows)
  fun invoke (window:windowState) message=
    if isSome(pending()) then failure message else
    let val class= #class window val ()= #active class:= !(#active class)+1
        val reply=(#procedure class)(#token window,message)
          handle e=>(#active class:= !(#active class)-1;remember e;Types.Result(failure message))
        (* The exception path already leaves the active count. *)
        val ()=if isSome(pending()) then () else #active class:= !(#active class)-1
    in case reply of Types.Result value=>value | Types.Default=>default window message end
  and default window message=case message of Types.NcCreate=>Int64.fromInt 1
    | Types.Close=>(destroyState window;Int64.fromInt 0)
    | Types.Paint=>(#invalid window:=NONE;Int64.fromInt 0)
    | _=>Int64.fromInt 0
  and destroyState window=closeState true window
  and closeState notifyDestroy(window:windowState)=
    if !(#phase window)=Closed orelse !(#phase window)=Destroying then fail "destroyWindow" 0w1400 else
    if List.exists(fn(p:paintState)=> #token(#window p)= #token window andalso !(#live p))(!paints)
      then fail "destroyWindow" 0w170 else
    let val previous= !(#phase window) val ()= #phase window:=Destroying
        val ()=if notifyDestroy then ignore(invoke window Types.Destroy) else ()
        val ()=ignore(invoke window Types.NcDestroy)
        val ()=(native "destroyWindow"(fn()=>Driver.destroy(#driver window))handle e=>(#phase window:=previous;raise e))
        val ()= #phase window:=Closed val class= #class window
        val ()= #windows class:= !(#windows class)-1
        val ()=timers:=List.filter(fn(t:timerState)=> #window t<> #token window)(!timers)
        val ()=queue:=List.filter(fn(w,_)=>w<>SOME(#token window))(!queue)
        val ()=windows:=List.filter(fn(w:windowState)=> #token w<> #token window)(!windows)
    in note("destroy " ^ Int.toString(#number window)) end
  fun postable message=case message of Types.NcCreate=>unsupported "posting lifecycle messages" | Types.Create=>unsupported "posting lifecycle messages"
    | Types.Destroy=>unsupported "posting lifecycle messages" | Types.NcDestroy=>unsupported "posting lifecycle messages"
    | Types.Unknown _=>unsupported "synthetic unknown native messages"
    | Types.Application{code,...}=>if code>=0wx8000 andalso code<=0wxBFFF then () else unsupported "application message code"
    | Types.Size{width,height}=>if width>=0 andalso width<=65535 andalso height>=0 andalso height<=65535 then () else unsupported "synthetic WM_SIZE dimensions"
    | Types.MouseMove{x,y,...}=>coordinates(x,y)
    | Types.ButtonDown{x,y,...}=>(coordinates(x,y);ignore(messageCode message))
    | Types.ButtonUp{x,y,...}=>(coordinates(x,y);ignore(messageCode message))
    | _=>ignore(messageCode message)
  and coordinates(x,y)=if x>= ~32768 andalso x<=32767 andalso y>= ~32768 andalso y<=32767 then () else unsupported "synthetic mouse coordinates"
  val stocks=ref([]:(int*Types.object)list)
  fun stock index=
    let fun description 0=Brush 0wxFFFFFF | description 1=Brush 0wxC0C0C0 | description 2=Brush 0wx808080
          | description 3=Brush 0wx404040 | description 4=Brush 0w0 | description 5=NullBrush
          | description 6=Pen{width=1,colour=0wxFFFFFF} | description 7=Pen{width=1,colour=0w0}
          | description 8=NullPen | description _=unsupported "stock object index"
    in newStock index(description index) end
  and newStock index kind=
    case List.find(fn(i,_)=>i=index)(!stocks) of SOME(_,token)=>token | NONE=>
    let val token=Win32Common.freshObject() val state={token=token,kind=kind,owned=false,live=ref true}
    in stocks:=(index,token):: !stocks;objects:=state:: !objects;token end
  fun pump()=
    let fun events count=if count=256 then () else case Driver.poll() of NONE=>()
          | SOME Driver.Quit=>(List.app(fn(w:windowState)=>if !(#phase w)=Live then enqueue(SOME(#token w))Types.Close else())(!windows);events(count+1))
          | SOME(Driver.Message(driver,message))=>
              (case List.find(fn(w:windowState)=> #driver w=driver andalso !(#phase w)=Live)(!windows) of
                 NONE=>() | SOME w=>(case message of Types.Paint=>markPaint(w,NONE)
                   | Types.Size _=>(enqueue(SOME(#token w))message;markPaint(w,NONE))
                   | _=>enqueue(SOME(#token w))message);events(count+1))
        val ()=events 0 val now=Driver.ticks()
        fun timer(t:timerState)=if activeWindow(#window t) andalso now>= !(#due t) then
          (if List.exists(fn(w,m)=>w=SOME(#window t) andalso(case m of Types.Timer id=>id= #id t | _=>false))(!queue)
           then () else enqueue(SOME(#window t))(Types.Timer(#id t));#due t:=IntInf.+(now,#interval t)) else ()
        fun repaint(w:windowState)=if !(#phase w)=Live andalso !(#visible w) andalso isSome(!(#invalid w)) andalso
          not(List.exists(fn(token,message)=>token=SOME(#token w) andalso messageCode message=0wxF)(!queue))
          then enqueue(SOME(#token w))Types.Paint else ()
    in List.app timer(!timers);List.app repaint(!windows) end
  fun matches(window,minimum,maximum)(w,message)=
    (case window of NONE=>true | SOME token=>w=SOME token) andalso
    ((minimum=0w0 andalso maximum=0w0) orelse(messageCode message>=minimum andalso messageCode message<=maximum))
  fun take predicate remove=
    let fun loop([],prefix)=NONE | loop(x::xs,prefix)=if predicate x then
          (if remove then queue:=List.revAppend(prefix,xs) else ();SOME x) else loop(xs,x::prefix)
    in loop(!queue,[]) end
  fun copied value=let val token=Win32Common.freshQueued() in copies:=(token,value):: !copies;token end
  fun copy token=case List.find(fn(t,_)=>Win32Common.queuedKey t=Win32Common.queuedKey token)(!copies) of
    SOME(_,value)=>value | NONE=>fail "message" 0w6
  fun beginPaint token=
    let val window=findWindow "beginPaint" token
        val ()=if !(#phase window)=Destroying then fail "beginPaint" 0w1400 else ()
        val ()=if List.exists(fn(p:paintState)=> #token(#window p)=token andalso !(#live p))(!paints) then fail "beginPaint" 0w170 else ()
        val zero={left=Int32.fromInt 0,top=Int32.fromInt 0,right=Int32.fromInt 0,bottom=Int32.fromInt 0}
        val area=if !(#visible window) then intersect((case !(#invalid window) of SOME r=>r | NONE=>zero),rect window) else zero
        val black=stock 7 val white=stock 0
        val drawing=native "beginPaint"(fn()=>Driver.begin{window= #driver window,rectangle=area})
        val paint=Win32Common.freshPaint()
        val state={token=paint,window=window,drawing=drawing,live=ref true,pen=ref black,brush=ref white,
          point=ref(0,0),colour=ref 0w0,mode=ref 2}:paintState
    in paints:=state:: !paints;#invalid window:=NONE;note("begin-paint " ^ Int.toString(#number window) ^ " " ^ rectangleText area);(paint,area) end
  fun endPaint(token,paint)=
    let val p=findPaint "endPaint" paint
        val ()=if #token(#window p)=token then () else fail "endPaint" 0w6
        val ()= #live p:=false
        val ()=paints:=List.filter(fn(q:paintState)=> #token q<>paint)(!paints)
    in native "endPaint"(fn()=>Driver.finish(#drawing p));note("end-paint " ^ Int.toString(#number(#window p))) end
  structure Kernel=
  struct
    fun getModuleHandle NONE=instance | getModuleHandle(SOME _)=unsupported "named native modules"
    fun getLastError()= !lastError
    fun setLastError code=lastError:=code
    fun queryPerformanceCounter()=Driver.counter()
    fun queryPerformanceFrequency()=Driver.frequency()
  end
  structure User=
  struct
    fun registerClassEx{name,instance=module,style,procedure}=
      (text "registerClassEx" name;
       if module<>instance then fail "registerClassEx" 0w6 else ();
       if name="" then fail "registerClassEx" 0w87 else ();
       if Word32.andb(style,Word32.notb 0w3)<>0w0 then unsupported "window class style" else ();
       if List.exists(fn(c:classState)=> #name c=name)(!classes) then fail "registerClassEx" 0w1410 else ();
       let val token=Win32Common.freshAtom()
           val state={token=token,name=name,instance=module,style=style,procedure=procedure,windows=ref 0,active=ref 0}:classState
       in classes:=state:: !classes;note("register " ^ String.toString name);token end)
    fun unregisterClass(token,module)=
      let val state=findClass "unregisterClass" token
          val ()=if #instance state=module then () else fail "unregisterClass" 0w6
          val ()=if !(#windows state)=0 andalso !(#active state)=0 then () else fail "unregisterClass" 0w1412
      in classes:=List.filter(fn(c:classState)=> #token c<>token)(!classes);note("unregister " ^ String.toString(#name state)) end
    fun createWindowEx{class,instance=module,title,style,extendedStyle,x,y,width,height,parent}=activation(fn()=>
      let val state=findClass "createWindowEx" class
          val ()=if #instance state=module andalso module=instance then () else fail "createWindowEx" 0w6
          val ()=text "createWindowEx" title
          val ()=if extendedStyle<>0w0 orelse isSome parent orelse Word32.andb(style,Word32.notb 0wx10CF0000)<>0w0
            then unsupported "portable top-level window flags" else ()
          val ()=if width>0 andalso height>0 andalso IntInf.fromInt width<=2147483647 andalso IntInf.fromInt height<=2147483647
            then () else fail "createWindowEx" 0w87
          val visible=Word32.andb(style,0wx10000000)<>0w0
          val driver=native "createWindowEx"(fn()=>Driver.create{title=title,x=x,y=y,width=width,height=height,visible=visible,
            resizable=Word32.andb(style,0wx40000)<>0w0})
          val token=Win32Common.freshWindow() val ()=serial:= !serial+1
          val window={token=token,driver=driver,class=state,phase=ref Creating,visible=ref visible,invalid=ref NONE,number= !serial}:windowState
          val ()=windows:=window:: !windows val ()= #windows state:= !(#windows state)+1
          val ()=note("create " ^ Int.toString(!serial) ^ " " ^ String.toString title ^ " " ^ Int.toString x ^ "," ^ Int.toString y)
          val accepted=invoke window Types.NcCreate<>Int64.fromInt 0
          val made=accepted andalso !(#phase window)<>Closed andalso invoke window Types.Create<>Int64.fromInt ~1
          val ()=if made andalso not(isSome(pending())) andalso !(#phase window)<>Closed then #phase window:=Live
            else (if !(#phase window)=Closed then () else closeState accepted window;fail "createWindowEx" 0w1407)
          val ()=if visible then markPaint(window,NONE) else ()
      in token end)
    fun destroyWindow token=activation(fn()=>destroyState(findWindow "destroyWindow" token))
    fun showWindow(token,command)=
      let val window=findWindow "showWindow" token
          val ()=if List.exists(fn c=>c=command)[0,1,5,8,9,10] then () else unsupported "window show command"
          val previous= !(#visible window)
          val ()=native "showWindow"(fn()=>Driver.show(#driver window,command))
          val ()= #visible window:=command<>0
          val ()=if command<>0 andalso not previous then markPaint(window,NONE) else ()
      in note("show " ^ Int.toString(#number window) ^ " " ^ Int.toString command);previous end
    fun updateWindow token=activation(fn()=>let val window=findWindow "updateWindow" token
      in case !(#invalid window) of NONE=>() | SOME _=>
        (queue:=List.filter(fn(w,m)=>not(w=SOME token andalso messageCode m=0wxF))(!queue);ignore(invoke window Types.Paint)) end)
    fun defWindowProc(token,message)=activation(fn()=>case message of Types.Unknown _=>unsupported "unknown message requires native callback context"
      | _=>default(findWindow "defWindowProc" token)message)
    fun getClientRect token=rect(findWindow "getClientRect" token)
    fun setWindowText(token,value)=(text "setWindowText" value;native "setWindowText"(fn()=>Driver.title(#driver(findWindow "setWindowText" token),value));note("title " ^ String.toString value))
    fun peekMessage{window,minimum,maximum,remove}=
      (case window of NONE=>() | SOME token=>ignore(findWindow "peekMessage" token);
       pump();case take(matches(window,minimum,maximum))remove of SOME value=>SOME(copied value)
       | NONE=>case !quit of NONE=>NONE | SOME _=>(if remove then quit:=NONE else ();SOME(copied(NONE,Types.Unknown 0wx12))))
    fun getMessage{window,minimum,maximum}=
      let val ()=case window of NONE=>() | SOME token=>ignore(findWindow "getMessage" token)
          fun loop()=(pump();case take(matches(window,minimum,maximum))true of SOME value=>Types.Message(copied value) | NONE=>
            case !quit of SOME status=>(quit:=NONE;Types.Quit status) | NONE=>
            if not Driver.externalEvents andalso null(!timers) then unsupported "mock getMessage has no future event"
            else (Driver.delay 0w10;loop()))
      in loop() end
    fun translateMessage token=
      let val(window,message)=copy token
      in case message of Types.KeyDown{key,...}=>
          (if Driver.externalEvents then () else
            let val code=Word32.toLargeInt key
                val code=if code>=65 andalso code<=90 then code+32 else code
            in if code>=32 andalso code<=126 then enqueue window(Types.Char(Word16.fromLargeInt code)) else () end;true)
        | Types.KeyUp _=>true | _=>false end
    fun discardMessage token=
      (ignore(copy token);copies:=List.filter(fn(t,_)=>Win32Common.queuedKey t<>Win32Common.queuedKey token)(!copies))
    fun dispatchMessage token=
      let val value=copy token
          val ()=discardMessage token
      in activation(fn()=>case value of (NONE,_)=>Int64.fromInt 0
        | (SOME window,message)=>if activeWindow window then invoke(findWindow "dispatchMessage" window)message else Int64.fromInt 0) end
    fun postQuitMessage status=(quit:=SOME status;note("quit " ^ Int32.toString status))
    fun postMessage(token,message)=(ignore(findWindow "postMessage" token);postable message;enqueue(SOME token)message;note("post " ^ Word32.toString(messageCode message)))
    fun sendMessage(token,message)=activation(fn()=>
      (postable message;note("send " ^ Word32.toString(messageCode message));invoke(findWindow "sendMessage" token)message))
    fun invalidateRect(token,area,erase)=
      let val window=findWindow "invalidateRect" token
      in markPaint(window,area);note("invalidate " ^ Int.toString(#number window) ^ " " ^ Bool.toString erase) end
    val beginPaint=beginPaint val endPaint=endPaint
    fun withPaint token body=
      let val value=beginPaint token
          val result=body value handle e=>(endPaint(token,#1 value)handle _=>();raise e)
      in endPaint(token,#1 value);result end
    fun fillRect(paint,rectangle,brush)=
      let val p=findPaint "fillRect" paint val o'=findObject "fillRect"(Win32Common.brushObject brush)
      in case #kind o' of Brush colour=>if empty rectangle then () else
          (native "fillRect"(fn()=>Driver.fill{drawing= #drawing p,rectangle=rectangle,colour=colour});
           note("fill " ^ rectangleText rectangle ^ " " ^ Word32.toString colour))
        | NullBrush=>() | _=>fail "fillRect" 0w6 end
    fun setTimer(token,requested,milliseconds)=
      let val _=findWindow "setTimer" token
          val id=if requested=0w0 then let val n= !nextTimer in nextTimer:=Word64.+(n,0w1);n end else requested
          val interval=IntInf.max(10,Word32.toLargeInt milliseconds)
          val value={window=token,id=id,interval=interval,due=ref(IntInf.+(Driver.ticks(),interval))}:timerState
      in timers:=value::List.filter(fn(t:timerState)=>not(#window t=token andalso #id t=id))(!timers);note "set-timer";id end
    fun killTimer(token,id)=
      (ignore(findWindow "killTimer" token);
       if List.exists(fn(t:timerState)=> #window t=token andalso #id t=id)(!timers) then
         (timers:=List.filter(fn(t:timerState)=>not(#window t=token andalso #id t=id))(!timers);note "kill-timer")
       else fail "killTimer" 0w6)
  end
  structure Gdi=
  struct
    fun createPen{style,width,colour}=
      (if style<>0 then unsupported "solid pens only" else ();
       if width<0 then fail "createPen" 0w87 else ();
       rgb colour;
       let val token=Win32Common.freshPen()
           val state={token=Win32Common.penObject token,kind=Pen{width=Int.max(1,width),colour=colour},owned=true,live=ref true}
       in objects:=state:: !objects;note("pen " ^ Int.toString width ^ " " ^ Word32.toString colour);token end)
    fun createSolidBrush colour=
      let val ()=rgb colour val token=Win32Common.freshBrush()
          val state={token=Win32Common.brushObject token,kind=Brush colour,owned=true,live=ref true}
      in objects:=state:: !objects;note("brush " ^ Word32.toString colour);token end
    fun penObject pen=let val token=Win32Common.penObject pen
      in ignore(findObject "penObject" token);token end
    fun brushObject brush=let val token=Win32Common.brushObject brush
      in ignore(findObject "brushObject" token);token end
    fun objectBrush token=case #kind(findObject "objectBrush" token) of
      Brush _=>Win32Common.objectBrush token | NullBrush=>Win32Common.objectBrush token | _=>fail "objectBrush" 0w6
    fun selectObject(paint,token)=
      let val p=findPaint "selectObject" paint val state=findObject "selectObject" token
          val slot=case #kind state of Pen _=> #pen p | NullPen=> #pen p | _=> #brush p
          val previous= !slot
      in slot:=token;note "select";previous end
    fun deleteObject token=
      let val state=findObject "deleteObject" token
          val ()=if #owned state then () else fail "deleteObject" 0w6
          val ()=if List.exists(fn(p:paintState)=> !(#live p) andalso(!(#pen p)=token orelse !(#brush p)=token))(!paints)
            then fail "deleteObject" 0w170 else ()
      in #live state:=false;objects:=List.filter(fn(o':objectState)=> #token o'<>token)(!objects);note "delete" end
    val getStockObject=stock
    fun moveToEx(paint,x,y)=
      let val p=findPaint "moveToEx" paint val(previousX,previousY)= !(#point p)
      in #point p:=(x,y);note("move " ^ Int.toString x ^ "," ^ Int.toString y);{x=previousX,y=previousY} end
    fun lineTo(paint,x,y)=
      let val p=findPaint "lineTo" paint val(x1,y1)= !(#point p)
          val state=findObject "lineTo"(!(#pen p))
          val ()=case #kind state of Pen{width,colour}=>native "lineTo"(fn()=>Driver.line{drawing= #drawing p,x1=x1,y1=y1,x2=x,y2=y,width=width,colour=colour})
            | NullPen=>() | _=>fail "lineTo" 0w6
      in #point p:=(x,y);note("line " ^ Int.toString x ^ "," ^ Int.toString y) end
    fun rectangle(paint,area:Types.rect)=
      if empty area then ignore(findPaint "rectangle" paint) else
      let val p=findPaint "rectangle" paint
          val brush=objectBrush(!(#brush p))
          val ()=User.fillRect(paint,area,brush)
          val old= !(#point p)
          val x1=Int32.toInt(#left area) val x2=Int32.toInt(#right area)-1
          val y1=Int32.toInt(#top area) val y2=Int32.toInt(#bottom area)-1
          val ()=ignore(moveToEx(paint,x1,y1))
          val ()=(lineTo(paint,x2,y1);lineTo(paint,x2,y2);lineTo(paint,x1,y2);lineTo(paint,x1,y1))
            handle e=>(#point p:=old;raise e)
      in #point p:=old;note "rectangle" end
    fun setTextColor(paint,colour)=let val p=findPaint "setTextColor" paint val ()=rgb colour val old= !(#colour p)
      in #colour p:=colour;note("text-colour " ^ Word32.toString colour);old end
    fun setBkMode(paint,mode)=
      let val p=findPaint "setBkMode" paint val ()=if mode=1 orelse mode=2 then () else unsupported "text background mode"
          val old= !(#mode p)
      in #mode p:=mode;note("background " ^ Int.toString mode);old end
    fun textOut(paint,x,y,text)=
      let val p=findPaint "textOut" paint
          val ()=if List.all(fn c=>Char.ord c>=32 andalso Char.ord c<=126)(String.explode text) then () else unsupported "portable GDI text requires printable ASCII"
      in native "textOut"(fn()=>Driver.text{drawing= #drawing p,x=x,y=y,text=text,colour= !(#colour p),opaque= !(#mode p)=2,background=0wxFFFFFF});
         note("text " ^ Int.toString x ^ "," ^ Int.toString y ^ " " ^ String.toString text) end
  end
  fun inject(token,message)=User.postMessage(token,message)
  fun advance milliseconds=Driver.delay milliseconds
  fun reset()=
    if not(null(!classes)) orelse List.exists(fn(w:windowState)=> !(#phase w)<>Closed)(!windows) orelse
      List.exists(fn(p:paintState)=> !(#live p))(!paints) orelse List.exists(fn(o':objectState)=> #owned o' andalso !(#live o'))(!objects)
    then fail "reset" 0w170 else
      (observations:=[];windows:=[];paints:=[];copies:=[];queue:=[];timers:=[];quit:=NONE;lastError:=0w0;serial:=0;nextTimer:=0w1)
end

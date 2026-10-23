(* Implements: WIN32_MOCK *)
structure Win32Mock : WIN32_MOCK
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
  Win32ModelFn(struct
  type window=int
  type drawing=window
  datatype event=Quit | Message of window*Win32Common.Types.message
  val externalEvents=false
  type state={id:window,width:int,height:int,title:string ref,visible:bool ref}
  val windows=ref([]:state list) val next=ref 0 val clock=ref(0:IntInf.int)
  fun window id=case List.find(fn(s:state)=> #id s=id)(!windows) of SOME s=>s
    | NONE=>raise Win32Common.Types.Error{function="mock-window",code=0w1400}
  fun create{title,x,y,width,height,visible,resizable}=
    let val ()=next:= !next+1 val id= !next
    in windows:={id=id,width=width,height=height,title=ref title,visible=ref visible}:: !windows;id end
  fun destroy id=(ignore(window id);windows:=List.filter(fn(s:state)=> #id s<>id)(!windows))
  fun show(id,command)= #visible(window id):=command<>0
  fun title(id,text)= #title(window id):=text
  fun client id=let val state=window id in {width= #width state,height= #height state} end
  fun begin{window=id,rectangle}=(ignore(window id);id)
  fun finish id=ignore(window id)
  fun fill{drawing,rectangle,colour}=ignore(window drawing)
  fun line{drawing,x1,y1,x2,y2,width,colour}=ignore(window drawing)
  fun text{drawing,x,y,text,colour,opaque,background}=ignore(window drawing)
  fun poll()=NONE
  fun ticks()= !clock
  fun counter()=Int64.fromLarge(IntInf.*(!clock,1000000))
  fun frequency()=Int64.fromLarge 1000000000
  fun delay milliseconds=clock:=IntInf.+(!clock,Word32.toLargeInt milliseconds)
  end)

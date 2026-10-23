(* A class registered by an early REPL entry must retain its closure after
   later entries append code, collect, and replace the closure it calls. *)
structure Win32ReplTest =
struct
  structure W=Win32Native
  structure T=W.Types
  val created=ref 0
  val destroyed=ref 0
  val innerCalls=ref 0
  val creationIdentity=ref(NONE:T.window option)
  val hook=ref(fn(_:T.window)=>Int64.fromInt 0)
  fun check(name,condition)=if condition then () else raise Fail("Win32 REPL: " ^ name)
  val instance=W.Kernel.getModuleHandle NONE
  val class=W.User.registerClassEx{name="RuneffiRetainedReplClass",instance=instance,style=0w0,
    procedure=fn(window,message)=>case message of
      T.NcCreate=>(created:= !created+1;creationIdentity:=SOME window;T.Default)
    | T.NcDestroy=>(destroyed:= !destroyed+1;T.Default)
    | T.Application{code=0wx8001,...}=>T.Result(Int64.+((!hook)window,Int64.fromInt 1))
    | T.Application{code=0wx8002,...}=>(innerCalls:= !innerCalls+1;T.Result(Int64.fromInt 42))
    | _=>T.Default}
  fun create title=
    let val window=W.User.createWindowEx{class=class,instance=instance,title=title,style=0wx00CF0000,
          extendedStyle=0w0,x=40,y=40,width=160,height=100,parent=NONE}
        val ()=check("creation callback identity",!creationIdentity=SOME window)
    in window end
  val ()=check("class retains native callback",RuneForeign.live()>0w0)
end

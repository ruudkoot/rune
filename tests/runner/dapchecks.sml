(* DAP requests are typed messages; assertions retain the editor-facing
   values and UTF-16 columns of the independent legacy transcript driver. *)
structure DapChecks =
struct
  open Sh
  exception Failed of string
  type adapter={child:ProtocolIO.child,seq:int ref,seen:Json.value list ref}
  fun need (ok,why)=if ok then () else raise Failed why
  fun object fields=Json.Object fields
  fun number n=Json.Number (Int.toString n)
  fun string text=Json.String text
  fun get value key=case Json.member (key,value) of SOME value => value | NONE => raise Failed ("DAP field missing: " ^ key)
  fun array (Json.Array rows)=rows | array _=raise Failed "DAP expected array"
  fun text (Json.String text)=text | text _=raise Failed "DAP expected string"
  fun integer value=case Json.toInt value of SOME n => n | NONE => raise Failed "DAP expected integer"
  fun body value=get value "body"
  fun yes value=get value "success"=Json.Bool true
  fun request (adapter : adapter) command arguments =
    let val seq= !(#seq adapter)+1
        val ()= #seq adapter:=seq
        val message=Dap.Request {seq=seq,command=command,arguments=arguments}
    in ProtocolIO.sendRaw (#child adapter) (Dap.encode message);seq end
  fun until (adapter : adapter) predicate =
    let val deadline=Time.+ (Runtime.clock (),Time.fromSeconds 60)
        fun loop ()=case ProtocolIO.receiveTime (#child adapter) (Time.- (deadline,Runtime.clock ())) (fn (_,_) => ()) of
              NONE => raise Failed "DAP adapter ended before the expected message"
            | SOME message =>
                let val value=Json.decode message
                    val ()=need (isSome (Dap.fromJson value),"invalid DAP message")
                    val ()= #seen adapter := !(#seen adapter) @ [value]
                in if predicate value then value else loop () end
    in loop () end
  fun response adapter seq=until adapter (fn value => Json.member ("type",value)=SOME (string "response") andalso Json.member ("request_seq",value)=SOME (number seq))
  fun event adapter name=until adapter (fn value => Json.member ("type",value)=SOME (string "event") andalso Json.member ("event",value)=SOME (string name))
  fun ask adapter command arguments=response adapter (request adapter command (SOME arguments))
  fun frames adapter=array (get (body (ask adapter "stackTrace" (object [("threadId",number 1)]))) "stackFrames")
  fun variables adapter frame =
    let val response=ask adapter "scopes" (object [("frameId",number frame)])
        val scopes=array (get (body response) "scopes")
        val reference=integer (get (hd scopes) "variablesReference")
        val response=ask adapter "variables" (object [("variablesReference",number reference)])
    in List.map (fn row => (text (get row "name"),text (get row "value"))) (array (get (body response) "variables")) end
  fun sameVariables actual expected=length actual=length expected andalso List.all (fn row => List.exists (fn value => value=row) actual) expected
  fun outputs (adapter : adapter)=String.concat (List.mapPartial (fn value => if Json.member ("event",value)=SOME (string "output") then
          let val value=body value in if get value "category"=string "stdout" then SOME (text (get value "output")) else NONE end else NONE) (!(#seen adapter)))
  fun start args directory : adapter={child=ProtocolIO.spawn {args=args,directory=directory,environment=Posix.ProcEnv.environ (),engine=false,framing=Framing.ContentLength},
                                      seq=ref 0,seen=ref []}
  fun finish (adapter : adapter)=
    let val _=ask adapter "disconnect" (object []) handle ProtocolIO.Failed _ => Json.Null | Failed _ => Json.Null
        val ended=ProtocolIO.wait (#child adapter) 30
        val ()=ProtocolIO.close (#child adapter)
    in need (#status ended=Posix.Process.W_EXITED,"DAP adapter did not exit successfully") end
  fun one args directory () =
    let val active=ref NONE : adapter option ref
        fun run () =
          let val a=start args directory
              val ()=active:=SOME a
              val r=ask a "initialize" (object [("adapterID",string "rune"),("linesStartAt1",Json.Bool true),("columnsStartAt1",Json.Bool true)])
              val ()=need (yes r andalso get (body r) "supportsConfigurationDoneRequest"=Json.Bool true,"DAP initialize capabilities")
              val _=event a "initialized"
              val prog="tests/dap/prog.sml"
              val ()=need (yes (ask a "launch" (object [("program",string prog)])),"DAP launch")
              val r=ask a "setBreakpoints" (object [("source",object [("path",string prog)]),("breakpoints",Json.Array [object [("line",number 3)],object [("line",number 11)]])])
              val ()=need (yes r andalso length (array (get (body r) "breakpoints"))=2,"DAP breakpoints")
              val ()=need (yes (ask a "setExceptionBreakpoints" (object [("filters",Json.Array [string "all"])])),"DAP exception breakpoints")
              val ()=need (yes (ask a "configurationDone" (object [])),"DAP configurationDone")
              val e=event a "stopped"
              val ()=need (get (body e) "reason"=string "breakpoint","DAP breakpoint stop")
              val r=ask a "threads" (object [])
              val threads=array (get (body r) "threads")
              val ()=need (length threads=1 andalso get (hd threads) "id"=number 1 andalso get (hd threads) "name"=string "main","DAP threads")
              val fs=frames a
              val frame=hd fs
              val ()=need (get frame "name"=string "f" andalso get frame "line"=number 3 andalso get (get frame "source") "path"=string prog,"DAP stackTrace")
              val ()=need (sameVariables (variables a (integer (get frame "id"))) [("x","20"),("y","21")],"DAP frame variables")
              val r=ask a "evaluate" (object [("expression",string "x + y * 10"),("frameId",number 0),("context",string "repl")])
              val ()=need (yes r andalso get (body r) "result"=string "230","DAP evaluate in frame")
              val r=ask a "evaluate" (object [("expression",string "nothere + 1"),("frameId",number 0),("context",string "repl")])
              val ()=need (not (yes r) andalso String.isSubstring "nothere" (text (get r "message")),"DAP evaluate error")
              val ()=need (yes (ask a "next" (object [("threadId",number 1)])),"DAP next")
              val e=event a "stopped"
              val fs=frames a
              val ()=need (get (body e) "reason"=string "step" andalso get (hd fs) "line"=number 4,"DAP next line")
              val ()=need (sameVariables (variables a 0) [("x","20"),("y","21"),("z","42")],"DAP next variables")
              val ()=need (yes (ask a "continue" (object [("threadId",number 1)])),"DAP continue")
              val e=event a "stopped"
              val fs=frames a
              val ()=need (get (body e) "reason"=string "exception" andalso get (hd fs) "name"=string "h"
                             andalso String.isSubstring "zero" (text (get (body e) "text")),"DAP raise stop")
              val ()=need (yes (ask a "continue" (object [("threadId",number 1)])),"DAP continue after raise")
              val e=event a "stopped"
              val fs=frames a
              val ()=need (get (body e) "reason"=string "breakpoint" andalso get (hd fs) "name"=string "g"
                         andalso get (List.nth (fs,1)) "line"=number 12 andalso get (List.nth (fs,1)) "column"=number 20,"DAP UTF-16 caller column")
              val ()=need (yes (ask a "continue" (object [("threadId",number 1)])),"DAP continue to end")
              val _=event a "terminated"
              val ()=need (outputs a="r = 63\ndone 4\n","DAP stdout events")
              val exited=List.filter (fn value => Json.member ("event",value)=SOME (string "exited")) (!(#seen a))
              val ()=need (not (null exited) andalso get (body (hd exited)) "exitCode"=number 0,"DAP exit event")
              val ()=finish a
              val ()=active:=NONE
              val a=start args directory
              val ()=active:=SOME a
              val _=ask a "initialize" (object [("adapterID",string "rune")])
              val _=ask a "launch" (object [("program",string "tests/dap/loop.sml")])
              val _=ask a "configurationDone" (object [])
              val ()=OS.Process.sleep (Time.fromSeconds 1)
              val ()=need (yes (ask a "pause" (object [("threadId",number 1)])),"DAP pause")
              val e=event a "stopped"
              val fs=frames a
              val ()=need (get (body e) "reason"=string "pause" andalso get (hd fs) "name"=string "loop","DAP paused in loop")
              val ()=need (List.exists (fn (name,_) => name="n") (variables a 0),"DAP loop variable")
              val ()=finish a
          in active:=NONE;say "PASS DAP frame, exception, column, output and pause sessions\n" end
    in run () handle e => (case !active of NONE => () | SOME a =>
          ((ProtocolIO.signal (#child a) Posix.Signal.kill handle OS.SysErr _ => ());
           (ignore (ProtocolIO.wait (#child a) 5) handle _ => ());ProtocolIO.close (#child a));raise e) end
end

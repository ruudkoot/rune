(* A notebook client on lib/jupyter and lib/zmtp. Every reply is authenticated
   and correlated, and each asynchronous exchange has one finite deadline. *)
structure KernelChecks =
struct
  open Sh
  exception Failed of string
  fun need (ok,why)=if ok then () else raise Failed why
  fun obj rows=Json.Object rows
  fun str text=Json.String text
  fun num n=Json.Number (Int.toString n)
  fun get value key=case Json.member (key,value) of SOME value => value | NONE => raise Failed ("kernel field missing: " ^ key)
  fun text (Json.String s)=s | text _=raise Failed "kernel expected string"
  fun int value=case Json.toInt value of SOME n => n | NONE => raise Failed "kernel expected integer"
  fun rows (Json.Array xs)=xs | rows _=raise Failed "kernel expected array"
  fun has value key expected=Json.member (key,value)=SOME expected
  fun check name condition=(need (condition,name);say ("PASS " ^ name ^ "\n"))
  fun timeout ()=case Int.fromString (env ("PROTOCOL_TIMEOUT","60")) of SOME n =>
          if n>0 then Time.fromSeconds (LargeInt.fromInt n) else raise Failed "protocol timeout must be positive"
        | NONE => raise Failed "invalid protocol timeout"
  fun connection directory key =
    let fun reserve ()=let val s=INetSock.TCP.socket ()
                           val ()=Socket.bind (s,INetSock.any 0)
                       in (s,#2 (INetSock.fromAddr (Socket.Ctl.getSockName s))) end
        val reserved=List.tabulate (5,fn _ => reserve ())
        val ports=List.map #2 reserved
        val value=obj [("shell_port",num (List.nth (ports,0))),("iopub_port",num (List.nth (ports,1))),
             ("stdin_port",num (List.nth (ports,2))),("control_port",num (List.nth (ports,3))),("hb_port",num (List.nth (ports,4))),
             ("ip",str "127.0.0.1"),("key",str key),("transport",str "tcp"),("signature_scheme",str "hmac-sha256"),("kernel_name",str "rune")]
        val file=directory ^ "/connection.json"
        val ()=mkdirs directory
        val ()=write (file,Json.encode value ^ "\n")
        val ()=List.app (Socket.close o #1) reserved
    in (file,Jupyter.readConnection (Json.encode value)) end
  fun client (conn : Jupyter.connection) {interrupt,cleanup} () =
    let val deadline=Time.+ (Runtime.clock (),Time.fromSeconds 15)
        fun connect kind port identity =
          Zmtp.connect (kind,{host= #ip conn,port=port},{identity=identity}) handle Zmtp.Error why =>
            if Time.>= (Runtime.clock (),deadline) then raise Failed ("kernel startup: " ^ why)
            else (OS.Process.sleep (Time.fromMilliseconds 25);connect kind port identity)
        val shell=connect Zmtp.Dealer (#shell conn) (SOME "client")
        val control=connect Zmtp.Dealer (#control conn) (SOME "client")
        val stdin=connect Zmtp.Dealer (#stdin conn) (SOME "client")
        val iopub=connect Zmtp.Sub (#iopub conn) NONE
        val hb=connect Zmtp.Req (#heartbeat conn) NONE
        val sockets=[shell,control,stdin,iopub,hb]
        val ()=Zmtp.subscribe (iopub,"")
        val sequence=ref 0
        val debugSequence=ref 0
        fun send socket kind content =
          let val ()=sequence:= !sequence+1
              val id="rune-test-" ^ Int.toString (!sequence)
              val message={identities=[],header={msgId=id,session="rune-test",username="test",date="2026-10-10T00:00:00Z",msgType=kind,version="5.4"},
                  parent=obj [],metadata=obj [],content=content,buffers=[]} : Jupyter.message
          in Zmtp.send (socket,Jupyter.encode (#key conn) message);id end
        fun raw socket =
          let val deadline=Time.+ (Runtime.clock (),timeout ())
              fun loop ()=case Zmtp.receive socket of SOME parts => parts | NONE =>
                 if Time.>= (Runtime.clock (),deadline) then raise Failed "kernel reply timed out"
                 else (ignore (Zmtp.wait (sockets,SOME (Time.fromMilliseconds 50)));loop ())
          in loop () end
        fun receive socket=case Jupyter.decode (#key conn) (raw socket) of SOME m => m | NONE => raise Failed "kernel message has invalid framing or signature"
        fun reply socket id kind =
          let val m=receive socket
          in need (#msgType (#header m)=kind andalso has (#parent m) "msg_id" (str id),"kernel reply type/parent ID differs");#content m end
        fun publications id =
          let val deadline=Time.+ (Runtime.clock (),timeout ())
              fun loop acc =
                let val ()=need (Time.< (Runtime.clock (),deadline),"kernel never became idle")
                    val m=receive iopub
                    val kind= #msgType (#header m)
                    val content= #content m
                in if not (has (#parent m) "msg_id" (str id)) then loop acc else
                   if kind="status" andalso has content "execution_state" (str "idle") then List.rev ((kind,content)::acc)
                   else loop ((kind,content)::acc) end
          in loop [] end
        fun request kind content input =
          let val id=send shell kind content
              val ()=case input of NONE => () | SOME answer =>
                   let val m=receive stdin
                       val ()=check "input_request on stdin" (#msgType (#header m)="input_request" andalso has (#parent m) "msg_id" (str id))
                   in ignore (send stdin "input_reply" (obj [("value",str answer)])) end
              val expected=String.substring (kind,0,size kind-size "request") ^ "reply"
              val result=reply shell id expected
              val ()=check (kind ^ " answered") true
          in (result,publications id) end
        fun execute code input=request "execute_request" (obj [("code",str code),("silent",Json.Bool false),("store_history",Json.Bool true),
                     ("user_expressions",obj []),("allow_stdin",Json.Bool (isSome input)),("stop_on_error",Json.Bool true)]) input
        fun ofKind said kind=List.map #2 (List.filter (fn (k,_) => k=kind) said)
        fun result said expected=case ofKind said "execute_result" of [v] => has (get v "data") "text/plain" (str expected) | _ => false
        fun debug command arguments =
          let val ()=debugSequence:= !debugSequence+1
              val id=send control "debug_request" (obj [("seq",num (!debugSequence)),("type",str "request"),("command",str command),("arguments",arguments)])
              val result=reply control id "debug_reply"
              val ()=check ("debug " ^ command ^ " answered") (has result "request_seq" (num (!debugSequence)))
          in result end
        fun debugOK command args=let val r=debug command args in check command (has r "success" (Json.Bool true));r end
        fun body value=get value "body"
        fun run ()=
          let val ()=Zmtp.send (hb,["beat"])
              val ()=check "the heart beats" (raw hb=["beat"])
              (* Flush the subscription before the first execution. *)
              val ()=Zmtp.flush (iopub,SOME (Time.fromSeconds 2))
              val ()=OS.Process.sleep (Time.fromMilliseconds 500)
              val (r,_)=request "kernel_info_request" (obj []) NONE
              val ()=check "kernel_info" (has (get r "language_info") "name" (str "sml") andalso has r "implementation" (str "rune-kernel")
                               andalso has r "protocol_version" (str "5.4") andalso has r "debugger" (Json.Bool true))
              val (r,said)=execute "val x = 1 + 2" NONE
              val ()=check "a declaration without its ;" (has r "status" (str "ok") andalso has r "execution_count" (num 1))
              val ()=check "its result as text" (result said "val x = 3 : int")
              val html=text (get (get (hd (ofKind said "execute_result")) "data") "text/html")
              val ()=check "its result as HTML in the palette's styles" (String.isSubstring "rune-syn-number" html andalso String.isSubstring "<style>" html)
              val (_,said)=execute "val () = print \"hello\\n\"; val () = TextIO.output (TextIO.stdErr, \"to stderr\\n\");" NONE
              val streams=ofKind said "stream"
              fun stream name value=List.exists (fn v => has v "name" (str name) andalso has v "text" (str value)) streams
              val ()=check "the program's output as streams" (stream "stdout" "hello\n" andalso stream "stderr" "to stderr\n")
              val (r,said)=execute "val y = x + undefined;" NONE
              val errors=ofKind said "error"
              val ()=check "a compile error" (has r "status" (str "error") andalso length errors=1 andalso
                   String.isSubstring "unbound variable or constructor: undefined" (text (hd (rows (get (hd errors) "traceback")))))
              val (r,said)=execute "fun f 0 = raise Fail \"zero\" | f n = f (n - 1); f 2 : int;" NONE
              val errors=ofKind said "error"
              val trace=List.map text (rows (get (hd errors) "traceback"))
              val ()=check "an uncaught exception" (has r "status" (str "error") andalso has r "ename" (str "Fail") andalso length errors=1 andalso
                     hd trace="uncaught exception Fail: zero" andalso List.exists (String.isSubstring "in f at") trace)
              val (r,_)=request "is_complete_request" (obj [("code",str "val z = let in 1")]) NONE
              val ()=check "is_complete: incomplete" (has r "status" (str "incomplete"))
              val (r,_)=request "is_complete_request" (obj [("code",str "val z = 1;")]) NONE
              val ()=check "is_complete: complete" (has r "status" (str "complete"))
              val (r,_)=request "complete_request" (obj [("code",str "List.fil"),("cursor_pos",num 8)]) NONE
              val ()=check "complete" (List.exists (fn v => v=str "filter") (rows (get r "matches")) andalso has r "cursor_start" (num 5) andalso has r "cursor_end" (num 8))
              val (r,_)=request "inspect_request" (obj [("code",str "List.map"),("cursor_pos",num 6),("detail_level",num 0)]) NONE
              val ()=check "inspect" (has r "found" (Json.Bool true) andalso String.isSubstring "val List.map" (text (get (get r "data") "text/plain")))
              val (_,said)=execute "val l = TextIO.inputLine TextIO.stdIn;" (SOME "typed")
              val ()=check "input from the notebook" (result said "val l = SOME \"typed\\n\" : string option")
              val (_,said)=execute "Display.displayAs (\"d\", [(\"text/html\", \"<b>first</b>\"), (\"text/plain\", \"first\")]); Display.update (\"d\", [(\"text/plain\", \"second\")]); Display.clear true;" NONE
              val displays=ofKind said "display_data"
              val updates=ofKind said "update_display_data"
              val ()=check "Display: display_data, update_display_data, clear_output" (not (null displays) andalso not (null updates) andalso not (null (ofKind said "clear_output"))
                     andalso has (get (hd displays) "data") "text/html" (str "<b>first</b>") andalso has (get (hd displays) "transient") "display_id" (str "d")
                     andalso has (get (hd updates) "data") "text/plain" (str "second"))
              val _=debugOK "initialize" (obj [("clientID",str "test"),("adapterID",str "rune")])
              val _=debugOK "attach" (obj [])
              val info=body (debug "debugInfo" (obj []))
              val ()=check "debugInfo" (has info "isStarted" (Json.Bool true) andalso has info "hashMethod" (str "Murmur2") andalso has info "tmpFileSuffix" (str ".sml"))
              val cell="fun dbl x =\n  let val y = x + 1\n  in y * 2\n  end"
              val path=text (get (body (debug "dumpCell" (obj [("code",str cell)]))) "sourcePath")
              (* Frozen from the independent Python notebook client. *)
              val ()=need (get info "hashSeed"=Json.Number "3339675911","Jupyter hash seed differs")
              val hash="1889632010"
              val ()=check "dumpCell names the cell by its hash" (path=text (get info "tmpFilePrefix") ^ hash ^ text (get info "tmpFileSuffix") andalso read path=cell)
              val r=debugOK "setBreakpoints" (obj [("source",obj [("path",str path)]),("breakpoints",Json.Array [obj [("line",num 2)]])])
              val ()=check "setBreakpoints" (length (rows (get (body r) "breakpoints"))=1)
              val _=debugOK "configurationDone" (obj [])
              val (r,_)=execute cell NONE
              val ()=check "the cell compiled under its file" (has r "status" (str "ok"))
              val id=send shell "execute_request" (obj [("code",str "dbl 20;"),("silent",Json.Bool false),("store_history",Json.Bool true),
                     ("user_expressions",obj []),("allow_stdin",Json.Bool false),("stop_on_error",Json.Bool true)])
              val stopDeadline=Time.+ (Runtime.clock (),timeout ())
              fun stopped ()=let val ()=need (Time.< (Runtime.clock (),stopDeadline),"missing debugger stop")
                                 val m=receive iopub
                             in if #msgType (#header m)="debug_event" then #content m else stopped () end
              val stop=stopped ()
              val ()=check "a stop is a debug_event" (has stop "event" (str "stopped") andalso has (body stop) "reason" (str "breakpoint"))
              val frame=hd (rows (get (body (debug "stackTrace" (obj [("threadId",num 1)]))) "stackFrames"))
              val ()=check "stackTrace: the cell's frame" (has frame "name" (str "dbl") andalso has frame "line" (num 2) andalso has (get frame "source") "path" (str path))
              val scope=hd (rows (get (body (debug "scopes" (obj [("frameId",num 0)]))) "scopes"))
              val variables=rows (get (body (debug "variables" (obj [("variablesReference",get scope "variablesReference")]))) "variables")
              val ()=check "variables" (length variables=1 andalso has (hd variables) "name" (str "x") andalso has (hd variables) "value" (str "20"))
              val r=debugOK "evaluate" (obj [("expression",str "x * 2"),("frameId",num 0),("context",str "repl")])
              val ()=check "evaluate in the frame" (has (body r) "result" (str "40"))
              val _=debugOK "continue" (obj [("threadId",num 1)])
              val r=reply shell id "execute_reply"
              val said=publications id
              val ()=check "the cell ends" (has r "status" (str "ok") andalso result said "val it = 42 : int")
              val _=debugOK "disconnect" (obj [("restart",Json.Bool false)])
              val id=send shell "execute_request" (obj [("code",str "fun loop () : unit = loop (); loop ();"),("silent",Json.Bool false),
                      ("store_history",Json.Bool true),("user_expressions",obj []),("allow_stdin",Json.Bool false),("stop_on_error",Json.Bool true)])
              val ()=Zmtp.flush (shell,SOME (Time.fromSeconds 5))
              val ()=OS.Process.sleep (Time.fromMilliseconds 1500)
              val ()=interrupt ()
              val r=reply shell id "execute_reply"
              val _=publications id
              val ()=check "an interrupt ends the execution" (has r "status" (str "error") andalso has r "ename" (str "Interrupt"))
              val (r,said)=execute "x + 1;" NONE
              val ()=check "the session goes on" (has r "status" (str "ok") andalso result said "val it = 4 : int")
              val id=send control "shutdown_request" (obj [("restart",Json.Bool false)])
              val r=reply control id "shutdown_reply"
          in check "shutdown" (has r "status" (str "ok")) end
        val ()=(run () handle e =>
             ((cleanup ();
               let val id=send control "shutdown_request" (obj [("restart",Json.Bool false)])
               in ignore (reply control id "shutdown_reply") end) handle _ => ();
              List.app Zmtp.close sockets;raise e))
    in List.app Zmtp.close sockets end
end

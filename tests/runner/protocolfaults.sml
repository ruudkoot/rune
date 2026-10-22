(* Malformed peers exercise the public controller, independently of the
   production server. Faults run under the same outer process supervisor. *)
structure ProtocolFaults =
struct
  open Sh
  fun need (ok,why)=if ok then () else raise Fail ("protocol fault: " ^ why)
  fun peer mode file () =
    let val conn=Jupyter.readConnection (read file)
        val shell=Zmtp.bind (Zmtp.Router,{host= #ip conn,port= #shell conn})
        val control=Zmtp.bind (Zmtp.Router,{host= #ip conn,port= #control conn})
        val stdin=Zmtp.bind (Zmtp.Router,{host= #ip conn,port= #stdin conn})
        val pub=Zmtp.bind (Zmtp.Pub,{host= #ip conn,port= #iopub conn})
        val hb=Zmtp.bind (Zmtp.Rep,{host= #ip conn,port= #heartbeat conn})
        val sockets=[shell,control,stdin,pub,hb]
        val deadline=Time.+ (Runtime.clock (),Time.fromSeconds 15)
        fun loop () =
          if Time.>= (Runtime.clock (),deadline) then raise Fail "fault peer expired" else
          let val _=Zmtp.wait (sockets,SOME (Time.fromMilliseconds 50))
              val ()=case Zmtp.receive hb of NONE => () | SOME parts => (Zmtp.send (hb,parts);Zmtp.flush (hb,SOME (Time.fromSeconds 2)))
          in case Zmtp.receive shell of NONE => loop () | SOME parts =>
              if mode="exit" then () else
              let val message=case Jupyter.decode (#key conn) parts of SOME m => m | NONE => raise Fail "fault client sent invalid request"
                  val parent=if mode="parent" then Json.Object [("msg_id",Json.String "wrong-request")] else Jupyter.headerJson (#header message)
                  val response={identities= #identities message,header={msgId="reply",session="fault",username="test",date="2026-10-10",msgType="kernel_info_reply",version="5.4"},
                                parent=parent,metadata=Json.Object [],content=Json.Object [],buffers=[]} : Jupyter.message
                  val encoded=Jupyter.encode (#key conn) response
                  fun corrupt []=[] | corrupt ("<IDS|MSG>" :: _ :: rest)="<IDS|MSG>" :: "bad-signature" :: rest | corrupt (x::xs)=x :: corrupt xs
                  val ()=Zmtp.send (shell,if mode="signature" then corrupt encoded else encoded)
              in Zmtp.flush (shell,SOME (Time.fromSeconds 2)) end end
        val ()=(loop () handle e => (List.app Zmtp.close sockets;raise e))
    in List.app Zmtp.close sockets end
  fun peerCheck mode file () =KernelChecks.client (Jupyter.readConnection (read file)) {interrupt=fn () => (),cleanup=fn () => ()} ()
  fun executable file text=(write (file,"#!/bin/sh\n" ^ text ^ "\n");Posix.FileSys.chmod (file,Posix.FileSys.S.irwxu))
  fun one () =
    let val directory=run ^ "/protocol-faults"
        val ()=mkdirs directory
        val worker=fromRoot "bin/rune-protocol-check"
        fun rejected name changes args expected =
          let val status=Children.exec Subprocess.unlimited
                  (fn env => List.foldl (fn ((key,value),env) => setEnv (key,value) env) env changes)
                  {cmd=args,dir=SOME root,stdin="",stdout=directory ^ "/" ^ name ^ ".out",stderr=directory ^ "/" ^ name ^ ".err",timeout=30}
              val ()=write (directory ^ "/" ^ name ^ ".status",Int.toString status ^ "\n")
              val out=read (directory ^ "/" ^ name ^ ".out")
          in need (status<>0 andalso status<>124 andalso String.isSubstring expected out,
                   "unexpected " ^ name ^ " result (exit " ^ Int.toString status ^ "): " ^ out ^ read (directory ^ "/" ^ name ^ ".err"));
             say ("PASS protocol rejects " ^ name ^ "\n") end
        fun kernel mode =
          let val (file,_)=KernelChecks.connection (directory ^ "/" ^ mode) "fault-key"
              val child as (pid,_)=ProtocolChecks.launch directory ("peer-" ^ mode) [worker,"fault-peer",mode,file] (Posix.ProcEnv.environ ())
              val ()=(rejected mode [("PROTOCOL_TIMEOUT","2")] [worker,"fault-client",mode,file]
                     (if mode="signature" then "invalid framing or signature" else if mode="parent" then "reply type/parent ID differs" else "FAIL protocol")
                         handle e => (ProtocolChecks.reap pid;raise e))
          in ProtocolChecks.wait child 15 end
        val ()=List.app kernel ["signature","parent","exit"]
        val fixture=directory ^ "/fixture"
        val ()=(mkdirs (fixture ^ "/bin");mkdirs (fixture ^ "/tests/repl-protocol"))
        fun repl (name,program,expected) =
          (* Read the request before the planted reply/exit: otherwise a
             fast peer closes fd 3 while the controller is still writing,
             testing SIGPIPE instead of the selected framing/lifecycle fault. *)
          let val ()=executable (fixture ^ "/bin/rune-repl") ("IFS= read -r request <&3 || exit 2\n" ^ program)
              val ()=write (fixture ^ "/tests/repl-protocol/" ^ name ^ ".script","send {\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\"}\nuntil 1\nend\n")
          in rejected name [("RUNE_TEST_ROOT",fixture)] [worker,"repl",name] expected end
        val ()=List.app repl
             [("bad-headers","printf 'Content-Length: invalid\\r\\n\\r\\n' >&4","a length that is no number"),
              ("wrong-id","printf '%s\\n' '{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{}}' >&4","engine closed its channel"),
              ("early-exit","exit 0","engine closed its channel")]
        val ()=rejected "lost-interrupt" [("PROTOCOL_TIMEOUT","3")] [worker,"fault-lost-interrupt"] "kernel reply timed out"
    in say "PASS protocol framing, authentication, correlation, interrupt and child-lifecycle faults\n" end
end

(* REPL engine transcripts, using framed channels and the same descriptor
   and asynchronous-output rules as a front. Expected bytes stay hand-authored. *)
structure ReplProtocolChecks =
struct
  open Sh
  exception Failed of string
  fun need (ok,why)=if ok then () else raise Failed why
  fun escapes text =
    let fun loop i=if i=size text then "" else
          let val ch=String.sub (text,i)
          in if ch<> #"\\" then str ch ^ loop (i+1)
             else if i+1=size text then "\\" else
               let val next=String.sub (text,i+1)
                   val value=case next of #"n" => "\n" | #"r" => "\r" | #"t" => "\t" | #"b" => "\b" | #"f" => "\f"
                       | #"\\" => "\\" | #"\"" => "\"" | #"'" => "'" | _ => "\\" ^ str next
               in value ^ loop (i+2) end end
    in loop 0 end
  fun one name update () =
    let val framing=if String.isSuffix "-headers" name then Framing.ContentLength else Framing.Lines
        val child=ProtocolIO.spawn {args=[fromRoot "bin/rune-repl","--engine"],directory=root,
                 environment=setEnv ("RUNE_CACHE","") (Posix.ProcEnv.environ ()),engine=true,framing=framing}
        val transcript=ref [] : string list ref
        val inputs=ref [] : string list ref
        val busy=ref false
        val ended=ref false
        fun line text=transcript:=text :: !transcript
        fun output (stream,text)=
          let val rows=String.fields (fn ch => ch = #"\n") text
              val rows=if not (null rows) andalso List.last rows="" then List.take (rows,length rows-1) else rows
          in List.app (fn text => line (stream ^ ": " ^ text)) rows end
        fun send text=(busy:=false;ProtocolIO.send child framing text)
        fun record message =
          case ProtocolJson.text (ProtocolJson.field "method" message) of
            SOME "status" => busy:=(case ProtocolJson.field "params" message of SOME params => ProtocolJson.text (ProtocolJson.field "state" params)=SOME "busy" | NONE => false)
          | SOME "input" =>
              let val answer=case !inputs of [] => Json.Null | text :: rest => (inputs:=rest;Json.String text)
                  val id=getOpt (ProtocolJson.field "id" message,Json.Null)
              in line "engine asks: input";send (Json.encode (Json.Object [("jsonrpc",Json.String "2.0"),("id",id),("result",answer)])) end
          | _ => line ("<- " ^ ProtocolJson.encode (ProtocolJson.implementation message))
        fun nextMessage deadline=case ProtocolIO.receiveTime child (Time.- (deadline,Runtime.clock ())) output of
                   NONE => raise Failed "engine closed its channel before expected message" | SOME text => Json.decode text
        fun ident message=case ProtocolJson.field "id" message of SOME (Json.Number n) => n | SOME (Json.String n) => n | _ => "null"
        fun until what =
          let val deadline=Time.+ (Runtime.clock (),Time.fromSeconds 60)
              fun loop ()=
                let val message=nextMessage deadline
                    val ()=record message
                    val response=isSome (ProtocolJson.field "result" message) orelse isSome (ProtocolJson.field "error" message)
                in if (response andalso ident message=what) orelse ProtocolJson.text (ProtocolJson.field "method" message)=SOME what then () else loop () end
          in loop () end
        fun waitBusy ()=
          let val deadline=Time.+ (Runtime.clock (),Time.fromSeconds 20)
              fun loop ()=if !busy then () else (record (nextMessage deadline);loop ())
          in loop () end
        fun finish ()=
          let val ()=ProtocolIO.closeInput child
              val status=ProtocolIO.wait child 30
              val ()=ProtocolIO.drain child output
              val code=case #status status of Posix.Process.W_EXITED => 0 | Posix.Process.W_EXITSTATUS code => Word8.toInt code | Posix.Process.W_SIGNALED signal => ~ (SysWord.toInt (Posix.Signal.toWord signal)) | _ => ~1
          in line ("ended " ^ Int.toString code);ended:=true end
        fun command raw =
          let val text=Hosts.trim raw
          in if text="" orelse String.isPrefix "#" text then () else
             let val (command,rest)=case Substring.position " " (Substring.full text) of (command,rest) =>
                     (Substring.string command,if Substring.isEmpty rest then "" else Substring.string (Substring.triml 1 rest))
             in case command of
                 "send" => (line ("-> " ^ rest);send rest)
               | "raw" => (line ("-> (raw) " ^ rest);ProtocolIO.sendRaw child (escapes rest))
               | "until" => until rest
               | "input" => inputs:= !inputs @ [escapes rest]
               | "signal" => (waitBusy ();OS.Process.sleep (Time.fromMilliseconds 300);ProtocolIO.signal child Posix.Signal.int;line "SIGINT")
               | "sleep" => (case Int.fromString rest of SOME ms => OS.Process.sleep (Time.fromMilliseconds (LargeInt.fromInt ms)) | NONE => raise Failed "invalid transcript sleep")
               | "end" => finish ()
               | _ => raise Failed ("unknown REPL protocol instruction " ^ command)
             end end
        fun play ()=List.app command (String.fields (fn ch => ch = #"\n") (read (fromRoot ("tests/repl-protocol/" ^ name ^ ".script"))))
        val ()=(play () handle e =>
              (ProtocolIO.signal child Posix.Signal.kill handle OS.SysErr _ => ();
               ignore (ProtocolIO.wait child 5) handle _ => ();
               ProtocolIO.close child;raise e))
        val ()=need (!ended,"protocol script did not close its engine")
        val ()=ProtocolIO.close child
        val got=String.concat (List.map (fn text => text ^ "\n") (List.rev (!transcript)))
        val output=run ^ "/repl-protocol/" ^ name ^ ".out"
        val expected=fromRoot ("tests/repl-protocol/" ^ name ^ ".expected")
        val ()=mkdirs (OS.Path.dir output)
        val ()=write (output,got)
        val ()=if update then write (expected,got) else ()
    in need (got=read expected,"REPL protocol transcript differs: " ^ name ^ " (" ^ output ^ ")");say ("PASS repl-protocol/" ^ name ^ "\n") end
end

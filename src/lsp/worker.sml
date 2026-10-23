(* A worker checks sources and serves frozen queries. Its stdout is private
   binary framing; it never shares the client's protocol descriptors. *)
structure RuneLspWorker =
struct
  structure V=RuneLspWorkerWire
  structure E=RuneLspWorkerAnalysis
  fun serve () =
    let val engine=E.new ()
        val reader=ref (Framing.bounded {framing=Framing.ContentLength,maxHeaderBytes=8192,maxBodyBytes=V.maximum})
        val pending=ref [] : V.value list ref
        val ended=ref false
        fun send value =
          let val (count,pieces)=V.chunks value
              val pieces=("Content-Length: " ^ Int.toString count ^ "\r\n\r\n") :: pieces
              fun piece text =
                let val bytes=Byte.stringToBytes text
                    fun write offset=if offset=size text then () else
                      let val count=Posix.IO.writeVec (Posix.FileSys.stdout,Word8VectorSlice.slice (bytes,offset,NONE))
                      in if count=0 then raise Fail "worker output closed" else write (offset+count) end
                in write 0 end
          in List.app piece pieces end
        fun read () =
          let val bytes=Posix.IO.readVec (Posix.FileSys.stdin,8192)
          in if Word8Vector.length bytes=0 then ended:=true else
            let val (messages,next)=Framing.feed (!reader,Byte.bytesToString bytes)
            in reader:=next;pending:= !pending @ List.map V.decode messages end end
        fun ready ()=send (V.Object [("op",V.Bytes "ready")])
        fun reply (id,result)=send (V.Object [("id",V.Integer id),("result",result)])
        fun failed (id,message)=send (V.Object [("id",V.Integer id),("error",V.Bytes (E.safe message))])
        fun cancelMessage (id,value)=V.bytes (V.field (value,"op"))="cancel" andalso V.integer (V.field (value,"id"))=id
        fun cancelled id =
          let val descriptor=OS.IO.pollIn (valOf (OS.IO.pollDesc (Posix.FileSys.fdToIOD Posix.FileSys.stdin)))
              val ()=if null (OS.IO.poll ([descriptor],SOME Time.zeroTime)) then () else read ()
              val (cancels,others)=List.partition (fn value => cancelMessage (id,value)) (!pending)
          in pending:=others; !ended orelse not (null cancels) end
        fun command value =
          let val opName=V.bytes (V.field (value,"op"))
              val id=V.integer (V.field (value,"id"))
              fun work () = case opName of
                "discover" =>
                  let val (workspace,documents)=RuneLspWorkerModel.restore (V.field (value,"state"))
                      val _=RuneLspProjects.enrich (workspace,documents,fn () => cancelled id)
                  in E.discovery (workspace,documents,V.bytes (V.field (value,"uri"))) end
              | "check" =>
                  let val encoding=case V.bytes (V.field (value,"encoding")) of "utf-8" => LspProtocol.Utf8
                        | "utf-16" => LspProtocol.Utf16 | "utf-32" => LspProtocol.Utf32
                        | _ => raise V.Invalid "invalid worker position encoding"
                      val view=E.check (engine,{state=V.field (value,"state"),uri=V.bytes (V.field (value,"uri")),
                        encoding=encoding,capabilities=(V.unjson (V.field (value,"capabilities")) handle V.Invalid _ => Json.Object []),
                        cancelled=fn () => cancelled id})
                  in V.Object [("snapshot",V.Bytes (#id view)),("reports",V.Array (E.reports view))] end
              | "query" =>
                  let val view=case E.find (engine,V.bytes (V.field (value,"snapshot"))) of SOME view => view
                        | NONE => raise Fail "analysis snapshot has been evicted"
                  in V.json (E.query (view,{method=V.bytes (V.field (value,"method")),params=V.unjson (V.field (value,"params"))})) end
              | "workspace" =>
                  let val encoding=case V.bytes (V.field (value,"encoding")) of "utf-8" => LspProtocol.Utf8
                        | "utf-16" => LspProtocol.Utf16 | "utf-32" => LspProtocol.Utf32
                        | _ => raise V.Invalid "invalid workspace position encoding"
                      val params=V.unjson (V.field (value,"params"))
                      val method=(V.bytes (V.field (value,"method")) handle V.Invalid _ => "workspace/diagnostic")
                      val previous=case Json.member ("previousResultIds",params) of NONE => [] | SOME (Json.Array values) =>
                        List.map (fn value => (RuneLspSync.string (RuneLspSync.required (value,"uri")),
                          RuneLspSync.string (RuneLspSync.required (value,"value")))) values
                        | _ => raise V.Invalid "invalid previous workspace result ids"
                  in V.json (case method of "workspace/symbol" => E.workspaceSymbols (engine,
                       {state=V.field (value,"state"),encoding=encoding,capabilities=V.unjson (V.field (value,"capabilities")),
                        cancelled=fn () => cancelled id,query=RuneLspSync.string (RuneLspSync.required (params,"query"))})
                    | "workspaceSymbol/resolve" => E.resolveSymbol (engine,params,V.field (value,"state"))
                    | _ => E.workspaceDiagnostics (engine,{state=V.field (value,"state"),encoding=encoding,
                       capabilities=V.unjson (V.field (value,"capabilities")),cancelled=fn () => cancelled id,previous=previous})) end
              | _ => raise V.Invalid "unknown worker operation"
          in if opName="cancel" then () else
               ((reply (id,work ()) handle RuneCompiler.Analysis.Cancelled =>
                   send (V.Object [("id",V.Integer id),("cancelled",V.Bool true)])
                 | RuneCompiler.Failed diagnostics => failed (id,String.concatWith "\n" (List.map #message diagnostics))
                 | V.Invalid message => failed (id,message)
                 | RuneLspWorkspace.Invalid message => failed (id,message)
                 | RuneLspSync.Invalid message => failed (id,message)
                 | LspUri.Invalid => failed (id,"invalid file URI during worker analysis")
                 | error => failed (id,General.exnMessage error));ready ()) end
        fun loop ()=case !pending of value :: rest => (pending:=rest;command value;loop ())
          | [] => if !ended then () else (read ();loop ())
        val result=(ready ();loop ();if Framing.pending (!reader) then OS.Process.failure else OS.Process.success)
          handle error => (TextIO.output (TextIO.stdErr,"runelsp worker: " ^ General.exnMessage error ^ "\n");OS.Process.failure)
    in E.clear engine;result end
end

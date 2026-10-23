(* Independent real-project replay. The installed release remains a usable
   baseline: VM, server, source root and output are explicit arguments. *)
structure RuneLspProjectReplay =
struct
  structure C=RuneLspTestClient
  fun object fields=Json.Object fields
  fun read file=let val input=BinIO.openIn file
    in Byte.bytesToString(BinIO.inputAll input) before BinIO.closeIn input end
  fun write (file,text)=let val output=TextIO.openOut file
    in TextIO.output(output,text);TextIO.closeOut output end
  fun run (vm,server,root,out) =
    let val root=OS.FileSys.fullPath root
        val windows=List.exists(fn(key,value)=>key="sysname" andalso value="Windows")(Posix.ProcEnv.uname())
        val platform=if windows then LspUri.Windows else LspUri.Posix
        fun uri path=LspUri.original(LspUri.fromPath(platform,path))
        val source=OS.Path.concat(root,"src/main/rune-main.sml")
        val document=object[("uri",Json.String(uri source))]
        val client=C.start(vm,[server,"--stdio","--lib",OS.Path.concat(root,"lib")])
        val samples=ref []
        fun response id=C.receiveWithin(client,fn value=>Json.member("id",value)=SOME(Json.int id),Time.fromSeconds 90)
        fun timedFrom (name,timer,action) =
          let val result=action()
              val sample=object[("phase",Json.String name),("microseconds",Json.intInf(Time.toMicroseconds(Timer.checkRealTimer timer))),
                ("result",result)]
              val ()=samples:=sample:: !samples
              val ()=write(out,Json.encode(Json.Array(List.rev(!samples))) ^ "\n")
          in print(name ^ " " ^ Time.toString(Timer.checkRealTimer timer) ^ " s\n");TextIO.flushOut TextIO.stdOut;result end
        fun timed(name,action)=timedFrom(name,Timer.startRealTimer(),action)
        fun work() =
          let val target=object[("name",Json.String "rune"),
                ("build",Json.String(uri(OS.Path.concat(root,"rune.build"))))]
              val settings=object[("libraryRoot",Json.String(uri(OS.Path.concat(root,"lib")))),
                ("targets",Json.Array[target]),("activeContext",Json.String "rune")]
              val _=timed("initialize",fn()=>
                (C.request(client,1,"initialize",object[("capabilities",object[("textDocument",object[
                  ("diagnostic",object[]),("documentLink",object[("tooltipSupport",Json.Bool true)])])]),
                  ("workspaceFolders",Json.Array[object[("uri",Json.String(uri root)),("name",Json.String "rune")]]),
                  ("initializationOptions",settings)]);C.result(response 1)))
              val ()=C.notify(client,"initialized",object[])
              val ()=C.notify(client,"textDocument/didOpen",object[("textDocument",object[("uri",Json.String(uri source)),
                ("languageId",Json.String "sml"),("version",Json.int 1),("text",Json.String(read source))])])
              val params=object[("textDocument",document),("position",object[("line",Json.int 2),("character",Json.int 10)])]
              val requests=[(10,"textDocument/diagnostic",object[("textDocument",document)]),
                (11,"textDocument/hover",params),(12,"textDocument/documentSymbol",object[("textDocument",document)]),
                (13,"textDocument/documentLink",object[("textDocument",document)])]
              val dispatch=Timer.startRealTimer()
              val ()=List.app(fn(id,method,params)=>C.request(client,id,method,params))requests
              val answers=List.map(fn(id,method,_)=>timedFrom(method,dispatch,fn()=>response id))requests
              val ()=if List.all(fn answer=>not(isSome(Json.member("error",answer))))answers then () else raise Fail "project replay contains failed requests"
              val _=timed("warm-hover",fn()=>(C.request(client,20,"textDocument/hover",params);C.result(response 20)))
              val ()=C.request(client,9000,"shutdown",Json.Null)
              val _=C.result(response 9000)
              val ()=C.notify(client,"exit",Json.Null)
          in print "PASS lsp/project-replay\n" end
    in (work() before C.close client) handle error=>(C.close client;raise error) end
end
val ()=(case CommandLine.arguments() of [vm,server,root,out]=>RuneLspProjectReplay.run(vm,server,root,out)
  | _=>raise Fail "usage: project-replay.rbc VM SERVER SOURCE_ROOT OUTPUT.json")
  handle error=>(TextIO.output(TextIO.stdErr,"FAIL lsp/project-replay: " ^ General.exnMessage error ^ "\n");OS.Process.exit OS.Process.failure)

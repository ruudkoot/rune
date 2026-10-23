(* Run this same independent protocol client on each packaged VM, with an
   extracted extension path as its sole argument. It needs no Rune install. *)
structure RuneLspDistributionTests =
struct
  structure C=RuneLspTestClient
  fun check (name,ok)=if ok then print("PASS vscode/packaged/" ^ name ^ "\n") else raise Fail name
  fun object fields=Json.Object fields
  fun read file=let val input=BinIO.openIn file
    in Byte.bytesToString(BinIO.inputAll input) before BinIO.closeIn input end
  fun write (file,text)=let val output=BinIO.openOut file
    in BinIO.output(output,Byte.stringToBytes text);BinIO.closeOut output end
  fun copy source target =
    if OS.FileSys.isDir source then
      let val ()=OS.FileSys.mkDir target val stream=OS.FileSys.openDir source
          fun loop()=case OS.FileSys.readDir stream of NONE=>() | SOME name=>
            (copy(OS.Path.concat(source,name))(OS.Path.concat(target,name));loop())
      in loop() before OS.FileSys.closeDir stream end
    else write(target,read source)
  fun run extension =
    let val windows=List.exists(fn(key,value)=>key="sysname" andalso value="Windows")(Posix.ProcEnv.uname())
        val platform=if windows then LspUri.Windows else LspUri.Posix
        fun uri path=LspUri.original(LspUri.fromPath(platform,OS.FileSys.fullPath path))
        val extension=OS.FileSys.fullPath extension
        val bin=OS.Path.concat(extension,"server/bin")
        val vm=OS.Path.concat(bin,if windows then "runevm.exe" else "runevm")
        val server=OS.Path.concat(bin,"runelsp.rbc")
        val library=OS.Path.concat(extension,"server/lib")
        val reservation=OS.FileSys.tmpName()
        val ()=OS.FileSys.remove reservation
        val workspace=OS.Path.concat(OS.Path.dir extension,"workspace with spaces \206\187 " ^ OS.Path.file reservation)
        val ()=OS.FileSys.mkDir workspace
        val file=OS.Path.concat(workspace,"main.sml")
        val ()=write(file,"val answer=List.length [1,2]\n")
        val document=object[("uri",Json.String(uri file))]
        val client=C.start(vm,[server,"--stdio","--lib",library])
        val serial=ref 10
        fun request method params =
          let val id= !serial val ()=serial:=id+1
          in C.request(client,id,method,params);C.result(C.response(client,id)) end
        val revision=ref 1
        fun text value=(revision:= !revision+1;C.notify(client,"textDocument/didChange",object
          [("textDocument",object[("uri",Json.String(uri file)),("version",Json.int(!revision))]),
           ("contentChanges",Json.Array[object[("text",Json.String value)]])]))
        fun diagnostics()=C.field(request "textDocument/diagnostic" (object[("textDocument",document)]),"items")
        fun hover character=request "textDocument/hover" (object[("textDocument",document),
          ("position",object[("line",Json.int 0),("character",Json.int character)])])
        fun watched path=C.notify(client,"workspace/didChangeWatchedFiles",object[("changes",Json.Array
          [object[("uri",Json.String(uri path)),("type",Json.int 2)]])])
        fun work () =
          let val _=request "initialize" (object[("capabilities",object[]),
                ("workspaceFolders",Json.Array[object[("uri",Json.String(uri workspace)),("name",Json.String "fixture")]])])
              val ()=C.notify(client,"initialized",object[])
              val ()=C.notify(client,"textDocument/didOpen",object[("textDocument",object
                [("uri",Json.String(uri file)),("languageId",Json.String "sml"),("version",Json.int 1),
                 ("text",Json.String(read file))])])
              val ()=check("fallback-basis-worker",diagnostics()=Json.Array[])
              val ()=check("hover",C.field(C.field(hover 4,"contents"),"value")=Json.String "int")
              val ()=case OS.Process.getEnv "RUNE_VSCODE_REBUILD" of NONE=>() | SOME command=>
                check("development-rebuild",OS.Process.isSuccess(OS.Process.system command) andalso
                  C.field(C.field(hover 4,"contents"),"value")=Json.String "int")
              val definition=request "textDocument/definition" (object[("textDocument",document),
                ("position",object[("line",Json.int 0),("character",Json.int 21)])])
              val ()=check("basis-navigation",case definition of Json.Array(_::_)=>true | _=>false)
              val ()=text "val bad:int=true\n"
              val ()=check("diagnostics",case diagnostics() of Json.Array(_::_)=>true | _=>false)
              val ()=text "val answer=List.ma\n"
              val completion=request "textDocument/completion" (object[("textDocument",document),
                ("position",object[("line",Json.int 0),("character",Json.int 18)])])
              val items=case Json.member("items",completion) of SOME(Json.Array items)=>items | _=>[]
              val ()=check("completion",List.exists(fn item=>Json.member("label",item)=SOME(Json.String "map"))items)
              val localLib=OS.Path.concat(workspace,"lib")
              val ()=copy library localLib
              val basis=OS.Path.concat(localLib,"basis")
              val manifest=OS.Path.concat(basis,"MANIFEST")
              val original=read manifest
              val probe=OS.Path.concat(basis,"vscode-probe.sml")
              val ()=write(probe,"structure VSCodeProbe=struct val value=1 end\n")
              val ()=write(manifest,original ^ "vscode-probe.sml | demand | yes | VSCodeProbe | \n")
              val ()=C.notify(client,"workspace/didChangeConfiguration",object[("settings",object
                [("libraryRoot",Json.String(uri localLib))])])
              val ()=text "val answer=VSCodeProbe.value\n"
              val ()=check("checkout-library-root",diagnostics()=Json.Array[] andalso
                C.field(C.field(hover 4,"contents"),"value")=Json.String "int")
              val ()=write(probe,"structure VSCodeProbe=struct val value=true end\n")
              val ()=watched probe
              val ()=check("saved-basis-change",C.field(C.field(hover 4,"contents"),"value")=Json.String "bool")
              val extra=OS.Path.concat(basis,"vscode-extra.sml")
              val ()=write(extra,"structure VSCodeExtra=struct val value=\"new\" end\n")
              val ()=write(manifest,read manifest ^ "vscode-extra.sml | demand | yes | VSCodeExtra | \n")
              val ()=watched manifest
              val ()=text "val answer=VSCodeExtra.value\n"
              val ()=check("changed-manifest",diagnostics()=Json.Array[] andalso
                C.field(C.field(hover 4,"contents"),"value")=Json.String "string")
              val ()=check("shutdown",request "shutdown" Json.Null=Json.Null)
              val ()=C.notify(client,"exit",Json.Null)
          in () end
    in (work() before C.close client) handle error=>(C.close client;raise error) end
end
val ()=(case CommandLine.arguments() of [extension]=>RuneLspDistributionTests.run extension
  | _=>raise Fail "usage: distribution-tests.rbc EXTRACTED_EXTENSION")
  handle error=>(TextIO.output(TextIO.stdErr,"FAIL " ^ General.exnMessage error ^ "\n");OS.Process.exit OS.Process.failure)

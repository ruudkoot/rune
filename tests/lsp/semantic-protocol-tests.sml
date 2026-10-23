structure RuneLspSemanticProtocolTests =
struct
  structure C=RuneLspTestClient
  val check=Expect.that
  fun object fields=Json.Object fields
  fun document uri=object [("uri",Json.String uri)]
  fun fixtureInitialized initialization action =
    let val (program,args)=case CommandLine.arguments () of [vm,server,worker] => (vm,[server,vm,worker])
          | [vm,server] => (vm,[server]) | [program] => (program,[])
          | _ => raise Fail "semantic protocol tests require server launch arguments"
        val client=C.start (program,args)
        fun work () =
          let val ()=C.request (client,1,"initialize",initialization)
              val _=C.result (C.response (client,1))
              val ()=C.notify (client,"initialized",object [])
              val ()=action client
              val ()=C.request (client,9000,"shutdown",Json.Null)
              val ()=check ("shutdown response",C.result (C.response (client,9000))=Json.Null)
              val ()=C.notify (client,"exit",Json.Null)
          in () end
    in (work () before C.close client) handle error => (C.close client;raise error) end
  fun fixtureWith capabilities action=fixtureInitialized (object [("capabilities",capabilities)]) action
  fun fixture action=fixtureWith (object []) action
  fun openDocument (client,uri,text)=C.notify (client,"textDocument/didOpen",object [("textDocument",object
    [("uri",Json.String uri),("languageId",Json.String "sml"),("version",Json.int 1),("text",Json.String text)])])
  fun diagnostics client = fixture (fn client =>
    let val uri="untitled:semantic-protocol"
        val ()=openDocument (client,uri,"val bad:int=true\n")
        val pushed=C.receive (client,fn value => Json.member ("method",value)=SOME (Json.String "textDocument/publishDiagnostics"))
        val params=C.field (pushed,"params")
        val ()=check ("push diagnostics without EOF",case C.field (params,"diagnostics") of Json.Array (_::_) => true | _ => false)
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "val answer=42\n")]])])
        val ()=C.request (client,2,"textDocument/diagnostic",object [("textDocument",document uri)])
        val report=C.result (C.response (client,2))
        val ()=check ("pull diagnostics clear errors",C.field (report,"items")=Json.Array [])
        val ()=C.request (client,3,"textDocument/diagnostic",object [("textDocument",document uri),("previousResultId",C.field (report,"resultId"))])
        val unchanged=C.result (C.response (client,3))
        val ()=check ("unchanged report",C.field (unchanged,"kind")=Json.String "unchanged")
        val ()=C.request (client,4,"textDocument/hover",object [("textDocument",document uri),
          ("position",object [("line",Json.int 0),("character",Json.int 4)])])
        val hover=C.result (C.response (client,4))
    in check ("hover uses checked snapshot",C.field (C.field (hover,"contents"),"value")=Json.String "int") end)
  fun cancellation () = fixture (fn client =>
    let val uri="untitled:cancel-protocol"
        val text=String.concat (List.tabulate (10000,fn i => "val x" ^ Int.toString i ^ "=" ^ Int.toString i ^ "\n"))
        val ()=openDocument (client,uri,text)
        val ()=C.request (client,10,"textDocument/hover",object [("textDocument",document uri),
          ("position",object [("line",Json.int 0),("character",Json.int 4)])])
        val ()=C.notify (client,"$/cancelRequest",object [("id",Json.int 10)])
        val cancelled=C.response (client,10)
    in check ("cancellation answered while checking",C.field (C.field (cancelled,"error"),"code")=Json.int (~32800)) end)
  fun pullRefresh () = fixtureWith (object [("textDocument",object [("diagnostic",object [])]),
    ("workspace",object [("diagnostics",object [("refreshSupport",Json.Bool true)])])]) (fn client =>
    let val uri="untitled:pull-refresh"
        val ()=openDocument (client,uri,"val bad:int=true\n")
        val refresh=C.receive (client,fn value => Json.member ("method",value)=SOME (Json.String "workspace/diagnostic/refresh"))
        val ()=C.send (client,object [("jsonrpc",Json.String "2.0"),("id",C.field (refresh,"id")),("result",Json.Null)])
        val ()=C.request (client,30,"textDocument/diagnostic",object [("textDocument",document uri)])
        val report=C.result (C.response (client,30))
        val C.Client {messages,...}=client
        val pushed=List.exists (fn value => Json.member ("method",value)=SOME (Json.String "textDocument/publishDiagnostics")) (!messages)
    in check ("pull client receives refresh without duplicate pushes",not pushed andalso
      (case C.field (report,"items") of Json.Array (_::_) => true | _ => false)) end)
  fun progressCancellation () = fixture (fn client =>
    let val uri="untitled:progress-cancellation"
        val text=String.concat (List.tabulate (10000,fn i => "val x" ^ Int.toString i ^ "=" ^ Int.toString i ^ "\n"))
        val ()=openDocument (client,uri,text)
        val ()=C.request (client,31,"textDocument/diagnostic",object [("textDocument",document uri),
          ("workDoneToken",Json.String "cancel-this-check")])
        val ()=C.notify (client,"window/workDoneProgress/cancel",object [("token",Json.String "cancel-this-check")])
        val response=C.response (client,31)
    in check ("work progress cancellation owns its matching request",
      C.field (C.field (response,"error"),"code")=Json.int (~32800)) end)
  fun staleDiagnostics () = fixture (fn client =>
    let val uri="untitled:stale-diagnostics"
        val text=String.concat (List.tabulate (5000,fn i => "val x" ^ Int.toString i ^ "=" ^ Int.toString i ^ "\n"))
        val ()=openDocument (client,uri,text)
        val ()=C.request (client,40,"textDocument/diagnostic",object [("textDocument",document uri)])
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "val fixed=1\n")]])])
        val answer=C.response (client,40)
        val error=C.field (answer,"error")
    in check ("stale diagnostic request can be retriggered",C.field (error,"code")=Json.int (~32802)
      andalso C.field (C.field (error,"data"),"retriggerRequest")=Json.Bool true) end)
  fun markup () = fixtureWith (object [("textDocument",object
    [("diagnostic",object [("markupMessageSupport",Json.Bool true)]),
     ("hover",object [("contentFormat",Json.Array [Json.String "markdown"])])])]) (fn client =>
    let val uri="untitled:markup"
        val ()=openDocument (client,uri,"val bad:int=true\n")
        val ()=C.request (client,50,"textDocument/diagnostic",object [("textDocument",document uri)])
        val report=C.result (C.response (client,50))
        val message=case C.field (report,"items") of Json.Array (item::_) => C.field (item,"message") | _ => raise Fail "missing markup diagnostic"
        val ()=check ("diagnostic markup negotiated",C.field (message,"kind")=Json.String "plaintext")
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "val value=42\n")]])])
        val ()=C.request (client,51,"textDocument/hover",object [("textDocument",document uri),
          ("position",object [("line",Json.int 0),("character",Json.int 4)])])
        val hover=C.result (C.response (client,51))
    in check ("hover markup negotiated",C.field (C.field (hover,"contents"),"kind")=Json.String "markdown") end)
  fun fileProject () =
    let val dir="tests/out/lsp-scratch/protocol-project-" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
        val ()=OS.FileSys.mkDir dir
        fun write (name,text)=let val output=TextIO.openOut (dir ^ "/" ^ name)
          in TextIO.output (output,text);TextIO.closeOut output end
        val ()=write ("main.build","files main.sml end\n")
        val ()=write ("main.sml","val answer=42\n")
        val platform=if List.exists (fn (key,value) => key="sysname" andalso value="Windows") (Posix.ProcEnv.uname ())
          then LspUri.Windows else LspUri.Posix
        val uri=LspUri.original (LspUri.fromPath (platform,OS.FileSys.fullPath (dir ^ "/main.sml")))
        fun clean ()=(OS.FileSys.remove (dir ^ "/main.build");OS.FileSys.remove (dir ^ "/main.sml");OS.FileSys.rmDir dir)
        fun work ()=fixture (fn client =>
          let val ()=openDocument (client,uri,"val answer=43\n")
              val ()=C.request (client,60,"textDocument/hover",object [("textDocument",document uri),
                ("position",object [("line",Json.int 0),("character",Json.int 4)])])
              val hover=C.result (C.response (client,60))
          in check ("native build context resolves without path rewriting",C.field (C.field (hover,"contents"),"value")=Json.String "int") end)
    in (work () before clean ()) handle error => (clean () handle _ => ();raise error) end
  fun workspaceDiagnostics () =
    let val dir="tests/out/lsp-scratch/workspace-diagnostics-" ^ SysWord.toString (Posix.Process.pidToWord (Posix.ProcEnv.getpid ()))
        val ()=OS.FileSys.mkDir dir
        fun write (name,text)=let val output=TextIO.openOut (dir ^ "/" ^ name)
          in TextIO.output (output,text);TextIO.closeOut output end
        val ()=write ("project.build","files main.sml end\n")
        val ()=write ("main.sml","val bad:int=true\n")
        val platform=if List.exists (fn (key,value) => key="sysname" andalso value="Windows") (Posix.ProcEnv.uname ())
          then LspUri.Windows else LspUri.Posix
        val root=LspUri.original (LspUri.fromPath (platform,OS.FileSys.fullPath dir))
        val uri=LspUri.original (LspUri.fromPath (platform,OS.FileSys.fullPath (dir ^ "/main.sml")))
        fun clean ()=(OS.FileSys.remove (dir ^ "/project.build");OS.FileSys.remove (dir ^ "/main.sml");OS.FileSys.rmDir dir)
        fun work ()=fixtureInitialized (object [("capabilities",object [("textDocument",object [("diagnostic",object [])])]),
          ("workspaceFolders",Json.Array [object [("uri",Json.String root),("name",Json.String "fixture")]])]) (fn client =>
          let val ()=C.request (client,70,"workspace/diagnostic",object [("previousResultIds",Json.Array [])])
              val report=C.result (C.response (client,70))
              val first=case C.field (report,"items") of Json.Array [item] => item | _ => raise Fail "workspace report missing closed source"
              val ()=check ("closed source checked through build model",C.field (first,"uri")=Json.String uri andalso
                (case C.field (first,"items") of Json.Array (_::_) => true | _ => false))
              val ()=C.request (client,72,"workspace/diagnostic",object [("previousResultIds",Json.Array []),
                ("partialResultToken",Json.String "workspace-partial"),("workDoneToken",Json.String "workspace-work")])
              val partial=C.receive (client,fn value => Json.member ("method",value)=SOME (Json.String "$/progress") andalso
                (case Json.member ("params",value) of SOME params => Json.member ("token",params)=SOME (Json.String "workspace-partial") | _ => false))
              val ()=check ("workspace partial results carry reports",case C.field (C.field (C.field (partial,"params"),"value"),"items") of
                Json.Array (_::_) => true | _ => false)
              val ()=check ("partial final result contains no duplicates",C.field (C.result (C.response (client,72)),"items")=Json.Array [])
              val ()=write ("main.sml","val fixed=42\n")
              val ()=C.request (client,71,"workspace/diagnostic",object [("previousResultIds",Json.Array
                [object [("uri",Json.String uri),("value",C.field (first,"resultId"))]])])
              val fixed=C.result (C.response (client,71))
              val item=case C.field (fixed,"items") of Json.Array [item] => item | _ => raise Fail "workspace refresh missing source"
          in check ("disk-only changes invalidate workspace diagnostics",C.field (item,"items")=Json.Array []) end)
    in (work () before clean ()) handle error => (clean () handle _ => ();raise error) end
  fun navigation ()=fixture (fn client =>
    let val uri="untitled:navigation"
        val text="val first=1\nval second=first\nfun identity x=x\nval third=identity second\n"
        val ()=openDocument (client,uri,text)
        fun query (id,method,line,character)=
          (C.request (client,id,method,object [("textDocument",document uri),
            ("position",object [("line",Json.int line),("character",Json.int character)])]);C.result (C.response (client,id)))
        val definition=query (80,"textDocument/definition",1,12)
        val target=case definition of Json.Array [target] => target | _ => raise Fail "definition not resolved"
        val start=C.field (C.field (target,"range"),"start")
        val ()=check ("value definition uses compiler binding",C.field (target,"uri")=Json.String uri andalso
          C.field (start,"line")=Json.int 0 andalso C.field (start,"character")=Json.int 4)
        val function=query (81,"textDocument/definition",3,12)
        val functionStart=case function of Json.Array [target] => C.field (C.field (target,"range"),"start")
          | _ => raise Fail "function definition not resolved"
        val ()=check ("function selection is its head identifier",C.field (functionStart,"line")=Json.int 2
          andalso C.field (functionStart,"character")=Json.int 4)
        val ()=C.request (client,82,"textDocument/documentSymbol",object [("textDocument",document uri)])
        val symbols=C.result (C.response (client,82))
    in check ("document symbols reflect checked declarations",case symbols of Json.Array values =>
      List.exists (fn value => Json.member ("name",value)=SOME (Json.String "identity")) values | _ => false) end)
  fun workspaceSymbols ()=fixtureWith (object [("workspace",object [("symbol",object
    [("resolveSupport",object [("properties",Json.Array [Json.String "location.range"])])])])]) (fn client =>
    let val uri="untitled:workspace-symbols"
        val ()=openDocument (client,uri,"fun namedFunction x=x\nval value=1\n")
        val ()=C.request (client,90,"workspace/symbol",object [("query",Json.String "namedFunction")])
        val symbols=C.result (C.response (client,90))
        val symbol=case symbols of Json.Array [symbol] => symbol | _ => raise Fail "workspace symbol missing"
        val ()=check ("workspace symbol can defer its range",Json.member ("range",C.field (symbol,"location"))=NONE)
        val ()=C.request (client,91,"workspaceSymbol/resolve",symbol)
        val resolved=C.result (C.response (client,91))
        val ()=check ("workspace resolve returns validated location",isSome (Json.member ("range",C.field (resolved,"location"))))
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "val replacement=1\n")]])])
        val ()=C.request (client,92,"workspaceSymbol/resolve",symbol)
        val stale=C.response (client,92)
    in check ("stale symbol resolve refused",isSome (Json.member ("error",stale))) end)
  fun completion ()=fixture (fn client =>
    let val uri="untitled:completion"
        val text="structure S : sig val visible:int end = struct val visible=1 val hidden=2 end\nval result=S."
        val ()=openDocument (client,uri,text)
        fun query (id,line,column)=
          (C.request (client,id,"textDocument/completion",object [("textDocument",document uri),
            ("position",object [("line",Json.int line),("character",Json.int column)])]);
           C.result (C.response (client,id)))
        val result=query (100,1,13)
        val items=case C.field (result,"items") of Json.Array items => items | _ => raise Fail "completion items missing"
        val item=case List.find (fn item => C.field (item,"label")=Json.String "visible") items of
          SOME item => item | NONE => raise Fail "visible completion missing"
        val ()=check ("signature hides private completion names",
          not (List.exists (fn item => C.field (item,"label")=Json.String "hidden") items))
        val ()=check ("completion replacement follows the qualification",
          C.field (C.field (C.field (item,"textEdit"),"range"),"start")=object [("line",Json.int 1),("character",Json.int 13)])
        val ()=C.request (client,101,"completionItem/resolve",item)
        val resolved=C.result (C.response (client,101))
        val ()=check ("completion resolves against its frozen scope",C.field (resolved,"detail")=Json.String "int")
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "fun f parameter = let val localName=1 in loc")]])])
        val localResult=query (102,0,44)
        val ()=check ("unfinished local completion uses lexical scope",case C.field (localResult,"items") of Json.Array items =>
          List.exists (fn item => C.field (item,"label")=Json.String "localName") items | _ => false)
        val ()=C.request (client,103,"completionItem/resolve",item)
        val stale=C.response (client,103)
    in check ("old completion resolve rejected after an edit",isSome (Json.member ("error",stale))) end)
  fun signatureHelp ()=fixtureInitialized (object [("capabilities",object [("textDocument",object
    [("signatureHelp",object [("signatureInformation",object [("parameterInformation",object [("labelOffsetSupport",Json.Bool true)])])])])]),
    ("initializationOptions",object [("sourceMode",Json.String "unicode")])]) (fn client =>
    let val uri="untitled:signature-help"
        val text="datatype \240\144\144\128 = V\nfun f (x:\240\144\144\128,y:bool)=x\nval result=f(V, "
        val ()=openDocument (client,uri,text)
        val ()=C.request (client,110,"textDocument/signatureHelp",object [("textDocument",document uri),
          ("position",object [("line",Json.int 2),("character",Json.int 16)])])
        val result=C.result (C.response (client,110))
        val ()=check ("signature identifies the active tuple argument",C.field (result,"activeParameter")=Json.int 1)
        val information=case C.field (result,"signatures") of Json.Array [value] => value | _ => raise Fail "signature missing"
        val parameters=case C.field (information,"parameters") of Json.Array values => values | _ => raise Fail "signature parameters missing"
        val ()=check ("signature parameter offsets count UTF-16 units",case parameters of [_,second] =>
          C.field (second,"label")=Json.Array [Json.int 7,Json.int 11] | _ => false)
    in check ("signature retains the compiler type",String.isSubstring "bool" (case C.field (information,"label") of
      Json.String label => label | _ => "")) end)
  fun completionSnippets ()=fixtureWith (object [("textDocument",object [("completion",object
    [("completionItem",object [("snippetSupport",Json.Bool true)])])])]) (fn client =>
    let val uri="untitled:completion-snippets"
        val ()=openDocument (client,uri,"fun identity (x:int)=x\nval result=ide\n")
        val ()=C.request (client,120,"textDocument/completion",object [("textDocument",document uri),
          ("position",object [("line",Json.int 1),("character",Json.int 14)])])
        val response=C.result (C.response (client,120))
        val items=case C.field (response,"items") of Json.Array items => items | _ => raise Fail "completion items missing"
        val item=case List.find (fn item => C.field (item,"insertTextFormat")=Json.int 2) items of
          SOME item => item | NONE => raise Fail "typed invocation snippet missing"
        val ()=check ("snippet arguments follow the checked callable type",C.field (C.field (item,"textEdit"),"newText")=
          Json.String "identity (${1:(raise Match)})$0")
        val ()=C.request (client,121,"completionItem/resolve",item)
        val resolved=C.result (C.response (client,121))
        val ()=check ("snippet item resolves without becoming a plain item",C.field (resolved,"insertTextFormat")=Json.int 2)
        val ()=C.notify (client,"textDocument/didChange",object [("textDocument",object [("uri",Json.String uri),("version",Json.int 2)]),
          ("contentChanges",Json.Array [object [("text",Json.String "fun identity (x:int)=x\nval result=identity ((raise Match))\n")]])])
        val ()=C.request (client,122,"textDocument/diagnostic",object [("textDocument",document uri)])
        val checked=C.result (C.response (client,122))
    in check ("expanded invocation template parses and typechecks without execution",C.field (checked,"items")=Json.Array []) end)
  fun inlineCompletion ()=fixtureWith (object [("textDocument",object [("inlineCompletion",object [])])]) (fn client =>
    let val uri="untitled:inline-pattern"
        val ()=openDocument (client,uri,"datatype t=Some of int | None\nfun f (So)=1\n")
        fun query (id,extra)=
          (C.request (client,id,"textDocument/inlineCompletion",object [("textDocument",document uri),
             ("position",object [("line",Json.int 1),("character",Json.int 9)]),
             ("context",object (("triggerKind",Json.int 1)::extra))]);C.result (C.response (client,id)))
        val response=query (130,[])
        val items=case C.field (response,"items") of Json.Array items => items | _ => raise Fail "inline items missing"
        val item=case items of [item] => item | _ => raise Fail "constructor pattern completion missing"
        val ()=check ("inline completion uses a real constructor and a parenthesized pattern",
          C.field (item,"insertText")=Json.String "(Some _)")
        val incompatible=query (131,[("selectedCompletionInfo",object [("range",object
          [("start",object [("line",Json.int 1),("character",Json.int 0)]),
           ("end",object [("line",Json.int 1),("character",Json.int 9)])]),("text",Json.String "different")])])
    in check ("incompatible selected completion receives no inline edit",C.field (incompatible,"items")=Json.Array []) end)
  fun completionContextAndDocumentation ()=fixture (fn client =>
    let val uri="untitled:completion-context"
        val ()=openDocument (client,uri,"(* Preserves its integer argument. *)\nfun identity (x:int)=x\nval copied=identity 1\n")
        fun position (line,column)=object [("line",Json.int line),("character",Json.int column)]
        fun request (id,method,line,column)=
          (C.request (client,id,method,object [("textDocument",document uri),("position",position (line,column))]);
           C.result (C.response (client,id)))
        fun change (version,text)=C.notify (client,"textDocument/didChange",object
          [("textDocument",object [("uri",Json.String uri),("version",Json.int version)]),
           ("contentChanges",Json.Array [object [("text",Json.String text)]])])
        val hover=request (140,"textDocument/hover",2,13)
        val ()=check ("hover attaches the actual declaration's captured documentation",case C.field (C.field (hover,"contents"),"value") of
          Json.String value => String.isSubstring "Preserves its integer argument." value | _ => false)
        val ()=change (2,"(* Preserves its integer argument. *)\nfun identity (x:int)=x\nval result=ide\n")
        val completion=request (141,"textDocument/completion",2,14)
        val item=case C.field (completion,"items") of Json.Array [item] => item | _ => raise Fail "documented completion missing"
        val ()=C.request (client,142,"completionItem/resolve",item)
        val resolved=C.result (C.response (client,142))
        val ()=check ("completion resolves captured source documentation",C.field (resolved,"documentation")=Json.String "Preserves its integer argument.")
        val ()=change (3,"val record={name=1,other=true}\nval selected= #na record\n")
        val fields=request (143,"textDocument/completion",1,17)
        val field=case C.field (fields,"items") of Json.Array [field] => field | _ => raise Fail "concrete record field missing"
        val ()=check ("record selector completion is typed and replaces only the label",
          C.field (field,"label")=Json.String "name" andalso C.field (field,"kind")=Json.int 5 andalso
          C.field (field,"detail")=Json.String "int" andalso
          C.field (C.field (C.field (field,"textEdit"),"range"),"start")=position (1,15))
        val ()=change (4,"type existingType=int\nval existingValue=1\nval result:exis=1\n")
        val types=request (144,"textDocument/completion",2,15)
    in check ("type positions exclude same-prefix values",case C.field (types,"items") of Json.Array [item] =>
      C.field (item,"label")=Json.String "existingType" | _ => false) end)
  fun legacyCompletionFallback ()=fixture (fn client =>
    let val uri="untitled:legacy-completion"
        val ()=openDocument (client,uri,"datatype t=Some of int | None\nval Someone=1\nfun f (So)=1\n")
        val params=[("textDocument",document uri),("position",object [("line",Json.int 2),("character",Json.int 9)])]
        val ()=C.request (client,150,"textDocument/completion",object params)
        val completion=C.result (C.response (client,150))
        val ()=check ("older clients receive ordinary constructor completion without snippets",case C.field (completion,"items") of
          Json.Array [item] => C.field (item,"label")=Json.String "Some" andalso C.field (item,"insertTextFormat")=Json.int 1 | _ => false)
        val ()=C.request (client,151,"textDocument/inlineCompletion",object (("context",object [("triggerKind",Json.int 1)])::params))
        val unsupported=C.response (client,151)
    in check ("inline completion requires negotiated client support",C.field (C.field (unsupported,"error"),"code")=Json.int (~32601)) end)
end
structure RuneLspSemanticProtocolTestMain=Main (struct
  val name="lsp-semantic-protocol"
  val tests=Test.describe "lsp-semantic-protocol" [Test.it "diagnostics-and-hover" (fn () => RuneLspSemanticProtocolTests.diagnostics ()),
    Test.it "cancellation" RuneLspSemanticProtocolTests.cancellation,
    Test.it "pull-refresh" RuneLspSemanticProtocolTests.pullRefresh,
    Test.it "progress-cancellation" RuneLspSemanticProtocolTests.progressCancellation,
    Test.it "stale-diagnostics" RuneLspSemanticProtocolTests.staleDiagnostics,
    Test.it "markup-negotiation" RuneLspSemanticProtocolTests.markup,
    Test.it "file-project-mapping" RuneLspSemanticProtocolTests.fileProject,
    Test.it "workspace-diagnostics" RuneLspSemanticProtocolTests.workspaceDiagnostics,
    Test.it "navigation-and-symbols" RuneLspSemanticProtocolTests.navigation,
    Test.it "workspace-symbols-resolve" RuneLspSemanticProtocolTests.workspaceSymbols,
    Test.it "completion" RuneLspSemanticProtocolTests.completion,
    Test.it "signature-help" RuneLspSemanticProtocolTests.signatureHelp,
    Test.it "completion-snippets" RuneLspSemanticProtocolTests.completionSnippets,
    Test.it "inline-completion" RuneLspSemanticProtocolTests.inlineCompletion,
    Test.it "completion-context-and-documentation" RuneLspSemanticProtocolTests.completionContextAndDocumentation,
    Test.it "legacy-completion-fallback" RuneLspSemanticProtocolTests.legacyCompletionFallback]
end)
val ()=RuneLspSemanticProtocolTestMain.main ()

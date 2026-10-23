(* Resident static analysis and frozen views inside the supervised worker. *)
structure RuneLspWorkerAnalysis =
struct
  structure C=RuneCompiler
  structure A=C.Analysis
  structure V=RuneLspWorkerWire
  structure M=RuneLspWorkerModel
  structure W=RuneLspWorkspace
  structure D=RuneLspDocuments
  structure U=LspUri
  structure L=LspPosition
  structure J=RuneLspSync
  type context={key:string,compiler:C.session,analysis:A.t}
  type source={file:string,uri:string,text:string,mode:string,version:IntInf.int option,index:L.t option,tokens:C.Syntax.piece list option ref}
  type view={id:string,snapshot:A.snapshot,sources:source list,encoding:LspProtocol.encoding,uri:string,ordinal:int option,
    capabilities:Json.value}
  datatype t=Worker of {contexts:context list ref,views:view list ref}
  fun new ()=Worker {contexts=ref [],views=ref []}
  fun safe text =
    let fun loop i=if i=size text then [] else
          case Utf8.decode (text,i) of SOME (_,count) => String.substring (text,i,count) :: loop (i+count)
          | NONE => ("\\x" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX (Char.ord (String.sub (text,i))))) :: loop (i+1)
    in String.concat (loop 0) end
  fun clear (Worker {contexts,views}) =
    (List.app (fn context:context => (A.close (#analysis context);C.close (#compiler context))) (!contexts);
     contexts:=[];views:=[])
  fun context (Worker {contexts,...},{key,lib,flags}) =
    case List.find (fn context:context => #key context=key) (!contexts) of SOME context =>
      (contexts:=context :: List.filter (fn prior:context => #key prior<>key) (!contexts);context)
    | NONE =>
      let val compiler=C.session {lib=SOME lib,flags=flags}
          val context={key=key,compiler=compiler,analysis=A.create (compiler,{context=key})}:context
          val all=context :: !contexts
          val ()=if length all<=4 then () else List.app (fn context:context =>
            (A.close (#analysis context);C.close (#compiler context))) (List.drop (all,4))
      in contexts:=List.take (all,Int.min (4,length all));context end
  fun descriptor (context:W.context)=V.Object [("id",V.Bytes (#id context)),("label",V.Bytes (#label context)),
    ("target",V.Bytes (#target context)),("build",V.Bytes (#build context)),("ordinal",V.Integer (IntInf.fromInt (#ordinal context)))]
  fun discovery (workspace,documents,uri) = case W.select (workspace,documents,uri) of
    W.Loose => V.Object [("kind",V.Bytes "loose")]
  | W.Selected context => V.Object [("kind",V.Bytes "selected"),("context",descriptor context)]
  | W.Ambiguous contexts => V.Object [("kind",V.Bytes "ambiguous"),("contexts",V.Array (List.map descriptor contexts))]
  fun readFile (file,mode) =
    let val input=BinIO.openIn file
        val bytes=(Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input)
          handle error => (BinIO.closeIn input handle _ => ();raise error)
    in if mode="unicode=latin1" then String.translate (fn byte => Utf8.encode (Char.ord byte)) bytes else bytes end
  fun position (source:source,encoding,offset,forward) =
    case #index source of NONE => {line=0,character=0}:LspProtocol.position
    | SOME index =>
        let val count=size (#text source)
            fun find at=case L.position (index,encoding,at) of SOME value => value
              | NONE => if forward andalso at<count then find (at+1) else if at>0 then find (at-1) else {line=0,character=0}
        in find (Int.max (0,Int.min (count,offset))) end
  fun range (source,encoding,start,stop)=LspProtocol.rangeToJson
    {start=position (source,encoding,start,false),stop=position (source,encoding,stop,true)}
  fun sourceFor (view:view,file)=List.find (fn source:source => #file source=file) (#sources view)
  fun tokens (source:source) = case !(#tokens source) of SOME tokens => tokens | NONE =>
    let val parsed=C.Syntax.parse {file= #file source,text= #text source,mode= #mode source,orPatterns=true,fixity=C.Syntax.initial}
        val tokens=C.Syntax.pieces parsed
    in #tokens source:=SOME tokens;tokens end
  fun identifier (piece:C.Syntax.piece)=List.exists (fn kind => kind= #kind piece) ["identifier","operator","typeVariable"]
  fun selections (source:source,occurrence:A.occurrence) =
    let val wanted= #path occurrence @ [#name occurrence]
        fun prefix ([],_)=true | prefix (_,[])=false | prefix (a::rest,b::others)=a=b andalso prefix (rest,others)
        fun piece (piece:C.Syntax.piece) =
          if not (identifier piece) orelse #start piece< #start occurrence orelse #stop piece> #stop occurrence then NONE else
          let val parts=String.fields (fn c => c= #".") (#text piece)
              val matched=if #kind occurrence="structure" andalso not (#isDefinition occurrence)
                then prefix (wanted,parts) else wanted=parts
              val index=length wanted-1
          in if not matched orelse index<0 orelse index>=length parts then NONE else
               let val start= #start piece+List.foldl (fn (part,n) => n+size part+1) 0 (List.take (parts,index))
               in SOME (start,start+size (List.nth (parts,index))) end end
        val ranges=List.mapPartial piece (tokens source)
    in if #kind occurrence="type" andalso not (#isDefinition occurrence) then
         (case List.rev ranges of [] => [] | last::_ => [last])
       else (case ranges of [] => [] | first::_ => [first]) end
  fun owned (view:view,occurrence:A.occurrence) = case #ordinal view of NONE => true | SOME ordinal =>
    case List.find (fn source:source => #uri source= #uri view) (#sources view) of NONE => false | SOME source =>
      #unit occurrence= #file source ^ "#" ^ Int.toString (ordinal+1)
  fun at (view:view,source:source,offset) =
    let val candidates=List.concat (List.map (fn occurrence:A.occurrence =>
          if #file occurrence<> #file source orelse not (owned (view,occurrence)) then [] else
            List.mapPartial (fn (start,stop) => if start<=offset andalso offset<stop then SOME (occurrence,(start,stop)) else NONE)
              (selections (source,occurrence))) (A.occurrences (#snapshot view)))
        fun best (item,NONE)=SOME item
          | best (item as (occurrence:A.occurrence,_),old as SOME (prior:A.occurrence,_))=
              if #derived prior andalso not (#derived occurrence) orelse #derived prior= #derived occurrence andalso
                 #stop occurrence- #start occurrence< #stop prior- #start prior then SOME item else old
    in List.foldl best NONE candidates end
  fun location (view:view,location:A.location)=case sourceFor (view,#file location) of NONE => NONE
    | SOME source => SOME (Json.Object [("uri",Json.String (#uri source)),
        ("range",range (source,#encoding view,#start location,#stop location))])
  fun unique values=List.foldl (fn (value,all) => if List.exists (fn prior => prior=value) all then all else all @ [value]) [] values
  fun symbols (view:view,source:source) =
    let val definitions=List.filter (fn occurrence:A.occurrence => #file occurrence= #file source andalso #isDefinition occurrence
          andalso not (#derived occurrence) andalso owned (view,occurrence)) (A.occurrences (#snapshot view))
        fun symbol (occurrence:A.occurrence)=case selections (source,occurrence) of [] => NONE | (start,stop)::_ =>
          let val functions=List.exists (fn fact:A.fact => #unit fact= #unit occurrence andalso #file fact= #file source
                andalso #start fact<=start andalso start< #stop fact andalso not (null (#arguments fact))) (A.facts (#snapshot view))
              val kind=case #kind occurrence of "structure" => 2 | "signature" => 11 | "functor" => 12 | "type" => 23
                | _ => if functions then 12 else 13
          in SOME (Json.Object [("name",Json.String (#name occurrence)),("kind",Json.int kind),
            ("location",Json.Object [("uri",Json.String (#uri source)),("range",range (source,#encoding view,start,stop))])]) end
    in unique (List.mapPartial symbol definitions) end
  fun capability (value,[])=SOME value
    | capability (value,name::rest)=Option.mapPartial (fn value => capability (value,rest)) (Json.member (name,value))
  fun diagnostics (view:view) =
    let fun diagnostic (diagnostic:C.diagnostic) = case sourceFor (view,#file diagnostic) of NONE => NONE
          | SOME source => SOME (#uri source,Json.Object [("range",range (source,#encoding view,#start diagnostic,#stop diagnostic)),
              ("severity",Json.int (if #severity diagnostic="error" then 1 else 2)),("source",Json.String "rune"),
              ("message",if capability (#capabilities view,["textDocument","diagnostic","markupMessageSupport"])=SOME (Json.Bool true)
                then Json.Object [("kind",Json.String "plaintext"),("value",Json.String (safe (#message diagnostic)))]
                else Json.String (safe (#message diagnostic)))])
    in List.mapPartial diagnostic (A.diagnostics (#snapshot view)) end
  fun check (worker as Worker {views,...},{state,uri,encoding,capabilities,cancelled}) =
    let val (workspace as W.Workspace {platform,lib,...},documents)=M.restore state
        val _=RuneLspProjects.enrich (workspace,documents,cancelled)
        val configuration=W.configurationFor (workspace,uri)
        val selection=W.select (workspace,documents,uri)
        val selected=case selection of W.Ambiguous _ => raise Fail "select a build context before analysis"
          | W.Selected context => SOME context | W.Loose => NONE
        val target=case selected of NONE => NONE | SOME selected => List.find (fn target:W.target =>
          #build target= #build selected andalso #name target= #target selected) (#targets configuration)
        val flags=case target of NONE => #flags configuration | SOME target => #flags target
        val libraryRoot=case target of NONE => getOpt (#libraryRoot configuration,lib)
          | SOME target => getOpt (#libraryRoot target,getOpt (#libraryRoot configuration,lib))
        val variables= #variables configuration @ (case target of NONE => [] | SOME target => #variables target)
        val key=V.encode (V.Array [V.Bytes (case selected of NONE => "loose:" ^ uri
            | SOME selected => #build selected ^ "#" ^ #target selected),
          V.Bytes libraryRoot,M.strings flags,M.pairs variables])
        val context=context (worker,{key=key,lib=libraryRoot,flags=flags})
        fun native uri=U.native (platform,U.parse uri)
        val overlays=List.mapPartial (fn snapshot:D.snapshot => case native (#uri snapshot) of NONE => NONE
          | SOME {path,...} => SOME {file=path,text=L.text (#content snapshot)}) (D.all documents)
        fun matches (file,snapshot:D.snapshot)=case native (#uri snapshot) of NONE => file= #uri snapshot
          | SOME {path,...} => W.sameFile platform (file,path)
        fun overlay file=case List.filter (fn snapshot => matches (file,snapshot)) (D.all documents) of [] => NONE
          | first :: rest => if List.exists (fn snapshot => L.text (#content snapshot)<>L.text (#content first)) rest
              then raise Fail "conflicting source overlays refer to one file" else SOME first
        fun input (source:C.Project.source):A.input =
          let val opened=overlay (#file source)
          in {file= #file source,text=case opened of SOME snapshot => L.text (#content snapshot)
                | NONE => readFile (#file source,#mode source),mode= #mode source,annotations= #annotations source,
              revision=case opened of NONE => "disk" | SOME snapshot => IntInf.toString (#revision snapshot)} end
        val project=case selected of NONE => NONE | SOME selected => SOME (C.Project.read (#compiler context,
          {file=W.filePath platform (#build selected),variables=variables,overlays=overlays,windows=platform=U.Windows}))
        val inputs=case project of SOME project => List.map input (C.Project.sources project)
          | NONE =>
              let val snapshot=case D.snapshot (documents,uri) of SOME snapshot => snapshot | NONE => raise Fail "document is not open"
                  val file=case native uri of NONE => uri | SOME {path,...} => path
              in [{file=file,text=L.text (#content snapshot),mode="",annotations=[],revision=IntInf.toString (#revision snapshot)}:A.input] end
        val snapshot=A.check (#analysis context,{project=project,inputs=inputs,cancelled=cancelled})
        fun captured (input:A.input):source list =
          let val opened=overlay (#file input)
              val aliases=List.filter (fn snapshot => matches (#file input,snapshot)) (D.all documents)
              val aliases=case List.find (fn snapshot:D.snapshot => #uri snapshot=uri) aliases of NONE => aliases
                | SOME current => current :: List.filter (fn snapshot:D.snapshot => #uri snapshot<>uri) aliases
              val uris=if null aliases then [(U.original (U.fromPath (platform,OS.FileSys.fullPath (#file input))),NONE)]
                else List.map (fn snapshot:D.snapshot => (#uri snapshot,SOME (#version snapshot))) aliases
              val index=(SOME (L.make (#text input)) handle L.Invalid => NONE)
              val pieces=ref NONE
          in List.map (fn (uri,version) => {file= #file input,uri=uri,text= #text input,mode= #mode input,version=version,
            index=index,tokens=pieces}:source) uris end
        val sources=List.concat (List.map captured (A.inputs snapshot @ A.dependencies snapshot))
        val view={id=A.id snapshot,snapshot=snapshot,sources=sources,encoding=encoding,uri=uri,
          ordinal=Option.map #ordinal selected,capabilities=capabilities}:view
        val all=view :: !views
        val ()=views:=List.take (all,Int.min (4,length all))
    in view end
  fun find (Worker {views,...},id)=List.find (fn view:view => #id view=id) (!views)
  fun documentDiagnostics (view:view,{uri,previous}) =
    let val all=diagnostics view
        val direct=List.map #2 (List.filter (fn (source,_) => source=uri) all)
        val inputs=A.inputs (#snapshot view)
        fun ordinal file =
          let fun find (_,[])=length inputs | find (n,(input:A.input)::rest)=if #file input=file then n else find (n+1,rest)
          in find (0,inputs) end
        val active=case List.find (fn source:source => #uri source=uri) (#sources view) of NONE => length inputs
          | SOME source => getOpt (#ordinal view,ordinal (#file source))
        val earlierFailure=List.exists (fn diagnostic:C.diagnostic => ordinal (#file diagnostic)<active) (A.diagnostics (#snapshot view))
        val items=if not (null direct) orelse not earlierFailure then direct else
          let val related=List.mapPartial (fn diagnostic:C.diagnostic => case sourceFor (view,#file diagnostic) of NONE => NONE
                | SOME source => SOME (Json.Object [("location",Json.Object [("uri",Json.String (#uri source)),
                    ("range",range (source,#encoding view,#start diagnostic,#stop diagnostic))]),
                  ("message",Json.String (safe (#message diagnostic)))])) (A.diagnostics (#snapshot view))
              val relatedSupported=capability (#capabilities view,["textDocument","publishDiagnostics","relatedInformation"])=SOME (Json.Bool true)
                orelse capability (#capabilities view,["textDocument","diagnostic","relatedInformation"])=SOME (Json.Bool true)
          in [Json.Object ([("range",LspProtocol.rangeToJson {start={line=0,character=0},stop={line=0,character=0}}),
              ("severity",Json.int 3),("source",Json.String "runelsp"),("code",Json.String "rune.analysis.blocked"),
              ("message",Json.String "analysis is unavailable because an earlier source could not be checked")] @
              (if relatedSupported then [("relatedInformation",Json.Array related)] else []))] end
        val resultId=Hex.fromBytes (Sha256.digest (A.context (#snapshot view) ^ "\000" ^ uri ^ "\000" ^ Json.encode (Json.Array items)))
    in if previous=SOME resultId then Json.Object [("kind",Json.String "unchanged"),("resultId",Json.String resultId)]
       else Json.Object [("kind",Json.String "full"),("resultId",Json.String resultId),("items",Json.Array items)] end
  fun reports (view:view) =
    List.map (fn source:source => V.Object [("uri",V.Bytes (#uri source)),
      ("version",case #version source of NONE => V.Null | SOME version => V.Integer version),
      ("report",V.json (documentDiagnostics (view,{uri= #uri source,previous=NONE})))])
      (List.filter (fn source:source => #uri source= #uri view) (#sources view))
  fun workspaceViews (worker,{state,encoding,capabilities,cancelled}) =
    let val (workspace,documents)=M.restore state
        val {uris,problems}=RuneLspProjects.enrich (workspace,documents,cancelled)
        val uris=unique (List.map #uri (D.all documents) @ uris)
        val captured=M.capture (workspace,documents)
        val checked=ref [] : (string*view) list ref
        val output=ref [] : view list ref
        fun contextKey (context:W.context)= #build context ^ "#" ^ #target context ^ ":" ^ C.Project.fingerprint (#project context)
        fun one uri =
          if cancelled () then raise A.Cancelled else
          case W.select (workspace,documents,uri) of W.Ambiguous _ => ()
          | selected =>
            let val key=case selected of W.Loose => "loose:" ^ uri | W.Selected context => contextKey context | _ => ""
                val prior=List.find (fn (old,_) => old=key) (!checked)
                val view=case prior of SOME (_,view) => view
                  | NONE => check (worker,{state=captured,uri=uri,encoding=encoding,capabilities=capabilities,cancelled=cancelled})
                val view={id= #id view,snapshot= #snapshot view,sources= #sources view,encoding= #encoding view,uri=uri,
                  ordinal=case selected of W.Selected context => SOME (#ordinal context) | _ => NONE,capabilities=capabilities}:view
                val ()=if isSome prior then () else checked:=(key,view):: !checked
            in output:=view :: !output end
        val ()=List.app one uris
    in {views=List.rev (!output),problems=problems} end
  fun workspaceDiagnostics (worker,{state,encoding,capabilities,cancelled,previous}) =
    let val {views,problems}=workspaceViews (worker,{state=state,encoding=encoding,capabilities=capabilities,cancelled=cancelled})
        fun report (view:view)=
          let val prior=case List.find (fn (uri,_) => uri= #uri view) previous of NONE => NONE | SOME (_,id) => SOME id
              val json=documentDiagnostics (view,{uri= #uri view,previous=prior})
              val fields=case json of Json.Object fields => fields | _ => []
              val version=case List.find (fn source:source => #uri source= #uri view) (#sources view) of
                SOME source => (case #version source of NONE => Json.Null | SOME version => Json.intInf version) | NONE => Json.Null
          in Json.Object (("uri",Json.String (#uri view)) :: ("version",version) :: fields) end
        fun problem ({uri,message}:RuneLspProjects.problem)=Json.Object [("uri",Json.String uri),("version",Json.Null),
          ("kind",Json.String "full"),("items",Json.Array [Json.Object
            [("range",LspProtocol.rangeToJson {start={line=0,character=0},stop={line=0,character=0}}),
             ("severity",Json.int 1),("source",Json.String "rune-build"),("message",Json.String (safe message))]])]
    in Json.Object [("items",Json.Array (List.map report views @ List.map problem problems))] end
  fun symbolToken symbol=Hex.fromBytes (Sha256.digest (Json.encode symbol))
  fun workspaceSymbols (worker,{state,encoding,capabilities,cancelled,query}) =
    let val {views,...}=workspaceViews (worker,{state=state,encoding=encoding,capabilities=capabilities,cancelled=cancelled})
        val generation=V.integer (V.field (state,"generation"))
        val needle=String.map Char.toLower query
        val resolve=case capability (capabilities,["workspace","symbol","resolveSupport","properties"]) of
          SOME (Json.Array properties) => List.exists (fn value => value=Json.String "location.range") properties | _ => false
        fun viewSymbols (view:view)=case List.find (fn source:source => #uri source= #uri view) (#sources view) of NONE => []
          | SOME source => List.mapPartial (fn symbol =>
              let val name=J.string (J.required (symbol,"name"))
                  val fields=case symbol of Json.Object fields => fields | _ => []
                  val full=J.required (symbol,"location")
                  val shown=if resolve then Json.Object [("uri",J.required (full,"uri"))] else full
                  val data=Json.Object [("snapshot",Json.String (#id view)),("token",Json.String (symbolToken symbol)),
                    ("uri",Json.String (#uri view)),("generation",Json.intInf generation),
                    ("ordinal",case #ordinal view of NONE => Json.Null | SOME ordinal => Json.int ordinal)]
              in if not (String.isSubstring needle (String.map Char.toLower name)) then NONE else
                   SOME (Json.Object (("data",data)::("location",shown)::List.filter (fn (key,_) => key<>"location") fields)) end)
              (symbols (view,source))
        val all=unique (List.concat (List.map viewSymbols views))
    in Json.Array (List.take (all,Int.min (1000,length all))) end
  fun resolveSymbol (worker,params,state) =
    let val data=J.object (J.required (J.object params,"data"))
        val generation=case Json.toIntInf (J.required (data,"generation")) of SOME generation => generation
          | NONE => raise Fail "invalid symbol generation"
        val ()=if generation=V.integer (V.field (state,"generation")) then () else raise Fail "workspace symbol is stale"
        val view=case find (worker,J.string (J.required (data,"snapshot"))) of SOME view => view | NONE => raise Fail "symbol snapshot has been evicted"
        val uri=J.string (J.required (data,"uri"))
        val ordinal=case J.required (data,"ordinal") of Json.Null => NONE | value => Json.toInt value
        val view={id= #id view,snapshot= #snapshot view,sources= #sources view,encoding= #encoding view,uri=uri,
          ordinal=ordinal,capabilities= #capabilities view}:view
        val source=case List.find (fn source:source => #uri source=uri) (#sources view) of SOME source => source
          | NONE => raise Fail "symbol source is unavailable"
        val (_,documents)=M.restore state
        val text=case D.snapshot (documents,uri) of SOME snapshot => L.text (#content snapshot)
          | NONE => readFile (#file source,#mode source)
        val ()=if text= #text source then () else raise Fail "workspace symbol source changed"
        val token=J.string (J.required (data,"token"))
        val symbol=case List.find (fn symbol => symbolToken symbol=token) (symbols (view,source)) of SOME symbol => symbol
          | NONE => raise Fail "workspace symbol data is invalid"
        val fields=case symbol of Json.Object fields => fields | _ => []
    in Json.Object (("data",data)::fields) end
  fun completionItems (view:view,source:source,offset) =
    let fun ordinal ([],_)=NONE
          | ordinal ((input:A.input)::rest,index)=if #file input= #file source then SOME index else ordinal (rest,index+1)
        val selected=case #ordinal view of SOME index => SOME index | NONE => ordinal (A.inputs (#snapshot view),0)
        fun visible path=case selected of NONE => [] | SOME ordinal =>
          A.visibleAt (#snapshot view,{ordinal=ordinal,offset=offset,path=path})
    in RuneLspCompletion.items {text= #text source,offset=offset,pieces=tokens source,snapshot= #id view,
      uri= #uri source,visible=visible,range=fn (start,stop) => range (source,#encoding view,start,stop)} end
  fun query (view:view,{method,params}) =
    let val resolving=method="completionItem/resolve"
        val document=J.object (J.required (J.object params,if resolving then "data" else "textDocument"))
        val uri=J.string (J.required (document,"uri"))
        val source=case List.find (fn source:source => #uri source=uri) (#sources view) of
          SOME source => source | NONE => raise Fail "document is not part of this analysis snapshot"
        fun offset ()=case LspProtocol.positionFromJson (J.required (params,"position")) of NONE => raise J.Invalid "invalid semantic position"
          | SOME point => case #index source of NONE => NONE | SOME index => L.offset (index,#encoding view,point)
        fun occurrence ()=Option.mapPartial (fn offset => at (view,source,offset)) (offset ())
        fun target choose=case occurrence () of NONE => Json.Array [] | SOME (occurrence,_) =>
          Json.Array (case Option.mapPartial (fn target => location (view,target)) (choose occurrence) of NONE => [] | SOME target => [target])
    in case method of "textDocument/diagnostic" =>
         documentDiagnostics (view,{uri=uri,previous=case J.member (params,"previousResultId") of
           SOME (Json.String value) => SOME value | NONE => NONE | _ => raise J.Invalid "invalid diagnostic result id"})
       | "textDocument/completion" => Json.Object [("isIncomplete",Json.Bool true),
           ("items",Json.Array (case offset () of NONE => [] | SOME at => completionItems (view,source,at)))]
       | "completionItem/resolve" =>
           let val data=document
               val ()=if J.string (J.required (data,"snapshot"))= #id view then () else raise Fail "completion item is stale"
               val at=case Json.toInt (J.required (data,"offset")) of SOME at => at | NONE => raise J.Invalid "invalid completion offset"
               val name=J.string (J.required (data,"name"))
               val kind=J.string (J.required (data,"kind"))
           in case List.find (fn item => case Json.member ("data",item) of NONE => false | SOME value =>
                 Json.member ("name",value)=SOME (Json.String name) andalso Json.member ("kind",value)=SOME (Json.String kind))
                (completionItems (view,source,at)) of SOME item => item | NONE => raise Fail "completion item is unavailable" end
       | "textDocument/definition" => target (fn occurrence:A.occurrence => #definition occurrence)
       | "textDocument/declaration" => target (fn occurrence:A.occurrence => #declaration occurrence)
       | "textDocument/typeDefinition" =>
           let val constructors=case offset () of NONE => [] | SOME offset => List.concat (List.map #constructors
                 (List.filter (fn fact:A.fact => #file fact= #file source andalso not (#derived fact)
                   andalso #start fact<=offset andalso offset< #stop fact) (A.facts (#snapshot view))))
               val definitions=List.filter (fn definition:A.typeDefinition => List.exists (fn id => id= #id definition) constructors) (A.types (#snapshot view))
           in Json.Array (unique (List.mapPartial (fn definition:A.typeDefinition =>
                Option.mapPartial (fn target => location (view,target)) (#definition definition)) definitions)) end
       | "textDocument/implementation" =>
           let val declaration=case occurrence () of NONE => NONE | SOME (occurrence,_) => #declaration occurrence
               val implementations=List.filter (fn occurrence:A.occurrence => #declaration occurrence=declaration andalso isSome declaration
                 andalso #definition occurrence<>declaration)
                 (A.occurrences (#snapshot view))
               val typeImplementations=List.filter (fn definition:A.typeDefinition => #declaration definition=declaration
                 andalso isSome declaration andalso #implementation definition<>declaration) (A.types (#snapshot view))
           in Json.Array (unique (List.mapPartial (fn occurrence:A.occurrence =>
                Option.mapPartial (fn target => location (view,target)) (#definition occurrence)) implementations @
                List.mapPartial (fn definition:A.typeDefinition => Option.mapPartial (fn target => location (view,target))
                  (#implementation definition)) typeImplementations)) end
       | "textDocument/documentSymbol" => Json.Array (symbols (view,source))
       | "textDocument/hover" =>
         let val point=case LspProtocol.positionFromJson (J.required (params,"position")) of
               SOME point => point | NONE => raise J.Invalid "invalid hover position"
             val offset=case #index source of NONE => NONE | SOME index => L.offset (index,#encoding view,point)
         in case Option.mapPartial (fn offset => case #ordinal view of
                SOME ordinal => A.typeAtOccurrence (#snapshot view,{ordinal=ordinal,offset=offset})
              | NONE => A.typeAt (#snapshot view,{file= #file source,offset=offset})) offset of
              NONE => Json.Null | SOME ty =>
                let val formats=case capability (#capabilities view,["textDocument","hover","contentFormat"]) of
                      SOME (Json.Array formats) => formats | _ => []
                    val markdown=case List.find (fn format => format=Json.String "markdown" orelse format=Json.String "plaintext") formats of
                      SOME (Json.String "markdown") => true | _ => false
                    fun longest (i,run,best)=if i=size ty then Int.max (run,best) else
                      if String.sub (ty,i)= #"`" then longest (i+1,run+1,best) else longest (i+1,0,Int.max (run,best))
                    val fence=CharVector.tabulate (Int.max (3,longest (0,0,0)+1),fn _ => #"`")
                    val shown=if markdown then fence ^ "sml\n" ^ safe ty ^ "\n" ^ fence else safe ty
                in Json.Object [("contents",Json.Object [("kind",Json.String (if markdown then "markdown" else "plaintext")),
                  ("value",Json.String shown)])] end
         end
       | _ => raise Fail "semantic method is not implemented" end
end

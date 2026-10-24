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
  exception Stale of string
  type context={key:string,compiler:C.session,analysis:A.t,bytes:int ref}
  type source={file:string,uri:string,text:string,mode:string,ordinal:int option,syntax:C.Syntax.t option,
    slot:int,version:IntInf.int option,revision:IntInf.int option,index:L.t option,
    tokens:(C.Syntax.piece list * C.Syntax.piece vector) option ref}
  type scope={role:string,fields:(string*string) list,candidates:A.candidate list}
  type scopeEntry={ordinal:int,offset:int,path:string list,result:scope,bytes:int}
  type view={id:string,snapshot:A.snapshot,sources:source list,encoding:LspProtocol.encoding,uri:string,ordinal:int option,
    capabilities:Json.value,activeUnit:string option,generation:IntInf.int,scopes:scopeEntry list ref}
  datatype t=Worker of {contexts:context list ref,views:view list ref,tokens:RuneLspTokens.t,namespace:string ref,
    progress:(V.value->unit) ref}
  fun new ()=Worker {contexts=ref [],views=ref [],tokens=RuneLspTokens.new (),namespace=ref "local",progress=ref(fn _=>())}
  fun onProgress (Worker{progress,...},report)=progress:=report
  fun notify (Worker{progress,...},fields)=(!progress)(V.Object fields)
  (* Job IDs belong to the supervisor and do not reset with this process. *)
  fun commandId (Worker {namespace,...},id)=
    (namespace:="worker-job-" ^ IntInf.toString id;RuneLspProfile.job:= !namespace)
  fun safe text =
    let fun loop i=if i=size text then [] else
          case Utf8.decode (text,i) of SOME (_,count) => String.substring (text,i,count) :: loop (i+count)
          | NONE => ("\\x" ^ StringCvt.padLeft #"0" 2 (Int.fmt StringCvt.HEX (Char.ord (String.sub (text,i))))) :: loop (i+1)
    in String.concat (loop 0) end
  fun clear (Worker {contexts,views,tokens,...}) =
    (List.app (fn context:context => (A.close (#analysis context);C.close (#compiler context))) (!contexts);
     contexts:=[];views:=[];RuneLspTokens.clear tokens)
  val retainedSourceBudget=2*1024*1024
  fun inputBytes inputs=List.foldl(fn (input:A.input,n)=>size(#text input)+n)0 inputs
  fun snapshotBytes snapshot=inputBytes(A.inputs snapshot)+inputBytes(A.dependencies snapshot)
  (* Charge shared text on every retained view. This conservative source-byte
     budget supplements the count, VM heap and process address-space limits. *)
  fun retain weight entries=
    let fun loop([],_,_,kept)=List.rev kept
          | loop(entry::rest,n,bytes,kept)=
              if n=4 orelse n>0 andalso weight entry>retainedSourceBudget-bytes then List.rev kept
              else loop(rest,n+1,bytes+weight entry,entry::kept)
    in loop(entries,0,0,[]) end
  fun release (context:context)=(A.close(#analysis context);C.close(#compiler context))
  fun context (Worker {contexts,progress,...},{key,lib,flags}) =
    case List.find (fn context:context => #key context=key) (!contexts) of SOME context =>
      (contexts:=context :: List.filter (fn prior:context => #key prior<>key) (!contexts);context)
    | NONE =>
      let val compiler=C.session {lib=lib,flags=flags}
          val context={key=key,compiler=compiler,analysis=A.create (compiler,{context=key}),bytes=ref 0}:context
          val reportedChecked=ref ~1
          val ()=A.observe(#analysis context,SOME(fn event:A.observation=>
            let val report= #phase event<>"unit-frozen" orelse #checked event<> !reportedChecked
                val ()=reportedChecked:= #checked event
            in RuneLspProfile.observe event;if report then
              (!progress)(V.Object[("phase",V.Bytes(#phase event)),("file",V.Bytes(#file event)),
                ("checked",V.Integer(IntInf.fromInt(#checked event))),("reused",V.Integer(IntInf.fromInt(#reused event)))]) else () end))
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
  fun makeView {id,snapshot,sources,encoding,uri,ordinal,capabilities,generation} : view =
    let val activeUnit=A.unitAt (snapshot,{ordinal=getOpt (ordinal,0)})
    in {id=id,snapshot=snapshot,sources=sources,encoding=encoding,uri=uri,
        ordinal=ordinal,capabilities=capabilities,activeUnit=activeUnit,generation=generation,scopes=ref []} end
  fun activeSource (view:view,uri) = List.find (fn source:source => #uri source=uri andalso
    (uri<> #uri view orelse #ordinal source=SOME (getOpt (#ordinal view,0)))) (#sources view)
  fun sourceFor (view:view,file)=List.find (fn source:source => #file source=file) (#sources view)
  fun tokenData (source:source) = case !(#tokens source) of SOME tokens => tokens | NONE =>
    let val parsed=case #syntax source of SOME syntax => syntax | NONE =>
          C.Syntax.parse {file= #file source,text= #text source,mode= #mode source,orPatterns=true,fixity=C.Syntax.initial}
        val pieces=C.Syntax.pieces parsed
        val tokens=(pieces,Vector.fromList pieces)
    in #tokens source:=SOME tokens;tokens end
  fun tokens source = #1 (tokenData source)
  fun piecesWithin (source,start,stop) =
    let val pieces= #2 (tokenData source)
        val count=Vector.length pieces
        fun lower (lo,hi)=if lo>=hi then lo else
          let val mid=lo+(hi-lo) div 2
          in if #start (Vector.sub (pieces,mid))<start then lower (mid+1,hi) else lower (lo,mid) end
        fun collect (at,kept)=if at=count then List.rev kept else
          let val piece=Vector.sub (pieces,at)
          in if #start piece>=stop then List.rev kept else collect (at+1,piece::kept) end
    in collect (lower (0,count),[]) end
  fun identifier (piece:C.Syntax.piece)=List.exists (fn kind => kind= #kind piece) ["identifier","operator","typeVariable"]
  fun selectionCandidates (source:source,occurrence:A.occurrence) =
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
    in List.mapPartial piece (piecesWithin (source,#start occurrence,#stop occurrence)) end
  fun selections (source,occurrence:A.occurrence) =
    let val ranges=selectionCandidates (source,occurrence)
    in if #kind occurrence="type" andalso not (#isDefinition occurrence) then
         (case List.rev ranges of [] => [] | last::_ => [last])
       else (case ranges of [] => [] | first::_ => [first]) end
  fun ownedUnit (view:view,unit) = #activeUnit view=SOME unit
  fun owned (view,occurrence:A.occurrence) = ownedUnit (view,#unit occurrence)
  fun at (view:view,source:source,offset) =
    let val candidates=List.concat (List.map (fn occurrence:A.occurrence =>
          if #file occurrence<> #file source orelse not (owned (view,occurrence)) orelse
             offset< #start occurrence orelse offset>= #stop occurrence then [] else
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
  fun highlights (view:view,source:source,offset) =
    case (case at (view,source,offset) of NONE => if offset>0 then at (view,source,offset-1) else NONE
          | found => found) of NONE => Json.Array [] | SOME (selected,_) =>
      case #binding selected of NONE => Json.Array [] | SOME binding =>
        let
          fun collect (occurrence:A.occurrence,(count,kept)) =
            if #file occurrence<> #file source orelse not (owned (view,occurrence)) orelse
               #derived occurrence orelse #binding occurrence<>SOME binding then (count,kept)
            else List.foldl (fn ((start,stop),(count,kept)) =>
              if count=8192 then raise Fail "document highlights exceed the supported response budget"
              else (count+1,(start,stop,if #kind occurrence="value" andalso not (#isDefinition occurrence) then 2 else 1)::kept))
              (count,kept) (selections (source,occurrence))
          val (_,ranges)=List.foldl collect (0,[]) (A.occurrences (#snapshot view))
          fun before' ((a,b,k),(c,d,l))=a<c orelse a=c andalso (b<d orelse b=d andalso k<=l)
          fun merge ([],ys)=ys | merge (xs,[])=xs
            | merge (xs as x::xt,ys as y::yt)=if before' (x,y) then x::merge (xt,ys) else y::merge (xs,yt)
          fun split (x::y::rest)=let val (a,b)=split rest in (x::a,y::b) end | split xs=(xs,[])
          fun sort []=[] | sort [x]=[x] | sort xs=let val (a,b)=split xs in merge (sort a,sort b) end
          fun emit ([],_)=[]
            | emit ((start,stop,kind)::rest,previous)=
                if previous=SOME (start,stop) then emit (rest,previous) else
                Json.Object [("range",range (source,#encoding view,start,stop)),("kind",Json.int kind)]::
                  emit (rest,SOME (start,stop))
        in Json.Array (emit (sort ranges,NONE)) end
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
  fun check (worker as Worker {contexts,views,namespace,...},{state,uri,encoding,capabilities,cancelled}) =
    let val (workspace as W.Workspace {platform,lib,...},documents)=M.restore state
        val _=RuneLspProjects.enrich (workspace,documents,cancelled)
        val configuration=W.configurationFor (workspace,uri)
        val selection=W.select (workspace,documents,uri)
        val selected=case selection of W.Ambiguous _ => raise Fail "select a build context before analysis"
          | W.Selected context => SOME context | W.Loose => NONE
        val ()=notify(worker,[("phase",V.Bytes "project-selected"),("file",V.Bytes(case selected of NONE=>uri | SOME context=> #build context)),
          ("context",V.Bytes(case selected of NONE=>"loose source" | SOME context=> #target context))])
        val target=case selected of NONE => NONE | SOME selected => List.find (fn target:W.target =>
          #build target= #build selected andalso #name target= #target selected) (#targets configuration)
        val flags=case target of NONE => #flags configuration | SOME target => #flags target
        val libraryRoot=case target of NONE => getOpt (#libraryRoot configuration,lib)
          | SOME target => getOpt (#libraryRoot target,getOpt (#libraryRoot configuration,lib))
        val variables= #variables configuration @ (case target of NONE => [] | SOME target => #variables target)
        (* The owning Basis is compiled from the initial environment. Loading
           its sealed program prelude first both duplicates it and hides the
           internal names/primitive permission needed by its own sources. *)
        val bootstrap=case selected of NONE=>false | SOME selected=>
          W.isBasisBuild platform (libraryRoot,W.filePath platform (#build selected))
        fun withoutLibraries ("--library"::_::rest)=withoutLibraries rest
          | withoutLibraries (flag::rest)=flag::withoutLibraries rest
          | withoutLibraries []=[]
        val compilerFlags=if bootstrap then "--allow-prim"::withoutLibraries flags else flags
        val compilerLib=if bootstrap then NONE else SOME libraryRoot
        val key=V.encode (V.Array [V.Bytes (case selected of NONE => "loose:" ^ uri
            | SOME selected => #build selected ^ "#" ^ #target selected),
          V.Bytes libraryRoot,V.Bool bootstrap,M.strings compilerFlags,M.pairs variables])
        val context=context (worker,{key=key,lib=compilerLib,flags=compilerFlags})
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
        val ()=if inputBytes inputs+List.foldl(fn (prior:context,n)=>
              if #key prior=key then n else !(#bytes prior)+n)0(!contexts)<=retainedSourceBudget then () else
          (List.app release (List.filter(fn prior:context=> #key prior<>key)(!contexts));
           contexts:=[context];views:=List.filter(fn view:view=>A.context(#snapshot view)=key)(!views))
        val snapshot=A.check (#analysis context,{project=project,inputs=inputs,cancelled=cancelled})
        val ()= #bytes context:=snapshotBytes snapshot
        val kept=retain (fn context:context=> !(#bytes context)) (!contexts)
        val ()=List.app release (List.filter(fn prior:context=>not(List.exists(fn context:context=> #key context= #key prior)kept))(!contexts))
        val ()=contexts:=kept
        (* Slots address the previous captured graph in linear time. Exact
           file/text/mode guards also cover reordered and repeated inputs. *)
        val previous=case !views of []=>Vector.fromList [] | view::_=>
          let val slots=Array.array(length(A.inputs(#snapshot view))+length(A.dependencies(#snapshot view)),NONE)
              val ()=List.app(fn source:source=>Array.update(slots,#slot source,SOME source))(#sources view)
          in Array.vector slots end
        fun captured (input:A.input,ordinal,slot):source list =
          let val opened=overlay (#file input)
              val aliases=List.filter (fn snapshot => matches (#file input,snapshot)) (D.all documents)
              val aliases=case List.find (fn snapshot:D.snapshot => #uri snapshot=uri) aliases of NONE => aliases
                | SOME current => current :: List.filter (fn snapshot:D.snapshot => #uri snapshot<>uri) aliases
              val uris=if null aliases then [(U.original (U.fromPath (platform,OS.FileSys.fullPath (#file input))),NONE,NONE)]
                else List.map (fn snapshot:D.snapshot => (#uri snapshot,SOME (#version snapshot),SOME (#revision snapshot))) aliases
              val prior=if slot>=Vector.length previous then NONE else
                case Vector.sub(previous,slot) of SOME source=>
                  if #file source= #file input andalso #text source= #text input andalso #mode source= #mode input
                  then SOME source else NONE | NONE=>NONE
              val index=case prior of SOME source=> #index source | NONE=>
                (notify(worker,[("phase",V.Bytes "indexing-source"),("file",V.Bytes(#file input)),
                   ("checked",V.Integer(IntInf.fromInt(#checked(A.work snapshot)))),
                   ("reused",V.Integer(IntInf.fromInt(#reused(A.work snapshot))))]);
                 SOME(L.make(#text input)) handle L.Invalid=>NONE)
              val pieces=case prior of SOME source=> #tokens source | NONE=>ref NONE
              val syntax=Option.mapPartial (fn ordinal => A.syntaxAt (snapshot,{ordinal=ordinal})) ordinal
          in List.map (fn (uri,version,revision) => {file= #file input,uri=uri,text= #text input,mode= #mode input,ordinal=ordinal,
            syntax=syntax,slot=slot,version=version,revision=revision,
            index=index,tokens=pieces}:source) uris end
        val primary=A.inputs snapshot
        val dependencies=A.dependencies snapshot
        val primaryCount=length primary
        val sources=List.concat (ListPair.map (fn (input,ordinal) => captured (input,SOME ordinal,ordinal))
          (primary,List.tabulate (primaryCount,fn i => i)) @
          ListPair.map (fn (input,ordinal)=>captured(input,NONE,primaryCount+ordinal))
            (dependencies,List.tabulate(length dependencies,fn i=>i)))
        val view=makeView {id= !namespace ^ ":" ^ A.id snapshot,snapshot=snapshot,sources=sources,encoding=encoding,uri=uri,
          ordinal=Option.map #ordinal selected,capabilities=capabilities,generation=W.generation workspace}:view
        val all=view :: !views
        val ()=views:=retain (fn view:view=>snapshotBytes(#snapshot view)) all
    in view end
  fun find (Worker {views,...},id)=List.find (fn view:view => #id view=id) (!views)
  fun documentDiagnostics (view:view,{uri,previous}) =
    let val all=diagnostics view
        val direct=List.map #2 (List.filter (fn (source,_) => source=uri) all)
        val inputs=A.inputs (#snapshot view)
        fun ordinal file =
          let fun find (_,[])=length inputs | find (n,(input:A.input)::rest)=if #file input=file then n else find (n+1,rest)
          in find (0,inputs) end
        val active=case activeSource (view,uri) of NONE => length inputs
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
      (case activeSource (view,#uri view) of NONE => [] | SOME source => [source])
  (* Finish each context's response before checking the next one. Keeping
     every snapshot here bypasses the resident cache's eviction budget. *)
  fun workspaceResults (worker,{state,encoding,capabilities,cancelled},collect) =
    let val (workspace,documents)=M.restore state
        val {uris,problems}=RuneLspProjects.enrich (workspace,documents,cancelled)
        val uris=unique (List.map #uri (D.all documents) @ uris)
        val captured=M.capture (workspace,documents)
        fun contextKey (context:W.context)= #build context ^ "#" ^ #target context ^ ":" ^ C.Project.fingerprint (#project context)
        fun group (uri,groups) =
          if cancelled () then raise A.Cancelled else
          case W.select (workspace,documents,uri) of W.Ambiguous _ => groups
          | selected =>
            let val key=case selected of W.Loose => "loose:" ^ uri | W.Selected context => contextKey context | _ => ""
                val ordinal=case selected of W.Selected context => SOME (#ordinal context) | _ => NONE
                fun insert []=[(key,[(uri,ordinal)])]
                  | insert ((prior,items)::rest)=if prior=key then (prior,items @ [(uri,ordinal)])::rest
                    else (prior,items)::insert rest
            in insert groups end
        val groups=List.foldl group [] uris
        val ()=notify(worker,[("phase",V.Bytes "workspace-planned"),("file",V.Bytes ""),
          ("contexts",V.Integer(IntInf.fromInt(length groups)))])
        val contextIndex=ref 0
        fun one (_,[]) = []
          | one (_,(items as (uri,_)::_)) =
              let val ()=contextIndex:= !contextIndex+1
                  val ()=notify(worker,[("phase",V.Bytes "workspace-context-start"),("file",V.Bytes uri),
                    ("contextIndex",V.Integer(IntInf.fromInt(!contextIndex)))])
                  val view=check (worker,{state=captured,uri=uri,encoding=encoding,capabilities=capabilities,cancelled=cancelled})
                  fun result (uri,ordinal)=
                    if cancelled () then raise A.Cancelled else
                    (uri,collect (makeView {id= #id view,snapshot= #snapshot view,sources= #sources view,
                      encoding= #encoding view,uri=uri,ordinal=ordinal,capabilities=capabilities,generation= #generation view}))
              in List.map result items end
        val results=List.concat (List.map one groups)
        val ordered=List.mapPartial (fn uri=>Option.map #2 (List.find (fn (file,_)=>file=uri) results)) uris
    in {results=ordered,problems=problems} end
  fun workspaceDiagnostics (worker,{state,encoding,capabilities,cancelled,previous}) =
    let fun report (view:view)=
          let val prior=case List.find (fn (uri,_) => uri= #uri view) previous of NONE => NONE | SOME (_,id) => SOME id
              val json=documentDiagnostics (view,{uri= #uri view,previous=prior})
              val fields=case json of Json.Object fields => fields | _ => []
              val version=case activeSource (view,#uri view) of
                SOME source => (case #version source of NONE => Json.Null | SOME version => Json.intInf version) | NONE => Json.Null
          in Json.Object (("uri",Json.String (#uri view)) :: ("version",version) :: fields) end
        fun problem ({uri,message}:RuneLspProjects.problem)=Json.Object [("uri",Json.String uri),("version",Json.Null),
          ("kind",Json.String "full"),("items",Json.Array [Json.Object
            [("range",LspProtocol.rangeToJson {start={line=0,character=0},stop={line=0,character=0}}),
             ("severity",Json.int 1),("source",Json.String "rune-build"),("message",Json.String (safe message))]])]
        val {results,problems}=workspaceResults (worker,
          {state=state,encoding=encoding,capabilities=capabilities,cancelled=cancelled},report)
    in Json.Object [("items",Json.Array (results @ List.map problem problems))] end
  fun symbolToken symbol=Hex.fromBytes (Sha256.digest (Json.encode symbol))
  fun workspaceSymbols (worker,{state,encoding,capabilities,cancelled,query}) =
    let val generation=V.integer (V.field (state,"generation"))
        val needle=String.map Char.toLower query
        val resolve=case capability (capabilities,["workspace","symbol","resolveSupport","properties"]) of
          SOME (Json.Array properties) => List.exists (fn value => value=Json.String "location.range") properties | _ => false
        fun viewSymbols (view:view)=case activeSource (view,#uri view) of NONE => []
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
        val {results,...}=workspaceResults (worker,
          {state=state,encoding=encoding,capabilities=capabilities,cancelled=cancelled},viewSymbols)
        val all=unique (List.concat results)
    in Json.Array (List.take (all,Int.min (1000,length all))) end
  fun resolveSymbol (worker,params,state) =
    let val data=J.object (J.required (J.object params,"data"))
        val generation=case Json.toIntInf (J.required (data,"generation")) of SOME generation => generation
          | NONE => raise Fail "invalid symbol generation"
        val ()=if generation=V.integer (V.field (state,"generation")) then () else raise Stale "workspace symbol is stale"
        val view=case find (worker,J.string (J.required (data,"snapshot"))) of SOME view => view | NONE => raise Stale "symbol snapshot has been evicted"
        val uri=J.string (J.required (data,"uri"))
        val ordinal=case J.required (data,"ordinal") of Json.Null => NONE | value => Json.toInt value
        val view=makeView {id= #id view,snapshot= #snapshot view,sources= #sources view,encoding= #encoding view,uri=uri,
          ordinal=ordinal,capabilities= #capabilities view,generation= #generation view}:view
        val source=case activeSource (view,uri) of SOME source => source
          | NONE => raise Fail "symbol source is unavailable"
        val (_,documents)=M.restore state
        val text=case D.snapshot (documents,uri) of SOME snapshot => L.text (#content snapshot)
          | NONE => readFile (#file source,#mode source)
        val ()=if text= #text source then () else raise Stale "workspace symbol source changed"
        val token=J.string (J.required (data,"token"))
        val symbol=case List.find (fn symbol => symbolToken symbol=token) (symbols (view,source)) of SOME symbol => symbol
          | NONE => raise J.Invalid "workspace symbol data is invalid"
        val fields=case symbol of Json.Object fields => fields | _ => []
    in Json.Object (("data",data)::fields) end
  fun sourceOrdinal (view:view,source:source) =
    #ordinal source
  fun scopeAt (view:view,position as {ordinal,offset,path}) : scope =
    let fun matches(item:scopeEntry)= #ordinal item=ordinal andalso #offset item=offset andalso #path item=path
        val cache= #scopes view
    in case List.find matches (!cache) of SOME item=>
        (RuneLspProfile.sample "scope-cache-hit" (#uri view) 0 0 (#bytes item);
         cache:=item::List.filter(fn item=>not(matches item))(!cache);#result item)
      | NONE=>
        let val ()=RuneLspProfile.sample "scope-cache-miss" (#uri view) 0 0 0
            val result=A.completionAt(#snapshot view,position)
            fun strings values=List.foldl(fn (value,n)=>size value+32+n)0 values
            fun candidate (item:A.candidate,n)=n+128+size(#name item)+size(#kind item)+
              (case #detail item of NONE=>0 | SOME text=>size text)+
              List.foldl(fn (args,n)=>32+strings args+n)0(#arguments item)+
              (case #definition item of NONE=>0 | SOME location=>48+size(#file location))
            val bytes=256+strings path+size(#role result)+List.foldl candidate 0 (#candidates result)+
              List.foldl(fn ((label,ty),n)=>64+size label+size ty+n)0(#fields result)
            val maximum=1024*1024
            fun keep([],_,_,all)=List.rev all
              | keep(item::rest,count,total,all)=if count=8 orelse #bytes item>maximum-total then List.rev all
                else keep(rest,count+1,total+ #bytes item,item::all)
            val item={ordinal=ordinal,offset=offset,path=path,result=result,bytes=bytes}:scopeEntry
            val ()=if bytes>maximum then () else cache:=keep(item:: !cache,0,0,[])
        in result end end
  fun completionItems (view:view,source:source,offset) =
    let val selected=sourceOrdinal (view,source)
        fun query path=case selected of NONE => {role="unknown",candidates=[],fields=[]} | SOME ordinal =>
          scopeAt (view,{ordinal=ordinal,offset=offset,path=path})
    in RuneLspCompletion.items {text= #text source,offset=offset,pieces=tokens source,snapshot= #id view,
      uri= #uri source,query=query,range=fn (start,stop) => range (source,#encoding view,start,stop),
      snippets=capability (#capabilities view,["textDocument","completion","completionItem","snippetSupport"])=SOME (Json.Bool true)} end
  fun completionDocumentation (view:view,source:source,offset,name,kind) =
    case sourceOrdinal (view,source) of NONE => NONE | SOME ordinal =>
      let val {path,...}=RuneLspCompletion.prefix (#text source,offset)
          val candidates= #candidates(scopeAt(view,{ordinal=ordinal,offset=offset,path=path}))
      in case List.find (fn candidate:A.candidate => #name candidate=name andalso #kind candidate=kind) candidates of
           NONE => NONE | SOME candidate => Option.mapPartial (fn location => A.documentationAt (#snapshot view,location)) (#definition candidate) end
  fun query (Worker {tokens=history,...},view:view,{method,params}) =
    let val resolving=method="completionItem/resolve" orelse method="inlayHint/resolve" orelse method="documentLink/resolve"
        val document=J.object (J.required (J.object params,if resolving then "data" else "textDocument"))
        val uri=J.string (J.required (document,"uri"))
        val source=case activeSource (view,uri) of
          SOME source => source | NONE => raise Fail "document is not part of this analysis snapshot"
        fun offset ()=case LspProtocol.positionFromJson (J.required (params,"position")) of NONE => raise J.Invalid "invalid semantic position"
          | SOME point => case #index source of NONE => NONE | SOME index => L.offset (index,#encoding view,point)
        fun occurrence ()=Option.mapPartial (fn offset => at (view,source,offset)) (offset ())
        fun target choose=case occurrence () of NONE => Json.Array [] | SOME (occurrence,_) =>
          Json.Array (case Option.mapPartial (fn target => location (view,target)) (choose occurrence) of NONE => [] | SOME target => [target])
        fun semanticTokens () =
          let val occurrences=List.filter (fn occurrence:A.occurrence => #file occurrence= #file source andalso
                owned (view,occurrence) andalso not (#derived occurrence)) (A.occurrences (#snapshot view))
              fun select occurrence=if #isDefinition (occurrence:A.occurrence) then selections (source,occurrence) else
                (case selectionCandidates (source,occurrence) of [span] => [span] | _ => [])
              val candidates=RuneLspTokens.lexical (tokens source) @ RuneLspTokens.semantic (occurrences,select)
          in RuneLspTokens.reply (history,{uri=uri,text= #text source,index= #index source,encoding= #encoding view,
            capabilities= #capabilities view,method=method,params=params,tokens=candidates}) end
    in case method of "textDocument/semanticTokens/full" => semanticTokens ()
       | "textDocument/documentLink" => Json.Null
       | "documentLink/resolve" => raise Stale "document link is not part of a build document"
       | "textDocument/semanticTokens/full/delta" => semanticTokens ()
       | "textDocument/semanticTokens/range" => semanticTokens ()
       | "textDocument/inlayHint" =>
           (case (sourceOrdinal (view,source),RuneLspHints.bounds (params,#index source,#encoding view),#index source) of
              (SOME ordinal,SOME (start,stop),SOME index) =>
                let val hints=A.typeHints (#snapshot view,{ordinal=ordinal,start=start,stop=stop})
                    val ()=if length hints>RuneLspHints.maximum then raise Fail "inlay hint count budget exceeded" else ()
                in RuneLspHints.bounded (List.map (fn hint => RuneLspHints.render {uri=uri,snapshot= #id view,
                  capabilities= #capabilities view,index=index,encoding= #encoding view,hint=hint,resolved=false,clean=safe,
                  revision=getOpt (#revision source,~1),generation= #generation view}) hints) end
            | _ => Json.Null)
       | "inlayHint/resolve" =>
           let val ()=if J.string (J.required (document,"snapshot"))= #id view then () else raise Stale "inlay hint is stale"
               val ()=if uri= #uri view andalso Json.toIntInf (J.required (document,"revision"))= #revision source andalso
                 Json.toIntInf (J.required (document,"generation"))=SOME (#generation view) then () else raise Stale "inlay hint context changed"
               val binding=J.string (J.required (document,"binding"))
               val at=case Json.toInt (J.required (document,"offset")) of SOME at => at | NONE => raise J.Invalid "invalid inlay hint offset"
               val hints=case sourceOrdinal (view,source) of NONE => [] | SOME ordinal =>
                 A.typeHints (#snapshot view,{ordinal=ordinal,start=at,stop=at})
           in case (List.find (fn hint:A.typeHint => #binding hint=binding andalso #position hint=at) hints,#index source) of
                (SOME hint,SOME index) =>
                  let val result=RuneLspHints.render {uri=uri,snapshot= #id view,capabilities= #capabilities view,index=index,
                        encoding= #encoding view,hint=hint,resolved=true,clean=safe,
                        revision=getOpt (#revision source,~1),generation= #generation view}
                      val supplied=LspProtocol.positionFromJson (J.required (params,"position"))
                      val expected=LspProtocol.positionFromJson (J.required (result,"position"))
                      val ()=if isSome supplied andalso supplied=expected andalso
                        Json.member ("label",params)=Json.member ("label",result) then () else raise J.Invalid "inlay hint identity was modified"
                  in result end
              | _ => raise J.Invalid "inlay hint is unavailable" end
       | "textDocument/diagnostic" =>
         documentDiagnostics (view,{uri=uri,previous=case J.member (params,"previousResultId") of
           SOME (Json.String value) => SOME value | NONE => NONE | _ => raise J.Invalid "invalid diagnostic result id"})
       | "textDocument/completion" => Json.Object [("isIncomplete",Json.Bool true),
           ("items",Json.Array (case offset () of NONE => [] | SOME at => completionItems (view,source,at)))]
       | "textDocument/inlineCompletion" =>
           let val context=J.object (J.required (params,"context"))
               val ()=case Json.toInt (J.required (context,"triggerKind")) of SOME 1 => () | SOME 2 => ()
                 | _ => raise J.Invalid "invalid inline completion trigger"
               val selected=case Json.member ("selectedCompletionInfo",context) of NONE => NONE | SOME value =>
                 let val point=J.required (value,"range")
                     val ()=case LspProtocol.rangeFromJson point of NONE => raise J.Invalid "invalid selected completion range" | SOME _ => ()
                 in SOME (point,J.string (J.required (value,"text"))) end
               fun query (ordinal,at,path)=scopeAt (view,{ordinal=ordinal,offset=at,path=path})
               val items=case (sourceOrdinal (view,source),offset ()) of (SOME ordinal,SOME at) =>
                 RuneLspCompletion.inline {text= #text source,offset=at,pieces=tokens source,
                   query=fn path => query (ordinal,at,path),range=fn (start,stop) => range (source,#encoding view,start,stop),selected=selected}
                 | _ => []
           in Json.Object [("items",Json.Array items)] end
       | "textDocument/signatureHelp" =>
           (case (sourceOrdinal (view,source),offset ()) of (SOME ordinal,SOME at) =>
              (case A.signatureAt (#snapshot view,{ordinal=ordinal,offset=at}) of NONE => Json.Null | SOME call =>
                RuneLspCompletion.renderSignature (call,capability (#capabilities view,
                  ["textDocument","signatureHelp","signatureInformation","parameterInformation","labelOffsetSupport"])=SOME (Json.Bool true)))
            | _ => Json.Null)
       | "completionItem/resolve" =>
           let val data=document
               val ()=if J.string (J.required (data,"snapshot"))= #id view then () else raise Stale "completion item is stale"
               val at=case Json.toInt (J.required (data,"offset")) of SOME at => at | NONE => raise J.Invalid "invalid completion offset"
               val name=J.string (J.required (data,"name"))
               val kind=J.string (J.required (data,"kind"))
               val template=Json.member ("template",data)
           in case List.find (fn item => case Json.member ("data",item) of NONE => false | SOME value =>
                 Json.member ("name",value)=SOME (Json.String name) andalso Json.member ("kind",value)=SOME (Json.String kind)
                 andalso Json.member ("template",value)=template)
                (completionItems (view,source,at)) of SOME (item as Json.Object fields) =>
                  (case completionDocumentation (view,source,at,name,kind) of NONE => item | SOME text =>
                    Json.Object (("documentation",Json.String (safe text))::fields))
                | _ => raise J.Invalid "completion item is unavailable" end
       | "textDocument/definition" => target (fn occurrence:A.occurrence => #definition occurrence)
       | "textDocument/declaration" => target (fn occurrence:A.occurrence => #declaration occurrence)
       | "textDocument/documentHighlight" => (case offset () of NONE => Json.Array []
           | SOME offset => highlights (view,source,offset))
       | "textDocument/foldingRange" => RuneLspStructure.folding {text= #text source,syntax= #syntax source,
           pieces=tokens source,index= #index source,encoding= #encoding view,capabilities= #capabilities view}
       | "textDocument/selectionRange" => RuneLspStructure.selection {text= #text source,syntax= #syntax source,
           pieces=tokens source,index= #index source,encoding= #encoding view,positions=J.required (params,"positions")}
       | "textDocument/typeDefinition" =>
           let val constructors=case offset () of NONE => [] | SOME offset => List.concat (List.map #constructors
                 (List.filter (fn fact:A.fact => #file fact= #file source andalso ownedUnit (view,#unit fact) andalso not (#derived fact)
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
             val ty=Option.mapPartial (fn offset => case sourceOrdinal (view,source) of
                SOME ordinal => A.typeAtOccurrence (#snapshot view,{ordinal=ordinal,offset=offset})
              | NONE => NONE) offset
             val binding=Option.mapPartial (fn offset => at (view,source,offset)) offset
             val documentation=case binding of NONE => NONE | SOME (occurrence,_) =>
               Option.mapPartial (fn location => A.documentationAt (#snapshot view,location)) (#definition occurrence)
             val ty=case ty of SOME _ => ty | NONE => case binding of SOME (occurrence,_) =>
               if List.exists (fn kind => kind= #kind occurrence) ["type","structure","signature","functor"]
               then SOME (#kind occurrence ^ " " ^ String.concatWith "." (#path occurrence @ [#name occurrence])) else NONE
               | NONE => NONE
         in case (ty,documentation) of
              (NONE,NONE) => Json.Null | _ =>
                let val formats=case capability (#capabilities view,["textDocument","hover","contentFormat"]) of
                      SOME (Json.Array formats) => formats | _ => []
                    val markdown=case List.find (fn format => format=Json.String "markdown" orelse format=Json.String "plaintext") formats of
                      SOME (Json.String "markdown") => true | _ => false
                    val ty=getOpt (ty,"")
                    fun longest (i,run,best)=if i=size ty then Int.max (run,best) else
                      if String.sub (ty,i)= #"`" then longest (i+1,run+1,best) else longest (i+1,0,Int.max (run,best))
                    val fence=CharVector.tabulate (Int.max (3,longest (0,0,0)+1),fn _ => #"`")
                    val typeText=if ty="" then "" else if markdown then fence ^ "sml\n" ^ safe ty ^ "\n" ^ fence else safe ty
                    val shown=typeText ^ (case documentation of NONE => "" | SOME text =>
                      (if typeText="" then "" else "\n\n") ^ safe text)
                in Json.Object [("contents",Json.Object [("kind",Json.String (if markdown then "markdown" else "plaintext")),
                  ("value",Json.String shown)])] end
         end
       | _ => raise Fail "semantic method is not implemented" end
end

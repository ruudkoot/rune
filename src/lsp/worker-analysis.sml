(* Resident static analysis and frozen views inside the supervised worker. *)
structure RuneLspWorkerAnalysis =
struct
  structure C=CompilerApi
  structure A=C.Analysis
  structure V=RuneLspWorkerWire
  structure M=RuneLspWorkerModel
  structure W=RuneLspWorkspace
  structure D=RuneLspDocuments
  structure U=LspUri
  structure L=LspPosition
  structure J=RuneLspSync
  exception Stale of string
  exception ContextPending of string
  (* A file's text and identity, as long as its stamp stands. *)
  type text={file:string,mode:string,stamp:string,key:string,id:OS.FileSys.file_id option,text:string}
  (* latest: what a kept source's syntax is asked of. keys: a file's key by its
     place among a view's sources. *)
  type context={key:string,compiler:C.session,analysis:A.t,bytes:int ref,
    projects:(int*C.Project.t) list ref,texts:text option array ref,latest:A.snapshot option ref,
    keys:(string*string) option array ref}
  (* syntax: asks the snapshot, which opens a closed unit *)
  type source={file:string,uri:string,text:string,mode:string,ordinal:int option,syntax:unit->C.Syntax.t option,
    slot:int,version:IntInf.int option,revision:IntInf.int option,index:L.t option,
    tokens:(C.Syntax.piece list * C.Syntax.piece vector) option ref}
  type scope={role:string,fields:(string*string) list,candidates:A.candidate list}
  type scopeEntry={ordinal:int,offset:int,path:string list,result:scope,bytes:int}
  type view={id:string,snapshot:A.snapshot,sources:source list,encoding:LspProtocol.encoding,uri:string,ordinal:int option,
    capabilities:Json.value,activeUnit:string option,generation:IntInf.int,scopes:scopeEntry list ref}
  type watched={file:string,mode:string,digest:string option}
  type diagnosticCache={key:string,files:watched list,builds:(string*string list) list,reports:Json.value list,
    trustedRoots:string list,validated:Time.time}
  (* What planning a file's check found, and what says that it holds: the state
     it was given, the stamps of what it read and the text of what of that is
     open. implicit: the build of a file in no build, which no file holds
     (RuneLspImplicit). decided: whether several contexts have been compared. *)
  type planned={serial:int,key:string,stamps:(string*string) list,texts:(string*string) list,
    configuration:W.settings,selection:W.selection,contexts:W.context list,
    implicit:{file:string,text:string} option,decided:bool}
  datatype t=Worker of {contexts:context list ref,views:view list ref,tokens:RuneLspTokens.t,namespace:string ref,
    progress:(V.value->unit) ref,diagnosticCache:diagnosticCache option ref,plans:planned list ref,planSerial:int ref,
    symbolMemo:(string*Json.value list) W.table ref}
  fun new ()=Worker {contexts=ref [],views=ref [],tokens=RuneLspTokens.new (),namespace=ref "local",
    progress=ref(fn _=>()),diagnosticCache=ref NONE,plans=ref [],planSerial=ref 0,symbolMemo=ref (W.table 0)}
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
  fun clearAnalysis (Worker {contexts,views,...}) =
    (List.app (fn context:context => (A.close (#analysis context);C.close (#compiler context))) (!contexts);
     contexts:=[];views:=[])
  fun clear (worker as Worker {tokens,diagnosticCache,plans,symbolMemo,...}) =
    (clearAnalysis worker;diagnosticCache:=NONE;plans:=[];symbolMemo:=W.table 0;RuneLspTokens.clear tokens)
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
  (* the libraries' units this worker's contexts leave for each other: two
     builds over one library check its units once (D26) *)
  val libraryUnits=A.pool ()
  fun context (Worker {contexts,progress,...},{key,lib,flags}) =
    case List.find (fn context:context => #key context=key) (!contexts) of SOME context =>
      (contexts:=context :: List.filter (fn prior:context => #key prior<>key) (!contexts);context)
    | NONE =>
      let val compiler=C.session {lib=lib,flags=flags}
          val context={key=key,compiler=compiler,analysis=A.create (compiler,{context=key}),bytes=ref 0,
            projects=ref [],texts=ref (Array.fromList []),latest=ref NONE,keys=ref (Array.fromList [])}:context
          (* two builds over one library check its units once (D26) *)
          val ()=A.share (#analysis context,SOME libraryUnits)
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
    ("name",V.Bytes (#name context)),("target",V.Bytes (#target context)),("build",V.Bytes (#build context)),
    ("ordinal",V.Integer (IntInf.fromInt (#ordinal context)))]
  fun readFile (file,mode) =
    let val input=BinIO.openIn file
        val bytes=(Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input)
          handle error => (BinIO.closeIn input handle _ => ();raise error)
    in if mode="unicode=latin1" then String.translate (fn byte => Utf8.encode (Char.ord byte)) bytes else bytes end
  (* A file's stamp says that it is as it was, until the client's file events
     can: its time, which is in whole seconds, and its size. So a stamp is
     worth keeping only of a file older than a second or two when it was read:
     git's rule for a racy index entry. *)
  fun stampOf file=(Time.toString (OS.FileSys.modTime file) ^ ":" ^ Position.toString (OS.FileSys.fileSize file))
    handle OS.SysErr _ => "absent"
  fun settled file=(Time.< (Time.+ (OS.FileSys.modTime file,Time.fromSeconds 3),Time.now ())) handle OS.SysErr _ => true
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
    let val parsed=case #syntax source () of SOME syntax => syntax | NONE =>
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
  (* the occurrences and facts of the view's unit: a query needs no other's *)
  fun ownOccurrences (view:view)=case #activeUnit view of NONE => [] | SOME unit => A.occurrencesIn (#snapshot view,unit)
  fun ownFacts (view:view)=case #activeUnit view of NONE => [] | SOME unit => A.factsIn (#snapshot view,unit)
  fun at (view:view,source:source,offset) =
    let val candidates=List.concat (List.map (fn occurrence:A.occurrence =>
          if #file occurrence<> #file source orelse
             offset< #start occurrence orelse offset>= #stop occurrence then [] else
            List.mapPartial (fn (start,stop) => if start<=offset andalso offset<stop then SOME (occurrence,(start,stop)) else NONE)
              (selections (source,occurrence))) (ownOccurrences view))
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
            if #file occurrence<> #file source orelse
               #derived occurrence orelse #binding occurrence<>SOME binding then (count,kept)
            else List.foldl (fn ((start,stop),(count,kept)) =>
              if count=8192 then raise Fail "document highlights exceed the supported response budget"
              else (count+1,(start,stop,if #kind occurrence="value" andalso not (#isDefinition occurrence) then 2 else 1)::kept))
              (count,kept) (selections (source,occurrence))
          val (_,ranges)=List.foldl collect (0,[]) (ownOccurrences view)
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
  fun symbolNodes (view:view,source:source) =
    let val definitions=List.filter (fn occurrence:A.occurrence => #file occurrence= #file source andalso #isDefinition occurrence
          andalso not (#derived occurrence)) (ownOccurrences view)
        fun entry (occurrence:A.occurrence)=case selections(source,occurrence) of []=>NONE | (start,stop)::_=>
          SOME{identity=getOpt(#binding occurrence,"span:" ^ Int.toString start),name= #name occurrence,
            category= #kind occurrence,start=start,stop=stop}:RuneLspOutline.entry option
        val facts=List.filter(fn fact:A.fact=> #file fact= #file source)(ownFacts view)
    in RuneLspOutline.prepare{entries=List.mapPartial entry definitions,events=RuneLspStructure.events(#syntax source ()),
      pieces=tokens source,facts=facts} end
  fun symbols (view:view,source:source)=RuneLspOutline.flat(symbolNodes(view,source),#uri source,
    fn(start,stop)=>range(source,#encoding view,start,stop))
  fun documentSymbols (view:view,source:source)=
    let val nodes=symbolNodes(view,source)
        val encode=fn(start,stop)=>range(source,#encoding view,start,stop)
    in Json.Array(if RuneLspStructure.member(#capabilities view,["textDocument","documentSymbol","hierarchicalDocumentSymbolSupport"])=SOME(Json.Bool true)
      then RuneLspOutline.nested(nodes,encode) else RuneLspOutline.flat(nodes,#uri source,encode)) end
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
  fun planKey (state,uri,documents)=V.encode (V.Array [V.Bytes uri,
    V.Array (List.map (fn snapshot:D.snapshot => V.Bytes (#uri snapshot)) (D.all documents)),
    V.Object (List.filter (fn (name,_) => not (List.exists (fn other => other=name) ["documents","generation","inputGeneration"])) (V.object state))])
  fun buildText (snapshot:D.snapshot)=OS.Path.file (#uri snapshot)="rune.workspace"
    orelse String.isSuffix ".build" (#uri snapshot)
  (* The implicit library of a file in no build (D26), over its directory, with
     the names it uses looked up in its workspace: the workspace's root, or
     else the client's folder that holds it, or else its directory *)
  fun implicitFor (workspace as W.Workspace {platform,lib,roots,...},documents,uri) =
    case (U.native (platform,U.parse uri),D.snapshot (documents,uri)) of
      (SOME {path,key},SOME snapshot) =>
        let val found=W.rootFileIn (platform,documents) path handle C.Failed _ => NONE
            val folder=List.find (fn root => case W.nativeKey platform root of SOME root => W.below (root,key) | NONE => false) (!roots)
            val root=case (found,folder) of (SOME found,_) => C.Workspace.root found
              | (NONE,SOME folder) => W.filePath platform folder
              | (NONE,NONE) => W.directory platform path
            val {build,text,read,...}=RuneLspImplicit.context {platform=platform,
              lib=getOpt (#libraryRoot (W.configurationFor (workspace,uri)),lib),
              libraryRoots=case found of SOME found => C.Workspace.libraryRoots found | NONE => [],
              root=root,file=path,text=L.text (#content snapshot)}
        in Option.map (fn context => (context,{file=build,text=text},read))
             (W.implicitContext (workspace,documents,uri,{build=build,text=text})) end
    | _ => NONE
  (* the plan of a file: what enrich and the choice of a context found, which
     hold while nothing they read has changed, whatever the file's text *)
  fun plan (worker as Worker {plans,planSerial,...},state,workspace as W.Workspace {platform,...},documents,uri,cancelled) =
    let val key=planKey (state,uri,documents)
        fun textOf (snapshot:D.snapshot)=L.text (#content snapshot)
        fun open' (document,text)=case D.snapshot (documents,document) of SOME snapshot => textOf snapshot=text | NONE => false
        fun holds (memo:planned)= #key memo=key andalso List.all open' (#texts memo)
          andalso List.all (fn snapshot => not (buildText snapshot) orelse
            List.exists (fn (document,_) => document= #uri snapshot) (#texts memo)) (D.all documents)
          andalso List.all (fn (file,stamp) => stampOf file=stamp) (#stamps memo)
    in case List.find holds (!plans) of SOME memo => (plans:=memo::List.filter (fn other:planned => #serial other<> #serial memo) (!plans);memo)
     | NONE =>
       let val ()=notify (worker,[("phase",V.Bytes "planning"),("file",V.Bytes uri)])
           val {read={files,sources,directories},...}=RuneLspProjects.enrich (workspace,documents,cancelled)
           val configuration=W.configurationFor (workspace,uri)
           val (selection,contexts)=W.resolve (workspace,documents,uri)
           (* a file in no build has the implicit library of its directory *)
           val (selection,contexts,implicit,implicitRead)=case selection of
               W.Loose => (case implicitFor (workspace,documents,uri) of
                   SOME (context,overlay,read) => (W.Selected context,[context],SOME overlay,read)
                 | NONE => (W.Loose,[],NONE,[]))
             | _ => (selection,contexts,NONE,[])
           fun unique items=List.foldl (fn (item,all) => if List.exists (fn other => other=item) all then all else item::all) [] items
           val own=case U.native (platform,U.parse uri) of NONE => [] | SOME {path,...} => W.directories (workspace,path)
           val read=unique (files @ sources @ directories @ own @ implicitRead @ List.concat (List.map (fn context:W.context =>
             List.filter (fn file => not (isSome implicit) orelse file<> #file (valOf implicit))
               (List.map #file (C.Project.inputs (#project context)))) contexts))
           fun native (snapshot:D.snapshot)=Option.map #path (U.native (platform,U.parse (#uri snapshot)))
           val texts=List.mapPartial (fn snapshot:D.snapshot =>
             if buildText snapshot orelse (case native snapshot of NONE => false | SOME path =>
                  List.exists (fn file => W.sameFile platform (file,path)) sources)
             then SOME (#uri snapshot,textOf snapshot) else NONE) (D.all documents)
           val () =planSerial:= !planSerial+1
           val memo={serial= !planSerial,key=key,stamps=List.map (fn file => (file,stampOf file)) read,texts=texts,
             configuration=configuration,selection=selection,contexts=contexts,implicit=implicit,decided=false}:planned
           val all=memo:: !plans
       in plans:=(if List.all settled read then List.take (all,Int.min (8,length all)) else !plans);memo end end
  (* a check of a file in the context selected, or on its own *)
  fun checkIn (worker as Worker {contexts,views,namespace,...},{state,uri,encoding,capabilities,cancelled},
               workspace as W.Workspace {platform,lib,...},documents,planned as {configuration,...}:planned,selected:W.context option) =
    let val ()=notify(worker,[("phase",V.Bytes "project-selected"),("file",V.Bytes(case selected of NONE=>uri | SOME context=> #build context)),
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
          | SOME {path,...} => SOME {file=path,text=L.text (#content snapshot)}) (D.all documents) @
          (case #implicit planned of SOME overlay => [overlay] | NONE => [])
        (* each open document once, so that an input costs a look at each and
           not a stat of it *)
        val opened=List.map (fn snapshot:D.snapshot => case native (#uri snapshot) of
            NONE => (snapshot,NONE,NONE)
          | SOME {path,...} => (snapshot,SOME (W.pathKey platform path),SOME (OS.FileSys.fileId path) handle OS.SysErr _ => NONE))
          (D.all documents)
        fun fileIdOf file=SOME (OS.FileSys.fileId file) handle OS.SysErr _ => NONE
        fun fit (cell,at)=if at<Array.length (!cell) then () else
          let val old= !cell
          in cell:=Array.tabulate (Int.max (at+1,2*Array.length old),fn i => if i<Array.length old then Array.sub (old,i) else NONE) end
        (* a closed input's text, as long as its stamp stands *)
        fun remembered (file,mode,ordinal)=
          let val cell= #texts context
              val ()=fit (cell,ordinal)
              val stamp=stampOf file
              fun fresh ()=
                let val memo={file=file,mode=mode,stamp=stamp,key=W.pathKey platform file,id=fileIdOf file,text=readFile (file,mode)}:text
                in Array.update (!cell,ordinal,if settled file then SOME memo else NONE);memo end
          in case Array.sub (!cell,ordinal) of
               SOME (memo:text) => if #file memo=file andalso #mode memo=mode andalso #stamp memo=stamp then memo else fresh ()
             | NONE => fresh () end
        fun matching (file,key,id)=
          let fun same (snapshot:D.snapshot,documentKey,documentId)=case documentKey of NONE => file= #uri snapshot
                | SOME other => other=key orelse (case (id,documentId) of
                    (SOME a,SOME b) => OS.FileSys.compare (a,b)=EQUAL | _ => false)
          in List.map #1 (List.filter same opened) end
        fun overlayOf (file,key,id)=case matching (file,key,id) of [] => NONE
          | first :: rest => if List.exists (fn snapshot => L.text (#content snapshot)<>L.text (#content first)) rest
              then raise Fail "conflicting source overlays refer to one file" else SOME first
        (* what a file is known by, kept with its place among the sources *)
        fun identified (file,slot)=
          let val cell= #keys context
              val ()=fit (cell,slot)
          in case Array.sub (!cell,slot) of
               SOME (known,key) => if known=file then key else fresh (file,slot,cell)
             | NONE => fresh (file,slot,cell) end
        and fresh (file,slot,cell)=let val key=W.pathKey platform file in Array.update (!cell,slot,SOME (file,key));key end
        fun input (source:C.Project.source):A.input =
          let val disk=(SOME (remembered (#file source,#mode source,#ordinal source))) handle IO.Io _ => NONE | OS.SysErr _ => NONE
              val opened=case disk of SOME memo => overlayOf (#file source,#key memo,#id memo)
                | NONE => overlayOf (#file source,W.pathKey platform (#file source),fileIdOf (#file source))
          in {file= #file source,text=case (opened,disk) of (SOME snapshot,_) => L.text (#content snapshot)
                | (NONE,SOME memo) => #text memo | (NONE,NONE) => readFile (#file source,#mode source),
              mode= #mode source,annotations= #annotations source,
              revision=case opened of NONE => "disk" | SOME snapshot => IntInf.toString (#revision snapshot)} end
        val project=case selected of NONE => NONE | SOME selected =>
          (case List.find (fn (serial,_) => serial= #serial planned) (!(#projects context)) of
             SOME (_,project) => SOME project
           | NONE =>
               let val project=C.Project.read (#compiler context,
                     {file=W.filePath platform (#build selected),workspace=W.rootFileIn (platform,documents) (W.filePath platform (#build selected)),
                      variables=variables,overlays=overlays,windows=platform=U.Windows})
                   val all=(#serial planned,project):: !(#projects context)
               in #projects context:=List.take (all,Int.min (4,length all));SOME project end)
        val inputs=case project of SOME project => List.map input (C.Project.sources project)
          | NONE =>
              let val snapshot=case D.snapshot (documents,uri) of SOME snapshot => snapshot | NONE => raise Fail "document is not open"
                  val file=case native uri of NONE => uri | SOME {path,...} => path
              in [{file=file,text=L.text (#content snapshot),mode="",annotations=[],revision=IntInf.toString (#revision snapshot)}:A.input] end
        val ()=if inputBytes inputs+List.foldl(fn (prior:context,n)=>
              if #key prior=key then n else !(#bytes prior)+n)0(!contexts)<=retainedSourceBudget then () else
          (List.app release (List.filter(fn prior:context=> #key prior<>key)(!contexts));
           contexts:=[context];views:=List.filter(fn view:view=>A.context(#snapshot view)=key)(!views))
        val ()=RuneLspProfile.sample "check-inputs" uri 0 0 0
        (* what the editor has open keeps what a question needs; the rest closes *)
        val ()=A.focus (#analysis context,SOME (List.mapPartial (fn input:A.input =>
          if #revision input="disk" then NONE else SOME (#file input)) inputs))
        val snapshot=A.check (#analysis context,{project=project,inputs=inputs,cancelled=cancelled})
        val ()=RuneLspProfile.sample "check-analysed" uri 0 0 0
        val ()= #latest context:=SOME snapshot
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
          let val memo=Option.mapPartial (fn at => if at<Array.length (!(#texts context))
                  then Array.sub (!(#texts context),at) else NONE) ordinal
              val (key,id)=case memo of
                  SOME memo => if #file memo= #file input then (#key memo,#id memo) else (identified (#file input,slot),NONE)
                | NONE => (identified (#file input,slot),NONE)
              val aliases=matching (#file input,key,id)
              val aliases=case List.find (fn snapshot:D.snapshot => #uri snapshot=uri) aliases of NONE => aliases
                | SOME current => current :: List.filter (fn snapshot:D.snapshot => #uri snapshot<>uri) aliases
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
              val latest= #latest context
              fun syntax ()=case (ordinal,!latest) of (SOME ordinal,SOME snapshot) => A.syntaxAt (snapshot,{ordinal=ordinal}) | _ => NONE
          in case (prior,aliases) of
               (SOME source,[]) => if isSome (#version source) orelse #ordinal source<>ordinal then
                   [{file= #file input,uri= #uri source,text= #text input,mode= #mode input,ordinal=ordinal,syntax=syntax,slot=slot,
                     version=NONE,revision=NONE,index=index,tokens=pieces}:source]
                 else [source]
             | _ =>
               let val uris=if not (null aliases) then
                     List.map (fn snapshot:D.snapshot => (#uri snapshot,SOME (#version snapshot),SOME (#revision snapshot))) aliases
                   else [(U.original (U.fromPath (platform,OS.FileSys.fullPath (#file input))),NONE,NONE)]
               in List.map (fn (uri,version,revision) => {file= #file input,uri=uri,text= #text input,mode= #mode input,ordinal=ordinal,
                    syntax=syntax,slot=slot,version=version,revision=revision,index=index,tokens=pieces}:source) uris end end
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
        val ()=RuneLspProfile.sample "check-viewed" uri 0 0 0
    in view end
  (* What a file's unit means where a view checked it: each occurrence, where
     it is and what it resolves to, by paths whole and never by a printed
     type, which depends on what was selected (E22); and its errors, if it
     failed. NONE where the check stopped before the unit. *)
  fun meaning (platform,view:view) =
    case #activeUnit view of NONE => NONE | SOME unit =>
      if not (isSome (A.versionOf (#snapshot view,unit))) then NONE else
      let fun place NONE="-"
            | place (SOME ({file,start,stop}:A.location))=W.pathKey platform file ^ ":" ^ Int.toString start ^ ":" ^ Int.toString stop
          val file=case activeSource (view,#uri view) of SOME source => #file source | NONE => ""
          val uses=List.map (fn occurrence:A.occurrence => String.concatWith "|" [#kind occurrence,
            String.concatWith "." (#path occurrence @ [#name occurrence]),Int.toString (#start occurrence),Int.toString (#stop occurrence),
            place (#definition occurrence),place (#declaration occurrence),Bool.toString (#isDefinition occurrence)])
            (ownOccurrences view)
          val errors=List.mapPartial (fn diagnostic:C.diagnostic => if #file diagnostic<>file then NONE else
            SOME (String.concatWith "|" [Int.toString (#start diagnostic),Int.toString (#stop diagnostic),#message diagnostic]))
            (A.diagnostics (#snapshot view))
          fun insert (x,[])=[x] | insert (x,y::rest)=if x<=y then x::y::rest else y::insert (x,rest)
      in SOME (List.foldl insert [] uses @ errors) end
  (* Several contexts (D26): those that do not reach the file go, and a choice
     is asked for only where those left differ in what the file's names
     resolve to. Each is checked, the first last, so that it is the one kept;
     the answer holds as long as the plan does. *)
  fun decide (worker as Worker {plans,...},args as {cancelled,...},workspace as W.Workspace {platform,...},documents,planned:planned) =
    case #selection planned of
      W.Ambiguous contexts => if #decided planned then planned else
        let fun meaningIn context=(meaning (platform,checkIn (worker,args,workspace,documents,planned,SOME context)))
              handle C.Failed _ => NONE | Fail _ => NONE | IO.Io _ => NONE | OS.SysErr _ => NONE
            val outcomes=List.rev (List.map (fn context => (context,meaningIn context)) (List.rev contexts))
            val reaching=List.filter (isSome o #2) outcomes
            val (selection,kept)=case reaching of
                [] => (W.Selected (hd contexts),contexts)
              | (first,found)::rest =>
                  if List.all (fn (_,other) => other=found) rest then (W.Selected first,List.map #1 reaching)
                  else (W.Ambiguous (List.map #1 reaching),List.map #1 reaching)
            val memo={serial= #serial planned,key= #key planned,stamps= #stamps planned,texts= #texts planned,
              configuration= #configuration planned,selection=selection,contexts=kept,implicit= #implicit planned,decided=true}:planned
            val ()=notify (worker,[("phase",V.Bytes "contexts-compared"),("file",V.Bytes (#uri args)),
              ("contexts",V.Integer (IntInf.fromInt (length contexts))),("reaching",V.Integer (IntInf.fromInt (length reaching)))])
        in plans:=List.map (fn other:planned => if #serial other= #serial memo then memo else other) (!plans);memo end
    | _ => planned
  fun resolved (worker,args as {state,uri,cancelled,...},workspace,documents)=
    decide (worker,args,workspace,documents,plan (worker,state,workspace,documents,uri,cancelled))
  fun check (worker,args as {state,uri,...}) =
    let val ()=RuneLspProfile.sample "check-begin" uri 0 0 0
        val (workspace,documents)=M.restore state
        val ()=RuneLspProfile.sample "check-restored" uri 0 0 0
        val planned=resolved (worker,args,workspace,documents)
        val ()=RuneLspProfile.sample "check-planned" uri 0 0 0
        val selected=case #selection planned of W.Ambiguous _ => raise ContextPending "select a build context before analysis"
          | W.Selected context => SOME context | W.Loose => NONE
    in checkIn (worker,args,workspace,documents,planned,selected) end
  fun discover (worker,state,uri,cancelled)=
    let val (workspace,documents)=M.restore state
        val {selection,contexts,...}:planned=resolved (worker,{state=state,uri=uri,encoding=LspProtocol.Utf16,
          capabilities=Json.Object [],cancelled=cancelled},workspace,documents)
        val all=("contexts",V.Array (List.map descriptor contexts))
    in case selection of W.Loose => V.Object [("kind",V.Bytes "loose"),all]
       | W.Selected context => V.Object [("kind",V.Bytes "selected"),("context",descriptor context),all]
       | W.Ambiguous _ => V.Object [("kind",V.Bytes "ambiguous"),all] end
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
  fun workspaceResults (worker,{state,encoding,capabilities,cancelled},transient,watch,collect) =
    let val (workspace as W.Workspace {platform,...},documents)=M.restore state
        val {uris,problems,...}=RuneLspProjects.enrich (workspace,documents,cancelled)
        (* Closed-project diagnostics do not acquire extra contexts as editor
           tabs open. Open documents have their own diagnostic provider. *)
        val uris=unique ((if transient then [] else List.map #uri (D.all documents)) @ uris)
        val captured=M.capture (workspace,documents)
        fun contextKey (context:W.context)= #build context ^ "#" ^ #target context ^ ":" ^ C.Project.fingerprint (#project context)
        (* a sweep covers every file, and asks no one to choose: a file with
           several contexts is checked in the first (D26) *)
        fun group (uri,groups) =
          if cancelled () then raise A.Cancelled else
            let val selected=case W.select (workspace,documents,uri) of W.Selected context => SOME context
                  | W.Ambiguous (first::_) => SOME first | _ => NONE
                val key=case selected of NONE => "loose:" ^ uri | SOME context => contextKey context
                val ()=case selected of SOME context=>List.app(fn input:C.Project.input=>
                  watch(#file input,#mode input,#text input))(C.Project.inputs(#project context)) | NONE=>()
                val ordinal=Option.map #ordinal selected
                fun insert []=[(key,(selected,[(uri,ordinal)]))]
                  | insert ((prior,(context,items))::rest)=if prior=key then (prior,(context,items @ [(uri,ordinal)]))::rest
                    else (prior,(context,items))::insert rest
            in insert groups end
        val groups=List.foldl group [] uris
        val ()=notify(worker,[("phase",V.Bytes "workspace-planned"),("file",V.Bytes ""),
          ("contexts",V.Integer(IntInf.fromInt(length groups)))])
        val contextIndex=ref 0
        fun one (_,(_,[])) = []
          | one (_,(selected,items as (uri,_)::_)) =
              let val ()=if transient then clearAnalysis worker else ()
                  val ()=contextIndex:= !contextIndex+1
                  val ()=notify(worker,[("phase",V.Bytes "workspace-context-start"),("file",V.Bytes uri),
                    ("contextIndex",V.Integer(IntInf.fromInt(!contextIndex)))])
                  val args={state=captured,uri=uri,encoding=encoding,capabilities=capabilities,cancelled=cancelled}
                  val view=case selected of NONE => check (worker,args) | SOME context =>
                    let val (workspace,documents)=M.restore captured
                    in checkIn (worker,args,workspace,documents,plan (worker,captured,workspace,documents,uri,cancelled),SOME context) end
                  val ()=List.app(fn source:source=>watch(#file source,#mode source,#text source))(#sources view)
                  fun result (uri,ordinal)=
                    if cancelled () then raise A.Cancelled else
                    (uri,collect (makeView {id= #id view,snapshot= #snapshot view,sources= #sources view,
                      encoding= #encoding view,uri=uri,ordinal=ordinal,capabilities=capabilities,generation= #generation view}))
                  val results=List.map result items
                  val ()=if transient then clearAnalysis worker else ()
              in results end
        val results=List.concat (List.map one groups)
        val ordered=List.mapPartial (fn uri=>Option.map #2 (List.find (fn (file,_)=>file=uri) results)) uris
    in {results=ordered,problems=problems} end
  fun workspaceDiagnostics (worker as Worker {diagnosticCache,...},{state,encoding,capabilities,cancelled,previous}) =
    let val (workspace as W.Workspace {platform,choices,...},documents)=M.restore state
        val watchedRoots=(M.unstrings(V.field(state,"watchedRoots")) handle V.Invalid _=>[])
        val ()=choices:=[]
        val state=M.capture(workspace,documents)
        val semanticState=V.Object(List.filter(fn (name,_)=>name<>"documents" andalso name<>"generation")(V.object state))
        val hashes=ref 0 val skipped=ref 0
        fun hash text=Hex.fromBytes(Sha256.digest text)
        val key=hash(V.encode(V.Array[semanticState,V.Bytes(LspProtocol.encodingName encoding),V.json capabilities]))
        fun disk (file,mode)=let val text=readFile(file,mode) in hashes:= !hashes+1;SOME(hash text) end
          handle OS.SysErr _=>NONE | IO.Io _=>NONE
        fun effective (file,mode)=
          let val opened=List.filter(fn snapshot:D.snapshot=>case U.native(platform,U.parse(#uri snapshot)) of
                NONE=>false | SOME {path,...}=>W.sameFile platform(file,path))(D.all documents)
          in case opened of []=>disk(file,mode) | first::rest=>
            if List.all(fn snapshot=>L.text(#content snapshot)=L.text(#content first))rest
            then SOME(hash(L.text(#content first))) else NONE end
        fun builds()=List.mapPartial(fn uri=>case U.native(platform,U.parse uri) of NONE=>NONE
          | SOME {path,...}=>SOME(path,W.buildFiles platform path))(W.roots workspace)
        fun valid (cached:diagnosticCache)=
          let val periodic=Time.>=(Time.-(Time.now(),#validated cached),Time.fromSeconds 60)
              fun covered file=not periodic andalso
                List.exists(fn suffix=>String.isSuffix suffix file)[".sml",".sig",".build"] andalso
                List.exists(fn root=>List.exists(fn old=>old=root)(#trustedRoots cached) andalso
                  (case W.nativeKey platform root of NONE=>false | SOME key=>W.below(key,W.pathKey platform file)))watchedRoots
              val ok= #key cached=key andalso #builds cached=builds() andalso
                List.all(fn {file,mode,digest}:watched=>if cancelled() then raise A.Cancelled
                  else if covered file then (skipped:= !skipped+1;true) else effective(file,mode)=digest)(#files cached)
              val ()=RuneLspProfile.sample "workspace-cache-validate" "" (!hashes) (!skipped) (length(#files cached))
              val ()=if ok then diagnosticCache:=SOME{key=key,files= #files cached,builds= #builds cached,reports= #reports cached,
                trustedRoots=watchedRoots,validated=if periodic then Time.now() else #validated cached} else ()
          in ok end
        val files=ref []:watched list ref
        val consistent=ref true
        fun remember (file,mode,digest)=case List.find(fn prior:watched=> #file prior=file andalso #mode prior=mode)(!files) of
          SOME prior=>if #digest prior=digest then () else consistent:=false
        | NONE=>files:={file=file,mode=mode,digest=digest}:: !files
        (* the library build of each directory above a file, there or
           not, whose index says what the file is to the libraries *)
        fun librariesAbove file=
          let val dir=OS.Path.dir file
              val build=OS.Path.concat(dir,"library.build")
              val ()=if List.exists(fn prior:watched=> #file prior=build)(!files) then ()
                else remember(build,"",disk(build,""))
          in if dir=file orelse dir="" then () else librariesAbove dir end
        fun watch(file,mode,text)=(remember(file,mode,SOME(hash text));librariesAbove file)
        fun report (view:view)=
          let val json=documentDiagnostics (view,{uri= #uri view,previous=NONE})
              val fields=case json of Json.Object fields => fields | _ => []
              val version=case activeSource (view,#uri view) of
                SOME source => (case #version source of NONE => Json.Null | SOME version => Json.intInf version) | NONE => Json.Null
          in Json.Object (("uri",Json.String (#uri view)) :: ("version",version) :: fields) end
        fun problem ({uri,message}:RuneLspProjects.problem)=Json.Object [("uri",Json.String uri),("version",Json.Null),
          ("kind",Json.String "full"),("items",Json.Array [Json.Object
            [("range",LspProtocol.rangeToJson {start={line=0,character=0},stop={line=0,character=0}}),
             ("severity",Json.int 1),("source",Json.String "rune-build"),("message",Json.String (safe message))]])]
        fun fresh()=
          let val initialBuilds=builds()
              val ()=diagnosticCache:=NONE
              val {results,problems}=workspaceResults (worker,
                {state=state,encoding=encoding,capabilities=capabilities,cancelled=cancelled},true,watch,report)
              val reports=results @ List.map problem problems
              val ()=if !consistent andalso null problems andalso size(Json.encode(Json.Array reports))<=4*1024*1024 then
                diagnosticCache:=SOME{key=key,files= !files,builds=initialBuilds,reports=reports,
                  trustedRoots=watchedRoots,validated=Time.now()} else ()
          in reports end handle error=>(clearAnalysis worker;raise error)
        val reports=case !diagnosticCache of SOME cached=>if valid cached then
            (RuneLspProfile.sample "workspace-diagnostics-cache-hit" "" 0 0 (length(#reports cached));#reports cached) else fresh()
          | NONE=>fresh()
        fun version report=case (report,Json.member("uri",report)) of (Json.Object fields,SOME(Json.String uri))=>
          Json.Object(("version",case D.snapshot(documents,uri) of NONE=>Json.Null | SOME snapshot=>Json.intInf(#version snapshot))::
            List.filter(fn (name,_)=>name<>"version")fields) | _=>report
        fun reuse original=let val report=version original in case (Json.member("uri",report),Json.member("resultId",report)) of
          (SOME(Json.String uri),SOME(Json.String id))=>
            if not(List.exists(fn (file,value)=>file=uri andalso value=id)previous) then report else
              (case report of Json.Object fields=>Json.Object(("kind",Json.String "unchanged")::
                List.filter(fn (name,_)=>name<>"kind" andalso name<>"items")fields) | _=>report)
          | _=>report end
    in Json.Object [("items",Json.Array(List.map reuse reports))] end
  fun symbolToken symbol=Hex.fromBytes (Sha256.digest (Json.encode symbol))
  fun workspaceSymbols (worker as Worker {symbolMemo,...},{state,encoding,capabilities,cancelled,query}) =
    let val generation=V.integer (V.field (state,"generation"))
        (* A closed unit opens to say its symbols: once, while it stays as it is. *)
        val remembered=ref []
        fun symbolsOf (view:view,source:source)=
          case Option.mapPartial (fn unit => A.versionOf (#snapshot view,unit)) (#activeUnit view) of
            NONE => symbols (view,source)
          | SOME version =>
              let val found=case W.lookup (!symbolMemo,#uri source) of
                      SOME (known,all) => if known=version then SOME all else NONE | NONE => NONE
                  val all=case found of SOME all => all | NONE => symbols (view,source)
              in remembered:=(#uri source,(version,all)):: !remembered;all end
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
              (symbolsOf (view,source))
        val {results,...}=workspaceResults (worker,
          {state=state,encoding=encoding,capabilities=capabilities,cancelled=cancelled},false,fn _=>(),viewSymbols)
        val memo=W.table (length (!remembered))
        val ()=List.app (fn (uri,item) => W.add (memo,uri,item)) (!remembered)
        val ()=symbolMemo:=memo
        (* the first thousand that differ, each looked at once *)
        val seen=W.table 1000
        fun first (0,_,kept)=List.rev kept
          | first (_,[],kept)=List.rev kept
          | first (left,symbol::rest,kept)=
              let val key=Json.encode symbol
              in if isSome (W.lookup (seen,key)) then first (left,rest,kept)
                 else (W.add (seen,key,());first (left-1,rest,symbol::kept)) end
    in Json.Array (first (1000,List.concat results,[])) end
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
                not (#derived occurrence)) (ownOccurrences view)
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
       | "textDocument/foldingRange" => RuneLspStructure.folding {text= #text source,syntax= #syntax source (),
           pieces=tokens source,index= #index source,encoding= #encoding view,capabilities= #capabilities view}
       | "textDocument/selectionRange" => RuneLspStructure.selection {text= #text source,syntax= #syntax source (),
           pieces=tokens source,index= #index source,encoding= #encoding view,positions=J.required (params,"positions")}
       | "textDocument/typeDefinition" =>
           let val constructors=case offset () of NONE => [] | SOME offset => List.concat (List.map #constructors
                 (List.filter (fn fact:A.fact => #file fact= #file source andalso not (#derived fact)
                   andalso #start fact<=offset andalso offset< #stop fact) (ownFacts view)))
               val definitions=List.filter (fn definition:A.typeDefinition => List.exists (fn id => id= #id definition) constructors) (A.types (#snapshot view))
           in Json.Array (unique (List.mapPartial (fn definition:A.typeDefinition =>
                Option.mapPartial (fn target => location (view,target)) (#definition definition)) definitions)) end
       | "textDocument/implementation" =>
           let val declaration=case occurrence () of NONE => NONE | SOME (occurrence,_) => #declaration occurrence
               val implementations=case declaration of NONE => [] | SOME declared => A.implementationsOf (#snapshot view,declared)
               val typeImplementations=List.filter (fn definition:A.typeDefinition => #declaration definition=declaration
                 andalso isSome declaration andalso #implementation definition<>declaration) (A.types (#snapshot view))
           in Json.Array (unique (List.mapPartial (fn occurrence:A.occurrence =>
                Option.mapPartial (fn target => location (view,target)) (#definition occurrence)) implementations @
                List.mapPartial (fn definition:A.typeDefinition => Option.mapPartial (fn target => location (view,target))
                  (#implementation definition)) typeImplementations)) end
       | "textDocument/documentSymbol" => documentSymbols (view,source)
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

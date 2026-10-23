(* Build documents use compiler project queries, rather than pretending to be
   Standard ML semantic snapshots. All operations are static and read-only. *)
structure RuneLspBuild =
struct
  structure C=RuneCompiler
  structure D=RuneLspDocuments
  structure W=RuneLspWorkspace
  structure M=RuneLspWorkerModel
  structure V=RuneLspWorkerWire
  structure J=RuneLspSync
  structure U=LspUri
  structure L=LspPosition
  structure E=RuneLspWorkerAnalysis
  fun linkClient capabilities=case E.capability (capabilities,["textDocument","documentLink"]) of
    SOME (Json.Object _) => true | _ => false
  fun linkMethod method=method="textDocument/documentLink" orelse method="documentLink/resolve"
  fun isDocument (platform,snapshot:D.snapshot)=
    List.exists (fn name => name= #languageId snapshot) ["rune-build","runebuild"] orelse
    ((case U.native (platform,U.parse (#uri snapshot)) of NONE => false | SOME {path,...} =>
       String.isSuffix ".build" (String.map Char.toLower path)) handle U.Invalid => false)
  fun query (worker,{state,uri,method,params,encoding,capabilities}) =
    let val (workspace as W.Workspace {platform,lib,...},documents)=M.restore state
        val snapshot=case D.snapshot (documents,uri) of SOME snapshot => snapshot | NONE => raise J.Invalid "build document is not open"
        val ()=if D.healthy (documents,uri) then () else raise J.Invalid "build document synchronization requires a replacement"
        val native=Option.map #path (U.native (platform,U.parse uri))
        val file=getOpt (native,uri)
        val text=L.text (#content snapshot)
        val source={file=file,uri=uri,text=text,mode="ascii",ordinal=NONE,syntax=NONE,version=SOME (#version snapshot),
          revision=SOME (#revision snapshot),index=SOME (#content snapshot),tokens=ref NONE}:E.source
        val configuration=W.configurationFor (workspace,uri)
        fun matches (target:W.target)=case native of NONE => false | SOME path =>
          W.sameFile platform (path,W.filePath platform (#build target))
        val targets=List.filter matches (#targets configuration)
        val selected=case targets of [] => NONE | [target] => SOME target | _ =>
          (case #activeContext configuration of NONE => raise Fail "select a target for this build document"
           | SOME name => case List.find (fn target:W.target => #name target=name) targets of SOME target => SOME target
             | NONE => raise Fail "the active target does not select this build document")
        val flags=case selected of NONE => #flags configuration | SOME target => #flags target
        val root=case selected of NONE => getOpt (#libraryRoot configuration,lib)
          | SOME target => getOpt (#libraryRoot target,getOpt (#libraryRoot configuration,lib))
        val variables= #variables configuration @ (case selected of NONE => [] | SOME target => #variables target)
        fun compiler ()= #compiler (E.context (worker,{key=V.encode (V.Array
          [V.Bytes "build",V.Bytes root,M.strings flags,M.pairs variables]),lib=root,flags=flags}))
        fun range (start,stop)=E.range (source,encoding,start,stop)
        fun position ()=case LspProtocol.positionFromJson (J.required (params,"position")) of NONE => raise J.Invalid "invalid build position"
          | SOME point => case L.offset (#content snapshot,encoding,point) of NONE => raise J.Invalid "invalid build position" | SOME at => at
        fun linkCandidates () =
          let val candidates=case native of NONE => [] | SOME file =>
                C.Project.buildLinks (compiler (),{file=file,text=text,variables=variables,windows=platform=U.Windows})
              val ()=if length candidates<=2048 then () else raise Fail "document link count budget exceeded"
              fun token (candidate:C.Project.buildLink)=Hex.fromBytes (Sha256.digest (V.encode (V.Array
                [V.Bytes (#kind candidate),V.Bytes (#target candidate),V.Integer (IntInf.fromInt (#start candidate)),
                 V.Integer (IntInf.fromInt (#stop candidate))])))
          in List.map (fn candidate => (candidate,token candidate)) candidates end
        fun linkItem (candidate:C.Project.buildLink,token)=Json.Object [("range",range (#start candidate,#stop candidate)),
          ("data",Json.Object [("kind",Json.String "buildLink"),("uri",Json.String uri),
            ("revision",Json.intInf (#revision snapshot)),("generation",Json.intInf (W.generation workspace)),("token",Json.String token)])]
        fun links () =
          let val result=Json.Array (List.map linkItem (linkCandidates ()))
          in if size (Json.encode result)>1024*1024 then raise Fail "document link response budget exceeded" else result end
        fun resolveLink () =
          let val data=J.object (J.required (params,"data"))
              val ()=if J.string (J.required (data,"kind"))="buildLink" then () else raise J.Invalid "invalid document link kind"
              val ()=if Json.toIntInf (J.required (data,"revision"))=SOME (#revision snapshot) andalso
                Json.toIntInf (J.required (data,"generation"))=SOME (W.generation workspace) then () else raise E.Stale "document link is stale"
              val token=J.string (J.required (data,"token"))
              val (candidate,item)=case List.find (fn (_,key) => key=token) (linkCandidates ()) of
                NONE => raise J.Invalid "document link is unavailable" | SOME pair => (#1 pair,linkItem pair)
              val supplied=LspProtocol.rangeFromJson (J.required (params,"range"))
              val expected=LspProtocol.rangeFromJson (J.required (item,"range"))
              val ()=if isSome supplied andalso supplied=expected then () else raise J.Invalid "document link range was modified"
              val path=OS.FileSys.fullPath (#target candidate) handle OS.SysErr _ => raise Fail "document link target is unavailable"
              val target=U.original (U.fromPath (platform,path))
              val tooltip=if E.capability (capabilities,["textDocument","documentLink","tooltipSupport"])=SOME (Json.Bool true)
                then [("tooltip",Json.String (E.safe path))] else []
              val fields=case item of Json.Object fields => fields | _ => raise Fail "invalid document link presentation"
          in Json.Object (("target",Json.String target)::fields @ tooltip) end
        fun items at =
          case native of NONE => {items=[],isIncomplete=false} | SOME file =>
            let val result=C.Project.pathCompletions (compiler (),{file=file,text=text,offset=at,variables=variables,windows=platform=U.Windows})
                fun json (item:C.Project.pathCompletion)=
                  let val kind=case #kind item of "directory" => 19 | "library" => 9 | "variable" => 6 | _ => 17
                      val fields=[("label",Json.String (#label item)),("kind",Json.int kind),("insertTextFormat",Json.int 1),
                        ("textEdit",Json.Object [("range",range (#start item,#stop item)),("newText",Json.String (#text item))])]
                      val token=Hex.fromBytes (Sha256.digest (Json.encode (Json.Object fields)))
                  in Json.Object (("data",Json.Object [("kind",Json.String "buildPath"),("uri",Json.String uri),
                    ("revision",Json.intInf (#revision snapshot)),("generation",Json.intInf (W.generation workspace)),
                    ("offset",Json.int at),("token",Json.String token)])::fields) end
                val valid=List.filter (fn item:C.Project.pathCompletion => Utf8.isValid (#label item) andalso Utf8.isValid (#text item)) (#items result)
                fun bounded ([],_,out)=(List.rev out,false)
                  | bounded (item::rest,bytes,out)=
                      let val cost=size (#label (item:C.Project.pathCompletion))+size (#text item)+512
                      in if cost>1024*1024-bytes then (List.rev out,true) else bounded (rest,bytes+cost,item::out) end
                val (selected,truncated)=bounded (valid,0,[])
            in {items=List.map json selected,isIncomplete= #isIncomplete result orelse truncated} end
        fun diagnostics () =
          let val syntax=C.Project.buildSyntax {file=file,text=text}
              fun overlay (snapshot:D.snapshot)=case U.native (platform,U.parse (#uri snapshot)) of NONE => NONE
                | SOME {path,...} => SOME {file=path,text=L.text (#content snapshot)}
              val overlays=List.mapPartial overlay (D.all documents)
              val _=List.foldl (fn (item,seen) =>
                if List.exists (fn prior => W.sameFile platform (#file item,#file prior) andalso #text item<> #text prior) seen
                then raise Fail "conflicting source overlays refer to one file" else item::seen) [] overlays
              val projectErrors=if not (null (#diagnostics syntax)) orelse not (isSome native) then [] else
                ((ignore (C.Project.read (compiler (),{file=file,variables=variables,
                   overlays=overlays,windows=platform=U.Windows}));[])
                 handle C.Failed errors => errors)
              fun diagnostic (diagnostic:C.diagnostic)=Json.Object
                [("range",if #file diagnostic=file then range (#start diagnostic,#stop diagnostic) else range (0,0)),
                 ("severity",Json.int (if #severity diagnostic="error" then 1 else 2)),("source",Json.String "rune-build"),
                 ("message",Json.String (E.safe (#message diagnostic)))]
              val items=List.map diagnostic (#diagnostics syntax @ projectErrors)
              val id=Hex.fromBytes (Sha256.digest (V.encode (V.Array [V.Bytes uri,V.Bytes root,M.strings flags,M.pairs variables]) ^ Json.encode (Json.Array items)))
              val previous=case Json.member ("previousResultId",params) of NONE => NONE | SOME (Json.String id) => SOME id
                | _ => raise J.Invalid "invalid build diagnostic result id"
          in if previous=SOME id then Json.Object [("kind",Json.String "unchanged"),("resultId",Json.String id)] else
            Json.Object [("kind",Json.String "full"),("resultId",Json.String id),("items",Json.Array items)] end
    in case method of
         "textDocument/documentLink" => links ()
       | "documentLink/resolve" => resolveLink ()
       | "textDocument/semanticTokens/full" => Json.Null
       | "textDocument/inlayHint" => Json.Null
       | "inlayHint/resolve" => raise J.Invalid "build documents do not have inferred type hints"
       | "textDocument/semanticTokens/full/delta" => Json.Null
       | "textDocument/semanticTokens/range" => Json.Null
       | "textDocument/selectionRange" =>
           let val grammar=C.Project.buildSyntax {file=file,text=text}
               val pieces=List.map (fn reference:C.Project.buildReference =>
                 {kind="buildPath",start= #start reference,stop= #stop reference,
                  text=String.substring (text,#start reference,#stop reference- #start reference)}:C.Syntax.piece)
                 (#references grammar)
           in RuneLspStructure.selection {text=text,syntax=NONE,pieces=pieces,index=SOME (#content snapshot),
             encoding=encoding,positions=J.required (params,"positions")} end
       | "textDocument/completion" =>
           let val result=items (position ())
           in Json.Object [("items",Json.Array (#items result)),("isIncomplete",Json.Bool (#isIncomplete result))] end
       | "completionItem/resolve" =>
           let val data=J.required (params,"data")
               val ()=if Json.toIntInf (J.required (data,"revision"))=SOME (#revision snapshot) andalso
                 Json.toIntInf (J.required (data,"generation"))=SOME (W.generation workspace) then () else raise E.Stale "build completion is stale"
               val at=case Json.toInt (J.required (data,"offset")) of SOME at => at | NONE => raise J.Invalid "invalid build completion offset"
               val token=J.string (J.required (data,"token"))
           in case List.find (fn item => case Json.member ("data",item) of NONE => false | SOME data =>
                Json.member ("token",data)=SOME (Json.String token)) (#items (items at)) of SOME item => item
             | NONE => raise E.Stale "build completion is no longer available" end
       | "textDocument/diagnostic" => diagnostics ()
       | "textDocument/hover" => Json.Null
       | "textDocument/signatureHelp" => Json.Null
       | "textDocument/inlineCompletion" => Json.Object [("items",Json.Array [])]
       | _ => Json.Array []
    end
end

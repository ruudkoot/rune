(* Immutable workspace/document capture for a supervised analysis job. *)
structure RuneLspWorkerModel =
struct
  structure V=RuneLspWorkerWire
  structure W=RuneLspWorkspace
  structure D=RuneLspDocuments
  fun strings values=V.Array (List.map V.Bytes values)
  fun unstrings value=List.map V.bytes (V.array value)
  fun optional NONE=V.Null | optional (SOME value)=V.Bytes value
  fun unoptional V.Null=NONE | unoptional value=SOME (V.bytes value)
  fun pairs values=V.Array (List.map (fn (name,value) => V.Array [V.Bytes name,V.Bytes value]) values)
  fun unpairs value=List.map (fn value => case V.array value of [name,value] => (V.bytes name,V.bytes value)
    | _ => raise V.Invalid "invalid worker name/value pair") (V.array value)
  fun target (target:W.target)=V.Object [("name",V.Bytes (#name target)),("build",V.Bytes (#build target)),
    ("flags",strings (#flags target)),("variables",pairs (#variables target)),("libraryRoot",optional (#libraryRoot target))]
  fun untarget value : W.target={name=V.bytes (V.field (value,"name")),build=V.bytes (V.field (value,"build")),
    flags=unstrings (V.field (value,"flags")),variables=unpairs (V.field (value,"variables")),libraryRoot=unoptional (V.field (value,"libraryRoot"))}
  fun settings (settings:W.settings)=V.Object [("targets",V.Array (List.map target (#targets settings))),
    ("flags",strings (#flags settings)),("variables",pairs (#variables settings)),
    ("activeContext",optional (#activeContext settings)),("libraryRoot",optional (#libraryRoot settings))]
  fun unsettings value : W.settings={targets=List.map untarget (V.array (V.field (value,"targets"))),
    flags=unstrings (V.field (value,"flags")),variables=unpairs (V.field (value,"variables")),
    activeContext=unoptional (V.field (value,"activeContext")),libraryRoot=unoptional (V.field (value,"libraryRoot"))}
  fun capture (W.Workspace {platform,lib,roots,settings=global,scoped,generation,inputGeneration,choices},documents) =
    V.Object [("platform",V.Bytes (if platform=LspUri.Windows then "windows" else "posix")),("lib",V.Bytes lib),
      ("roots",strings (!roots)),("settings",settings (!global)),("choices",pairs (!choices)),("generation",V.Integer (!generation)),
      ("inputGeneration",V.Integer(!inputGeneration)),
      ("scoped",V.Array (List.map (fn (uri,value) => V.Array [V.Bytes uri,settings value]) (!scoped))),
      ("documents",V.Array (List.map (fn snapshot:D.snapshot => V.Object [("uri",V.Bytes (#uri snapshot)),
        ("language",V.Bytes (#languageId snapshot)),("version",V.Integer (#version snapshot)),
        ("revision",V.Integer (#revision snapshot)),("text",V.Bytes (LspPosition.text (#content snapshot)))])
        (List.filter (fn snapshot:D.snapshot => D.healthy (documents,#uri snapshot)) (D.all documents))))]
  fun restore value =
    let val platform=case V.bytes (V.field (value,"platform")) of "windows" => LspUri.Windows | "posix" => LspUri.Posix
          | _ => raise V.Invalid "unknown worker platform"
        val roots=unstrings (V.field (value,"roots"))
        val ()=if length roots<=64 then () else raise V.Invalid "too many worker workspace roots"
        val workspace=W.Workspace {platform=platform,lib=V.bytes (V.field (value,"lib")),roots=ref roots,
          settings=ref (unsettings (V.field (value,"settings"))),choices=ref (unpairs (V.field (value,"choices"))),
          generation=ref (V.integer (V.field (value,"generation"))),inputGeneration=ref(V.integer(V.field(value,"inputGeneration"))),scoped=ref (List.map (fn value =>
            case V.array value of [uri,value] => (V.bytes uri,unsettings value) | _ => raise V.Invalid "invalid worker scope")
            (V.array (V.field (value,"scoped"))))}
        val documents=D.new (LspProtocol.Utf8,{maxDocuments=512,maxDocumentBytes=4*1024*1024,maxTotalBytes=64*1024*1024,
          maxDocumentLines=200000,maxTotalLines=500000})
        val ()=List.app (fn value =>
          let val snapshot=D.openDocument (documents,{uri=V.bytes (V.field (value,"uri")),
                languageId=V.bytes (V.field (value,"language")),version=V.integer (V.field (value,"version")),
                text=V.bytes (V.field (value,"text"))})
              val revision=V.integer (V.field (value,"revision"))
              val ()=if IntInf.>= (revision,0) then () else raise V.Invalid "invalid worker document revision"
              val entry=valOf (D.lookup (documents,#uri snapshot))
              val snapshot:D.snapshot={uri= #uri snapshot,languageId= #languageId snapshot,version= #version snapshot,
                revision=revision,content= #content snapshot}
          in D.put (documents,{snapshot=snapshot,seen= #seen entry,desynchronized=false,save= #save entry}) end)
          (V.array (V.field (value,"documents")))
    in (workspace,documents) end
end

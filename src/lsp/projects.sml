(* Workspace membership is collected from compiler plans, including sources
   outside a root reached through use. No recursive directory scan is used. *)
structure RuneLspProjects =
struct
  structure W=RuneLspWorkspace
  structure D=RuneLspDocuments
  structure U=LspUri
  structure C=RuneCompiler
  type problem={uri:string,message:string}
  fun enrich (workspace as W.Workspace {platform,lib,roots,settings,scoped,...},documents,cancelled) =
    let val memberships=ref [] : (string*W.target) list ref
        val problems=ref [] : problem list ref
        val builds=ref [] : W.target list ref
        fun poll ()=if cancelled () then raise C.Analysis.Cancelled else ()
        fun fileUri file=U.original (U.fromPath (platform,OS.FileSys.fullPath file handle OS.SysErr _ => file))
        val overlays=List.mapPartial (fn snapshot:D.snapshot =>
          case U.native (platform,U.parse (#uri snapshot)) of NONE => NONE | SOME {path,...} =>
            SOME {file=path,text=LspPosition.text (#content snapshot)}) (D.all documents)
        fun target (config:W.settings,target:W.target) =
          let val ()=poll ()
              val libraryRoot=getOpt (#libraryRoot target,getOpt (#libraryRoot config,lib))
              val normalized={name= #name target,build= #build target,flags= #flags target,
                variables= #variables config @ #variables target,libraryRoot=SOME libraryRoot}:W.target
              val seen=List.exists (fn prior => prior=normalized) (!builds)
              val ()=if seen then () else builds:=normalized :: !builds
              val parent=C.session {lib=SOME libraryRoot,flags= #flags target}
              val project=(if seen then NONE else SOME (C.Project.read (parent,{file=W.filePath platform (#build target),variables= #variables normalized,
                overlays=overlays,windows=platform=U.Windows})) before C.close parent) handle error => (C.close parent;raise error)
              fun source (source:C.Project.source) =
                let val uri=fileUri (#file source)
                    val aliases=List.map #uri (List.filter (fn snapshot:D.snapshot =>
                      case U.native (platform,U.parse (#uri snapshot)) of NONE => false | SOME {path,...} =>
                        W.sameFile platform (#file source,path)) (D.all documents))
                in List.app (fn uri => memberships:=(uri,normalized) :: !memberships) (uri::aliases) end
          in Option.app (fn project => List.app source (C.Project.sources project)) project end
          handle C.Failed diagnostics => problems:={uri= #build target,message=String.concatWith "\n" (List.map #message diagnostics)} :: !problems
               | W.Invalid message => problems:={uri= #build target,message=message} :: !problems
        fun root uri =
          let val config=W.configurationFor (workspace,uri)
              val targets=if not (null (#targets config)) then #targets config else
                case U.native (platform,U.parse uri) of NONE => [] | SOME {path,...} =>
                  List.map (fn file => {name=fileUri file,build=fileUri file,flags= #flags config,
                    variables=[],libraryRoot=NONE}:W.target) (W.buildFiles platform path)
          in List.app (fn candidate => target (config,candidate)) targets end
        val ()=List.app root (!roots)
        val global= !settings
        val ()=List.app (fn candidate => target (global,candidate)) (#targets global)
        val uris=List.foldl (fn ((uri,_),all) => if List.exists (fn prior => prior=uri) all then all else uri::all) [] (!memberships)
        fun apply uri =
          let val original=W.configurationFor (workspace,uri)
              val candidates=List.foldl (fn ((_,target),all) => if List.exists (fn prior => prior=target) all then all else all @ [target]) []
                (List.filter (fn (file,_) => file=uri) (!memberships))
              val exact=List.exists (fn (scope,settings:W.settings) => scope=uri andalso not (null (#targets settings))) (!scoped)
              val config={targets=candidates,flags= #flags original,variables=[],activeContext= #activeContext original,
                libraryRoot= #libraryRoot original}:W.settings
          in if exact then () else scoped:=(uri,config) :: List.filter (fn (scope,_) => scope<>uri) (!scoped) end
        val ()=List.app apply uris
    in {uris=List.rev uris,problems=List.rev (!problems)} end
end

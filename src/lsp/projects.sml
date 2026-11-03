(* Workspace membership is collected from compiler plans, including sources
   outside a root reached through use. No recursive directory scan is used. *)
structure RuneLspProjects =
struct
  structure W=RuneLspWorkspace
  structure D=RuneLspDocuments
  structure U=LspUri
  structure C=CompilerApi
  type problem={uri:string,message:string}
  (* the files a plan was read from, what of them are sources a build reads
     (a group's), and the directories that say what builds there are *)
  type read={files:string list,sources:string list,directories:string list}
  fun enrich (workspace as W.Workspace {platform,lib,roots,settings,...},documents,cancelled) =
    let val memberships=ref [] : (string*W.target) list ref
        val problems=ref [] : problem list ref
        val builds=ref [] : W.target list ref
        val files=ref [] : string list ref
        val sources=ref [] : string list ref
        val directories=ref [] : string list ref
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
              val build=W.filePath platform (#build target)
              val project=(if seen then NONE else SOME (C.Project.read (parent,{file=build,workspace=W.rootFileIn (platform,documents) build,
                variables= #variables normalized,overlays=overlays,windows=platform=U.Windows})) before C.close parent)
                handle error => (C.close parent;raise error)
              val ()=files:=C.Workspace.candidates {file=build,windows=platform=U.Windows} @ !files
              fun input (input:C.Project.input)=if #kind input="source"
                then sources:= #file input:: !sources else files:= #file input:: !files
              val ()=Option.app (fn project => List.app input (C.Project.inputs project)) project
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
                  W.withNamed (workspace,documents,W.join platform (path,"file"),#flags config,
                    List.map (fn file => {name=fileUri file,build=fileUri file,flags= #flags config,
                      variables=[],libraryRoot=NONE}:W.target) (W.buildFiles platform path),true)
              val ()=case U.native (platform,U.parse uri) of NONE => ()
                | SOME {path,...} => directories:=path:: !directories
          in List.app (fn candidate => target (config,candidate)) targets end
        val ()=List.app root (!roots)
        val global= !settings
        val ()=List.app (fn candidate => target (global,candidate)) (#targets global)
        val owners=W.table (length (!memberships)) : W.target list ref W.table
        val uris=List.foldl (fn ((uri,target),all) => case W.lookup (owners,uri) of
            NONE => (W.add (owners,uri,ref [target]);uri::all)
          | SOME targets => (if List.exists (fn prior => prior=target) (!targets) then () else targets:= !targets @ [target];all))
          [] (!memberships)
        fun apply uri =
          let val original=W.configurationFor (workspace,uri)
              val config={targets=List.rev (!(valOf (W.lookup (owners,uri)))),flags= #flags original,variables=[],
                activeContext= #activeContext original,libraryRoot= #libraryRoot original}:W.settings
          in case W.scopedAt (workspace,uri) of SOME (settings:W.settings) =>
               if null (#targets settings) then SOME (uri,config) else NONE
             | NONE => SOME (uri,config) end
        val ()=W.assign (workspace,List.mapPartial apply uris)
    in {uris=List.rev uris,problems=List.rev (!problems),
        read={files= !files,sources= !sources,directories= !directories}:read} end
end

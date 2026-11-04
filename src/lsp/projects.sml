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
  fun fileUri platform file=U.original (U.fromPath (platform,OS.FileSys.fullPath file handle OS.SysErr _ => file))
  (* The targets enrich reads, in its order, each with the settings it is read
     in: each root's, where they name targets, or else the builds the root
     holds and its root file names; then the global settings'. *)
  fun targets (workspace as W.Workspace {platform,roots,settings,...},documents) =
    let fun root uri =
          let val config=W.configurationFor (workspace,uri)
              val targets=if not (null (#targets config)) then #targets config else
                case U.native (platform,U.parse uri) of NONE => [] | SOME {path,...} =>
                  W.withNamed (workspace,documents,W.join platform (path,"file"),#flags config,
                    List.map (fn file => {name=fileUri platform file,build=fileUri platform file,flags= #flags config,
                      variables=[],libraryRoot=NONE}:W.target) (W.buildFiles platform path),true)
          in List.map (fn target => (config,target)) targets end
    in List.concat (List.map root (!roots)) @ List.map (fn target => (!settings,target)) (#targets (!settings)) end
  (* a target as enrich reads it: its settings' variables and library root in it *)
  fun normalize (lib,config:W.settings,target:W.target) : W.target=
    {name= #name target,build= #build target,flags= #flags target,variables= #variables config @ #variables target,
     libraryRoot=SOME (getOpt (#libraryRoot target,getOpt (#libraryRoot config,lib)))}
  fun rootDirectories (W.Workspace {platform,roots,...})=
    List.mapPartial (fn uri => Option.map #path (U.native (platform,U.parse uri))) (!roots)
  fun enrich (workspace as W.Workspace {platform,lib,roots,settings,...},documents,cancelled) =
    let val memberships=ref [] : (string*W.target) list ref
        val problems=ref [] : problem list ref
        val builds=ref [] : W.target list ref
        val files=ref [] : string list ref
        val sources=ref [] : string list ref
        val directories=ref [] : string list ref
        fun poll ()=if cancelled () then raise C.Analysis.Cancelled else ()
        val fileUri=fileUri platform
        val overlays=List.mapPartial (fn snapshot:D.snapshot =>
          case U.native (platform,U.parse (#uri snapshot)) of NONE => NONE | SOME {path,...} =>
            SOME {file=path,text=LspPosition.text (#content snapshot)}) (D.all documents)
        fun target (config:W.settings,target:W.target) =
          let val ()=poll ()
              val normalized=normalize (lib,config,target)
              val libraryRoot=valOf (#libraryRoot normalized)
              val seen=List.exists (fn prior => prior=normalized) (!builds)
              val ()=if seen then () else builds:=normalized :: !builds
              val parent=C.session {lib=SOME libraryRoot,flags= #flags target}
              val build=W.filePath platform (#build target)
              val project=(if seen then NONE else SOME (W.readProject (parent,{file=build,workspace=W.rootFileIn (platform,documents) build,
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
        val ()=directories:=List.rev (rootDirectories workspace)
        val ()=List.app target (targets (workspace,documents))
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
  (* A file of a library planned from its library's targets alone (D26, D28).
     Where nothing names a file's context, a check takes it in the targets
     over its owning library that hold it, whatever else holds it: so where
     one of those does, enrich and W.contexts would come to the contexts it
     gives, and the other targets need not be read. That is a target enrich
     reads (targets) whose build is the owner's, read as enrich and
     W.contexts read it. NONE where this does not settle it: the settings
     name the file's targets or its context, a document is not in step, or
     no target over the owner holds the file. configuration is the file's,
     as enrich would leave it for a check to read its target's settings. *)
  fun owned (workspace as W.Workspace {platform,lib,...},documents,uri,cancelled) =
    if not (!W.owners) orelse List.exists (fn snapshot:D.snapshot => not (D.healthy (documents,#uri snapshot))) (D.all documents)
    then NONE else
    case U.native (platform,U.parse uri) of NONE => NONE | SOME {path,...} =>
    let val original=W.configurationFor (workspace,uri)
        val exact=case W.scopedAt (workspace,uri) of SOME (settings:W.settings) => not (null (#targets settings)) | NONE => false
    in if isSome (#activeContext original) orelse exact then NONE else
       case W.ownerBuild platform path of NONE => NONE | SOME owner =>
       let val overlays=List.mapPartial (fn snapshot:D.snapshot =>
             case U.native (platform,U.parse (#uri snapshot)) of NONE => NONE | SOME {path,...} =>
               SOME {file=path,text=LspPosition.text (#content snapshot)}) (D.all documents)
           val files=ref [] : string list ref
           val isOwner=W.sameAs platform owner
           fun read (seen,[])=List.rev seen
             | read (seen,(config,target:W.target)::rest)=
                 let val normalized=normalize (lib,config,target)
                 in if not (isOwner (W.uriPath platform (#build target)))
                       orelse List.exists (fn (prior,_) => prior=normalized) seen then read (seen,rest) else
                    let val ()=if cancelled () then raise C.Analysis.Cancelled else ()
                        val build=W.filePath platform (#build target)
                        val ()=files:=C.Workspace.candidates {file=build,windows=platform=U.Windows} @ !files
                        val parent=C.session {lib= #libraryRoot normalized,flags= #flags target}
                        val contexts=(let val project=(W.readProject (parent,{file=build,workspace=W.rootFileIn (platform,documents) build,
                              variables= #variables normalized,overlays=overlays,windows=platform=U.Windows}) before C.close parent)
                              handle error => (C.close parent;raise error)
                          in files:=List.map #file (C.Project.inputs project) @ !files;
                             W.contextsIn (platform,normalized,project,path) end)
                          handle C.Failed _ => [] | W.Invalid _ => []
                    in read ((normalized,contexts)::seen,rest) end end
           val holding=List.filter (not o null o #2) (read ([],targets (workspace,documents)))
           (* Where no target is over the owner, the file's settings name no
              targets and no variables, and its root file names no target over
              the owner, W.contexts takes the owner as a target of its own,
              whether a root's build holds the file (the owner, as no
              candidate is) or none does (the owner, found above the file,
              or as no candidate is): the same target either way. *)
           val holding=if not (null holding) then holding else
             if not (null (#targets original)) orelse not (null (#variables original)) orelse
                List.exists (fn target:W.target => isOwner (W.uriPath platform (#build target)))
                  (W.namedTargets (workspace,documents,path,#flags original,false)) then [] else
             let val uri=U.original (U.fromPath (platform,owner))
                 val target={name=uri,build=uri,flags= #flags original,variables=[],libraryRoot=NONE}:W.target
                 val parent=C.session {lib=SOME (getOpt (#libraryRoot original,lib)),flags= #flags original}
                 val () =files:=C.Workspace.candidates {file=path,windows=platform=U.Windows} @
                   C.Workspace.candidates {file=owner,windows=platform=U.Windows} @ !files
                 val contexts=(let val project=(W.readProject (parent,{file=owner,workspace=W.rootFileIn (platform,documents) owner,
                       variables=[],overlays=overlays,windows=platform=U.Windows}) before C.close parent)
                       handle error => (C.close parent;raise error)
                   in files:=List.map #file (C.Project.inputs project) @ !files;W.contextsIn (platform,target,project,path) end)
                   handle C.Failed _ => [] | W.Invalid _ => []
             in if null contexts then [] else [(target,contexts)] end
           (* where a library.build would make another library the owner *)
           fun walk (directory,found)=if W.sameFile platform (directory,W.directory platform owner) then found else
             case W.parent platform directory of NONE => directory::found
               | SOME above => if length found>64 then found else walk (above,directory::found)
           val roots=rootDirectories workspace
           val rootFiles=List.concat (List.map (fn root => C.Workspace.candidates {file=W.join platform (root,"file"),
             windows=platform=U.Windows}) roots)
       in if null holding then NONE else
          SOME {contexts=List.concat (List.map #2 holding),
                configuration={targets=List.filter (fn target:W.target => isSome (#libraryRoot target)) (List.map #1 holding),
                  flags= #flags original,variables=[],activeContext= #activeContext original,libraryRoot= #libraryRoot original}:W.settings,
                read={files=owner::rootFiles @ !files,sources=[],directories=roots @ walk (W.directory platform path,[])}:read} end end
end

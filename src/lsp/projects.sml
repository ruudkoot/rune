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
  (* An index of what each build file names (D28), so that a file of no
     library is planned from the targets that can reach a build naming it,
     and no other target is read. The way it plans holds where it is exact:

     enrich and W.contexts take a target for an open file where a source of
     the target's plan is that file: the same key, or the same file. Of a
     file on the disk, the same key is the same path, so both come to the
     same file. A plan reaches each build by a spelling, whose directory the
     build's paths are taken from; a node here is the build under the real
     directory of that spelling, whose paths name the files those of every
     spelling of it do, as the system resolves them. So a target holds the
     file only if, from its build, the uses reach a node naming a file that
     is the file: a superset, which each candidate's project, read as enrich
     reads it, makes exact. A build that does not parse, names a path with a
     variable, or is not there, may name anything and reach anything.

     Kept between plans: a node's text is taken again, from the kept texts,
     where it changed; what its sources are, again where an event names one,
     and where no event can say, at every plan. *)
  type source={path:string,id:OS.FileSys.file_id option}
  (* id: the build file's own; vouched: whether events vouch for every
     source's file, when it was looked at, and pathVouched for the build's;
     overlaid: whether its text was an open document's *)
  type node={key:string,path:string,dir:string,text:string option,wild:bool,uses:string list,sources:source list,
    vouched:bool,id:OS.FileSys.file_id option,pathVouched:bool,overlaid:bool}
  (* byPath and byNode: the nodes of a build by the key events name its file
     by, and by its file; held: the nodes whose texts must be looked at at
     every plan, an open document's or one no event vouches for; targets: a
     target's build's node, and the places of its root file *)
  type index={nodes:node W.store,usedBy:string list W.store,byId:(OS.FileSys.file_id*string) list W.store,
    bySource:string list W.store,wild:unit W.store,real:string W.store,seen:IntInf.int ref,
    byPath:string list W.store,byNode:(OS.FileSys.file_id*string) list W.store,held:unit W.store,
    targets:(string*string list) W.store,projects:(string*C.Project.t*(string*string option) list) list ref,
    places:(string list*string list) ref}
  fun index () : index={nodes=W.store (),usedBy=W.store (),byId=W.store (),bySource=W.store (),wild=W.store (),
    real=W.store (),seen=ref 0,byPath=W.store (),byNode=W.store (),held=W.store (),targets=W.store (),projects=ref [],
    places=ref ([],[])}
  fun forgetIndex (index:index)=(W.empty (#nodes index);W.empty (#usedBy index);W.empty (#bySource index);
    W.empty (#byId index);W.empty (#wild index);W.empty (#real index);W.empty (#byPath index);W.empty (#byNode index);
    W.empty (#held index);W.empty (#targets index);#projects index:=[];#places index:=([],[]))
  fun vouchedPath path=isSome (!W.vouch path)
  fun idName id=Word.toString (OS.FileSys.hash id)
  fun absolute platform v=String.isPrefix "/" v orelse String.isPrefix "\\" v orelse
    (platform=U.Windows andalso size v>=3 andalso String.sub (v,1)= #":" andalso (String.sub (v,2)= #"/" orelse String.sub (v,2)= #"\\"))
  (* the node a spelling of a build reaches: its directory's real path, which
     is kept, and its name *)
  fun nodeKey (index:index,platform) path=
    let val dir=W.directory platform path
        val name=if String.isPrefix dir path andalso size path>size dir then String.extract (path,size dir+1,NONE) else OS.Path.file path
        val real=case W.fetch (#real index,dir) of SOME real => real | NONE =>
          let val real=(OS.FileSys.fullPath dir) handle OS.SysErr _ => dir
          in W.keep (#real index,dir,real);real end
    in (W.join platform (real,name),real) end
  fun push (store,key,value)=W.keep (store,key,value::getOpt (W.fetch (store,key),[]))
  fun pull (store,key,keep')=case W.fetch (store,key) of NONE => ()
    | SOME values => (case List.filter keep' values of [] => W.remove (store,key) | rest => W.keep (store,key,rest))
  fun unlink (index:index,platform) (node:node)=
    (List.app (fn use => pull (#usedBy index,use,fn other => other<> #key node)) (#uses node);
     List.app (fn {id=SOME id,...} => pull (#byId index,idName id,fn (_,other) => other<> #key node) | _ => ()) (#sources node);
     List.app (fn {path,...} => case W.eventKey platform path of NONE => ()
       | SOME key => pull (#bySource index,key,fn other => other<> #key node)) (#sources node);
     Option.app (fn key => pull (#byPath index,key,fn other => other<> #key node)) (W.eventKey platform (#path node));
     Option.app (fn id => pull (#byNode index,idName id,fn (_,other) => other<> #key node)) (#id node);
     W.remove (#held index,#key node);W.remove (#wild index,#key node);W.remove (#nodes index,#key node))
  fun link (index:index,platform) (node:node)=
    (W.keep (#nodes index,#key node,node);
     List.app (fn use => push (#usedBy index,use,#key node)) (#uses node);
     List.app (fn {id=SOME id,...} => push (#byId index,idName id,(id,#key node)) | _ => ()) (#sources node);
     List.app (fn {path,...} => case W.eventKey platform path of NONE => () | SOME key => push (#bySource index,key,#key node)) (#sources node);
     Option.app (fn key => push (#byPath index,key,#key node)) (W.eventKey platform (#path node));
     Option.app (fn id => push (#byNode index,idName id,(id,#key node))) (#id node);
     if #overlaid node orelse not (#pathVouched node) then W.keep (#held index,#key node,()) else ();
     if #wild node then W.keep (#wild index,#key node,()) else ())
  (* a build's text as a plan reads it: the open document's, or the kept
     text, or the disk's, which is kept *)
  fun overlayOf (platform,documents) path=
    List.find (fn snapshot:D.snapshot => case U.native (platform,U.parse (#uri snapshot)) of
      SOME {path=other,...} => W.sameFile platform (other,path) | NONE => false) (D.all documents)
  fun buildText (platform,documents) path=
    case overlayOf (platform,documents) path of
      SOME snapshot => SOME (LspPosition.text (#content snapshot))
    | NONE => let val {held,read}= !W.holding in case held path of SOME text => SOME text | NONE =>
        let val input=BinIO.openIn path
            val text=(Byte.bytesToString (BinIO.inputAll input) before BinIO.closeIn input)
              handle error => (BinIO.closeIn input handle _ => ();raise error)
        in W.buildsRead:= !W.buildsRead+1;read (path,text);SOME text end
        handle IO.Io _ => NONE | OS.SysErr _ => NONE end
  fun summarize (index:index,platform,documents) (key,path,dir) : node=
    let val text=buildText (platform,documents) path
        val id=W.identityOf (path,"")
        val pathVouched=vouchedPath path
        val overlaid=isSome (overlayOf (platform,documents) path)
        val wildNode={key=key,path=path,dir=dir,text=text,wild=true,uses=[],sources=[],vouched=true,
          id=id,pathVouched=pathVouched,overlaid=overlaid}
    in case text of NONE => wildNode | SOME body =>
       let val {references,diagnostics}=C.Project.buildSyntax {file=path,text=body}
           fun resolve v=if absolute platform v then v else W.join platform (dir,v)
           val named=List.filter (fn r:C.Project.buildReference => #kind r="source" orelse #kind r="build") references
           val wild=not (null diagnostics) orelse List.exists (fn r:C.Project.buildReference => String.isSubstring "$(" (#value r)) named
           val sources=List.map (fn r:C.Project.buildReference => let val p=resolve (#value r)
             in {path=p,id=W.identityOf (p,"")} end) (List.filter (fn r:C.Project.buildReference => #kind r="source") named)
           val uses=List.map (fn r:C.Project.buildReference => #1 (nodeKey (index,platform) (resolve (#value r))))
             (List.filter (fn r:C.Project.buildReference => #kind r="build") named)
       in {key=key,path=path,dir=dir,text=text,wild=wild,uses=uses,sources=sources,
           vouched=List.all (fn {path,...} => vouchedPath path) sources,id=id,pathVouched=pathVouched,overlaid=overlaid} end
       handle C.Failed _ => wildNode end
  (* the node of a spelling of a build, made, with what it uses, where it is not *)
  fun ensure (index:index,platform,documents) path=
    let val (key,dir)=nodeKey (index,platform) path
        fun visit (key,path,dir)=if isSome (W.fetch (#nodes index,key)) then () else
          let val node=summarize (index,platform,documents) (key,path,dir)
          in link (index,platform) node;List.app (fn use => visit (use,use,W.directory platform use)) (#uses node) end
    in visit (key,path,dir);key end
  (* brought up to a state: a node whose text changed is taken again, with
     what it now uses; one an event names a source of has its sources'
     files looked at again; where no event can say (vouched), every one *)
  fun refresh (index:index,platform,documents,changed:string list option) =
    let fun again (node:node)=
          let val fresh=summarize (index,platform,documents) (#key node,#path node,#dir node)
          in unlink (index,platform) node;link (index,platform) fresh;
             List.app (fn use => ignore (ensure (index,platform,documents) use)) (#uses fresh) end
        fun keysOf store key=getOpt (W.fetch (store,key),[])
        (* the nodes whose text may have changed: those an event names, those
           an open document is, and those no event vouches for, or that were
           an open document's; where the events are not whole, every one *)
        val documented=List.concat (List.map (fn snapshot:D.snapshot =>
          case U.native (platform,U.parse (#uri snapshot)) of NONE => [] | SOME {path,...} =>
            getOpt (Option.map (keysOf (#byPath index)) (W.eventKey platform path),[]) @
            (case W.identityOf (path,"") of NONE => []
              | SOME id => List.mapPartial (fn (other,key) => if OS.FileSys.compare (other,id)=EQUAL then SOME key else NONE)
                  (keysOf (#byNode index) (idName id)))) (D.all documents))
        val looked=case changed of NONE => List.map #1 (W.entries (#nodes index))
          | SOME keys => List.concat (List.map (keysOf (#byPath index)) keys) @ documented @ List.map #1 (W.entries (#held index))
        val seen=W.store () : unit W.store
        val () =List.app (fn key => if isSome (W.fetch (seen,key)) then () else (W.keep (seen,key,());
          case W.fetch (#nodes index,key) of NONE => ()
            | SOME node => if buildText (platform,documents) (#path node)<> #text node
                orelse isSome (overlayOf (platform,documents) (#path node))<> #overlaid node then again node else ())) looked
        (* the nodes whose sources' files may have changed *)
        val named=case changed of NONE => List.map #1 (W.entries (#nodes index))
          | SOME keys => List.concat (List.map (keysOf (#bySource index)) keys) @
              List.mapPartial (fn (key,node:node) => if #vouched node then NONE else SOME key) (W.entries (#nodes index))
        fun restat key=case W.fetch (#nodes index,key) of NONE => () | SOME (node:node) =>
          let val sources=List.map (fn {path,...} => {path=path,id=W.identityOf (path,"")}) (#sources node)
          in unlink (index,platform) node;
             link (index,platform) {key= #key node,path= #path node,dir= #dir node,text= #text node,wild= #wild node,
               uses= #uses node,sources=sources,vouched=List.all (fn {path,...} => vouchedPath path) sources,
               id=W.identityOf (#path node,""),pathVouched= #pathVouched node,overlaid= #overlaid node} end
    in List.app restat named end
  (* A target's project, read as enrich reads it, or the one read last where
     it is read again the same: a project is of the target's settings and the
     texts of what it read, its builds and the places of its root file, which
     are each taken as a plan takes them (buildText). The last eight are kept. *)
  fun projectOf (index:index,platform,documents,overlays) (normalized:W.target,build) =
    let val key=String.concatWith "\000" ([#name normalized,#build normalized,getOpt (#libraryRoot normalized,"")] @
          #flags normalized @ List.concat (List.map (fn (name,value) => [name,value]) (#variables normalized)))
        fun texts project=List.map (fn {file,...}:C.Project.input => (file,buildText (platform,documents) file)) (C.Project.inputs project) @
          List.map (fn file => (file,buildText (platform,documents) file)) (C.Workspace.candidates {file=build,windows=platform=U.Windows})
        fun same (project,read)=texts project=read
    in case List.find (fn (other,project,read) => other=key andalso same (project,read)) (!(#projects index)) of
         SOME (_,project,_) => project
       | NONE =>
         let val parent=C.session {lib= #libraryRoot normalized,flags= #flags normalized}
             val project=(W.readProject (parent,{file=build,workspace=W.rootFileIn (platform,documents) build,
               variables= #variables normalized,overlays=overlays,windows=platform=U.Windows}) before C.close parent)
               handle error => (C.close parent;raise error)
             val kept=(key,project,texts project)::List.filter (fn (other,_,_) => other<>key) (!(#projects index))
         in #projects index:=List.take (kept,Int.min (8,length kept));project end end
  (* The plan of a file from the index: NONE where it does not settle it, or
     is not exact (a document not in step, settings that name the file's
     targets, a file not on the disk), and enrich and W.contexts decide. *)
  fun indexed (index:index,workspace as W.Workspace {platform,lib,...},documents,uri,cancelled) =
    if List.exists (fn snapshot:D.snapshot => not (D.healthy (documents,#uri snapshot))) (D.all documents) then NONE else
    case U.native (platform,U.parse uri) of NONE => NONE | SOME {path,...} =>
    let val original=W.configurationFor (workspace,uri)
        val exact=case W.scopedAt (workspace,uri) of SOME (settings:W.settings) => not (null (#targets settings)) | NONE => false
    in if exact then NONE else
       case (SOME (OS.FileSys.fileId path) handle OS.SysErr _ => NONE) of NONE => NONE | SOME id =>
       let val all=targets (workspace,documents)
           val files=ref [] : string list ref
           (* every target's build, as a node, remembered *)
           val withKeys=List.map (fn (config,target:W.target) =>
             let val (key,_)=case W.fetch (#targets index,#build target) of
                     SOME (known as (key,_)) => if isSome (W.fetch (#nodes index,key)) then known else
                       (ensure (index,platform,documents) (W.uriPath platform (#build target)),#2 known)
                   | NONE => let val build=W.uriPath platform (#build target)
                       val known=(ensure (index,platform,documents) build,C.Workspace.candidates {file=build,windows=platform=U.Windows})
                     in W.keep (#targets index,#build target,known);known end
             in (config,target,key) end) all
           (* the places of the targets' root files, once each, kept while the targets stand *)
           val builds=List.map (fn (_,target:W.target) => #build target) all
           val () =if #1 (!(#places index))=builds then () else
             let val seen=W.store () : unit W.store
                 val places=List.concat (List.map (fn build => case W.fetch (#targets index,build) of NONE => [] | SOME (_,places) =>
                   List.filter (fn place => if isSome (W.fetch (seen,place)) then false else (W.keep (seen,place,());true)) places) builds)
             in #places index:=(builds,places) end
           val () =files:= #2 (!(#places index))
           (* what can reach a node naming the file *)
           val reached=W.store () : unit W.store
           fun reach key=if isSome (W.fetch (reached,key)) then () else
             (W.keep (reached,key,());List.app reach (getOpt (W.fetch (#usedBy index,key),[])))
           val naming=List.filter (fn (other,_) => OS.FileSys.compare (other,id)=EQUAL) (getOpt (W.fetch (#byId index,idName id),[]))
           val () =List.app (fn (_,key) => reach key) naming
           (* the names a source that is the file can have: those of the
              index's paths that are the file *)
           val names=OS.Path.file path::List.concat (List.map (fn (_,key) => case W.fetch (#nodes index,key) of NONE => []
             | SOME (node:node) => List.mapPartial (fn {path,id=SOME other} =>
                 if OS.FileSys.compare (other,id)=EQUAL then SOME (OS.Path.file path) else NONE | _ => NONE) (#sources node)) naming)
           val () =List.app (fn (key,_) => reach key) (W.entries (#wild index))
           val overlays=List.mapPartial (fn snapshot:D.snapshot =>
             case U.native (platform,U.parse (#uri snapshot)) of NONE => NONE | SOME {path,...} =>
               SOME {file=path,text=LspPosition.text (#content snapshot)}) (D.all documents)
           fun read (seen,[])=List.rev seen
             | read (seen,(config,target:W.target,key)::rest)=
                 let val normalized=normalize (lib,config,target)
                 in if not (isSome (W.fetch (reached,key))) orelse List.exists (fn (prior,_) => prior=normalized) seen
                    then read (seen,rest) else
                    let val ()=if cancelled () then raise C.Analysis.Cancelled else ()
                        val build=W.filePath platform (#build target)
                        val contexts=(W.contextsNamed (platform,normalized,projectOf (index,platform,documents,overlays) (normalized,build),
                          path,SOME names)) handle C.Failed _ => [] | W.Invalid _ => []
                    in read ((normalized,contexts)::seen,rest) end end
           val holding=List.filter (not o null o #2) (read ([],withKeys))
           val configuration={targets=List.map #1 holding,flags= #flags original,variables=[],
             activeContext= #activeContext original,libraryRoot= #libraryRoot original}:W.settings
           val found=List.concat (List.map #2 holding)
           (* then what W.contexts does with them: one owner (D26) *)
           val owner=if isSome (#activeContext configuration) orelse not (!W.owners) then NONE else W.ownerBuild platform path
           val found=case owner of NONE => found | SOME build =>
             let val owned=List.filter (fn context:W.context => W.sameFile platform (W.filePath platform (#build context),build)) found
                 val owned=if not (null owned) then owned else
                   let val uri=U.original (U.fromPath (platform,build))
                       val target={name=uri,build=uri,flags= #flags configuration,variables=[],libraryRoot=NONE}:W.target
                       val parent=C.session {lib=SOME (getOpt (#libraryRoot configuration,lib)),flags= #flags configuration}
                   in (let val project=(W.readProject (parent,{file=build,workspace=W.rootFileIn (platform,documents) build,
                            variables=[],overlays=overlays,windows=platform=U.Windows}) before C.close parent)
                            handle error => (C.close parent;raise error)
                       in files:=List.map #file (C.Project.inputs project) @ !files;W.contextsIn (platform,target,project,path) end)
                       handle C.Failed _ => [] | W.Invalid _ => [] end
             in if null owned then found else owned end
           val roots=rootDirectories workspace
           val rootFiles=List.concat (List.map (fn root => C.Workspace.candidates {file=W.join platform (root,"file"),
             windows=platform=U.Windows}) roots)
       in if null holding then NONE else
          SOME {contexts=found,configuration=configuration,
                read={files=rootFiles @ List.map (fn (_,node:node) => #path node) (W.entries (#nodes index)) @ !files,sources=[],
                      directories=roots @ W.directories (workspace,path)}:read} end end
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

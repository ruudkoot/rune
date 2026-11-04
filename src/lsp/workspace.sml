(* Workspace settings and build contexts. Project planning stays behind the
   compiler library; the adapter owns URI conversion and client choices. *)
structure RuneLspWorkspace =
struct
  structure J=RuneLspSync
  structure U=LspUri
  structure D=RuneLspDocuments
  structure C=CompilerApi
  type target={name:string,build:string,flags:string list,variables:(string*string) list,libraryRoot:string option}
  type settings={targets:target list,flags:string list,variables:(string*string) list,activeContext:string option,libraryRoot:string option}
  type context={id:string,label:string,name:string,target:string,build:string,ordinal:int,project:C.Project.t,source:C.Project.source}
  datatype selection=Loose | Selected of context | Ambiguous of context list
  (* A table of chains, in which a name's first entry is the one a search of the
     list it was made from finds. *)
  type 'a table=(string*'a) list array
  (* changes: the files a client's watcher said changed, newest first, each by
     the input generation its event made, its key, and whether it came or
     went, which changes its directory too; changeFloor: the generation from
     which that list is whole (changed, below) *)
  datatype t=Workspace of {platform:U.platform,lib:string,roots:string list ref,settings:settings ref,scoped:(string*settings) list ref,
    index:{uris:settings table,keys:settings table} option ref,
    generation:IntInf.int ref,inputGeneration:IntInf.int ref,choices:(string*string) list ref,
    changes:(IntInf.int*string*bool) list ref,changeFloor:IntInf.int ref}
  exception Invalid of string
  val defaults:settings={targets=[],flags=[],variables=[],activeContext=NONE,libraryRoot=NONE}
  fun invalid message=raise Invalid message
  (* What a status shows of a file or a target: the last part of a file URI, or
     the name as it stands. *)
  fun shortName (platform,name)=case (U.native (platform,U.parse name) handle U.Invalid => NONE) of NONE => name
    | SOME {path,...} => (case String.tokens (fn c => c= #"/" orelse c= #"\\") path of [] => name | parts => List.last parts)
  fun strings value = case value of Json.Array values => List.map J.string values
    | _ => invalid "expected an array of strings"
  fun optional (object,key,decode,fallback)=case J.member (object,key) of NONE => fallback | SOME value => decode value
  fun filePath platform text =
    case U.native (platform,U.parse text) of SOME {path,...} => path | NONE => invalid "expected a supported file URI"
  fun nativeKey platform text = Option.map #key (U.native (platform,U.parse text)) handle U.Invalid => NONE
  fun variables platform (Json.Object fields) = List.map (fn (name,value) =>
        if name="" then invalid "empty path variable" else (name,filePath platform (J.string value))) fields
    | variables _ _ = invalid "pathVariables must be an object of file URIs"
  fun flags platform value =
    let val value=J.object value
        val target=optional (value,"target",J.string,"registers")
        val ()=if target="registers" orelse target="stack" then () else invalid "unknown compiler target"
        val mode=optional (value,"sourceMode",J.string,"ascii")
        val modeFlag=case mode of "ascii" => [] | "unicode" => ["--unicode=utf8"]
          | "unicode=utf8" => ["--unicode=utf8"] | "unicode=latin1" => ["--unicode=latin1"]
          | _ => invalid "unknown source mode"
        val libraries=optional (value,"libraries",strings,[])
    in ["--target=" ^ target] @ modeFlag @ List.concat (List.map (fn name => ["--library",name]) libraries) end
  fun settings platform value : settings =
    let val value=J.object value
        val common=flags platform value
        val vars=optional (value,"pathVariables",variables platform,[])
        fun target child : target =
          let val child=J.object child
              val commonFields=case value of Json.Object fields => fields | _ => invalid "settings must be an object"
              val childFields=case child of Json.Object fields => fields | _ => invalid "target must be an object"
              val merged=Json.Object (childFields @ List.filter (fn (name,_) => not (List.exists (fn (key,_) => key=name) childFields)) commonFields)
              val build=J.string (J.required (child,"build"))
              val _=filePath platform build
              val name=optional (child,"name",J.string,build)
              val libraryRoot=case J.member (child,"libraryRoot") of NONE => NONE | SOME Json.Null => NONE
                | SOME value => SOME (filePath platform (J.string value))
          in {name=name,build=build,flags=flags platform merged,libraryRoot=libraryRoot,
              variables=optional (child,"pathVariables",variables platform,[])} end
        val targets=case J.member (value,"targets") of NONE => [] | SOME (Json.Array values) => List.map target values
          | _ => invalid "targets must be an array"
        val active=case J.member (value,"activeContext") of NONE => NONE | SOME Json.Null => NONE
          | SOME value => SOME (J.string value)
        val libraryRoot=case J.member (value,"libraryRoot") of NONE => NONE | SOME Json.Null => NONE
          | SOME value => SOME (filePath platform (J.string value))
    in {targets=targets,flags=common,variables=vars,activeContext=active,libraryRoot=libraryRoot} end
    handle J.Invalid message => raise Invalid message | U.Invalid => raise Invalid "invalid file URI"
  fun new {platform,lib} = Workspace {platform=platform,lib=lib,roots=ref [],settings=ref defaults,scoped=ref [],index=ref NONE,
    generation=ref 0,inputGeneration=ref 0,choices=ref [],changes=ref [],changeFloor=ref 0}
  fun generation (Workspace {generation,...})= !generation
  fun inputGeneration (Workspace {inputGeneration,...})= !inputGeneration
  fun dirty (Workspace {generation,inputGeneration,...}) =
    (generation:=IntInf.+ (!generation,1);inputGeneration:=IntInf.+(!inputGeneration,1))
  fun invalidate (workspace as Workspace {choices,...}) = (dirty workspace;choices:=[])
  fun roots (Workspace {roots,...})= !roots
  fun setRoots (workspace as Workspace {platform,roots,...},values) =
    let val ()=if length values>64 then invalid "too many workspace folders" else ()
        val ()=List.app (fn uri => ignore (U.parse uri)) values
        val unique=List.foldl (fn (uri,all) => if List.exists (fn prior => prior=uri) all then all else all @ [uri]) [] values
    in roots:=unique;invalidate workspace end
  fun configure (workspace as Workspace {platform,settings=stored,...},value) =
    let val parsed=settings platform value
    in if parsed= !stored then () else (stored:=parsed;invalidate workspace) end
  fun table count : 'a table=Array.array (2*count+1,[])
  (* by a name's last 32 characters and its size: paths share long prefixes,
     and a chain compares whole names *)
  fun slot (chains:'a table,name)=
    let val n=size name
        fun go (i,hash)=if i>=n then hash else go (i+1,(hash*31+Char.ord (String.sub (name,i))) mod 1048573)
    in go (Int.max (0,n-32),n mod 1048573) mod Array.length chains end
  fun lookup (chains,name)=Option.map #2 (List.find (fn (other,_) => other=name) (Array.sub (chains,slot (chains,name))))
  fun add (chains,name,value)=let val at=slot (chains,name) in Array.update (chains,at,(name,value) :: Array.sub (chains,at)) end
  (* a table that grows, in which a name has one entry *)
  type 'a store={chains:'a table ref,count:int ref}
  fun store () : 'a store={chains=ref (table 32),count=ref 0}
  fun fetch ({chains,...}:'a store,name)=lookup (!chains,name)
  fun remove ({chains,count}:'a store,name)=
    let val at=slot (!chains,name)
        val (gone,kept)=List.partition (fn (other,_) => other=name) (Array.sub (!chains,at))
    in Array.update (!chains,at,kept);count:= !count-length gone end
  fun keep (s as {chains,count}:'a store,name,value)=
    (remove (s,name);
     if 2*(!count+1)<=Array.length (!chains) then () else
       let val old= !chains
           val grown=table (2*Array.length old)
       in Array.app (List.app (fn (other,item) => add (grown,other,item))) old;chains:=grown end;
     add (!chains,name,value);count:= !count+1)
  fun entries ({chains,...}:'a store)=Array.foldl (op @) [] (!chains)
  fun empty ({chains,count}:'a store)=(chains:=table 32;count:=0)
  fun stored ({count,...}:'a store)= !count
  (* Scoped settings by URI and by native key, made after a change to them, so
     that a file's configuration costs its depth and not the number of scopes. *)
  fun indexed (Workspace {platform,scoped,index,...}) =
    case !index of SOME tables => tables | NONE =>
      let val uris=table (length (!scoped)) val keys=table (length (!scoped))
          val ()=List.app (fn (uri,value) => (add (uris,uri,value);
            Option.app (fn key => add (keys,key,value)) (nativeKey platform uri))) (List.rev (!scoped))
          val tables={uris=uris,keys=keys}
      in index:=SOME tables;tables end
  fun scopedAt (workspace,uri)=lookup (#uris (indexed workspace),uri)
  (* The longest key that holds a file's: itself, or a directory above it, with
     or without the slash that ends it. *)
  fun nearest (keys,key) =
    let fun prefix count=lookup (keys,String.substring (key,0,count))
        fun above at=if at<0 then NONE else if String.sub (key,at)<> #"/" then above (at-1) else
          case prefix (at+1) of SOME value => SOME value | NONE =>
            (case prefix at of SOME value => SOME value | NONE => above (at-1))
    in case prefix (size key) of SOME value => SOME value | NONE => above (size key-1) end
  fun forget (Workspace {scoped,index,choices,...},uri) =
    (scoped:=List.filter (fn (scope,_) => scope<>uri) (!scoped);index:=NONE;
     choices:=List.filter (fn (document,_) => document<>uri) (!choices))
  fun configurationFor (workspace as Workspace {platform,settings,scoped,...},uri) =
    if null (!scoped) then !settings else
    let val {uris,keys}=indexed workspace
    in case lookup (uris,uri) of SOME settings => settings
       | NONE => getOpt (Option.mapPartial (fn key => nearest (keys,key)) (nativeKey platform uri),!settings) end
  fun configureAt (workspace as Workspace {platform,scoped,index,...},uri,value) =
    let val previous=configurationFor(workspace,uri)
        val rest=List.filter(fn (scope,_)=>scope<>uri)(!scoped)
    in case value of Json.Null=>
        (scoped:=rest;index:=NONE;if previous=configurationFor(workspace,uri) then () else dirty workspace)
      | _=>let val parsed=settings platform value
           in if parsed=previous then () else (scoped:=(uri,parsed)::rest;index:=NONE;dirty workspace) end end
  (* Settings for many documents at once, each as one configureAt would leave
     them, the last in the list the newest. A worker's plan, so no generation moves. *)
  fun assign (Workspace {scoped,index,...},entries) =
    let val fresh=table (length entries)
        val ()=List.app (fn (uri,value) => add (fresh,uri,value)) entries
    in scoped:=List.rev entries @ List.filter (fn (uri,_) => not (isSome (lookup (fresh,uri)))) (!scoped);index:=NONE end
  fun choose (Workspace {choices,generation,...},uri,id) =
    (choices:=(uri,id) :: List.filter (fn (document,_) => document<>uri) (!choices);
     generation:=IntInf.+(!generation,1))
  fun folder value =
    let val value=J.object value
        val uri=J.string (J.required (value,"uri"))
        val _=J.string (J.required (value,"name"))
    in uri end
  fun initRoots platform value =
    let fun legacy ()=case J.member (value,"rootUri") of SOME (Json.String uri) => [uri]
          | _ => (case J.member (value,"rootPath") of SOME (Json.String path) => [U.original (U.fromPath (platform,path))] | _ => [])
    in
    case J.member (value,"workspaceFolders") of
      SOME (Json.Array folders) => List.map folder folders
    | SOME Json.Null => legacy ()
    | NONE => legacy ()
    | _ => invalid "invalid workspaceFolders" end
  fun initialize (workspace as Workspace {platform,...},value) =
    let val ()=setRoots (workspace,initRoots platform value)
    in case J.member (value,"initializationOptions") of NONE => () | SOME Json.Null => ()
      | SOME options => configure (workspace,options) end
  fun foldersChanged (workspace as Workspace {roots=stored,...},value) =
    let val event=J.object (J.required (J.object value,"event"))
        fun folders key=case J.required (event,key) of Json.Array values =>
          List.map folder values
          | _ => invalid "workspace folder changes must be arrays"
        val removed=folders "removed"
        val added=folders "added"
        val kept=List.filter (fn root => not (List.exists (fn uri => root=uri) removed)) (!stored)
    in setRoots (workspace,kept @ List.filter (fn uri => not (List.exists (fn root => root=uri) kept)) added) end
  fun below (root,path)=root=path orelse String.isPrefix (if String.isSuffix "/" root then root else root ^ "/") path
  (* What a path is known by: remembered, for a path's key does not change
     where the path alone gives it (at most a million) *)
  val known=store () : string store
  fun pathKey platform path =
    let val name=(if platform=U.Windows then "w:" else "p:") ^ path
    in case fetch (known,name) of SOME key => key | NONE =>
       let val (uri,pure)=(U.fromPath (platform,path),true) handle U.Invalid => (U.fromPath (platform,OS.FileSys.fullPath path),false)
           val key=case U.native (platform,uri) of SOME {key,...} => key | NONE => path
       in if pure andalso stored known<1000000 then keep (known,name,key) else ();key end end
    handle OS.SysErr _ => path
  (* The file a key names, remembered where the client's events would say
     that it changed (vouch, which the worker sets, and unknow, which it
     calls as it brings those up to date, D28); elsewhere looked at again *)
  (* A key with its ".." arcs taken out, as a client's events name a file:
     NONE where one would climb above its root *)
  fun lexical key=
    let val (head,body)=
          if String.isPrefix "//" key then
            let fun slash (at,n)=if at>=size key then size key else if String.sub (key,at)= #"/" then (if n=1 then at else slash (at+1,n-1)) else slash (at+1,n)
                val stop=slash (2,2)
            in (String.substring (key,0,Int.min (size key,stop+1)),String.extract (key,Int.min (size key,stop+1),NONE)) end
          else if size key>=3 andalso String.sub (key,1)= #":" andalso String.sub (key,2)= #"/" then (String.substring (key,0,3),String.extract (key,3,NONE))
          else if String.isPrefix "/" key then ("/",String.extract (key,1,NONE)) else ("",key)
        fun clean ([],kept)=SOME (List.rev kept)
          | clean (".."::rest,_::kept)=clean (rest,kept)
          | clean (".."::_,[])=NONE
          | clean (arc::rest,kept)=if arc="" orelse arc="." then clean (rest,kept) else clean (rest,arc::kept)
    in Option.map (fn arcs => head ^ String.concatWith "/" arcs) (clean (String.fields (fn c => c= #"/") body,[])) end
  (* The key by which a client's file events name what a path names: its key,
     or with its ".." arcs taken out where that is the same file (it is not
     through a symbolic link to a directory), remembered; NONE where not. *)
  val eventKeys=store () : string option store
  fun eventKey platform path=
    let val key=pathKey platform path
    in if not (String.isSubstring ".." key) then SOME key else
       case fetch (eventKeys,key) of SOME known => known | NONE =>
       if not (List.exists (fn arc => arc="..") (String.fields (fn c => c= #"/") key)) then SOME key else
       let val clean=case lexical key of NONE => NONE | SOME clean =>
             ((if OS.FileSys.compare (OS.FileSys.fileId path,OS.FileSys.fileId clean)=EQUAL then SOME clean else NONE)
              handle OS.SysErr _ => NONE)
       in if stored eventKeys<1000000 then keep (eventKeys,key,clean) else ();clean end end
  val identities=store () : OS.FileSys.file_id option store
  (* the key by which events vouch for a file, where they do; the worker says *)
  val vouch=ref (fn _ : string => NONE : string option)
  fun unknow NONE=empty identities
    | unknow (SOME keys)=List.app (fn key => remove (identities,key)) keys
  fun identityOf (path,_)=
    let fun look ()=SOME (OS.FileSys.fileId path) handle OS.SysErr _ => NONE
    in case !vouch path of NONE => look () | SOME key =>
       case fetch (identities,key) of SOME id => id | NONE => let val id=look () in keep (identities,key,id);id end end
  (* whether a path names a file, its key and its file found once *)
  fun sameAs platform path=
    let val key=pathKey platform path
        val id=ref NONE : OS.FileSys.file_id option option ref
        fun mine ()=case !id of SOME known => known | NONE => let val known=identityOf (path,key) in id:=SOME known;known end
    in fn other => let val otherKey=pathKey platform other
       in otherKey=key orelse (case mine () of NONE => false
            | SOME a => case identityOf (other,otherKey) of SOME b => OS.FileSys.compare (a,b)=EQUAL | NONE => false) end end
  (* the path of a file URI, remembered, for it does not change *)
  val uriPaths=store () : string store
  fun uriPath platform uri=
    let val name=(if platform=U.Windows then "w:" else "p:") ^ uri
    in case fetch (uriPaths,name) of SOME path => path | NONE =>
       let val path=filePath platform uri in if stored uriPaths<1000000 then keep (uriPaths,name,path) else ();path end end
  (* Files the client's watcher says changed (workspace/didChangeWatchedFiles):
     a plan made at an input generation sees what changed since without a
     look at the disk, where the client watches (D28). The last 4096 are
     kept; a plan older than the newest dropped looks at the disk. *)
  val changeLimit=4096
  fun changed (workspace as Workspace {platform,inputGeneration,changes,changeFloor,...},files : (string*bool) list) =
    let val ()=dirty workspace
        val generation= !inputGeneration
        val keys=List.map (fn (uri,moved) => (nativeKey platform uri,moved)) files
        val all=List.map (fn (key,moved) => (generation,getOpt (key,""),moved)) keys @ !changes
    in if List.exists (not o isSome o #1) keys then (changes:=[];changeFloor:=generation)
       else if length all<=changeLimit then changes:=all
       else (changes:=List.take (all,changeLimit);changeFloor:= #1 (List.nth (all,changeLimit))) end
  (* the keys of the files that changed since generation, each with whether
     it came or went, where the list says *)
  fun changedSince (Workspace {changes,changeFloor,...},generation)=
    if IntInf.< (generation,!changeFloor) then NONE
    else SOME (List.map (fn (_,key,moved) => (key,moved)) (List.filter (fn (g,_,_) => IntInf.> (g,generation)) (!changes)))
  (* What a client's watcher reports (RuneLspController.watch): a file of these
     names, and a directory, by what is created in it and removed from it *)
  fun watchable path=
    List.exists (fn suffix => String.isSuffix suffix path) [".sml",".sig",".fun",".build","/MANIFEST","/rune.workspace","\\MANIFEST","\\rune.workspace"]
    orelse path="MANIFEST" orelse path="rune.workspace"
  fun sameFile platform (left,right)=sameAs platform right left
  fun directory platform path = if platform<>U.Windows then OS.Path.dir path else
    let val path=String.map (fn #"\\" => #"/" | c => c) path
        fun last i=if i<0 then NONE else if String.sub (path,i)= #"/" then SOME i else last (i-1)
    in case last (size path-1) of NONE => "." | SOME 0 => "/"
      | SOME 2 => if String.sub (path,1)= #":" then String.substring (path,0,3) else String.substring (path,0,2)
      | SOME at => String.substring (path,0,at) end
  fun join platform (directory,path)=if platform=U.Windows then
    directory ^ (if String.isSuffix "/" directory then "" else "/") ^ path else OS.Path.concat (directory,path)
  fun basisBuild platform root=join platform(join platform(root,"basis"),"library.build")
  fun isBasisBuild platform (root,file)=sameFile platform(file,basisBuild platform root)
  fun parent platform path =
    let val directory=directory platform path in if directory=path orelse directory="" then NONE else SOME directory end
  fun buildFiles platform directory =
    let val stream=OS.FileSys.openDir directory
        fun read result=case OS.FileSys.readDir stream of NONE => result | SOME file =>
          read (if String.isSuffix ".build" file then join platform (directory,file) :: result else result)
        val files=(read [] before OS.FileSys.closeDir stream)
          handle e => (OS.FileSys.closeDir stream handle _ => ();raise e)
        fun insert (x,[])= [x] | insert (x,y::rest)=if x<y then x::y::rest else y::insert (x,rest)
    in List.foldl insert [] files end handle OS.SysErr _ => []
  (* the directories a file's builds are looked for in: its own and those above
     it, up to the folder of the client that holds it *)
  fun directories (Workspace {platform,roots,...},path) =
    let val key=pathKey platform path
        val applicable=List.filter (fn root => case nativeKey platform root of SOME root => below (root,key) | NONE => false) (!roots)
        fun ancestors (directory,boundary,seen) =
          if List.exists (fn previous => previous=directory) seen then [] else
          directory :: (if pathKey platform directory=boundary then [] else
            case parent platform directory of NONE => [] | SOME next =>
              if below (boundary,pathKey platform next) then ancestors (next,boundary,directory::seen) else [])
        val starts=case applicable of [] => [(directory platform path,pathKey platform (directory platform path))]
          | roots => List.map (fn root => (directory platform path,valOf (nativeKey platform root))) roots
    in List.concat (List.map (fn (directory,boundary) => ancestors (directory,boundary,[])) starts) end
  fun discover (workspace as Workspace {platform,...},path) =
    let val files=List.concat (List.map (buildFiles platform) (directories (workspace,path)))
    in List.foldl (fn (file,result) => if List.exists (fn prior => prior=file) result then result else result @ [file]) [] files end
  (* The root file a build is under, which its units are named from. *)
  fun rootFile platform build=C.Workspace.find {file=build,windows=platform=U.Windows}
  (* What a plan may take of a build file without reading it, and what it is
     told of each it reads (RuneLspWorkerAnalysis keeps those texts, while
     the client's events or their stamps say that they stand, D28); and how
     many builds have been read, for a bench. *)
  val holding=ref {held=fn _ : string => NONE : string option,read=fn _ : string*string => ()}
  val buildsRead=ref 0
  fun readProject (session,request)=
    let val {held,read}= !holding
    in C.Project.readHolding (session,request,{held=held,read=fn file => (buildsRead:= !buildsRead+1;read file)}) end
  (* and the text of one open in the editor where it is, saved or not *)
  fun rootFileIn (platform,documents) build =
    let val windows=platform=U.Windows
        fun opened path=List.find (fn snapshot:D.snapshot => D.healthy (documents,#uri snapshot) andalso
          ((case U.native (platform,U.parse (#uri snapshot)) of SOME {path=other,...} => sameFile platform (other,path)
            | NONE => false) handle U.Invalid => false)) (D.all documents)
        fun first []=NONE
          | first (path::rest)=case opened path of
              SOME snapshot => SOME (C.Workspace.read {file=path,text=LspPosition.text (#content snapshot),windows=windows})
            | NONE => if (OS.FileSys.access (path,[]) handle OS.SysErr _ => false) then rootFile platform build else first rest
    in first (C.Workspace.candidates {file=build,windows=windows}) end
  (* The targets a root file names. A file's contexts take them wherever the
     client's folder is, above the root or below it; a sweep of a folder
     inside a workspace (within) takes its builds from discovery alone. A
     root file that does not read shows at its builds. *)
  fun namedTargets (Workspace {platform,roots,...},documents,path,flags,within) =
    (case rootFileIn (platform,documents) path of NONE => [] | SOME found =>
      let val root=pathKey platform (C.Workspace.root found)
          fun holds folder=case nativeKey platform folder of SOME folder => below (folder,root) | NONE => false
      in if within andalso not (List.exists holds (!roots)) then [] else
         List.map (fn {name,build,options} => let val uri=U.original (U.fromPath (platform,build))
           in {name=name,build=uri,flags=flags @ options,variables=[],libraryRoot=NONE}:target end) (C.Workspace.targets found) end)
    handle C.Failed _ => [] | U.Invalid => []
  (* those, then the builds found that they do not name *)
  fun withNamed (workspace,documents,path,flags,found:target list,within) =
    let val named=namedTargets (workspace,documents,path,flags,within)
    in named @ List.filter (fn target:target => not (List.exists (fn other:target => #build other= #build target) named)) found end
  (* Whether a file of a library has that one context (D26): off only to
     measure what was before (tools/lsp/contexts.sml --before) *)
  val owners=ref true
  (* The build of the library a file is of: the deepest directory above it
     with a library.build, as its unit's name says (docs/units.md, Names) *)
  fun ownerBuild platform path =
    let fun up (directory,seen)=
          let val build=join platform (directory,"library.build")
          in if (OS.FileSys.access (build,[]) handle OS.SysErr _ => false) then SOME build
             else case parent platform directory of NONE => NONE
               | SOME above => if List.exists (fn other => other=above) seen orelse length seen>64 then NONE
                   else up (above,directory::seen) end
    in up (directory platform path,[]) end
  (* the contexts a target's project gives a file, one an occurrence of it *)
  (* where a file's name is one of names *)
  fun named names path=List.exists (fn name => path=name orelse String.isSuffix ("/" ^ name) path orelse
    String.isSuffix ("\\" ^ name) path) names
  fun contextsIn (platform,target:target,project,path)=contextsNamed (platform,target,project,path,NONE)
  (* those whose name is one of names, where it is known that only a file of
     such a name can be the file (RuneLspProjects.indexed) *)
  and contextsNamed (platform,target:target,project,path,names)=
    let val same=sameAs platform path
        val same=case names of NONE => same | SOME names => (fn other => named names other andalso same other) in
    List.map (fn source:C.Project.source =>
      {id= #build target ^ "#" ^ #name target ^ ":" ^ Int.toString (#ordinal source),
       label= #name target ^ " (unit " ^ Int.toString (#ordinal source+1) ^ ")",
       name=shortName (platform,#name target),build= #build target,
       target= #name target,ordinal= #ordinal source,project=project,source=source}:context)
      (List.filter (fn source:C.Project.source => same (#file source)) (C.Project.sources project)) end
  fun contexts (workspace as Workspace {platform,lib,settings=stored,...},documents,uri) =
    case U.native (platform,U.parse uri) of NONE => [] | SOME {path,key} =>
    let val config=configurationFor (workspace,uri)
        val targets=if null (#targets config) then withNamed (workspace,documents,path,#flags config,List.map (fn path =>
          let val uri=U.original (U.fromPath (platform,path))
          in {name=uri,build=uri,flags= #flags config,variables=[],libraryRoot=NONE}:target end) (discover (workspace,path)),false) else #targets config
        val overlays=List.mapPartial (fn snapshot:D.snapshot =>
          if not (D.healthy (documents,#uri snapshot)) then NONE else
          case U.native (platform,U.parse (#uri snapshot)) of NONE => NONE
          | SOME {path,...} => SOME {file=path,text=LspPosition.text (#content snapshot)}) (D.all documents)
        fun target (target:target) =
          let val session=C.session {lib=SOME (getOpt (#libraryRoot target,getOpt (#libraryRoot config,lib))),flags= #flags target}
              val build=filePath platform (#build target)
              val project=(readProject (session,{file=build,workspace=rootFileIn (platform,documents) build,
                variables= #variables config @ #variables target,overlays=overlays,windows=platform=U.Windows})
                before C.close session) handle e => (C.close session;raise e)
          in contextsIn (platform,target,project,path) end
        val found=List.concat (List.map (fn candidate =>
          if null (#targets config) then (target candidate handle C.Failed _ => []) else target candidate) targets)
        (* One owner (D26): a file of a library is checked in the library,
           whatever else holds it, a test's build among them, where the
           library holds it; unless the settings name the context to take. *)
        val found=if isSome (#activeContext config) orelse not (!owners) then found else
          case ownerBuild platform path of NONE => found | SOME build =>
            let val owned=List.filter (fn context:context => sameFile platform (filePath platform (#build context),build)) found
                val owned=if not (null owned) then owned else
                  let val uri=U.original (U.fromPath (platform,build))
                  in target {name=uri,build=uri,flags= #flags config,variables=[],libraryRoot=NONE} handle C.Failed _ => [] end
            in if null owned then found else owned end
        val basis=join platform (getOpt(#libraryRoot config,lib),"basis")
        val build=basisBuild platform (getOpt(#libraryRoot config,lib))
    in if not(null found) orelse not(below(pathKey platform basis,key)) then found
       else let val location=U.fromPath(platform,build) handle U.Invalid=>U.fromPath(platform,OS.FileSys.fullPath build)
            in target {name="basis",build=U.original location,flags= #flags config,
              variables=[],libraryRoot= #libraryRoot config} end handle C.Failed _=>found end
  (* which of a file's contexts it is checked in: the one chosen, or the
     only one, or the client is asked *)
  fun selectAmong (workspace as Workspace {platform,lib,choices,...},uri,contexts) =
    let val active=case List.find (fn (document,_) => document=uri) (!choices) of SOME (_,id) => SOME id
          | NONE => #activeContext (configurationFor (workspace,uri))
        val selection=case active of SOME id =>
         (case List.filter (fn context:context => #id context=id orelse #target context=id) contexts of
           [context] => Selected context
          | _ => case contexts of []=>Loose | [context]=>
              if isBasisBuild platform(getOpt(#libraryRoot(configurationFor(workspace,uri)),lib),filePath platform(#build context))
              then Selected context else Ambiguous contexts
            | _=>Ambiguous contexts)
       | NONE => case contexts of [] => Loose | [context] => Selected context | _ => Ambiguous contexts
    in selection end
  fun resolve (workspace,documents,uri) =
    let val contexts=contexts (workspace,documents,uri)
    in (selectAmong (workspace,uri,contexts),contexts) end
  fun select arguments= #1 (resolve arguments)
  (* The context of a file in no build: the implicit library a build at a
     place no file has names (RuneLspImplicit), read through an overlay *)
  fun implicitContext (workspace as Workspace {platform,lib,...},documents,uri,{build,text}) : context option =
    case U.native (platform,U.parse uri) of NONE => NONE | SOME {path,...} =>
    let val config=configurationFor (workspace,uri)
        val overlays={file=build,text=text} :: List.mapPartial (fn snapshot:D.snapshot =>
          if not (D.healthy (documents,#uri snapshot)) then NONE else
          case U.native (platform,U.parse (#uri snapshot)) of NONE => NONE
          | SOME {path,...} => SOME {file=path,text=LspPosition.text (#content snapshot)}) (D.all documents)
        val session=C.session {lib=SOME (getOpt (#libraryRoot config,lib)),flags= #flags config}
        val project=(readProject (session,{file=build,workspace=rootFileIn (platform,documents) path,
          variables= #variables config,overlays=overlays,windows=platform=U.Windows}) before C.close session)
          handle e => (C.close session;raise e)
        val buildUri=U.original (U.fromPath (platform,build))
    in case List.find (fn source:C.Project.source => sameFile platform (#file source,path)) (C.Project.sources project) of
         NONE => NONE
       | SOME source => SOME {id=buildUri ^ "#implicit:" ^ Int.toString (#ordinal source),
           label="its directory, and where the names it uses are declared (" ^
             Int.toString (length (C.Project.sources project)) ^ " files)",
           name="implicit",build=buildUri,target="implicit",ordinal= #ordinal source,project=project,source=source} end
    handle C.Failed _ => NONE | U.Invalid => NONE
end

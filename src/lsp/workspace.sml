(* Workspace settings and build contexts. Project planning stays behind the
   compiler library; the adapter owns URI conversion and client choices. *)
structure RuneLspWorkspace =
struct
  structure J=RuneLspSync
  structure U=LspUri
  structure D=RuneLspDocuments
  structure C=RuneCompiler
  type target={name:string,build:string,flags:string list,variables:(string*string) list,libraryRoot:string option}
  type settings={targets:target list,flags:string list,variables:(string*string) list,activeContext:string option,libraryRoot:string option}
  type context={id:string,label:string,target:string,build:string,ordinal:int,project:C.Project.t,source:C.Project.source}
  datatype selection=Loose | Selected of context | Ambiguous of context list
  datatype t=Workspace of {platform:U.platform,lib:string,roots:string list ref,settings:settings ref,scoped:(string*settings) list ref,
    generation:IntInf.int ref,choices:(string*string) list ref}
  exception Invalid of string
  val defaults:settings={targets=[],flags=[],variables=[],activeContext=NONE,libraryRoot=NONE}
  fun invalid message=raise Invalid message
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
  fun new {platform,lib} = Workspace {platform=platform,lib=lib,roots=ref [],settings=ref defaults,scoped=ref [],
    generation=ref 0,choices=ref []}
  fun generation (Workspace {generation,...})= !generation
  fun invalidate (Workspace {generation,choices,...}) = (generation:=IntInf.+ (!generation,1);choices:=[])
  fun dirty (Workspace {generation,...}) = generation:=IntInf.+ (!generation,1)
  fun roots (Workspace {roots,...})= !roots
  fun setRoots (workspace as Workspace {platform,roots,...},values) =
    let val ()=if length values>64 then invalid "too many workspace folders" else ()
        val ()=List.app (fn uri => ignore (U.parse uri)) values
        val unique=List.foldl (fn (uri,all) => if List.exists (fn prior => prior=uri) all then all else all @ [uri]) [] values
    in roots:=unique;invalidate workspace end
  fun configure (workspace as Workspace {platform,settings=stored,...},value) =
    let val parsed=settings platform value
    in if parsed= !stored then () else (stored:=parsed;invalidate workspace) end
  fun forget (Workspace {scoped,choices,...},uri) =
    (scoped:=List.filter (fn (scope,_) => scope<>uri) (!scoped);
     choices:=List.filter (fn (document,_) => document<>uri) (!choices))
  fun configurationFor (Workspace {platform,settings,scoped,...},uri) =
    case List.find (fn (scope,_) => scope=uri) (!scoped) of SOME (_,settings) => settings
    | NONE =>
        let val key=nativeKey platform uri
            fun contains scope = case (nativeKey platform scope,key) of
              (SOME root,SOME file) => root=file orelse String.isPrefix (if String.isSuffix "/" root then root else root ^ "/") file
            | _ => false
            val roots=List.filter (fn (scope,_) => contains scope) (!scoped)
            fun nearest (current as (scope,_),NONE)=SOME current
              | nearest (current as (scope,_),old as SOME (prior,_))=
                  if size (valOf (nativeKey platform scope))>size (valOf (nativeKey platform prior)) then SOME current else old
        in case List.foldl nearest NONE roots of SOME (_,settings) => settings | NONE => !settings end
  fun configureAt (workspace as Workspace {platform,scoped,...},uri,value) =
    let val previous=configurationFor(workspace,uri)
        val rest=List.filter(fn (scope,_)=>scope<>uri)(!scoped)
    in case value of Json.Null=>
        (scoped:=rest;if previous=configurationFor(workspace,uri) then () else dirty workspace)
      | _=>let val parsed=settings platform value
           in if parsed=previous then () else (scoped:=(uri,parsed)::rest;dirty workspace) end end
  fun choose (Workspace {choices,...},uri,id) =
    choices:=(uri,id) :: List.filter (fn (document,_) => document<>uri) (!choices)
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
  fun pathKey platform path =
    let val uri=U.fromPath (platform,path) handle U.Invalid => U.fromPath (platform,OS.FileSys.fullPath path)
    in case U.native (platform,uri) of SOME {key,...} => key | NONE => path end
    handle OS.SysErr _ => path
  fun sameFile platform (left,right) =
    pathKey platform left=pathKey platform right orelse
      ((OS.FileSys.compare (OS.FileSys.fileId left,OS.FileSys.fileId right)=EQUAL) handle OS.SysErr _ => false)
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
  fun discover (Workspace {platform,roots,...},path) =
    let val key=pathKey platform path
        val applicable=List.filter (fn root => case nativeKey platform root of SOME root => below (root,key) | NONE => false) (!roots)
        fun ancestors (directory,boundary,seen) =
          if List.exists (fn previous => previous=directory) seen then [] else
          buildFiles platform directory @ (if pathKey platform directory=boundary then [] else
            case parent platform directory of NONE => [] | SOME next =>
              if below (boundary,pathKey platform next) then ancestors (next,boundary,directory::seen) else [])
        val directories=case applicable of [] => [(directory platform path,pathKey platform (directory platform path))]
          | roots => List.map (fn root => (directory platform path,valOf (nativeKey platform root))) roots
        val files=List.concat (List.map (fn (directory,boundary) => ancestors (directory,boundary,[])) directories)
    in List.foldl (fn (file,result) => if List.exists (fn prior => prior=file) result then result else result @ [file]) [] files end
  fun contexts (workspace as Workspace {platform,lib,settings=stored,...},documents,uri) =
    case U.native (platform,U.parse uri) of NONE => [] | SOME {path,key} =>
    let val config=configurationFor (workspace,uri)
        val targets=if null (#targets config) then List.map (fn path =>
          let val uri=U.original (U.fromPath (platform,path))
          in {name=uri,build=uri,flags= #flags config,variables=[],libraryRoot=NONE}:target end) (discover (workspace,path)) else #targets config
        val overlays=List.mapPartial (fn snapshot:D.snapshot =>
          if not (D.healthy (documents,#uri snapshot)) then NONE else
          case U.native (platform,U.parse (#uri snapshot)) of NONE => NONE
          | SOME {path,...} => SOME {file=path,text=LspPosition.text (#content snapshot)}) (D.all documents)
        fun target (target:target) =
          let val session=C.session {lib=SOME (getOpt (#libraryRoot target,getOpt (#libraryRoot config,lib))),flags= #flags target}
              val project=(C.Project.read (session,{file=filePath platform (#build target),
                variables= #variables config @ #variables target,overlays=overlays,windows=platform=U.Windows})
                before C.close session) handle e => (C.close session;raise e)
              val sources=List.filter (fn source:C.Project.source => sameFile platform (#file source,path)) (C.Project.sources project)
          in List.map (fn source:C.Project.source =>
            {id= #build target ^ "#" ^ #name target ^ ":" ^ Int.toString (#ordinal source),
             label= #name target ^ " (unit " ^ Int.toString (#ordinal source+1) ^ ")",build= #build target,
             target= #name target,ordinal= #ordinal source,project=project,source=source}:context) sources end
        val found=List.concat (List.map (fn candidate =>
          if null (#targets config) then (target candidate handle C.Failed _ => []) else target candidate) targets)
        val basis=join platform (getOpt(#libraryRoot config,lib),"basis")
        val build=basisBuild platform (getOpt(#libraryRoot config,lib))
    in if not(null found) orelse not(below(pathKey platform basis,key)) then found
       else let val location=U.fromPath(platform,build) handle U.Invalid=>U.fromPath(platform,OS.FileSys.fullPath build)
            in target {name="basis",build=U.original location,flags= #flags config,
              variables=[],libraryRoot= #libraryRoot config} end handle C.Failed _=>found end
  fun select (workspace as Workspace {platform,lib,settings=stored,choices,...},documents,uri) =
    let val contexts=contexts (workspace,documents,uri)
        val active=case List.find (fn (document,_) => document=uri) (!choices) of SOME (_,id) => SOME id
          | NONE => #activeContext (configurationFor (workspace,uri))
    in case active of SOME id =>
         (case List.filter (fn context:context => #id context=id orelse #target context=id) contexts of
           [context] => Selected context
          | _ => case contexts of []=>Loose | [context]=>
              if isBasisBuild platform(getOpt(#libraryRoot(configurationFor(workspace,uri)),lib),filePath platform(#build context))
              then Selected context else Ambiguous contexts
            | _=>Ambiguous contexts)
       | NONE => case contexts of [] => Loose | [context] => Selected context | _ => Ambiguous contexts end
end

(* The compiler's scoped project model. Input callbacks let command-line
   builds and editor overlays share source ordering and annotations. *)
structure CompilerProject =
struct
  datatype step=SUnit of string * string list
    | SLocal of step list * step list
    | SLibrary of (BuildFile.kind * string) list * step list
    | SUse of string * step list
    | SImplements of string * step list
  type input={path:string,text:string,revision:string}
  (* references: each path a build file names of a source or of a build file,
     with the build file, as the build file spells them but for the directory *)
  type plan={steps:step list,caches:string list,libraries:string list,inputs:input list,inline:string list,
             inlineValues:string list,references:(string*string) list}
  exception Invalid of string
  fun modeOf (default,annotations)=List.foldl (fn (annotation,mode) =>
    getOpt (Source.modeNamed annotation,mode)) default annotations
  fun alpha c=(c>= #"a" andalso c<= #"z") orelse (c>= #"A" andalso c<= #"Z")
  fun lower text=String.map (fn c => if c>= #"A" andalso c<= #"Z" then Char.chr (Char.ord c+32) else c) text
  fun normalize windows path =
    if not windows then path else
      let val path=String.map (fn #"\\" => #"/" | c => c) path
      in if String.size path>=2 andalso alpha (String.sub (path,0)) andalso String.sub (path,1)= #":" then
           String.str (Char.toUpper (String.sub (path,0))) ^ String.extract (path,1,NONE)
         else if String.isPrefix "//" path then
           let fun stop i=if i=String.size path orelse String.sub (path,i)= #"/" then i else stop (i+1)
               val at=stop 2
           in "//" ^ lower (String.substring (path,2,at-2)) ^ String.extract (path,at,NONE) end
         else path end
  (* The selected project syntax is independent of the host OS.Path. This
     also lets a Windows server inspect a POSIX build using decoded overlays. *)
  fun drive path = size path>=2 andalso alpha (String.sub (path,0)) andalso String.sub (path,1)= #":"
  fun absolute windows path =
    let val path=normalize windows path
    in String.isPrefix "/" path orelse
      (windows andalso drive path andalso size path>=3 andalso String.sub (path,2)= #"/") end
  fun directory windows path =
    let val path=normalize windows path
        fun last i=if i<0 then NONE else if String.sub (path,i)= #"/" then SOME i else last (i-1)
    in case last (size path-1) of
       NONE => if windows then (if drive path then String.substring (path,0,2) else ".") else ""
     | SOME 0 => "/"
     | SOME 2 => if windows andalso drive path then String.substring (path,0,3) else String.substring (path,0,2)
     | SOME at => String.substring (path,0,at) end
  fun concat windows (directory,path) =
    let val directory=normalize windows directory
        val path=normalize windows path
        val path=if windows andalso drive path then
          if drive directory andalso lower (String.substring (directory,0,2))=lower (String.substring (path,0,2))
          then String.extract (path,2,NONE) else raise Invalid "relative build path uses a different drive"
          else path
        val root=directory="/" orelse (windows andalso drive directory andalso size directory=3) orelse
          (windows andalso String.isPrefix "//" directory andalso
           (case String.fields (fn c => c = #"/") (String.extract (directory,2,NONE)) of
              [server,share,""] => server<>"" andalso share<>"" | _ => false))
    in if directory="" then path
       else if path="" then
         if not root andalso String.isSuffix "/" directory then String.substring (directory,0,size directory-1) else directory
       else directory ^ (if String.isSuffix "/" directory orelse windows andalso drive directory andalso size directory=2 then "" else "/") ^ path
    end
  fun pathKey windows path =
    let val path=normalize windows path
        val n=size path
        fun next i=if i=n orelse String.sub (path,i)= #"/" then i else next (i+1)
        val network=if windows andalso String.isPrefix "//" path then
          let val server=next 2
              val share=if server<n then next (server+1) else server
          in if server>2 andalso server<n andalso share>server+1 then SOME share else NONE end else NONE
        val (root,body,rooted)=case network of
            SOME stop => (String.substring (path,0,stop) ^ "/",String.extract (path,Int.min (n,stop+1),NONE),true)
          | NONE => if windows andalso drive path then
              if n>2 andalso String.sub (path,2)= #"/" then (String.substring (path,0,3),String.extract (path,3,NONE),true)
              else (String.substring (path,0,2),String.extract (path,2,NONE),false)
            else if String.isPrefix "/" path then ("/",String.extract (path,1,NONE),true) else ("",path,false)
        fun clean ([],kept)=List.rev kept
          | clean (arc::rest,kept)=if arc="" orelse arc="." then clean (rest,kept)
            else if arc=".." then (case kept of
                [] => clean (rest,if rooted then [] else [".."])
              | ".."::_ => clean (rest,".."::kept)
              | _::above => clean (rest,above))
            else clean (rest,arc::kept)
        val arcs=clean (String.fields (fn c => c = #"/") body,[])
    in root ^ (if null arcs andalso not rooted then "." else String.concatWith "/" arcs) end
  fun inputKey windows path =
    String.concatWith "/" (List.filter (fn arc => arc<>".")
      (String.fields (fn c => c = #"/") (normalize windows path)))
  fun plan {file,defaultMode,windows,readBuild,syntax} : plan =
    let val file=normalize windows file
        val root=directory windows file
        val caches=ref []
        val libraries=ref []
        val inline=ref [] : string list ref
        val inlineValues=ref [] : string list ref
        val inputs=ref [] : input list ref
        val references=ref [] : (string*string) list ref
        val captured=ref StringMap.empty : input StringMap.map ref
        val completed=ref StringMap.empty : step list StringMap.map ref
        fun capture path =
          let val key=pathKey windows path
          in case StringMap.find (!captured,key) of SOME input => #text input
           | NONE => let val {text,revision}=readBuild path
                         val input={path=path,text=text,revision=revision}
                         val ()=(captured:=StringMap.insert (!captured,key,input);inputs:=input :: !inputs)
                     in text end end
        fun read (file,stack,annotations) =
          let val key=pathKey windows file
              val ()=if List.exists (fn previous => previous=key) stack then raise Invalid ("the build file " ^ file ^ " uses itself") else ()
          in case StringMap.find (!completed,key) of SOME steps => steps | NONE =>
          let
              val declarations=BuildFile.parse (file,capture file)
              val here=directory windows file
              fun path name=normalize windows (BuildFile.expandFrom {isAbsolute=absolute windows,concat=concat windows,root=root} (here,name))
                handle BuildFile.Error message => raise Invalid (file ^ ": " ^ message)
              (* a path the build file itself chooses, not a variable *)
              fun named name=
                let val target=path name
                in if String.isPrefix "$(" name then () else references:=(file,target) :: !references;target end
              fun steps (annotations,declarations)=List.concat (List.map (fn declaration => step (annotations,declaration)) declarations)
              and step (annotations,declaration)=
                case declaration of
                  BuildFile.File name => [SUnit (named name,annotations)]
                | BuildFile.Files names => List.map (fn name => SUnit (named name,annotations)) names
                | BuildFile.Group names =>
                    let val analysed=List.map (fn name => let val file=named name
                          in Deps.analyse (file,syntax (modeOf (defaultMode,annotations),file)) end) names
                        val broken=List.concat (List.map (fn f:Deps.file => List.map (fn (span,what) =>
                          Error.format (span,"a file of a group declares modules and type abbreviations only, and this is " ^ what)) (#breaks f)) analysed)
                        val ()=case broken of [] => () | message :: _ => raise Invalid message
                        val (ordered,_)=Deps.order analysed handle Deps.Graph message => raise Invalid (file ^ ": " ^ message)
                    in List.map (fn f:Deps.file => SUnit (#path f,annotations)) ordered end
                | BuildFile.Local (a,b) => [SLocal (steps (annotations,a),steps (annotations,b))]
                | BuildFile.Library (exports,declarations) => [SLibrary (exports,steps (annotations,declarations))]
                | BuildFile.Use name => let val included=named name
                    in [SUse (pathKey windows included,read (included,key :: stack,annotations))] end
                | BuildFile.Implements (name,declarations) => [SImplements (name,steps (annotations,declarations))]
                | BuildFile.Annotate (more,declarations) => steps (annotations @ more,declarations)
                | BuildFile.Cache cache => (caches:=path cache :: !caches;[])
                | BuildFile.Libraries names => (libraries:= !libraries @ names;[])
                | BuildFile.Inline names => (inline:= !inline @ names;[])
                | BuildFile.InlineVal names => (inlineValues:= !inlineValues @ names;[])
              val result=steps (annotations,declarations)
              val ()=completed:=StringMap.insert (!completed,key,result)
          in result end end
        val steps=read (file,[],[])
    in {steps=steps,caches=List.rev (!caches),libraries= !libraries,inputs=List.rev (!inputs),inline= !inline,
        inlineValues= !inlineValues,references=List.rev (!references)} end
    handle BuildFile.Error message => raise Invalid message | Deps.Graph message => raise Invalid message
  (* Reaching in (docs/build.md, D10): a directory with a library.build is a
     library, the deepest over a path being its own, and a library is reached
     through its interface. What each build file names under a library not its
     own, by the build file and the library, with how many paths; isLibrary
     says whether a directory has one. A generated pointer -- current.build,
     naming the set it stands for under sets/ -- is left out: nobody wrote it,
     and what generates it goes with the FFI's migration (D15). *)
  fun reaches {references:(string*string) list,windows:bool,isLibrary:string -> bool} : (string*string*int) list =
    let
      val known=ref StringMap.empty : string option StringMap.map ref
      fun libraryOfDirectory dir =
        case StringMap.find (!known,dir) of
          SOME library => library
        | NONE =>
            let val up=directory windows dir
                val library=
                  if isLibrary (if dir="" then "." else dir) then SOME dir
                  else if up=dir orelse dir="" orelse dir="." orelse dir=".." orelse String.isSuffix "/.." dir then NONE
                  else libraryOfDirectory up
            in known:=StringMap.insert (!known,dir,library);library end
      fun libraryOf path=libraryOfDirectory (directory windows (pathKey windows path))
      fun pointer (build,target)=
        String.isSuffix "/current.build" ("/" ^ build) andalso
        String.isPrefix (pathKey windows (concat windows (directory windows build,"sets")) ^ "/") (pathKey windows target)
      fun note (reference as (build,target),found)=
        case libraryOf target of
          NONE => found
        | SOME library =>
            if libraryOf build=SOME library orelse pointer reference then found
            else
              let fun add []=[(build,library,1)]
                    | add ((b,l,n) :: rest)=if b=build andalso l=library then (b,l,n+1) :: rest else (b,l,n) :: add rest
              in add found end
    in List.foldl note [] references end
  fun units steps =
    let val used=ref [] : string list ref
        fun all steps=List.concat (List.map one steps)
        and one (SUnit unit)=[unit]
          | one (SLocal (a,b))=all a @ all b
          | one (SLibrary (_,steps))=all steps
          | one (SImplements (_,steps))=all steps
          | one (SUse (file,steps))=if List.exists (fn prior => prior=file) (!used) then []
            else (used:=file :: !used;all steps)
    in all steps end
  fun files steps=List.map #1 (units steps)
end

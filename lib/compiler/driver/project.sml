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
  type plan={steps:step list,caches:string list,libraries:string list,inputs:input list}
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
  fun absolute windows path = OS.Path.isAbsolute path orelse
    (windows andalso ((String.size path>0 andalso String.sub (path,0)= #"\\") orelse
      (String.size path>=3 andalso alpha (String.sub (path,0)) andalso
       String.sub (path,1)= #":" andalso Char.contains "/\\" (String.sub (path,2)))))
  fun directory windows path = if not windows then OS.Path.dir path else
    let val path=normalize true path
        fun last i=if i<0 then NONE else if String.sub (path,i)= #"/" then SOME i else last (i-1)
    in case last (size path-1) of NONE => "." | SOME 0 => "/"
     | SOME 2 => if String.sub (path,1)= #":" then String.substring (path,0,3) else String.substring (path,0,2)
     | SOME at => String.substring (path,0,at) end
  fun concat windows (directory,path) = if not windows then OS.Path.concat (directory,path)
    else directory ^ (if String.isSuffix "/" directory then "" else "/") ^ path
  fun pathKey windows path =
    if windows andalso String.isPrefix "//" path then
      "//" ^ OS.Path.mkCanonical (String.extract (path,2,NONE))
    else if windows andalso String.size path>=3 andalso String.sub (path,1)= #":" andalso String.sub (path,2)= #"/" then
      String.substring (path,0,2) ^ OS.Path.mkCanonical (String.extract (path,2,NONE))
    else OS.Path.mkCanonical path
  fun inputKey windows path =
    String.concatWith "/" (List.filter (fn arc => arc<>".")
      (String.fields (fn c => c = #"/") (normalize windows path)))
  fun plan {file,defaultMode,windows,readBuild,syntax} : plan =
    let val file=normalize windows file
        val caches=ref []
        val libraries=ref []
        val inputs=ref [] : input list ref
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
              val directory=directory windows file
              fun path name=normalize windows (BuildFile.expandUsing {isAbsolute=absolute windows,concat=concat windows} (directory,name))
                handle BuildFile.Error message => raise Invalid (file ^ ": " ^ message)
              fun steps (annotations,declarations)=List.concat (List.map (fn declaration => step (annotations,declaration)) declarations)
              and step (annotations,declaration)=
                case declaration of
                  BuildFile.File name => [SUnit (path name,annotations)]
                | BuildFile.Files names => List.map (fn name => SUnit (path name,annotations)) names
                | BuildFile.Group names =>
                    let val analysed=List.map (fn name => let val file=path name
                          in Deps.analyse (file,syntax (modeOf (defaultMode,annotations),file)) end) names
                        val broken=List.concat (List.map (fn f:Deps.file => List.map (fn (span,what) =>
                          Error.format (span,"a file of a group declares modules and type abbreviations only, and this is " ^ what)) (#breaks f)) analysed)
                        val ()=case broken of [] => () | message :: _ => raise Invalid message
                        val (ordered,_)=Deps.order analysed handle Deps.Graph message => raise Invalid (file ^ ": " ^ message)
                    in List.map (fn f:Deps.file => SUnit (#path f,annotations)) ordered end
                | BuildFile.Local (a,b) => [SLocal (steps (annotations,a),steps (annotations,b))]
                | BuildFile.Library (exports,declarations) => [SLibrary (exports,steps (annotations,declarations))]
                | BuildFile.Use name => let val included=path name
                    in [SUse (pathKey windows included,read (included,key :: stack,annotations))] end
                | BuildFile.Implements (name,declarations) => [SImplements (name,steps (annotations,declarations))]
                | BuildFile.Annotate (more,declarations) => steps (annotations @ more,declarations)
                | BuildFile.Cache directory => (caches:=path directory :: !caches;[])
                | BuildFile.Libraries names => (libraries:= !libraries @ names;[])
              val result=steps (annotations,declarations)
              val ()=completed:=StringMap.insert (!completed,key,result)
          in result end end
        val steps=read (file,[],[])
    in {steps=steps,caches=List.rev (!caches),libraries= !libraries,inputs=List.rev (!inputs)} end
    handle BuildFile.Error message => raise Invalid message | Deps.Graph message => raise Invalid message
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

(* The compiler's scoped project model: what one build file says, with what
   it uses, or what the command line says in its place. Input callbacks let
   command-line builds and editor overlays share source ordering and
   annotations. This is the reader of the build language: a library's index,
   a compile, an editor and the plan's text all go through it (D6). *)
structure CompilerProject =
struct
  datatype step=SUnit of string * string list
    | SLibrary of (BuildFile.kind * string) list * step list
    | SUse of string * step list
    | SImplements of string * step list
  type input={path:string,text:string,revision:string}
  (* references: each path a build file names of a source or of a build file,
     with the build file, as the build file spells them but for the directory *)
  (* header: the file's, where it is a library's; basis: what of the Basis
     Library a compile takes, demand (the default), all (--basis all) or none
     (--no-prelude), and view its view of it, if any (D12), which the command
     line says and a program's build file may: a plan says what a compile sees *)
  type plan={steps:step list,libraries:string list,header:BuildFile.header option,inputs:input list,inline:string list,
             inlineValues:string list,references:(string*string) list,basis:string,view:string option}
  exception Invalid of string
  fun modeOf (default,annotations)=List.foldl (fn (annotation,mode) =>
    getOpt (Source.modeNamed annotation,mode)) default annotations
  (* what a file is to a program, of a library (docs/build.md, A library's
     build file): the last that its annotations name *)
  fun classOf annotations=
    case List.filter (fn annotation => List.exists (fn class => class=annotation) ["always","demand","seal","final"]) annotations of
      [] => "demand" | classes => List.last classes
  (* what a command line says, which is a plan too: the files, in order, and
     the libraries *)
  fun ofFiles {files:string list,libraries:string list} : plan=
    {steps=List.map (fn file => SUnit (file,[])) files,libraries=libraries,header=NONE,inputs=[],inline=[],
     inlineValues=[],references=[],basis="demand",view=NONE}
  (* a plan with the Basis Library the command line says of it, beside what a
     build file says: two views are refused *)
  fun withBasis (p : plan,{basis:string,view:string option}) : plan=
    let val view=case (#view p,view) of
            (SOME a,SOME b) => if a=b then SOME a else raise Invalid ("the build's view of the Basis Library is " ^ a ^ ", and the command line's " ^ b)
          | (NONE,v) => v
          | (v,NONE) => v
    in {steps= #steps p,libraries= #libraries p,header= #header p,inputs= #inputs p,inline= #inline p,
        inlineValues= #inlineValues p,references= #references p,basis=basis,view=view} end
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
  fun fileName path=List.last (String.fields (fn c => c = #"/") path)
  (* a build file's plan as Rune compiles it; with hosts, with the files the
     other SML systems have alone too (host=only), which a library's index
     lists for them *)
  fun planWith {file,windows,readBuild,hosts:bool} : plan =
    let val file=normalize windows file
        val root=directory windows file
        val libraries=ref []
        val header=ref NONE : BuildFile.header option ref
        val inline=ref [] : string list ref
        val inlineValues=ref [] : string list ref
        val view=ref NONE : string option ref
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
              val library=fileName file="library.build"
              fun path name=normalize windows (BuildFile.expandFrom {isAbsolute=absolute windows,concat=concat windows,root=root} (here,name))
                handle BuildFile.Error message => raise Invalid (file ^ ": " ^ message)
              (* a path the build file itself chooses, not a variable *)
              fun named name=
                let val target=path name
                in if String.isPrefix "$(" name then () else references:=(file,target) :: !references;target end
              (* a file the other SML systems have alone is not Rune's *)
              fun unit (annotations,file)=
                if not hosts andalso List.exists (fn annotation => annotation="host=only") annotations then []
                else [SUnit (file,annotations)]
              fun steps (annotations,declarations)=List.concat (List.map (fn declaration => step (annotations,declaration)) declarations)
              and step (annotations,declaration)=
                case declaration of
                  BuildFile.File name => unit (annotations,named name)
                | BuildFile.Files names => List.concat (List.map (fn name => unit (annotations,named name)) names)
                | BuildFile.Library (exports,declarations) =>
                    (* a boundary is a library's: a directory with a library.build *)
                    if library then [SLibrary (exports,steps (annotations,declarations))]
                    else raise Invalid (file ^ ": a library's boundary belongs in its library.build")
                | BuildFile.Use name => let val included=named name
                    in [SUse (pathKey windows included,read (included,key :: stack,annotations))] end
                | BuildFile.Implements (name,declarations) => [SImplements (name,steps (annotations,declarations))]
                | BuildFile.Annotate (more,declarations) => steps (annotations @ more,declarations)
                | BuildFile.Libraries names =>
                    if isSome (!header) then raise Invalid (file ^ ": a library with a header says what it is written on with requires")
                    else (libraries:= !libraries @ names;[])
                | BuildFile.Header (given as {requires,...}) =>
                    if library then (if null stack then header:=SOME given else ();libraries:= !libraries @ requires;[])
                    else raise Invalid (file ^ ": a header belongs to a library's library.build")
                | BuildFile.Inline names => (inline:= !inline @ names;[])
                | BuildFile.InlineVal names => (inlineValues:= !inlineValues @ names;[])
                | BuildFile.View name =>
                    if library then raise Invalid (file ^ ": a view of the Basis Library is a program's; a library's own is a seal file inside its boundary")
                    else (case !view of
                            SOME other => if other=name then [] else raise Invalid (file ^ ": a program has one view of the Basis Library, and this build says " ^ other ^ " and " ^ name)
                          | NONE => (view:=SOME name;[]))
              val result=steps (annotations,declarations)
              val ()=if library andalso List.exists (fn SLibrary _ => true | _ => false) result andalso length result>1
                     then raise Invalid (file ^ ": all source files belong inside the library export boundary") else ()
              val ()=completed:=StringMap.insert (!completed,key,result)
          in result end end
        val steps=read (file,[],[])
    in {steps=steps,libraries= !libraries,header= !header,inputs=List.rev (!inputs),inline= !inline,
        inlineValues= !inlineValues,references=List.rev (!references),basis="demand",view= !view} end
    handle BuildFile.Error message => raise Invalid message
  fun plan {file,windows,readBuild} : plan = planWith {file=file,windows=windows,readBuild=readBuild,hosts=false}
  (* A plan's units as the rules read them (Deps.illFormed), each file in the
     fixity its place in the build gives it, as a compile reads it, from
     fixity on: what a boundary keeps stays inside it, and a build file used
     again adds what it left. library: the plan is a library's *)
  fun layout {steps:step list,library:bool,defaultMode:Source.mode,fixity:Fixity.env,
              syntax:Source.mode*string*Fixity.env -> Ast.program*Fixity.env} : Deps.layout list =
    let
      val used=ref StringMap.empty : (string*Fixity.fixity) list StringMap.map ref
      fun added (after:Fixity.env,before':Fixity.env)=
        List.take (#list after,length (#list after)-length (#list before'))
      fun walk ([],fixity)=([],fixity)
        | walk (step :: rest,fixity)=
          let val (here,fixity)=one (step,fixity)
              val (after,fixity)=walk (rest,fixity)
          in (here @ after,fixity) end
      and one (SUnit (file,annotations),fixity)=
            let val (read,fixity)=
                  let val (program,left)=syntax (modeOf (defaultMode,annotations),file,fixity)
                  in (Deps.analyseUnit (file,program),left) end
                  handle Error.CompileError (span,_) => (Deps.unread (file,span),fixity)
            in ([Deps.unitOf (library,annotations,read)],fixity) end
        | one (SLibrary (exports,inner),fixity)=
            let val (within,after)=walk (inner,fixity)
                fun out (n,_)=List.exists (fn export => export=(BuildFile.Fix,n)) exports
            in ([Deps.Scope within],Fixity.extend (fixity,List.filter out (added (after,fixity)))) end
        | one (SUse (key,inner),fixity)=
            (case StringMap.find (!used,key) of
               SOME directives => ([],Fixity.extend (fixity,directives))
             | NONE =>
                 let val (within,after)=walk (inner,fixity)
                 in used:=StringMap.insert (!used,key,added (after,fixity));(within,after) end)
        | one (SImplements (_,inner),fixity)=([Deps.Scope (#1 (walk (inner,fixity)))],fixity)
    in #1 (walk (steps,fixity)) end
  (* whether all that steps declare stands behind a boundary of their own *)
  fun bounded steps=List.all (fn SUnit _ => false | SLibrary _ => true | SImplements _ => true
    | SUse (_,inner) => bounded inner) steps
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
          | one (SLibrary (_,steps))=all steps
          | one (SImplements (_,steps))=all steps
          | one (SUse (file,steps))=if List.exists (fn prior => prior=file) (!used) then []
            else (used:=file :: !used;all steps)
    in all steps end
  fun files steps=List.map #1 (units steps)
end

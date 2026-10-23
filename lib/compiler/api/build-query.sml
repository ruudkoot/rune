(* Read-only editor queries use the compiler's build lexer/parser. Recovery
   retains observed path roles; strict parsing supplies the diagnostics. *)
structure CompilerBuildQuery =
struct
  structure B=BuildFile
  structure P=CompilerProject
  type reference={kind:string,value:string,start:int,stop:int,quoted:bool}
  type expectation=string*Source.span
  type syntax={references:reference list,expected:expectation list,diagnostics:CompilerSession.diagnostic list}
  type completion={label:string,text:string,kind:string,start:int,stop:int}
  type link={kind:string,target:string,start:int,stop:int}
  fun inspect {file,text} : syntax =
    let val references=ref [] : reference list ref
        val expected=ref [] : expectation list ref
        fun path (kind,word,span:Source.span)=references:=
          {kind=kind,value=case word of B.W value => value | B.S value => value,
           start= #start span,stop= #stop span,quoted=case word of B.S _ => true | _ => false} :: !references
        val problem=(ignore (B.parseUsing {path=file,text=text,recover=false,pathAt=fn _ => (),wanted=fn _ => ()});NONE)
          handle B.LocatedError error => SOME error
        val _=(B.parseUsing {path=file,text=text,recover=true,pathAt=path,wanted=fn item => expected:=item :: !expected})
          handle B.LocatedError _ => []
        val source=Source.fromStringIn (Source.Ascii,file,text)
        fun diagnostic (span:Source.span,message)=
          let val (line,column)=Source.lineCol (source,#start span)
          in {severity="error",file=file,start= #start span,stop= #stop span,line=line,column=column,message=message} end
    in {references=List.rev (!references),expected=List.rev (!expected),diagnostics=case problem of NONE => [] | SOME error => [diagnostic error]} end
  fun links {file,text,windows,lib} : link list =
    let val references= #references (inspect {file=file,text=text})
        fun one (reference:reference)=
          if #quoted reference andalso (#stop reference<= #start reference+1 orelse
             #stop reference>size text orelse String.sub (text,#stop reference-1)<> #"\"") then NONE else
          let val value= #value reference
              val target=if #kind reference="library" then
                  case lib of NONE => if BasisManifest.isLibraryPath value then
                      SOME (P.concat windows (value,"library.build")) else NONE
                    | SOME root => SOME (P.concat windows (BasisManifest.libraryDir (root,value),"library.build"))
                else SOME (B.expandUsing {isAbsolute=P.absolute windows,concat=P.concat windows} (P.directory windows file,value))
          in Option.map (fn target => {kind= #kind reference,target=P.normalize windows target,
            start= #start reference,stop= #stop reference}:link) target end
          handle B.Error _ => NONE | P.Invalid _ => NONE
    in List.mapPartial one references end
  fun serialize (value,quoted) =
    if Char.contains value #"\"" then NONE else
    let val plain=not (List.exists (fn keyword => keyword=value) B.keywords) andalso
          ((case B.lexemes ("",value,false) of [{word=B.W word,start=0,stop}] => word=value andalso stop=size value
              | _ => false) handle B.LocatedError _ => false)
    in SOME (if quoted orelse not plain then "\"" ^ value ^ "\"" else value) end
  fun sort items =
    let fun split ([],a,b)=(a,b) | split (x::rest,a,b)=split (rest,b,x::a)
        fun merge ([],ys)=ys | merge (xs,[])=xs
          | merge (x::xs,y::ys)=if String.compare (#label (x:completion),#label (y:completion))<>GREATER
              then x::merge (xs,y::ys) else y::merge (x::xs,ys)
        fun run []=[] | run [x]=[x] | run xs=let val (a,b)=split (xs,[],[]) in merge (run a,run b) end
    in run items end
  fun completions {file,text,offset,variables,windows,lib} =
    let val {references,expected,...}=inspect {file=file,text=text}
        val reference=case List.find (fn item:reference => #start item<=offset andalso offset< #stop item) references of
          SOME item => SOME item | NONE => List.find (fn item:reference => #stop item=offset) references
        val selected=case reference of SOME item => SOME item | NONE =>
          Option.map (fn (kind,_) => {kind=kind,value="",start=offset,stop=offset,quoted=false}:reference)
            (List.find (fn (_,span:Source.span) => #start span<=offset andalso offset<= #stop span) expected)
    in if offset<0 orelse offset>size text then {items=[],isIncomplete=false} else
       case selected of NONE => {items=[],isIncomplete=false} | SOME item =>
      let val value= #value item
          val contentStart= #start item+(if #quoted item then 1 else 0)
          val cursor=Int.max (0,Int.min (size value,offset-contentStart))
          val prefix=String.substring (value,0,cursor)
          fun separator c=c= #"/" orelse windows andalso c= #"\\"
          fun last i=if i<0 then 0 else if separator (String.sub (prefix,i)) then i+1 else last (i-1)
          val split=last (size prefix-1)
          val parent=String.substring (prefix,0,split)
          val word=String.extract (prefix,split,NONE)
          fun suffix i=if i=size value then "" else if separator (String.sub (value,i)) then String.extract (value,i,NONE) else suffix (i+1)
          val tail=suffix cursor
          fun matching name=String.isPrefix (if windows then P.lower word else word) (if windows then P.lower name else name)
          val insertSpace= #start item= #stop item andalso offset>0 andalso not (Char.isSpace (String.sub (text,offset-1)))
          fun candidate (label,value,kind)=Option.map (fn value =>
            {label=label,text=(if insertSpace then " " else "") ^ value,kind=kind,start= #start item,stop= #stop item}:completion)
            (serialize (value,#quoted item))
          fun variableAt (at,found)=if at>=size prefix then found else
            if String.sub (prefix,at)= #"$" andalso at+1<size prefix andalso String.sub (prefix,at+1)= #"(" then variableAt (at+2,SOME at)
            else if String.sub (prefix,at)= #")" then variableAt (at+1,NONE) else variableAt (at+1,found)
          fun variablesAt start =
            let val fragment=String.extract (prefix,start+2,NONE)
                fun rest at=if at>=size value then "" else if String.sub (value,at)= #")" then String.extract (value,at+1,NONE) else rest (at+1)
                val after=rest cursor
                val items=List.mapPartial (fn (name,_) => if String.isPrefix fragment name then
                  candidate ("$(" ^ name ^ ")",String.substring (prefix,0,start) ^ "$(" ^ name ^ ")" ^ after,"variable") else NONE) variables
            in {items=sort items,isIncomplete=false} end
          fun files () =
            let val root=if #kind item="library" then lib else SOME (B.expandUsing
                  {isAbsolute=P.absolute windows,concat=P.concat windows} (P.directory windows file,parent))
                val root=Option.map (fn "" => "." | path => path) root
                val stream=case root of NONE => NONE | SOME root => SOME (OS.FileSys.openDir root) handle OS.SysErr _ => NONE
                fun scan (stream,root,count,items)=if count=8192 then (items,true) else
                  case OS.FileSys.readDir stream of NONE => (items,false) | SOME name =>
                    if not (matching name) then scan (stream,root,count+1,items) else
                    let val path=P.concat windows (root,name)
                        val directory=OS.FileSys.isDir path handle OS.SysErr _ => false
                        val library= #kind item="library"
                        val accepted=if library then directory andalso
                              (OS.FileSys.access (P.concat windows (path,"library.build"),[]) handle OS.SysErr _ => false)
                            else #kind item<>"directory" orelse directory
                        val continuation=if directory andalso not library andalso tail="" then "/" else ""
                        val completed=if library then name else parent ^ name ^ continuation ^ tail
                        val found=if accepted then candidate (name ^ continuation,completed,
                          if library then "library" else if directory then "directory" else "file") else NONE
                    in scan (stream,root,count+1,case found of NONE => items | SOME found => found::items) end
                val (all,incomplete)=case (stream,root) of (SOME stream,SOME root) =>
                      ((scan (stream,root,0,[]) before OS.FileSys.closeDir stream)
                       handle error => (OS.FileSys.closeDir stream handle _ => ();raise error))
                    | _ => ([],false)
                val items=sort all
            in {items=List.take (items,Int.min (512,length items)),isIncomplete=incomplete orelse length items>512} end
      in case variableAt (0,NONE) of SOME start => variablesAt start
       | NONE => files () handle B.Error _ => {items=[],isIncomplete=false} end
    end
end

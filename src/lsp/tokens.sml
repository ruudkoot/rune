(* Negotiated presentation of lexical classes and checked binding namespaces. *)
structure RuneLspTokens =
struct
  structure C=RuneCompiler
  structure P=LspProtocol
  structure L=LspPosition
  structure J=RuneLspSync
  type legend={types:string list,modifiers:string list,full:bool,range:bool,delta:bool,key:string}
  type token={start:int,stop:int,kind:string,modifiers:string list,priority:int}
  type row={line:IntInf.int,start:IntInf.int,length:IntInf.int,kind:int,bits:IntInf.int,priority:int}
  type entry={uri:string,key:string,id:string,data:IntInf.int vector}
  datatype t=History of entry list ref
  fun new ()=History (ref [])
  fun clear (History entries)=entries:=[]
  fun member (value,[])=SOME value
    | member (value,name::rest)=Option.mapPartial (fn value => member (value,rest)) (Json.member (name,value))
  fun strings (SOME (Json.Array values)) =
        let fun read []=SOME [] | read (Json.String value::rest)=Option.map (fn rest => value::rest) (read rest) | read _=NONE
        in read values end
    | strings _=NONE
  fun requested (SOME (Json.Bool true))=true | requested (SOME (Json.Object _))=true | requested _=false
  fun legend capabilities : legend option =
    case member (capabilities,["textDocument","semanticTokens"]) of NONE => NONE | SOME options =>
      (case (strings (Json.member ("tokenTypes",options)),strings (Json.member ("tokenModifiers",options)),
             strings (Json.member ("formats",options))) of
         (SOME types,SOME modifiers,SOME formats) =>
           let fun supported values name=List.exists (fn value => value=name) values
               val types=List.filter (supported types)
                 ["namespace","type","interface","typeParameter","variable","keyword","comment","string","number"]
               val modifiers=List.filter (supported modifiers) ["declaration","readonly"]
               val full=member (options,["requests","full"])
               val range=requested (member (options,["requests","range"]))
               val delta=member (options,["requests","full","delta"])=SOME (Json.Bool true)
               val key=Json.encode (Json.Array [Json.Array (List.map Json.String types),Json.Array (List.map Json.String modifiers)])
           in if null types orelse not (supported formats "relative") orelse not (requested full orelse range) then NONE
              else SOME {types=types,modifiers=modifiers,full=requested full,range=range,delta=delta,key=key} end
       | _ => NONE)
  fun provider capabilities = Option.map (fn ({types,modifiers,full,range,delta,...}:legend) => Json.Object
    [("legend",Json.Object [("tokenTypes",Json.Array (List.map Json.String types)),
      ("tokenModifiers",Json.Array (List.map Json.String modifiers))]),("range",Json.Bool range),
     ("full",if delta then Json.Object [("delta",Json.Bool true)] else Json.Bool full)]) (legend capabilities)
  fun method name=List.exists (fn value => name=value)
    ["textDocument/semanticTokens/full","textDocument/semanticTokens/full/delta","textDocument/semanticTokens/range"]
  fun enabled (capabilities,name)=case legend capabilities of NONE => false | SOME options =>
    if name="textDocument/semanticTokens/range" then #range options
    else if name="textDocument/semanticTokens/full/delta" then #full options andalso #delta options else #full options
  fun lexical (pieces:C.Syntax.piece list) = List.mapPartial (fn piece =>
    let val kind=case #kind piece of "keyword" => SOME "keyword" | "comment" => SOME "comment"
          | "string" => SOME "string" | "number" => SOME "number" | "typeVariable" => SOME "typeParameter" | _ => NONE
    in Option.map (fn kind => {start= #start piece,stop= #stop piece,kind=kind,modifiers=[],priority=1}:token) kind end) pieces
  fun semantic (occurrences:C.Analysis.occurrence list,select) = List.concat (List.map (fn occurrence =>
    let val kind=case #kind occurrence of "value" => SOME "variable" | "type" => SOME "type"
          | "structure" => SOME "namespace" | "signature" => SOME "interface" | "functor" => SOME "namespace" | _ => NONE
        val modifiers=(if #isDefinition occurrence then ["declaration"] else []) @
          (if #kind occurrence="value" then ["readonly"] else [])
    in case kind of NONE => [] | SOME kind => List.map (fn (start,stop) =>
      {start=start,stop=stop,kind=kind,modifiers=modifiers,priority=if #isDefinition occurrence then 3 else 2}:token) (select occurrence) end) occurrences)
  fun index (names,name)=
    let fun find ([],_)=NONE | find (value::rest,n)=if value=name then SOME n else find (rest,n+1)
    in find (names,0) end
  fun dataJson data=Json.Array (Vector.foldr (fn (value,rest) => Json.intInf value::rest) [] data)
  fun delta (old,current) =
    let val n=Vector.length old val m=Vector.length current
        fun prefix i=if i<n andalso i<m andalso Vector.sub (old,i)=Vector.sub (current,i) then prefix (i+1) else i
        val from=prefix 0
        fun suffix i=if i<n-from andalso i<m-from andalso Vector.sub (old,n-i-1)=Vector.sub (current,m-i-1) then suffix (i+1) else i
        val same=suffix 0
        val inserted=Vector.tabulate (m-from-same,fn i => Vector.sub (current,from+i))
    in if from=n andalso from=m then Json.Array [] else Json.Array [Json.Object
      ([("start",Json.int from),("deleteCount",Json.int (n-from-same))] @
       (if Vector.length inserted=0 then [] else [("data",dataJson inserted)]))] end
  fun remember (History entries,entry:entry) =
    let val all=entry::List.filter (fn old:entry => not (#uri old= #uri entry andalso #key old= #key entry andalso #id old= #id entry)) (!entries)
        fun keep ([],_,_)=[]
          | keep (entry::rest,count,bytes)=
              let (* Allow for boxed integers as well as vector slots. *)
                  val used=Vector.length (#data (entry:entry))*64+size (#uri entry)+size (#key entry)+size (#id entry)
              in if used>8*1024*1024 then keep (rest,count,bytes)
                 else if count=8 orelse used>8*1024*1024-bytes then [] else entry::keep (rest,count+1,bytes+used) end
    in entries:=keep (all,0,0) end
  fun reply (history as History entries,{uri,text,index=NONE,encoding,capabilities,method,params,tokens})=Json.Null
    | reply (history as History entries,{uri,text,index=SOME sourceIndex,encoding,capabilities,method,params,tokens}) =
      let val options=case legend capabilities of SOME options => options | NONE => raise J.Invalid "semantic tokens were not negotiated"
          val bounds=if method<>"textDocument/semanticTokens/range" then NONE else
            case P.rangeFromJson (J.required (params,"range")) of NONE => raise J.Invalid "invalid semantic token range"
            | SOME {start,stop} =>
                if #line start> #line stop orelse #line start= #line stop andalso #character start> #character stop then raise J.Invalid "reversed semantic token range" else
                (case (L.offset (sourceIndex,encoding,start),L.offset (sourceIndex,encoding,stop)) of
                   (SOME a,SOME b) => if a<=b then SOME (a,b) else raise J.Invalid "reversed semantic token range"
                 | _ => raise J.Invalid "semantic token range splits an encoded character")
          fun intersects (start,stop)=case bounds of NONE => true | SOME (a,b) => a<b andalso start<b andalso a<stop
          fun bits names=List.foldl (fn (name,total) => case index (#modifiers options,name) of NONE => total | SOME n =>
            let fun power (0,value)=value | power (n,value)=power (n-1,value*2)
            in total+power (n,1) end) (0:IntInf.int) names
          val count=ref 0
          fun span (token:token,kind,start,stop,kept) =
            if start>=stop orelse not (intersects (start,stop)) then kept else
            case (L.position (sourceIndex,encoding,start),L.position (sourceIndex,encoding,stop)) of
              (SOME first,SOME last) =>
                if #line first<> #line last orelse #character last<= #character first then kept else
                if !count=20000 then raise Fail "semantic token response budget exceeded" else
                (count:= !count+1;{line= #line first,start= #character first,length= #character last- #character first,
                  kind=kind,bits=bits (#modifiers token),priority= #priority token}:row)::kept
            | _ => kept
          fun split (token:token,kept) = case index (#types options,#kind token) of NONE => kept | SOME kind =>
            if #start token<0 orelse #stop token>size text then kept else
            let fun loop (from,at,kept)=if at>= #stop token then span (token,kind,from,at,kept) else
                  case String.sub (text,at) of
                    #"\r" => let val next=at+(if at+1< #stop token andalso String.sub (text,at+1)= #"\n" then 2 else 1)
                             in loop (next,next,span (token,kind,from,at,kept)) end
                  | #"\n" => loop (at+1,at+1,span (token,kind,from,at,kept))
                  | _ => loop (from,at+1,kept)
            in loop (#start token,#start token,kept) end
          fun less (a:row,b:row)= #line a< #line b orelse #line a= #line b andalso
            (#start a< #start b orelse #start a= #start b andalso (#priority a> #priority b orelse
              #priority a= #priority b andalso #length a>= #length b))
          val sorted=RuneLspStructure.sort less (List.foldl split [] tokens)
          fun encode ([],_,_,_,kept)=Vector.fromList (List.rev kept)
            | encode ((token:row)::rest,line,column,finish,kept)=
                if #line token=line andalso #start token<finish then encode (rest,line,column,finish,kept) else
                encode (rest,#line token,#start token,#start token+ #length token,
                  #bits token::IntInf.fromInt (#kind token):: #length token::
                  (if #line token=line then #start token-column else #start token):: (#line token-line)::kept)
          val data=encode (sorted,0,0,0,[])
          val json=dataJson data
      in if isSome bounds then Json.Object [("data",json)] else
        let val id="tokens-" ^ Hex.fromBytes (Sha256.digest (Json.encode (Json.Array [Json.String uri,Json.String (#key options),json])))
            val previous=if method<>"textDocument/semanticTokens/full/delta" then NONE else
              let val wanted=J.string (J.required (params,"previousResultId"))
              in List.find (fn entry:entry => #uri entry=uri andalso #key entry= #key options andalso #id entry=wanted) (!entries) end
            val result=case previous of NONE => Json.Object [("resultId",Json.String id),("data",json)]
              | SOME old => Json.Object [("resultId",Json.String id),("edits",delta (#data old,data))]
            val ()=remember (history,{uri=uri,key= #key options,id=id,data=data})
        in result end end
end

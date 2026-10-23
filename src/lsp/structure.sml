(* Structural ranges use the compiler's captured syntax and lossless pieces. *)
structure RuneLspStructure =
struct
  structure C=RuneCompiler
  structure P=LspProtocol
  structure L=LspPosition
  structure J=RuneLspSync
  fun sort less xs =
    let fun merge ([],ys)=ys | merge (xs,[])=xs
          | merge (xs as x::xt,ys as y::yt)=if less (x,y) then x::merge (xt,ys) else y::merge (xs,yt)
        fun split (x::y::rest)=let val (a,b)=split rest in (x::a,y::b) end | split xs=(xs,[])
        fun go []=[] | go [x]=[x] | go xs=let val (a,b)=split xs in merge (go a,go b) end
    in go xs end
  fun member (value,[])=SOME value
    | member (value,name::rest)=Option.mapPartial (fn value => member (value,rest)) (Json.member (name,value))
  fun events NONE=[] | events (SOME syntax)=C.Syntax.events syntax
  fun valid (count,start,stop)=start>=0 andalso start<stop andalso stop<=count
  fun folding {text,syntax,pieces,index,encoding,capabilities} =
    case index of NONE => Json.Array [] | SOME index =>
      let val limit=case Option.mapPartial Json.toInt (member (capabilities,["textDocument","foldingRange","rangeLimit"])) of
            SOME count => if count<0 then 8192 else Int.min (8192,count) | NONE => 8192
          fun candidate (start,stop,kind)=if not (valid (size text,start,stop)) then NONE else
            case (L.position (index,encoding,start),L.position (index,encoding,stop)) of
              (SOME first,SOME last) =>
                let val finish= #line last-(if #character last=0 andalso #line last> #line first then 1 else 0)
                in if finish<= #line first then NONE else SOME (#line first,finish,kind) end
            | _ => NONE
          fun syntaxRange (event:C.Syntax.event)=
            if List.exists (fn kind => kind= #kind event)
              ["DVal","DValRec","DFun","DType","DDatatype","DLocal","DStructure","DSignature","DFunctor",
               "ELet","ECase","EFn","EHandle","EWhile","ERecord","EList","ESeq","StrStruct","SigSig","DOpen"]
            then candidate (#start event,#stop event,if #kind event="DOpen" then SOME "imports" else NONE) else NONE
          fun comment (piece:C.Syntax.piece)=if #kind piece="comment" then candidate (#start piece,#stop piece,SOME "comment") else NONE
          fun less ((a,b,_),(c,d,_))=a<c orelse a=c andalso b>=d
          fun trim (start,top::rest)=if start>top then trim (start,rest) else top::rest | trim (_,[])=[]
          fun choose ([],_,_,_,kept)=List.rev kept
            | choose ((start,stop,kind)::rest,stack,previous,count,kept)=
                if count=limit then List.rev kept else
                let val stack=trim (start,stack)
                in if previous=SOME start orelse (case stack of top::_ => stop>top | [] => false)
                   then choose (rest,stack,previous,count,kept)
                   else choose (rest,stop::stack,SOME start,count+1,(start,stop,kind)::kept) end
          val ranges=if limit=0 then [] else choose
            (sort less (List.mapPartial syntaxRange (events syntax) @ List.mapPartial comment pieces),[],NONE,0,[])
      in Json.Array (List.map (fn (start,stop,kind) => Json.Object
        ([("startLine",Json.intInf start),("endLine",Json.intInf stop)] @
          (case kind of NONE => [] | SOME kind => [("kind",Json.String kind)]))) ranges) end
  fun selection {text,syntax,pieces,index,encoding,positions} =
    let val requested=case positions of Json.Array positions => positions | _ => raise J.Invalid "expected selection positions array"
        val ()=if length requested<=128 then () else raise Fail "selection range position budget exceeded"
        val count=size text
        val nodes=List.mapPartial (fn event:C.Syntax.event =>
          if valid (count,#start event,#stop event) then SOME (#start event,#stop event) else NONE) (events syntax)
        fun identifier (piece:C.Syntax.piece)=List.exists (fn kind => #kind piece=kind) ["identifier","operator","typeVariable"]
        fun one point =
          let val point=case P.positionFromJson point of SOME point => point | NONE => raise J.Invalid "invalid selection position"
              val at=case Option.mapPartial (fn index => L.offset (index,encoding,point)) index of
                SOME at => at | NONE => raise J.Invalid "selection position splits an encoded character"
              val current=List.find (fn piece:C.Syntax.piece => #start piece<=at andalso at< #stop piece andalso #kind piece<>"whitespace") pieces
              val previous=List.find (fn piece:C.Syntax.piece => #stop piece=at andalso identifier piece) pieces
              val token=case current of SOME piece => if identifier piece then current else
                    (case previous of SOME _ => previous | NONE => current) | NONE => previous
              fun component (start,[])=NONE
                | component (start,part::rest)=if start<=at andalso at<=start+size part then SOME (start,start+size part)
                    else component (start+size part+1,rest)
              val lexical=case token of NONE => [] | SOME piece =>
                let val whole=(#start piece,#stop piece)
                in whole :: (if #kind piece="identifier" then case component (#start piece,String.fields (fn c => c = #".") (#text piece)) of
                    NONE => [] | SOME part => [part] else []) end
              fun contains ((a,b),(c,d))=a<=c andalso d<=b
              fun less ((a,b),(c,d))=b-a<d-c orelse b-a=d-c andalso a>=c
              val candidates=sort less (lexical @ List.filter (fn (a,b) => a<=at andalso at<=b) nodes @ [(0,count)])
              fun grow ([],_,_,kept)=List.rev kept
                | grow (next::rest,current,depth,kept)=if depth=63 then List.rev kept else
                    if next=current orelse not (contains (next,current)) then grow (rest,current,depth,kept)
                    else grow (rest,next,depth+1,next::kept)
              val nested=grow (candidates,(at,at),0,[])
              val nested=case List.rev nested of [] => [(at,at)] | outer::_ =>
                if outer=(0,count) then nested else nested @ [(0,count)]
              fun range (start,stop)=case index of NONE => raise Fail "selection source is unavailable" | SOME index =>
                (case (L.position (index,encoding,start),L.position (index,encoding,stop)) of
                   (SOME first,SOME last) => P.rangeToJson {start=first,stop=last}
                 | _ => raise Fail "selection syntax has an invalid source boundary")
              fun build []=raise Fail "empty selection chain"
                | build [span]=Json.Object [("range",range span)]
                | build (span::rest)=Json.Object [("range",range span),("parent",build rest)]
          in build nested end
        val result=Json.Array (List.map one requested)
    in if size (Json.encode result)>1024*1024 then raise Fail "selection range response budget exceeded" else result end
end

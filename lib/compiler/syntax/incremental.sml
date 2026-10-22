(* Lossless token storage and declaration reuse. Token positions are rebuilt
   from immutable widths; cached ASTs have relative spans and are copied only
   at the compiler bridge, never exposed with mutable elaboration slots. *)
structure CompilerSyntax =
struct
  type problem=Source.span * string
  type lexeme={gap:string,raw:string,token:Token.token option,problems:(int*int*string) list}
  type chunk={base:int,key:(Token.token*int*int) list,incoming:(string*Fixity.fixity) list,
    directives:(string*Fixity.fixity) list,syntax:Ast.program,ends:int list,problems:problem list,consumed:int}
  type nested={base:int,origin:int,context:SyntaxParser.ctx,key:(Token.token*int*int) list,
    incoming:(string*Fixity.fixity) list,directives:(string*Fixity.fixity) list,syntax:Ast.dec,consumed:int}
  type work={lexedBytes:int,reusedTokens:int,parsedDeclarations:int,reusedDeclarations:int}
  datatype t=Syntax of {file:string,text:string,mode:Source.mode,orPatterns:bool,
    lexemes:(int*lexeme) vector,chunks:chunk list,nested:nested list,initial:Fixity.env,fixity:Fixity.env,work:work}
  fun text (Syntax {text,...})=text
  fun fixity (Syntax {fixity,...})=fixity
  fun work (Syntax {work,...})=work
  fun width ({gap,raw,...}:lexeme)=size gap+size raw
  fun lexical {file,text,mode,previous,change} =
    let
      val n=size text
      val {next,...}=Lexer.lexerOf (mode,file,text)
      fun ch i=if i<n then String.sub (text,i) else #"\000"
      fun comment (i,depth)=if i>=n then n
        else if ch i= #"(" andalso ch (i+1)= #"*" then comment (i+2,depth+1)
        else if ch i= #"*" andalso ch (i+1)= #")" then if depth=1 then i+2 else comment (i+2,depth-1)
        else comment (i+1,depth)
      fun trivia i=if i>=n then n else
        if List.exists (fn c => ch i=c) [#" ",#"\t",#"\n",#"\f"] then trivia (i+1)
        else if ch i= #"\r" andalso ch (i+1)= #"\n" then trivia (i+2)
        else if ch i= #"(" andalso ch (i+1)= #"*" then trivia (comment (i+2,1)) else i
      fun stringEnd (i,gap)=if i>=n then n
        else if gap then stringEnd (i+1,ch i<> #"\\") else
          case ch i of #"\"" => i+1 | #"\n" => i
          | #"\\" => if Char.isSpace (ch (i+1)) then stringEnd (i+1,true) else stringEnd (Int.min (n,i+2),false)
          | _ => stringEnd (i+1,false)
      fun one from : lexeme =
        let val beginning=if from=0 andalso mode<>Source.Unicode Source.Latin1
              andalso String.isPrefix "\239\187\191" text then 3 else from
        in
          (let val (token,span,_) = next beginning
           in {gap=String.substring (text,from,#start span-from),raw=String.substring (text,#start span,#stop span- #start span),
               token=SOME token,problems=[]} end)
          handle Error.CompileError (span,message) =>
            let val start=trivia beginning
                val stop=if #start span<start then start
                  else if ch start= #"\"" then stringEnd (start+1,false)
                  else if ch start= #"#" andalso ch (start+1)= #"\"" then stringEnd (start+2,false)
                  else Int.min (n,Int.max (from+1,#stop span))
                val stop=Int.max (Int.min (n,from+1),stop)
            in {gap="",raw=String.substring (text,from,stop-from),token=NONE,
                problems=[(#start span-from,#stop span-from,message)]} end
        end
      val old=case previous of NONE => Vector.fromList [] | SOME (Syntax {lexemes,...}) => lexemes
      fun boundary offset =
        let fun search (lo,hi)=if lo>=hi then lo else
              let val mid=(lo+hi+1) div 2 in if #1 (Vector.sub (old,mid))<=offset then search (mid,hi) else search (lo,mid-1) end
        in if Vector.length old=0 then NONE else
             let val i=search (0,Vector.length old-1) in if #1 (Vector.sub (old,i))=offset then SOME i else NONE end end
      val (first,reuseAfter,delta)=case change of NONE => (0,n+1,0)
        | SOME {start,stop,text=replacement} =>
            let fun find i=if i>=Vector.length old orelse #1 (Vector.sub (old,i))>start then Int.max (0,i-2) else find (i+1)
            in (find 0,start+size replacement,size replacement-(stop-start)) end
      val prefix=List.tabulate (first,fn i => Vector.sub (old,i))
      val start=if first<Vector.length old then #1 (Vector.sub (old,first)) else 0
      val lexed=ref 0
      val reused=ref first
      fun tail (i,offset)=List.tabulate (Vector.length old-i,fn j =>
        let val (at,item)=Vector.sub (old,i+j) in (at+offset,item) end)
      fun scan from =
        let val item=one from
            val ()=lexed:= !lexed+width item
            val matching=if from<reuseAfter then NONE else boundary (from-delta)
        in case matching of SOME i =>
             if item= #2 (Vector.sub (old,i)) then (reused:= !reused+Vector.length old-i;tail (i,delta)) else continue (from,item)
           | NONE => continue (from,item)
        end
      and continue (from,item:lexeme) = (from,item) ::
        (case #token item of SOME Token.EOF => [] | _ => scan (from+width item))
    in (Vector.fromList (prefix @ scan start),!lexed,!reused) end
  fun tokens lexemes file =
    Vector.fromList (Vector.foldr (fn ((at,item:lexeme),all) => case #token item of NONE => all | SOME token =>
      (token,{file=file,start=at+size (#gap item),stop=at+width item}) :: all) [] lexemes)
  fun make {file,text,mode,orPatterns,initial,previous,change} =
    let
      val (lexemes,lexedBytes,reusedTokens)=lexical {file=file,text=text,mode=mode,previous=previous,change=change}
      val toks=tokens lexemes file
      val ntoks=Vector.length toks
      fun at i=Vector.sub (toks,Int.min (ntoks-1,i))
      fun key (i,count,base)=List.tabulate (Int.min (ntoks-i,count+3),fn j =>
        let val (token,span)=at (i+j) in (token,#start span-base,#stop span-base) end)
      val old=case previous of NONE => [] | SOME (Syntax {chunks,...}) => chunks
      fun relocated (chunk:chunk) = case change of NONE => NONE
        | SOME {start,stop,text} => if #base chunk<=start then SOME (#base chunk,chunk)
          else if #base chunk>=stop then SOME (#base chunk+size text-(stop-start),chunk) else NONE
      val cache=IntMap.fromList (List.mapPartial relocated old)
      val parsed=ref 0
      val reused=ref 0
      val oldNested=case previous of NONE => [] | SOME (Syntax {nested,...}) => nested
      fun relocateNested (node:nested) = case change of NONE => NONE
        | SOME {start,stop,text} =>
          let val at=if #base node<=start then SOME (#base node)
                else if #base node>=stop then SOME (#base node+size text-(stop-start)) else NONE
          in Option.map (fn base => (base,{base=base,origin= #origin node,context= #context node,key= #key node,
            incoming= #incoming node,directives= #directives node,syntax= #syntax node,consumed= #consumed node}:nested)) at end
      val memo=ref (IntMap.fromList (List.mapPartial relocateNested oldNested))
      fun reuse (context,i,incoming:Fixity.env) =
        let val base= #start (#2 (at i))
        in case IntMap.find (!memo,base) of NONE => NONE | SOME node =>
          if #context node=context andalso #incoming node=StringMap.listItemsi (#table incoming)
            andalso #key node=key (i,#consumed node,base) then
            (reused:= !reused+1;SOME (hd (SyntaxAst.copy ([#syntax node],base- #origin node)),
              Fixity.extend (incoming,#directives node),i+ #consumed node)) else NONE end
      fun remember (context,i,next,incoming:Fixity.env,outgoing:Fixity.env,syntax) =
        let val base= #start (#2 (at i))
            val node={base=base,origin=base,context=context,key=key (i,next-i,base),
              incoming=StringMap.listItemsi (#table incoming),syntax=syntax,consumed=next-i,
              directives=List.take (#list outgoing,length (#list outgoing)-length (#list incoming))}:nested
        in if context=SyntaxParser.Top then () else parsed:= !parsed+1;
           memo:=IntMap.insert (!memo,base,node) end
      fun loop (i,incoming,result) =
        if #1 (at i)=Token.EOF then (List.rev result,incoming) else
        let val base= #start (#2 (at i))
            val incomingKey=StringMap.listItemsi (#table incoming)
            val cached=case IntMap.find (cache,base) of SOME chunk =>
              if null (#problems chunk) andalso #incoming chunk=incomingKey andalso #key chunk=key (i,#consumed chunk,base)
              then SOME chunk else NONE | NONE => NONE
            val (chunk,outgoing)=case cached of SOME chunk =>
                (reused:= !reused+length (#syntax chunk);
                 ({base=base,key= #key chunk,incoming=incomingKey,directives= #directives chunk,syntax= #syntax chunk,
                   ends= #ends chunk,problems=[],consumed= #consumed chunk}:chunk,Fixity.extend (incoming,#directives chunk)))
              | NONE =>
                let val (syntax,outgoing,next,ends,problems)=SyntaxParser.parseChunk (toks,incoming,i,orPatterns,reuse,remember)
                    val next=Int.max (i+1,next)
                    val problems=if null syntax andalso null problems then [(#2 (at i),"unexpected '" ^ Token.toString (#1 (at i)) ^ "'")] else problems
                    val consumed=next-i
                    val directives=List.take (#list outgoing,length (#list outgoing)-length (#list incoming))
                    fun relative (span:Source.span,message)=({file=file,start= #start span-base,stop= #stop span-base},message)
                    val chunk={base=base,key=key (i,consumed,base),incoming=incomingKey,directives=directives,
                      syntax=SyntaxAst.copy (syntax,~base),ends=List.map (fn stop => stop-base) ends,
                      problems=List.map relative problems,consumed=consumed}:chunk
                in parsed:= !parsed+length syntax;(chunk,outgoing) end
        in loop (i+ #consumed chunk,outgoing,chunk :: result) end
      val (chunks,fixity)=loop (0,initial,[])
      val starts=IntMap.fromList (List.tabulate (ntoks,fn i => (#start (#2 (at i)),i)))
      val nested=IntMap.foldli (fn (base,node,all) => case IntMap.find (starts,base) of NONE => all | SOME i =>
        if #key node=key (i,#consumed node,base) then node :: all else all) [] (!memo)
    in Syntax {file=file,text=text,mode=mode,orPatterns=orPatterns,initial=initial,fixity=fixity,lexemes=lexemes,chunks=chunks,nested=nested,
      work={lexedBytes=lexedBytes,reusedTokens=reusedTokens,parsedDeclarations= !parsed,reusedDeclarations= !reused}} end
  fun parse {file,text,mode,orPatterns,fixity} =
    make {file=file,text=text,mode=mode,orPatterns=orPatterns,initial=fixity,previous=NONE,change=NONE}
  fun edit (previous as Syntax {file,text=old,mode,orPatterns,...},{start,stop,text,fixity}) =
    if start<0 orelse stop<start orelse stop>size old then raise Subscript else
    make {file=file,text=String.substring (old,0,start) ^ text ^ String.extract (old,stop,NONE),mode=mode,orPatterns=orPatterns,
      initial=fixity,previous=SOME previous,change=SOME {start=start,stop=stop,text=text}}
  fun bridge (Syntax {chunks,...}) =
    List.concat (List.map (fn (chunk:chunk) => SyntaxAst.copy (#syntax chunk,#base chunk)) chunks)
  fun ends (Syntax {chunks,...})=List.concat (List.map (fn (chunk:chunk) => List.map (fn stop => stop+ #base chunk) (#ends chunk)) chunks)
  fun problems (Syntax {file,lexemes,chunks,...}) =
    Vector.foldr (fn ((at,item:lexeme),all) => List.map (fn (start,stop,message) =>
        ({file=file,start=at+start,stop=at+stop},message)) (#problems item) @ all)
      (List.concat (List.map (fn (chunk:chunk) => List.map (fn (span:Source.span,message) =>
        ({file=file,start= #start span+ #base chunk,stop= #stop span+ #base chunk},message)) (#problems chunk)) chunks)) lexemes
  fun pieces (Syntax {lexemes,...}) =
    let
      fun trivia (at,gap) =
        let val n=size gap
            fun ch i=if i<n then String.sub (gap,i) else #"\000"
            fun comment (i,d)=if i>=n then n
              else if ch i= #"(" andalso ch (i+1)= #"*" then comment (i+2,d+1)
              else if ch i= #"*" andalso ch (i+1)= #")" then if d=1 then i+2 else comment (i+2,d-1)
              else comment (i+1,d)
            fun space i=if i>=n orelse ch i= #"(" andalso ch (i+1)= #"*" then i else space (i+1)
            fun loop i=if i>=n then [] else
              let val (kind,next)=if i=0 andalso String.isPrefix "\239\187\191" gap then ("bom",3)
                    else if ch i= #"(" andalso ch (i+1)= #"*" then ("comment",comment (i+2,1))
                    else ("whitespace",space (i+1))
              in {kind=kind,start=at+i,stop=at+next,text=String.substring (gap,i,next-i)} :: loop next end
        in loop 0 end
      fun kind token=case token of
        Token.ID s => if Ident.isStartByte (String.sub (s,0)) then "identifier" else "operator"
      | Token.LONGID _ => "identifier" | Token.TYVAR _ => "typeVariable"
      | Token.INT _ => "number" | Token.WORD _ => "number" | Token.REAL _ => "number"
      | Token.STRING _ => "string" | Token.WIDESTRING _ => "string" | Token.CHAR _ => "string"
      | _ => let val spelling=Token.toString token
             in if Char.isAlpha (String.sub (spelling,0)) orelse String.isPrefix "_" spelling andalso size spelling>1
                then "keyword" else "punctuation" end
    in Vector.foldr (fn ((at,item:lexeme),all) => trivia (at,#gap item) @
      (if #raw item="" then [] else [{kind=case #token item of NONE => "error" | SOME token => kind token,
        start=at+size (#gap item),stop=at+width item,text= #raw item}]) @ all) [] lexemes end
end

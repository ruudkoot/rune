
 fun text s=name s
 fun appendText xs ys=F.append xs ys
 fun textConcat xs=concat(List.foldr(fn(x,rest)=>F.cons(x,rest))(F.empty())xs)
 fun renderList render values=textConcat[text"[",interleave(text",")(map render values),text"]"]
 fun parenthesize depth value=if depth>10 then textConcat[text"(",value,text")"]else value
 fun renderInteger value=name(signed value)
 fun renderQuoted value=
   let fun escape c=case force c of #"\""=>text"\\\""| #"\\"=>text"\\\\"| #"\n"=>text"\\n"
         | #"\r"=>text"\\r"| #"\t"=>text"\\t"|c=>singleton(cell c)
   in textConcat[text"\"",flatMap escape value,text"\""]end
 fun renderDomain depth domain=F.defer(fn()=>case force domain of Two=>text"Two"
   |Lift1 ds=>parenthesize depth(textConcat[text"Lift1 ",renderList(renderDomain 0)ds])
   |Lift2 ds=>parenthesize depth(textConcat[text"Lift2 ",renderList(renderDomain 0)ds])
   |Func(ds,result)=>parenthesize depth(textConcat[text"Func ",renderList(renderDomain 0)ds,text" ",renderDomain 11 result]))
 fun renderRoute depth point=F.defer(fn()=>case force point of
    Zero=>text"Zero"|One=>text"One"|Stop1=>text"Stop1"|Stop2=>text"Stop2"|Up2=>text"Up2"
   |Up1 rs=>parenthesize depth(textConcat[text"Up1 ",renderList(renderRoute 0)rs])
   |UpUp2 rs=>parenthesize depth(textConcat[text"UpUp2 ",renderList(renderRoute 0)rs])
   |Rep rep=>parenthesize depth(textConcat[text"Rep ",renderRepresentation 11 rep]))
 and renderRepresentation depth rep=F.defer(fn()=>case force rep of
    RepTwo f=>parenthesize depth(textConcat[text"RepTwo ",renderFrontier 11 f])
   |Rep1(f,highs)=>parenthesize depth(textConcat[text"Rep1 ",renderFrontier 11 f,text" ",renderList(renderRepresentation 0)highs])
   |Rep2(f,m,highs)=>parenthesize depth(textConcat[text"Rep2 ",renderFrontier 11 f,text" ",renderFrontier 11 m,
        text" ",renderList(renderRepresentation 0)highs]))
 and renderFrontier depth frontier=F.defer(fn()=>
   let val Min1Max0(arity,ones,zeros)=force frontier
   in parenthesize depth(textConcat[text"Min1Max0 ",renderInteger arity,text" ",renderList(renderFrel 0)ones,
       text" ",renderList(renderFrel 0)zeros])end)
 and renderFrel depth frel=F.defer(fn()=>let val MkFrel rs=force frel
   in parenthesize depth(textConcat[text"MkFrel ",renderList(renderRoute 0)rs])end)
 fun renderAbstract depth expression=F.defer(fn()=>case force expression of
    HVar v=>parenthesize depth(textConcat[text"HVar ",renderQuoted v])
   |HPoint p=>parenthesize depth(textConcat[text"HPoint ",renderRoute 11 p])
   |HLam(vs,e)=>parenthesize depth(textConcat[text"HLam ",renderList renderQuoted vs,text" ",renderAbstract 11 e])
   |HApp(a,b)=>parenthesize depth(textConcat[text"HApp ",renderAbstract 11 a,text" ",renderAbstract 11 b])
   |HVAp(f,args)=>parenthesize depth(textConcat[text"HVAp ",renderAbstract 11 f,text" ",renderList(renderAbstract 0)args])
   |HMeet es=>parenthesize depth(textConcat[text"HMeet ",renderList(renderAbstract 0)es])
   |HTable entries=>parenthesize depth(textConcat[text"HTable ",renderList(fn entry=>
      let val(point,e)=force entry in textConcat[text"(",renderRoute 0 point,text",",renderAbstract 0 e,text")"]end)entries]))
 type outputSequence=integer->integer->name
 type indentSequence=outputSequence->outputSequence
 fun emptyOutput indent column=F.empty()
 fun emptyIndent rest=rest
 fun appendIndent left right rest=left(right rest)
 fun indentCharacter character rest indent column=F.defer(fn()=>case character of #"\n"=>
     F.cons(cell character,rest indent(int 0))
   |_=>if leq indent column then F.cons(cell character,rest indent(add column(int 1)))
       else F.append(copy(subtract indent column)(cell #" "))
          (F.cons(cell character,rest indent(add indent(int 1)))))
 fun indentText chars rest indent column=F.defer(fn()=>case force chars of F.Nil=>rest indent column
   |F.Cons(c,cs)=>indentCharacter(force c)(indentText cs rest)indent column)
 fun indentString s=indentText(text s)
 fun indentBlock block rest indent column=
   let val base=if less indent column then column else indent
       fun after _ finalColumn=rest indent finalColumn
   in block after base column end
 fun indentInterleave separator blocks rest indent column=
   let fun join blocks=case force blocks of F.Nil=>emptyIndent|F.Cons(block,others)=>
       if null others then force block else appendIndent(force block)(appendIndent separator(join others))
   in join blocks rest indent column end
 fun renderIndent block=block emptyOutput(int 0)(int 0)

 fun combineIndent blocks=List.foldr(fn(a,b)=>appendIndent a b)emptyIndent blocks
 fun prettyCore expression:indentSequence=fn rest=>fn indent=>fn column=>
   let fun run blocks=combineIndent blocks rest indent column
       fun parens e=combineIndent[indentString"(",prettyCore e,indentString")"]
       fun right e=case force e of EVar _=>prettyCore e|ENum _=>prettyCore e|EConstr _=>prettyCore e|_=>parens e
       fun left e=case force e of EAp _=>prettyCore e|_=>right e
   in case force expression of EVar n=>run[indentText n]|EConstr n=>run[indentText n]
      |ENum n=>run[indentText(renderInteger n)]
      |EAp(a,b)=>run[left a,indentString" ",right b]
      |ELam(vs,body)=>run[indentString"\\",
          indentInterleave(indentString" ")(map(fn n=>cell(indentText n))vs),
          indentString" -> ",indentBlock(prettyCore body)]
      |ELet(recursive,defs,body)=>
        let val recText=if force recursive then"rec\n  "else"\n  "
            val blocks=map(fn entry=>let val(n,e)=force entry
                in cell(combineIndent[indentText n,indentString" = ",prettyCore e])end)defs
        in run[indentString"let",indentString recText,
             indentBlock(indentInterleave(indentString";\n")blocks),indentString"\nin ",prettyCore body]end
      |ECase(sw,alts)=>
        let val blocks=map(fn entry=>let val(n,alternative)=force entry val(args,e)=force alternative
          in cell(combineIndent[indentString"  ",indentText n,indentString" ",
             indentInterleave(indentString" ")(map(fn n=>cell(indentText n))args),
             indentString" -> ",indentBlock(prettyCore e)])end)alts
        in run[indentString"case ",prettyCore sw,indentString" of\n",
           indentBlock(indentInterleave(indentString";\n")blocks),indentString"\nend"]end
   end
 fun prettyTypeExpression expression:indentSequence=fn rest=>fn indent=>fn column=>
   case force expression of TDefVar n=>indentText n rest indent column
     |TDefCons(n,args)=>combineIndent[indentString"(",indentText n,indentString" ",
        indentInterleave(indentString" ")(map(fn e=>cell(prettyTypeExpression e))args),indentString")"]rest indent column
 fun prettyTypeDefinition definition=
   let val(n,variables,constructors)=force definition
       val alternatives=map(fn alternative=>let val(n,args)=force alternative
         in cell(combineIndent[indentText n,indentString" ",
              indentInterleave(indentString" ")(map(fn e=>cell(prettyTypeExpression e))args)])end)constructors
   in renderIndent(combineIndent[indentText n,indentString" ",
      indentInterleave(indentString" ")(map(fn v=>cell(indentText v))variables),
      indentString" ::= ",indentBlock(indentInterleave(indentString" |\n")alternatives)])end
 fun prettyParsed types expression=F.append(flatMap(fn t=>textConcat[text"\n",prettyTypeDefinition t,text";\n\n"])types)
    (F.append(text";;\n\n")(renderIndent(prettyCore expression)))

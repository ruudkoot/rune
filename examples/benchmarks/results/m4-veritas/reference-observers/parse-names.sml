
 fun reservedHead tokens value=case tokenKind tokens of SOME(Reserved actual)=>equalText actual(text value)|_=>false
 fun byteHead tokens value=case tokenKind tokens of SOME(Reserved actual)=>equalText actual(byte value)|_=>false
 fun parseOperatorType tokens=case tokenKind tokens of SOME(Reserved chars)=>
    (case string chars of"Pre"=>(Pre,tokenTail tokens)|"BinL"=>(BinL,tokenTail tokens)|"BinR"=>(BinR,tokenTail tokens)
      |"Post"=>(Post,tokenTail tokens)|_=>(BinL,tokens))|_=>(BinL,tokens)
 fun parsePrecedence tokens=case tokenKind tokens of SOME(Clear chars)=>
    if digitString chars then(readInteger chars,tokenTail tokens)else(int 1,tokens)|_=>(int 1,tokens)
 fun parseName tokens=L.delay(fn()=>case tokenKind tokens of
    SOME(Reserved chars)=>if equalText chars(text"{")then
       let val after=tokenTail tokens
       in case tokenKind after of SOME(Clear identifier)=>
          let val(kind,after)=parseOperatorType(tokenTail after)
              val(precedence,after)=parsePrecedence after
          in if reservedHead after"}"then(Ok(cell(OperatorName(identifier,precedence,kind))),tokenTail after)
             else(Bad(text"missing '}'"),dummyTokens)end
         |_=>unexpected tokens end
      else unexpected tokens
   |SOME(Clear identifier)=>(Ok(cell(Name identifier)),tokenTail tokens)
   |SOME _=>unexpected tokens|NONE=>(Bad(text"empty identifier"),dummyTokens))
 and unexpected tokens=case tokenHead tokens of NONE=>raise Match|SOME token=>
    (Bad(textConcat[text" unexpected '",displayToken token,text"' (name)"]),dummyTokens)
 fun makeDeclarationFlags names sort typed:flagged=D.delay(fn()=>case force sort of ParseError _=>force sort
   |Operand operand=>(case force operand of ITerm sort=>
       let fun declarations count names=F.defer(fn()=>case force names of F.Nil=>F.empty()|F.Cons(name,rest)=>
              let val dec=cell(SymbolDec(shiftTerm(F.empty())count sort,fromNative[symbolName name,typed]))
              in F.cons(operandDeclaration dec,declarations(add count(int 1))rest)end)
           val declarations=declarations(int 0)names
       in if null declarations then ParseError(text"empty declaration")
          else force(foldRightOne(flaggedDeclarationPair(singleton grouped))declarations)end
      |_=>raise Fail"unexpected term in make_dc")|_=>raise Fail"unexpected term in make_dc")
 fun tryIndexed tokens=if not(byteHead tokens 168)then NONE else
   let val one=tokenTail tokens
   in case tokenKind one of SOME(Clear first)=>
       let val comma=tokenTail one
       in if not(reservedHead comma",")then NONE else
          let val two=tokenTail comma
          in case tokenKind two of SOME(Clear second)=>
             let val after=tokenTail two
             in if byteHead after 169 then SOME(indexedSymbol first second,tokenTail after)
                else if reservedHead after","then
                   let val three=tokenTail after
                   in case tokenKind three of SOME(Clear third)=>
                       let val closing=tokenTail three
                       in if byteHead closing 169 then SOME(indexedConstructor first second third,tokenTail closing)else NONE end
                     |_=>NONE end
                else NONE end
            |_=>NONE end end
     |_=>NONE end

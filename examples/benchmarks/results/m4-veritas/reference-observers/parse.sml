
 fun parseTerm (state:parseState)terminators tokens:parseResult=L.delay(fn()=>
   let val parsed=parseTermParts state terminators tokens
       val(values,remaining)=L.force parsed
   in(foldedApplication(prioritize values),remaining)end)
 and parseTermParts (state:parseState)terminators tokens=L.delay(fn()=>
   let val(tags,sg)=state
       fun more value after=
         let val future=parseTermParts state terminators after
             val values=F.defer(fn()=> #1(L.force future))
             val remaining=C.defer(fn()=> #2(L.force future))
         in(F.cons(value,values),remaining)end
       fun one value remaining=(singleton value,remaining)
       fun afterTerm (parsed:parseResult)=C.defer(fn()=>tokenTail(#2(L.force parsed)))
       fun parsedValue (parsed:parseResult)=D.delay(fn()=>force(#1(L.force parsed)))
       fun ordinaryReserved chars=
         if equalText chars(text"if")then
           let val hyp=parseHypothesis state(singleton(reserved"then"))(tokenTail tokens)
               val declaration=parsedValue hyp val extended=extendParseState declaration state
               val yes=parseTerm extended(singleton(reserved"else"))(afterTerm hyp)
               val no=parseTerm extended terminators(afterTerm yes)
           in one(flaggedConditional declaration(parsedValue yes)(parsedValue no))(C.defer(fn()=> #2(L.force no)))end
         else if equalText chars(text"let")then
           let val dec=parseAbbreviatedDeclaration state(singleton(cell(InfixOperatorToken(text"="))))(tokenTail tokens)
               val value=parseTerm state(singleton(reserved"in"))(afterTerm dec)
               val declaration=parsedValue dec
               val body=parseTerm(extendParseState declaration state)terminators(afterTerm value)
           in one(flaggedLet declaration(parsedValue value)(parsedValue body))(C.defer(fn()=> #2(L.force body)))end
         else if equalText chars(text"recurse")then
           let val clauses=parseRecurseClauses state(F.empty())(tokenTail tokens)
               val(values,after)=L.force clauses
               val result=parseTerm state terminators after
           in one(flaggedRecurse values(parsedValue result))(C.defer(fn()=> #2(L.force result)))end
         else if equalText chars(byte 185)then
           let val argument=parseTerm state(singleton(cell(Reserved(byte 176))))(tokenTail tokens)
               val(values,remaining)=L.force(parseTermParts state terminators(afterTerm argument))
           in(F.cons(operatorValue(SpecialOperator(text""))BinR 100,F.cons(parsedValue argument,values)),remaining)end
         else if equalText chars(text",")then
           let val(values,remaining)=L.force(parseTermParts state(F.cons(reserved"typed",terminators))(tokenTail tokens))
           in(F.cons(operatorValue(SpecialOperator(text","))BinR 20,values),remaining)end
         else if equalText chars(text"typed")then
           let val result=parseTerm state terminators(tokenTail tokens)
           in(fromNative[operatorValue(SpecialOperator(text"typed"))BinL 1,parsedValue result],C.defer(fn()=> #2(L.force result)))end
         else if equalText chars(byte 168)then
           (case tryIndexed tokens of SOME(value,after)=>more value after|NONE=>unexpectedReserved chars)
         else if equalText chars(text"{")then
           let val declaration=parseDeclaration state(singleton(reserved"|"))(tokenTail tokens)
               val decl=parsedValue declaration
               val body=parseTerm(extendParseState decl state)(singleton(reserved"}"))(afterTerm declaration)
           in more(flaggedBinder SubtypeB decl(parsedValue body))(afterTerm body)end
         else if equalText chars(text"[")then
           let val declaration=parseDeclaration state(singleton(reserved"]"))(tokenTail tokens)
               val value=parsedValue declaration
               val(values,after)=L.force(parseTermParts(extendParseState value state)terminators(afterTerm declaration))
           in(F.cons(value,values),after)end
         else if equalText chars(byte 181)then more(operatorValue(SpecialOperator(text"Not"))Pre 60)(tokenTail tokens)
         else if equalText chars(text"(")then
           let val result=parseTerm state(singleton(reserved")"))(tokenTail tokens)
           in more(parsedValue result)(afterTerm result)end
         else if equalText chars(text"@")then one(parseError(text"@ not implemented "))dummyTokens
         else case tokenHead tokens of SOME token=>if terminates terminators token then(F.empty(),tokens)else unexpectedReserved chars|_=>raise Match
       and unexpectedReserved chars=one(parseError(textConcat[text" unexpected '",chars,text"' (term) tmnl: ",
           flatMap displayToken terminators,text"|"]))dummyTokens
   in case tokenKind tokens of NONE=>(F.empty(),C.empty())
     |SOME(Reserved chars)=>ordinaryReserved chars
     |SOME(BinderToken kind)=>
         let val declaration=parseDeclaration state(singleton(reserved"."))(tokenTail tokens)
             val value=parsedValue declaration
             val body=parseTerm(extendParseState value state)terminators(afterTerm declaration)
         in one(flaggedBinder kind value(parsedValue body))(C.defer(fn()=> #2(L.force body)))end
     |SOME(InfixBinderToken chars)=>more(makeInfixBinder chars)(tokenTail tokens)
     |SOME(InfixOperatorToken chars)=>more(makeInfixOperator chars)(tokenTail tokens)
     |SOME(ScanError message)=>one(parseError message)dummyTokens
     |SOME(Clear chars)=>
         let val native=string chars
         in if size native>1 andalso String.sub(native,0)= #"U"andalso digitString(tail chars)then
               more(operandTerm(bareConstant(Universe(readInteger(tail chars)))))(tokenTail tokens)
            else if List.exists(fn value=>value=native)["true","false","bool"]then
               more(operandTerm(bareConstant(case native of"true"=>Truth|"false"=>Falsehood|_=>BoolType)))(tokenTail tokens)
            else let val(found,tag)=fetchTag chars tags
                 in if found then
                      let val(_,kinds,_)=force tag
                          val parsed=parseTagArguments state(F.empty())kinds(tokenTail tokens)
                          val(arguments,after)=L.force parsed
                      in more(flaggedTag tag arguments)after end
                    else more(lookupParsedName chars sg)(tokenTail tokens)end end
   end)
 and parseHypothesis state terminators tokens:parseResult=L.delay(fn()=>
   if reservedHead tokens"["then
     let val result=parseDeclaration state(singleton(reserved"]"))(tokenTail tokens)
         val(declaration,after)=L.force result val after=tokenTail after
     in case tokenHead after of SOME token=>if terminates terminators token then(declaration,after)
          else(parseError(textConcat[text"Unexpected token '",displayToken token,text"'"]),dummyTokens)
        |NONE=>(parseError(text"Unexpected end of file"),dummyTokens)end
   else let val(term,after)=L.force(parseTerm state terminators tokens)
        in(flaggedSymbolDeclaration term(cell(Name(text"_")))(singleton nondependent),after)end)
 and parseDeclaration state terminators tokens:parseResult=L.delay(fn()=>
   let val first=parseOneDeclaration state terminators tokens
       val(value,after)=L.force first
   in if reservedHead after";"then
         let val extended=extendParseState value state
             val(rest,remaining)=L.force(parseDeclaration extended terminators(tokenTail after))
         in(flaggedDeclarationPair(singleton ungrouped)value rest,remaining)end
      else case tokenHead after of SOME token=>if terminates terminators token then(value,after)
           else raise Fail("Bdec: "^string(tokenTexts after)^"\ntmnl: "^string(flatMap displayToken terminators)^"|")
         |NONE=>raise Fail("Bdec: \ntmnl: "^string(flatMap displayToken terminators)^"|")end)
 and tokenTexts tokens=F.defer(fn()=>case L.force tokens of C.Nil=>F.empty()
    |C.Cons(token,rest)=>F.append(displayToken(L.force token))(tokenTexts rest))
 and parseOneDeclaration state terminators tokens:parseResult=L.delay(fn()=>if reservedHead tokens"("then
       let val(value,after)=L.force(parseDeclaration state(singleton(reserved")"))(tokenTail tokens))
       in(value,tokenTail after)end
     else L.force(parseDeclarationNames state(F.cons(reserved";",terminators))(F.empty())tokens))
 and parseDeclarationNames state terminators names tokens:parseResult=L.delay(fn()=>
   let val(result,after)=L.force(parseName tokens)
   in case result of Bad message=>(parseError message,dummyTokens)|Ok name=>
      if reservedHead after","then L.force(parseDeclarationNames state terminators(F.cons(name,names))(tokenTail after))
      else case tokenKind after of SOME(InfixOperatorToken chars)=>if equalText chars(text":")then
          let val(sort,remaining)=L.force(parseTerm state(F.cons(reserved";",terminators))(tokenTail after))
          in(makeDeclarationFlags(reverse(F.cons(name,names)))sort declarationTyped,remaining)end
         else(makeDeclarationFlags(reverse(F.cons(name,names)))(operandTerm(bareConstant(Universe(int 0))))declarationUntyped,after)
       |_ =>(makeDeclarationFlags(reverse(F.cons(name,names)))(operandTerm(bareConstant(Universe(int 0))))declarationUntyped,after)
   end)
 and parseAbbreviatedDeclaration state terminators tokens:parseResult=L.delay(fn()=>if reservedHead tokens"("then
       let val(value,after)=L.force(parseDeclaration state(singleton(reserved")"))(tokenTail tokens))
       in(value,tokenTail after)end
     else let val(result,after)=L.force(parseName tokens)
          in case result of Ok name=>(flaggedSymbolDeclaration(operandTerm(bareConstant(Universe(int 0))))name(F.empty()),after)
             |Bad message=>(parseError message,dummyTokens)end)
 and parseRecurseClauses state clauses tokens=L.delay(fn()=>
   let val(value,after)=L.force(parseAtomicTerm state(singleton(reserved"end"))tokens)
   in if reservedHead after"end"then
        if reservedHead(tokenTail after)"typed"then(F.cons(value,clauses),tokenTail(tokenTail after))
           else(singleton(parseError(text" recurse must be typed ")),dummyTokens)
      else L.force(parseRecurseClauses state(F.cons(value,clauses))after)end)
 and parseAtomicTerm state terminators tokens:parseResult=L.delay(fn()=>
   let val(_,sg)=state
       fun wrong()=case tokenHead tokens of SOME token=>
          (parseError(textConcat[text" unexpected '",displayToken token,text"' (aterm -- no tmnl check)"]),dummyTokens)
         |NONE=>raise Match
   in case tryIndexed tokens of SOME value=>value|NONE=>case tokenKind tokens of
       SOME(Reserved chars)=>if equalText chars(text"{")then
           let val(dec,after)=L.force(parseDeclaration state(singleton(reserved"|"))(tokenTail tokens))
               val(body,after)=L.force(parseTerm(extendParseState dec state)(singleton(reserved"}"))(tokenTail after))
           in(flaggedBinder SubtypeB dec body,after)end
         else if equalText chars(text"(")then
           let val(value,after)=L.force(parseTerm state(singleton(reserved")"))(tokenTail tokens))
           in(value,tokenTail after)end
         else wrong()
      |SOME(Clear chars)=>
         let val native=string chars
             val value=if size native>1 andalso String.sub(native,0)= #"U"andalso digitString(tail chars)then
                   operandTerm(bareConstant(Universe(readInteger(tail chars))))
                else if List.exists(fn s=>native=s)["true","false","bool"]then
                   operandTerm(bareConstant(case native of"true"=>Truth|"false"=>Falsehood|_=>BoolType))
                else lookupParsedName chars sg
         in(value,tokenTail tokens)end
      |_=>wrong()end)
 and parseTagArguments state arguments kinds tokens=L.delay(fn()=>case force kinds of F.Nil=>(reverse arguments,tokens)
   |F.Cons(kind,rest)=>
      let val(_,sg)=state
          val(arg,after)=case force kind of IntArg=>L.force(parseIntegerList tokens)
            |other=>let val(value,after)=L.force(parseAtomicTerm state(F.empty())tokens)
                    in(case other of TermArg=>cell(TagTerm(buildTerm sg value))
                        |DerivArg=>cell(TagTheorem(parseDerivation state value))|_=>raise Match,after)end
      in L.force(parseTagArguments state(F.cons(arg,arguments))rest after)end)
 and parseIntegerList tokens=L.delay(fn()=>if byteHead tokens 168 then L.force(parseIntegerItems(F.empty())(tokenTail tokens))
    else(cell(TagTerm(termError"Malformed integer list")),dummyTokens))
 and parseIntegerItems values tokens=L.delay(fn()=>case tokenKind tokens of SOME(Clear chars)=>
       if digitString chars then L.force(parseIntegerSeparator(F.cons(readInteger chars,values))(tokenTail tokens))else invalidInteger values tokens
   |SOME(Reserved chars)=>if equalText chars(byte 169)then(cell(TagInt values),tokenTail tokens)else invalidInteger values tokens
   |_=>invalidInteger values tokens)
 and invalidInteger values tokens=case tokenHead tokens of SOME token=>
       (cell(TagTerm(termError("Malformed item in integer list: "^string(displayToken token)))),dummyTokens)
      |NONE=>(cell(TagTerm(termError"Unexpected end of input")),dummyTokens)
 and parseIntegerSeparator values tokens=L.delay(fn()=>if byteHead tokens 169 then(cell(TagInt values),tokenTail tokens)
    else if reservedHead tokens","then L.force(parseIntegerItems values(tokenTail tokens))
    else(cell(TagTerm(termError(" ',' or '"^String.str(Char.chr 169)^"' expected "))),dummyTokens))
 and parseDerivation state flagged:theorem=D.delay(fn()=>case force flagged of Operand operand=>
       (case force operand of ITerm term=>force(derive state term)|_=>force(theoremError"unimplemented feature"))
      |_=>force(theoremError"unimplemented feature"))
 and derive(state:parseState)term:theorem=D.delay(fn()=>
   let val(tags,sg)=state
   in case force term of TagId(tag,arguments)=>
       let val(name,_,functions)=force tag
           fun find values=case force values of F.Nil=>force(theoremError("cannot convert tag "^string name^" to theorem"))
             |F.Cons(function,rest)=>case force function of TheoremFunction function=>force(function arguments)|_=>find rest
       in find functions end
      |Binder(DeltaB,dec,body,_,_)=>
        let val declaration=buildDeclaration sg dec
            val extended=extendSignature declaration sg
            val proof=derive(tags,extended)body
            val(ty,_,signatureValue)=L.force(internalTerm(wrappedDeclarationType declaration))
        in case force(termType signatureValue ty)of Constant(BoolType,_,_)=>force(discharge proof)
            |Constant(Universe _,_,_)=>force(generalize proof)|_=>force(theoremError"dc type not bool or univ")end
      |App(first,second,_,_)=>
        let val proof=derive state first
            val(body,_)=L.force(internalTheorem proof)
        in case force body of Binder(ForallB,_,_,_,_)=>force(specialize proof(buildITerm sg second))
           |Binder(ImpB,_,_,_,_)=>force(modusPonens proof(derive state second))
           |_=>force(theoremError("not "^String.str(Char.chr 177)^" or "^String.str(Char.chr 182)))end
      |PairTerm(first,second,_,_,_)=>
        let val a=derive state first val b=derive state second
            val script=textConcat[byte 177,text" a:bool. ",byte 177,text" b:bool.a ",byte 182,text" b ",byte 182,text" a ",byte 179,text" b"]
            val(parsed,_)=L.force(parseTerm state(singleton(reserved""))(tokenize script))
            val proof=tautology(buildTerm sg parsed)
            val specialized=specialize(specialize proof(wrappedTheoremType a))(wrappedTheoremType b)
        in force(modusPonens(modusPonens specialized a)b)end
      |Sym(i,j,_,_)=>force(axiom sg i j)
      |_=>force(theoremError(" Invalid construction: "^string(unparseITerm(internalSignature sg)term)))end)
 fun driveParse state chars=parseTerm state(singleton(reserved""))(tokenize chars)
 fun parseIterm state chars=D.delay(fn()=>let val(value,_)=L.force(driveParse state chars)in force value end)
 fun parseTermSpec sg tags chars=
   let val value=parseIterm(tags,sg)chars
   in case force value of Operand operand=>(case force operand of ITerm term=>Ok term|_=>raise Match)
      |ParseError message=>Bad message|_=>raise Match end
 fun parseWrappedTerm state chars=let val(_,sg)=state in buildTerm sg(parseIterm state chars)end

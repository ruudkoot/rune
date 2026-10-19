
 fun attachTermInformation term types attrs:term=D.delay(fn()=>case force term of TermError _=>force term
   |_=>case force types of F.Nil=>force(setTermInformation term(F.empty())attrs)
     |F.Cons(sort,_)=>let val(_,ty,_)=L.force(internalTerm term)
       in if equalTerm ty sort then force(setTermInformation term(F.empty())attrs)
          else force(termError"Invalid type specification")end)
 fun buildTerm signatureValue flagged:term=D.delay(fn()=>
   let fun invalid()=raise Fail("Error: "^string(unparseFlagged(internalSignature signatureValue)flagged)^"|\n")
   in case force flagged of Operand operand=>
    (case force operand of ITerm term=>force(buildITerm signatureValue term)|_=>invalid())|_=>invalid()end)
 and buildITerm signatureValue term:term=D.delay(fn()=>case force term of
    Sym(i,j,types,attrs)=>force(attachTermInformation(symbol signatureValue i j)types attrs)
   |App(first,second,types,attrs)=>force(attachTermInformation(application(buildITerm signatureValue first)(buildITerm signatureValue second))types attrs)
   |PairTerm(first,second,third,types,attrs)=>
       let val first=buildITerm signatureValue first
           val second=buildITerm signatureValue second
           val third=D.delay(fn()=>case force third of Constant(Universe n,_,_)=>if equalInt n(int ~1)then
                 let val dec=symbolDeclaration(wrappedTermType first)
                     val extended=extendSignature dec signatureValue
                     val shifted=shiftWrappedTerm(int 1)extended(wrappedTermType second)
                 in force(sigmaFormation shifted)end
                else force(buildITerm signatureValue third)
              |_=>force(buildITerm signatureValue third))
       in force(attachTermInformation(pairFormation first second third)types attrs)end
   |Binder(kind,dec,body,types,attrs)=>
       let val declaration=buildDeclaration signatureValue dec
           fun expanded()=buildITerm(extendSignature declaration signatureValue)body
           val term=case kind of LambdaB=>lambdaFormation(expanded())|ForallB=>universal(expanded())
             |ImpB=>implication(expanded())|ExistsB=>existential(expanded())|PiB=>piFormation(expanded())
             |SigmaB=>sigmaFormation(expanded())|SubtypeB=>subtypeFormation(expanded())
             |DeltaB=>termError("Invalid occurance of "^String.str(Char.chr 196))
             |ChooseB=>termError("Invalid occurance of "^String.str(Char.chr 229))
       in force(attachTermInformation term types attrs)end
   |Constant(kind,types,attrs)=>
       let val term=case kind of BoolType=>boolean signatureValue|Truth=>truth signatureValue
              |Falsehood=>falsehood signatureValue|Universe i=>universe signatureValue i
       in force(attachTermInformation term types attrs)end
   |Binary(kind,first,second,types,attrs)=>
       let val first=buildITerm signatureValue first
           val second=buildITerm signatureValue second
           val term=case kind of AndB=>conjunction first second|OrB=>disjunction first second
              |EqualB=>equality first second|IsSubtypeB=>isSubtype first second
       in force(attachTermInformation term types attrs)end
   |Unary(NotU,body,types,attrs)=>force(attachTermInformation(negation(buildITerm signatureValue body))types attrs)
   |Cond(dec,first,second,types,attrs)=>
       let val firstDec=buildDeclaration signatureValue dec
           val secondDec=symbolDeclaration(negation(wrappedDeclarationType firstDec))
           val first=buildITerm(extendSignature firstDec signatureValue)first
           val second=buildITerm(extendSignature secondDec signatureValue)second
       in force(attachTermInformation(conditional first second)types attrs)end
   |Const(i,j,k,types,attrs)=>force(attachTermInformation(constructor signatureValue i j k)types attrs)
   |Recurse(terms,sort,types,attrs)=>
       force(attachTermInformation(recurse(map(buildITerm signatureValue)terms)(buildITerm signatureValue sort))types attrs)
   |TagId(tag,arguments)=>
       let val(name,_,functions)=force tag
           fun find functions=case force functions of F.Nil=>force(termError("cannot convert tag "^string name^" to term"))
             |F.Cons(function,rest)=>case force function of TermFunction function=>force(function arguments)|_=>find rest
       in find functions end
   |_=>let val sg=internalSignature signatureValue
       in raise Fail("Unimplemented construction: "^string(unparseITerm sg term)^"|\n")end)
 and buildDeclaration signatureValue dec:declaration=D.delay(fn()=>case force dec of SymbolDec(term,attrs)=>
       let val sg=internalSignature signatureValue
           val declaration=case force(termType sg term)of Constant(BoolType,_,_)=>axiomDeclaration(buildITerm signatureValue term)
              |_=>symbolDeclaration(buildITerm signatureValue term)
       in force(setDeclarationInformation declaration attrs)end
   |AxiomDec(term,attrs)=>force(setDeclarationInformation(axiomDeclaration(buildITerm signatureValue term))attrs)
   |DecPair(first,second,attrs)=>
       let val first=buildDeclaration signatureValue first
           val second=buildDeclaration(extendSignature first signatureValue)second
       in force(setDeclarationInformation(declarationPair second)attrs)end
   |_=>raise Fail"Only symbol_dec so far implemented")
 fun buildSignature signatureValue:signatureValue=D.delay(fn()=>case force signatureValue of
    EmptySig _=>force emptySignature
   |Extend(dec,parent,_)=>let val parent=buildSignature parent in force(extendSignature(buildDeclaration parent dec)parent)end
   |_=>raise Fail"unimplemented signature constructor")

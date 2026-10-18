 fun jsonInt x=Int.toString(D.force x)
 fun jsonInts xs=jsonSequence Int.toString xs
 fun jsonPriority cell=case D.force cell of No=>jsonArray[jsonQuote"No"]
   |Prio(assoc,n)=>jsonArray[jsonQuote"Prio",jsonQuote(case D.force assoc of LeftAssoc=>"Left"|RightAssoc=>"Right"|NonAssoc=>"None"),jsonInt n]
 fun jsonNamedProd(lhs,rhs,code,prio)=
   let val(body,used)=D.force code
   in jsonArray[jsonInt lhs,jsonInts rhs,jsonArray[jsonText body,jsonInts used],jsonPriority prio]end
 fun jsonStart(name,n,start,partial)=jsonArray[jsonText name,jsonInt n,jsonInt start,if D.force partial then"true"else"false"]
 fun jsonGrammar g=jsonArray[
   jsonSequence jsonNamedProd(productions g),
   jsonSequence(fn n=>jsonArray[Int.toString n,jsonInts(lookupProdsOfName g n)])(nonterminals g),
   jsonSequence(fn(n,s)=>jsonArray[jsonInt n,jsonText s])(tokenSpecs g),
   jsonInts(terminals g),jsonInts(nonterminals g),jsonSequence jsonStart(starts g),
   jsonSequence(fn(n,value)=>jsonArray[Int.toString n,jsonOption jsonText value])(A.assocs(types g)),
   jsonSequence(fn(n,value)=>jsonArray[Int.toString n,jsonText value])(A.assocs(tokenNames g)),
   Int.toString(firstNonterm g),Int.toString(firstTerm g),Int.toString(eof g),
   jsonSequence(fn(n,p)=>jsonArray[jsonInt n,jsonPriority p])(priorities g),
   jsonText(tokenType g),if importedIdentity g then"true"else"false",
   let val(b,a,c,d,e)=monad g in jsonArray[if b then"true"else"false",jsonText a,jsonText c,jsonText d,jsonText e]end,
   (case expect g of NONE=>"null"|SOME n=>Int.toString n),
   jsonSequence jsonPair(attributes g),jsonText(attributeType g),
   (case lexer g of NONE=>"null"|SOME pair=>jsonPair pair),
   (case errorHandler g of NONE=>"null"|SOME text=>jsonText text)]
 fun grammarJSON input=
   ((case parse(X.input input)1 of
      X.Failed message=>jsonArray[jsonQuote"parse-error",jsonText message]
     |X.Ok ast=>(case mangler"input.y"ast of
        Rejected errors=>jsonArray[jsonQuote"mangle-error",jsonSequence jsonText errors]
       |Succeeded grammar=>jsonArray[jsonQuote"grammar",jsonGrammar(L.force grammar)]))
    handle Fail message=>jsonArray[jsonQuote"exception",jsonQuote message])

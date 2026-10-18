 fun jsonQuote s=
   let fun escape #"\""="\\\""|escape #"\\"="\\\\"|escape c=
         if Char.ord c<32 then
           let val h=String.map Char.toLower(Int.fmt StringCvt.HEX(Char.ord c))
           in "\\u"^String.implode(List.tabulate(4-String.size h,fn _=> #"0"))^h end
         else String.str c
   in "\""^String.translate escape s^"\""end
 fun jsonArray values="["^String.concatWith","values^"]"
 fun jsonText value=jsonQuote(X.string value)
 fun jsonOption out cell=case D.force cell of NONE=>"null"|SOME value=>out value
 fun jsonSequence out values=jsonArray(List.map out(F.toList values))
 fun jsonTag name fields=jsonArray(jsonQuote name::fields)
 fun jsonPair(a,b)=jsonArray[jsonText a,jsonText b]
 fun jsonDirective value=case value of
    TokenType value=>jsonTag"TokenType"[jsonText value]
   |TokenSpec values=>jsonTag"TokenSpec"[jsonSequence jsonPair values]
   |TokenName(name,start,partial)=>jsonTag"TokenName"[jsonText name,jsonOption jsonText start,
       if D.force partial then"true"else"false"]
   |TokenLexer(a,b)=>jsonTag"TokenLexer"[jsonText a,jsonText b]
   |TokenImportedIdentity=>jsonTag"TokenImportedIdentity"[]
   |TokenMonad(a,b,c,d)=>jsonTag"TokenMonad"[jsonText a,jsonText b,jsonText c,jsonText d]
   |TokenNonassoc values=>jsonTag"TokenNonassoc"[jsonSequence jsonText values]
   |TokenRight values=>jsonTag"TokenRight"[jsonSequence jsonText values]
   |TokenLeft values=>jsonTag"TokenLeft"[jsonSequence jsonText values]
   |TokenExpect count=>jsonTag"TokenExpect"[Int.toString(D.force count)]
   |TokenError value=>jsonTag"TokenError"[jsonText value]
   |TokenAttributetype value=>jsonTag"TokenAttributetype"[jsonText value]
   |TokenAttribute(a,b)=>jsonTag"TokenAttribute"[jsonText a,jsonText b]
 fun jsonRule(names,code,line,priority)=jsonArray[
   jsonSequence jsonText names,jsonText code,Int.toString(D.force line),jsonOption jsonText priority]
 fun jsonProduction(name,rules,ty)=jsonArray[
   jsonText name,jsonSequence jsonRule rules,jsonOption jsonText ty]
 fun jsonAST ast=case D.force ast of AbsSyn(header,dirs,productions,footer)=>
   jsonTag"AbsSyn"[jsonOption jsonText header,jsonSequence jsonDirective dirs,
      jsonSequence jsonProduction productions,jsonOption jsonText footer]
 fun parseJSON value=
   case parse(X.input value)1 of X.Ok ast=>jsonAST ast
    |X.Failed message=>jsonArray[jsonQuote"error",jsonText message]

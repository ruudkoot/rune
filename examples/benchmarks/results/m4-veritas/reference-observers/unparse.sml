
 fun integerText number=text(String.map(fn #"~"=> #"-"|c=>c)(Int.toString(force number)))
 fun operatorText Pre=text"Pre"|operatorText BinL=text"BinL"|operatorText BinR=text"BinR"|operatorText Post=text"Post"
 fun unparseName value=F.defer(fn()=>case force value of Name chars=>chars|OperatorName(chars,precedence,kind)=>
    textConcat[text"{",chars,text" ",operatorText kind,text" ",integerText precedence,text"}"])
 fun unparseBinder LambdaB=byte 236|unparseBinder ForallB=byte 177|unparseBinder ExistsB=byte 178
   |unparseBinder PiB=byte 208|unparseBinder SigmaB=byte 211|unparseBinder ChooseB=byte 229|unparseBinder DeltaB=byte 196
   |unparseBinder _=raise Match
 fun unparseBinary OrB=byte 180|unparseBinary AndB=byte 179|unparseBinary EqualB=text"="|unparseBinary IsSubtypeB=byte 172
 fun unparseConstant Truth=text"True"|unparseConstant Falsehood=text"False"|unparseConstant BoolType=text"Bool"
   |unparseConstant(Universe i)=F.append(text"U")(integerText i)
 fun declarationName attrs=D.delay(fn()=>case force(attributeValue NameStyle attrs)of SymbolName value=>force value
    |DatatypeName _=>Name(text" Unexpected Datatype ")|_=>raise Match)
 fun basicName value=F.defer(fn()=>case force value of Name chars=>chars|OperatorName(chars,_,_)=>chars)
 fun constructorName names index=F.defer(fn()=>case force names of F.Nil=>text" Constructor not found "
   |F.Cons(n,rest)=>if less(int 0)index then constructorName rest(subtract index(int 1))
      else if equalInt index(int 0)then basicName n else raise Match)
 fun printedSymbol signatureValue first second constructor=F.defer(fn()=>case force signatureValue of
    Extend(declaration,parent,_)=>if equalInt first(int 0)then lookupDeclaration declaration(F.empty())second constructor
       else if less(int 0)first then printedSymbol parent(subtract first(int 1))second constructor else text"symbol not found "
   |_=>text"symbol not found ")
 and lookupDeclaration declaration stack index constructor=F.defer(fn()=>
   let fun next()=case force stack of F.Cons(dec,rest)=>if less(int 0)index then
          lookupDeclaration dec rest(subtract index(int 1))constructor else text" symbol not found "
         |F.Nil=>text" symbol not found "
   in case force declaration of
       SymbolDec(_,attrs)=>if equalInt index(int 0)then basicName(declarationName attrs)else next()
      |AxiomDec(_,attrs)=>if equalInt index(int 0)then basicName(declarationName attrs)else next()
      |Def(_,_,attrs)=>if equalInt index(int 0)then basicName(declarationName attrs)else next()
      |Data(_,_,attrs)=>if equalInt index(int 0)then
          let val names=F.defer(fn()=>case force(attributeValue NameStyle attrs)of
               SymbolName value=>singleton value|DatatypeName values=>values|_=>raise Match)
          in constructorName names constructor end else next()
      |DecPair(first,second,attrs)=>if less(int 0)index then
         (case force(attributeValue DecStyle attrs)of Grouped=>lookupDeclaration first(F.cons(second,stack))(subtract index(int 1))constructor
          |Ungrouped=>lookupDeclaration first(F.cons(second,stack))(subtract index(int 1))constructor|_=>raise Match)
        else next()end)
 fun unparseITerm signatureValue term=F.defer(fn()=>case force term of
    Sym(i,j,_,attrs)=>(case force(attributeValue SymbolStyle attrs)of
       Named=>printedSymbol signatureValue i j(int ~1)
      |Indexed=>textConcat[byte 168,integerText i,text",",integerText j,byte 169]|_=>raise Match)
   |Const(i,j,k,_,_)=>printedSymbol signatureValue i j k
   |App(a,b,_,_)=>textConcat[text"(",unparseITerm signatureValue a,text" ",unparseITerm signatureValue b,text")"]
   |PairTerm(a,b,c,_,_)=>textConcat[text"((",unparseITerm signatureValue a,text" , ",unparseITerm signatureValue b,
        text") : ",unparseITerm signatureValue c,text")"]
   |Binder(SubtypeB,dec,body,_,_)=>textConcat[text"{",unparseDeclaration signatureValue dec,text" | ",
        unparseITerm(cell(Extend(dec,signatureValue,F.empty())))body,text"}"]
   |Binder(ImpB,dec,body,_,_)=>textConcat[text" [",unparseDeclaration signatureValue dec,text"] ",byte 182,text" ",
        unparseITerm(cell(Extend(dec,signatureValue,F.empty())))body]
   |Binder(kind,dec,body,_,_)=>textConcat[text"(",unparseBinder kind,unparseDeclaration signatureValue dec,text". ",
        unparseITerm(cell(Extend(dec,signatureValue,F.empty())))body,text")"]
   |Constant(kind,_,_)=>unparseConstant kind
   |Unary(_,body,_,_)=>textConcat[text" ",byte 181,unparseITerm signatureValue body]
   |Binary(kind,a,b,_,_)=>textConcat[text"(",unparseITerm signatureValue a,text" ",unparseBinary kind,text" ",unparseITerm signatureValue b,text")"]
   |Cond(dec,a,b,_,_)=>let val extended=cell(Extend(dec,signatureValue,F.empty()))
      in textConcat[text" if [",unparseDeclaration signatureValue dec,text"] then ",unparseITerm extended a,
            text" else ",unparseITerm extended b]end
   |Recurse(terms,ty,_,_)=>textConcat[text"\nrecurse\n\t",flatMap(fn term=>F.append(unparseITerm signatureValue term)(text"\n\t"))terms,
        text"\nend typed ",unparseITerm signatureValue ty]
   |TagId(tag,args)=>let val(name,_,_)=force tag
        fun arg value=F.defer(fn()=>case force value of TagTerm term=>unparseWrappedTerm term
            |TagTheorem theorem=>unparseWrappedTheorem theorem
            |TagInt indices=>textConcat[byte 168,flatMap(fn index=>F.append(text",")(integerText index))indices,byte 169])
      in textConcat[text"( ",name,flatMap(fn value=>F.append(text" ")(arg value))args,text" )"]end
   |ITermError message=>message)
 and unparseDeclaration signatureValue declaration=F.defer(fn()=>case force declaration of
    SymbolDec(term,attrs)=>textConcat[unparseName(declarationName attrs),text" : ",unparseITerm signatureValue term]
   |AxiomDec(term,attrs)=>textConcat[unparseName(declarationName attrs),text" :a: ",unparseITerm signatureValue term]
   |Def(term,_,attrs)=>textConcat[unparseName(declarationName attrs),text" ",byte 189,text" ",unparseITerm signatureValue term]
   |DecPair(first,second,_)=>textConcat[text" ( ",unparseDeclaration signatureValue first,text" ; ",
        unparseDeclaration(cell(Extend(first,signatureValue,F.empty())))second,text" ) "]
   |Data(declarations,constructors,attrs)=>
      let val names=F.defer(fn()=>case force(attributeValue NameStyle attrs)of SymbolName _=>singleton(cell(Name(text" Unexpected Symbol ")))
            |DatatypeName names=>names|_=>raise Match)
          val n=head names
          val arguments=flatMap(fn dec=>textConcat[text"(",unparseDeclaration signatureValue dec,text") "])declarations
          fun extend signatureValue declarations=case force declarations of F.Nil=>signatureValue
            |F.Cons(dec,rest)=>extend(cell(Extend(dec,signatureValue,F.empty())))rest
          val universe=bareConstant(Universe(int 0))
          val typeDeclaration=cell(SymbolDec(universe,singleton(symbolName n)))
          val extended=cell(Extend(typeDeclaration,extend signatureValue(reverse declarations),F.empty()))
          fun constructorRows names rows=F.defer(fn()=>case(force names,force rows)of(F.Nil,F.Nil)=>F.empty()
            |(F.Cons(n,names),F.Cons(args,rows))=>textConcat[unparseName n,text" ",
               flatMap(fn arg=>F.append(unparseITerm extended arg)(text" "))args,text" | ",constructorRows names rows]|_=>raise Match)
      in textConcat[text"datatype ",unparseName n,text" ",arguments,text" = ",constructorRows(tail names)constructors]end)
 and unparseSignature signatureValue=F.defer(fn()=>case force signatureValue of EmptySig _=>F.empty()
   |Extend(dec,parent,_)=>textConcat[unparseDeclaration(cell(EmptySig(F.empty())))dec,text" ;\n",unparseSignature parent]
   |_=>raise Match)
 and unparseWrappedTheorem theorem=F.defer(fn()=>case force theorem of TH(body,sg)=>textConcat[text"Theorem: ",unparseITerm sg body,text"\n"]
   |TheoremError message=>textConcat[text"Invalid theorem: ",message,text"\n"])
 and unparseWrappedTerm term=F.defer(fn()=>case force term of TM(body,ty,sg)=>textConcat[text"Term: ",unparseITerm sg body,
       text"\nType: ",unparseITerm sg ty,text"\nSig: ",unparseSignature sg,text"\n"]
   |TermError message=>textConcat[text"\nTerm formation error\n",message,text"\n"])
 fun unparseFlagged signatureValue flagged=F.defer(fn()=>case force flagged of ParseError message=>F.append message(text"\n")
   |Operand operand=>(case force operand of ITerm term=>unparseITerm signatureValue term
       |IDec dec=>unparseDeclaration signatureValue dec|TypeApp value=>F.append(text"Unparse TypApp: ")(unparseFlagged signatureValue value)
       |_=>text"unparse unknown")
   |Operator(operator,kind,precedence)=>(case force operator of
       TermOperator term=>textConcat[unparseITerm signatureValue term,text"{tpe",operatorText kind,text"prc",integerText precedence,text"}\n"]
      |SpecialOperator name=>if equalText name(text"")then text"unparse operator"else
          if equalText name(text"typed")then text"Unparse 'typed'"else text"unparse unknown"
      |_=>text"unparse unknown"))
 fun displayToken token=F.defer(fn()=>case force token of Reserved value=>value|Clear value=>value|BinderToken kind=>unparseBinder kind
   |InfixBinderToken value=>value|InfixOperatorToken value=>value|ScanError message=>F.append(text"Invalid token: ")message)


 type parseState=tagData F.seq*signatureValue
 type parseResult=(flagged*tokenStream)L.delay
 fun tokenHead tokens=case L.force tokens of C.Nil=>NONE|C.Cons(value,_)=>SOME(L.force value)
 fun tokenTail tokens=C.defer(fn()=>case L.force tokens of C.Nil=>raise Empty|C.Cons(_,rest)=>rest)
 fun tokenKind tokens=case tokenHead tokens of NONE=>NONE|SOME token=>SOME(force token)
 fun reserved value=cell(Reserved(text value))
 fun equalToken first second=case(force first,force second)of
    (Reserved a,Reserved b)=>equalText a b|(Clear a,Clear b)=>equalText a b
   |(BinderToken a,BinderToken b)=>a=b|(InfixBinderToken a,InfixBinderToken b)=>equalText a b
   |(InfixOperatorToken a,InfixOperatorToken b)=>equalText a b|(ScanError a,ScanError b)=>equalText a b|_=>false
 fun terminates tokens token=any(equalToken token)tokens
 val dummyTokens:tokenStream=tokenCons(reserved"")(C.empty())
 fun operatorValue operator kind precedence=cell(Operator(cell operator,kind,int precedence))
 fun makeInfixBinder chars=
   let val(kind,precedence)=case string chars of
       s=>case Char.ord(String.sub(s,0))of 167=>(LambdaB,5)|183=>(PiB,80)|184=>(SigmaB,90)|182=>(ImpB,20)|187=>(DeltaB,10)|_=>raise Match
   in operatorValue(BinderOperator kind)BinR precedence end
 fun makeInfixOperator chars=if equalText chars(text":")then operatorValue(SpecialOperator chars)BinL 15 else
   let val(kind,precedence)=case string chars of"="=>(EqualB,15)|s=>case Char.ord(String.sub(s,0))of
          179=>(AndB,40)|180=>(OrB,30)|172=>(IsSubtypeB,70)|_=>raise Match
   in operatorValue(InfixOperator kind)BinR precedence end
 fun swapOperator operator operands=F.defer(fn()=>case force operands of F.Nil=>singleton operator
   |F.Cons(top,rest)=>F.cons(flaggedApplication operator top,rest))
 fun addOperator operator kind operands=F.defer(fn()=>case kind of Post=>operands
   |_=>case force operands of F.Cons(argument,rest)=>(case force rest of F.Cons(function,tail)=>
         F.cons(flaggedApplication function argument,tail)|_=>singleton(parseError(text" Insufficient arguments for operator")))
     |_=>singleton(parseError(text" Insufficient arguments for operator")))
 fun flushOperators operands operators previous compare=L.delay(fn()=>case force operators of F.Nil=>(operands,F.empty())
   |F.Cons(operator,rest)=>case force operator of Operator(kind,style,precedence)=>
       if less precedence previous orelse compare operator then(operands,operators)
       else L.force(flushOperators(addOperator kind style operands)rest previous compare)|_=>raise Match)
 fun prioritize values=
   let fun loop operands operators wasOperand values=F.defer(fn()=>case force values of F.Nil=>
          let val(result,_)=L.force(flushOperators operands operators(int ~1)(fn _=>false))in result end
        |F.Cons(value,rest)=>case force value of ParseError _=>singleton value
          |Operand _=>if wasOperand then
               loop operands operators true(F.cons(operatorValue(SpecialOperator(text""))BinL 100,values))
             else loop(F.cons(value,operands))operators true rest
          |Operator(_,Pre,_)=>loop(F.cons(value,operands))(F.cons(value,operators))false rest
          |Operator(_,style,precedence)=>
             let fun compare operator=case force operator of Operator(_,BinR,other)=>leq other precedence|_=>false
                 val(result,remaining)=L.force(flushOperators operands operators precedence
                    (if style=BinR then compare else fn _=>false))
                 val changed=swapOperator value result
             in if style=Post then loop changed remaining wasOperand rest
                else loop changed(F.cons(value,remaining))false rest end)
       val result=loop(F.empty())(F.empty())false values
   in F.defer(fn()=>if null result then singleton(parseError(text"Empty term"))else result)end
 fun foldedApplication values=foldLeft flaggedApplication(head values)(tail values)
 fun isSingletonList values=case force values of F.Cons(_,rest)=>null rest|_=>false
 fun lookupParsedName name signatureValue=
   let fun signatureAt sg i:flagged=D.delay(fn()=>case force sg of EmptySig _=>ParseError(F.append(text" Undefined symbol: ")name)
         |Extend(dec,parent,_)=>let val(found,value)=declarationAt dec(F.empty())i(int 0)
             in if found then force(L.force value)else force(signatureAt parent(add i(int 1)))end|_=>raise Match)
       and declarationAt dec stack i j=
         let val(found,value)=declarationHere dec stack i j
         in if found then(found,value)else case force stack of F.Nil=>(false,L.delay(fn()=>raise Fail""))
           |F.Cons(next,rest)=>declarationAt next rest i(add j(int 1))end
       and declarationHere dec stack i j=case force dec of DecPair(a,b,_)=>declarationAt a(F.cons(b,stack))i(add j(int 1))
         |SymbolDec(_,attrs)=>namedAttribute attrs i j
         |AxiomDec(_,attrs)=>namedAttribute attrs i j
         |Def(_,_,attrs)=>if isSingletonList attrs then namedAttribute attrs i j else raise Match
         |Data(_,_,attrs)=>if isSingletonList attrs then
             (case force(#2(force(head attrs)))of DatatypeName names=>constructorNames names i j(int 0)|_=>raise Match)
            else raise Match
       and namedAttribute attrs i j=case force attrs of F.Nil=>raise Match|F.Cons(attribute,_)=>
          (case force(#2(force attribute))of SymbolName declared=>named declared i j|_=>raise Match)
       and named declared i j=
         let val term=cell(Sym(i,j,F.empty(),singleton symbolNamed))
         in case force declared of Name actual=>if equalText name actual then
              (true,L.delay(fn()=>operandTerm term))else(false,L.delay(fn()=>raise Fail""))
           |OperatorName(actual,precedence,kind)=>if equalText name actual then
              (true,L.delay(fn()=>cell(Operator(cell(TermOperator term),kind,precedence))))
             else(false,L.delay(fn()=>raise Fail""))end
       and constructorNames names i j k=case force names of F.Nil=>(false,L.delay(fn()=>raise Fail""))
         |F.Cons(declared,rest)=>
           let val term=cell(Const(i,j,k,F.empty(),singleton symbolNamed))
               val(actual,operator)=case force declared of Name actual=>(actual,NONE)
                  |OperatorName(actual,precedence,kind)=>(actual,SOME(precedence,kind))
           in if not(equalText actual name)then constructorNames rest i j(add k(int 1))
              else(true,L.delay(fn()=>case operator of NONE=>operandTerm term
                    |SOME(precedence,kind)=>cell(Operator(cell(TermOperator term),kind,precedence))))end
   in signatureAt(internalSignature signatureValue)(int 0)end
 fun extendParseState flagged(tags,sg):parseState=case force flagged of Operand operand=>
    (case force operand of IDec dec=>(tags,extendSignature(buildDeclaration sg dec)sg)|_=>raise Match)|_=>raise Match
 fun fetchTag name tags=case force tags of F.Nil=>(false,cell(text"",F.empty(),F.empty()))
   |F.Cons(tag,rest)=>let val(actual,_,_)=force tag in if equalText actual name then(true,tag)else fetchTag name rest end

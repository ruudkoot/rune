
 fun parseError message=cell(ParseError message)
 fun operandTerm term=cell(Operand(cell(ITerm term)))
 fun operandDeclaration dec=cell(Operand(cell(IDec dec)))
 fun readInteger chars=case Int.fromString(string chars)of SOME value=>int value|NONE=>raise Fail"Prelude.read: no parse"
 fun digitString chars=all(fn c=>Char.isDigit(force c))chars
 fun indexedSymbol first second:flagged=D.delay(fn()=>if digitString first andalso digitString second then
     force(operandTerm(cell(Sym(readInteger first,readInteger second,F.empty(),singleton symbolIndexed))))
   else ParseError(F.append(if digitString first then second else first)(text" is not an integer ")))
 fun indexedConstructor first second third=operandTerm(cell(Const(readInteger first,readInteger second,readInteger third,F.empty(),singleton symbolIndexed)))
 fun flaggedBinder kind declaration body:flagged=D.delay(fn()=>case(force declaration,force body)of
    (Operand dec,Operand term)=>(case(force dec,force term)of(IDec dec,ITerm body)=>
        force(operandTerm(cell(Binder(kind,dec,body,F.empty(),singleton prefixBinder))))|_=>raise Match)
   |(ParseError _,_)=>force declaration|(_,ParseError _)=>force body|_=>raise Match)
 fun flaggedConditional declaration first second:flagged=D.delay(fn()=>case force declaration of ParseError _=>force declaration
   |_=>case force first of ParseError _=>force first
   |_=>case force second of ParseError _=>force second
   |_=>case(force declaration,force first,force second)of(Operand dec,Operand first,Operand second)=>
      (case(force dec,force first,force second)of(IDec dec,ITerm first,ITerm second)=>
          force(operandTerm(cell(Cond(dec,first,second,F.empty(),F.empty()))))|_=>raise Match)|_=>raise Match)
 fun flaggedLet declaration first second:flagged=D.delay(fn()=>case force declaration of ParseError _=>force declaration
   |_=>case force first of ParseError _=>force first
   |_=>case force second of ParseError _=>force second
   |_=>case(force declaration,force first,force second)of(Operand dec,Operand first,Operand second)=>
      (case(force dec,force first,force second)of(IDec dec,ITerm first,ITerm second)=>
          let val function=bareBinder LambdaB dec second
          in force(operandTerm(cell(App(function,first,F.empty(),singleton letStyle))))end|_=>raise Fail"let' operand")
      |_=>raise Fail"let' operator")
 fun flaggedApplication first second:flagged=D.delay(fn()=>
   let fun bad()=raise Fail("app' y: "^string(unparseFlagged(cell(EmptySig(F.empty())))second)^"\nx: "^
          string(unparseFlagged(cell(EmptySig(F.empty())))first))
       fun special value wanted=case force value of Operator(opr,_,_)=>
          (case force opr of SpecialOperator actual=>equalText actual(text wanted)|_=>false)|_=>false
       fun result term=force(operandTerm term)
   in if special first""then force second else if special second""then force first
      else if special first"typed"then Operand(cell(TypeApp second))
      else case(force first,force second)of
       (Operator(operator,_,_),Operand operand)=>(case(force operator,force operand)of
          (BinderOperator kind,IDec dec)=>Operand(cell(PartialApp(kind,dec,cell false)))
         |(BinderOperator kind,ITerm sort)=>
             let val dec=cell(SymbolDec(sort,singleton(symbolName(cell(Name(text"_"))))))
             in Operand(cell(PartialApp(kind,dec,cell true)))end
         |(InfixOperator kind,ITerm term)=>Operand(cell(PartialInfix(kind,term)))
         |(TermOperator operator,ITerm term)=>
             let val style=case force first of Operator(_,kind,_)=>operatorStyle kind|_=>raise Match
             in result(cell(App(operator,term,F.empty(),singleton style)))end
         |_=>if special first","then(case force operand of ITerm term=>Operand(cell(PairApp term))|_=>bad())
             else if special first"typed"then Operand(cell(TypeApp second))
             else if special first"Not"then(case force operand of ITerm term=>result(cell(Unary(NotU,term,F.empty(),F.empty())))|_=>bad())
             else if special first":"then(case force operand of ITerm term=>Operand(cell(PartialColon term))|_=>bad())
             else bad())
      |(Operand first,Operand second)=>(case(force first,force second)of
          (PartialApp(kind,dec,anonymous),ITerm body)=>result(cell(Binder(kind,dec,
              D.delay(fn()=>force(if force anonymous then shiftTerm(F.empty())(int 1)body else body)),F.empty(),singleton infixBinder)))
         |(PartialInfix(kind,first),ITerm second)=>result(bareBinary kind first second)
         |(PairApp first,ITerm second)=>result(cell(PairTerm(first,second,bareConstant(Universe(int ~1)),F.empty(),singleton pairUntyped)))
         |(TypeApp value,ITerm sort)=>(case force value of Operand operand=>(case force operand of ITerm term=>
              (case force term of PairTerm(first,second,_,types,_)=>result(cell(PairTerm(first,second,sort,types,singleton pairTyped)))|_=>bad())
              |_=>bad())|_=>bad())
         |(PartialColon first,ITerm second)=>result(addType first second)
         |(ITerm first,ITerm second)=>result(makeApplication first second)|_=>bad())
      |(Operand operand,Operator(operator,_,_))=>(case(force operand,force operator)of(ITerm term,TermOperator operator)=>
          result(makeApplication term operator)|_=>bad())
      |(Operator(first,kind,_),Operator(second,_,_))=>(case(force first,force second)of(TermOperator a,TermOperator b)=>
          result(cell(App(a,b,F.empty(),singleton(operatorStyle kind))))|_=>bad())
      |(ParseError _,_)=>force first|(_,ParseError _)=>force second end)
 fun flaggedDeclarationPair attrs first second:flagged=D.delay(fn()=>case(force first,force second)of
    (ParseError _,_)=>force first|(_,ParseError _)=>force second
   |(Operand a,Operand b)=>(case(force a,force b)of(IDec a,IDec b)=>force(operandDeclaration(cell(DecPair(a,b,attrs))))|_=>raise Match)
   |_=>raise Match)
 fun flaggedSymbolDeclaration term name attrs:flagged=D.delay(fn()=>case force term of ParseError _=>force term
   |Operand operand=>(case force operand of ITerm term=>force(operandDeclaration(cell(SymbolDec(term,F.cons(symbolName name,attrs)))))
      |_=>raise Match)|_=>raise Match)
 fun flaggedRecurse terms sort:flagged=D.delay(fn()=>case force sort of ParseError _=>force sort
   |Operand operand=>(case force operand of ITerm sort=>
      let fun clear acc terms=L.delay(fn()=>case force terms of F.Nil=>Ok acc|F.Cons(term,rest)=>
           case force term of ParseError message=>Bad message
             |Operand operand=>(case force operand of ITerm term=>L.force(clear(F.cons(term,acc))rest)|_=>raise Match)
             |_=>raise Match)
      in case L.force(clear(F.empty())terms)of Ok terms=>force(operandTerm(cell(Recurse(terms,sort,F.empty(),singleton recursiveStyle))))
        |Bad message=>ParseError message end|_=>raise Match)|_=>raise Match)
 fun flaggedTag tag arguments:flagged=D.delay(fn()=>
   let fun check arguments=case force arguments of F.Nil=>NONE|F.Cons(arg,rest)=>case force arg of
        TagTerm term=>(case force term of TM _=>check rest|TermError message=>SOME message)
       |TagTheorem theorem=>(case force theorem of TH _=>check rest|TheoremError message=>SOME message)
       |TagInt _=>check rest
   in case check arguments of NONE=>force(operandTerm(cell(TagId(tag,arguments))))|SOME message=>ParseError message end)
